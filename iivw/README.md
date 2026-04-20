# iivw - Inverse intensity of visit weighting for longitudinal data

**Version**: 1.0.1 | 2026-04-17

`iivw` corrects bias from informative visit timing in irregular longitudinal data. It computes inverse intensity weights (IIW), inverse probability of treatment weights (IPTW), or their product (FIPTIW), then fits weighted outcome models with GEE-style estimation or mixed models.

The package is designed for clinic-based panel data where sicker patients tend to be seen more often. `iivw_weight` stores the weighting metadata in dataset characteristics, and `iivw_fit` reads that metadata automatically so you do not need to restate the panel and weight settings.

## Requirements

- Stata 16 or later
- Stata 17 or later if you want `iivw_fit, model(mixed)`

## Installation

```stata
capture ado uninstall iivw
net install iivw, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/iivw") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `iivw` | Package overview and entry point |
| `iivw_weight` | Compute IIW, IPTW, or FIPTIW weights |
| `iivw_fit` | Fit a weighted outcome model after `iivw_weight` |

## How It Works

`iivw` has a simple two-command workflow:

1. Run `iivw_weight` on one row per visit data. You always specify `id()` and `time()`.
2. Choose the weighting strategy that matches your problem.
3. Run `iivw_fit` on the same dataset to fit the weighted outcome model.

Use the weighting modes as follows:

| Weight type | When to use it | Key `iivw_weight` inputs |
|-------------|----------------|--------------------------|
| `iivw` | Visit timing is informative, but treatment weighting is not needed | `id()` `time()` `visit_cov()` |
| `iptw` | Treatment confounding only | `treat()` `treat_cov()` `wtype(iptw)` |
| `fiptiw` | Both informative visit timing and treatment confounding matter | `id()` `time()` `visit_cov()` `treat()` `treat_cov()` |

Important behavior:

- `treat()` must be binary and time-invariant within subject.
- `categorical()` in `iivw_fit` is for the outcome model only. It does not create multi-arm IPTW.
- `iivw_fit` automatically uses the weight variable, panel ID, and time variable recorded by `iivw_weight`.

## Worked Examples

These examples use a self-contained synthetic panel because Stata does not ship a built-in irregular-visit dataset that exercises the full workflow.

### 1. Create example longitudinal data

This setup creates four visits per subject, irregular visit times, a continuous outcome (`edss`), a binary treatment (`treated`), and a three-level treatment label (`treatment`) for outcome-model examples.

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

This is the basic workflow when the main concern is that patients with worse disease are seen more often. `visit_cov()` contains the variables that drive visit intensity.

```stata
iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
summarize _iivw_weight, detail
iivw_fit edss treated edss_bl, model(gee) timespec(linear)
```

Look at the weight distribution before moving on. If the tails are extreme, rerun `iivw_weight` with `truncate(# #)`.

### 3. FIPTIW: correct visit timing and treatment confounding together

Add `treat()` and `treat_cov()` when treatment assignment is also non-random. Here the final weights combine the visit-process model and the treatment model.

```stata
iivw_weight, id(id) time(days) ///
    visit_cov(edss relapse) ///
    treat(treated) treat_cov(age sex edss_bl) ///
    truncate(1 99) replace nolog

iivw_fit edss treated age sex edss_bl, model(gee) timespec(quadratic)
```

This is the canonical FIPTIW workflow for a binary treatment.

### 4. Time-varying effects in the weighted outcome model

Once weights are in place, `iivw_fit` can add time terms and time interactions. This example asks whether the treatment effect changes over follow-up.

```stata
iivw_fit edss treated age sex edss_bl, ///
    model(gee) timespec(ns(3)) interaction(treated)
```

Use `timespec(linear)`, `timespec(quadratic)`, `timespec(cubic)`, `timespec(ns(#))`, or `timespec(none)` depending on how flexible the time trend should be.

### 5. Categorical predictors in the outcome model

This example still uses the current weight variable created by `iivw_weight`, but it models a labeled three-level treatment variable in the outcome model. That is what `categorical()` is for.

```stata
iivw_weight, id(id) time(days) visit_cov(edss relapse) replace nolog
iivw_fit edss treatment edss_bl, ///
    categorical(treatment) timespec(ns(3)) interaction(treatment)
```

If you need treatment weighting, `treat()` in `iivw_weight` remains binary. A multi-level treatment can still appear in `iivw_fit` as an ordinary modeled predictor.

### 6. Bootstrap standard errors

Bootstrap replicates apply to the outcome model fit with fixed weights. The weights are not re-estimated inside each bootstrap draw.

```stata
iivw_fit edss treated edss_bl, bootstrap(500) nolog
```

## Key Options

### `iivw_weight`

| Option | Meaning |
|--------|---------|
| `visit_cov(varlist)` | Covariates for the Andersen-Gill visit model |
| `treat(varname)` | Binary treatment indicator for IPTW or FIPTIW |
| `treat_cov(varlist)` | Covariates for the treatment model |
| `stabcov(varlist)` | Covariates for stabilized IIW numerator model |
| `lagvars(varlist)` | Time-varying covariates to lag by one visit |
| `truncate(# #)` | Percentile truncation of the final weights |
| `generate(name)` | Prefix for generated weight variables |

### `iivw_fit`

| Option | Meaning |
|--------|---------|
| `model(gee)` | Default GEE-style weighted fit via `glm` with clustered robust SEs |
| `model(mixed)` | Mixed-effects outcome model |
| `timespec(...)` | Time trend: `linear`, `quadratic`, `cubic`, `ns(#)`, or `none` |
| `interaction(varlist)` | Time x covariate interactions |
| `categorical(varlist)` | Expand labeled categorical predictors |
| `bootstrap(#)` | Bootstrap SEs for the outcome model |

## Validation

The package ships with functional, validation, and cross-validation QA under `qa/`. The cross-validation workflows compare `iivw` against independent R implementations for both IIW-style weighting and the FIPTIW setting described by Tompkins et al. (2025).

## References

- Buzkova P, Lumley T. Longitudinal data analysis for generalized linear models with follow-up dependent on outcome-related variables. *Canadian Journal of Statistics*. 2007;35(4):485-500.
- Lin H, Scharfstein DO, Rosenheck RA. Analysis of longitudinal data with irregular, outcome-dependent follow-up. *Journal of the Royal Statistical Society Series B*. 2004;66(3):791-813.
- Pullenayegum EM. Multiple outputation for the analysis of longitudinal data subject to irregular observation. *Statistics in Medicine*. 2016;35(11):1800-1818.
- Tompkins G, Dubin JA, Wallace M. On flexible inverse probability of treatment and intensity weighting. *Statistical Methods in Medical Research*. 2025.

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
