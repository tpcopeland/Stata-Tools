# check

![Stata 14+](https://img.shields.io/badge/Stata-14%2B-brightgreen)
![MIT License](https://img.shields.io/badge/License-MIT-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

Quick variable inspection with comprehensive descriptive statistics.

## Description

The `check` command produces a detailed table with comprehensive statistics for one or multiple variables, including:

- N, # Missing, % Missing, # Unique Values
- Variable Type and Format
- Descriptive Statistics (Mean, Standard Deviation, Minimum, 25th Percentile, Median, 75th Percentile, Maximum)
- Variable Label

This command is useful for rapid data quality checks and initial data exploration.

## Dependencies

None - uses only built-in Stata commands.

## Installation

```stata
net from https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/check
net install check
```

## Syntax

```stata
check varlist [, short]
```

### Options

**short** - Removes detailed descriptive statistics, showing only basic information (N, missing, unique values, type, format, label)

## Examples

```stata
* Load example data
sysuse auto, clear

* Check multiple variables
check price mpg weight

* Short version without detailed statistics
check price mpg weight, short
```

## Requirements

Stata 14.0 or higher

## Author

Timothy P Copeland
Department of Clinical Neuroscience
Karolinska Institutet

Original concept by Michael N Mitchell

## Help

For more information:
```stata
help check
```
