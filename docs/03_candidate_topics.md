# 03 — Matérias candidatas e recomendação (atualizado 08/09/2026 com o censo completo dos metadados)

Duas bases de evidência: (A) o **piloto textual** de 7 dias (16.938 documentos; 1.381 mencionam dano moral; 271 com valor em R$; 159 com valor de dano moral classificável fora de precedente) e (B) o **censo dos metadados completos** (`docs/06_metadata_census.md`: 3.482.383 documentos de 2021-01 a 2026-09; 247.420 na família TPU "dano moral", 242.293 em classes cíveis REsp/AREsp/EREsp/EAREsp).

## A. Contagens exatas por família TPU (docs de dano moral cíveis, por ano de publicação)
| Matéria (família TPU) | 2021 | 2022 | 2023 | 2024 | 2025 | 2026* | Total | Eventos com valor (estim. ≈1/3) |
|---|---|---|---|---|---|---|---|---|
| **Inscrição indevida em cadastro (6226)** | 2.108 | 2.377 | 2.299 | 3.300 | 3.397 | 2.699 | **16.180** | ≈ 5.000 |
| **Plano de saúde (6233, 12486)** | 4.157 | 3.771 | 2.594 | 2.410 | 2.279 | 1.305 | **16.516** | ≈ 5.000 |
| Acidente de trânsito (10435, 9996, 10504, 10441) | 3.892 | 3.749 | 3.263 | 3.864 | 4.407 | 3.471 | 22.646 | ≈ 7.000 (heterogêneo: morte × lesão) |
| Protesto indevido (7781, 14170, 14156) | 248 | 364 | 280 | 412 | 444 | 281 | 2.029 | ≈ 600 |
| Consumidor › Responsabilidade do Fornecedor (7779) | 11.414 | 13.117 | 10.889 | 12.908 | 14.344 | 10.417 | 73.089 | — |
| Civil › Responsabilidade Civil (10433) | 21.571 | 22.127 | 22.233 | 24.389 | 27.207 | 17.704 | 135.231 | — |
| Administrativo › Responsabilidade da Administração (9992) | 6.779 | 7.653 | 7.359 | 7.559 | 8.369 | 5.743 | 43.462 | — |
\* 2026 até 04/09. A fração "com valor" vem do piloto (271/1.381 docs com R$; 159/1.381 com valor de dano moral classificável) e será substituída pela contagem real após a extração sobre os textos completos.

## B. Triagem textual do piloto (1.381 docs de dano moral; regex; um doc pode cair em mais de uma matéria)
| Matéria | Docs DM | Docs com valor de DM | Homogeneidade factual | Evento normativo datado |
|---|---|---|---|---|
| Responsabilidade do Estado / servidor | 173 | 59 | baixa | — |
| Contexto penal (ruído; excluído por classe) | 171 | 41 | — | — |
| Morte / lesão / acidente | 136 | 55 | baixa | Tema 518 (2012) |
| Consignado / descontos indevidos | 129 | 21 | média-alta | Temas 1328/1435 pendentes |
| Energia / água / saneamento | 105 | 33 | média | Tema 1221 (2024) |
| Imobiliário (atraso na entrega) | 94 | 11 | média | Tema 971 |
| Plano de saúde | 84 | 19 | média-alta | **Tema 1365 (2026-03-20)** |
| Erro médico | 49 | 14 | baixa | — |
| Negativação | 45 | 16 | **alta** | Súmula 385/Tema 922 (2016); Tema 1315 (2026-03) |
| Ambiental / coletivo | 35 | 9 | baixa | Temas 681/707 |
| Honra / imagem / imprensa | 20 | 7 | média | Tema 1289 pendente |
| Telecom | 15 | 5 | média | Tema 954 sobrestado |
| Fraude bancária | 8 | 5 | média | — |
| Transporte aéreo | 3 | 0 | média | — |
Observação: a triagem textual subestimou a negativação (45 docs) em relação ao código TPU 6226 (o censo dá 2,1–3,4 mil docs/ano, ≈6,7% dos docs de dano moral cíveis), porque muitos textos de AREsp não conhecidos não descrevem o fato. A seleção final combinará código de família TPU **e** regex no texto, reportando a concordância.

## Recomendação (mantida e agora quantificada)
1. **Matéria principal: inscrição indevida em cadastro de inadimplentes (família TPU 6226)** — 16.180 documentos cíveis em 2021–2026, volume crescente, fato binário com dano presumido, dois precedentes qualificados datados (Tema 922/Súmula 385 em 2016; Tema 1315 em 2026-03) e faixa de valores estreita, o que deixa a heterogeneidade residual (tribunal de origem, órgão julgador, período) interpretável.
2. **Matéria de controle: negativa de cobertura por plano de saúde (6233/12486)** — 16.516 documentos, volume decrescente, e o **Tema 1365 (publicado 2026-03-20)** como evento normativo limpo para o estudo de quebra/efeito (RQ5), com a negativação como grupo não afetado.
3. Acidente de trânsito (22.646) fica como matéria de robustez apenas se for possível separar morte de lesão pelo texto; erro médico, responsabilidade do Estado e coletivos ficam fora do modelo principal.
4. Trabalhista: fora (competência do TST).

## Implicações para o desenho
- O STJ intervém raramente no quantum (piloto: 3 majorações, 0 reduções, 294 manutenções por Súmula 7 em 1.381 docs). Com ≈5 mil eventos com valor por matéria, espera-se algumas dezenas a poucas centenas de intervenções: suficiente para descrever, insuficiente para modelos ricos de RQ4 sem agregação. O artigo desta trilha (STJ) deve centrar-se no **controle do quantum pela Corte** (admissibilidade, Súmula 7, valores de origem como insumo) — ver decisão de 07/09 em `decisions_log.md`.
- Como parte relevante das negativações tramita em Juizados (sem acesso ao STJ), o corpus superrepresenta rito comum e valores maiores: declarar e medir (docs/02).
