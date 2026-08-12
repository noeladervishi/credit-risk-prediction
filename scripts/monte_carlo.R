simulate_correlated_defaults <- function(pd, rho = 0.15, n_sim = 10000,
                                          stress_shift = 0, seed = 42) {
  if (any(pd <= 0 | pd >= 1)) {
    stop("pd values must be strictly between 0 and 1 (exclusive)")}
  if (rho < 0 || rho >= 1) stop("rho must be in [0, 1)")
  set.seed(seed)
  n <- length(pd)
  default_threshold <- qnorm(pd)             
  M <- rnorm(n_sim) + stress_shift            
  epsilon <- matrix(rnorm(n_sim * n), nrow = n_sim, ncol = n)
  Z <- sqrt(rho) * M + sqrt(1 - rho) * epsilon
  defaults <- sweep(Z, 2, default_threshold, FUN = "<=") * 1L
  attr(defaults, "rho") <- rho
  attr(defaults, "stress_shift") <- stress_shift
  defaults}

simulate_portfolio_loss <- function(default_matrix, ead, lgd) {
  loss_per_borrower <- ead * lgd           
  as.numeric(default_matrix %*% loss_per_borrower)}

empirical_default_correlation <- function(default_matrix) {
  cor_matrix <- cor(default_matrix)
  diag(cor_matrix) <- NA
  mean(cor_matrix, na.rm = TRUE)}