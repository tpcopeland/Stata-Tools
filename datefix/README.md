<p align="center"><img src="../_resources/logos/datefix_hex.svg" width="150" alt="datefix hex logo"></p>

# datefix — Imported date strings to Stata dates

**Version 1.1.3** | 2026-10-26

[![version](https://img.shields.io/badge/version-1.1.3-1a5f91?style=flat-square)](#version-history) [![Stata 16+](https://img.shields.io/badge/Stata-16%2B-1a5f91?style=flat-square)](#requirements) [![MIT license](https://img.shields.io/badge/license-MIT-1a5f91?style=flat-square)](../LICENSE) [![Part of Stata-Tools](https://img.shields.io/badge/part%20of-Stata--Tools-0e3a5a?style=flat-square)](../README.md)

**[Quick Start](#quick-start)** · **[Installation](#installation)** · **[Key Options](#key-options)** · **[Version History](#version-history)** · **[Stata-Tools](../README.md)** · **[Report a bug](https://github.com/tpcopeland/Stata-Tools/issues)**

`datefix` converts imported string date variables to numeric Stata daily dates for users cleaning data after import. It can infer date order, preserve raw values in a new variable, apply `%td` display formats, and identify values that prevent conversion.

## Quick Start

After [installing](#installation), convert an imported day-month-year string in place:

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

The command auto-detects the ordering and displays the converted variable with the default `%tdCCYY/NN/DD` format. More examples, including `newvar()`, `topyear()` and `diagnose`, are in `help datefix`.

## Features

- **Detects the date order.** Without `order()`, `datefix` tries MDY, DMY and YMD and keeps the ordering with the most valid parses; `order()` fixes it when the input is ambiguous. Daily dates only: datetime strings fail conversion.
- **All or nothing.** A nonmissing string that fails to parse stops the command before any variable in the `varlist` is replaced, and an all-missing source stops with `r(2000)`, so a failed or empty conversion is never reported as a success.
- **Finds the bad values.** `diagnose` lists each distinct unconvertible value with its frequency and observation numbers.
- **Raw values kept on request.** `newvar()` writes the date to a new variable and keeps the imported string (unless `drop`); `df()` changes only the display format. A numeric input is taken to hold daily dates already and is only formatted or copied.

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
| `datefix` | Convert string dates; format or copy existing numeric daily-date values |

## Key Options

Syntax: `datefix varlist [, newvar(name) drop df(%fmt) order(string) topyear(#) diagnose]`. Use one or more source variables; `newvar()` is limited to a single source variable, and `order()` accepts `MDY`, `DMY`, or `YMD` (case-insensitive).

| Option | Default | Description |
|--------|---------|-------------|
| `newvar(name)` | Off | Create a new numeric date variable; retain the source unless `drop` is also specified |
| `drop` | Off | Drop the source variable when `newvar()` is used; without `newvar()`, it is redundant because strings are replaced and numeric inputs are formatted in place |
| `df(%fmt)` | `%tdCCYY/NN/DD` | Apply a Stata daily-date display format; the format must begin with `%td` |
| `order(string)` | Auto | Parse strings as `MDY`, `DMY`, or `YMD`; automatic detection chooses the most valid ordering, with MDY preferred for top-count ties and YMD preferred over DMY when those two tie above MDY |
| `topyear(#)` | Off | Pass an integer top-year argument to `date()` for two-digit years |
| `diagnose` | Off | On string-conversion failure, list unconvertible values, frequencies, and observation numbers; the option may be abbreviated to `diag` |

## Stored Results

`datefix` defines no stored results and clears incidental `r()` state before returning. Conversion messages, the auto-detected order (when `order()` is omitted), and missing-value counts are printed in the Results window.

## QA

QA suites and how to run them are documented in [`qa/README.md`](qa/README.md).

## Version History

- **1.1.3** (2026-10-13): The summary line for a numeric input now says the variable is already numeric and only had the date format applied, instead of claiming it was converted.
- **1.1.2** (2026-08-11): Accepted colon-separated daily dates, rejected all-missing inputs without mutation, preserved literal Unicode diagnostic values, and made help examples and the local-install demo self-contained.
- **1.1.1** (2026-08-05): Made multi-variable conversion atomic and cleared incidental `r()` state on return.

<details><summary>Earlier versions</summary>

- **1.1.0** (2026-06-25): Added the `diagnose` option, which reports distinct unconvertible values, their frequencies, and observation numbers when conversion fails.
- **1.0.1** (2026-06-19): Documentation fixes — `df()` and `drop` now render as options in the help file, added section markers, and standardized the author string.
- **1.0.0** (2026-04-08): Initial release with auto-detection, `newvar()`, custom display formats, and `topyear()` support.

</details>

## Author

Timothy P Copeland, Karolinska Institutet

Questions and bug reports: [GitHub issues](https://github.com/tpcopeland/Stata-Tools/issues). Please include the first line of `which datefix` and your Stata version.

To cite: Copeland TP. *datefix: Imported date strings to Stata dates*. Stata-Tools, https://github.com/tpcopeland/Stata-Tools/tree/main/datefix. Please give the version you used (`which datefix` prints it).

## License

MIT (see [LICENSE](../LICENSE))
