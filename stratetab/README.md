# stratetab

![Stata 17+](https://img.shields.io/badge/Stata-17%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

Combine strate output files and export to Excel.

## Description

stratetab combines pre-computed strate output files and exports them to Excel with outcome labels as headers and category labels indented in the first column. The command creates formatted tables with events, person-years, and rates with 95% confidence intervals.

## Dependencies

Requires **strate** (built-in Stata survival analysis command). Data must be declared as survival-time data using `stset`.

## Installation

```stata
net from https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/stratetab
net install stratetab
```

## Syntax

```stata
stratetab, using(filelist) xlsx(filename) [options]
```

### Required options

- **using(namelist)** - Space-separated list of strate output files (without .dta extension)
- **xlsx(filename)** - Excel output file (must have .xlsx extension)

### Optional options

- **sheet(string)** - Excel sheet name (default: Results)
- **title(string)** - Title text for row 1
- **labels(string)** - Outcome labels separated by backslash
- **digits(integer)** - Decimal places for rates (default: 1)
- **eventdigits(integer)** - Decimal places for events (default: 0)
- **pydigits(integer)** - Decimal places for person-years (default: 0)
- **unitlabel(string)** - Unit label for person-years and rates

## Example

```stata
* First, run strate and save results
use survdata, clear
stset time, failure(event)

strate exposure, output(strate_outcome1) replace
strate exposure, failure(event2) output(strate_outcome2) replace

* Combine results in formatted table
stratetab, using(strate_outcome1 strate_outcome2) ///
    xlsx(results.xlsx) ///
    labels(Primary Outcome \ Secondary Outcome) ///
    title(Event Rates by Exposure) ///
    digits(2)
```

## Output format

The Excel table includes:
- Outcome labels as headers
- Indented category rows
- Events, person-years, and rates with 95% CI
- Professional formatting

## Requirements

Stata 17.0 or higher

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## Help

For more information:
```stata
help stratetab
```
