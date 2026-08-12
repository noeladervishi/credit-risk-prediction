library(dplyr)
library(xgboost)
library(DALEX)

compute_shap_values <- function(xgb_model, newdata) {
  x <- xgb_model$align(xgb_model$encode(newdata))
  predict(xgb_model$booster, xgboost::xgb.DMatrix(x), predcontrib = TRUE)}

global_shap_summary <- function(shap_matrix) {
  shap_df <- as.data.frame(shap_matrix) %>% select(-BIAS)
  tibble(
    feature = names(shap_df),
    mean_abs_shap = sapply(shap_df, function(col) mean(abs(col)))
  ) %>%
    arrange(desc(mean_abs_shap))}

explain_borrower <- function(shap_matrix, row_index, top_n = 5) {
  row_vals <- shap_matrix[row_index, ]
  row_vals <- row_vals[names(row_vals) != "BIAS"]
  tibble(
    feature = names(row_vals),
    shap_value = as.numeric(row_vals),
    direction = if_else(shap_value > 0, "Increases risk", "Decreases risk")
  ) %>%
    arrange(desc(abs(shap_value))) %>%
    slice_head(n = top_n)}

build_dalex_explainer <- function(scorecard_model, train_df, predict_fn) {
  DALEX::explain(
    model = scorecard_model,
    data = train_df %>% select(all_of(scorecard_model$features)),
    y = train_df$default_flag,
    predict_function = function(m, newdata) predict_fn(m, newdata),
    label = "Logistic Scorecard Benchmark",
    verbose = FALSE)}