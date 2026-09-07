# 02_download_metadata_all.R — baixa TODOS os JSON de metadados diários/mensais do conjunto principal
# (sem os ZIP de textos), a partir do inventário CKAN. Idempotente e retomável: pula arquivos já baixados
# com tamanho correto; registra log e SHA-256. Rodar como Background Job (1–3 h).
suppressPackageStartupMessages({ library(dplyr); library(readr); library(digest); library(stringi) })
root <- Sys.getenv("STJMD_ROOT", unset = ".")
inv <- read_csv(file.path(root, "data/interim/ckan_inventory.csv"), show_col_types = FALSE) |>
  filter(dataset == "integras-de-decisoes-terminativas-e-acordaos-do-diario-da-justica", format == "JSON", !is.na(key)) |>
  arrange(key, desc(last_modified)) |> distinct(key, .keep_all = TRUE) |>
  mutate(file = sprintf("metadados%s.json", key))
out <- file.path(root, "data/raw/stj_integras/metadata"); dir.create(out, showWarnings = FALSE, recursive = TRUE)
log <- file.path(root, "logs/download_metadata.log")
options(timeout = 600)
n_ok <- 0; n_skip <- 0; n_fail <- 0
for (i in seq_len(nrow(inv))) {
  p <- file.path(out, inv$file[i])
  if (file.exists(p) && (is.na(inv$size[i]) || file.size(p) == inv$size[i])) { n_skip <- n_skip + 1; next }
  ok <- FALSE
  for (try in 1:3) {
    ok <- tryCatch({ download.file(inv$url[i], p, mode = "wb", quiet = TRUE); TRUE }, error = function(e) FALSE)
    if (ok && (is.na(inv$size[i]) || file.size(p) == inv$size[i])) break
    ok <- FALSE; Sys.sleep(5 * try)
  }
  sha <- if (ok) digest(p, algo = "sha256", file = TRUE) else NA
  cat(sprintf("%s | %s | ok=%s | size=%s | expected=%s | sha256=%s\n", format(Sys.time()), inv$file[i], ok,
              if (file.exists(p)) file.size(p) else NA, inv$size[i], sha), file = log, append = TRUE)
  if (ok) n_ok <- n_ok + 1 else n_fail <- n_fail + 1
  if (i %% 50 == 0) cat(sprintf("[%d/%d] ok=%d skip=%d fail=%d\n", i, nrow(inv), n_ok, n_skip, n_fail))
  Sys.sleep(0.3)
}
files <- list.files(out, "\\.json$", full.names = TRUE)
writeLines(sprintf("%s  %s", vapply(files, function(f) digest(f, algo = "sha256", file = TRUE), ""), basename(files)),
           file.path(out, "CHECKSUMS.sha256"))
cat(sprintf("FIM: ok=%d skip=%d fail=%d | arquivos em disco=%d | GB=%.2f\n", n_ok, n_skip, n_fail, length(files),
            sum(file.size(files)) / 1e9))
