# annotation_sampling.R — amostragem estratificada, semeada e reprodutível para a anotação manual da Semana 3
# (300 candidatos monetários + 150 documentos completos + subconjunto cego de re-anotação).
# Funções puras (sem DuckDB): recebem data frames e devolvem a amostra com estrato, N_h, n_h e peso de desenho
# (w = N_h / n_h), para que as métricas possam ser reportadas também ponderadas para a população.
# O script scripts/08_annotation_sample.R faz a leitura do banco e a escrita das planilhas.
suppressPackageStartupMessages({ library(dplyr); library(purrr); library(tibble); library(stringi) })

# Alocação proporcional (n·N_h/N, maior resto) seguida de piso por estrato (min_n, limitado a N_h): as unidades
# que faltam aos estratos pequenos saem, uma a uma, do estrato com maior folga acima do piso.
# N: vetor nomeado de tamanhos de estrato; n: tamanho total. Devolve vetor inteiro nomeado que soma min(n, sum(N)).
allocate_strata <- function(N, n, min_n = 1L) {
  stopifnot(length(N) >= 1, all(N >= 0), n >= 0)
  N <- N[N > 0]; n <- min(n, sum(N))
  if (!length(N) || n == 0) return(setNames(integer(length(N)), names(N)))
  floor_n <- pmin(N, min_n)
  if (sum(floor_n) >= n) {           # mais estratos que unidades: os maiores estratos recebem 1 cada (ordem estável)
    o <- order(-N, names(N)); a <- setNames(integer(length(N)), names(N)); a[o[seq_len(n)]] <- 1L; return(a)
  }
  q <- n * N / sum(N); a <- floor(q); r <- n - sum(a)
  if (r > 0) { o <- order(-(q - a), -N, names(N)); a[o[seq_len(r)]] <- a[o[seq_len(r)]] + 1 }
  while (any(a < floor_n)) {
    i <- which(a < floor_n)[1]; donor <- which.max(ifelse(a > floor_n, a - floor_n, -Inf))
    a[i] <- a[i] + 1; a[donor] <- a[donor] - 1
  }
  out <- as.integer(a); names(out) <- names(N); out
}

# Amostra estratificada de `pool` por coluna `stratum`; `alloc` = vetor nomeado n_h. Ordem determinística
# (ordena por `id_cols` antes de sortear) para que a mesma semente gere a mesma amostra em qualquer máquina.
draw_stratified <- function(pool, alloc, id_cols, seed) {
  set.seed(seed)
  pool <- pool |> arrange(stratum, across(all_of(id_cols)))
  Nh <- table(pool$stratum)
  map_dfr(names(alloc)[alloc > 0], function(h) {
    p <- pool[pool$stratum == h, , drop = FALSE]
    p[sort(sample.int(nrow(p), alloc[[h]])), , drop = FALSE] |>
      mutate(N_h = as.integer(Nh[[h]]), n_h = as.integer(alloc[[h]]), w = N_h / n_h)
  })
}

# Rótulo de matéria a partir das flags de família TPU (um documento pode ter as duas).
materia_label <- function(negativacao, plano_saude) {
  negativacao <- coalesce(as.logical(negativacao), FALSE); plano_saude <- coalesce(as.logical(plano_saude), FALSE)
  case_when(negativacao & plano_saude ~ "ambas", negativacao ~ "negativacao", plano_saude ~ "plano_saude", TRUE ~ "outra")
}

# --- 300 candidatos monetários ---------------------------------------------------------------------------------
# cand: um candidato por linha com seq_documento, start_pos, category, stage, direction, in_precedent_quote, ano,
#       materia, doc_sem_dm (o documento foi classificado `sem_dano_moral`), form.
# Bloco A (share_dm · n): candidatos preditos `dano_moral` — o que o artigo usa —, estratos matéria × ano × doc_sem_dm.
# Bloco B (restante): demais categorias, estratos matéria × categoria predita, mínimo `min_other` por estrato,
#       para estimar a precisão de cada categoria (inclusive as raras: custas, dano_estetico, conjunto...).
# Os blocos particionam o universo (estrato = bloco + células), logo os pesos w são pesos de desenho válidos.
sample_amounts <- function(cand, n = 300L, share_dm = 0.6, min_other = 5L, seed = 20261002L) {
  cand <- cand |> mutate(block = if_else(category == "dano_moral", "A", "B"),
                         stratum = if_else(block == "A",
                                           paste("A", materia, ano, if_else(doc_sem_dm, "semDM", "comDM"), sep = "|"),
                                           paste("B", materia, category, sep = "|")))
  nA <- min(round(n * share_dm), sum(cand$block == "A")); nB <- n - nA
  NA_h <- table(cand$stratum[cand$block == "A"]); NB_h <- table(cand$stratum[cand$block == "B"])
  alloc <- c(allocate_strata(setNames(as.numeric(NA_h), names(NA_h)), nA, 1L),
             allocate_strata(setNames(as.numeric(NB_h), names(NB_h)), nB, min_other))
  draw_stratified(cand, alloc, c("seq_documento", "start_pos"), seed)
}

# --- 150 documentos completos -------------------------------------------------------------------------------
# docs: um documento por linha com seq_documento, ano, materia, has_brl (texto contém "R$"), outcome (predito).
# Bloco R (n_rare): desfechos preditos raros e decisivos para RQ3/RQ4 (majorado/reduzido/ambiguo/provido_verificar),
#       sobreamostrados para que haja casos positivos a avaliar; estratos = desfecho predito.
# Bloco P (restante): estratos matéria × ano × has_brl × sem_dano_moral — o achado de 12/09 (≈50 % sem menção a
#       dano moral) é um eixo explícito para decidir se é ruído do código TPU ou limite do regex.
RARE_OUTCOMES <- c("majorado_stj", "reduzido_stj", "ambiguo", "provido_verificar")
sample_documents <- function(docs, n = 150L, n_rare = 30L, seed = 20261002L) {
  docs <- docs |> mutate(block = if_else(outcome %in% RARE_OUTCOMES, "R", "P"),
                         stratum = if_else(block == "R", paste("R", outcome, sep = "|"),
                                           paste("P", materia, ano, if_else(has_brl, "comRS", "semRS"),
                                                 if_else(outcome == "sem_dano_moral", "semDM", "comDM"), sep = "|")))
  NR_h <- table(docs$stratum[docs$block == "R"]); NP_h <- table(docs$stratum[docs$block == "P"])
  nR <- min(n_rare, sum(NR_h)); nP <- n - nR
  alloc <- c(allocate_strata(setNames(as.numeric(NR_h), names(NR_h)), nR, 1L),
             allocate_strata(setNames(as.numeric(NP_h), names(NP_h)), nP, 1L))
  draw_stratified(docs, alloc, "seq_documento", seed)
}

# --- identificadores e re-anotação cega -----------------------------------------------------------------------
# item_id sequencial na ordem embaralhada (o anotador não vê estrato nem predição).
assign_item_ids <- function(s, prefix, seed) {
  set.seed(seed); s <- s[sample.int(nrow(s)), , drop = FALSE]
  s$item_id <- sprintf("%s%03d", prefix, seq_len(nrow(s))); s
}
# Subconjunto para re-anotação intra-anotador: amostra aleatória simples dos itens já sorteados, com NOVOS
# identificadores e nova ordem (cego em relação à 1ª passada). Devolve (item_id_reanot, item_id).
reannotation_subset <- function(s, n, prefix, seed) {
  set.seed(seed); n <- min(n, nrow(s))
  pick <- s$item_id[sort(sample.int(nrow(s), n))]
  pick <- pick[sample.int(length(pick))]
  tibble(item_id_reanot = sprintf("%s%03d", prefix, seq_along(pick)), item_id = pick)
}

# Marca o valor no contexto para a planilha: "... antes ⟦R$ 10.000,00⟧ depois ..." (quebras de linha → espaço).
mark_context <- function(before, raw, after) {
  clean <- function(x) stri_trim_both(stri_replace_all_regex(coalesce(x, ""), "\\s+", " "))
  paste0("…", clean(before), " ⟦", raw, "⟧ ", clean(after), "…")
}

# TRUE se alguma célula de anotação (colunas true_*) já foi preenchida — protege trabalho manual de sobrescrita.
has_annotations <- function(path) {
  if (!file.exists(path)) return(FALSE)
  first <- tryCatch(readLines(path, n = 1, warn = FALSE, encoding = "UTF-8"), error = function(e) "")
  sep <- if (length(first) && stri_count_fixed(first, ";") > stri_count_fixed(first, ",")) ";" else ","
  d <- tryCatch(utils::read.csv(path, sep = sep, colClasses = "character", check.names = FALSE, encoding = "UTF-8"), error = function(e) NULL)
  if (is.null(d)) return(TRUE)   # ilegível: não arriscar
  tc <- grep("^true_", names(d), value = TRUE)
  length(tc) > 0 && any(!is.na(as.matrix(d[tc])) & stri_trim_both(as.matrix(d[tc])) != "")
}

# --- montagem completa da amostra da Semana 3 (usada por scripts/08_annotation_sample.R) -----------------------
W3_FILES <- c(modelo_valores = "w3_modelo_valores.csv", modelo_documentos = "w3_modelo_documentos.csv",
              modelo_reanotacao_valores = "w3_modelo_reanotacao_valores.csv", modelo_reanotacao_documentos = "w3_modelo_reanotacao_documentos.csv",
              chave_valores = "w3_chave_valores.csv", chave_documentos = "w3_chave_documentos.csv",
              chave_reanotacao_valores = "w3_chave_reanotacao_valores.csv", chave_reanotacao_documentos = "w3_chave_reanotacao_documentos.csv",
              estratos = "w3_amostra_estratos.csv")
AMOUNT_TRUE_COLS <- c("true_valor_correto", "true_category", "true_stage", "true_direction", "true_in_precedent", "true_reference_value")
DOC_TRUE_COLS <- c("true_materia", "true_menciona_dano_moral", "true_resultado_stj", "true_valor_pedido", "true_valor_sentenca",
                   "true_valor_acordao_origem", "true_valor_stj", "true_per_capita", "true_n_vitimas", "true_origem_uf",
                   "true_incluir", "true_motivo_exclusao")

# Sorteio: cand (candidatos) e docs (documentos) como descritos em sample_amounts()/sample_documents().
draw_week3 <- function(cand, docs, n_amounts = 300L, n_docs = 150L, n_rare = 30L, share_dm = 0.6,
                       n_reanot_amounts = 45L, n_reanot_docs = 25L, seed = 20261002L) {
  sa <- sample_amounts(cand, n = n_amounts, share_dm = share_dm, seed = seed) |> assign_item_ids("V", seed + 1L)
  sd <- sample_documents(docs, n = n_docs, n_rare = n_rare, seed = seed + 2L) |> assign_item_ids("D", seed + 3L)
  list(sa = sa, sd = sd, ra = reannotation_subset(sa, n_reanot_amounts, "RV", seed + 4L),
       rd = reannotation_subset(sd, n_reanot_docs, "RD", seed + 5L))
}

fmt_brl <- function(v, u) ifelse(is.na(v), "", ifelse(u == "SM", paste(formatC(v, format = "fg", big.mark = ".", decimal.mark = ","), "SM"),
                                                      paste("R$", formatC(v, format = "f", digits = 2, big.mark = ".", decimal.mark = ","))))
fmt_value_set <- function(v) paste(vapply(sort(unique(v)), function(x) format(x, scientific = FALSE), ""), collapse = ";")
w3_text_file <- function(seq) sprintf("w3_textos/%s.txt", seq)

# Monta todas as tabelas de saída. texts: (seq_documento, text_norm); dm_vals: (seq_documento, stage, value) dos
# candidatos dano_moral BRL fora de precedente e fora de valor de referência; orig: (seq_documento, origem_uf).
finalize_week3 <- function(dr, texts, dm_vals, orig) {
  sa <- dr$sa |> left_join(texts, by = "seq_documento") |>
    mutate(contexto = pmap_chr(list(text_norm, start_pos, end_pos, raw, ctx_before, ctx_after), function(t, s, e, r, cb, ca) {
      if (is.na(t)) return(mark_context(cb, r, ca))   # contexto ampliado: 600 caracteres antes / 300 depois
      mark_context(stri_sub(t, max(1, s - 600), s - 1), stri_sub(t, s, e), stri_sub(t, e + 1, min(nchar(t), e + 300)))
    })) |> select(-text_norm)
  vals <- dm_vals |> group_by(seq_documento, stage) |> summarise(v = fmt_value_set(value), .groups = "drop")
  pv <- function(st, nm) { x <- vals |> filter(stage == st) |> select(seq_documento, v); names(x)[2] <- nm; x }
  sd <- dr$sd |> left_join(pv("pedido", "pred_valor_pedido"), by = "seq_documento") |>
    left_join(pv("origem_sentenca", "pred_valor_sentenca"), by = "seq_documento") |>
    left_join(pv("origem_acordao", "pred_valor_acordao_origem"), by = "seq_documento") |>
    left_join(pv("stj", "pred_valor_stj"), by = "seq_documento") |>
    left_join(orig |> distinct(seq_documento, .keep_all = TRUE) |> rename(pred_origem_uf = origem_uf), by = "seq_documento") |>
    mutate(across(starts_with("pred_valor_"), ~ coalesce(.x, "")), pred_origem_uf = coalesce(pred_origem_uf, ""))
  blank <- function(cols) as_tibble(setNames(rep(list(""), length(cols)), cols))
  amount_sheet <- function(d, id_col) {
    o <- d |> transmute(id = .data[[id_col]], ano, valor_extraido = raw, valor_lido = fmt_brl(value, unit), contexto,
                        arquivo_texto = w3_text_file(seq_documento))
    o <- bind_cols(o, blank(AMOUNT_TRUE_COLS)[rep(1, nrow(o)), ]) |> mutate(nota = ""); names(o)[1] <- id_col; o
  }
  doc_sheet <- function(d, id_col) {
    o <- d |> transmute(id = .data[[id_col]], seq_documento, classe, tipo_documento, ano, arquivo_texto = w3_text_file(seq_documento))
    o <- bind_cols(o, blank(DOC_TRUE_COLS)[rep(1, nrow(o)), ]) |> mutate(nota = ""); names(o)[1] <- id_col; o
  }
  list(
    modelo_valores = amount_sheet(sa |> arrange(item_id), "item_id"),
    modelo_documentos = doc_sheet(sd |> arrange(item_id), "item_id"),
    modelo_reanotacao_valores = amount_sheet(dr$ra |> inner_join(sa, by = "item_id") |> arrange(item_id_reanot), "item_id_reanot"),
    modelo_reanotacao_documentos = doc_sheet(dr$rd |> inner_join(sd, by = "item_id") |> arrange(item_id_reanot), "item_id_reanot"),
    chave_valores = sa |> arrange(item_id) |> transmute(item_id, seq_documento, start_pos, end_pos, stratum, N_h, n_h, w, materia, ano,
      doc_sem_dm, value, unit, form, pred_category = category, pred_stage = stage, pred_direction = direction,
      pred_in_precedent = in_precedent_quote, pred_reference_value = reference_value, pred_per_capita = per_capita),
    chave_documentos = sd |> arrange(item_id) |> transmute(item_id, seq_documento, stratum, N_h, n_h, w, materia, ano, has_brl,
      pred_outcome = outcome, pred_sumula7 = sumula7, pred_valor_pedido, pred_valor_sentenca, pred_valor_acordao_origem,
      pred_valor_stj, pred_origem_uf),
    chave_reanotacao_valores = dr$ra, chave_reanotacao_documentos = dr$rd,
    estratos = bind_rows(sa |> distinct(stratum, N_h, n_h) |> mutate(amostra = "valores"),
                         sd |> distinct(stratum, N_h, n_h) |> mutate(amostra = "documentos")) |>
      select(amostra, stratum, N_h, n_h) |> arrange(amostra, stratum))
}

# Grava as tabelas (CSV UTF-8 com BOM, abre direto no Excel) e os textos integrais em <ann_dir>/w3_textos/.
write_week3 <- function(out, texts, ann_dir) {
  dir.create(file.path(ann_dir, "w3_textos"), showWarnings = FALSE, recursive = TRUE)
  for (k in names(W3_FILES)) readr::write_excel_csv(out[[k]], file.path(ann_dir, W3_FILES[[k]]), na = "")
  walk2(texts$seq_documento, texts$text_norm, ~ writeLines(enc2utf8(.y), file.path(ann_dir, "w3_textos", sprintf("%s.txt", .x)), useBytes = TRUE))
  invisible(file.path(ann_dir, W3_FILES))
}
