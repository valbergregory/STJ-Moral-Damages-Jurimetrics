# 05_metadata_census.R — censo exato do conjunto principal a partir de TODOS os metadados diários (sem textos):
# documentos por ano/classe/tipo, documentos com código de assunto de dano moral, matérias por código TPU
# (6226 negativação, 6233/12486 plano de saúde, 7781 protesto, 10435 acidente...), dias com metadados.
# Saída: data/interim/census_*.csv, DuckDB stg.documents (metadados), docs/06_metadata_census.md. Rodar como Background Job.
suppressPackageStartupMessages({ library(dplyr); library(purrr); library(readr); library(stringi); library(tidyr); library(DBI); library(duckdb) })
root <- Sys.getenv("STJMD_ROOT", unset = ".")
source(file.path(root, "R/build_sample_corpus.R"))   # read_metadata_day(), DM_CODES
files <- list.files(file.path(root, "data/raw/stj_integras/metadata"), "^metadados\\d{6,8}\\.json$", full.names = TRUE)
cat("arquivos de metadados:", length(files), "\n")
t0 <- Sys.time()
meta <- map_dfr(files, function(f) tryCatch(read_metadata_day(f) |> mutate(key = stri_extract_first_regex(basename(f), "\\d{6,8}")),
                                            error = function(e) { message("falha em ", basename(f), ": ", conditionMessage(e)); NULL }))
cat(sprintf("documentos: %d (%.1f min)\n", nrow(meta), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
meta <- meta |> mutate(ano = as.integer(format(data_publicacao, "%Y")),
                       leafs = stri_split_fixed(coalesce(assuntos_leaf, ""), ";"),
                       dm_code = map_lgl(leafs, ~ any(.x %in% DM_CODES)),
                       negativacao = map_lgl(leafs, ~ "6226" %in% .x),
                       protesto = map_lgl(leafs, ~ "7781" %in% .x),
                       plano_saude = map_lgl(leafs, ~ any(c("6233", "12486") %in% .x)),
                       acidente_transito = map_lgl(leafs, ~ any(c("10435", "9996", "10504") %in% .x)),
                       consumidor = map_lgl(leafs, ~ "7779" %in% .x),
                       civil_rc = map_lgl(leafs, ~ "10433" %in% .x),
                       adm_rc = map_lgl(leafs, ~ "9992" %in% .x),
                       classe_civel = classe %in% c("REsp", "AREsp", "EREsp", "EAREsp"))
dir.create(file.path(root, "data/interim"), showWarnings = FALSE)
w <- function(x, n) write_csv(x, file.path(root, "data/interim", n))
c_year <- meta |> count(ano, tipo_documento) |> pivot_wider(names_from = tipo_documento, values_from = n, values_fill = 0); w(c_year, "census_year_type.csv")
c_class <- meta |> count(classe, sort = TRUE); w(c_class, "census_class.csv")
c_dm <- meta |> filter(dm_code) |> count(ano, classe_civel, negativacao, plano_saude, protesto, acidente_transito); w(c_dm, "census_dm_topics.csv")
c_fmt <- meta |> count(ano, assuntos_formato); w(c_fmt, "census_assuntos_formato.csv")
c_days <- meta |> count(key) |> mutate(ano = substr(key, 1, 4)); w(c_days, "census_days.csv")
top_leaf <- meta |> filter(dm_code) |> select(seq_documento, leafs) |> unnest(leafs) |> count(leafs, sort = TRUE) |> head(40); w(top_leaf, "census_dm_top_leafs.csv")
# DuckDB
con <- dbConnect(duckdb(), file.path(root, "data/stjmd.duckdb"))
dbExecute(con, "CREATE SCHEMA IF NOT EXISTS stg")
dbWriteTable(con, DBI::Id(schema = "stg", table = "documents_meta"), select(meta, -leafs), overwrite = TRUE)
dbDisconnect(con, shutdown = TRUE)
# relatório
dmc <- meta |> filter(dm_code, classe_civel)
md <- c("# 06 — Censo dos metadados completos", "", sprintf("Gerado em %s por `scripts/05_metadata_census.R` a partir de %d arquivos de metadados (%d documentos).", format(Sys.time(), "%Y-%m-%d"), length(files), nrow(meta)), "",
        "## Documentos por ano e tipo", "", knitr::kable(c_year), "",
        "## Formato do campo de assuntos por ano", "", knitr::kable(c_fmt), "",
        sprintf("## Documentos com código TPU de dano moral: %d (%.1f%%); em classes cíveis (REsp/AREsp/EREsp/EAREsp): %d", sum(meta$dm_code), 100 * mean(meta$dm_code), nrow(dmc)), "",
        "| Matéria (código TPU) | Docs DM cíveis | por ano |", "|---|---|---|",
        map_chr(c("negativacao", "plano_saude", "protesto", "acidente_transito", "consumidor", "civil_rc", "adm_rc"), function(v) {
          x <- dmc |> filter(.data[[v]]); by <- x |> count(ano) |> mutate(s = sprintf("%d: %d", ano, n)) |> pull(s) |> paste(collapse = "; ")
          sprintf("| %s | %d | %s |", v, nrow(x), by) }), "",
        "## Classes mais frequentes", "", knitr::kable(head(c_class, 15)), "",
        "## Códigos-folha mais frequentes entre docs de dano moral", "", knitr::kable(top_leaf))
writeLines(md, file.path(root, "docs/06_metadata_census.md"))
cat("censo escrito em docs/06_metadata_census.md\n")
