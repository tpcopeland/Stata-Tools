# Stata-Tools

---

Production distribution repository for Stata packages (25 packages). All packages require Stata 16+, except where noted. Install any package directly from here using `net install`.

## Installation

```stata
* Install a single package
capture ado uninstall <package>
net install <package>, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/<package>") replace

* Example
capture ado uninstall tvtools
net install tvtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools") replace

* After installation, view help
help <command>
```

To update an already-installed package:

```stata
capture ado uninstall <package>
net install <package>, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/<package>") replace
```

## Packages

### Data Management

| Package | Version | Updated | Description |
| --- | --- | --- | --- |
| [codescan](https://github.com/tpcopeland/Stata-Tools/tree/main/codescan) | ![version](https://img.shields.io/badge/version-2.0.9-blue) | ![updated](https://img.shields.io/badge/updated-2026--07--09-brightgreen) | Scan wide-format diagnosis, procedure, and medication code fields with indicator, count, and summary outputs |
| [compress_tc](https://github.com/tpcopeland/Stata-Tools/tree/main/compress_tc) | ![version](https://img.shields.io/badge/version-1.1.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--06--19-brightgreen) | Two-stage compression for string-heavy Stata data via strL and compress |
| [datamap](https://github.com/tpcopeland/Stata-Tools/tree/main/datamap) | ![version](https://img.shields.io/badge/version-1.5.3-blue) | ![updated](https://img.shields.io/badge/updated-2026--07--10-brightgreen) | Privacy-safe dataset maps, Markdown dictionaries, console QC/expectation gates (datacheck), and missing-value pattern analysis (datamvp) |
| [datefix](https://github.com/tpcopeland/Stata-Tools/tree/main/datefix) | ![version](https://img.shields.io/badge/version-1.1.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--06--25-brightgreen) | Convert imported date strings to Stata daily dates |
| [fvgen](https://github.com/tpcopeland/Stata-Tools/tree/main/fvgen) | ![version](https://img.shields.io/badge/version-1.2.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--06--30-brightgreen) | Flatten factor-variable interactions into labeled main and product variables for clean regression export |
| [massdesas](https://github.com/tpcopeland/Stata-Tools/tree/main/massdesas) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Batch convert SAS datasets to Stata (Stata 14+; requires import sas, filelist, and fs) |
| [pkgtransfer](https://github.com/tpcopeland/Stata-Tools/tree/main/pkgtransfer) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Transfer installed package sets between systems via online reinstall or offline ZIP |
| [rangematch](https://github.com/tpcopeland/Stata-Tools/tree/main/rangematch) | ![version](https://img.shields.io/badge/version-1.3.3-blue) | ![updated](https://img.shields.io/badge/updated-2026--07--09-brightgreen) | Range join between master and using datasets (file or frame) via a Mata binary-search backend (Stata 16.1+) |

### Analysis

| Package | Version | Updated | Description |
| --- | --- | --- | --- |
| [cstat_surv](https://github.com/tpcopeland/Stata-Tools/tree/main/cstat_surv) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Post-stcox Harrell's C-statistic with infinitesimal-jackknife SEs and confidence intervals |
| [finegray](https://github.com/tpcopeland/Stata-Tools/tree/main/finegray) | ![version](https://img.shields.io/badge/version-1.1.3-blue) | ![updated](https://img.shields.io/badge/updated-2026--07--10-brightgreen) | Fast Fine-Gray competing risks regression with prediction and proportional-hazards diagnostics |
| [gcomp](https://github.com/tpcopeland/Stata-Tools/tree/main/gcomp) | ![version](https://img.shields.io/badge/version-1.4.3-blue) | ![updated](https://img.shields.io/badge/updated-2026--07--04-brightgreen) | Parametric g-computation for mediation and time-varying confounding (includes gcomptab) |
| [iivw](https://github.com/tpcopeland/Stata-Tools/tree/main/iivw) | ![version](https://img.shields.io/badge/version-1.9.4-blue) | ![updated](https://img.shields.io/badge/updated-2026--07--09-brightgreen) | Inverse intensity/visit weighting for irregular longitudinal data (Stata 17+ for mixed models) |
| [msm](https://github.com/tpcopeland/Stata-Tools/tree/main/msm) | ![version](https://img.shields.io/badge/version-1.2.3-blue) | ![updated](https://img.shields.io/badge/updated-2026--07--04-brightgreen) | Marginal structural models for longitudinal causal analysis with IPTW, diagnostics, prediction, plots, and reports |
| [psdash](https://github.com/tpcopeland/Stata-Tools/tree/main/psdash) | ![version](https://img.shields.io/badge/version-1.4.1-blue) | ![updated](https://img.shields.io/badge/updated-2026--07--07-brightgreen) | Propensity score diagnostics dashboard: overlap, balance, weight distribution, and common support |
| [qba](https://github.com/tpcopeland/Stata-Tools/tree/main/qba) | ![version](https://img.shields.io/badge/version-1.0.1-blue) | ![updated](https://img.shields.io/badge/updated-2026--06--19-brightgreen) | Quantitative bias analysis for misclassification, selection bias, and unmeasured confounding, with multi-bias chains and visualization (simple and probabilistic) |

### Time-Varying Data & Registries

| Package | Version | Updated | Description |
| --- | --- | --- | --- |
| [setools](https://github.com/tpcopeland/Stata-Tools/tree/main/setools) | ![version](https://img.shields.io/badge/version-1.4.1-blue) | ![updated](https://img.shields.io/badge/updated-2026--07--03-brightgreen) | Swedish registry tools for Charlson scoring, procedure-code matching, migrations, and MS progression endpoints |
| [tvtools](https://github.com/tpcopeland/Stata-Tools/tree/main/tvtools) | ![version](https://img.shields.io/badge/version-1.6.8-blue) | ![updated](https://img.shields.io/badge/updated-2026--07--03-brightgreen) | Time-varying exposure workflow for survival analysis, diagnostics, IPTW/IPCW weights, and age-band intervals |

### Reporting & Visualization

| Package | Version | Updated | Description |
| --- | --- | --- | --- |
| [consort](https://github.com/tpcopeland/Stata-Tools/tree/main/consort) | ![version](https://img.shields.io/badge/version-1.1.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--06--24-brightgreen) | CONSORT-style exclusion flowcharts with bundled Python/matplotlib rendering |
| [eplot](https://github.com/tpcopeland/Stata-Tools/tree/main/eplot) | ![version](https://img.shields.io/badge/version-1.2.4-blue) | ![updated](https://img.shields.io/badge/updated-2026--07--06-brightgreen) | Unified effect plotting from variables, stored estimates, matrices, or graph-ready frames |
| [logdoc](https://github.com/tpcopeland/Stata-Tools/tree/main/logdoc) | ![version](https://img.shields.io/badge/version-1.1.2-blue) | ![updated](https://img.shields.io/badge/updated-2026--07--09-brightgreen) | Convert Stata SMCL/log files to faithful HTML, Markdown, Word, LaTeX, Quarto, or PDF documents (requires Python 3.6+) |
| [kmplot](https://github.com/tpcopeland/Stata-Tools/tree/main/kmplot) | ![version](https://img.shields.io/badge/version-1.2.1-blue) | ![updated](https://img.shields.io/badge/updated-2026--06--26-brightgreen) | Publication-ready Kaplan-Meier and cumulative failure curves with CI, risk tables, landmarks, saved data, median lines, and censor marks |
| [raincloud](https://github.com/tpcopeland/Stata-Tools/tree/main/raincloud) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Raincloud plots combining density, raw points, and box summaries |
| [spaghetti](https://github.com/tpcopeland/Stata-Tools/tree/main/spaghetti) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Long-format longitudinal trajectory plots with optional group mean and CI overlays |
| [tabtools](https://github.com/tpcopeland/Stata-Tools/tree/main/tabtools) | ![version](https://img.shields.io/badge/version-1.9.5-blue) | ![updated](https://img.shields.io/badge/updated-2026--07--09-brightgreen) | Excel-ready manuscript tables with optional eplot forest-plot companions for regression, treatment-effect, composite, and survival workflows (Stata 17+ for most commands) |
| [tc_schemes](https://github.com/tpcopeland/Stata-Tools/tree/main/tc_schemes) | ![version](https://img.shields.io/badge/version-1.1.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--06--28-brightgreen) | Manage 45 bundled graph schemes (blindschemes, schemepack, cleanplots, modern, originals) from one command |

## Example Data

The `_data/` directory contains 19 **fully synthetic** `.dta` datasets used as shared example data across packages. No real patient data is included. The datasets simulate a pharmacoepidemiology cohort study comparing SSRI and SNRI antidepressant initiators in a Swedish registry setting.

```stata
* Load example data directly from the repo
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear
```

| File | Description |
| --- | --- |
| `cohort.dta` | Main cohort spine: one row per patient with entry/exit dates and treatment |
| `prescriptions.dta` | Long-format prescription records |
| `diagnoses.dta` | Long-format diagnosis history (ICD codes, dates) |
| `procedures.dta` | Long-format procedure records |
| `outcomes.dta` | Outcome events: dates and types |
| `lisa.dta` | Socioeconomic register data (education, income, employment) |
| `migrations.dta` | Long-format migration/residence history |
| `migrations_wide.dta` | Wide-format version of migration data |
| `calendar.dta` | Calendar-time covariates and period indicators |
| `cci.dta` | Charlson Comorbidity Index scores |
| `comorbidities.dta` | Wide-format comorbidity flags at cohort entry |
| `relapses.dta` | Relapse/recurrence event records |
| `relapses_only.dta` | Relapse records filtered to index events only |
| `treatment.dta` | Treatment assignment and exposure periods |
| `tv_antidep.dta` | Time-varying antidepressant exposure in episode format |
| `tv_antidep_episodes.dta` | Antidepressant episodes with switch/augmentation flags |
| `tv_benzo_episodes.dta` | Benzodiazepine co-prescription episodes |
| `tv_events.dta` | Time-varying event records for outcome analysis |
| `tv_merged.dta` | Pre-merged time-varying dataset for tvtools examples |

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
