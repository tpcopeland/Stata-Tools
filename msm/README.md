# msm - Marginal structural models for longitudinal causal analysis

**Version 1.0.0** | 2026-04-08

`msm` is a Stata suite for inverse-probability-weighted marginal structural models in person-period data. It is designed for longitudinal settings with time-varying treatments and confounders, where standard regression adjustment can be biased by treatment-confounder feedback.

The package covers the full workflow for conventional static-regime MSM analyses: study protocol specification, variable mapping, validation, stabilized weighting, diagnostics, outcome modeling, counterfactual prediction, plotting, reporting, Excel export, and sensitivity analysis.

## Requirements

- Stata 16 or later

## Installation

```stata
capture ado uninstall msm
net install msm, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/msm") replace
```

The release installs `msm_example.dta`, which the examples below access with `findfile`.

## Commands

### Setup and validation

| Command | Description |
|---------|-------------|
| `msm` | Package overview and workflow guide |
| `msm_protocol` | Record the target trial, contrast, weighting plan, and analysis plan |
| `msm_prepare` | Map identifier, period, treatment, outcome, censoring, and covariate variables |
| `msm_validate` | Run the package's 10 data-quality checks for person-period data |

### Estimation

| Command | Description |
|---------|-------------|
| `msm_weight` | Estimate stabilized IPTW and optional censoring weights |
| `msm_fit` | Fit weighted pooled logistic, linear, or Cox outcome models |
| `msm_predict` | Generate counterfactual predictions under always-treated and never-treated strategies |

### Diagnostics and output

| Command | Description |
|---------|-------------|
| `msm_diagnose` | Summarize weights and assess covariate balance |
| `msm_plot` | Draw weight, balance, survival, trajectory, and positivity plots |
| `msm_report` | Produce publication-style results tables |
| `msm_table` | Export multi-sheet Excel summaries of pipeline results |
| `msm_sensitivity` | Compute E-values and confounding-bound sensitivity summaries |

## How It Works

`msm` is organized as a pipeline. After documenting the study design with `msm_protocol`, you use `msm_prepare` to store the dataset's variable mapping in characteristics. Downstream commands then read those stored settings instead of making you restate the same identifiers and covariates at every step.

The typical workflow is:

1. `msm_protocol` to define the causal question and analysis plan.
2. `msm_prepare` to register ID, period, treatment, outcome, censoring, and covariate variables.
3. `msm_validate` to check person-period structure, treatment variation, missingness, and positivity by period.
4. `msm_weight` to estimate stabilized treatment weights and, when needed, censoring weights.
5. `msm_diagnose` to inspect weight behavior and standardized mean differences.
6. `msm_fit` to estimate the weighted outcome model.
7. `msm_predict` to standardize predictions under always-treated and never-treated strategies.
8. `msm_plot`, `msm_report`, `msm_table`, and `msm_sensitivity` to communicate results.

## Choosing an Outcome Model

| `msm_fit` model | When to use it | Follow-on implications |
|-----------------|----------------|------------------------|
| `model(logistic)` | Binary outcomes when you also want standardized counterfactual predictions | Required for `msm_predict` |
| `model(linear)` | Continuous outcomes where the weighted mean difference is the target | `msm_predict` is not available |
| `model(cox)` | Time-to-event analyses where a weighted hazard ratio is the main estimand | `msm_predict` is not available; use `stcox` postestimation instead |

## Data Requirements

- Data must be in person-period format, with one row per individual-period.
- `id()` and `period()` must uniquely identify observations.
- All individuals must share a common baseline period before weighting.
- `treatment()` and `outcome()` should be binary 0/1 variables.
- `censor()` is optional but should also be binary 0/1 when used.
- Variables in `baseline_covariates()` should be time-fixed within person.
- `msm_weight` currently rejects delayed entry.
- `msm_predict` currently supports logistic fits, so prediction workflows should use `msm_fit, model(logistic)`.

## Current Scope and Limits

- `msm` currently targets static binary treatment strategies. Prediction is implemented for always-treated, never-treated, or both; dynamic and stochastic regimes are not yet part of the estimation/prediction workflow.
- `msm_predict` requires a prior `msm_fit, model(logistic)` run. Linear and Cox fits can be estimated, diagnosed, and reported, but they do not feed into `msm_predict`.
- If you plan to predict, keep `outcome_cov()` limited to covariates that are time-fixed within individual. During prediction those terms are standardized at the baseline/reference-population values.
- `msm_weight` assumes a shared baseline period across individuals. Late entry/left truncation is not currently supported.
- By default, `msm_predict` only allows `times()` within the observed follow-up range. Use `extrapolate` only when you deliberately want out-of-range predictions.
- The package is built around person-period data with binary treatment and outcome indicators. If your design requires multivalued treatment rules or richer intervention regimes, the current release is too narrow.

## Worked Examples

### 1. Full pipeline with the bundled example dataset

This example mirrors the package's intended end-to-end workflow and uses the sample file shipped with the release. It stays within the package's supported scope: static always-treat versus never-treat prediction from a pooled logistic MSM.

```stata
findfile msm_example.dta
use "`r(fn)'", clear

msm_protocol, ///
    population("Adults aged 18-65 with condition X") ///
    treatment("Always treat vs. never treat") ///
    confounders("Biomarker (time-varying), comorbidity (time-varying), age, sex") ///
    outcome("Binary clinical endpoint") ///
    causal_contrast("ATE: always treat vs. never treat") ///
    weight_spec("Stabilized IPTW, truncated at 1st/99th percentile") ///
    analysis("Pooled logistic regression, robust SE clustered by ID")

msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) covariates(biomarker comorbidity) ///
    baseline_covariates(age sex)

msm_validate, strict verbose

msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
    treat_n_cov(age sex) truncate(1 99) nolog

msm_diagnose, balance_covariates(biomarker comorbidity age sex) ///
    by_period threshold(0.1)

msm_fit, model(logistic) outcome_cov(age sex) nolog

msm_predict, times(1 3 5 7 9) type(cum_inc) difference ///
    samples(200) seed(12345)

msm_sensitivity, evalue

msm_plot, type(survival) times(1 3 5 7 9) seed(12345)
msm_report, eform
msm_table, xlsx(msm_results.xlsx) all eform replace
```

Use this full path when you want both estimation and publication-ready outputs from the same analysis run.

### 2. Minimal estimation-and-prediction workflow

If you want the core causal estimates first, this shorter sequence gets you from prepared data to standardized counterfactual predictions quickly.

```stata
findfile msm_example.dta
use "`r(fn)'", clear

msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) covariates(biomarker comorbidity) ///
    baseline_covariates(age sex)

msm_validate
msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
    treat_n_cov(age sex) nolog
msm_fit, model(logistic) outcome_cov(age sex) nolog
msm_predict, times(3 5 7 9) difference seed(12345)
```

## Output Notes

- `msm_weight` creates `_msm_weight` and returns weight summaries such as `r(mean_weight)`, `r(ess)`, and `r(n_truncated)`.
- `msm_diagnose` can return a balance matrix in `r(balance)` when `balance_covariates()` is specified.
- `msm_fit` stores the weighted model in `e()` and records the fitted MSM effect matrix in `e(effects)`.
- `msm_predict` returns the prediction matrix in `r(predictions)` and risk differences in `r(rd_#)` when `difference` is requested.

## Practical Notes

- If you plan to run `msm_predict`, keep `outcome_cov()` limited to covariates that are time-fixed within individual.
- `msm_validate, strict` promotes warnings such as period gaps or positivity problems to errors before weighting.
- `msm_table` exports all currently available pipeline outputs to separate Excel sheets, while `msm_report` focuses on a compact analysis summary.
- If you need dynamic treatment rules, delayed-entry weighting, or standardized predictions after linear/Cox fits, treat those as out of scope for the current release.

## References

- Robins JM, Hernan MA, Brumback B. Marginal structural models and causal inference in epidemiology. *Epidemiology*. 2000;11(5):550-560.
- Hernan MA, Brumback B, Robins JM. Marginal structural models to estimate the causal effect of zidovudine on the survival of HIV-positive men. *Epidemiology*. 2000;11(5):561-570.
- Cole SR, Hernan MA. Constructing inverse probability weights for marginal structural models. *American Journal of Epidemiology*. 2008;168(6):656-664.
- VanderWeele TJ, Ding P. Sensitivity analysis in observational research: introducing the E-value. *Annals of Internal Medicine*. 2017;167(4):268-274.

## Version History

- **1.0.0** (2026-04-08): Initial Stata-Tools release of the full MSM workflow suite

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
