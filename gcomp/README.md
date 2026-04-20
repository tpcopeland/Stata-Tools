# gcomp - Parametric g-computation for mediation and time-varying confounding

**Version 1.0.2** | 2026-04-19

`gcomp` implements Robins' parametric g-computation formula in Stata using Monte Carlo simulation and bootstrap inference. The package supports two related workflows: causal mediation analysis and longitudinal causal effects with time-varying confounding.

`gcomp` is a maintained fork of SSC `gformula` v1.16 beta (Rhian Daniel, 2021) with bug fixes, modernization, and removal of SSC dependencies. The companion command `gcomptab` formats supported mediation results into publication-ready Excel tables.

## Requirements

- Stata 16 or later

## Installation

```stata
capture ado uninstall gcomp
net install gcomp, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/gcomp") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `gcomp` | Estimate mediation effects or longitudinal causal effects via parametric g-computation |
| `gcomptab` | Export supported `gcomp` mediation results to formatted Excel tables |

## How It Works

`gcomp` always needs the same two building blocks:

- `commands()` tells Stata which model family to use for each simulated variable, such as `logit`, `regress`, `mlogit`, or `ologit`.
- `equations()` tells Stata which predictors belong in each model.

From there, the workflow branches:

- In **mediation mode**, you add `mediation`, identify the exposure and mediator, specify baseline confounders, and choose an effect type such as `obe`, `oce`, `linexp`, or `specific`.
- In **time-varying mode**, you identify the subject and time variables, list the time-varying confounders, and define the interventions to compare.

`gcomptab` is a post-estimation formatter. Run it only after a supported mediation fit from `gcomp`.

## Choosing a Mode

| Use case | Core syntax pattern | What you get |
|----------|---------------------|--------------|
| Binary or categorical mediation | `gcomp ..., outcome() mediation exposure() mediator() base_confs() effect_type` | TCE, NDE, NIE, PM, and sometimes CDE |
| Time-varying confounding | `gcomp ..., outcome() idvar() tvar() varyingcovariates() intvars() interventions()` | Potential outcomes under user-specified longitudinal interventions |
| Excel export of mediation results | `gcomptab, xlsx() sheet()` | Publication-ready mediation table in `.xlsx` format |

## Worked Examples

### 1. Binary-exposure mediation with generated data

This example mirrors the main help-file workflow. The data are simulated in-place, so nothing else needs to be installed. The small `sim()` and `samples()` values keep the example quick; for a real analysis, increase them materially.

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
    base_confs(c) sim(100) samples(20) seed(42)
```

Use this pattern when the exposure is binary and you want the usual decomposition into total, direct, and indirect effects.

### 2. Export a mediation fit to Excel with `gcomptab`

Run `gcomptab` immediately after a supported mediation model. The workbook path is just a normal filename in the current working directory.

```stata
gcomptab, xlsx("mediation_results.xlsx") sheet("Table 1") ///
    title("Causal Mediation: Smoking Effect via Inflammation")
```

`gcomptab` formats the estimates, confidence intervals, and standard errors into a polished Excel table. It is intended for mediation output, not the time-varying intervention workflow.

### 3. Categorical-exposure mediation with `oce`

Use `oce` when the exposure has more than two levels.

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
    base_confs(c) sim(100) samples(20) seed(42)
```

This estimates mediation contrasts across exposure levels. `gcomptab` is not the formatter for `oce`; use it for the standard supported mediation outputs described in the help file.

### 4. Time-varying confounding in long data

Here the data are already in long format with one row per person-time observation. `L` is the time-varying confounder, `A` is the intervention variable, and `outcome` is the binary outcome. With `eofu`, only the final-row outcome is used conceptually; earlier nonmissing values are ignored by design.

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
    sim(50) samples(10) seed(42) eofu
```

The `interventions()` syntax is label-plus-replacement. In the example above, `A_` is the intervention label and `A_=1` or `A_=0` is the actual intervention rule applied to the variable named in `intvars()`.

## Core Options

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

- `e(b)`: named effect estimates
- `e(V)`: variance matrix
- `e(se)`: standard errors
- `e(ci_normal)`: normal-based confidence intervals
- `e(ci_percentile)`, `e(ci_bc)`, and `e(ci_bca)` when requested
- metadata such as `e(analysis_type)`, `e(outcome)`, `e(exposure)`, and `e(mediation_type)` when applicable

After `gcomptab`, formatted export details are stored in `r()`, including the workbook name, sheet name, CI type, and effect estimates copied into the table.

## References

- Robins JM. 1986. A new approach to causal inference in mortality studies with sustained exposure periods. *Mathematical Modelling* 7(9-12):1393-1512.
- Daniel RM, De Stavola BL, Cousens SN. 2011. gformula: Estimating causal effects in the presence of time-varying confounding or mediation using the g-computation formula. *Stata Journal* 11(4):479-517.

## Version History

- **1.0.2** (2026-04-19): Current Stata-Tools release
