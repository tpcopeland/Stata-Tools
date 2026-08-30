# asof

`asof` attaches one measurement record per identifier and anchor date from a long Stata dataset. It makes direction, selection, tie, protocol-window, and observability-window rules explicit while keeping the master data in memory.

## Quick Start

This minimal example is self-contained:

```stata
tempfile events
clear
input long id double visit_date score
1 90 4
1 110 6
end
format %td visit_date
save `events'
clear
input long id double index_date
1 100
end
format %td index_date
asof score using `events', id(id) date(visit_date) anchor(index_date) direction(both) select(nearest) generate(score_index) gapname(score_gap)
```

The command creates `score_index`, records the signed day difference in `score_gap`, and leaves every master row in place.

## Requirements

- Stata 16 or later.
- No community-contributed runtime dependencies.

## Installation

Install the package from Stata-Tools:

```stata
net install asof, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/asof") replace
```

## Commands

| Command | Purpose |
|---|---|
| `asof` | Select one eligible using record per identifier-anchor key and attach requested values. |

## Options

| Option | Purpose |
|---|---|
| `id()` | Identifier in master and using data. |
| `date()` | Measurement date in the using data. |
| `anchor()` | Reference date in the master data. |
| `direction()` | Eligible side of the anchor: `before`, `onorbefore`, `after`, `onorafter`, or `both`. |
| `select()` | Choose the `nearest`, `first`, or `last` eligible record. |
| `window()` | Apply inclusive signed day bounds relative to the anchor. |
| `range()` | Apply inclusive lower and upper observability variables from the master. |
| `require()` | Require specified using variables to be nonmissing. |
| `suffix()` / `prefix()` | Construct output names from carried names. |
| `generate()` | Supply one explicit output name per carried variable. |
| `datename()` / `gapname()` / `matchname()` | Store the selected date, signed day gap, and match flag. |
| `ties()` | Resolve equally ranked records. |
| `frame()` | Read events from a copied Stata frame. |
| `replace` | Overwrite existing compatible output variables. |
| `nowarn` | Suppress the unmatched-observation message. |
| `noisily` | Display the full coverage report. |

## How It Works

The data in memory are the master cohort or person-period spine. The using dataset is the long measurement table. `direction()` restricts which side of the anchor is eligible, `window()` applies signed protocol-day bounds, and `range()` applies per-row observability bounds. `select()` then chooses the nearest, first, or last eligible date.

Carried variables and `require()` lists are resolved in the using data, so standard wildcard and hyphen-range notation is supported.

The implementation sorts distinct master keys and using events, then performs a Mata scan with binary searches inside each identifier block. It does not form the per-person cross product produced by `joinby`.

Nearest ties default to the record before the anchor. Use `ties(after)`, `ties(first)`, `ties(last)`, or `ties(error)` when another policy is required. `r(N_ties)` reports how often the tie rule determined a key-level result.

## Worked Examples

### 1. Closest measurement on either side

Create reusable synthetic event and master files, then run the examples below in the same Stata session:

```stata
tempfile events master
clear
input long id double visit_date score edss eq5d_uk eq5d_se eq_vas
1 21990 4 2.0 .80 .78 75
1 22010 6 2.5 .76 .74 70
1 22480 8 3.0 .71 .69 65
2 22070 5 1.5 .85 .83 80
2 22130 7 2.0 .81 .79 76
2 22390 9 2.5 .77 .75 72
3 21950 3 1.0 .90 .88 88
3 22220 6 1.5 .86 .84 82
3 22610 8 2.0 .82 .80 78
end
format %td visit_date
save `events'
clear
input long id double(index_date study_start followup_date)
1 22000 21500 22500
2 22100 21700 22400
3 22200 22000 22600
end
format %td index_date study_start followup_date
save `master'
asof score using `events', id(id) date(visit_date) anchor(index_date) direction(both) select(nearest) generate(score_index) datename(score_date) gapname(score_gap) matchname(score_found)
list
```

### 2. Protocol and observability windows

Intersect a one-year pre-index protocol window with each person's observed study period:

```stata
use `master', clear
asof edss using `events', id(id) date(visit_date) anchor(index_date) direction(onorbefore) select(nearest) window(-365 0) range(study_start followup_date) generate(edss_baseline)
```

### 3. Last available value

Select the latest quality-of-life record no later than follow-up end:

```stata
use `master', clear
asof eq5d_uk eq5d_se eq_vas using `events', id(id) date(visit_date) anchor(followup_date) direction(onorbefore) select(last) range(study_start followup_date) suffix(_last) datename(eq5d_date_last)
```

## Guided Demo

The complete demo script, [`demo/demo_asof.do`](demo/demo_asof.do), builds its invented cohort and measurement history inline, installs the local package into a temporary ado sandbox, and runs five guided workflows. It does not read data from `_data/` or any other directory outside `asof/`. From the repository root, run:

```bash
stata-mp -b do asof/demo/demo_asof.do
```

The demo always regenerates its console logs. When `logdoc` is already installed, it also refreshes the checked-in Markdown renderings shown below; `logdoc` is not required to run any example.

### 1. Recognize the master and using data

Keep the cohort or person-period spine in memory. Put the repeated, dated measurements in the `using` dataset. The identifier must exist in both.

<details>
<summary>Data layout (click to expand)</summary>

### Master data in memory: one row per patient and index date

```stata
.     list id cohort index_date study_start followup_date,
>         noobs sep(0) abbreviate(16)
```

```
  +---------------------------------------------------------+
  |  id   cohort   index_date   study_start   followup_date |
  |---------------------------------------------------------|
  | 101        A   2024-02-29    2024-01-01      2024-12-31 |
  | 102        A   2024-04-15    2024-02-01      2024-10-31 |
  | 103        B   2024-07-01    2024-05-01      2024-09-30 |
  | 104        B   2024-08-01    2024-01-01      2024-12-31 |
  +---------------------------------------------------------+
```

### Using data: repeated dated measurements per patient

```stata
.     frame asof_demo_events: list id visit_date score edss status,
>         noobs sepby(id) abbreviate(16)
```

```
  +--------------------------------------------+
  |  id   visit_date   score   edss     status |
  |--------------------------------------------|
  | 101   2024-02-14      48      2     stable |
  | 101   2024-03-15      52    2.5   improved |
  | 101   2024-06-01      58      3   worsened |
  |--------------------------------------------|
  | 102   2024-01-15      40      1     stable |
  | 102   2024-04-10      59      2     stable |
  | 102   2024-04-15      60      .    pending |
  | 102   2024-07-20      65    2.5   improved |
  |--------------------------------------------|
  | 103   2024-05-15      70      3     stable |
  | 103   2024-06-25      72    3.5     stable |
  | 103   2024-07-10       .      4   worsened |
  | 103   2024-10-15      75    4.5   worsened |
  |--------------------------------------------|
  | 105   2024-02-01      80      1     stable |
  +--------------------------------------------+
```

</details>

### 2. Make a first as-of join

This call chooses the closest nonmissing score on either side of each index date. `datename()`, `gapname()`, and `matchname()` make the selected record and unmatched rows explicit; `noisily` prints the match audit.

<details>
<summary>First join, coverage, and stored results (click to expand)</summary>

```stata
.     asof score using "`events'", id(id) date(visit_date)
>         anchor(index_date) direction(both) select(nearest)
>         generate(score_index) datename(score_date) gapname(score_gap)
>         matchname(score_found) noisily
```

```
asof match coverage
  rule:       both / nearest / ties(before)
  master:                4
  keys:                  4
  matched:               3
  unmatched:             1
  missing key:           0
  using rows:           12
  eligible:             10
  ties:                  1
```

### Stored results make match coverage auditable

```stata
.     return list
```

```
scalars:
            r(gap_p50) =  -6
           r(gap_mean) =  -7
            r(gap_max) =  0
            r(gap_min) =  -15
             r(N_ties) =  1
         r(N_eligible) =  10
            r(N_using) =  12
            r(N_nokey) =  0
        r(N_unmatched) =  1
          r(N_matched) =  3
             r(N_keys) =  4
           r(N_master) =  4

macros:
               r(ties) : "before"
             r(select) : "nearest"
          r(direction) : "both"
           r(generate) : "score_index"
            r(varlist) : "score"
```

### The master rows stay in place and receive the selected values

```stata
.     list id index_date score_index score_date score_gap score_found,
>         noobs sep(0) abbreviate(16)
```

```
  +-----------------------------------------------------------------------+
  |  id   index_date   score_index   score_date   score_gap   score_found |
  |-----------------------------------------------------------------------|
  | 101   2024-02-29            48   2024-02-14         -15             1 |
  | 102   2024-04-15            60   2024-04-15           0             1 |
  | 103   2024-07-01            72   2024-06-25          -6             1 |
  | 104   2024-08-01             .            .           .             0 |
  +-----------------------------------------------------------------------+
```

</details>

### 3. Choose the intended direction, selection, and tie rule

Patient 101 has measurements exactly 15 days before and after index. The comparison makes strict direction rules, earliest/latest selection, and `ties(after)` visible.

<details>
<summary>Selection-rule comparison (click to expand)</summary>

```stata
.     asof score using "`events'", id(id) date(visit_date)
>         anchor(index_date) direction(before) select(nearest)
>         generate(before_nearest) datename(before_date)
```

```stata
.     asof score using "`events'", id(id) date(visit_date)
>         anchor(index_date) direction(after) select(nearest)
>         generate(after_nearest) datename(after_date)
```

```stata
.     asof score using "`events'", id(id) date(visit_date)
>         anchor(index_date) direction(both) select(nearest)
>         generate(both_default) datename(default_date)
```

```stata
.     asof score using "`events'", id(id) date(visit_date)
>         anchor(index_date) direction(both) select(nearest) ties(after)
>         generate(both_tie_after) datename(tie_after_date)
```

```stata
.     asof score using "`events'", id(id) date(visit_date)
>         anchor(index_date) direction(both) select(first)
>         generate(first_any) datename(first_date)
```

```stata
.     asof score using "`events'", id(id) date(visit_date)
>         anchor(index_date) direction(both) select(last)
>         generate(last_any) datename(last_date)
```

### Nearest defaults to the earlier record when distances tie

```stata
.     list index_date before_nearest before_date after_nearest after_date,
>         noobs sep(0) abbreviate(16)
```

```
  +------------------------------------------------------------------------+
  | index_date   before_nearest   before_date   after_nearest   after_date |
  |------------------------------------------------------------------------|
  | 2024-02-29               48    2024-02-14              52   2024-03-15 |
  +------------------------------------------------------------------------+
```

```stata
.     list both_default default_date both_tie_after tie_after_date,
>         noobs sep(0) abbreviate(16)
```

```
  +---------------------------------------------------------------+
  | both_default   default_date   both_tie_after   tie_after_date |
  |---------------------------------------------------------------|
  |           48     2024-02-14               52       2024-03-15 |
  +---------------------------------------------------------------+
```

### `first` and `last` select the earliest and latest eligible dates

```stata
.     list first_any first_date last_any last_date,
>         noobs sep(0) abbreviate(16)
```

```
  +------------------------------------------------+
  | first_any   first_date   last_any    last_date |
  |------------------------------------------------|
  |        48   2024-02-14         58   2024-06-01 |
  +------------------------------------------------+
```

</details>

### 4. Restrict eligibility and control missingness

`window(-45 0)` applies a 45-day pre-index protocol window, and `range(study_start followup_date)` intersects it with person-specific observability. By default, `edss` must be nonmissing, so patient 102 skips the exact-index record. `require(visit_date)` instead allows that record to match while carrying a missing EDSS value.

<details>
<summary>Windows, observability, and missing values (click to expand)</summary>

```stata
.     asof edss using "`events'", id(id) date(visit_date)
>         anchor(index_date) direction(onorbefore) select(nearest)
>         window(-45 0) range(study_start followup_date)
>         generate(edss_baseline) datename(edss_date) gapname(edss_gap)
>         matchname(edss_found) noisily
```

```
asof match coverage
  rule:       onorbefore / nearest / ties(before)
  master:                4
  keys:                  4
  matched:               3
  unmatched:             1
  missing key:           0
  using rows:           12
  eligible:              3
  ties:                  0
```

```stata
.     asof edss using "`events'", id(id) date(visit_date)
>         anchor(index_date) direction(onorbefore) select(nearest)
>         window(-45 0) range(study_start followup_date)
>         require(visit_date) generate(edss_any)
>         datename(edss_date_any) matchname(edss_found_any)
```

```
(1 master observations had no eligible using record)
```

```stata
.     list id index_date edss_baseline edss_date edss_gap edss_found,
>         noobs sep(0) abbreviate(16)
```

```
  +-----------------------------------------------------------------------+
  |  id   index_date   edss_baseline    edss_date   edss_gap   edss_found |
  |-----------------------------------------------------------------------|
  | 101   2024-02-29               2   2024-02-14        -15            1 |
  | 102   2024-04-15               2   2024-04-10         -5            1 |
  | 103   2024-07-01             3.5   2024-06-25         -6            1 |
  | 104   2024-08-01               .            .          .            0 |
  +-----------------------------------------------------------------------+
```

```stata
.     list id edss_any edss_date_any edss_found_any,
>         noobs sep(0) abbreviate(16)
```

```
  +-------------------------------------------------+
  |  id   edss_any   edss_date_any   edss_found_any |
  |-------------------------------------------------|
  | 101          2      2024-02-14                1 |
  | 102          .      2024-04-15                1 |
  | 103        3.5      2024-06-25                1 |
  | 104          .               .                0 |
  +-------------------------------------------------+
```

</details>

### 5. Carry several variables from a frame

The final workflow resolves `eq5d_*` in an in-memory frame, carries numeric and string variables together, applies a suffix, and selects the last observed value within follow-up. It also shows that repeated master keys receive the same result without reordering the master data.

<details>
<summary>Frame input and multi-variable output (click to expand)</summary>

```stata
.     asof eq5d_* status using events_in_memory, frame(asof_demo_events)
>         id(id) date(visit_date) anchor(followup_date)
>         direction(onorbefore) select(last)
>         range(study_start followup_date) require(visit_date)
>         suffix(_last) datename(last_visit) gapname(last_gap)
>         matchname(last_found) noisily
```

```
asof match coverage
  rule:       onorbefore / last / ties(first)
  master:                5
  keys:                  4
  matched:               4
  unmatched:             1
  missing key:           0
  using rows:           12
  eligible:              9
  ties:                  0
```

```stata
.     list master_row id followup_date eq5d_uk_last eq5d_se_last
>         status_last last_visit last_gap last_found,
>         noobs sep(0) abbreviate(16)
```

```
  +-------------------------------------------------------------------------------------------------------------------+
  | master_row    id   followup_date   eq5d_uk_last   eq5d_se_last   status_last   last_visit   last_gap   last_found |
  |-------------------------------------------------------------------------------------------------------------------|
  |          1   101      2024-12-31             .8            .78      worsened   2024-06-01       -213            1 |
  |          2   102      2024-10-31             .8            .78      improved   2024-07-20       -103            1 |
  |          3   103      2024-09-30            .68              .      worsened   2024-07-10        -82            1 |
  |          4   104      2024-12-31              .              .                          .          .            0 |
  |          5   101      2024-12-31             .8            .78      worsened   2024-06-01       -213            1 |
  +-------------------------------------------------------------------------------------------------------------------+
```

```stata
.     return list
```

```
scalars:
            r(gap_p50) =  -158
           r(gap_mean) =  -152.75
            r(gap_max) =  -82
            r(gap_min) =  -213
             r(N_ties) =  0
         r(N_eligible) =  9
            r(N_using) =  12
            r(N_nokey) =  0
        r(N_unmatched) =  1
          r(N_matched) =  4
             r(N_keys) =  4
           r(N_master) =  5

macros:
               r(ties) : "first"
             r(select) : "last"
          r(direction) : "onorbefore"
           r(generate) : "eq5d_uk_last eq5d_se_last status_last"
            r(varlist) : "eq5d_uk eq5d_se status"
```

</details>

## Stored Results

| Result | Meaning |
|---|---|
| `r(N_master)` | Master rows selected by `if`/`in`. |
| `r(N_keys)` | Distinct nonmissing identifier-anchor keys. |
| `r(N_matched)` / `r(N_unmatched)` | Valid-key master rows with or without an eligible record. |
| `r(N_nokey)` | Selected master rows with a missing identifier or anchor. |
| `r(N_using)` / `r(N_eligible)` | Using rows read and distinct using rows eligible for at least one key. |
| `r(N_ties)` | Key-level selections for which the tie rule fired. |
| `r(gap_min)` / `r(gap_max)` / `r(gap_mean)` / `r(gap_p50)` | Signed day-gap summaries over matched master rows. |
| `r(varlist)` / `r(generate)` | Input carried names and resolved output names. |
| `r(direction)` / `r(select)` / `r(ties)` | Resolved selection rules. |

See `help asof` for the complete syntax, output-name rules, date-unit contract, and stored-result definitions.

## QA

See [qa/README.md](qa/README.md) for the test runbook and coverage map.

## Version History

Version 0.1.0, 2026-08-30.

- 0.1.0 (2026-08-12): Initial release.

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
