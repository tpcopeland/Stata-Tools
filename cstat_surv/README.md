# cstat_surv

![Stata 13+](https://img.shields.io/badge/Stata-13%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

Calculate C-statistic for survival models.

## Description

`cstat_surv` calculates the C-statistic (concordance statistic) for survival models after fitting a Cox proportional hazards model. The C-statistic measures the model's ability to discriminate between subjects who experience the event and those who do not.

The command must be run immediately after fitting a Cox model with `stcox`. It uses Somers' D transformation to calculate the C-statistic, accounting for censoring in survival data.

### C-statistic Interpretation

The C-statistic ranges from 0 to 1:
- **C = 0.5**: No discrimination (random predictions)
- **C > 0.7**: Acceptable discrimination
- **C > 0.8**: Excellent discrimination

The C-statistic is equivalent to the area under the ROC curve (AUC) and represents the probability that, for a randomly selected pair of subjects where one experienced the event and one did not, the model assigns a higher risk to the subject who experienced the event.

## Dependencies

**Required**: The `somersd` package (from SSC)

```stata
ssc install somersd
```

## Installation

```stata
net from https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/cstat_surv
net install cstat_surv
```

## Syntax

```stata
cstat_surv
```

**No options** - must be run immediately after `stcox`

## Requirements

1. Your data must be `stset` before running the Cox model
2. You must have just run `stcox` in the current session
3. The `somersd` package must be installed (from SSC)

## How It Works

The command works by:

1. Predicting hazard ratios from the fitted Cox model
2. Computing the inverse hazard ratio for proper ordering
3. Creating a censoring indicator from the failure variable
4. Calculating Somers' D using the `somersd` command with the c-transformation
5. Cleaning up temporary variables

## Examples

### Basic Example

Setup:
```stata
webuse drugtr
stset studytime, failure(died)
```

Fit a Cox proportional hazards model:
```stata
stcox age drug
```

Calculate the C-statistic:
```stata
cstat_surv
```

The output will display Somers' D and its transformation, including the C-statistic with confidence intervals and p-values.

### More Complex Example

```stata
* Load and prepare survival data
use patient_data, clear
stset followup_time, failure(death)

* Fit Cox model with multiple predictors
stcox age i.sex i.treatment baseline_severity

* Calculate model discrimination
cstat_surv

* Interpret results
* C > 0.7 suggests good predictive ability
```

## Stored Results

`cstat_surv` stores the following in `r()` (via the `somersd` command):

| Result | Description |
|--------|-------------|
| `r(somers_d)` | Somers' D coefficient |
| `r(c)` | C-statistic |
| `r(se)` | Standard error |
| `r(z)` | Z-statistic |
| `r(p)` | P-value |
| `r(lb)` | Lower bound of confidence interval |
| `r(ub)` | Upper bound of confidence interval |

## Requirements

Stata 13.0 or higher (requires `stcox` and `somersd`)

## Author

Timothy P Copeland
Department of Clinical Neuroscience
Karolinska Institutet
Email: timothy.copeland@ki.se

Version 1.0.0 - 15 May 2022

## See Also

- [stcox](https://www.stata.com/manuals/ststcox.pdf) - Cox proportional hazards regression
- [stset](https://www.stata.com/manuals/ststset.pdf) - Declare survival-time data
- [somersd](https://www.stata.com/meeting/uk10/uk10_newson.pdf) - Somers' D and extensions
