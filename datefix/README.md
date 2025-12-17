# datefix

![Stata 14+](https://img.shields.io/badge/Stata-14%2B-brightgreen)
![MIT License](https://img.shields.io/badge/License-MIT-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

Convert string date variables to numeric date formatted variables.

## Description

`datefix` converts one or more string variables containing date information to numeric encoded variables with proper date formatting. The command automatically detects the date format and handles various date representations. It is particularly useful for cleaning imported data with inconsistent date formats.

**Important Notes:**
- If the `newvar()` option is used, only one variable can be specified in the command
- The program does not accommodate datetime values, only dates

## Installation

```stata
net install datefix, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/datefix")
```

## Syntax

```stata
datefix varlist [, newvar(string) drop df(date_format) order(string) topyear(integer)]
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `newvar(string)` | (none) | Creates a new numeric date variable with the given name. When this option is used, only one variable can be specified in `varlist`. The original string variable is preserved unless `drop` is specified. |
| `drop` | not dropped | Drops the original string variable. Only applicable when `newvar()` is used; otherwise is redundant since variables are replaced by default. |
| `df(date_format)` | `%tdCCYY/MM/DD` | Specifies the display format for the date. Accepts any valid Stata date format (see examples below). |
| `order(string)` | auto-detected | Specifies the ordering of month, day, and year (e.g., MDY, DMY, YMD). If not specified, the ordering that produces the fewest missing values is automatically selected. |
| `topyear(integer)` | (none) | Specifies the topyear for Stata's `date()` function. **Required** if two-digit years are present in the data. For example, `topyear(1900)` means that 2-digit years are interpreted as being closest to but not after 1900. See Stata's `help date()` for more information. |

## Examples

### Example 1: Basic Conversion with Default Format

Convert the string date variables `dob` and `dod` using the default date format (`%tdCCYY/MM/DD`) and whichever ordering of day, month, and year produces the fewest missing values, replacing the original string variables:

```stata
datefix dob dod
```

### Example 2: Creating a New Variable with Custom Format

Convert the variable `visit_date` into a new variable `vdate` using the MDY date format, preserving the original string variable `visit_date`, and using the format that produces a date in "Month DD, CCYY" format:

```stata
datefix visit_date, newvar(vdate) order(MDY) df(%tdMonth_DD,_CCYY)
```

### Example 3: Handling Two-Digit Years

Convert the variable `city_founded` into a numeric date variable, indicating that years listed with two digits are in the years closest to but not after 1900:

```stata
datefix city_founded, topyear(1900)
```

### Example 4: Creating New Variable and Dropping Original

```stata
datefix admission_date, newvar(admit_dt) drop df(%tdDD/MM/CCYY)
```

## Common Date Formats for df() Option

| Format String | Example Output | Description |
|---------------|----------------|-------------|
| `%tdCCYY/MM/DD` | 2020/01/10 | Default format (YYYY/MM/DD) |
| `%tdMonth_DD,_CCYY` | January 10, 2020 | Full month name |
| `%tdDD_Mon._CCYY` | 10 Jan. 2020 | Abbreviated month |
| `%tdDD/MM/CCYY` | 10/01/2020 | DD/MM/YYYY format |
| `%tdMon_DD,_CCYY` | Jan 10, 2020 | Abbreviated month, comma |

For a complete list of date formats, see Stata's help on datetime display formats: `help datetime_display_formats`

## How It Works

1. The command examines the string variable(s) to identify the date pattern
2. If `order()` is not specified, it tests different orderings (MDY, DMY, YMD) and selects the one producing the fewest missing values
3. Converts the string to Stata's internal numeric date representation
4. Applies the specified display format (or default if not specified)
5. Either replaces the original variable or creates a new one based on options specified

## Requirements

- Stata 14.0 or higher
- No external dependencies - uses only built-in Stata commands

## Version History

- **Version 1.0.1** (3 December 2025): Bug fixes - replaced hardcoded variable names with tempvars, improved datetime detection, fixed local macro checking
- **Version 1.0.0** (2 December 2025): GitHub publication release

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## See Also

- `help date()` - Stata's date() function documentation
- `help datetime_display_formats` - Date format options
- `help datetime` - General date/time documentation

## Getting Help

For more detailed information, you can access the Stata help file:
```stata
help datefix
```
