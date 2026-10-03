# awards_rules.R — regras de consistência (docs/02) e construção dos eventos decisórios (stg.award_events) a partir de
# stg.money_candidates + stg.doc_outcomes + stg.selected_docs (+ stg.doc_origin). Plano: docs/10_estimation_plan.md §1.
# Funções puras (sem banco, sem I/O); testadas em tests/testthat/test-awards_rules.R com fixtures sintéticas.
# Dependência: R/validity_metrics.R (norm_label, parse_bool_pt, parse_value_set) — usada só por apply_reviewed().
#
# Convenções (todas rastreáveis a docs/02, docs/COMO_ANOTAR.md §9 ou docs/10 §1):
#  * Candidato elegível = categoria dano_moral, BRL, fora de precedente citado e de valor de referência, sem divergência
#    cifra × extenso, com estágio atribuível (pedido / sentença / acórdão de origem / STJ).
#  * `valor_stj` fica VAZIO sob Súmula 7 (Q1–Q9, decisão de 02/10); `valor_stj_efetivo` aplica a regra 5 de docs/02
#    (mantido ⇒ valor do STJ = valor de origem) sem apagar a distinção.
#  * População de análise = incluir ∧ evento primário ∧ não ambíguo ∧ valor da resposta presente ∧ sem PJ autora (§9 item 7).
#    `autor_pj` AINDA NÃO é extraído: a coluna existe como NA e o filtro só passa a valer quando houver extração/anotação.
suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(purrr); library(stringi); library(tibble) })

STAGE_COL <- c(pedido = "valor_pedido", origem_sentenca = "valor_sentenca", origem_acordao = "valor_acordao_origem", stj = "valor_stj")
VALOR_COLS <- unname(STAGE_COL)
CLASSES_CIVEIS <- c("REsp", "AREsp", "EREsp", "EAREsp")
OUTCOMES_A_VERIFICAR <- c("provido_verificar", "indeterminado", "ambiguo", "erro")
OUTCOMES_MANTIDO <- c("mantido_sumula7", "mantido")

.ensure_cols <- function(d, cols, fill = NA) { for (nm in setdiff(cols, names(d))) d[[nm]] <- fill; d }

# --- 1. elegibilidade dos candidatos ---------------------------------------------------------------------------------
# Acrescenta `reason` (NA = elegível) e `elig`. A ordem dos motivos é a de precedência na leitura do documento.
candidate_flags <- function(cands) {
  cands <- .ensure_cols(cands, c("category", "unit", "stage", "direction", "value"), NA)
  cands <- .ensure_cols(cands, c("in_precedent_quote", "reference_value", "extenso_mismatch", "per_capita"), FALSE)
  cands |> mutate(
    reason = case_when(
      category != "dano_moral" | is.na(category) ~ "nao_dano_moral",
      unit == "SM" ~ "salario_minimo",
      coalesce(in_precedent_quote, FALSE) ~ "precedente",
      coalesce(reference_value, FALSE) ~ "referencia",
      coalesce(extenso_mismatch, FALSE) ~ "extenso_divergente",
      !(stage %in% names(STAGE_COL)) ~ "estagio_indeterminado",
      is.na(value) ~ "sem_valor",
      TRUE ~ NA_character_),
    elig = is.na(reason))
}

# --- 2. eventos decisórios ---------------------------------------------------------------------------------------------
derive_materia <- function(docs) {
  if ("materia" %in% names(docs)) return(docs)
  docs <- .ensure_cols(docs, c("negativacao", "plano_saude"), FALSE)
  docs |> mutate(materia = case_when(coalesce(negativacao, FALSE) & coalesce(plano_saude, FALSE) ~ "ambas",
                                     coalesce(negativacao, FALSE) ~ "negativacao",
                                     coalesce(plano_saude, FALSE) ~ "plano_saude", TRUE ~ NA_character_))
}

# cands: stg.money_candidates; outcomes: stg.doc_outcomes (seq_documento, outcome, sumula7); docs: stg.selected_docs
# (seq_documento, numero_registro, classe, tipo_documento, data_publicacao, negativacao, plano_saude);
# origin: stg.doc_origin (seq_documento, origem_tipo, origem_uf) ou NULL. Uma linha por documento (event_k = 1).
build_award_events <- function(cands, outcomes, docs, origin = NULL) {
  fl <- candidate_flags(cands); el <- filter(fl, elig)
  st <- el |> group_by(seq_documento, stage) |>
    summarise(n_dist = n_distinct(round(value, 2)), val = round(first(value), 2), any_pc = any(per_capita %in% TRUE),
              dir = { d <- setdiff(unique(direction), c("indeterminado", NA)); if (length(d) == 1) d else NA_character_ }, .groups = "drop") |>
    mutate(val = if_else(n_dist > 1, NA_real_, val))
  wide <- st |> mutate(col = unname(STAGE_COL[stage])) |> select(seq_documento, col, val) |>
    pivot_wider(names_from = col, values_from = val) |> .ensure_cols(VALOR_COLS, NA_real_)
  multi <- st |> filter(n_dist > 1) |> group_by(seq_documento) |>
    summarise(multi = paste0("multiplos_valores:", paste(stage, collapse = ",")), .groups = "drop")
  pc <- st |> group_by(seq_documento) |> summarise(per_capita = any(any_pc), .groups = "drop")
  dirs <- st |> filter(stage %in% c("origem_acordao", "stj")) |> select(seq_documento, stage, dir) |>
    pivot_wider(names_from = stage, values_from = dir, names_prefix = "dir_") |> .ensure_cols(c("dir_origem_acordao", "dir_stj"), NA_character_)
  sm <- fl |> filter(!is.na(category)) |> group_by(seq_documento) |>
    summarise(has_mismatch = any(category == "dano_moral" & unit == "BRL" & coalesce(extenso_mismatch, FALSE)),
              has_sm = any(category == "dano_moral" & unit == "SM"),
              has_prec = any(category == "dano_moral" & (coalesce(in_precedent_quote, FALSE) | coalesce(reference_value, FALSE))),
              .groups = "drop")

  ev <- derive_materia(docs) |> select(any_of(c("seq_documento", "numero_registro", "materia", "classe", "tipo_documento", "data_publicacao"))) |>
    .ensure_cols(c("numero_registro", "classe", "tipo_documento"), NA_character_) |>
    left_join(select(outcomes, seq_documento, resultado_stj = outcome, sumula7), by = "seq_documento") |>
    left_join(wide, by = "seq_documento") |> left_join(multi, by = "seq_documento") |> left_join(pc, by = "seq_documento") |>
    left_join(dirs, by = "seq_documento") |> left_join(sm, by = "seq_documento")
  if (!is.null(origin) && nrow(origin)) ev <- left_join(ev, distinct(select(origin, seq_documento, origem_tipo, origem_uf), seq_documento, .keep_all = TRUE), by = "seq_documento")
  ev <- ev |> .ensure_cols(c("origem_tipo", "origem_uf"), NA_character_) |>
    mutate(across(c(has_mismatch, has_sm, has_prec), ~ coalesce(.x, FALSE)), per_capita = coalesce(per_capita, FALSE))

  org <- coalesce(ev$valor_acordao_origem, ev$valor_sentenca)         # valor de origem de referência
  res <- ev$resultado_stj; stj <- ev$valor_stj
  flags <- list(
    multiplos_valores_estagio = !is.na(ev$multi),                                                               # docs/02 regra 4
    resultado_a_verificar     = is.na(res) | res %in% OUTCOMES_A_VERIFICAR,
    stj_sem_origem_distinta   = ev$dir_stj %in% c("aumento", "reducao") & (is.na(org) | (!is.na(stj) & org == stj)),   # regra 1
    alteracao_incoerente      = (res == "majorado_stj" & !is.na(stj) & !is.na(org) & stj <= org) |
                                (res == "reduzido_stj" & !is.na(stj) & !is.na(org) & stj >= org),
    alteracao_sem_valores     = res %in% c("majorado_stj", "reduzido_stj") & (is.na(stj) | is.na(org)),
    direcao_origem_incoerente = (ev$dir_origem_acordao == "aumento" & !is.na(ev$valor_sentenca) & !is.na(ev$valor_acordao_origem) & ev$valor_acordao_origem <= ev$valor_sentenca) |
                                (ev$dir_origem_acordao == "reducao" & !is.na(ev$valor_sentenca) & !is.na(ev$valor_acordao_origem) & ev$valor_acordao_origem >= ev$valor_sentenca),   # regra 2
    sumula7_valor_divergente  = res == "mantido_sumula7" & !is.na(stj) & !is.na(org) & stj != org,                # regra 5
    extenso_divergente        = ev$has_mismatch)
  flags <- map(flags, ~ coalesce(.x, FALSE))
  mot <- if (nrow(ev)) apply(do.call(cbind, flags), 1, function(r) paste(names(flags)[r], collapse = ";")) else character(0)

  no_decision_value <- is.na(ev$valor_sentenca) & is.na(ev$valor_acordao_origem) & is.na(ev$valor_stj)
  motivo <- case_when(ev$has_mismatch ~ "extenso_divergente",
                      !is.na(ev$classe) & !(ev$classe %in% CLASSES_CIVEIS) ~ "outro",
                      no_decision_value & ev$has_sm ~ "salario_minimo_sem_conversao",
                      no_decision_value & ev$has_prec ~ "so_precedente",
                      no_decision_value ~ "sem_valor_estagio", TRUE ~ NA_character_)
  ev <- ev |> mutate(
    valor_stj_efetivo = if_else(!is.na(valor_stj), valor_stj, if_else(resultado_stj %in% OUTCOMES_MANTIDO, coalesce(valor_acordao_origem, valor_sentenca), NA_real_)),
    alterou_stj = resultado_stj %in% c("majorado_stj", "reduzido_stj"),
    n_vitimas = NA_integer_, autor_pj = NA, event_k = 1L,
    ambiguo = mot != "", motivos_ambiguidade = mot, motivo_exclusao = motivo, incluir = is.na(motivo),
    ano = as.integer(format(as.Date(data_publicacao), "%Y")), fonte_valores = "automatico", origem_conhecida = !is.na(origem_uf)) |>
    select(-multi, -dir_origem_acordao, -dir_stj, -has_mismatch, -has_sm, -has_prec) |> arrange(data_publicacao, seq_documento)
  # evento primário: 1º documento INCLUÍDO de cada processo (docs/02: decisão monocrática → AgInt → EDcl)
  ev$evento_primario <- FALSE
  idx <- which(ev$incluir); key <- coalesce(ev$numero_registro[idx], paste0("doc", ev$seq_documento[idx]))
  ev$evento_primario[idx[!duplicated(key)]] <- TRUE
  ev |> relocate(seq_documento, event_k, numero_registro, materia, ano, data_publicacao)
}

# --- 3. revisão manual sobrepõe a extração -------------------------------------------------------------------------
# reviewed: planilha de documentos anotada (colunas true_* de docs/data_dictionary.md) com `seq_documento` (junção via
# w3_chave_documentos.csv, feita pelo chamador). Só documentos já presentes em `events` são sobrescritos (atributo
# "n_revisados_fora" informa quantos ficaram de fora). Várias cifras por estágio → ambiguo (docs/02 regra 4).
apply_reviewed <- function(events, reviewed) {
  stopifnot("seq_documento" %in% names(events), "seq_documento" %in% names(reviewed))
  reviewed <- .ensure_cols(reviewed, c("true_incluir", "true_motivo_exclusao", "true_resultado_stj", "true_per_capita", "true_n_vitimas",
                                       "true_origem_uf", "true_materia", "true_valor_pedido", "true_valor_sentenca",
                                       "true_valor_acordao_origem", "true_valor_stj"), NA_character_)
  reviewed <- filter(reviewed, !is.na(norm_label(true_incluir)))
  one <- function(col) map(parse_value_set(reviewed[[col]]), identity)
  sets <- list(valor_pedido = one("true_valor_pedido"), valor_sentenca = one("true_valor_sentenca"),
               valor_acordao_origem = one("true_valor_acordao_origem"), valor_stj = one("true_valor_stj"))
  multi <- reduce(map(sets, ~ map_lgl(.x, ~ length(.x) > 1)), `|`)
  val <- map(sets, ~ map_dbl(.x, ~ if (length(.x) == 1) .x else NA_real_))
  inc <- parse_bool_pt(reviewed$true_incluir)
  rv <- tibble(seq_documento = reviewed$seq_documento, !!!val, rv_resultado = as.character(norm_label(reviewed$true_resultado_stj)),
               rv_incluir = inc, rv_motivo = as.character(norm_label(reviewed$true_motivo_exclusao)), rv_multi = multi,
               rv_pc = parse_bool_pt(reviewed$true_per_capita), rv_n = suppressWarnings(as.integer(reviewed$true_n_vitimas)),
               rv_uf = toupper(as.character(norm_label(reviewed$true_origem_uf))), rv_materia = as.character(norm_label(reviewed$true_materia)))
  n_fora <- sum(!rv$seq_documento %in% events$seq_documento)
  rv <- filter(rv, seq_documento %in% events$seq_documento)
  hit <- events$seq_documento %in% rv$seq_documento; m <- match(events$seq_documento, rv$seq_documento)
  for (col in VALOR_COLS) events[[col]][hit] <- rv[[col]][m[hit]]
  events$resultado_stj[hit] <- coalesce(rv$rv_resultado[m[hit]], events$resultado_stj[hit])
  events$per_capita[hit] <- coalesce(rv$rv_pc[m[hit]], events$per_capita[hit])
  events$n_vitimas[hit] <- rv$rv_n[m[hit]]
  uf <- rv$rv_uf[m[hit]]; events$origem_uf[hit] <- if_else(is.na(uf) | uf == "NAO_CONSTA", NA_character_, uf)
  events$origem_conhecida <- !is.na(events$origem_uf)
  mat <- rv$rv_materia[m[hit]]; events$materia[hit] <- if_else(mat %in% c("negativacao", "plano_saude", "ambas"), mat, events$materia[hit])
  events$incluir[hit] <- rv$rv_incluir[m[hit]] %in% TRUE
  events$motivo_exclusao[hit] <- if_else(events$incluir[hit], NA_character_, coalesce(rv$rv_motivo[m[hit]], "outro"))
  events$ambiguo[hit] <- rv$rv_multi[m[hit]]
  events$motivos_ambiguidade[hit] <- if_else(rv$rv_multi[m[hit]], "multiplos_valores_revisados", "")
  events$alterou_stj[hit] <- events$resultado_stj[hit] %in% c("majorado_stj", "reduzido_stj")
  events$valor_stj_efetivo[hit] <- if_else(!is.na(events$valor_stj[hit]), events$valor_stj[hit],
                                           if_else(events$resultado_stj[hit] %in% OUTCOMES_MANTIDO, coalesce(events$valor_acordao_origem[hit], events$valor_sentenca[hit]), NA_real_))
  events$fonte_valores[hit] <- "revisado"
  # o evento primário depende de quem foi incluído: recalcula
  events$evento_primario <- FALSE
  ord <- order(events$data_publicacao, events$seq_documento); idx <- ord[events$incluir[ord]]
  key <- coalesce(events$numero_registro[idx], paste0("doc", events$seq_documento[idx])); events$evento_primario[idx[!duplicated(key)]] <- TRUE
  attr(events, "n_revisados_fora") <- n_fora
  events
}

# --- 4. deflação -----------------------------------------------------------------------------------------------------------
# value × IPCA(base) / IPCA(mês de referência). ipca: tibble(ref_month "YYYYMM", ipca_index). Mês sem índice → NA.
deflate_to_base <- function(value, date, ipca, base_month = "202512") {
  idx <- setNames(ipca$ipca_index, ipca$ref_month)
  if (!base_month %in% names(idx)) stop("mês-base ", base_month, " ausente da série do IPCA (última: ", tail(names(idx), 1), ")")
  value * idx[[base_month]] / unname(idx[format(as.Date(date), "%Y%m")])
}
# LIMITAÇÃO DECLARADA: a data em que o valor foi fixado na origem NÃO é extraída. O mês de referência padrão é o da
# publicação da decisão do STJ, que é POSTERIOR à fixação — a deflação é, portanto, subestimada em média. Alternativa a
# decidir (docs/10 §9): extrair a data do acórdão de origem ou usar o ano de origem do número CNJ.
add_real_values <- function(events, ipca, base_month = "202512", date_col = "data_publicacao") {
  for (col in VALOR_COLS) events[[paste0(col, "_real")]] <- deflate_to_base(events[[col]], events[[date_col]], ipca, base_month)
  events$valor_stj_efetivo_real <- deflate_to_base(events$valor_stj_efetivo, events[[date_col]], ipca, base_month)
  attr(events, "deflator") <- list(base_month = base_month, ref_date = date_col)
  events
}

# --- 5. população de análise e atrito ---------------------------------------------------------------------------
analysis_population <- function(events, response = "valor_acordao_origem") {
  events |> filter(incluir, evento_primario, !ambiguo, !is.na(.data[[response]]), !(autor_pj %in% TRUE))
}
# Atrito sequencial por matéria (cada passo parte do anterior). `ambas` é contada como linha própria.
attrition_table <- function(events, response = "valor_acordao_origem") {
  steps <- list(
    "1. documentos selecionados"           = events,
    "2. com valor de decisão (incluídos)"  = filter(events, incluir),
    "3. evento primário do processo"       = filter(events, incluir, evento_primario),
    "4. sem ambiguidade"                   = filter(events, incluir, evento_primario, !ambiguo),
    "5. com a resposta principal"          = filter(events, incluir, evento_primario, !ambiguo, !is.na(.data[[response]])),
    "6. sem PJ autora"                     = analysis_population(events, response))
  imap_dfr(steps, ~ count(.x, materia, name = "n") |> mutate(passo = .y)) |>
    pivot_wider(names_from = materia, values_from = n, values_fill = 0L) |>
    mutate(total = as.integer(rowSums(across(-passo))))
}
