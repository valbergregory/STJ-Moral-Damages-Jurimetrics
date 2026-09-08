# 05_metadata_census.R — censo exato do conjunto principal a partir de TODOS os metadados diários (sem textos).
# Passo 1 (lento, ~30 min): parse dos 1.287 JSON -> DuckDB stg.documents_meta (só se a tabela não existir ou com --reparse).
# Passo 2 (rápido): flags de matéria por FAMÍLIA TPU (ancestrais; ver R/tpu_codes.R) -> data/interim/census_*.csv,
# stg.documents_meta atualizada, docs/06_metadata_census.md. Rodar como Background Job.
suppressPackageStartupMessages({ library(dplyr); library(purrr); library(readr); library(stringi); library(tidyr); library(DBI); library(duckdb) })
root <- Sys.getenv("STJMD_ROOT", unset = "."); args <- commandArgs(trailingOnly = TRUE)
source(file.path(root, "R/build_sample_corpus.R")); source(file.path(root, "R/tpu_codes.R"))
db <- file.path(root, "data/stjmd.duckdb"); con <- dbConnect(duckdb(), db)
have <- dbExistsTable(con, DBI::Id(schema = "stg", table = "documents_meta"))
if (!have || "--reparse" %in% args) {
  files <- list.files(file.path(root, "data/raw/stj_integras/metadata"), "^metadados\\d{6,8}\\.json$", full.names = TRUE)
  cat("arquivos de metadados:", length(files), "\n"); t0 <- Sys.time()
  meta <- map_dfr(files, function(f) tryCatch(read_metadata_day(f) |> mutate(key = stri_extract_first_regex(basename(f), "\\d{6,8}")),
                                              error = function(e) { message("falha em ", basename(f), ": ", conditionMessage(e)); NULL }))
  cat(sprintf("documentos: %d (%.1f min)\n", nrow(meta), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  meta <- meta |> mutate(ano = as.integer(format(data_publicacao, "%Y")))
} else {
  meta <- dbGetQuery(con, "SELECT * FROM stg.documents_meta") |> as_tibble()
  meta <- meta |> select(-any_of(c("dm_code", "negativacao", "protesto", "plano_saude", "acidente_transito", "consumidor", "civil_rc", "adm_rc",
                                   "classe_civel", "n_codigos", "leafs", "protesto_indevido", "consumidor_rf")))
  cat("lido do DuckDB:", nrow(meta), "documentos\n")
}
tpu <- load_tpu(file.path(root, "data/raw/cnj_assuntos.csv")); parent <- tpu_parent_map(tpu)
# flags por família (calculadas sobre o conjunto de strings distintas para velocidade)
u <- unique(meta$assuntos_leaf); u <- u[!is.na(u)]
fam <- tibble(assuntos_leaf = u)
for (nm in names(TPU_FAMILIES)) fam[[nm]] <- in_tpu_family(u, TPU_FAMILIES[[nm]], parent)
names(fam)[names(fam) == "dano_moral"] <- "dm_code"
meta <- meta |> left_join(fam, by = "assuntos_leaf") |>
  mutate(across(c(dm_code, negativacao, protesto_indevido, plano_saude, acidente_transito, consumidor_rf, civil_rc, adm_rc), ~ coalesce(.x, FALSE)),
         classe_civel = classe %in% c("REsp", "AREsp", "EREsp", "EAREsp"),
         n_codigos = if_else(is.na(assuntos_leaf), 0L, stri_count_fixed(assuntos_leaf, ";") + 1L))
dbWriteTable(con, DBI::Id(schema = "stg", table = "documents_meta"), meta, overwrite = TRUE)
dbDisconnect(con, shutdown = TRUE)

dir.create(file.path(root, "data/interim"), showWarnings = FALSE)
w <- function(x, n) write_csv(x, file.path(root, "data/interim", n))
c_year <- meta |> count(ano, tipo_documento) |> pivot_wider(names_from = tipo_documento, values_from = n, values_fill = 0); w(c_year, "census_year_type.csv")
c_class <- meta |> count(classe, sort = TRUE); w(c_class, "census_class.csv")
c_fmt <- meta |> group_by(ano) |> summarise(n = n(), caminho_pontuado = sum(assuntos_formato == "caminho_pontuado", na.rm = TRUE),
                                             media_codigos = round(mean(n_codigos), 2), pct_um_codigo = round(100 * mean(n_codigos == 1), 1)); w(c_fmt, "census_assuntos_formato.csv")
c_days <- meta |> count(key) |> mutate(ano = substr(key, 1, 4)); w(c_days, "census_days.csv")
dmc <- meta |> filter(dm_code, classe_civel)
topics <- c("negativacao", "plano_saude", "protesto_indevido", "acidente_transito", "consumidor_rf", "civil_rc", "adm_rc")
c_dm <- map_dfr(topics, ~ dmc |> filter(.data[[.x]]) |> count(ano) |> mutate(materia = .x, .before = 1)) |>
  pivot_wider(names_from = ano, values_from = n, values_fill = 0) |> mutate(total = rowSums(across(where(is.numeric)))); w(c_dm, "census_dm_topics.csv")
top_leaf <- dmc |> select(seq_documento, assuntos_leaf) |> separate_rows(assuntos_leaf, sep = ";") |> count(assuntos_leaf, sort = TRUE) |>
  mutate(codigo = as.integer(assuntos_leaf)) |> left_join(select(tpu, codigo, descricao), by = "codigo") |> select(codigo, descricao, n) |> head(30); w(top_leaf, "census_dm_top_leafs.csv")
md <- c("# 06 — Censo dos metadados completos", "",
        sprintf("Gerado em %s por `scripts/05_metadata_census.R` (%d documentos; matérias por FAMÍLIA TPU, i.e. código ou qualquer descendente — ver `R/tpu_codes.R`).", format(Sys.time(), "%Y-%m-%d"), nrow(meta)), "",
        "## Documentos por ano e tipo", "", knitr::kable(c_year), "",
        "## Registro do campo de assuntos por ano (deriva de esquema)", "", knitr::kable(c_fmt), "",
        "Leitura: em 2021 e 2026 o STJ publica o caminho completo dos assuntos; em 2022–2025 só códigos-folha (separador `;` até 2023 e `, ` em 2024–2025), com 1,7–1,8 códigos por documento em todos os anos. Como só as folhas aparecem em 2022–2025, contagens por código pai (7779, 10433) subestimam; as contagens abaixo usam a família TPU (pai + descendentes) e são comparáveis entre anos.", "",
        sprintf("## Documentos na família 'dano moral': %d (%.1f%%); em classes cíveis (REsp/AREsp/EREsp/EAREsp): %d", sum(meta$dm_code), 100 * mean(meta$dm_code), nrow(dmc)), "",
        "## Matérias (família TPU) entre docs de dano moral cíveis, por ano de publicação", "", knitr::kable(c_dm), "",
        "## Classes mais frequentes", "", knitr::kable(head(c_class, 15)), "",
        "## Códigos mais frequentes entre docs de dano moral cíveis", "", knitr::kable(top_leaf))
writeLines(md, file.path(root, "docs/06_metadata_census.md"))
cat("censo escrito em docs/06_metadata_census.md\n"); print(c_dm)
