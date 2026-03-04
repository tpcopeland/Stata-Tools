# today

![Stata 14+](https://img.shields.io/badge/Stata-14%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

Set global macros with today's date and current time, with customizable formatting.

## Description

`today` sets two global macros (`$today` and `$today_time`) containing the current date and time respectively. It offers flexible formatting options for both date and time components, making it convenient for incorporating the current date and time into Stata programs, logs, and output files.

By default, it uses the "ymd" format for the date (YYYY_MM_DD), a colon (":") as the time separator, and includes seconds in the time.

## Dependencies

None - uses only built-in Stata commands.

## Installation

```stata
net install today, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/today")
```

## Syntax

```stata
today [, df(string) tsep(string) hm from(string) to(string)]
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| **df(string)** | ymd | Date format (see below) |
| **tsep(string)** | : | Time separator between hours, minutes, and seconds |
| **hm** | *(off)* | Include only hours and minutes, omitting seconds |
| **from(string)** | *(computer timezone)* | Source timezone in UTC format (e.g., UTC+7 or UTC-5); must be specified with `to()` |
| **to(string)** | *(computer timezone)* | Target timezone in UTC format (e.g., UTC+7 or UTC-5); must be specified with `from()` |

### Date Format Options (df)

| Format | Example Output | Description |
|--------|----------------|-------------|
| **ymd** | 2024_12_19 | YYYY_MM_DD (default) |
| **dmony** | 19 Dec 2024 | DD Mon YYYY |
| **dmy** | 19/12/2024 | DD/MM/YYYY |
| **mdy** | 12/19/2024 | MM/DD/YYYY |

## Global Macros Created

| Macro | Contains |
|-------|----------|
| **$today** | Current date, formatted according to the `df()` option |
| **$today_time** | Current date and time, formatted according to the `df()` and `tsep()` options, including or excluding seconds based on the `hm` option |

## Examples

### Example 1: Default format

```stata
today
display "$today"
* Output: 2024_12_19

display "$today_time"
* Output: 2024_12_19 14:30:45
```

### Example 2: Custom date format

```stata
today, df(dmony)
display "$today"
* Output: 19 Dec 2024

display "$today_time"
* Output: 19 Dec 2024 14:30:45
```

### Example 3: Custom time format

```stata
today, df(mdy) tsep(.)
display "$today"
* Output: 12/19/2024

display "$today_time"
* Output: 12/19/2024 14.30.45
```

### Example 4: Hours and minutes only

```stata
today, hm tsep(-)
display "$today"
* Output: 2024_12_19

display "$today_time"
* Output: 2024_12_19 14-30
```

### Example 5: Timezone conversion

```stata
* Computer is in UTC+1, convert to UTC-7
today, from(UTC+1) to(UTC-7)
display "$today_time"
* Output will show time adjusted by -8 hours
```

### Example 6: Use in file naming

```stata
* Create timestamped filenames
today
save "analysis_$today.dta", replace
log using "log_$today_time.log", replace

* Or with custom format for shorter names
today, hm tsep(-)
export excel using "export_$today_time.xlsx", replace
```

### Example 7: Add timestamp to graph titles

```stata
today, df(dmony)
twoway scatter y x, title("Analysis Run: $today")
graph export "plot_$today.png", replace
```

### Example 8: Complete workflow with timestamps

```stata
* Start analysis with timestamp
today, df(dmony) hm
display "Analysis started: $today_time"

* Your analysis code here
use mydata, clear
summarize

* Save results with timestamp
today
save "results_$today.dta", replace

* Create log file
log using "analysis_log_$today_time.log", text replace
* Analysis commands...
log close
```

### Example 9: International date formats

```stata
* US format
today, df(mdy)
display "$today"  // 12/19/2024

* European format
today, df(dmy)
display "$today"  // 19/12/2024

* ISO 8601-like format
today, df(ymd)
display "$today"  // 2024_12_19
```

## Use Cases

### Timestamped Output Files
Create unique filenames for each analysis run:
```stata
today
export delimited using "export_$today.csv", replace
```

### Log File Management
Automatically name log files with date and time:
```stata
today, hm
log using "analysis_$today_time.log", replace
```

### Data Processing Timestamps
Add creation timestamps to datasets:
```stata
today
gen str20 created_date = "$today"
label variable created_date "Dataset creation date"
```

### Report Headers
Include current date in analysis output:
```stata
today, df(dmony)
display _newline(2) "Report generated: $today" _newline(2)
```

## Requirements

Stata 14.0 or higher

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## Version

Version 1.0.1, 2025-12-03

## See Also

- `display c(current_date)` - Built-in current date
- `display c(current_time)` - Built-in current time
- `date()` - Date functions
- `clock()` - Time functions
