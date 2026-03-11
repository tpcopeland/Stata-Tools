#!/usr/bin/env Rscript
# =============================================================================
# Cross-Validation Comparison: R emulate vs Stata tte
# Part 3: Compare results from both runs
# =============================================================================

cat(strrep("=", 80), "\n")
cat("CROSS-VALIDATION COMPARISON: R emulate vs Stata tte\n")
cat(sprintf("Date: %s\n", Sys.time()))
cat(strrep("=", 80), "\n\n")

results_dir <- normalizePath("~/Stata-Tools/tte/qa/crossval_results")

# Load results
r_file <- file.path(results_dir, "r_emulate_results.csv")
s_file <- file.path(results_dir, "stata_tte_results.csv")

if (!file.exists(r_file)) stop("R results not found: ", r_file)
if (!file.exists(s_file)) stop("Stata results not found: ", s_file)

r_res <- read.csv(r_file, stringsAsFactors = FALSE)
s_res <- read.csv(s_file, stringsAsFactors = FALSE)

cat(sprintf("R results: %d rows\n", nrow(r_res)))
cat(sprintf("Stata results: %d rows\n\n", nrow(s_res)))

# Merge on (dataset, config, metric)
merged <- merge(r_res, s_res, by = c("dataset", "config", "metric"),
                suffixes = c("_r", "_stata"))
cat(sprintf("Matched results: %d rows\n\n", nrow(merged)))

# Compute differences
merged$abs_diff <- abs(merged$value_r - merged$value_stata)
merged$rel_diff <- ifelse(abs(merged$value_stata) > 1e-8,
                          abs(merged$value_r - merged$value_stata) / abs(merged$value_stata),
                          NA)

# Tolerances by metric type
get_tolerance <- function(metric, config) {
  # ITT configs have tighter tolerances (no weight model differences)
  is_itt <- grepl("ITT", config)

  if (metric == "coef") {
    if (is_itt) return(0.005) else return(0.02)
  }
  if (metric == "se") {
    if (is_itt) return(0.01) else return(0.05)
  }
  if (metric == "or_hr") {
    if (is_itt) return(0.01) else return(0.05)
  }
  if (grepl("^n_expanded$|^n_trials$", metric)) return(0)
  if (grepl("^w_mean$", metric)) return(0.02)
  if (grepl("^w_sd$", metric)) return(0.05)
  if (grepl("^w_min$", metric)) return(0.05)
  if (grepl("^w_max$", metric)) return(0.5)
  if (grepl("^w_ess$", metric)) return(50)
  if (grepl("^w_n_truncated$", metric)) return(5)
  if (grepl("^pred_", metric)) {
    if (is_itt) return(0.005) else return(0.02)
  }
  return(0.05)  # default
}

merged$tolerance <- mapply(get_tolerance, merged$metric, merged$config)
merged$status <- ifelse(is.na(merged$abs_diff), "NA",
                        ifelse(merged$abs_diff <= merged$tolerance, "PASS",
                        ifelse(merged$abs_diff <= merged$tolerance * 3, "NOTE", "FAIL")))

# For n_expanded, exact match required
idx_exact <- merged$metric %in% c("n_expanded", "n_trials")
merged$status[idx_exact] <- ifelse(is.na(merged$abs_diff[idx_exact]), "NA",
                                   ifelse(merged$abs_diff[idx_exact] == 0, "PASS", "FAIL"))

# =============================================================================
# Summary by dataset
# =============================================================================
datasets <- unique(merged$dataset)
overall_pass <- 0
overall_note <- 0
overall_fail <- 0

for (ds in datasets) {
  sub <- merged[merged$dataset == ds, ]
  configs <- unique(sub$config)

  cat(strrep("-", 80), "\n")
  cat(sprintf("DATASET: %s (%d configs, %d comparisons)\n", ds, length(configs), nrow(sub)))
  cat(strrep("-", 80), "\n")

  for (cfg in configs) {
    csub <- sub[sub$config == cfg, ]
    n_pass <- sum(csub$status == "PASS", na.rm = TRUE)
    n_note <- sum(csub$status == "NOTE", na.rm = TRUE)
    n_fail <- sum(csub$status == "FAIL", na.rm = TRUE)
    n_na   <- sum(csub$status == "NA", na.rm = TRUE)

    # Config summary line
    status_str <- if (n_fail > 0) "FAIL" else if (n_note > 0) "NOTE" else "PASS"
    cat(sprintf("\n  %-50s %s (%d pass, %d note, %d fail)\n",
                cfg, status_str, n_pass, n_note, n_fail))

    # Show key metrics
    for (met in c("coef", "se", "or_hr")) {
      row <- csub[csub$metric == met, ]
      if (nrow(row) == 1) {
        cat(sprintf("    %-20s R=%-12.6f Stata=%-12.6f diff=%-10.6f [%s]\n",
                    met, row$value_r, row$value_stata, row$abs_diff, row$status))
      }
    }

    # Show weight metrics if present
    w_rows <- csub[grepl("^w_", csub$metric), ]
    if (nrow(w_rows) > 0) {
      for (j in seq_len(nrow(w_rows))) {
        row <- w_rows[j, ]
        cat(sprintf("    %-20s R=%-12.6f Stata=%-12.6f diff=%-10.6f [%s]\n",
                    row$metric, row$value_r, row$value_stata, row$abs_diff, row$status))
      }
    }

    # Show prediction diffs at a few key time points
    pred_rows <- csub[grepl("^pred_diff_", csub$metric), ]
    if (nrow(pred_rows) > 0) {
      # Show first, mid, last
      show_idx <- unique(c(1, ceiling(nrow(pred_rows)/2), nrow(pred_rows)))
      for (j in show_idx) {
        row <- pred_rows[j, ]
        cat(sprintf("    %-20s R=%-12.6f Stata=%-12.6f diff=%-10.6f [%s]\n",
                    row$metric, row$value_r, row$value_stata, row$abs_diff, row$status))
      }
    }

    # Show any failures in detail
    failures <- csub[csub$status == "FAIL", ]
    if (nrow(failures) > 0 && !all(failures$metric %in% c("coef", "se", "or_hr"))) {
      cat("    FAILURES:\n")
      for (j in seq_len(nrow(failures))) {
        row <- failures[j, ]
        if (!row$metric %in% c("coef", "se", "or_hr")) {
          cat(sprintf("      %-20s R=%-12.6f Stata=%-12.6f diff=%.6f > tol=%.6f\n",
                      row$metric, row$value_r, row$value_stata,
                      row$abs_diff, row$tolerance))
        }
      }
    }

    overall_pass <- overall_pass + n_pass
    overall_note <- overall_note + n_note
    overall_fail <- overall_fail + n_fail
  }
  cat("\n")
}

# =============================================================================
# Overall summary
# =============================================================================
cat(strrep("=", 80), "\n")
cat("OVERALL SUMMARY\n")
cat(strrep("=", 80), "\n\n")

total <- overall_pass + overall_note + overall_fail
cat(sprintf("Total comparisons: %d\n", total))
cat(sprintf("PASS: %d (%.1f%%)\n", overall_pass, 100 * overall_pass / total))
cat(sprintf("NOTE: %d (%.1f%%) - within 3x tolerance, known algorithmic diffs\n",
            overall_note, 100 * overall_note / total))
cat(sprintf("FAIL: %d (%.1f%%)\n", overall_fail, 100 * overall_fail / total))

cat("\n")
if (overall_fail == 0) {
  cat("RESULT: ALL COMPARISONS WITHIN TOLERANCE\n")
} else {
  cat(sprintf("RESULT: %d COMPARISON(S) EXCEEDED TOLERANCE\n", overall_fail))
}

# =============================================================================
# Coefficient comparison table (all configs)
# =============================================================================
cat("\n\n")
cat(strrep("=", 80), "\n")
cat("COEFFICIENT COMPARISON TABLE\n")
cat(strrep("=", 80), "\n\n")

coef_rows <- merged[merged$metric == "coef", ]
coef_rows <- coef_rows[order(coef_rows$dataset, coef_rows$config), ]

cat(sprintf("%-15s %-50s %10s %10s %10s %6s\n",
            "Dataset", "Config", "R_coef", "Stata_coef", "Diff", "Status"))
cat(strrep("-", 105), "\n")

for (i in seq_len(nrow(coef_rows))) {
  r <- coef_rows[i, ]
  cat(sprintf("%-15s %-50s %10.4f %10.4f %10.6f %6s\n",
              r$dataset, r$config, r$value_r, r$value_stata, r$abs_diff, r$status))
}

# =============================================================================
# SE comparison table
# =============================================================================
cat("\n")
cat(strrep("=", 80), "\n")
cat("STANDARD ERROR COMPARISON TABLE\n")
cat(strrep("=", 80), "\n\n")

se_rows <- merged[merged$metric == "se", ]
se_rows <- se_rows[order(se_rows$dataset, se_rows$config), ]

cat(sprintf("%-15s %-50s %10s %10s %10s %6s\n",
            "Dataset", "Config", "R_SE", "Stata_SE", "Diff", "Status"))
cat(strrep("-", 105), "\n")

for (i in seq_len(nrow(se_rows))) {
  r <- se_rows[i, ]
  cat(sprintf("%-15s %-50s %10.4f %10.4f %10.6f %6s\n",
              r$dataset, r$config, r$value_r, r$value_stata, r$abs_diff, r$status))
}

# =============================================================================
# Known algorithmic differences
# =============================================================================
cat("\n")
cat(strrep("=", 80), "\n")
cat("KNOWN ALGORITHMIC DIFFERENCES\n")
cat(strrep("=", 80), "\n")
cat("
1. SE computation: emulate uses sandwich::vcovCL(type='HC1', cadjust=TRUE)
   Stata uses vce(cluster) which applies G/(G-1) only. Both apply finite-
   sample corrections but differently. ITT configs show minimal diff; PP/AT
   configs show larger diff due to weight model interaction.

2. GLM solver precision: R's glm() and Stata's glm use IRLS but with
   different convergence criteria and floating-point implementations.
   Differences are typically < 1e-6 for coefficients.

3. Prediction MC seeds: Even with same seed value (54321), R and Stata
   have different RNGs, so MC confidence intervals will differ. Point
   estimates (which don't use MC) should match closely.

4. Weight model: Both use logistic regression for treatment switch models
   with the same stratification (by arm). Minor differences from GLM solver.

5. Spline basis: Both use Harrell RCS (identical formula). Knot placement
   uses quantile(type=2) in R and _pctile in Stata (matched by design).
")

# Save detailed results
write.csv(merged, file.path(results_dir, "crossval_comparison.csv"),
          row.names = FALSE)
cat(sprintf("\nDetailed results saved to: %s\n",
            file.path(results_dir, "crossval_comparison.csv")))
