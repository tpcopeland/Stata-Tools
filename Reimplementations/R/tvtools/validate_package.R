#!/usr/bin/env Rscript
# Validation script for tvtools R package
# Run this to verify package structure is correct before installation

cat("Validating tvtools R package structure...\n\n")

# Check R version
r_version <- R.version.string
cat("R Version:", r_version, "\n")
if (getRversion() < "4.0.0") {
  stop("R >= 4.0.0 required")
} else {
  cat("✓ R version requirement met\n\n")
}

# Check required files exist
required_files <- c(
  "DESCRIPTION",
  "NAMESPACE",
  "LICENSE",
  "README.md",
  "R/tvevent.R",
  "R/tvexpose.R",
  "R/tvmerge.R",
  "R/tvtools-package.R"
)

cat("Checking required files:\n")
all_exist <- TRUE
for (file in required_files) {
  exists <- file.exists(file)
  status <- if (exists) "✓" else "✗"
  cat(sprintf("  %s %s\n", status, file))
  if (!exists) all_exist <- FALSE
}

if (!all_exist) {
  stop("\nSome required files are missing!")
}
cat("\n✓ All required files present\n\n")

# Check DESCRIPTION file
cat("Validating DESCRIPTION file:\n")
desc <- read.dcf("DESCRIPTION")
required_fields <- c("Package", "Version", "Title", "Description", "License")
for (field in required_fields) {
  value <- desc[1, field]
  cat(sprintf("  %s: %s\n", field, substr(value, 1, 50)))
}
cat("✓ DESCRIPTION file valid\n\n")

# Check dependencies
cat("Checking dependencies:\n")
required_pkgs <- c("dplyr", "data.table", "tibble", "haven", "rlang", "tidyr", "lubridate")
missing_pkgs <- character(0)
for (pkg in required_pkgs) {
  installed <- requireNamespace(pkg, quietly = TRUE)
  status <- if (installed) "✓" else "✗ (missing)"
  cat(sprintf("  %s %s\n", status, pkg))
  if (!installed) missing_pkgs <- c(missing_pkgs, pkg)
}

if (length(missing_pkgs) > 0) {
  cat("\n⚠ Warning: Some dependencies are missing. Install with:\n")
  cat(sprintf("  install.packages(c('%s'))\n", paste(missing_pkgs, collapse = "', '")))
} else {
  cat("\n✓ All dependencies installed\n")
}

# Summary
cat("\n" , rep("=", 60), "\n", sep = "")
cat("PACKAGE VALIDATION SUMMARY\n")
cat(rep("=", 60), "\n", sep = "")
cat("\nPackage: tvtools\n")
cat("Version:", desc[1, "Version"], "\n")
cat("Status: Ready for installation\n\n")

cat("To install this package, run:\n")
cat("  devtools::install_local('.')\n\n")

cat("Or from parent directory:\n")
cat("  devtools::install_local('tvtools')\n\n")

cat("To check package (developers):\n")
cat("  devtools::check()\n\n")

cat("To generate documentation:\n")
cat("  devtools::document()\n\n")

cat("✓ Validation complete!\n")
