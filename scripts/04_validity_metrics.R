# 04_validity_metrics.R — precisão, recall e F1 por campo a partir da anotação manual do pesquisador.
# Entrada: data/annotations/pilot_annotation_<iniciais>.csv (template preenchido: true_category, true_stage,
#          true_direction, true_in_precedent; linhas sem true_category são ignoradas). Vários anotadores → concordância.
# Saída: docs/07_extraction_validity.md (tabelas em Markdown) + outputs/overleaf/tables/extraction_validity.tex
suppressPackageStartupMessages({ library(dplyr); library(readr); library(purrr); library(tidyr); library(stringi); library(tibble) })
root <- Sys.getenv("STJMD_ROOT", unset = ".")
files <- list.files(file.path(root, "data/annotations"), "^pilot_annotation_[A-Za-z]+\\.csv$", full.names = TRUE)
if (!length(files)) stop("Nenhuma anotação encontrada (data/annotations/pilot_annotation_<iniciais>.csv). Preencha o template primeiro.")

prf <- function(pred, truth, positive) {
  tp <- sum(pred == positive & truth == positive); fp <- sum(pred == positive & truth != positive); fn <- sum(pred != positive & truth == positive)
  p <- if (tp + fp) tp / (tp + fp) else NA; r <- if (tp + fn) tp / (tp + fn) else NA
  tibble(class = positive, n_true = sum(truth == positive), precision = p, recall = r, f1 = if (!is.na(p) && !is.na(r) && p + r) 2 * p * r / (p + r) else NA)
}
field_report <- function(d, pred_col, true_col) {
  d <- d |> filter(!is.na(.data[[true_col]]), .data[[true_col]] != "")
  classes <- sort(unique(c(d[[pred_col]], d[[true_col]])))
  per <- map_dfr(classes, ~ prf(d[[pred_col]], d[[true_col]], .x))
  macro <- per |> summarise(class = "macro", n_true = sum(n_true), precision = mean(precision, na.rm = TRUE), recall = mean(recall, na.rm = TRUE), f1 = mean(f1, na.rm = TRUE))
  acc <- mean(d[[pred_col]] == d[[true_col]])
  list(table = bind_rows(per, macro), accuracy = acc, n = nrow(d))
}
md_table <- function(t) {
  t <- t |> mutate(across(c(precision, recall, f1), ~ ifelse(is.na(.x), "—", sprintf("%.3f", .x))))
  c(paste0("| ", paste(names(t), collapse = " | "), " |"), paste0("|", paste(rep("---", ncol(t)), collapse = "|"), "|"),
    apply(t, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
}
out <- c("# 07 — Validade da extração monetária (anotação manual)", "",
         sprintf("Gerado por `scripts/04_validity_metrics.R` em %s. Anotadores: %s.", format(Sys.time(), "%Y-%m-%d"), paste(basename(files), collapse = ", ")), "")
tex_rows <- c()
for (f in files) {
  a <- read_csv(f, show_col_types = FALSE, col_types = cols(.default = "c"))
  a <- a |> mutate(pred_in_precedent = tolower(pred_in_precedent), true_in_precedent = tolower(true_in_precedent))
  out <- c(out, sprintf("## Anotador: %s (n = %d candidatos anotados)", basename(f), sum(!is.na(a$true_category) & a$true_category != "")), "")
  for (fld in list(c("pred_category", "true_category", "Categoria"), c("pred_stage", "true_stage", "Estágio"),
                   c("pred_direction", "true_direction", "Direção"), c("pred_in_precedent", "true_in_precedent", "Dentro de precedente"))) {
    r <- field_report(a, fld[1], fld[2])
    out <- c(out, sprintf("### %s — acurácia %.3f (n = %d)", fld[3], r$accuracy, r$n), "", md_table(r$table), "")
    m <- r$table |> filter(class == "macro")
    tex_rows <- c(tex_rows, sprintf("%s & %d & %.3f & %.3f & %.3f & %.3f \\\\", fld[3], r$n, r$accuracy, m$precision, m$recall, m$f1))
  }
}
# concordância entre anotadores (se >1): proporção de rótulos iguais por campo
if (length(files) > 1) {
  ann <- map(files, ~ read_csv(.x, show_col_types = FALSE, col_types = cols(.default = "c")) |> select(doc_id, start, starts_with("true_")))
  j <- reduce(ann, ~ inner_join(.x, .y, by = c("doc_id", "start"), suffix = c("", ".b")))
  agree <- map_dbl(c("true_category", "true_stage", "true_direction", "true_in_precedent"), ~ mean(j[[.x]] == j[[paste0(.x, ".b")]], na.rm = TRUE))
  out <- c(out, "## Concordância entre anotadores (2 primeiros)", "", sprintf("- %s: %.3f", c("categoria", "estágio", "direção", "precedente"), agree), "")
}
writeLines(out, file.path(root, "docs/07_extraction_validity.md"))
dir.create(file.path(root, "outputs/overleaf/tables"), showWarnings = FALSE, recursive = TRUE)
writeLines(c("\\begin{table}[htbp]\\centering", "\\caption{Validity of the monetary extractor against manual annotation (macro-averaged)}", "\\label{tab:extraction_validity}",
             "\\begin{tabular}{lrrrrr}\\toprule", "Field & $n$ & Accuracy & Precision & Recall & F1 \\\\ \\midrule", tex_rows, "\\bottomrule\\end{tabular}\\end{table}"),
           file.path(root, "outputs/overleaf/tables/extraction_validity.tex"))
cat("escrito docs/07_extraction_validity.md e outputs/overleaf/tables/extraction_validity.tex\n")
