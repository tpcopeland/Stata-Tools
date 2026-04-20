# datamap

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

Privacy-safe dataset documentation and Markdown data dictionaries for Stata.

The package installs two commands:

| Command | Purpose | Output |
| --- | --- | --- |
| `datamap` | Privacy-safe dataset documentation with summary statistics, detection features, and quality checks | Plain text (`.txt`) |
| `datadict` | Markdown data dictionaries for GitHub, reports, and Pandoc conversion | Markdown (`.md`) |

Both commands preserve the dataset in memory, classify variables automatically, and support documenting data in memory, a single `.dta` file, a directory of datasets, or a named file list.

## Installation

```stata
capture ado uninstall datamap
net install datamap, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/datamap") replace
help datamap
help datadict
```

## How It Works

`datamap` and `datadict` solve related but different problems:

- Use `datamap` when you want a privacy-safe technical inventory for LLM context, code review, or internal data handoff.
- Use `datadict` when you want a polished Markdown codebook for a repository, report appendix, or documentation site.

The commands share the same basic workflow:

1. Choose the input source: the data already in memory, `single()`, `directory()`, or `filelist()`.
2. Decide how much information to expose: full summary, reduced detail, or privacy-hardened output with `exclude()` and related options.
3. Write one combined file or separate files, depending on whether you are documenting a single dataset or a larger project.

## Worked Examples

### 1. Document a built-in dataset already in memory

This is the simplest starting point. `datamap` inspects the active dataset and writes a text summary without changing the data in memory.

```stata
sysuse auto, clear
datamap
```

### 2. Add privacy controls, missingness, and quality checks

For sensitive data, start by excluding identifiers and then layer on the quality and missing-data summaries.

```stata
sysuse auto, clear
datamap, exclude(make) quality missing(detail) output(auto_map.txt)
```

### 3. Write a Markdown data dictionary from the same dataset

`datadict` is the presentation-oriented companion command. Use it when you want a human-readable Markdown artifact rather than a plain-text technical inventory.

```stata
sysuse auto, clear
datadict, output(auto_dictionary.md) ///
    title("Auto Data Dictionary") ///
    version("1.0") ///
    author("Timothy P Copeland, Karolinska Institutet") ///
    missing stats
```

### 4. Save a dataset and document it by filename

The same commands also work when the data are not already loaded into memory.

```stata
sysuse auto, clear
save auto_example.dta, replace

datamap, single(auto_example.dta) output(auto_example.txt)
datadict, single(auto_example.dta) output(auto_example.md) title("Saved auto example")
```

### 5. Scale up to a project directory

Use directory mode once the single-dataset workflow is behaving as expected.

```stata
datamap, directory("analysis_data") recursive output(project_map.txt)
datadict, directory("analysis_data") recursive separate
```

## Command-Specific Highlights

### `datamap`

- Privacy controls: `exclude()`, `datesafe`, `nostats`, `nofreq`, `nolabels`
- Structure detection: `detect(panel survival survey binary common)` or `autodetect`
- Data quality: `quality` or `quality2(strict)`
- Missing-data review: `missing(detail)` or `missing(pattern)`
- Optional sample rows: `samples(#)` for carefully controlled examples
- Output currently supports text mode via `format(text)`

### `datadict`

- Markdown metadata: `title()`, `subtitle()`, `version()`, `author()`, `date()`
- Optional narrative inputs: `notes()`, `changelog()`
- Enhanced table detail: `missing` and `stats`
- Combined or per-dataset output with `separate`
- Pandoc-friendly Markdown that can be converted to PDF, HTML, or Word

### Shared input and output patterns

- `single()`: one dataset
- `directory()`: all `.dta` files in a folder
- `filelist()`: a specific list of datasets
- `recursive`: traverse subdirectories
- `output()`: combined output filename
- `separate`: one output file per dataset
- `maxcat()` and `maxfreq()`: control how categorical detail is summarized

## Returned Results

`datamap` stores:

- Scalars: `r(nfiles)`, `r(nobs)`, `r(nvars)`
- Macros: `r(format)`, `r(output)`, `r(input_source)`

`datadict` stores:

- Scalar: `r(nfiles)`
- Macro: `r(output)`

## Screenshots

### `datamap` console output

![datamap Console Output](demo/console_datamap.png)

### `datadict` console output

![datadict Console Output](demo/console_datadict.png)

## Requirements

- Stata 16 or newer
- No external package dependencies

## Detailed Help

For full syntax, option details, and the `.sthlp` examples:

```stata
help datamap
help datadict
```

## Version

**Version**: 1.0.0

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT License

## See Also

- Built-in Stata commands: `describe`, `codebook`, `labelbook`, `summarize`
- External tool: [Pandoc](https://pandoc.org) for converting Markdown dictionaries to PDF, HTML, or Word
