# _targets.R — pipeline reproduzível (targets). Esqueleto da Fase 0/1; alvos de estimação entram
# somente após a validação da extração (docs/07_extraction_validity.md) e da coerência jurídica da amostra.
# Rodar em Background Job (RStudio): targets::tar_make()
library(targets)
tar_option_set(packages = c("dplyr", "purrr", "stringi", "readr", "jsonlite", "tibble", "tidyr", "DBI", "duckdb"),
               format = "rds", seed = 20260905)
for (f in list.files("R", "\\.R$", full.names = TRUE)) source(f)

list(
  # --- Fase 0: fontes ---------------------------------------------------------------------------
  tar_target(sample_days_file, "config/sample_days.txt", format = "file"),
  tar_target(sample_days, readLines(sample_days_file) |> (\(x) x[x != "" & !startsWith(x, "#")])()),
  tar_target(ipca_file, fetch_ipca()$file, format = "file"),
  tar_target(ipca, readr::read_csv(ipca_file, show_col_types = FALSE, col_types = "cd")),

  # --- Fase 1: corpus-amostra ------------------------------------------------------------------
  tar_target(sample_zip_files, list.files("data/raw/stj_integras/sample", "^textos\\d{8}\\.zip$", full.names = TRUE), format = "file"),
  tar_target(sample_meta_files, list.files("data/raw/stj_integras/sample", "^metadados\\d{8}\\.json$", full.names = TRUE), format = "file"),
  tar_target(sample_corpus, { build_sample_corpus(); readRDS("data/interim/sample_dm_corpus.rds") }),

  # --- Fase 2: extração monetária (piloto) -------------------------------------------------------
  tar_target(money_candidates, purrr::map_dfr(seq_len(nrow(sample_corpus)),
                                              ~ extract_money(sample_corpus$text[.x], sample_corpus$seq_documento[.x]))),
  tar_target(doc_outcomes, purrr::map_dfr(sample_corpus$text, stj_quantum_outcome) |>
               dplyr::mutate(doc_id = sample_corpus$seq_documento, .before = 1)),
  tar_target(doc_origin, purrr::map_dfr(sample_corpus$text, extract_origin_court) |>
               dplyr::mutate(doc_id = sample_corpus$seq_documento, .before = 1))
  # --- Fase 3+ (após validação): award_events, deflação, descritivas, quantílica, hierárquico, preditivo, artigo
)
