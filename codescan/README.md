# codescan

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

`codescan` scans wide-format diagnosis, procedure, medication, or other code variables using anchored regex or prefix rules. It can return row-level indicators or counts, collapse to one row per patient, or merge patient-level summaries back onto encounter-level data.

The package ships:

| Command | Purpose |
| --- | --- |
| `codescan` | Main scanning command |
| `codescan_describe` | Reconnaissance command for inspecting the raw code inventory |

Bundled code dictionaries:

| File | Purpose |
| --- | --- |
| `charlson_icd10_example.csv` | Charlson ICD-10 definitions with Quan 2011 weights |
| `elixhauser_icd10_example.csv` | Elixhauser ICD-10 definitions with van Walraven 2009 weights |

## Installation

```stata
net install codescan, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/codescan")
help codescan
help codescan_describe
```

## What `codescan` does

- Scans any number of wide-format code slots in one pass.
- Accepts inline rules through `define()` or reusable dictionaries through `codefile()`.
- Supports backward and forward windows relative to an index date.
- Creates row-level flags or counts, patient-level collapsed summaries, or merged patient-level results.
- Returns date summaries, co-occurrence matrices, and Charlson/Elixhauser/custom scores.
- Exports summary tables to `.csv` or `.xlsx` and can save the final result dataset to `.dta`.

## Typical workflow

Most users will get oriented faster if they use `codescan` in this order:

1. Inspect the raw code inventory with `codescan_describe`.
2. Draft and test a simple `define()` specification at the row level.
3. Decide whether the finished output should stay row-level, `collapse` to one row per patient, or `merge` patient-level results back to encounters.
4. Add windows, date summaries, hierarchy rules, scoring, and export/save options only after the basic matches look right.

The usual progression is:

```stata
codescan_describe dx1-dx30
codescan dx1-dx30, define(dm2 "E11" | htn "I1[0-35]")
codescan dx1-dx30, id(pid) date(visit_dt) refdate(index_dt) ///
    define(dm2 "E11" | htn "I1[0-35]") lookback(365) collapse alldates
```

## Quick start

The block below is copy-paste runnable after installation. Re-run the setup block before examples that replace the dataset in memory.

### Setup

```stata
clear
input long pid str6 dx1 str6 dx2 str6 proc1 double visit_dt double index_dt
1 "E110" "I10"  "XF001" 21914 21915
1 "Z00"  "E119" ""      21880 21915
2 "I50"  ""     "JFB10" 21900 21915
2 "E102" ""     ""      22020 21915
3 "Z00"  ""     ""      21910 21915
end
format visit_dt index_dt %td
```

### Row-level indicators

```stata
codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]" | chf "I50")
```

### Patient-level collapse with a lookback window and date summaries

```stata
codescan dx1 dx2, id(pid) date(visit_dt) refdate(index_dt) ///
    define(dm2 "E11" | htn "I1[0-35]" | chf "I50") ///
    lookback(365) inclusive collapse alldates
```

### Prefix matching for procedure codes

```stata
codescan proc1, define(mammo "XF001|XF002" | colectomy "JFB|JFH") mode(prefix)
```

### Save an inline rule set, then reuse it as a codefile

```stata
codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") save(dm_rules.csv)
codescan dx1 dx2, codefile(dm_rules.csv)
```

### Charlson scoring with the bundled codefile

```stata
codescan dx1 dx2, codefile(charlson_icd10_example.csv) id(pid) collapse ///
    score(charlson) ///
    hierarchy(dm_comp > dm_uncomp \ liver_severe > liver_mild \ metastatic > cancer)
```

### Export a formatted summary and save the final result dataset

```stata
codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") id(pid) collapse ///
    export(codescan_results.xlsx) ///
    saving(codescan_results.dta, replace) ///
    format(%9.2f)
```

### Inspect the code inventory before writing rules

```stata
codescan_describe dx1 dx2, top(10)
codescan_describe dx1 dx2, save(chapter_rules.csv)
```

## Matching rules and important behaviors

- `regex` is the default mode. Patterns are anchored at the start of the code value, so `define(dm2 "E11")` matches `E110` and `E119`, not `AE11`.
- `prefix` mode uses simple startswith comparisons and is usually faster when regex features are unnecessary.
- Exclusion patterns are written with `~`, for example `define(dm2 "E11" ~ "E116")`.
- Exclusions are evaluated per code value. An excluded value is ignored, but it does not wipe out a valid match found in another variable on the same row.
- `nodots` strips periods during matching without modifying the stored data.
- `nocase` uppercases patterns and code values internally for case-insensitive matching.
- `countmode` changes the created variables from 0/1 indicators to integer counts. Prevalence in `r(summary)` still refers to the proportion of observations or patients with a count greater than zero.

## Windows and aggregation

- `lookback(#)` uses the interval `[refdate - #, refdate)` by default.
- `lookforward(#)` uses the interval `(refdate, refdate + #]` by default.
- `inclusive` includes `refdate` in a single-direction window.
- Using both `lookback()` and `lookforward()` automatically includes `refdate`.
- Rows with missing `date()` or `refdate()` are excluded whenever windowing is used.
- `collapse` reduces the data to one row per `id()`.
- `merge` computes patient-level results and attaches them back to the original row structure.
- `earliestdate`, `latestdate`, and `countdate` require `date()` plus `collapse` or `merge`.
- `alldates` is shorthand for all three date-summary options.

## Public options by task

### Definition sources

- `define(string asis)`: inline rules such as `define(dm2 "E11" | htn "I1[0-35]")`
- `codefile(string)`: CSV or `.dta` code dictionary with required `name` and `pattern` columns
- `label(string asis)`: human-readable variable labels
- `save(filename)`: write parsed `define()` rules to a reusable CSV

### Result dataset shape

- `collapse`: one row per `id()`
- `merge`: patient-level outputs merged back to row-level data
- `preserve`: restore the original data after the command finishes
- `frame(name)`: store the final result dataset in a named frame
- `saving(filename [, replace])`: save the final result dataset to disk

### Matching behavior

- `mode(regex|prefix)`: choose the matching engine
- `level(#)`: truncate prefix tokens before matching in prefix mode
- `nocase`: case-insensitive matching
- `nodots`: strip periods during matching
- `tostring`: convert numeric code variables to string before scanning
- `generate(prefix)`: prefix all created variable names, including the score variable
- `replace`: overwrite existing output variables or frames, but never a scan variable listed in `varlist`
- `noisily`: display progress notes

### Diagnostics and reporting

- `detail`: return per-variable contribution counts in `r(varcounts)`
- `cooccurrence`: return a pairwise co-occurrence matrix
- `graph`: draw a prevalence bar chart
- `export(filename)`: export the summary table to `.csv` or `.xlsx`
- `format(%fmt)`: control prevalence and confidence-interval formatting
- `unmatched(name)`: row-level flag for observations with no matches
- `matched_code(name)`: first code value that survived inclusion and exclusion checks

### Scoring

- `score(charlson)`: bundled Charlson mapping
- `score(elixhauser)`: bundled van Walraven Elixhauser mapping
- `score(custom)`: weights from the `weight` column in `codefile()`
- `hierarchy(string)`: superior > inferior rules applied before scoring; intended for patient-level use through `collapse` or `merge`

## Returned results

`codescan` stores:

- Scalars: `r(N)`, `r(n_conditions)`, `r(collapsed)`, `r(merged)`, `r(mode_count)`, `r(lookback)`, `r(lookforward)`, `r(ci_level)`
- Macros: `r(conditions)`, `r(newvars)`, `r(varlist)`, `r(mode)`, `r(nocase)`, `r(generate)`, `r(define)`, `r(codefile)`, `r(id)`, `r(refdate)`, `r(frame)`, `r(score)`
- Matrices: `r(summary)`, `r(codelist)`, `r(varcounts)`, `r(cooccurrence)`, `r(sensitivity)`

Important details:

- `r(N)` is the analyzed sample after `if`/`in` and any active time window. After `collapse` or `merge`, it is the number of unique `id()` values summarized.
- `r(newvars)` lists variables left in memory on exit. It is empty after `preserve` restores the original data.
- With a single `lookback()` value, `r(lookback)` is a scalar. With multiple lookback values, it is a macro and the prevalence comparison is returned in `r(sensitivity)`.

`codescan_describe` stores:

- Scalars: `r(n_unique)`, `r(n_entries)`, `r(n_vars)`
- Macro: `r(varlist)`
- Matrices: `r(top_codes)`, `r(chapters)`

When `codescan_describe` sees observations but every scanned code slot is empty, it still succeeds and returns zero-filled `r(top_codes)` and `r(chapters)` matrices.

## Screenshots

### Row-level scan

![Console output](demo/console_output.png)

### Collapse with time window

![Collapse output](demo/console_collapse.png)

## References

- Quan H, Sundararajan V, Halfon P, et al. (2005). ICD-9-CM and ICD-10 coding algorithms for defining comorbidities in administrative data.
- Quan H, Li B, Couris CM, et al. (2011). Updated Charlson comorbidity weights for risk adjustment.
- van Walraven C, Austin PC, Jennings A, Quan H, Forster AJ. (2009). A point-system adaptation of the Elixhauser comorbidity measure for hospital mortality.

## Requirements

- Stata 16 or newer
- No external package dependencies

## Version

Current version: **1.0.2** (2026-04-17)

### Changelog

- **1.0.2** (2026-04-17)
  - `replace` now refuses any output name that matches a scan variable in `varlist`, including `matched_code()`, `unmatched()`, score variables, and derived `_first`/`_last`/`_count`/`_nrows` outputs, preventing silent input-variable clobbering.
  - `hierarchy()` now resolves bare names under `generate()` by checking the defined condition list first and only then trying the generated prefix fallback, so cases like `generate(c)` with `hierarchy(cancer > copd)` behave as documented.
  - Internal/docs cleanup: the `r(codelist)` header now matches the returned two-column matrix, and release-side demo/QA files no longer set `more` in the user session.
- **1.0.1** (2026-04-17)
  - `r()` scalars/locals/matrices are now posted before `export()` and `saving()`, so programmatic callers retain `r(summary)`, `r(codelist)`, `r(cooccurrence)`, `r(sensitivity)`, `r(varcounts)`, and all scalars when an export target fails (disk full, locked file, permission error).
  - `unmatched(name)` is now a strict 0/1 flag at row level. Rows filtered by `if`/`in`, or rows with missing `id()` when `collapse`/`merge` is active, now receive 0 instead of missing, matching the help-file contract.
  - Internal: declared the previously implicit Mata `touse` colvector in `_codescan_mata_cooccurrence`; the co-occurrence matrix target is now passed through a named `_mata_cooc_matname` local for symmetry with the other `_mata_*` interop locals.
- **1.0.0** (2026-04-08)
  - Initial release.

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT License
