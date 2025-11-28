# compress_tc

Stata command for maximum string variable compression via strL conversion.

## Install

```stata
net install compress_tc, from("https://raw.githubusercontent.com/USERNAME/compress_tc/main/")
```

## Syntax

```
compress_tc [varlist] [, nocompress nostrl noreport quietly detail]
```

## What it does

Two-stage compression:
1. Convert `str#` → `strL` (heap storage with deduplication + zlib compression)
2. Run `compress` to find optimal types (reverts short unique strings to `str#`)

Best for: repeated strings, long strings, sparse string data.

## Options

| Option | Effect |
|--------|--------|
| `nocompress` | strL conversion only, skip compress |
| `nostrl` | Standard compress only, skip strL |
| `noreport` | Hide compress's per-variable output |
| `quietly` | Suppress all output |
| `detail` | Show variable types before conversion |

## Returns

| r() | Description |
|-----|-------------|
| `r(bytes_saved)` | Total bytes saved |
| `r(pct_saved)` | Percentage reduction |
| `r(bytes_initial)` | Initial string data bytes |
| `r(bytes_final)` | Final string data bytes |
| `r(varlist)` | Variables processed |

## Examples

```stata
compress_tc                      // all string variables
compress_tc name address         // specific variables
compress_tc, noreport            // summary only
compress_tc, nostrl              // standard compress only
compress_tc, quietly             // silent, use r() for results
display r(bytes_saved)           // access saved bytes
```

## Notes

- Requires Stata 13+ (strL introduced in v13)
- Memory stats reflect total string data, not just specified varlist
- strL datasets require Stata 13+ format (.dta v117+)
- strL may temporarily increase size for short unique strings; compress fixes this


## Author

Timothy P Copeland
Department of Clinical Neuroscience
Karolinska Institutet

Fork of strcompress by Luke Stein (lcdstein@babson.edu) 

https://github.com/lukestein/strcompress/
