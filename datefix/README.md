# datefix — Convert imported date strings to Stata daily dates

**Version 1.1.0** | 2026-07-14

`datefix` converts imported string date variables to numeric Stata daily dates for users cleaning data after import. It can infer date order, preserve raw values in a new variable, apply `%td` display formats, and identify values that prevent conversion.

## Quick Start

Convert an imported day-month-year string in place:

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

The command auto-detects the ordering and displays the converted variable with the default `%tdCCYY/NN/DD` format.

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
| `datefix` | Convert string or numeric date variables to numeric Stata daily dates |

## How It Works

- `datefix` processes each variable in `varlist` independently. String variables are parsed with Stata's `date()` function; numeric variables are treated as existing daily-date values and are formatted or copied.
- If `order()` is omitted, the command tries MDY, DMY, and YMD and selects the ordering with the most valid parses. MDY wins ties, so use `order()` when the input is ambiguous.
- Without `newvar()`, a string variable is converted in place. With `newvar()`, the source variable is retained unless `drop` is also specified.
- `topyear()` is passed to `date()` for interpreting two-digit years, and `df()` changes the display format without changing the stored daily-date value.
- Any nonmissing string that cannot be parsed causes the conversion to stop before that variable is replaced. The command reports missing-value counts before and after a successful conversion.

## Worked Examples

### 1. Preserve the imported string and choose a display format

Use `newvar()` when the raw imported value should remain available for auditing.

```stata
clear
input str10 visit_date
"03/14/2020"
"04/20/2020"
"05/01/2020"
end

datefix visit_date, newvar(vdate) order(MDY) df(%tdMonth_DD,_CCYY)
list visit_date vdate
```

### 2. Replace the source variable with a new name

Combine `newvar()` and `drop` when the cleaned variable should replace the imported column.

```stata
clear
input str10 admit_str
"06/15/2024"
"01/22/2024"
"11/03/2023"
end

datefix admit_str, newvar(admit_date) drop order(MDY) df(%tdDD/NN/CCYY)
list
```

### 3. Interpret two-digit years

Set `topyear()` explicitly when the source contains two-digit years.

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

### 4. Copy an existing numeric daily date with another format

Numeric input is useful when the values already count days from 01jan1960 but need a new variable or display format.

```stata
clear
input double visit_num
21915
21945
21988
end

datefix visit_num, newvar(visit_date) df(%tdDD_Mon._CCYY)
list
```

### 5. Diagnose values that block conversion

With `diagnose`, the command lists distinct unconvertible values, their frequencies, and the observation numbers where they occur before returning an error.

```stata
clear
input str12 dob
"2020/01/15"
"2020/00/15"
"2020/13/40"
"not recorded"
"2020/00/15"
end

capture noisily datefix dob, diagnose
```

The `capture` keeps the expected conversion error from stopping a larger do-file; the failing variable is not created or replaced when a nonmissing value fails.

## Key Options

Syntax: `datefix varlist [, newvar(name) drop df(%fmt) order(string) topyear(#) diagnose]`. Use one or more source variables; `newvar()` is limited to a single source variable, and `order()` accepts `MDY`, `DMY`, or `YMD`.

| Option | Default | Description |
|--------|---------|-------------|
| `newvar(name)` | Off | Create a new numeric date variable; retain the source unless `drop` is also specified |
| `drop` | Off | Drop the source variable when `newvar()` is used; otherwise it is redundant because in-place conversion replaces the source |
| `df(%fmt)` | `%tdCCYY/NN/DD` | Apply a Stata daily-date display format; the format must begin with `%td` |
| `order(string)` | Auto | Parse strings as `MDY`, `DMY`, or `YMD`; automatic detection chooses the most valid ordering and MDY wins ties |
| `topyear(#)` | Off | Pass an integer top-year argument to `date()` for two-digit years |
| `diagnose` | Off | List unconvertible values, frequencies, and observation numbers on failure; the option may be abbreviated to `diag` |

## Stored Results

`datefix` does not define documented `r()` stored results. Conversion status, the selected order, and missing-value counts are printed in the Results window.

## Assumptions and Limits

- Numeric variables are assumed to contain Stata daily dates, measured as days from 01jan1960; `datefix` does not validate their substantive meaning.
- Strings containing `:` are treated as possible datetime values and rejected because `datefix` handles daily dates only.
- A nonmissing string that fails under the chosen order stops the operation before replacement. Use `diagnose` to locate the failing values.
- The diagnostic table shows at most 50 distinct failing values and at most 10 observation numbers per value, indicating when additional values or rows are omitted.
- If date strings are ambiguous, automatic detection is heuristic; specify `order()` for a known input convention.

## References

- Stata `help date()` documents the date-string parsing function used by `datefix`; `help datetime_display_formats` documents the `%td` display formats accepted by `df()`.

## QA

QA suites and how to run them are documented in [`qa/README.md`](qa/README.md).

## Version History

- **1.1.0** (2026-06-25): Added the `diagnose` option, which reports distinct unconvertible values, their frequencies, and observation numbers when conversion fails.
- **1.0.1** (2026-06-19): Documentation fixes — `df()` and `drop` now render as options in the help file, added section markers, and standardized the author string.
- **1.0.0** (2026-04-08): Initial release with auto-detection, `newvar()`, custom display formats, and `topyear()` support.

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
