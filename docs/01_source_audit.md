# 01 — Auditoria das fontes (05/09/2026)

Tudo abaixo foi verificado por acesso direto às APIs/arquivos nesta data. Nada foi inferido de documentação secundária.

## 1. Portal de Dados Abertos do STJ (CKAN)
- Base: `https://dadosabertos.web.stj.jus.br/` — API CKAN v3 funcional (`package_list`, `package_show`, `resource_show`).
- Licença de todos os conjuntos usados: **Creative Commons Atribuição (CC-BY)**.
- Inventário completo em `data/interim/ckan_inventory.csv` (gerado por `scripts/00_inventory_ckan.R`).

### 1.1 Conjunto principal — "Íntegras de Decisões Terminativas e Acórdãos do Diário da Justiça"
| Item | Verificado |
|---|---|
| Recursos | 2.583 (1.281 ZIP de textos, 1.297 JSON de metadados, 1 CSV dicionário) |
| Chaves de data únicas | 1.278 (1.274 diárias AAAAMMDD + 4 mensais: 202202, 202203, 202204, 202207) |
| Período | 2021-01-04 → 2026-08-26 (atualização diária; `metadata_modified` 2026-09-05) |
| Granularidade | fev–abr/2022 e jul/2022 existem **apenas como arquivo mensal** (sem data de publicação diária no nome; usar `dataPublicacao` do JSON). Sem lacuna de cobertura detectada no inventário R (`scripts/00_inventory_ckan.R`). |
| Duplicatas | 21 pares (chave, tipo) com recurso reenviado (mesmo arquivo, dois UUIDs). Regra: manter o `last_modified` mais recente. |
| Tamanho | 11,19 GB de ZIP (2021: 1,99; 2022: 1,81; 2023: 1,99; 2024: 2,30; 2025: 2,57; 2026 até ago: 0,52). |
| Conteúdo do ZIP | um `.txt` por documento (UTF-8, sem BOM, quebras como `<br>`, sem cabeçalho de autuação: começa em `DECISÃO`/`ACÓRDÃO`/`EMENTA`). |
| Conteúdo do JSON | lista de objetos: `SeqDocumento`, `dataPublicacao`, `tipoDocumento`, `numeroRegistro`, `processo`, `dataRecebimento`, `dataDistribuicao`, `ministro`, `recurso`, `teor`, `descricaoMonocratica`, `assuntos` (códigos TPU/CNJ). |
| Cobertura | decisões monocráticas indicadas como terminativas + acórdãos publicados no DJe; **exclui segredo de justiça**. |
| Volume (amostra de 7 dias) | 16.927 textos; 2.171 docs em 6,9 MB ⇒ ≈300 docs/MB ⇒ ordem de **3 milhões de documentos** no período (a confirmar com a carga completa dos metadados, ~2 GB de JSON). |

**Deriva de esquema (crítica para a ingestão):**
- 2021: `SeqDocumento`, `NM_MINISTRO`, datas ISO, `tipoDocumento` = `DECISAO`/`ACORDAO`, `assuntos` como caminhos pontuados `"01156.06220.07779., 08826.08842.08874.10655."` (código com zeros à esquerda, último nó = assunto folha).
- 2023 (ex.: 20230515): `seqDocumento`, `ministro`, **datas em epoch-ms**, `DECISÃO`/`ACÓRDÃO` acentuados, `assuntos` = `"10076;10076"` (só folhas, sem caminho). Nomes dos TXT com prefixo de pasta `20230515/`.
- 2025–2026: `dataDistribuição` (acentuado), formato 2021 para o resto.
- 2026-08-26: **ZIP com 412 textos para 2.285 metadados** (dia recente incompleto). Regra: só usar dias em que |textos| ≥ 0,95·|metadados|, verificado no inventário.
- Casamento texto↔metadado nos dias-amostra: 2021 (98–99%), 2023 (100%), 2025 (99%).

### 1.2 Espelhos de acórdãos (Turmas/Seções) — 10 conjuntos
- JSON mensal (2022-05 → 2026-06) + um ZIP retroativo por órgão. Campos: `id`, `numeroProcesso`, `numeroRegistro`, `siglaClasse`, `nomeOrgaoJulgador`, `ministroRelator`, `ementa`, `decisao`, `jurisprudenciaCitada`, `teseJuridica`, `tema`, `referenciasLegislativas`, `acordaosSimilares`, `dataDecisao`, `dataPublicacao`.
- **Não trazem UF/origem.** Só cobrem acórdãos selecionados pela Secretaria de Jurisprudência (subconjunto pequeno: 57 registros na 3ª Turma em jul/2022). Uso: enriquecer `jurisprudenciaCitada` e `tema` dos acórdãos; não serve como corpus.

### 1.3 Precedentes qualificados
- `temas.csv` (2.400 precedentes: 1.502 Temas, 837 Controvérsias, 27 PUIL, 23 IAC, 11 SIRDR) e `processos.csv`; CSV separado por vírgula, UTF-8 com BOM.
- 86 precedentes mencionam dano moral. Eventos datados relevantes para RQ5/causal (data de publicação do acórdão):
  - Tema 922 (Súmula 385; inscrição indevida com anotação legítima preexistente) — 2016-05-16.
  - Tema 1078 (baixa de gravame não gera dano in re ipsa) — 2021-12-07.
  - Tema 1156 (tempo de fila bancária) — 2024-04-29.
  - **Tema 1365 (recusa de cobertura por plano de saúde não gera dano in re ipsa)** — julgado 2026-03-11, publicado 2026-03-20.
  - Tema 1315 (notificação eletrônica no cadastro de inadimplentes) — 2026-03-12.
  - Afetados/pendentes: Tema 1328 (RMC em benefício), 1435 (descontos indevidos em benefício), 1404 (dados pessoais/cadastros), 1467 (demora do plano de saúde).

### 1.4 Acervo em tramitação
- Um único `processos_tramitando_AAAAMMDD.json.gz` (77 MB; 331.018 processos no snapshot de 2026-09-02) **substituído diariamente** (CKAN não guarda histórico).
- Campos-chave: `numeroRegistro` (liga com o conjunto principal), `numeroUnico` (CNJ), `origem`, `UF`, `codigoOrgaoJulgador`, `codigoAssuntoCNJ`, `partes`.
- Teste de vínculo com os dias-amostra: docs de 2026-08-26 → **88% ligados**; 2025-03-12 → 3%; 2023 → 1%; 2021 → 0%. Ou seja: resolve UF só para processos ainda pendentes. **Recomendação: arquivar o snapshot diariamente a partir de agora** (script agendado), para cobertura prospectiva.

### 1.5 API Pública do DataJud (CNJ)
- Endpoint STJ responde **401 sem a chave pública** documentada em `datajud-wiki.cnj.jus.br`. Índice consultável por `numeroProcesso` (CNJ); **não há campo com o número de registro do STJ**, logo só complementa processos cujo número CNJ já é conhecido (via acervo em tramitação ou citação no texto — 6% dos docs de danos morais citam um número CNJ).

### 1.6 Consulta processual pública do STJ
- `https://processo.stj.jus.br/robots.txt` proíbe `/processo/` e `/processo/pesquisa/`; uma requisição de teste retornou **403**. **Descartada** (regra do projeto: não contornar bloqueios).

### 1.7 IPCA (IBGE/SIDRA)
- Tabela 1737, variável 2266 (número-índice, dez/1993 = 100), série mensal 1979-12 → 2026-07 (560 meses), via API SIDRA/`sidrar`.
- Arquivo bruto: `data/raw/ipca/ipca_1737_v2266_20260905.csv` + `.meta.json` (URL, data, SHA-256). Deflator: `deflate_brl()` em `R/fetch_ipca.R`; mês-base a definir (proposta: último mês disponível na coleta final).

### 1.8 Tabela de assuntos (TPU/CNJ)
- `https://dpj.cnj.jus.br/sgt/api/v1.0/assuntos.csv` (570 KB; latin-1; `;`). Códigos de dano moral por ramo: **7779** (Consumidor › Responsabilidade do Fornecedor › Indenização por Dano Moral; filhos 6226 inclusão indevida em cadastro, 7781 protesto indevido, 12042 análise de crédito), **10433** (Civil › Responsabilidade Civil › Indenização por Dano Moral; filho 10435 acidente de trânsito), **9992** (Administrativo › Responsabilidade da Administração › Indenização por Dano Moral), 14010/14033 (Trabalho), 14011/15301 (coletivo/ambiental).

## 2. Implicações
1. **UF/tribunal de origem é a principal lacuna estrutural.** Fontes por ordem: (a) acervo em tramitação (prospectivo, ~90%); (b) texto da decisão (regex: 42% dos docs de danos morais na amostra, sobretudo quando o relator descreve "acórdão do Tribunal de Justiça do Estado de …"); (c) número CNJ citado no texto (6%). A cobertura será reportada e a análise por tribunal (RQ2) restrita aos docs com origem identificada, com teste de seleção (docs com vs. sem origem).
2. O corpus contém **muito mais decisões monocráticas de admissibilidade (AREsp "não conhecido", Súmula 7) do que revisões de quantum**: na amostra, 21% dos docs de danos morais mencionam algum valor em R$ e ~12% trazem um valor de dano moral classificável. O desenho precisa de modelo two-part/hurdle e de descrição explícita da seleção recursal.
3. A carga completa é viável em disco (11,2 GB ZIP + ~2 GB JSON) e em tempo (≈1.280 downloads; ~10 h a 3 MB/s), mas o plano é **baixar primeiro só os metadados** (para contagens exatas e filtro por assunto) e depois só os ZIPs dos dias necessários.
