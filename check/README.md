# check

![Stata 14+](https://img.shields.io/badge/Stata-14%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

Comprehensive variable summary combining data quality metrics and descriptive statistics.

## Description

`check` provides a comprehensive summary of one or more variables, displaying both data quality metrics and descriptive statistics in a single table. This command is particularly useful for initial data exploration and validation, as it combines information typically obtained from multiple commands (`codebook`, `summarize`, `tabulate`, etc.) into one convenient output.

The command is ideal for:
- Initial data exploration after importing new datasets
- Validating data quality and completeness
- Quick variable inspection during analysis
- Identifying potential data issues

## Dependencies

This command requires the following user-written packages:
- **mdesc** - Install with: `ssc install mdesc`
- **unique** - Install with: `ssc install unique`

These packages will be automatically checked when you run `check`, with informative error messages if not installed.

## Installation

```stata
net install check, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/check")
```

## Syntax

```stata
check varlist [, short]
```

## Options

| Option | Description |
|--------|-------------|
| **short** | Removes descriptive statistics from output, showing only data quality metrics |

## Output Information

The output table includes the following information for each variable:

### Data Quality Metrics (always shown)
- **N**: Total number of observations
- **# Missing**: Count of missing values
- **% Missing**: Percentage of observations that are missing
- **# Unique Values**: Number of distinct values
- **Variable Type**: Storage type (byte, int, long, float, double, string)
- **Variable Format**: Display format
- **Variable Label**: Descriptive label if defined

### Descriptive Statistics (omitted with `short` option)
- **Mean**: Arithmetic mean (for numeric variables)
- **Standard Deviation**: SD (for numeric variables)
- **Minimum**: Smallest value
- **25th Percentile**: First quartile
- **Median**: 50th percentile
- **75th Percentile**: Third quartile
- **Maximum**: Largest value

## Examples

### Example 1: Check a single variable

```stata
sysuse auto, clear
check mpg
```

### Example 2: Check multiple variables

```stata
check mpg weight price
```

### Example 3: Check all variables in dataset

```stata
check _all
```

### Example 4: Short output (no descriptive statistics)

```stata
check mpg weight price, short
```

This is useful when you only need to check data completeness and structure without examining the distribution of values.

### Example 5: Check variables matching a pattern

```stata
check rep*
```

### Example 6: Check after data import

```stata
import delimited "rawdata.csv", clear
check _all

* Review output for:
* - Unexpected missing values
* - Variables that should be numeric but imported as string
* - Unreasonable min/max values
```

### Example 7: Quality control workflow

```stata
* Import dataset
use patient_data, clear

* Check key variables for data quality issues
check patient_id age_at_entry diagnosis_date

* If issues found, investigate further
summarize age_at_entry, detail
codebook diagnosis_date
```

## Use Cases

### Data Import Validation
After importing data from external sources (CSV, Excel, SAS), use `check _all` to verify:
- Variables imported with correct types
- Missing value patterns are expected
- Value ranges are reasonable

### Variable Inspection
During analysis, quickly inspect specific variables:
```stata
* Check outcome and key predictors
check outcome treatment age sex baseline_score
```

### Data Quality Report
Generate a quick data quality report for a dataset:
```stata
check _all, short
* Provides overview of completeness for all variables
```

## Comparison with Other Commands

| Command | Purpose | Advantage of `check` |
|---------|---------|---------------------|
| `codebook` | Detailed variable documentation | Faster, more concise output |
| `summarize` | Numeric summaries | Includes missing counts and percentiles |
| `inspect` | Distribution inspection | Shows both quality and statistics |
| `describe` | Variable metadata | Adds statistics and missing info |

## Requirements

Stata 14.0 or higher

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

Revisions of original concept and code by Michael N Mitchell 

## License

MIT License

## Version

Version 1.0.3, 2025-12-13

## See Also

- `codebook` - Detailed variable documentation
- `summarize` - Summary statistics
- `inspect` - Distribution inspection
- `describe` - Dataset and variable descriptions
