# 05 — Relatório do piloto de extração monetária (05/09/2026)

Script: `scripts/03_pilot_money_extraction.R` (log completo em `logs/pilot_summary.txt`; saídas em `data/interim/pilot_*.csv` e `data/stjmd_pilot.duckdb`). Extrator: `R/extract_money.R` (versão piloto 0.2, após correção de prioridade do rótulo que antecede o valor e sinalizador de valor de referência). Testes unitários: 18/18 passando.

## Cobertura
| Métrica | Valor |
|---|---|
| Docs de danos morais processados | 1.381 (≥ 100 exigidos) |
| Docs com ≥ 1 expressão monetária | 281 |
| Candidatos extraídos | 868 (746 cifras "R$", 85 por extenso isolado, 3 "N mil reais", 34 salários mínimos) |
| Cifra + extenso entre parênteses casados | 361; **16 divergências** cifra≠extenso (sinalizadas para revisão) |
| Candidatos dentro de precedente citado | 71 (8%) — excluídos do uso |
| Candidatos dentro da ementa transcrita da origem | 122 — mantidos (são valores da origem) |
| Per capita sinalizado | 68 |
| Tempo | 54 s para 1.381 docs (≈ 25 docs/s) ⇒ corpus completo de danos morais (≈270 mil docs) em ≈ 3 h |

## Classificação (fora de precedente)
dano_moral 352 · contrato_divida 156 · honorarios 103 · indeterminado 69 · dano_material 59 · multa 32 · valor_causa 16 · custas 4 · dano_estetico 4 · conjunto moral+material 1 · limite procedimental 1.

Estágio × direção dos candidatos `dano_moral`: origem_acordao 85, origem_sentenca 67, stj 66, pedido 39, indeterminado 95. **167 docs** têm ao menos um valor de dano moral fora de precedente; por estágio, 7–9 docs em cada apresentam mais de um valor distinto (ambíguos → revisão).

Desfecho do STJ quanto ao quantum (por doc): mantido_sumula7 294 · mantido 93 · nao_provido_sem_quantum 111 · provido_verificar 25 · majorado_stj 3 · reduzido_stj 0 · indeterminado 263 · sem_dano_moral 592 (o regex de seleção por código TPU inclui docs que não discutem dano moral no texto).

Tribunal de origem pelo texto: identificado em **592 de 1.381 docs (43%)**: SP 168, RJ 41, MG 37, RS 34, TRF4 30, PR 29, GO 28, DF 26, … Fonte: início do texto (543), corpo (35), número CNJ (12).

## Checagem informal de precisão (feita por Claude, NÃO substitui a anotação do pesquisador)
Leitura de 40 contextos aleatórios da categoria `dano_moral` (versão 0.1): 36 corretos; 2 eram multa diária ("multa diária de R$ 45.000,00" — corrigido na 0.2 pela regra do rótulo antecedente); 1 era valor de "faixa" jurisprudencial (agora sinalizado `reference_value`); 1 era pedido de perda de uma chance (discutível: material). Estágio "indeterminado" em ~27% dos candidatos de dano moral — é o campo mais fraco e o foco da próxima iteração (ancorar em marcadores de seção: "Sentença:", "Acórdão:", "Trata-se", dispositivo).

## Amostra anotada
`data/annotations/pilot_annotation_template.csv` — 182 candidatos (≤15 por categoria predita + 60 aleatórios) com contexto e campos `true_*` em branco. **Precisão, recall e F1 por campo serão calculados somente após a anotação manual pelo pesquisador** (script `scripts/04_validity_metrics.R`, a escrever). Meta antes de qualquer estimação: F1 ≥ 0,90 (categoria), ≥ 0,85 (estágio), ≥ 0,90 (in_precedent), e concordância ≥ 0,90 na matéria.

## Problemas conhecidos
1. Valores por extenso sem cifra ("dez mil reais") só entram se a frase terminar em "reais"; centavos por extenso são ignorados.
2. Salários mínimos não são convertidos (exigem data-base e valor oficial do SM — tabela a incluir do Governo Federal/IPEA).
3. Cadeias "reduzida de R$ 20.000 (10.000 cada) para R$ 8.000 (4.000 cada)" produzem 4 candidatos; a consolidação por evento fica para a etapa de consistência + revisão.
4. `stj_quantum_outcome()` depende de localizar o dispositivo ("Ante o exposto…"); 263 docs ficaram indeterminados — em parte acórdãos (dispositivo no início) e decisões com dispositivo atípico.
