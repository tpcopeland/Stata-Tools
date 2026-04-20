# msm - Marginal Structural Models for Stata

**Version 1.0.0** | 2026-04-08

`msm` is a full Stata workflow for marginal structural models using inverse probability weighting in longitudinal person-period data. It is designed for settings with time-varying treatments and confounders, where standard regression adjustment can be biased because confounders are affected by prior treatment.

## Requirements

- Stata 16 or later

## Installation

```stata
capture ado uninstall msm
net install msm, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/msm") replace
```

The package installs `msm_example.dta`, which the worked example below uses.

## Commands

### Data preparation

| Command | Description |
|---------|-------------|
| `msm` | Package overview and workflow guide |
| `msm_prepare` | Map variables and store metadata |
| `msm_validate` | Run data quality checks for the prepared person-period data |

### Core estimation

| Command | Description |
|---------|-------------|
| `msm_weight` | Estimate stabilized IPTW and optional IPCW |
| `msm_fit` | Fit weighted pooled logistic, linear, or Cox outcome models |
| `msm_predict` | Generate counterfactual predictions with confidence intervals |

### Diagnostics and output

| Command | Description |
|---------|-------------|
| `msm_diagnose` | Summarize weights and assess covariate balance |
| `msm_plot` | Draw weight, balance, survival, trajectory, and positivity plots |
| `msm_report` | Produce publication-style result tables |
| `msm_table` | Export multi-sheet Excel summaries |
| `msm_protocol` | Document the study protocol using the MSM design checklist |
| `msm_sensitivity` | Compute E-values and unmeasured-confounding bounds |

## How It Works

`msm` is organized as a pipeline. `msm_prepare` is the entry point: it maps your dataset's variable names to the package's internal workflow and stores that metadata in dataset characteristics so downstream commands know which variables to use.

From there, a typical analysis moves through validation, weight estimation, diagnostics, model fitting, prediction, and reporting. The sequence is usually:

1. `msm_protocol` to document the target trial and causal contrast.
2. `msm_prepare` to map identifiers, period, treatment, outcome, and covariates.
3. `msm_validate` to check person-period structure and common data problems.
4. `msm_weight` to estimate stabilized treatment and optional censoring weights.
5. `msm_diagnose` to inspect weight distributions and standardized mean differences.
6. `msm_fit` to estimate the weighted outcome model.
7. `msm_predict` to standardize predictions under always-treated and never-treated strategies.
8. `msm_plot`, `msm_report`, `msm_table`, and `msm_sensitivity` to communicate results.

`msm_predict` currently supports logistic outcome models only. If you plan to use `msm_predict`, keep `outcome_cov()` limited to baseline covariates rather than time-varying terms.

## Data Requirements

- The data must be in person-period format, with one row per individual-period.
- `id()` and `period()` must uniquely identify observations.
- `treatment()`, `outcome()`, and `censor()` if used should be binary 0/1 variables.
- Variables passed in `baseline_covariates()` must be time-fixed within person.
- Delayed entry is not currently supported; all individuals should share the common baseline period.

## Worked Examples

### 1. Full pipeline with the bundled example data

This example follows the package's intended workflow from protocol through export. It is the fastest way to see how the commands fit together after installation.

```stata
findfile msm_example.dta
use "`r(fn)'", clear

* Optional but recommended: document the target trial
msm_protocol, ///
    population("Adults aged 18-65 with condition X") ///
    treatment("Always treat vs. never treat") ///
    confounders("Biomarker (time-varying), comorbidity (time-varying), age, sex") ///
    outcome("Binary clinical endpoint") ///
    causal_contrast("ATE: always treat vs. never treat") ///
    weight_spec("Stabilized IPTW, truncated at 1st/99th percentile") ///
    analysis("Pooled logistic regression, robust SE clustered by ID")

* Step 1: map variables
msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) covariates(biomarker comorbidity) ///
    baseline_covariates(age sex)

* Step 2: check the prepared data
msm_validate, strict verbose

* Step 3: estimate stabilized treatment weights
msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
    treat_n_cov(age sex) truncate(1 99) nolog

* Step 4: inspect weights and balance
msm_diagnose, balance_covariates(biomarker comorbidity age sex) ///
    by_period threshold(0.1)

* Step 5: fit the weighted outcome model
msm_fit, model(logistic) outcome_cov(age sex) nolog

* Step 6: predict counterfactual outcomes
msm_predict, times(1 3 5 7 9) type(cum_inc) difference ///
    samples(200) seed(12345)

* Step 7: assess sensitivity to unmeasured confounding
msm_sensitivity, evalue

* Step 8: visualize and export
msm_plot, type(survival) title("Cumulative Incidence: Always vs. Never Treat")
msm_plot, type(weights) title("IP Weight Distribution")
msm_plot, type(balance) covariates(biomarker comorbidity age sex)
msm_table, xlsx(msm_results.xlsx) all eform replace
```

The denominator model in `msm_weight` conditions on lagged treatment, period, and the covariates you pass in `treat_d_cov()`. The numerator model uses the covariates in `treat_n_cov()` for stabilization. If you need richer treatment history terms, construct them explicitly and include them in those model lists.

### 2. Minimal pipeline when you only want estimation and prediction

If you do not need protocol output right away, the minimum practical workflow is preparation, validation, weighting, fitting, and prediction.

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

Use this shorter workflow when you want the core causal estimates first and can come back later for reporting, sensitivity analysis, and formatted exports.

## Notes

- `msm_weight` distinguishes perfect prediction from genuinely incomplete inputs. Complete-case strata with perfect prediction use truncated observed probabilities rather than silently defaulting the weight factor to 1.
- `msm_weight` creates `_msm_weight` as the combined weight, plus `_msm_tw_weight` and `_msm_cw_weight` when treatment and censoring weights are estimated separately.
- `msm_plot` uses the active Stata graph scheme unless you change the scheme before plotting.

## References

- Robins JM, Hernan MA, Brumback B. Marginal structural models and causal inference in epidemiology. *Epidemiology*. 2000;11(5):550-560.
- Hernan MA, Brumback B, Robins JM. Marginal structural models to estimate the causal effect of zidovudine on the survival of HIV-positive men. *Epidemiology*. 2000;11(5):561-570.
- Cole SR, Hernan MA. Constructing inverse probability weights for marginal structural models. *American Journal of Epidemiology*. 2008;168(6):656-664.
- VanderWeele TJ, Ding P. Sensitivity analysis in observational research: introducing the E-value. *Annals of Internal Medicine*. 2017;167(4):268-274.

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
