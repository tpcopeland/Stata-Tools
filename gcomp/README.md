# gcomp — Parametric g-computation for mediation and time-varying confounding

**Version 1.1.0** | 2026-04-26

`gcomp` implements Robins' parametric g-computation formula in Stata using Monte Carlo simulation and bootstrap inference. It supports two related causal-inference workflows: **causal mediation analysis** and **longitudinal causal-effect estimation** in the presence of time-varying confounding.

This Stata-Tools release is a maintained fork of SSC `gformula` v1.16 beta (Rhian Daniel, 2021) with bug fixes, modernization, and removal of SSC dependencies. The companion command `gcomptab` formats supported mediation results into publication-ready Excel tables.

## Requirements

- Stata 16 or later
- No external dependencies — all required functionality is bundled

## Installation

```stata
capture ado uninstall gcomp
net install gcomp, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/gcomp") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `gcomp` | Estimate mediation effects or longitudinal causal effects via parametric g-computation |
| `gcomptab` | Export supported `gcomp` mediation results to a formatted Excel table |

## How It Works

### The core idea

Standard regression adjusts for confounders by including them in a model. But when confounders are themselves affected by prior exposure — the time-varying confounding problem — this approach can introduce bias. Similarly, when a mediator-outcome confounder is affected by the exposure, standard mediation methods fail.

G-computation solves both problems by:

1. **Fitting parametric models** to the observed data (one model per variable you need to simulate)
2. **Simulating a copy of the population** under each hypothetical scenario (e.g. "everyone treated" vs. "no one treated")
3. **Comparing outcomes** across scenarios to estimate the causal effect

Bootstrap confidence intervals are obtained by repeating the entire procedure on resampled data.

### Two required ingredients

Every `gcomp` call needs:

- **`commands()`** — tells Stata which model family to use for each simulated variable: `logit` (binary), `regress` (continuous), `mlogit` (multinomial), or `ologit` (ordinal)
- **`equations()`** — tells Stata which predictors belong in each of those models

Both use a colon-separated, comma-delimited syntax:

```stata
commands(m: logit, y: logit)
equations(m: x c, y: m x c)
```

### Choosing a workflow

| Use case | Core syntax pattern | What you get |
|----------|---------------------|--------------|
| **Mediation** (binary exposure) | `gcomp ..., outcome() mediation obe exposure() mediator() base_confs()` | TCE, NDE, NIE, PM, and optionally CDE |
| **Mediation** (categorical exposure) | `gcomp ..., outcome() mediation oce exposure() mediator() base_confs()` | Per-level mediation contrasts |
| **Time-varying confounding** | `gcomp ..., outcome() idvar() tvar() varyingcovariates() intvars() interventions()` | Potential outcomes under hypothetical interventions |
| **Excel export** | `gcomptab, xlsx() sheet()` | Publication-ready table from supported mediation results |

## Worked Examples

### 1. Binary-exposure mediation (OBE)

The simplest mediation setup: a binary exposure, a binary mediator, a binary outcome, and a continuous confounder. We simulate data with known effects so you can verify the output.

```stata
clear
set seed 12345
set obs 1000
gen double c = rnormal(50, 10)
gen double x = rbinomial(1, invlogit(-2 + 0.02 * c))
gen double m = rbinomial(1, invlogit(-1 + 0.8 * x + 0.01 * c))
gen double y = rbinomial(1, invlogit(-3 + 0.5 * m + 0.3 * x + 0.02 * c))

gcomp y m x c, outcome(y) mediation obe ///
    exposure(x) mediator(m) ///
    commands(m: logit, y: logit) ///
    equations(m: x c, y: m x c) ///
    base_confs(c) sim(500) samples(200) seed(42)
```

The output reports the total causal effect (TCE), natural direct effect (NDE), natural indirect effect (NIE), and proportion mediated (PM). The `sim()` and `samples()` values are kept small for speed — use much larger values for real analyses (e.g. `sim(10000) samples(1000)`).

### 2. Adding a controlled direct effect

Add `control(0)` to fix the mediator at 0 for all subjects and estimate the CDE alongside the natural effects:

```stata
gcomp y m x c, outcome(y) mediation obe ///
    exposure(x) mediator(m) ///
    commands(m: logit, y: logit) ///
    equations(m: x c, y: m x c) ///
    base_confs(c) control(0) sim(500) samples(200) seed(42)
```

### 3. Export supported mediation results to Excel

Run `gcomptab` immediately after a supported mediation model. The workbook path is an ordinary filename in the current working directory.

```stata
gcomptab, xlsx("mediation_results.xlsx") sheet("Table 1") ///
    title("Causal Mediation: Smoking Effect via Inflammation")
```

`gcomptab` formats estimates, confidence intervals, and standard errors into a polished Excel table. It supports `obe`, `linexp`, `specific`, and baseline mediation — it does not support `oce` results.

### 4. Categorical-exposure mediation (OCE)

Use `oce` when the exposure has more than two levels and you want mediation contrasts against a baseline level.

```stata
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

Each non-baseline exposure level produces its own set of mediation contrasts. Convenience scalars are stored as `e(tce_1)`, `e(nde_1)`, etc. Because `gcomptab` does not format `oce` output, review the stored `e()` results directly or build custom tables from them.

### 5. Time-varying confounding in long data

Panel data with 120 subjects over 3 time points. `A` is the time-varying treatment, `L` is the time-varying confounder affected by prior treatment, and `outcome` is recorded only on the final row for each subject (`eofu`).

```stata
clear
set seed 20260421
set obs 360
gen long id = ceil(_n / 3)
bysort id: gen int time = _n
gen double L0 = rnormal()
bysort id (time): replace L0 = L0[1]
gen byte A = .
gen double L = .
gen byte Alag = 0
gen double Llag = 0

bysort id (time): replace L = 0.15 + 0.65 * L0 + rnormal(0, 0.35) if time == 1
bysort id (time): replace A = rbinomial(1, invlogit(-0.35 + 0.70 * L + 0.20 * L0)) if time == 1

bysort id (time): replace L = 0.10 + 0.60 * L[_n-1] - 0.55 * A[_n-1] + 0.15 * L0 + rnormal(0, 0.35) if time == 2
bysort id (time): replace A = rbinomial(1, invlogit(-0.25 + 0.60 * L + 0.20 * L0)) if time == 2

bysort id (time): replace L = 0.05 + 0.55 * L[_n-1] - 0.55 * A[_n-1] + 0.10 * L0 + rnormal(0, 0.35) if time == 3
bysort id (time): replace A = rbinomial(1, invlogit(-0.15 + 0.55 * L + 0.20 * L0)) if time == 3

bysort id (time): replace Alag = A[_n-1] if _n > 1
bysort id (time): replace Llag = L[_n-1] if _n > 1

gen byte outcome = 0
bysort id (time): replace outcome = rbinomial(1, invlogit(-1.35 - 0.90 * A[_n-1] + 0.75 * L[_n-1] + 0.20 * L0)) if time == 3

gcomp outcome L0 A L Alag Llag id time, outcome(outcome) ///
    idvar(id) tvar(time) ///
    varyingcovariates(L) fixedcovariates(L0) ///
    laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
    commands(A: logit, outcome: logit, L: regress) ///
    equations(A: L0 L, outcome: Alag Llag L0, L: Alag Llag L0) ///
    intvars(A) interventions(A=1, A=0) ///
    sim(120) samples(5) seed(20260421) eofu
```

This estimates potential outcomes under "always treat" (`A=1`) and "never treat" (`A=0`), accounting for the time-varying confounder `L` that is both a predictor of treatment and affected by past treatment. For `eofu` analyses, record the outcome only on the final row — earlier nonmissing values are ignored by design.

## Key Options

### gcomp

| Option | Role |
|--------|------|
| `outcome(varname)` | Identify the outcome variable |
| `commands(string)` | Choose the model family for each simulated variable |
| `equations(string)` | Specify the predictor set for each simulated variable |
| `mediation` | Switch into mediation mode |
| `exposure(varlist)` | Identify the exposure variable(s) for mediation |
| `mediator(varlist)` | Identify the mediator variable(s) |
| `base_confs(varlist)` | List baseline confounders for mediation |
| `control(string)` | Set mediator level for CDE; without this, CDE is not estimated |
| `idvar(varname)` / `tvar(varname)` | Identify subject and time in long data |
| `varyingcovariates(varlist)` | List time-varying confounders affected by prior exposure |
| `intvars(varlist)` / `interventions(string)` | Define the variables and rules for hypothetical interventions |
| `eofu` | Outcome is measured only on the last row per subject |
| `simulations(#)` / `samples(#)` | Set Monte Carlo sample size and bootstrap replications |
| `diagnostics` | Display model-fit statistics during initial estimation |
| `all` | Report all four CI types (normal, percentile, BC, BCa) |
| `seed(#)` | Set random number seed for reproducibility |

### gcomptab

| Option | Role |
|--------|------|
| `xlsx(filename)` | Excel workbook to create or update |
| `sheet(string)` | Sheet name to create or replace |
| `ci(string)` | Confidence-interval type: `normal` (default), `percentile`, `bc`, `bca` |
| `title(string)` | Table title written into cell A1 |
| `labels(string)` | Override the default effect labels (backslash-separated) |
| `decimal(#)` | Decimal places for numeric values (default 3, range 1-6) |
| `boldp(#)` | Bold numeric cells when Wald p < cutoff |
| `highlight(#)` | Highlight row in yellow when Wald p < cutoff |
| `zebra` | Alternating row shading |
| `footnote(string)` | Footnote text below the table |

## Returned Results

### After `gcomp`

All results are stored in `e()`:

**Scalars:** `e(N)` (subjects), `e(MC_sims)` (Monte Carlo sample size), `e(samples)` (bootstrap replications).

**Matrices:** `e(b)` (point estimates), `e(V)` (variance-covariance), `e(se)` (standard errors), `e(ci_normal)` (normal CIs), and optionally `e(ci_percentile)`, `e(ci_bc)`, `e(ci_bca)` (with `all`). `e(effects)` provides an effecttab-compatible matrix (estimate, ci_lower, ci_upper, pvalue) for non-`oce` mediation. `e(model_diagnostics)` stores model-fit statistics.

**Macros:** `e(cmd)` (`"gcomp"`), `e(analysis_type)` (`"mediation"` or `"time_varying"`), `e(outcome)`, `e(exposure)`, `e(mediator)`, `e(mediation_type)`, `e(scale)`, `e(msm)`.

**Convenience scalars (mediation, non-oce):** `e(tce)`, `e(nde)`, `e(nie)`, `e(pm)`, `e(cde)`, and their SEs (`e(se_tce)`, etc.).

**Convenience scalars (mediation, oce):** `e(tce_j)`, `e(nde_j)`, `e(nie_j)`, `e(pm_j)`, `e(cde_j)` for each contrast *j*.

**Time-varying mode:** `e(obs_data)` (observed outcome prevalence).

### After `gcomptab`

Results are stored in `r()`: `r(N_effects)` (4 or 5), `r(tce)`, `r(nde)`, `r(nie)`, `r(pm)`, `r(cde)` (if applicable), `r(xlsx)`, `r(sheet)`, `r(ci)`.

## References

- Robins JM. 1986. A new approach to causal inference in mortality studies with sustained exposure periods. *Mathematical Modelling* 7(9-12):1393-1512.
- Daniel RM, De Stavola BL, Cousens SN. 2011. gformula: Estimating causal effects in the presence of time-varying confounding or mediation using the g-computation formula. *Stata Journal* 11(4):479-517.
- Taubman SL, Robins JM, Mittleman MA, Hernan MA. 2009. Intervening on risk factors for coronary heart disease: an application of the parametric g-formula. *International Journal of Epidemiology* 38(6):1599-1611.
- VanderWeele TJ. 2015. *Explanation in causal inference: methods for mediation and interaction*. Oxford University Press.

## Version History

- **1.1.0** (2026-04-26): Input validation and model-fit diagnostics. `commands()`, `equations()`, and related options are now validated before the bootstrap loop — mismatches produce clear error messages naming the offending variable. New `diagnostics` option displays model-fit statistics (N, convergence, R^2/pseudo-R^2, RMSE) for each parametric model during the initial estimation run. Diagnostics are always stored in `e(model_diagnostics)`.
- **1.0.3** (2026-04-22): Fix time-varying g-computation regression — varlist2 ordering had been reversed (outcome first) in v1.0.2, causing `predict pred_Y` to fire before time-varying confounders and treatment were sampled at each visit. Every simulated outcome came out as 1 (silent wrong results); `minsim` errored with r(503). Restores outcome-last ordering from v1.0.1. Adds V7.3 minsim regression test and tightens V7.1 assertions to guard against re-introduction.
- **1.0.2** (2026-04-19): Stata-Tools fork release with bundled Excel export support via `gcomptab`

## Author

Fork maintainer: Timothy P Copeland, Karolinska Institutet. Original command by Rhian Daniel, London School of Hygiene and Tropical Medicine.

## License

MIT
