root <- Sys.getenv("STJMD_ROOT", unset = normalizePath(file.path(testthat::test_path(), "..", "..")))
source(file.path(root, "R", "validity_metrics.R")); source(file.path(root, "R", "awards_rules.R")); source(file.path(root, "R", "feasibility.R"))

# eventos sintéticos já no formato de build_award_events(): n documentos, `alt` deles alterados pelo STJ
synth <- function(n, materia = "negativacao", alt = 0L, uf = c("SP", "MG"), start = "2025-01-01", by_days = 3, known = TRUE) {
  tibble(seq_documento = seq_len(n) + if (materia == "plano_saude") 1e5 else 0, event_k = 1L, numero_registro = paste0(materia, seq_len(n)),
         materia = materia, data_publicacao = as.Date(start) + (seq_len(n) - 1) * by_days, valor_pedido = NA_real_, valor_sentenca = NA_real_,
         valor_acordao_origem = 5000 + seq_len(n), valor_stj = NA_real_, valor_stj_efetivo = 5000 + seq_len(n),
         resultado_stj = c(rep("majorado_stj", alt), rep("mantido_sumula7", n - alt)), alterou_stj = seq_len(n) <= alt,
         origem_uf = rep(uf, length.out = n), origem_conhecida = known, autor_pj = NA, ambiguo = FALSE, incluir = TRUE, evento_primario = TRUE)
}

test_that("feasibility counts match the nested analysis population", {
  ev <- bind_rows(synth(100, alt = 3), synth(60, "plano_saude", alt = 0)); ev$ambiguo[1:5] <- TRUE; ev$origem_conhecida[10:20] <- FALSE
  ev$origem_uf[10:20] <- NA
  r <- feasibility_tables(ev)
  expect_equal(r$n_pop, nrow(analysis_population(ev))); expect_equal(r$n_pop, 155)
  expect_equal(sum(r$origin$n), r$n_pop)
  expect_equal(r$origin$com_origem[r$origin$materia == "negativacao"], 100 - 5 - 11 + 0)  # 5 ambíguos fora; 11 sem origem (nenhum coincide com os ambíguos)
  expect_false(r$pj_filter_active)
})

test_that("RQ4 falls back to descriptive when events per covariate are below the plan threshold (10)", {
  few <- feasibility_tables(synth(500, alt = 20))$rq4              # 20 / 6 covariáveis = 3,3 < 10
  expect_equal(few$modo[few$materia == "todas"], "descritivo")
  many <- feasibility_tables(synth(500, alt = 70))$rq4             # 70 / 6 = 11,7 ≥ 10
  expect_equal(many$modo[many$materia == "todas"], "firth")
  expect_equal(many$eventos[many$materia == "todas"], 70)
  custom <- feasibility_tables(synth(500, alt = 20), list(n_covariates_rq4 = 2))$rq4                # 20 / 2 = 10 → exatamente no limite
  expect_equal(custom$modo[custom$materia == "todas"], "firth")
})

test_that("court and monthly thresholds drive the hierarchical/series decisions", {
  r <- feasibility_tables(synth(400, uf = c("SP", "MG", "RS", "PR", "BA", "CE", "GO")))          # ~57 por UF
  expect_equal(sum(r$courts$entra_hierarquico), 7)
  r2 <- feasibility_tables(synth(400, uf = c("SP", "MG", "RS", "PR", "BA", "CE", "GO")), list(min_court_n = 100))
  expect_equal(sum(r2$courts$entra_hierarquico), 0)
  dense <- feasibility_tables(synth(900, by_days = 1))$monthly                                   # ~30 por mês
  expect_equal(dense$granularidade, "mensal")
  sparse <- feasibility_tables(synth(300, by_days = 10))$monthly                                 # ~3 por mês
  expect_equal(sparse$granularidade, "trimestral")
})

test_that("Tema 1365 window needs enough events on both sides", {
  ps <- synth(200, "plano_saude", start = "2025-12-01", by_days = 1)        # corta em 20/03/2026
  r <- feasibility_tables(ps)
  expect_equal(r$tema$pre + r$tema$pos, 200); expect_true(r$tema$pre > 0 && r$tema$pos > 0)
  expect_true(r$tema$janela_ok)
  expect_false(feasibility_tables(synth(200, "plano_saude", start = "2024-01-01"))$tema$janela_ok)   # tudo antes do corte
})

test_that("decisions respect the toolchain and the Stan test; contingency is always viable", {
  ev <- bind_rows(synth(600, alt = 70, uf = c("SP", "MG", "RS", "PR", "BA"), by_days = 1),
                  synth(200, "plano_saude", start = "2025-12-01", by_days = 1, uf = c("SP", "MG", "RS", "PR", "BA")))   # plano de saúde cruza 20/03/2026
  r <- feasibility_tables(ev)
  tc_all <- tibble(pacote = names(TOOLCHAIN_PKGS), uso = unname(TOOLCHAIN_PKGS), instalado = TRUE, versao = "1")
  d <- feasibility_decisions(r, tc_all, list(ok = TRUE, engine = "rstan", seconds = 1, msg = ""))
  expect_true(all(d$viavel))
  d2 <- feasibility_decisions(r, mutate(tc_all, instalado = FALSE), list(ok = FALSE, engine = NA, seconds = NA, msg = "x"))
  expect_true(d2$viavel[d2$modelo == "RQ4 descritiva (plano de contingência)"])
  expect_false(d2$viavel[d2$modelo == "RQ2 hierárquico bayesiano (brms)"]); expect_false(d2$viavel[d2$modelo == "RQ4 logística de Firth"])
  d3 <- feasibility_decisions(r, tc_all, NULL)       # Stan não testado → brms não é dado como viável
  expect_false(d3$viavel[d3$modelo == "RQ2 hierárquico bayesiano (brms)"])
})

test_that("report is markdown with counts only and flags missing PJ extraction and Stan not tested", {
  r <- feasibility_tables(synth(100, alt = 1)); tc <- check_toolchain(c("dplyr", "pacote_inexistente_xyz"))
  expect_equal(tc$instalado, c(TRUE, FALSE))
  md <- feasibility_md(r, feasibility_decisions(r, NULL, NULL), tc, NULL, generated = as.Date("2026-10-03"))
  txt <- paste(md, collapse = "\n")
  expect_match(txt, "Relatório de viabilidade"); expect_match(txt, "autor_pj"); expect_match(txt, "não executado")
  expect_match(txt, "Limitação da deflação"); expect_false(grepl("ctx_|dispositivo|ministro", txt))
  ev <- synth(100); ev$autor_pj <- c(TRUE, rep(FALSE, 99))
  expect_true(feasibility_tables(ev)$pj_filter_active)
})

test_that("stan_compile_test degrades gracefully when no Stan backend is installed", {
  skip_if(requireNamespace("rstan", quietly = TRUE) || requireNamespace("cmdstanr", quietly = TRUE))
  s <- stan_compile_test(); expect_false(s$ok); expect_match(s$msg, "instalados")
})

test_that("stan_compile_test always returns ok/engine/seconds/msg and explains a failure (opt-in: compila de verdade)", {
  skip_if(Sys.getenv("STJMD_STAN_TEST") != "1", "defina STJMD_STAN_TEST=1 para tentar compilar um modelo Stan")
  s <- stan_compile_test(); expect_named(s, c("ok", "engine", "seconds", "msg"))
  if (!s$ok) expect_true(nzchar(s$msg))
})
