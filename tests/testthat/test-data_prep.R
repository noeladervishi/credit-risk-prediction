make_valid_df <- function() {
  data.frame(
    loan_id = 1:5,
    issue_d = as.Date(c("2012-01-01","2012-02-01","2013-01-01","2013-05-01","2014-01-01")),
    issue_year = c(2012, 2012, 2013, 2013, 2014),
    default_flag = c(0L, 1L, 0L, 0L, 1L),
    ead = c(1000, 2000, 1500, 3000, 500),
    lgd = c(0, 0.6, 0, 0, 0.45))}

test_that("validate_loan_schema passes on a well-formed data frame", {
  expect_true(validate_loan_schema(make_valid_df()))})

test_that("validate_loan_schema catches missing required columns", {
  df <- make_valid_df()
  df$ead <- NULL
  expect_error(validate_loan_schema(df), "Missing required columns")})

test_that("validate_loan_schema catches non-binary default_flag", {
  df <- make_valid_df()
  df$default_flag[1] <- 2L
  expect_error(validate_loan_schema(df), "binary")})

test_that("validate_loan_schema catches non-positive EAD", {
  df <- make_valid_df()
  df$ead[1] <- 0
  expect_error(validate_loan_schema(df), "positive")})

test_that("validate_loan_schema catches LGD outside [0,1]", {
  df <- make_valid_df()
  df$lgd[1] <- 1.5
  expect_error(validate_loan_schema(df), "0, 1")})

test_that("split_by_vintage rejects overlapping year ranges", {
  df <- make_valid_df()
  expect_error(
    split_by_vintage(df, train_years = 2012:2013, val_years = 2013, test_years = 2014),
    "overlap")})

test_that("split_by_vintage correctly partitions by issue_year", {
  df <- make_valid_df()
  result <- split_by_vintage(df, train_years = 2012:2013, val_years = 2014, test_years = NULL)

  expect_true(all(result$train$issue_year %in% c(2012, 2013)))
  expect_true(all(result$val$issue_year == 2014))
  expect_equal(nrow(result$train) + nrow(result$val), nrow(df))})