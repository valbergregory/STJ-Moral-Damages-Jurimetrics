# ---------------------------------------------------------------------------
# extract_money.R — extração e classificação contextual de expressões
# monetárias em decisões do STJ (piloto). Somente R (stringi/stringr).
# Nenhuma expressão monetária é tratada como indenização por padrão: cada
# candidato recebe categoria, estágio processual, direção e sinalizadores de
# ambiguidade; a decisão final de uso fica para regras de consistência +
# revisão manual (ver docs/extraction_protocol.md).
# ---------------------------------------------------------------------------
suppressPackageStartupMessages({
  library(stringi); library(stringr); library(dplyr); library(purrr); library(tibble)
})

# --- normalização -----------------------------------------------------------
normalize_text <- function(x) {
  x <- stri_replace_all_fixed(x, "\r", "")
  x <- stri_replace_all_regex(x, "<br\\s*/?>", "\n", case_insensitive = TRUE)
  ents <- c("&amp;" = "&", "&lt;" = "<", "&gt;" = ">", "&quot;" = "\"", "&#39;" = "'",
            "&apos;" = "'", "&nbsp;" = " ", "&ordm;" = "º", "&ordf;" = "ª", "&sect;" = "§")
  x <- stri_replace_all_fixed(x, names(ents), unname(ents), vectorize_all = FALSE)
  x <- stri_replace_all_regex(x, "&#(\\d+);", "")
  x <- stri_replace_all_regex(x, "[ \\t\\u00a0]+", " ")
  x
}

# --- números por extenso (pt-BR) -------------------------------------------
.pt_units <- c(um = 1, uma = 1, dois = 2, duas = 2, tres = 3, "três" = 3, quatro = 4, cinco = 5,
  seis = 6, sete = 7, oito = 8, nove = 9, dez = 10, onze = 11, doze = 12, treze = 13,
  quatorze = 14, catorze = 14, quinze = 15, dezesseis = 16, dezessete = 17, dezoito = 18,
  dezenove = 19, vinte = 20, trinta = 30, quarenta = 40, cinquenta = 50, "cinqüenta" = 50,
  sessenta = 60, setenta = 70, oitenta = 80, noventa = 90, cem = 100, cento = 100,
  duzentos = 200, trezentos = 300, quatrocentos = 400, quinhentos = 500, seiscentos = 600,
  setecentos = 700, oitocentos = 800, novecentos = 900)
.pt_words_regex <- paste0("(?:", paste(c(names(.pt_units), "mil", "milh[aã]o", "milh[oõ]es",
                                          "bilh[aã]o", "bilh[oõ]es", "e"), collapse = "|"), ")")

words_to_number <- function(s) {
  s <- stri_trans_tolower(s)
  s <- stri_replace_all_regex(s, "\\bde\\b", " ")
  w <- stri_split_regex(s, "[\\s\\-]+", omit_empty = TRUE)[[1]]
  total <- 0; cur <- 0; seen <- FALSE
  for (t in w) {
    if (t == "e") next
    if (t %in% names(.pt_units)) { cur <- cur + .pt_units[[t]]; seen <- TRUE }
    else if (t == "mil") { cur <- ifelse(cur == 0, 1, cur) * 1e3; total <- total + cur; cur <- 0; seen <- TRUE }
    else if (stri_detect_regex(t, "^milh")) { cur <- ifelse(cur == 0, 1, cur) * 1e6; total <- total + cur; cur <- 0; seen <- TRUE }
    else if (stri_detect_regex(t, "^bilh")) { cur <- ifelse(cur == 0, 1, cur) * 1e9; total <- total + cur; cur <- 0; seen <- TRUE }
    else return(NA_real_)
  }
  if (!seen) return(NA_real_)
  total + cur
}

parse_brl <- function(s) {
  s <- stri_replace_all_regex(s, "[^0-9,\\.]", "")
  if (stri_detect_fixed(s, ",")) {
    p <- stri_split_fixed(s, ",")[[1]]
    int <- stri_replace_all_fixed(p[1], ".", ""); dec <- substr(paste0(p[2], "00"), 1, 2)
    return(as.numeric(int) + as.numeric(dec) / 100)
  }
  if (stri_detect_regex(s, "^\\d{1,3}(\\.\\d{3})+$")) return(as.numeric(stri_replace_all_fixed(s, ".", "")))
  suppressWarnings(as.numeric(stri_replace_all_fixed(s, ".", "")))
}

# --- padrões de valor -------------------------------------------------------
.re_currency <- "R\\$\\s?(\\d{1,3}(?:\\.\\d{3})+(?:,\\d{1,2})?|\\d+(?:,\\d{1,2})?)"
.re_scaled   <- "(?<![\\d,\\.])(\\d{1,3}(?:[\\.,]\\d{1,3})?)\\s?(mil|milh[aã]o|milh[oõ]es)\\s?(?:de\\s?)?reais"
.re_words    <- paste0("\\b((?:", .pt_words_regex, "\\s?){1,14})\\s?reais\\b")
.re_salmin   <- "(\\d{1,4}|[a-zçãõáéíóúê]+)\\s?\\(?[^()\\n]{0,30}?\\)?\\s?sal[áa]rios?[\\s-]?m[íi]nimos?"

find_amounts <- function(text) {
  out <- list()
  m <- stri_locate_all_regex(text, .re_currency, omit_no_match = TRUE)[[1]]
  if (nrow(m)) {
    raw <- stri_sub(text, m[, 1], m[, 2])
    out[[1]] <- tibble(start = m[, 1], end = m[, 2], raw = raw, unit = "BRL", form = "cifra",
                       value = map_dbl(raw, parse_brl))
  }
  m <- stri_locate_all_regex(text, .re_scaled, omit_no_match = TRUE, case_insensitive = TRUE)[[1]]
  if (nrow(m)) {
    raw <- stri_sub(text, m[, 1], m[, 2])
    num <- as.numeric(stri_replace_all_fixed(stri_extract_first_regex(raw, "^\\d{1,3}(?:[\\.,]\\d{1,3})?"), ",", "."))
    mult <- ifelse(stri_detect_regex(raw, "milh", case_insensitive = TRUE), 1e6, 1e3)
    out[[2]] <- tibble(start = m[, 1], end = m[, 2], raw = raw, unit = "BRL", form = "escala", value = num * mult)
  }
  m <- stri_locate_all_regex(text, .re_words, omit_no_match = TRUE, case_insensitive = TRUE)[[1]]
  if (nrow(m)) {
    raw <- stri_sub(text, m[, 1], m[, 2])
    val <- map_dbl(stri_replace_last_regex(raw, "\\s?reais$", "", case_insensitive = TRUE), words_to_number)
    out[[3]] <- tibble(start = m[, 1], end = m[, 2], raw = raw, unit = "BRL", form = "extenso", value = val) |>
      filter(!is.na(value))
  }
  m <- stri_locate_all_regex(text, .re_salmin, omit_no_match = TRUE, case_insensitive = TRUE)[[1]]
  if (nrow(m)) {
    raw <- stri_sub(text, m[, 1], m[, 2])
    tok <- stri_extract_first_regex(raw, "^[^\\s(]+")
    val <- suppressWarnings(as.numeric(tok))
    wv <- map_dbl(tok, ~ words_to_number(.x))
    val <- ifelse(is.na(val), wv, val)
    out[[4]] <- tibble(start = m[, 1], end = m[, 2], raw = raw, unit = "SM", form = "salario_minimo", value = val) |>
      filter(!is.na(value))
  }
  res <- bind_rows(out)
  if (!nrow(res)) return(res)
  res <- arrange(res, start)
  res$extenso_parenthetical <- FALSE; res$extenso_mismatch <- NA
  drop <- logical(nrow(res))
  for (i in seq_len(nrow(res))) {
    if (res$form[i] != "extenso") next
    prev <- which(res$form == "cifra" & res$end < res$start[i] & res$start[i] - res$end <= 4)
    if (length(prev)) {
      between <- stri_sub(text, res$end[prev[1]] + 1, res$start[i] - 1)
      if (stri_detect_regex(between, "^\\s?\\(\\s?$")) {
        res$extenso_parenthetical[prev[1]] <- TRUE
        res$extenso_mismatch[prev[1]] <- !isTRUE(all.equal(res$value[prev[1]], res$value[i]))
        drop[i] <- TRUE
      }
    }
  }
  res <- res[!drop, ]
  keep <- rep(TRUE, nrow(res)); last_end <- 0
  for (i in seq_len(nrow(res))) { if (res$start[i] <= last_end) keep[i] <- FALSE else last_end <- res$end[i] }
  res[keep, ]
}

# --- classificação contextual ---------------------------------------------
.cat_cues <- list(
  honorarios     = "honor[áa]ri|verba honor|sucumb[êe]nc",
  multa          = "\\bmulta|astreinte|art\\.?\\s?1\\.?026|art\\.?\\s?523|art\\.?\\s?77\\b|litig[âa]ncia de m[áa]-f[ée]",
  custas         = "\\bcustas|despesas processuais|preparo",
  valor_causa    = "valor (?:da|atribu[íi]do [àa]) causa|valor de al[çc]ada|\\bal[çc]ada",
  dano_material  = "danos? materia|preju[íi]zos? materia|lucros? cessantes?|danos? emergentes?|ressarci|restitui|repeti[çc][ãa]o|devolu[çc][ãa]o|reembols|pens(?:ão|ao|ionamento)",
  dano_estetico  = "danos? est[ée]tic",
  dano_moral     = "danos? mora|extrapatrimonia|compensa[çc][ãa]o|quantum (?:indenizat|compensat)|indeniza[çc][ãa]o|montante (?:indenizat|arbitrad|fixad)|valor (?:arbitrad|fixad|da condena)|arbitr|reparat[óo]ri",
  contrato_divida = "empr[ée]stimo|financiamento|parcela|d[ée]bito|d[íi]vida|cobran[çc]a|fatura|contrato no valor|sal[áa]rio\\b|remunera[çc][ãa]o|benef[íi]cio|aposentadoria|dep[óo]sito|saque|transfer[êe]ncia|compra|pre[çc]o|mensalidade|pr[êe]mio|ap[óo]lice|cheque|\\bt[íi]tulo",
  limite_procedimental = "sessenta sal[áa]rios|60 \\(?sessenta\\)? sal|\\bteto\\b|limite (?:de|da) (?:al[çc]ada|compet[êe]ncia)|juizado"
)
.stage_cues <- list(
  origem_sentenca = "senten[çc]a|ju[íi]zo (?:de|da) (?:primeir|1)|primeir[oa] (?:grau|inst[âa]ncia)|juiz singular|magistrado a quo|ju[íi]zo a quo|ju[íi]zo de origem|julgou (?:parcialmente )?procedente",
  origem_acordao  = "tribunal de origem|corte de origem|tribunal a quo|corte a quo|corte local|tribunal local|tribunal estadual|ac[óo]rd[ãa]o recorrido|ac[óo]rd[ãa]o (?:impugnado|combatido|hostilizado|vergastado)|apela[çc][ãa]o|inst[âa]ncias? ordin[áa]ria|\\bTJ[A-Z/-]{0,4}\\b|Tribunal de Justi[çc]a|Tribunal Regional|Turma Recursal|ac[óo]rd[ãa]o (?:estadual|regional|de origem)|assim ementad|voto condutor|colegiado (?:estadual|de origem)",
  stj             = "esta Corte|este Tribunal Superior|este Superior Tribunal|nesta Corte|Superior Tribunal de Justi[çc]a|\\bSTJ\\b|dou (?:parcial )?provimento|conhe[çc]o do (?:agravo|recurso)|nego provimento|majoro|reduzo|minoro|\\bfixo\\b|\\barbitro\\b|estabele[çc]o|para (?:reduzir|majorar|fixar|arbitrar|elevar|diminuir)|ante o exposto|isso posto|pelo exposto|diante do exposto",
  pedido          = "pleite|postul|requer(?:eu|endo|ida|ido)|pediu|pretende|pretens[ãa]o|\\binicial\\b"
)
.dir_cues <- list(
  aumento    = "major|elev|aument|ampli|para mais",
  reducao    = "reduz|minor|diminu|decot|rebaix|para menos",
  manutencao = "mant[ée]|manuten[çc][ãa]o|preserv|confirm|subsist|adequad|razo[áa]vel|proporcional|n[ãa]o (?:se mostra|é|se revela) (?:irris[óo]ri|exorbitant)"
)
.re_precedent_close <- "\\((?:AgRg|AgInt|EDcl|EREsp|EAREsp|REsp|AREsp|RMS|HC|RHC|Ag|CC)[^()]{5,220}?(?:DJe?|julgado em|DJU)"
.re_narrative_break <- "Trata-se|No caso|Na hip[óo]tese|In casu|Ante o exposto|Assim,|Pois bem|Com efeito|Na esp[ée]cie|No presente caso|Nesse contexto|Dessa forma|Diante disso|Isso posto|Pelo exposto"
.re_sentence_tail <- "(?:[^.\\n]|\\.(?!\\s[A-ZÁÉÍÓÚÂÊÔÃÕ]))*$"
.re_sentence_head <- "^(?:[^.\\n]|\\.(?!\\s[A-ZÁÉÍÓÚÂÊÔÃÕ]))*"

cue_dists <- function(ctx_before, ctx_after, pattern) {
  b <- stri_locate_all_regex(ctx_before, pattern, omit_no_match = TRUE, case_insensitive = TRUE)[[1]]
  a <- stri_locate_all_regex(ctx_after,  pattern, omit_no_match = TRUE, case_insensitive = TRUE)[[1]]
  db <- if (nrow(b)) nchar(ctx_before) - max(b[, 2]) + 1 else Inf
  da <- if (nrow(a)) min(a[, 1]) else Inf
  c(before = db, after = da)
}
nearest_cue_dist <- function(ctx_before, ctx_after, pattern) min(cue_dists(ctx_before, ctx_after, pattern))
.re_reference_value <- "faixa de|patamar|jurisprud[êe]ncia (?:tem|vem) (?:fixa|arbitra)|casos (?:semelhantes|an[áa]logos|cong[êe]neres|similares)|precedentes? (?:desta|da|deste) (?:Corte|Tribunal)|par[âa]metro|em (?:hip[óo]teses|situa[çc][õo]es) (?:semelhantes|an[áa]logas)|m[ée]dia (?:das|de) (?:indeniza|condena)"

classify_amount <- function(text, start, end, win_before = 320, win_after = 220) {
  n <- nchar(text)
  cb <- stri_sub(text, max(1, start - win_before), start - 1)
  ca <- stri_sub(text, end + 1, min(n, end + win_after))
  cb_sent <- stri_extract_last_regex(cb, .re_sentence_tail); if (is.na(cb_sent) || nchar(cb_sent) < 80) cb_sent <- cb
  ca_sent <- stri_extract_first_regex(ca, .re_sentence_head); if (is.na(ca_sent) || nchar(ca_sent) < 40) ca_sent <- ca
  dd <- map(.cat_cues, ~ cue_dists(cb, ca, .x))
  dist_b <- map_dbl(dd, 1); dist_a <- map_dbl(dd, 2); dist <- pmin(dist_b, dist_a)
  # regra 1: o rótulo que ANTECEDE o valor a curta distância ("multa diária de R$", "honorários em R$") prevalece
  nb <- dist_b[dist_b <= 45]
  near <- dist[dist <= 60]
  category <- if (length(nb)) names(nb)[which.min(nb)] else if (length(near)) names(near)[which.min(near)] else
    if (any(is.finite(dist))) names(dist)[which.min(dist)] else "indeterminado"
  reference_value <- stri_detect_regex(paste(cb_sent, ca_sent), .re_reference_value, case_insensitive = TRUE)
  if (category %in% c("dano_moral", "dano_material") && is.finite(dist[["dano_moral"]]) && is.finite(dist[["dano_material"]]) &&
      abs(dist[["dano_moral"]] - dist[["dano_material"]]) <= 25 &&
      stri_detect_regex(paste(cb_sent, ca_sent), "danos? (?:morais?|materiais?) e (?:danos? )?(?:materiais?|morais?)|morais e materiais|materiais e morais", case_insensitive = TRUE))
    category <- "moral_material_conjunto"
  sdist <- map_dbl(.stage_cues, ~ nearest_cue_dist(cb, ca, .x))
  stage <- if (any(is.finite(sdist))) names(sdist)[which.min(sdist)] else "indeterminado"
  ddist <- map_dbl(.dir_cues, ~ nearest_cue_dist(cb_sent, ca_sent, .x))
  direction <- if (any(is.finite(ddist))) names(ddist)[which.min(ddist)] else "indeterminado"
  after_long <- stri_sub(text, end + 1, min(n, end + 900))
  prec <- stri_locate_first_regex(after_long, .re_precedent_close)[1, 1]
  brk  <- stri_locate_first_regex(after_long, .re_narrative_break)[1, 1]
  in_precedent <- !is.na(prec) && (is.na(brk) || prec < brk)
  before_long <- stri_sub(text, max(1, start - 2500), start - 1)
  em_pos <- stri_locate_last_regex(before_long, "assim ementad|seguinte ementa|ementa:|ementado nos seguintes termos", case_insensitive = TRUE)[1, 2]
  brk2 <- if (!is.na(em_pos)) stri_locate_first_regex(stri_sub(before_long, em_pos + 1),
            "\\n\\s*(?:Opostos|Interpostos|Os embargos|No recurso especial|Nas razões|Em suas razões|Sobreveio|Irresignad|Inconformad|Sustenta|Alega|Aponta|Trata-se|O recurso|Contrarraz)", case_insensitive = TRUE)[1, 1] else NA
  in_origin_ementa <- !is.na(em_pos) && is.na(brk2)
  per_capita <- stri_detect_regex(paste(cb_sent, ca_sent), "para cada|a cada um|cada (?:autor|v[íi]tima|recorr|requerente|demandante|um dos)|por autor|individualmente|cada qual", case_insensitive = TRUE)
  tibble(category = category, cat_dist = if (is.finite(min(dist))) min(dist) else NA_real_,
         stage = stage, stage_dist = if (is.finite(min(sdist))) min(sdist) else NA_real_,
         direction = direction, in_precedent_quote = in_precedent, in_origin_ementa = in_origin_ementa,
         per_capita = per_capita, reference_value = reference_value, ctx_before = stri_sub(cb, -160), ctx_after = stri_sub(ca, 1, 120))
}

extract_money <- function(text, doc_id = NA) {
  text <- normalize_text(text)
  am <- find_amounts(text)
  if (!nrow(am)) return(tibble())
  cls <- pmap_dfr(list(am$start, am$end), ~ classify_amount(text, ..1, ..2))
  bind_cols(tibble(doc_id = doc_id), am, cls) |> mutate(rel_pos = start / nchar(text))
}

# --- resultado no STJ quanto ao quantum (dispositivo) -----------------------
.re_s7 <- "S[úu]mula\\s?(?:n\\.?[ºo°]?\\s?)?7\\b|reexame (?:de|do) (?:conjunto )?f[áa]tico|revolvimento (?:do|de) (?:conjunto |acervo )?f[áa]tico|matéria fático"
stj_quantum_outcome <- function(text) {
  text <- normalize_text(text); n <- nchar(text)
  tail_txt <- stri_sub(text, max(1, floor(n * 0.6)), n)
  disp <- stri_extract_last_regex(tail_txt, "(?:ante o exposto|isso posto|pelo exposto|diante do exposto|em face do exposto|assim sendo)[\\s\\S]{0,900}$", case_insensitive = TRUE)
  if (is.na(disp)) disp <- stri_sub(tail_txt, -900)
  has_dm <- stri_detect_regex(text, "danos? mora|extrapatrimonia", case_insensitive = TRUE)
  quantum_topic <- stri_detect_regex(text, "quantum|valor (?:da|de|arbitrad|fixad)|irris[óo]ri|exorbitant|major|minor|reduz", case_insensitive = TRUE)
  s7 <- stri_detect_regex(text, .re_s7, case_insensitive = TRUE)
  chg_up   <- stri_detect_regex(disp, "(?:para )?(?:majorar|elevar|aumentar|fixar)[\\s\\S]{0,120}(?:danos? mora|indeniza|compensa|quantum)|majora(?:r|do|ndo)[\\s\\S]{0,60}(?:danos? mora|indeniza|quantum)", case_insensitive = TRUE)
  chg_down <- stri_detect_regex(disp, "(?:para )?(?:reduzir|minorar|diminuir|decotar)[\\s\\S]{0,120}(?:danos? mora|indeniza|compensa|quantum)|reduz(?:ir|ido|indo)[\\s\\S]{0,60}(?:danos? mora|indeniza|quantum)", case_insensitive = TRUE)
  denied   <- stri_detect_regex(disp, "nego (?:seguimento|provimento)|n[ãa]o conhe[çc]o|conhe[çc]o do agravo para n[ãa]o conhecer|nego conhecimento|desprov", case_insensitive = TRUE)
  granted  <- stri_detect_regex(disp, "dou (?:parcial )?provimento|conhe[çc]o do (?:agravo|recurso) para dar", case_insensitive = TRUE)
  outcome <- if (!has_dm) "sem_dano_moral" else if (chg_up && !chg_down) "majorado_stj" else if (chg_down && !chg_up) "reduzido_stj" else
    if (chg_up && chg_down) "ambiguo" else if (granted && quantum_topic) "provido_verificar" else
    if (denied && quantum_topic && s7) "mantido_sumula7" else if (denied && quantum_topic) "mantido" else
    if (denied) "nao_provido_sem_quantum" else "indeterminado"
  tibble(outcome = outcome, sumula7 = s7, quantum_topic = quantum_topic, dispositivo = stri_sub(disp, 1, 400))
}
