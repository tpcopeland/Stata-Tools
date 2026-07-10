# massdesas - Batch convert SAS datasets to Stata format

**Version 1.0.0** | 2026-07-10

`massdesas` recursively scans a directory tree for `.sas7bdat` files, imports each one into Stata, and writes a sibling `.dta` file with the same base name. It is meant for project folders with many SAS datasets where one-at-a-time conversion would be slow and error-prone.

## Requirements

- Stata 14 or later
- Stata's built-in `import sas`
- `filelist` from SSC
- `fs` from SSC

## Installation

```stata
capture ado uninstall massdesas
net install massdesas, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/massdesas") replace
```

Install the SSC dependencies once if they are not already available:

```stata
ssc install filelist
ssc install fs
```

## Commands

| Command | Description |
|---------|-------------|
| `massdesas` | Recursively convert `.sas7bdat` files to `.dta` files |

## Quick Start

If your current working directory already contains SAS files somewhere under it, this is enough:

```stata
massdesas
```

If the source files live somewhere else and you want imported variable names standardized to lowercase:

```stata
massdesas, directory("/path/to/sas_files") lower
```

## How It Works

- If `directory()` is omitted, `massdesas` uses the current working directory.
- The command searches that root and all subdirectories for files matching `*.sas7bdat`.
- Each matching file is imported with `import sas` and saved as a `.dta` in the same folder.
- `lower` passes `case(lower)` to `import sas`, which converts imported variable names to lowercase.
- `erase` deletes the original `.sas7bdat` file only after a successful conversion.

## Worked Examples

### 1. Convert an entire project tree

```stata
massdesas, directory("/project/raw/sas_files")
```

This recurses through `/project/raw/sas_files`, converts every `.sas7bdat` file it finds, and leaves the `.dta` files beside the SAS sources.

### 2. Convert and normalize variable names to lowercase

```stata
massdesas, directory("/project/raw/sas_files") lower
```

Use this when the source files have mixed-case variable names and you want Stata-style lowercase names throughout the converted outputs.

### 3. Test before erasing the originals

```stata
massdesas, directory("/project/backup_sas_files") lower
use "/project/backup_sas_files/example_file.dta", clear
describe
massdesas, directory("/project/raw/sas_files") lower erase
```

`erase` only removes a `.sas7bdat` file after a successful `.dta` save, but the deletion is still permanent, so it is best used after you validate a backup or staging copy.

## Notes and Limitations

- File pattern matching is case-sensitive on Linux and macOS, so `.SAS7BDAT` files are not found by the default `*.sas7bdat` search.
- Filenames containing spaces are not supported.
- If a file fails to convert, `massdesas` reports the failure and continues with the remaining files.
- If a converted file contains zero observations, the command reports that fact and still saves the `.dta`.

## Version History

- **1.0.0** (2026-04-08): Initial Stata-Tools release

## Author

Timothy P Copeland, Karolinska Institutet
