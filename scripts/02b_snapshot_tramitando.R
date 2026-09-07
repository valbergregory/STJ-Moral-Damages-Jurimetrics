# 02b_snapshot_tramitando.R — arquiva o snapshot diário do "Acervo em tramitação" do STJ.
# O CKAN mantém só o arquivo mais recente; este script guarda uma cópia datada (nome original) com SHA-256.
# Agendar diariamente (ver docs/RUNBOOK.md). Idempotente: não baixa de novo o mesmo arquivo.
suppressPackageStartupMessages({ library(httr2); library(jsonlite); library(digest) })
root <- Sys.getenv("STJMD_ROOT", unset = ".")
out <- file.path(root, "data/raw/stj_tramitando"); dir.create(out, showWarnings = FALSE, recursive = TRUE)
js <- request("https://dadosabertos.web.stj.jus.br/api/3/action/package_show") |> req_url_query(id = "acervo-em-tramitacao") |>
  req_user_agent("stjmd-research (R httr2)") |> req_retry(max_tries = 4) |> req_perform() |> resp_body_string()
res <- fromJSON(js)$result$resources
r <- res[res$format %in% c("GZ", "gz", "JSON") & grepl("tramitando", res$name), ][1, ]
dest <- file.path(out, r$name)
if (file.exists(dest) && (is.na(r$size) || file.size(dest) == as.numeric(r$size))) { cat("já existe:", r$name, "\n"); quit(save = "no") }
options(timeout = 900)
for (try in 1:3) {
  ok <- tryCatch({ download.file(r$url, dest, mode = "wb", quiet = TRUE); TRUE }, error = function(e) FALSE)
  if (ok && (is.na(r$size) || file.size(dest) == as.numeric(r$size))) break
  Sys.sleep(30 * try)
}
line <- sprintf("%s | %s | size=%s | expected=%s | sha256=%s | last_modified=%s", format(Sys.time()), r$name, file.size(dest), r$size,
                digest(dest, algo = "sha256", file = TRUE), r$last_modified)
cat(line, "\n"); cat(line, "\n", file = file.path(root, "logs/snapshot_tramitando.log"), append = TRUE)
