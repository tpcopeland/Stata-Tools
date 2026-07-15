# datamap — Privacy-safe dataset maps and Markdown dictionaries

**Version 1.6.1** | 2026-07-15

`datamap` documents Stata datasets without exporting row-level data. It produces four kinds of output:

- **`datamap`** writes structured text or JSON designed for LLM prompts, internal data handoffs, or automated pipelines. It includes privacy controls (`exclude()`, `datesafe`, `mincell()`), likely-identifier warnings, compact output, automatic structure detection (panel, survival, survey), data quality flags, and missing-data summaries.
- **`datadict`** writes a Markdown data dictionary suitable for GitHub, documentation sites, or conversion to PDF/Word/HTML via Pandoc. It includes document metadata (`title()`, `author()`, `version()`), optional missing-value/statistics/detail columns, structured metadata export via `saving()`, manifests, and separate-output routing with `outdir()`/`suffix()`.
- **`datacheck`** profiles a dataset to the console — per-class distributions, missingness, and key-structure/uniqueness — and can gate a do-file on declared expectations (`expectn()`, `isid()`, `inrange()`, `notmissing()`, ...), halting with `r(9)` when reality does not match what you declared.
- **`datamvp`** analyzes missing-value patterns: pattern-frequency tables, monotone-missingness tests for multiple imputation, stratified analysis, and missingness graphics (a fork of Jeroen Weesie's `mvpatterns`). `datacheck`'s `patterns` option calls it.

`datamap`, `datadict`, and `datacheck` share one classification engine. A successful run leaves your data in memory exactly as it found it. `datamap` and `datadict` accept data in memory, a single `.dta` file, a directory scan, or a named file list; `datadict` also accepts line-delimited manifests for path-safe batch dictionaries.

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
| `datamap`  | Plain text or JSON | LLM context, internal documentation, QA, privacy-controlled sharing, automated metadata pipelines |
| `datadict` | Markdown      | GitHub repos, report appendices, Pandoc conversion, IRB submissions |
| `datacheck`| Console (+ optional saved profile) | Interactive QC, distribution review, key/uniqueness checks, expectation gates before an analysis or export |
| `datamvp`  | Console + graphics | Missing-value pattern tables, monotone-missingness tests, stratified analysis, missingness graphs |

## How It Works

1. **Choose the input source.** Load data into memory (the default), or point at a file with `single()`, a folder with `directory()`, or a list of names with `filelist()`.
2. **Pick the output command.** Use `datamap` for plain text or `datadict` for Markdown.
3. **Layer on options.** Add privacy controls (`exclude()`, `datesafe`, `mincell()`), classifier overrides (`continuous()`, `categorical()`, `date()`/`datevars()`), reusable project defaults (`config()`), compact output (`compact`), JSON output (`format(json)`), or structured metadata export (`saving()`). Use `datacheck compare()` to detect schema drift against a saved profile.
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

### 4. JSON for a metadata pipeline

```stata
sysuse auto, clear
datamap, format(json) output(auto_map.json)
```

### 5. Markdown dictionary with statistics and metadata

`datadict` is the presentation-oriented companion. Add document metadata and optional columns:

```stata
sysuse auto, clear
datadict, output(auto_dictionary.md) ///
    title("Auto Data Dictionary") ///
    author("Timothy P Copeland, Karolinska Institutet") ///
    missing stats
```

Write structured metadata alongside the Markdown dictionary:

```stata
sysuse auto, clear
datadict price mpg foreign, output(auto_dictionary.md) ///
    detail missing stats datasignature ///
    saving(auto_dictionary_meta, replace)
```

### 6. Document a saved dataset by filename

Both commands work on `.dta` files without loading them first:

```stata
sysuse auto, clear
tempfile auto_example
save `auto_example', replace

datamap, single("`auto_example'") output(auto_example_map.txt)
datadict, single("`auto_example'") output(auto_example_dict.md) title("Saved auto")
```

### 7. Scale up to a directory

Document every `.dta` file in a folder — combined or one file per dataset:

```stata
datamap, directory("analysis_data") recursive output(project_map.txt)
datadict, directory("analysis_data") recursive separate outdir("docs") suffix("_dict")
```

### 8. Interactive QC and an expectation gate with `datacheck`

`datacheck` profiles the data to the console — distributions, missingness, and key structure — and can gate a do-file on declared expectations. Run it as the last line before an analysis:

```stata
sysuse auto, clear

* Descriptive: classify, profile by type, report missingness and key structure
datacheck, id(make)

* Gated: halt the do-file unless the data matches what you declared
datacheck, expectn(74) isid(make) notmissing(mpg weight) inrange(mpg 10 50)
```

The gate evaluates every expectation, prints all violations at once, and exits with `r(9)` (Stata's assertion code) on any failure — or add `warn` to report violations without halting while you build the script.

## Demo

The v1.6 demo script (`datamap/demo/demo_datamap.do`) builds a 1,200-observation synthetic cohort so capped cardinalities are visible, installs `datamap` from the local package manifest, verifies every generated artifact, checks that the frame-based in-memory paths leave `datasignature` unchanged, and converts console logs to Markdown with `logdoc`.

Run it from the Stata-Tools repo root:

```bash
stata-mp -b do datamap/demo/demo_datamap.do
```

Generated artifacts include:

- privacy-warning, privacy-safe, compact, and missingness maps (`demo/datamap_warning.txt`, `demo/datamap_clinical.txt`, `demo/datamap_compact.txt`, and `demo/datamap_missing.txt`)
- structured JSON metadata (`demo/datamap_metadata.json`)
- Markdown dictionaries (`demo/datadict_auto.md` and `demo/datadict_clinical.md`)
- seven `console_*.md` transcripts generated by `logdoc`
- the reproducible `_demo_cohort.dta` and `_demo_missing.dta` fixtures
- the `datamvp` missingness graph (`demo/missingness_bar.png`)

### Capped Cardinality, Privacy, And In-Memory Safety

The first map deliberately leaves identifier-like variables unexcluded. With 1,200 distinct IDs, v1.6's default `uniqcap(1000)` stops counting once the lower bound is known and prints `>1000` rather than an invented exact cardinality.

<details>
<summary>Privacy warning and capped-count output</summary>

```stata
. datamap, single("datamap/demo/_demo_cohort.dta") ///
>     output("datamap/demo/datamap_warning.txt") ///
>     mincell(5) noguidance compact
```

```
warning: likely identifier variable(s) not in exclude(): patient_id subject_id patient_name
Output written to: datamap/demo/datamap_warning.txt
```

```
DISCLOSURE RISK SUMMARY
-----------------------
Excluded variables: 0
Small-cell threshold: 5
Date-safe mode: off
Likely identifiers not excluded: patient_id subject_id patient_name

QUICK REFERENCE
----------------------------------------
  Variable                Type      Class          Miss%  Unique
  patient_id              double    continuous      0.0%   >1000
  subject_id              double    continuous      0.0%   >1000
  patient_name            str32     string          0.0%   >1000
  birth_date              double    date            0.0%   >1000
```

</details>

The demo also exercises the new no-snapshot in-memory path and fails if the data signature changes:

```stata
. use "datamap/demo/_demo_cohort.dta", clear
. quietly datasignature
. local map_signature "`r(datasignature)'"
. tempfile map_integrity
. quietly datamap, output("`map_integrity'.txt") ///
>     exclude(patient_id subject_id patient_name) ///
>     datesafe mincell(5) autodetect quality samples(3) missing(detail)
. quietly datasignature
. assert "`map_signature'" == "`r(datasignature)'"
```

```
In-memory integrity check: datamap left the datasignature unchanged
```

The shipped privacy-safe map then excludes identifiers, suppresses exact dates and small cells, detects common/survival structures, and includes aggregate sample rows.

<details>
<summary>Privacy-safe map excerpt</summary>

```stata
. datamap, single("datamap/demo/_demo_cohort.dta") ///
>     output("datamap/demo/datamap_clinical.txt") ///
>     exclude(patient_id subject_id patient_name) ///
>     datesafe mincell(5) autodetect quality samples(3) missing(detail)
```

```
DISCLOSURE RISK SUMMARY
-----------------------
Excluded variables: 3
Small-cell threshold: 5
Date-safe mode: on
Likely identifiers not excluded: 0

Survival Analysis Variables Detected
  Likely time variables: follow_up_time
  Likely event indicators: event
    event rate: 27.3%

Missing Data Summary
  Variables with >50% missing: 0
  Variables with >10% missing: 3
  Observations with complete data: 624 (52%)

Suppressed frequency cells:
    9 = Satellite clinic: suppressed (<5)
    1 = Present: suppressed (<5)
```

</details>

### JSON Metadata

`format(json)` exposes the censoring contract directly. The demo lowers `uniqcap()` to 100 so the flag is easy to see in a small fixture: `unique_values` is the lower bound 101 and `unique_values_capped` tells consumers that it is not exact.

<details>
<summary>JSON metadata output</summary>

```stata
. datamap, single("datamap/demo/_demo_cohort.dta") ///
>     output("datamap/demo/datamap_metadata.json") ///
>     format(json) exclude(patient_id subject_id patient_name) ///
>     datesafe mincell(5) quality missing(detail) uniqcap(100)
```

```json
{
  "name": "age",
  "classification": "continuous",
  "missing_n": 0,
  "missing_pct": 0,
  "unique_values": 101,
  "unique_values_capped": true
}
```

</details>

### Compact Maps And Markdown Dictionaries

`compact` retains the disclosure summary and quick-reference table. `datadict` uses the same capped counter and reports the high-cardinality string honestly as `>1000 unique values`.

<details>
<summary>Compact map and dictionary output</summary>

```stata
. datamap, single("datamap/demo/_demo_cohort.dta") ///
>     output("datamap/demo/datamap_compact.txt") ///
>     compact exclude(patient_id subject_id patient_name) datesafe mincell(5)
```

```
QUICK REFERENCE
----------------------------------------
  Variable                Type      Class          Miss%  Unique
  patient_id              double    excluded        0.0%       .
  subject_id              double    excluded        0.0%       .
  patient_name            str32     excluded        0.0%       .
  age                     double    continuous      0.0%     450
  birth_date              double    date            0.0%   >1000
```

```stata
. datadict, single("datamap/demo/_demo_cohort.dta") ///
>     output("datamap/demo/datadict_clinical.md") ///
>     title("SYNTH-01 Clinical Trial Data Dictionary") ///
>     subtitle("Synthetic cohort for demonstration purposes") ///
>     version("1.1") ///
>     author("Timothy P Copeland, Karolinska Institutet") ///
>     missing stats dateformat(%tdDD/NN/CCYY)
```

```markdown
| Variable | Label | Type | Missing | Statistics/Values |
|---|---|---|---|---|
| `patient_name` | Patient full name | String | 0 (0.0%) | N=1200; >1000 unique values |
```

```
In-memory integrity check: datadict left the datasignature unchanged
```

</details>

### Console QC And Expectation Gates (`datacheck`)

`datacheck` profiles the cohort, uses the shared capped-cardinality display, and then evaluates declared expectations. The fixture includes one impossible age, adherence above 100%, a rare site, and missing values so both QC flags and gate violations are visible.

<details>
<summary>QC profile and gate output</summary>

```stata
. datacheck patient_id age sex smoking bmi pct_adherence site, ///
>     id(patient_id) outliers(3) rare(5)
```

```
datacheck: 1200 obs, 7 variables profiled  (complete cases: 760 = 63.3%)

QUICK REFERENCE
  Variable              Class       Type       Miss%   Unique  Flag
  patient_id            continuous  double      0.0%    >1000
  age                   continuous  double      0.0%      450  outliers
  sex                   categorical double      0.0%        2
  smoking               categorical double     15.7%        3  missing
  bmi                   continuous  double      7.6%      238  missing
  pct_adherence         continuous  double     19.3%      534  missing
  site                  categorical double      0.0%        7  rare
```

```stata
. datacheck age pct_adherence, expectn(1200) isid(patient_id) ///
>     notmissing(age sex) inrange(age 18 110 \ pct_adherence 0 100) warn
```

```
WARNINGS (2)
  inrange(age): 1 obs outside [18, 110]  (min -3, max 97.7)
  inrange(pct_adherence): 110 obs outside [0, 100]  (min 25.1, max 147.3)
```

With `warn`, violations are reported and execution continues; omit it to halt with `r(9)`.

</details>

### Missing-Value Patterns (`datamvp`)

`datamvp` tabulates which variables are jointly missing and tests whether the pattern is monotone, the condition needed for sequential multiple imputation. `datacheck`'s `patterns` option calls the same engine.

![Missingness by variable](demo/missingness_bar.png)

<details>
<summary>Pattern table and monotone test</summary>

```stata
. datamvp x1 x2 x3 x4, percent sort
```

```
Missing value patterns

  +----------------------------------+
  | _pattern   _miss   _freq    _pct |
  |----------------------------------|
  |     ++++       0      38   47.50 |
  |     ++.+       1      14   17.50 |
  |     ..++       2       8   10.00 |
  |     .+++       1       7    8.75 |
  |     ..+.       3       7    8.75 |
  |     ....       4       3    3.75 |
  |     ...+       3       2    2.50 |
  |     .+.+       2       1    1.25 |
  +----------------------------------+

Total observations:              80
Complete cases:                  38  ( 47.5%)
Unique patterns:                  8
```

```stata
. datamvp x1 x2 x3 x4, monotone
```

```
Monotone missingness test:
  Observations with monotone pattern:       41 ( 51.2%)
  Pattern is non-monotone
```

</details>

## Feature Reference

### datamap options

| Category | Options |
|----------|---------|
| Input | `single()`, `directory()`, `filelist()`, `recursive` |
| Output | `output()`, `format(text\|json)`, `separate`, `append` (text only), `saving()` |
| Project defaults | `config()` |
| Content | `nostats`, `nofreq`, `nolabels`, `maxfreq()`, `maxcat()`, `uniqcap()`, `noguidance`, `compact` |
| Privacy | `exclude()`, `datesafe`, `dateformat()`, `mincell()` |
| Classification | `continuous()`, `categorical()`, `date()` |
| Detection | `detect()`, `autodetect`, `panelid()`, `survivalvars()` |
| Quality | `quality`, `quality2(strict)`, `missing(detail\|pattern)` |
| Sample data | `samples()` |

### datadict options

| Category | Options |
|----------|---------|
| Input | `single()`, `directory()`, `filelist()`, `recursive` |
| Output | `output()`, `separate` |
| Metadata | `title()`, `subtitle()`, `version()`, `author()`, `date()` |
| Content | `notes()`, `changelog()`, `missing`, `stats`, `maxcat()`, `maxfreq()`, `uniqcap()`, `mincell()`, `dateformat()` |
| Technical metadata | `detail`, `columns()`, `datasignature`, `saving()` |
| Batch/project workflow | `manifest()`, `outdir()`, `suffix()`, `config()` |
| Privacy/classification | `exclude()`, `continuous()`, `categorical()`, `datevars()` |

### datacheck additions

| Category | Options |
|----------|---------|
| Project defaults | `config()` |
| Schema drift | `compare()` |
| Metadata export | `saving()` with the shared metadata schema |

## Options

This table is the complete public option contract for the flagship `datamap`
command. See the command-specific help files for the companion commands.

| Option | Purpose |
|--------|---------|
| `append` | Append text output to an existing file. |
| `autodetect` | Enable all structure detectors. |
| `categorical` | Force variables to the categorical class. |
| `compact` | Produce a compact map and omit guidance prose. |
| `config` | Read reusable project defaults from a configuration file. |
| `continuous` | Force variables to the continuous class. |
| `date` | Force variables to the date class. |
| `dateformat` | Set the display format for dates. |
| `datesafe` | Show date spans instead of exact dates. |
| `detect` | Select structure detectors. |
| `directory` | Scan a directory for Stata datasets. |
| `exclude` | Document variables without values or statistics. |
| `filelist` | Process a space-separated dataset list. |
| `format` | Choose text or JSON output. |
| `maxcat` | Set the categorical-classification threshold. |
| `maxfreq` | Cap displayed category frequencies. |
| `uniqcap` | Report unique counts above this as `>#` instead of counting exactly; `0` counts exactly. Default 1000. |
| `mincell` | Suppress small frequency cells. |
| `missing` | Include detailed or patterned missingness output. |
| `nofreq` | Suppress categorical frequency tables. |
| `noguidance` | Suppress analysis guidance prose. |
| `nolabels` | Suppress value-label definitions. |
| `nostats` | Suppress continuous-variable summary statistics. |
| `output` | Name the generated map file. |
| `panelid` | Specify the panel identifier for detection. |
| `quality` | Enable basic quality flags. |
| `quality2` | Enable strict quality flags. |
| `recursive` | Include subdirectories in a directory scan. |
| `samples` | Include a limited number of sample rows. |
| `saving` | Save standardized metadata alongside the map. |
| `separate` | Write one output file per input dataset. |
| `single` | Process one saved dataset. |
| `survivalvars` | Specify candidate survival variables. |

## Stored Results

After a successful `datamap` run, the following `r()` results describe the
combined output or the single in-memory dataset.

| Result | Meaning |
|--------|---------|
| `r(categorical_vars)` | Categorical variable names. |
| `r(continuous_vars)` | Continuous variable names. |
| `r(date_vars)` | Date variable names. |
| `r(excluded_vars)` | Excluded variable names. |
| `r(format)` | Output format. |
| `r(input_source)` | Input mode. |
| `r(metadata)` | Standardized metadata file, when `saving()` is used. |
| `r(mincell)` | Small-cell threshold. |
| `r(n_categorical)` | Number of categorical variables. |
| `r(n_continuous)` | Number of continuous variables. |
| `r(n_date)` | Number of date variables. |
| `r(n_excluded)` | Number of excluded variables. |
| `r(n_string)` | Number of string variables. |
| `r(n_suggested_exclude)` | Number of likely identifiers not excluded. |
| `r(nfiles)` | Number of documented datasets. |
| `r(nobs)` | Observation count for a single or in-memory dataset. |
| `r(nvars)` | Variable count for a single or in-memory dataset. |
| `r(output)` | Combined output filename. |
| `r(string_vars)` | String variable names. |
| `r(suggested_exclude)` | Likely identifiers not excluded. |

### Variable classification (datamap, datadict, datacheck)

| Priority | Condition | Class |
|----------|-----------|-------|
| 1 | Listed in `exclude()` | Excluded |
| 2 | Listed in `continuous()`, `categorical()`, or `date()`/`datevars()` | Forced class |
| 3 | String type (`str#`, `strL`) | String |
| 4 | Date format (`%t*`, `%d*`) | Date |
| 5 | Value labels or ≤ `maxcat()` unique values | Categorical |
| 6 | Everything else | Continuous |

## Choosing Between the Commands

- **`datamap`** when you need a technical inventory: LLM context windows, internal handoffs, automated pipelines, or privacy-controlled documentation.
- **`datadict`** when you need a publication-quality Markdown document: GitHub repositories, report appendices, IRB submissions, or Pandoc conversion.
- **`datacheck`** when you need to eyeball distributions interactively or enforce expectations: run it as the last line before an analysis or export and have it stop the do-file when the data does not match what you declared.
- **`datamvp`** when you need to understand the *structure* of missingness: which patterns occur, whether they are monotone (relevant for multiple imputation), and how missingness varies across groups.
- Use **`separate`** with `datamap`/`datadict` when each dataset should get its own output file.
- Start with a single dataset; switch to **`directory()`** + **`recursive`** once the output looks right.

## Privacy Notes

- `datamap` suppresses categorical and binary frequency cells smaller than `mincell()`; the default is `mincell(5)`.
- Set `mincell(0)` only after reviewing disclosure risk.
- `datamap` warns when variable names look like identifiers but are not listed in `exclude()`.
- `samples()` prints raw rows by design; excluded variables are masked, and date variables are suppressed when `datesafe` is specified.

## QA

Run the full Stata QA suite from the package root:

```bash
cd qa
stata-mp -b do run_all.do
```

The suite covers all four public commands with 17 QA files: 15 functional test
files, 2 validation files, and no cross-validation suite (the package is a
deterministic documentation and QC tool, so known-answer validations are the
appropriate oracle).

- `test_datacheck.do`, `test_datadict_v14.do`, and `test_datamap*.do`
- `test_datamvp.do` and `test_datamvp_labels.do`
- `validation_datamap.do` and `validation_datamvp.do`
- `qa/README.md` has the complete file index, coverage map, and lane contract.

## Changelog

### 1.6.1 (2026-07-15)

Further reduced peak memory for exact distinct counts. When `uniqcap(0)` (or an internal panel/event/strata unit count) requests an exact cardinality, `_datamap_nuniq` now reads the column through a Mata view instead of a full copy, so no full-length column copy is allocated before the sort. Measured on a 20M-row double column: peak RSS 997MB → 845MB (one column copy eliminated), with the same counts and no speed change. No user-visible output changes.

### 1.6.0 (2026-07-14)

Large-file performance. On a 3M-row, 60-variable dataset `datamap` went from 201s to 50s; the dominant per-variable cost, the distinct-value count, dropped from 55% of runtime to near zero for continuous and ID variables.

- Unique counts are now **censored above `uniqcap()` (default 1000)** and reported as `>1000` rather than counted exactly. Counting a continuous or ID variable exactly requires sorting every observation; capping lets the counter stop after seeing `uniqcap`+1 distinct values. Measured on a 20M-row double column: 27.0s and 866MB peak → 0.16s and 398MB.
- New `uniqcap(#)` option (also a config key). `uniqcap(0)` restores exact counts at any cardinality, at the old cost. The cap is always raised to at least `maxcat()` and `maxfreq()`, so a censored count can never change a variable's classification or hide its frequency table. Panel unit counts under `detect(panel)` are always exact.
- JSON gains `unique_values_capped`; when true, `unique_values` is a lower bound, not an exact count. The saved metadata dataset (`saving()`) gains a matching `unique_capped` column.
- The report writers now read the classification table in a **frame** instead of under `preserve`. `preserve` costs a full in-memory copy of the dataset, and eleven of these fired per run purely to read a small lookup table. `datamap, single("file.dta")` on an 826MB file dropped from 1.92GB to 1.01GB peak memory.
- `datadict` counted distinct values with `egen tag()`, which **sorts the whole dataset once per variable** — the very pattern the shared counter was written to replace. It now uses that counter, and gains the same `uniqcap()` option. On the 3M × 60 file `datadict` went from 348s to 135s. Its `saving()` dataset gains the `unique_capped` column.
- `datacheck` also picks up the shared cap; its console unique counts render as `>1000` when censored.
- **`datamap` and `datadict` no longer `preserve` when documenting the data already in memory.** A `preserve` is a full second copy of the dataset in memory; skipping it roughly halves peak memory. Pre-loading an 826MB file and running `datamap` went from **1.92GB to 1.01GB** peak — the same as `single()` mode now. Everything that used to rely on the snapshot runs in a frame instead (the report writers, and the `saving()` metadata export, which previously left the *metadata table* in memory and depended on `restore` to put your data back).

  A successful run still leaves the data bit-identical — same observations, variables, sort order, labels, notes, characteristics, and `datasignature`. The trade-off is that a run which **fails partway through is no longer rolled back**. `single()`, `directory()`, `filelist()`, and `manifest()` still preserve, because those genuinely load a file over your data and must restore it.

**Reading a large file: let `datamap` open it.** `datamap, single("big.dta")` from an empty session peaks at about 1.2× the file size. Running `use big.dta` first and then `datamap` still costs about 2.3×, because the top-level `preserve` that guarantees your data is restored must copy it.

### 1.5.4 (2026-07-10)

- Restore `datadict`'s documented privacy default: categorical cells with counts below 5 are suppressed unless `mincell(0)` is requested explicitly.
- Reject explicit or configured negative thresholds in `datadict` and `datacheck` instead of silently treating them as omitted options.
- Reject invalid `datamvp` pattern-frequency bounds and graph-only options that previously succeeded as silent no-ops.
- Stop option-like text inside quoted titles and output paths from being misread as numeric options.

### 1.5.3 (2026-07-10)

- Add regression coverage for the existing `datamvp` write-path guards and complete the remaining
  `datacheck` option/return coverage (`by()`, `maxcat()`, `maxfreq()`, and
  `r(onlyflagged)`).
- Add the package QA guide, complete the flagship README option/result contract,
  and wrap long help-file prose for the Stata Viewer.

### 1.5.2 (2026-07-09)

- Fix `format(json)` aborting with `r(198)` whenever a reported number was negative and smaller than 1 in magnitude (any continuous variable with, say, a mean of `-0.03`). JSON output was unusable on most real datasets.
- Large datasets now map several times faster. Classification counted distinct values with `tabulate`, which builds a full frequency table and aborts above ~12k levels, then fell back to `duplicates report`, which sorts the whole dataset once per variable. Both are replaced by a single-column `uniqrows()` count. On a 500k x 60 dataset, `datamap` drops from ~25s to ~9s; the classification pass itself drops from ~20s to ~4s.
- Fix inflated `unique_values` for high-cardinality numeric variables containing missing values: the `duplicates report` fallback counted `.` and `.a`-`.z` as distinct values, while low-cardinality variables (counted with `tabulate`) excluded them. All numeric counts now exclude missing.

### 1.5.1 (2026-07-08)

- Fix crashes (`r(198)`) on datasets with long variable names: per-variable locals keyed by variable name overflowed Stata's 31-character macro-name limit in `datacheck`, `datamap`/`datacheck` `saving()`, `datamap` `samples()` and value-label output, and `datamvp`.
- Fix `r(134)` crashes on high-cardinality identifier/design variables: `datamap` panel/survey/survival detection and the dataset summary now count distinct values without `tabulate`, and the panel-structure fallback no longer relies on a statistic `codebook, compact` never stores.
- Fix `datamvp`'s `generate()` silently overwriting one indicator when two long variable names truncated to the same stub, and its leak of `set varabbrev off` on the no-missing-values exit path.
- Fix privacy-safe documentation dropping `$name`/backtick text from variable, value, and data labels in both text and JSON output.
- `datamap` now rejects negative `maxfreq()`/`maxcat()`/`mincell()`/`samples()` at every legal abbreviation instead of silently substituting the default.
- Internal: `datamap` JSON output derives its version from the package header (no drift); removed a permanent "File modified: unavailable" line from `datadict`; removed unused legacy code.

### 1.5.0 (2026-06-19)

- Add shared classifier overrides across `datamap`, `datadict`, and `datacheck`: `continuous()`, `categorical()`, `date()` for `datamap`/`datacheck`, and `datevars()` for `datadict`.
- Add shared project `config()` parsing for reusable privacy, classification, and threshold defaults.
- Add `datamap saving()` and align `datamap`, `datadict`, and `datacheck` metadata exports on a common variable-level schema.
- Add `datacheck compare()` to detect added, dropped, type-changed, class-changed, and row-count drift against a saved profile or raw dataset.
- Extend `datadict` privacy controls with `exclude()` and `mincell()` suppression.
- Add v1.5 regression QA for metadata schema, privacy suppression, classifier overrides, config loading, and schema comparison.

### 1.4.1 (2026-06-19)

- Fix float-formatting in text output: rounded statistics, percentages, and sample-row values no longer leak full double precision (e.g. `49.40000000000001%` now renders `49.4%`). Affects `datamap` continuous distributions, panel/survival/survey detection, the missing-data summary, and sample observations.

## Author

Timothy P Copeland, Karolinska Institutet
