root <- Sys.getenv("STJMD_ROOT", unset = normalizePath(file.path(testthat::test_path(), "..", "..")))
source(file.path(root, "R", "validity_metrics.R")); source(file.path(root, "R", "annotation_vocab.R")); source(file.path(root, "R", "awards_rules.R"))

cand <- function(doc, value, stage, category = "dano_moral", direction = "indeterminado", unit = "BRL", ...) {
  as_tibble(modifyList(list(seq_documento = doc, value = value, unit = unit, category = category, stage = stage, direction = direction,
                            in_precedent_quote = FALSE, reference_value = FALSE, extenso_mismatch = NA, per_capita = FALSE), list(...)))
}
docs_df <- function(ids, reg = paste0("R", ids), date = "2024-03-15", ...) {
  tibble(seq_documento = ids, numero_registro = reg, classe = "AREsp", tipo_documento = "DECISAO",
         data_publicacao = as.Date(date), negativacao = TRUE, plano_saude = FALSE, ...)
}
outc <- function(ids, outcome) tibble(seq_documento = ids, outcome = outcome, sumula7 = FALSE)
ev1 <- function(cands, outcome = "mantido_sumula7", docs = docs_df(1L), origin = NULL)
  build_award_events(cands, outc(docs$seq_documento, outcome), docs, origin)

test_that("candidate_flags keeps only moral-damage BRL values with an attributable stage", {
  f <- candidate_flags(bind_rows(
    cand(1L, 1e4, "origem_acordao"), cand(1L, 2e3, "origem_acordao", category = "honorarios"), cand(1L, 5, "stj", unit = "SM"),
    cand(1L, 3e4, "stj", in_precedent_quote = TRUE), cand(1L, 4e4, "stj", reference_value = TRUE),
    cand(1L, 5e4, "origem_sentenca", extenso_mismatch = TRUE), cand(1L, 6e4, "indeterminado")))
  expect_equal(f$reason, c(NA, "nao_dano_moral", "salario_minimo", "precedente", "referencia", "extenso_divergente", "estagio_indeterminado"))
  expect_equal(f$elig, c(TRUE, rep(FALSE, 6)))
})

test_that("stages map to columns; Súmula 7 keeps valor_stj empty but valor_stj_efetivo equals the origin value (regra 5)", {
  e <- ev1(bind_rows(cand(1L, 5000, "origem_sentenca"), cand(1L, 8000, "origem_acordao")))
  expect_equal(c(e$valor_sentenca, e$valor_acordao_origem), c(5000, 8000))
  expect_true(is.na(e$valor_stj)); expect_equal(e$valor_stj_efetivo, 8000)
  expect_true(e$incluir); expect_false(e$ambiguo); expect_equal(e$materia, "negativacao")
  expect_false(e$alterou_stj)
})

test_that("two distinct values in the same stage → ambiguous (regra 4); same value repeated is not", {
  e <- ev1(bind_rows(cand(1L, 5000, "origem_acordao"), cand(1L, 7000, "origem_acordao")))
  expect_true(e$ambiguo); expect_match(e$motivos_ambiguidade, "multiplos_valores_estagio"); expect_true(is.na(e$valor_acordao_origem))
  e2 <- ev1(bind_rows(cand(1L, 5000, "origem_acordao"), cand(1L, 5000, "origem_acordao")))
  expect_false(e2$ambiguo); expect_equal(e2$valor_acordao_origem, 5000)
})

test_that("STJ change must be coherent with the origin value (regras 1 e 5)", {
  ok <- ev1(bind_rows(cand(1L, 10000, "origem_acordao"), cand(1L, 15000, "stj", direction = "aumento")), "majorado_stj")
  expect_false(ok$ambiguo); expect_true(ok$alterou_stj)
  semorig <- ev1(cand(1L, 15000, "stj", direction = "aumento"), "majorado_stj")
  expect_match(semorig$motivos_ambiguidade, "stj_sem_origem_distinta")
  wrong <- ev1(bind_rows(cand(1L, 10000, "origem_acordao"), cand(1L, 8000, "stj")), "majorado_stj")
  expect_match(wrong$motivos_ambiguidade, "alteracao_incoerente")
  s7 <- ev1(bind_rows(cand(1L, 10000, "origem_acordao"), cand(1L, 12000, "stj")), "mantido_sumula7")
  expect_match(s7$motivos_ambiguidade, "sumula7_valor_divergente")
  novals <- ev1(cand(1L, 10000, "origem_acordao"), "reduzido_stj")
  expect_match(novals$motivos_ambiguidade, "alteracao_sem_valores")
})

test_that("origin ruling direction must agree with sentence vs. appeal values (regra 2)", {
  bad <- ev1(bind_rows(cand(1L, 10000, "origem_sentenca"), cand(1L, 6000, "origem_acordao", direction = "aumento")))
  expect_match(bad$motivos_ambiguidade, "direcao_origem_incoerente")
  good <- ev1(bind_rows(cand(1L, 10000, "origem_sentenca"), cand(1L, 6000, "origem_acordao", direction = "reducao")))
  expect_false(grepl("direcao", good$motivos_ambiguidade))
})

test_that("outcomes needing review are ambiguous but kept", {
  e <- ev1(cand(1L, 10000, "origem_acordao"), "provido_verificar")
  expect_true(e$ambiguo); expect_true(e$incluir); expect_match(e$motivos_ambiguidade, "resultado_a_verificar")
})

test_that("exclusion reasons follow docs/02 and use the annotation vocabulary", {
  d <- docs_df(1:5, reg = paste0("X", 1:5))
  cs <- bind_rows(
    cand(1L, 10000, "pedido"),                                            # só pedido → sem_valor_estagio
    cand(2L, 3, "stj", unit = "SM"),                                      # só salário mínimo
    cand(3L, 9000, "stj", in_precedent_quote = TRUE),                     # só precedente
    cand(4L, 5e4, "origem_acordao", extenso_mismatch = TRUE), cand(4L, 7e3, "origem_sentenca"),  # divergência → exclui o documento
    cand(5L, 2000, "origem_acordao", category = "honorarios"))            # sem dano moral
  e <- build_award_events(cs, outc(1:5, "mantido"), d)
  expect_equal(e$motivo_exclusao, c("sem_valor_estagio", "salario_minimo_sem_conversao", "so_precedente", "extenso_divergente", "sem_valor_estagio"))
  expect_false(any(e$incluir))
  expect_true(all(e$motivo_exclusao %in% VOCAB_DOCUMENTOS$true_motivo_exclusao))   # mesmo vocabulário da anotação
})

test_that("documents without any candidate are kept in the table and excluded", {
  e <- build_award_events(cand(1L, 100, "stj")[0, ], outc(1L, "sem_dano_moral"), docs_df(1L))
  expect_equal(nrow(e), 1); expect_false(e$incluir); expect_equal(e$motivo_exclusao, "sem_valor_estagio")
})

test_that("primary event = first included document of each process", {
  d <- docs_df(c(10L, 11L, 12L), reg = c("P1", "P1", "P2"), date = c("2024-01-10", "2024-02-10", "2024-01-05"))
  cs <- bind_rows(cand(10L, 5000, "origem_acordao"), cand(11L, 5000, "origem_acordao"), cand(12L, 7000, "origem_acordao"))
  e <- build_award_events(cs, outc(c(10L, 11L, 12L), "mantido_sumula7"), d)
  expect_equal(e$seq_documento[e$evento_primario], c(12L, 10L))   # ordenado por data de publicação
  # o primeiro documento do processo é excluído → o segundo vira primário
  cs2 <- bind_rows(cand(10L, 5000, "pedido"), cand(11L, 5000, "origem_acordao"), cand(12L, 7000, "origem_acordao"))
  e2 <- build_award_events(cs2, outc(c(10L, 11L, 12L), "mantido_sumula7"), d)
  expect_equal(sort(e2$seq_documento[e2$evento_primario]), c(11L, 12L))
})

test_that("matéria and origin are derived/joined", {
  d <- docs_df(1:3, reg = c("a", "b", "c")); d$negativacao <- c(TRUE, FALSE, TRUE); d$plano_saude <- c(FALSE, TRUE, TRUE)
  og <- tibble(seq_documento = 1:2, origem_tipo = "TJ", origem_uf = c("SP", NA))
  e <- build_award_events(bind_rows(cand(1L, 1, "stj"), cand(2L, 1, "stj"), cand(3L, 1, "stj")), outc(1:3, "mantido"), d, og)
  expect_equal(e$materia, c("negativacao", "plano_saude", "ambas")); expect_equal(e$origem_conhecida, c(TRUE, FALSE, FALSE))
})

test_that("apply_reviewed overrides values, flags multiple values and recomputes the primary event", {
  d <- docs_df(1:2, reg = c("P1", "P1"), date = c("2024-01-01", "2024-02-01"))
  e <- build_award_events(bind_rows(cand(1L, 5000, "origem_acordao"), cand(2L, 5000, "origem_acordao")), outc(1:2, "mantido_sumula7"), d)
  rv <- tibble(seq_documento = c(1L, 2L, 99L), true_incluir = c("nao", "sim", "sim"), true_motivo_exclusao = c("sem_valor_estagio", "", ""),
               true_valor_pedido = "", true_valor_sentenca = "", true_valor_acordao_origem = c("", "R$ 12.000,00", "1"), true_valor_stj = "",
               true_resultado_stj = c("", "mantido", ""), true_per_capita = "", true_n_vitimas = c("", "2", ""), true_origem_uf = c("", "mg", ""),
               true_materia = c("", "ambas", ""))
  r <- apply_reviewed(e, rv)
  expect_equal(r$incluir, c(FALSE, TRUE)); expect_equal(r$motivo_exclusao, c("sem_valor_estagio", NA))
  expect_equal(r$valor_acordao_origem, c(NA, 12000)); expect_equal(r$fonte_valores, c("revisado", "revisado"))
  expect_equal(r$origem_uf, c(NA, "MG")); expect_equal(r$n_vitimas, c(NA, 2L)); expect_equal(r$materia, c("negativacao", "ambas"))
  expect_equal(r$evento_primario, c(FALSE, TRUE)); expect_equal(attr(r, "n_revisados_fora"), 1)
  multi <- apply_reviewed(e, tibble(seq_documento = 1L, true_incluir = "sim", true_valor_acordao_origem = "1000; 2000"))
  expect_true(multi$ambiguo[1]); expect_true(is.na(multi$valor_acordao_origem[1]))
})

test_that("deflation scales by IPCA(base)/IPCA(month) and fails loudly without the base month", {
  ipca <- tibble(ref_month = c("202401", "202412", "202512"), ipca_index = c(100, 105, 110))
  expect_equal(deflate_to_base(1000, as.Date("2024-01-20"), ipca, "202512"), 1100)
  expect_equal(deflate_to_base(1000, as.Date("2025-12-01"), ipca, "202512"), 1000)
  expect_true(is.na(deflate_to_base(1000, as.Date("2023-05-01"), ipca, "202512")))
  expect_error(deflate_to_base(1000, as.Date("2024-01-20"), ipca, "203001"), "ausente")
  e <- build_award_events(cand(1L, 1000, "origem_acordao"), outc(1L, "mantido"), docs_df(1L, date = "2024-01-20"))
  r <- add_real_values(e, ipca, "202512")
  expect_equal(r$valor_acordao_origem_real, 1100); expect_equal(attr(r, "deflator")$ref_date, "data_publicacao")
})

test_that("analysis population and attrition table are nested and consistent", {
  d <- docs_df(1:4, reg = paste0("Q", 1:4)); d$plano_saude <- c(FALSE, FALSE, TRUE, TRUE); d$negativacao <- !d$plano_saude
  cs <- bind_rows(cand(1L, 1e3, "origem_acordao"), cand(2L, 2e3, "origem_acordao"), cand(2L, 3e3, "origem_acordao"),
                  cand(3L, 4e3, "origem_acordao"), cand(4L, 5e3, "pedido"))
  e <- build_award_events(cs, outc(1:4, "mantido"), d)
  a <- attrition_table(e)
  expect_type(a$total, "integer")                               # contagem, não double (md_table formata double com 3 casas)
  expect_true(all(diff(a$total) <= 0))
  expect_equal(a$total[1], 4); expect_equal(a$total[nrow(a)], nrow(analysis_population(e))); expect_equal(nrow(analysis_population(e)), 2)
  e$autor_pj[e$seq_documento == 1L] <- TRUE
  expect_equal(nrow(analysis_population(e)), 1)
})
