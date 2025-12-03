# Installation Guide for tvtools R Package

## Prerequisites

### Required R Version
- R >= 4.0.0

### Required R Packages
The following packages will be automatically installed if not present:
- dplyr (>= 1.0.0)
- data.table (>= 1.14.0)
- tibble (>= 3.0.0)
- haven (>= 2.4.0)
- rlang (>= 0.4.0)
- tidyr (>= 1.1.0)
- lubridate (>= 1.7.0)

### Suggested Packages (for testing and examples)
- testthat (>= 3.0.0)
- survival
- knitr
- rmarkdown

---

## Installation Methods

### Method 1: Install from GitHub (Recommended)

```r
# Install devtools if not already installed
if (!requireNamespace("devtools", quietly = TRUE)) {
  install.packages("devtools")
}

# Install tvtools from GitHub
devtools::install_github(
  "tpcopeland/Stata-Tools",
  subdir = "Reimplementations/R/tvtools"
)
```

### Method 2: Install from Local Source

If you have cloned the repository:

```r
# Navigate to the package directory and install
devtools::install_local("path/to/Stata-Tools/Reimplementations/R/tvtools")

# Or use install.packages with type="source"
install.packages(
  "path/to/Stata-Tools/Reimplementations/R/tvtools",
  repos = NULL,
  type = "source"
)
```

### Method 3: Build and Install from Source

For developers who want to build the package:

```bash
# Navigate to the parent directory containing tvtools/
cd /path/to/Stata-Tools/Reimplementations/R/

# Build the package tarball
R CMD build tvtools

# Install the built package
R CMD INSTALL tvtools_0.1.0.tar.gz
```

---

## Verify Installation

After installation, verify that the package loads correctly:

```r
# Load the package
library(tvtools)

# Check package version
packageVersion("tvtools")

# View package help
help(package = "tvtools")

# Test basic functionality
?tvexpose
?tvmerge
?tvevent
```

---

## Common Installation Issues

### Issue: Package dependencies fail to install

**Solution**: Install dependencies manually first:
```r
install.packages(c("dplyr", "data.table", "tibble", "haven",
                   "rlang", "tidyr", "lubridate"))
```

### Issue: Compilation errors on Windows

**Solution**: Install Rtools from CRAN:
- Download from: https://cran.r-project.org/bin/windows/Rtools/
- Install and ensure it's in your PATH

### Issue: Permission errors on Linux/Mac

**Solution**: Install to user library or use sudo:
```r
# Install to user library (recommended)
devtools::install_github(
  "tpcopeland/Stata-Tools",
  subdir = "Reimplementations/R/tvtools",
  lib = Sys.getenv("R_LIBS_USER")
)
```

---

## Updating the Package

To update to the latest version:

```r
# Remove old version
remove.packages("tvtools")

# Reinstall latest version
devtools::install_github(
  "tpcopeland/Stata-Tools",
  subdir = "Reimplementations/R/tvtools"
)
```

---

## Running Tests

To run the package test suite:

```r
# Install with tests
devtools::install_github(
  "tpcopeland/Stata-Tools",
  subdir = "Reimplementations/R/tvtools",
  build_vignettes = TRUE,
  dependencies = TRUE
)

# Run tests
devtools::test("path/to/tvtools")

# Or use testthat directly
library(testthat)
library(tvtools)
test_package("tvtools")
```

---

## Building Documentation

To build package documentation:

```r
# Install roxygen2 if needed
install.packages("roxygen2")

# Generate documentation
devtools::document("path/to/tvtools")

# Build manual PDF (requires LaTeX)
devtools::build_manual("path/to/tvtools")
```

---

## Uninstalling

To remove the package:

```r
remove.packages("tvtools")
```

---

## Getting Help

- **Package Documentation**: `help(package = "tvtools")`
- **Function Help**: `?tvexpose`, `?tvmerge`, `?tvevent`
- **Issues**: https://github.com/tpcopeland/Stata-Tools/issues
- **Email**: timothy.copeland@ki.se

---

## Next Steps

After successful installation, see the [README.md](README.md) for quick start examples and usage guides.
