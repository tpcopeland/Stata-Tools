# finegray

Fine-Gray competing risks regression for Stata. Version 1.0.0.

## Overview

`finegray` fits the Fine and Gray (1999) subdistribution hazard model for competing risks data. It estimates subdistribution hazard ratios (SHR) that quantify the effect of covariates on the cumulative incidence of a cause of interest in the presence of competing events.

The estimator uses a native Mata forward-backward scan algorithm (Kawaguchi et al. 2021) that avoids data expansion entirely, producing identical point estimates and log-likelihoods to Stata's `stcrreg` and R's `cmprsk::crr` while running orders of magnitude faster.

## Installation

```stata
cap ado uninstall finegray
net install finegray, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/finegray") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `finegray` | Fine-Gray subdistribution hazard regression |
| `finegray_predict` | Post-estimation predictions (linear predictor, CIF, Schoenfeld residuals) |
| `finegray_phtest` | Test proportional subdistribution hazards assumption |

## Quick start

```stata
* Load competing risks data
webuse hypoxia, clear
gen byte status = failtype
stset dftime, failure(dfcens==1) id(stnum)

* Fit Fine-Gray model for cause 1
finegray ifp tumsize pelnode, compete(status) cause(1)

* Predict cumulative incidence
finegray_predict cif_hat, cif

* Test proportional hazards assumption
finegray_phtest
```

## Syntax

```
finegray varlist [if] [in], compete(varname) cause(#) [options]
```

`varlist` may contain factor variables and interactions (`i.varname`, `ib#.varname`, `c.varname`, `#`, `##`).

### Required options

| Option | Description |
|--------|-------------|
| `compete(varname)` | Event type variable (0=censored, 1=cause 1, 2=cause 2, ...) |
| `cause(#)` | Value of `compete()` for the cause of interest |

### Model options

| Option | Description |
|--------|-------------|
| `censvalue(#)` | Censoring value in `compete()`; default 0 |
| `strata(varlist)` | Stratify censoring distribution by groups (numeric only) |

### SE/Robust options

| Option | Description |
|--------|-------------|
| `cluster(numvar)` | Clustered standard errors (numeric only) |
| `norobust` | Model-based SEs instead of default sandwich estimator |

### Reporting options

| Option | Description |
|--------|-------------|
| `noshr` | Report log subdistribution hazard ratios instead of SHR |
| `level(#)` | Confidence level; default 95 |
| `nolog` | Suppress iteration log |

### Optimization options

| Option | Description |
|--------|-------------|
| `iterate(#)` | Maximum iterations; default 200 |
| `tolerance(#)` | Convergence tolerance; default 1e-8 |

## Post-estimation

### Predictions

```
finegray_predict newvar [if] [in], [cif xb schoenfeld timevar(varname)]
```

| Option | Description |
|--------|-------------|
| `xb` | Linear predictor z'beta (default) |
| `cif` | Cumulative incidence function: 1 - exp(-H0(t) * exp(z'beta)) |
| `schoenfeld` | Schoenfeld residuals at cause-event times |
| `timevar(varname)` | Use specified variable for time instead of `_t` |

`xb` predictions work on any dataset containing the model covariates. `schoenfeld` residuals require the original `stset` estimation data.

### Proportional hazards test

```
finegray_phtest [, time(function) detail]
```

| Option | Description |
|--------|-------------|
| `time(function)` | Time function: `rank` (default), `log`, or `identity` |
| `detail` | Display scaled Schoenfeld residuals |

Tests the PSH assumption by correlating scaled Schoenfeld residuals with a function of time. Requires the original estimation data.

### Margins

```stata
finegray ifp tumsize pelnode, compete(status) cause(1)
margins, at(ifp=(0 5 10)) predict(xb)
```

## Data requirements

- Data must be `stset` with the `id()` option
- One observation per subject (no multiple-record data)
- Left-truncated (delayed entry) data are supported via `stset ... enter()`
- The `compete()` variable must be consistent with the `stset` failure indicator

## Features

- **Factor variables**: full support for `i.`, `c.`, `#`, and `##` operators
- **Stratified censoring**: group-specific Kaplan-Meier via `strata()`
- **Clustered SEs**: sandwich variance with `cluster()`
- **Model-based SEs**: observed-information variance via `norobust`
- **Left truncation**: delayed entry via `stset ... enter()`
- **CIF prediction**: individual-level cumulative incidence at any time point
- **PH diagnostics**: Schoenfeld residual-based test via `finegray_phtest`
- **Margins compatible**: works with `margins` for adjusted predictions

## Performance

Benchmarks on simulated competing risks data (3 covariates, Stata/MP):

| N | finegray | stcrreg | Speedup |
|---|----------|---------|---------|
| 500 | 0.04s | 1.5s | 40x |
| 1,000 | 0.06s | 3.9s | 63x |
| 2,000 | 0.14s | 15.9s | 114x |
| 5,000 | 0.27s | 96.8s | 357x |
| 10,000 | 0.58s | 378.7s | 651x |

The speedup grows with sample size because `finegray` is O(np) per iteration while `stcrreg` is O(nDp), where D is the number of unique event times.

## Cross-validation

`finegray` is systematically cross-validated against three independent implementations: Stata's `stcrreg`, R's `cmprsk::crr`, and R's `fastcmprsk::fastCrr`. The cross-validation suite (`qa/crossval_finegray.do` + `qa/crossval_finegray_r.R`) runs 55 tests covering coefficients, standard errors, log-likelihoods, cumulative incidence functions, baseline hazards, and stratified censoring.

### Point estimates and log-likelihoods

Coefficients and log pseudo-likelihoods are numerically identical across all four implementations. Three-way comparison confirms agreement within 1e-6 on the hypoxia dataset.

### Standard errors

| Comparison | Agreement | Notes |
|------------|-----------|-------|
| `finegray` vs `cmprsk::crr` (robust) | Exact to 3+ decimal places | Both use IPCW sandwich on unexpanded data |
| `finegray norobust` vs `crr$invinf` (model-based) | Exact to 6 decimal places | Both report inverse observed information |
| `finegray` vs `stcrreg` (robust) | ~0.5% relative difference | Different computational paths (unexpanded vs expanded data) |
| `finegray` vs `fastcmprsk::fastCrr` (bootstrap) | Up to ~50% difference | Expected: bootstrap SEs (B=200) vs analytic sandwich |

### CIF and baseline hazard

CIF at z=0 agrees to 6 decimal places with `cmprsk` and `fastcmprsk`. Baseline cumulative hazard agrees to 8 decimal places with `fastcmprsk`.

### Stratified models

`finegray strata()` vs `cmprsk::crr cengroup`: coefficients within 0.002, SEs within 0.3%, log-likelihood within 0.07%, CIF within 0.001. Differences reflect independent KM implementations for the censoring distribution.

### Cluster and left-truncation SEs

Cluster SEs: exact coefficients, ~0.7% SE difference (tested with 80-100 clusters). Left-truncation SEs: exact coefficients, ~1.3% SE difference (tested with ~40% delayed entry).

## Stored results

`finegray` stores results in `e()`:

**Scalars**: `e(N)`, `e(N_fail)`, `e(N_compete)`, `e(N_cens)`, `e(ll)`, `e(ll_0)`, `e(chi2)`, `e(p)`, `e(df_m)`, `e(converged)`, `e(level)`, `e(cause)`, `e(censvalue)`, `e(iterate)`, `e(tolerance)`

**Macros**: `e(cmd)`, `e(cmdline)`, `e(predict)`, `e(depvar)`, `e(compete)`, `e(covariates)`, `e(fvvarlist)`, `e(strata)`, `e(clustvar)`, `e(vce)`, `e(title)`, `e(marginsok)`, `e(properties)`

**Matrices**: `e(b)`, `e(V)`, `e(basehaz)`

See `help finegray` for full details.

## Examples

```stata
* Log subdistribution hazard ratios (no exponentiation)
finegray ifp tumsize pelnode, compete(status) cause(1) noshr

* Factor variables with automatic indicator expansion
finegray i.pelnode ifp tumsize, compete(status) cause(1)

* Factor x continuous interaction
finegray i.pelnode##c.ifp tumsize, compete(status) cause(1)

* Factor x factor interaction
gen byte ifp_grp = (ifp > 10)
finegray i.pelnode##i.ifp_grp tumsize, compete(status) cause(1)

* Stratified censoring distribution
finegray ifp tumsize, compete(status) cause(1) strata(pelnode)

* Model-based standard errors
finegray ifp tumsize pelnode, compete(status) cause(1) norobust

* CIF at a specific time point
finegray ifp tumsize pelnode, compete(status) cause(1)
gen double mytime = 5
finegray_predict cif_at5, cif timevar(mytime)

* PH test with log time function
finegray ifp tumsize pelnode, compete(status) cause(1)
finegray_phtest, time(log)
```

## Requirements

- Stata 16+

## References

Fine JP, Gray RJ. A proportional hazards model for the subdistribution of a competing risk. *JASA* 1999; 94(446): 496-509.

Kawaguchi ES, Shen JI, Suchard MA, Li G. Scalable algorithms for large competing risks data. *Journal of Computational and Graphical Statistics* 2021; 30(3): 685-693.

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT

## Version history

### 1.0.0 (2026-04-06)

- Initial release
