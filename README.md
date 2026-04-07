# Stata-Tools

[<img align="left" alt="GitHub" width="25px" src="https://cdn.simpleicons.org/github" />](https://github.com/tpcopeland/Stata-Tools)
[<img align="left" alt="Google Scholar" width="25px" src="https://cdn.simpleicons.org/googlescholar" />](https://scholar.google.com/citations?user=oWGGVpYAAAAJ)

<br />

---

Production distribution repository for Stata packages (21 packages). All packages require Stata 16+, except where noted. Install any package directly from here using `net install`.

## Installation

```stata
* Install a single package
net install <package>, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/<package>")

* Example
net install tvtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools")

* After installation, view help
help <command>
```

To update an already-installed package:

```stata
ado uninstall <package>
net install <package>, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/<package>")
```

## Packages

### Data Management

| Package | Version | Updated | Description |
| --- | --- | --- | --- |
| [codescan](https://github.com/tpcopeland/Stata-Tools/tree/main/codescan) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Scan wide-format code variables for pattern matches |
| [compress_tc](https://github.com/tpcopeland/Stata-Tools/tree/main/compress_tc) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Two-stage string compression via strL |
| [datamap](https://github.com/tpcopeland/Stata-Tools/tree/main/datamap) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Privacy-safe dataset documentation and Markdown data dictionaries |
| [datefix](https://github.com/tpcopeland/Stata-Tools/tree/main/datefix) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Convert inconsistent date strings to Stata dates |
| [massdesas](https://github.com/tpcopeland/Stata-Tools/tree/main/massdesas) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Batch convert SAS datasets to Stata |
| [pkgtransfer](https://github.com/tpcopeland/Stata-Tools/tree/main/pkgtransfer) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Transfer installed packages between systems via .do or .zip |

### Analysis

| Package | Version | Updated | Description |
| --- | --- | --- | --- |
| [cstat_surv](https://github.com/tpcopeland/Stata-Tools/tree/main/cstat_surv) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | C-statistic for Cox survival models |
| [finegray](https://github.com/tpcopeland/Stata-Tools/tree/main/finegray) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Fast Fine-Gray competing risks regression |
| [gcomp](https://github.com/tpcopeland/Stata-Tools/tree/main/gcomp) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | G-computation formula via Monte Carlo simulation (includes gcomptab) |
| [iivw](https://github.com/tpcopeland/Stata-Tools/tree/main/iivw) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Inverse intensity of visit weighting (IIW, IPTW, FIPTIW) for irregular longitudinal data |
| [msm](https://github.com/tpcopeland/Stata-Tools/tree/main/msm) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Marginal structural models via IPTW for time-varying treatments |
| [mvp](https://github.com/tpcopeland/Stata-Tools/tree/main/mvp) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Missing value pattern analysis with visualizations |

### Time-Varying Data & Registries

| Package | Version | Updated | Description |
| --- | --- | --- | --- |
| [setools](https://github.com/tpcopeland/Stata-Tools/tree/main/setools) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Swedish registry toolkit (ICD expansion, migrations, MS progression, etc.) |
| [tvtools](https://github.com/tpcopeland/Stata-Tools/tree/main/tvtools) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Time-varying exposure data pipeline |

### Reporting & Visualization

| Package | Version | Updated | Description |
| --- | --- | --- | --- |
| [consort](https://github.com/tpcopeland/Stata-Tools/tree/main/consort) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | CONSORT-style exclusion flowcharts (requires Python 3.7+) |
| [eplot](https://github.com/tpcopeland/Stata-Tools/tree/main/eplot) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Forest plots and coefficient plots from estimates or data |
| [kmplot](https://github.com/tpcopeland/Stata-Tools/tree/main/kmplot) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Publication-ready Kaplan-Meier survival curves with risk tables, CI bands, and median lines |
| [raincloud](https://github.com/tpcopeland/Stata-Tools/tree/main/raincloud) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Raincloud plots: density, scatter, and box elements |
| [spaghetti](https://github.com/tpcopeland/Stata-Tools/tree/main/spaghetti) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Longitudinal trajectory plots with group mean overlays |
| [tabtools](https://github.com/tpcopeland/Stata-Tools/tree/main/tabtools) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Publication-ready Excel tables (table1_tc, regtab, effecttab, stratetab, tablex) |
| [tc_schemes](https://github.com/tpcopeland/Stata-Tools/tree/main/tc_schemes) | ![version](https://img.shields.io/badge/version-1.0.0-blue) | ![updated](https://img.shields.io/badge/updated-2026--04--08-brightgreen) | Graph schemes from blindschemes and schemepack |

## Example Data

The `_data/` directory contains **fully synthetic** datasets modeling an SSRI vs SNRI antidepressant study in Swedish registry style (2006-2023). No real patient data is included. These datasets are used in package examples and help files.

```stata
* Load example data directly from the repo
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear
```

| File | Description |
| --- | --- |
| `cohort.dta` | Study population with demographics and dates |
| `prescriptions.dta` | Drug dispensing records (ATC codes) |
| `diagnoses.dta` | Hospital diagnoses (ICD-10 codes) |
| `procedures.dta` | Surgical/medical procedures (KVA codes) |
| `outcomes.dta` | Pre-computed outcome event dates |
| `lisa.dta` | Longitudinal socioeconomic data (panel) |
| `migrations.dta` | Migration records |
| `migrations_wide.dta` | Migration records (wide format) |
| `calendar.dta` | Calendar-time factors (monthly) |
| `cci.dta` | Charlson comorbidity index data |
| `comorbidities.dta` | Comorbidity records |
| `relapses.dta` | MS clinical events (EDSS scores) |
| `relapses_only.dta` | MS relapses subset |
| `treatment.dta` | Treatment assignment data |
| `tv_antidep.dta` | Time-varying antidepressant exposure |
| `tv_antidep_episodes.dta` | Antidepressant treatment episodes |
| `tv_benzo_episodes.dta` | Benzodiazepine treatment episodes |
| `tv_events.dta` | Time-varying event data |
| `tv_merged.dta` | Merged time-varying dataset |

## Author

Timothy P Copeland
Department of Clinical Neuroscience, Karolinska Institutet

## License

MIT
