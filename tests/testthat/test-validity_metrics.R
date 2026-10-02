root <- Sys.getenv("STJMD_ROOT", unset = normalizePath(file.path(testthat::test_path(), "..", "..")))
source(file.path(root, "R", "validity_metrics.R"))
fx <- file.path(root, "tests", "testthat", "fixtures", "w3")

test_that("labels, booleans and hand-typed BRL values are normalised", {
  expect_equal(norm_label(c(" Dano moral ", "redução", "", NA, "origem-acordao")), c("dano_moral", "reducao", NA, NA, "origem_acordao"))
  expect_equal(parse_bool_pt(c("sim", "Não", "TRUE", "0", "", "talvez")), c(TRUE, FALSE, TRUE, FALSE, NA, NA))
  expect_equal(parse_brl_input(c("R$ 10.000,00", "10.000", "10000", "10000,5", "1.500.000", "10 mil", "", "-")),
               c(10000, 10000, 10000, 10000.5, 1500000, 10000, NA, NA))
  expect_equal(parse_value_set(c("10000; 5000", "", "R$ 2.000,00"))[[1]], c(5000, 10000))
  expect_length(parse_value_set("")[[1]], 0)
})

test_that("prf_table matches hand-computed precision, recall and F1", {
  pred <- c("dm", "dm", "dm", "dm", "dm", "hon", "hon"); truth <- c("dm", "dm", "dm", "dm", "hon", "hon", "hon")
  r <- prf_table(pred, truth); t <- r$table
  expect_equal(t$precision[t$class == "dm"], 0.8); expect_equal(t$recall[t$class == "dm"], 1)
  expect_equal(t$f1[t$class == "hon"], 0.8); expect_equal(t$f1[t$class == "macro"], (2 * 0.8 / 1.8 + 0.8) / 2)
  expect_equal(r$accuracy, 6 / 7); expect_equal(r$n, 7)
  # classe só predita (nunca verdadeira) entra com 0 no macro (convenção scikit-learn)
  t2 <- prf_table(c("a", "b"), c("a", "a"))$table
  expect_true(is.na(t2$recall[t2$class == "b"])); expect_equal(t2$f1[t2$class == "macro"], (2 * 0.5 / 1.5 + 0) / 2)
  # rótulo verdadeiro NA é ignorado; pesos de desenho
  expect_equal(prf_table(c("a", "b"), c("a", NA))$n, 1)
  expect_equal(prf_table(c("a", "b", "b"), c("a", "a", "b"), w = c(1, 1, 8))$accuracy, 0.9)
})

test_that("Cohen's kappa reproduces the textbook 2x2 example", {
  a <- c(rep("y", 25), rep("n", 25)); b <- c(rep("y", 20), rep("n", 5), rep("y", 10), rep("n", 15))
  k <- cohen_kappa(a, b)
  expect_equal(k$po, 0.7); expect_equal(k$pe, 0.5); expect_equal(k$kappa, 0.4)
  expect_equal(cohen_kappa(c("x", "y", NA), c("x", "y", "y"))$kappa, 1)
  expect_true(is.na(cohen_kappa(c("x", "x"), c("x", "x"))$kappa))   # pe = 1: indefinido
})

test_that("stage value sets are matched with tolerance", {
  m <- match_value_sets(list(c(10000, 12000), numeric(0), 5000, numeric(0)), list(10000, numeric(0), numeric(0), 15000))
  expect_equal(m$tp, c(TRUE, FALSE, FALSE, FALSE)); expect_equal(m$fp, c(FALSE, FALSE, TRUE, FALSE))
  expect_equal(m$fn, c(FALSE, FALSE, FALSE, TRUE)); expect_equal(m$tn, c(FALSE, TRUE, FALSE, FALSE)); expect_equal(m$exato, c(FALSE, TRUE, FALSE, FALSE))
  expect_equal(prf_counts(3, 1, 2)$f1, 2 * 0.75 * 0.6 / 1.35)
})

test_that("bootstrap CI is seeded and brackets the point estimate", {
  set.seed(1); truth <- sample(c("a", "b", "c"), 60, TRUE); pred <- ifelse(runif(60) < 0.8, truth, "a")
  ci1 <- bootstrap_ci(pred, truth, B = 200, seed = 7); ci2 <- bootstrap_ci(pred, truth, B = 200, seed = 7)
  expect_identical(ci1, ci2); expect_true(ci1[["lo"]] <= macro_f1(pred, truth) && macro_f1(pred, truth) <= ci1[["hi"]])
})

test_that("Excel pt-BR CSV (semicolon + BOM) is read", {
  d <- read_annotation_csv(file.path(fx, "w3_valores_VG.csv"))
  expect_equal(names(d)[1], "item_id"); expect_equal(nrow(d), 8); expect_equal(d$true_in_precedent[1], "não")
})

test_that("04_validity_metrics.R runs end-to-end on synthetic fixtures", {
  tmp <- file.path(tempdir(), "w3_metrics"); unlink(tmp, recursive = TRUE)
  dir.create(file.path(tmp, "R"), recursive = TRUE); dir.create(file.path(tmp, "data", "annotations"), recursive = TRUE)
  file.copy(file.path(root, "R", "validity_metrics.R"), file.path(tmp, "R"))
  file.copy(list.files(fx, "\\.csv$", full.names = TRUE), file.path(tmp, "data", "annotations"))
  old <- Sys.getenv("STJMD_ROOT"); Sys.setenv(STJMD_ROOT = tmp); on.exit(Sys.setenv(STJMD_ROOT = old), add = TRUE)
  expect_output(source(file.path(root, "scripts", "04_validity_metrics.R"), local = new.env()), "07_extraction_validity")
  md <- readLines(file.path(tmp, "docs", "07_extraction_validity.md"), encoding = "UTF-8")
  # categoria: 7 itens anotados, acurácia 6/7, macro-F1 = (0.889 + 0.800)/2
  expect_true(any(grepl("### Categoria — n = 7 · acurácia 0.857 · macro-F1 0.844", md, fixed = TRUE)))
  expect_true(any(grepl("F1 da classe `dano_moral` na categoria: 0.889", md, fixed = TRUE)))
  expect_true(any(grepl("Leitura do número (`true_valor_correto`): 6 de 7 corretos", md, fixed = TRUE)))
  expect_true(any(grepl("### Resultado no STJ quanto ao quantum — n = 4 · acurácia 0.750", md, fixed = TRUE)))
  # valor no estágio STJ: D002 TP (10000 entre {10000; 12000}), D004 FN → P = 1, R = 0.5
  expect_true(any(grepl("| stj | 4 | 1 | 0 | 1 | 1.000 | 0.500 | 0.667 | 0.500 |", md, fixed = TRUE)))
  expect_true(any(grepl("| origem_acordao | 4 | 3 | 0 | 0 | 1.000 | 1.000 | 1.000 | 1.000 |", md, fixed = TRUE)))
  # kappa intra-anotador: categoria 4/4 concordes (κ = 1); estágio 3/4 (κ = 0.6); resultado STJ dos docs 1/2
  expect_true(any(grepl("| categoria | 4 | 1.000 | 0.625 | 1.000 |", md, fixed = TRUE)))
  expect_true(any(grepl("| estagio | 4 | 0.750 | 0.375 | 0.600 |", md, fixed = TRUE)))
  expect_true(any(grepl("| resultado_stj | 2 | 0.500 |", md, fixed = TRUE)))
  expect_true(any(grepl("Gate da Semana 3", md)))
  expect_true(file.exists(file.path(tmp, "outputs", "overleaf", "tables", "extraction_validity.tex")))
})

test_that("fast macro_f1 equals the macro row of prf_table", {
  set.seed(3)
  for (i in 1:20) {
    truth <- sample(c("a", "b", "c", "d", NA), 40, TRUE); pred <- sample(c("a", "b", "c", "e"), 40, TRUE); w <- runif(40, 1, 10)
    t <- prf_table(pred, truth, w)$table
    expect_equal(macro_f1(pred, truth, w), t$f1[t$class == "macro"])
  }
})
