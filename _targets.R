library(targets)

# Source all project functions
for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) source(f)

tar_option_set(
  packages = c("dplyr", "readr", "lubridate", "pROC", "scorecard", "xgboost", "DALEX"))

RAW_DATA_PATH <- "data/raw/accepted_2007_to_2018Q4.csv"

list(
  # Data ingestion & cleaning
  tar_target(raw_path_file, RAW_DATA_PATH, format = "file"),
  tar_target(raw_loans, load_raw_loans(raw_path_file)),
  tar_target(cleaned_loans, {
    df <- clean_loans(raw_loans)
    validate_loan_schema(df)
    df}),
  # Vintage-based (out-of-time) split
  tar_target(vintage_split, split_by_vintage(cleaned_loans)),
  tar_target(train_df, vintage_split$train),
  tar_target(val_df,   vintage_split$val),
  tar_target(test_df,  vintage_split$test),
  # Logistic / scorecard benchmark
  tar_target(scorecard_model, train_scorecard_model(train_df)),
  tar_target(scorecard_train_pred, predict_scorecard(scorecard_model, train_df)),
  tar_target(scorecard_test_pred,  predict_scorecard(scorecard_model, test_df)),
  # XGBoost model + evaluation
  tar_target(xgb_model, train_xgboost_model(train_df, val_df)),
  tar_target(xgb_train_pred, predict_xgboost(xgb_model, train_df)),
  tar_target(xgb_test_pred,  predict_xgboost(xgb_model, test_df)),
  tar_target(scorecard_eval, evaluate_model(
    train_df$default_flag, scorecard_train_pred,
    test_df$default_flag,  scorecard_test_pred)),
  tar_target(xgb_eval, evaluate_model(
    train_df$default_flag, xgb_train_pred,
    test_df$default_flag,  xgb_test_pred)),
  # Monte Carlo simulation + risk metrics
  tar_target(mc_pd,  pmin(pmax(xgb_test_pred, 1e-4), 1 - 1e-4)),
  tar_target(mc_ead, test_df$ead),
  tar_target(mc_lgd, {
    mean_lgd <- mean(train_df$lgd[train_df$default_flag == 1], na.rm = TRUE)
    rep(mean_lgd, length(mc_pd))}),
  tar_target(baseline_defaults, simulate_correlated_defaults(mc_pd, rho = 0.15, n_sim = 10000, stress_shift = 0)),
  tar_target(loss_distribution, simulate_portfolio_loss(baseline_defaults, mc_ead, mc_lgd)),
  tar_target(risk_metrics_summary, risk_summary(loss_distribution)),
  tar_target(stress_scenario, run_stress_scenario(mc_pd, mc_ead, mc_lgd, rho = 0.15, n_sim = 10000, stress_shift = -2)),
  # Explainability
  tar_target(shap_values, compute_shap_values(xgb_model, test_df)),
  tar_target(shap_global, global_shap_summary(shap_values)),
  # Final report
  tar_target(
    model_risk_report, {
      rmarkdown::render(
        "report/model_risk_report.Rmd",
        output_file = "../outputs/model_risk_report.html",
        params = list(confidence_level = 0.99),
        envir = new.env())
      "outputs/model_risk_report.html"},
    format = "file"))