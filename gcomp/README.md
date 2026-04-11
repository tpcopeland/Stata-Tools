# gcomp — G-Computation Formula for Stata

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue)

**Version**: gcomp 1.0.0 / gcomptab 1.0.0 (2026-04-08)
**Forked from**: SSC `gformula` v1.16 beta (Rhian Daniel, 2021)

## Overview

Implements Robins' parametric g-computation formula (Robins 1986) using Monte Carlo simulation for:

- **Time-varying confounding**: Estimates causal effects of time-varying exposures on outcomes in the presence of time-varying confounders affected by prior exposure
- **Causal mediation**: Estimates total causal effects (TCE), natural direct effects (NDE), natural indirect effects (NIE), proportion mediated (PM), and controlled direct effects (CDE)

## Commands

| Command | Description |
|---------|-------------|
| `gcomp` | G-computation formula for causal inference and mediation |
| `gcomptab` | Export gcomp mediation results to publication-ready Excel |

## Installation

```stata
net install gcomp, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/gcomp/") replace
```

## Syntax

### gcomp — Time-varying confounding

```stata
gcomp varlist [if] [in], outcome(varname) commands(string) equations(string)
    idvar(varname) tvar(varname) varyingcovariates(varlist)
    intvars(varlist) interventions(string) [options]
```

### gcomp — Causal mediation

```stata
gcomp varlist [if] [in], outcome(varname) commands(string) equations(string)
    mediation exposure(varlist) mediator(varlist) base_confs(varlist)
    effect_type [options]
```

where `effect_type` is one of: `obe`, `oce`, `linexp`, `specific`, or `baseline(string)`.

### gcomptab — Export mediation results to Excel

```stata
gcomptab, xlsx(filename) sheet(string) [ci(string) effect(string)
    title(string) labels(string) decimal(#) font(string) fontsize(#)
    borderstyle(string) zebra footnote(string) open boldp(#) highlight(#)]
```

## Key Options

### Required (both modes)

| Option | Description |
|--------|-------------|
| `outcome(varname)` | Outcome variable |
| `commands(string)` | Model type for each variable, e.g., `commands(m: logit, y: logit)` |
| `equations(string)` | Prediction equations, e.g., `equations(m: x c, y: m x c)` |

### Required (time-varying)

| Option | Description |
|--------|-------------|
| `idvar(varname)` | Subject identifier |
| `tvar(varname)` | Time variable |
| `varyingcovariates(varlist)` | Time-varying confounders affected by prior exposure |
| `intvars(varlist)` | Variables to intervene on |
| `interventions(string)` | Intervention rules, e.g., `interventions(A=0)` |

### Mediation options

| Option | Description |
|--------|-------------|
| `mediation` | Enable mediation analysis mode |
| `exposure(varlist)` | Exposure variable(s) |
| `mediator(varlist)` | Mediator variable(s) |
| `base_confs(varlist)` | Baseline confounders |
| `control(string)` | Controlled direct effect level(s) |
| `post_confs(varlist)` | Post-treatment confounders of mediator-outcome |
| `logOR` / `logRR` | Report log odds ratio or log risk ratio |
| `boceam` | BOCE-AM estimation for multi-mediator settings |

### Time-varying options

| Option | Description |
|--------|-------------|
| `eofu` | Outcome measured at end of follow-up |
| `pooled` | Pooled logistic regression across visits |
| `monotreat` | Monotone treatment assumption |
| `dynamic` | Dynamic treatment regime |
| `death(varname)` | Competing death/censoring variable |
| `msm(string)` | Marginal structural model specification |
| `fixedcovariates(varlist)` | Time-invariant covariates |
| `laggedvars(varlist)` | Variables with lagged effects |
| `lagrules(string)` | Custom lag specification rules |
| `derived(varlist)` | Deterministically derived variables |
| `derrules(string)` | Derivation rules |

### Imputation

| Option | Description |
|--------|-------------|
| `impute(varlist)` | Variables to impute (MAR assumption) |
| `imp_eq(string)` | Imputation prediction equations |
| `imp_cmd(string)` | Imputation model commands |
| `imp_cycles(#)` | Chained-equation cycles (default: 10) |

### Simulation

| Option | Description |
|--------|-------------|
| `simulations(#)` | Monte Carlo sample size (default: sample size) |
| `samples(#)` | Bootstrap replications (default: 1000) |
| `seed(#)` | Random number seed |
| `minsim` | Use expected values instead of random draws |
| `moreMC` | Allow MC sample size larger than N |

### Output

| Option | Description |
|--------|-------------|
| `all` | Report all four CI types (normal, percentile, BC, BCa) |
| `graph` | Graph potential outcomes |
| `saving(filename)` | Save bootstrap dataset |
| `replace` | Overwrite existing saved file |

### gcomptab options

| Option | Description |
|--------|-------------|
| `xlsx(filename)` | Output Excel filename (must end with `.xlsx`) |
| `sheet(string)` | Sheet name to create/replace |
| `ci(string)` | CI type: `normal` (default), `percentile`, `bc`, `bca` |
| `decimal(#)` | Decimal places for estimates (default: 3, range: 1-6) |

## Examples

### Example 1: Binary exposure mediation (OBE)

Does smoking affect lung function, and how much is mediated through inflammation?

```stata
* Generate data with known causal structure
clear
set seed 12345
set obs 1000
gen double c = rnormal(50, 10)
gen double x = rbinomial(1, invlogit(-2 + 0.02 * c))
gen double m = rbinomial(1, invlogit(-1 + 0.8 * x + 0.01 * c))
gen double y = rbinomial(1, invlogit(-3 + 0.5 * m + 0.3 * x + 0.02 * c))

* Run g-computation mediation
gcomp y m x c, outcome(y) mediation obe ///
    exposure(x) mediator(m) ///
    commands(m: logit, y: logit) ///
    equations(m: x c, y: m x c) ///
    base_confs(c) sim(500) samples(200) seed(42)
```

### Example 2: Time-varying confounding

What is the causal effect of sustained treatment on a binary outcome, adjusting for time-varying confounders?

```stata
* Panel data: 500 subjects, 5 time points
* Confounder L is affected by prior treatment A
gcomp outcome L A, outcome(outcome) ///
    idvar(id) tvar(time) ///
    varyingcovariates(L) ///
    commands(L: logit, outcome: logit) ///
    equations(L: A, outcome: L A) ///
    intvars(A) interventions(A=1, A=0) ///
    sim(500) samples(200) seed(42)
```

`interventions()` is executed as literal Stata replacement syntax on the
variables named in `intvars()`. For static regimes, use expressions such as
`A=1` and `A=0`.

### Example 3: Export results to Excel

```stata
* After running gcomp, export to Excel
gcomptab, xlsx(mediation_results.xlsx) sheet("Table 1") ///
    title("Causal Mediation: Smoking → Inflammation → Lung Function")
```

### Example 4: Categorical exposure mediation (OCE)

```stata
* Physical activity level (0=none, 1=moderate, 2=high) → depression,
* mediated through sleep quality
clear
set seed 54321
set obs 1000
gen double c = rnormal()
gen double x = floor(runiform() * 3)
gen double m = rbinomial(1, invlogit(-0.5 + 0.3 * x + 0.2 * c))
gen double y = rbinomial(1, invlogit(-1 + 0.4 * m - 0.2 * x + 0.1 * c))

gcomp y m x c, outcome(y) mediation oce ///
    exposure(x) mediator(m) ///
    commands(m: logit, y: logit) ///
    equations(m: x c, y: m x c) ///
    base_confs(c) sim(500) samples(200) seed(42)
```

## Demo Output

### Console output

![Console output — setup and models](demo/console_output_setup.png)

![Console output — analysis](demo/console_output_analysis.png)

![Console output — results](demo/console_output_results.png)

### Excel export (gcomptab)

![gcomptab Excel output](demo/demo_gcomptab.png)

## Stored Results

### gcomp

`gcomp` stores the following in `e()`:

**Scalars:**
| Result | Description |
|--------|-------------|
| `e(N)` | Number of subjects |
| `e(MC_sims)` | Monte Carlo simulation size |
| `e(samples)` | Number of bootstrap replications |

**Convenience scalars** (mediation, non-OCE):
| Result | Description |
|--------|-------------|
| `e(tce)` | Total causal effect |
| `e(nde)` | Natural direct effect |
| `e(nie)` | Natural indirect effect |
| `e(pm)` | Proportion mediated |
| `e(cde)` | Controlled direct effect (with `control()`) |
| `e(se_tce)` | SE of total causal effect |
| `e(se_nde)` | SE of natural direct effect |
| `e(se_nie)` | SE of natural indirect effect |
| `e(se_pm)` | SE of proportion mediated |
| `e(se_cde)` | SE of controlled direct effect |

**Convenience scalars** (mediation, OCE — *j*=1,...,*K*-1):
| Result | Description |
|--------|-------------|
| `e(tce_`*j*`)` | TCE for level *j* vs. baseline |
| `e(nde_`*j*`)` | NDE for level *j* vs. baseline |
| `e(nie_`*j*`)` | NIE for level *j* vs. baseline |
| `e(pm_`*j*`)` | PM for level *j* vs. baseline |
| `e(cde_`*j*`)` | CDE for level *j* vs. baseline |

**Time-varying scalar:**
| Result | Description |
|--------|-------------|
| `e(obs_data)` | Observed outcome in the data |

**Matrices:**
| Result | Description |
|--------|-------------|
| `e(b)` | Coefficient vector with named columns |
| `e(V)` | Diagonal variance matrix (SE^2 on diagonal) |
| `e(se)` | Standard error vector |
| `e(ci_normal)` | Normal-based confidence intervals |
| `e(ci_percentile)` | Percentile CIs (with `all`) |
| `e(ci_bc)` | Bias-corrected CIs (with `all`) |
| `e(ci_bca)` | Bias-corrected accelerated CIs (with `all`) |

**Macros:**
| Result | Description |
|--------|-------------|
| `e(cmd)` | `gcomp` |
| `e(analysis_type)` | `mediation` or `time_varying` |
| `e(outcome)` | Outcome variable name |
| `e(exposure)` | Exposure variable(s) (mediation) |
| `e(mediator)` | Mediator variable(s) (mediation) |
| `e(mediation_type)` | `obe`, `oce`, `linexp`, `specific`, or `baseline` |
| `e(scale)` | `RD`, `logOR`, or `logRR` |
| `e(msm)` | MSM specification (time-varying with MSM) |

### gcomptab

`gcomptab` stores the following in `r()`:

| Result | Description |
|--------|-------------|
| `r(N_effects)` | Number of effects (4 without CDE, 5 with CDE) |
| `r(tce)` | Total causal effect |
| `r(nde)` | Natural direct effect |
| `r(nie)` | Natural indirect effect |
| `r(pm)` | Proportion mediated |
| `r(cde)` | Controlled direct effect |
| `r(xlsx)` | Excel filename |
| `r(sheet)` | Sheet name |
| `r(ci)` | CI type used |

## Changes from SSC v1.16

### Bug fixes
1. **Hardcoded `by id:`** - Survival/death path now correctly uses `idvar()` variable
2. **Broken baseline auto-detect with `oce`** - Fixed backtick macro bug that silently produced wrong results
3. **Global macro pollution** - Eliminated `$maxid`, `$check_delete`, `$check_print`, `$check_save`, `$almost_varlist` globals

### Modernization
- Merged `gformula_.ado` into single file (no more separate bootstrap program)
- Replaced deprecated `uniform()` with `runiform()` and `invnormal(uniform())` with `rnormal()`
- Added `double` precision to all numeric `gen` statements
- Inlined `detangle`/`formatline`/`chkin` dependencies (no more `ice` package dependency)
- Added `version 16.0`, `set varabbrev off`, `set more off`
- Namespaced internal variables to prevent collisions

## Validation

The `qa/` directory contains **172 tests** across 3 test files, all passing.

### Cross-validation (crossval_gcomp.do — 18 tests)

Cross-validates gcomp estimates against analytical ground truth, R `mediation` 4.5.1 (Imai, Keele & Tingley 2010), and internal consistency checks.

**V1: Known DGP — analytical ground truth (7 tests).** Generates N=5,000 from a known DGP (X→M→Y with confounder C, all logistic) and compares gcomp's OBE estimates against analytical potential outcome means (computed via N=100,000 MC integration over C). All effects recover the correct direction and magnitude: TCE within 0.011 of truth (0.056), NDE within 0.003 of truth (0.041), NIE within 0.008 of truth (0.015). PM falls in the plausible range [0.05, 0.60] (true: 0.272).

**V2: R `mediation` cross-validation (6 tests).** Runs gcomp on the same N=5,000 dataset used to generate R benchmarks. TCE agrees within 0.002, NDE within 0.009, NIE within 0.010. The gcomp TCE estimate falls within R's 95% CI [0.039, 0.088]. Both tools identify the same effect decomposition pattern (NDE > NIE). The additive decomposition TCE = NDE + NIE holds exactly (residual < 0.001).

**CV3: Time-varying mode cross-validation (3 tests).** Validates time-varying confounding mode against expected behavior with panel data.

**CV4: minsim vs random draws (2 tests).** Checks that the `minsim` option (expected values) produces consistent decomposition compared to standard random draws.

R benchmarks, shared dataset, and the R script that generated them are in `qa/data/`.

### Functional tests (test_gcomp.do — 116 tests)

Comprehensive functional coverage across 16 sections:

- **Core mediation** (tests 1-22): Internal program loading, OBE/OCE/linexp/specific/baseline mediation modes, `e()` stored results (scalars, matrices, macros), `control()` for CDE, `all` CI types, `minsim`, `logOR`/`logRR` scale options, seed reproducibility, data preservation, `estimates store` compatibility
- **gcomptab pipeline** (tests 23-47): Excel output with all option combinations (title, labels, decimal, CI types, effect labels), multi-sheet workbooks, `r()` return values, edge cases (negative/small/large effects), error handling (invalid CI, decimal, extension), full gcomp→gcomptab pipeline, `e()` persistence after rclass gcomptab
- **Bug regression** (tests 48-57): Multi-exposure `baseline()` fix, OCE bootstrap spacing, `gen double` after reshape precision, varabbrev/more restore on success and error, CDE inclusion/exclusion in `e(b)`, PM missing when TCE near-zero, OBE without `baseline()`
- **Time-varying mode** (tests 59-71): `eofu`, continuous outcome, `pooled`, `monotreat`, `death()`, `fixedcovariates()`, `laggedvars()`/`lagrules()`, `derived()`/`derrules()`, logit and regress MSM, multiple interventions, stored results, data preservation
- **Mediation expanded** (tests 72-81): `linexp`, `specific` with `baseline()`/`alternative()`, `post_confs()`, `moreMC`, `saving()`/`replace`, continuous outcome/mediator, multiple mediators, imputation, `baseline` effect type
- **Error handling** (tests 82-116): All invalid option combinations, missing required options, conflicting flags, gcomptab validation (oce rejection, shell metacharacter blocking, data/varabbrev preservation)

### Validation (validation_gcomp.do — 38 tests)

Correctness validation across 12 sections:

- **V1-V2**: Mediation decomposition invariants (TCE = NDE + NIE, PM = NIE/TCE) and known-answer DGP validation with tolerance bounds
- **V3**: Bootstrap properties (positive SEs, CIs contain estimates, positive CI widths, SE/V matrix consistency)
- **V4**: Scale option validation (`logOR` and `logRR` produce different estimates than risk difference)
- **V5**: `minsim` vs random draws consistency
- **V6**: gcomptab value accuracy (12 tests) — `r()` scalars match input, Excel structure (7 rows × 5 columns), point estimates/CIs/SEs present, negative effects, custom labels, title, decimal precision, CI type default
- **V7-V8**: Time-varying mode and continuous outcome validation
- **V9**: Reproducibility (same seed → same results)
- **V10-V12**: Stored result accuracy (`e(N)`, `e(MC_sims)`, `e(samples)` match inputs), linexp decomposition

## References

- Robins JM (1986). A new approach to causal inference in mortality studies with a sustained exposure period. *Mathematical Modelling* 7:1393-1512.
- Daniel RM, De Stavola BL, Cousens SN (2011). gformula: Estimating causal effects in the presence of time-varying confounding or mediation using the g-computation formula. *The Stata Journal* 11(4):479-517.

## Credits

Original author: Rhian Daniel (LSHTM)
Fork maintainer: Timothy P Copeland (Karolinska Institutet)
