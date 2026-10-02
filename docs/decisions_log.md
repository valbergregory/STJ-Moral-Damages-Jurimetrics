# Decisions log

| Data | Decisão / evento | Origem | Status |
|---|---|---|---|
| 2026-09-04 | Artigo 1 em **R-only** + DuckDB (sem stack misto) | Valber | fixa |
| 2026-09-05 | Fonte principal = Dados Abertos do STJ; sem Jusbrasil; consulta processual do STJ descartada (robots.txt + 403) | briefing desta sessão + verificação | fixa |
| 2026-09-05 | Outra sessão criou `Pricing-Non-Pecuniary-Harm` (mesmo artigo, fonte JurisDF/TJDFT) | sessão paralela | **duplicidade — Valber decide fundir ou manter duas trilhas; nada apagado** |
| 2026-10-02 | **Q1–Q9 da anotação decididas pelo pesquisador** (adotadas as convenções sugeridas): gate = F1 da classe `dano_moral` (macro informativo); `pedido` inclui o recursal; `valor_stj` vazio sob Súmula 7; desfechos sem código = `outro`+nota; AgInt/EDcl anotados; protesto = `outra`; desenho cego; sem 2º anotador; precedente citado = `indeterminado`. Detalhe em docs/COMO_ANOTAR.md §9; `scripts/04_validity_metrics.R` marca o gate por essa leitura | Valber (mensagem de 02/10) | **fechada — decisão do pesquisador (2026-10-02)** |
| 2026-10-02 | **Desenho "IA sugere, pesquisador decide" aprovado para a planilha de valores** (Q10 em docs/COMO_ANOTAR.md §9): revisão integral das 300 linhas pelo pesquisador; versão da IA preservada à parte para medir a taxa de alteração; re-anotação cega sem sugestões; declaração no artigo | Valber (mensagem de 02/10: "Aprovo o desenho") | **fechada — decisão do pesquisador (2026-10-02)** |
| 2026-10-02 | Convenções Q11 (ementa repetida: próprio julgado → `stj`, senão precedente citado) e Q12 (DM fixado após sentença improcedente → direção `aumento`) adotadas | Valber (mensagem de 02/10: "adoto as duas convenções sugeridas") | **fechada — decisão do pesquisador (2026-10-02)** |
