<img src="../_resources/logos/pygrid_hex.svg" align="right" width="150" alt="pygrid hex logo">

# pygrid — Person-period denominators with zero-filled events

**Version 1.0.2** | 2026-10-13

[![version](https://img.shields.io/badge/version-1.0.2-1a5f91?style=flat-square)](#version-history) [![Stata 16+](https://img.shields.io/badge/Stata-16%2B-1a5f91?style=flat-square)](#requirements) [![MIT license](https://img.shields.io/badge/license-MIT-1a5f91?style=flat-square)](../LICENSE) [![Part of Stata-Tools](https://img.shields.io/badge/part%20of-Stata--Tools-0e3a5a?style=flat-square)](../README.md)

**[Quick Start](#quick-start)** · **[Installation](#installation)** · **[Options](#options)** · **[Demo](#demo)** · **[Stata-Tools](../README.md)** · **[Report a bug](https://github.com/tpcopeland/Stata-Tools/issues)**

`pygrid` turns inclusive person-level observation windows into exact person-period denominators. Its companion command `pyattach` attaches event counts, sums, indicators, maxima, and rates while retaining zero-event periods by default.

## Quick Start

After [installing](#installation), split three people's follow-up into calendar years and attach their qualifying events, keeping the years with no events:

```stata
set linesize 120

* Event rows: one per event, with a cost, a severity, and a qualifying flag
clear
input long person_id str9 event_text double cost byte severity byte qualifying
101 "31dec2019" 125 2 1
101 "01jan2020"  80 1 1
101 "29feb2020" 210 3 1
101 "01jan2021" 999 5 0
101 "20mar2022"  60 2 1
102 "15jul2021" 175 4 1
103 "01jan2022"  90 2 1
999 "01jun2020" 300 5 1
end
generate double event_date = daily(event_text, "DMY")
drop event_text
format event_date %td
tempfile events
save "`events'"

* Follow-up windows: one row per person
clear
input long id str9 entry_text str9 exit_text str8 cohort
101 "15jun2019" "20mar2022" "Clinic A"
102 "01jan2020" "31dec2021" "Clinic B"
103 "10sep2021" "31dec2021" "Clinic A"
end
generate double window_start = daily(entry_text, "DMY")
generate double window_end = daily(exit_text, "DMY")
drop entry_text exit_text
format window_start window_end %td

* One row per person and calendar year, then attach the qualifying events
pygrid, id(id) start(window_start) end(window_end) axis(calendar) keep(cohort) noisily
pyattach using "`events'", id(person_id) date(event_date) count(n_events) sum(cost total_cost) any(any_event) max(severity max_severity) rate(events_per_py) if(qualifying == 1) orphans(report) noisily
format person_years %9.3f
list id cohort period period_start period_stop person_years n_events events_per_py, sepby(id) noobs abbreviate(16)
```

```
pygrid: 3 persons, 7 period rows
  empty windows: 0   partial periods: 3
  person-time: 5.07598   axis: calendar   convention: inclusive
```

```
pyattach: 2 orphan event row(s); 1 have id() absent from the grid
pyattach: 7 eligible events, 5 attached
  orphans: 2   zero-event grid rows: 3
  overall event rate: .985032
```

```
  +------------------------------------------------------------------------------------------------+
  |  id     cohort   period   period_start   period_stop   person_years   n_events   events_per_py |
  |------------------------------------------------------------------------------------------------|
  | 101   Clinic A     2019      15jun2019     31dec2019          0.548          1            1.83 |
  | 101   Clinic A     2020      01jan2020     31dec2020          1.002          2            2.00 |
  | 101   Clinic A     2021      01jan2021     31dec2021          0.999          0            0.00 |
  | 101   Clinic A     2022      01jan2022     20mar2022          0.216          1            4.62 |
  |------------------------------------------------------------------------------------------------|
  | 102   Clinic B     2020      01jan2020     31dec2020          1.002          0            0.00 |
  | 102   Clinic B     2021      01jan2021     31dec2021          0.999          1            1.00 |
  |------------------------------------------------------------------------------------------------|
  | 103   Clinic A     2021      10sep2021     31dec2021          0.309          0            0.00 |
  +------------------------------------------------------------------------------------------------+
```

Seven person-year rows carry exact observed time, including the partial first and last years. Five qualifying events attach; the excluded `qualifying == 0` row is not counted, the two orphans (person 999, who is not in the grid, and person 103's event after follow-up ended) are reported, and three rows keep zero events.

<sub>Output copied from `demo/console_getting_started.md` and `demo/console_event_attachment.md`, written by `demo/demo_pygrid.do`. `set linesize 120` matches the demo; at the default width `list` wraps the rows into blocks. The demo also formats `total_cost` and `events_per_py` in the same `format` call, which Stata ignores (one format per call), so the shown output is unchanged.</sub>

## Features

- **Exact person-time.** Each row's time is inclusive by default, `(period_stop - period_start + 1)/365.25`, and partial first and last periods are kept with their exact observed time.
- **Zero-event periods stay in.** `pyattach` adds counts, sums, any-event indicators, maxima, and rates without changing the number of denominator rows, and fills no-event rows with zeros unless `nozerofill` is given.
- **Calendar, anniversary, or fixed periods.** `axis()` sets the rule, `width()` and `unit()` the period length, `origin()` the anniversary or relative-period origin, and `partial()` keeps, drops, or flags short edge periods.
- **Study bounds and data coverage.** `clamp()` intersects every window with study dates and `coverage()` delays follow-up to a coverage start; people left with no time are counted in `r(N_empty_window)`.
- **No silently lost events.** Eligible events that land in no grid row are an error by default; `orphans()` can report or save them instead.
- **A grid that knows it was edited.** Every grid carries an integrity stamp; `pyattach` accepts reordered rows and added measure columns but refuses a grid whose structural values were changed.

## Requirements

- Stata 16 or later
- No runtime dependencies
- Integer Stata daily dates in every date variable and numeric date bound

## Installation

```stata
capture ado uninstall pygrid
net install pygrid, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/pygrid") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `pygrid` | Build a person-period denominator grid with exact person-time |
| `pyattach` | Attach zero-filled event measures to a `pygrid` denominator |

## How It Works

```
one row per person window          pygrid                      pyattach using events
id  start  end  [keep() vars]  -->  id  period  period_start  -->  ... plus count(), sum(),
                                    period_stop  person_years      any(), max(), rate();
                                                                   zero where no event
```

Identifiers may be numeric or fixed-width strings. All date variables and numeric date bounds must contain integer Stata daily dates; datetime and fractional values are rejected.

Source windows must have `end()` on or after `start()`. Calendar month blocks are anchored at January 1960, so odd widths remain stable across years.

Every generated grid carries an integrity stamp over its structural metadata and data. Row reordering and added event-measure columns remain valid, but editing structural values or metadata requires rebuilding the grid before calling `pyattach`; grids created before version 1.0.1 must also be rebuilt.

## Demo

The complete runnable tutorial is [`demo/demo_pygrid.do`](demo/demo_pygrid.do). It creates its own cohort and event data, rebuilds the package from the local source, and writes reproducible console assets to `pygrid/demo/`. Run it from the repository root:

```bash
stata-mp -b do pygrid/demo/demo_pygrid.do
```

Start with the first two sections for the usual denominator-to-rate workflow. The later sections show how period definitions, observation restrictions, output naming, and source-data preservation fit together. By default, person-time is inclusive: `(period_stop - period_start + 1)/365.25`. In survival-time notation, `[start, stop]` therefore maps to the half-open interval `[start, stop + 1)`.

### 1. Build a calendar-year denominator

Each source row becomes one row per observed calendar year. `keep(cohort)` carries source metadata onto every period, while `noisily` reports the number of people, generated rows, partial periods, and total person-time. Notice that the first and last calendar years are retained with their exact observed time.

<details>
<summary>Observed Stata output (click to expand)</summary>

```stata
. noisily pygrid, id(id) start(window_start) end(window_end)
>     axis(calendar) keep(cohort) noisily
```

```
pygrid: 3 persons, 7 period rows
  empty windows: 0   partial periods: 3
  person-time: 5.07598   axis: calendar   convention: inclusive

```

```stata
. format person_years %9.3f
```

```stata
. noisily list id cohort period period_start period_stop person_years,
>     sepby(id) noobs abbreviate(16)
```

```
  +---------------------------------------------------------------------+
  |  id     cohort   period   period_start   period_stop   person_years |
  |---------------------------------------------------------------------|
  | 101   Clinic A     2019      15jun2019     31dec2019          0.548 |
  | 101   Clinic A     2020      01jan2020     31dec2020          1.002 |
  | 101   Clinic A     2021      01jan2021     31dec2021          0.999 |
  | 101   Clinic A     2022      01jan2022     20mar2022          0.216 |
  |---------------------------------------------------------------------|
  | 102   Clinic B     2020      01jan2020     31dec2020          1.002 |
  | 102   Clinic B     2021      01jan2021     31dec2021          0.999 |
  |---------------------------------------------------------------------|
  | 103   Clinic A     2021      10sep2021     31dec2021          0.309 |
  +---------------------------------------------------------------------+

```

```stata
. noisily return list
```

```
scalars:
         r(period_max) =  2022
         r(period_min) =  2019
              r(pymax) =  1.002053388090349
              r(pymin) =  .216290212183436
            r(pytotal) =  5.075975359342916
          r(N_partial) =  3
        r(N_uncovered) =  0
     r(N_empty_window) =  0
             r(N_rows) =  7
          r(N_persons) =  3

macros:
       r(pyconvention) : "inclusive"
               r(unit) : "year"
              r(width) : "1"
               r(axis) : "calendar"

```

</details>

### 2. Attach events and retain zero-event time

`pyattach` adds a count, cost sum, any-event indicator, maximum severity, and event rate without changing the seven-row denominator. The demo's `if()` filters only event rows. It deliberately includes two eligible events outside the grid so `orphans(report)` can show the diagnostic; without an explicit policy, orphans are errors. Periods with no event remain present with zero-filled measures.

<details>
<summary>Observed Stata output (click to expand)</summary>

```stata
. noisily pyattach using "`events'", id(person_id) date(event_date)
>     count(n_events) sum(cost total_cost) any(any_event)
>     max(severity max_severity) rate(events_per_py)
>     if(qualifying == 1) orphans(report) noisily
```

```
pyattach: 2 orphan event row(s); 1 have id() absent from the grid
pyattach: 7 eligible events, 5 attached
  orphans: 2   zero-event grid rows: 3
  overall event rate: .985032

```

```stata
. format person_years %9.3f
```

```stata
. format total_cost %9.0fc
```

```stata
. format events_per_py %9.2f
```

```stata
. noisily list id cohort period period_start period_stop person_years
>     n_events events_per_py,
>     sepby(id) noobs abbreviate(16)
```

```
  +------------------------------------------------------------------------------------------------+
  |  id     cohort   period   period_start   period_stop   person_years   n_events   events_per_py |
  |------------------------------------------------------------------------------------------------|
  | 101   Clinic A     2019      15jun2019     31dec2019          0.548          1            1.83 |
  | 101   Clinic A     2020      01jan2020     31dec2020          1.002          2            2.00 |
  | 101   Clinic A     2021      01jan2021     31dec2021          0.999          0            0.00 |
  | 101   Clinic A     2022      01jan2022     20mar2022          0.216          1            4.62 |
  |------------------------------------------------------------------------------------------------|
  | 102   Clinic B     2020      01jan2020     31dec2020          1.002          0            0.00 |
  | 102   Clinic B     2021      01jan2021     31dec2021          0.999          1            1.00 |
  |------------------------------------------------------------------------------------------------|
  | 103   Clinic A     2021      10sep2021     31dec2021          0.309          0            0.00 |
  +------------------------------------------------------------------------------------------------+

```

```stata
. noisily list id period total_cost any_event max_severity,
>     sepby(id) noobs abbreviate(16)
```

```
  +------------------------------------------------------+
  |  id   period   total_cost   any_event   max_severity |
  |------------------------------------------------------|
  | 101     2019          125           1              2 |
  | 101     2020          290           1              3 |
  | 101     2021            0           0              0 |
  | 101     2022           60           1              2 |
  |------------------------------------------------------|
  | 102     2020            0           0              0 |
  | 102     2021          175           1              4 |
  |------------------------------------------------------|
  | 103     2021            0           0              0 |
  +------------------------------------------------------+

```

```stata
. noisily return list
```

```
scalars:
       r(rate_overall) =  .9850323624595468
             r(events) =  5
       r(N_zerofilled) =  3
     r(N_orphan_nokey) =  1
           r(N_orphan) =  2
         r(N_attached) =  5
         r(N_eligible) =  7
            r(N_using) =  8

```

</details>

### 3. Choose calendar, anniversary, or fixed periods

The first section used common calendar boundaries. Anniversary periods instead start on each person's `origin()`; `partial(flag)` retains shorter edge periods and marks them. A fixed axis produces one row per observed window. The fixed example also demonstrates custom output names and `pyunit(day)`.

<details>
<summary>Observed Stata output (click to expand)</summary>

```stata
. noisily pygrid, id(id) start(index_date) end(followup_date)
>     axis(anniversary) origin(index_date) partial(flag) keep(cohort) noisily
```

```
pygrid: 2 persons, 7 period rows
  empty windows: 0   partial periods: 2
  person-time: 5.76591   axis: anniversary   convention: inclusive

```

```stata
. format person_years %9.3f
```

```stata
. noisily list id cohort period rel_period period_start period_stop
>     person_years _partial, sepby(id) noobs abbreviate(16)
```

```
  +---------------------------------------------------------------------------------------------+
  |  id     cohort   period   rel_period   period_start   period_stop   person_years   _partial |
  |---------------------------------------------------------------------------------------------|
  | 201   Clinic A        1            0      15jun2020     14jun2021          0.999          0 |
  | 201   Clinic A        2            1      15jun2021     14jun2022          0.999          0 |
  | 201   Clinic A        3            2      15jun2022     14jun2023          0.999          0 |
  | 201   Clinic A        4            3      15jun2023     20sep2023          0.268          1 |
  |---------------------------------------------------------------------------------------------|
  | 202   Clinic B        1            0      01oct2019     29sep2020          0.999          0 |
  | 202   Clinic B        2            1      30sep2020     29sep2021          0.999          0 |
  | 202   Clinic B        3            2      30sep2021     31mar2022          0.501          1 |
  +---------------------------------------------------------------------------------------------+

```

```stata
. noisily return list
```

```
scalars:
         r(period_max) =  4
         r(period_min) =  1
              r(pymax) =  .999315537303217
              r(pymin) =  .2683093771389459
            r(pytotal) =  5.765913757700205
          r(N_partial) =  2
        r(N_uncovered) =  0
     r(N_empty_window) =  0
             r(N_rows) =  7
          r(N_persons) =  2

macros:
       r(pyconvention) : "inclusive"
               r(unit) : "year"
              r(width) : "1"
               r(axis) : "anniversary"

```

**Fixed windows and person-time in days**

```stata
. use "`anniversary_source'", clear
```

```stata
. noisily pygrid, id(id) start(index_date) end(followup_date)
>     axis(fixed) generate(window) startgen(observed_start)
>     stopgen(observed_stop) pytime(days_at_risk) pyunit(day)
>     keep(cohort) noisily
```

```
pygrid: 2 persons, 2 period rows
  empty windows: 0   partial periods: 0
  person-time: 2106   axis: fixed   convention: inclusive

```

```stata
. format observed_start observed_stop %td
```

```stata
. noisily list id cohort window observed_start observed_stop days_at_risk,
>     noobs abbreviate(16)
```

```
  +-------------------------------------------------------------------------+
  |  id     cohort   window   observed_start   observed_stop   days_at_risk |
  |-------------------------------------------------------------------------|
  | 201   Clinic A        1        15jun2020       20sep2023           1193 |
  | 202   Clinic B        1        01oct2019       31mar2022            913 |
  +-------------------------------------------------------------------------+

```

```stata
. noisily return list
```

```
scalars:
         r(period_max) =  1
         r(period_min) =  1
              r(pymax) =  1193
              r(pymin) =  913
            r(pytotal) =  2106
          r(N_partial) =  0
        r(N_uncovered) =  0
     r(N_empty_window) =  0
             r(N_rows) =  2
          r(N_persons) =  2

macros:
       r(pyconvention) : "inclusive"
               r(unit) : "year"
              r(width) : "1"
               r(axis) : "fixed"

```

</details>

### 4. Apply study and data-coverage restrictions

The final example intersects source windows with `clamp()`, delays eligible follow-up with row-specific `coverage()`, creates calendar periods relative to `origin()`, and flags partial periods. Person 303 contributes no time after the study bounds and is counted in `r(N_empty_window)`. With `saveas()`, the six-row grid is written to a new dataset while the three-row source data stay in memory.

<details>
<summary>Observed Stata output (click to expand)</summary>

```stata
. noisily pygrid, id(id) start(window_start) end(window_end)
>     axis(calendar) origin(index_date) coverage(coverage_start)
>     clamp(`study_start' `study_stop') relgen(study_year)
>     partial(flag) keep(cohort) saveas("`controlled_grid'") replace noisily
```

```
pygrid: 2 persons, 6 period rows
  empty windows: 1   partial periods: 3
  person-time: 4.79671   axis: calendar   convention: inclusive

```

```stata
. noisily return list
```

```
scalars:
         r(period_max) =  2022
         r(period_min) =  2020
              r(pymax) =  .999315537303217
              r(pymin) =  .4955509924709103
            r(pytotal) =  4.796714579055442
          r(N_partial) =  3
        r(N_uncovered) =  1
     r(N_empty_window) =  1
             r(N_rows) =  6
          r(N_persons) =  2

macros:
       r(pyconvention) : "inclusive"
               r(unit) : "year"
              r(width) : "1"
               r(axis) : "calendar"

```

```stata
. noisily display as text "Source rows still in memory after saveas(): " as result _N
```

```
Source rows still in memory after saveas(): 3

```

```stata
. use "`controlled_grid'", clear
```

```stata
. format person_years %9.3f
```

```stata
. noisily list id cohort period study_year period_start period_stop
>     person_years _partial, sepby(id) noobs abbreviate(16)
```

```
  +---------------------------------------------------------------------------------------------+
  |  id     cohort   period   study_year   period_start   period_stop   person_years   _partial |
  |---------------------------------------------------------------------------------------------|
  | 301   Clinic A     2020            0      01jul2020     31dec2020          0.504          1 |
  | 301   Clinic A     2021            1      01jan2021     31dec2021          0.999          0 |
  | 301   Clinic A     2022            2      01jan2022     30jun2022          0.496          1 |
  |---------------------------------------------------------------------------------------------|
  | 302   Clinic B     2020            0      15mar2020     31dec2020          0.799          1 |
  | 302   Clinic B     2021            1      01jan2021     31dec2021          0.999          0 |
  | 302   Clinic B     2022            2      01jan2022     31dec2022          0.999          0 |
  +---------------------------------------------------------------------------------------------+

```

</details>

The checked-in `.log` files are plain-text Stata output; `logdoc` also generates the reusable markdown for [getting started](demo/console_getting_started.md), [event attachment](demo/console_event_attachment.md), [period axes](demo/console_period_axes.md), and [window controls](demo/console_window_controls.md).

## Command Reference

```stata
pygrid [if] [in], id(varname) start(varname) end(varname) axis(calendar|anniversary|fixed) [options]
pyattach using filename, id(varname) date(varname) [options]
```

`pyattach` needs at least one measure: `count()`, `sum()`, `any()`, or `max()`. Use `help pygrid` and `help pyattach` for the complete option and stored-result contracts.

## Options

### pygrid

| Option | Default | Purpose |
|--------|---------|---------|
| `id(varname)` | required | Numeric or fixed-width string person or episode identifier. |
| `start(varname)` | required | Inclusive daily window start. |
| `end(varname)` | required | Inclusive daily window end. |
| `axis(rule)` | required | Calendar, anniversary, or fixed periods. |
| `origin(varname)` | none | Anniversary origin or calendar relative-period origin. |
| `width(#)` | 1 | Period width. Unused with `axis(fixed)`. |
| `unit(unit)` | year | Day, month, or year periods. Unused with `axis(fixed)`. |
| `first(#)` | none | First retained period number. |
| `last(#)` | none | Last retained period number. |
| `partial(rule)` | keep | Keep, drop, or flag partial periods. |
| `clamp(# #)` | none | Intersect windows with study bounds. |
| `coverage(#\|varname)` | none | Truncate windows at a coverage start. |
| `generate(name)` | period | Period-number output name. |
| `relgen(name)` | rel_period | Relative-period output name when `origin()` is used. |
| `startgen(name)` | period_start | Observed-period start name. |
| `stopgen(name)` | period_stop | Observed-period stop name. |
| `pytime(name)` | person_years | Person-time output name. |
| `pyunit(unit)` | year | Store person-time in years or days. |
| `noinclusive` | off | Exclude each interval's terminal day from person-time and event attachment. |
| `keep(varlist)` | none | Copy source variables to period rows. |
| `saveas(filename)` | none | Save a grid while preserving the data in memory. |
| `replace` | off | Replace an existing `saveas()` target. |
| `noisily` | off | Display a build report. |

### pyattach

| Option | Default | Purpose |
|--------|---------|---------|
| `id(varname)` | required | Numeric or fixed-width string event identifier. |
| `date(varname)` | required | Integer Stata daily event date. |
| `count(name)` | none | Count attached event rows. |
| `sum(varname [name])` | none | Sum an event measure. |
| `any(name)` | none | Indicate one or more attached events. |
| `max(varname [name])` | none | Take an event-measure maximum. |
| `if(expression)` | none | Restrict the numerator in the using data. |
| `rate(name)` | none | Divide `count()` by grid person-time. |
| `nozerofill` | off | Leave no-event rows missing. |
| `orphans(policy)` | error | Error, report, or save unmatched eligible events. |
| `noisily` | off | Display an attachment report. |

## Stored Results

| Command | Results |
|---------|---------|
| `pygrid` scalars | `r(N_persons)`, `r(N_rows)`, `r(N_empty_window)`, `r(N_uncovered)`, `r(N_partial)`, `r(pytotal)`, `r(pymin)`, `r(pymax)`, `r(period_min)`, `r(period_max)` |
| `pygrid` macros | `r(axis)`, `r(width)`, `r(unit)`, `r(pyconvention)` |
| `pyattach` scalars | `r(N_using)`, `r(N_eligible)`, `r(N_attached)`, `r(N_orphan)`, `r(N_orphan_nokey)`, `r(N_zerofilled)`, `r(events)`, `r(rate_overall)` |

## QA

QA suites and how to run them are documented in [`qa/README.md`](qa/README.md).

## Version History

- **1.0.2** (13 October 2026): Compact `pygrid` and `pyattach` count lines (counts and person-time no longer pad to 12 and 14 columns). Documentation: with `axis(fixed)`, `width()` and `unit()` are unused and `r(width)`/`r(unit)` carry no period size; `pyunit(year)` is a 365.25-day divisor, so calendar years can be 0.999 or 1.002 person-years; the README synopsis no longer lists `count()` as required (at least one of `count()`, `sum()`, `any()`, `max()` is).
- **1.0.1** (30 August 2026): Rejects reversed source windows, adds tamper-detecting grid integrity stamps while preserving row-reordering support, pins and documents the January 1960 month-block origin, and strengthens rollback QA against asymmetric dataset comparisons.
- **1.0.0** (12 August 2026): Initial implementation of calendar, anniversary, and fixed grids; exact person-time; coverage and partial-period rules; zero-filled event attachment; orphan policies; and rate construction.

## Author

Timothy P Copeland, Karolinska Institutet

Questions and bug reports: [GitHub issues](https://github.com/tpcopeland/Stata-Tools/issues). Please include the first line of `which pygrid` and your Stata version.

To cite: Copeland TP. *pygrid: Person-period denominators with zero-filled events*. Stata-Tools, https://github.com/tpcopeland/Stata-Tools/tree/main/pygrid. Please give the version you used (`which pygrid` prints it).

## License

MIT (see [LICENSE](../LICENSE))
