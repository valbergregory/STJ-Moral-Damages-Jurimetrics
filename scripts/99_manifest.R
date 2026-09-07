# 99_manifest.R — manifesto dos dados brutos: arquivo, conjunto, URL de origem, licença, tamanho, SHA-256, data de download.
# Saída: data/raw/MANIFEST.csv (versionado). Rodar após qualquer download.
suppressPackageStartupMessages({ library(dplyr); library(readr); library(digest); library(stringi); library(purrr); library(tibble) })
root <- Sys.getenv("STJMD_ROOT", unset = ".")
inv <- tryCatch(read_csv(file.path(root, "data/interim/ckan_inventory.csv"), show_col_types = FALSE), error = function(e) NULL)
files <- list.files(file.path(root, "data/raw"), recursive = TRUE, full.names = TRUE)
files <- files[!grepl("MANIFEST\\.csv$|CHECKSUMS", files)]
man <- tibble(path = stri_replace_first_fixed(files, paste0(root, "/"), ""), file = basename(files),
              size_bytes = file.size(files), downloaded_at = format(file.mtime(files), "%Y-%m-%d %H:%M"),
              sha256 = map_chr(files, ~ digest(.x, algo = "sha256", file = TRUE))) |>
  mutate(dataset = case_when(
    grepl("stj_integras", path) ~ "STJ — Íntegras de decisões terminativas e acórdãos do DJ",
    grepl("stj_tramitando", path) ~ "STJ — Acervo em tramitação",
    grepl("stj_precedentes", path) ~ "STJ — Precedentes qualificados",
    grepl("stj_espelhos", path) ~ "STJ — Espelhos de acórdãos",
    grepl("ckan/", path) ~ "STJ — CKAN package_show",
    grepl("ipca", path) ~ "IBGE/SIDRA — IPCA (tabela 1737, var. 2266)",
    grepl("cnj_assuntos", path) ~ "CNJ — TPU assuntos",
    grepl("dicionario-tramitando", path) ~ "STJ — dicionário do acervo em tramitação",
    TRUE ~ "outro"),
    license = case_when(grepl("^STJ", dataset) ~ "CC BY (STJ Dados Abertos)", grepl("IBGE", dataset) ~ "dados públicos IBGE",
                        grepl("CNJ", dataset) ~ "dados públicos CNJ", TRUE ~ NA_character_))
# URL: casa por nome de arquivo com o inventário CKAN (textosAAAAMMDD.zip / metadadosAAAAMMDD.json)
if (!is.null(inv)) {
  inv2 <- inv |> mutate(fname = case_when(format == "ZIP" ~ sprintf("textos%s.zip", key), format == "JSON" & !is.na(key) ~ sprintf("metadados%s.json", key),
                                          TRUE ~ resource_name)) |> arrange(desc(last_modified)) |> distinct(fname, .keep_all = TRUE) |> select(fname, url)
  man <- man |> left_join(inv2, by = c("file" = "fname"))
} else man$url <- NA_character_
ck <- grepl("ckan/package_show_", man$path)
man$url[ck] <- paste0("https://dadosabertos.web.stj.jus.br/api/3/action/package_show?id=",
                      stri_replace_all_regex(man$file[ck], "^package_show_|_\\d{8}\\.json$", ""))
man$url[grepl("ipca", man$path)] <- "https://apisidra.ibge.gov.br/values/t/1737/n1/all/v/2266/p/all/d/v2266%2013"
man$url[grepl("cnj_assuntos", man$path)] <- "https://dpj.cnj.jus.br/sgt/api/v1.0/assuntos.csv"
write_csv(man |> select(dataset, path, file, url, license, size_bytes, sha256, downloaded_at), file.path(root, "data/raw/MANIFEST.csv"))
cat("MANIFEST:", nrow(man), "arquivos;", round(sum(man$size_bytes) / 1e6), "MB\n")
