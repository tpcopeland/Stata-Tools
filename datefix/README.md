# datefix - Convert string date variables to Stata daily dates

**Version 1.0.0** | 2026-04-08

`datefix` converts string date variables to numeric Stata daily dates and applies a daily-date display format. It is designed for the common data-cleaning case where imported dates arrive as strings, the ordering is unclear, or two-digit years need explicit handling before analysis.

## Requirements

- Stata 16 or later
- Daily dates only; datetime strings are not supported

## Installation

```stata
capture ado uninstall datefix
net install datefix, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/datefix") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `datefix` | Convert one or more string date variables to numeric Stata daily dates, optionally into a new variable with a custom display format |

## Quick Start

If the imported dates are clearly day-month-year or year-month-day, `datefix` can usually infer the correct ordering and replace the original string variable in place.

```stata
clear
input str10 visit_date
"31/01/2020"
"15/02/2020"
"07/03/2020"
end

datefix visit_date
list
```

In this example, `datefix` will auto-detect `DMY`, convert `visit_date` to a numeric daily date, and leave it displayed with the default `%tdCCYY/NN/DD` format.

## How It Works

- Without `newvar()`, each variable in `varlist` is converted in place.
- With `newvar()`, only one source variable may be specified, and the original variable is preserved unless `drop` is also requested.
- If `order()` is omitted, `datefix` tests `MDY`, `DMY`, and `YMD` and chooses the ordering that produces the most valid parses.
- If two-digit years are present, supply `topyear()` so Stata's `date()` function interprets them correctly.
- If a variable is already numeric, `datefix` applies the requested display format or copies it to `newvar()`.

## Worked Examples

### 1. Auto-detect the ordering and replace the original variable

This is the default cleanup workflow for imported string dates.

```stata
clear
input str10 dob str10 dod
"31/01/2020" "02/02/2020"
"15/02/2020" "18/02/2020"
end

datefix dob dod
list
```

### 2. Preserve the original string and write a new formatted date variable

Use `newvar()` when you want to keep the raw imported string alongside the cleaned Stata date.

```stata
clear
input str10 visit_date
"03/14/2020"
"04/20/2020"
"05/01/2020"
end

datefix visit_date, newvar(vdate) order(MDY) df(%tdMonth_DD,_CCYY)
list
```

### 3. Handle two-digit years explicitly

When the source data use two-digit years, `topyear()` tells Stata how those years should be interpreted.

```stata
clear
input str8 founded
"07/04/76"
"11/12/84"
"05/09/91"
end

datefix founded, order(MDY) topyear(1900)
list
```

### 4. Copy an already numeric date variable and change only the display format

`datefix` also works as a lightweight formatting helper when the dates are already numeric Stata daily dates.

```stata
clear
input double visit_num
21915
21945
21988
end
format %td visit_num

datefix visit_num, newvar(visit_label) df(%tdDD_Mon._CCYY)
list
```

## Common `df()` Formats

| Format string | Example output | Use |
|---------------|----------------|-----|
| `%tdCCYY/NN/DD` | 2020/01/10 | Default year-month-day display |
| `%tdDD/NN/CCYY` | 10/01/2020 | Day-month-year display |
| `%tdMonth_DD,_CCYY` | January 10, 2020 | Full month name |
| `%tdMon_DD,_CCYY` | Jan 10, 2020 | Abbreviated month with comma |
| `%tdDD_Mon._CCYY` | 10 Jan. 2020 | Compact manuscript-style date |

For the full set of Stata date display formats, see `help datetime_display_formats`.

## Practical Notes

- `newvar()` cannot be combined with multiple source variables.
- `drop` is only meaningful when `newvar()` is used.
- If `datefix` encounters strings with `:` in them, it stops because those look like datetimes rather than daily dates.
- Missing-value counts are reported before and after conversion so you can spot parsing problems quickly.

## Version History

- **1.0.0** (2026-04-08): Initial Stata-Tools release for converting string dates to Stata daily dates with auto-detection, format control, and `topyear()` handling.

## Author

Timothy P Copeland, Karolinska Institutet
