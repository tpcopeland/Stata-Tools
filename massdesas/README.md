# massdesas — Batch convert SAS datasets to Stata format

**Version 1.0.2** | 2026-08-05

`massdesas` recursively converts SAS `.sas7bdat` datasets to Stata `.dta` files, preserving the directory tree and writing each result beside its source. It is for Stata users who need to batch-convert a collection of SAS files with optional lowercase variable names and controlled source-file deletion.

## Quick Start

Point `directory()` at a folder containing at least one `.sas7bdat` file:

```stata
massdesas, directory("/path/to/sas_files") lower
return list
```

The command writes `.dta` files beside the SAS sources and reports the conversion counts in `r()`. Omit `lower` when imported variable names should retain their original case.

## Requirements

- Stata 14 or later
- Stata's built-in `import sas` command
- The SSC packages `filelist` and `fs`

## Installation

```stata
capture ado uninstall massdesas
net install massdesas, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/massdesas") replace
ssc install filelist, replace
ssc install fs, replace
```

## Commands

| Command | Description |
|---------|-------------|
| `massdesas` | Recursively convert `.sas7bdat` files to sibling `.dta` files |

## How It Works

- If `directory()` is omitted, `massdesas` uses the current working directory.
- The command uses `filelist` to search that root and all subdirectories for files matching `*.sas7bdat`, then uses `fs` to enumerate the files in each directory.
- Each file is imported with `import sas` and saved as a `.dta` file in the same directory with the same base name.
- `lower` passes `case(lower)` to `import sas`, converting imported variable names to lowercase.
- `erase` deletes each original `.sas7bdat` file only after its `.dta` file has been saved successfully.
- The command preserves the caller's data and restores the original current working directory after processing.

## Worked Examples

### 1. Convert files in the current working directory

Change to a directory containing SAS datasets, then omit `directory()` to use `c(pwd)`:

```stata
cd "/path/to/sas_files"
massdesas
return list
```

### 2. Convert a project tree with lowercase variable names

The search includes nested directories, and `lower` standardizes imported variable names:

```stata
massdesas, directory("/path/to/project/raw") lower
return list
```

### 3. Check the conversion summary before inspecting outputs

Use the returned failure count to stop a workflow if any file could not be converted:

```stata
massdesas, directory("/path/to/staging") lower
assert r(n_failed) == 0
display "Converted files: " r(n_converted)
```

### 4. Remove source files after validating a copy

Run `erase` only on a backup or staging copy after confirming that the generated `.dta` files are usable:

```stata
massdesas, directory("/path/to/backup_copy") lower erase
return list
```

## Command Reference

### massdesas

```stata
massdesas [, directory(directory_name) erase lower]
```

The command stops with an error if the root directory does not exist or contains no matching SAS files. When an individual file fails, processing continues and the failure is counted in `r(n_failed)`.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `directory(directory_name)` | Current working directory | Root directory to search recursively for `.sas7bdat` files |
| `erase` | Off | Permanently delete each original SAS file after its conversion succeeds |
| `lower` | Off | Pass `case(lower)` to `import sas` so imported variable names are lowercase |

## Stored Results

After a successful run, `massdesas` stores the following results:

| Result | Type | Description |
|--------|------|-------------|
| `r(n_converted)` | Scalar | Number of SAS files successfully converted |
| `r(n_failed)` | Scalar | Number of SAS files that failed to convert |
| `r(directory)` | Local macro | Root directory used for the conversion |

## Assumptions and Limits

- Only files matching the literal pattern `*.sas7bdat` are searched. On case-sensitive filesystems, files ending in `.SAS7BDAT` are not found.
- Filenames and directory paths containing spaces are supported when the `directory()` path is quoted.
- A nonexistent directory or a directory with no matching SAS files produces an error rather than an empty result set.
- If `filelist` or `fs` is unavailable, the command stops with `r(199)`; install the missing SSC dependency before running it.
- `erase` is permanent and is applied only after a successful `.dta` save; keep a backup until the converted files have been checked.
- Existing `.dta` files with the same base name are overwritten because each converted dataset is saved with `replace`; preserve a copy if existing outputs must be retained.
- Conversion behavior and supported SAS features follow Stata's built-in `import sas` command.

## References

- StataCorp's SAS importer: see `help import sas` in Stata.
- The required SSC utilities: see `help filelist` and `help fs` after installation.

## Version History

- **1.0.2** (2026-08-05): Documented that converted `.dta` outputs overwrite existing same-named files and standardized package author metadata.
- **1.0.1** (2026-08-05): Fixed SAS filename quoting, preserved the complete basename when it contains `.sas7bdat`, and ensured the caller's data are restored after unexpected errors.
- **1.0.0** (2026-04-08): Initial Stata-Tools release

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
