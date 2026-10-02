# validity_metrics.R — funções puras para medir a validade do extrator contra a anotação manual do pesquisador:
# leitura tolerante de CSV salvo pelo Excel/LibreOffice (vírgula ou ponto e vírgula, BOM), normalização de rótulos,
# booleanos e valores em reais digitados à mão, P/R/F1 por classe (com pesos de desenho opcionais), intervalo
# bootstrap, comparação de valores por estágio no nível do documento e kappa de Cohen (re-anotação intra-anotador).
# Usado por scripts/04_validity_metrics.R; testado em tests/testthat/test-validity_metrics.R.
suppressPackageStartupMessages({ library(dplyr); library(purrr); library(tibble); library(stringi); library(readr) })

# --- leitura ------------------------------------------------------------------------------------------------------
read_annotation_csv <- function(path) {
  first <- readLines(path, n = 1, warn = FALSE, encoding = "UTF-8")
  first <- if (length(first)) first else ""
  delim <- if (stri_count_fixed(first, ";") > stri_count_fixed(first, ",")) ";" else ","
  d <- read_delim(path, delim = delim, col_types = cols(.default = col_character()), na = character(),
                  trim_ws = TRUE, show_col_types = FALSE, progress = FALSE)
  names(d) <- stri_replace_all_regex(names(d), "^\\x{FEFF}", "") |> stri_trim_both()
  d
}

# --- normalização -------------------------------------------------------------------------------------------------
norm_label <- function(x) {
  x <- stri_trans_tolower(stri_trim_both(coalesce(as.character(x), "")))
  x <- stri_trans_general(x, "Latin-ASCII")
  x <- stri_replace_all_regex(x, "[\\s\\-]+", "_")
  ifelse(x == "", NA_character_, x)
}
parse_bool_pt <- function(x) {
  x <- norm_label(x)
  out <- rep(NA, length(x))
  out[x %in% c("sim", "s", "true", "t", "1", "verdadeiro", "v", "yes", "y", "x")] <- TRUE
  out[x %in% c("nao", "n", "false", "f", "0", "falso", "no")] <- FALSE
  out
}
# "R$ 10.000,00", "10.000", "10000", "10000,5", "10 mil" → número; vazio/"-"/"nd" → NA. Vários valores: "10000; 5000".
parse_brl_input <- function(x) {
  one <- function(s) {
    s <- stri_trans_tolower(stri_trim_both(s))
    if (is.na(s) || s %in% c("", "-", "nd", "na", "n/a")) return(NA_real_)
    mult <- if (stri_detect_regex(s, "\\bmil\\b")) 1e3 else 1
    s <- stri_replace_all_regex(s, "[^0-9,\\.]", "")
    if (s == "") return(NA_real_)
    v <- if (stri_detect_fixed(s, ",")) {
      p <- stri_split_fixed(s, ",")[[1]]
      as.numeric(stri_replace_all_fixed(p[1], ".", "")) + as.numeric(paste0("0.", p[2]))
    } else if (stri_detect_regex(s, "^\\d{1,3}(\\.\\d{3})+$")) as.numeric(stri_replace_all_fixed(s, ".", "")) else suppressWarnings(as.numeric(s))
    v * mult
  }
  map_dbl(coalesce(as.character(x), ""), one)
}
# conjunto de valores em uma célula ("10000;5000") — usado nos campos de valor por estágio
parse_value_set <- function(x) {
  map(coalesce(as.character(x), ""), function(s) {
    if (stri_trim_both(s) == "") return(numeric(0))
    v <- parse_brl_input(stri_split_regex(s, "[;|/]")[[1]]); sort(unique(v[!is.na(v)]))
  })
}

# --- P/R/F1 ----------------------------------------------------------------------------------------------------------
# Por classe (um contra todos) sobre pares com rótulo verdadeiro preenchido. Pesos w (desenho) opcionais.
# Convenção do scikit-learn para o macro: classe sem predições (P indefinida) ou sem verdadeiros (R indefinida)
# entra com 0 no macro-F1; na tabela por classe o valor indefinido aparece como NA.
prf_table <- function(pred, truth, w = NULL) {
  ok <- !is.na(truth); pred <- coalesce(pred[ok], "(vazio)"); truth <- truth[ok]
  w <- if (is.null(w)) rep(1, length(truth)) else as.numeric(w)[ok]
  classes <- sort(unique(c(pred, truth)))
  per <- map_dfr(classes, function(k) {
    tp <- sum(w[pred == k & truth == k]); fp <- sum(w[pred == k & truth != k]); fn <- sum(w[pred != k & truth == k])
    p <- if (tp + fp > 0) tp / (tp + fp) else NA_real_; r <- if (tp + fn > 0) tp / (tp + fn) else NA_real_
    f <- if (!is.na(p) && !is.na(r) && p + r > 0) 2 * p * r / (p + r) else if (!is.na(p) && !is.na(r)) 0 else NA_real_
    tibble(class = k, n_true = sum(truth == k), n_pred = sum(pred == k), precision = p, recall = r, f1 = f)
  })
  z <- function(v) coalesce(v, 0)
  macro <- tibble(class = "macro", n_true = sum(per$n_true), n_pred = sum(per$n_pred),
                  precision = mean(z(per$precision)), recall = mean(z(per$recall)), f1 = mean(z(per$f1)))
  list(table = bind_rows(per, macro), accuracy = if (length(truth)) sum(w * (pred == truth)) / sum(w) else NA_real_, n = length(truth))
}
# versão rápida (base R) do macro-F1 de prf_table(), usada no bootstrap; mesma convenção (indefinido = 0)
macro_f1 <- function(pred, truth, w = NULL) {
  ok <- !is.na(truth); pred <- pred[ok]; pred[is.na(pred)] <- "(vazio)"; truth <- truth[ok]
  w <- if (is.null(w)) rep(1, length(truth)) else as.numeric(w)[ok]
  if (!length(truth)) return(0)
  lv <- sort(unique(c(pred, truth))); hit <- pred == truth
  tp <- tapply(c(w[hit], 0 * seq_along(lv)), factor(c(truth[hit], lv), lv), sum)
  np <- tapply(c(w, 0 * seq_along(lv)), factor(c(pred, lv), lv), sum); nt <- tapply(c(w, 0 * seq_along(lv)), factor(c(truth, lv), lv), sum)
  p <- ifelse(np > 0, tp / np, 0); r <- ifelse(nt > 0, tp / nt, 0); f <- ifelse(p + r > 0, 2 * p * r / (p + r), 0)
  mean(f)
}
class_f1 <- function(pred, truth, k, w = NULL) { t <- prf_table(pred, truth, w)$table; v <- t$f1[t$class == k]; if (length(v)) v else NA_real_ }

# IC percentil por bootstrap sobre os itens (reamostragem simples; semente fixa).
bootstrap_ci <- function(pred, truth, stat = macro_f1, B = 1000L, seed = 20261002L, level = 0.95) {
  ok <- !is.na(truth); pred <- pred[ok]; truth <- truth[ok]; n <- length(truth)
  if (n < 2 || B < 1) return(c(lo = NA_real_, hi = NA_real_))
  set.seed(seed)
  s <- replicate(B, { i <- sample.int(n, n, replace = TRUE); stat(pred[i], truth[i]) })
  a <- (1 - level) / 2; q <- stats::quantile(s, c(a, 1 - a), na.rm = TRUE, names = FALSE); c(lo = q[1], hi = q[2])
}

# --- valores por estágio (nível do documento) -----------------------------------------------------------------
# pred_set / true_set: listas de vetores numéricos. TP se algum valor verdadeiro está no conjunto predito (tolerância
# `tol` em reais); FN se há verdadeiro e nenhum casa; FP se há predito e nenhum casa com um verdadeiro (inclui
# verdadeiro vazio); TN se ambos vazios. `exato` = conjuntos iguais (mede a ambiguidade de vários valores por estágio).
match_value_sets <- function(pred_set, true_set, tol = 0.5) {
  map2_dfr(pred_set, true_set, function(p, t) {
    hit <- length(p) && length(t) && any(outer(t, p, function(a, b) abs(a - b) <= tol))
    tibble(tp = hit, fp = length(p) > 0 && !hit, fn = length(t) > 0 && !hit, tn = !length(p) && !length(t),
           exato = length(p) == length(t) && (!length(p) || all(abs(sort(p) - sort(t)) <= tol)))
  })
}
prf_counts <- function(tp, fp, fn) {
  p <- if (tp + fp > 0) tp / (tp + fp) else NA_real_; r <- if (tp + fn > 0) tp / (tp + fn) else NA_real_
  tibble(tp = tp, fp = fp, fn = fn, precision = p, recall = r,
         f1 = if (!is.na(p) && !is.na(r) && p + r > 0) 2 * p * r / (p + r) else if (!is.na(p) && !is.na(r)) 0 else NA_real_)
}

# --- concordância ------------------------------------------------------------------------------------------------
# Kappa de Cohen para dois vetores de rótulos (pares com NA descartados). po = concordância observada.
cohen_kappa <- function(a, b) {
  a <- as.character(a); b <- as.character(b); ok <- !is.na(a) & !is.na(b); a <- a[ok]; b <- b[ok]; n <- length(a)
  if (!n) return(tibble(n = 0L, po = NA_real_, pe = NA_real_, kappa = NA_real_))
  lv <- union(a, b); pa <- table(factor(a, lv)) / n; pb <- table(factor(b, lv)) / n
  po <- mean(a == b); pe <- sum(pa * pb)
  tibble(n = n, po = po, pe = pe, kappa = if (pe < 1) (po - pe) / (1 - pe) else NA_real_)
}

# --- formatação --------------------------------------------------------------------------------------------------
fmt3 <- function(x) ifelse(is.na(x), "—", sprintf("%.3f", x))
md_table <- function(t) {
  t <- t |> mutate(across(where(is.double), fmt3), across(everything(), ~ stri_replace_all_fixed(as.character(.x), "|", "\\|")))
  c(paste0("| ", paste(names(t), collapse = " | "), " |"), paste0("|", paste(rep("---", ncol(t)), collapse = "|"), "|"),
    apply(t, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
}
