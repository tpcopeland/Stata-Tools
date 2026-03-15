# aft

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

Accelerated Failure Time model selection, diagnostics, piecewise modeling, and treatment switching adjustment for Stata.

## Description

Accelerated failure time (AFT) models express covariate effects as **time ratios** (TR) -- multiplicative changes in survival time. A TR of 1.4 means the covariate is associated with 40% longer survival. This is often more clinically intuitive than the hazard ratios produced by Cox models.

`aft` automates the full AFT workflow: distribution comparison, model fitting, diagnostic assessment, Cox PH benchmarking, piecewise AFT for time-varying effects, and RPSFTM g-estimation for treatment switching adjustment in randomized trials.

**Supported distributions:** exponential, Weibull, lognormal, log-logistic, generalized gamma.

## Commands

| Command | Description |
|---------|-------------|
| `aft` | Package overview and workflow guide |
| `aft_select` | Compare up to 5 AFT distributions via AIC/BIC and nested LR tests; recommend best fit |
| `aft_fit` | Fit AFT model with selected (or manual) distribution; display time ratios |
| `aft_diagnose` | Cox-Snell residuals, Q-Q plots, KM overlay, distribution-specific diagnostics, GOF statistics |
| `aft_compare` | Side-by-side Cox PH (HR) vs AFT (TR) comparison with Schoenfeld PH test |
| `aft_split` | Piecewise AFT: split episodes at time cutpoints or quantiles and fit per-interval models |
| `aft_pool` | Inverse-variance weighted pooling of piecewise estimates (fixed or DerSimonian-Laird random effects) with heterogeneity statistics and forest plots |
| `aft_rpsftm` | Rank-Preserving Structural Failure Time Model (RPSFTM) g-estimation for treatment switching in RCTs |
| `aft_counterfactual` | Counterfactual survival curves and RMST comparisons from RPSFTM |

## Installation

```stata
net install aft, from("https://raw.githubusercontent.com/tpcopeland/Stata-Dev/main/aft")
```

## Quick Start

```stata
sysuse cancer, clear
stset studytime, failure(died)

* Compare distributions and pick the best fit
aft_select drug age

* Fit the recommended AFT model
aft_fit drug age

* Diagnostic plots and GOF statistics
aft_diagnose, all

* Side-by-side Cox vs AFT comparison
aft_compare drug age
```

## Workflows

### Core AFT workflow

1. **`stset`** your survival data
2. **`aft_select`** fits all 5 distributions, computes AIC/BIC, runs LR tests for nested models within the generalized gamma family, and recommends the best fit
3. **`aft_fit`** fits the AFT model using the recommendation from `aft_select` (or a manual override). Results display as time ratios by default
4. **`aft_diagnose`** assesses model adequacy with Cox-Snell residuals, Q-Q plots, KM overlays, distribution-specific diagnostics, and GOF statistics
5. **`aft_compare`** fits both Cox PH and AFT on the same covariates, displays HR vs TR side-by-side, and runs the Schoenfeld test to check the PH assumption

### Piecewise AFT (time-varying effects)

When the constant time ratio assumption is violated, split the timeline into intervals and allow effects to vary:

```stata
* Split at fixed time points and fit per-interval models
aft_split drug age, cutpoints(10 20)

* Or use quantile-based splitting
aft_split drug age, quantiles(3) distribution(weibull)

* Pool per-interval estimates with a forest plot
aft_pool, method(random) plot
```

`aft_pool` reports Cochran's Q and I-squared heterogeneity statistics for each covariate. High I-squared (>50%) suggests the time ratio varies meaningfully across intervals.

### Treatment switching adjustment (RPSFTM)

In RCTs where control-arm patients cross over to the experimental treatment, intention-to-treat analysis underestimates the true treatment effect. The RPSFTM finds the acceleration factor psi such that counterfactual untreated survival times are independent of randomization:

```stata
* G-estimation with re-censoring
aft_rpsftm, randomization(arm) treatment(treated) recensor

* Visualize counterfactual survival curves
aft_counterfactual, plot

* RMST comparison at specific time horizons
aft_counterfactual, table timehorizons(12 24 36)
```

The method performs a grid search over candidate psi values, computing counterfactual times as U = T * exp(-psi * d) where d is the proportion of time on treatment. A log-rank (or Wilcoxon) test is evaluated at each grid point, and the zero-crossing is the point estimate. Confidence intervals are obtained by inverting the test. Bootstrap standard errors are available via the `bootstrap` option.

## Key Features

- **Automated distribution selection** with AIC/BIC ranking and nested LR tests within the generalized gamma family
- **Graceful convergence handling**: flags non-converging distributions and continues
- **Pipeline integration**: commands pass settings via dataset characteristics -- `aft_fit` reads from `aft_select`, `aft_pool` reads from `aft_split`, `aft_counterfactual` reads from `aft_rpsftm`
- **PH assumption testing**: `aft_compare` runs the Schoenfeld test and flags violations
- **Forest plots** for piecewise AFT with heterogeneity statistics
- **Re-censoring** to prevent informative censoring in RPSFTM counterfactuals
- **Full streg passthrough**: strata, frailty, shared frailty, VCE, and ancillary covariates are supported across all fitting commands

## Stored Results

All commands store results in `r()` or `e()`. Key examples:

| Command | Result | Contents |
|---------|--------|----------|
| `aft_select` | `r(best_dist)` | Recommended distribution |
| `aft_select` | `r(table)` | Comparison matrix (ll, k, AIC, BIC) |
| `aft_fit` | `e()` | Full `streg` estimation results |
| `aft_diagnose` | `r(aic)`, `r(bic)` | Goodness-of-fit statistics |
| `aft_compare` | `r(ph_global_p)` | Schoenfeld PH test p-value |
| `aft_compare` | `r(comparison)` | HR vs TR matrix |
| `aft_split` | `r(coefs)`, `r(ses)` | Per-interval coefficient and SE matrices |
| `aft_pool` | `r(pooled)` | Pooled TR, SE, CI, p-value per covariate |
| `aft_pool` | `r(heterogeneity)` | Q, Q_p, I-squared per covariate |
| `aft_rpsftm` | `e(psi)`, `e(af)` | Acceleration factor (log and exp scale) |
| `aft_counterfactual` | `r(rmst)` | RMST values by arm and time horizon |

## Requirements

- Stata 16.0 or higher

## Version

- **1.1.0** (15 March 2026): Add piecewise AFT (`aft_split`, `aft_pool`) and RPSFTM g-estimation (`aft_rpsftm`, `aft_counterfactual`)
- **1.0.0** (14 March 2026): Initial release with `aft_select`, `aft_fit`, `aft_diagnose`, `aft_compare`

## References

- White IR, Babiker AG, Walker S, Darbyshire JH. Randomization-based methods for correcting for treatment changes: examples from the Concorde trial. *Statistics in Medicine* 1999;18:2617-2634.

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## See Also

- `help streg` -- Stata's parametric survival models
- `help stcox` -- Cox proportional hazards model
- `help stsplit` -- Episode splitting
