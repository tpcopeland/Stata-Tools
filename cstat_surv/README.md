# cstat_surv — Harrell's C-statistic after `stcox`

**Version 1.0.1** | 2026-08-05

`cstat_surv` calculates Harrell's C-statistic for a Cox proportional hazards model after `stcox`. It reports the C-statistic, an infinitesimal-jackknife standard error, a confidence interval, and pair counts for survival-model discrimination.

## Quick Start

Run the command immediately after `stcox` on `stset` survival data:

```stata
sysuse cancer, clear
stset studytime, failure(died)
stcox age
cstat_surv
```

Use `cstat_surv, level(90)` when you want a 90% confidence interval.

## Requirements

- Stata 16 or later
- Survival-time data declared with `stset`
- Current Cox model results from `stcox`

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

`cstat_surv` uses the current `stcox` estimates to predict hazard ratios, compares all comparable pairs among valid observations in the estimation sample, and calculates the proportion of pairs in which higher predicted risk corresponds to earlier failure. It computes the standard error with an infinitesimal jackknife and forms a t-based confidence interval at the requested `level()`.

A pair is comparable when the observation with the shorter survival time experienced the event. For tied survival times where both observations experienced events, unequal predicted risks contribute half a concordant and half a discordant pair, while equal predicted risks contribute a tied pair.

The C-statistic ranges from 0 to 1. A value of 0.5 indicates no discrimination, values above 0.7 indicate acceptable discrimination, and values above 0.8 indicate excellent discrimination.

The command posts new `e()` results, replacing the active Cox model results. Rerun `stcox` if you need the original model results again.

## Worked Examples

### 1. Calculate C-statistic after a multivariable Cox model

This complete workflow uses Stata's built-in `cancer` data and reports pair counts with the C-statistic.

```stata
sysuse cancer, clear
stset studytime, failure(died)
stcox age i.drug
cstat_surv
```

### 2. Request a 90% confidence interval

The `level()` option changes the confidence level used for the reported interval.

```stata
sysuse cancer, clear
stset studytime, failure(died)
stcox age i.drug c.age#i.drug
cstat_surv, level(90)
```

### 3. Compare discrimination across two Cox models

Because `cstat_surv` replaces `e()`, fit the second Cox model before calculating its C-statistic.

```stata
sysuse cancer, clear
stset studytime, failure(died)

stcox age
cstat_surv
scalar c_age = e(c)

stcox age i.drug c.age#i.drug
cstat_surv
display "Age-only C = " %6.4f c_age
display "Age + drug + interaction C = " %6.4f e(c)
```

### 4. Read selected stored results

After the command runs, use the stored results for reporting or downstream calculations.

```stata
sysuse cancer, clear
stset studytime, failure(died)
stcox age i.drug
cstat_surv
display "C = " %6.4f e(c)
display "SE = " %6.4f e(se)
display "Comparable pairs = " %8.0fc e(N_comparable)
display "Somers' D = " %6.4f e(somers_d)
```

## Demo

From a checkout of `Stata-Tools`, run `cstat_surv/demo/demo_cstat_surv.do` from the repository root to reproduce console output for a simple model, a more complex model, a custom confidence level, model comparison, and selected stored results. The script writes `cstat_surv/demo/console_output.smcl` and is not part of the `net install` payload.

```stata
do cstat_surv/demo/demo_cstat_surv.do
```

## Command Reference

### `cstat_surv`

```stata
cstat_surv [, level(#)]
```

Run `cstat_surv` immediately after fitting a Cox model with `stcox` on data declared with `stset`.

## Key Options

| Option | Description |
|--------|-------------|
| `level(#)` | Set the confidence level, in percent, for confidence intervals; defaults to Stata's current `c(level)` (95 unless changed with `set level`) |

## Stored Results

`cstat_surv` stores the following results in `e()`:

| Result | Type | Description |
|--------|------|-------------|
| `e(c)` | Scalar | Harrell's C-statistic |
| `e(se)` | Scalar | Infinitesimal-jackknife standard error |
| `e(ci_lo)` | Scalar | Lower confidence limit |
| `e(ci_hi)` | Scalar | Upper confidence limit |
| `e(df_r)` | Scalar | Degrees of freedom |
| `e(somers_d)` | Scalar | Somers' D statistic, equal to `2C - 1` |
| `e(N)` | Scalar | Number of observations |
| `e(N_comparable)` | Scalar | Number of comparable pairs |
| `e(N_concordant)` | Scalar | Number of concordant pairs, fractional with ties |
| `e(N_discordant)` | Scalar | Number of discordant pairs, fractional with ties |
| `e(N_tied)` | Scalar | Number of tied pairs |
| `e(level)` | Scalar | Confidence level |
| `e(cmd)` | Macro | `cstat_surv` |
| `e(depvar)` | Macro | `_t` |
| `e(title)` | Macro | `Harrell's C-statistic` |
| `e(vcetype)` | Macro | `Jackknife` |
| `e(b)` | Matrix | Coefficient vector for the C-statistic |
| `e(V)` | Matrix | Variance-covariance matrix |
| `e(sample)` | Function | Estimation-sample indicator |

## Assumptions and Limits

- The data must be declared with `stset` before the Cox model is fit, and the current estimation results must come from `stcox`.
- The C-statistic uses unweighted pairs even when the original `stcox` model used weights; the command displays a note when weights are detected.
- Delayed entry through `_t0` is not accounted for in pair comparisons.
- Multi-record counting-process data are not supported; the command assumes one record per subject.
- The algorithm compares all pairs of observations and has O(n²) complexity. For datasets with more than 10,000 observations, computation may take several seconds.
- The command exits with an error when no comparable pairs are found.

## References

- Harrell FE Jr, Lee KL, Mark DB. Multivariable prognostic models: issues in developing models, evaluating assumptions and adequacy, and measuring and reducing errors. *Statistics in Medicine*. 1996;15(4):361–387. [doi:10.1002/(SICI)1097-0258(19960229)15:4<361::AID-SIM168>3.0.CO;2-4](https://doi.org/10.1002/%28SICI%291097-0258%2819960229%2915%3A4%3C361%3A%3AAID-SIM168%3E3.0.CO%3B2-4)

## Version History

- **1.0.1** (2026-08-05): Correct the documented default confidence level and clarify the valid estimation sample used for pair comparisons.
- **1.0.0** (2026-07-10): Initial Stata-Tools release

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
