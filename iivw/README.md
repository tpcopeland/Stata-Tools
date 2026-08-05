# iivw — Inverse intensity of visit weighting for longitudinal data

**Version 3.2.1** | 2026-08-04

<code>iivw</code> corrects over-representation caused by informative visit timing in irregular longitudinal observational data, and can also apply treatment-propensity weights. It gives Stata users a workflow for estimating weights, checking leverage and the person-time target, fitting outcome models, and comparing sampling with measurement-process movement.

## Quick Start

The following creates a small irregular-visit panel, computes IIW weights, checks them, and fits a weighted population-average model.

```stata
clear
set seed 20260417
set obs 240
gen long id = ceil(_n/4)
bysort id: gen byte visit = _n
gen double time = 3 * (visit - 1) + runiform() * .05
replace time = 0 if visit == 1
gen double x = rnormal()
bysort id: replace x = x[1]
gen byte treated = runiform() < invlogit(.4 + .5 * x)
bysort id: replace treated = treated[1]
gen double y = 1 + .1 * time + x + rnormal()
gen double fu_end = 12

iivw_weight, id(id) time(time) visit_cov(x) lagvars(y) maxfu(12) nolog
iivw_balance
iivw_fit y x, vce(fixed) nolog
```

<code>vce(fixed)</code> is explicit here so the short example uses the weights-known analytic sandwich. For IIW and IPTW, the supported default when no variance option is supplied is a 999-draw subject-level refit bootstrap; see <a href="#inference">Inference</a>.

## Requirements

- Stata 16 or later.
- Stata 17 or later for <code>iivw_fit, model(mixed)</code> and the <code>collect</code> option.
- No external runtime dependency is required for the core <code>iivw</code> commands or their direct <code>xlsx()</code> reporting exports.
- Optional: <code>tabtools</code> for <code>regtab</code> model-table exports, and <code>psdash</code> for treatment-propensity diagnostics after IPTW/FIPTIW weighting.
- The repository demo additionally uses <code>tc_schemes</code> for its graph scheme.

## Installation

Install the released package from the public Stata-Tools distribution:

```stata
capture ado uninstall iivw
net install iivw, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/iivw") replace
```

Install optional companion packages only when you need their workflows:

```stata
net install tabtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tabtools") replace
net install psdash, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/psdash") replace
```

## Commands

| Command | Description |
|---|---|
| <code>iivw</code> | Display the package overview and return the installed command list |
| <code>iivw_weight</code> | Compute IIW, IPTW, or FIPTIW weights |
| <code>iivw_balance</code> | Check weight leverage and visit-model balance against the at-risk person-time target |
| <code>iivw_fit</code> | Fit weighted or unweighted GEE-style and mixed-effects outcome models |
| <code>iivw_exogtest</code> | Test whether lagged outcomes or disease activity predict subsequent visit timing |
| <code>iivw_diagnose</code> | Decompose movement in a stored marginal or reference-slope estimate across three models |

## How It Works

The package addresses a visit-level sampling problem: when patients who are sicker, or otherwise different, are seen more often, a row-per-visit analysis can over-represent them. The visit model estimates the conditional intensity of observation, and the resulting weights make the outcome analysis less dominated by differential visit frequency.

| Weight type | Use when | Construction |
|---|---|---|
| IIW | Visit timing is informative but treatment weighting is not needed | Inverse intensity weights from an Andersen–Gill recurrent-event Cox model |
| IPTW | Treatment assignment is confounded but visit timing is not being corrected | Stabilized inverse treatment-propensity weights from a one-row-per-subject logistic model |
| FIPTIW | Both visit timing and treatment assignment are informative or confounded | The product of the IIW and IPTW components |

The usual workflow is:

1. <code>iivw_weight</code> estimates the visit and, when requested, treatment models, creates the final weight, and stores the panel contract in dataset characteristics.
2. <code>iivw_balance</code> reports leverage, effective sample size, descriptive composition shifts, and the target standardized mean difference for the visit model.
3. <code>iivw_fit</code> reads the stored weight and panel metadata and fits the outcome model.
4. <code>iivw_exogtest</code> and <code>iivw_diagnose</code> are optional diagnostics for separating observation-process movement from residual measurement-process movement.

For IIW and FIPTIW, give the study's observation window with exactly one of <code>censor()</code>, <code>maxfu()</code>, or <code>endatlastvisit</code>. A subject-specific or common administrative end is usually the design-relevant choice; <code>endatlastvisit</code> is available for studies whose follow-up genuinely ends at the last observed visit.

Visit-model covariates must be measured before the interval whose visit they explain. Put baseline and externally updated variables in <code>visit_cov()</code>; use <code>lagvars()</code> for visit-measured outcomes, disease activity, or recent events. The weight-model varlists accept plain numeric variables, not factor-variable or inline spline notation, so expand such terms into physical columns before weighting.

## Choosing a Workflow

| Study question | Starting workflow |
|---|---|
| Irregular registry or EHR visits distort a disease trajectory | Use IIW, inspect <code>iivw_balance</code>, and compare <code>timespec(linear)</code> with a flexible time specification |
| Treatment is binary and time-invariant, with confounding by baseline severity | Use IPTW or FIPTIW with <code>treat()</code> and <code>treat_cov()</code>; inspect treatment components with optional <code>psdash</code> |
| Both treatment and visit timing are confounded | Use FIPTIW; <code>treat()</code> is included in the visit-intensity model by default |
| Repeated measurement may create practice or test-count artifact | Fit unweighted, weighted, and measurement-adjusted models, then use <code>iivw_exogtest</code> and <code>iivw_diagnose</code> |

## Worked Examples

Run the Quick Start setup first if you want to reuse its synthetic data. The examples below are sequenced so that the same panel can support IIW, FIPTIW, inference, exogeneity, and decomposition workflows.

### 1. IIW only

Correct informative visit timing without a treatment-propensity component. The default <code>baseline(entry)</code> treats each subject's first row as study entry.

```stata
iivw_weight, id(id) time(time) visit_cov(x) lagvars(y) maxfu(12) replace nolog
iivw_balance
iivw_fit y x, model(gee) timespec(linear) vce(fixed) nolog
```

### 2. FIPTIW for treatment confounding and informative visits

Adding <code>treat()</code> makes the default weight type FIPTIW and adds treatment to the visit-intensity model. <code>stabcov(treated)</code> is valid here because <code>treated</code> is also in the outcome design shown below.

```stata
iivw_weight, id(id) time(time) visit_cov(x) lagvars(y) maxfu(12) ///
    treat(treated) treat_cov(x) stabcov(treated) replace nolog
iivw_balance, component(final) nolog
iivw_fit y treated x, model(gee) timespec(linear) vce(fixed) nolog
```

### 3. Refit-bootstrap inference

For a weighted IIW or IPTW analysis, the recommended variance route refits the nuisance models inside each subject-level bootstrap replicate. FIPTIW intervals requested explicitly are nominal and are labeled in the stored inference status.

```stata
iivw_fit y treated x, model(gee) ///
    vce(bootstrap, reps(999) seed(20260417)) ///
    citype(percentile) nolog
```

### 4. Exogeneity diagnostic for visit timing

The diagnostic creates one-visit lags of the tested variables and fits counting-process Cox models for subsequent visits. Use the same end-of-follow-up contract as the weighting call.

```stata
iivw_exogtest y, id(id) time(time) maxfu(12) ///
    adjust(x) by(treated) replace nolog
```

### 5. Sampling movement versus measurement-process movement

Store three comparable models for the coefficient of interest, then ask <code>iivw_diagnose</code> to report the sampling gap, artifact gap, and descriptive shares. Use <code>estimand(contrast)</code> when the coefficient is a treatment contrast; that reports movement but suppresses the share decomposition.

```stata
iivw_fit y time x, unweighted id(id) time(time) ///
    timespec(none) nolog
estimates store M_unweighted

iivw_fit y time x, timespec(none) vce(fixed) replace nolog
estimates store M_weighted

gen double log_visit = log(visit + 1)
iivw_fit y time x log_visit, timespec(none) ///
    vce(fixed) replace nolog
estimates store M_adjusted

iivw_diagnose time, unweighted(M_unweighted) ///
    weighted(M_weighted) adjusted(M_adjusted) ///
    estimand(marginal) exogeneity(unknown)
```

The direct reporting commands can write styled workbook sheets without <code>tabtools</code>:

```stata
iivw_balance, xlsx("iivw_reporting_exports.xlsx") sheet("Balance") replace
iivw_exogtest y, id(id) time(time) maxfu(12) adjust(x) ///
    by(treated) replace nolog xlsx("iivw_reporting_exports.xlsx") ///
    sheet("Exogeneity")
iivw_diagnose time, unweighted(M_unweighted) ///
    weighted(M_weighted) adjusted(M_adjusted) ///
    xlsx("iivw_reporting_exports.xlsx") sheet("Diagnostics") replace
```

## Demo

The repository checkout workflow is [demo/demo_iivw.do](demo/demo_iivw.do). It creates synthetic SDMT-like data, installs the optional companion packages needed for graph and model-table output, and is the source for the checked-in assets below; the demo script is not part of the <code>net install</code> payload.

| Asset | Contents |
|---|---|
| ![Treatment-propensity dashboard](demo/iivw_psdash_dashboard.png) | <code>psdash combined</code> treatment-propensity overlap, support, balance, and treatment-weight diagnostics |
| ![Final FIPTIW weight distribution](demo/iivw_psdash_final_weights.png) | Final analysis-weight distribution from <code>psdash weights, iivwcomponent(final)</code> |
| [Model-comparison and visit-wave workbook](demo/iivw_results.xlsx) | <code>collect</code>/<code>regtab</code> output for model comparison and categorical-time interactions |
| [Direct reporting workbook](demo/iivw_reporting_exports.xlsx) | <code>iivw_balance</code>, <code>iivw_exogtest</code>, and <code>iivw_diagnose</code> export sheets |

## Command Reference

### iivw

Syntax:

```stata
iivw
```

With no arguments, <code>iivw</code> displays the package overview and returns <code>r(version)</code>, <code>r(commands)</code>, and <code>r(n_commands)</code>.

### iivw_weight

Syntax:

```stata
iivw_weight, id(varname) time(varname) [options]
```

| Option | Default | Purpose |
|---|---|---|
| <code>id(varname)</code> | Required | Subject identifier in long panel data |
| <code>time(varname)</code> | Required | Numeric, nonnegative visit time, unique within subject |
| <code>visit_cov(varlist)</code> | Required for IIW/FIPTIW unless <code>lagvars()</code> supplies covariates | Numeric covariates for the visit-intensity Cox model; ignored for IPTW-only with a note |
| <code>treat(varname)</code> | None | Binary 0/1 treatment, constant within subject; required for IPTW/FIPTIW |
| <code>treat_cov(varlist)</code> | None | Numeric covariates for the treatment logistic model; required when treatment weighting is requested |
| <code>wtype(iivw\|iptw\|fiptiw)</code> | Auto-detected | IIW when <code>treat()</code> is absent, FIPTIW when it is present; use <code>iptw</code> to skip the visit model |
| <code>stabcov(varlist)</code> | None | Covariates for the IIW stabilization numerator |
| <code>lagvars(varlist)</code> | None | Raw visit-measured sources to lag by one visit before use in the visit model |
| <code>entry(varname)</code> | 0 | Subject-specific study entry time |
| <code>censor(varname)</code> | None | Subject-specific end of follow-up; mutually exclusive with <code>maxfu()</code> and <code>endatlastvisit</code> |
| <code>maxfu(#)</code> | None | Common end of follow-up; mutually exclusive with the other end-of-follow-up options |
| <code>endatlastvisit</code> | None | End each subject's risk window at their last visit; use only when that is the study design |
| <code>baseline(entry\|event)</code> | <code>entry</code> | Treat the first visit as study entry or as a modeled recurrent event |
| <code>truncvisit(# #)</code> | None | Trim the IIW component at row-level percentiles |
| <code>trunctreat(# #)</code> | None | Trim the IPTW component at subject-level percentiles |
| <code>truncfinal(# #)</code> | None | Trim the final analysis weight at row-level percentiles |
| <code>experimentalnotreatvisit</code> | Off | FIPTIW sensitivity mode that omits treatment from the visit model; outside the supported contract |
| <code>generate(name)</code> | <code>_iivw_</code> | Prefix for generated weights and metadata-linked variables |
| <code>replace</code> | Off | Overwrite variables owned by a prior <code>iivw</code> call |
| <code>nolog</code> | Off | Suppress model iteration logs |
| <code>efron</code> | On | Use Efron handling for tied visit times |
| <code>breslow</code> | Off | Use Breslow handling, mainly for compatibility with pre-3.0.0 analyses |
| <code>allownonconverged</code> | Off | Continue after a nonconverged weight model; use only as an explicit sensitivity/debugging choice |
| <code>allowmissingweights</code> | Off | Accept rows with no computed weight as a complete-case analysis; otherwise missing-weight rows are an error |

<code>truncate()</code> is removed and errors. Choose <code>truncvisit()</code>, <code>trunctreat()</code>, or <code>truncfinal()</code> so the component being altered is explicit.

### iivw_balance

Syntax:

```stata
iivw_balance [varlist] [if] [in], [options]
```

The optional numeric <code>varlist</code> adds covariates to the displayed table; the stored visit-model covariates remain the target of the balance verdict. The command applies to IIW and FIPTIW metadata, not IPTW-only weights.

| Option | Default | Purpose |
|---|---|---|
| <code>component(iiw\|final)</code> | <code>iiw</code> | Describe the visit component or the final analysis weight; the target verdict always uses the IIW component |
| <code>cvcut(#)</code> | 0.10 | CV below this threshold is classified as low leverage |
| <code>essratiocut(#)</code> | 0.95 | ESS/N above this threshold is classified as low leverage |
| <code>balcut(#)</code> | 0.10 | Maximum absolute target SMD allowed for <code>within_rule</code> |
| <code>agrefit</code> | Off | Display hazard ratios from the refitted visit-intensity model |
| <code>level(#)</code> | <code>c(level)</code> | Confidence level for refit hazard-ratio intervals |
| <code>efron</code>, <code>breslow</code> | Stored setting | Ignored as fit requests; the refit replays the tie method used to create the weights |
| <code>nolog</code> | Off | Suppress Cox iteration logs in the refit |

For the workbook options shared by the reporting commands, see <a href="#excel-reporting">Excel reporting</a>.

### iivw_fit

Syntax:

```stata
iivw_fit depvar [indepvars] [if] [in], [options]
```

| Option | Default | Purpose |
|---|---|---|
| <code>unweighted</code> | Off | Fit without applying stored weights |
| <code>id(varname)</code> | Stored metadata for weighted fits | Panel ID for an unweighted fit without package metadata |
| <code>time(varname)</code> | Stored metadata for weighted fits | Time variable for an unweighted fit without metadata when time is modeled |
| <code>model(gee\|mixed)</code> | <code>gee</code> | Use <code>glm</code> with clustered robust SEs, or <code>mixed</code> with a subject random intercept |
| <code>family(string)</code> | <code>gaussian</code> | GLM family for GEE-style fits |
| <code>link(string)</code> | Canonical link | GLM link override |
| <code>timespec(string)</code> | <code>linear</code> | <code>linear</code>, <code>quadratic</code>, <code>cubic</code>, <code>ns(#)</code>, <code>categorical</code>, or <code>none</code> |
| <code>interaction(varlist)</code> | None | Create interactions between listed covariates and all generated time terms |
| <code>categorical(varlist)</code> | None | Expand integer-valued outcome predictors into labeled dummies |
| <code>basecat(#)</code> | Lowest observed level | Reference level for variables in <code>categorical()</code> |
| <code>timebasecat(#)</code> | Lowest observed time | Reference level for <code>timespec(categorical)</code> |
| <code>cluster(varname)</code> | Stored panel ID | Cluster variable for analytic robust SEs |
| <code>vce(bootstrap, reps(#) [seed(#)] [fixedweights]\|fixed)</code> | Weight-type dependent | Refit bootstrap, fixed-weight bootstrap, or analytic sandwich; details are below |
| <code>bootstrap(#)</code> | Omitted | Legacy spelling for bootstrap variance; prefer <code>vce()</code> |
| <code>refitweights</code> | Off | Legacy request to refit weights inside bootstrap draws; prefer <code>vce(bootstrap)</code> |
| <code>citype(none\|wald\|percentile\|basic\|bca)</code> | <code>wald</code>, except bare FIPTIW is <code>none</code> | Select point-only, normal/Wald, percentile, basic, or BCa endpoints |
| <code>allowfailedreps</code> | Off | Accept an incomplete bootstrap and record the failed-replicate counts |
| <code>level(#)</code> | <code>c(level)</code> | Confidence level |
| <code>nolog</code> | Off | Suppress the underlying estimator's iteration log |
| <code>allownonconverged</code> | Off | Continue after outcome-model nonconvergence |
| <code>experimentalmixed</code> | Off | Required for a weighted <code>model(mixed)</code> fit |
| <code>replace</code> | Off | Overwrite generated time, categorical, and interaction variables |
| <code>collect</code> | Off | Use Stata's <code>collect</code> framework for non-bootstrap GEE fits |
| <code>geeopts(string)</code> | None | Pass additional options to <code>glm</code>, except options that take control of the package-owned variance |
| <code>mixedopts(string)</code> | None | Pass additional options to <code>mixed</code> |

### iivw_exogtest

Syntax:

```stata
iivw_exogtest varlist [if] [in], id(varname) time(varname) [options]
```

| Option | Default | Purpose |
|---|---|---|
| <code>id(varname)</code> | Required | Subject identifier |
| <code>time(varname)</code> | Required | Numeric, nonnegative visit or measurement time |
| <code>adjust(varlist)</code> | None | Baseline or design covariates in the timing model |
| <code>by(varname)</code> | None | Fit separate diagnostics by a subject-constant group |
| <code>bystart</code> | Off | Permit a time-varying <code>by()</code> variable and classify intervals by the value at their start |
| <code>entry(varname)</code> | 0 | Subject-specific study entry time |
| <code>censor(varname)</code>, <code>maxfu(#)</code>, <code>endatlastvisit</code> | Exactly one required | End-of-follow-up contract; use the same choice as <code>iivw_weight</code> |
| <code>generate(name)</code> | <code>_iivw_exog_</code> | Prefix for generated one-visit lag variables |
| <code>replace</code> | Off | Overwrite owned lag variables and an existing export worksheet |
| <code>efron</code> | On | Efron ties in <code>stcox</code> |
| <code>breslow</code> | Off | Breslow ties for compatibility or sensitivity analysis |
| <code>nolog</code> | Off | Suppress Cox iteration logs |
| <code>level(#)</code> | <code>c(level)</code> | Confidence level for hazard-ratio intervals |

For the workbook options, see <a href="#excel-reporting">Excel reporting</a>; <code>decimals()</code> defaults to 3 for this command.

### iivw_diagnose

Syntax:

```stata
iivw_diagnose coefficient, unweighted(estname) weighted(estname) adjusted(estname) [options]
```

| Option | Default | Purpose |
|---|---|---|
| <code>unweighted(estname)</code> | Required | Stored unweighted model |
| <code>weighted(estname)</code> | Required | Stored IIW, IPTW, or FIPTIW-weighted model |
| <code>adjusted(estname)</code> | Required | Stored weighted model with a direct measurement-process adjustment |
| <code>exogeneity(exogenous\|endogenous\|unknown)</code> | <code>unknown</code> | State how the adjustment should be interpreted; this is not tested by the command |
| <code>estimand(marginal\|contrast)</code> | <code>marginal</code> | Compute shares for a marginal/reference slope or movement only for a contrast |
| <code>true(#)</code> | None | Supply a known truth and return bias quantities |
| <code>force</code> | Off | Bypass the comparability check and label the result descriptive/non-decomposable |
| <code>level(#)</code> | <code>c(level)</code> | Confidence level for the three stored estimates |

The three estimates must refer to the same outcome, coefficient, model scale, and clustering variable unless <code>force</code> is used. For workbook options, see <a href="#excel-reporting">Excel reporting</a>; <code>decimals()</code> defaults to 4 for this command.

## Key Options

### Weight construction

<code>iivw_weight</code> auto-detects IIW versus FIPTIW from <code>treat()</code>; use <code>wtype(iptw)</code> for treatment weighting without a visit model. The treatment variable must be binary and time-invariant within subject, and the treatment model is fit cross-sectionally on one row per subject. Under FIPTIW, treatment is included in the visit-intensity model unless the explicit experimental sensitivity option is used.

The default <code>baseline(entry)</code> treats the first visit per subject as study entry and assigns it the normalized entry weight. <code>baseline(event)</code> models the first visit as a recurrent event and is retained for designs where that first visit is genuinely part of the monitoring process.

The default tie method is Efron in <code>iivw_weight</code> and <code>iivw_exogtest</code>. <code>iivw_balance</code> replays the stored method and may withhold its target-SMD verdict for tied Efron fits because the target is based on the Breslow score residual; leverage and effective-sample-size summaries remain available.

### Inference

For IIW and IPTW GEE fits with no explicit variance request, <code>iivw_fit</code> uses <code>vce(bootstrap, reps(999))</code> with subject-level nuisance-model refitting. <code>vce(bootstrap, reps(#) fixedweights)</code> resamples subjects while holding weights fixed, and <code>vce(fixed)</code> uses the analytic cluster-robust sandwich with weights treated as known. The latter two omit weight-estimation uncertainty and should be described as such.

For a bare weighted FIPTIW GEE fit, the default is point-only: coefficients are reported without a covariance matrix or nominal interval. Explicit <code>vce()</code> or <code>citype()</code> requests nominal inference and records its status in <code>e(iivw_inference_status)</code>. Fewer than 999 bootstrap draws are allowed but are marked <code>uncleared-low-reps</code>; failed draws are an error unless <code>allowfailedreps</code> explicitly accepts them.

<code>citype(wald)</code> uses a normal/Wald transformation, <code>citype(percentile)</code> uses empirical bootstrap quantiles, <code>citype(basic)</code> reflects those quantiles around the observed estimate, and <code>citype(bca)</code> adds bias correction and delete-one-subject acceleration. The asymmetric choices require bootstrap draws.

### Excel reporting

<code>iivw_balance</code>, <code>iivw_exogtest</code>, and <code>iivw_diagnose</code> write direct styled <code>.xlsx</code> sheets when <code>xlsx(filename)</code> is supplied. <code>sheet()</code> defaults are <code>Balance</code>, <code>Exogeneity</code>, and <code>Diagnostics</code>, respectively. <code>replace</code> overwrites only the named sheet, <code>open</code> opens the workbook, and <code>title()</code>/<code>footnote()</code> add optional rows.

The reporting defaults are <code>decimals(4)</code> for <code>iivw_balance</code> and <code>iivw_diagnose</code>, <code>decimals(3)</code> for <code>iivw_exogtest</code>, and <code>borderstyle(thin)</code> with header shading and zebra rows off. <code>borderstyle()</code>, <code>headershade</code>, <code>theme()</code>, <code>headercolor()</code>, <code>zebracolor()</code>, and <code>zebra</code> control the workbook presentation and require <code>xlsx()</code> when they affect an export.

## Stored Results

The commands also leave dataset characteristics or estimation results so later steps can verify that the weights and model specification still match the data. The in-Stata help files list every stored name; the following are the main user-facing results.

### iivw_weight

<code>r(weighttype)</code>, <code>r(weight_var)</code>, <code>r(iw_var)</code>, <code>r(tw_var)</code>, and <code>r(ps_var)</code> identify the weight type and generated variables. Weight summaries include <code>r(mean_weight)</code>, <code>r(min_weight)</code>, <code>r(max_weight)</code>, <code>r(p1_weight)</code>, <code>r(median_weight)</code>, <code>r(p99_weight)</code>, <code>r(ess)</code>, and <code>r(ess_ratio)</code>.

The command also returns analysis and model counts such as <code>r(N)</code>, <code>r(n_ids)</code>, missing-weight and treatment-arm loss counts, truncation cutpoints, propensity-score extrema, and visit-model event counts. <code>r(visit_b)</code> contains the visit-intensity coefficients, and the returned macros record the raw and expanded covariate lists, lag variables, follow-up contract, treatment covariates, and contract version.

### iivw_balance

Key scalars are <code>r(weight_cv)</code>, <code>r(ess)</code>, <code>r(ess_ratio)</code>, <code>r(ess_cluster)</code>, <code>r(ess_cluster_ratio)</code>, <code>r(balance_max_shift)</code>, and <code>r(balance_max_tsmd)</code>. The diagnostic labels are in <code>r(leverage)</code>, <code>r(balance_flag)</code>, <code>r(target_status)</code>, and <code>r(component)</code>. <code>r(balance)</code> contains the covariate table and <code>r(hr_unweighted)</code> contains refit hazard ratios when available.

### iivw_fit

<code>iivw_fit</code> is an <code>eclass</code> command. Standard results include <code>e(cmd)</code>, <code>e(b)</code>, <code>e(V)</code> when an interval-bearing fit is requested, and <code>e(sample)</code>. Important package metadata include <code>e(iivw_model)</code>, <code>e(iivw_weighttype)</code>, <code>e(iivw_weight_var)</code>, <code>e(iivw_vce)</code>, <code>e(iivw_underlying_vce)</code>, <code>e(iivw_underlying_cmd)</code>, <code>e(iivw_refitweights)</code>, <code>e(iivw_ci_type)</code>, <code>e(iivw_ci)</code>, and <code>e(iivw_inference_status)</code>.

Bootstrap provenance is recorded in <code>e(iivw_bs_reps_requested)</code>, <code>e(iivw_bs_reps_completed)</code>, <code>e(iivw_bs_reps_failed)</code>, <code>e(iivw_resample_unit)</code>, <code>e(iivw_vce_seed)</code>, <code>e(iivw_rng)</code>, and <code>e(iivw_rngstate_start)</code>. The fitted design is recorded in <code>e(iivw_id)</code>, <code>e(iivw_time)</code>, <code>e(iivw_timespec)</code>, <code>e(iivw_time_vars)</code>, <code>e(iivw_interaction)</code>, and <code>e(iivw_categorical)</code>.

### iivw_exogtest

The result matrix <code>r(results)</code> contains model-by-term coefficients, standard errors, tests, hazard ratios, intervals, and sample counts. Useful scalars include <code>r(N)</code>, <code>r(n_ids)</code>, <code>r(n_models)</code>, <code>r(n_skipped)</code>, <code>r(n_unknown)</code>, <code>r(min_p)</code>, <code>r(joint_min_p)</code>, <code>r(holm_min_p)</code>, <code>r(history_association_flag)</code>, <code>r(tie_multiplicity)</code>, <code>r(n_event_times)</code>, and <code>r(n_modeled_events)</code>.

Macros record <code>r(id)</code>, <code>r(time)</code>, <code>r(testvars)</code>, <code>r(lagvars)</code>, <code>r(adjust)</code>, <code>r(by)</code>, indexed group/term labels, <code>r(result_row_labels)</code>, <code>r(result_columns)</code>, and <code>r(conclusion)</code>. Export results are returned in <code>r(xlsx)</code>, <code>r(sheet)</code>, and <code>r(decimals)</code> when an export succeeds.

### iivw_diagnose

Scalars include <code>r(decomposable)</code>, <code>r(sample_identical)</code>, <code>r(n_sample_unweighted)</code>, <code>r(n_sample_weighted)</code>, and <code>r(n_sample_adjusted)</code>. Macros record the coefficient, three stored model names, <code>r(exogeneity)</code>, <code>r(estimand)</code>, <code>r(depvar)</code>, confidence-interval distributions, <code>r(noncollapsible)</code>, and <code>r(conclusion)</code>.

<code>r(estimates)</code> contains the three model estimates and limits, <code>r(decomp)</code> contains the sampling/artifact/total gaps and shares when decomposable, and <code>r(bias)</code> is returned when <code>true()</code> is supplied. Workbook results use <code>r(xlsx)</code>, <code>r(sheet)</code>, and <code>r(decimals)</code>.

## Assumptions and Limits

### Study design

These weights address measured visit timing and, when requested, measured treatment confounding; they do not make an observational design causal without credible exchangeability, positivity, and model specification. Unmeasured confounding, unmeasured visit drivers, and misspecified functional forms remain limitations.

The treatment implementation is for a binary, time-invariant treatment. Treatment switching requires a time-varying treatment marginal structural model, which this package does not implement. The package models when visits occur; it does not fit a dropout or censoring model. <code>censor()</code> and <code>maxfu()</code> define the at-risk window rather than estimating a censoring weight.

Current visit measurements must not be used as if they were known before the visit. Use <code>lagvars()</code> for previous-visit information, and remember that time-varying covariates are carried forward over the terminal at-risk interval.

### Diagnostics and stability

A large composition shift is descriptive and can be evidence that the weights are doing work; the target SMD is the diagnostic with a reference distribution. Read <code>r(balance_flag)</code> together with leverage and effective sample size, and treat <code>unknown</code> or <code>not_assessed</code> as absence of a supported verdict rather than as balance.

Extreme weights, low effective sample size, rare treatment patterns, few clusters, and nonconvergence can make estimates unstable. The default is to stop on nonconvergence or missing weights; <code>allownonconverged</code>, <code>allowmissingweights</code>, and <code>allowfailedreps</code> are explicit acknowledgments of weakened analyses, not repairs.

### Compatibility notes

Version 2.0.0 made the end-of-follow-up contract explicit, changed the first-visit default to <code>baseline(entry)</code>, removed <code>truncate()</code>, and made stale or missing weight state fail closed. Re-run <code>iivw_weight</code> when using a dataset whose older weighting contract lacks the stored replay information required by refit bootstrap or balance replay.

Weighted <code>model(mixed)</code> requires <code>experimentalmixed</code> because a single observation-level probability weight does not consistently weight the random-effects variance components. Use weighted <code>model(gee)</code> for the primary marginal analysis; interpret weighted mixed-model fixed effects as an experimental sensitivity analysis.

## References

- Buzkova P, Lumley T. Longitudinal data analysis for generalized linear models with follow-up dependent on outcome-related variables. <em>Canadian Journal of Statistics</em>. 2007;35(4):485–500. doi:10.1002/cjs.5550350402.
- Coulombe J, Moodie EEM, Platt RW. Weighted regression analysis to correct for informative monitoring times and confounders in longitudinal studies. <em>Biometrics</em>. 2021;77(1):162–174. doi:10.1111/biom.13285.
- Lin H, Scharfstein DO, Rosenheck RA. Analysis of longitudinal data with irregular, outcome-dependent follow-up. <em>Journal of the Royal Statistical Society: Series B</em>. 2004;66(3):791–813. doi:10.1111/j.1467-9868.2004.b5543.x.
- Rabe-Hesketh S, Skrondal A. Multilevel modelling of complex survey data. <em>Journal of the Royal Statistical Society: Series A</em>. 2006;169(4):805–827. doi:10.1111/j.1467-985X.2006.00426.x.
- Tompkins G, Dubin JA, Wallace M. On flexible inverse probability of treatment and intensity weighting: Informative censoring, variable selection, and weight trimming. <em>Statistical Methods in Medical Research</em>. 2025;34(5):915–937. doi:10.1177/09622802241313289.
- Hertz-Picciotto I, Rockhill B. Validity and efficiency of approximation methods for tied survival times in Cox regression. <em>Biometrics</em>. 1997;53(3):1151–1156.

## QA

QA suites and how to run them are documented in [qa/README.md](qa/README.md).

## Version History

- **3.2.1** (2026-08-04): Reporting exports now preserve quoted worksheet names and workbook paths through the internal writer; package and QA release hygiene was updated.
- **3.2.0** (2026-08-03): Constant outcomes now fail explicitly, follow-up and weight-contract documentation was corrected, and shipped help examples were repaired.
- **3.1.0** (2026-07-25): Treatment-weight trimming uses subject-level percentiles, while visit and final-weight trimming retain their row-level definitions.

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
