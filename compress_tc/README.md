# compress_tc

![Stata 13+](https://img.shields.io/badge/Stata-13%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

Maximally compress string variables via strL conversion.

## Description

`compress_tc` performs two-stage compression of string variables:

1. Converts fixed-length `str#` variables to variable-length `strL`
2. Runs `compress` to find optimal storage types

The `strL` type stores strings in a compressed heap, which can dramatically reduce memory for datasets with long strings, repeated values, or both. The subsequent `compress` step reverts short unique strings to `str#` format if that proves more efficient.

If varlist is not specified, `compress_tc` operates on all variables.

This command is particularly effective for:
- Datasets with many repeated string values (e.g., categorical data stored as strings)
- Variables with long strings (e.g., addresses, descriptions, notes)
- Variables with many missing/empty values

## Installation

```stata
net install compress_tc, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/compress_tc")
```

## Syntax

```stata
compress_tc [varlist] [, nocompress nostrl noreport quietly detail]
```

## Options

### Main Options

| Option | Description |
|--------|-------------|
| **nocompress** | Skip the `compress` step; perform strL conversion only |
| **nostrl** | Skip strL conversion; perform standard `compress` only (equivalent to running `compress` directly but with memory reporting) |

### Reporting Options

| Option | Description |
|--------|-------------|
| **noreport** | Suppress `compress`'s detailed per-variable output while still showing summary statistics |
| **quietly** | Suppress all output (results are still stored in `r()`) |
| **detail** | Display the original type of each string variable before conversion |

## Stored Results

`compress_tc` stores the following in `r()`:

**Scalars:**
- `r(bytes_saved)` - total bytes saved
- `r(pct_saved)` - percentage reduction in string data
- `r(bytes_initial)` - initial string data size in bytes
- `r(bytes_final)` - final string data size in bytes

**Macros:**
- `r(varlist)` - variables specified (or all if none specified)

## Examples

### Example 1: Compress all string variables in the dataset

```stata
compress_tc
```

### Example 2: Compress specific variables

```stata
compress_tc name address city
```

### Example 3: Show detailed variable information

```stata
compress_tc, detail
```

### Example 4: Suppress compress output, show only summary

```stata
compress_tc, noreport
```

### Example 5: Standard compress only (no strL conversion)

```stata
compress_tc, nostrl
```

### Example 6: strL conversion only (no compress)

```stata
compress_tc, nocompress
```

### Example 7: Silent operation, access results programmatically

```stata
compress_tc, quietly
display "Saved " r(bytes_saved) " bytes (" %4.1f r(pct_saved) "%)"
```

## Technical Notes

**How strL compression works:** Stata's `strL` type stores strings in a separate heap with deduplication and compression. Identical strings are stored only once, and long strings are compressed using zlib.

**Memory measurement:** The reported byte savings reflect total string data in the dataset (`memory`'s `data_data_u` + `data_strl_u`), not just the specified varlist. This is a limitation of Stata's memory reporting.

**When strL increases size:** For variables with short, unique strings, `strL` may temporarily increase memory due to heap overhead. The subsequent `compress` step detects this and reverts such variables to `str#` format.

**File format note:** Datasets with `strL` variables must be saved in Stata 13+ format (`.dta` version 117 or later). They cannot be saved in older formats.

## Requirements

Stata 13.0 or higher (strL type introduced in Stata 13)


## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

Fork of strcompress by Luke Stein

https://github.com/lukestein/strcompress/

## License

MIT License

## Version

Version 1.0.2, 2025-12-03
