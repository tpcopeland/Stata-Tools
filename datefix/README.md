# datefix - Convert imported date strings to Stata daily dates

**Version 1.1.0** | 2026-07-10

`datefix` converts string date variables to numeric Stata daily dates and applies a daily-date display format. It is designed for the common cleanup step after import, especially when date order is inconsistent, two-digit years need disambiguation, or you want to preserve the original string alongside a cleaned numeric date.

## Requirements

- Stata 16 or later

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

If the imported dates are unambiguous, `datefix` can usually infer the correct ordering and replace the original string variable in place.

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

In this example, `datefix` will auto-detect the ordering that produces the most valid parses, convert `visit_date` to a numeric daily date, and apply the default `%tdCCYY/NN/DD` format.

## How It Works

- Without `newvar()`, each variable in `varlist` is converted in place.
- With `newvar()`, only one source variable may be specified, and the original variable is preserved unless `drop` is also requested.
- If `order()` is omitted, `datefix` tests `MDY`, `DMY`, and `YMD` and uses the ordering that produces the most valid parses. If the strings are ambiguous, specify `order()` explicitly.
- `topyear()` passes Stata's `topyear` argument to `date()` so two-digit years are interpreted correctly.
- If a variable is already numeric, `datefix` can still copy it to `newvar()` and apply a different daily-date display format.

## Worked Examples

### 1. Auto-detect the ordering and replace the original variables

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

### 5. Find the values that block a conversion

When a column contains a few bad entries (a month or day of `00`, an impossible date, or stray text), `diagnose` lists exactly which values failed and where they are, instead of just reporting a count.

```stata
clear
input str10 dob
"2020/01/15"
"2020/00/15"
"2020/13/40"
"not recorded"
"2020/00/15"
end

datefix dob, diagnose
```

`datefix` prints a table of the distinct unconvertible values, their frequencies, and the offending observation numbers, then stops with an error so you can fix the source data and rerun. No variable is created or replaced while any value still fails.

## Common `df()` Formats

| Format string | Example output | Use |
|---------------|----------------|-----|
| `%tdCCYY/NN/DD` | 2020/01/10 | Default year-month-day display |
| `%tdDD/NN/CCYY` | 10/01/2020 | Day-month-year display |
| `%tdMonth_DD,_CCYY` | January 10, 2020 | Full month name |
| `%tdDD_Mon._CCYY` | 10 Jan. 2020 | Compact manuscript-style date |

For the full set of Stata date display formats, see `help datetime_display_formats`.

## Practical Notes

- `newvar()` cannot be combined with multiple source variables.
- `drop` is only meaningful when `newvar()` is used.
- `datefix` stops when it encounters strings with `:` because those look like datetimes rather than daily dates.
- Missing-value counts are reported before and after conversion so you can spot parsing problems quickly.
- Add `diagnose` to print the exact values that block a conversion — month or day of `00`, out-of-range components like `2020/13/40`, or stray non-date text — together with their frequencies and the observation numbers where they occur, so you do not have to go searching.
- `datefix` does not store results in `r()`.

## Version History

- **1.1.0** (2026-06-25): Added the `diagnose` option, which reports the distinct unconvertible values, their frequencies, and the observation numbers when a conversion fails, then stops — so problem dates no longer have to be hunted down manually.
- **1.0.1** (2026-06-19): Documentation fixes — `df()` and `drop` now render as options in the help file, added section markers, and standardized the author string.
- **1.0.0** (2026-04-08): Initial release with auto-detection, `newvar()`, custom display formats, and `topyear()` support.

## Author

Timothy P Copeland, Karolinska Institutet
