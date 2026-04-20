# tabtools - Publication-ready Excel tables from Stata workflows

**Version 1.0.7** | 2026-04-18

`tabtools` is a suite of Stata commands for exporting publication-ready tables to Excel with a consistent formatting language across descriptive tables, regression results, treatment effects, survival summaries, incidence rates, diagnostic accuracy, and composite manuscript tables. The package is built for real analysis workflows: fit or summarize in Stata, export directly to Excel, and keep the same title, borders, fonts, p-value styling, and sheet layout across the whole workbook.

The package includes a ready-made demo workbook in [demo/demo_tabtools.xlsx](demo/demo_tabtools.xlsx) and a rebuild script in [demo/demo_tabtools.do](demo/demo_tabtools.do).

## Requirements

- Stata 16 or later for `tabtools` and `table1_tc`
- Stata 17 or later for `regtab`, `effecttab`, `comptab`, `hrcomptab`, `survtab`, `crosstab`, `diagtab`, `corrtab`, and `stratetab`
- `collect`-based workflows use Stata's built-in `collect` framework

## Installation

```stata
capture ado uninstall tabtools
net install tabtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tabtools") replace
```

## Commands

### Descriptive and exploratory tables

| Command | Description | Stata |
|---------|-------------|-------|
| `table1_tc` | Table 1 generator with automatic tests, SMDs, weighting support, and Excel export | 16+ |
| `crosstab` | Cross-tabulation with association measures such as OR, RR, and risk difference | 17+ |
| `corrtab` | Correlation matrix with significance stars and lower, upper, or full layout options | 17+ |

### Model and effect tables

| Command | Description | Stata |
|---------|-------------|-------|
| `regtab` | Format the current `collect` from regression models into a polished Excel table | 17+ |
| `effecttab` | Format `teffects` or `margins` results from the current `collect` | 17+ |
| `comptab` | Combine selected rows from one or more `regtab` or `effecttab` frames into one composite sheet | 17+ |
| `hrcomptab` | Build a final Table 2-style sheet by combining a `stratetab` frame with selected `regtab` rows | 17+ |

### Survival, rates, and diagnostics

| Command | Description | Stata |
|---------|-------------|-------|
| `survtab` | Survival summary table with Kaplan-Meier estimates, medians, RMST, and number at risk | 17+ |
| `stratetab` | Format saved `strate` output files into incidence-rate tables | 17+ |
| `diagtab` | Diagnostic-accuracy table with sensitivity, specificity, predictive values, likelihood ratios, and AUC | 17+ |

### Utility

| Command | Description | Stata |
|---------|-------------|-------|
| `tabtools` | Suite controller for browsing commands and setting persistent formatting defaults | 16+ |

## How It Works

- `table1_tc`, `crosstab`, `corrtab`, `survtab`, and `diagtab` work directly from the dataset in memory.
- `regtab` and `effecttab` are post-`collect` formatters. You fit or estimate first, then `tabtools` turns the current `collect` into an Excel sheet.
- `stratetab` is different: it reads saved `strate, output()` files, so a dataset does not need to be in memory at the moment you format the final table.
- `comptab` and `hrcomptab` are second-stage builders. They combine frames created earlier in the workflow into composite manuscript tables.
- `tabtools set` and `tabtools get` let you set workbook-wide defaults once per session so every command shares the same formatting.

## Worked Examples

### 1. Build a Table 1 with `sysuse auto`

This is the simplest direct-to-Excel workflow. `foreign` is the grouping variable, and `smd` adds standardized mean differences to the same output table.

```stata
sysuse auto, clear
table1_tc, by(foreign) ///
    vars(price contn \ mpg contn \ weight contn \ rep78 cat) ///
    xlsx(table1.xlsx) sheet("Table 1") ///
    title("Table 1. Vehicle Characteristics by Origin") ///
    smd boldp(0.05) zebra
```

### 2. Format a regression table after `collect`

`regtab` does not refit the model. It reads the current `collect`, applies the right coefficient label automatically, and writes a formatted table.

```stata
sysuse auto, clear
generate byte expensive = (price > 6000)

collect clear
collect: logistic expensive mpg weight i.foreign
regtab, xlsx(regression.xlsx) sheet("Logistic") ///
    title("Table 2. Predictors of High Price") ///
    noint boldp(0.05) zebra
```

### 3. Format treatment effects from `teffects`

This is the canonical `effecttab` workflow. Estimate first, then export the active `collect`.

```stata
webuse cattaneo2, clear

collect clear
collect: teffects ipw (bweight) ///
    (mbsmoke mage medu mmarried fbaby), ate
effecttab, xlsx(effects.xlsx) sheet("ATE") ///
    effect("ATE") ///
    title("Average Treatment Effect on Birthweight") ///
    clean
```

### 4. Combine multiple model frames into one composite table

`comptab` is the bridge from separate model sheets to a single manuscript table. The source frames usually come from earlier `regtab` or `effecttab` runs.

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

### 5. Cross-tabulation and correlation tables on built-in data

The direct descriptive commands work from the dataset in memory and do not require `collect`.

```stata
webuse nhanes2, clear
crosstab diabetes highbp, xlsx(crosstab.xlsx) ///
    title("Diabetes by Hypertension")

sysuse auto, clear
corrtab price mpg weight length, xlsx(corrtab.xlsx) ///
    lower title("Correlation Matrix")
```

### 6. Survival summaries and incidence-rate tables

`survtab` runs after `stset`. `stratetab` formats the saved files produced by `strate`.

```stata
webuse drugtr, clear
stset studytime, failure(died)
survtab, times(5 10 15 20) by(drug) ///
    median rmst(20) ///
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

### 7. Diagnostic accuracy from a built-in dataset

`diagtab` takes a binary test and a binary reference standard and formats the usual diagnostic measures into one sheet.

```stata
webuse nhanes2, clear
generate byte bmi_high = (bmi >= 30) if !missing(bmi)

diagtab bmi_high diabetes, xlsx(diagtab.xlsx) ///
    title("Diagnostic Accuracy: Obesity as Predictor of Diabetes")
```

## Persistent Defaults

Use `tabtools set` when you want every subsequent export in the session to share the same font, size, border style, or theme.

```stata
tabtools set font Calibri
tabtools set fontsize 11
tabtools set borderstyle academic
tabtools set theme lancet
tabtools get
```

Reset back to command defaults with:

```stata
tabtools set clear
```

## Workflow Notes

- `table1_tc` is the only table-building command in the suite that also supports Stata 16.
- `regtab`, `effecttab`, and `table1_tc` can be used for console preview workflows when you omit `xlsx()` and just want to inspect the formatted result first.
- `hrcomptab` is the advanced second-stage Table 2 builder for project-specific survival/rate pipelines. See `help hrcomptab` and `help tabtools_cookbook` for the full multi-frame workflow.
- `table1_tc` is derived from Mark Chatfield's `table1_mc` version 3.5, with package-specific enhancements and integration into the wider `tabtools` formatting system.

## Resources

Use built-in help for command-specific syntax and options:

```stata
help tabtools
help table1_tc
help regtab
help effecttab
help comptab
help hrcomptab
help crosstab
help corrtab
help survtab
help stratetab
help diagtab
help tabtools_cheatsheet
help tabtools_cookbook
```

## Version History

- **1.0.7** (2026-04-18): Current Stata-Tools release with the streamlined command set and synchronized package-facing documentation.

## Author

Timothy P Copeland, Karolinska Institutet
