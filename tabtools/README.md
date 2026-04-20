# tabtools - Publication-ready Excel tables across common Stata workflows

**Version 1.0.7** | 2026-04-18

`tabtools` is a suite of Stata commands for exporting manuscript-ready tables to Excel across descriptive summaries, regression models, treatment effects, survival analysis, diagnostic accuracy workflows, incidence rates, and composite tables. The package is organized around a shared formatting layer, so commands that come from very different analysis pipelines still produce tables that look like they belong in the same workbook.

## Requirements

- Stata 16 or later for `tabtools` and `table1_tc`
- Stata 17 or later for `regtab`, `effecttab`, `comptab`, `hrcomptab`, `survtab`, `crosstab`, `corrtab`, `diagtab`, and `stratetab`
- `regtab` and `effecttab` require Stata's `collect` framework
- `survtab` requires `stset` data, and `stratetab` expects saved `strate, output()` datasets

## Installation

```stata
capture ado uninstall tabtools
net install tabtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tabtools") replace
```

After installation, start with `help tabtools` for the suite overview, `help tabtools_cheatsheet` for common option patterns, and `help tabtools_cookbook` for longer worked workflows.

## Commands

### Direct table builders

| Command | Description | Stata |
|---------|-------------|-------|
| `table1_tc` | Table 1 generator with automatic tests, SMDs, weighting support, and Excel export | 16+ |
| `crosstab` | Cross-tabulation with association measures such as OR, RR, and risk difference | 17+ |
| `corrtab` | Correlation matrix with significance stars, p-values, and lower, upper, or full layouts | 17+ |
| `survtab` | Kaplan-Meier survival summary table with medians, RMST, and number at risk | 17+ |
| `diagtab` | Diagnostic-accuracy table with sensitivity, specificity, predictive values, likelihood ratios, and optional AUC | 17+ |

### Post-estimation formatters

| Command | Description | Stata |
|---------|-------------|-------|
| `regtab` | Format the current `collect` from regression models into a polished Excel table or console preview | 17+ |
| `effecttab` | Format `teffects` or `margins` results from the current `collect` into an effects table | 17+ |

### File and frame workflow builders

| Command | Description | Stata |
|---------|-------------|-------|
| `stratetab` | Format saved `strate, output()` files into incidence-rate tables | 17+ |
| `comptab` | Combine selected rows from one or more `regtab` or `effecttab` frames into one composite sheet | 17+ |
| `hrcomptab` | Build a final Table 2-style sheet by combining a `stratetab` frame with selected `regtab` rows | 17+ |

### Suite utility

| Command | Description | Stata |
|---------|-------------|-------|
| `tabtools` | Browse commands and manage persistent formatting defaults for the current Stata session | 16+ |

## Choosing a Workflow

| Workflow | Start here | Notes |
|----------|------------|-------|
| Descriptive table from the dataset in memory | `table1_tc`, `crosstab`, `corrtab`, `diagtab` | These commands work directly on the active dataset and do not require `collect` |
| Regression or effect estimates after modeling | `collect:` then `regtab` or `effecttab` | These commands format the active collection rather than refitting models |
| Survival summaries from `stset` data | `survtab` | Use when you want Kaplan-Meier estimates, medians, RMST, or risk sets |
| Incidence-rate tables from saved `strate` files | `stratetab` | File-based workflow; no dataset needs to remain in memory |
| Final manuscript table assembled from earlier outputs | `comptab` or `hrcomptab` | These second-stage builders consume frames produced earlier in the pipeline |
| Session-wide formatting defaults | `tabtools` | Use `tabtools set`, `tabtools get`, and `tabtools set clear` to control fonts, borders, themes, and digits |

## Worked Examples

### 1. Quick-start Table 1 from built-in data

This is the simplest install-safe entry point. `table1_tc` auto-detects variable types when you pass a varlist directly, so you only need `vars()` when you want explicit control over the type mapping.

```stata
sysuse auto, clear
table1_tc price mpg weight rep78, by(foreign) ///
    xlsx(table1.xlsx) sheet("Table 1") ///
    title("Table 1. Vehicle Characteristics by Origin") ///
    smd zebra
```

### 2. Regression table after `collect`

`regtab` reads the active collection and formats it into a manuscript-style table. If you omit `xlsx()`, the same formatted table can be previewed in the Results window.

```stata
sysuse auto, clear
generate byte expensive = (price > 6000)

collect clear
collect: logistic expensive mpg weight i.foreign
regtab, xlsx(regression.xlsx) sheet("Logistic") ///
    title("Table 2. Predictors of High Price") ///
    noint boldp(0.05) zebra
```

### 3. Treatment effects after `teffects`

`effecttab` is the parallel formatter for treatment effects and marginal results. Estimate first, then export the active collection.

```stata
webuse cattaneo2, clear

collect clear
collect: teffects ipw (bweight) ///
    (mbsmoke mage medu mmarried fbaby, logit), ate
effecttab, xlsx(effects.xlsx) sheet("ATE") ///
    effect("ATE") ///
    title("Average Treatment Effect on Birthweight") ///
    clean
```

### 4. Composite table from stored frames

`comptab` is the bridge from separate model tables to a single manuscript table. The source frames usually come from earlier `regtab` or `effecttab` runs.

```stata
sysuse auto, clear
generate byte expensive = (price > 6000)

collect clear
collect: logistic expensive i.foreign
regtab, frame(m1) noint

collect clear
collect: logistic expensive i.foreign mpg weight
regtab, frame(m2) noint

comptab m1 m2, rownames("foreign \ foreign") ///
    xlsx(composite.xlsx) sheet("Models") ///
    title("Table 3. Association with Price (OR, 95% CI)") ///
    zebra
```

### 5. Cross-tabulation and correlation tables

The direct descriptive commands do not require `collect`. They work straight from the dataset in memory.

```stata
sysuse auto, clear
generate byte expensive = (price > 6000)
crosstab expensive foreign, or label ///
    xlsx(crosstab.xlsx) ///
    title("Price by Origin")

corrtab price mpg weight length, xlsx(corrtab.xlsx) ///
    lower title("Correlation Matrix")
```

### 6. Survival summaries and incidence-rate tables

`survtab` runs after `stset`. `stratetab` formats the saved files produced by `strate`.

```stata
webuse drugtr, clear
stset studytime, failure(died)
survtab, times(5 10 15 20) by(drug) ///
    median riskset difference ///
    xlsx(survival.xlsx) sheet("KM") ///
    title("Survival by Treatment Group")

webuse diet, clear
stset dox, failure(fail) origin(time dob) enter(time doe) ///
    scale(365.25) id(id)
strate hieng, per(1000) output(rate_hieng, replace)
stratetab, using(rate_hieng) outcomes(1) ///
    xlsx(rates.xlsx) sheet("Rates") ///
    outlabels("CHD Death") explabels("Energy Intake") ///
    title("Incidence Rates per 1,000 Person-Years")
```

### 7. Diagnostic accuracy from a continuous score

`diagtab` accepts a binary test directly, or a continuous score when you specify a cutoff or ask for the optimal Youden threshold.

```stata
webuse lbw, clear
logit low age lwt smoke
predict phat

diagtab phat low, cutoff(0.4) auc ///
    xlsx(diagtab.xlsx) ///
    title("Diagnostic Accuracy: Low Birth Weight Prediction")
```

## Persistent Defaults

Use either explicit keys or a named theme, depending on how much control you want over the workbook style.

```stata
tabtools set theme lancet
tabtools set digits 2
tabtools get

tabtools set clear
```

## Resources

- `help tabtools` for the suite overview and persistent defaults
- `help tabtools_cheatsheet` for compact option patterns across commands
- `help tabtools_cookbook` for longer end-to-end recipes
- `help table1_tc`, `help regtab`, `help effecttab`, `help comptab`, `help hrcomptab`, `help survtab`, `help stratetab`, `help crosstab`, `help corrtab`, and `help diagtab` for command-specific syntax

## Version History

- **1.0.7** (2026-04-18): Current Stata-Tools suite release covering direct descriptive tables, `collect`-based model formatters, file-based rate workflows, and frame-based composite builders.

## Author

Timothy P Copeland, Karolinska Institutet
