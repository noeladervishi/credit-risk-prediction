test_that("simulate_correlated_defaults produces the expected marginal default rate", {
  set.seed(1)
  pd <- rep(0.10, 500)
  defaults <- simulate_correlated_defaults(pd, rho = 0.15, n_sim = 20000, seed = 1)
  observed_rate <- mean(defaults)
  expect_equal(observed_rate, 0.10, tolerance = 0.01)})

test_that("higher rho produces higher empirical default correlation", {
  pd <- rep(0.08, 300)
  low_rho  <- simulate_correlated_defaults(pd, rho = 0.05, n_sim = 20000, seed = 2)
  high_rho <- simulate_correlated_defaults(pd, rho = 0.40, n_sim = 20000, seed = 2)
  cor_low  <- empirical_default_correlation(low_rho)
  cor_high <- empirical_default_correlation(high_rho)
  expect_gt(cor_high, cor_low)})

test_that("stress_shift increases the simulated default rate when negative", {
  pd <- rep(0.10, 500)
  baseline <- simulate_correlated_defaults(pd, rho = 0.15, n_sim = 20000, stress_shift = 0, seed = 3)
  stressed <- simulate_correlated_defaults(pd, rho = 0.15, n_sim = 20000, stress_shift = -2, seed = 3)
  expect_gt(mean(stressed), mean(baseline))})

test_that("simulate_portfolio_loss returns one loss value per simulation and is non-negative", {
  set.seed(4)
  pd <- runif(100, 0.02, 0.20)
  ead <- runif(100, 5000, 30000)
  lgd <- runif(100, 0.3, 0.7)
  defaults <- simulate_correlated_defaults(pd, rho = 0.15, n_sim = 5000, seed = 4)
  losses <- simulate_portfolio_loss(defaults, ead, lgd)
  expect_length(losses, 5000)
  expect_true(all(losses >= 0))})

test_that("simulate_correlated_defaults rejects invalid inputs", {
  expect_error(simulate_correlated_defaults(c(0, 0.1), rho = 0.1))
  expect_error(simulate_correlated_defaults(c(1, 0.1), rho = 0.1))
  expect_error(simulate_correlated_defaults(c(0.1, 0.2), rho = 1))})