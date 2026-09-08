# 06 — Censo dos metadados completos

Gerado em 2026-09-07 por `scripts/05_metadata_census.R` (3482383 documentos; matérias por FAMÍLIA TPU, i.e. código ou qualquer descendente — ver `R/tpu_codes.R`).

## Documentos por ano e tipo

|  ano| ACORDAO| DECISAO|
|----:|-------:|-------:|
| 2021|  101142|  432088|
| 2022|  117010|  443127|
| 2023|  139541|  419671|
| 2024|  143703|  497235|
| 2025|  198480|  506807|
| 2026|  147051|  336528|

## Registro do campo de assuntos por ano (deriva de esquema)

|  ano|      n| caminho_pontuado| media_codigos| pct_um_codigo|
|----:|------:|----------------:|-------------:|-------------:|
| 2021| 533230|           533230|          1.89|          43.8|
| 2022| 560137|             1817|          1.71|          52.8|
| 2023| 559212|                0|          1.72|          53.8|
| 2024| 640938|                0|          1.78|          55.5|
| 2025| 705287|                0|          1.82|          54.2|
| 2026| 483579|           474854|          1.65|          58.8|

Leitura: em 2021 e 2026 o STJ publica o caminho completo dos assuntos; em 2022–2025 só códigos-folha (separador `;` até 2023 e `, ` em 2024–2025), com 1,7–1,8 códigos por documento em todos os anos. Como só as folhas aparecem em 2022–2025, contagens por código pai (7779, 10433) subestimam; as contagens abaixo usam a família TPU (pai + descendentes) e são comparáveis entre anos.

## Documentos na família 'dano moral': 247420 (7.1%); em classes cíveis (REsp/AREsp/EREsp/EAREsp): 242293

## Matérias (família TPU) entre docs de dano moral cíveis, por ano de publicação

|materia           |  2021|  2022|  2023|  2024|  2025|  2026|  total|
|:-----------------|-----:|-----:|-----:|-----:|-----:|-----:|------:|
|negativacao       |  2108|  2377|  2299|  3300|  3397|  2699|  16180|
|plano_saude       |  4157|  3771|  2594|  2410|  2279|  1305|  16516|
|protesto_indevido |   248|   364|   280|   412|   444|   281|   2029|
|acidente_transito |  3892|  3749|  3263|  3864|  4407|  3471|  22646|
|consumidor_rf     | 11414| 13117| 10889| 12908| 14344| 10417|  73089|
|civil_rc          | 21571| 22127| 22233| 24389| 27207| 17704| 135231|
|adm_rc            |  6779|  7653|  7359|  7559|  8369|  5743|  43462|

## Classes mais frequentes

|classe |       n|
|:------|-------:|
|AREsp  | 1995380|
|REsp   |  591648|
|HC     |  584382|
|RHC    |  102997|
|CC     |   58160|
|EAREsp |   39412|
|RMS    |   25641|
|EREsp  |   21860|
|Rcl    |   15899|
|MS     |    9413|
|PUIL   |    5933|
|CR     |    5112|
|Pet    |    4495|
|ExeMS  |    4126|
|AR     |    3259|

## Códigos mais frequentes entre docs de dano moral cíveis

| codigo|descricao                                      |     n|
|------:|:----------------------------------------------|-----:|
|  10433|Indenização por Dano Moral                     | 98787|
|   7779|Indenização por Dano Moral                     | 56163|
|  10439|Indenização por Dano Material                  | 38758|
|   9992|Indenização por Dano Moral                     | 32200|
|   7780|Indenização por Dano Material                  | 22260|
|  10435|Acidente de Trânsito                           | 17260|
|   6226|Inclusão Indevida em Cadastro de Inadimplentes | 16180|
|  10671|Obrigação de Fazer / Não Fazer                 | 12803|
|  10502|Indenização por Dano Material                  | 10872|
|  10441|Acidente de Trânsito                           | 10686|
|  10496|Promessa de Compra e Venda                     | 10230|
|  10434|Serviços de Saúde                              |  9336|
|  10437|Direito de Imagem                              |  9314|
|   7752|Bancários                                      |  8486|
|  10438|Dano Ambiental                                 |  6471|
|   9587|Compra e Venda                                 |  6450|
|   8961|Antecipação de Tutela / Tutela Específica      |  6370|
|   7768|Rescisão do contrato e devolução do dinheiro   |  6264|
|  12489|Tratamento médico-hospitalar                   |  6089|
|  12486|Planos de saúde                                |  5621|
|  13237|Ônus da Prova                                  |  5168|
|  11806|Empréstimo consignado                          |  4978|
|  10085|Água e/ou Esgoto                               |  4935|
|   9996|Acidente de Trânsito                           |  4905|
|   4703|Defeito, nulidade ou anulação                  |  4854|
|   6233|Planos de Saúde                                |  4362|
|  10588|Vícios de Construção                           |  4183|
|   9596|Prestação de Serviços                          |  4104|
|   8843|Assistência Judiciária Gratuita                |  4022|
|   9995|Serviços de Saúde                              |  3854|
