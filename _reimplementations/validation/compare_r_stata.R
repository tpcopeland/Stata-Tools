#!/usr/bin/env Rscript
# R vs Stata Comparison Script
# Compare R tvtools output with Stata reference outputs

suppressPackageStartupMessages({
  library(data.table)
  library(devtools)
})

# Load tvtools from local package
load_all("/home/tpcopeland/Stata-Tools/_reimplementations/R/tvtools")

DATA_PATH <- "/home/tpcopeland/Stata-Tools/_reimplementations/data/R"
STATA_OUT <- "/home/tpcopeland/Stata-Tools/_reimplementations/validation/stata_outputs"

cat("======================================================================\n")
cat("CROSS-LANGUAGE VALIDATION: R vs Stata\n")
cat("======================================================================\n")
cat(paste("Date:", Sys.time(), "\n\n"))

# Load test data
cohort <- readRDS(file.path(DATA_PATH, "cohort.rds"))
hrt <- readRDS(file.path(DATA_PATH, "hrt.rds"))
dmt <- readRDS(file.path(DATA_PATH, "dmt.rds"))

setDT(cohort)
setDT(hrt)
setDT(dmt)

results <- list()

# =============================================================================
# Test 1: Basic tvexpose
# =============================================================================
cat("Test 1: Basic tvexpose\n")

r_result <- tvexpose(
  master_data = cohort,
  exposure_file = hrt,
  id = "id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "hrt_type",
  entry = "study_entry",
  exit = "study_exit",
  reference = 0,
  verbose = FALSE
)

r_df <- as.data.table(r_result$data)
stata_df <- fread(file.path(STATA_OUT, "test1_basic_tvexpose.csv"))

r_count <- nrow(r_df)
stata_count <- nrow(stata_df)
pct_diff <- abs(r_count - stata_count) / stata_count * 100

status <- ifelse(pct_diff < 5, "PASS", "FAIL")
cat(sprintf("  Row count: R=%d, Stata=%d (%.1f%% diff) [%s]\n", r_count, stata_count, pct_diff, status))
results$basic <- pct_diff < 5

# =============================================================================
# Test 2: Person-time conservation
# =============================================================================
cat("\nTest 2: Person-time conservation\n")

# Calculate expected person-time from cohort
cohort_copy <- copy(cohort)
cohort_copy[, expected_days := as.numeric(study_exit - study_entry) + 1]
expected_total <- sum(cohort_copy$expected_days)

# Calculate actual from R output (use correct column names)
start_col <- names(r_df)[grep("^start$|rx_start", names(r_df))[1]]
stop_col <- names(r_df)[grep("^stop$|rx_stop", names(r_df))[1]]

r_df[, actual_days := as.numeric(get(stop_col) - get(start_col)) + 1]
actual_total <- sum(r_df$actual_days)

pct_diff <- abs(actual_total - expected_total) / expected_total * 100
status <- ifelse(pct_diff < 1, "PASS", "FAIL")

cat(sprintf("  Expected: %s days\n", format(expected_total, big.mark=",")))
cat(sprintf("  Actual:   %s days\n", format(actual_total, big.mark=",")))
cat(sprintf("  Difference: %.2f%% [%s]\n", pct_diff, status))
results$persontime <- pct_diff < 1

# =============================================================================
# Test 3: Evertreated option
# =============================================================================
cat("\nTest 3: Evertreated option\n")

r_ever <- tvexpose(
  master_data = cohort,
  exposure_file = hrt,
  id = "id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "hrt_type",
  entry = "study_entry",
  exit = "study_exit",
  reference = 0,
  evertreated = TRUE,
  verbose = FALSE
)

# Find exposure column
exp_col <- names(r_ever$data)[grep("tv_|ever_", names(r_ever$data))[1]]
unique_vals <- unique(r_ever$data[[exp_col]])
valid_binary <- all(unique_vals %in% c(0, 1, NA))

status <- ifelse(valid_binary, "PASS", "FAIL")
cat(sprintf("  Binary values only: %s [%s]\n", valid_binary, status))

# Check monotonicity
dt <- as.data.table(r_ever$data)
monotonic <- dt[, {
  vals <- get(exp_col)
  all(diff(vals) >= 0, na.rm = TRUE)
}, by = id][, all(V1)]

status <- ifelse(monotonic, "PASS", "FAIL")
cat(sprintf("  Monotonic (never reverts): %s [%s]\n", monotonic, status))
results$evertreated <- valid_binary && monotonic

# =============================================================================
# Test 4: Currentformer option
# =============================================================================
cat("\nTest 4: Currentformer option\n")

r_cf <- tvexpose(
  master_data = cohort,
  exposure_file = hrt,
  id = "id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "hrt_type",
  entry = "study_entry",
  exit = "study_exit",
  reference = 0,
  currentformer = TRUE,
  verbose = FALSE
)

exp_col <- names(r_cf$data)[grep("tv_|cf_", names(r_cf$data))[1]]
unique_vals <- unique(r_cf$data[[exp_col]])
valid_trichotomous <- all(unique_vals %in% c(0, 1, 2, NA))

status <- ifelse(valid_trichotomous, "PASS", "FAIL")
cat(sprintf("  Valid categories (0,1,2): %s [%s]\n", valid_trichotomous, status))
results$currentformer <- valid_trichotomous

# =============================================================================
# Test 5: Lag option
# =============================================================================
cat("\nTest 5: Lag option\n")

r_no_lag <- tvexpose(
  master_data = cohort,
  exposure_file = hrt,
  id = "id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "hrt_type",
  entry = "study_entry",
  exit = "study_exit",
  reference = 0,
  verbose = FALSE
)

r_with_lag <- tvexpose(
  master_data = cohort,
  exposure_file = hrt,
  id = "id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "hrt_type",
  entry = "study_entry",
  exit = "study_exit",
  reference = 0,
  lag = 30,
  verbose = FALSE
)

# Calculate exposed time
calc_exposed_time <- function(result) {
  dt <- as.data.table(result$data)
  exp_col <- names(dt)[grep("tv_|_exp", names(dt))[1]]
  start_col <- names(dt)[grep("^start$|rx_start", names(dt))[1]]
  stop_col <- names(dt)[grep("^stop$|rx_stop", names(dt))[1]]
  
  dt[, duration := as.numeric(get(stop_col) - get(start_col)) + 1]
  # Exposed = not 0 and not NA
  dt[get(exp_col) != 0 & !is.na(get(exp_col)), sum(duration)]
}

exp_no_lag <- calc_exposed_time(r_no_lag)
exp_with_lag <- calc_exposed_time(r_with_lag)

lag_reduced <- exp_with_lag < exp_no_lag
status <- ifelse(lag_reduced, "PASS", "FAIL")
cat(sprintf("  Lag reduces exposed time: %s < %s [%s]\n", 
            format(exp_with_lag, big.mark=","), 
            format(exp_no_lag, big.mark=","), status))
results$lag <- lag_reduced

# =============================================================================
# Test 6: Washout option
# =============================================================================
cat("\nTest 6: Washout option\n")

r_with_washout <- tvexpose(
  master_data = cohort,
  exposure_file = hrt,
  id = "id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "hrt_type",
  entry = "study_entry",
  exit = "study_exit",
  reference = 0,
  washout = 30,
  verbose = FALSE
)

exp_no_washout <- exp_no_lag  # Already calculated
exp_with_washout <- calc_exposed_time(r_with_washout)

washout_extended <- exp_with_washout >= exp_no_washout
status <- ifelse(washout_extended, "PASS", "FAIL")
cat(sprintf("  Washout extends exposed time: %s >= %s [%s]\n", 
            format(exp_with_washout, big.mark=","), 
            format(exp_no_washout, big.mark=","), status))
results$washout <- washout_extended

# =============================================================================
# Summary
# =============================================================================
cat("\n======================================================================\n")
cat("SUMMARY\n")
cat("======================================================================\n")

passed <- sum(unlist(results))
total <- length(results)

for (name in names(results)) {
  status <- ifelse(results[[name]], "PASS", "FAIL")
  cat(sprintf("  %s: %s\n", name, status))
}

cat("----------------------------------------------------------------------\n")
cat(sprintf("TOTAL: %d/%d tests passed\n", passed, total))
cat("======================================================================\n")

# Exit with appropriate code
if (passed == total) {
  quit(status = 0)
} else {
  quit(status = 1)
}
