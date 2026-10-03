# RUNBOOK — ordem de execução (RStudio, Windows)

Convenções: **[Terminal]** = aba Terminal do RStudio (Git, downloads, Rscript); **[Job]** = Background Job
(Jobs → Start Local Job → selecionar o script, working directory = raiz do projeto); **[Console]** = checagens rápidas.
Antes de tudo: abrir o projeto na raiz e rodar `renv::restore()` no Console (uma vez; ~5–15 min na primeira instalação).
Rscript: `"C:\Program Files\R\R-4.4.3\bin\Rscript.exe"`. Variável opcional `STJMD_ROOT` = raiz do projeto quando rodar de fora.

> **Próximo passo (02/10/2026): matéria APROVADA** (negativação = principal; plano de saúde = controle; decisions_log).
> Começar a **Semana 3**: passos 5 → 5b → 6 → 7 abaixo, seguindo `docs/COMO_ANOTAR.md`. Os passos 0–2e já foram
> executados (Semanas 1–2); não é preciso refazê-los.

| # | Passo | Como | Lê | Grava | Duração |
|---|---|---|---|---|---|
| 0 | Inventário do Portal de Dados Abertos do STJ (CKAN) | [Terminal] `Rscript scripts/00_inventory_ckan.R` | API CKAN | `data/raw/ckan/package_show_*.json`, `data/interim/ckan_inventory.csv` | 1–2 min |
| 1 | Baixar SÓ os dias-amostra | [Terminal] `Rscript scripts/01_download_sample.R` | `config/sample_days.txt`, inventário | `data/raw/stj_integras/sample/*.zip/*.json`, `CHECKSUMS.sha256`, `logs/download_sample.log` | 2–5 min (52 MB) |
| 1b | IPCA (SIDRA 1737/2266) | [Terminal] `Rscript R/fetch_ipca.R` | API SIDRA | `data/raw/ipca/ipca_*.csv` + `.meta.json` | < 1 min |
| 2 | Baixar TODOS os metadados diários (sem textos) | [Job] `scripts/02_download_metadata_all.R` | inventário | `data/raw/stj_integras/metadata/metadados*.json` (~1,7 GB), `CHECKSUMS.sha256`, `logs/download_metadata.log` | 1–3 h (1.300 arquivos; retomável) |
| 2c | Censo exato dos metadados (parse dos 1.287 JSON → `stg.documents_meta`, flags por família TPU) | [Job] `scripts/05_metadata_census.R` (`--reparse` força novo parse) | passo 2, `data/raw/cnj_assuntos.csv` | `data/stjmd.duckdb` (`stg.documents_meta`), `data/interim/census_*.csv`, `docs/06_metadata_census.md` | ~30 min (parse) + 1 min |
| 2d | Baixar TODOS os ZIP de textos (11,4 GB; fev/2022 vem como recurso `202202.zip` sem formato — tratado) | [Job] `scripts/06_download_texts_all.R` (aceita intervalo de chaves: `... 20210101 20211231`) | inventário | `data/raw/stj_integras/texts/textos*.zip`, `CHECKSUMS.sha256`, `logs/download_texts.log` | 2–4 h (retomável) |
| 2e | **Ingestão dos textos selecionados + extração completa** (só os TXT dos docs cíveis da família "dano moral" ∩ matérias pedidas) | [Job] `scripts/07_ingest_texts.R` (`--families=negativacao,plano_saude` padrão; `--limit-zips=N` p/ teste; `--skip-extract`; `--only-extract`) | passos 2c e 2d | `stg.document_text`, `stg.ingest_log`, `stg.selected_docs`, `stg.money_candidates`, `stg.doc_outcomes`, `stg.doc_origin`; `data/interim/ingest_*.csv`, `full_*.csv`; `docs/08_text_ingest_report.md`; `data/annotations/full_doc_outcome_template.csv` + `full_amount_template.csv` | ~6 min (1.158 ZIPs) + ~25 min (32,6 k docs); idempotente |
| 2b | Snapshot diário do acervo em tramitação | [Terminal] `Rscript scripts/02b_snapshot_tramitando.R` (agendar diariamente; ver abaixo) | CKAN | `data/raw/stj_tramitando/processos_tramitando_AAAAMMDD.json.gz` (77 MB/dia) | 2–5 min |
| 3 | Corpus-amostra normalizado | [Job] `R/build_sample_corpus.R` | passo 1 | `data/interim/sample_all_docs.rds`, `sample_dm_corpus.rds` | 1–2 min |
| 4 | Piloto de extração monetária | [Job] `scripts/03_pilot_money_extraction.R` | passo 3 | `data/interim/pilot_*.csv`, `data/stjmd_pilot.duckdb`, `data/annotations/pilot_annotation_template.csv`, `logs/pilot_summary.txt` | ~1 min |
| 5 | Testes unitários | [Terminal] `Rscript -e "testthat::test_dir('tests/testthat')"` | `R/` | console | < 1 min |
| 5b | **Sorteio da amostra de anotação (Semana 3)**: 300 candidatos + 150 documentos + re-anotação cega 45 + 25, estratificado e semeado (seed 20261002) | [Job] `scripts/08_annotation_sample.R` (`--force` refaz o mesmo sorteio; recusa sobrescrever anotação) | passo 2e (`data/stjmd.duckdb`) | `data/annotations/w3_modelo_*.csv` (planilhas cegas), `w3_chave_*.csv` (predições/pesos), `w3_textos/*.txt`, `w3_amostra_estratos.csv`; `logs/annotation_sample.log` (só contagens) | ~5–15 min |
| 6 | Anotação manual (pesquisador) | Excel/LibreOffice: copiar `w3_modelo_valores.csv` → `w3_valores_<INI>.csv` e `w3_modelo_documentos.csv` → `w3_documentos_<INI>.csv`; ≥ 7 dias depois, as re-anotações (`w3_reanotacao_*_<INI>.csv`). Guia: **`docs/COMO_ANOTAR.md`**. (Templates antigos `pilot_annotation_template.csv` e `full_*_template.csv` ficam superados.) | passo 5b | anotações (não versionadas) | ≈ 23–35 h |
| 6b | Conferir as planilhas de anotação (vocabulário, valores, UF, coerência Q9/Q13/Q15) | [Terminal] `Rscript scripts/09_check_annotation.R` | passo 6 | console (lista de problemas por `item_id`; status 1 se houver erro) | < 1 min |
| 7 | Métricas de validade: P/R/F1 por campo (IC bootstrap, ponderado pelo desenho), valores por estágio no documento, kappa intra-anotador, gate | [Terminal] `Rscript scripts/04_validity_metrics.R` (aceita anotação parcial; lê também `pilot_annotation_<INI>.csv`) | passo 6b | `docs/07_extraction_validity.md`, `outputs/overleaf/tables/extraction_validity.tex` | < 1 min |
| 7b | **Viabilidade (gate G4 do plano, docs/10)**: eventos decisórios (`R/awards_rules.R`) + contagens por modelo (`R/feasibility.R`); só lê o banco, não estima nada. `--stan-test` tenta compilar um modelo Stan; `--reviewed=` e `--key=` sobrepõem a anotação (Q13–Q17) | [Terminal] `Rscript scripts/10_feasibility.R [--stan-test]` | `data/stjmd.duckdb` (passo 7 do 07) | `docs/10a_feasibility_report.md` (só contagens), `data/interim/award_events_v0.rds` (não versionado) | 1–5 min (+ minutos com `--stan-test`) |
| 8 | Manifesto de downloads (URL/data/SHA-256/licença) | [Terminal] `Rscript scripts/99_manifest.R` | `data/raw/` | `data/raw/MANIFEST.csv` | < 1 min |
| 9 | Exportação para o Overleaf | [Terminal] `Rscript scripts/90_export_overleaf.R` | `data/interim/`, resultados | `outputs/overleaf/{tables/*.tex, figures/*.pdf,*.png, numbers.tex}` | < 1 min |
| 10 | Pipeline completo | [Job] `targets::tar_make()` | tudo acima | `_targets/` | depende dos alvos ativos |

Passos ≥ 11 (dataset analítico, deflação, modelos) só entram no RUNBOOK depois do gate de validade (docs/07).

## Agendar o snapshot diário (Windows, Agendador de Tarefas)
No PowerShell **como usuário normal** (uma vez; substitua o caminho se o projeto estiver em outro lugar):
```powershell
$act = New-ScheduledTaskAction -Execute "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" -Argument "scripts/02b_snapshot_tramitando.R" -WorkingDirectory "D:\Claude code - projetos\STJ-Moral-Damages-Jurimetrics"
$trg = New-ScheduledTaskTrigger -Daily -At 07:30
Register-ScheduledTask -TaskName "STJ-tramitando-snapshot" -Action $act -Trigger $trg -Description "Arquiva o snapshot diário do acervo em tramitação do STJ"
```
O CKAN substitui o arquivo todo dia; sem esse agendamento a cobertura prospectiva de UF/origem se perde.

## Onde ver se deu certo
- `logs/download_metadata.log`: uma linha por arquivo com `ok=TRUE` e tamanho igual ao esperado.
- `logs/pilot_summary.txt`: contagens do piloto (não versionado, contém trechos de decisões).
- `data/raw/MANIFEST.csv`: todo arquivo bruto com hash.
- `logs/ingest_texts.log` (só contagens) e `docs/08_text_ingest_report.md`: cobertura de texto por matéria/ano e distribuição dos candidatos/desfechos.
