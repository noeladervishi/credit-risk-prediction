library(dplyr)

simulate_sample_loans <- function(n = 20000, seed = 1) {
  set.seed(seed)
  grades <- sample(LETTERS[1:7], n, replace = TRUE,
                    prob = c(0.15, 0.25, 0.25, 0.15, 0.10, 0.06, 0.04))
  grade_pd <- c(A = 0.03, B = 0.06, C = 0.10, D = 0.15, E = 0.22, F = 0.30, G = 0.38)
  base_pd <- grade_pd[grades]
  issue_year <- sample(2007:2015, n, replace = TRUE,
                        prob = c(0.02, 0.03, 0.05, 0.08, 0.10, 0.12, 0.15, 0.20, 0.25))
  macro_bump <- case_when(
    issue_year %in% c(2008, 2009) ~ 0.03,
    issue_year == 2015 ~ 0.015,
    TRUE ~ 0)
  dti <- pmin(pmax(rnorm(n, 18, 8), 0), 45)
  annual_inc <- pmax(rlnorm(n, meanlog = 10.9, sdlog = 0.5), 15000)
  int_rate <- pmax(rnorm(n, 6 + as.numeric(factor(grades)) * 2.5, 2), 5)
  true_pd <- pmin(pmax(base_pd + macro_bump +
                          (dti - 18) * 0.001 -
                          (annual_inc - 60000) * 1e-8, 0.01), 0.6)
  default_flag <- rbinom(n, 1, true_pd)
  funded_amnt <- round(runif(n, 1000, 35000), -2)
  term <- sample(c("36 months", "60 months"), n, replace = TRUE, prob = c(0.7, 0.3))
  recovery_rate <- pmax(pmin(rnorm(n, 0.35, 0.1), 0.9), 0)
  total_pymnt <- ifelse(default_flag == 1,
                         funded_amnt * runif(n, 0.05, 0.4),
                         funded_amnt * runif(n, 1.0, 1.25))
  recoveries <- ifelse(default_flag == 1, funded_amnt * recovery_rate * 0.3, 0)
  loss_amount <- pmax(funded_amnt - total_pymnt - recoveries, 0)
  lgd <- ifelse(default_flag == 1, pmin(pmax(loss_amount / funded_amnt, 0), 1), 0)

  tibble(
    loan_id = seq_len(n),
    issue_d = as.Date(paste0(issue_year, "-", sample(1:12, n, replace = TRUE), "-01")),
    issue_year = issue_year,
    issue_qtr = paste0(issue_year, "-Q", sample(1:4, n, replace = TRUE)),
    default_flag = as.integer(default_flag),
    ead = funded_amnt,
    lgd = lgd,
    loan_amnt = funded_amnt,
    term = term,
    int_rate = int_rate,
    installment = funded_amnt / ifelse(term == "36 months", 36, 60),
    grade = grades,
    sub_grade = paste0(grades, sample(1:5, n, replace = TRUE)),
    emp_length_num = sample(0:10, n, replace = TRUE),
    home_ownership = sample(c("RENT", "MORTGAGE", "OWN"), n, replace = TRUE, prob = c(0.4, 0.45, 0.15)),
    annual_inc = annual_inc,
    verification_status = sample(c("Verified", "Source Verified", "Not Verified"), n, replace = TRUE),
    purpose = sample(c("debt_consolidation", "credit_card", "home_improvement", "other"), n, replace = TRUE),
    dti = dti,
    delinq_2yrs = rpois(n, 0.3),
    inq_last_6mths = rpois(n, 0.8),
    open_acc = pmax(round(rnorm(n, 10, 4)), 1),
    pub_rec = rpois(n, 0.1),
    revol_bal = pmax(rlnorm(n, 8.5, 1), 0),
    revol_util = pmin(pmax(rnorm(n, 45, 20), 0), 100),
    total_acc = pmax(round(rnorm(n, 25, 10)), 1),
    application_type = "Individual")}