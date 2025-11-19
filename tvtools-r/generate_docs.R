#!/usr/bin/env Rscript
# Script to generate .Rd help files for the tvtools R package
#
# This script uses roxygen2 to generate documentation from the @roxygen
# comments in the R source files.
#
# Usage:
#   Rscript generate_docs.R
#
# Or from within R:
#   setwd("/home/user/Stata-Tools/tvtools-r")
#   source("generate_docs.R")

# Set working directory to package root
setwd("/home/user/Stata-Tools/tvtools-r")

# Install roxygen2 if not already installed
if (!requireNamespace("roxygen2", quietly = TRUE)) {
  cat("Installing roxygen2 package...\n")
  install.packages("roxygen2", repos = "https://cloud.r-project.org")
}

# Load roxygen2
library(roxygen2)

# Generate documentation
cat("Generating .Rd help files from roxygen comments...\n")
roxygenize()

cat("\nDocumentation generation complete!\n")
cat("Help files have been created in: /home/user/Stata-Tools/tvtools-r/man/\n")

# List the generated files
cat("\nGenerated files:\n")
man_files <- list.files("man", pattern = "\\.Rd$", full.names = FALSE)
for (f in man_files) {
  cat(sprintf("  - %s\n", f))
}

cat("\nYou can now view help by running:\n")
cat("  ?tvexpose\n")
cat("  ?tvmerge\n")
cat("  ?cohort\n")
cat("  ?hrt_exposure\n")
cat("  ?dmt_exposure\n")
