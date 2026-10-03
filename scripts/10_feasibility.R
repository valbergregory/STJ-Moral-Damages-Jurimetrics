# 10_feasibility.R — gate G4 do plano de estimação (docs/10_estimation_plan.md): constrói os eventos decisórios a partir
# das tabelas da Fase 2 (R/awards_rules.R) e mede quanto dado há para cada modelo (R/feasibility.R). Só lê o banco.
# Saída: docs/10a_feasibility_report.md (somente contagens, sem texto de decisão) e data/interim/award_events_v0.rds
# (não versionado). NÃO estima nada e NÃO substitui o G1 (relatório de validade da extração).
#
# Uso (Terminal/Background Job; precisa de data/stjmd.duckdb com as tabelas do passo 07):
#   Rscript scripts/10_feasibility.R                 # relatório com a extração automática
#   Rscript scripts/10_feasibility.R --stan-test     # + testa a compilação do Stan (risco 4 de docs/04; pode levar minutos)
#   Rscript scripts/10_feasibility.R --reviewed=data/annotations/w3_documentos_VG.csv --key=data/annotations/w3_chave_documentos.csv
#       # sobrepõe a revisão manual (Q13–Q17) aos documentos anotados; a chave liga item_id → seq_documento
# Idempotente: sobrescreve os dois arquivos de saída.
suppressPackageStartupMessages({ library(dplyr); library(purrr); library(stringi); library(readr); library(tibble); library(tidyr); library(DBI); library(duckdb) })
root <- Sys.getenv("STJMD_ROOT", unset = "."); args <- commandArgs(trailingOnly = TRUE)
for (f in c("validity_metrics", "awards_rules", "feasibility")) source(file.path(root, "R", paste0(f, ".R")))
opt <- function(name, default = NULL) { v <- args[startsWith(args, paste0("--", name, "="))]; if (length(v)) sub("^--[^=]+=", "", v[1]) else default }
ipca_file <- opt("ipca", NULL)

db <- file.path(root, "data/stjmd.duckdb")
if (!file.exists(db)) stop("Banco não encontrado: ", db, ". Este script roda na máquina do autor, depois de scripts/07_ingest_texts.R (o banco não é versionado).")
con <- dbConnect(duckdb(), db, read_only = TRUE); on.exit(try(dbDisconnect(con, shutdown = TRUE), silent = TRUE), add = TRUE)
need <- c("selected_docs", "money_candidates", "doc_outcomes", "doc_origin")
miss <- need[!map_lgl(need, ~ dbExistsTable(con, DBI::Id(schema = "stg", table = .x)))]
if (length(miss)) stop("Tabelas ausentes em stg: ", paste(miss, collapse = ", "), " — rode scripts/07_ingest_texts.R.")
q <- function(tbl) as_tibble(dbGetQuery(con, sprintf("SELECT * FROM stg.%s", tbl)))
docs <- q("selected_docs"); cands <- q("money_candidates"); outc <- q("doc_outcomes"); og <- q("doc_origin")
cat(sprintf("selecionados: %d | candidatos: %d | desfechos: %d | origem: %d\n", nrow(docs), nrow(cands), nrow(outc), nrow(og)))

events <- build_award_events(cands, outc, docs, og)
note <- "Extração automática. "
rv_path <- opt("reviewed", NULL)
if (!is.null(rv_path)) {
  key <- read_annotation_csv(opt("key", file.path(root, "data/annotations/w3_chave_documentos.csv")))
  rv <- read_annotation_csv(rv_path) |> left_join(select(key, item_id, seq_documento), by = "item_id") |> mutate(seq_documento = as.numeric(seq_documento))
  events <- apply_reviewed(events, rv)
  note <- sprintf("Revisão manual aplicada a %d documentos (%d fora da seleção atual). ", sum(events$fonte_valores == "revisado"), attr(events, "n_revisados_fora"))
}
if (!is.null(ipca_file)) events <- add_real_values(events, read_csv(ipca_file, show_col_types = FALSE, col_types = "cd"), opt("base", "202512"))

tc <- check_toolchain(); stan <- if ("--stan-test" %in% args) stan_compile_test() else NULL
res <- feasibility_tables(events); dec <- feasibility_decisions(res, tc, stan)
out <- file.path(root, "docs/10a_feasibility_report.md")
writeLines(feasibility_md(res, dec, tc, stan, db_note = note), out, useBytes = TRUE)
dir.create(file.path(root, "data/interim"), showWarnings = FALSE, recursive = TRUE)
saveRDS(events, file.path(root, "data/interim/award_events_v0.rds"))
cat("\n", paste(readLines(out)[seq_len(min(60, length(readLines(out))))], collapse = "\n"), "\n\nRelatório: ", out, "\n", sep = "")
