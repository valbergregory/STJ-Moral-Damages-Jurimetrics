# Como anotar — Semana 3 (validade da extração)

Guia passo a passo da anotação manual que sustenta o gate da Semana 3 (docs/04): **300 candidatos monetários**
(P/R/F1 por campo) + **150 documentos completos** (evento decisório completo) + **re-anotação cega** de um subconjunto
(concordância intra-anotador, kappa de Cohen). Metas: F1 ≥ 0,90 em categoria, ≥ 0,85 em estágio (≥ 0,90 em
`in_precedent`, docs/05). Nada da Semana 5 em diante começa sem o relatório `docs/07_extraction_validity.md`.

Preparado por Claude Code em 02/10/2026 a partir do que o extrator (`R/extract_money.R`, v0.2) e a documentação já
definem (`docs/data_dictionary.md`, `docs/02_selection_protocol.md`). Onde faltava definição, **não** se inventou
regra: os pontos estão na seção 9 (perguntas ao pesquisador) com a convenção *provisória* sugerida.

## 1. Gerar a amostra (uma vez, ~5–15 min)

Pré-requisito: `data/stjmd.duckdb` da Semana 2 (passo 2e do RUNBOOK).

1. **[Terminal]** `git pull`
2. **[Console]** `renv::restore()` (só se o RStudio avisar que faltam pacotes; nenhum pacote novo foi acrescentado).
3. **[Terminal]** testes: `Rscript -e "testthat::test_dir('tests/testthat')"` → deve terminar com `FAIL 0`.
4. **[Job]** Jobs → Start Local Job → `scripts/08_annotation_sample.R`, working directory = raiz do projeto.
   Ou no Terminal: `"C:\Program Files\R\R-4.4.3\bin\Rscript.exe" scripts/08_annotation_sample.R`
5. Conferir `logs/annotation_sample.log` (só contagens) e a pasta `data/annotations/`.

O sorteio é estratificado e semeado (semente 20261002): rodar de novo com `--force` gera exatamente a mesma amostra.
O script se recusa a sobrescrever planilhas que já tenham anotação.

## 2. Arquivos (todos em `data/annotations/`, fora do Git)

| Arquivo | O que é | Você… |
|---|---|---|
| `w3_modelo_valores.csv` | 300 candidatos (V001–V300), cegos | copia para `w3_valores_<INI>.csv` e preenche |
| `w3_modelo_documentos.csv` | 150 documentos (D001–D150), cegos | copia para `w3_documentos_<INI>.csv` e preenche |
| `w3_modelo_reanotacao_valores.csv` | 45 candidatos já sorteados, com novos IDs (RV001–RV045) e nova ordem | copia para `w3_reanotacao_valores_<INI>.csv` **≥ 7 dias depois** |
| `w3_modelo_reanotacao_documentos.csv` | 25 documentos já sorteados (RD001–RD025) | copia para `w3_reanotacao_documentos_<INI>.csv` **≥ 7 dias depois** |
| `w3_textos/<seq_documento>.txt` | texto integral de cada documento sorteado | abre ao lado da planilha |
| `w3_chave_*.csv` | predições do extrator, estratos e pesos | **não abrir** antes de terminar (anotação cega) |
| `w3_amostra_estratos.csv` | tamanho de cada estrato (N_h) e da amostra (n_h) | consulta, se quiser |

`<INI>` = suas iniciais, só letras (ex.: `VG`). As planilhas **não** mostram a categoria, o estágio nem o desfecho
que o extrator atribuiu — isso evita ancorar a anotação na predição (os templates antigos `full_*_template.csv` e
`pilot_annotation_template.csv` mostravam; ficam superados por estes).

**Como salvar**: Excel → *Salvar como* → "CSV UTF-8 (delimitado por vírgulas)". LibreOffice → CSV, conjunto de
caracteres UTF-8. Se o Excel gravar com ponto e vírgula, tudo bem: o script de métricas detecta o separador.
Não apague nem reordene colunas; não altere `item_id`. Deixar uma célula vazia = "não anotado" (a linha é ignorada
naquele campo), então é possível rodar as métricas com a anotação pela metade.

## 3. Ordem de trabalho e tempo estimado

Estimativas grosseiras (feitas por Claude, não medidas): ajuste depois dos 20 primeiros itens.

| Bloco | O quê | Tempo estimado |
|---|---|---|
| 0 | Ler este guia; gerar a amostra | 30 min |
| 1 | **Calibragem**: V001–V020; anotar dúvidas na coluna `nota`; responder às perguntas da seção 9 | 30–45 min |
| 2 | V021–V300 (≈ 40–60 s por item) | 3,5–5 h |
| 3 | D001–D150 (≈ 6–10 min por documento; acórdãos longos demoram mais) | 15–25 h |
| 4 | Re-anotação cega, **sem consultar a 1ª passada**, ≥ 7 dias após terminar cada bloco | 45 min + 3–4 h |
| 5 | Rodar as métricas e ler `docs/07_extraction_validity.md` | 5 min |

Total ≈ 23–35 h — a "Semana 3" provavelmente ocupa mais de uma semana corrida. Evite rodar as métricas antes de
terminar os blocos 2 e 3, para não se ancorar no desempenho do extrator.

## 4. Planilha de valores (`w3_valores_<INI>.csv`)

Colunas fixas: `item_id`, `ano`, `valor_extraido` (texto casado pelo extrator), `valor_lido` (número interpretado),
`contexto` (600 caracteres antes e 300 depois, valor marcado entre ⟦ ⟧), `arquivo_texto` (texto integral, se o
contexto não bastar). Preencha:

| Coluna | Valores aceitos | Pergunta a responder |
|---|---|---|
| `true_valor_correto` | `sim` / `nao` | O número em `valor_lido` é o que está escrito em ⟦ ⟧ (inclusive centavos e extenso)? |
| `true_category` | ver tabela abaixo | A que se refere este valor no caso? |
| `true_stage` | `pedido`, `origem_sentenca`, `origem_acordao`, `stj`, `indeterminado` | Em que momento processual este valor foi pedido/fixado? |
| `true_direction` | `aumento`, `reducao`, `manutencao`, `indeterminado` | Na frase, o valor resulta de majoração, redução ou manutenção? |
| `true_in_precedent` | `sim` / `nao` | O valor está dentro de ementa/trecho de **outro** processo citado como precedente? |
| `true_reference_value` | `sim` / `nao` | É valor de referência jurisprudencial ("faixa de", "casos semelhantes", "patamar"), não o valor deste caso? |
| `nota` | texto livre (sem nomes) | Dúvidas, contexto insuficiente, erro de leitura etc. |

Categorias (as mesmas do extrator, `docs/data_dictionary.md`):

| Código | Use quando o valor é… |
|---|---|
| `dano_moral` | indenização/compensação por dano moral ou extrapatrimonial |
| `dano_material` | dano material, lucros cessantes, danos emergentes, restituição/repetição/devolução, reembolso, pensão |
| `dano_estetico` | indenização por dano estético |
| `moral_material_conjunto` | um único valor que cobre dano moral **e** material sem separar |
| `honorarios` | honorários advocatícios / sucumbência |
| `multa` | multa (diária, astreintes, arts. 77, 523, 1.026 do CPC, litigância de má-fé) |
| `custas` | custas, despesas processuais, preparo |
| `valor_causa` | valor da causa / de alçada |
| `contrato_divida` | valor de contrato, dívida, débito, parcela, fatura, mensalidade, prêmio, benefício (ex.: o valor da dívida que gerou a inscrição) |
| `limite_procedimental` | teto de competência (ex.: 40/60 salários mínimos dos Juizados) |
| `indeterminado` | o texto não permite dizer a que o valor se refere |

Estágios: `pedido` = valor pleiteado pela parte (ver pergunta Q2); `origem_sentenca` = fixado ou mantido na sentença
(1º grau); `origem_acordao` = fixado, mantido ou alterado pelo tribunal de origem (TJ/TRF/Turma Recursal), inclusive
dentro da ementa transcrita do acórdão recorrido; `stj` = o próprio STJ fixa, majora, reduz ou declara manter o
valor; `indeterminado` = o texto não permite atribuir.

Exemplos (textos **inventados**, sem partes):

| Contexto (resumido) | category | stage | direction | in_precedent | reference_value |
|---|---|---|---|---|---|
| "A sentença fixou a compensação por danos morais em ⟦R$ 5.000,00⟧, valor majorado pelo Tribunal de origem para R$ 8.000,00." | dano_moral | origem_sentenca | indeterminado | nao | nao |
| "…majorado pelo Tribunal de origem para ⟦R$ 8.000,00⟧." (mesmo trecho, 2º valor) | dano_moral | origem_acordao | aumento | nao | nao |
| "Ante o exposto, dou parcial provimento ao recurso especial para reduzir a indenização por danos morais para ⟦R$ 10.000,00⟧." | dano_moral | stj | reducao | nao | nao |
| "Majoro os honorários advocatícios em ⟦R$ 1.000,00⟧." | honorarios | stj | aumento | nao | nao |
| "(AgInt no AREsp n. 0.000.000/UF, … fixada em ⟦R$ 10.000,00⟧ …, DJe …)" | dano_moral | indeterminado | indeterminado | sim | nao |
| "Esta Corte tem mantido indenizações na faixa de ⟦R$ 5.000,00⟧ a R$ 15.000,00 em casos semelhantes." | dano_moral | stj | manutencao | nao | sim |
| "…inscrição do nome no cadastro de inadimplentes por dívida de ⟦R$ 350,00⟧ já quitada." | contrato_divida | indeterminado | indeterminado | nao | nao |

Regras de desempate (do protocolo): o rótulo que antecede o valor prevalece ("multa diária de R$ …" é `multa`, mesmo
que a frase fale de dano moral); salário mínimo não se converte (anote a categoria normalmente; `valor_lido` mostra
"SM"); se cifra e extenso divergirem, `true_valor_correto = nao` e explique na `nota`. Valor dentro de precedente
citado (`true_in_precedent = sim`): anote a categoria, mas estágio e direção = `indeterminado` (o valor é de outro caso; convenção provisória, Q9).

## 5. Planilha de documentos (`w3_documentos_<INI>.csv`)

Leia o texto integral (`arquivo_texto`). Uma linha por documento:

| Coluna | Valores aceitos | Regra |
|---|---|---|
| `true_materia` | `negativacao`, `plano_saude`, `ambas`, `outra`, `nao_consta` | Pelo **texto**: inscrição indevida em cadastro de inadimplentes / negativa de cobertura de plano de saúde (ver Q6). `nao_consta` = o texto não descreve a lide (ver Q13); nunca deduzir pela identidade da parte |
| `true_menciona_dano_moral` | `sim` / `nao` | O texto menciona dano moral/extrapatrimonial em qualquer ponto? (valida o sinalizador `sem_dano_moral`, achado de 12/09: ≈ 50 % dos documentos do código TPU não mencionam) |
| `true_resultado_stj` | `sem_dano_moral`, `mantido_sumula7`, `mantido`, `majorado_stj`, `reduzido_stj`, `nao_provido_sem_quantum`, `outro`, `indeterminado` | O que o STJ decidiu **quanto ao valor do dano moral** (definições abaixo) |
| `true_valor_pedido` | R$ (vazio se ausente) | ver Q2 |
| `true_valor_sentenca` | R$ (vazio se ausente) | valor de dano moral da sentença |
| `true_valor_acordao_origem` | R$ (vazio se ausente) | valor de dano moral fixado/mantido pelo tribunal de origem |
| `true_valor_stj` | R$ (vazio se ausente) | valor que o STJ fixa/majora/reduz ou declara manter **expressamente** (ver Q3) |
| `true_per_capita` | `sim` / `nao` / vazio | O valor é por vítima/autor? |
| `true_n_vitimas` | inteiro / vazio | Número de autores/vítimas, se o texto disser |
| `true_origem_uf` | UF (`SP`, `DF`…), `TRF1`…`TRF6`, `TRT`, `nao_consta` | Tribunal de origem pelo texto (o TJDFT é `DF`) |
| `true_incluir` | `sim` / `nao` | O documento atende aos critérios de inclusão da docs/02? |
| `true_motivo_exclusao` | `materia_diversa`, `sem_valor_estagio`, `so_precedente`, `coletivo_ambiental`, `trabalhista`, `salario_minimo_sem_conversao`, `extenso_divergente`, `acordo_desistencia`, `outro` | Só se `true_incluir = nao` (critérios de exclusão da docs/02) |
| `nota` | texto livre (sem nomes) | — |

Valores: digite como quiser (`10000`, `10.000,00`, `R$ 10.000,00`, `10 mil`). Mais de um valor no mesmo estágio
(ex.: um por autor) → separe por `;` (`10000; 5000`). Valores em salário mínimo: deixe vazio e explique na `nota`.

Códigos de `true_resultado_stj` (vocabulário do `stj_quantum_outcome()` e da docs/02, sem os rótulos de triagem
automática `provido_verificar`/`ambiguo`, que o anotador sempre resolve):

| Código | Quando |
|---|---|
| `sem_dano_moral` | o documento não trata de dano moral |
| `mantido_sumula7` | recurso não conhecido/desprovido e o valor fica mantido com invocação da Súmula 7 / reexame fático |
| `mantido` | o valor fica mantido pelo STJ por outro fundamento (ex.: razoabilidade analisada) |
| `majorado_stj` / `reduzido_stj` | o STJ altera o valor do dano moral |
| `nao_provido_sem_quantum` | recurso negado/não conhecido sem discussão do valor |
| `outro` | qualquer outra situação — descreva na `nota` (ver Q4) |
| `indeterminado` | o texto não permite saber |

## 6. Re-anotação cega (concordância intra-anotador)

Pelo menos 7 dias depois de terminar cada bloco, copie `w3_modelo_reanotacao_valores.csv` →
`w3_reanotacao_valores_<INI>.csv` (e o equivalente de documentos) e anote do zero, **sem abrir** a 1ª passada nem as
chaves. Os itens têm IDs novos e outra ordem. O script cruza as duas passadas e calcula o kappa de Cohen por campo.

## 7-a. Conferir a planilha (ao fim de cada sessão)

**[Terminal]** `Rscript scripts/09_check_annotation.R` — mostra quantas linhas já têm anotação e lista, por `item_id`,
códigos fora do vocabulário, valores ilegíveis, UF inválida e quebras das regras de coerência (Q9, Q13, Q15, critérios da
docs/02). "erro" deve ser corrigido antes das métricas; "aviso" é só para conferir. Não altera nada. O vocabulário e as
regras estão em `R/annotation_vocab.R` (testes em `tests/testthat/test-annotation_vocab.R`).

## 7. Rodar as métricas

**[Terminal]** `Rscript scripts/04_validity_metrics.R` (opções: `--boot=1000 --seed=20261002 --tol=0.5`).
Grava `docs/07_extraction_validity.md` (só números agregados; nenhum trecho) e
`outputs/overleaf/tables/extraction_validity.tex`. O relatório traz, por anotador: P/R/F1 por classe e macro (com IC
95 % por bootstrap e versão ponderada pelos pesos do desenho) para categoria, estágio, direção, `in_precedent` e
`reference_value`; para documentos, desfecho, menciona-dano-moral, matéria, UF de origem e P/R/F1 do valor de dano
moral por estágio; e o kappa da re-anotação. A tabela "Gate da Semana 3" no topo marca atingido/não atingido.

Se o gate não for atingido e o extrator for alterado com base nestes itens, as métricas destes mesmos itens deixam de
ser uma validação independente: a recomendação é sortear uma amostra nova e menor (`--seed=` diferente) para a
re-validação. (Recomendação metodológica; a decisão é do pesquisador.)

## 8. Privacidade

`data/annotations/` inteiro fica fora do Git (`.gitignore`). Na coluna `nota`, nunca escreva nome de parte, advogado ou
magistrado. `docs/07` e `logs/annotation_sample.log` só têm contagens e podem ser versionados.

## 9. Definições da anotação — DECIDIDAS pelo pesquisador em 02/10/2026

| # | Decisão |
|---|---|
| Q1 | Gate = **F1 da classe `dano_moral`** (categoria) e estágio dos candidatos de dano moral verdadeiro; macro-F1 reportado como informativo. |
| Q2 | `pedido` inclui o valor pedido na inicial **e** o pedido ao STJ; quando for o recursal, registrar na `nota`. |
| Q3 | `valor_stj` sob Súmula 7 sem repetição do valor: **vazio** (a regra 5 da docs/02 é aplicada na consistência). |
| Q4 | Desfechos sem código: `outro` + `nota`; códigos próprios podem ser criados depois, com a lista de notas. |
| Q5 | AgInt/EDcl que repetem o valor: anotar normalmente. |
| Q6 | Protesto (TPU 7781) e ameaça de cadastro sem inscrição: `outra` + `nota` (não é `negativacao`). |
| Q7 | Desenho **cego** confirmado (planilha sem predições). |
| Q8 | Sem segundo anotador por ora; só concordância intra-anotador (o script aceita outros `<INI>` no futuro). |
| Q9 | Valores em precedente citado: estágio e direção `indeterminado`. |
| Q10 | **Pré-anotação por IA dos valores ("IA sugere, pesquisador decide")**: a planilha de valores parte das sugestões da IA (nota `IA[alta\|media\|baixa\|calibragem]: ...`); o pesquisador revisa **todas** as 300 linhas, inclusive V001–V020, e só rótulos revisados contam. A versão da IA fica intocada em `data/annotations/w3_valores_VG_IA.csv`; o trabalho vai em `w3_valores_VG.csv`; discordâncias registradas na `nota` como `\| VG: motivo`. A re-anotação cega (RV) é feita **sem** sugestões, ≥ 7 dias depois. As sugestões são da IA, não do extrator: o desenho continua cego quanto às predições avaliadas (Q7). O procedimento e a taxa de alteração IA → final serão declarados no artigo. |
| Q11 | **Mesma ementa transcrita em vários documentos** (ex.: REsp 2.069.520/RS): se o número da ementa for o do próprio documento, `true_in_precedent = nao` e estágio `stj`; caso contrário, precedente citado (Q9). Conferir pelo número do processo no topo do texto. |
| Q12 | **Tribunal fixa o dano moral após sentença improcedente**: direção = `aumento` (de zero para o valor), com `nota` "sentença improcedente". Se o texto não disser o que a sentença decidiu, `indeterminado`. |
| Q13 | **Decisão que não descreve a lide** (Súmula 182/284, intempestividade etc.): `true_materia = nao_consta` (nunca deduzir pela parte); `true_menciona_dano_moral` pelo texto; resultado `sem_dano_moral` se não menciona, `nao_provido_sem_quantum` se menciona e o recurso não passou; `true_incluir = nao`, motivo `sem_valor_estagio`. Nas métricas, `nao_consta` sai do P/R/F1 de matéria e a proporção é reportada à parte. |
| Q14 | **STJ leva o dano moral de zero a um valor ou de um valor a zero**: restabelece a sentença depois que o tribunal de origem afastou o DM → `majorado_stj`; restabelece a improcedência (ou afasta o DM) depois que a origem o fixou → `reduzido_stj`. |
| Q15 | **Dano moral só em precedente citado**: `true_menciona_dano_moral = sim` (vale a literalidade) e `true_resultado_stj = sem_dano_moral`. |
| Q16 | **Provimento parcial alheio ao valor do DM** (só multa, honorários, juros etc.): `nao_provido_sem_quantum`. |
| Q17 | **Valor pedido na apelação** também é `pedido` (amplia a Q2); registrar "pedido na apelação" na `nota`. |

Texto original das perguntas (mantido para registro):

## 9-a. Perguntas ao pesquisador (convenção provisória entre parênteses)

- **Q1 — leitura do gate.** "F1 ≥ 0,90 em categoria" é o macro-F1 sobre todas as categorias ou o F1 da classe
  `dano_moral`? "≥ 0,85 em estágio" vale para todos os candidatos ou só para os de dano moral? (O relatório mostra as
  quatro leituras; o macro conta com 0 a classe que só aparece nas predições, o que é conservador.)
- **Q2 — `pedido`.** É só o valor pedido na petição inicial, ou também o valor que o recorrente pede ao STJ ("pretende
  a majoração para R$ …")? (Provisório: os dois contam como `pedido`; especifique na `nota` quando for o recursal.)
- **Q3 — `valor_stj` sob Súmula 7.** Quando o STJ só não conhece o recurso, sem repetir o valor, deixar vazio (medida
  da extração) ou preencher com o valor de origem (regra 5 da docs/02)? (Provisório: vazio; a regra 5 é aplicada
  depois, na etapa de consistência.)
- **Q4 — desfechos sem código.** Como codificar: provimento por fundamento alheio ao valor (ex.: nulidade, retorno dos
  autos), afastamento total da condenação por dano moral (ex.: Súmula 385), restabelecimento da sentença?
  (Provisório: `outro` + `nota`; com a lista de notas em mãos, decidir se viram códigos próprios.)
- **Q5 — documentos derivados.** AgInt/EDcl que só repetem o valor da decisão monocrática: anotar normalmente o
  documento (provisório: sim; o "evento primário" da docs/02 é decidido depois).
- **Q6 — protesto × negativação.** Protesto indevido de título (família TPU própria, 7781) conta como `negativacao` ou
  `outra`? E cadastro de proteção ao crédito sem inscrição efetiva (só ameaça)? (Provisório: `outra` + `nota`.)
- **Q7 — anotação cega.** Confirmar o desenho cego (planilha sem predições), diferente do template do piloto.
- **Q8 — segundo anotador.** Há previsão de um segundo anotador para concordância **entre** anotadores? O script
  aceita vários `<INI>`; hoje só a intra-anotador está planejada.
- **Q9 — valores em precedente citado.** Estágio e direção desses valores ficam `indeterminado`? (Provisório: sim; eles
  são excluídos do uso de qualquer forma, docs/02.)
