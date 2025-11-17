# today

Set global macros with current date and time.

## Description

today sets two global macros - $today and $today_time - containing the current date and time with customizable formatting. It is convenient for incorporating timestamps into Stata programs, logs, and output files.

## Dependencies

None - uses only built-in Stata commands.

## Installation

```stata
net from https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/today
net install today
```

## Syntax

```stata
today [, df(format) tsep(string) hm from(string) to(string)]
```

### Options

**df(format)** - Date format:
- **ymd** - YYYY_MM_DD (default)
- **dmony** - DD Mon YYYY
- **dmy** - DD/MM/YYYY
- **mdy** - MM/DD/YYYY

**tsep(string)** - Time separator (default: ":")

**hm** - Exclude seconds from time

**from(string)** and **to(string)** - Transform date range

## Examples

```stata
* Set date and time with defaults
today
display "$today"      // 2024_12_19
display "$today_time" // 14:30:25

* Custom date format
today, df(dmony)
display "$today"      // 19 Dec 2024

* Custom time format without seconds
today, hm tsep(.)
display "$today_time" // 14.30

* Use in file naming
today
save "analysis_$today.dta", replace
log using "log_$today_time.log", replace
```

## Global macros created

- **$today** - Current date in specified format
- **$today_time** - Current time in specified format

## Requirements

Stata 14.0 or higher

## Author

Timothy P Copeland

## Help

For more information:
```stata
help today
```
