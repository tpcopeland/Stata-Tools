# msm — Marginal Structural Models for Stata

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue)

**Version 1.0.0** | 2026-04-08

A comprehensive suite for estimating marginal structural models (MSM) using inverse probability of treatment weighting (IPTW) for time-varying treatments and confounders. Implements the complete pipeline from Robins, Hernan & Brumback (2000).

## Table of Contents

- [Installation](#installation)
- [Why MSMs?](#why-msms)
- [Quick Start](#quick-start)
- [Commands](#commands)
- [The Pipeline](#the-pipeline)
- [Command Reference](#command-reference)
  - [msm_prepare](#msm_prepare)
  - [msm_validate](#msm_validate)
  - [msm_weight](#msm_weight)
  - [msm_diagnose](#msm_diagnose)
  - [msm_fit](#msm_fit)
  - [msm_predict](#msm_predict)
  - [msm_plot](#msm_plot)
  - [msm_report](#msm_report)
  - [msm_table](#msm_table)
  - [msm_protocol](#msm_protocol)
  - [msm_sensitivity](#msm_sensitivity)
- [Worked Example](#worked-example)
- [Stored Results](#stored-results)
- [Demo Output](#demo-output)
- [References](#references)
- [Version](#version)

---

## Installation

```stata
net install msm, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/msm")
```

The package includes `msm_example.dta` for testing.

**Requirements:** Stata 16+
Plots use the current Stata scheme by default.

---

## Why MSMs?

Standard regression adjustment fails when time-varying confounders are simultaneously:
1. Affected by prior treatment (mediators)
2. Predictive of future treatment (confounders)

Conditioning on these variables introduces collider bias; not conditioning introduces confounding bias. There is no correct regression adjustment.

MSMs solve this by using IPTW to create a pseudo-population where treatment is independent of measured confounders. The weighted outcome model then estimates the causal effect free of time-varying confounding.

---

## Quick Start

```stata
findfile msm_example.dta
use "`r(fn)'", clear

* 1. Prepare
msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) covariates(biomarker comorbidity) ///
    baseline_covariates(age sex)

* 2. Validate
msm_validate, strict verbose

* 3. Weight
msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
    treat_n_cov(age sex) truncate(1 99) nolog

* 4. Diagnose
msm_diagnose, by_period threshold(0.1)

* 5. Fit
msm_fit, model(logistic) outcome_cov(age sex) nolog

* 6. Predict
msm_predict, times(3 5 7 9) difference seed(12345)

* 7. Sensitivity
msm_sensitivity, evalue

* 8. Export
msm_table, xlsx(msm_results.xlsx) all replace
```

---

## Commands

| Command | Purpose |
|---------|---------|
| `msm` | Package overview and workflow guide |
| `msm_prepare` | Map variables and store metadata |
| `msm_validate` | 10 data quality checks |
| `msm_weight` | Stabilized IPTW (+ optional IPCW) |
| `msm_diagnose` | Weight distributions and covariate balance |
| `msm_fit` | Weighted outcome model (logistic/linear/Cox) |
| `msm_predict` | Counterfactual predictions with CIs |
| `msm_plot` | Weight, balance, survival, trajectory, positivity plots |
| `msm_report` | Publication results tables |
| `msm_table` | Multi-sheet Excel export |
| `msm_protocol` | MSM study protocol (7 components) |
| `msm_sensitivity` | E-value and confounding bounds |

---

## The Pipeline

```
                        ┌──────────────────┐
                        │  Person-period   │
                        │     data         │
                        └────────┬─────────┘
                                 │
                        ┌────────▼─────────┐
                  ┌─────│   msm_prepare    │  Map variables, store metadata
                  │     └────────┬─────────┘
                  │              │
                  │     ┌────────▼─────────┐
                  │     │   msm_validate   │  10 data quality checks
                  │     └────────┬─────────┘
                  │              │
  msm_protocol ───┤     ┌────────▼─────────┐
  (any time)      │     │   msm_weight     │  Stabilized IPTW (+IPCW)
                  │     └────────┬─────────┘
                  │              │
                  │     ┌────────▼─────────┐
                  │     │   msm_diagnose   │  Weight dist. + balance
                  │     └────────┬─────────┘
                  │              │
                  │     ┌────────▼─────────┐
                  │     │   msm_fit        │  Weighted outcome model
                  │     └────────┬─────────┘
                  │              │
                  │     ┌────────▼─────────┐
                  │     │   msm_predict    │  Counterfactual outcomes
                  │     └────────┬─────────┘
                  │              │
                  │     ┌────────▼──────────────────┐
                  └─────│   msm_report / msm_table  │  Publication output
                        │   msm_sensitivity         │  E-values
                        │   msm_plot                │  Visualization
                        └───────────────────────────┘
```

---

## Command Reference

### msm_prepare

Entry point. Maps your variable names to internal names and stores metadata for downstream commands.

**Syntax:**
```stata
msm_prepare, id(varname) period(varname) treatment(varname)
    outcome(varname) [censor(varname) covariates(varlist)
    baseline_covariates(varlist)]
```

| Option | Description |
|--------|-------------|
| `id(varname)` | Individual identifier (**required**) |
| `period(varname)` | Time period variable, integer (**required**) |
| `treatment(varname)` | Binary treatment indicator, 0/1 (**required**) |
| `outcome(varname)` | Binary outcome indicator, 0/1 (**required**) |
| `censor(varname)` | Binary censoring indicator |
| `covariates(varlist)` | Time-varying covariates |
| `baseline_covariates(varlist)` | Baseline-only covariates |

**Data requirements:** Person-period (long) format. One row per individual per time period. No duplicate `(id, period)` combinations. Treatment and outcome must be binary 0/1. `baseline_covariates()` must be time-fixed within individual, and delayed entry is not currently supported: all individuals must share the common baseline period.

---

### msm_validate

Runs 10 data quality checks on the prepared data.

**Syntax:**
```stata
msm_validate [, strict verbose]
```

| Option | Description |
|--------|-------------|
| `strict` | Treat warnings as errors |
| `verbose` | Show detailed diagnostics with counts |

**Checks:**
1. Person-period format
2. Gaps in period sequences
3. Terminal outcome (no follow-up after outcome)
4. Treatment variation
5. Missing data
6. Sufficient observations per period
7. Covariate completeness
8. Treatment history patterns
9. Censoring patterns
10. Positivity by period

---

### msm_weight

Calculates stabilized inverse probability of treatment weights (IPTW) and optionally censoring weights (IPCW).

**Syntax:**
```stata
msm_weight, treat_d_cov(varlist)
    [treat_n_cov(varlist) censor_d_cov(varlist) censor_n_cov(varlist)
    truncate(numlist) replace nolog]
```

| Option | Description |
|--------|-------------|
| `treat_d_cov(varlist)` | Treatment denominator covariates (**required**) |
| `treat_n_cov(varlist)` | Treatment numerator covariates (stabilization) |
| `censor_d_cov(varlist)` | Censoring denominator covariates |
| `censor_n_cov(varlist)` | Censoring numerator covariates |
| `truncate(numlist)` | Truncation percentiles, e.g., `truncate(1 99)` |
| `replace` | Replace existing weight variables |
| `nolog` | Suppress logistic iteration logs |

**Weight formula (stabilized):**

```
w_t = ∏ [ Pr(A_t | A_{t-1}, V) / Pr(A_t | A_{t-1}, L_t, V) ]
```

`msm_weight` now distinguishes perfect prediction from incomplete inputs. If a
complete-case treatment or censoring stratum is perfectly predicted, the
command uses truncated observed probabilities for that stratum rather than
dropping it or defaulting the weight factor to 1. If required weighting inputs
are genuinely missing, cumulative weights become missing from that period
forward.

The denominator model conditions on lagged treatment, period, and the covariates you pass in `treat_d_cov()`. The numerator model conditions on lagged treatment plus the covariates you pass in `treat_n_cov()`. If you need richer history terms, construct them explicitly and include them in the model. Weights are accumulated as a cumulative product across periods within each individual, using log-sums for numerical stability.

**Created variables:** `_msm_weight` (combined), `_msm_tw_weight` (treatment), `_msm_cw_weight` (censoring, if applicable).

---

### msm_diagnose

Weight distribution summaries and covariate balance assessment.

**Syntax:**
```stata
msm_diagnose [, balance_covariates(varlist) by_period threshold(#)]
```

| Option | Description |
|--------|-------------|
| `balance_covariates(varlist)` | Covariates for SMD balance checks |
| `by_period` | Show weight statistics by time period |
| `threshold(#)` | SMD threshold for balance; default `0.1` |

Reports: mean/SD/min/max weights, effective sample size, unweighted vs. weighted standardized mean differences.

---

### msm_fit

Fits the weighted outcome model.

**Syntax:**
```stata
msm_fit [, model(string) outcome_cov(varlist) period_spec(string)
    cluster(varname) bootstrap(#) level(#) nolog]
```

| Option | Description |
|--------|-------------|
| `model(string)` | `logistic` (default), `linear`, or `cox` |
| `outcome_cov(varlist)` | Additional time-fixed outcome covariates; use baseline-only covariates if you plan to run `msm_predict` |
| `period_spec(string)` | `linear`, `quadratic` (default), `cubic`, `ns(#)`, or `none` |
| `cluster(varname)` | Cluster variable; default is patient ID |
| `bootstrap(#)` | Bootstrap replicates (0 = no bootstrap; currently not implemented) |
| `level(#)` | Confidence level; default `95` |
| `nolog` | Suppress iteration log |

**Logistic** (default): `glm outcome treatment [period terms] [covariates] [pw=weight], family(binomial) link(logit) vce(cluster id)`

**Linear**: `regress outcome treatment [covariates] [pw=weight], vce(cluster id)`

**Cox**: `stcox treatment [covariates] [pw=weight], vce(cluster id)`

---

### msm_predict

Counterfactual predictions under always-treated and never-treated strategies.

**Syntax:**
```stata
msm_predict, times(numlist)
    [strategy(string) type(string) samples(#) seed(#)
    level(#) difference extrapolate]
```

| Option | Description |
|--------|-------------|
| `times(numlist)` | Time periods for prediction (**required**) |
| `strategy(string)` | `always`, `never`, or `both` (default) |
| `type(string)` | `cum_inc` (default) or `survival` |
| `samples(#)` | MC samples for CIs; default `100` |
| `seed(#)` | Random seed |
| `level(#)` | Confidence level; default `95` |
| `difference` | Compute risk differences |
| `extrapolate` | Allow prediction beyond the maximum observed period |

`msm_predict` currently supports logistic outcome models only. It uses G-formula standardization over the baseline reference population, so any `outcome_cov()` terms are held at their baseline values during prediction. Do not use time-varying covariates in `outcome_cov()` if you plan to run `msm_predict`.

---

### msm_plot

Diagnostic and results visualizations.

**Syntax:**
```stata
msm_plot, type(string) [covariates(varlist) threshold(#) times(numlist)
    samples(#) seed(#) n_sample(#) title(string) saving(string) replace]
```

| Type | What it plots |
|------|---------------|
| `weights` | IP weight density by treatment group |
| `balance` | Love plot: SMD before and after weighting |
| `survival` | Cumulative incidence under always/never strategies |
| `trajectory` | Treatment spaghetti plot (individual trajectories) |
| `positivity` | Treatment probability by period |

`msm_plot` uses the current Stata scheme by default.

---

### msm_report

Publication results tables (console, Excel, or CSV).

**Syntax:**
```stata
msm_report [, export(string) format(string) decimals(#) eform replace
    title(string) font(name) fontsize(#) borderstyle(style)
    zebra footnote(string) open]
```

| Option | Description |
|--------|-------------|
| `export(string)` | File path for export (required for `csv`/`excel`) |
| `format(string)` | `display` (default), `csv`, or `excel` |
| `eform` | Exponentiate coefficients (OR/HR) |
| `decimals(#)` | Decimal places; default `4` |
| `replace` | Replace existing file |
| `title(string)` | Title for cell A1 (Excel only) |
| `font(name)` | Font name; default `Arial` (Excel only) |
| `fontsize(#)` | Font size in points; default `10` (Excel only) |
| `borderstyle(style)` | `thin` (default), `medium`, or `academic` (Excel only) |
| `zebra` | Alternating row shading (Excel only) |
| `footnote(string)` | Merged footnote below table (Excel only) |
| `open` | Auto-open file after export (Excel only) |

---

### msm_table

Multi-sheet Excel export of the complete analysis.

**Syntax:**
```stata
msm_table, xlsx(filename)
    [coefficients predictions balance weights sensitivity all
    eform decimals(#) sep(string) title(string) replace
    font(name) fontsize(#) borderstyle(style) nformat(string)
    zebra boldp(#) highlight(#) footnote(string) open]
```

| Option | Description |
|--------|-------------|
| `xlsx(filename)` | Excel output file (**required**) |
| `all` | Export all available tables (default) |
| `coefficients` | Model coefficients sheet |
| `predictions` | Counterfactual predictions sheet |
| `balance` | Covariate balance sheet |
| `weights` | Weight distribution sheet |
| `sensitivity` | E-value sensitivity sheet |
| `eform` | Exponentiate coefficients |
| `decimals(#)` | Decimal places; default `3` |
| `sep(string)` | CI delimiter; default `", "` |
| `title(string)` | Title for cell A1 |
| `replace` | Replace existing file |
| `font(name)` | Font name; default `Arial` |
| `fontsize(#)` | Font size in points; default `10` |
| `borderstyle(style)` | `thin` (default), `medium`, or `academic` |
| `nformat(string)` | Excel number format for numeric cells |
| `zebra` | Alternating row shading |
| `boldp(#)` | Bold p-values below threshold (Coefficients only) |
| `highlight(#)` | Highlight rows where p < threshold (Coefficients only) |
| `footnote(string)` | Merged footnote below each table |
| `open` | Auto-open file after export |

Each sheet gets professional formatting: Arial 10, borders, bold headers, centered numerics.

---

### msm_protocol

Documents the MSM study protocol using 7 components adapted from the Hernan framework.

**Syntax:**
```stata
msm_protocol, population(string) treatment(string) confounders(string)
    outcome(string) causal_contrast(string) weight_spec(string)
    analysis(string) [export(string) format(string) replace]
```

All 7 components are required:

| Component | What to specify |
|-----------|----------------|
| `population()` | Target population |
| `treatment()` | Treatment strategies compared |
| `confounders()` | Measured confounders |
| `outcome()` | Outcome definition |
| `causal_contrast()` | Causal contrast of interest |
| `weight_spec()` | Weight specification |
| `analysis()` | Statistical analysis plan |

Export formats: `display`, `csv`, `excel`, `latex`.

---

### msm_sensitivity

Assesses sensitivity to unmeasured confounding.

**Syntax:**
```stata
msm_sensitivity [, evalue confounding_strength(# #) level(#)]
```

| Option | Description |
|--------|-------------|
| `evalue` | Compute E-value (default; available for logistic and Cox fits) |
| `confounding_strength(# #)` | RR(U,D) and RR(U,Y) for bias factor |
| `level(#)` | Confidence level; default `95` |

**E-value** (VanderWeele & Ding 2017): minimum strength of association that an unmeasured confounder would need with both treatment and outcome to fully explain the observed effect. E-values are reported for logistic and Cox fits; linear models support `confounding_strength()` bounds but not E-values.

---

## Worked Example

Full pipeline for a time-varying treatment analysis.

```stata
findfile msm_example.dta
use "`r(fn)'", clear

* Document study design
msm_protocol, ///
    population("Adults aged 18-65 with condition X") ///
    treatment("Always treat vs. never treat") ///
    confounders("Biomarker (time-varying), comorbidity (time-varying), age, sex") ///
    outcome("Binary clinical endpoint") ///
    causal_contrast("ATE: always treat vs. never treat") ///
    weight_spec("Stabilized IPTW, truncated at 1st/99th percentile") ///
    analysis("Pooled logistic regression, robust SE clustered by ID")

* Step 1: Prepare — map variables, store metadata
msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) covariates(biomarker comorbidity) ///
    baseline_covariates(age sex)

* Step 2: Validate — 10 data quality checks
msm_validate, strict verbose

* Step 3: Calculate stabilized IP weights
*   Denominator: all covariates (captures confounding)
*   Numerator: baseline covariates only (stabilizes weights)
msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
    treat_n_cov(age sex) truncate(1 99) nolog

* Step 4: Diagnose weights and balance
msm_diagnose, balance_covariates(biomarker comorbidity age sex) ///
    by_period threshold(0.1)

* Step 5: Fit weighted outcome model
msm_fit, model(logistic) outcome_cov(age sex) nolog

* Step 6: Predict counterfactual outcomes
msm_predict, times(1 3 5 7 9) type(cum_inc) difference ///
    samples(200) seed(12345)

* Step 7: Sensitivity analysis
msm_sensitivity, evalue

* Step 8: Visualize
msm_plot, type(survival) title("Cumulative Incidence: Always vs. Never Treat")
msm_plot, type(weights) title("IP Weight Distribution")
msm_plot, type(balance) covariates(biomarker comorbidity age sex)

* Step 9: Export everything to Excel
msm_table, xlsx(msm_results.xlsx) all eform replace
```

---

## Stored Results

### msm_prepare → r()

| Result | Description |
|--------|-------------|
| `r(N)` | Number of observations |
| `r(n_ids)` | Unique individuals |
| `r(n_periods)` | Distinct time periods |
| `r(n_events)` | Outcome events |
| `r(n_treated)` | Treated observations |
| `r(n_censored)` | Censored observations |
| `r(id)` | ID variable name |
| `r(period)` | Period variable name |
| `r(treatment)` | Treatment variable name |
| `r(outcome)` | Outcome variable name |
| `r(covariates)` | Time-varying covariates |
| `r(baseline_covariates)` | Baseline covariates |

### msm_validate → r()

| Result | Description |
|--------|-------------|
| `r(n_checks)` | Checks run |
| `r(n_errors)` / `r(n_warnings)` | Issues found |
| `r(validation)` | `"passed"` or `"failed"` |

### msm_weight → r()

| Result | Description |
|--------|-------------|
| `r(mean_weight)` | Mean weight |
| `r(sd_weight)` | SD of weights |
| `r(min_weight)` | Minimum weight |
| `r(p1_weight)` | 1st percentile weight |
| `r(median_weight)` | Median weight |
| `r(p99_weight)` | 99th percentile weight |
| `r(max_weight)` | Maximum weight |
| `r(ess)` | Effective sample size |
| `r(n_truncated)` | Number of truncated observations |
| `r(weight_var)` | Name of weight variable |

### msm_fit → e()

Standard `glm`/`regress`/`stcox` results, plus:

| Result | Description |
|--------|-------------|
| `e(msm_cmd)` | `"msm_fit"` |
| `e(msm_model)` | Model type (logistic, linear, or cox) |
| `e(msm_treatment)` | Treatment variable name |
| `e(msm_period_spec)` | Period specification used |
| `e(effects)` | 1 x 4 effect matrix: estimate, CI lower, CI upper, and p-value |

### msm_predict → r()

| Result | Description |
|--------|-------------|
| `r(predictions)` | Matrix of predictions per strategy and time |
| `r(rd_#)` | Risk difference at time # (with `difference`) |
| `r(n_times)` | Number of time points |
| `r(n_ref)` | Reference population size |
| `r(samples)` | MC samples used |
| `r(level)` | Confidence level |
| `r(type)` | Prediction type |
| `r(strategy)` | Strategy used |

### msm_diagnose → r()

| Result | Description |
|--------|-------------|
| `r(mean_weight)` | Mean weight |
| `r(sd_weight)` | SD of weights |
| `r(min_weight)` | Minimum weight |
| `r(max_weight)` | Maximum weight |
| `r(p1_weight)` | 1st percentile weight |
| `r(p99_weight)` | 99th percentile weight |
| `r(ess)` | Effective sample size (person-period level) |
| `r(ess_pct)` | ESS as percentage of total |
| `r(n_extreme)` | Number of extreme weight observations |
| `r(balance)` | Covariate balance matrix |

### msm_plot → r()

| Result | Description |
|--------|-------------|
| `r(plot_type)` | Plot type produced |

### msm_report → r()

| Result | Description |
|--------|-------------|
| `r(format)` | Output format |
| `r(export)` | Export file path |

### msm_table

No stored results. Writes directly to the Excel file.

### msm_protocol → r()

| Result | Description |
|--------|-------------|
| `r(population)` | Target population definition |
| `r(treatment)` | Treatment strategies compared |
| `r(confounders)` | Confounders measured |
| `r(outcome)` | Outcome definition |
| `r(causal_contrast)` | Causal contrast |
| `r(weight_spec)` | Weight specification |
| `r(analysis)` | Statistical analysis plan |
| `r(format)` | Output format |

### msm_sensitivity → r()

| Result | Description |
|--------|-------------|
| `r(evalue_point)` | E-value for point estimate |
| `r(evalue_ci)` | E-value for CI bound |
| `r(effect)` | Treatment effect estimate |
| `r(effect_lo)` | CI lower bound |
| `r(effect_hi)` | CI upper bound |
| `r(bias_factor)` | Bias factor (with `confounding_strength()`) |
| `r(corrected_effect)` | Corrected effect estimate (with `confounding_strength()`) |
| `r(rr_ud)` | Hypothetical RR(U,D) (with `confounding_strength()`) |
| `r(rr_uy)` | Hypothetical RR(U,Y) (with `confounding_strength()`) |

`r(evalue_point)` and `r(evalue_ci)` are returned for logistic and Cox fits only.

---

## Demo Output

### Counterfactual Cumulative Incidence

![Survival curves](demo/survival_plot.png)

### IP Weight Diagnostics

![Weight distribution](demo/weight_plot.png)

### Covariate Balance

![Balance plot](demo/balance_plot.png)

### Publication Tables

![Excel tables](demo/msm_tables.png)

<details>
<summary>Console output (click to expand)</summary>

![Console output — setup](demo/console_pipeline_setup_p1.png)

![Console output — diagnostics](demo/console_pipeline_diagnostics_p1.png)

![Console output — results](demo/console_pipeline_results_p1.png)

</details>

---

## Validation

The `qa/` directory contains **42 tests** across 6 validation modules, all passing. Run with `do run_all_validations.do`.

### V1: Known DGP — time-varying confounding (8 tests)

Simulates N=10,000 subjects over 10 periods with a true log-OR of −0.357 (OR=0.70) and treatment-confounder feedback (Cole & Hernan 2008). The MSM estimate recovers the true effect within ±0.15. A 30-replication Monte Carlo confirms coverage ≥80%. The naive (post-treatment conditioning) estimate is shown to be attenuated relative to the causal estimate. Stabilized weight means fall in [0.90, 1.10].

### V2: R `ipw` package — HAART dataset (6 tests)

Cross-validates against R `ipw` (van der Wal & Geskus 2011, JSS 43(13)) using 386 HIV-positive patients from the `haartdat` dataset. Stabilized weight means match R's `ipwtm()` output within 10% (R benchmark: 1.042). Treatment OR falls in the clinically plausible range [0.3, 3.0]. Truncation sensitivity confirms robustness.

### V3: NHEFS — Hernan & Robins textbook (8 tests)

Replicates Chapters 12 and 17 of *Causal Inference: What If* using the NHEFS dataset (N=1,566). Stabilized weight mean matches the published 0.999 (±0.01), weight SD matches 0.288 (±0.05), and the smoking cessation ATE matches the published 3.44 kg (±0.30). The 95% CI covers the textbook value. A person-period restructuring validates pooled logistic and Cox models.

### V4: Fewell RA/Methotrexate DGP (7 tests)

Replicates the Fewell et al. (2004, Stata Journal 4(4):402–420) simulation of N=5,000 subjects with disease activity as a time-varying confounder. The MSM estimate falls within 0.20 of the true log-OR (−0.50). Weighted SMDs are smaller than unweighted SMDs, confirming balance improvement. Weight SDs remain below 2.0.

### V5: Null effect and reproducibility (6 tests)

Tests type I error control under a null DGP (true log-OR = 0). Point estimates fall within ±0.20 of zero, 95% CIs cover the null, and the rejection rate across 100 Monte Carlo replications stays below 15%. Seed reproducibility is confirmed to relative precision < 1e-10 for coefficients and < 1e-8 for predictions.

### V6: IPCW — informative censoring (7 tests)

Simulates N=5,000 subjects with informative censoring (sicker patients censor more). IPTW+IPCW recovers the true effect (log-OR = −0.50) within ±0.30 and outperforms IPTW-only. Combined weight means fall in [0.85, 1.15] with ESS > 50%.

## References

- Robins JM, Hernan MA, Brumback B. Marginal structural models and causal inference in epidemiology. *Epidemiology*. 2000;11(5):550-560.
- Hernan MA, Brumback B, Robins JM. Marginal structural models to estimate the causal effect of zidovudine on the survival of HIV-positive men. *Epidemiology*. 2000;11(5):561-570.
- Hernan MA, Robins JM. *Causal Inference: What If*. Boca Raton: Chapman & Hall/CRC, 2020.
- Cole SR, Hernan MA. Constructing inverse probability weights for marginal structural models. *American Journal of Epidemiology*. 2008;168(6):656-664.
- Fewell Z, Hernan MA, Wolfe F, Tilling K, Choi H, Sterne JAC. Controlling for time-dependent confounding using marginal structural models. *Stata Journal*. 2004;4(4):402-420.
- van der Wal WM, Geskus RB. ipw: An R package for inverse probability weighting. *Journal of Statistical Software*. 2011;43(13):1-23.
- VanderWeele TJ, Ding P. Sensitivity analysis in observational research: introducing the E-value. *Annals of Internal Medicine*. 2017;167(4):268-274.

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT

## Version

Version 1.0.0, 2026-04-08
