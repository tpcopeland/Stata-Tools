# Stata-Tools

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-1a5f91) ![License: MIT](https://img.shields.io/badge/license-MIT-blue)

Stata packages for epidemiology and registry research: building cohorts from coded records, time-varying exposures, causal inference, survival and competing risks, and publication-ready tables and figures.

A typical pipeline: `codescan` / `comorbidity` → `tvtools` → `msm` · `finegray` · `gcomp` → `psdash` → `tabtools` · `eplot` · `kmplot` → `logdoc`

## Install

```stata
capture ado uninstall tvtools
net install tvtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools") replace
help tvtools
```

Swap `tvtools` for any package below. Run the same lines again to update, or `ado update, update` to update everything installed this way. Keep the `ado uninstall` line: if an older copy came from SSC or elsewhere, `net install` registers a second copy beside it instead of replacing it.

Each package folder has a README with worked examples; `help <package>` has the full reference.

## Packages

### Data preparation

| Package | What it does | Version | Updated |
| --- | --- | --- | --- |
| [asof](asof) | Attach one measurement per ID and anchor date ("as-of" join), with explicit direction, selection, tie, and window rules | ![version](https://img.shields.io/badge/version-0.1.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--30-brightgreen) |
| [codescan](codescan) | Flag, count, and summarize diagnosis, procedure, and drug codes across wide code fields, by regex or prefix, within time windows | ![version](https://img.shields.io/badge/version-4.2.3-blue) | ![updated](https://img.shields.io/badge/updated-2026--09--09-brightgreen) |
| [compress_tc](compress_tc) | Shrink string-heavy datasets: strL conversion, then `compress` | ![version](https://img.shields.io/badge/version-1.1.1-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--05-brightgreen) |
| [datamap](datamap) | Document data without exposing it: privacy-safe maps and Markdown dictionaries (`datamap`, `datadict`), QC gates (`datacheck`), missing-value patterns (`datamvp`) | ![version](https://img.shields.io/badge/version-1.6.8-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--30-brightgreen) |
| [datefix](datefix) | Convert imported date strings to Stata dates, detecting day/month order and reporting values that fail | ![version](https://img.shields.io/badge/version-1.1.2-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--11-brightgreen) |
| [fvgen](fvgen) | Turn factor-variable interactions into labeled main-effect and product variables for clean regression export | ![version](https://img.shields.io/badge/version-1.2.5-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--30-brightgreen) |
| [massdesas](massdesas) | Convert every `.sas7bdat` in a directory tree to `.dta` | ![version](https://img.shields.io/badge/version-1.0.2-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--05-brightgreen) |
| [pkgtransfer](pkgtransfer) | Move your installed packages to another machine, by online reinstall or offline ZIP | ![version](https://img.shields.io/badge/version-1.1.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--16-brightgreen) |
| [rangematch](rangematch) | Range join: match records whose key falls in, or whose interval overlaps, each master interval (file or frame) | ![version](https://img.shields.io/badge/version-1.5.6-blue) | ![updated](https://img.shields.io/badge/updated-2026--09--09-brightgreen) |

### Cohorts, registries, and time-varying data

| Package | What it does | Version | Updated |
| --- | --- | --- | --- |
| [comorbidity](comorbidity) | Charlson, Elixhauser, or custom scores from wide ICD-10 fields, with hierarchy rules and component indicators | ![version](https://img.shields.io/badge/version-1.0.1-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--30-brightgreen) |
| [pygrid](pygrid) | Person-period denominator grids with zero-filled event attachment (`pygrid`, `pyattach`) | ![version](https://img.shields.io/badge/version-1.0.1-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--30-brightgreen) |
| [setools](setools) | Swedish registry tools: Swedish Charlson index, ICD-7 to ICD-10 (`cci_se`), migration exclusions and censoring (`migrations`), MS progression endpoints (`sustainedss`, `cdp`, `pira`) | ![version](https://img.shields.io/badge/version-1.5.7-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--30-brightgreen) |
| [tvtools](tvtools) | Time-varying exposure datasets for survival analysis: exposure episodes (`tvexpose`), merges (`tvmerge`), events (`tvevent`), IPTW/IPCW weights (`tvweight`), age bands, and diagnostics | ![version](https://img.shields.io/badge/version-1.17.2-blue) | ![updated](https://img.shields.io/badge/updated-2026--09--09-brightgreen) |

### Causal inference and survival

| Package | What it does | Version | Updated |
| --- | --- | --- | --- |
| [cstat_surv](cstat_surv) | Harrell's C after `stcox`, with a leave-one-out jackknife SE and CI | ![version](https://img.shields.io/badge/version-1.0.1-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--05-brightgreen) |
| [finegray](finegray) | Fast Fine-Gray competing-risks regression, with prediction, cumulative incidence, and a proportional subdistribution hazards diagnostic | ![version](https://img.shields.io/badge/version-1.3.7-blue) | ![updated](https://img.shields.io/badge/updated-2026--09--23-brightgreen) |
| [gcomp](gcomp) | Parametric g-computation for time-varying confounding and mediation; `gcomptab` tabulates the results | ![version](https://img.shields.io/badge/version-2.0.1-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--28-brightgreen) |
| [iivw](iivw) | Inverse-intensity (IIW), IPTW, and combined FIPTIW weighting for irregularly timed visits, with diagnostics for informative visit processes | ![version](https://img.shields.io/badge/version-4.2.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--09--15-brightgreen) |
| [msm](msm) | Marginal structural models with IPTW, end to end: prepare, weight, diagnose, fit, predict, sensitivity analysis, report | ![version](https://img.shields.io/badge/version-1.4.8-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--30-brightgreen) |
| [psdash](psdash) | Propensity score diagnostics: overlap, balance (SMD, Love plot), weight distribution, common support; after `teffects`, `logit`/`probit`, `msm`, and more | ![version](https://img.shields.io/badge/version-1.7.2-blue) | ![updated](https://img.shields.io/badge/updated-2026--09--09-brightgreen) |
| [qba](qba) | Quantitative bias analysis for misclassification, selection bias, and unmeasured confounding: simple or probabilistic, chainable, plotted | ![version](https://img.shields.io/badge/version-1.1.3-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--10-brightgreen) |

### Tables and reporting

| Package | What it does | Version | Updated |
| --- | --- | --- | --- |
| [consort](consort) | CONSORT-style exclusion flowcharts, recorded as you drop observations | ![version](https://img.shields.io/badge/version-1.1.1-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--05-brightgreen) |
| [diagtab](diagtab) | Diagnostic accuracy with CIs, ROC AUC, and cutoff analysis; console, Excel, CSV, Markdown, or frame output | ![version](https://img.shields.io/badge/version-2.0.1-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--30-brightgreen) |
| [logdoc](logdoc) | Turn `.smcl`, `.log`, or `.do` files into HTML, Markdown, Quarto, Word, LaTeX, or PDF | ![version](https://img.shields.io/badge/version-1.1.7-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--30-brightgreen) |
| [simtab](simtab) | Monte Carlo simulation performance metrics with MCSEs, as publication-ready tables | ![version](https://img.shields.io/badge/version-2.0.1-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--30-brightgreen) |
| [tabtools](tabtools) | Manuscript tables to Excel and Markdown: Table 1 (`table1_tc`), regression (`regtab`), treatment effects (`effecttab`), survival (`survtab`), and more | ![version](https://img.shields.io/badge/version-2.1.7-blue) | ![updated](https://img.shields.io/badge/updated-2026--09--16-brightgreen) |

### Graphics

| Package | What it does | Version | Updated |
| --- | --- | --- | --- |
| [eplot](eplot) | Forest and coefficient plots from variables, stored estimates, matrices, or frames | ![version](https://img.shields.io/badge/version-1.4.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--09--07-brightgreen) |
| [kmplot](kmplot) | Kaplan-Meier and cumulative-failure curves with CIs, risk tables, landmarks, medians, and censor marks | ![version](https://img.shields.io/badge/version-1.3.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--21-brightgreen) |
| [raincloud](raincloud) | Raincloud plots: density, raw points, and box summary in one figure | ![version](https://img.shields.io/badge/version-1.0.3-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--11-brightgreen) |
| [spaghetti](spaghetti) | Individual trajectories over time, with optional group means and CIs | ![version](https://img.shields.io/badge/version-1.0.1-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--05-brightgreen) |
| [swimlane](swimlane) | Swimmer and state swimlane plots for patient timelines | ![version](https://img.shields.io/badge/version-0.1.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--06--29-brightgreen) |
| [tc_schemes](tc_schemes) | 45 graph schemes (blindschemes, schemepack, cleanplots, modern, and originals) behind one command | ![version](https://img.shields.io/badge/version-1.1.1-blue) | ![updated](https://img.shields.io/badge/updated-2026--08--05-brightgreen) |

## Requirements beyond Stata 16

| Package | Needs |
| --- | --- |
| diagtab, simtab, tabtools | Stata 17+ |
| iivw | Stata 17+ for mixed-effects outcome models only |
| rangematch | Stata 16.1+ |
| massdesas | Stata 14+, plus `ssc install filelist` and `ssc install fs` |
| comorbidity | `codescan` from this repo |
| tabtools | `eplot` from this repo, for forest plots (optional) |
| consort | Python 3.7+ with matplotlib, to draw the diagram |
| logdoc | Python 3.6+ (standard library only); Stata 17+ for Word; `xhtml2pdf` or `wkhtmltopdf` for PDF |

## Example data

[`_data/`](_data) holds 19 fully synthetic datasets (no real patients) simulating a Swedish-registry cohort of SSRI and SNRI antidepressant starters. Load any of them straight from GitHub to try a command on realistic data:

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear
```

## Contact

Found a bug or have a request? [Open an issue](https://github.com/tpcopeland/Stata-Tools/issues).

Timothy P Copeland, Karolinska Institutet · [MIT License](LICENSE)
