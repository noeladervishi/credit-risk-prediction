library(dplyr)
library(lubridate)
library(readr)

load_raw_loans <- function(raw_path, n_max = Inf) {
  if (!file.exists(raw_path)) {
    stop(
      "Raw data file not found at: ", raw_path,
      "\nDownload the accepted-loans file from ",
      "https://www.kaggle.com/datasets/wordsforthewise/lending-club ",
      "and place it at this path.")}
  readr::read_csv(raw_path, n_max = n_max, guess_max = 100000, show_col_types = FALSE)}

clean_loans <- function(raw_loans) {
  matured_statuses <- c("Fully Paid", "Charged Off")
  cleaned <- raw_loans %>%
    filter(loan_status %in% matured_statuses) %>%
    mutate(
      issue_d      = lubridate::myd(paste0(issue_d, "-01"), quiet = TRUE),
      issue_year   = lubridate::year(issue_d),
      issue_qtr    = paste0(issue_year, "-Q", lubridate::quarter(issue_d)),
      default_flag = if_else(loan_status == "Charged Off", 1L, 0L),
      ead = as.numeric(funded_amnt),
      recoveries   = coalesce(as.numeric(recoveries), 0),
      total_pymnt  = coalesce(as.numeric(total_pymnt), 0),
      loss_amount  = pmax(funded_amnt - total_pymnt - recoveries, 0),
      lgd = case_when(
        default_flag == 1L & funded_amnt > 0 ~ pmin(pmax(loss_amount / funded_amnt, 0), 1),
        default_flag == 0L                   ~ 0,   
        TRUE                                  ~ NA_real_),
      int_rate    = as.numeric(gsub("%", "", int_rate)),
      revol_util  = as.numeric(gsub("%", "", revol_util)),
      emp_length_num = case_when(
        emp_length == "< 1 year"  ~ 0,
        emp_length == "10+ years" ~ 10,
        grepl("^[0-9]+", emp_length) ~ as.numeric(gsub("[^0-9]", "", emp_length)),
        TRUE ~ NA_real_),
      dti = as.numeric(dti),
      annual_inc = as.numeric(annual_inc)
    ) %>%
    filter(!is.na(issue_d), !is.na(ead), ead > 0) %>%
    select(
      loan_id = id, issue_d, issue_year, issue_qtr, default_flag, ead, lgd, loan_amnt, term, int_rate, installment, grade, sub_grade,
      emp_length_num, home_ownership, annual_inc, verification_status, purpose, dti, delinq_2yrs, inq_last_6mths, open_acc, pub_rec, 
      revol_bal, revol_util, total_acc, application_type)
  cleaned}

split_by_vintage <- function(cleaned_loans,
                              train_years = 2007:2013,
                              val_years   = 2014,
                              test_years  = 2015) {
  overlap <- intersect(train_years, c(val_years, test_years))
  if (length(overlap) > 0) {
    stop("train_years must not overlap with val_years/test_years: ", paste(overlap, collapse = ", "))}
  list(
    train = cleaned_loans %>% filter(issue_year %in% train_years),
    val   = cleaned_loans %>% filter(issue_year %in% val_years),
    test  = cleaned_loans %>% filter(issue_year %in% test_years))}

validate_loan_schema <- function(df) {
  required_cols <- c("loan_id", "issue_d", "issue_year", "default_flag", "ead", "lgd")
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "))}
  if (!all(df$default_flag %in% c(0L, 1L))) {
    stop("default_flag must be binary (0/1)")}
  if (any(df$ead <= 0, na.rm = TRUE)) {
    stop("ead (exposure at default) must be strictly positive")}
  if (any(df$lgd < 0 | df$lgd > 1, na.rm = TRUE)) {
    stop("lgd must be within [0, 1]")}
  invisible(TRUE)}