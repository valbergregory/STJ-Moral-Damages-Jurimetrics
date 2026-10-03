# 10 — Plano de estimação (v0.1, proposta para aprovação do pesquisador, 03/10/2026)

Plano de análise pré-especificado para as Semanas 4–8 (docs/04). **Nenhuma estimação foi rodada.** Nada aqui é
resultado; números de N citados vêm de docs/06 e docs/08 e serão substituídos pelos do dataset congelado. Este
documento fixa *o que será estimado e como*, para que a escolha de especificação não dependa dos resultados.

## 0. Pré-condições (gates)
| Gate | Critério | Onde se mede |
|---|---|---|
| G1 — validade da extração | F1 da classe `dano_moral` ≥ 0,90; estágio ≥ 0,85 (leitura de Q1, COMO_ANOTAR §9) | `docs/07_extraction_validity.md` (`scripts/04`) |
| G2 — coerência jurídica da amostra | proporção de `incluir = sim` na amostra de 150 documentos e motivos de exclusão | mesma anotação (`true_incluir`) |
| G3 — dataset v1 congelado | `data/processed/awards.parquet` + data card + hash; `targets` sem alvos pendentes | Semana 4 |
| G4 — viabilidade | N por estrato (matéria × estágio × origem conhecida) suficiente para cada modelo (§6) | `scripts/10_feasibility.R` (a criar) |
Se G1 falhar, itera-se o extrator (já corrigido em 03/10 para "R$ X mil", extenso com vírgula e salário mínimo
decimal) e re-mede-se; as RQs 1–6 não começam antes.

## 1. Dataset analítico (`stg.award_events` → `awards.parquet`)
- **Unidade:** evento decisório (`seq_documento`, `event_k`), um por vítima/pedido quando o texto individualiza
  (docs/02). Evento primário por processo = primeiro documento que decide o quantum; AgInt/EDcl só como checagem.
- **Resposta principal:** `valor_acordao_origem` (indenização fixada na origem) e `valor_stj`. Valores em R$ nominais
  → **deflacionados pelo IPCA (SIDRA 1737) para o mês-base de dez/2025** (mês-base é decisão aberta, ver §9);
  análise em `log(valor_real)`. Per capita quando `n_vitimas` conhecido (docs/02, regra 3); totais só em
  sensibilidade. Salário mínimo (`unit = SM`) fica fora da resposta; tabela à parte.
- **Fonte dos valores:** `fonte_valores ∈ {automatico, revisado}`. Os 150 documentos anotados são o padrão-ouro; o
  restante é extração automática filtrada pelas regras de consistência (docs/02) e pela exclusão de `ambiguo`,
  `in_precedent_quote`, `reference_value`, `extenso_mismatch`. **A população analisada é a dos documentos com
  evento não ambíguo**; sua diferença para o corpus completo é descrita (tabela de atrito) e entra como limitação.
- **Covariáveis (só as observáveis no texto/metadados):** matéria (negativação × plano de saúde), ano de publicação
  e de origem, tribunal/UF de origem (cobertura parcial: ≈46 % pelo texto, docs/08), órgão julgador do STJ
  (turma/seção; **relator só como ID anonimizado**, nunca nome), classe (REsp/AREsp/EREsp/EAREsp), tipo de recurso
  interno, `autor_pj`, `n_vitimas`, presença de dano material conjunto, `teor`, uso de Súmula 7, tamanho do texto.
  Nenhuma covariável é construída a partir do desfecho.
- **Exclusões:** as de docs/02; SM sem conversão; `incluir = nao` na anotação (propagado por regra, não por
  decisão ad hoc). Cada exclusão tem contagem registrada.

## 2. Erro de medição (transversal)
A extração é automática; o erro é medido (G1) e **propagado**, não ignorado:
1. Estimativas principais no dataset automático filtrado; **repetidas no subconjunto revisado** (150 docs) como
   checagem de vazamento de erro.
2. Análise de sensibilidade com perturbação: reamostra-se `valor` conforme a matriz de confusão por campo
   (P/R por categoria/estágio, com IC bootstrap de `04_validity_metrics`) e re-estima-se (≥ 500 repetições,
   semente fixa). Reportam-se intervalos que incluem esse erro.
3. Pesos de desenho da amostra de anotação (`w = N_h/n_h`) só servem para métricas de validade; **não** entram nas
   regressões (a amostra de anotação não é a amostra de análise).

## 3. Descritivas e dispersão (RQ1, RQ3) — Semana 5
- Distribuições por matéria × estágio (pedido, sentença, origem, STJ): quantis (5-25-50-75-95), IQR, coef. de
  variação em log, Gini; gráficos de densidade/ECDF em R$ reais.
- **Dispersão STJ × origem (RQ3):** só é identificável nos documentos em que o STJ **altera** o valor ou re-fixa.
  Como a taxa de alteração é baixíssima (docs/08: 8 majorações + 10 reduções no corpus de negativação; ≈ 0 em plano
  de saúde), o resultado esperado é "STJ não altera a dispersão porque quase não altera o valor". O plano reflete
  isso: (a) estimar a **taxa de intervenção** com IC (Clopper-Pearson/Bayes beta); (b) comparar a razão de
  variâncias de log-valor origem vs. STJ **apenas** nos pares com intervenção, descritivamente, sem teste de
  hipótese de efeito; (c) separar "mantido por Súmula 7" de "mantido no mérito".
- **Regressão quantílica (RQ1):** `quantreg::rq(log_valor_real ~ X, tau = c(.1,.25,.5,.75,.9))`, erros-padrão por
  bootstrap em blocos por `numero_registro`; coeficientes por quantil em figura. Reportar também OLS e Tobit/hurdle
  para sinalizar diferença de forma funcional.
- **Duas partes (`two-part`):** (i) `P(valor > 0)` — logit com tribunal/ano; (ii) `log(valor) | valor > 0`. Útil
  porque improcedência e valor zero na origem coexistem com condenações.

## 4. Heterogeneidade entre tribunais (RQ2) — Semana 6
- **Modelo hierárquico:** `log(valor_real) ~ X + (1 | tribunal_origem) + (1 | ano) + (1 | orgao_stj)`
  (ID anonimizado do relator só em robustez). Estima-se a **fração de variância** por nível (ICC) com e sem
  controles de caso — "diferenças persistentes entre tribunais sobrevivem aos controles?" = ICC e efeitos
  aleatórios de tribunal com `X` completo vs. nulo.
- **Software:** `brms` (Stan) se o toolchain compilar (risco 4, docs/04); fallback `lme4`/`glmmTMB` e, para
  comparação, `fixest` com efeitos fixos de tribunal. Prior fracamente informativo, checagens preditivas
  posteriores, R-hat/ESS reportados. Decisão do software no `scripts/10_feasibility.R`.
- **Seleção e cobertura (risco 1):** origem conhecida em ≈ 46 % dos documentos. (a) estimar no subconjunto com
  origem; (b) comparar covariáveis observáveis com/sem origem; (c) **ponderação pelo inverso da probabilidade de
  origem conhecida** (logit em covariáveis do documento) como robustez; (d) limites de Manski/pior-caso só como
  ilustração, sem pretensão de ponto. O artigo declara que o resultado vale para "documentos com origem
  identificável".

## 5. Intervenção do STJ no quantum (RQ4) — Semana 6
- Resposta binária `alterou_stj ∈ {majorado, reduzido}`; evento raro (≈ dezenas de casos). Para evitar separação:
  **regressão logística de Firth** (`brglm2`) ou bayesiana com prior regularizador; poucas covariáveis
  pré-definidas (valor de origem em log, matéria, órgão, classe, Súmula 7 mencionada, ano). Sem seleção automática
  de variáveis.
- **Corpus completo, não só a amostra**: agrega-se 2021-01 → data de corte (docs/04, risco 2). Se mesmo assim houver
  < 10 eventos por covariável, o plano cai para **descritivo** (tabela cruzada + IC exatos) e o artigo declara que
  o dado não sustenta inferência multivariada. Esta é uma decisão antecipada, não ajuste post hoc.
- Intervenção ≠ efeito causal: o STJ altera valores muito acima/abaixo da faixa por seleção; reporta-se
  *associação*. Não se usa "efeito do STJ" em tabela ou texto.

## 6. Séries, quebras e evento (RQ5) — Semana 7
- **Série:** mediana mensal de `log(valor_real)` por matéria (n mínimo por mês definido no feasibility; meses
  abaixo do mínimo agregados em trimestres). Pergunta: convergência, quebra estrutural ou inflação real?
- `strucchange` (`breakpoints`, `efp`) para quebras; teste de raiz unitária (ADF/KPSS) na série deflacionada;
  tendência por regressão com HAC. Com ≈ 4 anos de dados (2021–2026) as séries são curtas: **não se afirma
  convergência**, só se testa e se descreve a incerteza.
- **Evento Tema 1365 (matéria de controle: plano de saúde):** estudo de evento / séries interrompidas com data de
  corte = data do evento **verificada na fonte** (docs/02 registra 2026-03-20; conferir tese literal e situação
  pela base de precedentes do STJ antes de usar). Comparação com a série de negativação (não afetada) em
  diferenças-em-diferenças descritivo. Janela pós-evento curta → intervalo largo; é estudo de caso.
- Sobrevivência (tempo até decisão) **só** se as datas de recebimento/distribuição forem confiáveis (docs/06);
  caso contrário, fora do escopo.

## 7. Modelagem preditiva (RQ6) — Semana 8
- **Alvo:** `log(valor_real)` na origem e, em separado, `P(alteração pelo STJ)` (se N permitir).
- **Modelos:** regressão linear regularizada (referência), `ranger`, `xgboost`; hiperparâmetros por validação
  cruzada aninhada **dentro do treino**.
- **Validação:** (i) **temporal** — treina até t, testa em t+1 (janela expansiva, por semestre); (ii) **por
  tribunal** — leave-one-court-out; (iii) sem vazamento: nenhuma covariável derivada do dispositivo do STJ ao prever
  valor de origem; tokens de valor removidos do texto de entrada.
- **Incerteza:** *conformal split* (e/ou CQR sobre quantis) para intervalos de predição; cobertura empírica
  reportada por tribunal e por quantil do valor; **calibração** (cobertura nominal × observada) e *width* médio.
  Se a cobertura em tribunais pequenos for ruim, isso é resultado, não falha a esconder.
- **Interpretabilidade:** importância por permutação e SHAP (`shapviz`) só descritivos; ficha do modelo (model
  card): dados, versão do extrator, semente, métricas, limites de uso. **O modelo não é oferecido como
  ferramenta de arbitramento**; o artigo declara que prever faixa não é fixar indenização.

## 8. Robustez e reprodutibilidade (Semana 9)
- Especificações alternativas (deflator, base, per capita × total, sem PJ, só `revisado`, só acórdãos, sem EDcl).
- Multiplicidade: as hipóteses das RQs 1–6 são pré-listadas aqui; reportam-se todos os testes realizados; para
  famílias de coeficientes por quantil/tribunal usa-se controle de FDR (Benjamini–Hochberg) e se declara o
  número de modelos rodados.
- `targets` com alvos novos (`awards`, `m_quantreg`, `m_hier`, `m_firth`, `m_break`, `m_pred`); cada alvo grava
  `git_commit` e `seed` em `res.model_runs`; `renv.lock` e `logs/sessionInfo_*.txt`; saídas só por
  `scripts/90_export_overleaf.R` (tabelas `.tex`, figuras `.pdf/.png`, `numbers.tex`).
- **Sem nomes** de partes, advogados ou magistrados em qualquer saída; relator só como ID anonimizado.
- **Congelamento:** após o G3, qualquer mudança de especificação vira linha no `decisions_log` com motivo e
  data; modelos exploratórios ficam em seção separada ("exploratório") e não alimentam o texto principal sem essa
  marcação.

## 9. Decisões abertas (do pesquisador)
1. **Mês-base do deflator** (dez/2025 proposto) e série (IPCA cheio; alternativa INPC).
2. **Resposta principal:** `valor_acordao_origem` (proposto) ou `valor_stj` quando alterado; ou ambos como RQs
   separadas.
3. **Software bayesiano:** `brms` (exige Rtools/Stan na máquina do Valber) ou `lme4/glmmTMB` como principal.
4. **RQ4 com N pequeno:** aceita o plano de cair para análise descritiva se < 10 eventos por covariável?
5. **Tema 1365:** manter como estudo de caso (proposto) ou retirar se a janela pós-evento ficar curta.
6. **Escopo de RQ6:** modelo preditivo no corpo do artigo ou em apêndice (risco de leitura como "calculadora de
   indenização").
7. **Pessoa jurídica autora:** excluir (proposto como padrão, docs/02 manda sinalizar) ou manter com `autor_pj`.

## 10. Entregáveis e scripts previstos
| Arquivo | Conteúdo | Semana |
|---|---|---|
| `scripts/10_feasibility.R` | N por estrato/modelo, cobertura de origem, mínimo mensal, teste de compilação do Stan | 4 |
| `scripts/11_build_awards.R` + `R/awards_rules.R` | regras de consistência, `award_events`, deflação, `awards.parquet`, data card | 4 |
| `scripts/12_descriptives_quantreg.R` | RQ1, RQ3 | 5 |
| `scripts/13_hierarchical.R`, `14_firth_intervention.R` | RQ2, RQ4 | 6 |
| `scripts/15_breaks_event.R` | RQ5 | 7 |
| `scripts/16_predictive_conformal.R` | RQ6 | 8 |
| `scripts/17_robustness.R` | §8 | 9 |
| `tests/testthat/test-awards_rules.R` etc. | regras com fixtures sintéticas | cada semana |
Os scripts só nascem **depois da aprovação deste plano e do G1**; o código é escrito e testado em fixtures
sintéticas (os dados reais só existem na máquina do autor).
