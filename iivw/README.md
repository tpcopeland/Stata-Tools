# iivw - Inverse intensity of visit weighting for longitudinal data

**Version 1.0.2** | 2026-04-26

`iivw` corrects bias from informative visit timing in irregular longitudinal data. It computes inverse intensity weights (IIW), inverse probability of treatment weights (IPTW), or their product (FIPTIW), then fits weighted outcome models with GEE-style estimation or mixed models. The package is designed for clinic-based panel data where sicker patients tend to be seen more often.

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

1. Run `iivw_weight` on one row per visit data. You always specify `id()` and `time()`.
2. Choose the weighting strategy that matches the scientific problem.
3. Inspect the resulting weight distribution before fitting the outcome model.
4. Run `iivw_fit` on the same dataset. It reads the stored weighting metadata automatically.

## Choosing a Weight Type

| Weight type | When to use it | Key `iivw_weight` inputs |
|-------------|----------------|--------------------------|
| `iivw` | Visit timing is informative, but treatment weighting is not needed | `id()` `time()` `visit_cov()` |
| `iptw` | Treatment confounding only | `treat()` `treat_cov()` `wtype(iptw)` |
| `fiptiw` | Both informative visit timing and treatment confounding matter | `id()` `time()` `visit_cov()` `treat()` `treat_cov()` |

## Worked Examples

These examples use a self-contained synthetic panel because Stata does not ship a built-in irregular-visit dataset that exercises the full workflow.

### 1. Create example longitudinal data

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

This is the basic workflow when the main concern is that patients with worse disease are seen more often.

```stata
iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
summarize _iivw_weight, detail
iivw_fit edss treated edss_bl, model(gee) timespec(linear)
```

If the weight tails are extreme, rerun `iivw_weight` with `truncate(# #)` before fitting the outcome model.

### 3. FIPTIW: correct visit timing and treatment confounding together

Add `treat()` and `treat_cov()` when treatment assignment is also non-random.

```stata
iivw_weight, id(id) time(days) ///
    visit_cov(edss relapse) ///
    treat(treated) treat_cov(age sex edss_bl) ///
    truncate(1 99) replace nolog

iivw_fit edss treated age sex edss_bl, model(gee) timespec(quadratic)
```

### 4. Add time-varying effects in the weighted outcome model

Once weights are in place, `iivw_fit` can add time trends and time interactions.

```stata
iivw_fit edss treated age sex edss_bl, ///
    model(gee) timespec(ns(3)) interaction(treated)
```

Use `timespec(linear)`, `timespec(quadratic)`, `timespec(cubic)`, `timespec(ns(#))`, or `timespec(none)` depending on how flexible the time trend should be.

### 5. Use categorical predictors in the outcome model

`categorical()` affects the outcome model only. It does not create multi-arm IPTW.

```stata
iivw_weight, id(id) time(days) visit_cov(edss relapse) replace nolog
iivw_fit edss treatment edss_bl, ///
    categorical(treatment) timespec(ns(3)) interaction(treatment)
```

### 6. Bootstrap standard errors

Bootstrap replicates apply to the outcome model fit with fixed weights. The weights are not re-estimated inside each bootstrap draw.

```stata
iivw_fit edss treated edss_bl, bootstrap(500) nolog
```

## Practical Notes

- `treat()` must be binary and time-invariant within subject.
- `iivw_fit` automatically uses the weight variable, panel ID, and time variable recorded by `iivw_weight`.
- `categorical()` is for the outcome model only. It does not define IPTW treatment levels.
- `bootstrap()` reflects outcome-model uncertainty only because the weights are treated as fixed.

## Validation

The package ships with functional, validation, and cross-validation QA under `qa/`, including comparisons against independent R workflows for both IIW-style weighting and the FIPTIW setting.

## References

- Buzkova P, Lumley T. Longitudinal data analysis for generalized linear models with follow-up dependent on outcome-related variables. *Canadian Journal of Statistics*. 2007;35(4):485-500.
- Lin H, Scharfstein DO, Rosenheck RA. Analysis of longitudinal data with irregular, outcome-dependent follow-up. *Journal of the Royal Statistical Society Series B*. 2004;66(3):791-813.
- Pullenayegum EM. Multiple outputation for the analysis of longitudinal data subject to irregular observation. *Statistics in Medicine*. 2016;35(11):1800-1818.
- Tompkins G, Dubin JA, Wallace M. On flexible inverse probability of treatment and intensity weighting. *Statistical Methods in Medical Research*. 2025.

## Changelog

### v1.0.2 (2026-04-26)

- Added `efron` option to `iivw_weight` for Efron tie-handling in the Cox model (matches R's coxph default; Breslow remains the Stata default)
- Improved `stabcov()` documentation with guidance on numerator model specification in FIPTIW settings
- Added Remarks in `iivw_fit.sthlp` for choosing between GEE and mixed models, and for timespec selection
- Expanded `entry()` documentation for late-entry/left-truncation designs
- Fixed `iivw.sthlp` Example 1 to match README (was showing wrong predictors)
- Improved error message for time-varying treatment (suggests MSMs as alternative)

## Author

Timothy P Copeland, Karolinska Institutet
