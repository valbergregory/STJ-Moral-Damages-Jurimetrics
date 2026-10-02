root <- Sys.getenv("STJMD_ROOT", unset = normalizePath(file.path(testthat::test_path(), "..", "..")))
source(file.path(root, "R", "annotation_sampling.R"))

# universo sintético (nenhum dado real): 3.000 documentos, ~6 candidatos por documento com valor
synthetic_universe <- function(seed = 1) {
  set.seed(seed)
  docs <- tibble(seq_documento = 100000L + seq_len(3000), ano = sample(2021:2026, 3000, TRUE),
                 tipo_documento = sample(c("DECISAO", "ACORDAO"), 3000, TRUE, c(.8, .2)), classe = "AREsp",
                 materia = sample(c("negativacao", "plano_saude", "ambas"), 3000, TRUE, c(.48, .48, .04)),
                 has_brl = runif(3000) < .3,
                 outcome = sample(c("sem_dano_moral", "mantido_sumula7", "mantido", "indeterminado", "nao_provido_sem_quantum",
                                    "provido_verificar", "majorado_stj", "reduzido_stj"), 3000, TRUE, c(.45, .2, .08, .14, .06, .05, .007, .003)),
                 sumula7 = runif(3000) < .5)
  withv <- docs |> filter(has_brl)
  cand <- withv[rep(seq_len(nrow(withv)), each = 6), ] |> group_by(seq_documento) |> mutate(start_pos = row_number() * 100L) |> ungroup() |>
    mutate(end_pos = start_pos + 12L, raw = "R$ 1.000,00", value = 1000, unit = "BRL", form = "cifra",
           category = sample(c("dano_moral", "contrato_divida", "multa", "honorarios", "indeterminado", "dano_material", "custas", "dano_estetico"),
                             n(), TRUE, c(.55, .17, .08, .06, .06, .04, .02, .02)),
           stage = sample(c("stj", "origem_acordao", "origem_sentenca", "pedido", "indeterminado"), n(), TRUE),
           direction = "indeterminado", in_precedent_quote = runif(n()) < .1, reference_value = FALSE, per_capita = FALSE,
           ctx_before = "contexto anterior sintético", ctx_after = "contexto posterior", doc_sem_dm = outcome == "sem_dano_moral")
  list(docs = docs, cand = cand)
}

test_that("allocate_strata is proportional, respects minimum and caps", {
  a <- allocate_strata(c(a = 900, b = 90, c = 10), 100, 1)
  expect_equal(sum(a), 100); expect_true(all(a >= 1)); expect_equal(unname(a), c(90, 9, 1))
  expect_equal(unname(allocate_strata(c(a = 990, b = 5, c = 5), 100, 3)), c(94, 3, 3))
  b <- allocate_strata(c(a = 3, b = 500), 50, 5)
  expect_equal(unname(b), c(3, 47))                       # mínimo limitado ao tamanho do estrato
  expect_equal(sum(allocate_strata(c(a = 2, b = 3), 50)), 5)   # n maior que o universo
  expect_equal(sum(allocate_strata(setNames(rep(10, 20), letters[1:20]), 5)), 5)  # mais estratos que unidades
})

test_that("week-3 draw has the planned sizes, valid weights and is reproducible", {
  u <- synthetic_universe()
  d1 <- draw_week3(u$cand, u$docs, seed = 20261002L); d2 <- draw_week3(u$cand, u$docs, seed = 20261002L)
  expect_equal(nrow(d1$sa), 300); expect_equal(nrow(d1$sd), 150)
  expect_identical(d1$sa[c("item_id", "seq_documento", "start_pos")], d2$sa[c("item_id", "seq_documento", "start_pos")])
  expect_identical(d1$sd$seq_documento, d2$sd$seq_documento)
  expect_false(identical(draw_week3(u$cand, u$docs, seed = 1L)$sd$seq_documento, d1$sd$seq_documento))
  expect_equal(sum(d1$sa$category == "dano_moral"), 180)               # bloco A = 60 %
  expect_true(all(c("custas", "dano_estetico") %in% d1$sa$category))   # categorias raras garantidas (mínimo por estrato)
  expect_true(all(c("majorado_stj", "reduzido_stj") %in% d1$sd$outcome))  # desfechos raros sobreamostrados
  expect_true(any(d1$sd$outcome == "sem_dano_moral") && any(!d1$sd$has_brl))
  # pesos: a soma de w por estrato reconstitui N_h, e a soma total = tamanho do universo dos estratos sorteados
  chk <- d1$sd |> group_by(stratum) |> summarise(sw = sum(w), N = first(N_h))
  expect_equal(chk$sw, chk$N)
  expect_equal(sum(d1$sd$w), nrow(u$docs))
  expect_equal(anyDuplicated(d1$sa[c("seq_documento", "start_pos")]), 0L); expect_equal(anyDuplicated(d1$sd$seq_documento), 0L)
  # re-anotação: subconjunto, novos IDs, sem repetição
  expect_equal(nrow(d1$ra), 45); expect_equal(nrow(d1$rd), 25)
  expect_true(all(d1$ra$item_id %in% d1$sa$item_id)); expect_true(all(grepl("^RV\\d{3}$", d1$ra$item_id_reanot)))
  expect_false(identical(d1$ra$item_id, sort(d1$ra$item_id)))         # ordem embaralhada
})

test_that("worksheets are blind, keys carry predictions, and files are written", {
  u <- synthetic_universe(2); dr <- draw_week3(u$cand, u$docs)
  ids <- unique(c(dr$sa$seq_documento, dr$sd$seq_documento))
  texts <- tibble(seq_documento = ids, text_norm = strrep("Texto sintético de decisão. ", 60))
  dm_vals <- tibble(seq_documento = dr$sd$seq_documento[1:3], stage = "stj", value = c(10000, 5000, 5000))
  dm_vals <- bind_rows(dm_vals, tibble(seq_documento = dr$sd$seq_documento[1], stage = "stj", value = 12000))
  orig <- tibble(seq_documento = dr$sd$seq_documento[1:2], origem_uf = c("SP", "TRF4"))
  out <- finalize_week3(dr, texts, dm_vals, orig)
  expect_setequal(names(out), names(W3_FILES))
  for (k in c("modelo_valores", "modelo_documentos", "modelo_reanotacao_valores", "modelo_reanotacao_documentos")) {
    nm <- grep("^true_", names(out[[k]]), value = TRUE, invert = TRUE)
    expect_false(any(grepl("^pred_|stratum|^w$|^N_h$|outcome|category|materia", nm)), info = k)
    expect_true(all(unlist(out[[k]][grep("^true_", names(out[[k]]))]) == ""), info = k)
  }
  expect_true(all(c(AMOUNT_TRUE_COLS, "contexto") %in% names(out$modelo_valores)))
  expect_true(all(DOC_TRUE_COLS %in% names(out$modelo_documentos)))
  expect_equal(names(out$modelo_reanotacao_valores)[1], "item_id_reanot")
  expect_true(all(grepl("⟦", out$modelo_valores$contexto, fixed = TRUE)))
  k1 <- out$chave_documentos |> filter(seq_documento == dr$sd$seq_documento[1])
  expect_equal(k1$pred_valor_stj, "10000;12000"); expect_equal(k1$pred_origem_uf, "SP")
  expect_true(all(c("pred_category", "pred_stage", "w", "stratum") %in% names(out$chave_valores)))
  tmp <- file.path(tempdir(), "w3_sample"); unlink(tmp, recursive = TRUE); dir.create(tmp)
  write_week3(out, texts, tmp)
  expect_true(all(file.exists(file.path(tmp, W3_FILES))))
  expect_equal(length(list.files(file.path(tmp, "w3_textos"))), length(ids))
  # proteção contra sobrescrita: modelo vazio = sem anotação; preenchido (mesmo com ;) = protegido
  p <- file.path(tmp, W3_FILES[["modelo_valores"]]); expect_false(has_annotations(p))
  m <- out$modelo_valores; m$true_category[1] <- "dano_moral"
  write.table(m, p, sep = ";", row.names = FALSE, fileEncoding = "UTF-8"); expect_true(has_annotations(p))
})

test_that("materia_label combines TPU family flags", {
  expect_equal(materia_label(c(TRUE, FALSE, TRUE, NA), c(FALSE, TRUE, TRUE, NA)), c("negativacao", "plano_saude", "ambas", "outra"))
})
