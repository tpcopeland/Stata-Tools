# compress_tc - Maximal string compression via strL conversion

**Version 1.0.0** | 2026-04-08

`compress_tc` is a small utility for aggressively shrinking string-heavy Stata datasets. It first converts eligible `str#` variables to `strL`, then runs Stata's built-in `compress` so short or unique strings can move back to ordinary fixed-width storage when that is more efficient.

This package is a maintained fork of Luke Stein's `strcompress` with additional options, reporting, and error handling.

## Requirements

- Stata 16 or later

## Installation

```stata
capture ado uninstall compress_tc
net install compress_tc, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/compress_tc") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `compress_tc` | Convert string variables to `strL`, then optimize storage with `compress` |

## Quick Start

Use a built-in dataset first to see the command shape. `auto` has one string variable, `make`, so the example is simple but fully runnable:

```stata
sysuse auto, clear
compress_tc make, detail
display "Saved " r(bytes_saved) " bytes (" %4.1f r(pct_saved) "%)"
```

In a real string-heavy dataset, the savings are usually much larger than in `sysuse auto`.

## How It Works

`compress_tc` has two stages:

1. Convert the requested string variables from fixed-width `str#` storage to `strL`.
2. Run `compress` unless you request `nocompress`.

That combination matters because `strL` is excellent for long, repeated, or sparse strings, but Stata's ordinary string types can still be smaller for short unique values. `compress_tc` tries both approaches in sequence and reports the net result.

## Worked Examples

### 1. Compress every string variable in memory

If you omit a varlist, `compress_tc` scans the whole dataset and processes every string variable it finds.

```stata
sysuse auto, clear
compress_tc
```

### 2. Inspect which variables changed

`detail` shows the original string types before conversion. `varsavings` adds a per-variable summary after compression.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/prescriptions.dta", clear
compress_tc atc drug_name, detail varsavings
```

This is the most useful pattern when you want to understand where the memory savings are coming from.

### 3. Compare the two stages separately

Use `nocompress` to see the effect of the `strL` conversion alone, or `nostrl` to keep only ordinary `compress` behavior with the same reporting machinery.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/procedures.dta", clear
compress_tc kva_code proc_description, nocompress

use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/procedures.dta", clear
compress_tc kva_code proc_description, nostrl
```

### 4. Use the command quietly inside a larger workflow

`quietly` suppresses console output but still leaves the summary results in `r()`.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/prescriptions.dta", clear
compress_tc, quietly
return list
```

## Key Options

| Option | What it does |
|--------|---------------|
| `nocompress` | Skip the final `compress` step and keep only the `strL` conversion |
| `nostrl` | Skip the `strL` conversion and run ordinary `compress` only |
| `noreport` | Suppress `compress`'s per-variable output while keeping the summary |
| `quietly` | Suppress all output while still returning results in `r()` |
| `detail` | Show each processed string variable's original storage type |
| `varsavings` | Show a per-variable summary after compression |

## Returned Results

`compress_tc` stores the following in `r()`:

- `r(bytes_saved)`: total bytes saved
- `r(pct_saved)`: percentage reduction in data size
- `r(bytes_initial)`: initial data size in bytes
- `r(bytes_final)`: final data size in bytes
- `r(varlist)`: string variables actually processed

## Technical Notes

- `strL` storage is especially useful for repeated values, long text, and sparse strings.
- Reported byte savings are dataset-wide because Stata's memory accounting is dataset-wide.
- A `strL` variable requires Stata 13+ `.dta` format if you later save the dataset.

## Version History

- **1.0.0** (2026-04-08): Current Stata-Tools release
