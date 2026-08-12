---
title: "console_event_attachment"
---

## Attach counts, costs, indicators, maxima, and rates

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
