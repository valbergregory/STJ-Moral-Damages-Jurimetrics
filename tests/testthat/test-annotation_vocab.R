root <- Sys.getenv("STJMD_ROOT", unset = normalizePath(file.path(testthat::test_path(), "..", "..")))
source(file.path(root, "R", "validity_metrics.R")); source(file.path(root, "R", "annotation_vocab.R"))

doc_row <- function(...) {
  base <- list(item_id = "D001", true_materia = "", true_menciona_dano_moral = "", true_resultado_stj = "", true_valor_pedido = "",
               true_valor_sentenca = "", true_valor_acordao_origem = "", true_valor_stj = "", true_per_capita = "", true_n_vitimas = "",
               true_origem_uf = "", true_incluir = "", true_motivo_exclusao = "", nota = "")
  as_tibble(modifyList(base, list(...)))
}
rules <- function(d, kind = "documentos") check_annotation(d, kind)$regra

test_that("a coherent, fully annotated document passes", {
  ok <- doc_row(true_materia = "negativacao", true_menciona_dano_moral = "Sim", true_resultado_stj = "mantido_sumula7",
                true_valor_sentenca = "R$ 5.000,00", true_valor_acordao_origem = "10 mil", true_origem_uf = "sp", true_incluir = "sim")
  expect_equal(nrow(check_annotation(ok, "documentos")), 0)
  expect_equal(nrow(check_annotation(doc_row(), "documentos")), 0)          # vazio = não anotado, não é erro
  expect_equal(annotation_progress(bind_rows(ok, doc_row(item_id = "D002")), "documentos")[["anotados"]], 1)
})

test_that("vocabulary, values, UF and victims are validated", {
  expect_match(rules(doc_row(true_materia = "consumo")), "vocabulário")
  expect_match(rules(doc_row(true_valor_stj = "dez mil reais")), "ilegível")
  expect_match(rules(doc_row(true_origem_uf = "XX")), "UF")
  expect_match(rules(doc_row(true_n_vitimas = "2 autores")), "inteiro")
  expect_equal(nrow(check_annotation(doc_row(true_origem_uf = "TRF3", true_valor_stj = "10000; 5000"), "documentos")), 0)
})

test_that("Q13: nao_consta is a valid code and forces exclusion as sem_valor_estagio", {
  good <- doc_row(true_materia = "nao_consta", true_menciona_dano_moral = "nao", true_resultado_stj = "sem_dano_moral",
                  true_incluir = "nao", true_motivo_exclusao = "sem_valor_estagio")
  expect_equal(nrow(check_annotation(good, "documentos")), 0)
  expect_true(any(grepl("Q13", rules(modifyList(good, list(true_motivo_exclusao = "materia_diversa")) |> as_tibble()))))
  expect_true(any(grepl("Q13", rules(modifyList(good, list(true_incluir = "sim", true_motivo_exclusao = "")) |> as_tibble()))))
})

test_that("coherence rules between outcome, mention, values and inclusion", {
  r <- rules(doc_row(true_menciona_dano_moral = "nao", true_resultado_stj = "mantido"))
  expect_true(any(grepl("menciona = nao", r)))
  expect_true(any(grepl("Q15", rules(doc_row(true_resultado_stj = "sem_dano_moral", true_valor_sentenca = "5000")))))
  expect_true(any(grepl("exige motivo", rules(doc_row(true_incluir = "nao")))))
  expect_true(any(grepl("não leva motivo", rules(doc_row(true_incluir = "sim", true_motivo_exclusao = "outro", true_materia = "negativacao",
                                                        true_valor_stj = "5000")))))
  expect_true(any(grepl("critério 4", rules(doc_row(true_incluir = "sim", true_materia = "plano_saude")))))
  expect_true(any(grepl("exige matéria", rules(doc_row(true_incluir = "sim", true_materia = "outra", true_valor_stj = "5000")))))
  w <- check_annotation(doc_row(true_resultado_stj = "mantido_sumula7"), "documentos")
  expect_equal(w$gravidade, "aviso")                                     # Súmula 7 sem valor de origem só avisa
})

test_that("amount sheet: Q9 forbids stage/direction inside a cited precedent", {
  v <- tibble(item_id = c("V001", "V002"), true_valor_correto = c("sim", "s"), true_category = c("dano_moral", "dano_moral"),
              true_stage = c("indeterminado", "stj"), true_direction = c("indeterminado", "aumento"),
              true_in_precedent = c("sim", "sim"), true_reference_value = c("nao", "nao"))
  p <- check_annotation(v, "valores")
  expect_equal(unique(p$item_id), "V002"); expect_equal(nrow(p), 2)
  expect_match(rules(tibble(item_id = "V1", true_valor_correto = "talvez", true_category = "", true_stage = "", true_direction = "",
                            true_in_precedent = "", true_reference_value = ""), "valores"), "vocabulário")
})

test_that("ia_change_rate counts the researcher's changes field by field (Q10)", {
  ia <- bind_rows(doc_row(item_id = "D1", true_materia = "outra", true_valor_sentenca = "5.000,00", true_origem_uf = "SP"),
                  doc_row(item_id = "D2", true_materia = "negativacao", true_valor_sentenca = "", true_origem_uf = "MG"))
  fin <- bind_rows(doc_row(item_id = "D1", true_materia = "nao_consta", true_valor_sentenca = "5000", true_origem_uf = "sp"),
                   doc_row(item_id = "D2", true_materia = "negativacao", true_valor_sentenca = "3000", true_origem_uf = ""))
  r <- ia_change_rate(ia, fin, "documentos")
  expect_equal(r$alterados[r$campo == "true_materia"], 1); expect_equal(r$taxa[r$campo == "true_materia"], 0.5)
  expect_equal(r$alterados[r$campo == "true_valor_sentenca"], 1)        # "5.000,00" = "5000"; vazio → 3000 mudou
  expect_equal(r$n[r$campo == "true_origem_uf"], 1); expect_equal(r$alterados[r$campo == "true_origem_uf"], 0)
  expect_equal(r$n[r$campo == "true_incluir"], 0)                       # campo vazio na versão final não conta
})
