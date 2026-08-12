library(testthat)

for (f in list.files(here::here("R"), pattern = "\\.R$", full.names = TRUE)) {
  source(f)}

test_dir(here::here("tests", "testthat"))