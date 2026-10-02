# 08_annotation_sample.R — Semana 3: sorteia, de forma estratificada e com semente fixa, a amostra de anotação manual
# (300 candidatos monetários + 150 documentos completos + subconjunto cego de re-anotação intra-anotador) a partir do
# banco gerado na Semana 2 (scripts/07_ingest_texts.R) e grava as planilhas em data/annotations/ (NÃO versionadas:
# contêm trechos e textos de decisões; ver .gitignore). Guia de preenchimento: docs/COMO_ANOTAR.md.
#
# Uso (RStudio → Background Job, working directory = raiz do projeto; ou Terminal):
#   Rscript scripts/08_annotation_sample.R                 # padrão: 300 + 150, re-anotação 45 + 25, semente 20261002
#   Rscript scripts/08_annotation_sample.R --force         # refaz o sorteio mesmo com planilhas-modelo existentes
#                                                          # (recusa se alguma célula true_* de um modelo já foi preenchida)
# Opções: --families=negativacao,plano_saude --n-amounts=300 --n-docs=150 --n-rare=30 --share-dm=0.6
#         --n-reanot-amounts=45 --n-reanot-docs=25 --seed=20261002
# Lê:    data/stjmd.duckdb (stg.selected_docs, stg.document_text, stg.money_candidates, stg.doc_outcomes, stg.doc_origin)
# Grava: data/annotations/w3_modelo_valores.csv, w3_modelo_documentos.csv,
#        w3_modelo_reanotacao_valores.csv, w3_modelo_reanotacao_documentos.csv   (planilhas cegas para o anotador)
#        data/annotations/w3_chave_valores.csv, w3_chave_documentos.csv,
#        w3_chave_reanotacao_valores.csv, w3_chave_reanotacao_documentos.csv     (predições, estratos e pesos — não abrir)
#        data/annotations/w3_textos/<seq_documento>.txt                          (texto integral dos documentos sorteados)
#        data/annotations/w3_amostra_estratos.csv + logs/annotation_sample.log    (só contagens)
suppressPackageStartupMessages({ library(dplyr); library(purrr); library(stringi); library(readr); library(tibble); library(DBI); library(duckdb) })
root <- Sys.getenv("STJMD_ROOT", unset = "."); args <- commandArgs(trailingOnly = TRUE)
source(file.path(root, "R/annotation_sampling.R"))
opt <- function(name, default) { v <- args[startsWith(args, paste0("--", name, "="))]; if (length(v)) sub("^--[^=]+=", "", v[1]) else default }
families <- stri_split_fixed(opt("families", "negativacao,plano_saude"), ",")[[1]]
stopifnot(all(families %in% c("negativacao", "plano_saude")))   # materia_label() conhece estas duas (aprovadas em 02/10)
n_amounts <- as.integer(opt("n-amounts", 300)); n_docs <- as.integer(opt("n-docs", 150)); n_rare <- as.integer(opt("n-rare", 30))
share_dm <- as.numeric(opt("share-dm", 0.6)); n_re_a <- as.integer(opt("n-reanot-amounts", 45)); n_re_d <- as.integer(opt("n-reanot-docs", 25))
seed <- as.integer(opt("seed", 20261002)); force <- "--force" %in% args
ann_dir <- file.path(root, "data/annotations")
dir.create(ann_dir, showWarnings = FALSE, recursive = TRUE); dir.create(file.path(root, "logs"), showWarnings = FALSE)
logf <- file.path(root, "logs/annotation_sample.log")
log <- function(...) { msg <- sprintf("[%s] %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), paste0(..., collapse = "")); cat(msg, "\n"); cat(msg, "\n", file = logf, append = TRUE) }

models <- file.path(ann_dir, W3_FILES[c("modelo_valores", "modelo_documentos", "modelo_reanotacao_valores", "modelo_reanotacao_documentos")])
if (any(file.exists(models)) && !force) stop("Planilhas da Semana 3 já existem em data/annotations/ (w3_modelo_*.csv). ",
  "Para refazer o sorteio use --force (a mesma semente gera a mesma amostra).")
done_files <- list.files(ann_dir, "^w3_(valores|documentos|reanotacao_valores|reanotacao_documentos)_[A-Za-z]+\\.csv$")
if (length(done_files)) stop("Já existem planilhas anotadas (", paste(done_files, collapse = ", "), "). Um novo sorteio trocaria as chaves ",
  "w3_chave_*.csv e desalinharia a anotação. Mova-as para fora de data/annotations/ se quiser mesmo sortear de novo.")
if (any(map_lgl(models, has_annotations))) stop("Uma planilha w3_modelo_*.csv já tem células true_* preenchidas: não sobrescrevo. ",
  "Renomeie-a para w3_valores_<INI>.csv / w3_documentos_<INI>.csv e continue anotando: não é preciso sortear de novo.")
log(sprintf("== 08_annotation_sample: famílias=%s | n_amounts=%d n_docs=%d (raros %d) share_dm=%.2f | reanot %d+%d | seed=%d",
            paste(families, collapse = "+"), n_amounts, n_docs, n_rare, share_dm, n_re_a, n_re_d, seed))

con <- dbConnect(duckdb(), file.path(root, "data/stjmd.duckdb"), read_only = TRUE)
# Sem on.exit() aqui: no nível superior de um script executado via source()/Background Job do RStudio, on.exit()
# dispara logo após a própria linha e fecha a conexão ("Invalid connection"). O dbDisconnect() explícito fica abaixo.
fam_where <- paste(sprintf("coalesce(s.%s, FALSE)", families), collapse = " OR ")
fam_cols <- paste(map_chr(c("negativacao", "plano_saude"), ~ if (.x %in% families) sprintf("coalesce(s.%s, FALSE) AS %s", .x, .x) else sprintf("FALSE AS %s", .x)), collapse = ", ")

# --- universo de documentos (com texto ingerido e extração feita) ------------------------------------------------
docs <- dbGetQuery(con, sprintf("SELECT s.seq_documento, s.ano, s.tipo_documento, s.classe, %s, o.outcome, o.sumula7,
    contains(t.text_norm, 'R$') AS has_brl
  FROM stg.selected_docs s JOIN stg.document_text t USING (seq_documento) JOIN stg.doc_outcomes o USING (seq_documento)
  WHERE %s", fam_cols, fam_where)) |> as_tibble() |>
  mutate(materia = materia_label(negativacao, plano_saude), has_brl = coalesce(has_brl, FALSE))
log(sprintf("universo de documentos: %d (com texto e desfecho predito)", nrow(docs)))

# --- universo de candidatos ---------------------------------------------------------------------------------------
cand <- dbGetQuery(con, sprintf("SELECT m.seq_documento, m.start_pos, m.end_pos, m.raw, m.value, m.unit, m.form, m.category, m.stage,
    m.direction, m.in_precedent_quote, m.reference_value, m.per_capita, m.ctx_before, m.ctx_after
  FROM stg.money_candidates m JOIN stg.selected_docs s USING (seq_documento) WHERE %s", fam_where)) |> as_tibble() |>
  inner_join(docs |> select(seq_documento, ano, materia, outcome), by = "seq_documento") |>
  mutate(doc_sem_dm = outcome == "sem_dano_moral")
log(sprintf("universo de candidatos: %d (dano_moral predito: %d)", nrow(cand), sum(cand$category == "dano_moral")))

# --- sorteio (funções puras em R/annotation_sampling.R, testadas com dados sintéticos) ---------------------------
dr <- draw_week3(cand, docs, n_amounts = n_amounts, n_docs = n_docs, n_rare = n_rare, share_dm = share_dm,
                 n_reanot_amounts = n_re_a, n_reanot_docs = n_re_d, seed = seed)
log(sprintf("sorteados: %d candidatos (%d estratos) + %d documentos (%d estratos); re-anotação: %d + %d",
            nrow(dr$sa), n_distinct(dr$sa$stratum), nrow(dr$sd), n_distinct(dr$sd$stratum), nrow(dr$ra), nrow(dr$rd)))

# --- textos integrais, valores de dano moral por estágio e origem dos documentos sorteados -----------------------
in_list <- function(ids) paste(sort(unique(ids)), collapse = ",")
texts <- dbGetQuery(con, sprintf("SELECT seq_documento, text_norm FROM stg.document_text WHERE seq_documento IN (%s)",
                                 in_list(c(dr$sa$seq_documento, dr$sd$seq_documento)))) |> as_tibble()
dm_vals <- dbGetQuery(con, sprintf("SELECT seq_documento, stage, value FROM stg.money_candidates
  WHERE category = 'dano_moral' AND unit = 'BRL' AND NOT in_precedent_quote AND NOT coalesce(reference_value, FALSE)
    AND seq_documento IN (%s)", in_list(dr$sd$seq_documento))) |> as_tibble()
orig <- dbGetQuery(con, sprintf("SELECT seq_documento, origem_uf FROM stg.doc_origin WHERE seq_documento IN (%s)", in_list(dr$sd$seq_documento))) |> as_tibble()
dbDisconnect(con, shutdown = TRUE)

# --- planilhas cegas, chaves, textos e resumo dos estratos --------------------------------------------------------
out <- finalize_week3(dr, texts, dm_vals, orig)
write_week3(out, texts, ann_dir)
log(sprintf("textos gravados em data/annotations/w3_textos/: %d arquivos", nrow(texts)))
log(sprintf("valores: por categoria predita %s", paste(sprintf("%s=%d", names(table(dr$sa$category)), table(dr$sa$category)), collapse = ", ")))
log(sprintf("documentos: por desfecho predito %s", paste(sprintf("%s=%d", names(table(dr$sd$outcome)), table(dr$sd$outcome)), collapse = ", ")))
log("planilhas gravadas em data/annotations/ (w3_modelo_*.csv; chaves w3_chave_*.csv; textos w3_textos/). Próximo: docs/COMO_ANOTAR.md")
