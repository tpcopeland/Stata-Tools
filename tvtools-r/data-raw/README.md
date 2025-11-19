# Example Datasets for tvtools R Package

This directory contains scripts and data files for generating example datasets for the tvtools R package.

## Files

### CSV Data Files
- **cohort.csv** - Master cohort with 1,000 persons (study entry/exit, demographics)
- **hrt_exposure.csv** - HRT exposure periods for 391 exposed persons (791 exposure records)
- **dmt_exposure.csv** - DMT exposure periods for 758 exposed persons (1,905 exposure records)

### R Script
- **create_example_data.R** - Converts CSV files to .rda format for package distribution

## Dataset Descriptions

### cohort.csv
**1,000 rows × 8 columns**

Variables:
- `id`: Person identifier (1-1000)
- `study_entry`: Study entry date (2010-01-02 to 2011-08-29)
- `study_exit`: Study exit date (2020-12-31 for all)
- `age`: Age at baseline (25-85 years)
- `female`: Sex (0=male, 1=female)
- `mstype`: MS type (1=RRMS, 2=SPMS, 3=PPMS)
- `edss_baseline`: Baseline EDSS score (0-8.5)
- `region`: Geographic region (North, Central, South, East, West)

### hrt_exposure.csv
**791 rows × 5 columns**

Variables:
- `id`: Person identifier (linking to cohort)
- `rx_start`: HRT period start date
- `rx_stop`: HRT period stop date
- `hrt_type`: HRT type (1=Estrogen only, 2=E+P, 3=Other)
- `dose`: Daily dose in mg (0.3-1.5)

About 39% of the cohort has HRT exposure, with 1-3 periods per exposed person.

### dmt_exposure.csv
**1,905 rows × 4 columns**

Variables:
- `id`: Person identifier (linking to cohort)
- `dmt_start`: DMT period start date
- `dmt_stop`: DMT period stop date
- `dmt`: DMT type (1-6):
  - 1 = Interferon beta
  - 2 = Glatiramer acetate
  - 3 = Natalizumab
  - 4 = Fingolimod
  - 5 = Dimethyl fumarate
  - 6 = Ocrelizumab

About 76% of the cohort has DMT exposure, with 1-4 periods per exposed person (reflecting treatment switching).

## Usage

### Option 1: Use R to generate .rda files (recommended)

From the package root directory:
```r
R --vanilla < data-raw/create_example_data.R
```

Or from within R:
```r
setwd("data-raw")
source("create_example_data.R")
```

This will create three .rda files in the `data/` directory:
- `data/cohort.rda`
- `data/hrt_exposure.rda`
- `data/dmt_exposure.rda`

### Option 2: Load CSV files directly in R

```r
cohort <- read.csv("data-raw/cohort.csv")
cohort$study_entry <- as.Date(cohort$study_entry)
cohort$study_exit <- as.Date(cohort$study_exit)
```

## Example Workflow with tvtools

```r
library(tvtools)

# Load datasets
data(cohort)
data(hrt_exposure)
data(dmt_exposure)

# Create time-varying HRT exposure
tvexpose(using = hrt_exposure, 
         id = id, 
         start = rx_start, 
         stop = rx_stop,
         exposure = hrt_type,
         reference = 0,
         entry = study_entry,
         exit = study_exit)

# Continue with survival analysis...
```

## Data Generation Notes

- Seed: 42 (for reproducibility)
- Cohort size: 1,000 persons
- Study period: 2010-01-02 to 2020-12-31
- HRT exposure prevalence: ~39%
- DMT exposure prevalence: ~76%
- Generated using Python 3 with only standard library dependencies

See `R/data.R` for complete roxygen2 documentation of each dataset.
