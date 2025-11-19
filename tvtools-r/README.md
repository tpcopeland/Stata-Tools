# tvtools: Time-Varying Exposure Tools for Survival Analysis

<!-- badges: start -->
[![R-CMD-check](https://img.shields.io/badge/R--CMD--check-passing-brightgreen.svg)](https://github.com/tpcopeland/tvtools-r)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/tpcopeland/tvtools-r)
<!-- badges: end -->

## Overview

**tvtools** provides comprehensive tools for creating and merging time-varying exposure variables for survival analysis in R. This package is designed to handle complex exposure patterns common in epidemiological and pharmacoepidemiological studies.

### Key Features

- **Create time-varying exposures** from period-based exposure data
- **Multiple exposure definitions**: ever-treated, current/former, duration categories, continuous exposure
- **Flexible data handling**: grace periods, gap filling, lag/washout periods
- **Merge multiple exposures**: combine different time-varying exposures into a single analysis dataset
- **Comprehensive diagnostics**: validate coverage, identify gaps and overlaps
- **Survival analysis ready**: output compatible with `survival::Surv()` and Cox models

## Installation

```r
# Install from GitHub
# install.packages("devtools")
devtools::install_github("tpcopeland/tvtools-r")
```

## Quick Start

### Basic Time-Varying Exposure

Create a time-varying exposure variable from treatment periods:

```r
library(tvtools)
library(survival)
library(dplyr)

# Load cohort data with entry/exit dates
data(cohort)

# Load treatment exposure periods
data(hrt_exposure)

# Create time-varying HRT exposure
tv_data <- tvexpose(
  master = cohort,
  exposure_data = hrt_exposure,
  id = "id",
  entry = "study_entry",
  exit = "study_exit",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "hrt_type",
  reference = 0,
  generate = "hrt_type"
)

# Run Cox regression
cox_model <- coxph(Surv(start, stop, event) ~ hrt_type + age + female,
                   data = tv_data)
summary(cox_model)
```

### Ever-Treated Analysis

Create a binary indicator that switches permanently at first exposure:

```r
tv_ever <- tvexpose(
  master = cohort,
  exposure_data = hrt_exposure,
  id = "id",
  entry = "study_entry",
  exit = "study_exit",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "hrt_type",
  reference = 0,
  evertreated = TRUE
)
```

### Duration-Based Exposure

Create categories based on cumulative exposure duration:

```r
tv_duration <- tvexpose(
  master = cohort,
  exposure_data = hrt_exposure,
  id = "id",
  entry = "study_entry",
  exit = "study_exit",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "hrt_type",
  reference = 0,
  duration = c(1, 5, 10),  # Categories: <1, 1-5, 5-10, 10+ years
  continuousunit = "years"
)
```

### Merging Multiple Exposures

Combine different time-varying exposures:

```r
# Create first time-varying dataset (HRT)
tv_hrt <- tvexpose(
  master = cohort,
  exposure_data = hrt_exposure,
  id = "id",
  entry = "study_entry",
  exit = "study_exit",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "hrt_type",
  reference = 0,
  generate = "hrt_type"
)

# Create second time-varying dataset (DMT)
tv_dmt <- tvexpose(
  master = cohort,
  exposure_data = dmt_exposures,
  id = "id",
  entry = "study_entry",
  exit = "study_exit",
  start = "dmt_start",
  stop = "dmt_stop",
  exposure = "dmt",
  reference = 0,
  generate = "dmt_type"
)

# Merge the two time-varying datasets
tv_merged <- tvmerge(
  datasets = list(tv_hrt, tv_dmt),
  id = "id",
  start = c("start", "start"),
  stop = c("stop", "stop"),
  exposure = c("hrt_type", "dmt_type")
)

# Now you can analyze joint effects
cox_model <- coxph(Surv(start, stop, event) ~ hrt_type + dmt_type + age + female,
                   data = tv_merged)
```

## Main Functions

### `tvexpose()`

Creates time-varying exposure variables from period-based exposure data.

**Key parameters:**
- `master`: Master cohort dataset with person-level data
- `exposure_data`: Dataset containing exposure periods
- `id`: Person identifier variable
- `entry`, `exit`: Study entry and exit dates
- `start`, `stop`: Exposure period start and stop dates
- `exposure`: Exposure type/category variable
- `reference`: Value indicating unexposed/reference status
- `evertreated`, `currentformer`, `duration`, `continuousunit`: Exposure definition options

**Advanced options:**
- Grace periods for gap handling
- Lag and washout periods
- Priority rules for overlapping exposures
- Recency categories
- Pattern tracking

See `vignette("introduction")` for detailed examples.

### `tvmerge()`

Merges multiple time-varying exposure datasets created by `tvexpose()`.

**Key parameters:**
- `datasets`: List of time-varying datasets to merge
- `id`: Person identifier variable
- `start`: Character vector of start date variable names (one per dataset)
- `stop`: Character vector of stop date variable names (one per dataset)
- `exposure`: Character vector of exposure variable names (one per dataset)
- `generate`: Optional - custom names for exposure variables in output

**Features:**
- Handles categorical and continuous exposures
- Creates intersection of time periods
- Validates coverage and detects gaps
- Preserves additional covariates

See `vignette("tvmerge-guide")` for detailed workflow examples.

## Documentation

- [Introduction to tvtools](vignettes/introduction.Rmd) - Basic concepts and `tvexpose()` examples
- [Merging Time-Varying Exposures](vignettes/tvmerge-guide.Rmd) - Complete workflow with `tvmerge()`
- [Function Reference](man/) - Detailed documentation for all functions

## Use Cases

**tvtools** is designed for:

1. **Pharmacoepidemiology**: Analyzing drug exposure effects while accounting for treatment changes
2. **Occupational cohort studies**: Modeling time-varying workplace exposures
3. **Environmental epidemiology**: Handling changing pollution or climate exposures
4. **Clinical research**: Analyzing treatment switching and dose modifications
5. **Immortal time bias correction**: Creating proper ever-treated variables

## Typical Workflow

```r
# 1. Prepare cohort data with entry/exit dates
cohort <- data.frame(
  id = 1:1000,
  study_entry = as.Date("2010-01-01") + sample(0:365, 1000, replace = TRUE),
  study_exit = as.Date("2020-12-31"),
  age = rnorm(1000, 50, 10),
  female = rbinom(1000, 1, 0.5),
  event = rbinom(1000, 1, 0.1)
)

# 2. Prepare exposure periods
exposures <- data.frame(
  id = sample(1:1000, 5000, replace = TRUE),
  rx_start = as.Date("2010-01-01") + sample(0:3650, 5000, replace = TRUE),
  rx_stop = as.Date("2010-01-01") + sample(365:3650, 5000, replace = TRUE),
  drug_type = sample(1:3, 5000, replace = TRUE)
)

# 3. Create time-varying exposure
tv_data <- tvexpose(
  master = cohort,
  exposure_data = exposures,
  id = "id",
  entry = "study_entry",
  exit = "study_exit",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "drug_type",
  reference = 0,
  generate = "drug_type"
)

# 4. Analyze with survival models
library(survival)
cox_model <- coxph(Surv(start, stop, event) ~ drug_type + age + female,
                   data = tv_data)
summary(cox_model)
```

## Citation

If you use tvtools in your research, please cite:

```
Copeland TP (2025). tvtools: Time-Varying Exposure Tools for Survival Analysis.
R package version 1.0.0.
```

BibTeX entry:

```bibtex
@Manual{tvtools,
  title = {tvtools: Time-Varying Exposure Tools for Survival Analysis},
  author = {Timothy P. Copeland},
  year = {2025},
  note = {R package version 1.0.0},
  url = {https://github.com/tpcopeland/tvtools-r},
}
```

## Related Software

**tvtools** is also available for Stata users:
- [tvtools for Stata](https://github.com/tpcopeland/Stata-Tools/tree/main/tvtools) - Original implementation with `tvexpose` and `tvmerge` commands

## Author

**Timothy P. Copeland**
Department of Clinical Neuroscience
Karolinska Institutet
Email: timothy.copeland@ki.se

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Issues

Report bugs or request features at: https://github.com/tpcopeland/tvtools-r/issues
