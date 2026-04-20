# cstat_surv

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

Calculate Harrell's C-statistic for Cox proportional hazards models.

## Installation

```stata
capture ado uninstall cstat_surv
net install cstat_surv, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/cstat_surv") replace
help cstat_surv
```

## Requirements

- Stata 16 or newer
- Survival data declared with `stset`
- A Cox model fit with `stcox` in the current session

`cstat_surv` must be run immediately after `stcox`. It reads the active estimation results, predicts the fitted risk score, and then replaces the current `e()` results with the C-statistic output.

## How It Works

`cstat_surv`:

1. checks that the most recent model is `stcox`
2. predicts from that fitted Cox model
3. compares all comparable survival pairs
4. calculates Harrell's C and its standard error via the infinitesimal jackknife

Interpretation is standard:

- `C = 0.5` suggests no discrimination
- `C > 0.7` is often taken as acceptable discrimination
- `C > 0.8` is often taken as strong discrimination

## Worked Example

The built-in `webuse drugtr` dataset is enough to show the full workflow.

```stata
webuse drugtr, clear
stset studytime, failure(died)
stcox age drug
cstat_surv
```

That sequence:

- declares the survival outcome
- fits a Cox model
- reports Harrell's C, its standard error, and the confidence interval

If you want a different confidence level, rerun `stcox` first and then call `cstat_surv` with `level()`:

```stata
webuse drugtr, clear
stset studytime, failure(died)
stcox age drug
cstat_surv, level(90)
```

## Important Behavior and Limitations

- The command uses unweighted pair comparisons even if the original `stcox` model used weights. A note is displayed when weights are detected.
- Delayed entry via `_t0` is not accounted for in pair comparisons.
- Multi-record counting-process survival data are not supported. The command assumes one record per subject.
- The algorithm is pairwise and therefore quadratic in sample size. Very large datasets can take noticeably longer to run.

## Syntax

```stata
cstat_surv [, level(#)]
```

### Option

- `level(#)`: confidence level for the reported interval; default is the current Stata confidence level

## Stored Results

`cstat_surv` posts results to `e()`:

### Scalars

| Result | Description |
| --- | --- |
| `e(c)` | Harrell's C-statistic |
| `e(se)` | Standard error |
| `e(ci_lo)` | Lower confidence limit |
| `e(ci_hi)` | Upper confidence limit |
| `e(df_r)` | Degrees of freedom used for the interval |
| `e(somers_d)` | Somers' D, equal to `2C - 1` |
| `e(N)` | Number of observations used |
| `e(N_comparable)` | Number of comparable pairs |
| `e(N_concordant)` | Number of concordant pairs |
| `e(N_discordant)` | Number of discordant pairs |
| `e(N_tied)` | Number of tied pairs |
| `e(level)` | Confidence level |

### Macros

| Result | Description |
| --- | --- |
| `e(cmd)` | `cstat_surv` |
| `e(depvar)` | `_t` |
| `e(title)` | Harrell's C-statistic |
| `e(vcetype)` | Jackknife |

### Matrices

| Result | Description |
| --- | --- |
| `e(b)` | Coefficient vector containing the C-statistic |
| `e(V)` | Variance matrix |

## Screenshot

![Console Output](demo/console_output.png)

## Version

**Version**: 1.0.0

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT License

## See Also

- `stset`
- `stcox`
