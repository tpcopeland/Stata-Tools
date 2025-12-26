# tvtools Option Comparison: Stata vs Python vs R

**Generated:** 2025-12-26

## Summary

| Function | Stata Options | Python Options | R Options | Gaps |
|----------|---------------|----------------|-----------|------|
| tvexpose | 43 | 41 | 43 | Minor (verbose, replace) |
| tvmerge | 17 | 16 | 17 | Minor (replace, dateformat) |
| tvevent | 14 | 14 | 11 | **R missing startvar/stopvar/validate** |

---

## tvexpose Options

| Option | Stata | Python | R | Notes |
|--------|-------|--------|---|-------|
| **Required** |
| using/exposure_file | Y | Y | Y | Dataset with exposure periods |
| id | Y | Y | Y | Person identifier |
| start | Y | Y | Y | Exposure start date |
| exposure | Y | Y | Y | Exposure type variable |
| entry | Y | Y | Y | Study entry date |
| exit | Y | Y | Y | Study exit date |
| **Core Options** |
| stop | Y | Y | Y | Exposure stop date |
| reference | Y | Y | Y | Unexposed reference value |
| pointtime | Y | Y | Y | Point-in-time data flag |
| **Exposure Definitions** |
| evertreated | Y | Y | Y | Binary ever/never |
| currentformer | Y | Y | Y | Never/current/former |
| duration | Y | Y | Y | Cumulative duration categories |
| dose | Y | Y | Y | Cumulative dose tracking |
| dosecuts | Y | Y | Y | Dose categorization cutpoints |
| continuousunit | Y | Y | Y | Time unit (days/weeks/months/years) |
| expandunit | Y | Y | Y | Row expansion granularity |
| bytype | Y | Y | Y | Separate vars per type |
| recency | Y | Y | Y | Time since last exposure |
| **Data Handling** |
| grace | Y | Y | Y | Grace period(s) |
| merge/merge_days | Y (merge) | Y (merge_days) | Y (merge_days) | **Name differs in Stata** |
| fillgaps | Y | Y | Y | Fill gaps in exposure |
| carryforward | Y | Y | Y | Carry forward through gaps |
| **Overlap Resolution** |
| priority | Y | Y | Y | Priority ordering |
| split | Y | Y | Y | Split at boundaries |
| layer | Y | Y | Y | Later takes precedence |
| combine | Y | Y | Y | Combined indicator |
| **Lag/Washout** |
| lag | Y | Y | Y | Delay exposure onset |
| washout | Y | Y | Y | Extend after stopping |
| window | Y | Y | Y | Acute window filter |
| **Pattern Tracking** |
| switching | Y | Y | Y | Switching indicator |
| switchingdetail | Y | Y | Y | Switching pattern |
| statetime | Y | Y | Y | Time in current state |
| **Output** |
| generate | Y | Y | Y | Output variable name |
| saveas | Y | Y | Y | Save path |
| replace | Y | N | N | Overwrite existing |
| referencelabel | Y | Y | Y | Reference category label |
| label | Y | Y | Y | Variable label |
| keepvars | Y | Y | Y | Keep additional vars |
| keepdates | Y | Y | Y | Keep entry/exit dates |
| **Diagnostics** |
| check | Y | Y | Y | Coverage diagnostics |
| gaps | Y | Y | Y | Show gaps |
| overlaps | Y | Y | Y | Show overlaps |
| summarize | Y | Y | Y | Summary stats |
| validate | Y | Y | Y | Validation dataset |
| verbose | N | Y | Y | Progress messages |

**Gaps:** Python/R missing `replace` (minor - handled by saveas)

---

## tvmerge Options

| Option | Stata | Python | R | Notes |
|--------|-------|--------|---|-------|
| **Required** |
| datasets | Y | Y | Y | 2+ datasets to merge |
| id | Y | Y | Y | Person identifier |
| start | Y | Y | Y | Start date vars (list) |
| stop | Y | Y | Y | Stop date vars (list) |
| exposure | Y | Y | Y | Exposure vars (list) |
| **Exposure Type** |
| continuous | Y | Y | Y | Continuous exposure indices |
| **Output Naming** |
| generate | Y | Y | Y | New exposure names |
| prefix | Y | Y | Y | Variable prefix |
| startname | Y | Y | Y | Output start var name |
| stopname | Y | Y | Y | Output stop var name |
| dateformat | Y | N | Y | Date output format |
| **File I/O** |
| saveas | Y | Y | Y | Save path |
| replace | Y | N | N | Overwrite existing |
| keep | Y | Y | Y | Keep additional vars |
| **Performance** |
| batch | Y | Y | Y | Batch processing |
| **ID Matching** |
| force | Y | Y | Y | Allow mismatched IDs |
| **Diagnostics** |
| check | Y | Y | Y | Coverage diagnostics |
| validatecoverage | Y | Y | Y | Coverage validation |
| validateoverlap | Y | Y | Y | Overlap validation |
| summarize | Y | Y | Y | Summary stats |

**Gaps:** Python missing `dateformat` (minor), Python/R missing `replace` (minor)

---

## tvevent Options

| Option | Stata | Python | R | Notes |
|--------|-------|--------|---|-------|
| **Required** |
| using/intervals_data | Y | Y | Y | Interval dataset |
| id | Y | Y | Y | Person identifier |
| date | Y | Y | Y | Event date variable |
| **Event Type** |
| type | Y | Y | Y | single/recurring |
| compete | Y | Y | Y | Competing risk dates |
| **Output** |
| generate | Y | Y | Y | Event indicator name |
| eventlabel | Y | Y | Y | Event type labels |
| **Variable Handling** |
| keepvars | Y | Y | Y | Keep additional vars |
| continuous | Y | Y | Y | Proportional adjustment |
| timegen | Y | Y | Y | Time duration var |
| timeunit | Y | Y | Y | Time unit |
| **Interval Variables** |
| startvar | Y | Y | Y | Start column name |
| stopvar | Y | Y | Y | Stop column name |
| **File I/O** |
| replace | Y | Y | Y | Replace existing vars |
| validate | Y | N | N | Validation output |

**All critical options now implemented across all three implementations.**

---

## Minor Remaining Gaps
- `replace` option: Not critical - users can overwrite files directly
- `dateformat`: R handles date formatting natively
- `validate` diagnostic: Nice-to-have but not essential

---

## Default Value Differences

| Option | Stata | Python | R |
|--------|-------|--------|---|
| merge_days | 120 | 0 | 0 |
| generate (tvexpose) | (required) | "tv_exposure" | "tv_exposure" |
| generate (tvevent) | "_failure" | "_failure" | "_failure" |
| batch | 20 | 20 | 20 |

**Note:** Stata's default `merge_days=120` differs from Python/R's `merge_days=0`. This could cause different results if not explicitly specified.
