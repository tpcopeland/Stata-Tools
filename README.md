# Stata-Tools

A collection of Stata commands for data management, analysis, and table generation.

## Overview

This repository contains a suite of Stata packages developed to streamline common research tasks including data documentation, descriptive statistics, survival analysis, and publication-ready table creation.

## Packages

### Data Management & Documentation

**check** - Quick variable inspection with comprehensive descriptive statistics
- Displays N, missing values, unique values, type, format, and summary statistics
- Useful for data quality checks and initial exploration

**datamap** - Generate privacy-safe dataset documentation
- Creates comprehensive codebooks while protecting sensitive information
- Supports batch processing of multiple datasets
- Automatic variable classification and documentation

**datefix** - Convert inconsistent date formats to Stata dates
- Handles multiple date format variations automatically
- Useful for cleaning imported data with mixed date formats

**pkgtransfer** - Transfer installed Stata packages between systems
- Simplifies package management across multiple computers
- Generates installation scripts for reproducibility

**today** - Quick date stamping utilities
- Convenient commands for adding date stamps to files and analysis output

### Analysis & Tables

**table1_tc** - Create publication-ready Table 1 of baseline characteristics
- Automatic statistical test selection based on variable types
- Excel export with professional formatting
- Includes dialog interface for easy use

**regtab** - Format and export regression tables
- Works with Stata 17+ collect commands
- Exports coefficient tables with confidence intervals and p-values to Excel
- Professional formatting suitable for publication
- Includes dialog interface

**stratetab** - Combine and format strate output tables
- Merges multiple strate results into formatted Excel tables
- Custom labeling and precision control
- Person-years, event rates, and confidence intervals

### Survival Analysis

**cstat_surv** - Calculate C-statistic for survival models
- Post-estimation command for Cox models
- Assesses model discrimination
- Uses Somers' D transformation accounting for censoring

**tvtools** - Time-varying exposure data tools
- tvexpose: Create time-varying exposure variables for survival analysis
- tvmerge: Merge time-varying datasets with validation
- Includes dialogs and menu integration

## Installation

### Install from GitHub

For individual packages:

```stata
net from https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/[package-name]
net install [package-name]
```

For example, to install table1_tc:

```stata
net from https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/table1_tc
net install table1_tc
```

### Manual Installation

1. Download the package folder
2. Place files in your Stata PERSONAL directory
3. Find your directory with: `sysdir`
4. Restart Stata or type: `discard`

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

### Variable Inspection
```stata
* Check multiple variables
check age weight height bp

* Short version without detailed statistics
check age weight height, short
```

### C-statistic for Survival Models
```stata
* After fitting Cox model
stset time, failure(event)
stcox age treatment stage
cstat_surv
```

## Requirements

Most packages require Stata 14.2 or higher. Specific requirements:
- **regtab**: Stata 17+ (uses collect commands)
- **tvtools**: Stata 16+
- **cstat_surv**: Requires somersd package from SSC

## Documentation

Each package includes:
- Stata help file (.sthlp) - access via `help [command]`
- Package README with installation instructions
- Dialog interfaces for selected commands (table1_tc, regtab, tvtools)

## Support

Report issues and request features at: https://github.com/tpcopeland/Stata-Tools/issues

## Author

Timothy P Copeland
Department of Clinical Neuroscience
Karolinska Institutet

## License

MIT License - see individual package files for details

## Package Details

| Package | Description | Version | Stata Version |
|---------|-------------|---------|---------------|
| check | Variable inspection | 1.0 | 14+ |
| cstat_surv | C-statistic for survival | 1.0 | 14+ |
| datamap | Dataset documentation | 1.0 | 16+ |
| datefix | Date format conversion | 1.0 | 14+ |
| massdesas | Batch string destring | 1.0 | 14+ |
| pkgtransfer | Package management | 1.0 | 14+ |
| regtab | Regression tables | 1.2 | 17+ |
| stratetab | Strate output formatting | 2.1 | 17+ |
| table1_tc | Table 1 creation | 1.2 | 14.2+ |
| today | Date utilities | 1.0 | 14+ |
| tvtools | Time-varying data | 1.0 | 16+ |

## Citation

If you use these tools in your research, please cite the GitHub repository:

```
Copeland TP. Stata-Tools: A collection of Stata commands for data management and analysis.
GitHub repository: https://github.com/tpcopeland/Stata-Tools
```
