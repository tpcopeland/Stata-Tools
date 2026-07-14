# finegray - Fast Fine-Gray competing risks regression

**Version 1.1.4** | 2026-07-10

`finegray` fits the Fine and Gray (1999) subdistribution hazards model for competing risks data. It uses a native Mata forward-backward scan implementation that avoids data expansion, so it remains practical on datasets where `stcrreg` becomes slow or infeasible.

The package also includes post-estimation tools for prediction, cumulative incidence curves, and proportional subdistribution hazards diagnostics. The intended workflow is `finegray` for estimation, `finegray_predict` for `xb`, CIF, or Schoenfeld residuals, `finegray_cif` for cumulative incidence curves and fixed-horizon CIF with confidence intervals, and `finegray_phtest` for the proportional hazards check.

## Quick Start

```stata
webuse hypoxia, clear
gen byte status = failtype
stset dftime, failure(dfcens==1) id(stnum)

finegray ifp tumsize pelnode, compete(status) cause(1)
finegray_cif, attime(1 5 8) ci
finegray_phtest
```

## Requirements

- Stata 16 or later
- Data must be `stset` with `id()`
- Datasets with multiple records per subject (delayed entry, `(start,stop]` intervals, `stsplit`) are supported automatically when covariates are constant within subject; genuinely time-varying covariates are not (the subdistribution hazard is undefined with them)

## Installation

```stata
capture ado uninstall finegray
net install finegray, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/finegray") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `finegray` | Fit a Fine-Gray subdistribution hazards model |
| `finegray_predict` | Generate `xb`, CIF (with optional CI), or Schoenfeld residuals after `finegray` |
| `finegray_cif` | Plot cumulative incidence curves with confidence bands; report fixed-horizon CIF with CI |
| `finegray_phtest` | Test the proportional subdistribution hazards assumption |

## Options

| Option | Command | Purpose and default |
|--------|---------|---------------------|
| `compete()` | `finegray` | Required event-type variable |
| `cause()` | `finegray` | Required cause-of-interest value |
| `censvalue()` | `finegray` | Censoring value; default `0` |
| `strata()` | `finegray` | Stratify the censoring distribution |
| `cluster()` | `finegray` | Cluster-robust inference; requires more clusters than coefficients |
| `robust` / `norobust` | `finegray` | Sandwich variance is the default; `norobust` selects the observed-information variance, which is **not valid for inference** under a pseudo-likelihood |
| `adjust` / `noadjust` | `finegray` | The finite-sample adjustment to the sandwich (`N/(N-1)`, or `g/(g-1)` with `cluster()`) is the default, matching `stcrreg`; `noadjust` omits it |
| `shr` / `noshr` | `finegray` | SHRs are the default; `noshr` reports log-SHR coefficients |
| `level()` | `finegray` | Confidence level; default `c(level)` |
| `log` / `nolog` | `finegray` | Iteration logging is the default; `nolog` suppresses it |
| `iterate()` | `finegray` | Maximum Newton-Raphson iterations; default `200` |
| `tolerance()` | `finegray` | Convergence tolerance; default `1e-8` |
| `xb`, `cif`, `schoenfeld` | `finegray_predict` | Select the prediction type; default `xb` |
| `timevar()` | `finegray_predict` | Evaluate CIF predictions at a supplied time variable |
| `ci`, `level()` | `finegray_predict` | Add CIF confidence limits at the requested level |
| `bootstrap()`, `seed()` | `finegray_predict` | Use reproducible subject- or cluster-bootstrap CIF limits |
| `at()` | `finegray_cif` | Set the covariate profile; unspecified terms use estimation-sample means |
| `attime()` | `finegray_cif` | Report fixed-horizon CIF estimates |
| `timepoints()` | `finegray_cif` | Evaluate the curve on a custom time grid |
| `ci`, `level()` | `finegray_cif` | Add a pointwise confidence band at the requested level |
| `saving()` | `finegray_cif` | Save `time`, `cif`, `se`, `lci`, and `uci` |
| `bootstrap()`, `seed()` | `finegray_cif` | Use a reproducible subject or cluster bootstrap |
| `nograph` | `finegray_cif` | Suppress graph creation |
| `time()` | `finegray_phtest` | Select `rank`, `log`, or `identity`; default `rank` |
| `detail` | `finegray_phtest` | Display the first 20 scaled-Schoenfeld rows |

## Stored Results

`finegray` is an e-class estimation command. Its package-specific contract is:

Core estimation quantities include `e(N)`, `e(N_fail)`, `e(N_compete)`, `e(N_cens)`, `e(b)`, and `e(V)`.

| Result | Contents |
|--------|----------|
| `e(N)` | Number of subjects |
| `e(N_fail)` | Number of cause-of-interest events |
| `e(N_compete)` | Number of competing events |
| `e(N_cens)` | Number censored |
| `e(ll)`, `e(ll_0)` | Log pseudo-likelihood at the fitted `b` and at `b = 0` (the null model) |
| `e(chi2)`, `e(p)`, `e(df_m)` | Wald model test; `e(df_m)` is the numerical rank of `e(V)` |
| `e(rank)` | Rank of `e(V)` |
| `e(N_clust)` | Number of clusters (only with `cluster()`) |
| `e(converged)` | 1 if converged, 0 otherwise. A nonconverged fit is reported rather than refused (matching `stcrreg`), so `e(b)` holds the last iterate, not a solution — `finegray_predict`, `finegray_cif`, and `finegray_phtest` all exit `r(430)` rather than consume it |
| `e(level)` | Confidence level |
| `e(cause)`, `e(censvalue)` | Event coding used by the fit |
| `e(iterate)`, `e(tolerance)` | Optimization controls |
| `e(cmd)`, `e(cmdline)`, `e(predict)` | Command metadata |
| `e(refitcmd)` | Estimation command without `if`/`in`, replayed by the `bootstrap()` refits |
| `e(depvar)`, `e(compete)` | Event-type variable |
| `e(covariates)`, `e(fvvarlist)` | Expanded covariates and original factor-variable specification |
| `e(strata)`, `e(clustvar)`, `e(vce)` | Variance and censoring-strata metadata |
| `e(title)`, `e(marginsok)`, `e(properties)` | Estimation-command metadata |
| `e(datasignature)`, `e(datasignaturevars)` | Original-data signature used by data-dependent post-estimation |
| `e(sample)` | Estimation-sample indicator |
| `e(b)`, `e(V)` | Coefficient vector and variance-covariance matrix |
| `e(basehaz)` | Baseline cumulative subdistribution hazard by event time — **only when `basehaz` is specified** (see below) |

**`e(basehaz)` is opt-in.** It holds one row per distinct cause-event time, so it has roughly N/2 rows, and creating a Stata matrix that tall is O(rows²) — Stata builds one dimension name per row, and the cost is per name, not per element. At N = 200,000 that single matrix cost 38 s, more than the entire model fit, and it was the only reason `finegray`'s runtime was superlinear (log-log slope 1.65 with it, 1.06 without; 95.0 s → 18.7 s at N = 200,000). Nothing needs it: `finegray_cif` and `finegray_predict` rebuild the same curve in Mata, and `predict, basecshazard` returns the baseline as a variable at O(N) — the same idiom `stcrreg` uses, since `stcrreg` posts no baseline matrix in `e()` either. Specify `basehaz` when you want the matrix itself.

`finegray_cif` stores `r(table)`, `r(at)`, `r(level)`, `r(cause)`, and `r(profile_vars)`. With `bootstrap()`, it also stores `r(bootstrap_requested)`, `r(bootstrap_success)`, and `r(bootstrap_failed)`. `finegray_phtest` stores `r(chi2)`, `r(df)`, `r(p)`, `r(N_fail)`, `r(time)`, and `r(phtest)`. `finegray_predict` creates variables and intentionally clears `r()`.

## How It Works

The workflow has three parts:

1. `stset` the data with an `id()` variable. One or multiple contiguous records
   per subject are supported when covariates are constant within subject.
2. Fit `finegray` with a `compete()` event-type variable and `cause()` for the event of interest.
3. Use `finegray_predict` or `finegray_phtest` after estimation.

Operational details that matter:

- `compete()` is usually coded as `0 = censored`, `1 = cause 1`, `2 = cause 2`, and so on
- `cause(#)` selects the event type of interest
- `finegray_predict, xb` can be used on datasets that contain the model covariates
- `finegray_predict, cif` additionally requires a time variable (`_t` or `timevar()`)
- `finegray_predict, schoenfeld` and `finegray_phtest` require the original `stset` estimation data
- `finegray_predict` reproduces `stcrreg`'s post-estimation quantities: `xb` matches `predict, xb`, the baseline CIF matches `predict, basecif`, and `e(basehaz)` is the cumulative-subhazard analogue (`H0 = -ln(1 - basecif)`). The per-observation `cif` is the covariate-adjusted CIF, which `stcrreg` produces via `stcurve, cif at()` rather than `predict`; `finegray_predict, cif` matches it to numerical precision. Schoenfeld residuals match `stcrreg` exactly at untied event times; at tied event times the per-event split differs by convention while the per-time total is identical (see below)
- Factor-variable models are supported, but prediction on new data still requires the same factor-level support as the estimation sample
- Data-dependent post-estimation commands verify that the original estimation sample has not changed; re-run `finegray` after editing model data
- Constant or exactly collinear covariate columns are rejected explicitly rather than silently ridge-regularized

## Worked Examples

These examples use Stata's built-in `webuse hypoxia` data because it is a natural competing-risks dataset for the package.

### 1. Fit the basic Fine-Gray model

`failtype` identifies competing event types. After creating a clean event-type variable, `finegray` estimates the subdistribution hazard ratio for cause 1.

```stata
webuse hypoxia, clear
gen byte status = failtype
stset dftime, failure(dfcens==1) id(stnum)

finegray ifp tumsize pelnode, compete(status) cause(1)
```

This is the canonical starting point. By default, the command reports exponentiated subdistribution hazard ratios with sandwich standard errors.

### 2. Predict cumulative incidence after estimation

Use `finegray_predict, cif` when you want the fitted cumulative incidence at each observation's event time or at an explicitly supplied time variable.

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

### 3. Run the proportional hazards diagnostic

`finegray_phtest` is the post-estimation check for time-varying effects. It uses scaled Schoenfeld residuals and therefore must be run on the original estimation data.

```stata
webuse hypoxia, clear
gen byte status = failtype
stset dftime, failure(dfcens==1) id(stnum)
finegray ifp tumsize pelnode, compete(status) cause(1)

finegray_phtest
finegray_phtest, time(log)
```

Use the default rank-based test first. `time(log)` is a sensible sensitivity check when you suspect departures later in follow-up.

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

`noshr` reports log-SHR coefficients instead of exponentiated SHRs.

`norobust` switches from the default sandwich variance to the observed-information variance. **These standard errors are not valid for inference.** The Fine-Gray objective is a pseudo-likelihood — the inverse-probability-of-censoring weights make subjects' contributions dependent — so the inverse information matrix does not estimate the sampling variance of the coefficients. They are generally too small, and their confidence intervals do not have nominal coverage. `norobust` exists so the naive likelihood variance can be inspected and compared against the sandwich; `finegray` prints a warning whenever it is used.

The default sandwich treats the estimated censoring weights as fixed: it does not propagate the uncertainty in the estimated censoring distribution G(t). This is the same variance `stcrreg` reports. Against `cmprsk::crr`, which does include that nuisance term, `finegray`'s standard errors are smaller by roughly 0.2% in relative terms; coefficients are unaffected. Where that matters, `bootstrap()` in `finegray_cif` and `finegray_predict` re-estimates G(t) in every replication and so captures the censoring-weight uncertainty exactly.

### 5. Cumulative incidence curves and fixed-horizon CIF

`finegray_cif` draws the predicted CIF with a pointwise confidence band (an analogue of `stcurve, cif` that can also plot the interval) and reports the CIF at specific horizons. `finegray_predict, cif ci` adds per-subject confidence limits.

```stata
webuse hypoxia, clear
gen byte status = failtype
stset dftime, failure(dfcens==1) id(stnum)
finegray ifp tumsize pelnode, compete(status) cause(1)

finegray_cif, ci                                   // curve at covariate means, 95% band
finegray_cif, at(pelnode=1 ifp=20) ci              // curve for a covariate profile
finegray_cif, attime(1 5 8) ci                     // CIF at 1, 5, 8 years with CI
finegray_cif, ci nograph saving(cifcurve.dta)      // export the numeric estimates

gen double t5 = 5
finegray_predict cif5, cif timevar(t5) ci          // per-subject 5-year CIF + cif5_lci/cif5_uci
```

## Demonstration

The comprehensive demo script (`finegray/demo/demo_finegray.do`) installs the local package, exercises every public command and all 1.1.x workflows, verifies exported CIF data, and refreshes the graph below. Run it from the Stata-Tools repository root with `stata-mp -b do finegray/demo/demo_finegray.do`.

### Cumulative-incidence graph

The graph uses the package default profile, an analytic 95% pointwise confidence band, the `plotplainblind` scheme, and the required bottom legend position.

![Fine-Gray cumulative incidence with 95% band](demo/finegray_cif.png)

## Features

- Native forward-backward scan implementation without data expansion
- Automatic reduction of multiple-record (delayed entry / `stsplit`) data with subject-constant covariates
- Support for factor variables and interactions
- Stratified censoring distributions via `strata()`, stratified entry distributions via `truncstrata()`
- Robust, clustered, or model-based standard errors
- CIF prediction on estimation data or at user-supplied times, with confidence intervals
- Cumulative incidence curves with confidence bands and exportable estimates (`finegray_cif`)
- Approximate proportional subdistribution hazards test after estimation
- Left truncation (delayed entry) via the stabilized Zhang–Zhang–Fine Weight 1 estimator, computed without expanding the data — see below

## Left truncation (delayed entry)

**Under delayed entry `finegray` deliberately does not agree with `stcrreg`.** This is the package's main statistical contribution, and it is worth understanding before you use it.

A Fine–Gray weight built from the censoring distribution alone is not a valid weight for left-truncated data: if nothing is censored it collapses to a constant, which cannot correct anything. Zhang, Zhang & Fine (2011) show that the resulting estimator is biased and that the bias does **not** shrink as the sample grows. `stcrreg` uses that censoring-only weight, and so did `finegray` before this release.

`finegray` now targets the **stabilized Zhang–Zhang–Fine Weight 1** estimator. Writing `A(t)` for the probability of being under observation at `t`, a subject retained in the risk set after a competing event at `X_i` carries weight `A(t−)/A(X_i−)` instead of the censoring-only ratio `G(t−)/G(X_i−)`. `A` is computed as the product of the delayed-entry-aware censoring survivor `G` and a reverse-time product-limit estimator `H` of the entry distribution (Geskus 2011), which was verified to reproduce the canonical ZZF form to machine precision on every tied-time collision class before it was shipped.

The weight is **separable** — it factors into a function of time times a function of the subject — which is exactly the property that lets the forward–backward scan compute it **without expanding the data**. Reference implementations (`survival::finegray`, `mstate::crprep`) deliver the same weighting by emitting one row per weight change, expanding a 500-subject delayed-entry dataset by 17× and 27× respectively.

**What this means for you:**

| | |
|---|---|
| **Delayed-entry results change** | Coefficients, SEs, baseline hazards, predictions and CIFs all move relative to earlier `finegray` versions and relative to `stcrreg`. That is the fix, not a regression. |
| **No-delayed-entry results do not change** | With every subject entering at the origin, `H ≡ 1`, `A` collapses to `G`, and the estimator is bit-for-bit the existing right-censoring path. |
| **Pooled weights assume covariate-independent entry** | If entry depends on an observed discrete group, name it in `truncstrata()`. If censoring does, name it in `strata()`. The two are cross-classified internally. |
| **Continuous covariate-dependent entry is not supported** | It is rejected, not silently approximated: a continuously subject-specific weight destroys the shared time factor the scan depends on. |
| **Breaking change** | Under delayed entry, `A` is estimated per joint weight stratum, so every `strata()` level is also a weight stratum *even without* `truncstrata()`. At most 100 joint strata (≥20 subjects each) are supported. A delayed-entry model with many `strata()` levels that fitted in 1.1.4 may now stop with `r(459)` rather than silently pooling groups. The same model still fits without delayed entry. |

`e(lt_weight)` reports which weight was actually used (`zzf1_geskus` or `right_censoring`) and `e(lt_vce)` which variance, so no consumer has to infer either from the option list. Weight diagnostics are stored in `e(N_weight_strata)`, `e(min_weight_prob)`, `e(max_lt_weight)`, `e(N_prob_warn)`, `e(N_weight_warn)` and `e(weight_warn_strata)`. Unlike censoring-only weights, ZZF weights may legitimately exceed 1.

## Validation

The package QA cross-validates `finegray` against Stata's `stcrreg` and independent R implementations of Fine-Gray regression (`cmprsk`, `riskRegression`). The validation files under `qa/` cover coefficients, standard errors, log pseudo-likelihoods, CIF predictions (point estimates bit-exact against `riskRegression`), CIF confidence intervals (validated against a subject bootstrap), baseline hazards, multiple-record reduction, and stratified censoring behavior.

The suite is driven by `qa/run_all.do` (`quick`, `core`, `python`, and `full` lanes) and documented in `qa/README.md`. The `qa/` directory contains 15 package QA files: 5 functional/regression files, 6 validation files, and 4 cross-validation files covering all four public commands. The current static inventory contains 619 checks across those suites, including the dedicated `test_finegray_v114.do` bootstrap/parsing regression file.

`qa/crossval_predict_stcrreg.do` cross-validates every `finegray_predict` path directly against `stcrreg`'s native post-estimation predictions (no external dependency, so it never skips): `xb`, the relative subhazard `exp(xb)`, the covariate-adjusted CIF, the baseline CIF (`basecif`), the baseline cumulative subhazard (`e(basehaz)`), Schoenfeld residuals, and the subhazard ratios with their standard errors and 95% confidence intervals. All agree to numerical precision, with one documented and asserted exception:

- **Schoenfeld residuals at tied event times.** At an event time shared by two or more cause events, `finegray` and `stcrreg` partition the residual among the simultaneous events using different conventions, so an individual residual at a tied time can differ. The QA suite asserts that (a) residuals match `stcrreg` exactly at untied event times and (b) the sum of the residuals within each event time — and hence the overall score, which is zero at the estimate — is identical. Only the per-observation values at tied times differ; untied times, per-time totals, and every event-time aggregate are unaffected.

Standard errors are robust (sandwich) by default in both commands and agree to within 1e-3 relative. `finegray` applies the same finite-sample adjustment as `stcrreg` (`N/(N-1)`, or `g/(g-1)` under `cluster()`); versions through 1.1.4 omitted it, which is what produced the ~0.5% gap previously reported here and misattributed to `stcrreg`'s expanded dataset. `noadjust` reproduces the earlier numbers exactly.

## References

- Fine JP, Gray RJ. A proportional hazards model for the subdistribution of a competing risk. *Journal of the American Statistical Association*. 1999;94(446):496-509.
- Grambsch PM, Therneau TM. Proportional hazards tests and diagnostics based on weighted residuals. *Biometrika*. 1994;81(3):515-526.
- Kawaguchi ES, Shen JI, Suchard MA, Li G. Scalable algorithms for large competing risks data. *Journal of Computational and Graphical Statistics*. 2021;30(3):685-693.

## Version History

- **1.1.4** (2026-07-10; Pending SSC release): Bootstrap and parsing robustness fixes.
  - Bootstrap refits (`finegray_cif, bootstrap()` and `finegray_predict, ci bootstrap()`) now skip any replication whose resample loses a factor level. Previously such a replication posted a shorter coefficient vector: `finegray_cif` silently mispaired coefficients against the stored covariate profile (wrong bootstrap SE with `rc=0`), and `finegray_predict` aborted with a Mata conformability error `r(3200)`. Skipped replications are counted in `r(bootstrap_failed)` and reported in the skipped-replications note, which `finegray_predict` now also displays.
  - `finegray_cif, saving()` accepts `saving(filename,replace)` without a space after the comma; previously only `saving(filename, replace)` was accepted and the unspaced form was rejected with `r(198)`.
  - `finegray_predict` no longer leaves a partial prediction variable behind when it exits with an error (for example, a failed bootstrap or a confidence-limit name collision); any variables created by the failed call are dropped.

- **1.1.3** (2026-07-10; Not released to SSC): Regression fixes for the 1.1.2 estimator refresh.
  - Fixed the Newton-Raphson early-exit added in 1.1.2, which declared convergence on a small step without applying it. Coefficients could be left up to `sqrt(tolerance())` from the optimum; `predict, xb` is again bit-exact against `stcrreg`.
  - Fixed `finegray_predict, bootstrap()`, which aborted with `r(111)` on every replication because a local macro was referenced without quotes.
  - Fixed cumulative-incidence standard errors under multi-stratum censoring (`strata()` spanning more than one group), which exited `r(3201)` because a matrix was passed to Mata's vector-only `runningsum()`.

- **1.1.2** (2026-07-09; Not released to SSC): Deep correctness and state-safety review.
  - Fixed stratified censoring IPCW throughout the estimator, robust variance, baseline hazard, Schoenfeld residuals, and CIF influence functions. Each retained competing-event subject now uses the censoring survival from its own stratum; coefficients and log pseudo-likelihood now match `cmprsk::crr(..., cengroup=)` to numerical precision.
  - Added estimation-data signatures. `finegray_cif`, `finegray_phtest`, and the data-dependent `finegray_predict` paths reject stale or edited estimation data, while point `xb`/CIF scoring remains available on compatible new data.
  - Hardened post-estimation state and return gates: failed refits cannot expose stale success, graph/save failures preserve the complete analytical `r()` payload, `saving()` is strictly parsed, and `at()` rejects nonfinite values.
  - Bootstrap inference skips nonconverged refits, reports requested/successful/failed counts from `finegray_cif`, requires at least two successful replications, and preserves the original estimates and `e(sample)`.
  - Exact collinearity and constant covariates now produce an explicit `r(459)` diagnostic instead of undocumented ridge-dependent estimates; optimizer convergence at a numerical optimum is recognized without requiring a strictly increasing final step.

- **1.1.1** (2026-07-07; Not released to SSC): Correctness fixes for left truncation and multi-record fits.
  - **RETRACTION.** This entry described left truncation as "corrected." That was overstated and is withdrawn. What 1.1.1 fixed was the *score-residual risk window* under delayed entry — a real bug, and the fix stands. But the underlying **weight** was still the censoring-only IPCW weight, which is not a valid weight for left-truncated data at all (Zhang, Zhang & Fine 2011). Delayed-entry point estimates remained biased after 1.1.1, by tens to hundreds of Monte Carlo standard errors in a covariate-dependent direction, exactly as they were before it. See the **Left truncation** section above for the estimator that actually corrects this.
  - Performance: the CIF influence-function variance (`finegray_cif` and `finegray_predict, cif ci`) was rewritten from an O(_n_&sup2;) per-evaluation-point loop over the cause events to an O(_n_&nbsp;log&nbsp;_n_) prefix-sum computation. Standard errors are numerically identical (max abs difference 1e-16); a `finegray_cif` call at _n_&nbsp;=&nbsp;120,000 dropped from ~91s to ~7s. This makes CIF standard errors practical at epidemiological sample sizes.
  - Post-estimation after a multi-record (reduced) fit now reconstructs each subject's true entry time: `finegray` persists the earliest entry per subject in `_fg_entry` (recorded in `_dta[_finegray_entryvar]`), and `finegray_cif`, `finegray_phtest`, and the `ci`/`schoenfeld`/`bootstrap()` paths of `finegray_predict` read it instead of the kept record's own `_t0`. Previously these recomputed risk sets as if every subject entered at its last interval start, giving wrong CIF points/SEs, Schoenfeld residuals, PH tests, and bootstrap refits after `stsplit`-style data.
  - Robust/cluster SEs and CIF influence-function SEs under delayed entry (left truncation) fixed: the per-subject score residuals now restrict the at-risk contribution to each subject's actual risk window `[t0, t]`. Validated against a delete-one jackknife oracle; results with no delayed entry are unchanged.
  - `finegray_cif, bootstrap()` no longer destroys `e(sample)`: estimates are now held before `preserve` so the `e(sample)` marker survives the resampling loop; previously any post-estimation command run after a bootstrap call failed with "no observations".
  - `finegray_cif, ci` and `finegray_predict, cif ci` no longer error (Mata type mismatch) when the model was fit with two or more `strata()` variables; they now combine the strata into a single group column like `finegray_phtest` already did.
  - `finegray_cif, bootstrap()` and `finegray_predict, cif ci bootstrap()` no longer crash (type mismatch, `r(109)`) when the data were `stset` with a string `id()` variable; each resampled record is now assigned a fresh unique numeric subject id for the within-subject reduction. Numeric-id results are unchanged.
  - The `bootstrap()` resampling in `finegray_cif` and `finegray_predict, cif ci` now resamples whole clusters as units when the fit declared `cluster()`, instead of resampling subjects; the band therefore reflects within-cluster correlation. Fits without `cluster()` are unchanged.
  - `finegray_cif, at()` now accepts factor variables by their natural name (e.g. `at(pelnode=1)` after `finegray i.pelnode ...`), mapping the requested level onto the internal `_fg_*` dummies (a reference level sets all dummies to 0). A variable that enters an interaction, or a level not observed in the data, is rejected with a clear message; the internal `_fg_*` names remain accepted.

- **1.1.0** (2026-06-21; Not released to SSC): Feature release.
  - New command `finegray_cif`: cumulative incidence curves with pointwise confidence bands (an `stcurve, cif` analogue that also plots the interval), fixed-horizon CIF tables (`attime()`), curves on a custom time grid (`timepoints()`), a subject-bootstrap band (`bootstrap()`/`seed()`), and exportable estimates via `saving()`. The CIF plot's legend defaults to a single row, and all `twoway` graph options (including `legend()` — e.g. `legend(off)`, `legend(pos(6))`) pass through and override the defaults.
  - `finegray_predict, cif ci` adds per-subject CIF confidence limits (influence-function SE, complementary log-log scale), with an optional bootstrap band. The analytic SE now builds its influence functions from the full estimation sample even when prediction is restricted with `if`/`in`.
  - `finegray` now accepts datasets with multiple records per subject (delayed entry / `(start,stop]` / `stsplit`) when covariates are constant within subject, reducing them automatically; time-varying covariates are rejected with a clear message.
  - Documentation clarification (from the unreleased 1.0.1): `finegray_predict, cif` evaluates the CIF at each observation's own analysis time `_t`; `timevar()` gives a common horizon and `e(basehaz)` is the `stcrreg basecif` analogue.
- **1.0.0** (2026-04-06; Released to SSC): Initial Stata-Tools release of `finegray`, `finegray_predict`, and `finegray_phtest`

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
