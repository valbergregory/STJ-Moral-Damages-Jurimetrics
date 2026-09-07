# 02 — Protocolo de seleção (versão 0.1, proposta para aprovação)

## Unidade de análise e identificadores
| Nível | Chave | Fonte |
|---|---|---|
| Processo no STJ | `numero_registro` (12 dígitos) | metadados diários |
| Documento (decisão/acórdão publicado) | `seq_documento` | metadados + nome do TXT |
| Evento decisório | (`seq_documento`, `event_k`) — um por pedido/vítima quando o texto individualiza | `stg.award_events` |
| Estágios de valor | `valor_pedido`, `valor_sentenca`, `valor_acordao_origem`, `valor_stj` | extração + revisão |
| Tipo de dano | moral / estético / coletivo (nunca somar com material) | classificação de candidato |
| Vítimas | `n_vitimas` (per capita vs. total sinalizado) | sinalizador `per_capita` + revisão |
| Resultado | `resultado_stj` ∈ {mantido_sumula7, mantido, reduzido_stj, majorado_stj, provido_verificar, nao_provido_sem_quantum, indeterminado} | `stj_quantum_outcome()` + revisão |

Um mesmo processo pode gerar vários documentos (decisão monocrática → AgInt → EDcl). O **evento primário** é o primeiro documento que decide o quantum; os demais entram como `recurso_interno` e servem para checar consistência (o AgInt raramente altera o valor).

## Matéria principal proposta
**Inscrição indevida em cadastro de inadimplentes (negativação)**, código TPU 6226 (filho de 7779) ou texto equivalente, em relação de consumo. Ver justificativa em `03_candidate_topics.md`. Matéria de controle/robustez: **negativa de cobertura por plano de saúde** (código 6233/12486 + dano moral), que tem evento normativo datado (Tema 1365, 2026-03-20).

## Critérios de inclusão
1. Documento do conjunto principal com `tipo_documento` ∈ {DECISAO, ACORDAO} publicado entre 2021-01-04 e a data de corte.
2. Classe ∈ {REsp, AREsp, EREsp, EAREsp} (competência cível do STJ). Excluir HC/RHC/CC/MS/Rcl etc.
3. Matéria: assunto TPU 6226 **ou** (assunto 7779/10433 **e** regex de negativação no texto) **ou** regex de negativação + regex de dano moral quando o assunto estiver ausente (formato 2023 sem caminho). A concordância entre os três caminhos será reportada.
4. Pelo menos um valor de dano moral **atribuível a um estágio** (sentença, acórdão de origem ou STJ) fora de citação de precedente e fora de "faixa de referência".
5. Relação de consumo (pessoa natural × fornecedor/instituição financeira/concessionária). Pessoa jurídica autora entra com sinalizador (`autor_pj`), para análise de sensibilidade.

## Critérios de exclusão
- Dano moral coletivo, dano ambiental, relações de trabalho (competência da Justiça do Trabalho; só aparecem no STJ por conflito ou via anômala).
- Documentos cujo único valor de dano moral está em ementa/precedente citado de outro caso.
- Valores em salário mínimo sem conversão explícita no texto (mantidos em tabela separada, `unit = SM`).
- Documentos com `extenso_mismatch = TRUE` não resolvidos na revisão.
- Segredo de justiça (já ausente da fonte) e decisões de desistência/homologação de acordo (`teor = Outros` com cue de acordo).
- Dias com ZIP incompleto (|textos| < 0,95·|metadados|).

## Regras de consistência dos valores (antes da revisão manual)
1. Se há candidato `stj` com direção `aumento`/`reducao`, deve existir candidato de origem com valor diferente; caso contrário → `ambiguo`.
2. `valor_sentenca` ≤/≥ `valor_acordao_origem` deve ser coerente com a direção detectada no acórdão de origem (`majorou`/`reduziu`).
3. Valores per capita e totais coexistindo: guardar ambos; o modelo usa per capita quando `n_vitimas` conhecido.
4. Documentos com >1 valor distinto no mesmo estágio → `ambiguo` → fila de revisão.
5. `resultado_stj = mantido_sumula7` implica `valor_stj = valor_acordao_origem`.

## Viés de seleção (a declarar e medir)
- O corpus do STJ é o produto de: (i) ajuizamento; (ii) recurso ao TJ; (iii) interposição de REsp/AREsp; (iv) admissibilidade na origem; (v) publicação no DJe (exclui segredo). Não representa as indenizações nacionais.
- Medidas propostas: (a) comparar distribuição de valores de origem entre docs "não conhecidos" (Súmula 7) e docs com mérito; (b) distribuição de UF dos recorrentes vs. população/litigiosidade (CNJ Justiça em Números, oficial); (c) séries temporais do número de AREsp em danos morais como proxy de acesso ao STJ; (d) se houver base estadual oficial e estável (a verificar caso a caso, sem CAPTCHA), usar como comparação de valores na origem.
