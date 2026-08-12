library(dplyr)
library(pROC)

auc_score <- function(actual, predicted) {
  as.numeric(pROC::auc(pROC::roc(actual, predicted, quiet = TRUE)))}

ks_statistic <- function(actual, predicted) {
  roc_obj <- pROC::roc(actual, predicted, quiet = TRUE)
  max(abs(roc_obj$sensitivities - (1 - roc_obj$specificities)))}

calibration_table <- function(actual, predicted, n_bins = 10) {
  tibble(actual = actual, predicted = predicted) %>%
    mutate(bin = ntile(predicted, n_bins)) %>%
    group_by(bin) %>%
    summarise(
      n = n(),
      mean_predicted_pd = mean(predicted),
      observed_default_rate = mean(actual),
      .groups = "drop")}

psi <- function(expected, actual, n_bins = 10) {
  breaks <- quantile(expected, probs = seq(0, 1, length.out = n_bins + 1), na.rm = TRUE)
  breaks[1] <- -Inf
  breaks[length(breaks)] <- Inf
  breaks <- unique(breaks)
  exp_counts <- table(cut(expected, breaks = breaks, include.lowest = TRUE))
  act_counts <- table(cut(actual,   breaks = breaks, include.lowest = TRUE))
  exp_pct <- pmax(as.numeric(exp_counts) / sum(exp_counts), 1e-6)
  act_pct <- pmax(as.numeric(act_counts) / sum(act_counts), 1e-6)
  sum((act_pct - exp_pct) * log(act_pct / exp_pct))}

evaluate_model <- function(train_actual, train_pred, test_actual, test_pred) {
  list(
    train_auc = auc_score(train_actual, train_pred),
    test_auc  = auc_score(test_actual, test_pred),
    train_ks  = ks_statistic(train_actual, train_pred),
    test_ks   = ks_statistic(test_actual, test_pred),
    psi       = psi(train_pred, test_pred),
    calibration = calibration_table(test_actual, test_pred))}