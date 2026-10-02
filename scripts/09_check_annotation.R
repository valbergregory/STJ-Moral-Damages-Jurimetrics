# 09_check_annotation.R — confere as planilhas de anotação da Semana 3 antes das métricas (docs/COMO_ANOTAR.md §7-a).
# Verifica, linha a linha: códigos do vocabulário (R/annotation_vocab.R), valores legíveis, UF e as regras de coerência
# (Q9, Q13, Q15, critérios da docs/02). Mostra o progresso e lista os problemas por item_id — sem nenhum trecho de texto.
# Rode ao fim de cada sessão de anotação. Não altera as planilhas.
# Uso: Rscript scripts/09_check_annotation.R [--dir=data/annotations]
# Saída: console; no terminal termina com status 1 se houver "erro" (avisos não bloqueiam).
suppressPackageStartupMessages({ library(dplyr); library(readr); library(purrr); library(stringi); library(tibble) })
root <- Sys.getenv("STJMD_ROOT", unset = "."); args <- commandArgs(trailingOnly = TRUE)
source(file.path(root, "R/validity_metrics.R")); source(file.path(root, "R/annotation_vocab.R"))
opt <- function(name, default) { v <- args[startsWith(args, paste0("--", name, "="))]; if (length(v)) sub("^--[^=]+=", "", v[1]) else default }
ann_dir <- opt("dir", file.path(root, "data/annotations")); options(width = 200)

files <- list.files(ann_dir, "^w3_(reanotacao_)?(valores|documentos)_[A-Za-z]+(_IA)?\\.csv$", full.names = TRUE)
if (!length(files)) stop("Nenhuma planilha w3_valores_<INI>.csv / w3_documentos_<INI>.csv em ", ann_dir, ". Veja docs/COMO_ANOTAR.md.")
n_err <- 0L
for (f in files) {
  kind <- if (stri_detect_fixed(basename(f), "valores")) "valores" else "documentos"
  d <- read_annotation_csv(f); pr <- annotation_progress(d, kind); p <- check_annotation(d, kind)
  cat(sprintf("\n== %s (%s): %d de %d linhas com anotação; %d erro(s), %d aviso(s)\n", basename(f), kind, pr[["anotados"]], pr[["total"]],
              sum(p$gravidade == "erro"), sum(p$gravidade == "aviso")))
  if (nrow(p)) print(as.data.frame(p |> arrange(desc(gravidade == "erro"), item_id)), row.names = FALSE, right = FALSE)
  n_err <- n_err + sum(p$gravidade == "erro")
}
cat(if (n_err) sprintf("\n%d erro(s): corrija antes de rodar scripts/04_validity_metrics.R.\n", n_err) else "\nSem erros.\n")
if (!interactive()) quit(status = as.integer(n_err > 0))
