# 08 — Ingestão dos textos completos e extração (Semana 2)

Gerado em 2026-09-12 por `scripts/07_ingest_texts.R` (famílias TPU: negativacao, plano_saude; extrator v0.2). Seleção = classes cíveis ∩ família "dano moral" ∩ famílias pedidas, a partir de `stg.documents_meta` (docs/06). A escolha da matéria principal/controle continua **aguardando aprovação** (docs/03); o script aceita `--families=` e apenas acrescenta documentos.

- Selecionados: **32501** documentos em 1158 chaves (dias/meses); com texto ingerido: **28238** (86.9%).
- ZIPs processados: 1158 (inexistentes: 2); textos não encontrados dentro dos ZIPs: 4265.

## Cobertura por matéria, ano e tipo de documento

|materia     |  ano| n_sel_ACORDAO| n_sel_DECISAO| n_txt_ACORDAO| n_txt_DECISAO|
|:-----------|----:|-------------:|-------------:|-------------:|-------------:|
|negativacao | 2021|           330|          1778|           330|          1763|
|negativacao | 2022|           392|          1985|           392|          1790|
|negativacao | 2023|           412|          1879|           408|          1727|
|negativacao | 2024|           654|          2646|           654|          2585|
|negativacao | 2025|           918|          2477|           860|          2308|
|negativacao | 2026|           886|          1813|           117|           603|
|plano_saude | 2021|          1111|          3046|          1111|          3015|
|plano_saude | 2022|          1133|          2615|          1133|          2404|
|plano_saude | 2023|           855|          1702|           847|          1558|
|plano_saude | 2024|           704|          1705|           703|          1689|
|plano_saude | 2025|           948|          1331|           889|          1240|
|plano_saude | 2026|           602|           703|            66|           149|

## Documentos com valor de dano moral extraído (fora de citação de precedente)

|materia     | n_txt| n_docs_valor_dm| n_docs_valor_stj|
|:-----------|-----:|---------------:|----------------:|
|negativacao | 13537|            1538|              643|
|plano_saude | 14804|            3344|             1212|

## Desfecho do STJ quanto ao quantum (classificador de dispositivo, NÃO validado)

|outcome                 |sumula7 | negativacao| plano_saude|
|:-----------------------|:-------|-----------:|-----------:|
|sem_dano_moral          |TRUE    |        4221|        3153|
|sem_dano_moral          |FALSE   |        4107|        2888|
|mantido_sumula7         |TRUE    |        2362|        3208|
|indeterminado           |TRUE    |        1052|        1958|
|mantido                 |FALSE   |         567|         980|
|indeterminado           |FALSE   |         443|        1250|
|nao_provido_sem_quantum |TRUE    |         340|         509|
|provido_verificar       |FALSE   |         175|         326|
|nao_provido_sem_quantum |FALSE   |         137|         271|
|provido_verificar       |TRUE    |         119|         247|
|majorado_stj            |TRUE    |           8|          10|
|majorado_stj            |FALSE   |           4|           1|
|reduzido_stj            |TRUE    |           2|           3|

## Candidatos monetários por categoria

|category                |     n| n_precedente|
|:-----------------------|-----:|------------:|
|dano_moral              | 12077|         1988|
|contrato_divida         |  3764|          145|
|multa                   |  1734|          151|
|indeterminado           |  1316|           85|
|honorarios              |  1209|           33|
|dano_material           |   835|            9|
|valor_causa             |   396|           40|
|custas                  |    61|            1|
|limite_procedimental    |    38|            1|
|dano_estetico           |    26|            3|
|moral_material_conjunto |    18|            1|

## Candidatos 'dano_moral' por estágio × direção

|stage           | manutencao| indeterminado| aumento| reducao|
|:---------------|----------:|-------------:|-------:|-------:|
|indeterminado   |        712|           610|     243|      97|
|origem_acordao  |       1022|          1071|     279|     161|
|origem_sentenca |        859|           960|     270|     154|
|pedido          |        259|           426|     145|      48|
|stj             |       1037|          1082|     415|     239|

## Cobertura do tribunal de origem

|origem_fonte | negativacao| plano_saude|
|:------------|-----------:|-----------:|
|(sem origem) |        8658|        7501|
|texto_inicio |        4150|        6117|
|texto_geral  |         658|        1122|
|numero_cnj   |          71|          65|

## Próximo passo

Anotação manual pelo pesquisador em `data/annotations/full_doc_outcome_template.csv` (desfecho) e `full_amount_template.csv` (valores); depois `scripts/04_validity_metrics.R` → docs/07_extraction_validity.md. Nenhum número acima é resultado do artigo antes desse gate.
