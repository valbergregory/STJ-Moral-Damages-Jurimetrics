# extract_origin.R — identifica o tribunal/UF de origem a partir do texto da decisão.
# Os metadados diários do STJ não trazem UF; a consulta processual pública está bloqueada por robots.txt
# (403) e o acervo em tramitação só cobre processos ainda pendentes. Logo, o texto é a fonte primária,
# com cobertura parcial que deve ser reportada (ver docs/01_source_audit.md).
suppressPackageStartupMessages({ library(stringi); library(dplyr); library(tibble); library(purrr) })

.uf_names <- c(
  "acre" = "AC", "alagoas" = "AL", "amazonas" = "AM", "amapa" = "AP", "bahia" = "BA", "ceara" = "CE",
  "distrito federal" = "DF", "espirito santo" = "ES", "goias" = "GO", "maranhao" = "MA", "minas gerais" = "MG",
  "mato grosso do sul" = "MS", "mato grosso" = "MT", "para" = "PA", "paraiba" = "PB", "pernambuco" = "PE",
  "piaui" = "PI", "parana" = "PR", "rio de janeiro" = "RJ", "rio grande do norte" = "RN", "rondonia" = "RO",
  "roraima" = "RR", "rio grande do sul" = "RS", "santa catarina" = "SC", "sergipe" = "SE", "sao paulo" = "SP",
  "tocantins" = "TO")
.uf_alt <- "AC|AL|AM|AP|BA|CE|DF|ES|GO|MA|MG|MS|MT|PA|PB|PE|PI|PR|RJ|RN|RO|RR|RS|SC|SE|SP|TO"
.name_alt <- paste(names(.uf_names)[order(-nchar(names(.uf_names)))], collapse = "|")

.re_tj_name <- paste0("tribunal de justica (?:do|de|da)?\\s?(?:estado (?:do|de|da)\\s?)?(", .name_alt, ")(?:\\s?e (?:dos )?territorios)?")
.re_tj_sigla <- paste0("\\bTJ[/-]?(", .uf_alt, ")\\b|\\b(TJDFT?)\\b")
.re_trf <- "tribunal regional federal da (\\d)|\\bTRF[/-]?(\\d)\\b"
.re_trt <- "tribunal regional do trabalho|\\bTRT\\b"
.re_cnj <- "\\b(\\d{7})-?(\\d{2})\\.?(\\d{4})\\.?(\\d)\\.?(\\d{2})\\.?(\\d{4})\\b"

# mapa J.TR -> tribunal (segmento 8 = Justiça Estadual; 4 = Federal; 5 = Trabalho)
.tr_estadual <- c("01" = "AC", "02" = "AL", "03" = "AP", "04" = "AM", "05" = "BA", "06" = "CE", "07" = "DF", "08" = "ES",
  "09" = "GO", "10" = "MA", "11" = "MT", "12" = "MS", "13" = "MG", "14" = "PA", "15" = "PB", "16" = "PR", "17" = "PE",
  "18" = "PI", "19" = "RJ", "20" = "RN", "21" = "RS", "22" = "RO", "23" = "RR", "24" = "SC", "25" = "SE", "26" = "SP", "27" = "TO")

extract_origin_court <- function(text) {
  t <- stri_trans_general(text, "Latin-ASCII")
  # 1) primeiro trecho narrativo ("contra acórdão do Tribunal de Justiça ..."): prioriza as primeiras 3000 chars
  head <- stri_sub(t, 1, 3000)
  pick <- function(txt) {
    m <- stri_match_first_regex(txt, .re_tj_name, case_insensitive = TRUE)
    if (!is.na(m[1, 2])) return(list(tipo = "TJ", uf = unname(.uf_names[tolower(stri_trim_both(m[1, 2]))]), evid = m[1, 1]))
    m <- stri_match_first_regex(txt, .re_tj_sigla)
    if (!is.na(m[1, 1])) return(list(tipo = "TJ", uf = if (!is.na(m[1, 2])) m[1, 2] else "DF", evid = m[1, 1]))
    m <- stri_match_first_regex(txt, .re_trf, case_insensitive = TRUE)
    if (!is.na(m[1, 1])) return(list(tipo = "TRF", uf = paste0("TRF", coalesce(m[1, 2], m[1, 3])), evid = m[1, 1]))
    if (stri_detect_regex(txt, .re_trt, case_insensitive = TRUE)) return(list(tipo = "TRT", uf = "TRT", evid = "TRT"))
    NULL
  }
  r <- pick(head); src <- "texto_inicio"
  if (is.null(r)) { r <- pick(t); src <- "texto_geral" }
  if (is.null(r)) {
    m <- stri_match_first_regex(t, .re_cnj)
    if (!is.na(m[1, 1])) {
      j <- m[1, 5]; tr <- m[1, 6]
      uf <- if (j == "8") unname(.tr_estadual[tr]) else if (j == "4") paste0("TRF", as.integer(tr)) else if (j == "5") paste0("TRT", as.integer(tr)) else NA
      if (!is.na(uf)) { r <- list(tipo = if (j == "8") "TJ" else if (j == "4") "TRF" else "TRT", uf = uf, evid = m[1, 1]); src <- "numero_cnj" }
    }
  }
  if (is.null(r)) return(tibble(origem_tipo = NA_character_, origem_uf = NA_character_, origem_evidencia = NA_character_, origem_fonte = NA_character_))
  tibble(origem_tipo = r$tipo, origem_uf = r$uf, origem_evidencia = r$evid, origem_fonte = src)
}
