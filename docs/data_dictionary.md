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

## Anotação da Semana 3 (`data/annotations/w3_*`, não versionado; `scripts/08_annotation_sample.R`)
| Arquivo | Chave | Conteúdo |
|---|---|---|
| `w3_modelo_valores.csv` / `w3_valores_<INI>.csv` | `item_id` (V001…) | contexto do candidato + `true_valor_correto`, `true_category`, `true_stage`, `true_direction`, `true_in_precedent`, `true_reference_value`, `nota` |
| `w3_modelo_documentos.csv` / `w3_documentos_<INI>.csv` | `item_id` (D001…) | `true_materia`, `true_menciona_dano_moral`, `true_resultado_stj`, `true_valor_{pedido,sentenca,acordao_origem,stj}`, `true_per_capita`, `true_n_vitimas`, `true_origem_uf`, `true_incluir`, `true_motivo_exclusao`, `nota` |
| `w3_modelo_reanotacao_*.csv` | `item_id_reanot` (RV…/RD…) | mesmas colunas, itens re-sorteados com novos IDs (re-anotação cega) |
| `w3_chave_valores.csv` / `w3_chave_documentos.csv` | `item_id` | `seq_documento`, `stratum`, `N_h`, `n_h`, `w = N_h/n_h` (peso de desenho), predições `pred_*` do extrator v0.2 |
| `w3_chave_reanotacao_*.csv` | `item_id_reanot` → `item_id` | ligação re-anotação → 1ª passada |
Códigos e regras de preenchimento: `docs/COMO_ANOTAR.md`.
