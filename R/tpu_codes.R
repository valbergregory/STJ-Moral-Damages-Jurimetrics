# tpu_codes.R — utilitários da Tabela Processual Unificada (TPU/CNJ) de assuntos: cadeia de ancestrais e
# pertencimento a uma família de códigos. Motivo: os metadados do STJ registram ora o caminho completo
# (2021, 2026), ora só códigos-folha (2022–2023), ora UM único código por documento (2024–2025). Selecionar
# "dano moral" apenas pelo código pai (7779, 10433, 9992...) perde os documentos registrados só pelo filho
# (ex.: 6226 inclusão indevida em cadastro, 7781 protesto indevido, 10435 acidente de trânsito).
suppressPackageStartupMessages({ library(readr); library(dplyr); library(stringi) })

load_tpu <- function(path = "data/raw/cnj_assuntos.csv") {
  raw <- readBin(path, "raw", file.size(path))
  txt <- tryCatch(rawToChar(raw), error = function(e) NA)
  txt <- if (!is.na(txt) && validUTF8(txt)) txt else iconv(rawToChar(raw), "latin1", "UTF-8")
  tpu <- read_delim(I(txt), delim = ";", show_col_types = FALSE, col_types = cols(.default = "c"))
  tpu |> transmute(codigo = as.integer(codigo), descricao = stri_trim_both(descricao),
                   cod_pai = suppressWarnings(as.integer(sub("\\.0$", "", cod_pai))), nivel = as.integer(nivel), situacao)
}

# vetor nomeado código -> pai
tpu_parent_map <- function(tpu) setNames(tpu$cod_pai, tpu$codigo)

# ancestrais (inclusive o próprio código), como inteiros
tpu_ancestors <- function(code, parent) {
  code <- suppressWarnings(as.integer(code)); if (is.na(code)) return(integer(0))
  out <- code; cur <- code
  for (i in 1:12) { p <- parent[as.character(cur)]; if (is.null(p) || is.na(p) || p == 0) break; out <- c(out, unname(p)); cur <- unname(p) }
  out
}

# TRUE se algum código da lista (string "a;b;c") pertence à família (o próprio ou descendente) de `roots`
in_tpu_family <- function(codes_str, roots, parent) {
  roots <- as.integer(roots)
  vapply(codes_str, function(s) {
    if (is.na(s) || s == "") return(FALSE)
    cs <- stri_split_fixed(s, ";")[[1]]
    any(vapply(cs, function(c) any(tpu_ancestors(c, parent) %in% roots), logical(1)))
  }, logical(1), USE.NAMES = FALSE)
}

# famílias usadas no projeto (raízes)
TPU_FAMILIES <- list(
  dano_moral        = c(7779, 10433, 9992, 14010, 14033, 1855, 13195, 14011, 15301),
  negativacao       = c(6226),
  protesto_indevido = c(7781, 14170, 14156),
  plano_saude       = c(6233, 12486),
  acidente_transito = c(10435, 9996, 10504, 10441),
  consumidor_rf     = c(7779),
  civil_rc          = c(10433),
  adm_rc            = c(9992)
)
