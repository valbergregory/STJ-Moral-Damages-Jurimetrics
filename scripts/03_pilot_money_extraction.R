# 03_pilot_money_extraction.R — piloto: extrai e classifica valores monetários nos documentos de danos
# morais da amostra (>= 100 docs), mede cobertura de tribunal de origem, classifica o desfecho do STJ
# quanto ao quantum e gera (i) tabela de matérias candidatas e (ii) template de anotação manual.
# Rodar como Background Job (RStudio) ou: Rscript scripts/03_pilot_money_extraction.R
suppressPackageStartupMessages({
  library(dplyr); library(purrr); library(stringi); library(readr); library(tibble); library(tidyr); library(DBI); library(duckdb)
})
root <- Sys.getenv("STJMD_ROOT", unset = ".")
source(file.path(root, "R", "extract_money.R")); source(file.path(root, "R", "extract_origin.R"))
set.seed(20260905)
dm <- readRDS(file.path(root, "data/interim/sample_dm_corpus.rds"))
log <- file(file.path(root, "logs/pilot_summary.txt"), open = "wt"); sink(log, split = TRUE)
cat("== Piloto de extração monetária ==", format(Sys.time()), "\n")
cat("documentos de danos morais na amostra:", nrow(dm), " | com R$:", sum(dm$has_brl), "\n")

t0 <- Sys.time()
amounts <- map_dfr(seq_len(nrow(dm)), function(i) extract_money(dm$text[i], dm$seq_documento[i]))
cat(sprintf("extração: %d candidatos em %d docs (%.1f s)\n", nrow(amounts), n_distinct(amounts$doc_id), as.numeric(difftime(Sys.time(), t0, units = "secs"))))
outcomes <- map_dfr(dm$text, stj_quantum_outcome) |> mutate(doc_id = dm$seq_documento, .before = 1)
origin <- map_dfr(dm$text, extract_origin_court) |> mutate(doc_id = dm$seq_documento, .before = 1)

cat("\n-- candidatos por forma --\n"); print(count(amounts, form, unit))
cat("\n-- candidatos por categoria (todos) --\n"); print(count(amounts, category, sort = TRUE))
cat("\n-- candidatos por categoria, fora de citação de precedente --\n"); print(count(filter(amounts, !in_precedent_quote), category, sort = TRUE))
cat("\n-- dano_moral: estágio x direção (fora de precedente) --\n")
print(amounts |> filter(category == "dano_moral", !in_precedent_quote) |> count(stage, direction) |> pivot_wider(names_from = direction, values_from = n, values_fill = 0))
cat("\n-- sinalizadores --\n")
print(amounts |> summarise(n = n(), extenso_par = sum(extenso_parenthetical), mismatch = sum(extenso_mismatch, na.rm = TRUE),
                           in_precedent = sum(in_precedent_quote), in_origin_ementa = sum(in_origin_ementa), per_capita = sum(per_capita)))
cat("\n-- desfecho do STJ quanto ao quantum (doc) --\n"); print(count(outcomes, outcome, sumula7, sort = TRUE))
cat("\n-- cobertura de tribunal de origem (doc) --\n"); print(count(origin, origem_fonte, origem_tipo)); print(count(origin, origem_uf, sort = TRUE) |> head(15))

# doc-level: valor de dano moral por estágio (candidatos fora de precedente), com ambiguidade
doc_dm <- amounts |> filter(category %in% c("dano_moral", "moral_material_conjunto"), !in_precedent_quote, unit == "BRL") |>
  group_by(doc_id, stage) |> summarise(n_vals = n_distinct(value), value_min = min(value), value_max = max(value), .groups = "drop") |>
  mutate(ambiguous = n_vals > 1)
cat("\n-- docs com >=1 valor de dano moral (fora de precedente):", n_distinct(doc_dm$doc_id), "de", nrow(dm), "\n")
print(doc_dm |> group_by(stage) |> summarise(docs = n(), ambiguos = sum(ambiguous), mediana_min = median(value_min), p90 = quantile(value_max, .9)))

# tabela de matérias candidatas (regex por texto + código CNJ), por doc de danos morais e por doc com valor de dano moral
topics <- c(
  negativacao = "inscri[çc][ãa]o\\s+indevida|cadastro[s]?\\s+(?:de\\s+)?(?:inadimplentes|restritiv|prote[çc][ãa]o\\s+ao\\s+cr[ée]dito)|\\bSPC\\b|SERASA|negativa[çc][ãa]o",
  fraude_bancaria = "fraude[s]?\\s+(?:banc[áa]ria|eletr[ôo]nica)|\\bgolpe\\b|transa[çc][õo]es?\\s+(?:n[ãa]o\\s+reconhecida|fraudulenta)|empr[ée]stimo\\s+(?:fraudulento|n[ãa]o\\s+contratado)",
  consignado_desconto_indevido = "consignad|desconto[s]?\\s+indevido",
  aereo = "transporte\\s+a[ée]reo|companhia\\s+a[ée]rea|\\bvoo[s]?\\b|overbooking|extravio\\s+de\\s+bagagem",
  telecom = "telefonia|telecomunica[çc]|operadora\\s+de\\s+telefon|linha\\s+telef",
  erro_medico = "erro\\s+m[ée]dico|responsabilidade\\s+(?:civil\\s+)?(?:do\\s+)?(?:m[ée]dic|hospital)|cirurgi|procedimento\\s+m[ée]dico",
  plano_saude = "plano\\s+de\\s+sa[úu]de|operadora\\s+de\\s+(?:plano\\s+de\\s+)?sa[úu]de|negativa\\s+de\\s+cobertura",
  morte_lesao = "\\b(?:morte|[óo]bito|falecimento)\\b|les[ãa]o\\s+corporal|acidente\\s+de\\s+tr[âa]nsito|invalidez",
  energia_agua_saneamento = "energia\\s+el[ée]trica|fornecimento\\s+de\\s+(?:energia|[áa]gua)|saneamento|esgoto",
  imobiliario = "atraso\\s+na\\s+entrega|incorporadora|construtora|promessa\\s+de\\s+compra",
  ambiental_coletivo = "dano\\s+ambiental|desastre|rompimento\\s+d[ae]\\s+barragem|dano\\s+moral\\s+coletivo",
  honra_imagem_imprensa = "liberdade\\s+de\\s+(?:express[ãa]o|imprensa)|of[eê]nsa\\s+[àa]\\s+honra|cal[úu]nia|difama[çc]|inj[úu]ria|uso\\s+(?:indevido\\s+)?d[ae]\\s+imagem",
  protesto_indevido = "protesto\\s+indevido",
  servidor_estado = "responsabilidade\\s+civil\\s+do\\s+estado|ente\\s+p[úu]blico|fazenda\\s+p[úu]blica|servidor",
  penal_contexto = "\\bhabeas\\s+corpus\\b|\\bcrime\\b|den[úu]ncia|\\br[ée]u\\b"
)
dm_val_docs <- unique(doc_dm$doc_id)
screen <- map_dfr(names(topics), function(k) {
  hit <- stri_detect_regex(dm$text, topics[[k]], case_insensitive = TRUE)
  tibble(materia = k, docs_dano_moral = sum(hit), docs_com_valor_dm = sum(hit & dm$seq_documento %in% dm_val_docs),
         share_docs = round(mean(hit), 3))
}) |> arrange(desc(docs_dano_moral))
cat("\n-- matérias candidatas (amostra de", nrow(dm), "docs de danos morais) --\n"); print(screen, n = 30)
# códigos CNJ folha mais frequentes entre docs de danos morais
leafs <- dm |> filter(!is.na(assuntos_leaf)) |> separate_rows(assuntos_leaf, sep = ";") |> count(assuntos_leaf, sort = TRUE) |> head(25)
cat("\n-- códigos CNJ (folha) mais frequentes --\n"); print(leafs, n = 25)

# saídas
write_csv(amounts, file.path(root, "data/interim/pilot_amounts.csv"))
write_csv(outcomes, file.path(root, "data/interim/pilot_doc_outcomes.csv"))
write_csv(origin, file.path(root, "data/interim/pilot_doc_origin.csv"))
write_csv(screen, file.path(root, "data/interim/topic_screen.csv"))
# template de anotação manual: amostra estratificada por categoria predita (até 15 por categoria) + 60 aleatórios
ann <- bind_rows(
  amounts |> group_by(category) |> slice_sample(n = 15) |> ungroup(),
  amounts |> slice_sample(n = 60)) |> distinct(doc_id, start, .keep_all = TRUE) |>
  transmute(doc_id, start, raw, value, unit, pred_category = category, pred_stage = stage, pred_direction = direction,
            pred_in_precedent = in_precedent_quote, ctx_before, ctx_after,
            true_category = "", true_stage = "", true_direction = "", true_in_precedent = "", note = "")
dir.create(file.path(root, "data/annotations"), showWarnings = FALSE)
write_excel_csv(ann, file.path(root, "data/annotations/pilot_annotation_template.csv"))
cat("\ntemplate de anotação:", nrow(ann), "candidatos ->", "data/annotations/pilot_annotation_template.csv\n")

# DuckDB (validação da camada SQL)
con <- dbConnect(duckdb(), file.path(root, "data/stjmd_pilot.duckdb"))
dbWriteTable(con, "sample_documents", select(dm, -text), overwrite = TRUE)
dbWriteTable(con, "pilot_amounts", amounts, overwrite = TRUE)
dbWriteTable(con, "pilot_doc_outcomes", outcomes, overwrite = TRUE)
dbWriteTable(con, "pilot_doc_origin", origin, overwrite = TRUE)
cat("\n-- DuckDB check --\n"); print(dbGetQuery(con, "SELECT category, COUNT(*) n, ROUND(MEDIAN(value)) med FROM pilot_amounts WHERE unit='BRL' AND NOT in_precedent_quote GROUP BY 1 ORDER BY 2 DESC"))
dbDisconnect(con, shutdown = TRUE)

# amostra de contextos para revisão rápida
cat("\n== 40 contextos 'dano_moral' (fora de precedente) para revisão ==\n")
rev <- amounts |> filter(category == "dano_moral", !in_precedent_quote) |> slice_sample(n = 40)
for (i in seq_len(nrow(rev))) cat(sprintf("\n[%d] doc %s | %s | stage=%s dir=%s | ...%s <<%s>> %s...\n", i, rev$doc_id[i], rev$raw[i], rev$stage[i], rev$direction[i],
  stri_replace_all_regex(stri_sub(rev$ctx_before[i], -110), "\\n", " "), rev$raw[i], stri_replace_all_regex(stri_sub(rev$ctx_after[i], 1, 80), "\\n", " ")))
sink(); close(log)
