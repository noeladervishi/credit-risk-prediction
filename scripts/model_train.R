library(dplyr)
library(scorecard)
library(xgboost)

MODEL_FEATURES <- c( "loan_amnt", "term", "int_rate", "installment", "grade", "emp_length_num", "home_ownership", "annual_inc", 
"verification_status", "purpose", "dti", "delinq_2yrs", "inq_last_6mths", "open_acc", "pub_rec","revol_bal", "revol_util", "total_acc")

train_scorecard_model <- function(train_df) {
  model_df <- train_df %>%
    select(default_flag, all_of(MODEL_FEATURES)) %>%
    mutate(across(where(is.character), as.factor))
  bins <- scorecard::woebin(model_df, y = "default_flag", positive = "1")
  train_woe <- scorecard::woebin_ply(model_df, bins)
  fit <- glm(
    default_flag ~ .,
    data = train_woe,
    family = binomial(link = "logit"))
  list(fit = fit, bins = bins, features = MODEL_FEATURES)}

predict_scorecard <- function(scorecard_model, newdata) {
  woe_data <- scorecard::woebin_ply(
    newdata %>% select(all_of(scorecard_model$features)) %>%
      mutate(across(where(is.character), as.factor)),
    scorecard_model$bins)
  predict(scorecard_model$fit, newdata = woe_data, type = "response")}

train_xgboost_model <- function(train_df, val_df, params = list()) {
  default_params <- list(
    objective = "binary:logistic",
    eval_metric = "auc",
    eta = 0.05,
    max_depth = 4,
    subsample = 0.8,
    colsample_bytree = 0.8,
    min_child_weight = 20)
  params <- modifyList(default_params, params)
  encode <- function(df) {
    model.matrix(
      ~ . - 1,
      data = df %>% select(all_of(MODEL_FEATURES)) %>%
        mutate(across(where(is.character), as.factor)))}
  x_train <- encode(train_df)
  x_val   <- encode(val_df)
  common_cols <- union(colnames(x_train), colnames(x_val))
  align <- function(m) {
    missing <- setdiff(common_cols, colnames(m))
    for (col in missing) m <- cbind(m, matrix(0, nrow(m), 1, dimnames = list(NULL, col)))
    m[, common_cols, drop = FALSE]}
  x_train <- align(x_train)
  x_val   <- align(x_val)
  dtrain <- xgboost::xgb.DMatrix(x_train, label = train_df$default_flag)
  dval   <- xgboost::xgb.DMatrix(x_val,   label = val_df$default_flag)
  booster <- xgboost::xgb.train(
    params = params,
    data = dtrain,
    nrounds = 2000,
    watchlist = list(train = dtrain, val = dval),
    early_stopping_rounds = 50,
    verbose = 0)

  list(booster = booster, feature_names = common_cols, encode = encode, align = align)}

predict_xgboost <- function(xgb_model, newdata) {
  x <- xgb_model$align(xgb_model$encode(newdata))
  predict(xgb_model$booster, xgboost::xgb.DMatrix(x))}