# Script to convert CSV datasets to .rda format for the tvtools package
#
# This script reads pre-generated CSV files and saves them as compressed
# R data files (.rda) for inclusion in the package.
#
# Usage:
#   setwd("data-raw")
#   source("create_example_data.R")
#
# Or from the package root:
#   R --vanilla < data-raw/create_example_data.R

cat("Loading datasets from CSV files...\n")

# Read the CSV files
cohort <- read.csv("cohort.csv", stringsAsFactors = FALSE)
hrt_exposure <- read.csv("hrt_exposure.csv", stringsAsFactors = FALSE)
dmt_exposure <- read.csv("dmt_exposure.csv", stringsAsFactors = FALSE)

# Convert date columns to Date objects
cohort$study_entry <- as.Date(cohort$study_entry)
cohort$study_exit <- as.Date(cohort$study_exit)

hrt_exposure$rx_start <- as.Date(hrt_exposure$rx_start)
hrt_exposure$rx_stop <- as.Date(hrt_exposure$rx_stop)

dmt_exposure$dmt_start <- as.Date(dmt_exposure$dmt_start)
dmt_exposure$dmt_stop <- as.Date(dmt_exposure$dmt_stop)

# ============================================================================
# SAVE DATASETS
# ============================================================================

# Get the package directory (assuming script is in data-raw/)
current_dir <- getwd()
if (basename(current_dir) == "data-raw") {
  pkg_root <- dirname(current_dir)
} else {
  pkg_root <- current_dir
}

data_dir <- file.path(pkg_root, "data")

# Create data directory if it doesn't exist
if (!dir.exists(data_dir)) {
  dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)
}

cat("Saving datasets to", data_dir, "...\n")

# Save as compressed .rda files
save(cohort, file = file.path(data_dir, "cohort.rda"), compress = "xz")
save(hrt_exposure, file = file.path(data_dir, "hrt_exposure.rda"), compress = "xz")
save(dmt_exposure, file = file.path(data_dir, "dmt_exposure.rda"), compress = "xz")

# Print summary information
cat("\n=== EXAMPLE DATASETS CONVERTED TO .RDA ===\n\n")

cat("COHORT DATASET\n")
cat("Dimensions:", nrow(cohort), "rows,", ncol(cohort), "columns\n")
cat("Variables:", paste(names(cohort), collapse = ", "), "\n")
cat("Study period:", min(cohort$study_entry), "to", max(cohort$study_exit), "\n")
cat("Age range:", min(cohort$age), "to", max(cohort$age), "years\n")
cat("Female:", sum(cohort$female), "out of", nrow(cohort), "\n\n")

cat("HRT EXPOSURE DATASET\n")
cat("Dimensions:", nrow(hrt_exposure), "rows,", ncol(hrt_exposure), "columns\n")
cat("Variables:", paste(names(hrt_exposure), collapse = ", "), "\n")
cat("Exposed persons:", length(unique(hrt_exposure$id)), "out of", nrow(cohort), "\n")
cat("HRT types:", paste(sort(unique(hrt_exposure$hrt_type)), collapse = ", "), "\n")
cat("Dose range:", min(hrt_exposure$dose), "to", max(hrt_exposure$dose), "mg/day\n\n")

cat("DMT EXPOSURE DATASET\n")
cat("Dimensions:", nrow(dmt_exposure), "rows,", ncol(dmt_exposure), "columns\n")
cat("Variables:", paste(names(dmt_exposure), collapse = ", "), "\n")
cat("Exposed persons:", length(unique(dmt_exposure$id)), "out of", nrow(cohort), "\n")
cat("DMT types:", paste(sort(unique(dmt_exposure$dmt)), collapse = ", "), "\n\n")

cat("Data files saved to:", data_dir, "\n")
cat("Files: cohort.rda, hrt_exposure.rda, dmt_exposure.rda\n\n")

# Test that data can be loaded
load(file.path(data_dir, "cohort.rda"))
cat("SUCCESS: Data files created and verified.\n")
