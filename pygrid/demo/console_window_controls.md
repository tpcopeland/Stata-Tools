---
title: "console_window_controls"
---

## Coverage, study bounds, relative periods, and partial-period flags

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
