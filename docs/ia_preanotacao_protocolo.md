# Protocolo da pré-anotação por IA (Semana 3) — Q10

Desenho aprovado pelo pesquisador em 02/10/2026: **"IA sugere, pesquisador decide"** (docs/decisions_log.md;
docs/COMO_ANOTAR.md §9, Q10). Este arquivo registra como as sugestões foram produzidas, para declaração no artigo.
Nenhum trecho de decisão é versionado.

## O que foi pré-anotado
| Planilha | Itens | Data | Insumos entregues à IA |
|---|---|---|---|
| Valores (`w3_valores_<INI>.csv`) | V001–V300 | 02/10/2026 | contexto de cada candidato (já na planilha cega) + docs/COMO_ANOTAR.md §4 e §9 |
| Documentos (`w3_documentos_<INI>.csv`) | D001–D150 | 02/10/2026 | texto integral (`w3_textos/`) + guia montado de docs/COMO_ANOTAR.md §5 e §9 e docs/02 (critérios de inclusão/exclusão) |

**Não** foram pré-anotadas as planilhas de re-anotação cega (RV/RD) nem foram mostradas à IA as chaves do extrator
(`w3_chave_*.csv`): as sugestões não dependem das predições avaliadas.

## Como
- Assistente de IA (Claude Code, Anthropic), em sessões de 02/10/2026; os documentos foram divididos em 5 lotes de 30,
  cada um anotado por uma instância separada com as mesmas instruções (abaixo), lendo cada texto por inteiro.
- Depois da aprovação das convenções Q13–Q17, as 150 linhas foram harmonizadas por essas regras (cada linha alterada
  traz a regra aplicada na `nota`) e conferidas com `scripts/09_check_annotation.R`: 0 erro.
- Cada linha traz na `nota` o prefixo `IA[alta|media|baixa|calibragem]:` (confiança declarada pela IA) e, quando
  houver, `DÚVIDA — ...` com o que conferir.

Instruções dadas a cada lote de documentos (tradução do essencial):
1. Ler o guia por inteiro e segui-lo à risca; usar só os códigos permitidos.
2. Ler o texto integral de cada documento; preencher todas as colunas `true_*`.
3. Valores só de dano moral (não material, estético, honorários, multa); vários valores no mesmo estágio separados
   por "; "; valores em precedente citado ou faixa de referência nunca preenchem estágio; cuidado com "R$ X mil",
   extenso e salário mínimo (vazio + nota).
4. `menciona = nao` ⇒ `sem_dano_moral` e valores vazios; inclusão e motivo pelos critérios da docs/02.
5. `nota` com o nível de confiança e motivo curto; nunca nomes de partes, advogados ou magistrados.

## Regras do uso (para o pesquisador)
1. Guardar a versão da IA **intocada** como `w3_valores_<INI>_IA.csv` / `w3_documentos_<INI>_IA.csv` e anotar numa cópia
   (`w3_valores_<INI>.csv` / `w3_documentos_<INI>.csv`).
2. Revisar **todas** as linhas; discordância registrada na `nota` como `| <INI>: motivo`.
3. Re-anotação cega (RV/RD) ≥ 7 dias depois, **sem** sugestões.
4. `scripts/04_validity_metrics.R` reporta a taxa de alteração IA → final por campo (seção E) e o kappa da re-anotação
   (seção C); os dois números vão para o artigo junto com a descrição deste procedimento.
