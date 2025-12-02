# Contributing to tvtools

Thank you for your interest in contributing to tvtools! This document provides guidelines for contributing to the R implementation of tvtools.

## How to Contribute

### Reporting Bugs

If you find a bug, please open an issue on GitHub with:

1. **Clear title** describing the problem
2. **Reproducible example** using sample data
3. **Expected behavior** vs actual behavior
4. **Session info**: Output from `sessionInfo()`
5. **System details**: OS, R version, package version

Example bug report:
```r
# Reproducible example
library(tvtools)
# ... code that produces the bug ...

# Session info
sessionInfo()
```

### Suggesting Enhancements

Enhancement suggestions are welcome! Please open an issue with:

1. **Use case**: What problem does this solve?
2. **Proposed solution**: How should it work?
3. **Alternatives considered**: Other approaches you've thought about
4. **Stata comparison**: How does the Stata version handle this (if applicable)?

### Pull Requests

We welcome pull requests! Here's the workflow:

1. **Fork the repository** and create a branch from `main`
2. **Make your changes** following the code style guidelines below
3. **Add tests** for any new functionality
4. **Update documentation** (roxygen2 comments and README if needed)
5. **Run checks**: `devtools::check()` should pass with no errors/warnings
6. **Submit PR** with clear description of changes

## Development Setup

### Prerequisites

```r
# Install development packages
install.packages(c("devtools", "roxygen2", "testthat", "usethis"))
```

### Clone and Setup

```bash
git clone https://github.com/tpcopeland/Stata-Tools.git
cd Stata-Tools/Reimplementations/R/tvtools
```

```r
# Load package for development
devtools::load_all()

# Run tests
devtools::test()

# Check package
devtools::check()
```

## Code Style Guidelines

### General Principles

- Follow the [tidyverse style guide](https://style.tidyverse.org/)
- Use meaningful variable and function names
- Keep functions focused and modular
- Comment complex logic
- Maintain API compatibility with Stata version where possible

### Specific Conventions

#### Function Names
- Use snake_case for functions (matching Stata command names)
- Be descriptive: `calculate_duration()` not `calc_dur()`

#### Variable Names
```r
# Good
person_id <- data$id
start_date <- data$start

# Avoid
pid <- data$id
st <- data$start
```

#### Documentation
Use roxygen2 for all exported functions:
```r
#' Brief Title
#'
#' @description
#' Detailed description of what the function does.
#'
#' @param param_name Description of parameter
#' @return Description of return value
#' @export
#' @examples
#' \dontrun{
#' # Example code
#' }
my_function <- function(param_name) {
  # Implementation
}
```

#### Code Organization
```r
# 1. Input validation at top
# 2. Data preparation
# 3. Core logic
# 4. Return results

my_function <- function(x, y) {
  # Validate
  if (!is.numeric(x)) stop("x must be numeric")

  # Prepare
  data_clean <- prepare_data(x, y)

  # Process
  result <- process_data(data_clean)

  # Return
  return(result)
}
```

## Testing

### Writing Tests

All new functionality should include tests using testthat:

```r
# tests/testthat/test_myfunction.R
test_that("myfunction handles basic input", {
  result <- myfunction(input)
  expect_equal(result$value, expected)
  expect_true(is.data.frame(result$data))
})

test_that("myfunction validates input", {
  expect_error(myfunction(invalid_input), "error message")
})

test_that("myfunction matches Stata output", {
  # Compare with known Stata results
  r_result <- myfunction(test_data)
  expect_equal(r_result, stata_result, tolerance = 1e-6)
})
```

### Test Coverage

- Test normal operations
- Test edge cases (empty data, single row, missing values)
- Test error conditions
- Test option combinations
- Compare with Stata output when possible

### Running Tests

```r
# Run all tests
devtools::test()

# Run specific test file
testthat::test_file("tests/testthat/test_myfunction.R")

# Run with coverage
covr::package_coverage()
```

## Documentation

### Function Documentation

Use roxygen2 for all exported functions:
- `@description`: Detailed explanation
- `@param`: Each parameter with type and description
- `@return`: What the function returns
- `@examples`: Working examples (use `\dontrun{}` if they require external data)
- `@seealso`: Related functions
- `@export`: For user-facing functions

### README Updates

If adding major functionality:
1. Update the function reference section
2. Add example if appropriate
3. Update feature list if needed

### Vignettes

For complex features, consider adding a vignette:
```r
usethis::use_vignette("feature-name")
```

## Package Checks

Before submitting PR, ensure:

```r
# 1. Documentation is up to date
devtools::document()

# 2. Tests pass
devtools::test()

# 3. No check errors/warnings
devtools::check()

# 4. Code style is consistent
styler::style_pkg()
lintr::lint_package()
```

## Stata Compatibility

### Maintaining Compatibility

When possible, maintain API compatibility with Stata version:
- Use same parameter names
- Support same options
- Produce equivalent output
- Match error messages and validation

### Documenting Differences

If R implementation differs from Stata:
1. Document in function help: `@section Differences from Stata:`
2. Note in README if significant
3. Explain rationale in comments

### Testing Against Stata

When adding/modifying functionality:
1. Test with same input data in Stata
2. Compare results (accounting for floating point differences)
3. Document any intentional differences

## Versioning

We follow [Semantic Versioning](https://semver.org/):
- **Major (1.0.0)**: Breaking API changes
- **Minor (0.1.0)**: New features, backward compatible
- **Patch (0.0.1)**: Bug fixes, backward compatible

## Release Process

(For maintainers)

1. Update version in DESCRIPTION
2. Update NEWS.md
3. Run full checks
4. Submit to CRAN (when ready)
5. Tag release on GitHub
6. Update documentation site

## Questions?

- Open an issue for questions
- Email: timothy.copeland@ki.se
- Check documentation: `help(package = "tvtools")`

## Code of Conduct

Please note that this project follows a standard Code of Conduct. By participating, you agree to abide by its terms:

- Be respectful and inclusive
- Accept constructive criticism gracefully
- Focus on what's best for the community
- Show empathy towards others

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to tvtools!
