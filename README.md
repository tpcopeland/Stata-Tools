# Stata-Tools

![Repository](https://img.shields.io/badge/Repository-Stata--Tools-blue)
![MIT License](https://img.shields.io/badge/License-MIT-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

A collection of Stata commands for data management, analysis, and table generation.

## Overview 

This repository contains a suite of Stata packages developed to streamline common research tasks including data documentation, descriptive statistics, survival analysis, and publication-ready table creation.

## Table of Contents

- [Repository Structure](#repository-structure)
- [Packages](#packages)
  - [Data Management & Documentation](#data-management--documentation)
  - [Data Quality](#data-quality)
  - [Visualization & Reporting](#visualization--reporting)
  - [Analysis & Tables](#analysis--tables)
  - [Causal Inference Diagnostics](#causal-inference-diagnostics)
  - [Survival Analysis](#survival-analysis)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Requirements](#requirements)
- [Documentation](#documentation)
- [Development](#development)
- [Support](#support)
- [Author](#author)
- [License](#license)
- [Package Details](#package-details)
- [Citation](#citation)

## Repository Structure

```
Stata-Tools/
├── [package]/              # Individual Stata packages (see Packages section)
│   ├── *.ado               # Command implementation
│   ├── *.sthlp             # Help documentation
│   ├── *.pkg               # Package metadata
│   ├── *.dlg               # Dialog file (optional)
│   └── README.md           # Package documentation
│
├── _guides/                # Development documentation
│   ├── developing.md       # Guide for creating new commands
│   ├── testing.md          # Guide for writing functional tests
│   └── validating.md       # Guide for writing validation tests
│
├── _templates/             # Templates for new Stata commands
│   ├── TEMPLATE.ado        # Command template
│   ├── TEMPLATE.sthlp      # Help file template
│   ├── TEMPLATE.pkg        # Package metadata template
│   ├── TEMPLATE.dlg        # Dialog template
│   ├── testing_TEMPLATE.do # Functional test template
│   └── validation_TEMPLATE.do # Validation test template
│
├── _testing/               # Functional test suites
│   ├── generate_test_data.do  # Creates synthetic test datasets
│   ├── run_all_tests.do       # Master test runner
│   └── test_*.do              # Individual command tests
│
├── _validation/            # Validation tests (correctness verification)
│   └── validation_*.do     # Tests with hand-calculated expected values
│
├── _reimplementations/     # Cross-language ports
│   ├── R/tvtools/          # R implementation of tvtools
│   └── Python/tvtools/     # Python implementation of tvtools
│
├── CLAUDE.md               # AI assistant coding guide
└── README.md               # This file
```

## Packages

### Data Management & Documentation

**check** - Quick variable inspection with comprehensive descriptive statistics
- Displays N, missing values, unique values, type, format, and summary statistics
- Useful for data quality checks and initial exploration

**compress_tc** - Maximally compress string variables via strL conversion
- Two-stage compression: converts to strL then runs compress for optimal storage
- Dramatically reduces memory for datasets with long or repeated strings
- Automatic detection and reversion for cases where compression isn't beneficial

**datamap** - Privacy-safe dataset documentation and Markdown data dictionaries
- datamap: Generate comprehensive, privacy-safe text documentation with automatic variable classification
- datadict: Create professional Markdown data dictionaries for GitHub and documentation systems
- Supports batch processing of multiple datasets with flexible privacy controls

**datefix** - Convert inconsistent date formats to Stata dates
- Handles multiple date format variations automatically
- Useful for cleaning imported data with mixed date formats

**massdesas** - Batch convert SAS datasets to Stata format
- Recursively converts all .sas7bdat files in a directory tree
- Preserves directory structure
- Optional deletion of source files after conversion

**mvp** - Missing value pattern analysis with enhanced features
- Analyzes and displays missing value patterns across variables
- Visual representations including bar charts, heatmaps, and correlation matrices
- Tests for monotone missingness patterns important for multiple imputation
- Generate indicators, save patterns, and compute missingness correlations

**pkgtransfer** - Transfer installed Stata packages between systems
- Simplifies package management across multiple computers
- Generates installation scripts for reproducibility

**setools** - Swedish registry data toolkit
- migrations: Process migration registry data for cohort exclusions and censoring
- sustainedss: Compute sustained EDSS progression dates for MS research

**synthdata** - Generate synthetic datasets for privacy protection
- Multiple synthesis methods: parametric, sequential, bootstrap, permutation
- Privacy controls: rare category protection, extreme value trimming
- Validation tools: comparison reports, utility metrics, density plots
- Panel data support with relationship preservation

**today** - Quick date stamping utilities
- Convenient commands for adding date stamps to files and analysis output

### Data Quality

**outlier** - Outlier detection toolkit
- Multiple detection methods: IQR, standard deviation, Mahalanobis distance, influence diagnostics
- Actions: flag, winsorize, or exclude outliers
- Group-specific outlier detection and Excel report export

**validate** - Data validation rules
- Define expected ranges, patterns, and cross-variable checks
- Run validation suites and generate reports
- Assert on failure option for automated QC pipelines
- Useful for registry data quality control

### Visualization & Reporting

**consort** - Generate CONSORT-style exclusion flowcharts
- Creates publication-ready flowcharts visualizing cohort exclusions
- Tracks observation counts through sequential exclusion criteria
- Exports PNG images via Python/matplotlib integration

### Analysis & Tables

**table1_tc** - Create publication-ready Table 1 of baseline characteristics
- Automatic statistical test selection based on variable types
- Excel export with professional formatting
- Includes dialog interface for easy use

**regtab** - Format and export regression, treatment effects, and mediation tables
- **regtab**: Format standard regression output (logit, regress, stcox, etc.)
- **effecttab**: Format causal inference results (teffects ipw, margins, g-computation)
- **gformtab**: Format gformula mediation analysis (TCE, NDE, NIE, PM, CDE)
- Works with Stata 17+ collect commands (regtab/effecttab) and gformula (gformtab)
- Exports tables with confidence intervals and p-values to Excel
- Professional formatting suitable for publication
- Includes dialog interface for regtab

**stratetab** - Combine and format strate output tables
- Merges multiple strate results into formatted Excel tables
- Custom labeling and precision control
- Person-years, event rates, and confidence intervals

### Causal Inference Diagnostics

**balancetab** - Propensity score balance diagnostics
- Standardized mean differences before/after matching or weighting
- Love plot visualization for balance assessment
- Export balance tables to Excel
- Pairs naturally with effecttab workflow

**iptw_diag** - IPTW weight diagnostics
- Weight distribution summaries (mean, max, percentiles)
- Effective sample size (ESS) calculation
- Extreme weight detection and trimming options
- Weight stabilization utilities

### Survival Analysis

**cstat_surv** - Calculate C-statistic for survival models
- Post-estimation command for Cox models
- Assesses model discrimination
- Standalone calculation with embedded Mata (no external dependencies)

**tvtools** - Time-varying exposure data tools
- tvexpose: Create time-varying exposure variables for survival analysis
- tvmerge: Merge time-varying datasets with validation
- tvevent: Integrate events and competing risks into time-varying datasets
- Includes dialogs and menu integration

## Installation

### Install from GitHub

For individual packages:

```stata
net install [package-name], from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/[package-name]")
```

For example, to install table1_tc:

```stata
net install table1_tc, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/table1_tc")
```

### Manual Installation

1. Download the package folder from the repository
2. Identify your Stata PERSONAL directory using: `sysdir`
3. Place the downloaded files in your PERSONAL directory
4. Restart Stata or type `discard` to refresh the package list

## Quick Start

### Creating Table 1
```stata
* Using command line
table1_tc, vars(age contn \ bmi conts \ female bin \ race cat) by(treatment)

* Using dialog
db table1_tc
```

### Formatting Regression Tables
```stata
* First, run regressions with collect
collect: logit outcome predictor1 predictor2

* Then format and export
regtab, xlsx(results.xlsx) sheet(Table1) coef(OR)

* Or use dialog
db regtab
```

### Formatting Treatment Effects Tables
```stata
* IPTW estimation
collect clear
collect: teffects ipw (outcome) (treatment age sex), ate

* Format and export
effecttab, xlsx(results.xlsx) sheet(ATE) effect(ATE) clean
```

### Variable Inspection
```stata
* Check multiple variables
check age weight height bp

* Short version without detailed statistics
check age weight height, short
```

### Missing Value Pattern Analysis
```stata
* Analyze missing patterns with visualization
mvp price mpg rep78, graph(bar)

* Test for monotone missingness
mvp, monotone correlate
```

### String Compression
```stata
* Compress all string variables optimally
compress_tc

* Compress specific variables with detail
compress_tc name address comments, detail
```

### C-statistic for Survival Models
```stata
* After fitting Cox model
stset time, failure(event)
stcox age treatment stage
cstat_surv
```

## Requirements

**Minimum Stata Version:** 14.2+

The majority of packages are compatible with Stata 14.2 or higher. Specific version requirements:

- **regtab**: Stata 17+ (uses collect commands)
- **balancetab, iptw_diag, outlier, validate**: Stata 16+
- **tvtools**: Stata 16+
- **cstat_surv**: Stata 16+
- **datamap**: Stata 16+

## Documentation

Each package includes comprehensive documentation:
- **Stata Help Files (.sthlp)**: Access in-depth help using `help [command]`
- **Package README**: Installation instructions and usage details
- **Dialog Interfaces**: User-friendly GUI available for select commands (table1_tc, regtab, tvtools)
- **Examples**: Quick start examples and best practices included in help files

## Support

Report issues and request features at: https://github.com/tpcopeland/Stata-Tools/issues

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License - see individual package files for details

## Package Details

| Package | Description | Version | Stata Version |
|---------|-------------|---------|---------------|
| balancetab | Propensity score balance diagnostics | 1.0.0 | 16+ |
| check | Variable inspection | 1.0.3 | 14+ |
| compress_tc | String compression via strL | 1.0.2 | 13+ |
| consort | CONSORT flowchart generation | 1.0.1 | 16+ |
| cstat_surv | C-statistic for survival | 1.0.1 | 16+ |
| datamap | Dataset documentation | 1.0.1 | 16+ |
| datefix | Date format conversion | 1.0.1 | 14+ |
| iptw_diag | IPTW weight diagnostics | 1.0.0 | 16+ |
| massdesas | Batch SAS to Stata conversion | 1.0.3 | 14+ |
| mvp | Missing value pattern analysis | 1.1.1 | 14+ |
| outlier | Outlier detection toolkit | 1.0.0 | 16+ |
| pkgtransfer | Package management | 1.0.2 | 14+ |
| regtab | Regression, treatment effects & mediation tables | 1.2.0 | 16+/17+ |
| setools | Swedish registry data tools | 1.0.1 | 18+ |
| stratetab | Strate output formatting | 1.0.2 | 17+ |
| synthdata | Synthetic data generation | 1.2.2 | 16+ |
| table1_tc | Table 1 creation | 1.0.3 | 14.2+ |
| today | Date utilities | 1.0.1 | 14+ |
| tvtools | Time-varying data | 1.2.0 | 16+ |
| validate | Data validation rules | 1.0.0 | 16+ |

## Citation

If you use these tools in your research, please cite the GitHub repository:

```bibtex
@software{copeland2025stata,
  author = {Copeland, Timothy P},
  title = {Stata-Tools: A collection of Stata commands for data management and analysis},
  url = {https://github.com/tpcopeland/Stata-Tools},
  year = {2025}
}
```

Or in text format:
> Copeland TP. Stata-Tools: A collection of Stata commands for data management and analysis. GitHub repository: https://github.com/tpcopeland/Stata-Tools
