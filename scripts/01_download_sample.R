# 01_download_sample.R — baixa SOMENTE os dias-amostra listados em config/sample_days.txt
# (textos ZIP + metadados JSON) a partir do inventário CKAN, verifica tamanho, registra SHA-256 em
# data/raw/stj_integras/sample/CHECKSUMS.sha256 e não sobrescreve arquivos existentes (dados brutos imutáveis).
# Rodar no Terminal: Rscript scripts/01_download_sample.R
suppressPackageStartupMessages({ library(dplyr); library(readr); library(purrr); library(digest); library(stringi) })
root <- Sys.getenv("STJMD_ROOT", unset = ".")
inv <- read_csv(file.path(root, "data/interim/ckan_inventory.csv"), show_col_types = FALSE) |>
  filter(dataset == "integras-de-decisoes-terminativas-e-acordaos-do-diario-da-justica", format %in% c("ZIP", "JSON"))
days <- readLines(file.path(root, "config/sample_days.txt")) |> stri_trim_both() |> (\(x) x[x != "" & !startsWith(x, "#")])()
out <- file.path(root, "data/raw/stj_integras/sample"); dir.create(out, showWarnings = FALSE, recursive = TRUE)

todo <- inv |> filter(key %in% days) |> arrange(key, format, desc(last_modified)) |> distinct(key, format, .keep_all = TRUE) |>
  mutate(file = if_else(format == "ZIP", sprintf("textos%s.zip", key), sprintf("metadados%s.json", key)),
         path = file.path(out, file))
log <- file.path(root, "logs/download_sample.log")
for (i in seq_len(nrow(todo))) {
  p <- todo$path[i]
  if (file.exists(p)) { cat(sprintf("[skip] %s já existe\n", todo$file[i])); next }
  ok <- tryCatch({ download.file(todo$url[i], p, mode = "wb", quiet = TRUE); TRUE }, error = function(e) FALSE)
  size <- if (ok) file.size(p) else NA
  msg <- sprintf("%s | %s | ok=%s | size=%s | expected=%s | sha256=%s", format(Sys.time()), todo$file[i], ok, size, todo$size[i],
                 if (ok) digest(p, algo = "sha256", file = TRUE) else NA)
  cat(msg, "\n"); cat(msg, "\n", file = log, append = TRUE)
  if (ok && !is.na(todo$size[i]) && size != todo$size[i]) warning("tamanho divergente: ", todo$file[i])
}
files <- list.files(out, "\\.(zip|json)$", full.names = TRUE)
writeLines(sprintf("%s  %s", map_chr(files, ~ digest(.x, algo = "sha256", file = TRUE)), basename(files)),
           file.path(out, "CHECKSUMS.sha256"))
cat("checksums gravados para", length(files), "arquivos\n")
