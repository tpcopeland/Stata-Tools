# drest — Doubly Robust Estimation for Stata

**Version 1.0.0** | 2026-03-15

Doubly robust causal inference estimators for Stata. Implements AIPW, cross-fitted AIPW (DML-style), TMLE, and LTMLE (longitudinal) with influence-function inference, diagnostics, method comparison, and sensitivity analysis.

## Installation

```stata
net install drest, from("path/to/drest") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `drest` | Package overview and workflow |
| `drest_estimate` | AIPW estimation (ATE/ATT/ATC) |
| `drest_crossfit` | Cross-fitted AIPW (DML-style, K-fold) |
| `drest_tmle` | Targeted minimum loss-based estimation |
| `drest_ltmle` | Longitudinal TMLE (time-varying treatments) |
| `drest_diagnose` | Overlap, propensity, influence, balance diagnostics |
| `drest_compare` | Side-by-side IPTW vs g-computation vs AIPW |
| `drest_predict` | Potential outcome predictions |
| `drest_bootstrap` | Bootstrap inference |
| `drest_plot` | Overlap, influence, treatment effect plots |
| `drest_report` | Excel/display tables |
| `drest_sensitivity` | E-value sensitivity analysis |

## Quick Start

```stata
* Load data
sysuse auto, clear
gen byte highmpg = (mpg > 20)

* Estimate ATE of foreign on price
drest_estimate weight length, outcome(price) treatment(foreign)

* Diagnostics
drest_diagnose, overlap balance

* Compare estimators
drest_compare weight length, outcome(price) treatment(foreign) graph

* Sensitivity analysis
drest_sensitivity, evalue
```

## Workflow

```
1. drest_estimate  →  Fit AIPW (outcome + treatment models)
2. drest_diagnose  →  Check overlap, balance, influence
3. drest_compare   →  Compare IPTW / g-comp / AIPW
4. drest_plot      →  Visualize diagnostics
5. drest_report    →  Export results
6. drest_sensitivity → E-value for unmeasured confounding
```

## Doubly Robust Property

AIPW is consistent if *either* the outcome model or the treatment model is correctly specified (but not necessarily both). This "double robustness" provides protection against model misspecification that single-model approaches (IPTW or g-computation alone) lack.

## Author

Timothy P Copeland
Department of Clinical Neuroscience, Karolinska Institutet
