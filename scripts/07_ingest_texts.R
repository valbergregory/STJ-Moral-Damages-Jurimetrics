# 07_ingest_texts.R — Semana 2: ingere os TEXTOS completos dos documentos selecionados por família TPU
# (a partir de stg.documents_meta, censo do passo 05) abrindo só os TXT necessários dentro dos ZIP diários/mensais
# já baixados (passo 06), grava stg.document_text, roda o extrator monetário / desfecho quanto ao quantum /
# tribunal de origem sobre os textos ingeridos (stg.money_candidates, stg.doc_outcomes, stg.doc_origin) e gera
# (i) docs/08_text_ingest_report.md (só contagens) e (ii) templates de anotação ampliados em data/annotations/
# (não versionados: contêm trechos de decisões).
#
# Uso (Background Job ou Terminal):
#   Rscript scripts/07_ingest_texts.R                      # famílias padrão: negativacao,plano_saude (docs/03)
#   Rscript scripts/07_ingest_texts.R --families=negativacao
#   Rscript scripts/07_ingest_texts.R --limit-zips=20      # teste rápido
#   Rscript scripts/07_ingest_texts.R --skip-extract       # só ingestão dos textos
#   Rscript scripts/07_ingest_texts.R --only-extract       # só extração sobre o que já está em stg.document_text
# Idempotente/retomável: ZIP registrado em stg.ingest_log é pulado; a extração só roda para documentos ainda sem linha
# em stg.doc_outcomes. Seleção = classes cíveis (REsp/AREsp/EREsp/EAREsp) ∩ família "dano moral" ∩ (uma das famílias
# pedidas). A matéria principal/controle ainda AGUARDA aprovação do pesquisador (docs/03, decisions_log) — trocar
# --families não exige apagar nada: novos documentos são apenas acrescentados.
suppressPackageStartupMessages({
  library(dplyr); library(purrr); library(stringi); library(readr); library(tibble); library(tidyr); library(DBI); library(duckdb); library(digest)
})
root <- Sys.getenv("STJMD_ROOT", unset = "."); args <- commandArgs(trailingOnly = TRUE)
source(file.path(root, "R/extract_money.R")); source(file.path(root, "R/extract_origin.R")); source(file.path(root, "R/tpu_codes.R"))
opt <- function(name, default = NULL) { v <- args[startsWith(args, paste0("--", name, "="))]; if (length(v)) sub("^--[^=]+=", "", v[1]) else default }
families <- stri_split_fixed(opt("families", "negativacao,plano_saude"), ",")[[1]]
limit_zips <- as.integer(opt("limit-zips", NA)); skip_extract <- "--skip-extract" %in% args; only_extract <- "--only-extract" %in% args
stopifnot(all(families %in% setdiff(names(TPU_FAMILIES), "dano_moral")))  # dano_moral já é o filtro-base (dm_code)
EXTRACTOR_VERSION <- "0.2"          # ver R/extract_money.R (regra do rótulo antecedente + reference_value)
set.seed(20260912)

dir.create(file.path(root, "logs"), showWarnings = FALSE)
logf <- file.path(root, "logs/ingest_texts.log")
log <- function(...) { msg <- sprintf("[%s] %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), paste0(..., collapse = "")); cat(msg, "\n"); cat(msg, "\n", file = logf, append = TRUE) }
log("== 07_ingest_texts: famílias = ", paste(families, collapse = "+"), if (!is.na(limit_zips)) paste0(" | limit-zips=", limit_zips) else "")

con <- dbConnect(duckdb(), file.path(root, "data/stjmd.duckdb"))
on.exit(try(dbDisconnect(con, shutdown = TRUE), silent = TRUE), add = TRUE)
invisible(dbExecute(con, "CREATE SCHEMA IF NOT EXISTS stg"))
invisible(dbExecute(con, "CREATE TABLE IF NOT EXISTS stg.document_text (seq_documento BIGINT PRIMARY KEY, key VARCHAR, source_zip VARCHAR,
                 member VARCHAR, nchar INTEGER, text_sha256 VARCHAR, text_norm VARCHAR, ingested_at TIMESTAMP)"))
invisible(dbExecute(con, "CREATE TABLE IF NOT EXISTS stg.ingest_log (source_zip VARCHAR PRIMARY KEY, key VARCHAR, zip_exists BOOLEAN,
                 n_selected INTEGER, n_found INTEGER, n_missing INTEGER, seconds DOUBLE, ingested_at TIMESTAMP)"))
tbl_exists <- function(nm) dbExistsTable(con, DBI::Id(schema = "stg", table = nm))
append_tbl <- function(nm, df) { if (!nrow(df)) return(invisible()); id <- DBI::Id(schema = "stg", table = nm)
  if (tbl_exists(nm)) dbAppendTable(con, id, as.data.frame(df)) else dbWriteTable(con, id, as.data.frame(df)) }

# --- 1. seleção (recalculada a cada execução a partir do censo) --------------------------------------------------
fam_sql <- paste(sprintf("coalesce(%s, FALSE)", families), collapse = " OR ")
sel <- dbGetQuery(con, sprintf("SELECT seq_documento, key, ano, tipo_documento, classe, numero_registro, data_publicacao, %s
  FROM stg.documents_meta WHERE classe_civel AND dm_code AND (%s)", paste(families, collapse = ", "), fam_sql)) |> as_tibble()
sel <- sel |> mutate(across(all_of(families), ~ coalesce(.x, FALSE))) |>
  # o mesmo seq_documento pode constar em dois arquivos de metadados (diário + mensal de 2022): manter a 1ª ocorrência
  arrange(seq_documento, key) |> distinct(seq_documento, .keep_all = TRUE)
dbWriteTable(con, DBI::Id(schema = "stg", table = "selected_docs"), as.data.frame(sel), overwrite = TRUE)
log(sprintf("selecionados: %d documentos em %d chaves (dias/meses); por família: %s", nrow(sel), n_distinct(sel$key),
            paste(sprintf("%s=%d", families, map_int(families, ~ sum(sel[[.x]]))), collapse = ", ")))

# --- 2. ingestão dos textos, ZIP a ZIP -----------------------------------------------------------------------------
if (!only_extract) {
  zdir <- file.path(root, "data/raw/stj_integras/texts")
  done <- dbGetQuery(con, "SELECT source_zip FROM stg.ingest_log")$source_zip
  keys <- sort(unique(sel$key)); todo <- keys[!sprintf("textos%s.zip", keys) %in% done]
  if (!is.na(limit_zips)) todo <- head(todo, limit_zips)
  log(sprintf("ZIPs: %d necessários, %d já ingeridos, %d a processar", length(keys), length(keys) - length(todo), length(todo)))
  tmp <- file.path(tempdir(), "stj_ingest"); dir.create(tmp, showWarnings = FALSE, recursive = TRUE)
  have <- dbGetQuery(con, "SELECT seq_documento FROM stg.document_text")$seq_documento
  t_all <- Sys.time()
  for (i in seq_along(todo)) {
    k <- todo[i]; zf <- sprintf("textos%s.zip", k); zp <- file.path(zdir, zf); t0 <- Sys.time()
    need <- setdiff(sel$seq_documento[sel$key == k], have)
    row <- tibble(source_zip = zf, key = k, zip_exists = file.exists(zp), n_selected = length(need), n_found = 0L, n_missing = length(need))
    if (file.exists(zp) && length(need)) {
      lst <- tryCatch(utils::unzip(zp, list = TRUE), error = function(e) NULL)
      if (is.null(lst)) { log("ZIP ilegível: ", zf) } else {
        lst <- lst |> mutate(seq = suppressWarnings(as.integer(stri_extract_first_regex(basename(Name), "\\d+")))) |>
          filter(seq %in% need, Length > 0) |> distinct(seq, .keep_all = TRUE)
        if (nrow(lst)) {
          unlink(list.files(tmp, full.names = TRUE))
          files <- utils::unzip(zp, files = lst$Name, exdir = tmp, junkpaths = TRUE)
          txt <- map_chr(files, ~ tryCatch(read_file(.x), error = function(e) NA_character_))
          docs <- tibble(seq_documento = as.integer(stri_extract_first_regex(basename(files), "\\d+")), key = k, source_zip = zf,
                         member = lst$Name[match(seq_documento, lst$seq)], text_norm = normalize_text(txt)) |>
            filter(!is.na(text_norm), seq_documento %in% need) |>
            mutate(nchar = nchar(text_norm), text_sha256 = map_chr(text_norm, ~ digest(.x, algo = "sha256", serialize = FALSE)),
                   ingested_at = Sys.time()) |> distinct(seq_documento, .keep_all = TRUE)
          append_tbl("document_text", docs); have <- c(have, docs$seq_documento)
          row$n_found <- nrow(docs); row$n_missing <- length(need) - nrow(docs)
        }
      }
    }
    row$seconds <- as.numeric(difftime(Sys.time(), t0, units = "secs")); row$ingested_at <- Sys.time()
    dbExecute(con, "DELETE FROM stg.ingest_log WHERE source_zip = ?", params = list(zf)); append_tbl("ingest_log", row)
    if (i %% 50 == 0 || i == length(todo)) log(sprintf("[%d/%d] %s: %d/%d textos | acumulado %.1f min", i, length(todo), zf, row$n_found, row$n_selected,
                                                        as.numeric(difftime(Sys.time(), t_all, units = "mins"))))
  }
  unlink(tmp, recursive = TRUE)
}
cov <- dbGetQuery(con, "SELECT count(*) n_sel, sum((t.seq_documento IS NOT NULL)::int) n_txt FROM stg.selected_docs s LEFT JOIN stg.document_text t USING (seq_documento)")
log(sprintf("cobertura de texto: %d de %d selecionados (%.1f%%)", cov$n_txt, cov$n_sel, 100 * cov$n_txt / cov$n_sel))

# --- 3. extração (candidatos monetários, desfecho, origem) em lotes ---------------------------------------------
if (!skip_extract) {
  if (!tbl_exists("doc_outcomes")) dbExecute(con, "CREATE TABLE stg.doc_outcomes (seq_documento BIGINT PRIMARY KEY, outcome VARCHAR, sumula7 BOOLEAN,
                                                     quantum_topic BOOLEAN, dispositivo VARCHAR, extractor_version VARCHAR)")
  # órfãos de um lote interrompido (candidatos/origem gravados sem o desfecho correspondente) são refeitos
  for (nm in c("money_candidates", "doc_origin")) if (tbl_exists(nm))
    invisible(dbExecute(con, sprintf("DELETE FROM stg.%s WHERE seq_documento NOT IN (SELECT seq_documento FROM stg.doc_outcomes)", nm)))
  pend <- dbGetQuery(con, "SELECT DISTINCT t.seq_documento FROM stg.document_text t JOIN stg.selected_docs s USING (seq_documento)
                           LEFT JOIN stg.doc_outcomes o USING (seq_documento) WHERE o.seq_documento IS NULL")$seq_documento
  log(sprintf("extração pendente: %d documentos", length(pend)))
  chunks <- split(pend, ceiling(seq_along(pend) / 400)); t_all <- Sys.time()
  for (ci in seq_along(chunks)) {
    ids <- chunks[[ci]]
    d <- dbGetQuery(con, sprintf("SELECT seq_documento, text_norm FROM stg.document_text WHERE seq_documento IN (%s)", paste(ids, collapse = ",")))
    am <- map_dfr(seq_len(nrow(d)), function(j) tryCatch(extract_money(d$text_norm[j], d$seq_documento[j]), error = function(e) tibble()))
    oc <- map_dfr(seq_len(nrow(d)), function(j) tryCatch(stj_quantum_outcome(d$text_norm[j]), error = function(e) tibble(outcome = "erro", sumula7 = NA, quantum_topic = NA, dispositivo = NA_character_))) |>
      mutate(seq_documento = d$seq_documento, .before = 1) |> mutate(extractor_version = EXTRACTOR_VERSION)
    og <- map_dfr(seq_len(nrow(d)), function(j) tryCatch(extract_origin_court(d$text_norm[j]), error = function(e) tibble(origem_tipo = NA_character_, origem_uf = NA_character_, origem_evidencia = NA_character_, origem_fonte = NA_character_))) |>
      mutate(seq_documento = d$seq_documento, .before = 1)
    if (nrow(am)) am <- am |> rename(seq_documento = doc_id, start_pos = start, end_pos = end) |> mutate(extractor_version = EXTRACTOR_VERSION)
    append_tbl("money_candidates", am); append_tbl("doc_origin", og); dbAppendTable(con, DBI::Id(schema = "stg", table = "doc_outcomes"), as.data.frame(oc))
    if (ci %% 5 == 0 || ci == length(chunks)) log(sprintf("[lote %d/%d] %d docs, %d candidatos | %.1f min", ci, length(chunks), nrow(d), nrow(am),
                                                          as.numeric(difftime(Sys.time(), t_all, units = "mins"))))
  }
}

# --- 4. relatório (só contagens) + templates de anotação (não versionados) --------------------------------------
dir.create(file.path(root, "data/interim"), showWarnings = FALSE); dir.create(file.path(root, "data/annotations"), showWarnings = FALSE)
il <- dbGetQuery(con, "SELECT * FROM stg.ingest_log") |> as_tibble(); write_csv(il, file.path(root, "data/interim/ingest_log.csv"))
by_fam_year <- map_dfr(families, ~ dbGetQuery(con, sprintf("SELECT '%s' materia, ano, tipo_documento, count(*) n_sel, sum((t.seq_documento IS NOT NULL)::int) n_txt
  FROM stg.selected_docs s LEFT JOIN stg.document_text t USING (seq_documento) WHERE %s GROUP BY 1,2,3 ORDER BY 2,3", .x, .x)))
write_csv(by_fam_year, file.path(root, "data/interim/ingest_coverage_by_family_year.csv"))
has_oc <- tbl_exists("doc_outcomes") && tbl_exists("money_candidates")
if (has_oc) {
  oc_tab <- map_dfr(families, ~ dbGetQuery(con, sprintf("SELECT '%s' materia, outcome, sumula7, count(*) n FROM stg.doc_outcomes o JOIN stg.selected_docs s USING (seq_documento) WHERE %s GROUP BY 1,2,3 ORDER BY 4 DESC", .x, .x)))
  dm_docs <- map_dfr(families, ~ dbGetQuery(con, sprintf("SELECT '%s' materia, count(DISTINCT s.seq_documento) n_txt,
      count(DISTINCT CASE WHEN m.category='dano_moral' AND NOT m.in_precedent_quote AND m.unit='BRL' THEN m.seq_documento END) n_docs_valor_dm,
      count(DISTINCT CASE WHEN m.category='dano_moral' AND NOT m.in_precedent_quote AND m.unit='BRL' AND m.stage='stj' THEN m.seq_documento END) n_docs_valor_stj
      FROM stg.selected_docs s JOIN stg.document_text t USING (seq_documento) LEFT JOIN stg.money_candidates m USING (seq_documento) WHERE %s", .x, .x)))
  cat_tab <- dbGetQuery(con, "SELECT category, count(*) n, sum(in_precedent_quote::int) n_precedente FROM stg.money_candidates GROUP BY 1 ORDER BY 2 DESC")
  stage_tab <- dbGetQuery(con, "SELECT stage, direction, count(*) n FROM stg.money_candidates WHERE category='dano_moral' AND NOT in_precedent_quote GROUP BY 1,2 ORDER BY 1,3 DESC")
  origin_tab <- map_dfr(families, ~ dbGetQuery(con, sprintf("SELECT '%s' materia, coalesce(origem_fonte,'(sem origem)') origem_fonte, count(*) n FROM stg.doc_origin o JOIN stg.selected_docs s USING (seq_documento) WHERE %s GROUP BY 1,2 ORDER BY 3 DESC", .x, .x)))
  write_csv(oc_tab, file.path(root, "data/interim/full_outcomes_by_family.csv")); write_csv(cat_tab, file.path(root, "data/interim/full_candidates_by_category.csv"))
  write_csv(stage_tab, file.path(root, "data/interim/full_dm_stage_direction.csv")); write_csv(origin_tab, file.path(root, "data/interim/full_origin_coverage.csv"))
  # templates de anotação (estratificados; contêm trechos -> data/annotations/*.csv está no .gitignore)
  doc_pool <- dbGetQuery(con, sprintf("SELECT o.seq_documento, s.ano, s.tipo_documento, %s, o.outcome, o.sumula7, o.quantum_topic, o.dispositivo
    FROM stg.doc_outcomes o JOIN stg.selected_docs s USING (seq_documento)", paste(sprintf("s.%s", families), collapse = ", "))) |> as_tibble() |>
    mutate(materia = pmap_chr(pick(all_of(families)), ~ paste(families[c(...)], collapse = "+")))
  doc_ann <- doc_pool |> group_by(materia, outcome) |> slice_sample(n = 12) |> ungroup() |>
    transmute(seq_documento, ano, tipo_documento, materia, pred_outcome = outcome, pred_sumula7 = sumula7, dispositivo,
              true_outcome = "", true_quantum_stj_brl = "", true_quantum_origem_brl = "", note = "")
  write_excel_csv(doc_ann, file.path(root, "data/annotations/full_doc_outcome_template.csv"))
  am_pool <- dbGetQuery(con, "SELECT m.*, s.ano FROM stg.money_candidates m JOIN stg.selected_docs s USING (seq_documento)") |> as_tibble()
  am_ann <- bind_rows(am_pool |> group_by(category, stage) |> slice_sample(n = 6) |> ungroup(), am_pool |> slice_sample(n = 120)) |>
    distinct(seq_documento, start_pos, .keep_all = TRUE) |>
    transmute(seq_documento, ano, start_pos, raw, value, unit, pred_category = category, pred_stage = stage, pred_direction = direction,
              pred_in_precedent = in_precedent_quote, ctx_before, ctx_after, true_category = "", true_stage = "", true_direction = "", true_in_precedent = "", note = "")
  write_excel_csv(am_ann, file.path(root, "data/annotations/full_amount_template.csv"))
  log(sprintf("templates de anotação: %d documentos (desfecho) + %d candidatos (valores)", nrow(doc_ann), nrow(am_ann)))
}
md <- c("# 08 — Ingestão dos textos completos e extração (Semana 2)", "",
  sprintf("Gerado em %s por `scripts/07_ingest_texts.R` (famílias TPU: %s; extrator v%s). Seleção = classes cíveis ∩ família \"dano moral\" ∩ famílias pedidas, a partir de `stg.documents_meta` (docs/06). A escolha da matéria principal/controle continua **aguardando aprovação** (docs/03); o script aceita `--families=` e apenas acrescenta documentos.",
          format(Sys.time(), "%Y-%m-%d"), paste(families, collapse = ", "), EXTRACTOR_VERSION), "",
  sprintf("- Selecionados: **%d** documentos em %d chaves (dias/meses); com texto ingerido: **%d** (%.1f%%).", cov$n_sel, n_distinct(sel$key), cov$n_txt, 100 * cov$n_txt / cov$n_sel),
  sprintf("- ZIPs processados: %d (inexistentes: %d); textos não encontrados dentro dos ZIPs: %d.", nrow(il), sum(!il$zip_exists), sum(il$n_missing)), "",
  "## Cobertura por matéria, ano e tipo de documento", "", knitr::kable(by_fam_year |> pivot_wider(names_from = tipo_documento, values_from = c(n_sel, n_txt), values_fill = 0)), "")
if (has_oc) md <- c(md,
  "## Documentos com valor de dano moral extraído (fora de citação de precedente)", "", knitr::kable(dm_docs), "",
  "## Desfecho do STJ quanto ao quantum (classificador de dispositivo, NÃO validado)", "", knitr::kable(oc_tab |> pivot_wider(names_from = materia, values_from = n, values_fill = 0)), "",
  "## Candidatos monetários por categoria", "", knitr::kable(cat_tab), "",
  "## Candidatos 'dano_moral' por estágio × direção", "", knitr::kable(stage_tab |> pivot_wider(names_from = direction, values_from = n, values_fill = 0)), "",
  "## Cobertura do tribunal de origem", "", knitr::kable(origin_tab |> pivot_wider(names_from = materia, values_from = n, values_fill = 0)), "",
  "## Próximo passo", "", "Anotação manual pelo pesquisador em `data/annotations/full_doc_outcome_template.csv` (desfecho) e `full_amount_template.csv` (valores); depois `scripts/04_validity_metrics.R` → docs/07_extraction_validity.md. Nenhum número acima é resultado do artigo antes desse gate.")
writeLines(md, file.path(root, "docs/08_text_ingest_report.md"))
log("relatório: docs/08_text_ingest_report.md — fim")
