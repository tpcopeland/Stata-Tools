# finegray - Fast Fine-Gray competing risks regression

**Version**: 1.0.0 | 2026-04-06

`finegray` fits the Fine and Gray (1999) subdistribution hazards model for competing risks data. It is written as a native Mata implementation that avoids data expansion, so it stays fast on datasets where `stcrreg` becomes slow or impractical.

The package also includes post-estimation tools for prediction and proportional subdistribution hazards diagnostics. The main workflow is `finegray` for estimation, `finegray_predict` for `xb`, CIF, or Schoenfeld residuals, and `finegray_phtest` for the PH check.

## Requirements

- Stata 16 or later
- Data must be `stset` with `id()`
- The estimation sample must contain one observation per subject

## Installation

```stata
capture ado uninstall finegray
net install finegray, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/finegray") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `finegray` | Fit a Fine-Gray subdistribution hazards model |
| `finegray_predict` | Generate `xb`, CIF, or Schoenfeld residuals after `finegray` |
| `finegray_phtest` | Test the proportional subdistribution hazards assumption |

## How It Works

The workflow has three parts:

1. `stset` the data with one record per subject and an `id()` variable.
2. Fit `finegray` with a `compete()` event-type variable and `cause()` for the event of interest.
3. Use `finegray_predict` or `finegray_phtest` after estimation.

Key points:

- `compete()` should usually be coded as `0 = censored`, `1 = cause 1`, `2 = cause 2`, and so on.
- `cause(#)` selects the event type of interest.
- `finegray_predict, xb` and `finegray_predict, cif` can be used on any dataset that contains the model covariates and a time variable.
- `finegray_predict, schoenfeld` and `finegray_phtest` require the original `stset` estimation data.

## Worked Examples

These examples use Stata's built-in `webuse hypoxia` data because it is a natural competing-risks dataset for the package.

### 1. Fit the basic Fine-Gray model

`failtype` in the `hypoxia` data identifies competing event types. After creating a clean event-type variable, `finegray` estimates the subdistribution hazard ratio for cause 1.

```stata
webuse hypoxia, clear
gen byte status = failtype
stset dftime, failure(dfcens==1) id(stnum)

finegray ifp tumsize pelnode, compete(status) cause(1)
```

This is the canonical starting point. By default, the command reports exponentiated subdistribution hazard ratios with sandwich standard errors.

### 2. Predict cumulative incidence after estimation

Use `finegray_predict, cif` when you want the fitted cumulative incidence at each observation's time or at an explicitly supplied time variable.

```stata
webuse hypoxia, clear
gen byte status = failtype
stset dftime, failure(dfcens==1) id(stnum)
finegray ifp tumsize pelnode, compete(status) cause(1)

finegray_predict cif_hat, cif
gen double t5 = 5
finegray_predict cif_at5, cif timevar(t5)
```

`cif_hat` uses each subject's current `_t`. `cif_at5` instead asks for the fitted CIF at time 5 for every observation.

### 3. Run the PH diagnostic

`finegray_phtest` is the post-estimation check for time-varying effects. It uses scaled Schoenfeld residuals and therefore must be run on the original estimation data.

```stata
webuse hypoxia, clear
gen byte status = failtype
stset dftime, failure(dfcens==1) id(stnum)
finegray ifp tumsize pelnode, compete(status) cause(1)

finegray_phtest
finegray_phtest, time(log)
```

Use the default rank-based test first. `time(log)` is often a sensible sensitivity check.

### 4. Common model variations

The package supports factor variables, stratified censoring distributions, cluster-robust inference, and model-based standard errors.

```stata
webuse hypoxia, clear
gen byte status = failtype
stset dftime, failure(dfcens==1) id(stnum)

finegray i.pelnode##c.ifp tumsize, compete(status) cause(1)
finegray ifp tumsize, compete(status) cause(1) strata(pelnode)
finegray ifp tumsize pelnode, compete(status) cause(1) norobust
finegray ifp tumsize pelnode, compete(status) cause(1) noshr
```

`norobust` switches from the default sandwich variance to the observed-information variance. `noshr` reports log-SHR coefficients instead of exponentiated SHRs.

## Features

- Native forward-backward scan implementation without data expansion
- Support for factor variables and interactions
- Stratified censoring distributions via `strata()`
- Robust or model-based standard errors
- CIF prediction on the estimation data or at user-supplied times
- Approximate proportional subdistribution hazards test after estimation

## Validation

The package QA cross-validates `finegray` against Stata's `stcrreg` and independent R implementations of Fine-Gray regression. The validation files live under `qa/` and cover coefficients, standard errors, log-likelihoods, CIF predictions, baseline hazards, and stratified censoring behavior.

## References

- Fine JP, Gray RJ. A proportional hazards model for the subdistribution of a competing risk. *Journal of the American Statistical Association*. 1999;94(446):496-509.
- Grambsch PM, Therneau TM. Proportional hazards tests and diagnostics based on weighted residuals. *Biometrika*. 1994;81(3):515-526.
- Kawaguchi ES, Shen JI, Suchard MA, Li G. Scalable algorithms for large competing risks data. *Journal of Computational and Graphical Statistics*. 2021;30(3):685-693.

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
