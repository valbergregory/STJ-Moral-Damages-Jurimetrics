# build_sample_corpus.R — lê os dias-amostra baixados (ZIP de textos + JSON de metadados),
# normaliza a deriva de esquema entre anos e seleciona documentos de danos morais.
# Regras de normalização documentadas em docs/data_dictionary.md.
suppressPackageStartupMessages({
  library(jsonlite); library(dplyr); library(purrr); library(stringi); library(tibble); library(readr)
})

DM_CODES <- c("7779", "14010", "14033", "9992", "10433", "1855", "13195", "14011", "15301")
DM_TEXT_RE <- "dano[s]?\\s+mora(l|is)|dano[s]?\\s+extrapatrimonia(l|is)|compensa[çc][ãa]o\\s+por\\s+dano"

# converte campo de data (ISO "YYYY-MM-DD" ou epoch em ms) para Date
parse_stj_date <- function(x) {
  if (is.numeric(x)) return(as.Date(as.POSIXct(x / 1000, origin = "1970-01-01", tz = "America/Sao_Paulo")))
  as.Date(substr(as.character(x), 1, 10))
}

# normaliza nomes/valores dos metadados diários (2021: NM_MINISTRO/SeqDocumento; 2023: seqDocumento/ministro + epoch ms;
# 2025+: dataDistribuição com acento; tipoDocumento com/sem acento; assuntos em caminhos pontuados ou leaf ';')
read_metadata_day <- function(path) {
  d <- fromJSON(path, simplifyVector = TRUE) |> as_tibble()
  nm <- tolower(names(d)); nm <- stri_trans_general(nm, "Latin-ASCII")
  nm[nm == "nm_ministro"] <- "ministro"
  names(d) <- nm
  d |> transmute(
    seq_documento = as.integer(seqdocumento),
    data_publicacao = parse_stj_date(datapublicacao),
    tipo_documento = stri_trans_general(toupper(tipodocumento), "Latin-ASCII"),
    numero_registro = as.character(numeroregistro),
    processo = stri_trim_both(as.character(processo)),
    classe = stri_extract_first_regex(processo, "^[A-Za-z]+"),
    data_recebimento = parse_stj_date(datarecebimento),
    data_distribuicao = parse_stj_date(datadistribuicao),
    ministro = stri_trim_both(as.character(ministro)),
    recurso = na_if(stri_trim_both(as.character(recurso)), ""),
    teor = as.character(teor),
    descricao_monocratica = as.character(descricaomonocratica),
    assuntos_raw = as.character(assuntos),
    assuntos_formato = if_else(stri_detect_fixed(coalesce(assuntos_raw, ""), "."), "caminho_pontuado", "leaf_lista"),
    assuntos_leaf = map_chr(assuntos_raw, function(a) {
      if (is.na(a) || a == "") return(NA_character_)
      # formatos observados: 2021/2026 caminhos "00287.03603.03607.03608., 01209.07942." ; 2022–2023 folhas "10318;10318" ;
      # 2024–2025 folhas "6100, 9148, 6120" (vírgula + espaço)
      if (stri_detect_fixed(a, ".")) {
        paths <- stri_trim_both(stri_split_fixed(a, ",")[[1]]); paths <- paths[paths != ""]
        leaf <- map_chr(paths, ~ { cs <- stri_split_fixed(stri_replace_last_fixed(.x, ".", ""), ".")[[1]]; cs[length(cs)] })
      } else leaf <- stri_trim_both(stri_split_regex(a, "[;,]")[[1]])
      leaf <- suppressWarnings(as.integer(leaf)); leaf <- leaf[!is.na(leaf)]
      if (!length(leaf)) return(NA_character_)
      paste(unique(as.character(leaf)), collapse = ";")
    }),
    assuntos_paths = if_else(assuntos_formato == "caminho_pontuado", assuntos_raw, NA_character_),
    source_file = basename(path)
  )
}

read_texts_day <- function(zip_path, exdir) {
  dir.create(exdir, showWarnings = FALSE, recursive = TRUE)
  files <- utils::unzip(zip_path, exdir = exdir, junkpaths = TRUE)
  tibble(seq_documento = as.integer(stri_replace_all_regex(basename(files), "\\D", "")),
         text = map_chr(files, ~ read_file(.x)),
         zip_file = basename(zip_path))
}

build_sample_corpus <- function(sample_dir = "data/raw/stj_integras/sample",
                                exdir = file.path(tempdir(), "stj_txt"), out_dir = "data/interim") {
  metas <- list.files(sample_dir, "^metadados\\d{8}\\.json$", full.names = TRUE)
  zips  <- list.files(sample_dir, "^textos\\d{8}\\.zip$", full.names = TRUE)
  meta <- map_dfr(metas, read_metadata_day)
  txt  <- map_dfr(zips, ~ read_texts_day(.x, file.path(exdir, stri_extract_first_regex(basename(.x), "\\d{8}"))))
  docs <- txt |> left_join(meta, by = "seq_documento") |>
    mutate(nchar = nchar(text),
           dm_text = stri_detect_regex(text, DM_TEXT_RE, case_insensitive = TRUE),
           dm_code = map_lgl(assuntos_leaf, ~ !is.na(.x) && any(stri_split_fixed(.x, ";")[[1]] %in% DM_CODES)),
           has_brl = stri_detect_regex(text, "R\\$\\s?\\d"))
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  saveRDS(docs, file.path(out_dir, "sample_all_docs.rds"))
  dm <- filter(docs, dm_text | dm_code)
  saveRDS(dm, file.path(out_dir, "sample_dm_corpus.rds"))
  message(sprintf("docs: %d | meta matched: %d | dano moral (texto ou código): %d | com R$: %d",
                  nrow(docs), sum(!is.na(docs$tipo_documento)), nrow(dm), sum(dm$has_brl)))
  invisible(list(all = docs, dm = dm))
}

if (sys.nframe() == 0) build_sample_corpus()
