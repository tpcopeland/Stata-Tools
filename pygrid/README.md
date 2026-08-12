# pygrid

**Version 1.0.0** | 2026-08-12

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

`pygrid` turns inclusive person-level observation windows into exact person-period denominators. Its companion command `pyattach` attaches event counts, sums, indicators, maxima, and rates while retaining zero-event periods by default.

## Installation

```stata
net install pygrid, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/pygrid")
```

The package requires Stata 16 or later and has no runtime dependencies.

Identifiers may be numeric or fixed-width strings. All date variables and numeric date bounds must contain integer Stata daily dates; datetime and fractional values are rejected.

## Syntax

```stata
pygrid [if] [in], id(varname) start(varname) end(varname) axis(calendar|anniversary|fixed) [options]
pyattach using filename, id(varname) date(varname) count(name) [options]
```

Use `help pygrid` and `help pyattach` for the complete option and stored-result contracts.

## pygrid options

| Option | Default | Purpose |
|--------|---------|---------|
| **id(varname)** | required | Numeric or fixed-width string person or episode identifier. |
| **start(varname)** | required | Inclusive daily window start. |
| **end(varname)** | required | Inclusive daily window end. |
| **axis(rule)** | required | Calendar, anniversary, or fixed periods. |
| **origin(varname)** | none | Anniversary origin or calendar relative-period origin. |
| **width(#)** | 1 | Period width. |
| **unit(unit)** | year | Day, month, or year periods. |
| **first(#)** | none | First retained period number. |
| **last(#)** | none | Last retained period number. |
| **partial(rule)** | keep | Keep, drop, or flag partial periods. |
| **clamp(# #)** | none | Intersect windows with study bounds. |
| **coverage(#\|varname)** | none | Truncate windows at a coverage start. |
| **generate(name)** | period | Period-number output name. |
| **relgen(name)** | rel_period | Relative-period output name when `origin()` is used. |
| **startgen(name)** | period_start | Observed-period start name. |
| **stopgen(name)** | period_stop | Observed-period stop name. |
| **pytime(name)** | person_years | Person-time output name. |
| **pyunit(unit)** | year | Store person-time in years or days. |
| **noinclusive** | off | Exclude each interval's terminal day from person-time and event attachment. |
| **keep(varlist)** | none | Copy source variables to period rows. |
| **saveas(filename)** | none | Save a grid while preserving the data in memory. |
| **replace** | off | Replace an existing `saveas()` target. |
| **noisily** | off | Display a build report. |

## pyattach options

| Option | Default | Purpose |
|--------|---------|---------|
| **id(varname)** | required | Numeric or fixed-width string event identifier. |
| **date(varname)** | required | Integer Stata daily event date. |
| **count(name)** | none | Count attached event rows. |
| **sum(varname [name])** | none | Sum an event measure. |
| **any(name)** | none | Indicate one or more attached events. |
| **max(varname [name])** | none | Take an event-measure maximum. |
| **if(expression)** | none | Restrict the numerator in the using data. |
| **rate(name)** | none | Divide `count()` by grid person-time. |
| **nozerofill** | off | Leave no-event rows missing. |
| **orphans(policy)** | error | Error, report, or save unmatched eligible events. |
| **noisily** | off | Display an attachment report. |

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
pygrid:            3 persons,            7 period rows
  empty windows:            0   partial periods:            3
  person-time:        5.07598   axis: calendar   convention: inclusive

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
pyattach:            2 orphan event row(s);            1 have id() absent from the grid
pyattach:            7 eligible events,            5 attached
  orphans:            2   zero-event grid rows:            3
  overall event rate:        .985032

```

```stata
. format person_years %9.3f total_cost %9.0fc events_per_py %9.2f
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
  | 101   Clinic A     2019      15jun2019     31dec2019          0.548          1         1.82625 |
  | 101   Clinic A     2020      01jan2020     31dec2020          1.002          2       1.9959016 |
  | 101   Clinic A     2021      01jan2021     31dec2021          0.999          0               0 |
  | 101   Clinic A     2022      01jan2022     20mar2022          0.216          1       4.6234177 |
  |------------------------------------------------------------------------------------------------|
  | 102   Clinic B     2020      01jan2020     31dec2020          1.002          0               0 |
  | 102   Clinic B     2021      01jan2021     31dec2021          0.999          1       1.0006849 |
  |------------------------------------------------------------------------------------------------|
  | 103   Clinic A     2021      10sep2021     31dec2021          0.309          0               0 |
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
pygrid:            2 persons,            7 period rows
  empty windows:            0   partial periods:            2
  person-time:        5.76591   axis: anniversary   convention: inclusive

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

#### Fixed windows and person-time in days

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
pygrid:            2 persons,            2 period rows
  empty windows:            0   partial periods:            0
  person-time:           2106   axis: fixed   convention: inclusive

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
pygrid:            2 persons,            6 period rows
  empty windows:            1   partial periods:            3
  person-time:        4.79671   axis: calendar   convention: inclusive

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

## Stored results

| Command | Results |
|---------|---------|
| `pygrid` scalars | `r(N_persons)`, `r(N_rows)`, `r(N_empty_window)`, `r(N_uncovered)`, `r(N_partial)`, `r(pytotal)`, `r(pymin)`, `r(pymax)`, `r(period_min)`, `r(period_max)` |
| `pygrid` macros | `r(axis)`, `r(width)`, `r(unit)`, `r(pyconvention)` |
| `pyattach` scalars | `r(N_using)`, `r(N_eligible)`, `r(N_attached)`, `r(N_orphan)`, `r(N_orphan_nokey)`, `r(N_zerofilled)`, `r(events)`, `r(rate_overall)` |

## Version history

- **1.0.0** (12 August 2026): Initial implementation of calendar, anniversary, and fixed grids; exact person-time; coverage and partial-period rules; zero-filled event attachment; orphan policies; and rate construction.

## QA

See [`qa/README.md`](qa/README.md) for the suite inventory, coverage, cross-validation, benchmark, and run commands.

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT License
