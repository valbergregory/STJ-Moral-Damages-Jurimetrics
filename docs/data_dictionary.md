# Dicionário de dados (v0.1)

## Fonte: metadados diários do STJ → `stg.documents`
| Campo | Origem | Tipo | Regra |
|---|---|---|---|
| seq_documento | `SeqDocumento`/`seqDocumento` | int | = nome do TXT no ZIP |
| data_publicacao | `dataPublicacao` | date | ISO ou epoch-ms (2023) → `parse_stj_date()` |
| tipo_documento | `tipoDocumento` | chr | maiúsculas sem acento: DECISAO / ACORDAO |
| numero_registro | `numeroRegistro` | chr(12) | chave do processo no STJ; liga com acervo em tramitação |
| processo | `processo` | chr | "AREsp 1703858"; `classe` = prefixo alfabético |
| data_recebimento / data_distribuicao | idem (com/sem acento) | date | |
| ministro | `NM_MINISTRO`/`ministro` | chr | relator ou prolator |
| recurso | `recurso` | chr | AgInt/AgRg/EDcl/...; NULL = processo principal |
| teor | `teor` | chr | "Não Conhecendo", "Negando", "Concedendo", "Outros", "Admitindo Embargo" |
| assuntos_raw | `assuntos` | chr | texto original |
| assuntos_formato | derivado | chr | caminho_pontuado (2021, 2026) / leaf_lista (2022–2025; separador `;` até 2023 e `, ` em 2024–2025) |
| assuntos_leaf | derivado | chr | folhas únicas separadas por ";" (inteiros, sem zeros à esquerda); NA se vazio |
| dm_code, negativacao, plano_saude, protesto_indevido, acidente_transito, consumidor_rf, civil_rc, adm_rc | derivado (`R/tpu_codes.R`) | bool | pertencimento a uma família TPU (código raiz ou qualquer descendente) |
| classe_civel | derivado | bool | classe ∈ {REsp, AREsp, EREsp, EAREsp} |
| n_codigos | derivado | int | número de códigos-folha distintos no documento |

## `stg.money_candidates` (saída de `extract_money()`)
| Campo | Valores | Significado |
|---|---|---|
| form | cifra / escala / extenso / salario_minimo | forma textual: "R$ 25.000,00" / "25 mil reais" / "vinte e cinco mil reais" / "10 salários mínimos" |
| unit | BRL / SM | reais nominais / salários mínimos (sem conversão) |
| extenso_parenthetical / extenso_mismatch | bool | cifra seguida de "(por extenso)"; divergência entre os dois |
| category | dano_moral, dano_material, dano_estetico, moral_material_conjunto, honorarios, multa, custas, valor_causa, contrato_divida, limite_procedimental, indeterminado | rótulo mais próximo; rótulo que antecede o valor (≤45 chars) prevalece |
| stage | pedido / origem_sentenca / origem_acordao / stj / indeterminado | estágio processual inferido do contexto |
| direction | aumento / reducao / manutencao / indeterminado | verbo mais próximo na frase |
| in_precedent_quote | bool | valor dentro de ementa/precedente citado (segue "(REsp ..., DJe ...)") |
| in_origin_ementa | bool | valor dentro da ementa transcrita do acórdão de origem (após "assim ementado") |
| per_capita | bool | "para cada autor", "cada um" etc. |
| reference_value | bool | "faixa de", "casos semelhantes", "patamar" — valor de referência jurisprudencial, não do caso |
| cat_dist / stage_dist | int | distância (chars) ao rótulo usado; quanto maior, menor a confiança |

## `stj_quantum_outcome()` → `pilot_doc_outcomes`
| outcome | Regra |
|---|---|
| sem_dano_moral | texto não menciona dano moral/extrapatrimonial |
| majorado_stj / reduzido_stj | dispositivo contém "majorar/reduzir ... indenização/danos morais" |
| provido_verificar | provimento (parcial) com tema de quantum, sem verbo claro → revisão |
| mantido_sumula7 | recurso negado/não conhecido + tema de quantum + Súmula 7/reexame fático |
| mantido | recurso negado/não conhecido + tema de quantum, sem Súmula 7 |
| nao_provido_sem_quantum | negado/não conhecido sem discussão de valor |
| indeterminado | dispositivo não localizado |

## `extract_origin_court()`
`origem_tipo` (TJ/TRF/TRT), `origem_uf` (UF ou TRFn/TRT), `origem_fonte` (texto_inicio ≤3.000 chars; texto_geral; numero_cnj via J.TR do número unificado), `origem_evidencia` (trecho).
