# Stata-Tools

Production distribution repository for Stata packages (35 packages, 172+ commands). All packages require Stata 16+, except where noted. Install any package directly from here using `net install`.

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

| Package | Description | Stata |
|---------|-------------|-------|
| **codescan** | Scan wide-format code variables for pattern matches | 16+ |
| **compress_tc** | Two-stage string compression via strL | 16+ |
| **datamap** | Privacy-safe dataset documentation and Markdown data dictionaries | 16+ |
| **datefix** | Convert inconsistent date strings to Stata dates | 16+ |
| **massdesas** | Batch convert SAS datasets to Stata | 16+ |
| **pkgtransfer** | Transfer installed packages between systems via .do or .zip | 16+ |
| **synthdata** | Realistic synthetic data generation with privacy controls | 16+ |
| **today** | Set global macros with today's date and current time | 16+ |
| **validate** | Data validation rules and reporting | 16+ |

### Analysis

| Package | Description | Stata |
|---------|-------------|-------|
| **aft** | Accelerated failure time model selection, diagnostics, and RPSFTM g-estimation | 16+ |
| **balancetab** | Propensity score balance diagnostics and Love plots | 16+ |
| **cstat_surv** | C-statistic for Cox survival models | 16+ |
| **drest** | Doubly robust estimation (AIPW, TMLE, crossfit, LTMLE) | 16+ |
| **finegray** | Fine-Gray competing risks regression | 16+ |
| **gcomp** | G-computation formula via Monte Carlo simulation (includes gcomptab) | 16+ |
| **iivw** | Inverse intensity of visit weighting (IIW, IPTW, FIPTIW) for irregular longitudinal data | 16+ |
| **iptw_diag** | IPTW weight diagnostics, ESS, trimming | 16+ |
| **mlearn** | Machine learning interface (scikit-learn, XGBoost, LightGBM, SHAP) | 16+ (Python 3.8+) |
| **msm** | Marginal structural models via IPTW for time-varying treatments | 16+ |
| **mvp** | Missing value pattern analysis with visualizations | 14+ |
| **nma** | Network meta-analysis suite | 16+ |
| **outlier** | Outlier detection (IQR, SD, Mahalanobis, influence) | 16+ |
| **qba** | Quantitative bias analysis (confounding, misclassification, selection) | 16+ |
| **treescan** | Tree-based scan statistic for signal detection | 16+ |
| **tte** | Target trial emulation suite | 16+ |

### Time-Varying Data & Registries

| Package | Description | Stata |
|---------|-------------|-------|
| **setools** | Swedish registry toolkit (ICD expansion, migrations, MS progression, etc.) | 16+ |
| **tvtools** | Time-varying exposure data pipeline | 16+ |

### Reporting & Visualization

| Package | Description | Stata |
|---------|-------------|-------|
| **consort** | CONSORT-style exclusion flowcharts (requires Python 3.7+) | 16+ |
| **eplot** | Forest plots and coefficient plots from estimates or data | 16+ |
| **kmplot** | Publication-ready Kaplan-Meier survival curves with risk tables, CI bands, and median lines | 16+ |
| **logdoc** | Convert Stata log files to HTML or Markdown documents (requires Python 3.6+) | 16+ |
| **raincloud** | Raincloud plots: density, scatter, and box elements | 16+ |
| **spaghetti** | Longitudinal trajectory plots with group mean overlays | 16+ |
| **tabtools** | Publication-ready Excel tables (table1_tc, regtab, effecttab, stratetab, tablex) | 16+ (17+ for regtab, effecttab, stratetab, tablex) |
| **tc_schemes** | Graph schemes from blindschemes and schemepack | 16+ |

## Example Data

The `_data/` directory contains **fully synthetic** datasets modeling an SSRI vs SNRI antidepressant study in Swedish registry style (2006-2023). No real patient data is included. These datasets are used in package examples and help files.

```stata
* Load example data directly from the repo
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear
```

| File | Description |
|------|-------------|
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
