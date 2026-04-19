# tabtools

![Stata 17+*](https://img.shields.io/badge/Stata-17%2B*-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Version 1.0.7](https://img.shields.io/badge/Version-1.0.7-blue)

A comprehensive suite of Stata commands for exporting publication-ready tables to Excel. Designed for epidemiological and clinical research workflows, tabtools handles descriptive statistics, regression results, treatment effects, survival analysis, diagnostic accuracy, incidence rates, and composite manuscript tables with consistent professional formatting. Most commands require Stata 17; `tabtools` and `table1_tc` also support Stata 16. `table1_tc` is derived from `table1_mc` version 3.5 (2024-12-19) by Mark Chatfield, with selected option changes while keeping the core workflow familiar. See [demo_tabtools.xlsx](https://github.com/tpcopeland/Stata-Tools/raw/refs/heads/main/tabtools/demo/demo_tabtools.xlsx) for examples of the various commands. [demo_tabtools.do](https://github.com/tpcopeland/Stata-Tools/raw/refs/heads/main/tabtools/demo/demo_tabtools.do) rebuilds that workbook from repository data and sibling packages.

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
| `hrcomptab` | Compose a final Table 2-style sheet by combining a `stratetab` frame with selected rows from one or more `regtab` frames | 17+ |

### Clinical

| Command | Description | Stata |
|---------|-------------|-------|
| `survtab` | Survival summary table with Kaplan-Meier estimates, median survival, RMST, number at risk, and cumulative incidence | 17+ |
| `stratetab` | Combine and format `strate` incidence rate outputs with optional rate ratios and log-normal CIs | 17+ |
| `diagtab` | Diagnostic accuracy table (sensitivity, specificity, PPV, NPV, LR+, LR-, DOR, AUC) from a 2x2 classification | 17+ |

### Utility

| Command | Description | Stata |
|---------|-------------|-------|
| `tabtools` | Suite controller: persistent formatting defaults (`set`/`get`) and command listing | 16+ |

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

### Incidence Rates

`stratetab` reads the saved `strate` output files directly, so no dataset needs to be in memory before you run it.

```stata
* After running strate commands and saving results:
stratetab, using(rate_control rate_treated) xlsx("rates.xlsx") ///
    outcomes(2) outlabels("Primary Endpoint \ Secondary Endpoint") ///
    title("Incidence Rates per 1,000 Person-Years") ///
    rateratio ratiodigits(2)
```

### Table 2 Composite

```stata
* Step 1: build the descriptive scaffold
stratetab, using(edss4_tv edss6_tv recurring_tv ///
    edss4_dose edss6_dose recurring_dose) ///
    outcomes(3) frame(hrt_rates, replace) ///
    outlabels("Sustained EDSS 4" \ "Sustained EDSS 6" \ "Recurring Relapse") ///
    explabels("Binary HRT" \ "Estrogen Dose Category")

* Step 2: build adjusted model frames with regtab
collect clear
collect: stcox hrt_tv ...
collect: stcox hrt_tv ...
collect: stcox hrt_tv ...
regtab, frame(hrt_bin, replace) noint coef("HR")

collect clear
collect: stcox i.hrt_dosecat ...
collect: stcox i.hrt_dosecat ...
collect: stcox i.hrt_dosecat ...
regtab, frame(hrt_dose, replace) noint coef("HR")

* Step 3: compose the final Table 2 sheet
hrcomptab hrt_rates, modelframes(hrt_bin hrt_dose) ///
    rows(1 \ 3/5) effect("aHR") ///
    xlsx("HRT.xlsx") sheet("Table 2") ///
    title("Table 2. Hormone Replacement Therapy Events, Events per Person Year, and Adjusted Hazard Ratios")
```

### Diagnostic Accuracy

```stata
webuse nhanes2, clear
generate byte bmi_high = (bmi >= 30) if !missing(bmi)

diagtab bmi_high diabetes, xlsx("diagnostic.xlsx") ///
    wilson ///
    title("Diagnostic Accuracy: Obesity as Predictor of Diabetes")
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
- **Custom colors**: `headercolor()` and `zebracolor()` with named colors or RGB values
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
- **Returned results**: `r(Dapa)` local macro describing the table's data-presentation style for downstream methods text

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
help hrcomptab            * Table 2-style composite from stratetab + regtab frames
help crosstab             * cross-tabulation
help corrtab              * correlation matrix
help survtab              * survival summary
help stratetab            * incidence rates
help diagtab              * diagnostic accuracy
help tabtools_cheatsheet  * quick option reference
help tabtools_cookbook    * worked examples
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

MIT License. See the repository [LICENSE](../LICENSE) file for details.

## Version

Version 1.0.7, 2026-04-18

### Changelog

- **1.0.7** (2026-04-18)
  - Removed `fittab`, `hrtab`, and `tablex` from the package to reduce maintenance burden and concentrate the suite on the workflows actually in use.
  - Folded the `hrcomptab` demo directly into `demo_tabtools.do` and removed the one-off helper script.
  - Synchronized package metadata and package-facing documentation for the `1.0.7` release.
- **1.0.6** (2026-04-17)
  - Added `hrcomptab`, a second-stage Table 2 builder that uses a `stratetab` frame as the scaffold and injects selected rows from one or more `regtab` frames into compact effect/p-value columns. This replaces the ad hoc Excel import/merge/export workflow for rate + adjusted hazard-ratio tables.
  - Added dedicated QA for `hrcomptab`, covering row-based selection, rowname-based selection, frame output, and `.xlsx` export.
- **1.0.5** (2026-04-17)
  - Removed `subtitle()` from the export commands so layouts now start the header row directly after the title row.
  - `corrtab` and `diagtab` now stop on Excel-formatting failures instead of printing a misleading success message.
  - QA: `test_tabtools_issue_regressions.do` now `capture erase`s the `rate1-rate4.dta` tempfiles before exiting so subsequent test files' tempname allocations don't collide with leftovers; `run_all.do` also scrubs `/tmp/St${c(pid)}*.dta` between files as a belt-and-suspenders.
  - Standardized `_orig_varabbrev` local naming across the codebase.
  - Removed tracked developer debug logs (`qa/dbg_pois.log`, `qa/debug_hrtab.log`) from the working tree.
- **1.0.4** (2026-04-16)
  - Documentation and package-hygiene refresh: corrected stale examples in the README, cheatsheet, and cookbook; clarified that `r(Dapa)` is a returned local macro rather than a data frame; documented the supported cosmetic options in `corrtab`/`diagtab`; standardized stored-results anchors in the affected help files; qualified the `regtab` font remark; fixed the package-local license reference; and removed tracked debug scripts/logs from the package root.
- **1.0.3** (2026-04-13)
  - Documentation/abbreviation fixes: relax syntax minima so user-typed abbreviations match what the help files document. `subtitle`, `display`, and `borderstyle` now accept the shorter forms (`sub`, `dis`, `border`) that the synopsis lines advertised. Also `crosstab`'s `trend` (now `tr`), `survtab`'s `events` (now `ev`), and `stratetab`'s `ratiodigits` (now `ratio`).
  - `survtab` RMST: replace hard-coded auxiliary variable names (`_dt`, `_area`, `_n_at_risk`, `_d_count`, `_last_in_t`, `_n_risk_first`, `_tail_area`, `_gw_term`) with `tempvar`s so the RMST/Greenwood-variance pass can never collide with same-named columns in the user dataset.
  - `tabtools.ado`: add defensive `capture program drop _tabtools_detail` before the subprogram definition (matches the pattern used elsewhere in the package).
  - `diagtab` single-cutoff Excel formatting: track the measures-header row in a local instead of hard-coding `B6`, and start zebra striping at the first measure row (Sensitivity) rather than mid-confusion-matrix. The previous off-by-one shaded the Test− and measures-header rows; the new logic shades alternating measure rows only.
- **1.0.2** (2026-04-12)
  - `regtab`: ICC fixes for mixed/multilevel models (skip ICC for count models, multi-level fallback accumulator, melogit direct-variance fallback, BIC always collects N, all-missing primary path falls back).
