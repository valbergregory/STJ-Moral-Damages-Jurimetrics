# annotation_vocab.R — vocabulário único das planilhas de anotação da Semana 3 (docs/COMO_ANOTAR.md §4, §5 e §9) e
# verificação de coerência linha a linha. Usado por scripts/09_check_annotation.R (antes das métricas) e por
# scripts/04_validity_metrics.R (matéria `nao_consta`, Q13).
# Testado em tests/testthat/test-annotation_vocab.R. Depende de R/validity_metrics.R (norm_label, parse_*).

BOOL_CODES <- c("sim", "nao")
VOCAB_VALORES <- list(
  true_valor_correto   = BOOL_CODES,
  true_category        = c("dano_moral", "dano_material", "dano_estetico", "moral_material_conjunto", "honorarios", "multa",
                           "custas", "valor_causa", "contrato_divida", "limite_procedimental", "indeterminado"),
  true_stage           = c("pedido", "origem_sentenca", "origem_acordao", "stj", "indeterminado"),
  true_direction       = c("aumento", "reducao", "manutencao", "indeterminado"),
  true_in_precedent    = BOOL_CODES,
  true_reference_value = BOOL_CODES)
VOCAB_DOCUMENTOS <- list(
  true_materia             = c("negativacao", "plano_saude", "ambas", "outra", "nao_consta"),   # nao_consta: Q13
  true_menciona_dano_moral = BOOL_CODES,
  true_resultado_stj       = c("sem_dano_moral", "mantido_sumula7", "mantido", "majorado_stj", "reduzido_stj",
                               "nao_provido_sem_quantum", "outro", "indeterminado"),
  true_per_capita          = BOOL_CODES,
  true_incluir             = BOOL_CODES,
  true_motivo_exclusao     = c("materia_diversa", "sem_valor_estagio", "so_precedente", "coletivo_ambiental", "trabalhista",
                               "salario_minimo_sem_conversao", "extenso_divergente", "acordo_desistencia", "outro"))
DOC_VALUE_COLS <- c(pedido = "true_valor_pedido", sentenca = "true_valor_sentenca", acordao_origem = "true_valor_acordao_origem",
                    stj = "true_valor_stj")
MATERIAS_INCLUIDAS <- c("negativacao", "plano_saude", "ambas")
UF_CODES <- c("AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS", "MG", "PA", "PB", "PR", "PE", "PI", "RJ", "RN",
              "RS", "RO", "RR", "SC", "SP", "SE", "TO", paste0("TRF", 1:6), "TRT", "NAO_CONSTA")

# booleano normalizado para o código do vocabulário ("Sim", "s", "TRUE" → "sim"); rótulos comuns via norm_label
norm_code <- function(x, col) {
  if (identical(VOCAB_VALORES[[col]], BOOL_CODES) || identical(VOCAB_DOCUMENTOS[[col]], BOOL_CODES)) {
    b <- parse_bool_pt(x); out <- ifelse(is.na(b), norm_label(x), ifelse(b, "sim", "nao")); out[is.na(norm_label(x))] <- NA; out
  } else norm_label(x)
}
cell_filled <- function(x) !is.na(x) & stri_trim_both(coalesce(as.character(x), "")) != ""
# célula de valor que não vira número (ex.: "dez mil reais"): parse_value_set descarta os tokens ilegíveis
value_unparseable <- function(x) {
  tok <- stri_split_regex(coalesce(as.character(x), ""), "[;|/]")
  map_lgl(tok, function(t) { t <- stri_trim_both(t); t <- t[t != ""]; length(t) > 0 && any(is.na(parse_brl_input(t))) })
}

# Uma linha por problema: item_id, coluna, gravidade ("erro" | "aviso"), regra. Células vazias = "não anotado" (não é erro).
check_annotation <- function(d, kind = c("valores", "documentos")) {
  kind <- match.arg(kind); vocab <- if (kind == "valores") VOCAB_VALORES else VOCAB_DOCUMENTOS
  id <- if ("item_id" %in% names(d)) d$item_id else if ("item_id_reanot" %in% names(d)) d$item_id_reanot else as.character(seq_len(nrow(d)))
  probs <- list(); add <- function(rows, col, sev, rule) if (any(rows, na.rm = TRUE))
    probs[[length(probs) + 1]] <<- tibble(item_id = id[which(rows)], coluna = col, gravidade = sev, regra = rule)
  miss <- setdiff(names(vocab), names(d))
  if (length(miss)) return(tibble(item_id = NA_character_, coluna = miss, gravidade = "erro", regra = "coluna ausente na planilha"))
  v <- map(set_names(names(vocab)), ~ norm_code(d[[.x]], .x))
  for (col in names(vocab)) add(!is.na(v[[col]]) & !(v[[col]] %in% vocab[[col]]), col, "erro",
                                paste0("código fora do vocabulário (aceitos: ", paste(vocab[[col]], collapse = ", "), ")"))
  if (kind == "valores") {
    # Q9/Q11: valor dentro de precedente citado não tem estágio nem direção
    prec <- v$true_in_precedent %in% "sim"
    add(prec & !(v$true_stage %in% c("indeterminado", NA)), "true_stage", "erro", "in_precedent = sim exige estágio indeterminado (Q9)")
    add(prec & !(v$true_direction %in% c("indeterminado", NA)), "true_direction", "erro", "in_precedent = sim exige direção indeterminada (Q9)")
    return(bind_rows(probs, tibble(item_id = character(), coluna = character(), gravidade = character(), regra = character())))
  }
  vals <- map(DOC_VALUE_COLS, ~ cell_filled(d[[.x]]))
  any_val <- reduce(vals, `|`); any_stage_val <- vals$sentenca | vals$acordao_origem | vals$stj
  for (nm in names(DOC_VALUE_COLS)) add(value_unparseable(d[[DOC_VALUE_COLS[[nm]]]]), DOC_VALUE_COLS[[nm]], "erro",
                                        "valor ilegível (use 10000, 10.000,00, R$ 10.000,00 ou 10 mil; vários: separe por ;)")
  uf <- toupper(norm_label(d$true_origem_uf))
  add(!is.na(uf) & !(uf %in% UF_CODES), "true_origem_uf", "erro", "UF/tribunal fora da lista (UF, TRF1–TRF6, TRT, nao_consta)")
  nv <- stri_trim_both(coalesce(d$true_n_vitimas, ""))
  add(nv != "" & !stri_detect_regex(nv, "^[0-9]+$"), "true_n_vitimas", "erro", "número de vítimas deve ser inteiro")
  men <- v$true_menciona_dano_moral; res <- v$true_resultado_stj; inc <- v$true_incluir; mot <- v$true_motivo_exclusao; mat <- v$true_materia
  add(men %in% "nao" & !(res %in% c("sem_dano_moral", NA)), "true_resultado_stj", "erro", "menciona = nao exige resultado sem_dano_moral")
  add(res %in% "sem_dano_moral" & any_val, "true_valor_*", "erro", "resultado sem_dano_moral com valor de dano moral preenchido (Q15)")
  add(inc %in% "sim" & !is.na(mot), "true_motivo_exclusao", "erro", "incluir = sim não leva motivo de exclusão")
  add(inc %in% "nao" & is.na(mot), "true_motivo_exclusao", "erro", "incluir = nao exige motivo de exclusão")
  add(inc %in% "sim" & !(mat %in% c(MATERIAS_INCLUIDAS, NA)), "true_materia", "erro", "incluir = sim exige matéria negativacao, plano_saude ou ambas")
  add(inc %in% "sim" & !any_stage_val, "true_valor_*", "erro", "incluir = sim exige valor de dano moral em algum estágio (critério 4 da docs/02)")
  add(mat %in% "nao_consta" & !(inc %in% c("nao", NA)), "true_incluir", "erro", "matéria nao_consta exige incluir = nao (Q13)")
  add(mat %in% "nao_consta" & !(mot %in% c("sem_valor_estagio", NA)), "true_motivo_exclusao", "erro", "matéria nao_consta exige motivo sem_valor_estagio (Q13)")
  add(mat %in% "outra" & inc %in% "nao" & !is.na(mot) & !(mot %in% c("materia_diversa", "so_precedente", "outro")), "true_motivo_exclusao", "aviso",
      "matéria outra costuma levar motivo materia_diversa")
  add(mot %in% "materia_diversa" & mat %in% MATERIAS_INCLUIDAS, "true_motivo_exclusao", "erro", "motivo materia_diversa contradiz matéria incluída")
  add(res %in% "mantido_sumula7" & !(vals$sentenca | vals$acordao_origem), "true_valor_*", "aviso",
      "mantido_sumula7 sem valor de origem (ok se o texto não traz o valor ou se é em salário mínimo)")
  add(res %in% c("majorado_stj", "reduzido_stj") & !any_stage_val, "true_valor_*", "aviso", "majorado/reduzido sem nenhum valor por estágio")
  bind_rows(probs, tibble(item_id = character(), coluna = character(), gravidade = character(), regra = character()))
}

# progresso: linhas com pelo menos um campo do vocabulário preenchido
annotation_progress <- function(d, kind = c("valores", "documentos")) {
  kind <- match.arg(kind); cols <- intersect(names(if (kind == "valores") VOCAB_VALORES else VOCAB_DOCUMENTOS), names(d))
  done <- if (length(cols)) Reduce(`|`, map(cols, ~ cell_filled(d[[.x]]))) else rep(FALSE, nrow(d))
  c(anotados = sum(done), total = nrow(d))
}
