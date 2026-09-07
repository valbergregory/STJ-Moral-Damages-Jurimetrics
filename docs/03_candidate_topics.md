# 03 — Matérias candidatas e recomendação (piloto de 7 dias, 05/09/2026)

Base: 16.927 documentos dos dias-amostra (`config/sample_days.txt`); 1.381 mencionam dano moral no texto ou trazem código TPU de dano moral (8,2%); 271 desses contêm algum valor em R$ (19,6%); 167 têm ao menos um valor **classificado como dano moral** fora de citação de precedente (12,1%).

## Tabela de matérias (triagem por regex no texto, entre os 1.381 docs de danos morais)
| Matéria | Docs DM | Docs com valor de DM | Homogeneidade factual | Evento normativo datado | Viabilidade |
|---|---|---|---|---|---|
| Responsabilidade do Estado / servidor (heterogênea) | 173 | 59 | baixa | — | descartar como matéria única |
| Contexto penal (HC/crime; ruído) | 171 | 41 | — | — | excluir por classe |
| Morte / lesão / acidente | 136 | 55 | baixa (morte ≠ lesão leve) | Tema 518 (ferrovia, 2012) | possível só com subtipos |
| Consignado / descontos indevidos em benefício | 129 | 21 | média-alta | Temas 1328/1435 **pendentes** (2025–26) | boa, mas evento ainda não julgado |
| Energia / água / saneamento | 105 | 33 | média | Tema 1221 (juros, 2024) | possível |
| Imobiliário (atraso na entrega) | 94 | 11 | média | Tema 971 (lucros cessantes) | baixa taxa de valor |
| **Plano de saúde (negativa de cobertura)** | 84 | 19 | média-alta | **Tema 1365 (2026-03-20): recusa não gera dano in re ipsa** | **boa — matéria de controle/estudo de evento** |
| Erro médico | 49 | 14 | baixa (gravidade muito variável) | — | descartar |
| **Inscrição indevida em cadastro (negativação)** | 45 | 16 | **alta** (dano in re ipsa; fato padronizado) | Súmula 385/Tema 922 (2016); Tema 1315 (2026-03) | **boa — matéria principal** |
| Ambiental / coletivo | 35 | 9 | baixa | Temas 681/707 | excluir (fora da unidade individual) |
| Honra / imagem / imprensa | 20 | 7 | média | Tema 1289 pendente | volume baixo |
| Telecom | 15 | 5 | média | Tema 954 sobrestado | volume baixo no STJ |
| Fraude bancária | 8 | 5 | média | — | volume baixo (maioria fica no JEC) |
| Protesto indevido | 4 | 2 | alta | — | volume baixo |
| Transporte aéreo | 3 | 0 | média | — | inviável no STJ (JEC/CDC; raramente chega) |
Regexes em `scripts/03_pilot_money_extraction.R`; as contagens são de triagem (podem contar um doc em mais de uma matéria) e serão substituídas pela contagem exata sobre os metadados completos (Semana 1).

## Extrapolação de volume (ordem de grandeza, a confirmar)
≈300 docs/MB × 11,2 GB ≈ 3,3 M documentos (2021-01 → 2026-08). Aplicando as taxas da amostra: ≈270 mil docs de danos morais; negativação ≈ 3,3% ⇒ **≈ 9 mil docs**, dos quais ≈ 1/3 com valor extraível ⇒ **≈ 3 mil eventos com valor**; plano de saúde ≈ 6,1% ⇒ ≈ 16 mil docs, ≈ 3,7 mil com valor. Ambas suportam regressão quantílica e modelos hierárquicos por UF/ano; a análise "intervenção do STJ" (RQ4) terá poucos eventos positivos (na amostra: 3 majorações e 0 reduções em 1.381 docs) e dependerá do corpus completo.

## Recomendação
1. **Matéria principal: inscrição indevida em cadastro de inadimplentes** (TPU 6226 ou 7779 + regex), relação de consumo, autor pessoa natural. É a matéria mais homogênea (dano presumido, fato binário), tem literatura de referência, dois precedentes qualificados datados (Tema 922/Súmula 385; Tema 1315) e valores tipicamente em faixa estreita, o que torna a heterogeneidade residual (tribunal, ministro, período) interpretável.
2. **Matéria de controle: negativa de cobertura por plano de saúde**, para o estudo de evento em torno do Tema 1365 (RQ5/causal) — antes/depois com controle pela negativação (que não foi afetada pelo Tema).
3. **Não misturar** morte/lesão, erro médico, responsabilidade do Estado e coletivos no mesmo modelo; ficam para um apêndice descritivo, se tanto.
4. Trabalhista: fora (competência do TST; só aparece no STJ como conflito de competência).

## Riscos específicos da negativação
- Parte relevante dos casos vem de Juizados (Turmas Recursais) e **não chega ao STJ** (cabe apenas Reclamação/PUIL): a amostra do STJ superrepresenta casos de rito comum e valores maiores — declarar.
- Muitos AREsp "não conhecidos" pela Súmula 7 trazem o valor da origem na narrativa (útil para RQ1–RQ3), mas nenhuma decisão sobre o quantum (RQ4 limitada).
