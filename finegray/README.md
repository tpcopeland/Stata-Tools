# finegray — Fast Fine-Gray competing risks regression

**Version 1.2.0** | 2026-07-20

`finegray` fits the Fine and Gray (1999) proportional subdistribution hazards model with a native Mata scan that avoids data expansion. It also provides post-estimation prediction, cumulative-incidence curves and intervals, and an explicitly approximate proportionality diagnostic.

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
- Datasets with multiple records per subject (delayed entry, `(start,stop]` intervals, `stsplit`) are supported automatically when covariates are constant within subject; covariates that change within subject are not supported. In particular, internal time-varying covariates do not retain the model's direct relationship to the CIF after a competing event.

## Installation

```stata
capture ado uninstall finegray
net install finegray, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/finegray") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `finegray` | Fit a Fine-Gray subdistribution hazards model |
| `finegray_predict` | Generate `xb`, CIF (with optional CI), baseline cumulative subhazard, or Schoenfeld residuals after `finegray` |
| `finegray_cif` | Plot cumulative incidence curves with confidence bands; report fixed-horizon CIF with CI |
| `finegray_phtest` | Screen the proportional subdistribution hazards assumption with an approximate residual diagnostic |
| `finegray_gof` | Test proportionality, functional form, and the link function with cumulative sums of residuals and bootstrap p-values |

## Options

| Option | Command | Purpose and default |
|--------|---------|---------------------|
| `compete()` | `finegray` | Required event-type variable |
| `cause()` | `finegray` | Required cause-of-interest value |
| `censvalue()` | `finegray` | Censoring value; default `0` |
| `strata()` | `finegray` | Stratify the censoring distribution |
| `truncstrata()` | `finegray` | Stratify the entry (delayed-entry) distribution; cross-classified with `strata()` internally |
| `cluster()` | `finegray` | Cluster-robust inference; requires more clusters than coefficients |
| `basehaz` | `finegray` | Post the baseline cumulative subhazard in `e(basehaz)`; off by default because the matrix is O(rows²) to build (see Stored results) |
| `robust` / `norobust` | `finegray` | Sandwich variance is the default; `norobust` selects the observed-information variance, which is **not valid for inference** under a pseudo-likelihood |
| `adjust` / `noadjust` | `finegray` | The finite-sample adjustment to the sandwich (`N/(N-1)`, or `g/(g-1)` with `cluster()`) is the default, matching `stcrreg`; `noadjust` omits it |
| `nuisance` | `finegray` | Adds the Fine–Gray (1999, eq. 7–8) estimated-`G` term to the sandwich meat, so it becomes `sum_i (eta_i + psi_i)^2`. Opt-in; right censoring only; refused with `norobust` and under delayed entry |
| `shr` / `noshr` | `finegray` | SHRs are the default; `noshr` reports log-SHR coefficients |
| `level()` | `finegray` | Confidence level; default `c(level)` |
| `log` / `nolog` | `finegray` | Iteration logging is the default; `nolog` suppresses it |
| `iterate()` | `finegray` | Maximum Newton-Raphson iterations; default `200` |
| `tolerance()` | `finegray` | Convergence tolerance; default `1e-8` |
| `xb`, `cif`, `schoenfeld`, `basecshazard` | `finegray_predict` | Select the prediction type; default `xb`. `basecshazard` writes the baseline cumulative subhazard as a variable (the `stcrreg` idiom), at O(N) |
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
| `twoway` graph options | `finegray_cif` | Pass options such as `legend()`, `title()`, and `xtitle()` through to the graph |
| `time()` | `finegray_phtest` | Select `rank`, `log`, or `identity`; default `rank` |
| `detail` | `finegray_phtest` | Display the first 20 approximately scaled Schoenfeld rows |
| `proportional` | `finegray_gof` | Test proportionality of the subdistribution hazards; the default when no test is named |
| `funcform()` | `finegray_gof` | Test the linear functional form of each named covariate |
| `link` | `finegray_gof` | Test the link function |
| `nsim()`, `seed()` | `finegray_gof` | Bootstrap replications (default 1000, minimum 100) and seed; p-values are simulation based |

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
| `e(covariates)`, `e(fvvarlist)`, `e(fvsemantic)` | Expanded covariates, original factor-variable specification, and its expansion semantics |
| `e(strata)`, `e(truncstrata)`, `e(clustvar)`, `e(vce)` | Censoring-strata, entry-strata, cluster, and variance metadata |
| `e(lt_weight)`, `e(lt_vce)` | Left-truncation weight form and the variance actually computed under delayed entry |
| `e(vce_meat)` | Which sandwich meat was used: `fixed_weight`, `nuisance_adjusted`, or `not_applicable` |
| `e(N_weight_strata)`, `e(min_weight_prob)`, `e(max_lt_weight)` | Weight-design diagnostics: number of joint weight strata, smallest weight probability, largest LT weight |
| `e(N_prob_warn)`, `e(N_weight_warn)`, `e(weight_warn_strata)` | Weight-diagnostic warning counts and the joint-group codes they flagged |
| `e(bh_seq)` | Internal key to the cached Mata baseline; presented by post-estimation and refused on mismatch (bookkeeping, not a statistic) |
| `e(title)`, `e(marginsok)`, `e(properties)` | Estimation-command metadata |
| `e(datasignature)`, `e(datasignaturevars)` | Original-data signature used by data-dependent post-estimation |
| `e(sample)` | Estimation-sample indicator |
| `e(b)`, `e(V)` | Coefficient vector and variance-covariance matrix |
| `e(basehaz)` | Baseline cumulative subdistribution hazard by event time — **only when `basehaz` is specified** (see below) |

**`e(basehaz)` is opt-in.** It holds one row per distinct cause-event time, so it has roughly N/2 rows, and creating a Stata matrix that tall is O(rows²) — Stata builds one dimension name per row, and the cost is per name, not per element. At N = 200,000 that single matrix cost 38 s, more than the entire model fit, and it was the only reason `finegray`'s runtime was superlinear (log-log slope 1.65 with it, 1.06 without; 95.0 s → 18.7 s at N = 200,000). Nothing needs it: `finegray_cif` and `finegray_predict` rebuild the same curve in Mata, and `predict, basecshazard` returns the baseline as a variable at O(N) — the same idiom `stcrreg` uses, since `stcrreg` posts no baseline matrix in `e()` either. Specify `basehaz` when you want the matrix itself.

`finegray_cif` stores `r(table)`, `r(at)`, `r(level)`, `r(cause)`, and `r(profile_vars)`. With `bootstrap()`, it also stores `r(bootstrap_requested)`, `r(bootstrap_success)`, and `r(bootstrap_failed)`. `finegray_phtest` stores `r(N_fail)`, `r(time)`, and `r(phtest)`. `finegray_gof` stores `r(gof)`, `r(sup_overall)`, `r(p_overall)`, `r(funcform)`, `r(sup_link)`, `r(p_link)`, `r(nsim)`, `r(seed)`, `r(test)`, and `r(covariates)` — deliberately no `r(chi2)` and no `r(df)`, because the overall statistic is a supremum of a sum of absolute standardized score processes rather than a quadratic form, and has no chi-squared null. `finegray_predict` creates variables and intentionally clears `r()`.

## How It Works

The workflow has three parts:

1. `stset` the data with an `id()` variable. One or multiple contiguous records per subject are supported when covariates are constant within subject.
2. Fit `finegray` with a `compete()` event-type variable and `cause()` for the event of interest.
3. Use `finegray_predict`, `finegray_phtest`, or `finegray_gof` after estimation.

Operational details that matter:

- `compete()` is usually coded as `0 = censored`, `1 = cause 1`, `2 = cause 2`, and so on
- `cause(#)` selects the event type of interest
- `finegray_predict, xb` can be used on datasets that contain the model covariates
- `finegray_predict, cif` additionally requires a time variable (`_t` or `timevar()`); it uses `e(basehaz)` when that opt-in matrix exists and otherwise resolves the fit-specific cached or rebuilt baseline
- `finegray_predict, schoenfeld`, `finegray_phtest`, and `finegray_gof` require the original `stset` estimation data
- `finegray_gof` covers right censoring only, and refuses delayed entry, `strata()`, and `cluster()` — each is a regime the source paper does not cover, not one merely untested here
- `finegray_gof` supports factor variables and interactions, reporting each design column under the term the user typed (`2.race`, not the internal `_fg_race_2`), and reconstructing the design from the fit-time expansion `e(fvsemantic)` — keyed to the level *value* — if those columns have been dropped
- Without delayed entry, `finegray_predict` reproduces `stcrreg`'s post-estimation quantities: `xb` matches `predict, xb`, the baseline CIF matches `predict, basecif`, and the fitted cumulative subhazard is `H0 = -ln(1 - basecif)` (also available in `e(basehaz)` when `basehaz` was requested). The per-observation `cif` is the covariate-adjusted CIF, which `stcrreg` produces via `stcurve, cif at()` rather than `predict`; `finegray_predict, cif` matches it to numerical precision. Schoenfeld residuals match `stcrreg` exactly at untied event times; at tied event times the per-event split differs by convention while the per-time total is identical (see below)
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

`finegray_phtest` is an approximate post-estimation diagnostic for time-varying effects. It uses diagonal-scaled Schoenfeld residuals and simple residual–time correlations, so it must be run on the original estimation data and should not be interpreted as a formal Grambsch–Therneau joint test.

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

The default is a **fixed-weight sandwich**: it treats the estimated censoring weights as fixed and does not propagate the uncertainty in the estimated censoring distribution G(t) (nor, under delayed entry, the entry distribution H(t)). This is the same variance `stcrreg` reports. `e(lt_vce)` records the delayed-entry variance as `fixed_weight_sandwich` (or `model_based` under `norobust`); it is **not** the full Fine–Gray (1999, eq. 7–8) / Zhang–Zhang–Fine (2011) nuisance-adjusted variance. Against `cmprsk::crr`, which does include that nuisance term, `finegray`'s default standard errors differ by **−0.6% to +0.7%** across the package's parity fixtures (**−1.3% to +1.4%** on the variance scale) — the correction is not signed, because `eta` and `psi` are correlated, so the default is **not** reliably the conservative choice. The effect on *covariances* is larger than on variances, so a multi-coefficient `test` or `lincom` moves more than the individual standard errors do. (Earlier releases quoted "roughly 0.2%", measured on a single fixture; that understated the range about threefold.) Under right censoring the nuisance term is available with `nuisance`, which reproduces `crr` to ~1e-7 relative; coefficients are unaffected either way.

For **coefficient** standard errors that account for weight estimation, bootstrap the whole fit — resample subjects and re-estimate in each replication:

```stata
program define myfit, eclass
    quietly stset t, failure(ev) id(id)
    quietly finegray x1 x2, compete(ev) cause(1)
end
bootstrap _b, reps(500) seed(12345) cluster(id) idcluster(newid) group(id): myfit
```

The `bootstrap()` options of `finegray_cif` and `finegray_predict` resample for CIF/prediction standard errors, **not** coefficient ones.

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

## Demo

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
- Approximate proportional subdistribution hazards diagnostic after estimation
- Left truncation (delayed entry) via Zhang–Zhang–Fine Weight 1, computed without expanding the data; the one-stratum path uses the equivalent Geskus product-limit representation — see below

## Left truncation (delayed entry)

**Under delayed entry `finegray` deliberately does not agree with `stcrreg`.** This is the package's main statistical contribution, and it is worth understanding before you use it.

A Fine–Gray weight built from the censoring distribution alone is not a valid weight for left-truncated data: if nothing is censored it collapses to a constant, which cannot correct anything. Zhang, Zhang & Fine (2011) show that the resulting estimator is biased and that the bias does **not** shrink as the sample grows. `stcrreg` uses that censoring-only weight, and so did `finegray` before this release.

With one weight stratum, `finegray` implements the **Geskus (2011) product-limit representation**. Writing `A(t) = G(t−)H(t−)`, where `G` is the delayed-entry-aware censoring survivor and `H` is a reverse-time product-limit estimator of entry, a subject retained after a competing event at `X_i` carries `A(t−)/A(X_i−)` instead of the censoring-only ratio `G(t−)/G(X_i−)`. Geskus states that this weight is equivalent to Zhang–Zhang–Fine Weight 1, and Bellach et al. (2020) prove the equivalence for continuous failure times; the package supplies and tests its own finite-sample tie convention.

With multiple weight strata, `finegray` uses the Zhang, Zhang & Fine (2011, eq. 7) form: the time-side stabilizer is pooled, while each subject-side denominator is stratum-specific. When `strata()` and `truncstrata()` specify the same grouping, this is the paper's stratified nonparametric construction. When the groupings differ, `finegray` estimates `G` within `strata()`, estimates `H` within `truncstrata()`, and multiplies those components in each observed combination; that factorized cross-classification is a package extension, not a construction attributed to Zhang et al. The same contract is used consistently by estimation, robust variance, baseline hazards, Schoenfeld diagnostics, CIFs, analytic CIF standard errors, and weight diagnostics.

The weight is **separable** — it factors into a function of time times a function of the subject — which is exactly the property that lets the forward–backward scan compute it **without expanding the data**. Reference implementations (`survival::finegray`, `mstate::crprep`) deliver the same weighting by emitting one row per weight change, expanding a 500-subject delayed-entry dataset by 17× and 27× respectively.

**What this means for you:**

| | |
|---|---|
| **Delayed-entry results change** | Coefficients, SEs, baseline hazards, predictions and CIFs all move relative to earlier `finegray` versions and relative to `stcrreg`. That is the fix, not a regression. |
| **No-delayed-entry results do not change** | With every subject entering at the origin, `H ≡ 1`, `A` collapses to `G`, and the estimator is bit-for-bit the existing right-censoring path. |
| **Pooled weights assume covariate-independent entry and censoring** | If entry depends on an observed discrete group, name it in `truncstrata()`. If censoring does, name it in `strata()`. Observed combinations form the joint denominator strata. |
| **Continuous covariate-dependent entry is not supported** | The command cannot infer or reject this dependence from the realized data. Do not use pooled weights when entry depends on a continuous model covariate unless a scientifically defensible discrete stratification removes that dependence. |
| **Breaking change** | Under delayed entry, factorized `A = G·H` is evaluated for every observed joint weight stratum, so every `strata()` level is also a weight stratum *even without* `truncstrata()`. (`G` is estimated within censoring strata and `H` within entry strata.) At most 100 joint strata (≥20 subjects each) are supported. A delayed-entry model with many `strata()` levels that fitted in 1.1.0 may now stop with `r(459)` rather than silently pooling groups. The same model still fits without delayed entry. |

`e(lt_weight)` reports which weight was actually used: `zzf1_geskus` for a one-stratum delayed-entry fit, `zzf1_stratified` for the equation-7 pooled-stabilizer form when `strata()` and `truncstrata()` name the same grouping (the paper's stratified construction), `zzf1_factorized` when they name different groupings (the factorized `A = G·H` extension described above, which is a package extension, not a construction attributed to Zhang et al.), and `right_censoring` when there is no delayed entry. When the factorized weight is used, `finegray` also prints a note at fit time. `e(lt_vce)` records the variance, so consumers do not have to infer either contract from the option list. Weight diagnostics are stored in `e(N_weight_strata)`, `e(min_weight_prob)`, `e(max_lt_weight)`, `e(N_prob_warn)`, `e(N_weight_warn)` and `e(weight_warn_strata)`. Product-limit delayed-entry weights may legitimately exceed 1.

## QA

On ordinary right-censored data without delayed entry, the package QA cross-validates `finegray` against Stata's `stcrreg` and independent R implementations of Fine-Gray regression: `cmprsk::crr` and `fastcmprsk::fastCrr`. (`riskRegression::FGR` is used for the CIF prediction check, but it is a `cmprsk` wrapper — it calls `do.call(cmprsk::crr, args)` — so it does not count as a further independent estimator.) The validation files under `qa/` cover coefficients, standard errors, log pseudo-likelihoods, CIF predictions (required to agree with `riskRegression` within `1e-4`; maximum absolute difference `2.359e-08` in the latest full run), CIF confidence intervals (validated against a subject bootstrap), baseline hazards, multiple-record reduction, and stratified censoring behavior. The delayed-entry product-limit branch, equation-7 stratified form, and factorized cross-classification are validated separately against direct estimating-equation oracles, independent R implementations, and Monte Carlo recovery and coverage gates; agreement with `stcrreg` is not expected there.

The suite is driven by `qa/run_all.do` (`quick`, `core`, `python`, `full`, and `gates` lanes) and documented in `qa/README.md`; `qa/run_all.sh` converts its numeric result sentinel into a reliable shell/CI exit status. The `qa/` directory contains 38 executable suite files: 16 functional/regression files (including `test_documentation_examples.do`, which runs the README workflows and advertised baseline options), 10 validation files, 7 cross-validation files covering all five public commands, and a performance benchmark. The four Monte Carlo gates — delayed-entry recovery, coverage, factorized cross-classification, and `finegray_gof` type-I calibration — run under the `gates` lane (hours, not minutes). A skipped or missing suite fails the runner — an external oracle that does not run is treated as an unrun check, not a pass.

The latest isolated `full` lane (2026-07-21, via `qa/run_all.sh full`) passed 29/29 suites and 609/609 checks with no failures or skips, plus the shell-level `fg02_failclosed` R-oracle gate; the receipt is `qa/run_all_status.txt`. The three full-size delayed-entry Monte-Carlo gates (recovery, coverage, factorization) last ran on 2026-07-15 and passed with every planned replication retained. They are not re-run for this tree because the delayed-entry estimator core is provably unchanged since that run: fitting the same seeded delayed-entry model on the gated tree and on this tree returns identical coefficients, robust SEs, and factorized-weight coefficients to 15 decimal places (the 2026-07-18 changes touch only the `e(lt_vce)` label and factor-name parsing, not the weight/score/variance path). See `qa/run_status_gates.txt` for the transfer receipt and `qa/README.md` for the gate design and the exact re-run command.

On no-delayed-entry data, `qa/crossval_predict_stcrreg.do` cross-validates every `finegray_predict` path directly against `stcrreg`'s native post-estimation predictions (no external dependency, so it never skips): `xb`, the relative subhazard `exp(xb)`, the covariate-adjusted CIF, the baseline CIF (`basecif`), the baseline cumulative subhazard (`e(basehaz)`), Schoenfeld residuals, and the subhazard ratios with their standard errors and 95% confidence intervals. All agree to numerical precision, with one documented and asserted exception:

- **Schoenfeld residuals at tied event times.** At an event time shared by two or more cause events, `finegray` and `stcrreg` partition the residual among the simultaneous events using different conventions, so an individual residual at a tied time can differ. The QA suite asserts that (a) residuals match `stcrreg` exactly at untied event times and (b) the sum of the residuals within each event time — and hence the overall score, which is zero at the estimate — is identical. Only the per-observation values at tied times differ; untied times, per-time totals, and every event-time aggregate are unaffected.

Standard errors are robust (sandwich) by default in both commands and agree to within 1e-3 relative. `finegray` applies the same finite-sample adjustment as `stcrreg` (`N/(N-1)`, or `g/(g-1)` under `cluster()`); versions through 1.1.0 omitted it, which is what produced the ~0.5% gap previously reported here and misattributed to `stcrreg`'s expanded dataset. `noadjust` reproduces the earlier numbers exactly.

## References

- Fine JP, Gray RJ. A proportional hazards model for the subdistribution of a competing risk. *Journal of the American Statistical Association*. 1999;94(446):496–509. [doi:10.1080/01621459.1999.10474144](https://doi.org/10.1080/01621459.1999.10474144)
- Zhang X, Zhang M-J, Fine J. A proportional hazards regression model for the subdistribution with right-censored and left-truncated competing risks data. *Statistics in Medicine*. 2011;30(16):1933–1951. [doi:10.1002/sim.4264](https://doi.org/10.1002/sim.4264)
- Geskus RB. Cause-specific cumulative incidence estimation and the Fine and Gray model under both left truncation and right censoring. *Biometrics*. 2011;67(1):39–49. [doi:10.1111/j.1541-0420.2010.01420.x](https://doi.org/10.1111/j.1541-0420.2010.01420.x)
- Bellach A, Kosorok MR, Gilbert PB, Fine JP. General regression model for the subdistribution of a competing risk under left-truncation and right-censoring. *Biometrika*. 2020;107(4):949–964. [doi:10.1093/biomet/asaa034](https://doi.org/10.1093/biomet/asaa034)
- Bellach A, Kosorok MR, Rüschendorf L, Fine JP. Weighted NPMLE for the subdistribution of a competing risk. *Journal of the American Statistical Association*. 2019;114(525):259–270. [doi:10.1080/01621459.2017.1401540](https://doi.org/10.1080/01621459.2017.1401540)
- Kawaguchi ES, Shen JI, Suchard MA, Li G. Scalable algorithms for large competing risks data. *Journal of Computational and Graphical Statistics*. 2021;30(3):685–693. [doi:10.1080/10618600.2020.1841650](https://doi.org/10.1080/10618600.2020.1841650)
- Grambsch PM, Therneau TM. Proportional hazards tests and diagnostics based on weighted residuals. *Biometrika*. 1994;81(3):515–526. [doi:10.1093/biomet/81.3.515](https://doi.org/10.1093/biomet/81.3.515). Correction with the same title: Grambsch PM, Therneau TM. *Biometrika*. 1995;82(3):668. [doi:10.1093/biomet/82.3.668](https://doi.org/10.1093/biomet/82.3.668)

Citation scope: Fine and Gray (1999) ground the model, right-censoring risk sets, and Schoenfeld-type residual plots. Zhang et al. (2011) ground left-truncated Weight 1 in its published `b/S` form; Geskus (2011) grounds the `G·H` product-limit form and tie ordering; Bellach et al. (2020) ground their continuous-time equivalence. Bellach et al. (2019) ground the estimated-weight variance term and the limitation for internal time-varying covariates. Kawaguchi et al. (2021) ground only the right-censoring, no-ties scan decomposition—not this package's tie, left-truncation, or variance extensions. Grambsch and Therneau (1994, corrected 1995) concern the Cox model; `finegray_phtest` borrows their residual–time diagnostic idea but does not implement or claim that paper's formal joint test for the proportional subdistribution hazards model.

## Version History

- **1.2.0** (2026-07-20; Pending SSC release): Left-truncation estimator, robust-SE finite-sample adjustment, the opt-in `nuisance` estimated-weight variance correction, opt-in baseline matrix, retired omnibus proportionality test, and a hardened QA gate. First release since 1.0.0; the 1.1.x line was never published to SSC.
  - **Left truncation now uses the Geskus (2011) product-limit weight.** Under delayed entry the weight factor is `A(t−) = G(t−)·H(t−)`, reweighting the risk set for entry rather than applying the censoring weight alone. A censoring-only weight — what `stcrreg` uses, and what `finegray` used through 1.1.0 — is not a valid weight for left-truncated data at all (Zhang, Zhang & Fine 2011): delayed-entry point estimates were biased by tens to hundreds of Monte Carlo standard errors in a covariate-dependent direction, and now recover the truth to within Monte Carlo error. This weight is equivalent to Zhang–Zhang–Fine Weight 1 in the unstratified continuous-time setting. With multiple weight strata the weight follows Zhang et al. (2011, eq. 7) — pooled time-side stabilizer, stratum-specific subject denominator — with the factorized `A = G·H` cross-classification as a package extension when `strata()` and `truncstrata()` name different groupings. `e(lt_weight)` records which weight was used and `e(lt_vce)` the variance actually computed; the fit prints a note when the factorized extension applies. The default sandwich met the package's truncation coverage gate, while `norobust` undercovered and now warns. With **no** delayed entry the weight, and every point estimate, is unchanged.
  - **Fixed a tie-handling defect in the delayed-entry at-risk count.** The entry-time risk set kept subjects exiting at that exact instant; Geskus's tie ordering (events, then censorings, then entries) removes them. Continuous data never exposed it (tied entry/exit has probability zero); a fixture of exact ties in Stata does.
  - **Robust standard errors now carry the same finite-sample adjustment as `stcrreg`** (`N/(N-1)`, or `g/(g-1)` under `cluster()`). Earlier versions omitted it, which is what produced the ~0.5% gap against `stcrreg` previously reported here and misattributed to `stcrreg`'s expanded dataset. `noadjust` reproduces the earlier numbers exactly.
  - **The `psi` term is now available (`nuisance`).** Through 1.1.0 the sandwich meat was `sum_i eta_i^2`, which treats the censoring survivor `G` as known; Fine and Gray (1999, sec. 4, pp. 500-501) give it as `sum_i (eta_i + psi_i)^2`, where `psi_i` is the contribution from having *estimated* `G` by Kaplan-Meier. The omission was documented rather than fixed because the delayed-entry form (Zhang, Zhang & Fine 2011, Appendix B) was unobtainable — but the **right-censoring** form is in Fine and Gray (1999) itself, and that is what `nuisance` implements. With `nuisance`, `finegray` reproduces `cmprsk::crr` — whose Fortran variance routine `crrvv` is by R. J. Gray, the paper's second author — to ~1e-7 relative across five parity fixtures (`qa/data/`), including 5-way tied event times, three censoring strata, and the 416-subject PBC example with five covariates.
  - **The correction is not always conservative.** `eta` and `psi` are correlated, so the adjusted variance can be larger *or* smaller than the default: measured **-1.3% to +1.4%** on the variance scale (**-0.6% to +0.7%** on standard errors) across the parity fixtures. Do not assume the default is the safe direction. The effect is concentrated in the *covariances* rather than the variances, so multi-coefficient inference (`test`, `lincom`) moves more than the reported standard errors do. The range is printed by `qa/crossval_nuisance_r.R` on every regeneration, so it has a generator rather than being quoted from one fixture. (The previous README/help claim of "roughly 0.2%" was measured on a single fixture and understated the range about threefold.)
  - **`nuisance` is refused under delayed entry** (`r(198)`) rather than silently applying a right-censoring correction to left-truncated data, and is refused with `norobust`, which has no sandwich to correct. `e(vce_meat)` is a new returned local recording which meat was used: `fixed_weight`, `nuisance_adjusted`, or `not_applicable`.
  - **Default output is unchanged by this option.** `nuisance` is opt-in, so the default standard errors are exactly those computed without it; a QA test pins the pre-`nuisance` values directly.
  - **`finegray_phtest` no longer reports an omnibus test.** The "Global test" row and `r(chi2)`, `r(df)`, `r(p)` are removed — a breaking change to the return surface, with no change to any estimate. The global statistic was the sum of the per-covariate 1-df statistics referred to chi2(p); that reference distribution is correct only when the components are independent, and scaled Schoenfeld residuals are correlated whenever the covariates are, so the printed `Prob>chi2` had no stated null distribution and erred in an unknown direction. The apparent repair — the joint quadratic form built from the p × p inverse information, as Grambsch and Therneau (1994) do for the Cox model — does not transfer: their null covariance is the Cox information, an identity resting on the Cox score being a martingale integral, whereas this estimator's score is IPCW-weighted with an estimated censoring distribution, so its variance is a sandwich carrying an extra term for that estimation (Fine and Gray 1999, eq. 7–8; Bellach et al. 2019, §3.3). That is why the fit itself defaults to `vce(robust)` rather than the inverse information; reusing the information as a null covariance would restate the same defect in a form that merely looks rigorous. At the time of that removal no published omnibus test for the proportional *subdistribution* hazards assumption was implemented; Li, Scheike and Zhang (2015) has since been grounded in the package's literature corpus and implemented as `finegray_gof`, while Zhou et al. (2013) remains unimplemented and PSHREG (Kohl et al. 2015), the closest reference implementation, likewise reports only per-covariate correlation tests and residual plots. For a global claim, use `finegray_gof` (added later in this same 1.2.0 cycle — see below), which implements Li, Scheike and Zhang (2015) with bootstrap p-values, or fit the time-interaction model directly. `finegray_phtest` is now a **diagnostic**, not a test: it reports the per-covariate scaled-Schoenfeld/time **correlation** only, with no chi2, df, or p-value in the display or in `r(phtest)` — no published null calibration exists for the marginal `n*rho^2` statistic under the subdistribution model, so a printed `Prob>chi2` would assert a level the package has not established. `r(phtest)` is now a *p* × 2 matrix with columns `correlation` and `events` (was *p* × 3 `[chi2, df, p]`); `r(N_fail)` and `r(time)` are unchanged. Code reading a p-value from `r(phtest)` or `r(p)` now sees the correlation column / an empty scalar rather than a fabricated inferential number.
  - **`e(basehaz)` is now opt-in (`basehaz`), and is a behavior change.** It holds one row per distinct cause-event time (≈ N/2 rows), and creating a Stata matrix that tall is O(rows²) — it cost 38 s at N = 200,000, more than the fit, and was the *only* reason `finegray` was superlinear in N. It is no longer posted unless you request `basehaz`; the runtime is now linear (log-log slope 1.06, 95 s → 18.7 s at N = 200,000). Post-estimation does not need the matrix — `finegray_cif` and `finegray_predict` rebuild the curve in Mata — so no `finegray_cif`/`predict` result changed. Only a user reading `e(basehaz)` directly, or `estimates save`-ing and predicting in a later session, needs to add `basehaz`.
  - **New `predict newvar, basecshazard`** returns the baseline cumulative subhazard as a variable at O(N) — the same idiom `stcrreg` uses, since `stcrreg` posts no baseline matrix in `e()`.
  - **QA gate hardening.** `run_all.do` now fails on a skipped or missing suite — a skipped external oracle is an unrun check, not a pass — closing the hole by which a fully green suite could coexist with unrun checks. Smoke runs exit nonzero on failure, every runner pass requires a zero-failure evaluated sentinel, recovery and coverage gates require every planned fit, and oracle manifests require every arm and replication at the pinned full size. Several tests that asserted a tautology, a vacuous positivity check, or parity with `stcrreg` under left truncation (which the new estimator deliberately breaks) were rewritten to assert the contrast they are named for.
  - **Documentation:** `finegray.sthlp` gains a *Dataset side effects* section collecting, in one place, everything a fit leaves behind — the `_fg_*` design columns, `_fg_entry`, the dataset characteristics, and the reduced `e(sample)`. The last was previously undocumented: on multiple-record data `e(sample)` marks one record per subject and `e(N)` counts subjects, so `count if e(sample)` returns subjects rather than records. No behavior changed; the reduction has always worked this way. The help file also documents that continuous covariate-dependent entry cannot be diagnosed automatically and remains outside the supported pooled-weight assumptions.
  - **New command `finegray_gof` (2026-07-20): a calibrated goodness-of-fit test, closing the gap this same release opened.** Removing the omnibus proportionality test from `finegray_phtest` left the package with a diagnostic where users want a test. `finegray_gof` implements the cumulative-sums-of-residuals tests of Li, Scheike and Zhang (2015): proportionality of the subdistribution hazards per covariate and overall, the linear functional form of a covariate, and the link function. It reports p-values where `finegray_phtest` deliberately does not, because the null distribution is not asserted from a table — it comes from a Lin–Wei–Ying multiplier bootstrap in which only the standard normal multipliers are redrawn, one per subject, with the model fitted once and never refitted. Factor-variable and interaction designs are supported: each column is mapped back to its `fvexpand` term for display, `r(gof)` rownames, and `r(covariates)`, and results are bit-identical to fitting the same design as ordinary variables.
    - **The reported p-values are simulation based and seed dependent**, with a resolution floor of `1/nsim`. An observed count of zero prints as `< 0.0010` at the default `nsim(1000)` rather than as a bare `0.0000`, because it means "below the floor", not "zero".
    - **The test is anticonservative at small samples, by the authors' own measurement** (Table 1: type I error 0.0624 at n = 50 against a nominal 0.05). The package's own Monte Carlo calibration reproduces the published Tables 1 and 4 to within Monte Carlo error — pooled proportionality 0.0593 against the paper's 0.0585, pooled functional form 0.0531 against 0.0531 — and confirms the paper's ordering, that the proportionality test is the more anticonservative of the two.
    - **It will not reproduce `crskdiag`, the authors' own R implementation, and that is not a defect here.** That implementation's censoring Kaplan–Meier is identically 1 on continuous data, so its IPCW weights are effectively absent, and its default `minor_included = 1` adds a defective nuisance term that feeds the test process itself rather than only the variance. Because observed and simulated suprema share the same weights, a mis-specified weight can leave the test correctly sized while changing every number it prints — which is what the calibration above shows.
    - **No `r(chi2)` and no `r(df)`, deliberately.** The overall statistic is a supremum of a sum of absolute standardized score processes: not a quadratic form, and with no chi-squared null. Reporting them would reintroduce precisely the defect removed from `finegray_phtest` in this same release.
    - **Scope is refused, not approximated.** Delayed entry, `strata()`, and `cluster()` each exit `r(301)` with a message naming its own reason; a nonconverged fit exits `r(430)`. There is no entry time anywhere in the source paper — not in the model, the appendix, the simulations, or either data example — so the delayed-entry analogue is a research contribution rather than an implementation detail. `funcform()` on a covariate with two or fewer distinct values is also refused (`r(198)`): the residual process is then identically zero and its p-value would be decided by rounding error, a point the paper makes at sec. 4.1.
  - **Post-estimation factor designs are resolved from the fit, not from the current `fvset` (2026-07-21).** `finegray_gof` and `finegray_phtest` resolved a factor-variable design by re-running `fvexpand` on `e(fvvarlist)` against the data in memory. `fvexpand` reads the base level from the variable's *current* `fvset` setting, so changing the base between the fit and the post-estimation call changed **which** terms were kept while leaving **how many** unchanged — passing every count check, including the assertion against `colsof(e(b))`. With the `_fg_*` columns present the effect was a silent relabel (level-2 and level-3 coefficients printed under the level-1 and level-2 names); with them dropped, the rebuild paired the wrong indicators with `e(b)` and every statistic changed (on one fixture `finegray_gof`'s OVERALL supremum went 8.6996 → 14.4044, and `finegray_phtest`'s correlations −0.2348/−0.2062/0.1931 → −0.2300/0.0315/−0.2124). Both at `rc = 0`, with no warning. Both commands now read the fit-time expansion `e(fvsemantic)` through a new shared helper, `_finegray_fv_design`, which keys each indicator to the level **value** rather than to a position — so a shifted level support cannot misalign a column either. `finegray_predict` and `finegray_cif` already read `e(fvsemantic)` and were never affected; the 2026-07-18 entry below, which described `finegray_phtest` as already doing so, was wrong about that command. Regression tests: `test_finegray_gof.do` G18 and `test_finegray.do` T125c, both confirmed to fail against the previous behavior.
  - **Pre-release maintenance (2026-07-18).** `finegray_cif` now honors the documented "dropping the `_fg_*` design columns is supported" contract: it rebuilds them on demand from the fit-time expansion `e(fvsemantic)` (as `finegray_predict` already did — the claim made here at the time that `finegray_phtest` did too was wrong, and is corrected in the 2026-07-21 entry above), giving a result bit-identical to the persistent-column path, and refuses with a curated `r(459)` — instead of a raw `r(111)` — when a dropped covariate cannot be rebuilt because the raw variable is also gone. The `finegray_cif` fixed-horizon table header no longer prints a confidence-level suffix when no interval was requested, and warns that `twoway` options are ignored in `attime()` table mode. Documentation-accuracy fixes: the README stored-results list dropped the retired `r(chi2)`/`r(df)`/`r(p)` from `finegray_phtest`, and the QA gate count is corrected to three. Internal only: `finegray_phtest` now mirrors the sibling commands' explicit preserve-restore in its cleanup zone (Stata already auto-restores on error, so no data was ever at risk), and unused intermediate results were removed. No estimate changed.

- **1.1.0** (2026-07-10; Not released to SSC): Cumulative incidence curves, multiple-record fits, and stratified-censoring correctness.
  - New command `finegray_cif`: cumulative incidence curves with pointwise confidence bands (an `stcurve, cif` analogue that also plots the interval), fixed-horizon CIF tables (`attime()`), curves on a custom time grid (`timepoints()`), a subject-bootstrap band (`bootstrap()`/`seed()`), and exportable estimates via `saving()`. The CIF plot's legend defaults to a single row, and all `twoway` graph options (including `legend()` — e.g. `legend(off)`, `legend(pos(6))`) pass through and override the defaults.
  - `finegray_predict, cif ci` adds per-subject CIF confidence limits (influence-function SE, complementary log-log scale), with an optional bootstrap band. The analytic SE builds its influence functions from the full estimation sample even when prediction is restricted with `if`/`in`.
  - `finegray` now accepts datasets with multiple records per subject (delayed entry / `(start,stop]` / `stsplit`) when covariates are constant within subject, reducing them automatically; time-varying covariates are rejected with a clear message.
  - **Fixed stratified censoring IPCW** throughout the estimator, robust variance, baseline hazard, Schoenfeld residuals, and CIF influence functions. Each retained competing-event subject now uses the censoring survival from its own stratum; coefficients and log pseudo-likelihood now match `cmprsk::crr(..., cengroup=)` to numerical precision.
  - **Fixed robust/cluster and CIF influence-function standard errors under delayed entry:** the per-subject score residuals now restrict the at-risk contribution to each subject's actual risk window `[t0, t]`. Validated against a delete-one jackknife oracle; results with no delayed entry are unchanged. (The *weight* under delayed entry was still wrong at this release — see 1.2.0.)
  - Added estimation-data signatures. `finegray_cif`, `finegray_phtest`, and the data-dependent `finegray_predict` paths reject stale or edited estimation data, while point `xb` scoring — and point CIF scoring while the active fit retains its baseline — remains available on compatible new data.
  - Exact collinearity and constant covariates now produce an explicit `r(459)` diagnostic instead of undocumented ridge-dependent estimates; optimizer convergence at a numerical optimum is recognized without requiring a strictly increasing final step.
  - `finegray_predict` no longer leaves a partial prediction variable behind when it exits with an error; any variables created by the failed call are dropped.
  - Documentation clarification: `finegray_predict, cif` evaluates the CIF at each observation's own analysis time `_t`; `timevar()` gives a common horizon, and the fitted baseline cumulative subhazard is the cumulative-hazard analogue of `stcrreg`'s `basecif`.

- **1.0.0** (2026-04-06; Released to SSC): Initial Stata-Tools release of `finegray`, `finegray_predict`, and `finegray_phtest`.

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
