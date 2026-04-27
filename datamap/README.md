# datamap — Privacy-safe dataset maps and Markdown dictionaries

**Version 1.0.0** | 2026-04-08

`datamap` documents Stata datasets without exporting row-level data. It produces two kinds of output:

- **`datamap`** writes a structured plain-text file designed to be pasted into an LLM prompt, attached to an internal data handoff, or fed into an automated pipeline. It includes privacy controls (`exclude()`, `datesafe`), automatic structure detection (panel, survival, survey), data quality flags, and missing-data summaries.
- **`datadict`** writes a Markdown data dictionary suitable for GitHub, documentation sites, or conversion to PDF/Word/HTML via Pandoc. It includes document metadata (`title()`, `author()`, `version()`), optional missing-value and statistics columns, and a table of contents when documenting multiple datasets.

Both commands preserve the dataset in memory, accept the same input modes (data in memory, a single `.dta` file, a directory scan, or a named file list), and handle the `.dta` extension automatically.

## Requirements

- Stata 16 or later
- [Pandoc](https://pandoc.org/) (optional) — only needed if you want to convert `datadict` Markdown output to PDF, HTML, or Word

## Installation

```stata
capture ado uninstall datamap
net install datamap, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/datamap") replace
```

## Commands

| Command    | Output format | Purpose |
|------------|---------------|---------|
| `datamap`  | Plain text    | LLM context, internal documentation, QA, privacy-controlled sharing |
| `datadict` | Markdown      | GitHub repos, report appendices, Pandoc conversion, IRB submissions |

## How It Works

1. **Choose the input source.** Load data into memory (the default), or point at a file with `single()`, a folder with `directory()`, or a list of names with `filelist()`.
2. **Pick the output command.** Use `datamap` for plain text or `datadict` for Markdown.
3. **Layer on options.** Add privacy controls (`exclude()`, `datesafe`), detection features (`autodetect`, `detect(panel survival)`), quality checks (`quality`), or missing-data analysis (`missing(detail)`) to `datamap`. Add document metadata (`title()`, `author()`) and descriptive statistics (`stats`, `missing`) to `datadict`.
4. **Write the output.** One combined file by default, or separate files per dataset with `separate`.

## Worked Examples

### 1. Quick text map from data in memory

The fastest starting point. `datamap` inspects the current dataset and writes a text summary to `datamap.txt`.

```stata
sysuse auto, clear
datamap
```

### 2. Quick Markdown dictionary from data in memory

```stata
sysuse auto, clear
datadict
```

This writes `data_dictionary.md` in the current directory.

### 3. Privacy controls with detection and quality checks

For sensitive data, exclude identifiers, suppress exact dates, and enable diagnostics:

```stata
sysuse auto, clear
datamap, exclude(make) quality missing(detail) autodetect output(auto_map.txt)
```

### 4. Markdown dictionary with statistics and metadata

`datadict` is the presentation-oriented companion. Add document metadata and optional columns:

```stata
sysuse auto, clear
datadict, output(auto_dictionary.md) ///
    title("Auto Data Dictionary") ///
    author("Timothy P Copeland, Karolinska Institutet") ///
    missing stats
```

### 5. Document a saved dataset by filename

Both commands work on `.dta` files without loading them first:

```stata
sysuse auto, clear
save auto_example.dta, replace

datamap, single(auto_example) output(auto_example_map.txt)
datadict, single(auto_example) output(auto_example_dict.md) title("Saved auto")
```

### 6. Scale up to a directory

Document every `.dta` file in a folder — combined or one file per dataset:

```stata
datamap, directory("analysis_data") recursive output(project_map.txt)
datadict, directory("analysis_data") recursive separate
```

## Feature Reference

### datamap options

| Category | Options |
|----------|---------|
| Input | `single()`, `directory()`, `filelist()`, `recursive` |
| Output | `output()`, `format()`, `separate`, `append` |
| Content | `nostats`, `nofreq`, `nolabels`, `maxfreq()`, `maxcat()` |
| Privacy | `exclude()`, `datesafe`, `dateformat()` |
| Detection | `detect()`, `autodetect`, `panelid()`, `survivalvars()` |
| Quality | `quality`, `quality2(strict)`, `missing(detail\|pattern)` |
| Sample data | `samples()` |

### datadict options

| Category | Options |
|----------|---------|
| Input | `single()`, `directory()`, `filelist()`, `recursive` |
| Output | `output()`, `separate` |
| Metadata | `title()`, `subtitle()`, `version()`, `author()`, `date()` |
| Content | `notes()`, `changelog()`, `missing`, `stats`, `maxcat()`, `maxfreq()`, `dateformat()` |

### Variable classification (both commands)

| Priority | Condition | Class |
|----------|-----------|-------|
| 1 | Listed in `exclude()` | Excluded |
| 2 | String type (`str#`, `strL`) | String |
| 3 | Date format (`%t*`, `%d*`) | Date |
| 4 | Value labels or ≤ `maxcat()` unique values | Categorical |
| 5 | Everything else | Continuous |

## Choosing Between the Commands

- **`datamap`** when you need a technical inventory: LLM context windows, internal handoffs, automated pipelines, or privacy-controlled documentation.
- **`datadict`** when you need a publication-quality Markdown document: GitHub repositories, report appendices, IRB submissions, or Pandoc conversion.
- Use **`separate`** with either command when each dataset should get its own output file.
- Start with a single dataset; switch to **`directory()`** + **`recursive`** once the output looks right.

## Author

Timothy P Copeland, Karolinska Institutet
