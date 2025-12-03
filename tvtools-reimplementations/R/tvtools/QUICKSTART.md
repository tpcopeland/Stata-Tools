# tvtools Quick Start Guide

## For End Users

### Installation

```r
# From GitHub (when public)
devtools::install_github("tpcopeland/Stata-Tools", subdir = "Reimplementations/R/tvtools")

# From local source
devtools::install_local("path/to/tvtools")
```

### Basic Usage

```r
library(tvtools)

# 1. Create time-varying exposure
result <- tvexpose(
  master_data = cohort,
  exposure_file = exposures,
  id = "id",
  start = "start_date",
  stop = "stop_date",
  exposure = "medication",
  reference = 0,
  entry = "entry_date",
  exit = "exit_date"
)

# 2. Add events
final <- tvevent(
  intervals_data = result$data,
  events_data = events,
  id = "id",
  date = "event_date",
  generate = "outcome"
)

# 3. Analyze
library(survival)
coxph(Surv(start, stop, outcome == 1) ~ medication, data = final$data)
```

---

## For Developers

### Setup Development Environment

```r
# Install development tools
install.packages(c("devtools", "roxygen2", "testthat", "usethis"))

# Clone repository
# git clone https://github.com/tpcopeland/Stata-Tools.git
# cd Stata-Tools/Reimplementations/R/tvtools

# Load package for development
devtools::load_all()
```

### Essential Commands

```r
# 1. Generate documentation from roxygen2 comments
devtools::document()

# 2. Run tests
devtools::test()

# 3. Check package (comprehensive validation)
devtools::check()

# 4. Install locally
devtools::install()

# 5. Build tarball
devtools::build()

# 6. Load for interactive development
devtools::load_all()
```

### Workflow

```r
# Step 1: Make changes to R/*.R files

# Step 2: Update roxygen2 documentation
devtools::document()

# Step 3: Test your changes
devtools::test()

# Step 4: Check package
devtools::check()

# Step 5: If all passes, commit
# git add .
# git commit -m "Description"
```

### Adding New Functions

```r
# 1. Create new R file in R/
usethis::use_r("newfunction")

# 2. Write function with roxygen2 documentation
#' Function Title
#'
#' @param x Description
#' @return Description
#' @export
#' @examples
#' newfunction(x = 1)
newfunction <- function(x) {
  # Implementation
}

# 3. Create test file
usethis::use_test("newfunction")

# 4. Generate documentation
devtools::document()

# 5. Run tests
devtools::test()
```

### Adding Tests

```r
# tests/testthat/test_myfunction.R
test_that("myfunction works correctly", {
  result <- myfunction(input)
  expect_equal(result, expected)
  expect_true(is.data.frame(result))
})

test_that("myfunction validates input", {
  expect_error(myfunction(bad_input), "error message")
})
```

### Building Vignettes

```r
# Build vignettes
devtools::build_vignettes()

# View vignettes
devtools::build_rmd("vignettes/tvtools-intro.Rmd")
```

---

## Common Tasks

### Update Package Version

Edit DESCRIPTION:
```
Version: 0.2.0
```

Update NEWS.md:
```markdown
# tvtools 0.2.0

* New feature X
* Bug fix Y
```

### Fix Documentation

1. Edit roxygen2 comments in R/*.R
2. Run `devtools::document()`
3. Check `man/*.Rd` files

### Run Specific Test

```r
testthat::test_file("tests/testthat/test_tvevent_basic.R")
```

### Check Test Coverage

```r
covr::package_coverage()
```

### Lint Code

```r
lintr::lint_package()
```

### Format Code

```r
styler::style_pkg()
```

---

## Troubleshooting

### "Cannot load package"

```r
# Clean and rebuild
devtools::clean_dll()
devtools::document()
devtools::load_all()
```

### "Documentation out of date"

```r
# Regenerate documentation
devtools::document()
```

### "Test failures"

```r
# Run tests with details
devtools::test()

# Or specific test
testthat::test_file("tests/testthat/test_myfunction.R")
```

### "Check warnings"

```r
# Run check and examine output
devtools::check()
# Read the output carefully and fix issues one by one
```

---

## Quick Reference

### File Locations
- Source code: `R/*.R`
- Tests: `tests/testthat/test_*.R`
- Documentation: Auto-generated in `man/` from roxygen2
- Vignettes: `vignettes/*.Rmd`
- Package metadata: `DESCRIPTION`

### Key Commands
| Task | Command |
|------|---------|
| Load package | `devtools::load_all()` |
| Document | `devtools::document()` |
| Test | `devtools::test()` |
| Check | `devtools::check()` |
| Install | `devtools::install()` |
| Build | `devtools::build()` |

### roxygen2 Tags
| Tag | Purpose |
|-----|---------|
| `@param` | Parameter description |
| `@return` | Return value description |
| `@export` | Export function |
| `@examples` | Usage examples |
| `@importFrom` | Import from package |
| `@seealso` | Related functions |

---

## Help

- Package help: `?tvtools`
- Function help: `?tvexpose`, `?tvmerge`, `?tvevent`
- Vignette: `vignette("tvtools-intro")`
- Issues: https://github.com/tpcopeland/Stata-Tools/issues
- Email: timothy.copeland@ki.se

---

## Package Structure

```
tvtools/
├── DESCRIPTION      # Package metadata
├── NAMESPACE        # Exports/imports
├── R/              # Source code
├── man/            # Documentation (generated)
├── tests/          # Tests
├── vignettes/      # Long-form docs
└── data-raw/       # Raw data
```

---

**Last Updated**: 2025-12-02
