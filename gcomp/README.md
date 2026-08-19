# gcomp — Parametric g-computation for mediation and longitudinal interventions

**Version 1.6.0** | 2026-08-19

`gcomp` estimates causal effects with parametric g-computation and Monte Carlo simulation for cross-sectional mediation and time-varying interventions. `gcomptab` exports mediation and dose-response results to Excel, Markdown, or CSV, and component-model results to Excel, Markdown, CSV, or the Results window.

## Quick Start

Fit a binary-exposure mediation model and inspect the posted effects:

```stata
clear
set seed 12345
set obs 800
generate double c = rnormal()
generate byte x = rbinomial(1, invlogit(.2*c))
generate byte m = rbinomial(1, invlogit(-.5 + .7*x + .2*c))
generate byte y = rbinomial(1, invlogit(-1 + .5*x + .7*m + .2*c))

gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c) simulations(400) samples(50) seed(42)
ereturn list
```

The main effect estimates are posted in `e(b)`, with bootstrap standard errors and confidence intervals in `e(se)` and the `e(ci_*)` matrices; non-OCE mediation runs also post named scalars such as `e(tce)`, `e(nde)`, and `e(nie)`.

## Requirements

- Stata 16 or later.
- No external Stata package is required; `gcomptab` uses Stata's built-in Results-window, text, and Excel-writing facilities.

## Installation

Run this in Stata:

```stata
capture ado uninstall gcomp
net install gcomp, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/gcomp") replace
```

The distribution installs the two public commands and their package-prefixed helper programs. The `demo/` and `qa/` directories are repository documentation and are not part of the `net install` payload.

## Commands

| Command | Purpose |
|---|---|
| `gcomp` | Fits parametric component models, simulates intervention or mediation worlds, and obtains bootstrap inference. |
| `gcomptab` | Exports mediation effects, time-varying dose-response results, or `gcomp` component models. |

## How It Works

`gcomp` parses the model map in `commands()` and `equations()`, fits the requested `logit`, `regress`, `mlogit`, `ologit`, `poisson`, or NB2 `nbreg` components, simulates the specified worlds, and bootstraps the complete estimate vector. Count targets must be nonnegative integers. `nbreg` uses Stata's default `dispersion(mean)` gamma-Poisson law; NB1 `dispersion(constant)` is rejected, and fitted alpha at or below `1e-8` uses the Poisson boundary.

Cross-sectional mediation uses one row per subject and requires an exposure and one or more causally ordered mediators. Choose an outcome-scale effect definition with `obe`, `oce`, `linexp`, `specific`, or `baseline`; `control()` requests controlled direct effects and `post_confs()` supports post-exposure mediator-outcome confounders. `structural()` declares deterministic regions: each target model is fitted on the complement, and the forced value is assigned using already-simulated upstream values in each counterfactual world.

Time-varying analyses use long data with a numeric subject identifier and visit variable. `intvars()` and `interventions()` define treatment regimes; `varyingcovariates()`, `fixedcovariates()`, `laggedvars()`, `derived()`, and their rule options describe the longitudinal data-generating process.

Monte Carlo size defaults to the observed analytic sample in mediation and to the number of subjects in time-varying mode; `simulations()` can set it explicitly. `samples()` defaults to 1,000 bootstrap replications. The run attempts all requested draws, and successful inference requires at least `max(2, ceil(.90 × requested))` successful draws.

`gcomp` warns unconditionally when an initial component model uses fewer eligible observations than it was offered; likely causes include perfect prediction, collinearity, and missing predictor values. The comparison uses the model's visit and monotreatment qualifier, requires a nonmissing target, and excludes rows removed by declared imputation eligibility. Use `diagnostics` to display the initial component-model summaries and inspect their fitted `N` values, `all` to request all supported bootstrap confidence-interval matrices, `saving()` to save the exact point-estimate simulation data, and `savemodels`/`showmodels` to expose analytic-sample component-model refits for reporting.

## Choosing a Workflow

| Goal | Data layout | Main options | Reporting command |
|---|---|---|---|
| Total, direct, indirect, or proportion mediated effect | One row per subject | `mediation` plus one of `obe`, `oce`, `linexp`, `specific`, or `baseline` | `gcomptab` for an effect table |
| Controlled direct effect | One row per subject | Mediation options plus `control()` | `gcomptab` with `effect()` or `labels()` |
| Longitudinal intervention, dose-response, or survival contrast | One row per subject-visit | `idvar()`, `tvar()`, `intvars()`, and `interventions()` | `gcomptab, doseresponse` |
| Component-model audit table | Either supported layout | `savemodels` or `showmodels` | `gcomptab, models` |

## Worked Examples

### 1. Binary mediation: overall effect

The following self-contained example estimates an outcome-scale mediation decomposition with a binary exposure, mediator, and outcome:

```stata
clear
set seed 12345
set obs 800
generate double c = rnormal()
generate byte x = rbinomial(1, invlogit(.2*c))
generate byte m = rbinomial(1, invlogit(-.5 + .7*x + .2*c))
generate byte y = rbinomial(1, invlogit(-1 + .5*x + .7*m + .2*c))

gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c) simulations(400) samples(50) seed(42)
matrix list e(b)
```

### 2. Controlled direct effect

Set `control(0)` to hold the binary mediator at zero while estimating the exposure contrast:

```stata
clear
set seed 12345
set obs 800
generate double c = rnormal()
generate byte x = rbinomial(1, invlogit(.2*c))
generate byte m = rbinomial(1, invlogit(-.5 + .7*x + .2*c))
generate byte y = rbinomial(1, invlogit(-1 + .5*x + .7*m + .2*c))

gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) control(0) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c) simulations(400) samples(50) seed(42)
display e(cde)
```

### 3. Deterministic outcome region

Here `y` is structurally zero whenever `m==0`. The outcome model is fitted only where `m!=0`, and the same rule is imposed after each simulated mediator draw. `showmodels` displays the complement-sample refit.

```stata
clear
set seed 24680
set obs 1000
generate double c = rnormal()
generate byte x = rbinomial(1, invlogit(.5*c))
generate byte m = rbinomial(1, invlogit(-.4 + .8*x + .3*c))
generate byte y = 0
replace y = rbinomial(1, invlogit(-1 + .5*x + .2*c)) if m == 1

gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    structural(y: m == 0 => 0) base_confs(c) ///
    simulations(300) samples(5) seed(24680) showmodels
```

### 4. NB2 count mediator

Use `nbreg` for an overdispersed count mediator so simulated values follow the fitted NB2 distribution and cannot be negative:

```stata
clear
set seed 13579
set obs 1000
generate double c = rnormal()
generate byte x = rbinomial(1, invlogit(.2*c))
generate double mu = exp(-.2 + .6*x + .2*c)
generate long m = rpoisson(rgamma(2, .5*mu))
generate double y = .3 + .4*x + .5*m + .2*c + rnormal()

gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: nbreg, y: regress) equations(m: x c, y: m x c) ///
    base_confs(c) simulations(500) samples(5) seed(13579)
```

### 5. Categorical exposure: OCE

`oce` estimates indexed contrasts for each observed exposure level and does not require a binary exposure:

```stata
clear
set seed 54321
set obs 900
generate double c = rnormal()
generate byte x = mod(_n - 1, 3)
generate byte m = rbinomial(1, invlogit(-.5 + .4*x + .2*c))
generate byte y = rbinomial(1, invlogit(-1 + .3*x + .7*m + .2*c))

gcomp y m x c, outcome(y) mediation oce exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c) simulations(400) samples(50) seed(42)
matrix list e(b)
```

### 6. Time-varying confounding with an end-of-follow-up outcome

This long-format example models treatment, a time-varying confounder, and a final-visit binary outcome:

```stata
clear
set seed 20260421
set obs 360
generate long id = ceil(_n/3)
bysort id: generate int time = _n
generate double L0 = rnormal()
bysort id (time): replace L0 = L0[1]
generate byte A = .
generate double L = .
generate byte Alag = 0
generate double Llag = 0
bysort id (time): replace L = 0.15 + 0.65*L0 + rnormal(0, .35) if time == 1
bysort id (time): replace A = rbinomial(1, invlogit(-.35 + .70*L + .20*L0)) if time == 1
bysort id (time): replace L = 0.10 + 0.60*L[_n-1] - 0.55*A[_n-1] + .15*L0 + rnormal(0, .35) if time == 2
bysort id (time): replace A = rbinomial(1, invlogit(-.25 + .60*L + .20*L0)) if time == 2
bysort id (time): replace L = 0.05 + 0.55*L[_n-1] - 0.55*A[_n-1] + .10*L0 + rnormal(0, .35) if time == 3
bysort id (time): replace A = rbinomial(1, invlogit(-.15 + .55*L + .20*L0)) if time == 3
bysort id (time): replace Alag = A[_n-1] if _n > 1
bysort id (time): replace Llag = L[_n-1] if _n > 1
generate byte outcome = 0
bysort id (time): replace outcome = rbinomial(1, invlogit(-1.35 - .90*A[_n-1] + .75*L[_n-1] + .20*L0)) if time == 3

gcomp outcome L0 A L Alag Llag id time, outcome(outcome) idvar(id) tvar(time) ///
    varyingcovariates(L) fixedcovariates(L0) ///
    laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
    commands(A: logit, outcome: logit, L: regress) ///
    equations(A: L0 L, outcome: Alag Llag L0, L: Alag Llag L0) ///
    intvars(A) interventions(A=1, A=0) eofu simulations(120) samples(5) seed(20260421)
matrix list e(b)
```

### 7. Diagnostics and confidence-interval matrices

Request model-fit diagnostics and all supported interval forms in one run:

```stata
clear
set seed 12345
set obs 800
generate double c = rnormal()
generate byte x = rbinomial(1, invlogit(.2*c))
generate byte m = rbinomial(1, invlogit(-.5 + .7*x + .2*c))
generate byte y = rbinomial(1, invlogit(-1 + .5*x + .7*m + .2*c))

gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c) simulations(400) samples(50) seed(42) diagnostics all
matrix list e(model_diagnostics)
matrix list e(ci_normal)
matrix list e(ci_percentile)
matrix list e(ci_bc)
matrix list e(ci_bca)
```

### 8. Mediation tables in Excel, Markdown, and CSV

The same fitted mediation result can be exported to multiple formats:

```stata
clear
set seed 12345
set obs 400
generate double c = rnormal()
generate byte x = rbinomial(1, invlogit(.2*c))
generate double m = .6*x + .3*c + rnormal()
generate double y = .7*m + .4*x + .2*c + rnormal()

gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) control(0) ///
    commands(m: regress, y: regress) equations(m: x c, y: m x c) ///
    base_confs(c) simulations(400) samples(50) seed(42)
gcomptab, xlsx("mediation_tables.xlsx") sheet("Normal CI") title("Mediation effects")
gcomptab, xlsx("mediation_tables.xlsx") sheet("Percentile CI") ci(percentile) ///
    markdown("mediation_table.md") csv("mediation_table.csv")
```

### 9. Longitudinal dose-response table

For a time-varying `eofu` analysis, `gcomptab, doseresponse` formats one row per intervention or observed regime:

```stata
clear
set seed 54321
set obs 600
generate long id = ceil(_n/3)
bysort id: generate int time = 2*_n - 1
generate double L = rnormal() + .1*time
generate byte A = rbinomial(1, invlogit(-.8 + .2*L))
generate byte Y = rbinomial(1, invlogit(-1 + .4*A + .2*L))

gcomp Y L A id time, outcome(Y) idvar(id) tvar(time) varyingcovariates(L) ///
    intvars(A) interventions(A=1, A=0) commands(L: regress, A: logit, Y: logit) ///
    equations(L: time, A: L time, Y: A L time) eofu pooled ///
    simulations(200) samples(50) seed(12345)
gcomptab, doseresponse xlsx("dose_response.xlsx") sheet("Dose response") ///
    strategylabels("Always A=1 \ Never A=0 \ Observed regime") ///
    expyears(5 0 2) reference(1) effect("Risk")
```

### 10. Component-model table

Use `savemodels` and `gcomptab, models` when the fitted component models need a compact coefficient table:

```stata
clear
set seed 12345
set obs 400
generate double c = rnormal()
generate byte x = rbinomial(1, invlogit(.2*c))
generate double m = .6*x + .3*c + rnormal()
generate double y = .7*m + .4*x + .2*c + rnormal()

gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: regress, y: regress) equations(m: x c, y: m x c) ///
    base_confs(c) simulations(400) samples(50) seed(42) savemodels
gcomptab, models xlsx("component_models.xlsx") sheet("Models") ///
    markdown("component_models.md") modellabels("Mediator (m) \ Outcome (y)") stats(n) stars
gcomptab, models display compact
```

## Demo

The repository checkout contains a reproducible report demo; the demo files are not included in the `net install` payload. From the Stata-Tools checkout root, run:

```bash
cd /path/to/Stata-Tools
stata-mp -b do gcomp/demo/demo_gcomp.do
```

`demo/demo_gcomp.do` is the canonical generator and covers mediation, controlled direct effects, OCE, time-varying `eofu`, Excel export, and component-model export. `demo/demo_gcomptab.do` is a compatibility wrapper, and `demo/manifest.md` records the generated artifacts and workbook sheet order.

The checkout includes [`demo/component_models.md`](demo/component_models.md) and [`demo/demo_gcomptab.xlsx`](demo/demo_gcomptab.xlsx); the workbook contains `Normal CI`, `Percentile CI`, and `Component models` sheets.

## Command Reference

### `gcomp`

Cross-sectional mediation:

```stata
gcomp varlist [if] [in], outcome(varname) commands(string) equations(string) ///
    mediation exposure(varlist) mediator(varlist) ///
    [obe | oce | specific | linexp | baseline] [control(string)] ///
    [structural(string)] [base_confs(varlist)]
```

Time-varying intervention:

```stata
gcomp varlist [if] [in], outcome(varname) commands(string) equations(string) ///
    idvar(varname) tvar(varname) intvars(varlist) interventions(string) ///
    [varyingcovariates(varlist) fixedcovariates(varlist) laggedvars(varlist) ///
     lagrules(string) derived(varlist) derrules(string) structural(string) eofu pooled monotreat ///
     dynamic death(varname) msm(string)]
```

In both layouts, the numeric varlist identifies the main analysis surface; variables named in options or referenced by legal factor-variable terms in `equations()` are retained automatically. The colon syntax in `commands()` and `equations()` maps each modeled variable to its estimator and predictors; list equations in causal generation order.

### `gcomptab`

Mediation, including a controlled direct effect:

```stata
gcomptab, xlsx(string) sheet(string) [ci(string) effect(string) labels(string) ///
    decimal(integer) title(string) markdown(string) csv(string) open]
```

Time-varying dose-response:

```stata
gcomptab, doseresponse xlsx(string) sheet(string) [strategylabels(string) ///
    expyears(numlist) reference(integer) nord effect(string) ci(string)]
```

Saved component models:

```stata
gcomptab, models [xlsx(string) sheet(string) markdown(string) csv(string) display] ///
    [usemodels(string) modellabels(string) termlabels(string) stats(string) ///
     coef(string) eform noeform raw se compact nopvalue stars starslevels(numlist) ///
     nointercept keepintercept keep(string) drop(string) digits(integer)]
```

Mediation and dose-response modes require `xlsx()` and `sheet()`; component-model mode can write to Excel, Markdown, CSV, the Results window, or any combination. Excel sheet names must be no longer than 31 characters and cannot contain Excel's reserved characters.

## Key Options

### `gcomp`

| Option | Contract |
|---|---|
| `outcome()` | Outcome variable; required in every run. |
| `commands()` | One estimator per modeled variable; supported families are `logit`, `regress`, `mlogit`, `ologit`, `poisson`, and NB2 `nbreg`. NB1 `dispersion(constant)` is not supported. |
| `equations()` | Predictor map using `variable: predictors` clauses; causal generation order is enforced. |
| `structural()` | Keyed deterministic rules such as `y: m == 0 => 0`; fits on the complement and forces the value using already-simulated upstream values. Conditions may use only earlier variables in the command varlist. |
| `mediation`, `exposure()`, `mediator()` | Select cross-sectional mediation and identify the exposure and causally ordered mediator list. |
| `obe`, `oce`, `linexp`, `specific`, `baseline` | Select the mediation effect definition; OCE returns indexed effects for the exposure levels. |
| `control()`, `alternative()`, `baseline()`, `base_confs()`, `post_confs()` | Define controlled exposure/mediator worlds and baseline or post-exposure confounder information for mediation. |
| `boceam`, `msm()`, `mediation` | Request the supported mediation extensions; `boceam` requires an MSM specification. |
| `logOR`, `logRR` | Request log odds-ratio or log risk-ratio effect scales where supported; they are mutually exclusive. |
| `idvar()`, `tvar()` | Identify numeric subject and visit variables for long-format time-varying analyses. |
| `varyingcovariates()`, `fixedcovariates()` | Identify covariates that are resimulated over visits or held at their subject-specific baseline values. |
| `intvars()`, `interventions()` | Identify intervention variables and define the intervention rules or regimes. |
| `laggedvars()`, `lagrules()` | Add lagged treatment or covariate variables and define how their lags are generated. |
| `derived()`, `derrules()` | Add derived variables and deterministic rules evaluated during simulation. |
| `eofu`, `pooled`, `monotreat`, `dynamic`, `death()` | Choose end-of-follow-up outcomes, common pooled coefficients, monotone treatment, dynamic regimes, or a competing event. |
| `impute()`, `imp_eq()`, `imp_cmd()`, `imp_cycles()` | Configure single stochastic chained-equation imputation with the component-model families above; `imp_cycles()` defaults to 10. |
| `simulations()`, `samples()`, `seed()`, `minsim`, `moreMC` | Control Monte Carlo size, bootstrap replications, random state, minimum-simulation checks, and the mediation-only larger-Monte-Carlo option. Defaults are observed sample size, 1,000, and no explicit seed. |
| `diagnostics`, `all`, `graph` | Display model diagnostics, retain the BCa interval matrix in addition to the default normal/percentile/BC matrices, or graph non-`eofu` time-varying survival results. |
| `saving()`, `replace` | Save exact point-estimate stochastic data and permit overwriting an existing file. |
| `savemodels`, `showmodels`, `modelstyle()` | Store or display analytic-sample component-model refit approximations; `modelstyle()` accepts `compact` or `native`. |

### `gcomptab`

| Option group | Contract |
|---|---|
| `xlsx()`, `sheet()`, `markdown()`, `csv()`, `open` | Select output targets; mediation and dose-response require Excel path and sheet, while `open` is best effort and returns `r(open_rc)`. |
| `ci()`, `effect()`, `labels()`, `title()`, `decimal()` | Select the interval matrix, effect label, row labels, title, and decimal places; CI defaults to normal and decimal defaults to 3. |
| `font()`, `fontsize()`, `borderstyle()`, `theme()` | Set font, font size, border preset, or a named preset (`lancet`, `nejm`, `bmj`, `apa`, `jama`, `plos`, `nature`, `cell`, or `annals`); defaults are Arial, 10, and thin borders. |
| `headershade`, `noshade`, `headercolor()`, `zebra`, `nozebra`, `zebracolor()`, `footnote()`, `boldp()`, `highlight()` | Control table shading, colors, notes, bold p-value cutoff, and highlight cutoff; the cutoffs default to 0, which disables emphasis. |
| `doseresponse`, `strategylabels()`, `expyears()`, `reference()`, `nord` | Select and label dose-response rows, add cumulative exposure-years, choose the reference strategy (default 1), or suppress the risk-difference column. |
| `models`, `usemodels()`, `modellabels()`, `termlabels()`, `stats()`, `display` | Select component-model mode, stored estimates, model and term labels, requested summary statistics, and Results-window output. |
| `coef()`, `eform`, `noeform`, `raw`, `se`, `compact`, `nopvalue`, `stars`, `starslevels()` | Override the scale-column label and select coefficient display columns; automatic model scales are OR for logit/ologit, RRR for mlogit, and Coef for regress. Model inference uses residual-df t statistics when available and normal statistics otherwise. |
| `nointercept`, `keepintercept`, `keep()`, `drop()`, `digits()` | Filter terms and set model-table digits; `digits(-1)` uses the decimal setting. |

## Stored Results

### After `gcomp`

The command is `eclass` and posts the following result groups:

| Result | Meaning |
|---|---|
| `e(b)`, `e(V)`, `e(se)` | Named point estimates, full bootstrap covariance, and standard errors. |
| `e(ci_normal)`, `e(ci_percentile)`, `e(ci_bc)`, `e(ci_bca)` | Bootstrap confidence intervals; `all` is required for the BCa matrix. |
| `e(tce)`, `e(nde)`, `e(nie)`, `e(pm)`, `e(cde)` and corresponding `e(se_*)` | Convenience mediation scalars for non-OCE runs; CDE is present when requested. |
| `e(tce_j)`, `e(nde_j)`, `e(nie_j)`, `e(pm_j)`, `e(cde_j)` | Indexed convenience scalars for OCE contrasts. |
| `e(model_diagnostics)` | Component-model rows with `N`, `converged`, `ll`, `r2`, and `rmse`. |
| `e(N)`, `e(N_rows)`, `e(N_subjects)`, `e(MC_sims)`, `e(samples)` | Analytic-sample and resampling sizes; `e(N)` is rows for mediation and subjects for time-varying analyses. |
| `e(bootstrap_requested)`, `e(bootstrap_attempted)`, `e(bootstrap_successful)`, `e(bootstrap_failed)`, `e(seed)` | Bootstrap accounting and optional seed. |
| `e(analysis_type)`, `e(outcome)`, `e(outcome_cmd)`, `e(exposure)`, `e(mediator)`, `e(mediation_type)`, `e(scale)`, `e(idvar)`, `e(tvar)`, `e(intvars)`, `e(interventions)`, `e(structural)` | Analysis and design metadata, including the outcome model family and deterministic rules. |
| `e(saving)`, `e(saved_schema_version)`, `e(saved_arm_schema)`, `e(run_id)`, `e(rngstate)`, `e(graph)` | Point-run saving, reproducibility, and optional graph metadata when applicable. |
| `e(model_names)`, `e(model_cmds)`, `e(model_depvars)`, `e(model_eq_1)`, `e(model_skipped)`, `e(model_capture)` | Component-model manifest when `savemodels` is used; `e(model_eq_1)` illustrates the indexed equation family. |
| `e(msm)`, `e(msm_colnames)` | Marginal structural-model specification and coefficient names when an MSM is requested. |
| `e(obs_data)` | Observed mean for `eofu` analyses or average log incidence for survival analyses. |
| Time-varying `e(b)` columns `PO#`, `out#`, `death#` | One `PO#` column per intervention plus the simulated observed regime; non-`eofu` survival runs also use `out#` for cumulative incidence and may include `death#`. |

Imputation metadata includes `e(impute_targets)`, `e(N_impute_targets)`, and indexed families such as `e(impute_target_1)`, `e(impute_needed_1)`, `e(impute_eligible_1)`, and `e(impute_dropped_1)`. Additional replay macros are listed by `ereturn list` after a run. `e(sample)` identifies the original analytic rows.

### After `gcomptab`

Mediation mode returns `r(N_effects)`, `r(has_cde)`, named effects, the selected `r(ci)`, and output-path returns such as `r(xlsx)`, `r(sheet)`, `r(markdown)`, and `r(csv)`. Dose-response mode returns `r(k)`, `r(reference)`, `r(ref_label)`, and `r(table)`. Component-model mode returns `r(N_models)`, `r(N_rows)`, `r(N_cols)`, `r(coef_label)`, `r(term_names)`, `r(methods)`, `r(table)`, and the output-path returns; `open` additionally returns `r(open_rc)`.

## Assumptions and Limits

Interpret causal effects using the assumptions required by the g-computation formula: consistency and well-defined interventions, positivity, the relevant sequential exchangeability conditions, correctly specified and causally ordered component models, and no interference between subjects. Natural mediation effects additionally require the cross-world assumptions implied by their definition.

For multiple mediators, list variables in causal simulation order; each later mediator is generated conditional on earlier same-arm draws. `fixedcovariates()` variables are held at their subject-specific baseline values, and loop-only predictors can be omitted from analytic-sample component-model refits.

`diagnostics` reports convergence and selected fit summaries but cannot establish exchangeability, positivity, consistency, or model correctness. Inspect overlap and model fit under plausible specifications, and interpret natural effects cautiously when post-treatment mediator-outcome confounding is present.

`impute()` performs single stochastic chained-equation imputation rather than Rubin-style multiple imputation; its uncertainty is not propagated as between-imputation uncertainty. Extended missing values `.a`–`.z` are treated as missing.

Monte Carlo and finite-bootstrap error are sampling approximations. `saving()` writes the exact point-estimate stochastic data, not bootstrap replicates. `savemodels` produces analytic-sample refit approximations, not guaranteed copies of every simulation-loop fit.

## References

- Robins JM. 1986. A new approach to causal inference in mortality studies with sustained exposure periods. *Mathematical Modelling* 7(9-12):1393-1512.
- Daniel RM, De Stavola BL, Cousens SN. 2011. gformula: Estimating causal effects in the presence of time-varying confounding or mediation using the g-computation formula. *Stata Journal* 11(4):479-517.
- Daniel RM, De Stavola BL, Cousens SN, Vansteelandt S. 2015. Causal mediation analysis with multiple mediators. *Biometrics* 71(1):1-14.
- StataCorp LLC. 2025. *nbreg — Negative binomial regression*. *Stata 19 Base Reference Manual*. College Station, TX: Stata Press.
- Taubman SL, Robins JM, Mittleman MA, Hernan MA. 2009. Intervening on risk factors for coronary heart disease: an application of the parametric g-formula. *International Journal of Epidemiology* 38(6):1599-1611.
- VanderWeele TJ. 2015. *Explanation in causal inference: methods for mediation and interaction*. Oxford University Press.

## QA

QA suites and how to run them are documented in [qa/README.md](qa/README.md).

## Version History

- **1.6.0** (2026-08-19): Added Poisson and NB2 negative-binomial component and imputation models with nonnegative-integer validation, gamma-Poisson draws, diagnostics, and a near-zero-dispersion Poisson fallback.
- **1.5.0** (2026-08-19): Added `structural()` rules that fit component models on the nonstructural complement and force deterministic mediator or outcome values from each world’s simulated history.
- **1.4.8** (2026-08-19): Added unconditional warnings when component models omit eligible observations at fit time, with exact fitted and omitted row counts.
- **1.4.7** (2026-08-11): Removed the unrequested placeholder BCa return, made component-model tables use residual-df t inference where available, made `stats()` fail closed, and preserved outcome-family metadata so ordinary dose-response tables use the correct risk/mean label.
- **1.4.6** (2026-07-19): Corrected post-exposure mediator-confounder world assignment, made survival dose-response tables use outcome-specific cumulative incidence, and expanded imputation equation handling for factor variables.
- **1.4.5** (2026-07-13): Hardened monotreatment, multi-mediator cross-world simulation, BOCE-AM, MSM posting, missing-value handling, point-run saving, bootstrap accounting, replay metadata, component-model manifests, and Markdown/CSV/Excel export semantics.
- **1.4.4** (2026-07-10): Preserved completed `gcomptab` results when the optional workbook opener fails.
- **1.4.3** (2026-07-04): Corrected end-of-follow-up missing-outcome handling for continuous time-varying outcomes.
- **1.4.2** (2026-07-04): Rebuilt the time-varying baseline lookup for linear-time performance and rejected malformed controlled-effect syntax.
- **1.4.1** (2026-07-02): Fixed `all` with competing events, mediation MSM options, extended missing-value screening, and related output edge cases.
- **1.4.0** (2026-06-28): Added mediation and dose-response Markdown and CSV exports.
- **1.3.2** (2026-06-25): Removed the continuous-covariate distinct-level limit in model validation.
- **1.3.1** (2026-06-16): Fixed categorical-model imputation and bootstrap base-outcome handling and added a degenerate-intervention guard.
- **1.3.0** (2026-06-14): Added component-model storage, display, and export through `savemodels`, `showmodels`, and `gcomptab, models`.
- **1.2.0** (2026-05-29): Added time-varying dose-response tables with strategy labels, exposure-years, and reference risk differences.
- **1.1.2** (2026-05-06): Restored full bootstrap covariance posting in `e(V)` and rejected `samples(1)`.
- **1.1.1** (2026-05-06): Hardened component-table matrix validation, font and sheet handling, state preservation, unsorted-panel subject counts, and eofu MSM refits.
- **1.1.0** (2026-04-26): Added pre-bootstrap input validation and stored component-model diagnostics.
- **1.0.3** (2026-04-22): Restored correct time-varying component-model ordering and tightened minimum-simulation handling.
- **1.0.2** (2026-04-19): Released the Stata-Tools fork with bundled Excel export through `gcomptab`.

## Author

Timothy P Copeland, Karolinska Institutet

Original command by Rhian Daniel, London School of Hygiene and Tropical Medicine.

## License

MIT
