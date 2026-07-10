# compress_tc - Two-stage compression for string-heavy Stata data

**Version 1.1.0** | 2026-07-10

`compress_tc` aggressively reduces memory use in string-heavy datasets by first converting fixed-width string variables to `strL`, then running Stata's built-in `compress` so short or unique strings can move back to ordinary storage when that is smaller. It is a fork of Luke Stein's `strcompress` with additional reporting, option control, and safer validation.

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
| `compress_tc` | Convert fixed-width string variables to `strL`, then optimize storage with `compress` |

## Quick Start

Use a built-in dataset first to see the command shape. `auto` has one string variable, `make`, so the example is simple but fully runnable.

```stata
sysuse auto, clear
compress_tc make, detail
display "Saved " r(bytes_saved) " bytes (" %4.1f r(pct_saved) "%)"
```

In a real string-heavy dataset, the savings are usually much larger than in `sysuse auto`.

## How It Works

- Stage 1 converts the requested `str#` variables to `strL` unless you specify `nostrl`.
- Stage 2 runs `compress` unless you specify `nocompress`.
- `detail` shows the original string storage types before conversion, while `varsavings` reports a per-variable before/after byte table with the savings.
- `lowmem` recasts and compresses one variable at a time so peak memory is bounded by the largest single variable, not the whole dataset.
- `dryrun` reports the projected savings without permanently changing the data.
- `minlength(#)` skips strL conversion for short fixed-length strings that `compress` would just revert anyway.
- `noreport` suppresses `compress`'s detailed output but still shows the summary. `quietly` suppresses all output while preserving `r()`.
- Reported sizes use the most readable unit (KB, MB, or GB).
- Memory reporting is dataset-wide because Stata's `memory` command reports dataset-wide usage.

## Worked Examples

### 1. Compress every string variable in memory

If you omit a varlist, `compress_tc` scans the whole dataset and processes every fixed-width string variable it finds.

```stata
sysuse auto, clear
compress_tc
```

### 2. Inspect which variables changed

`detail` shows the original types before conversion. `varsavings` adds a per-variable summary after compression.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/prescriptions.dta", clear
compress_tc atc drug_name, detail varsavings
```

This is the most useful pattern when you want to understand where the memory savings are coming from.

### 3. Compare the two stages separately

Use `nocompress` to isolate the `strL` conversion, or `nostrl` to keep only ordinary `compress` behavior with the same reporting layer.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/procedures.dta", clear
compress_tc kva_code proc_description, nocompress

use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/procedures.dta", clear
compress_tc kva_code proc_description, nostrl
```

### 4. Run quietly inside a larger workflow

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
| `lowmem` | Convert and compress one variable at a time to cap peak memory |
| `dryrun` | Report projected savings without modifying the data |
| `minlength(#)` | Only convert `str#` variables at least `#` bytes wide to `strL` |
| `noreport` | Suppress `compress`'s per-variable output while keeping the summary |
| `quietly` | Suppress all output while still returning results in `r()` |
| `detail` | Show each processed string variable's original storage type |
| `varsavings` | Show a per-variable before/after byte table with savings |

## Returned Results

`compress_tc` stores the following in `r()`:

- `r(bytes_saved)`: total bytes saved
- `r(pct_saved)`: percentage reduction in data size
- `r(bytes_initial)`: initial data size in bytes
- `r(bytes_final)`: final data size in bytes
- `r(bytes_strl)`: bytes held in the `strL` heap after compression
- `r(k_converted)`: number of variables recast to `strL`
- `r(k_reverted)`: number of those that `compress` moved back to a fixed type
- `r(vars_strl)`: variables stored as `strL` after compression
- `r(varlist)`: string variables actually processed

## Technical Notes

- `strL` storage is especially useful for repeated values, long text, and sparse strings.
- For variables with short, unique strings, `strL` can temporarily increase memory use. The second-stage `compress` call is what re-optimizes those cases.
- Datasets that contain `strL` variables must be saved in Stata 13+ `.dta` format.

## Version History

- **1.1.0** (2026-06-19): `varsavings` now reports real per-variable before/after bytes and savings; added `lowmem` (peak-memory-safe incremental conversion), `dryrun` (preview without modifying data), and `minlength(#)` (skip strL for short strings). Sizes display in the most readable unit (KB/MB/GB). New stored results `r(bytes_strl)`, `r(k_converted)`, `r(k_reverted)`, `r(vars_strl)`.
- **1.0.0** (2026-04-08): Initial Stata-Tools release of the two-stage string-compression workflow.

## Author

Timothy P Copeland, Karolinska Institutet

Fork of `strcompress` by Luke Stein.
