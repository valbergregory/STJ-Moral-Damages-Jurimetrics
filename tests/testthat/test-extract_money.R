root <- Sys.getenv("STJMD_ROOT", unset = normalizePath(file.path(testthat::test_path(), "..", "..")))
source(file.path(root, "R", "extract_money.R"))

test_that("parse_brl handles pt-BR formats", {
  expect_equal(parse_brl("R$ 25.000,00"), 25000)
  expect_equal(parse_brl("R$ 1.500.000,50"), 1500000.5)
  expect_equal(parse_brl("R$ 800,00"), 800)
  expect_equal(parse_brl("R$ 10.000"), 10000)
})

test_that("words_to_number parses extenso", {
  expect_equal(words_to_number("vinte e cinco mil"), 25000)
  expect_equal(words_to_number("cento e cinquenta mil"), 150000)
  expect_equal(words_to_number("um milhão e duzentos mil"), 1200000)
  expect_equal(words_to_number("dez mil"), 10000)
  expect_equal(words_to_number("três mil e quinhentos"), 3500)
})

test_that("find_amounts merges cifra + extenso and flags mismatch", {
  t <- "fixou em R$ 25.000,00 (vinte e cinco mil reais) e honorários de R$ 2.000,00 (dois mil reais)."
  a <- find_amounts(t)
  expect_equal(nrow(a), 2); expect_true(all(a$extenso_parenthetical)); expect_false(any(a$extenso_mismatch))
  a2 <- find_amounts("R$ 15.000,00 (dez mil reais)"); expect_true(a2$extenso_mismatch[1])
  a3 <- find_amounts("condenou ao pagamento de 50 mil reais e de 10 (dez) salários mínimos")
  expect_equal(a3$value, c(50000, 10)); expect_equal(a3$unit, c("BRL", "SM"))
})

test_that("classify_amount separates honorarios from dano moral", {
  t <- "O Tribunal de origem fixou a indenização por danos morais em R$ 20.000,00 (vinte mil reais), e os honorários advocatícios em R$ 1.000,00 (mil reais)."
  e <- extract_money(t, "x")
  expect_equal(e$category, c("dano_moral", "honorarios")); expect_equal(e$stage[1], "origem_acordao")
})

test_that("stj_quantum_outcome detects reduction in dispositive", {
  t <- "Trata-se de recurso sobre danos morais. O valor é exorbitante. Ante o exposto, dou parcial provimento ao recurso especial para reduzir a indenização por danos morais para R$ 10.000,00."
  expect_equal(stj_quantum_outcome(t)$outcome, "reduzido_stj")
})
