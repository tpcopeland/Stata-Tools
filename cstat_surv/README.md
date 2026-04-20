# cstat_surv - Harrell's C-statistic after `stcox`

**Version 1.0.0** | 2026-04-08

`cstat_surv` calculates Harrell's C-statistic for Cox proportional hazards models and reports an infinitesimal-jackknife standard error with a confidence interval. It is meant for post-estimation discrimination checks when you want a survival-model analogue of AUC.

## Requirements

- Stata 16 or later
- Survival-time data already declared with `stset`
- A Cox model fit with `stcox` in the current session

## Installation

```stata
capture ado uninstall cstat_surv
net install cstat_surv, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/cstat_surv") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `cstat_surv` | Calculate Harrell's C-statistic after `stcox` |

## How It Works

- Fit a Cox model with `stcox`.
- Run `cstat_surv` immediately afterward on the same estimation results.
- The command predicts fitted risk scores, compares all comparable survival pairs, and replaces `e()` with the C-statistic output.

## Worked Examples

### 1. Basic workflow with built-in data

This is the shortest complete workflow and is runnable with Stata's built-in survival example data.

```stata
webuse drugtr, clear
stset studytime, failure(died)
stcox age drug
cstat_surv
```

### 2. Report a different confidence level

Use `level()` when you want a non-default interval around Harrell's C.

```stata
webuse drugtr, clear
stset studytime, failure(died)
stcox age drug
cstat_surv, level(90)
```

## Important Behavior

- `cstat_surv` overwrites the active `e()` results with the C-statistic output, so rerun `stcox` if you need the original model results again.
- Weights from the original `stcox` model are not used in the pairwise C-statistic calculation.
- Delayed entry via `_t0` is not accounted for in pair comparisons.
- Multi-record counting-process survival data are not supported.
- The calculation is pairwise, so very large datasets can take noticeably longer to run.

## Key Stored Results

| Result | Description |
|--------|-------------|
| `e(c)` | Harrell's C-statistic |
| `e(se)` | Infinitesimal-jackknife standard error |
| `e(ci_lo)` | Lower confidence limit |
| `e(ci_hi)` | Upper confidence limit |
| `e(somers_d)` | Somers' D, equal to `2C - 1` |
| `e(N_comparable)` | Number of comparable pairs |

## Version History

- **1.0.0** (2026-04-08): Initial Stata-Tools release

## Author

Timothy P Copeland, Karolinska Institutet
