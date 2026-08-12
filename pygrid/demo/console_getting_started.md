---
title: "console_getting_started"
---

## Getting started: one row per observed calendar year

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
