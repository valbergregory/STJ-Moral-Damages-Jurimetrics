# Gatekeeping the Quantum: How Brazil's Superior Court of Justice Reviews Moral-Damages Awards

Research compendium (R + DuckDB, single language) for a jurimetrics / law-and-economics article measuring the
heterogeneity of moral-damages (*dano moral*) awards in decisions of Brazil's Superior Court of Justice (STJ),
built exclusively on official open data.

Working title (provisional, 2026-09-08; the sibling repository `Pricing-Non-Pecuniary-Harm` covers trial-court awards in the TJDFT). 

**Status (2026-09-08):** Phase 0 complete — source audit, selection protocol, seven-day pilot of the monetary
extractor (1,381 moral-damages documents), candidate-topic table and 11-week plan. Phase 1 (full metadata load)
in progress. **No estimation has been run.** Read `docs/` in numeric order; `docs/RUNBOOK.md` is the executable
step-by-step.

## Research questions
1. Which factors explain the variation of moral-damages awards in cases reaching the STJ?
2. Do persistent differences between courts of origin survive controls for case characteristics?
3. Does the STJ reduce or amplify the dispersion of awards?
4. Which factors are associated with STJ intervention in the quantum?
5. Does the case law show convergence, structural breaks or real inflation of awards?
6. Can predictive models estimate award ranges with adequate calibration without hiding legal uncertainty?

## Data sources (all official; see `docs/01_source_audit.md` and `data/raw/MANIFEST.csv`)
- **STJ Open Data Portal** (CC-BY): full texts and metadata of terminative decisions and rulings published in the
  DJe (2021-01 → present, ~11 GB zipped, ~3 million documents), qualified precedents, pending-docket snapshot.
- **IBGE/SIDRA** table 1737 (IPCA index) for deflation.
- **CNJ** unified subject table (TPU) for subject codes.
No commercial databases; no scraping of pages blocked by `robots.txt`; no CAPTCHA circumvention.

## Layout
```
config/     sample_days.txt                     R/          pure functions (extraction, ingestion, IPCA)
scripts/    numbered, idempotent steps          sql/        DuckDB schema (raw / stg / ann / res)
tests/      testthat                            docs/       audit, protocol, topics, plan, pilot report, RUNBOOK, AI policy
data/raw    immutable + SHA-256 + MANIFEST      data/interim, data/processed, data/annotations (not versioned)
article/    LaTeX skeleton only (author writes in Overleaf)   outputs/overleaf  generated tables, figures, numbers.tex
_targets.R  pipeline                            renv.lock   pinned packages (R 4.4.3)
```

## Reproduce
```bash
Rscript scripts/00_inventory_ckan.R          # CKAN inventory
Rscript scripts/01_download_sample.R         # sample days only (config/sample_days.txt), SHA-256
Rscript R/fetch_ipca.R                       # IPCA raw + meta.json
Rscript R/build_sample_corpus.R              # normalise schema drift, select moral-damages docs
Rscript scripts/03_pilot_money_extraction.R  # monetary extraction pilot
Rscript -e "testthat::test_dir('tests/testthat')"
Rscript scripts/99_manifest.R                # data/raw/MANIFEST.csv
Rscript scripts/90_export_overleaf.R         # outputs/overleaf/
```
Full sequence, expected inputs/outputs and run times: `docs/RUNBOOK.md`.

## Principles
Raw data are never edited. No monetary expression is treated as an award by default: every candidate carries a
category, procedural stage, direction and ambiguity flags, and goes through consistency rules and manual
annotation before use. The selection bias of the STJ corpus is declared and measured, never assumed away.
No name of any party, lawyer or judge appears in versioned outputs. AI assistance is limited to code, tests and
documentation and is disclosed as described in `docs/AI_POLICY_AND_REPRODUCIBILITY.md`; the manuscript prose is
written by the author.

## License and citation

Code: MIT ([LICENSE](LICENSE)). Text, documentation and data: see [LICENSING.md](LICENSING.md).
Code: MIT. Documentation and manuscript materials: CC BY 4.0. Redistributed data keep their original licenses.
See `LICENSE` and `CITATION.cff`.
