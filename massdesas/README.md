# massdesas - Batch convert SAS files to Stata datasets

**Version 1.0.0** | 2026-04-08

`massdesas` recursively scans a directory tree for `.sas7bdat` files, imports each one into Stata, and writes a sibling `.dta` file with the same base name. It is meant for project folders with many SAS datasets where one-at-a-time conversion would be slow and error-prone.

## Requirements

- Stata 14 or later
- `filelist` from SSC
- `fs` from SSC
- Stata's built-in `import sas`

## Installation

```stata
ssc install filelist
ssc install fs
capture ado uninstall massdesas
net install massdesas, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/massdesas") replace
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

`massdesas` will search `c(pwd)` recursively and create a `.dta` beside every `.sas7bdat` file it finds.

If your SAS files live in a different folder and you want imported variable names standardized to lowercase:

```stata
massdesas, directory("/path/to/sas_files") lower
```

## How It Works

- If `directory()` is omitted, `massdesas` uses the current working directory.
- The command searches that root and every subdirectory for files matching `*.sas7bdat`.
- Each matching file is imported with `import sas` and saved as a `.dta` in the same folder.
- `lower` passes `case(lower)` to `import sas`, which converts imported variable names to lowercase.
- `erase` deletes the original `.sas7bdat` file only after a successful `.dta` save.

Because the command works on files rather than data already loaded in memory, the examples below use path templates rather than `sysuse` or `webuse` data.

## Worked Examples

### 1. Convert an entire project tree

Use `directory()` when your SAS files live outside the current Stata working directory.

```stata
massdesas, directory("/project/raw/sas_files")
```

This will recurse through `/project/raw/sas_files`, convert every `.sas7bdat` file it finds, and leave the converted `.dta` files in the same folders as their SAS sources.

### 2. Convert and normalize variable names to lowercase

```stata
massdesas, directory("/project/raw/sas_files") lower
```

Use this when your SAS files contain mixed-case variable names and you want Stata-friendly lowercase names throughout the converted files.

### 3. Safer test-before-erase workflow

`erase` is useful, but it should come after you verify that the conversion worked on a backup or staging copy.

```stata
* First, convert a backup copy
massdesas, directory("/project/backup_sas_files") lower

* Inspect at least one converted file
use "/project/backup_sas_files/example_file.dta", clear
describe

* Only then consider removing originals in the real source tree
massdesas, directory("/project/raw/sas_files") lower erase
```

Files are deleted only after successful conversion, but the deletion is still permanent. Keep backups if the original SAS files matter.

### 4. Preserve a nested folder structure automatically

If your input tree looks like this:

```text
/project
  /raw
    baseline.sas7bdat
    followup.sas7bdat
  /derived
    analysis.sas7bdat
```

then this command:

```stata
massdesas, directory("/project") lower
```

produces:

```text
/project
  /raw
    baseline.dta
    followup.dta
  /derived
    analysis.dta
```

The directory layout is preserved; only the file format changes.

## Returned Results

After a run, `massdesas` stores:

- `r(n_converted)` - number of files successfully converted
- `r(n_failed)` - number of files that failed
- `r(directory)` - root directory that was scanned

## Notes and Limitations

- File pattern matching is case-sensitive on Linux and macOS. Files ending in `.SAS7BDAT` rather than `.sas7bdat` will not be found.
- Filenames containing spaces are not supported.
- If a file fails to convert, `massdesas` reports the failure and continues with the remaining files.
- When a converted file contains zero observations, the command reports that fact and still saves the `.dta`.

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
