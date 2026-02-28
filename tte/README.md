# tte — Target Trial Emulation for Stata

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue)

A comprehensive suite for target trial emulation using observational data. Implements the sequential trials framework (Hernán & Robins, 2016) with the clone-censor-weight approach for estimating per-protocol, intention-to-treat, and as-treated effects.

This is the first Stata implementation of the complete TTE workflow, going beyond the R `TrialEmulation` package by adding Cox model support, protocol table generation, and publication-ready reporting.

## Installation

```stata
net install tte, from("https://raw.githubusercontent.com/tpcopeland/Stata-Dev/main/tte")
```

---

## Commands

| Command | Description |
|---------|-------------|
| `tte` | Package overview and workflow guide |
| `tte_prepare` | Validate and map variables for analysis |
| `tte_validate` | Data quality checks and diagnostics |
| `tte_expand` | Sequential trial expansion (clone-censor) |
| `tte_weight` | Inverse probability weights (IPTW/IPCW) |
| `tte_fit` | Outcome modeling (pooled logistic / Cox MSM) |
| `tte_predict` | Marginal predictions with confidence intervals |
| `tte_diagnose` | Weight diagnostics and balance assessment |
| `tte_plot` | KM curves, cumulative incidence, weight plots |
| `tte_report` | Publication-quality results tables |
| `tte_protocol` | Target trial protocol table (Hernán 7-component) |

---

## Typical Workflow

```stata
* Load data
use tte_example, clear

* Step 1: Prepare data
tte_prepare, id(patid) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) censor(censored) ///
    covariates(age sex comorbidity biomarker) estimand(PP)

* Step 2: Validate
tte_validate

* Step 3: Expand into sequential trials
tte_expand, maxfollowup(8) grace(1)

* Step 4: Calculate IP weights
tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
    stabilized truncate(1 99) nolog

* Step 5: Fit outcome model
tte_fit, outcome_cov(age sex comorbidity) model(logistic) nolog

* Step 6: Predict marginal outcomes
tte_predict, times(0 2 4 6 8) type(cum_inc) difference ///
    samples(100) seed(12345)

* Step 7: Report results
tte_report, eform
```

---

## Estimands

| Estimand | Description | Censoring |
|----------|-------------|-----------|
| **ITT** | Intention-to-treat | No artificial censoring |
| **PP** | Per-protocol | Censor at treatment deviation |
| **AT** | As-treated | Censor at treatment switching |

---

## Features Beyond R TrialEmulation

| Feature | R TrialEmulation | tte (Stata) |
|---------|-----------------|-------------|
| Pooled logistic regression | Yes | Yes |
| Cox / parametric survival MSM | No | Yes |
| Protocol table (Hernán 7-component) | No | Yes |
| Data validation command | No | Yes |
| Publication report generation | No | Yes |
| Love plot / balance diagnostics | No | Yes |
| Weight distribution plots | No | Yes |
| Grace period handling | Limited | Full |
| Natural spline support | Via formula | Built-in option |

---

## Stored Results

All commands return results in `r()` or `e()`. Key results:

- `tte_prepare`: `r(N)`, `r(n_ids)`, `r(n_eligible)`, `r(n_events)`, `r(estimand)`
- `tte_expand`: `r(n_trials)`, `r(n_expanded)`, `r(expansion_ratio)`
- `tte_weight`: `r(mean_weight)`, `r(ess)`, `r(n_truncated)`
- `tte_fit`: `e(b)`, `e(V)`, `e(tte_model)`, `e(tte_estimand)`
- `tte_predict`: `r(predictions)` matrix, `r(rd_#)` scalars
- `tte_diagnose`: `r(balance)` matrix, `r(max_smd_wt)`, `r(ess)`

---

## References

- Hernán MA, Robins JM. Using Big Data to Emulate a Target Trial When a Randomized Trial Is Not Available. *Am J Epidemiol*. 2016;183(8):758-764.
- Hernán MA, Robins JM. *Causal Inference: What If*. Boca Raton: Chapman & Hall/CRC; 2020.
- Maringe C, Benitez Majano S, et al. TrialEmulation: An R Package for Target Trial Emulation. *arXiv*. 2024;2402.12083.

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## Version

Version 1.0.3, 2026-03-01
