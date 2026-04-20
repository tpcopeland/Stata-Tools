# kmplot - Publication-ready Kaplan-Meier and cumulative incidence plots

**Version 1.0.1** | 2026-04-10

`kmplot` turns an `stset` dataset into publication-ready survival graphics with sensible defaults for confidence intervals, risk tables, median lines, censor marks, and log-rank p-values. It keeps the flexibility of native Stata graphics while removing most of the repetitive styling work that usually follows `sts graph`.

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
| `kmplot` | Draw Kaplan-Meier or cumulative incidence curves with publication-oriented defaults |

## How It Works

- `kmplot` reads the current `stset` definition, so there is no separate model-fitting step.
- Add `by()` when you want one curve per group. `pvalue` only applies when `by()` is present.
- Add `failure` when you want cumulative incidence, that is `1 - S(t)`, instead of survival.
- Add `ci`, `risktable`, `median`, `medianannotate`, `censor`, and `export()` as you build up a manuscript-ready figure.

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

### 3. Cumulative incidence instead of survival

```stata
sysuse cancer, clear
stset studytime, failure(died)
kmplot, by(drug) failure risktable
```

### 4. Export the finished graph directly

```stata
sysuse cancer, clear
stset studytime, failure(died)
kmplot, by(drug) ci median export(km_figure.pdf, replace)
```

## Key Features

- Shaded confidence bands or dashed confidence-interval lines via `cistyle(band)` and `cistyle(line)`
- Number-at-risk tables, with optional cumulative event counts
- Median survival reference lines and optional note annotations
- Censor marks with thinning through `censorthin()`
- Direct graph export through `export()`
- Pass-through support for standard `twoway` graph options

## Version History

- **1.0.1** (2026-04-10): Initial Stata-Tools release with Kaplan-Meier, cumulative-incidence, risk-table, censoring, median-line, and export support

## Author

Timothy P Copeland, Karolinska Institutet
