test_that("expected_loss matches the closed-form EL = sum(PD*LGD*EAD)", {
  pd  <- c(0.05, 0.10, 0.02)
  lgd <- c(0.5, 0.6, 0.4)
  ead <- c(10000, 20000, 5000)
  expected <- sum(pd * lgd * ead)
  expect_equal(expected_loss(pd, lgd, ead), expected)})

test_that("var_from_losses matches base R quantile on a known distribution", {
  set.seed(10)
  losses <- rnorm(10000, mean = 1000, sd = 200)
  expect_equal(
    var_from_losses(losses, confidence = 0.95),
    as.numeric(quantile(losses, 0.95)))})

test_that("cvar is always >= var at the same confidence level", {
  set.seed(11)
  losses <- rgamma(10000, shape = 2, scale = 500)
  v <- var_from_losses(losses, 0.99)
  c <- cvar_from_losses(losses, 0.99)
  expect_gte(c, v)})

test_that("risk_summary returns one row per confidence level with EL constant across rows", {
  set.seed(12)
  losses <- rgamma(5000, shape = 2, scale = 300)
  levels <- c(0.90, 0.95, 0.99)
  summary_df <- risk_summary(losses, confidence_levels = levels)
  expect_equal(nrow(summary_df), length(levels))
  expect_equal(unique(summary_df$expected_loss), mean(losses))
  expect_true(all(diff(summary_df$var) >= 0))
  expect_true(all(diff(summary_df$cvar) >= 0))})

test_that("run_stress_scenario produces a stressed distribution with >= expected loss than baseline", {
  set.seed(13)
  pd  <- runif(200, 0.02, 0.15)
  ead <- runif(200, 5000, 25000)
  lgd <- runif(200, 0.3, 0.6)
  result <- run_stress_scenario(pd, ead, lgd, rho = 0.15, n_sim = 8000, stress_shift = -2, seed = 13)
  baseline_el <- mean(result$baseline$losses)
  stressed_el <- mean(result$stressed$losses)
  expect_gt(stressed_el, baseline_el)})