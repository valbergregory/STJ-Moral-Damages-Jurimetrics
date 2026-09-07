# 06_download_texts_all.R — baixa os ZIP de textos do conjunto principal (≈11,2 GB, ≈1.280 arquivos).
# NÃO rodar antes da aprovação do protocolo (docs/02): a matéria principal aparece em praticamente todos os dias,
# logo o universo de textos é o conjunto inteiro. Idempotente e retomável (pula arquivos com tamanho correto);
# opcionalmente restrito a um intervalo de chaves via argumentos: Rscript scripts/06_download_texts_all.R 20210101 20211231
suppressPackageStartupMessages({ library(dplyr); library(readr); library(digest); library(stringi) })
root <- Sys.getenv("STJMD_ROOT", unset = ".")
args <- commandArgs(trailingOnly = TRUE)
inv <- read_csv(file.path(root, "data/interim/ckan_inventory.csv"), show_col_types = FALSE) |>
  filter(dataset == "integras-de-decisoes-terminativas-e-acordaos-do-diario-da-justica", format == "ZIP", !is.na(key)) |>
  arrange(key, desc(last_modified)) |> distinct(key, .keep_all = TRUE) |> mutate(file = sprintf("textos%s.zip", key))
if (length(args) == 2) inv <- filter(inv, key >= args[1], key <= args[2])
out <- file.path(root, "data/raw/stj_integras/texts"); dir.create(out, showWarnings = FALSE, recursive = TRUE)
log <- file.path(root, "logs/download_texts.log")
options(timeout = 1800)
n_ok <- 0; n_skip <- 0; n_fail <- 0
for (i in seq_len(nrow(inv))) {
  p <- file.path(out, inv$file[i])
  if (file.exists(p) && (is.na(inv$size[i]) || file.size(p) == inv$size[i])) { n_skip <- n_skip + 1; next }
  ok <- FALSE
  for (try in 1:4) {
    ok <- tryCatch({ download.file(inv$url[i], p, mode = "wb", quiet = TRUE); TRUE }, error = function(e) FALSE)
    if (ok && (is.na(inv$size[i]) || file.size(p) == inv$size[i])) break
    ok <- FALSE; Sys.sleep(10 * try)
  }
  cat(sprintf("%s | %s | ok=%s | size=%s | expected=%s | sha256=%s\n", format(Sys.time()), inv$file[i], ok,
              if (file.exists(p)) file.size(p) else NA, inv$size[i], if (ok) digest(p, algo = "sha256", file = TRUE) else NA),
      file = log, append = TRUE)
  if (ok) n_ok <- n_ok + 1 else n_fail <- n_fail + 1
  if (i %% 25 == 0) cat(sprintf("[%d/%d] ok=%d skip=%d fail=%d | %.1f GB\n", i, nrow(inv), n_ok, n_skip, n_fail,
                                sum(file.size(list.files(out, full.names = TRUE))) / 1e9))
  Sys.sleep(0.5)
}
files <- list.files(out, "\\.zip$", full.names = TRUE)
writeLines(sprintf("%s  %s", vapply(files, function(f) digest(f, algo = "sha256", file = TRUE), ""), basename(files)),
           file.path(out, "CHECKSUMS.sha256"))
cat(sprintf("FIM: ok=%d skip=%d fail=%d | arquivos=%d | GB=%.2f\n", n_ok, n_skip, n_fail, length(files), sum(file.size(files)) / 1e9))
