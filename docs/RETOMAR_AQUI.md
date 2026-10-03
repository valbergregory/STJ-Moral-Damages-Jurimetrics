# RETOMAR AQUI — STJ (estado em 03/10/2026)

## Onde está
- Pasta local: `D:\Claude code - projetos\STJ-Moral-Damages-Jurimetrics` (sem `.Rproj` versionado:
  criar com File → New Project → Existing Directory). R 4.4.3: `"/c/Program Files/R/R-4.4.3/bin/Rscript.exe"`.
- Banco: `data/stjmd.duckdb` (só na máquina do autor).

## Feito em 02/10
1. Matéria aprovada: negativação (TPU 6226) + controle plano de saúde (decisions_log).
2. Q1–Q9 da anotação decididas (COMO_ANOTAR.md §9; gate = F1 da classe dano_moral).
3. Sorteio da Semana 3 rodado: 300 valores (53 estratos) + 150 documentos (70 estratos) + re-anotação 45+25;
   425 textos em `data/annotations/w3_textos/`. Correção do `on.exit` no `08_annotation_sample.R`.
4. **Pré-anotação por IA dos 300 valores** entregue ao autor fora do repositório
   (`w3_valores_VG_preanotado_IA.csv`; nota `IA[alta|media|baixa]: ...`). Achado: o extrator lê
   "R$ X mil" como R$ X,00 (V051, V125, V234, V267, V277) e erra extensos parciais (V118, V293) e
   "2,5 salários" (V172).

## Decidido em 02/10 (tarde)
- Desenho "IA sugere, pesquisador decide" **aprovado** (COMO_ANOTAR.md Q10); convenções Q11 (ementa repetida) e
  Q12 (DM após sentença improcedente → `aumento`) **adotadas**.

## Decidido/feito em 02/10 (noite)
- Q13–Q17 aprovadas (COMO_ANOTAR.md §9). Implementado em R: `R/annotation_vocab.R`, `scripts/09_check_annotation.R`,
  `04_validity_metrics.R` (Q13 + seção E, taxa IA → final), testes. Protocolo da IA: `docs/ia_preanotacao_protocolo.md`.
- Pré-anotação dos documentos D001–D150 entregue ao autor (fora do Git): `w3_documentos_VG_preanotado_IA.csv`,
  harmonizada por Q13–Q17, 0 erro no verificador; 8 de confiança baixa (D023, D024, D065, D078, D080, D090, D110, D129).

## Feito em 03/10 — correção do extrator (`R/extract_money.R`, commit `cac0dcb`)
- "R$ 20 mil" / "R$ 1,5 milhão" agora são multiplicados (antes lidos como R$ 20,00 / 1,50): V051, V125, V234, V267, V277.
- Extenso com vírgula ("trinta mil, duzentos e cinquenta reais") não é mais lido só pela cauda (250 → 30.250):
  causa provável de V118 e V293 (hipótese; os textos não estão no repositório).
- Salário mínimo: aceita decimal ("2,5") e "dois e meio"; a quantidade deixa de ser capturada como a palavra anterior
  ("fixou"): V172. Salário mínimo continua sem conversão (COMO_ANOTAR.md).
- Testes de regressão em `tests/testthat/test-extract_money.R` (174 passam). Rodar com `LC_ALL=C.UTF-8` fora do Windows.
- **Ainda não reextraído:** o banco e as planilhas do autor refletem o extrator antigo.

## Plano de estimação (03/10) — `docs/10_estimation_plan.md` **v1.0 aprovado**
Decisões do §9 adotadas (deflator dez/2025, resposta `valor_acordao_origem`, `brms` com fallback, RQ4 descritiva se N
pequeno, Tema 1365 mantido, PJ excluída). Em aberto só a posição da RQ6 (corpo × apêndice). Scripts 10–17 podem ser
escritos em fixtures sintéticas; **rodar sobre dados reais só após o G1** (`docs/07_extraction_validity.md`).

## Código novo (03/10) — base da Semana 4, ainda sem dados reais
- `R/awards_rules.R`: regras de consistência (docs/02), `award_events`, revisão sobreposta, deflação IPCA, atrito.
- `R/feasibility.R` + `scripts/10_feasibility.R`: gate G4 (contagens por modelo, ambiente R, teste do Stan opcional).
  Gera `docs/10a_feasibility_report.md` (só contagens). Rodar na sua máquina: `Rscript scripts/10_feasibility.R --stan-test`.
- Testes sintéticos (261 passam). Não pude rodar o script contra o banco (sem `duckdb` aqui): validei a cadeia
  texto → extrator → eventos → relatório com dados sintéticos; o trecho de leitura do DuckDB só roda na sua máquina.
- Lacunas conhecidas: `autor_pj` não é extraído (PJ não é excluída ainda); a data de fixação na origem não é extraída
  (deflação usa a publicação do STJ); limiares de viabilidade `min_month_n`, `min_court_n` etc. são propostos.

## PENDENTE (trabalho do autor)
0. `git pull`, rodar `Rscript scripts/07_ingest_texts.R` e conferir V051, V118, V125, V172, V234, V267, V277, V293
   (se algum seguir errado, mandar o trecho do texto). A reextração muda os valores candidatos: se a revisão das
   planilhas já começou, comparar a coluna lida pelo extrator antes de seguir.
1. Salvar as planilhas da IA intocadas como `data/annotations/w3_valores_VG_IA.csv` e `w3_documentos_VG_IA.csv`;
   trabalhar nas cópias `w3_valores_VG.csv` e `w3_documentos_VG.csv`.
2. Revisar valores (15 baixa → 8 erros do extrator → Q11/Q12 → média → alta) e documentos (8 baixa → linhas com
   "Q14 ... conferir" → DÚVIDA → resto).
3. Ao fim de cada sessão: `Rscript scripts/09_check_annotation.R`.
4. `Rscript scripts/04_validity_metrics.R` → `docs/07_extraction_validity.md` (gate da Semana 3 + seção E).
5. Re-anotação cega (45 + 25) ≥ 7 dias após a revisão, sem sugestões.
