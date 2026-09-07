# fetch_ipca.R — baixa o IPCA (número-índice, base dez/1993 = 100) da tabela 1737 do SIDRA/IBGE,
# variável 2266. Salva CSV bruto imutável + metadados (URL, data de coleta, SHA-256) em data/raw/ipca/.
suppressPackageStartupMessages({ library(sidrar); library(dplyr); library(readr); library(digest); library(jsonlite) })

fetch_ipca <- function(out_dir = "data/raw/ipca") {
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  api <- "/t/1737/n1/all/v/2266/p/all/d/v2266%2013"
  x <- sidrar::get_sidra(api = api)
  ipca <- x |>
    transmute(ref_month = as.character(.data[["Mês (Código)"]]), ipca_index = as.numeric(.data[["Valor"]])) |>
    filter(!is.na(ipca_index)) |> arrange(ref_month)
  stamp <- format(Sys.time(), "%Y%m%d")
  f <- file.path(out_dir, sprintf("ipca_1737_v2266_%s.csv", stamp))
  write_csv(ipca, f)
  meta <- list(source = "IBGE/SIDRA tabela 1737, variável 2266 (IPCA número-índice, dez/1993 = 100)",
               api = paste0("https://apisidra.ibge.gov.br/values", api), fetched_at = as.character(Sys.time()),
               n_rows = nrow(ipca), first = ipca$ref_month[1], last = ipca$ref_month[nrow(ipca)],
               sha256 = digest::digest(f, algo = "sha256", file = TRUE))
  write_json(meta, sub("[.]csv$", ".meta.json", f), auto_unbox = TRUE, pretty = TRUE)
  invisible(list(data = ipca, meta = meta, file = f))
}

# deflaciona valores nominais para a moeda de `base_month` (formato "YYYYMM")
deflate_brl <- function(value, ref_month, ipca, base_month) {
  idx <- setNames(ipca$ipca_index, ipca$ref_month)
  value * idx[[base_month]] / idx[ref_month]
}

if (sys.nframe() == 0) { r <- fetch_ipca(); str(r$meta) }
