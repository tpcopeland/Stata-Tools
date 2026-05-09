# iivw - Inverse intensity of visit weighting for longitudinal data

**Version 1.0.5** | 2026-05-09

`iivw` corrects bias from informative visit timing in irregular longitudinal data.  In clinic-based studies, sicker patients often visit more frequently, so they contribute more rows to the dataset and bias naive analyses.  This package re-weights each observation so the fitted outcome model targets the patient population more directly rather than the clinic-visit process.

Three weighting strategies are available:

- **IIW** (inverse intensity weighting) — corrects for outcome-dependent visit frequency
- **IPTW** (inverse probability of treatment weighting) — corrects for confounding by treatment indication
- **FIPTIW** (IIW × IPTW) — corrects for both simultaneously

Weighted outcome models are fit via GEE-style estimation (GLM with clustered robust SEs) or mixed effects.

## Requirements

- Stata 16 or later
- Stata 17 or later for `iivw_fit, model(mixed)`
- Optional: `tabtools` for the `regtab` Excel export examples

## Installation

```stata
capture ado uninstall iivw
net install iivw, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/iivw") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `iivw` | Package overview and available commands |
| `iivw_weight` | Compute IIW, IPTW, or FIPTIW weights |
| `iivw_fit` | Fit a weighted outcome model after `iivw_weight` |

## Plain-Language Summary

Longitudinal clinic data usually has one row per visit.  If some patients visit more often because they are getting worse, those patients also appear more often in the dataset.  A standard regression then partly answers the wrong question: it estimates an association in the visit process, not only in the patient population.

`iivw` estimates how likely each observed visit was, then gives less influence to visits that were very likely to occur and more influence to visits that were less likely to occur.  If treatment assignment is also confounded, `iivw` can multiply those visit weights by propensity-score treatment weights.

Use the package as a two-step workflow:

1. `iivw_weight` creates weights and stores the panel metadata.
2. `iivw_fit` reads those weights and fits the weighted outcome model.

## When Do I Need This?

You likely need this package if:

1. Your data comes from a clinical registry, electronic health records, or any setting where visit times are determined by clinical need rather than a fixed protocol.
2. You have longitudinal data with unequal numbers of visits per subject, and sicker (or healthier) patients are observed more often.
3. You want to estimate a treatment effect, disease trajectory, or covariate association and need to remove bias from informative visit timing.

You probably do *not* need this if visits follow a fixed protocol (e.g., randomized trial with scheduled assessments) or if the main concern is dropout rather than differential visit frequency.

## How It Works

1. **Compute weights** with `iivw_weight`.  You always specify `id()` and `time()`.  For IIW/FIPTIW, the command fits an Andersen-Gill recurrent-event Cox model to estimate each subject's visit intensity; for IPTW-only, it fits only the treatment propensity model.  It then creates a weight variable in the dataset.
2. **Choose the weighting strategy** that matches the scientific problem (see table below).
3. **Inspect weights** with `summarize _iivw_weight, detail`.  Look for extreme values.  If the weight distribution has heavy tails, re-run with `truncate(1 99)` to cap extreme weights.
4. **Fit the outcome model** with `iivw_fit`.  It reads the weight variable and panel structure from the dataset automatically.

## Choosing a Weight Type

| Weight type | When to use | Key `iivw_weight` options |
|-------------|-------------|---------------------------|
| `iivw` | Visit timing is informative, but treatment weighting is not needed | `id()` `time()` `visit_cov()` |
| `iptw` | Treatment confounding only (visits are protocol-driven) | `treat()` `treat_cov()` `wtype(iptw)` |
| `fiptiw` | Both informative visit timing and treatment confounding | `id()` `time()` `visit_cov()` `treat()` `treat_cov()` |

By default, `iivw_weight` auto-detects the type: specifying `treat()` triggers FIPTIW; omitting it triggers IIW.  Override with `wtype()`.

## Data Contract

`iivw_weight` expects long panel data: one row per subject-visit.  `id()` identifies the subject, and `time()` identifies visit time.  The `id()` and `time()` combination must be unique and nonmissing.  For IIW and FIPTIW, each subject needs at least two visits because the command estimates a visit-intensity model from inter-visit intervals.

For IPTW and FIPTIW, `treat()` must be a binary 0/1 treatment indicator, observed on every row, and constant within subject.  Treatment-model covariates are supplied with `treat_cov()` and are not inferred from `visit_cov()`.  IPTW-only analyses can use one row per subject by specifying `wtype(iptw)`.

## What Gets Added to the Data

By default, `iivw_weight` creates `_iivw_weight`, the final weight used by `iivw_fit`.  It also creates component weights when needed: `_iivw_iw` for visit-intensity weights and `_iivw_tw` for treatment weights.  Use `generate(prefix)` to change the prefix.

The weighting step also stores dataset metadata, including the panel ID, time variable, weight type, weight variable, and prefix.  `iivw_fit` reads that metadata automatically, so the usual workflow is to run `iivw_weight`, inspect the weights, and then run `iivw_fit` without re-entering the panel structure.

## Assumptions and Limits

The weights are a tool for a specific bias problem.  They do not make a weak study design causal by themselves.

| Requirement | Why it matters |
|-------------|----------------|
| Visit model covariates capture the drivers of visit timing | IIW only removes bias explained by measured covariates |
| Treatment model covariates capture measured treatment confounding | IPTW/FIPTIW assume no unmeasured confounding after adjustment |
| Treatment is binary and time-invariant within subject | Current IPTW/FIPTIW implementation is not for treatment switching |
| Positivity/overlap is plausible | Subjects with near-certain treatment or visits create extreme weights |
| Outcome model includes the scientific predictors of interest | Weights correct sampling/visit imbalance; they do not choose the outcome model |
| Standard errors treat weights as fixed | Built-in sandwich and bootstrap SEs do not re-estimate weights |

For dropout or censoring, use an IPCW strategy.  For time-varying treatment decisions, use a marginal structural model designed for that setting.

## Worked Examples

These examples use a self-contained synthetic panel because Stata does not ship a built-in irregular-visit dataset that exercises the full workflow.

### 1. Create example longitudinal data

This creates 80 subjects with 4 visits each, a continuous disability outcome (EDSS), a binary treatment, and a binary event (relapse) that also predicts visit frequency.

```stata
clear
set seed 20260417
set obs 320
gen long id = ceil(_n/4)
bysort id: gen byte visit = _n
gen double days = (visit - 1) * 90 + runiform() * 20
replace days = 0 if visit == 1
gen double edss_bl = 2 + 3 * runiform()
bysort id: replace edss_bl = edss_bl[1]
gen double age = 35 + 15 * runiform()
bysort id: replace age = age[1]
gen byte sex = runiform() > 0.5
bysort id: replace sex = sex[1]
gen byte treated = (runiform() < invlogit(-0.8 + 0.5 * edss_bl))
bysort id: replace treated = treated[1]
gen double edss = edss_bl + 0.012 * days - 0.7 * treated + rnormal(0, 0.45)
gen byte relapse = (runiform() < invlogit(-2 + 0.4 * edss))
gen byte treatment = cond(treated == 0, 0, cond(edss_bl < 3.5, 1, 2))
label define arm 0 "Placebo" 1 "Low dose" 2 "High dose"
label values treatment arm
```

### 2. IIW only: correct the visit process

When the main concern is that patients with worse disease are seen more often, but treatment assignment is either randomized or not being analyzed:

```stata
iivw_weight, id(id) time(days) ///
    visit_cov(edss_bl age sex) lagvars(edss relapse) nolog
summarize _iivw_weight, detail
iivw_fit edss treated edss_bl, model(gee) timespec(linear)
```

After computing weights, always inspect the distribution before fitting the outcome model.  If the weight tails are extreme (e.g., max > 10), re-run `iivw_weight` with `truncate(1 99)`.  For real analyses, prefer baseline or lagged time-varying predictors in the visit model when the current visit measurement should not be used to explain the timing of that same visit.

### 3. FIPTIW: correct visit timing and treatment confounding together

Add `treat()` and `treat_cov()` when treatment assignment is also non-random:

```stata
iivw_weight, id(id) time(days) ///
    visit_cov(edss_bl age sex) lagvars(edss relapse) ///
    treat(treated) treat_cov(age sex edss_bl) ///
    truncate(1 99) replace nolog

iivw_fit edss treated age sex edss_bl, model(gee) timespec(quadratic)
```

### 4. Add time-varying effects in the weighted outcome model

Once weights are in place, `iivw_fit` can add flexible time trends and time × covariate interactions:

```stata
iivw_fit edss treated age sex edss_bl, ///
    model(gee) timespec(ns(3)) interaction(treated) replace
```

Use `timespec(linear)`, `timespec(quadratic)`, `timespec(cubic)`, `timespec(ns(#))`, or `timespec(none)` depending on how flexible the time trend should be.  Start with `linear`, then compare to `ns(3)` to check sensitivity.

### 5. Use categorical predictors in the outcome model

`categorical()` expands a multi-level variable into labeled dummy variables.  It affects the outcome model only — it does not create multi-arm IPTW.

```stata
iivw_weight, id(id) time(days) ///
    visit_cov(edss_bl age sex) lagvars(edss relapse) replace nolog
iivw_fit edss treatment edss_bl, ///
    categorical(treatment) timespec(ns(3)) interaction(treatment) replace
```

### 6. Bootstrap standard errors

Bootstrap replicates apply to the outcome model fit with fixed weights.  The weights are not re-estimated inside each bootstrap draw:

```stata
iivw_fit edss treated edss_bl, bootstrap(500) nolog replace
```

### 7. Export results to Excel

Use the `collect` option with `regtab` (from the `tabtools` package) to build publication-ready tables:

```stata
collect clear
iivw_fit edss treated edss_bl, model(gee) nolog replace collect
regtab, xlsx(iivw_results.xlsx) sheet(Results) title(IIW Analysis) stats(n)
```

## Weight Diagnostics

After running `iivw_weight`, check these before fitting the outcome model:

| Diagnostic | What to look for | Action if concerning |
|------------|------------------|---------------------|
| `summarize _iivw_weight, detail` | Max > 10, max/min ratio > 100 | Add `truncate(1 99)` |
| Effective sample size (reported automatically) | ESS much less than N | Simplify the visit model or truncate |
| Weight mean (reported automatically) | Mean far from 1.0 | Check model specification |
| Compare with/without truncation | Treatment effect changes substantially | Result may be driven by a few extreme weights |
| `summarize _iivw_tw, detail` (FIPTIW only) | Extreme treatment weights | Positivity violations — check covariate overlap |

## Common Problems and Fixes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `treat() contains missing values` | Treatment is missing on one or more visit rows | Fill the baseline treatment consistently within subject, or exclude those subjects deliberately |
| `treat() must be time-invariant` | Treatment changes over time | Do not use this IPTW/FIPTIW implementation; use a time-varying treatment/MSM approach |
| `requires at least 2 visits per subject` | IIW/FIPTIW needs repeated visits | Use repeated-visit data, or use `wtype(iptw)` for treatment weighting only |
| Very large weights | Sparse overlap, overfit model, or unusual visit patterns | Inspect covariates, simplify the model, and try `truncate(1 99)` |
| `variable ... already exists` | Re-running created-variable steps | Add `replace` if overwriting is intended |
| `iivw_fit` says weights are missing | Dataset changed or weights were dropped after `iivw_weight` | Re-run `iivw_weight` immediately before `iivw_fit` |

## Interpreting Results

- **Coefficients** (default GEE with gaussian family) are the change in the outcome per one-unit change in the predictor, averaged over the population.
- **Treatment effect**: The coefficient on the treatment variable is the weighted treatment contrast.  A causal interpretation additionally requires a correctly specified visit model, a correctly specified propensity model for IPTW/FIPTIW, no unmeasured confounding, and a treatment assignment mechanism appropriate for the chosen weight type.
- **Standard errors** are sandwich (robust) SEs clustered at the subject level.  They do not account for weight estimation uncertainty.
- **Post-estimation**: All standard Stata post-estimation commands work after `iivw_fit` (`predict`, `lincom`, `test`, `margins`).

## What to Report

For technical reports and papers, include enough detail for readers to assess the weighting step:

- weight type used (`iivw`, `iptw`, or `fiptiw`)
- visit model covariates and whether `efron` tie handling was used
- treatment model covariates for IPTW/FIPTIW
- whether weights were stabilized with `stabcov()` and/or truncated with `truncate()`
- weight diagnostics: mean, min, max, selected percentiles, and effective sample size
- outcome model family/link, time specification, clustering level, and whether SEs were sandwich or bootstrap

## Practical Notes

- `treat()` must be observed on every row used in IPTW/FIPTIW, binary (0/1), and time-invariant within each subject.  For time-varying treatments, consider marginal structural models instead.
- `treat_cov()` is required for IPTW and FIPTIW; treatment-model covariates are not inferred from `visit_cov()`.
- IPTW-only analyses may use one row per subject.  IIW and FIPTIW require repeated visits because they estimate a visit-intensity model.
- `iivw_fit` automatically reads the weight variable, panel ID, and time variable stored by `iivw_weight`.
- `categorical()` is for the outcome model only.  It does not define IPTW treatment levels.
- `lagvars()` is useful when a time-varying variable should enter the visit model using its previous-visit value rather than its current-visit value.
- `bootstrap()` reflects outcome-model uncertainty only because the weights are treated as fixed.
- `efron` in `iivw_weight` uses the Efron tie-handling method in the Cox model (matches R's `coxph()` default; Breslow remains the Stata default).

## Validation

The package ships with functional, validation, and cross-validation QA under `qa/`, including comparisons against independent R workflows for both IIW-style weighting and the FIPTIW setting.

## Demo

The full FIPTIW workflow (weighting, weight diagnostics, outcome model) is rendered as a self-contained HTML document:

**[View rendered output (console_output.html)](demo/console_output.html)**

The demo also produces a multi-model comparison table (`demo/iivw_results.xlsx`) showing IIW, FIPTIW, FIPTIW with treatment-time interaction, and FIPTIW with categorical treatment side by side.

Regenerate from the repository root with:

```stata
do iivw/demo/demo_iivw.do
```

## References

- Buzkova P, Lumley T. Longitudinal data analysis for generalized linear models with follow-up dependent on outcome-related variables. *Canadian Journal of Statistics*. 2007;35(4):485-500.
- Lin H, Scharfstein DO, Rosenheck RA. Analysis of longitudinal data with irregular, outcome-dependent follow-up. *Journal of the Royal Statistical Society Series B*. 2004;66(3):791-813.
- Pullenayegum EM. Multiple outputation for the analysis of longitudinal data subject to irregular observation. *Statistics in Medicine*. 2016;35(11):1800-1818.
- Tompkins G, Dubin JA, Wallace M. On flexible inverse probability of treatment and intensity weighting. *Statistical Methods in Medical Research*. 2025.

## Changelog

### v1.0.5 (2026-05-09)

- Rejected invalid long `generate()` prefixes before creating partial outputs
- Rejected missing `treat()` values for IPTW/FIPTIW and negative `bootstrap()` counts
- Added exact known-answer validation and stricter R fixture coefficient checks

### v1.0.4 (2026-05-06)

- Added hard validation that `id()` and `time()` are nonmissing before `iivw_weight` reaches `stset`
- Enforced `entry()` as nonmissing, constant within subject, and strictly earlier than each subject's first visit
- Added adversarial QA lanes for weighting, outcome fitting, release/install/docs, validation guards, and external R cross-validation
- Integrated quick/full QA runner modes with full-mode R reference regeneration

### v1.0.3 (2026-04-30)

- Allowed IPTW-only weighting for one-row-per-subject datasets
- Required explicit `treat_cov()` for IPTW/FIPTIW treatment models
- Allowed `iivw_fit` time-only and intercept-only weighted outcome models
- Expanded the formatted effects summary to include time and interaction terms
- Made cross-validation path resolution robust to running from the package or repository root

### v1.0.2 (2026-04-26)

- Added `efron` option to `iivw_weight` for Efron tie-handling in the Cox model (matches R's coxph default; Breslow remains the Stata default)
- Added `collect` option to `iivw_fit` for Stata's collect framework integration
- Improved `stabcov()` documentation with guidance on numerator model specification in FIPTIW settings
- Added Remarks in `iivw_fit.sthlp` for choosing between GEE and mixed models, and for timespec selection
- Expanded `entry()` documentation for late-entry/left-truncation designs
- Fixed `iivw.sthlp` Example 1 to match README (was showing wrong predictors)
- Improved error message for time-varying treatment (suggests MSMs as alternative)

## Author

Timothy P Copeland, Karolinska Institutet
