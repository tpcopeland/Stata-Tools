---
title: "console_frames_multivariable"
---

## Carry several variables from an in-memory frame

### Wildcards resolve in the using frame; require() controls missingness

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

### Repeated master keys receive the same selection without changing order

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

### The complete r() contract remains available after frame input

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
