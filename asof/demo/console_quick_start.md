---
title: "console_quick_start"
---

## Closest nonmissing score on either side of index

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
