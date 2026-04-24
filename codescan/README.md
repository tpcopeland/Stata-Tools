# codescan - Scan wide-format diagnosis, procedure, and medication code fields

**Version 1.1.0** | 2026-04-24

`codescan` scans wide-format code slots with anchored regex or prefix rules and creates row-level indicators, counts, or patient-level summaries. `codescan_describe` is the reconnaissance companion command: it shows what codes are actually in the data before you commit to a scanning rule set.

## Requirements

- Stata 16 or later
- No external package dependencies

## Installation

```stata
capture ado uninstall codescan
net install codescan, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/codescan") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `codescan` | Scan wide-format code variables and generate indicators, counts, summaries, or scores |
| `codescan_describe` | Inspect the raw code inventory before writing scan rules |

## Bundled Example Codefiles

| File | Purpose |
|------|---------|
| `charlson_icd10_example.csv` | Charlson ICD-10 definitions with Quan-style weights |
| `elixhauser_icd10_example.csv` | Elixhauser ICD-10 definitions with van Walraven weights |

## How It Works

1. Inspect the raw code inventory with `codescan_describe`.
2. Draft simple `define()` rules or switch to a reusable `codefile()`.
3. Decide whether the finished output should stay row-level, `collapse` to one row per `id()`, or `merge` patient-level summaries back to the original rows.
4. Add time windows, date summaries, hierarchy rules, scoring, export, and saving only after the basic matches look right.

## Worked Examples

### 1. Build a small toy dataset

`codescan` is meant for wide-format code slots such as `dx1-dx30` or `proc1-proc20`, so the README uses a compact inline example rather than an unrelated built-in dataset.

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

Start here when you do not yet know which prefixes or patterns are actually present in the raw data.

```stata
codescan_describe dx1 dx2, top(10)
codescan_describe dx1 dx2, save(chapter_rules.csv)
```

### 3. Start with a row-level scan

This creates one output variable per named condition. Keep the first pass simple and verify the matches before adding windows or patient-level aggregation.

```stata
codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]" | chf "I50")
```

### 4. Collapse to one row per patient with a lookback window

Once the rule set looks right, add IDs and dates. `lookback(365)` limits matches to the prior year relative to `refdate()`, and `alldates` requests first, last, and count summaries for each matched condition.

```stata
codescan dx1 dx2, id(pid) date(visit_dt) refdate(index_dt) ///
    define(dm2 "E11" | htn "I1[0-35]" | chf "I50") ///
    lookback(365) inclusive collapse alldates
```

### 5. Use prefix matching for procedure codes

`regex` is the default. Switch to `mode(prefix)` when simple starts-with logic is enough and you do not need regex features.

```stata
codescan proc1, define(mammo "XF001|XF002" | colectomy "JFB|JFH") mode(prefix)
```

### 6. Save reusable definitions, then load them back as a codefile

This is the transition from ad hoc rule drafting to a reusable dictionary workflow.

```stata
codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") save(dm_rules.csv)
codescan dx1 dx2, codefile(dm_rules.csv)
```

### 7. Compute a Charlson score from the bundled example codefile

The bundled example names are recognized directly by `codefile()`. `hierarchy()` applies superior-greater-than-inferior rules before scoring.

```stata
codescan dx1 dx2, codefile(charlson_icd10_example.csv) id(pid) collapse ///
    score(charlson) ///
    hierarchy(dm_comp > dm_uncomp \ liver_severe > liver_mild \ metastatic > cancer)
```

### 8. Export a summary table and save the result dataset

Use `export()` for the prevalence table and `saving()` for the transformed dataset left behind by the command.

```stata
codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") id(pid) collapse ///
    export(codescan_results.xlsx) ///
    saving(codescan_results.dta, replace) ///
    format(%9.2f)
```

## Key Behaviors

- Matching is anchored at the start of each code value. `define(dm2 "E11")` matches `E110` and `E119`, not `AE11`.
- `mode(prefix)` uses starts-with comparisons and is usually faster when regex features are unnecessary.
- Exclusion patterns use `~`, for example `define(dm2 "E11" ~ "E116")`.
- `nodots` strips periods during matching without modifying the stored data.
- `nocase` uppercases patterns and code values internally for case-insensitive matching.
- `collapse` creates one row per `id()`, while `merge` attaches patient-level results back to the original row structure.
- `alldates` is shorthand for `earliestdate`, `latestdate`, and `countdate`.
- `countmode` changes the created variables from 0/1 indicators to integer counts.

## References

- Quan H, Sundararajan V, Halfon P, et al. ICD-9-CM and ICD-10 coding algorithms for defining comorbidities in administrative data.
- Quan H, Li B, Couris CM, et al. Updated Charlson comorbidity weights for risk adjustment.
- van Walraven C, Austin PC, Jennings A, Quan H, Forster AJ. A point-system adaptation of the Elixhauser comorbidity measure for hospital mortality.

## Author

Timothy P Copeland, Karolinska Institutet
