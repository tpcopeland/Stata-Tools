# gcomp — Parametric g-computation for mediation and longitudinal interventions

**Version 1.4.6** | 2026-07-19

<code>gcomp</code> estimates causal effects with parametric g-computation and Monte Carlo simulation for cross-sectional mediation and time-varying interventions. <code>gcomptab</code> turns mediation, dose-response, and saved component-model results into Excel, Markdown, CSV, or Results-window tables.

## Quick Start

Fit a binary-exposure mediation model and inspect the posted effects:

~~~stata
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
~~~

The main effect estimates are posted in <code>e(b)</code>, with bootstrap standard errors and confidence intervals in <code>e(se)</code> and the <code>e(ci_*)</code> matrices; non-OCE mediation runs also post named scalars such as <code>e(tce)</code>, <code>e(nde)</code>, and <code>e(nie)</code>.

## Requirements

- Stata 16 or later.
- No external Stata package is required; <code>gcomptab</code> uses Stata's built-in Results-window, text, and Excel-writing facilities.

## Installation

Run this in Stata:

~~~stata
capture ado uninstall gcomp
net install gcomp, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/gcomp") replace
~~~

The distribution installs the two public commands and their package-prefixed helper programs. The <code>demo/</code> and <code>qa/</code> directories are repository documentation and are not part of the <code>net install</code> payload.

## Commands

| Command | Purpose |
|---|---|
| <code>gcomp</code> | Fits parametric component models, simulates intervention or mediation worlds, and obtains bootstrap inference. |
| <code>gcomptab</code> | Exports mediation effects, time-varying dose-response results, or <code>gcomp</code> component models. |

## How It Works

<code>gcomp</code> parses the model map in <code>commands()</code> and <code>equations()</code>, fits the requested <code>logit</code>, <code>regress</code>, <code>mlogit</code>, or <code>ologit</code> components, simulates the specified worlds, and bootstraps the complete estimate vector.

Cross-sectional mediation uses one row per subject and requires an exposure and one or more causally ordered mediators. Choose an outcome-scale effect definition with <code>obe</code>, <code>oce</code>, <code>linexp</code>, <code>specific</code>, or <code>baseline</code>; <code>control()</code> requests controlled direct effects and <code>post_confs()</code> supports post-exposure mediator-outcome confounders.

Time-varying analyses use long data with a numeric subject identifier and visit variable. <code>intvars()</code> and <code>interventions()</code> define treatment regimes; <code>varyingcovariates()</code>, <code>fixedcovariates()</code>, <code>laggedvars()</code>, <code>derived()</code>, and their rule options describe the longitudinal data-generating process.

Monte Carlo size defaults to the observed analytic sample in mediation and to the number of subjects in time-varying mode; <code>simulations()</code> can set it explicitly. <code>samples()</code> defaults to 1,000 bootstrap replications, and successful inference requires at least <code>max(2, ceil(.90 × requested))</code> successful draws.

Use <code>diagnostics</code> to display the initial component-model summaries, <code>all</code> to request all supported bootstrap confidence-interval matrices, <code>saving()</code> to save the exact point-estimate simulation data, and <code>savemodels</code>/<code>showmodels</code> to expose analytic-sample component-model refits for reporting.

## Choosing a Workflow

| Goal | Data layout | Main options | Reporting command |
|---|---|---|---|
| Total, direct, indirect, or proportion mediated effect | One row per subject | <code>mediation</code> plus one of <code>obe</code>, <code>oce</code>, <code>linexp</code>, <code>specific</code>, or <code>baseline</code> | <code>gcomptab</code> for an effect table |
| Controlled direct effect | One row per subject | Mediation options plus <code>control()</code> | <code>gcomptab</code> with <code>effect()</code> or <code>labels()</code> |
| Longitudinal intervention or survival contrast | One row per subject-visit | <code>idvar()</code>, <code>tvar()</code>, <code>intvars()</code>, and <code>interventions()</code> | <code>gcomptab, doseresponse</code> |
| Component-model audit table | Either supported layout | <code>savemodels</code> or <code>showmodels</code> | <code>gcomptab, models</code> |

## Worked Examples

### 1. Binary mediation: overall effect

The following self-contained example estimates an outcome-scale mediation decomposition with a binary exposure, mediator, and outcome:

~~~stata
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
~~~

### 2. Controlled direct effect

Set <code>control(0)</code> to hold the binary mediator at zero while estimating the exposure contrast:

~~~stata
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
~~~

### 3. Categorical exposure: OCE

<code>oce</code> estimates indexed contrasts for each observed exposure level and does not require a binary exposure:

~~~stata
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
~~~

### 4. Time-varying confounding with an end-of-follow-up outcome

This long-format example models treatment, a time-varying confounder, and a final-visit binary outcome:

~~~stata
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
~~~

### 5. Diagnostics and confidence-interval matrices

Request model-fit diagnostics and all supported interval forms in one run:

~~~stata
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
~~~

### 6. Mediation tables in Excel, Markdown, and CSV

The same fitted mediation result can be exported to multiple formats:

~~~stata
clear
set seed 12345
set obs 400
generate double c = rnormal()
generate byte x = rbinomial(1, invlogit(.2*c))
generate double m = .6*x + .3*c + rnormal()
generate double y = .7*m + .4*x + .2*c + rnormal()

gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) control(0) ///
    commands(m: regress, y: regress) equations(m: x c, y: m x c) ///
    base_confs(c) simulations(400) samples(50) seed(42) all
gcomptab, xlsx("mediation_tables.xlsx") sheet("Normal CI") title("Mediation effects")
gcomptab, xlsx("mediation_tables.xlsx") sheet("Percentile CI") ci(percentile) ///
    markdown("mediation_table.md") csv("mediation_table.csv")
~~~

### 7. Longitudinal dose-response table

For a time-varying <code>eofu</code> analysis, <code>gcomptab, doseresponse</code> formats one row per intervention or observed regime:

~~~stata
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
~~~

### 8. Component-model table

Use <code>savemodels</code> and <code>gcomptab, models</code> when the fitted component models need a compact coefficient table:

~~~stata
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
~~~

## Demo

The repository checkout contains a reproducible report demo; the demo files are not included in the <code>net install</code> payload. From the Stata-Tools checkout root, run:

~~~bash
cd /path/to/Stata-Tools
stata-mp -b do gcomp/demo/demo_gcomp.do
~~~

<code>demo/demo_gcomp.do</code> is the canonical generator and covers mediation, controlled direct effects, OCE, time-varying <code>eofu</code>, Excel export, and component-model export. <code>demo/demo_gcomptab.do</code> is a compatibility wrapper, and <code>demo/manifest.md</code> records the generated artifacts and workbook sheet order.

The checkout includes [<code>demo/component_models.md</code>](demo/component_models.md) and [<code>demo/demo_gcomptab.xlsx</code>](demo/demo_gcomptab.xlsx); the workbook contains <code>Normal CI</code>, <code>Percentile CI</code>, and <code>Component models</code> sheets.

## Command Reference

### <code>gcomp</code>

Cross-sectional mediation:

~~~stata
gcomp varlist [if] [in], outcome(varname) commands(string) equations(string) ///
    mediation exposure(varlist) mediator(varlist) ///
    [obe | oce | specific | linexp | baseline] [control(string)] [base_confs(varlist)]
~~~

Time-varying intervention:

~~~stata
gcomp varlist [if] [in], outcome(varname) commands(string) equations(string) ///
    idvar(varname) tvar(varname) intvars(varlist) interventions(string) ///
    [varyingcovariates(varlist) fixedcovariates(varlist) laggedvars(varlist) ///
     lagrules(string) derived(varlist) derrules(string) eofu pooled monotreat ///
     dynamic death(varname) msm(string)]
~~~

In both layouts, the numeric varlist identifies the main analysis surface; variables named in options or referenced by legal factor-variable terms in <code>equations()</code> are retained automatically. The colon syntax in <code>commands()</code> and <code>equations()</code> maps each modeled variable to its estimator and predictors; list equations in causal generation order.

### <code>gcomptab</code>

Mediation, including a controlled direct effect:

~~~stata
gcomptab, xlsx(string) sheet(string) [ci(string) effect(string) labels(string) ///
    decimal(integer) title(string) markdown(string) csv(string) open]
~~~

Time-varying dose-response:

~~~stata
gcomptab, doseresponse xlsx(string) sheet(string) [strategylabels(string) ///
    expyears(numlist) reference(integer) nord effect(string) ci(string)]
~~~

Saved component models:

~~~stata
gcomptab, models [xlsx(string) sheet(string) markdown(string) csv(string) display] ///
    [usemodels(string) modellabels(string) termlabels(string) stats(string) ///
     coef(string) eform noeform raw se compact nopvalue stars starslevels(numlist) ///
     nointercept keepintercept keep(string) drop(string) digits(integer)]
~~~

Mediation and dose-response modes require <code>xlsx()</code> and <code>sheet()</code>; component-model mode can write to Excel, Markdown, CSV, the Results window, or any combination. Excel sheet names must be no longer than 31 characters and cannot contain Excel's reserved characters.

## Key Options

### <code>gcomp</code>

| Option | Contract |
|---|---|
| `outcome()` | Outcome variable; required in every run. |
| `commands()` | One estimator per modeled variable; supported families are <code>logit</code>, <code>regress</code>, <code>mlogit</code>, and <code>ologit</code>. |
| `equations()` | Predictor map using <code>variable: predictors</code> clauses; causal generation order is enforced. |
| `mediation`, `exposure()`, `mediator()` | Select cross-sectional mediation and identify the exposure and causally ordered mediator list. |
| `obe`, `oce`, `linexp`, `specific`, `baseline` | Select the mediation effect definition; OCE returns indexed effects for the exposure levels. |
| `control()`, `alternative()`, `baseline()`, `base_confs()`, `post_confs()` | Define controlled exposure/mediator worlds and baseline or post-exposure confounder information for mediation. |
| `boceam`, `msm()`, `mediation` | Request the supported mediation extensions; <code>boceam</code> requires an MSM specification. |
| `logOR`, `logRR` | Request log odds-ratio or log risk-ratio effect scales where supported; they are mutually exclusive. |
| `idvar()`, `tvar()` | Identify numeric subject and visit variables for long-format time-varying analyses. |
| `varyingcovariates()`, `fixedcovariates()` | Identify covariates that are resimulated over visits or held at their subject-specific baseline values. |
| `intvars()`, `interventions()` | Identify intervention variables and define the intervention rules or regimes. |
| `laggedvars()`, `lagrules()` | Add lagged treatment or covariate variables and define how their lags are generated. |
| `derived()`, `derrules()` | Add derived variables and deterministic rules evaluated during simulation. |
| `eofu`, `pooled`, `monotreat`, `dynamic`, `death()` | Choose end-of-follow-up outcomes, common pooled coefficients, monotone treatment, dynamic regimes, or a competing event. |
| `impute()`, `imp_eq()`, `imp_cmd()`, `imp_cycles()` | Configure single stochastic chained-equation imputation; <code>imp_cycles()</code> defaults to 10. |
| `simulations()`, `samples()`, `seed()`, `minsim`, `moreMC` | Control Monte Carlo size, bootstrap replications, random state, minimum-simulation checks, and the mediation-only larger-Monte-Carlo option. Defaults are observed sample size, 1,000, and no explicit seed. |
| `diagnostics`, `all`, `graph` | Display model diagnostics, retain all supported interval matrices, or graph non-<code>eofu</code> time-varying survival results. |
| `saving()`, `replace` | Save exact point-estimate stochastic data and permit overwriting an existing file. |
| `savemodels`, `showmodels`, `modelstyle()` | Store or display analytic-sample component-model refit approximations; <code>modelstyle()</code> accepts <code>compact</code> or <code>native</code>. |

### <code>gcomptab</code>

| Option group | Contract |
|---|---|
| `xlsx()`, `sheet()`, `markdown()`, `csv()`, `open` | Select output targets; mediation and dose-response require Excel path and sheet, while <code>open</code> is best effort and returns <code>r(open_rc)</code>. |
| `ci()`, `effect()`, `labels()`, `title()`, `decimal()` | Select the interval matrix, effect label, row labels, title, and decimal places; CI defaults to normal and decimal defaults to 3. |
| `font()`, `fontsize()`, `borderstyle()`, `theme()` | Set font, font size, border preset, or a named preset (<code>lancet</code>, <code>nejm</code>, <code>bmj</code>, <code>apa</code>, <code>jama</code>, <code>plos</code>, <code>nature</code>, <code>cell</code>, or <code>annals</code>); defaults are Arial, 10, and thin borders. |
| `headershade`, `noshade`, `headercolor()`, `zebra`, `nozebra`, `zebracolor()`, `footnote()`, `boldp()`, `highlight()` | Control table shading, colors, notes, bold p-value cutoff, and highlight cutoff; the cutoffs default to 0, which disables emphasis. |
| `doseresponse`, `strategylabels()`, `expyears()`, `reference()`, `nord` | Select and label dose-response rows, add cumulative exposure-years, choose the reference strategy (default 1), or suppress the risk-difference column. |
| `models`, `usemodels()`, `modellabels()`, `termlabels()`, `stats()`, `display` | Select component-model mode, stored estimates, model and term labels, requested summary statistics, and Results-window output. |
| `coef()`, `eform`, `noeform`, `raw`, `se`, `compact`, `nopvalue`, `stars`, `starslevels()` | Override the scale-column label and select coefficient display columns; automatic model scales are OR for logit/ologit, RRR for mlogit, and Coef for regress. |
| `nointercept`, `keepintercept`, `keep()`, `drop()`, `digits()` | Filter terms and set model-table digits; <code>digits(-1)</code> uses the decimal setting. |

## Stored Results

### After <code>gcomp</code>

The command is <code>eclass</code> and posts the following result groups:

| Result | Meaning |
|---|---|
| <code>e(b)</code>, <code>e(V)</code>, <code>e(se)</code> | Named point estimates, full bootstrap covariance, and standard errors. |
| <code>e(ci_normal)</code>, <code>e(ci_percentile)</code>, <code>e(ci_bc)</code>, <code>e(ci_bca)</code> | Bootstrap confidence intervals; <code>all</code> is required for the BCa matrix. |
| <code>e(tce)</code>, <code>e(nde)</code>, <code>e(nie)</code>, <code>e(pm)</code>, <code>e(cde)</code> and corresponding <code>e(se_*)</code> | Convenience mediation scalars for non-OCE runs; CDE is present when requested. |
| <code>e(tce_j)</code>, <code>e(nde_j)</code>, <code>e(nie_j)</code>, <code>e(pm_j)</code>, <code>e(cde_j)</code> | Indexed convenience scalars for OCE contrasts. |
| <code>e(model_diagnostics)</code> | Component-model rows with <code>N</code>, <code>converged</code>, <code>ll</code>, <code>r2</code>, and <code>rmse</code>. |
| <code>e(N)</code>, <code>e(N_rows)</code>, <code>e(N_subjects)</code>, <code>e(MC_sims)</code>, <code>e(samples)</code> | Analytic-sample and resampling sizes; <code>e(N)</code> is rows for mediation and subjects for time-varying analyses. |
| <code>e(bootstrap_requested)</code>, <code>e(bootstrap_attempted)</code>, <code>e(bootstrap_successful)</code>, <code>e(bootstrap_failed)</code>, <code>e(seed)</code> | Bootstrap accounting and optional seed. |
| <code>e(analysis_type)</code>, <code>e(outcome)</code>, <code>e(exposure)</code>, <code>e(mediator)</code>, <code>e(mediation_type)</code>, <code>e(scale)</code>, <code>e(idvar)</code>, <code>e(tvar)</code>, <code>e(intvars)</code>, <code>e(interventions)</code> | Analysis and design metadata. |
| <code>e(saving)</code>, <code>e(saved_schema_version)</code>, <code>e(saved_arm_schema)</code>, <code>e(run_id)</code>, <code>e(rngstate)</code>, <code>e(graph)</code> | Point-run saving, reproducibility, and optional graph metadata when applicable. |
| <code>e(model_names)</code>, <code>e(model_cmds)</code>, <code>e(model_depvars)</code>, <code>e(model_eq_1)</code>, <code>e(model_skipped)</code>, <code>e(model_capture)</code> | Component-model manifest when <code>savemodels</code> is used; <code>e(model_eq_1)</code> illustrates the indexed equation family. |
| <code>e(msm)</code>, <code>e(msm_colnames)</code> | Marginal structural-model specification and coefficient names when an MSM is requested. |
| <code>e(obs_data)</code>, <code>PO#</code>, <code>out#</code>, <code>death#</code> | Time-varying observed outcome and simulated columns; non-<code>eofu</code> survival runs use <code>out#</code> for cumulative incidence and may include <code>death#</code>. |

Imputation metadata includes <code>e(impute_targets)</code>, <code>e(N_impute_targets)</code>, and indexed families such as <code>e(impute_target_1)</code>, <code>e(impute_needed_1)</code>, <code>e(impute_eligible_1)</code>, and <code>e(impute_dropped_1)</code>. Additional replay macros are listed by <code>ereturn list</code> after a run. <code>e(sample)</code> identifies the original analytic rows.

### After <code>gcomptab</code>

Mediation mode returns <code>r(N_effects)</code>, <code>r(has_cde)</code>, named effects, the selected <code>r(ci)</code>, and output-path returns such as <code>r(xlsx)</code>, <code>r(sheet)</code>, <code>r(markdown)</code>, and <code>r(csv)</code>. Dose-response mode returns <code>r(k)</code>, <code>r(reference)</code>, <code>r(ref_label)</code>, and <code>r(table)</code>. Component-model mode returns <code>r(N_models)</code>, <code>r(N_rows)</code>, <code>r(N_cols)</code>, <code>r(coef_label)</code>, <code>r(term_names)</code>, <code>r(methods)</code>, <code>r(table)</code>, and the output-path returns; <code>open</code> additionally returns <code>r(open_rc)</code>.

## Assumptions and Limits

Interpret causal effects using the assumptions required by the g-computation formula: consistency and well-defined interventions, positivity, the relevant sequential exchangeability conditions, correctly specified and causally ordered component models, and no interference between subjects. Natural mediation effects additionally require the cross-world assumptions implied by their definition.

For multiple mediators, list variables in causal simulation order; each later mediator is generated conditional on earlier same-arm draws. <code>fixedcovariates()</code> variables are held at their subject-specific baseline values, and loop-only predictors can be omitted from analytic-sample component-model refits.

<code>diagnostics</code> reports convergence and selected fit summaries but cannot establish exchangeability, positivity, consistency, or model correctness. Inspect overlap and model fit under plausible specifications, and interpret natural effects cautiously when post-treatment mediator-outcome confounding is present.

<code>impute()</code> performs single stochastic chained-equation imputation rather than Rubin-style multiple imputation; its uncertainty is not propagated as between-imputation uncertainty. Extended missing values <code>.a</code>–<code>.z</code> are treated as missing.

Monte Carlo and finite-bootstrap error are sampling approximations. <code>saving()</code> writes the exact point-estimate stochastic data, not bootstrap replicates. <code>savemodels</code> produces analytic-sample refit approximations, not guaranteed copies of every simulation-loop fit.

## References

- Robins JM. 1986. A new approach to causal inference in mortality studies with sustained exposure periods. <em>Mathematical Modelling</em> 7(9-12):1393-1512.
- Daniel RM, De Stavola BL, Cousens SN. 2011. gformula: Estimating causal effects in the presence of time-varying confounding or mediation using the g-computation formula. <em>Stata Journal</em> 11(4):479-517.
- Daniel RM, De Stavola BL, Cousens SN, Vansteelandt S. 2015. Causal mediation analysis with multiple mediators. <em>Biometrics</em> 71(1):1-14.
- Taubman SL, Robins JM, Mittleman MA, Hernan MA. 2009. Intervening on risk factors for coronary heart disease: an application of the parametric g-formula. <em>International Journal of Epidemiology</em> 38(6):1599-1611.
- VanderWeele TJ. 2015. <em>Explanation in causal inference: methods for mediation and interaction</em>. Oxford University Press.

## QA

See [<code>qa/README.md</code>](qa/README.md) for the package validation and reproducibility runbook.

## Version History

- **1.4.6** (2026-07-19): Corrected post-exposure mediator-confounder world assignment, made survival dose-response tables use outcome-specific cumulative incidence, and expanded imputation equation handling for factor variables.
- **1.4.5** (2026-07-13): Hardened monotreatment, multi-mediator cross-world simulation, BOCE-AM, MSM posting, missing-value handling, point-run saving, bootstrap accounting, replay metadata, component-model manifests, and Markdown/CSV/Excel export semantics.
- **1.4.4** (2026-07-10): Preserved completed <code>gcomptab</code> results when the optional workbook opener fails.
- **1.4.3** (2026-07-04): Corrected end-of-follow-up missing-outcome handling for continuous time-varying outcomes.
- **1.4.2** (2026-07-04): Rebuilt the time-varying baseline lookup for linear-time performance and rejected malformed controlled-effect syntax.
- **1.4.1** (2026-07-02): Fixed <code>all</code> with competing events, mediation MSM options, extended missing-value screening, and related output edge cases.
- **1.4.0** (2026-06-28): Added mediation and dose-response Markdown and CSV exports.
- **1.3.2** (2026-06-25): Removed the continuous-covariate distinct-level limit in model validation.
- **1.3.1** (2026-06-16): Fixed categorical-model imputation and bootstrap base-outcome handling and added a degenerate-intervention guard.
- **1.3.0** (2026-06-14): Added component-model storage, display, and export through <code>savemodels</code>, <code>showmodels</code>, and <code>gcomptab, models</code>.
- **1.2.0** (2026-05-29): Added time-varying dose-response tables with strategy labels, exposure-years, and reference risk differences.
- **1.1.2** (2026-05-06): Restored full bootstrap covariance posting in <code>e(V)</code> and rejected <code>samples(1)</code>.
- **1.1.1** (2026-05-06): Hardened component-table matrix validation, font and sheet handling, state preservation, unsorted-panel subject counts, and eofu MSM refits.
- **1.1.0** (2026-04-26): Added pre-bootstrap input validation and stored component-model diagnostics.
- **1.0.3** (2026-04-22): Restored correct time-varying component-model ordering and tightened minimum-simulation handling.
- **1.0.2** (2026-04-19): Released the Stata-Tools fork with bundled Excel export through <code>gcomptab</code>.

## Author

Timothy P Copeland, Karolinska Institutet

Original command by Rhian Daniel, London School of Hygiene and Tropical Medicine.

## License

MIT
