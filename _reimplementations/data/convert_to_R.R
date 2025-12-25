#!/usr/bin/env Rscript
# Convert CSV test data to R .rds format
# Also parses dates correctly for tvtools testing

library(data.table)

csv_dir <- "/home/tpcopeland/Stata-Tools/_reimplementations/data/csv"
rds_dir <- "/home/tpcopeland/Stata-Tools/_reimplementations/data/R"

dir.create(rds_dir, showWarnings = FALSE, recursive = TRUE)

# List of files to convert
files <- c(
  "cohort", "hrt", "dmt", "steroids", "hospitalizations",
  "hospitalizations_wide", "point_events", "overlapping_exposures",
  "edss_long", "edge_single_obs", "edge_single_exp",
  "edge_short_followup", "edge_short_exp", "edge_same_type",
  "edge_boundary_exp"
)

# Date columns by file
date_cols <- list(
  cohort = c("study_entry", "study_exit", "edss4_dt", "death_dt", "emigration_dt"),
  hrt = c("rx_start", "rx_stop"),
  dmt = c("dmt_start", "dmt_stop"),
  steroids = c("steroid_start", "steroid_stop"),
  hospitalizations = c("hosp_date", "hosp_end"),
  hospitalizations_wide = c("study_entry", "study_exit", "hosp_date1", "hosp_date2",
                            "hosp_date3", "hosp_date4", "hosp_date5"),
  point_events = c("event_date"),
  overlapping_exposures = c("exp_start", "exp_stop"),
  edss_long = c("edss_dt"),
  edge_single_obs = c("study_entry", "study_exit", "edss4_dt", "death_dt", "emigration_dt"),
  edge_single_exp = c("rx_start", "rx_stop"),
  edge_short_followup = c("study_entry", "study_exit"),
  edge_short_exp = c("rx_start", "rx_stop"),
  edge_same_type = c("rx_start", "rx_stop"),
  edge_boundary_exp = c("rx_start", "rx_stop")
)

# Function to parse Stata date format (e.g., "03may2013")
parse_stata_date <- function(x) {
  # Handle empty or NA values
  x <- as.character(x)
  x[x == "" | x == "."] <- NA
  as.Date(x, format = "%d%b%Y")
}

cat("Converting CSV files to R format...\n")
cat(paste(rep("-", 60), collapse = ""), "\n")

for (f in files) {
  csv_path <- file.path(csv_dir, paste0(f, ".csv"))
  rds_path <- file.path(rds_dir, paste0(f, ".rds"))

  if (!file.exists(csv_path)) {
    cat(sprintf("  [SKIP] %s.csv not found\n", f))
    next
  }

  # Read CSV
  dt <- fread(csv_path)

  # Convert Stata date strings to actual dates
  if (f %in% names(date_cols)) {
    for (col in date_cols[[f]]) {
      if (col %in% names(dt)) {
        # Stata dates are in format like "03may2013"
        dt[[col]] <- parse_stata_date(dt[[col]])
      }
    }
  }

  # Save as RDS
  saveRDS(dt, rds_path)
  cat(sprintf("  [OK] %s.rds (%d obs, %d vars)\n", f, nrow(dt), ncol(dt)))
}

cat(paste(rep("-", 60), collapse = ""), "\n")
cat("Conversion complete\n")
