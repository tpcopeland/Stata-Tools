# kmplot - Publication-ready Kaplan-Meier survival and cumulative failure plots

**Version 1.2.1** | 2026-06-26

`kmplot` turns an `stset` dataset into publication-ready survival graphics with sensible defaults for confidence intervals, risk tables, fixed-time summaries, median lines, censor marks, and log-rank p-values. It keeps the flexibility of native Stata graphics while returning the reusable curve, risk-table, and landmark numbers needed for manuscripts.

## Requirements

- Stata 16 or later
- Data already declared with `stset`

## Installation

```stata
capture ado uninstall kmplot
net install kmplot, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/kmplot") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `kmplot` | Draw Kaplan-Meier survival or cumulative failure curves with publication-oriented defaults |

## How It Works

- `kmplot` reads the current `stset` definition, so there is no separate model-fitting step.
- Add `by()` when you want one curve per group. `pvalue` only applies when `by()` is present.
- Add `failure` when you want cumulative failure, that is `1 - S(t)`, instead of survival.
- Add `ci`, `level()`, `risktable`, `median`, `landmark()`, `censor`, `saving()`, `risksaving()`, and `export()` as you build up a manuscript-ready figure and its matching numbers.

## Worked Examples

### 1. Basic Kaplan-Meier curve

```stata
sysuse cancer, clear
stset studytime, failure(died)
kmplot
```

### 2. Stratified publication-style figure

This adds the features that usually matter in a manuscript figure: confidence bands, a number-at-risk table, median reference lines, censor marks, and the log-rank p-value.

```stata
sysuse cancer, clear
stset studytime, failure(died)
kmplot, by(drug) ci risktable median medianannotate pvalue censor
```

### 3. Cumulative failure instead of survival

```stata
sysuse cancer, clear
stset studytime, failure(died)
kmplot, by(drug) failure risktable
```

### 4. Fixed-time estimates and saved data

```stata
sysuse cancer, clear
stset studytime, failure(died)
kmplot, by(drug) ci risktable landmark(12 24) ///
    saving(curve_output, replace) risksaving(risk_output, replace)
matrix list r(landmarks)
matrix list r(risktable)
```

### 5. Export the finished graph directly

```stata
sysuse cancer, clear
stset studytime, failure(died)
kmplot, by(drug) ci median export(km_figure.pdf, replace)
```

## Demo Gallery

The shipped demo script in `demo/demo_kmplot.do` produces these PNG assets:

| Output | Command focus |
|--------|---------------|
| [km_basic.png](demo/km_basic.png) | Basic single-group Kaplan-Meier curve |
| [km_by_group.png](demo/km_by_group.png) | Stratified curves with `by()` |
| [km_ci_median.png](demo/km_ci_median.png) | CI bands and median reference lines |
| [km_failure_risktable.png](demo/km_failure_risktable.png) | Cumulative failure with a risk table |
| [km_risk_censor.png](demo/km_risk_censor.png) | Risk table with event counts and censor marks |
| [km_publication.png](demo/km_publication.png) | Full publication-style figure |
| [km_custom_style.png](demo/km_custom_style.png) | Custom colors, line patterns, CI lines, and p-value placement |
| [km_plain_ci.png](demo/km_plain_ci.png) | Plain-transform CI bands with custom opacity |
| [km_pvalue_level.png](demo/km_pvalue_level.png) | Journal-style p-value label and user-set 90% CI level |

## Key Features

- Shaded confidence bands or dashed confidence-interval lines via `cistyle(band)` and `cistyle(line)`
- User-selected CI levels via `level()`
- Number-at-risk tables, with optional cumulative event counts
- Automatic and user-controlled risk-table height via `riskheight()`
- Fixed-time survival or cumulative failure estimates via `landmark()`
- Median survival reference lines and optional note annotations
- Censor marks with thinning through `censorthin()`
- Reusable curve and risk-table datasets via `saving()` and `risksaving()`
- Rich `r()` metadata and matrices for reproducible figure recipes
- Journal-specific p-value label, format, and coordinate controls
- Direct graph export through `export()`
- Pass-through support for standard `twoway` graph options

## Method Notes

`kmplot` uses Stata's survival-time machinery after `stset`. Kaplan-Meier estimates and Greenwood standard errors come from `sts generate`; log-rank p-values come from `sts test, logrank`; and confidence intervals use the selected `level()` and transformation.

The `failure` option plots cumulative failure, `1 - S(t)`, from the Kaplan-Meier curve. It is not a competing-risk cumulative incidence function and does not implement Aalen-Johansen or Fine-Gray estimators.

Risk-table counts honor delayed entry through `_t0` when data are `stset` with `enter(...)`.

## QA

Run the full package QA from the package directory:

```stata
cd qa
do run_all.do
```

The current standard suite includes `test_kmplot.do` for functional and regression coverage and `validation_kmplot.do` for numerical validation against Stata survival commands and hand-computed invariants.

The QA directory contains 115 tests across 2 QA files and covers all one public command.

- `test_kmplot.do` - 86 tests for functional, option, state-restoration, export/save, and regression coverage
- `validation_kmplot.do` - 29 tests for numerical validation and survival-analysis invariants

| QA file | Tests | Purpose |
|---------|-------|---------|
| `test_kmplot.do` | 86 | Functional, option, state-restoration, export/save, and regression coverage |
| `validation_kmplot.do` | 29 | Numerical validation and survival-analysis invariants |

## Version History

- **1.2.1** (2026-06-26): Made the shaded confidence bands step with the Kaplan-Meier curve instead of cutting diagonally between event times, so the band tracks the staircase. Removed gridlines from the number-at-risk table and increased the vertical separation between the table and the x-axis labels for cleaner combined figures. Corrected the `ciopacity()` abbreviation in the help file, added auto-height, `saving()`-without-`ci`, and stepped-band regression tests, and added a p-value/CI-level demo panel.
- **1.2.0** (2026-06-26): Added `level()`, `riskheight()`, `landmark()`, `saving()`, `risksaving()`, p-value display controls, richer `r()` metadata and matrices, delayed-entry QA/docs, cumulative-failure terminology, method notes, and README gallery.
- **1.0.3** (2026-06-25): Replaced internal graph-working variables with `tempvar`s, restored preserved data on error paths, guarded `export()` paths, preserved analytical returns across export failures, and refreshed QA organization with a curated runner.
- **1.0.2** (2026-04-22): Varabbrev wrapper refactored to cover all exit paths (syntax, validation, and main logic). Fixed literal-quote rendering in user-supplied ytitle/xtitle/note options. Removed unnecessary `set more off`. Export success message now guarded by `confirm file`.
- **1.0.1** (2026-04-10): Initial Stata-Tools release with Kaplan-Meier, cumulative-failure, risk-table, censoring, median-line, and export support

## Author

Timothy P Copeland, Karolinska Institutet
