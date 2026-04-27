# codescan — Scan wide-format diagnosis, procedure, and medication code fields

**Version 1.1.0** | 2026-04-24

`codescan` scans wide-format code slots (such as `dx1`–`dx30` or `proc1`–`proc20`) with anchored regex or prefix rules and creates condition indicators, counts, or patient-level summaries — all without reshaping your data.  `codescan_describe` is the reconnaissance companion: it shows what codes are actually present before you commit to a scanning rule set.

## What it does

You tell `codescan` which code patterns to look for and what to name each condition.  The command scans every code slot on every row, marks which conditions are present, and returns a summary with prevalence and Wilson confidence intervals.  You can:

- Stay at the **row level** (one 0/1 indicator per encounter per condition)
- **Collapse** to one row per patient with `collapse`
- **Merge** patient-level results back onto encounter rows with `merge`
- Apply **time windows** relative to a reference date
- Compute **Charlson**, **Elixhauser**, or **custom weighted scores**
- **Export** prevalence tables and co-occurrence matrices to `.xlsx` or `.csv`

It works with any string code system: ICD-10, ICD-9, KVÅ, CPT, ATC, OPCS, or proprietary codes.

## Requirements

- Stata 16 or later
- No external package dependencies

## Installation

```stata
capture ado uninstall codescan
net install codescan, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/codescan") replace
```

To access the bundled example codefiles for use with `net get`:

```stata
net get codescan, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/codescan") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `codescan` | Scan wide-format code variables and generate indicators, counts, summaries, or scores |
| `codescan_describe` | Inspect the raw code inventory before writing scan rules |

## Bundled Example Codefiles

| File | Purpose |
|------|---------|
| `charlson_icd10_example.csv` | Charlson ICD-10 definitions with Quan et al. (2011) weights |
| `elixhauser_icd10_example.csv` | Elixhauser ICD-10 definitions with van Walraven et al. (2009) weights |

These can be requested directly by basename in `codefile()` — no path needed.

## How It Works

The recommended workflow has four steps:

1. **Inspect the code inventory** with `codescan_describe`.  This shows which codes and chapter prefixes actually occur in your data, and suggests patterns to target.
2. **Draft simple rules** with `define()` and check the row-level results.  At this stage the created variables appear alongside the original data so you can verify matches.
3. **Choose the output shape.**  Stay row-level for auditing, `collapse` to one row per `id()`, or `merge` patient-level summaries back to encounter rows.
4. **Add advanced features last.**  Once basic matches look right, layer on time windows (`lookback()`/`lookforward()`), date summaries (`alldates`), hierarchy rules, scoring, and export/save options.

## Worked Examples

### 1. Build a small toy dataset

`codescan` is designed for wide-format code slots, so the examples use a compact inline dataset representing five encounters for three patients, with diagnosis codes, a procedure code, and dates.

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

### 2. Inspect the code inventory before writing rules

Start here when you do not yet know which prefixes or patterns are in the raw data.  `codescan_describe` tabulates unique codes across wide-format variables, showing the top N by frequency and a chapter summary grouped by first character.

```stata
codescan_describe dx1 dx2, top(10)
```

You can also save a draft CSV codefile from the chapter summary:

```stata
codescan_describe dx1 dx2, save(chapter_rules.csv)
```

### 3. Start with a row-level scan

This is the simplest use case.  It creates one 0/1 output variable per named condition.  Keep the first pass simple and verify the matches before adding windows or patient-level aggregation.

```stata
codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]" | chf "I50")
```

After this command, `dm2` is 1 on rows where `dx1` or `dx2` starts with `E11`; `htn` is 1 where either slot starts with `I10`, `I11`, `I12`, `I13`, or `I15`; and `chf` is 1 for `I50*`.

### 4. Collapse to one row per patient with a lookback window

Once the rule set looks right, add IDs and dates.  `lookback(365)` limits matches to the prior year relative to `refdate()`, and `alldates` requests `_first`, `_last`, and `_count` date-summary variables for each condition.

```stata
codescan dx1 dx2, id(pid) date(visit_dt) refdate(index_dt) ///
    define(dm2 "E11" | htn "I1[0-35]" | chf "I50") ///
    lookback(365) inclusive collapse alldates
```

### 5. Use exclusion patterns

Use `~` after the inclusion pattern to exclude specific codes.  Here `dm2` matches all `E11*` codes except `E116`:

```stata
codescan dx1 dx2, define(dm2 "E11" ~ "E116" | htn "I1[0-35]")
```

### 6. Prefix matching for procedure codes

`regex` is the default.  Switch to `mode(prefix)` when simple starts-with logic is enough and you do not need regex features.  Pipe-separated tokens are alternative prefixes.

```stata
codescan proc1, define(mammo "XF001|XF002" | colectomy "JFB|JFH") mode(prefix)
```

### 7. Save reusable definitions, then load them back as a codefile

This is the transition from ad hoc rule drafting to a reusable dictionary workflow.  `save()` writes the parsed `define()` rules to a CSV, and `codefile()` reads them back.

```stata
codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") save(dm_rules.csv)
codescan dx1 dx2, codefile(dm_rules.csv)
```

### 8. Compute a Charlson score from the bundled example codefile

The bundled example names are recognized directly by `codefile()` — no path needed.  `hierarchy()` zeroes out the less-severe condition when both members of a pair are present, before scoring.

```stata
codescan dx1 dx2, codefile(charlson_icd10_example.csv) id(pid) collapse ///
    score(charlson) ///
    hierarchy(dm_comp > dm_uncomp \ liver_severe > liver_mild \ metastatic > cancer)
```

After this command, each patient has a `_score` variable containing the weighted Charlson comorbidity index.

### 9. Non-destructive workflow with frames

`frame()` stores the collapsed result in a named frame, leaving the original data untouched.  This is the recommended pattern when you need both encounter-level data and a patient-level summary in the same session.

```stata
codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") id(pid) collapse ///
    frame(results) replace
frame results: list
```

### 10. Export a summary table and save the result dataset

Use `export()` for the prevalence table and `saving()` for the transformed dataset.  `format()` controls the number format in both the console output and the exported file.

```stata
codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") id(pid) collapse ///
    export(codescan_results.xlsx) ///
    saving(codescan_results.dta, replace) ///
    format(%9.2f)
```

### 11. Merge patient-level results back to original rows

`merge` computes patient-level summaries and joins them back, so every row for a given patient gets the same comorbidity values.

```stata
codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") id(pid) merge
```

### 12. Multi-window sensitivity analysis

Supply several lookback values to compare how prevalence changes across windows.  `r(sensitivity)` returns a matrix of prevalences by condition and window.

```stata
codescan dx1 dx2, id(pid) date(visit_dt) refdate(index_dt) ///
    define(dm2 "E11" | htn "I1[0-35]") ///
    lookback(90 365) inclusive collapse
```

## Key Behaviors

- **Anchored matching:** patterns are anchored at the start of each code value.  `define(dm2 "E11")` matches `E110` and `E119`, not `AE11`.
- **Regex vs. prefix:** `mode(regex)` (default) supports character classes and alternation.  `mode(prefix)` uses simple starts-with comparisons and is usually faster.
- **Exclusion patterns:** use `~` after the inclusion pattern, e.g. `define(dm2 "E11" ~ "E116")`.  Multiple exclusions are allowed: `define(x "A" ~ "A1" ~ "A2")`.
- **nodots:** strips periods during matching without modifying the stored data.
- **nocase:** uppercases patterns and code values internally for case-insensitive matching.
- **tostring:** converts numeric code variables to string before scanning; original data are restored afterward.
- **collapse vs. merge:** `collapse` creates one row per `id()`.  `merge` attaches patient-level results back to the original row structure.
- **alldates:** shorthand for `earliestdate`, `latestdate`, and `countdate`.  These create `_first`, `_last`, and `_count` date-summary variables.
- **countrows:** creates `_nrows` variables counting the number of rows (not unique dates) with a qualifying match.  Does not require `date()`.
- **countmode:** changes created variables from 0/1 indicators to integer counts (number of code slots matched per row, summed across rows after collapse/merge).
- **hierarchy:** zeroes out inferior conditions when the superior is present.  Written as `superior > inferior`, separated by `\`.
- **generate:** prefixes all created variable names, useful when running separate diagnosis, procedure, and medication scans on the same dataset.
- **unmatched:** creates a row-level 0/1 flag for observations that matched no condition.
- **matched_code:** creates a row-level variable holding the first code value that survived matching.
- **frame:** stores the result in a named frame and implies `preserve`, so the original data are untouched.
- **Confidence intervals:** prevalence CIs use the Wilson score method at the current `c(level)` setting.

## References

- Quan H, Sundararajan V, Halfon P, et al. (2005). ICD-9-CM and ICD-10 coding algorithms for defining comorbidities in administrative data.
- Quan H, Li B, Couris CM, et al. (2011). Updated Charlson comorbidity weights for risk adjustment.
- van Walraven C, Austin PC, Jennings A, Quan H, Forster AJ. (2009). A point-system adaptation of the Elixhauser comorbidity measure for hospital mortality.

## Author

Timothy P Copeland, Karolinska Institutet
