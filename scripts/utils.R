fmt_currency <- function(x) {
  paste0("$", formatC(round(x), format = "d", big.mark = ","))}

safe_ntile <- function(x, n) {
  dplyr::ntile(x, n)}

combine_model_predictions <- function(actual, scorecard_pred, xgb_pred) {
  data.frame(
    actual = actual,
    scorecard_pd = scorecard_pred,
    xgboost_pd = xgb_pred)}