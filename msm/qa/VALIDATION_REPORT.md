# MSM Package Validation Report

**Package**: msm v1.0.0
**Date**: 2026-03-03
**Suite**: 8 validations, ~60 tests

## Summary

| # | Validation | Tests | Source | Status |
|---|-----------|-------|--------|--------|
| V1 | Known DGP (Cole & Hernan) | 8 | Simulated (N=10K, T=10) | PASS |
| V2 | R ipw Cross-Validation | 6 | haartdat (386 HIV+ patients) | PASS |
| V3 | NHEFS Benchmarks | 8 | Harvard CDN (N=1,629) | PASS |
| V4 | Fewell RA/Methotrexate | 7 | Simulated (N=5K, T=10) | PASS |
| V5 | Null Effect & Reproducibility | 6 | Simulated (100 MC reps) | PASS |
| V6 | IPCW / Informative Censoring | 7 | Simulated (N=5K, T=12) | PASS |
| V7 | Diagnostics & Reporting | 10 | msm_example.dta | PASS |
| V8 | Pipeline Guards & Edge Cases | 8 | Synthetic | PASS |

**Total: 60 tests, all PASS**

## Running the Suite

```stata
* Run all validations
cd ~/Stata-Tools/msm/qa
stata-mp -b do run_all_validations.do

* Run selective validations
stata-mp -b do run_all_validations.do 1 5 8
```

## External Sources

### Source 1: Cole & Hernan (2008) — V1
- **Reference**: Cole SR, Hernan MA. "Constructing Inverse Probability Weights for MSMs." AJE 168(6):656-664
- **Used in**: V1 (Known DGP weight construction principles)
- **Validates**: Stabilized weight mean ~1, truncation improves ESS, cumulative product behavior

### Source 2: van der Wal & Geskus (2011) — V2
- **Reference**: van der Wal WM, Geskus RB. "ipw: An R Package for Inverse Probability Weighting." JSS 43(13)
- **Data**: haartdat (386 HIV+ patients, counting-process format)
- **Validates**: Cross-language weight agreement, treatment coefficient direction

### Source 3: Hernan & Robins "What If" Ch12 — V3 Part A
- **Reference**: Hernan MA, Robins JM. "Causal Inference: What If." Chapter 12
- **Data**: NHEFS (N=1,566 complete cases)
- **Benchmarks**: Stabilized IPTW ATE = 3.44 kg, weight mean = 0.999, weight SD = 0.288

### Source 4: Hernan & Robins "What If" Ch17 — V3 Part B
- **Reference**: Hernan MA, Robins JM. "Causal Inference: What If." Chapter 17
- **Data**: NHEFS restructured to person-period
- **Validates**: Full MSM pipeline on real data, Cox model

### Source 5: Fewell et al. (2004) — V4
- **Reference**: Fewell Z et al. "Controlling for Time-dependent Confounding using MSMs." Stata Journal 4(4):402-420
- **DGP**: RA patients, methotrexate as time-varying treatment, disease activity as confounder affected by prior treatment
- **Validates**: Naive bias demonstration, balance improvement, full pipeline

## Validation Details

### V1: Known DGP with Time-Varying Confounding
- **DGP**: N=10,000, T=10, true log-OR = ln(0.70) = -0.357
- **Mechanism**: L_{t+1} = 0.5*L_t + 0.8*A_t + N(0,0.5) creates treatment-confounder feedback
- **Tests**: Large-sample accuracy (0.15), CI coverage, naive attenuation, weight mean near 1, 30-rep Monte Carlo (mean within 0.20, coverage >= 60%), truncation ESS improvement, period spec robustness, linear model direction

### V2: R ipw Cross-Validation (haartdat)
- **Data**: 386 HIV+ patients from R `ipw` package, restructured from counting-process to person-period
- **R benchmarks**: Weight mean 1.04, treatment coefficient negative
- **Tests**: Data validation, weight mean within 10% of R, coefficient direction (protective), OR in plausible range, ESS > 50%, truncation sensitivity

### V3: NHEFS Benchmarks
- **Part A (Ch12)**: Point-treatment IPTW on cross-sectional data. Weight mean ~0.999, SD ~0.288, ATE ~3.44 kg
- **Part B (Ch17)**: Person-period pooled logistic. Pipeline completion, Cox model, weight ESS > 50%

### V4: Fewell RA/Methotrexate DGP
- **DGP**: N=5,000, T=10, true log-OR = -0.50. Disease activity feedback: DA_{t+1} = 0.6*DA_t - 0.5*MTX_t
- **Tests**: Naive direction, MSM within 0.35, MSM negative, weighted SMD improvement, weight SD < 2.0, E-value > 1, monotonic predictions

### V5: Null Effect & Reproducibility
- **DGP**: Same as V1 but true effect = 0
- **Tests**: Near-zero estimate, CI covers null, 100-rep rejection rate < 15%, seed reproducibility, predict reproducibility, near-zero risk difference

### V6: IPCW / Informative Censoring
- **DGP**: N=5,000, T=12, censoring depends on L (sicker censor more) and A (treated censor less)
- **Tests**: IPTW-only pipeline, IPTW+IPCW within 0.30, directional correctness, censoring weight existence, combined weight mean, censoring weight mean, ESS > 50%

### V7: Diagnostics, Reporting, Sensitivity
- **Data**: msm_example.dta with full pipeline
- **Tests**: diagnose scalars, by_period, balance improvement, report display, CSV export, protocol (7 fields), E-value > 1, confounding_strength, plot weights, plot positivity

### V8: Pipeline Guards & Edge Cases
- **Tests**: validate/weight/fit/predict prerequisite failures, non-binary treatment rejection, duplicate id-period rejection, weight replace behavior, diagnose prerequisite

## Data Files

| File | Source | Size |
|------|--------|------|
| `data/nhefs.dta` | Harvard T.H. Chan SPH | 825 KB |
| `data/nhefs_personperiod.dta` | Generated from nhefs.dta | ~7 MB |
| `data/haartdat.dta` | R `ipw` package | ~1.9 MB |

## Machine-Parseable Output

Each validation emits a RESULT line:
```
RESULT: V# tests=N pass=P fail=F status=PASS/FAIL
```
