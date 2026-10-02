# RETOMAR AQUI — STJ (estado em 02/10/2026)

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

## PENDENTE (trabalho do autor)
1. Copiar a planilha da IA para `data/annotations/w3_valores_VG_IA.csv` (intocada) e para `w3_valores_VG.csv` (trabalho).
2. Revisar as 300 linhas: primeiro as 15 de confiança baixa, depois os 8 erros do extrator (V051, V125, V234, V267,
   V277, V118, V293, V172), depois média e alta; aplicar Q11 em V030/V059/V079/V090/V120 e Q12 em V005/V072/V077/V110/V195.
3. Planilha de documentos D001–D150 (pré-anotação por IA possível se o autor enviar os textos D*).
4. `Rscript scripts/04_validity_metrics.R` → `docs/07_extraction_validity.md` (gate da Semana 3).
5. Re-anotação cega (45 + 25) ≥ 7 dias após a revisão, sem sugestões.
