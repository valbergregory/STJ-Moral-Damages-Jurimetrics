# Decisions log

| Data | Decisão / evento | Origem | Status |
|---|---|---|---|
| 2026-09-04 | Artigo 1 em **R-only** + DuckDB (sem stack misto) | Valber | fixa |
| 2026-09-05 | Fonte principal = Dados Abertos do STJ; sem Jusbrasil; consulta processual do STJ descartada (robots.txt + 403) | briefing desta sessão + verificação | fixa |
| 2026-09-05 | Matéria principal recomendada: inscrição indevida em cadastro (TPU 6226); controle: plano de saúde (Tema 1365) | Claude (docs/03) | **aguarda aprovação** |
| 2026-09-05 | Outra sessão criou `Pricing-Non-Pecuniary-Harm` (mesmo artigo, fonte JurisDF/TJDFT) | sessão paralela | **duplicidade — Valber decide fundir ou manter duas trilhas; nada apagado** |
| 2026-09-05 | Diretriz transversal recebida via mensagem entre sessões: (1) Claude nunca escreve prosa do artigo, article/ só esqueleto LaTeX; (2) docs/RUNBOOK.md numerado; (3) script de exportação outputs/overleaf/{tables,figures,numbers.tex}; (4) renv.lock + sessionInfo + manifesto de downloads + CITATION.cff + LICENSE + Zenodo; (5) uma linguagem só; (6) nenhum nome de parte/advogado/juiz em outputs, logs ou commits, juízes só por órgão/turma | sessão "Política de IA" (peer) | **pendente de confirmação direta do Valber**: conflita com o briefing desta sessão (artigo em Quarto; Claude como assistente de redação). CLAUDE.md não foi alterado a pedido da outra sessão. Itens 4 e 6 já parcialmente aplicados (renv.lock; logs e template de anotação com contextos textuais colocados no .gitignore) |
| 2026-09-08 | Valber: "coloque no GitHub (público), deixe organizado e vamos avançando" → repositório público criado; diretriz transversal de 05/09 **aplicada** (LaTeX/Overleaf no lugar de Quarto, RUNBOOK, export, LICENSE, CITATION, manifesto, sem nomes); trilha STJ segue; pasta `Pricing-Non-Pecuniary-Harm` intocada até decisão explícita | Valber (08/09) | aplicada |
| 2026-09-07 | **Duplicidade resolvida: são DOIS artigos.** Registro feito pela sessão de `Pricing-Non-Pecuniary-Harm` na memória: a trilha TJDFT fica com o título "Pricing Non-Pecuniary Harm"; esta trilha STJ vira artigo próprio sobre o controle do quantum pelo STJ (Súmula 7), com título distinto | Valber (via outra sessão) | aplicada provisoriamente em 08/09: título provisório "Gatekeeping the Quantum: How Brazil's Superior Court of Justice Reviews Moral-Damages Awards" em README/CITATION/main.tex — **confirmar título com o Valber nesta sessão** |
| 2026-09-08 | Censo completo (3,48 M docs): negativação 16.180 docs cíveis, plano de saúde 16.516; recomendação de matéria mantida (docs/03) | Claude | aguarda aprovação |
| 2026-09-08 | Parser de assuntos corrigido (2024–2025 usam vírgula); seleção por família TPU | Claude | feito (f958c4e) |
| 2026-09-08 | Download dos textos completos (11 GB) iniciado em segundo plano após "vamos avançando" | Claude | em execução |
| 2026-09-08 | Semana 1 iniciada: download de todos os metadados diários (scripts/02) em segundo plano | Claude | em execução |
| 2026-09-05 | Piloto de extração v0.2: regra do rótulo antecedente; sinalizador reference_value | Claude | feito, testes 18/18 |
