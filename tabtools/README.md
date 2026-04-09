# tabtools

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Version 1.0.1](https://img.shields.io/badge/Version-1.0.1-blue)

A comprehensive suite of Stata commands for exporting publication-ready tables to Excel. Designed for epidemiological and clinical research workflows, tabtools handles descriptive statistics, regression results, treatment effects, survival analysis, diagnostic accuracy, and general-purpose table export with consistent professional formatting. `table1_tc` is a fork of `table1_mc` version 3.5 (2024-12-19) by Mark Chatfield, though I have taken some liberties with removing and changing some existing options, the `table1_mc` options are generally intact. See [demo_tabtools.xlsx](https://github.com/tpcopeland/Stata-Tools/raw/refs/heads/main/tabtools/demo/demo_tabtools.xlsx) for examples of the various commands and [demo_tabtools.do](https://github.com/tpcopeland/Stata-Tools/raw/refs/heads/main/tabtools/demo/demo_tabtools.do) for the .do file that created it. 

## Installation

```stata
net install tabtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tabtools") replace
```

To update an existing installation:

```stata
ado uninstall tabtools
net install tabtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tabtools") replace
```

## Commands

### Descriptive

| Command | Description | Stata |
|---------|-------------|-------|
| `table1_tc` | Baseline characteristics table (Table 1) with automatic significance tests, IPTW weighting, and standardized mean differences | 16+ |
| `crosstab` | Cross-tabulation with association measures (OR, RR, RD), Chi-squared/Fisher's exact tests, and trend test | 17+ |
| `corrtab` | Correlation matrix with significance stars, Pearson or Spearman, lower/upper/full triangle export | 17+ |

### Regression

| Command | Description | Stata |
|---------|-------------|-------|
| `regtab` | Format regression results from any estimation command (`logit`, `stcox`, `regress`, `melogit`, etc.) with auto-detected coefficient labels (OR, HR, IRR, Coef.) | 17+ |
| `effecttab` | Format treatment effects (`teffects`) and marginal effects (`margins`) results | 17+ |
| `comptab` | Compose publication tables by selecting rows from multiple `regtab`/`effecttab` output frames into a single composite table | 17+ |

### Clinical

| Command | Description | Stata |
|---------|-------------|-------|
| `survtab` | Survival summary table with Kaplan-Meier estimates, median survival, RMST, number at risk, and cumulative incidence | 17+ |
| `hrtab` | Multi-panel hazard ratio table for stcox, stcrreg, and finegray with person-years and event counts | 17+ |
| `stratetab` | Combine and format `strate` incidence rate outputs with optional rate ratios and log-normal CIs | 17+ |
| `diagtab` | Diagnostic accuracy table (sensitivity, specificity, PPV, NPV, LR+, LR-, DOR, AUC) from a 2x2 classification | 17+ |
| `fittab` | Model comparison table with fit statistics (N, AIC, BIC, log-likelihood, C-statistic, R-squared) across stored estimates | 17+ |

### Utility

| Command | Description | Stata |
|---------|-------------|-------|
| `tablex` | General-purpose table export for any Stata `table`/`collect` output | 17+ |
| `tabtools` | Suite controller: persistent formatting defaults (`set`/`get`) and command listing | 17+ |

## Quick Examples

### Descriptive Statistics (Table 1)

```stata
webuse nhanes2, clear

table1_tc, by(diabetes) ///
    vars(age contn %5.1f \ female bin \ race cat \ ///
         bmi contn %5.1f \ highbp bin) ///
    excel("table1.xlsx") sheet("Baseline") ///
    title("Table 1. Baseline Characteristics by Diabetes Status") ///
    smd footnote("SMD = standardized mean difference") zebra
```

### Cross-Tabulation

```stata
webuse nhanes2, clear

crosstab diabetes highbp, xlsx("crosstab.xlsx") ///
    or colpct exact ///
    title("Cross-tabulation: Diabetes by Hypertension")
```

### Correlation Matrix

```stata
sysuse auto, clear

corrtab price mpg weight length, xlsx("correlations.xlsx") ///
    star(0.05 0.01 0.001) lower ///
    title("Correlation Matrix: Vehicle Characteristics")
```

### Regression Results

```stata
sysuse auto, clear

collect clear
collect: regress price mpg weight length i.foreign
regtab, xlsx("regression.xlsx") sheet("OLS") ///
    title("Table 2. Predictors of Vehicle Price") ///
    stats(r2) boldp(0.05)
```

### Logistic Regression

```stata
webuse nhanes2, clear

collect clear
collect: logit diabetes age female i.race bmi highbp
regtab, xlsx("logistic.xlsx") sheet("Model") ///
    title("Odds Ratios for Diabetes") ///
    noint boldp(0.05)
```

### Treatment Effects

```stata
webuse cattaneo2, clear

collect clear
collect: teffects ipw (bweight) (mbsmoke mage medu, logit), ate
effecttab, xlsx("effects.xlsx") sheet("ATE") ///
    title("ATE of Maternal Smoking on Birth Weight") ///
    effect("ATE") tlabels(0 "Non-smoker" 1 "Smoker")
```

### Composite Table

```stata
webuse nhanes2, clear

* Model 1: age and sex only
collect clear
collect: logit diabetes age female
regtab, xlsx("models.xlsx") sheet("M1") frame(m1) noint

* Model 2: add comorbidities
collect clear
collect: logit diabetes age female bmi highbp
regtab, xlsx("models.xlsx") sheet("M2") frame(m2) noint

* Combine selected rows
comptab m1 m2, rows(1/2 \ 1/4) ///
    xlsx("models.xlsx") sheet("Composite") ///
    section("Unadjusted" \ "Adjusted") ///
    title("Table 3. Logistic Regression Models") ///
    footnote("OR with 95% CI; bold p < 0.05") boldp(0.05)
```

### Survival Summary

```stata
webuse drugtr, clear

stset studytime, failure(died)

survtab, times(5 10 15 20) by(drug) ///
    median rmst(20) ///
    xlsx("survival.xlsx") sheet("KM") ///
    title("Table 4. Survival by Treatment Group") ///
    timeunit("months")
```

### Hazard Ratios

```stata
webuse drugtr, clear
gen id = _n

hrtab, exposure(i.drug) model(stcox) ///
    outcome(died) time(studytime) stsetopts(id(id)) ///
    covars(age) ///
    xlsx("hazard_ratios.xlsx") sheet("HR") ///
    title("Table 5. Hazard Ratios by Treatment Group") ///
    pvalue display
```

### Incidence Rates

```stata
* After running strate commands and saving results:
stratetab, using(rate_control rate_treated) xlsx("rates.xlsx") ///
    outcomes(2) outlabels("Primary Endpoint \ Secondary Endpoint") ///
    title("Incidence Rates per 1,000 Person-Years") ///
    rateratio ratiodigits(2)
```

### Diagnostic Accuracy

```stata
webuse nhanes2, clear
generate byte bmi_high = (bmi >= 30) if !missing(bmi)

diagtab bmi_high diabetes, xlsx("diagnostic.xlsx") ///
    wilson ///
    title("Diagnostic Accuracy: Obesity as Predictor of Diabetes")
```

### Model Comparison

```stata
sysuse auto, clear

regress price mpg weight
estimates store m1

regress price mpg weight length
estimates store m2

regress price mpg weight length i.foreign
estimates store m3

fittab m1 m2 m3, xlsx("fit.xlsx") ///
    stats(N aic bic r2) ///
    labels("Base" "Extended" "Full") ///
    title("Model Comparison: Vehicle Price") lrtest(m1)
```

### General Table Export

```stata
sysuse auto, clear

table (foreign) (), statistic(mean price mpg weight) ///
    statistic(sd price mpg weight)
tablex using "summary.xlsx", sheet("Summary") ///
    title("Summary Statistics by Origin")
```

### Console Preview

```stata
* Omit xlsx() to display results in the console only
sysuse auto, clear

collect clear
collect: regress price mpg weight i.foreign
regtab, boldp(0.05) stats(r2)
```

## Features

### Shared Formatting

All commands in the tabtools suite share a consistent set of formatting options:

- **Excel export** with automatic column widths calculated from content length
- **Professional borders** with customizable styles: `default`, `thin`, `medium`, `academic`
- **Journal themes**: `lancet`, `nejm`, `bmj`, `apa` with pre-configured formatting
- **Merged headers** for title rows and grouped model columns
- **Consistent fonts** with persistent defaults via `tabtools set font`/`tabtools set fontsize`
- **Conditional formatting**: bold p-values (`boldp`), row highlighting (`highlight`), alternating row shading (`zebra`)
- **Footnotes** in smaller italic font below the table
- **Custom colors**: `headercolor()` and `zebracolor()` with RGB values
- **CSV export** alongside or instead of Excel via `csv()`
- **Frame storage** via `frame()` for downstream programmatic access
- **Console preview** via `display` or by omitting `xlsx()`
- **Open after export** with the `open` option (cross-platform)

### Regression Features

- **Auto-detected coefficient labels**: `logit` -> OR, `stcox` -> HR, `poisson` -> IRR, `regress` -> Coef.
- **Median Odds Ratio / Median Hazard Ratio** transformation for multilevel models (`melogit`, `mestreg`)
- **R-squared and pseudo-R-squared** via `stats(r2)`
- **Custom significance thresholds** via `starslevels()`
- **Covariate filtering** with `keep()` and `drop()` options
- **Returned results**: `r(table)` matrix and `r(methods)` auto-generated methods text
- **CDISC formatting mode** for regulatory submissions (`cdisc` option)

### Table 1 Features

- **Automatic significance tests**: t-test, Wilcoxon, chi-squared, Fisher's exact
- **IPTW-weighted statistics** with `wt()` for pseudo-population tables
- **Standardized mean differences** column via `smd` with configurable threshold (`smdthreshold()`)
- **Variable type support**: continuous normal (`contn`), continuous non-normal (`conts`), binary (`bin`), categorical (`cat`)
- **Returned results**: `r(Dapa)` data frame for pipeline workflows

### Clinical Features

- **Survival summaries** with Kaplan-Meier estimates, median survival with CI, RMST, number at risk, and cumulative incidence
- **Diagnostic accuracy** with sensitivity, specificity, PPV, NPV, likelihood ratios, DOR, and AUC with optimal cutoff
- **Model comparison** across stored estimates with AIC, BIC, log-likelihood, C-statistic, and likelihood ratio tests
- **Incidence rate ratios** with log-normal 95% CI

## Persistent Defaults

Set formatting defaults that apply across all tabtools commands within a session:

```stata
tabtools set font Calibri
tabtools set fontsize 11
tabtools set borderstyle thin
tabtools set theme lancet
tabtools get                    * view current defaults
tabtools set clear              * reset to command defaults
```

Defaults persist for the current Stata session only. To make them permanent, add `tabtools set` commands to your `profile.do`:

```stata
* In ~/ado/profile.do or similar:
tabtools set font Calibri
tabtools set fontsize 10
tabtools set theme lancet
```

## Documentation

Each command has comprehensive built-in help:

```stata
help tabtools             * suite overview and settings
help table1_tc            * descriptive statistics (Table 1)
help regtab               * regression results
help effecttab            * treatment effects and margins
help comptab              * composite tables from frames
help crosstab             * cross-tabulation
help corrtab              * correlation matrix
help survtab              * survival summary
help hrtab                * hazard ratio tables
help stratetab            * incidence rates
help diagtab              * diagnostic accuracy
help fittab               * model comparison
help tablex               * general table export
```

## Citation

If you use tabtools in your research, please cite:

> Copeland TP (2026). tabtools: Publication-Ready Table Export Suite for Stata. Department of Clinical Neuroscience, Karolinska Institutet.

BibTeX:

```bibtex
@software{copeland2026tabtools,
    author    = {Copeland, Timothy P},
    title     = {tabtools: Publication-Ready Table Export Suite for Stata},
    year      = {2026},
    institution = {Karolinska Institutet},
    url       = {https://github.com/tpcopeland/Stata-Tools}
}
```

## Author

Timothy P Copeland
Department of Clinical Neuroscience
Karolinska Institutet
timothy.copeland@ki.se

## License

MIT License. See [LICENSE](LICENSE) for details.

## Version

Version 1.0.1, 2026-04-09
