expected_loss <- function(pd, lgd, ead) {
  sum(pd * lgd * ead)}

var_from_losses <- function(loss_distribution, confidence = 0.99) {
  as.numeric(quantile(loss_distribution, probs = confidence, names = FALSE))}

cvar_from_losses <- function(loss_distribution, confidence = 0.99) {
  var_threshold <- var_from_losses(loss_distribution, confidence)
  tail_losses <- loss_distribution[loss_distribution >= var_threshold]
  if (length(tail_losses) == 0) return(var_threshold)
  mean(tail_losses)}

risk_summary <- function(loss_distribution, confidence_levels = c(0.95, 0.99, 0.999)) {
  data.frame(
    confidence = confidence_levels,
    expected_loss = mean(loss_distribution),
    var  = sapply(confidence_levels, var_from_losses, loss_distribution = loss_distribution),
    cvar = sapply(confidence_levels, cvar_from_losses, loss_distribution = loss_distribution))}

run_stress_scenario <- function(pd, ead, lgd, rho = 0.15, n_sim = 10000,
                                 stress_shift = -2, seed = 42) {
  baseline_defaults <- simulate_correlated_defaults(pd, rho, n_sim, stress_shift = 0, seed = seed)
  stressed_defaults  <- simulate_correlated_defaults(pd, rho, n_sim, stress_shift = stress_shift, seed = seed)
  baseline_losses <- simulate_portfolio_loss(baseline_defaults, ead, lgd)
  stressed_losses  <- simulate_portfolio_loss(stressed_defaults, ead, lgd)
  list(
    baseline = list(losses = baseline_losses, summary = risk_summary(baseline_losses)),
    stressed = list(losses = stressed_losses, summary = risk_summary(stressed_losses)))}