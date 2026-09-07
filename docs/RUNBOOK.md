# RUNBOOK — ordem de execução (RStudio, Windows)

Convenções: **[Terminal]** = aba Terminal do RStudio (Git, downloads, Rscript); **[Job]** = Background Job
(Jobs → Start Local Job → selecionar o script, working directory = raiz do projeto); **[Console]** = checagens rápidas.
Antes de tudo: abrir o projeto na raiz e rodar `renv::restore()` no Console (uma vez; ~5–15 min na primeira instalação).
Rscript: `"C:\Program Files\R\R-4.4.3\bin\Rscript.exe"`. Variável opcional `STJMD_ROOT` = raiz do projeto quando rodar de fora.

| # | Passo | Como | Lê | Grava | Duração |
|---|---|---|---|---|---|
| 0 | Inventário do Portal de Dados Abertos do STJ (CKAN) | [Terminal] `Rscript scripts/00_inventory_ckan.R` | API CKAN | `data/raw/ckan/package_show_*.json`, `data/interim/ckan_inventory.csv` | 1–2 min |
| 1 | Baixar SÓ os dias-amostra | [Terminal] `Rscript scripts/01_download_sample.R` | `config/sample_days.txt`, inventário | `data/raw/stj_integras/sample/*.zip/*.json`, `CHECKSUMS.sha256`, `logs/download_sample.log` | 2–5 min (52 MB) |
| 1b | IPCA (SIDRA 1737/2266) | [Terminal] `Rscript R/fetch_ipca.R` | API SIDRA | `data/raw/ipca/ipca_*.csv` + `.meta.json` | < 1 min |
| 2 | Baixar TODOS os metadados diários (sem textos) | [Job] `scripts/02_download_metadata_all.R` | inventário | `data/raw/stj_integras/metadata/metadados*.json` (~1,7 GB), `CHECKSUMS.sha256`, `logs/download_metadata.log` | 1–3 h (1.300 arquivos; retomável) |
| 2b | Snapshot diário do acervo em tramitação | [Terminal] `Rscript scripts/02b_snapshot_tramitando.R` (agendar diariamente; ver abaixo) | CKAN | `data/raw/stj_tramitando/processos_tramitando_AAAAMMDD.json.gz` (77 MB/dia) | 2–5 min |
| 3 | Corpus-amostra normalizado | [Job] `R/build_sample_corpus.R` | passo 1 | `data/interim/sample_all_docs.rds`, `sample_dm_corpus.rds` | 1–2 min |
| 4 | Piloto de extração monetária | [Job] `scripts/03_pilot_money_extraction.R` | passo 3 | `data/interim/pilot_*.csv`, `data/stjmd_pilot.duckdb`, `data/annotations/pilot_annotation_template.csv`, `logs/pilot_summary.txt` | ~1 min |
| 5 | Testes unitários | [Terminal] `Rscript -e "testthat::test_dir('tests/testthat')"` | `R/` | console | < 1 min |
| 6 | Anotação manual (pesquisador) | Excel/LibreOffice em `data/annotations/pilot_annotation_template.csv` → salvar como `pilot_annotation_<iniciais>.csv` | passo 4 | anotações | 2–4 h para 182 candidatos |
| 7 | Métricas de validade (P/R/F1 por campo) | [Terminal] `Rscript scripts/04_validity_metrics.R` (a escrever após o passo 6) | passo 6 | `docs/07_extraction_validity.md` | < 1 min |
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
