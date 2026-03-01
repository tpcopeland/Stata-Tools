#!/usr/bin/env Rscript
# Cross-Validation: R TreeMineR analysis
# Generates TreeMineR benchmark results on ICD-10-SE example data
#
# Usage: Rscript 01_r_treeminer.R
#   (run from treescan/qa/ directory, or from any location)
#
# Output: data/treeminer_diagnoses.csv, data/treeminer_results.csv
#
# Requires: install.packages("TreeMineR")

library(TreeMineR)

# Paths — detect script location via commandArgs, fall back to working dir
args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", args[grep("--file=", args)])
if (length(script_arg) > 0) {
    base_dir <- dirname(normalizePath(script_arg))
} else {
    base_dir <- getwd()
}
data_dir <- file.path(base_dir, "data")
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)

# Load example data from TreeMineR package
data(diagnoses)
data(icd_10_se)

# Summary
cat("TreeMineR Cross-Validation\n")
cat("==========================\n\n")
cat("Exposure distribution:\n")
print(table(diagnoses$exposed))
n_exp_ids <- length(unique(diagnoses$id[diagnoses$exposed == 1]))
n_unexp_ids <- length(unique(diagnoses$id[diagnoses$exposed == 0]))
p_val <- n_exp_ids / (n_exp_ids + n_unexp_ids)
cat(sprintf("\nUnique exposed: %d\n", n_exp_ids))
cat(sprintf("Unique unexposed: %d\n", n_unexp_ids))
cat(sprintf("p = %.4f\n\n", p_val))

# Run TreeMineR
cat("Running TreeMineR (999 Monte Carlo simulations, seed=42)...\n")
set.seed(42)
result <- TreeMineR(
    data = diagnoses,
    tree = icd_10_se,
    p = p_val,
    n_exposed = n_exp_ids,
    n_unexposed = n_unexp_ids,
    n_monte_carlo_sim = 999,
    random_seed = 42
)

cat("\nSignificant results (p < 0.05):\n")
sig <- result[result$p_value < 0.05, ]
print(sig)

cat(sprintf("\nMax LLR: %.4f\n", max(result$llr)))

# Export
write.csv(diagnoses, file.path(data_dir, "treeminer_diagnoses.csv"), row.names = FALSE)
write.csv(as.data.frame(result), file.path(data_dir, "treeminer_results.csv"), row.names = FALSE)
cat(sprintf("\nExported to:\n  %s\n  %s\n",
    file.path(data_dir, "treeminer_diagnoses.csv"),
    file.path(data_dir, "treeminer_results.csv")))
