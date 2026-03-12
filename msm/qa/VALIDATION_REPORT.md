# MSM Package Validation Report

**Package**: msm v1.0.0
**Date**: 2026-03-12
**Suite**: 11 validations + 3 functional tests, ~172 tests

## Summary

| # | Validation | Tests | Source | Status |
|---|-----------|-------|--------|--------|
| T1 | Functional Tests | 48+ | msm_example.dta | PASS |
| T2 | Table Export Tests | 13 | msm_example.dta | PASS |
| T3 | Complete Option Path Coverage | 67 | msm_example.dta + synthetic | PASS |
| V1 | Known DGP (Cole & Hernan) | 8 | Simulated (N=10K, T=10) | PASS |
| V2 | R ipw Cross-Validation | 6 | haartdat (386 HIV+ patients) | PASS |
| V3 | NHEFS Benchmarks | 8 | Harvard CDN (N=1,629) | PASS |
| V4 | Fewell RA/Methotrexate | 7 | Simulated (N=5K, T=10) | PASS |
| V5 | Null Effect & Reproducibility | 6 | Simulated (100 MC reps) | PASS |
| V6 | IPCW / Informative Censoring | 7 | Simulated (N=5K, T=12) | PASS |
| V7 | Diagnostics & Reporting | 10 | msm_example.dta | PASS |
| V8 | Pipeline Guards & Edge Cases | 8 | Synthetic | PASS |
| V9 | Cross-Language Validation | 16 | Stata vs R vs Python vs teffects | PASS |
| V10 | Mathematical Verification | 15 | Hand-calculated + synthetic | PASS |
| V11 | Stress & Boundary Testing | 14 | Simulated edge cases | PASS |

**Total: ~172 tests, all PASS**

## Running the Suite

```stata
* Run all validations
cd ~/Stata-Tools/msm/qa
stata-mp -b do run_all_validations.do

* Run selective validations
stata-mp -b do run_all_validations.do 1 5 8

* Run cross-validation only
stata-mp -b do crossval_msm_vs_all.do
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

### Source 6: R `ipw` + `survey` packages — V9
- **Packages**: `ipw` (ipwtm), `survey` (svyglm), `sandwich`
- **Validates**: Live cross-language weight and coefficient agreement on shared DGP data

### Source 7: Python `statsmodels` — V9
- **Packages**: `statsmodels` (GLM, WLS), `numpy`, `pandas`, `scipy`
- **Validates**: Live cross-language weight and coefficient agreement on shared DGP data

### Source 8: Stata `teffects ipw` — V9
- **Built-in**: Stata's `teffects ipw` command for point-treatment IPTW
- **Validates**: msm manual IPTW agrees with Stata's official implementation

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

### V9: Cross-Language Validation
- **DGP1**: N=2,000, T=8, true conditional log-OR = -0.357. Time-varying treatment with confounder feedback.
- **DGP2**: N=3,000, point treatment. True ATE = 2.0 (exactly).
- **DGP3**: N=10,000 true counterfactual simulation (always vs never treated).
- **Languages**: Stata msm, R (`ipw`/`survey`/`sandwich`), Python (`statsmodels`)
- **Comparisons**: Individual-level weight correlations, propensity score correlations, coefficient agreement, Stata `teffects ipw` benchmark

#### V9 Cross-Validation Results (2026-03-11)

**DGP1: Time-Varying Treatment** (truth: log-OR = -0.357)

| Source | Weight Mean | Weight SD | Log-OR | SE |
|--------|------------|-----------|--------|------|
| Stata msm | 0.9973 | 0.4070 | -0.2102 | 0.1069 |
| R (manual IPTW) | 0.9976 | 0.4083 | -0.2150 | 0.1064 |
| Python (manual) | 0.9976 | 0.4083 | -0.2150 | 0.1064 |

**DGP2: Point Treatment** (truth: ATE = 2.000)

| Source | Weight Mean | ATE | SE |
|--------|------------|------|------|
| Stata IPTW | 0.9989 | 1.9945 | 0.0993 |
| teffects ipw | — | 1.9945 | 0.0792 |
| R IPTW | 0.9989 | 1.9945 | 0.0993 |
| Python IPTW | 0.9989 | 1.9945 | 0.0993 |

#### V9 Tests

| Test | Description | Tolerance | Status |
|------|-------------|-----------|--------|
| C1 | Stata vs R weight mean (DGP1) | < 0.05 | PASS |
| C2 | Stata vs Python weight mean (DGP1) | < 0.05 | PASS |
| C3 | Stata vs R treatment effect (DGP1) | < 0.10 | PASS |
| C4 | Stata vs Python treatment effect (DGP1) | < 0.10 | PASS |
| C5 | R vs Python treatment effect (DGP1) | < 0.05 | PASS |
| C6 | All three direction correct (DGP1) | negative | PASS |
| C7 | msm within 0.20 of truth (DGP1) | < 0.20 | PASS |
| C8 | All weight means near 1.0 | < 0.10 | PASS |
| C9 | Manual IPTW vs teffects (DGP2) | < 0.20 | PASS |
| C10 | All three ATEs agree (DGP2) | < 0.10 | PASS |
| C11 | All ATEs near truth 2.0 (DGP2) | < 0.50 | PASS |
| C12 | Stata-R weight correlation (DGP1) | > 0.95 | PASS |
| C13 | Stata-Python weight correlation (DGP1) | > 0.95 | PASS |
| C14 | PS correlations (DGP2) | > 0.999 | PASS |
| C15 | DGP3 counterfactual validity | valid | PASS |
| C16 | msm 95% CI covers true log-OR | covered | PASS |

#### Key Finding: Sustained-Strategy vs Per-Period Effects

DGP3 reveals an important educational point: the sustained-strategy counterfactual (always vs never treated) can have a different sign from the MSM per-period coefficient. In this DGP, treatment is protective per-period (log-OR = -0.357) but the treatment-confounder feedback (A→L↑→Y↑) makes sustained treatment net neutral-to-harmful. This is well-documented in the MSM literature — the coefficient is the per-period marginal effect, not the sustained strategy effect. `msm_predict` (not the coefficient) should be used for sustained-strategy comparisons.

### T3: Complete Option Path Coverage (NEW — 2026-03-12)
- **Sections**: A (msm_prepare: 6), B (msm_validate: 4), C (msm_weight: 5), D (msm_fit: 12), E (msm_predict: 9), F (msm_diagnose: 4), G (msm_plot: 5), H (msm_report: 5), I (msm_protocol: 5), J (msm_sensitivity: 4), K (helpers: 6), L (metadata: 2)
- **Tests**: Every untested option combination, return value, error path, and edge case across all 12 subcommands
- **Notable**: D12 documents known limitation — Stata `bootstrap` prefix does not allow `pweight` in estimation command (rc=101)

### V10: Mathematical Verification (NEW — 2026-03-12)
- **Tests**: Hand-calculated ESS, SMD, E-value, bias factor, cumulative weight log-sum stability, hand-calculated IPTW on tiny dataset, natural spline basis properties, prediction probability monotonicity, weight product identity (tw * cw = combined), truncation clipping, E-value for protective effects, weighted SMD reduction, logistic/linear direction agreement, period spec robustness, E-value CI null-crossing
- **Key property**: ESS formula (sum w)^2/(sum w^2) verified exactly; E-value = RR + sqrt(RR*(RR-1)) verified to <0.001

### V11: Stress & Boundary Testing (NEW — 2026-03-12)
- **Tests**: Near-positivity (~5% treatment), strong confounding (coeff 2.0), many covariates (10), unbalanced panels (varying T=2-10), large N (100K obs), very rare events (<1%), high events (~20%), short panel (T=2), long panel (T=50), treatment switching mix, heavy censoring (~40%), stress predictions (10 time points), identical num/denom (weights ~1), aggressive truncation (10th/90th)
- **Key finding**: All 14 stress scenarios complete without errors; weights remain valid across extreme conditions

## Data Files

| File | Source | Size |
|------|--------|------|
| `data/nhefs.dta` | Harvard T.H. Chan SPH | 825 KB |
| `data/nhefs_personperiod.dta` | Generated from nhefs.dta | ~7 MB |
| `data/haartdat.dta` | R `ipw` package | ~1.9 MB |
| `crossval_data/dgp1_panel.dta` | Simulated (N=2K, T=8) | ~500 KB |
| `crossval_data/dgp2_point.dta` | Simulated (N=3K) | ~100 KB |
| `crossval_data/dgp3_true_counterfactual.dta` | Simulated (N=10K) | ~1 KB |

## Cross-Validation Scripts

| File | Language | Purpose |
|------|----------|---------|
| `crossval_dgp_generate.do` | Stata | Generate shared DGP datasets |
| `crossval_r.R` | R | IPTW + svyglm cross-validation |
| `crossval_python.py` | Python | statsmodels cross-validation |
| `crossval_msm_vs_all.do` | Stata | Master comparison + formal tests |

## Bugs Found and Fixed

| Bug | File | Description | Fix |
|-----|------|-------------|-----|
| Nested preserve | `msm_plot.ado` | Balance plot used nested `preserve`/`restore, preserve`/`preserve` which fails with "already preserved" (rc=621) | Compute SMDs first on original data, then `preserve` once for plot dataset |
| Bootstrap pweight | `msm_fit.ado` | `bootstrap` prefix does not allow `pweight` in GLM/regress (rc=101) | Known limitation, documented in T3-D12 |

## Machine-Parseable Output

Each validation emits a RESULT line:
```
RESULT: V# tests=N pass=P fail=F status=PASS/FAIL
RESULT: CROSSVAL tests=16 pass=16 fail=0 status=PASS
```
