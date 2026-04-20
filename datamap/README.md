# datamap - Privacy-safe dataset maps and Markdown dictionaries

**Version 1.0.0** | 2026-04-08

`datamap` documents Stata datasets without exporting row-level data. Use `datamap` for a plain-text inventory that can be made privacy-conscious with options such as `exclude()` and `datesafe`, and use `datadict` for Markdown data dictionaries you can commit to GitHub or convert into reports. Both commands preserve the dataset in memory and support data in memory, a single `.dta`, a directory scan, or a named file list.

## Requirements

- Stata 16 or later
- Pandoc is optional if you want to convert `datadict` output to PDF, HTML, or Word

## Installation

```stata
capture ado uninstall datamap
net install datamap, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/datamap") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `datamap` | Generate text documentation for one or more datasets with privacy controls when needed |
| `datadict` | Generate Markdown data dictionaries from the same input sources |

## How It Works

1. Choose the input source: the dataset in memory, `single()`, `directory()`, or `filelist()`.
2. Decide whether you need a technical map (`datamap`) or a publication-ready Markdown dictionary (`datadict`).
3. Add privacy or content controls such as `exclude()`, `datesafe`, `missing()`, `quality`, `missing`, or `stats` depending on the command.
4. Write one combined output file or separate files for each dataset.

## Choosing a Command

- Use `datamap` when you want a technical inventory for LLM context, internal data handoff, or QA.
- Use `datadict` when you want a Markdown artifact for repositories, appendices, or Pandoc conversion.
- Use `separate` when each dataset should get its own output file.
- Use `directory()` plus `recursive` once the single-dataset workflow is behaving the way you want.

## Worked Examples

### 1. Create a text map from the dataset in memory

This is the fastest starting point. `datamap` inspects the current dataset, preserves it, and writes a text summary.

```stata
sysuse auto, clear
datamap
```

### 2. Add privacy controls, missing-data reporting, and quality checks

For sensitive data, start by excluding identifiers and then layer on the extra diagnostics you want in the text output.

```stata
sysuse auto, clear
datamap, exclude(make) quality missing(detail) output(auto_map.txt)
```

### 3. Create a Markdown data dictionary from the same dataset

`datadict` is the presentation-oriented companion command. It adds document metadata and optional missingness or descriptive-statistics columns.

```stata
sysuse auto, clear
datadict, output(auto_dictionary.md) ///
    title("Auto Data Dictionary") ///
    author("Timothy P Copeland, Karolinska Institutet") ///
    missing stats
```

### 4. Document a saved dataset by filename

The same commands work when the data are not already loaded into memory.

```stata
sysuse auto, clear
save auto_example.dta, replace

datamap, single(auto_example.dta) output(auto_example.txt)
datadict, single(auto_example.dta) output(auto_example.md) ///
    title("Saved auto example")
```

### 5. Scale up to a project directory

Once the single-dataset workflow looks right, switch to directory mode and decide whether you want a combined output file or one file per dataset.

```stata
datamap, directory("analysis_data") recursive output(project_map.txt)
datadict, directory("analysis_data") recursive separate
```

## Feature Highlights

- Automatic variable classification into categorical, continuous, date, string, or excluded variables
- Privacy controls through `exclude()` and `datesafe` when exact identifiers or dates are sensitive
- Multiple input modes for data in memory, one file, a directory, or a named file list
- Missing-data summaries and quality checks in `datamap`
- Markdown document metadata in `datadict` through `title()`, `subtitle()`, `version()`, `author()`, and `date()`

## Author

Timothy P Copeland, Karolinska Institutet
