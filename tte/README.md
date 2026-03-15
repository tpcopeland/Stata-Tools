# tte — Target Trial Emulation for Stata

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue)

The first Stata implementation of the complete target trial emulation workflow. Implements the sequential trials framework (Hernán & Robins, 2016) with the clone-censor-weight approach for estimating per-protocol, intention-to-treat, and as-treated effects from observational data.

Features include pooled logistic and Cox marginal structural models, a Hernán 7-component protocol table generator, weight/balance diagnostics, and publication-ready reporting — all in a single, integrated pipeline.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Commands](#commands)
- [The Pipeline](#the-pipeline)
- [Estimands](#estimands)
- [Command Reference](#command-reference)
  - [tte_prepare](#tte_prepare)
  - [tte_validate](#tte_validate)
  - [tte_expand](#tte_expand)
  - [tte_weight](#tte_weight)
  - [tte_fit](#tte_fit)
  - [tte_predict](#tte_predict)
  - [tte_diagnose](#tte_diagnose)
  - [tte_plot](#tte_plot)
  - [tte_report](#tte_report)
  - [tte_protocol](#tte_protocol)
  - [tte_calibrate](#tte_calibrate)
- [Worked Example: ITT Analysis](#worked-example-itt-analysis)
- [Worked Example: Per-Protocol Analysis with IPTW](#worked-example-per-protocol-analysis-with-iptw)
- [Worked Example: NHEFS Smoking Cessation (What If)](#worked-example-nhefs-smoking-cessation-what-if)
- [Technical Notes](#technical-notes)
- [Features Beyond R TrialEmulation](#features-beyond-r-trialemulation)
- [Stored Results](#stored-results)
- [Demo Output](#demo-output)
- [Testing](#testing)
- [References](#references)
- [Version](#version)

---

## Installation

```stata
net install tte, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tte")
```

The package includes `tte_example.dta` (503 patients, 48,400 person-periods) for testing.

---

## Quick Start

```stata
use tte_example, clear

* ITT analysis in 5 commands
tte_prepare, id(patid) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(age sex comorbidity biomarker) estimand(ITT)
tte_validate
tte_expand, maxfollowup(8)
tte_fit, outcome_cov(age sex comorbidity) nolog
tte_predict, times(0 2 4 6 8) type(cum_inc) difference samples(100) seed(12345)
```

---

## Commands

| Command | Purpose |
|---------|---------|
| `tte` | Package overview and workflow guide |
| `tte_prepare` | Map variables and set the estimand |
| `tte_validate` | Run 10 data quality checks |
| `tte_expand` | Create sequential emulated trials (clone-censor) |
| `tte_weight` | Calculate stabilized inverse probability weights |
| `tte_fit` | Fit the outcome model (pooled logistic or Cox MSM) |
| `tte_predict` | Marginal cumulative incidence with Monte Carlo CIs |
| `tte_diagnose` | Weight diagnostics and covariate balance |
| `tte_plot` | KM curves, cumulative incidence, weight distributions |
| `tte_report` | Publication-quality results tables (display/Excel/CSV) |
| `tte_protocol` | Hernán & Robins 7-component protocol table |
| `tte_calibrate` | Negative control outcome calibration |

---

## The Pipeline

Data flows through the commands in order. Each step stores metadata as dataset characteristics so downstream commands know what has been done.

```
                          ┌──────────────────┐
                          │   Person-period  │
                          │      data        │
                          └────────┬─────────┘
                                   │
                          ┌────────▼─────────┐
                    ┌─────│   tte_prepare    │  Map variables, set estimand
                    │     └────────┬─────────┘
                    │              │
                    │     ┌────────▼─────────┐
                    │     │   tte_validate   │  10 data quality checks
                    │     └────────┬─────────┘
                    │              │
                    │     ┌────────▼─────────┐
  tte_protocol ─────┤     │   tte_expand     │  Clone → censor → sequential trials
  (any time)        │     └────────┬─────────┘
                    │              │
                    │     ┌────────▼─────────┐
                    │     │   tte_weight     │  Stabilized IPTW (PP/AT only)
                    │     └────────┬─────────┘
                    │              │
                    │     ┌────────▼─────────┐
                    │     │   tte_fit        │  Pooled logistic or Cox MSM
                    │     └────────┬─────────┘
                    │              │
                    │     ┌────────▼─────────┐
                    │     │   tte_predict    │  Marginal cumulative incidence
                    │     └────────┬─────────┘
                    │              │
                    │     ┌────────▼─────────┐
                    └─────│   tte_report     │  Publication tables
                          │   tte_diagnose   │  Weight/balance diagnostics
                          │   tte_plot       │  Visualization
                          └──────────────────┘
```

**ITT**: Skip `tte_weight` (no artificial censoring, weights = 1).
**PP/AT**: Include `tte_weight` to adjust for the artificial censoring introduced by `tte_expand`.

---

## Estimands

| Estimand | What it asks | Censoring rule | Weights needed? |
|----------|-------------|----------------|-----------------|
| **ITT** | What if everyone followed their *initial* assignment? | None | No |
| **PP** | What if everyone *adhered* to their assigned treatment? | Censor at treatment deviation | Yes (IPTW) |
| **AT** | What if everyone *continued* as actually treated? | Censor at treatment switching | Yes (IPTW) |

Set the estimand once in `tte_prepare, estimand(PP)` — all downstream commands inherit it automatically.

---

## Command Reference

### tte_prepare

Entry point. Maps your variable names to internal names and stores metadata for downstream commands.

**Syntax:**
```stata
tte_prepare, id(varname) period(varname) treatment(varname)
    outcome(varname) eligible(varname)
    [censor(varname) covariates(varlist) baseline_covariates(varlist)
     estimand(string) generate(string)]
```

**Required options:**

| Option | Description |
|--------|-------------|
| `id(varname)` | Patient identifier |
| `period(varname)` | Time period variable (integer, e.g., 0 1 2 ... T) |
| `treatment(varname)` | Binary treatment indicator (0/1) |
| `outcome(varname)` | Binary outcome indicator (0/1) |
| `eligible(varname)` | Binary trial eligibility indicator (0/1) |

**Optional:**

| Option | Description |
|--------|-------------|
| `censor(varname)` | Binary censoring indicator (0/1) |
| `covariates(varlist)` | Time-varying covariates (frozen at trial entry by `tte_expand`) |
| `baseline_covariates(varlist)` | Baseline-only covariates |
| `estimand(string)` | `ITT`, `PP` (default), or `AT` |
| `generate(string)` | Variable prefix; default `_tte_` |

**Data requirements:**
- Person-period (long) format: one row per individual per time period
- No duplicate `(id, period)` combinations
- Treatment/outcome/eligible must be binary 0/1
- Periods should be consecutive integers

---

### tte_validate

Runs 10 checks on the prepared data. Catches problems before the expensive expansion step.

**Syntax:**
```stata
tte_validate [, strict verbose]
```

| Option | Description |
|--------|-------------|
| `strict` | Treat warnings as errors (exit 198) |
| `verbose` | Show affected individual counts |

**Checks performed:**
1. Data structure (person-period format)
2. No gaps in period sequences
3. Treatment variable consistency
4. Outcome variable consistency
5. Missing data in key variables
6. Eligibility patterns
7. Sufficient sample size
8. Positivity (treated and untreated in each period)
9. Period numbering
10. Event rates

---

### tte_expand

The core algorithm. Expands person-period data into sequential emulated trials using the clone-censor-weight approach.

**Syntax:**
```stata
tte_expand [, trials(numlist) maxfollowup(#) grace(#)
    chunk_size(#) save(filename) replace keepvars(varlist)]
```

| Option | Description |
|--------|-------------|
| `trials(numlist)` | Specific trial periods to emulate (default: all eligible) |
| `maxfollowup(#)` | Maximum follow-up periods |
| `grace(#)` | Grace period for non-adherence; default `0` |
| `chunk_size(#)` | IDs per processing chunk (for large data); default `0` (all in memory) |
| `save(filename)` | Save expanded dataset to disk |
| `keepvars(varlist)` | Additional variables to carry forward |

**What it does (PP/AT):**
1. At each eligible period *t*, identifies eligible individuals
2. Clones each into treatment arm (arm=1) and control arm (arm=0)
3. Follows forward through subsequent periods
4. Censors when observed treatment deviates from assigned arm (after the grace period)
5. Drops post-censoring rows

**For ITT:** No cloning or artificial censoring — each individual enters once per eligible period.

**Covariate freezing:** All covariates from `tte_prepare` are frozen at their trial-entry (period *t*) values. This ensures the MSM conditions on baseline covariates L₀ only. Treatment retains its observed time-varying values.

**Grace periods:** With `grace(1)`, a treatment-arm patient who stops treatment at follow-up 0 is not censored until follow-up 1. This accommodates brief non-adherence.

---

### tte_weight

Calculates stabilized inverse probability weights to adjust for the artificial censoring introduced by `tte_expand`. Required for PP and AT; skipped for ITT (weights = 1).

**Syntax:**
```stata
tte_weight [, switch_d_cov(varlist) switch_n_cov(varlist)
    censor_d_cov(varlist) censor_n_cov(varlist)
    pool_switch pool_censor truncate(numlist)
    stabilized generate(name) replace nolog]
```

**Switch models (treatment switching):**

| Option | Description |
|--------|-------------|
| `switch_d_cov(varlist)` | Covariates for switch denominator (more variables = less confounding bias) |
| `switch_n_cov(varlist)` | Covariates for switch numerator (fewer variables = more stable weights) |

**Censoring models (informative censoring):**

| Option | Description |
|--------|-------------|
| `censor_d_cov(varlist)` | Covariates for censoring denominator |
| `censor_n_cov(varlist)` | Covariates for censoring numerator |

**Other:**

| Option | Description |
|--------|-------------|
| `stabilized` | Stabilized weights (default; recommended) |
| `truncate(numlist)` | Truncate at percentiles, e.g., `truncate(1 99)` |
| `pool_switch` | Pool switch models across arms |
| `nolog` | Suppress logistic model iteration logs |

**Weight formula (stabilized):**

```
w = Pr(Aₜ | Aₜ₋₁, L₀) / Pr(Aₜ | Aₜ₋₁, L₀, Lₜ)
```

The numerator conditions on fewer covariates → weights are closer to 1 → reduced variance. Always include `switch_d_cov()` at minimum.

---

### tte_fit

Fits the marginal structural model. Supports pooled logistic regression (default) and Cox proportional hazards.

**Syntax:**
```stata
tte_fit [, outcome_cov(varlist) model(string)
    followup_spec(string) trial_period_spec(string)
    robust cluster(varname) level(#) nolog]
```

| Option | Description |
|--------|-------------|
| `outcome_cov(varlist)` | Covariates for the outcome model |
| `model(string)` | `logistic` (default) or `cox` |
| `followup_spec(string)` | `linear`, `quadratic` (default), `cubic`, `ns(#)`, or `none` |
| `trial_period_spec(string)` | `linear`, `quadratic`, `cubic`, `ns(#)`, or `none` |
| `robust` | Robust/sandwich SEs (on by default) |
| `cluster(varname)` | Cluster variable; default is patient ID |
| `nolog` | Suppress iteration log |

**Pooled logistic** (default): Fits `glm outcome arm [time terms] [covariates] [pw=weight], family(binomial) link(logit) vce(cluster id)`. The treatment effect coefficient (on `arm`) is the log odds ratio for being assigned to treatment vs. control.

**Cox MSM**: Sets up survival data with `stset` and fits `stcox` with `pweight`s and clustered SEs.

**Natural splines:** `followup_spec(ns(3))` creates restricted cubic splines with 3 interior knots at equally spaced quantiles. More flexible than polynomial terms for long follow-up.

---

### tte_predict

Generates marginal cumulative incidence or survival curves with Monte Carlo confidence intervals.

**Syntax:**
```stata
tte_predict, times(numlist)
    [type(string) samples(#) seed(#) level(#) difference]
```

| Option | Description |
|--------|-------------|
| `times(numlist)` | Follow-up times for prediction (**required**) |
| `type(string)` | `cum_inc` (default) or `survival` |
| `samples(#)` | MC samples for CIs; default `100` (use 500+ for publication) |
| `seed(#)` | Random seed for reproducibility |
| `difference` | Also compute risk differences between arms |

**How it works:**
1. Draws `samples` coefficient vectors from MVN(b, V)
2. For each draw, iterates through every follow-up time computing cumulative incidence:
   `P(T <= t) = P(T <= t-1) + [1 - P(T <= t-1)] * h(t)`
3. Averages over the reference population (all observations at follow-up = 0)
4. Takes pointwise percentile CIs across draws

**Risk differences:** With `difference`, returns `r(rd_#)` scalars for the risk difference at each requested time.

---

### tte_diagnose

Weight diagnostics and covariate balance assessment.

**Syntax:**
```stata
tte_diagnose [, balance_covariates(varlist) weight_summary
    by_trial by_period export(filename)]
```

| Option | Description |
|--------|-------------|
| `balance_covariates(varlist)` | Covariates for SMD balance checks |
| `weight_summary` | Show weight summary statistics (default if weights exist) |
| `by_trial` | Break down weight distribution by trial period |
| `by_period` | Break down by follow-up period |
| `export(filename)` | Export diagnostics to file |

Reports: mean/SD/min/max weights, effective sample size, unweighted vs. weighted standardized mean differences.

---

### tte_plot

Diagnostic and results visualizations.

**Syntax:**
```stata
tte_plot [, type(string) by(varname) ci scheme(string)
    title(string) export(filename) replace]
```

| Type | What it plots |
|------|---------------|
| `km` | Kaplan-Meier survival curves |
| `cumhaz` | Cumulative incidence from `tte_predict` |
| `weights` | Weight distribution histograms by arm |
| `balance` | Love plot (SMDs from `tte_diagnose`) |

---

### tte_report

Publication-quality results tables.

**Syntax:**
```stata
tte_report [, format(string) export(filename) decimals(#)
    eform ci_separator(string) title(string) replace
    predictions(name)]
```

| Option | Description |
|--------|-------------|
| `format(string)` | `display` (default), `csv`, or `excel` |
| `export(filename)` | Save to file |
| `eform` | Exponentiate coefficients (show OR/HR instead of log) |
| `decimals(#)` | Decimal places; default `3` |
| `predictions(name)` | Include prediction matrix from `tte_predict` |

---

### tte_protocol

Generates the Hernán & Robins 7-component target trial specification table. Supports auto-fill from dataset metadata or fully manual specification.

**Syntax:**
```stata
tte_protocol, eligibility(string) treatment(string) assignment(string)
    followup_start(string) outcome(string) causal_contrast(string)
    analysis(string) [export(filename) format(string) title(string) replace]
```

All 7 components are required:

| Component | What to specify |
|-----------|----------------|
| `eligibility()` | Who is eligible for the trial |
| `treatment()` | Treatment strategies being compared |
| `assignment()` | How treatment is assigned |
| `followup_start()` | When follow-up begins (time zero) |
| `outcome()` | Outcome of interest |
| `causal_contrast()` | ITT, PP, or AT effect |
| `analysis()` | Statistical approach |

Export formats: `display` (console), `csv`, `excel`, `latex`.

![Protocol table](demo/protocol.png)

---

### tte_calibrate

Calibrates a treatment effect estimate using negative control outcomes (NCOs). Implements the empirical calibration algorithm from Schuemie et al. (2014), as used in the OHDSI EmpiricalCalibration R package. Standalone — does not require expanded data.

**Syntax:**
```stata
tte_calibrate, estimate(#) se(#) nco_estimates(matname)
    [method(string) level(#) null(#)]
```

**Required:**

| Option | Description |
|--------|-------------|
| `estimate(#)` | Primary log-effect estimate (e.g., log-OR or log-HR) |
| `se(#)` | Standard error of primary estimate |
| `nco_estimates(matname)` | Nx2 matrix of NCO estimates (col 1 = log-effect, col 2 = SE); minimum 3 NCOs |

**Optional:**

| Option | Description |
|--------|-------------|
| `method(string)` | Systematic error distribution; default `normal` |
| `level(#)` | Confidence level; default `95` |
| `null(#)` | Null hypothesis value; default `0` |

**How it works:** NCO estimates are modeled as draws from N(bias, se_k² + σ²). The bias and σ² are estimated by maximum likelihood (profile likelihood over σ², closed-form for bias). The calibrated estimate subtracts the estimated bias, and the calibrated SE inflates the original SE by the excess variance: calibrated SE = sqrt(SE² + σ²).

---

## Worked Example: ITT Analysis

Intention-to-treat: everyone analyzed as initially assigned, regardless of subsequent treatment changes. No weights needed.

```stata
* Load the trial_example dataset (503 patients, 48,400 person-periods)
use tte_example, clear

* Step 1: Map variables and set estimand
tte_prepare, id(patid) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(age sex comorbidity biomarker) estimand(ITT)

* Step 2: Validate data quality
tte_validate

* Step 3: Expand into sequential trials (no cloning for ITT)
tte_expand, maxfollowup(8)

* Step 4: Fit pooled logistic MSM
*   - Quadratic terms for follow-up time and trial period (default)
*   - Robust SEs clustered by patient ID (default)
tte_fit, outcome_cov(age sex comorbidity) nolog

* Step 5: Predict cumulative incidence at each follow-up period
tte_predict, times(0(1)8) type(cum_inc) difference ///
    samples(100) seed(12345)

* Step 6: Plot and report
tte_plot, type(cumhaz) ci title("Cumulative Incidence (ITT)")
tte_report, eform
```

![Cumulative incidence — ITT](demo/cumulative_incidence_itt.png)

![Report table — ITT](demo/tte_report_itt.png)

---

## Worked Example: Per-Protocol Analysis with IPTW

Per-protocol: censor individuals who deviate from their assigned treatment, then reweight with IPTW to adjust for the informative censoring. This is the clone-censor-weight approach.

```stata
use tte_example, clear

* Step 1: Prepare (same as ITT but estimand = PP)
tte_prepare, id(patid) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(age sex comorbidity biomarker) estimand(PP)

* Step 2: Validate
tte_validate

* Step 3: Expand — clones each person into treatment and control arms,
*   censors when observed treatment deviates from assigned arm
tte_expand, maxfollowup(8)

* Step 4: Calculate stabilized IP weights
*   - Denominator model: all covariates (captures confounding)
*   - Numerator model: subset of covariates (stabilizes weights)
*   - Truncate at 1st/99th percentiles (reduces extreme weights)
tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
    switch_n_cov(age sex) ///
    stabilized truncate(1 99) nolog

* Step 5: Check weight diagnostics
tte_diagnose, balance_covariates(age sex comorbidity biomarker)

* Step 6: Fit weighted outcome model
tte_fit, outcome_cov(age sex comorbidity) nolog

* Step 7: Predict and report
tte_predict, times(0(1)8) type(cum_inc) difference ///
    samples(100) seed(12345)

tte_plot, type(cumhaz) ci title("Cumulative Incidence (Per-Protocol)")
tte_plot, type(weights) title("IPTW Distribution by Arm")

tte_report, format(excel) export(tte_results.xlsx) replace
```

![Cumulative incidence — PP](demo/cumulative_incidence_pp.png)

![Weight distribution](demo/weight_distribution.png)

![Report table — PP](demo/tte_report_pp.png)

---

## Worked Example: NHEFS Smoking Cessation (What If)

Replicates the analysis from Hernán & Robins, *Causal Inference: What If* (2020), Chapters 12 and 17. The NHEFS dataset (1,629 smokers from NHANES I, 1971–1975) asks: does smoking cessation reduce mortality over 10 years?

This is a point-treatment analysis (everyone eligible at baseline), so it demonstrates the TTE framework applied to a single-enrollment cohort. Companion R scripts in `demo/` replicate the same analysis with R `TrialEmulation` and R `emulate` for cross-platform benchmarking.

```stata
* Load NHEFS (restructured to person-period format)
use tte/qa/data/nhefs_personperiod, clear

* Step 1: Define the target trial protocol
tte_protocol, ///
    eligibility("Smokers aged 25-74 in NHANES I with complete confounders") ///
    treatment("Quit smoking vs. continue smoking, sustained through 1982") ///
    assignment("Baseline observed smoking cessation behavior") ///
    followup_start("1983 (after treatment assessment)") ///
    outcome("All-cause mortality through 1992") ///
    causal_contrast("ITT and per-protocol") ///
    analysis("Pooled logistic MSM, robust SE clustered by individual")

* Step 2: ITT analysis
tte_prepare, id(seqn) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(age_std sex race smoke_cat wt71_std ///
        smokeyrs_std exercise active education) estimand(ITT)
tte_validate
tte_expand
tte_fit, outcome_cov(age_std sex race smoke_cat wt71_std ///
    smokeyrs_std exercise active education) ///
    followup_spec(quadratic) trial_period_spec(none) nolog
tte_predict, times(0(1)9) type(cum_inc) difference samples(200) seed(20200101)

* Step 3: Visualize
tte_plot, type(cumhaz) ci title("NHEFS: Mortality by Smoking Status (ITT)")
tte_report, eform
```

**Cross-platform comparison scripts:**

| Script | Package | Language |
|--------|---------|----------|
| `demo/demo_whatif.do` | `tte` | Stata |
| `demo/demo_whatif_trialemulation.R` | `TrialEmulation` | R |
| `demo/demo_whatif_emulate.R` | `emulate` | R |

---

## Technical Notes

### Covariate freezing

After `tte_expand`, all covariates from `tte_prepare` carry their trial-entry values. The MSM conditions on L₀ only; time-varying confounding is handled by the IP weights. Treatment retains its observed time-varying values throughout follow-up.

### Weight model stratification

Switch models are fitted separately by arm (2 strata). R TrialEmulation uses 4 strata (arm x lagged treatment). Both are valid and produce the same causal estimand when correctly specified.

### Robust SE differences vs. R

Stata's `vce(cluster)` uses a G/(G-1) finite-sample correction. R's `sandwich::vcovCL()` uses (N-1)/(N-k). Point estimates are identical; SEs differ slightly. The difference is negligible for N > 500.

### Natural spline basis

`followup_spec(ns(#))` uses restricted cubic splines (Harrell formulation). R uses `splines::ns()`. Both span the same function space but use different basis representations — individual coefficients differ, but marginal predictions from `tte_predict` are comparable.

### Monte Carlo predictions

CIs from `tte_predict` capture coefficient uncertainty only (parametric bootstrap on the MSM coefficients). They do not propagate uncertainty from the weight estimation step. This matches R TrialEmulation's approach.

---

## Features Beyond R TrialEmulation

| Feature | R TrialEmulation | tte (Stata) |
|---------|-----------------|-------------|
| Pooled logistic regression | Yes | Yes |
| Cox / parametric survival MSM | No | Yes |
| Protocol table (Hernán 7-component) | No | Yes |
| Data validation command | No | Yes (`tte_validate`, 10 checks) |
| Publication report generation | No | Yes (display/Excel/CSV/LaTeX) |
| Love plot / balance diagnostics | No | Yes (`tte_diagnose`) |
| Weight distribution plots | No | Yes (`tte_plot, type(weights)`) |
| Grace period handling | Limited | Full (integer grace periods) |
| Natural spline support | Via R formula | Built-in `ns(#)` option |
| Chunked processing for large data | No | Yes (`chunk_size()`) |

---

## Stored Results

### tte_prepare → r()

| Result | Description |
|--------|-------------|
| `r(N)` | Number of observations |
| `r(n_ids)` | Unique individuals |
| `r(n_periods)` | Distinct time periods |
| `r(n_eligible)` | Eligible observations |
| `r(n_events)` | Outcome events |
| `r(n_censored)` | Censored observations |
| `r(n_treated)` | Treated observations |
| `r(estimand)` | Estimand (ITT/PP/AT) |

### tte_validate → r()

| Result | Description |
|--------|-------------|
| `r(n_checks)` | Checks run |
| `r(n_errors)` | Errors found |
| `r(n_warnings)` | Warnings found |
| `r(validation)` | `"passed"` or `"failed"` |

### tte_expand → r()

| Result | Description |
|--------|-------------|
| `r(n_trials)` | Emulated trials created |
| `r(n_expanded)` | Total expanded observations |
| `r(n_treat)` | Treatment arm observations |
| `r(n_control)` | Control arm observations |
| `r(n_censored)` | Censored observations |
| `r(n_events)` | Outcome events |
| `r(expansion_ratio)` | Expansion ratio |

### tte_weight → r()

| Result | Description |
|--------|-------------|
| `r(mean_weight)` | Mean weight |
| `r(sd_weight)` | SD of weights |
| `r(min_weight)` / `r(max_weight)` | Range |
| `r(ess)` | Effective sample size |
| `r(n_truncated)` | Truncated weights |

### tte_fit → e()

Standard `glm` or `stcox` results, plus:

| Result | Description |
|--------|-------------|
| `e(tte_model)` | `"logistic"` or `"cox"` |
| `e(tte_estimand)` | ITT, PP, or AT |
| `e(tte_followup_spec)` | Follow-up time specification |
| `e(tte_trial_spec)` | Trial period specification |

### tte_predict → r()

| Result | Description |
|--------|-------------|
| `r(predictions)` | Matrix: time, est_0, ci_lo_0, ci_hi_0, est_1, ci_lo_1, ci_hi_1 [, diff, diff_lo, diff_hi] |
| `r(rd_#)` | Risk difference at time # (with `difference`) |
| `r(n_times)` | Number of prediction times |
| `r(samples)` | MC samples used |

### tte_diagnose → r()

| Result | Description |
|--------|-------------|
| `r(ess)` | Effective sample size (overall) |
| `r(ess_treat)` / `r(ess_control)` | ESS by arm |
| `r(max_smd_unwt)` | Max unweighted SMD |
| `r(max_smd_wt)` | Max weighted SMD |
| `r(balance)` | Covariate balance matrix |

### tte_calibrate → r()

| Result | Description |
|--------|-------------|
| `r(estimate)` | Primary estimate (uncalibrated) |
| `r(se)` | Primary SE (uncalibrated) |
| `r(ci_lo)` / `r(ci_hi)` | Uncalibrated CI bounds |
| `r(pvalue)` | Uncalibrated p-value |
| `r(bias)` | Estimated systematic bias |
| `r(sigma)` | Estimated systematic error SD |
| `r(n_nco)` | Number of negative control outcomes |
| `r(cal_estimate)` | Calibrated estimate |
| `r(cal_se)` | Calibrated SE |
| `r(cal_ci_lo)` / `r(cal_ci_hi)` | Calibrated CI bounds |
| `r(cal_pvalue)` | Calibrated p-value |

---

## Demo Output

The demo runs both ITT and PP analyses on the `tte_example` dataset and benchmarks against R TrialEmulation reference results.

<details>
<summary>Console output (click to expand)</summary>

![Console output](demo/console_output.png)

</details>

---

## Testing

The `qa/` directory contains **306+ tests** across 3 test suites, all passing.

| Suite | Tests | Focus |
|-------|------:|-------|
| `test_tte.do` | 163 | Functional tests — every command, option, and error path |
| `validation_tte.do` | 143 | 24 validation modules (V1–V24) |
| `crossval_tte.do` | — | Cross-validation configurations (Stata vs R emulate vs R TrialEmulation) |

### Functional tests (163 tests)

End-to-end coverage of all 12 commands: `tte_prepare`, `tte_validate`, `tte_expand`, `tte_weight`, `tte_fit`, `tte_predict`, `tte_diagnose`, `tte_report`, `tte_protocol`, `tte_plot`, `tte_calibrate`, and the `tte` overview. Covers ITT/PP/AT estimands, pooled logistic and Cox models, natural spline specifications, error handling, and full pipeline integration.

### Validation suite (143 tests across 24 modules)

Run with `stata-mp -b do validation_tte.do` (supports selective execution: `do validation_tte.do 1 5 13`).

#### V1–V5: External benchmarks (27 tests)

- **V1 — R TrialEmulation cross-validation:** Cross-validates against R `TrialEmulation` (Maringe et al. 2024) using the shared trial_example dataset (503 patients, 48,400 person-periods). ITT treatment coefficients agree within 3.2% (R: −0.273, Stata: −0.282), robust SEs within 1%.
- **V2 — NHEFS smoking cessation:** Replicates the Hernán & Robins *Causal Inference: What If* NHEFS analysis (N=1,629). Smoking cessation correctly shows a protective effect on mortality. Both pooled logistic and Cox models agree on direction, with ORs in the plausible range [0.3, 1.5].
- **V3 — Clone-censor-weight / immortal-time bias:** Simulates 2,000 lung cancer surgery patients over 24 periods (true HR = 0.60, based on Maringe et al. 2020 IJE). The clone-censor-weight estimate recovers the true effect while the naive analysis demonstrates residual immortal-time bias.
- **V4 — G-formula / time-varying confounding:** Simulates 5,000 HIV/ART patients with CD4 as a time-varying confounder (true OR = 0.449, based on Daniel et al. 2011 Stata Journal). The unadjusted estimate shows confounding by indication; the ITT estimate reverses this, recovering the true protective effect.
- **V5 — Known DGP Monte Carlo:** Large-sample (N=10,000) and 50-replication Monte Carlo with true log-OR = −0.50. Empirical 95% CI coverage is 94%. All time specifications (quadratic, cubic, natural splines) produce consistent estimates.

#### V6–V12: Statistical properties (43 tests)

- **V6 — Null effect / reproducibility:** Type I error ≤ 15% at α = 0.05; seed reproducibility to reldiff < 1e-10
- **V7 — IPCW:** Informative censoring correction improves estimates toward truth
- **V8 — Grace periods:** Monotonic censoring reduction with increasing grace period
- **V9 — Edge cases:** Small samples, single-period eligibility, all-treated scenarios
- **V10 — AT estimand:** As-treated approximates per-protocol within 0.5
- **V11 — RCT benchmarks:** Validates against `teffects ra` on randomized data
- **V12 — Sensitivity/stress:** Truncation robustness, N=50,000 stress test

#### V13–V17: Code path validation (33 tests)

Cox model ground truth (V13), `tte_expand` options (V14), `tte_predict` reproducibility (V15), `tte_diagnose`/`tte_report` output (V16), and pipeline guard enforcement (V17).

#### V18–V24: Advanced validation (40 tests)

- **V18 — Three-way cross-validation:** Stata tte vs R emulate vs R TrialEmulation
- **V19 — Formal equivalence (TOST):** Two one-sided tests for parameter equivalence
- **V20 — Cox PH gold-standard:** Ground truth validation for Cox models
- **V21 — Row-level pipeline conservation:** Data conservation through expansion pipeline
- **V22 — Row-level trajectory validation:** Per-individual trajectory correctness
- **V23 — Spline specification equivalence:** Boundary knot behavior (RCS vs ns)
- **V24 — Boundary and zero-event edge cases:** Zero events, boundary conditions, extreme data

### Cross-validation suite

Benchmarks Stata `tte` against R `emulate` and R `TrialEmulation` across 30+ configurations (ITT/PP/AT, logistic/Cox, linear/quadratic/cubic/ns(3)) on 6 datasets. Outputs comparison tables to `crossval_results/` for automated regression detection.

## References

- Hernán MA, Robins JM. Using Big Data to Emulate a Target Trial When a Randomized Trial Is Not Available. *Am J Epidemiol*. 2016;183(8):758-764.
- Hernán MA, Robins JM. *Causal Inference: What If*. Boca Raton: Chapman & Hall/CRC; 2020.
- Maringe C, Benitez Majano S, et al. TrialEmulation: An R Package for Target Trial Emulation. *arXiv*. 2024;2402.12083.

## Authors

Timothy P Copeland
Department of Clinical Neuroscience
Karolinska Institutet

Tania F Reza
Department of Global Public Health
Karolinska Institutet

## License

MIT License

## Version

Version 1.1.0, 2026-03-15
