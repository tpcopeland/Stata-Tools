# gcomp - Parametric g-computation for mediation and time-varying confounding

**Version 1.0.2** | 2026-04-19

`gcomp` implements Robins' parametric g-computation formula in Stata using Monte Carlo simulation and bootstrap inference. The package supports two related workflows: causal mediation analysis and longitudinal causal effects in the presence of time-varying confounding.

This Stata-Tools release is a maintained fork of SSC `gformula` v1.16 beta (Rhian Daniel, 2021) with bug fixes, modernization, and removal of SSC dependencies. The companion command `gcomptab` formats supported mediation results into publication-ready Excel tables.

## Requirements

- Stata 16 or later
- No external dependencies beyond official Stata commands bundled with Stata 16+

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

`gcomp` always needs the same two core ingredients:

- `commands()` tells Stata which model family to use for each simulated variable, such as `logit`, `regress`, `mlogit`, or `ologit`
- `equations()` tells Stata which predictors belong in each of those models

From there the workflow branches:

- In **mediation mode**, add `mediation`, identify the exposure and mediator, supply baseline confounders, and choose an effect type such as `obe`, `oce`, `linexp`, or `specific`
- In **time-varying mode**, identify the subject and time variables, list the time-varying confounders, and define the interventions to compare
- `gcomptab` is a post-estimation formatter. Run it only after a supported mediation fit from `gcomp`

## Choosing a Workflow

| Use case | Core syntax pattern | What you get |
|----------|---------------------|--------------|
| Binary or categorical mediation | `gcomp ..., outcome() mediation exposure() mediator() base_confs() effect_type` | TCE, NDE, NIE, PM, and sometimes CDE |
| Time-varying confounding | `gcomp ..., outcome() idvar() tvar() varyingcovariates() intvars() interventions()` | Potential outcomes under user-specified longitudinal interventions |
| Excel export of mediation output | `gcomptab, xlsx() sheet()` | Publication-ready `.xlsx` table from supported mediation results |

## Worked Examples

### 1. Binary-exposure mediation with simulated data

This mirrors the main help-file mediation workflow and runs from a clean Stata session. The small `sim()` and `samples()` values keep the example fast; use much larger values for real analyses.

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

Use this pattern when the exposure is binary and you want the standard decomposition into total, direct, and indirect effects.

### 2. Export supported mediation results to Excel with `gcomptab`

Run `gcomptab` immediately after a supported mediation model. The workbook path is just a normal filename in the current working directory.

```stata
gcomptab, xlsx("mediation_results.xlsx") sheet("Table 1") ///
    title("Causal Mediation: Smoking Effect via Inflammation")
```

`gcomptab` formats estimates, confidence intervals, and standard errors into a polished Excel table. It is intended for supported mediation output, not the time-varying intervention workflow, and it does not support `oce` results.

### 3. Categorical-exposure mediation with `oce`

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

This produces mediation contrasts across exposure levels. Because `gcomptab` does not format `oce` output, review the stored `e()` results directly or build custom tables from them.

### 4. Time-varying confounding in long data

Here the data are already in long format with one row per person-time observation. `L` is the time-varying confounder, `A` is the intervention variable, and `outcome` is the binary outcome.

```stata
clear
set seed 98765
set obs 600
gen long id = ceil(_n / 3)
bysort id: gen int time = _n
gen double L = rnormal()
gen double A = rbinomial(1, invlogit(-1 + 0.3 * L))
gen double outcome = rbinomial(1, invlogit(-2 + 0.5 * L + 0.4 * A))

gcomp outcome L A id time, outcome(outcome) ///
    idvar(id) tvar(time) ///
    varyingcovariates(L) ///
    commands(L: regress, outcome: logit, A: logit) ///
    equations(L: A, outcome: L A, A: L) ///
    intvars(A) interventions(A_: A_=1, A_: A_=0) ///
    sim(500) samples(200) seed(42) eofu
```

For `eofu` analyses, record the outcome only on the final row for each subject. Earlier nonmissing values are ignored by design.

## Key Options

### `gcomp`

| Option | Role |
|--------|------|
| `outcome(varname)` | Identify the outcome variable |
| `commands(string)` | Choose the model family for each simulated variable |
| `equations(string)` | Specify the predictor set for each simulated variable |
| `mediation` | Switch into mediation mode |
| `exposure(varlist)` | Identify the exposure variable or variables for mediation |
| `mediator(varlist)` | Identify the mediator variable or variables |
| `base_confs(varlist)` | List baseline confounders for mediation |
| `idvar(varname)` / `tvar(varname)` | Identify subject and time in long data |
| `varyingcovariates(varlist)` | List time-varying confounders affected by prior exposure |
| `intvars(varlist)` | List the variables the intervention acts on |
| `interventions(string)` | Define the intervention rules to compare |
| `simulations(#)` / `samples(#)` | Set Monte Carlo sample size and bootstrap replications |

### `gcomptab`

| Option | Role |
|--------|------|
| `xlsx(filename)` | Excel workbook to create or update |
| `sheet(string)` | Sheet name to create or replace |
| `ci(string)` | Confidence-interval type to display |
| `title(string)` | Table title written into the workbook |
| `labels(string)` | Override the default effect labels |
| `decimal(#)` | Control numeric precision |

## Returned Results

After `gcomp`, the main results are stored in `e()`, including:

- `e(b)`, `e(V)`, and `e(se)` for point estimates and uncertainty
- `e(ci_normal)` and, with `all`, `e(ci_percentile)`, `e(ci_bc)`, and `e(ci_bca)`
- metadata such as `e(analysis_type)`, `e(outcome)`, `e(exposure)`, `e(mediator)`, and `e(mediation_type)`
- convenience mediation scalars such as `e(tce)`, `e(nde)`, `e(nie)`, `e(pm)`, and `e(cde)` when applicable

After `gcomptab`, export details are stored in `r()`, including the workbook name, sheet name, CI type, number of effects exported, and effect estimates copied into the table.

## References

- Robins JM. 1986. A new approach to causal inference in mortality studies with sustained exposure periods. *Mathematical Modelling* 7(9-12):1393-1512.
- Daniel RM, De Stavola BL, Cousens SN. 2011. gformula: Estimating causal effects in the presence of time-varying confounding or mediation using the g-computation formula. *Stata Journal* 11(4):479-517.

## Version History

- **1.0.2** (2026-04-19): Current Stata-Tools fork release with bundled Excel export support via `gcomptab`

## Author

Fork maintainer: Timothy P Copeland, Karolinska Institutet. Original command by Rhian Daniel, London School of Hygiene and Tropical Medicine.

## License

MIT
