# 04 — Arquitetura e cronograma

## Decisão de linguagem: somente R (+ SQL via DuckDB)
Checagem pedida ("só R ou só Python?"): o pipeline inteiro cabe em R sem perda relevante e coincide com a decisão de 04/09/2026 (artigo 1 = R-only).
| Etapa | R (adotado) | Observação |
|---|---|---|
| Download/inventário | `httr2`, `jsonlite`, `digest` | feito (scripts 00/01) |
| Parsing/normalização | `stringi`, `jsonlite`, `readr` | deriva de esquema tratada |
| Extração monetária | `stringi` (ICU regex) | piloto feito; F1 a medir |
| Classificação temática | regex + TPU; opcional `text2vec`/`udpipe` (instalar) | embeddings só se a regra não bastar |
| Banco | `duckdb` + `DBI` (`sql/schema.sql`) | PostgreSQL/pgvector desnecessário |
| Inferência | `quantreg`, `fixest`, `brms`(instalar)+`rstan`, `mgcv`, `strucchange`, `survival` | brms exige toolchain Rtools/cmdstan — verificar |
| Preditivo | `tidymodels` + `xgboost` (`ranger`, `lightgbm` a instalar); conformal via `probably` (instalar) ou implementação split-conformal própria | SHAP via `shapviz`/`treeshap` (instalar) |
| Artigo | Quarto 1.9 + `modelsummary` + `ggplot2` | inglês |
Único ponto em que Python seria mais forte: embeddings de transformers para classificação temática. Só será considerado se a classificação por regra+TPU tiver concordância < 0,90 na anotação, e ainda assim via `reticulate` isolado, sem entrar no pipeline principal.

## Camadas
```
CKAN/SIDRA/CNJ ──(00/01 download, hash)──▶ data/raw (imutável)
      │
      ▼ (02 ingest: R/build_*.R)          DuckDB: raw.*, stg.documents, stg.document_text, stg.document_subjects, stg.cases
      ▼ (03 extract: R/extract_*.R)       stg.money_candidates, stg.document_topics
      ▼ (04 consistency + annotation)     stg.award_events, ann.*  ──▶ docs/07_extraction_validity.md (P/R/F1)
      ▼ (05 analytic dataset)             data/processed/awards.parquet (deflacionado pelo IPCA)
      ▼ (06–10 models)                    res.model_runs + figuras/tabelas (targets)
      ▼ (11 paper)                        paper/*.qmd (Quarto) + apêndice jurídico + data/model cards
```
`_targets.R` orquestra; cada alvo grava `git_commit` e `seed` em `res.model_runs`.

## Uso do RStudio
- **Console**: `source()` de funções, `extract_money()` em um documento, consultas DuckDB pequenas.
- **Background Jobs**: `scripts/02_ingest_full.R`, `scripts/03_*`, `targets::tar_make()`, `brms`.
- **Terminal**: `git`, `renv::restore()`, `Rscript scripts/01_download_sample.R`, agendamento do snapshot diário do acervo.

## Cronograma (pesquisador único; semanas corridas)
| Semana | Entrega | Critério de saída |
|---|---|---|
| 1 (08–12/09) | Aprovação do protocolo; carga completa dos **metadados** (≈2 GB); contagem exata por assunto/classe/ano; agendar snapshot diário do acervo | tabela de matérias com N exato |
| 2 | Download dos ZIPs dos dias necessários (matéria principal + controle); ingestão no DuckDB; testes | `stg.documents` completa, hashes |
| 3 | Anotação manual: 300 candidatos (P/R/F1 por campo) + 150 documentos (evento decisório completo); iteração do extrator | F1 ≥ 0,90 em categoria; ≥ 0,85 em estágio; relatório de validade |
| 4 | Regras de consistência; `award_events`; deflação IPCA; data card | dataset analítico congelado (v1) |
| 5 | Descritivas; regressão quantílica; two-part | tabelas/figuras RQ1, RQ3 |
| 6 | Hierárquico bayesiano (tribunal, ministro/órgão, ano); decomposição de variância; seleção (docs com/sem origem) | RQ2, RQ4 |
| 7 | Séries/quebras (strucchange); evento Tema 1365 (matéria de controle) como estudo de caso; sobrevivência só se datas confiáveis | RQ5 |
| 8 | Preditivo (xgboost/RF) com validação temporal e por tribunal; conformal; SHAP; model card | RQ6 |
| 9 | Robustez; limitações; apêndice jurídico | docs 11, 13, 15 |
| 10–11 | Artigo em inglês (Quarto), revisão | draft completo |
Gate obrigatório: nada da semana 5 em diante começa sem o relatório da semana 3.

## Riscos
1. Cobertura de UF/origem parcial (≈40% pelo texto no histórico; ≈90% prospectivo) → RQ2 com subamostra + teste de seleção.
2. Baixa taxa de alteração do quantum pelo STJ (0,2% majorado, 0 reduzido nos 1.381 docs-amostra) → RQ4 exigirá corpus completo e possivelmente agregação plurianual; two-part indispensável.
3. Formato 2023 sem caminho de assunto → filtro por folha e regex; medir concordância.
4. `brms` não instalado; compilação Stan no Windows depende de Rtools 4.4 — testar na semana 2.
