# check

Quick variable inspection with comprehensive descriptive statistics.

## Description

check produces a detailed table with N, # Missing, % Missing, # Unique Values, Variable Type, Variable Format, Mean, Standard Deviation, Minimum, 25th Percentile, Median, 75th Percentile, Maximum, and Variable Label for one or multiple variables. It is useful for rapid data quality checks and initial exploration.

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

Timothy P Copeland, Department of Clinical Neuroscience, Karolinska Institutet

Original concept by Michael N Mitchell

## Help

For more information:
```stata
help check
```
