# tvtools: Time-Varying Exposure and Event Analysis Tools for R

<!-- badges: start -->
[![R](https://img.shields.io/badge/R-4.0+-blue.svg)](https://www.r-project.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Status](https://img.shields.io/badge/Status-Development-orange)](https://github.com/tpcopeland/Stata-Tools)
<!-- badges: end -->

R implementation of the comprehensive tvtools package for managing time-varying exposures in longitudinal and survival analysis. Originally developed as Stata commands, this R port provides the same powerful functionality for creating, merging, and analyzing time-varying exposure data.

## Overview

**tvtools** provides three integrated functions for time-varying exposure analysis:

1. **`tvexpose()`** - Create time-varying exposure variables from period-based exposure data
2. **`tvmerge()`** - Merge multiple time-varying exposure datasets with temporal alignment
3. **`tvevent()`** - Integrate events and competing risks into time-varying datasets

### Typical Workflow

```
Raw exposure data
        ↓
    tvexpose()  ←──────────── Create time-varying exposure variables
        ↓
   [tvmerge()]  ←──────────── Merge multiple exposures (optional)
        ↓
    tvevent()   ←──────────── Integrate events and competing risks
        ↓
  Surv() + coxph() ←────────── Survival analysis
```

### Key Features

- **Comprehensive exposure definitions**: Basic time-varying, ever-treated, current/former, duration categories, continuous cumulative, recency
- **Advanced data handling**: Grace periods, gap filling, overlap resolution, lag/washout periods
- **Flexible merging**: Cartesian product temporal matching, continuous vs categorical exposures
- **Competing risks support**: Multiple competing events, automatic interval splitting, custom event labels
- **Validation tools**: Coverage diagnostics, gap detection, overlap checking, summary statistics
- **Performance optimized**: Efficient memory management, leverages data.table for speed

---

## Installation

```r
# Install from GitHub (development version)
# install.packages("devtools")
devtools::install_github("tpcopeland/Stata-Tools", subdir = "Reimplementations/R/tvtools")

# Or install locally after cloning
devtools::install_local("path/to/tvtools")
```

---

## Quick Start

### Example 1: Basic Time-Varying Exposure with tvexpose()

```r
library(tvtools)
library(dplyr)
library(lubridate)

# Create sample cohort data
cohort <- tibble(
  id = 1:5,
  entry_date = as.Date("2010-01-01") + days(0:4),
  exit_date = as.Date("2015-12-31")
)

# Create sample exposure data (medication periods)
exposures <- tibble(
  id = c(1, 1, 2, 3, 3, 3, 4),
  start_date = as.Date(c("2010-03-01", "2011-06-01", "2010-08-15",
                          "2010-05-01", "2011-01-01", "2012-03-01",
                          "2013-01-01")),
  stop_date = as.Date(c("2010-06-30", "2012-12-31", "2011-03-15",
                         "2010-10-31", "2011-06-30", "2013-05-31",
                         "2014-06-30")),
  medication = c(1, 2, 1, 1, 1, 2, 1)  # 0=unexposed, 1=drug A, 2=drug B
)

# Create time-varying exposure dataset
result <- tvexpose(
  master_data = cohort,
  exposure_file = exposures,
  id = "id",
  start = "start_date",
  stop = "stop_date",
  exposure = "medication",
  reference = 0,  # 0 = unexposed
  entry = "entry_date",
  exit = "exit_date",
  generate = "drug_exposure"
)

head(result$data)
#>   id      start       stop drug_exposure
#> 1  1 2010-01-01 2010-02-28             0
#> 2  1 2010-03-01 2010-06-30             1
#> 3  1 2010-07-01 2011-05-31             0
#> 4  1 2011-06-01 2012-12-31             2
#> 5  1 2013-01-01 2015-12-31             0
#> 6  2 2010-01-02 2010-08-14             0
```

### Example 2: Cumulative Duration with tvexpose()

```r
# Create duration categories for cumulative exposure
result_duration <- tvexpose(
  master_data = cohort,
  exposure_file = exposures,
  id = "id",
  start = "start_date",
  stop = "stop_date",
  exposure = "medication",
  reference = 0,
  entry = "entry_date",
  exit = "exit_date",
  duration = c(90, 180, 365),  # Categories: <90d, 90-180d, 180-365d, >365d
  generate = "drug_duration"
)

# Duration variable shows cumulative exposure time in categories
head(result_duration$data)
```

### Example 3: Merge Multiple Time-Varying Exposures with tvmerge()

```r
# Suppose we have two separate time-varying datasets
# (e.g., from two separate tvexpose() calls)

# Medication exposure dataset
med_data <- tibble(
  id = rep(1:3, each = 3),
  start = as.Date(c("2010-01-01", "2010-06-01", "2011-01-01",
                     "2010-01-01", "2010-08-01", "2011-03-01",
                     "2010-01-01", "2010-05-01", "2011-01-01")),
  stop = as.Date(c("2010-05-31", "2010-12-31", "2012-12-31",
                    "2010-07-31", "2011-02-28", "2012-12-31",
                    "2010-04-30", "2010-12-31", "2012-12-31")),
  medication = c(0, 1, 0,  0, 1, 2,  0, 1, 1)
)

# Comorbidity exposure dataset
comorbid_data <- tibble(
  id = rep(1:3, each = 2),
  start = as.Date(c("2010-01-01", "2010-09-01",
                     "2010-01-01", "2011-01-01",
                     "2010-01-01", "2010-11-01")),
  stop = as.Date(c("2010-08-31", "2012-12-31",
                    "2010-12-31", "2012-12-31",
                    "2010-10-31", "2012-12-31")),
  diabetes = c(0, 1,  0, 1,  0, 1)
)

# Merge the two time-varying datasets
merged <- tvmerge(
  datasets = list(med_data, comorbid_data),
  id = "id",
  start = c("start", "start"),
  stop = c("stop", "stop"),
  exposure = c("medication", "diabetes"),
  generate = c("med", "diab")
)

head(merged$data)
#>   id      start       stop med diab
#> 1  1 2010-01-01 2010-05-31   0    0
#> 2  1 2010-06-01 2010-08-31   1    0
#> 3  1 2010-09-01 2010-12-31   1    1
#> 4  1 2011-01-01 2012-12-31   0    1
```

### Example 4: Add Events with tvevent()

```r
# Start with time-varying exposure data (from tvexpose or tvmerge)
tv_data <- tibble(
  id = rep(1:4, each = 3),
  start = as.Date(c("2010-01-01", "2010-06-01", "2011-01-01",
                     "2010-01-01", "2010-08-01", "2011-06-01",
                     "2010-01-01", "2010-05-01", "2010-11-01",
                     "2010-01-01", "2010-09-01", "2011-03-01")),
  stop = as.Date(c("2010-05-31", "2010-12-31", "2012-12-31",
                    "2010-07-31", "2011-05-31", "2012-12-31",
                    "2010-04-30", "2010-10-31", "2012-12-31",
                    "2010-08-31", "2011-02-28", "2012-12-31")),
  exposure = c(0, 1, 0,  0, 1, 2,  0, 1, 1,  0, 1, 0)
)

# Event data with primary outcome and competing risk
events <- tibble(
  id = c(1, 2, 3),
  mi_date = as.Date(c("2011-08-15", NA, "2010-09-20")),  # Myocardial infarction
  death_date = as.Date(c(NA, "2011-10-30", NA))           # Death (competing risk)
)

# Integrate events into time-varying dataset
result_events <- tvevent(
  intervals_data = tv_data,
  events_data = events,
  id = "id",
  date = "mi_date",
  compete = "death_date",
  generate = "outcome",
  type = "single"  # Terminal event
)

tail(result_events$data, 10)
#> Shows intervals split at event dates with outcome indicator:
#> 0 = censored, 1 = MI, 2 = death
```

### Example 5: Complete Workflow

```r
library(tvtools)
library(survival)

# Step 1: Create time-varying exposure
tv_exposure <- tvexpose(
  master_data = cohort_data,
  exposure_file = medication_data,
  id = "patient_id",
  start = "rx_start",
  stop = "rx_stop",
  exposure = "drug_type",
  reference = 0,
  entry = "cohort_entry",
  exit = "cohort_exit",
  currentformer = TRUE,  # Create never/current/former categories
  generate = "drug_status"
)

# Step 2: Optionally merge with other time-varying covariates
# (Skip if only one exposure source)

# Step 3: Integrate outcome events
final_data <- tvevent(
  intervals_data = tv_exposure$data,
  events_data = outcomes,
  id = "patient_id",
  date = "event_date",
  compete = c("death_date", "censoring_date"),
  generate = "event",
  type = "single"
)

# Step 4: Survival analysis
cox_model <- coxph(
  Surv(start, stop, event == 1) ~ drug_status + age + sex,
  data = final_data$data,
  id = patient_id
)

summary(cox_model)
```

---

## Function Reference

### tvexpose()

Create time-varying exposure variables from period-based exposure data.

**Key Parameters:**
- `master_data`: Cohort data frame with entry/exit dates
- `exposure_file`: Exposure periods data (file path or data frame)
- `id`, `start`, `stop`: Variable names for ID and date columns
- `exposure`: Name of exposure variable
- `reference`: Value indicating unexposed status
- `entry`, `exit`: Study period boundaries

**Exposure Types:**
- `evertreated = TRUE`: Binary ever/never exposed
- `currentformer = TRUE`: Never/current/former categories
- `duration = c(90, 180, 365)`: Cumulative duration categories
- `continuousunit = "days"`: Continuous cumulative exposure
- `recency = c(1, 2, 5)`: Time since last exposure

**Advanced Options:**
- `grace`, `fillgaps`, `carryforward`: Handle gaps in exposure
- `lag`, `washout`: Exposure latency and persistence
- `priority`, `layer`, `split`: Handle overlapping exposures
- `check`, `summarize`: Validation and diagnostics

### tvmerge()

Merge multiple time-varying datasets using Cartesian product of overlapping periods.

**Key Parameters:**
- `datasets`: List of data frames or file paths
- `id`: ID variable name (same across all datasets)
- `start`, `stop`: Vectors of start/stop variable names
- `exposure`: Vector of exposure variable names
- `generate`: New names for exposure variables in output
- `continuous`: Which exposures are continuous (for interpolation)

**Options:**
- `batch`: Memory management (process IDs in batches)
- `force`: Allow mismatched IDs between datasets
- `check`, `summarize`: Diagnostics

### tvevent()

Integrate outcome events and competing risks into time-varying datasets.

**Key Parameters:**
- `intervals_data`: Time-varying dataset (from tvexpose/tvmerge)
- `events_data`: Events data frame
- `id`: ID variable name
- `date`: Primary event date variable
- `compete`: Competing risk date variables (vector)
- `generate`: Name for event indicator variable
- `type`: "single" (terminal) or "recurring" events

**Options:**
- `continuous`: Variables to adjust proportionally when splitting intervals
- `timegen`: Create duration variable
- `timeunit`: Unit for duration ("days", "months", "years")
- `eventlabel`: Custom event labels

---

## Links

- **Original Stata Package**: [tvtools on GitHub](https://github.com/tpcopeland/Stata-Tools/tree/main/tvtools)
- **Stata Installation**: `net install tvtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools")`
- **Issue Tracker**: [GitHub Issues](https://github.com/tpcopeland/Stata-Tools/issues)

---

## Citation

If you use tvtools in your research, please cite:

```
Copeland, T. P. (2025). tvtools: Time-Varying Exposure and Event Analysis Tools.
GitHub repository: https://github.com/tpcopeland/Stata-Tools
```

---

## Author

**Timothy P. Copeland**
Department of Clinical Neuroscience
Karolinska Institutet, Stockholm, Sweden
Email: timothy.copeland@ki.se

---

## License

MIT License - see LICENSE file for details.

---

## Version

Version 0.1.0 (Development), 2025-12-02
