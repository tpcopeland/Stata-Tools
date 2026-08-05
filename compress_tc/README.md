# compress_tc — Two-stage compression for string-heavy Stata data

**Version 1.1.1** | 2026-08-05

`compress_tc` reduces memory use in string-heavy Stata datasets by converting fixed-width strings to `strL` and then running Stata's built-in `compress`. It is for users who want a reportable way to apply or preview string-storage changes while retaining the resulting `r()` values.

## Quick Start

After installation, run a two-stage compression and inspect the dataset-wide result:

```stata
sysuse auto, clear
compress_tc make, detail
display "Saved " r(bytes_saved) " bytes (" %4.1f r(pct_saved) "%)"
```

`make` is a fixed-width string variable in `auto`; `detail` prints its original storage type. The final summary and `r()` values report total data-memory changes, which can be positive or negative.

## Requirements

- Stata 16 or later

## Installation

Install the released package from Stata-Tools:

```stata
capture ado uninstall compress_tc
net install compress_tc, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/compress_tc") replace
```

For a local Stata-Tools checkout, replace the URL with the package directory:

```stata
capture ado uninstall compress_tc
net install compress_tc, from("/path/to/Stata-Tools/compress_tc") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `compress_tc` | Two-stage compression for selected string variables, with reporting and memory controls |

## How It Works

By default, `compress_tc` applies two stages to the selected scope:

1. It identifies eligible fixed-width `str#` variables and recasts them to `strL`. `minlength(#)` can exclude variables whose declared width is below the threshold.
2. It runs Stata's `compress` on the selected varlist, allowing short or unique strings to return to `str#` when that uses less memory.

If `varlist` is omitted, stage 1 scans all variables for fixed-width strings and stage 2 follows Stata's no-varlist `compress` behavior. With a varlist, both stages are limited to that selection. `nostrl` skips stage 1, `nocompress` skips stage 2, and those options cannot be combined.

`dryrun` preserves the original dataset after the projected run, while the stored results still describe what the run would have achieved. `lowmem` converts and compresses one eligible variable at a time; its peak-memory benefit requires the final `compress` stage and it has no effect when `nostrl` skips conversion.

The summary uses Stata's dataset-wide `memory` totals (`data_data_u` + `data_strl_u`), not only the variables named in `varlist`. A negative `r(bytes_saved)` or `r(pct_saved)` means that the final total is larger, which can happen when `strL` overhead exceeds the savings.

## Worked Examples

### 1. Compress every variable in memory

When you omit `varlist`, stage 1 considers every fixed-width string variable and the final `compress` call follows its no-varlist behavior.

```stata
sysuse auto, clear
compress_tc
return list
```

### 2. Inspect selected string variables

The repository's prescription data provide a larger string-heavy example. `detail` shows the original types and `varsavings` adds a per-variable memory table.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/prescriptions.dta", clear
compress_tc atc drug_name, detail varsavings
```

### 3. Compare the two stages

Use `nocompress` to see the effect of `strL` conversion alone, or `nostrl` to run ordinary `compress` without the conversion stage.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/procedures.dta", clear
compress_tc kva_code proc_description, nocompress

use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/procedures.dta", clear
compress_tc kva_code proc_description, nostrl
```

The first run can show a negative byte change because it stops before `compress` can re-optimize short or unique strings.

### 4. Use the summary inside a workflow

`quietly` suppresses normal output but leaves the summary in `r()` for programmatic use.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/prescriptions.dta", clear
compress_tc, quietly
display "Dataset-wide change: " r(bytes_saved) " bytes (" %4.1f r(pct_saved) "%)"
return list
```

### 5. Preview a constrained low-memory run

This combination previews the result, converts eligible variables one at a time, and only converts fixed-width strings at least 20 bytes wide.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/procedures.dta", clear
compress_tc kva_code proc_description, dryrun lowmem minlength(20)
```

## Demo

From the Stata-Tools repository root, run [`demo/demo_compress_tc.do`](demo/demo_compress_tc.do):

```stata
do compress_tc/demo/demo_compress_tc.do
```

The demo writes a disposable SMCL log and is not part of the `net install` payload.

## Command Reference

### `compress_tc`

```stata
compress_tc [varlist] [, nocompress nostrl noreport quietly detail varsavings lowmem dryrun minlength(#)]
```

`varlist` is optional. The minimum option abbreviations accepted by the command are `noc`, `nos`, `nor`, `q`, `d`, `vars`, `low`, `dry`, and `min`. `minlength(#)` accepts a non-negative integer and defaults to `0`. Specifying both `nocompress` and `nostrl` exits with error 198 because it would disable both stages.

## Key Options

| Option | Default | Effect |
|--------|---------|--------|
| `nocompress` | off | Skip the final `compress` stage and keep only the `strL` conversion |
| `nostrl` | off | Skip `strL` conversion and run standard `compress` only |
| `noreport` | off | Suppress the per-variable output emitted by `compress` while retaining the summary |
| `quietly` | off | Suppress normal output while retaining stored results in `r()` |
| `detail` | off | When stage 1 runs, show each eligible fixed-width string variable's original storage type |
| `varsavings` | off | Show per-variable type transitions and before/after memory; default batch mode shows shared `strL` heap bytes as a dash |
| `lowmem` | off | Convert and, unless `nocompress` is specified, compress one eligible variable at a time |
| `dryrun` | off | Restore the original data after a projected run while retaining projected stored results |
| `minlength(#)` | `0` | Convert only `str#` variables at least `#` bytes wide; skipped variables still reach final `compress` when that stage runs |

When `lowmem` performs `strL` conversion, `varsavings` uses measured whole-dataset deltas for each variable and therefore includes its `strL` heap effect. The final `compress` stage is required for the peak-memory benefit, but not for this measurement. Without `lowmem`, a shared `strL` heap cannot be attributed to individual variables and is displayed as a dash.

## Stored Results

`compress_tc` is an r-class command and stores the following results.

### Scalars

| Result | Contents |
|--------|----------|
| `r(bytes_saved)` | Total data bytes saved, equal to `r(bytes_initial) - r(bytes_final)` and possibly negative |
| `r(pct_saved)` | Percentage reduction in total data size |
| `r(bytes_initial)` | Dataset-wide data bytes before the run |
| `r(bytes_final)` | Dataset-wide data bytes after the run, or after the projected run with `dryrun` |
| `r(bytes_strl)` | Bytes held in the `strL` heap after the run or projected run |
| `r(k_converted)` | Number of eligible fixed-width string variables recast to `strL` |
| `r(k_reverted)` | Number of those variables that the final `compress` stage moved back to a fixed-width type |

### Local macros

| Result | Contents |
|--------|----------|
| `r(vars_strl)` | Names of selected string variables stored as `strL` after the run |
| `r(varlist)` | Names in the command's processing scope: fixed-width strings by default, or all string variables with `nostrl` |

## Assumptions and Limits

- Memory totals are dataset-wide because they come from Stata's `memory` command; they do not isolate the variables named in `varlist`.
- Short, unique strings can temporarily use more memory as `strL`; the second-stage `compress` call can revert them to `str#` when that is more efficient.
- Datasets containing `strL` variables must be saved in Stata 13+ `.dta` format (version 117 or later).
- On an empty dataset or a dataset with zero data memory, the command returns zero scalar values and empty local macros.

## Version History

- **1.1.1** (2026-08-05): Corrected the `detail`, `lowmem`, per-variable savings, size-unit, and demo documentation.
- **1.1.0** (2026-06-19): `varsavings` now reports real per-variable before/after bytes and savings; added `lowmem` (incremental conversion that limits peak memory when the final `compress` stage runs), `dryrun` (preview without modifying data), and `minlength(#)` (skip strL for short strings). Sizes display in the most readable unit (B/KB/MB/GB). New stored results `r(bytes_strl)`, `r(k_converted)`, `r(k_reverted)`, `r(vars_strl)`.
- **1.0.0** (2026-04-08): Initial Stata-Tools release of the two-stage string-compression workflow.

## Author

Timothy P Copeland, Karolinska Institutet

This package is a fork of `strcompress` by Luke Stein.

## License

MIT License
