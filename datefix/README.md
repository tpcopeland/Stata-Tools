# datefix

![Stata 14+](https://img.shields.io/badge/Stata-14%2B-brightgreen)
![MIT License](https://img.shields.io/badge/License-MIT-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

Convert string date variables to numeric date formatted variables.

## Description

datefix converts one or more string variables containing date information to numeric encoded variables with proper date formatting. The command automatically detects the date format and handles various date representations. It is particularly useful for cleaning imported data with inconsistent date formats.

## Dependencies

None - uses only built-in Stata commands.

## Installation

```stata
net from https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/datefix
net install datefix
```

## Syntax

```stata
datefix varlist [, options]
```

### Options

- **newvar(string)** - Create new variable with given name (only one variable allowed)
- **drop** - Drop original string variable (only with newvar option)
- **df(date_format)** - Display format for date (default: %tdCCYY/MM/DD)
- **order(string)** - Specify ordering of month, day, year (MDY, DMY, YMD)
- **topyear(integer)** - Required if two-digit years are present

## Examples

```stata
* Convert date variables using default format
datefix dob dod

* Create new variable with MDY format
datefix visit_date, newvar(vdate) order(MDY) df(%tdMonth_DD,_CCYY)

* Convert with two-digit year handling
datefix city_founded, topyear(1900)
```

## Common date formats

- %tdCCYY/MM/DD - "2020/01/10" (default)
- %tdMonth_DD,_CCYY - "January 10, 2020"
- %tdDD_Mon._CCYY - "10 Jan. 2020"
- %tdMon_DD,_CCYY - "Jan 10, 2020"

## Requirements

Stata 14.0 or higher

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License - See LICENSE file for details

## Help

For more information:
```stata
help datefix
```
