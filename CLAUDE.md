# CLAUDE.md — Gatekeeping the Quantum (STJ moral-damages jurimetrics; título provisório desde 08/09/2026)

Projeto de artigo científico (jurimetria + análise econômica do Direito), escrito em inglês, sobre a
heterogeneidade das indenizações por danos morais nas decisões do STJ. Pesquisador único (Valber Gregory).
Conversa e documentação interna em pt-BR; artigo e código (nomes, comentários de API) em inglês quando exportados.

## Decisões fixas
- **Linguagem única: R** (decisão de 04/09/2026). SQL = DuckDB via pacote `duckdb`/`DBI` dentro do R. Sem Python no repositório.
  A inspeção inicial das fontes (05/09) usou Python ad hoc e foi descartada; tudo que fica é R.
- Meses fev–abr/2022 e jul/2022 existem só como arquivo mensal (chave AAAAMM); usar dataPublicacao do JSON.
- Fontes: somente oficiais e públicas (Portal de Dados Abertos do STJ, SIDRA/IBGE, TPU do CNJ). Sem Jusbrasil, sem scraping
  de `processo.stj.jus.br` (robots.txt bloqueia `/processo/` e responde 403). Não contornar CAPTCHA/bloqueios.
- Dados brutos imutáveis em `data/raw/` com SHA-256; nunca editar arquivo bruto; toda transformação vira nova tabela.
- Nenhuma expressão monetária vira "indenização" por padrão: candidatos recebem categoria/estágio/direção + sinalizadores e
  passam por regras de consistência e revisão manual (template em `data/annotations/`).
- Não fabricar fontes, números ou resultados. Quando o texto não permitir atribuir o valor a um estágio, marcar como ausente/ambíguo.
- Não avançar para estimações finais antes de: (i) relatório de validade da extração (P/R/F1 por campo, amostra anotada pelo
  pesquisador) e (ii) coerência jurídica da amostra temática.
- Git: commits só com autorização explícita do Valber. Repositório público em github.com/valbergregory/STJ-Moral-Damages-Jurimetrics
  (autorizado em 08/09/2026): nunca versionar dados com nomes de partes, logs do piloto, template de anotação preenchido ou segredos.

## Política de IA e reprodutibilidade (regra transversal do Valber, 05/09/2026 — docs/AI_POLICY_AND_REPRODUCIBILITY.md)
- Claude Code escreve código, testes, SQL, config, docs e RUNBOOK; **nunca escreve prosa do artigo**. `article/` contém só o
  esqueleto LaTeX (`main.tex` com `\input`, marcadores `% AUTHOR WRITES`, snippets de declaração de IA e disponibilidade de
  dados/código, `references.bib`). O Valber escreve o texto no Overleaf. Quarto foi substituído por LaTeX/Overleaf (08/09).
- `docs/RUNBOOK.md` numerado na ordem de execução; `scripts/90_export_overleaf.R` gera `outputs/overleaf/{tables/*.tex,
  figures/*.pdf+png, numbers.tex}` com `\newcommand` para cada número citado.
- `renv.lock` + `logs/sessionInfo_*.txt`; `data/raw/MANIFEST.csv` (URL/data/SHA-256/licença) via `scripts/99_manifest.R`;
  seeds fixas; testes com fixtures pequenas; CITATION.cff; LICENSE (MIT código / CC-BY texto); release + Zenodo antes da submissão.
- **Nenhum nome de parte, advogado ou magistrado em outputs, logs versionados ou commits**; relatores só em nível de órgão/turma
  nos resultados exportados (efeitos de relator, se estimados, ficam anonimizados por ID).
- Todo LLM usado como método (ex.: classificação temática) é instrumento de medida documentado: modelo, versão, prompts, seed,
  validação humana.

## Ambientes de execução (RStudio)
- **Console**: verificações pequenas (`source("R/extract_money.R"); extract_money(txt)`).
- **Background Jobs**: `scripts/0X_*.R` pesados e `targets::tar_make()`.
- **Terminal**: Git, `renv::restore()`, downloads (`Rscript scripts/01_download_sample.R`), DuckDB CLI se instalado.

## Estrutura
```
config/            sample_days.txt (dias-amostra), parâmetros
R/                 funções puras (extract_money.R, extract_origin.R, build_sample_corpus.R, fetch_ipca.R)
scripts/           00_inventory_ckan.R 01_download_sample.R 03_pilot_money_extraction.R ... (numerados, idempotentes)
sql/schema.sql     esquema DuckDB (raw/stg/ann/res)
tests/testthat/    testes unitários (Rscript -e 'testthat::test_dir("tests/testthat")')
data/raw           bruto imutável (+ CHECKSUMS.sha256)   data/interim  intermediário   data/processed  analítico
data/annotations   anotação manual                       logs/          logs e saídas de piloto
docs/              auditoria de fontes, protocolo, dicionário de dados, arquitetura, cronograma, RUNBOOK, política de IA, decisions_log
article/           esqueleto LaTeX (autor escreve no Overleaf)      outputs/overleaf  tabelas/figuras/numbers.tex gerados
_targets.R         pipeline
```

## Comandos úteis
- Testes: `Rscript -e "testthat::test_dir('tests/testthat')"`
- Piloto: `Rscript scripts/03_pilot_money_extraction.R` (lê `data/interim/sample_dm_corpus.rds`)
- Variável `STJMD_ROOT` aponta para a raiz quando rodar fora do diretório.
- Rscript em `C:\Program Files\R\R-4.4.3\bin\Rscript.exe`.

## Deriva de esquema conhecida (metadados diários)
- 2021: `SeqDocumento`, `NM_MINISTRO`, datas ISO, `tipoDocumento` sem acento, assuntos em caminhos "00287.03603.03607.03608., ...".
- 2022–2023: `seqDocumento`, `ministro`, datas em epoch-ms, `tipoDocumento` com acento, assuntos "10318;10318" (só folhas, `;`).
- 2024–2025: `dataDistribuição` (com acento); assuntos "6100, 9148, 6120" (só folhas, vírgula + espaço). 2026: volta ao caminho completo.
  Nomes dos TXT com/sem prefixo de pasta. Tudo tratado em `read_metadata_day()` (split por `[;,]`).
- **Seleção por assunto sempre por FAMÍLIA TPU** (código ou descendente, `R/tpu_codes.R`): 2022–2025 registram só folhas, então
  "dano moral" tem de incluir 6226, 7781, 10435 etc., não só os pais 7779/10433/9992.
- 2026-08-26: ZIP com 412 textos para 2.285 metadados (recurso parcial) — verificar antes de usar dias recentes.
