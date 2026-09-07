# 00_inventory_ckan.R — inventário reproduzível dos conjuntos do Portal de Dados Abertos do STJ (CKAN).
# Salva o JSON bruto de cada package_show em data/raw/ckan/ (com data de coleta) e um inventário tabular
# dos recursos do conjunto principal em data/interim/ckan_inventory.csv (chave AAAAMM/AAAAMMDD, formato,
# tamanho, URL, last_modified). Rodar no Terminal: Rscript scripts/00_inventory_ckan.R
suppressPackageStartupMessages({ library(httr2); library(jsonlite); library(dplyr); library(purrr); library(stringi); library(readr); library(tibble) })
root <- Sys.getenv("STJMD_ROOT", unset = ".")
BASE <- "https://dadosabertos.web.stj.jus.br/api/3/action/"
DATASETS <- c("integras-de-decisoes-terminativas-e-acordaos-do-diario-da-justica", "precedentes-qualificados",
              "acervo-em-tramitacao", "api-publica-datajud",
              paste0("espelhos-de-acordaos-", c("corte-especial", "primeira-secao", "segunda-secao", "terceira-secao",
                     "primeira-turma", "segunda-turma", "terceira-turma", "quarta-turma", "quinta-turma", "sexta-turma")))
out_raw <- file.path(root, "data/raw/ckan"); dir.create(out_raw, showWarnings = FALSE, recursive = TRUE)
stamp <- format(Sys.Date(), "%Y%m%d")

ckan_get <- function(action, ...) {
  request(paste0(BASE, action)) |> req_url_query(...) |> req_user_agent("stjmd-research (R httr2)") |>
    req_retry(max_tries = 4) |> req_perform() |> resp_body_string()
}

inventory <- map_dfr(DATASETS, function(id) {
  js <- ckan_get("package_show", id = id)
  writeLines(js, file.path(out_raw, sprintf("package_show_%s_%s.json", id, stamp)), useBytes = TRUE)
  d <- fromJSON(js)$result
  r <- as_tibble(d$resources)
  tibble(dataset = id, title = d$title, license = d$license_title, metadata_modified = d$metadata_modified,
         resource_name = r$name, format = r$format, size = as.numeric(r$size), url = r$url,
         last_modified = r$last_modified,
         key = stri_extract_first_regex(r$name, "\\d{8}|\\d{6}"))
})
write_csv(inventory, file.path(root, "data/interim/ckan_inventory.csv"))

main <- inventory |> filter(dataset == DATASETS[1], format %in% c("ZIP", "JSON")) |>
  mutate(kind = if_else(format == "ZIP", "textos", "metadados"))
summary_year <- main |> filter(!is.na(key)) |> distinct(key, kind, .keep_all = TRUE) |>
  mutate(year = substr(key, 1, 4)) |> group_by(year, kind) |> summarise(files = n(), gb = sum(size, na.rm = TRUE) / 1e9, .groups = "drop")
cat("Conjunto principal:", nrow(main), "recursos;", n_distinct(main$key), "chaves de data\n")
print(summary_year)
cat("chaves duplicadas (recurso reenviado):", sum(duplicated(main[, c("key", "kind")])), "\n")
cat("meses sem arquivo diário:", paste(setdiff(format(seq(as.Date("2021-01-01"), Sys.Date(), by = "month"), "%Y%m"),
                                             unique(substr(main$key[nchar(main$key) == 8], 1, 6))), collapse = ", "), "\n")
cat("chaves mensais (carga inicial):", paste(unique(main$key[nchar(main$key) == 6]), collapse = ", "), "\n")
