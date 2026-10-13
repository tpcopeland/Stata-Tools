<p align="center"><img src="../_resources/logos/massdesas_hex.svg" width="150" alt="massdesas hex logo"></p>

# massdesas — Convert a tree of SAS datasets to Stata

**Version 1.0.3** | 2026-10-13

[![version](https://img.shields.io/badge/version-1.0.3-1a5f91?style=flat-square)](#version-history) [![Stata 14+](https://img.shields.io/badge/Stata-14%2B-1a5f91?style=flat-square)](#requirements) [![MIT license](https://img.shields.io/badge/license-MIT-1a5f91?style=flat-square)](../LICENSE) [![Part of Stata-Tools](https://img.shields.io/badge/part%20of-Stata--Tools-0e3a5a?style=flat-square)](../README.md)

**[Quick Start](#quick-start)** · **[Installation](#installation)** · **[Options](#options)** · **[Stored Results](#stored-results)** · **[Stata-Tools](../README.md)** · **[Report a bug](https://github.com/tpcopeland/Stata-Tools/issues)**

`massdesas` recursively converts SAS `.sas7bdat` datasets to Stata `.dta` files, preserving the directory tree and writing each result beside its source. It is for Stata users who need to batch-convert a collection of SAS files with optional lowercase variable names and controlled source-file deletion.

## Quick Start

After [installing](#installation) it and its two SSC dependencies, point `directory()` at a folder containing at least one `.sas7bdat` file:

```stata
massdesas, directory("/path/to/sas_files") lower
return list
```

The command writes `.dta` files beside the SAS sources, including those in subfolders, and reports the conversion counts in `r()`. Omit `lower` when imported variable names should retain their original case.

## Features

- **The whole tree, in place.** Every `*.sas7bdat` under the root and its subdirectories is imported with `import sas` and saved beside its source under the same base name, replacing any existing `.dta` of that name.
- **One bad file does not stop the batch.** A file that fails is counted in `r(n_failed)` and the rest are still converted; a missing root or a root with no SAS files is an error, not an empty success.
- **Sources deleted only on success.** With `erase`, each `.sas7bdat` is removed only after its `.dta` has been saved.
- **Your session is left as found.** The data in memory and the working directory are restored afterwards.

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

## Options

```stata
massdesas [, directory(directory_name) erase lower]
```

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

## QA

QA suites and how to run them are documented in [`qa/README.md`](qa/README.md).

## Version History

- **1.0.3** (2026-10-13): The internal `cd`, `filelist`, `replace`, and `levelsof` calls no longer print to the console (lines such as `file ... saved as .dta format` and `(0 real changes made)` preceded the summary); the `Conversion complete` summary and failure messages are unchanged.
- **1.0.2** (2026-08-05): Documented that converted `.dta` outputs overwrite existing same-named files and standardized package author metadata.
- **1.0.1** (2026-08-05): Fixed SAS filename quoting, preserved the complete basename when it contains `.sas7bdat`, and ensured the caller's data are restored after unexpected errors.
- **1.0.0** (2026-04-08): Initial Stata-Tools release

## Author

Timothy P Copeland, Karolinska Institutet

Questions and bug reports: [GitHub issues](https://github.com/tpcopeland/Stata-Tools/issues). Please include the first line of `which massdesas` and your Stata version.

To cite: Copeland TP. *massdesas: Convert a tree of SAS datasets to Stata*. Stata-Tools, https://github.com/tpcopeland/Stata-Tools/tree/main/massdesas. Please give the version you used (`which massdesas` prints it).

## License

MIT (see [LICENSE](../LICENSE))
