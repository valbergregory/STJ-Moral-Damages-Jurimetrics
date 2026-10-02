# 04_validity_metrics.R — validade do extrator contra a anotação manual do pesquisador (gate da Semana 3).
#
# Entradas (data/annotations/, não versionadas; <INI> = iniciais do anotador, só letras, ex.: VG):
#   Semana 3 (scripts/08_annotation_sample.R + docs/COMO_ANOTAR.md):
#     w3_valores_<INI>.csv                 = w3_modelo_valores.csv preenchido      (+ chave w3_chave_valores.csv)
#     w3_documentos_<INI>.csv              = w3_modelo_documentos.csv preenchido   (+ chave w3_chave_documentos.csv)
#     w3_reanotacao_valores_<INI>.csv      = re-anotação cega (+ w3_chave_reanotacao_valores.csv)  → kappa intra-anotador
#     w3_reanotacao_documentos_<INI>.csv   = re-anotação cega (+ w3_chave_reanotacao_documentos.csv)
#   Piloto (legado, opcional): pilot_annotation_<INI>.csv (template do scripts/03 com pred_* e true_* na mesma planilha).
#   Linhas sem rótulo verdadeiro são ignoradas campo a campo: dá para rodar com a anotação parcial.
# Saídas: docs/07_extraction_validity.md (só métricas agregadas, sem trechos) e outputs/overleaf/tables/extraction_validity.tex
# Uso: Rscript scripts/04_validity_metrics.R [--dir=data/annotations] [--boot=1000] [--seed=20261002] [--tol=0.5]
suppressPackageStartupMessages({ library(dplyr); library(readr); library(purrr); library(tidyr); library(stringi); library(tibble) })
root <- Sys.getenv("STJMD_ROOT", unset = "."); args <- commandArgs(trailingOnly = TRUE)
source(file.path(root, "R/validity_metrics.R"))
opt <- function(name, default) { v <- args[startsWith(args, paste0("--", name, "="))]; if (length(v)) sub("^--[^=]+=", "", v[1]) else default }
ann_dir <- opt("dir", file.path(root, "data/annotations")); B <- as.integer(opt("boot", 1000)); seed <- as.integer(opt("seed", 20261002))
tol <- as.numeric(opt("tol", 0.5))
GATES <- c(category = 0.90, stage = 0.85, in_precedent = 0.90)   # docs/04 (semana 3) e docs/05

find_files <- function(pattern) { f <- list.files(ann_dir, pattern, full.names = TRUE); setNames(f, stri_match_first_regex(basename(f), pattern)[, 2]) }
f_val <- find_files("^w3_valores_([A-Za-z]+)\\.csv$"); f_doc <- find_files("^w3_documentos_([A-Za-z]+)\\.csv$")
f_rval <- find_files("^w3_reanotacao_valores_([A-Za-z]+)\\.csv$"); f_rdoc <- find_files("^w3_reanotacao_documentos_([A-Za-z]+)\\.csv$")
f_pilot <- find_files("^pilot_annotation_([A-Za-z]+)\\.csv$")
if (!length(c(f_val, f_doc, f_pilot))) stop("Nenhuma anotação encontrada em ", ann_dir, " (w3_valores_<INI>.csv, w3_documentos_<INI>.csv ou ",
                                             "pilot_annotation_<INI>.csv). Veja docs/COMO_ANOTAR.md.")
key <- function(nm) { p <- file.path(ann_dir, nm); if (!file.exists(p)) stop("Chave ausente: ", p, " (gerada por scripts/08_annotation_sample.R)"); read_annotation_csv(p) }

out <- c("# 07 — Validade da extração (anotação manual do pesquisador)", "",
  sprintf("Gerado por `scripts/04_validity_metrics.R` em %s (bootstrap B = %d, semente %d; tolerância de valor R$ %.2f). Só métricas agregadas; nenhum trecho de decisão.",
          format(Sys.time(), "%Y-%m-%d"), B, seed, tol),
  "Convenções: P/R/F1 um-contra-todos por classe; **macro** = média simples das classes (classe com P ou R indefinida entra com 0, como no scikit-learn); `F1 pond.` usa os pesos de desenho w = N_h/n_h da amostra estratificada (estima o F1 no universo); IC 95 % por bootstrap percentil sobre os itens.", "")
gate_rows <- list(); tex_rows <- c()

field_section <- function(pred, truth, title, w = NULL, focus = NULL) {
  r <- prf_table(pred, truth); ci <- bootstrap_ci(pred, truth, macro_f1, B = B, seed = seed)
  mw <- if (!is.null(w)) macro_f1(pred, truth, w) else NA_real_
  m <- r$table |> filter(class == "macro")
  lines <- c(sprintf("### %s — n = %d · acurácia %s · macro-F1 %s (IC 95%% %s–%s)%s", title, r$n, fmt3(r$accuracy), fmt3(m$f1), fmt3(ci[["lo"]]), fmt3(ci[["hi"]]),
                     if (!is.na(mw)) sprintf(" · macro-F1 pond. %s", fmt3(mw)) else ""), "", md_table(r$table), "")
  list(lines = lines, n = r$n, acc = r$accuracy, macro = m, ci = ci, focus_f1 = if (!is.null(focus)) class_f1(pred, truth, focus) else NA_real_)
}

# --- A. candidatos monetários (Semana 3) ------------------------------------------------------------------------
if (length(f_val)) {
  kv <- key("w3_chave_valores.csv")
  for (ini in names(f_val)) {
    a <- read_annotation_csv(f_val[[ini]]) |> select(item_id, starts_with("true_")) |> inner_join(kv, by = "item_id")
    a <- a |> mutate(w = as.numeric(w), true_category = norm_label(true_category), true_stage = norm_label(true_stage),
                     true_direction = norm_label(true_direction), pred_category = norm_label(pred_category), pred_stage = norm_label(pred_stage),
                     pred_direction = norm_label(pred_direction),
                     pred_in_precedent = as.character(parse_bool_pt(pred_in_precedent)), true_in_precedent = as.character(parse_bool_pt(true_in_precedent)),
                     pred_reference_value = as.character(parse_bool_pt(pred_reference_value)), true_reference_value = as.character(parse_bool_pt(true_reference_value)))
    n_done <- sum(!is.na(a$true_category))
    out <- c(out, sprintf("## A. Candidatos monetários — anotador %s (%d de %d itens com categoria anotada)", ini, n_done, nrow(a)), "")
    vc <- parse_bool_pt(a$true_valor_correto)
    out <- c(out, sprintf("- Leitura do número (`true_valor_correto`): %d de %d corretos (%s).", sum(vc, na.rm = TRUE), sum(!is.na(vc)),
                          fmt3(if (any(!is.na(vc))) mean(vc, na.rm = TRUE) else NA)), "")
    s_cat <- field_section(a$pred_category, a$true_category, "Categoria", a$w, focus = "dano_moral")
    s_stg <- field_section(a$pred_stage, a$true_stage, "Estágio (todos os candidatos)", a$w)
    dm <- a |> filter(true_category == "dano_moral")
    s_stg_dm <- field_section(dm$pred_stage, dm$true_stage, "Estágio (só candidatos verdadeiramente de dano moral)", dm$w)
    s_dir <- field_section(a$pred_direction, a$true_direction, "Direção", a$w)
    s_prec <- field_section(a$pred_in_precedent, a$true_in_precedent, "Dentro de precedente citado (in_precedent)", a$w)
    s_ref <- field_section(a$pred_reference_value, a$true_reference_value, "Valor de referência (reference_value)", a$w)
    out <- c(out, sprintf("F1 da classe `dano_moral` na categoria: %s.", fmt3(s_cat$focus_f1)), "",
             s_cat$lines, s_stg$lines, s_stg_dm$lines, s_dir$lines, s_prec$lines, s_ref$lines)
    gate_rows[[length(gate_rows) + 1]] <- tibble(anotador = ini, campo = c("categoria (macro-F1)", "categoria (F1 classe dano_moral)", "estágio (macro-F1)", "estágio, só dano_moral verdadeiro (macro-F1)", "in_precedent (macro-F1)"),
      n = c(s_cat$n, s_cat$n, s_stg$n, s_stg_dm$n, s_prec$n), f1 = c(s_cat$macro$f1, s_cat$focus_f1, s_stg$macro$f1, s_stg_dm$macro$f1, s_prec$macro$f1),
      ic95 = c(sprintf("%s–%s", fmt3(s_cat$ci[["lo"]]), fmt3(s_cat$ci[["hi"]])), "—", sprintf("%s–%s", fmt3(s_stg$ci[["lo"]]), fmt3(s_stg$ci[["hi"]])),
               sprintf("%s–%s", fmt3(s_stg_dm$ci[["lo"]]), fmt3(s_stg_dm$ci[["hi"]])), sprintf("%s–%s", fmt3(s_prec$ci[["lo"]]), fmt3(s_prec$ci[["hi"]]))),
      meta = c(GATES[["category"]], GATES[["category"]], GATES[["stage"]], GATES[["stage"]], GATES[["in_precedent"]]))
    for (s in list(list("Category", s_cat), list("Stage", s_stg), list("Direction", s_dir), list("In precedent", s_prec)))
      tex_rows <- c(tex_rows, sprintf("%s & %d & %.3f & %.3f & %.3f & %.3f \\\\", s[[1]], s[[2]]$n, s[[2]]$acc, s[[2]]$macro$precision, s[[2]]$macro$recall, s[[2]]$macro$f1))
  }
}

# --- B. documentos completos (Semana 3) -------------------------------------------------------------------------
if (length(f_doc)) {
  kd <- key("w3_chave_documentos.csv")
  for (ini in names(f_doc)) {
    d <- read_annotation_csv(f_doc[[ini]]) |> select(item_id, starts_with("true_")) |> inner_join(kd |> select(-any_of("seq_documento")), by = "item_id") |>
      mutate(w = as.numeric(w), true_resultado_stj = norm_label(true_resultado_stj), pred_outcome = norm_label(pred_outcome),
             true_materia = norm_label(true_materia), materia = norm_label(materia),
             true_menciona = as.character(parse_bool_pt(true_menciona_dano_moral)), pred_menciona = as.character(pred_outcome != "sem_dano_moral"),
             true_origem_uf = toupper(norm_label(true_origem_uf)), pred_origem_uf = toupper(norm_label(pred_origem_uf)))
    n_done <- sum(!is.na(d$true_resultado_stj) | !is.na(d$true_menciona))
    out <- c(out, sprintf("## B. Documentos completos — anotador %s (%d de %d documentos com anotação)", ini, n_done, nrow(d)), "",
             "Valores preditos por estágio = candidatos `dano_moral` em R$, fora de precedente e de valor de referência. Desfecho predito `provido_verificar`/`indeterminado` nunca coincide com um código humano e conta como erro.", "")
    s_out <- field_section(d$pred_outcome, d$true_resultado_stj, "Resultado no STJ quanto ao quantum", d$w)
    s_men <- field_section(d$pred_menciona, d$true_menciona, "Menciona dano moral (valida o sinalizador `sem_dano_moral` de 12/09)", d$w)
    s_mat <- field_section(d$materia, d$true_materia, "Matéria (família TPU × leitura do texto)", d$w)
    uf_known <- d |> filter(!is.na(true_origem_uf), true_origem_uf != "NAO_CONSTA")
    uf_cov <- mean(!is.na(uf_known$pred_origem_uf)); uf_acc <- mean(uf_known$pred_origem_uf == uf_known$true_origem_uf, na.rm = TRUE)
    out <- c(out, s_out$lines, s_men$lines, s_mat$lines,
             sprintf("### Tribunal/UF de origem — %d documentos com origem identificável pelo anotador; cobertura do extrator %s; acerto quando extraído %s", nrow(uf_known), fmt3(uf_cov), fmt3(uf_acc)), "")
    stg <- c(pedido = "valor_pedido", origem_sentenca = "valor_sentenca", origem_acordao = "valor_acordao_origem", stj = "valor_stj")
    vt <- map_dfr(names(stg), function(st) {
      ann <- d |> filter(!is.na(true_resultado_stj) | !is.na(true_menciona))
      m <- match_value_sets(parse_value_set(ann[[paste0("pred_", stg[[st]])]]), parse_value_set(ann[[paste0("true_", stg[[st]])]]), tol = tol)
      bind_cols(tibble(estagio = st, n = nrow(m)), prf_counts(sum(m$tp), sum(m$fp), sum(m$fn)), tibble(conjunto_exato = mean(m$exato)))
    })
    out <- c(out, "### Valor de dano moral por estágio (nível do documento)", "",
             "TP = algum valor anotado está entre os valores extraídos para o estágio; FP = valor extraído sem correspondente; FN = valor anotado não extraído; `conjunto_exato` = proporção de documentos em que os conjuntos coincidem (inclui ambos vazios).", "",
             md_table(vt), "")
    gate_rows[[length(gate_rows) + 1]] <- tibble(anotador = ini, campo = c("resultado STJ (macro-F1)", "menciona dano moral (macro-F1)"),
      n = c(s_out$n, s_men$n), f1 = c(s_out$macro$f1, s_men$macro$f1),
      ic95 = c(sprintf("%s–%s", fmt3(s_out$ci[["lo"]]), fmt3(s_out$ci[["hi"]])), sprintf("%s–%s", fmt3(s_men$ci[["lo"]]), fmt3(s_men$ci[["hi"]]))), meta = NA_real_)
  }
}

# --- C. re-anotação cega (concordância intra-anotador) --------------------------------------------------------------
kappa_block <- function(first, second, fields, title) {
  k <- map_dfr(names(fields), function(f) bind_cols(tibble(campo = f), cohen_kappa(fields[[f]](first), fields[[f]](second))))
  c(sprintf("### %s", title), "", md_table(k |> mutate(n = as.integer(n))), "")
}
if (length(f_rval) || length(f_rdoc)) out <- c(out, "## C. Re-anotação cega (mesmo anotador) — kappa de Cohen", "",
  "Itens re-sorteados com novos identificadores e nova ordem; `po` = concordância observada, `pe` = esperada ao acaso. Escala de Landis & Koch (1977): 0,61–0,80 substancial; > 0,80 quase perfeita.", "")
for (ini in intersect(names(f_rval), names(f_val))) {
  kr <- key("w3_chave_reanotacao_valores.csv")
  r2 <- read_annotation_csv(f_rval[[ini]]) |> select(item_id_reanot, starts_with("true_")) |> inner_join(kr, by = "item_id_reanot")
  r1 <- read_annotation_csv(f_val[[ini]]) |> select(item_id, starts_with("true_"))
  j <- inner_join(r1, r2 |> select(-item_id_reanot), by = "item_id", suffix = c("", ".b"))
  lab <- function(col) function(x) norm_label(x[[col]]); bol <- function(col) function(x) as.character(parse_bool_pt(x[[col]]))
  b <- j |> select(item_id, ends_with(".b")) |> rename_with(~ sub("\\.b$", "", .x))
  out <- c(out, kappa_block(j, b, list(categoria = lab("true_category"), estagio = lab("true_stage"), direcao = lab("true_direction"),
                                       in_precedent = bol("true_in_precedent"), reference_value = bol("true_reference_value"),
                                       valor_correto = bol("true_valor_correto")),
                            sprintf("Candidatos monetários — anotador %s (%d itens)", ini, nrow(j))))
}
for (ini in intersect(names(f_rdoc), names(f_doc))) {
  kr <- key("w3_chave_reanotacao_documentos.csv")
  r2 <- read_annotation_csv(f_rdoc[[ini]]) |> select(item_id_reanot, starts_with("true_")) |> inner_join(kr, by = "item_id_reanot")
  r1 <- read_annotation_csv(f_doc[[ini]]) |> select(item_id, starts_with("true_"))
  j <- inner_join(r1, r2 |> select(-item_id_reanot), by = "item_id", suffix = c("", ".b"))
  b <- j |> select(item_id, ends_with(".b")) |> rename_with(~ sub("\\.b$", "", .x))
  lab <- function(col) function(x) norm_label(x[[col]]); bol <- function(col) function(x) as.character(parse_bool_pt(x[[col]]))
  val <- function(col) function(x) map_chr(parse_value_set(x[[col]]), ~ if (length(.x)) paste(.x, collapse = ";") else "(vazio)")
  out <- c(out, kappa_block(j, b, list(resultado_stj = lab("true_resultado_stj"), menciona_dano_moral = bol("true_menciona_dano_moral"),
                                       materia = lab("true_materia"), incluir = bol("true_incluir"), valor_sentenca = val("true_valor_sentenca"),
                                       valor_acordao_origem = val("true_valor_acordao_origem"), valor_stj = val("true_valor_stj")),
                            sprintf("Documentos — anotador %s (%d documentos)", ini, nrow(j))))
}

# --- D. piloto (legado: template do scripts/03 com pred_* na própria planilha) -------------------------------------
for (ini in names(f_pilot)) {
  a <- read_annotation_csv(f_pilot[[ini]]) |>
    mutate(across(c(pred_category, true_category, pred_stage, true_stage, pred_direction, true_direction), norm_label),
           pred_in_precedent = as.character(parse_bool_pt(pred_in_precedent)), true_in_precedent = as.character(parse_bool_pt(true_in_precedent)))
  out <- c(out, sprintf("## D. Piloto de 05/09 (legado) — anotador %s (%d candidatos anotados)", ini, sum(!is.na(a$true_category))), "",
           field_section(a$pred_category, a$true_category, "Categoria")$lines, field_section(a$pred_stage, a$true_stage, "Estágio")$lines,
           field_section(a$pred_direction, a$true_direction, "Direção")$lines, field_section(a$pred_in_precedent, a$true_in_precedent, "Dentro de precedente")$lines)
}

# --- gate ----------------------------------------------------------------------------------------------------------
if (length(gate_rows)) {
  g <- bind_rows(gate_rows) |> mutate(situacao = case_when(is.na(meta) ~ "informativo", is.na(f1) ~ "sem dados",
                                                           f1 >= meta ~ "atingido", TRUE ~ "NÃO atingido"))
  out <- append(out, c("## Gate da Semana 3 (resumo)", "",
    "Metas de docs/04 e docs/05: F1 ≥ 0,90 em categoria, ≥ 0,85 em estágio, ≥ 0,90 em in_precedent. Qual leitura do F1 vale para o gate (macro sobre todas as classes ou só a classe `dano_moral`/estágio dos candidatos de dano moral) é **decisão do pesquisador** — as duas são mostradas.", "",
    md_table(g |> mutate(n = as.integer(n))), "", "Nada da semana 5 em diante começa antes de o pesquisador declarar o gate atendido (docs/04).", ""), after = 5)
}
dir.create(file.path(root, "docs"), showWarnings = FALSE)
writeLines(out, file.path(root, "docs/07_extraction_validity.md"))
if (length(tex_rows)) {
  dir.create(file.path(root, "outputs/overleaf/tables"), showWarnings = FALSE, recursive = TRUE)
  writeLines(c("\\begin{table}[htbp]\\centering", "\\caption{Validity of the monetary extractor against manual annotation (macro-averaged)}", "\\label{tab:extraction_validity}",
               "\\begin{tabular}{lrrrrr}\\toprule", "Field & $n$ & Accuracy & Precision & Recall & F1 \\\\ \\midrule", tex_rows, "\\bottomrule\\end{tabular}\\end{table}"),
             file.path(root, "outputs/overleaf/tables/extraction_validity.tex"))
}
cat("escrito docs/07_extraction_validity.md", if (length(tex_rows)) "e outputs/overleaf/tables/extraction_validity.tex", "\n")
