# feasibility.R — gate G4 do plano de estimação (docs/10_estimation_plan.md §0): quanto dado há para cada modelo.
# Funções puras sobre o data frame de eventos de R/awards_rules.R; o script scripts/10_feasibility.R só faz I/O.
# Produz CONTAGENS e uma recomendação por modelo — nunca estimativas. Nenhum texto de decisão, nome ou trecho sai daqui.
#
# Limiares: `min_events_per_covariate = 10` vem do plano (§5, RQ4). Os demais (`min_month_n`, `min_month_share`,
# `min_court_n`, `min_event_window_n`, `n_covariates_rq4`) são PROPOSTOS por esta implementação — o plano diz apenas que
# o mínimo é "definido no feasibility" — e ficam em FEAS_DEFAULTS para o pesquisador ajustar; ajustá-los é decisão a
# registrar no decisions_log antes de olhar os resultados.
suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(purrr); library(stringi); library(tibble) })

FEAS_DEFAULTS <- list(
  min_events_per_covariate = 10,                 # plano §5
  n_covariates_rq4 = 6,                          # valor de origem (log), matéria, órgão, classe, Súmula 7, ano (plano §5)
  min_month_n = 20L,                             # eventos por matéria-mês para série mensal (§6)
  min_month_share = 0.8,                         # fração de meses que precisa atingir o mínimo para manter a série mensal
  min_court_n = 30L,                             # eventos por tribunal de origem para entrar no modelo hierárquico (§4)
  min_event_window_n = 30L,                      # eventos pré e pós Tema 1365 para o estudo de caso (§6)
  tema1365_date = as.Date("2026-03-20"),         # docs/02; CONFERIR na fonte antes de usar (plano §6)
  response = "valor_acordao_origem")

# pacotes exigidos por cada bloco do plano
TOOLCHAIN_PKGS <- c(quantreg = "RQ1", fixest = "RQ2 (robustez)", lme4 = "RQ2 (fallback)", glmmTMB = "RQ2 (fallback)", brms = "RQ2 (principal)",
                    rstan = "RQ2 (Stan)", cmdstanr = "RQ2 (Stan, alternativa)", brglm2 = "RQ4", strucchange = "RQ5", mgcv = "RQ2/RQ5",
                    tidymodels = "RQ6", xgboost = "RQ6", ranger = "RQ6", probably = "RQ6 (conformal)", shapviz = "RQ6 (SHAP)", arrow = "awards.parquet")

check_toolchain <- function(pkgs = names(TOOLCHAIN_PKGS)) {
  tibble(pacote = pkgs, uso = unname(TOOLCHAIN_PKGS[pkgs]),
         instalado = map_lgl(pkgs, requireNamespace, quietly = TRUE),
         versao = map_chr(pkgs, ~ tryCatch(as.character(utils::packageVersion(.x)), error = function(e) NA_character_)))
}

# Compila um modelo Stan mínimo (risco 4 de docs/04: Rtools/cmdstan no Windows). Só roda sob demanda (--stan-test).
stan_compile_test <- function() {
  code <- "parameters { real y; } model { y ~ normal(0, 1); }"
  t0 <- Sys.time()
  if (requireNamespace("cmdstanr", quietly = TRUE) && !is.null(tryCatch(cmdstanr::cmdstan_version(error_on_NA = FALSE), error = function(e) NULL))) {
    r <- tryCatch({ f <- cmdstanr::write_stan_file(code); cmdstanr::cmdstan_model(f, quiet = TRUE); TRUE }, error = function(e) conditionMessage(e))
    return(list(ok = isTRUE(r), engine = "cmdstanr", seconds = as.numeric(difftime(Sys.time(), t0, units = "secs")), msg = if (isTRUE(r)) "" else r))
  }
  if (requireNamespace("rstan", quietly = TRUE)) {
    r <- tryCatch({ rstan::stan_model(model_code = code, verbose = FALSE); TRUE }, error = function(e) conditionMessage(e))
    return(list(ok = isTRUE(r), engine = "rstan", seconds = as.numeric(difftime(Sys.time(), t0, units = "secs")), msg = if (isTRUE(r)) "" else r))
  }
  list(ok = FALSE, engine = NA_character_, seconds = NA_real_, msg = "nem cmdstanr (com CmdStan) nem rstan instalados")
}

feasibility_tables <- function(events, th = FEAS_DEFAULTS) {
  th <- modifyList(FEAS_DEFAULTS, th)
  pop <- analysis_population(events, th$response)
  mats <- sort(unique(na.omit(events$materia)))

  stage_n <- events |> filter(incluir, evento_primario, !ambiguo) |> group_by(materia) |>
    summarise(across(all_of(VALOR_COLS), ~ sum(!is.na(.x)), .names = "{.col}"), n_eventos = n(), .groups = "drop")

  origin <- pop |> group_by(materia) |> summarise(n = n(), com_origem = sum(origem_conhecida), .groups = "drop") |>
    mutate(share_origem = if_else(n > 0, com_origem / n, NA_real_))

  courts <- pop |> filter(origem_conhecida) |> count(origem_uf, name = "n") |> arrange(desc(n)) |>
    mutate(entra_hierarquico = n >= th$min_court_n)

  # RQ4: eventos de alteração entre os documentos incluídos e não ambíguos do evento primário (corpus completo, não só a amostra)
  rq4_base <- events |> filter(incluir, evento_primario, !ambiguo)
  rq4 <- bind_rows(rq4_base |> group_by(materia) |> summarise(n = n(), eventos = sum(alterou_stj), .groups = "drop"),
                   tibble(materia = "todas", n = nrow(rq4_base), eventos = sum(rq4_base$alterou_stj))) |>
    mutate(eventos_por_covariavel = eventos / th$n_covariates_rq4,
           modo = if_else(eventos_por_covariavel >= th$min_events_per_covariate, "firth", "descritivo"))

  monthly <- pop |> mutate(mes = format(as.Date(data_publicacao), "%Y-%m")) |> count(materia, mes, name = "n") |>
    group_by(materia) |> summarise(meses = n(), meses_ok = sum(n >= th$min_month_n), share_ok = meses_ok / meses, mediana_n = median(n), .groups = "drop") |>
    mutate(granularidade = if_else(share_ok >= th$min_month_share, "mensal", "trimestral"))

  tema <- pop |> filter(materia %in% c("plano_saude", "ambas")) |>
    summarise(pre = sum(as.Date(data_publicacao) < th$tema1365_date), pos = sum(as.Date(data_publicacao) >= th$tema1365_date)) |>
    mutate(janela_ok = pre >= th$min_event_window_n & pos >= th$min_event_window_n)

  list(thresholds = th, attrition = attrition_table(events, th$response), stage_n = stage_n, origin = origin, courts = courts,
       rq4 = rq4, monthly = monthly, tema = tema, n_pop = nrow(pop),
       pj_filter_active = any(!is.na(events$autor_pj)))
}

# Uma linha por modelo do plano: viável? + regra aplicada. `toolchain` e `stan` vêm de check_toolchain()/stan_compile_test().
feasibility_decisions <- function(res, toolchain = NULL, stan = NULL) {
  th <- res$thresholds; has <- function(p) is.null(toolchain) || isTRUE(toolchain$instalado[toolchain$pacote == p])
  rq4_all <- res$rq4 |> filter(materia == "todas")
  n_courts <- sum(res$courts$entra_hierarquico); n_pop <- res$n_pop
  stan_ok <- isTRUE(stan$ok)
  tribble(
    ~modelo, ~viavel, ~regra,
    "RQ1 regressão quantílica / duas partes", n_pop >= 200 && has("quantreg"), "N da população de análise ≥ 200 e quantreg instalado (limiar proposto)",
    "RQ2 hierárquico bayesiano (brms)", n_courts >= 5 && stan_ok && has("brms"), sprintf("≥ 5 tribunais com ≥ %d eventos (%d); Stan compila: %s", th$min_court_n, n_courts, if (is.null(stan)) "não testado" else stan_ok),
    "RQ2 hierárquico (fallback lme4/glmmTMB)", n_courts >= 5 && (has("lme4") || has("glmmTMB")), sprintf("≥ 5 tribunais com ≥ %d eventos (%d)", th$min_court_n, n_courts),
    "RQ4 logística de Firth", nrow(rq4_all) == 1 && rq4_all$modo == "firth" && has("brglm2"), sprintf("eventos/covariável ≥ %g (%.1f eventos, %d covariáveis)", th$min_events_per_covariate, rq4_all$eventos, th$n_covariates_rq4),
    "RQ4 descritiva (plano de contingência)", TRUE, "sempre disponível (IC exatos)",
    "RQ5 série mensal", any(res$monthly$granularidade == "mensal"), "≥ 80% dos meses com n mínimo em ao menos uma matéria (limiar proposto)",
    "RQ5 evento Tema 1365", isTRUE(res$tema$janela_ok), sprintf("≥ %d eventos antes e depois de %s", th$min_event_window_n, format(th$tema1365_date)),
    "RQ6 preditivo", n_pop >= 500 && has("xgboost"), "N ≥ 500 e xgboost instalado (limiar proposto)")
}

feasibility_md <- function(res, decisions, toolchain, stan = NULL, generated = Sys.Date(), db_note = "") {
  th <- res$thresholds
  pct <- function(t) mutate(t, across(any_of(c("share_origem", "share_ok")), ~ round(.x, 3)))
  c("# 10a — Relatório de viabilidade (gate G4) — apenas contagens",
    "", sprintf("Gerado por `scripts/10_feasibility.R` em %s. %s**Nenhuma estimação.** Eventos = extração automática (`fonte_valores = automatico`),", format(generated), db_note),
    "sem revisão manual; os limiares abaixo são propostos e estão em `R/feasibility.R` (`FEAS_DEFAULTS`).",
    "", "## Atrito (docs/10 §1)", md_table(res$attrition),
    "", "## Valores por estágio (incluídos, evento primário, sem ambiguidade)", md_table(res$stage_n),
    "", sprintf("## Origem conhecida (população de análise: %d eventos)", res$n_pop), md_table(pct(res$origin)),
    "", sprintf("## Tribunais de origem (limiar: %d eventos)", th$min_court_n), if (nrow(res$courts)) md_table(res$courts) else "_nenhum tribunal com origem conhecida_",
    "", "## RQ4 — eventos de alteração pelo STJ", md_table(res$rq4),
    "", sprintf("## Séries (limiar: %d eventos por matéria-mês; ≥ %.0f%% dos meses)", th$min_month_n, 100 * th$min_month_share), md_table(pct(res$monthly)),
    "", sprintf("## Tema 1365 (corte %s — conferir na fonte)", format(th$tema1365_date)), md_table(res$tema),
    "", "## Decisões por modelo", md_table(mutate(decisions, viavel = ifelse(viavel, "sim", "não"))),
    "", "## Ambiente", md_table(toolchain |> mutate(instalado = ifelse(instalado, "sim", "não"))),
    "", if (is.null(stan)) "Teste de compilação do Stan: **não executado** (rode com `--stan-test`)." else
      sprintf("Teste de compilação do Stan: %s (motor: %s, %.0f s)%s", ifelse(stan$ok, "**ok**", "**falhou**"), stan$engine, stan$seconds, if (nzchar(stan$msg)) paste0(" — ", substr(stan$msg, 1, 200)) else ""),
    "", if (!res$pj_filter_active) "**Aviso:** `autor_pj` ainda não é extraído nem anotado; a exclusão de pessoa jurídica autora (docs/10 §9, item 7) **não está aplicada** nestas contagens." else NULL,
    "", "**Limitação da deflação:** a data de fixação do valor na origem não é extraída; a série usa a data de publicação da decisão do STJ (posterior), o que subestima a deflação em média.")
}
