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
4. Convenções de anotação Q11–Q18 decididas pelo pesquisador (COMO_ANOTAR.md §9); verificador
   `scripts/09_check_annotation.R` e vocabulário único `R/annotation_vocab.R`.

## Decidido em 03/10 — anotação integralmente manual
- A pré-anotação automática (Q10) foi **revogada antes de qualquer uso**. A anotação é do pesquisador, a partir
  das planilhas em branco do sorteio; qualquer planilha com sugestões deve ser apagada da pasta `data/annotations/`.

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

## ATENÇÃO — extrator corrigido com base na própria amostra de validação (anotado em 03/10)
- O commit `cac0dcb` (outra sessão) corrigiu o extrator a partir dos erros achados **nos itens da amostra
  da Semana 3** (V051, V125, V234, V267, V277, V118, V293, V172). Pela regra já registrada em
  COMO_ANOTAR.md §7, as métricas desses mesmos itens deixam de validar o extrator **novo**.
- Leitura correta: a planilha da Semana 3 valida o extrator **antigo** (as chaves `w3_chave_*` foram
  congeladas no sorteio; a reextração não as altera).
- O extrator novo precisa de uma **amostra nova e menor**, com outra semente, depois da reextração
  (`08_annotation_sample.R --seed=<nova>`), antes de usar os valores no plano de estimação (G1).
- Duas sessões do Claude escreveram neste repositório no mesmo dia: usar **uma sessão por vez**.

## PENDENTE (trabalho do autor)
0. `git pull`. Apagar de `data/annotations/` qualquer planilha com sugestões (`*_IA.csv`, `*_preanotado*`) e a
   cópia de trabalho derivada delas (`w3_valores_VG.csv` / `w3_documentos_VG.csv`, se existirem).
1. Copiar `w3_modelo_valores.csv` → `w3_valores_VG.csv` e `w3_modelo_documentos.csv` → `w3_documentos_VG.csv`
   e anotar do zero (COMO_ANOTAR.md §§4–5 e §9).
2. Ao fim de cada sessão: `Rscript scripts/09_check_annotation.R`.
3. `Rscript scripts/04_validity_metrics.R` → `docs/07_extraction_validity.md` (gate da Semana 3; valida o extrator
   antigo — ver ATENÇÃO).
4. Re-anotação cega (45 + 25) ≥ 7 dias após a 1ª passada.
5. Amostra nova (outra semente) para validar o extrator corrigido, antes do G1.
