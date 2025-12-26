#!/usr/bin/env Rscript
# R vs Stata Row-by-Row Comparison

suppressPackageStartupMessages({
  library(data.table)
  library(devtools)
})

load_all("/home/tpcopeland/Stata-Tools/_reimplementations/R/tvtools")

DATA_PATH <- "/home/tpcopeland/Stata-Tools/_reimplementations/data/R"
STATA_OUT <- "/home/tpcopeland/Stata-Tools/_reimplementations/validation/stata_outputs"

cat(paste(rep("=", 70), collapse=""), "\n")
cat("R vs STATA ROW-BY-ROW COMPARISON\n")
cat(paste(rep("=", 70), collapse=""), "\n")
cat(paste("Date:", Sys.time(), "\n\n"))

# Load test data
cohort <- readRDS(file.path(DATA_PATH, "cohort.rds"))
hrt <- readRDS(file.path(DATA_PATH, "hrt.rds"))
setDT(cohort)
setDT(hrt)

compare_dfs <- function(r_df, stata_df, test_name) {
  r_dt <- as.data.table(r_df)
  stata_dt <- as.data.table(stata_df)
  
  # Find date columns
  r_start <- names(r_dt)[grep("^start$|rx_start", names(r_dt))[1]]
  r_stop <- names(r_dt)[grep("^stop$|rx_stop", names(r_dt))[1]]
  stata_start <- names(stata_dt)[grep("start", names(stata_dt), ignore.case=TRUE)[1]]
  stata_stop <- names(stata_dt)[grep("stop", names(stata_dt), ignore.case=TRUE)[1]]
  
  # Convert R dates to numeric (days from 1970)
  r_dt[, start_num := as.numeric(get(r_start))]
  r_dt[, stop_num := as.numeric(get(r_stop))]
  
  # Convert Stata string dates to numeric
  stata_dt[, start_num := as.numeric(as.Date(get(stata_start)))]
  stata_dt[, stop_num := as.numeric(as.Date(get(stata_stop)))]
  
  # Find exposure columns
  r_exp_col <- names(r_dt)[grep("tv_|ever_|cf_|lag_|washout_", names(r_dt))[1]]
  stata_exp_col <- names(stata_dt)[grep("tv_|ever_|cf_|lag_|washout_", names(stata_dt))[1]]
  
  # Normalize exposure values (map numeric to text for comparison)
  exp_map <- c("0"="Unexposed", "1"="Estrogen", "2"="Combined", "3"="Progestin")
  r_dt[, exp_norm := as.character(get(r_exp_col))]
  r_dt[exp_norm %in% names(exp_map), exp_norm := exp_map[exp_norm]]
  
  stata_dt[, exp_norm := as.character(get(stata_exp_col))]
  
  # Create comparison keys
  r_dt[, key := paste(id, start_num, stop_num, exp_norm, sep="_")]
  stata_dt[, key := paste(id, start_num, stop_num, exp_norm, sep="_")]
  
  r_keys <- unique(r_dt$key)
  stata_keys <- unique(stata_dt$key)
  
  matching <- intersect(r_keys, stata_keys)
  only_r <- setdiff(r_keys, stata_keys)
  only_stata <- setdiff(stata_keys, r_keys)
  
  cat(sprintf("\n%s:\n", test_name))
  cat(sprintf("  R rows: %d, Stata rows: %d\n", nrow(r_dt), nrow(stata_dt)))
  cat(sprintf("  Matching: %d, Only R: %d, Only Stata: %d\n", 
              length(matching), length(only_r), length(only_stata)))
  
  return(list(
    match_pct = length(matching) / max(nrow(r_dt), nrow(stata_dt)) * 100,
    exact = length(only_r) == 0 && length(only_stata) == 0
  ))
}

# Test 1: Basic tvexpose
r_result <- tvexpose(
  master_data = cohort,
  exposure_file = hrt,
  id = "id", start = "rx_start", stop = "rx_stop",
  exposure = "hrt_type", entry = "study_entry", exit = "study_exit",
  reference = 0, verbose = FALSE
)
stata_df <- fread(file.path(STATA_OUT, "test1_basic_tvexpose.csv"))
res1 <- compare_dfs(r_result$data, stata_df, "Basic tvexpose")

# Test 2: Evertreated
r_result <- tvexpose(
  master_data = cohort, exposure_file = hrt,
  id = "id", start = "rx_start", stop = "rx_stop",
  exposure = "hrt_type", entry = "study_entry", exit = "study_exit",
  reference = 0, evertreated = TRUE, verbose = FALSE
)
stata_df <- fread(file.path(STATA_OUT, "test2_evertreated.csv"))
res2 <- compare_dfs(r_result$data, stata_df, "Evertreated")

# Test 3: Currentformer (semantic comparison)
r_result <- tvexpose(
  master_data = cohort, exposure_file = hrt,
  id = "id", start = "rx_start", stop = "rx_stop",
  exposure = "hrt_type", entry = "study_entry", exit = "study_exit",
  reference = 0, currentformer = TRUE, verbose = FALSE
)
stata_df <- fread(file.path(STATA_OUT, "test3_currentformer.csv"))

# Special handling for currentformer - map R 0/1/2 to Never/Current/Former
r_dt <- as.data.table(r_result$data)
stata_dt <- as.data.table(stata_df)

r_start <- names(r_dt)[grep("^start$|rx_start", names(r_dt))[1]]
r_stop <- names(r_dt)[grep("^stop$|rx_stop", names(r_dt))[1]]

r_dt[, start_num := as.numeric(get(r_start))]
r_dt[, stop_num := as.numeric(get(r_stop))]
stata_dt[, start_num := as.numeric(as.Date(rx_start))]
stata_dt[, stop_num := as.numeric(as.Date(rx_stop))]

r_exp_col <- names(r_dt)[grep("tv_|cf_", names(r_dt))[1]]
cf_map <- c("0"="Never", "1"="Current", "2"="Former")
r_dt[, exp_norm := cf_map[as.character(get(r_exp_col))]]
stata_dt[, exp_norm := cf_hrt]

r_dt[, key := paste(id, start_num, stop_num, exp_norm, sep="_")]
stata_dt[, key := paste(id, start_num, stop_num, exp_norm, sep="_")]

r_keys <- unique(r_dt$key)
stata_keys <- unique(stata_dt$key)
matching <- intersect(r_keys, stata_keys)
only_r <- setdiff(r_keys, stata_keys)
only_stata <- setdiff(stata_keys, r_keys)

cat("\nCurrentformer (semantic match):\n")
cat(sprintf("  R rows: %d, Stata rows: %d\n", nrow(r_dt), nrow(stata_dt)))
cat(sprintf("  Matching: %d, Only R: %d, Only Stata: %d\n", 
            length(matching), length(only_r), length(only_stata)))
res3 <- list(match_pct = length(matching) / max(nrow(r_dt), nrow(stata_dt)) * 100,
             exact = length(only_r) == 0 && length(only_stata) == 0)

# Test 4: Lag
r_result <- tvexpose(
  master_data = cohort, exposure_file = hrt,
  id = "id", start = "rx_start", stop = "rx_stop",
  exposure = "hrt_type", entry = "study_entry", exit = "study_exit",
  reference = 0, lag = 30, verbose = FALSE
)
stata_df <- fread(file.path(STATA_OUT, "test4_lag.csv"))
res4 <- compare_dfs(r_result$data, stata_df, "Lag (30 days)")

# Test 5: Washout
r_result <- tvexpose(
  master_data = cohort, exposure_file = hrt,
  id = "id", start = "rx_start", stop = "rx_stop",
  exposure = "hrt_type", entry = "study_entry", exit = "study_exit",
  reference = 0, washout = 30, verbose = FALSE
)
stata_df <- fread(file.path(STATA_OUT, "test5_washout.csv"))
res5 <- compare_dfs(r_result$data, stata_df, "Washout (30 days)")

# Summary
cat("\n", paste(rep("=", 70), collapse=""), "\n")
cat("SUMMARY: R vs Stata\n")
cat(paste(rep("=", 70), collapse=""), "\n")

results <- list(
  "Basic tvexpose" = res1$exact,
  "Evertreated" = res2$exact,
  "Currentformer" = res3$exact,
  "Lag" = res4$exact,
  "Washout" = res5$exact
)

for (name in names(results)) {
  status <- ifelse(results[[name]], "EXACT MATCH", "MISMATCH")
  cat(sprintf("  %s: %s\n", name, status))
}

passed <- sum(unlist(results))
total <- length(results)
cat(paste(rep("-", 70), collapse=""), "\n")
cat(sprintf("Total: %d/%d tests with EXACT row match\n", passed, total))
cat(paste(rep("=", 70), collapse=""), "\n")
