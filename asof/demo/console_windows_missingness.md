---
title: "console_windows_missingness"
---

## Intersect a protocol window with each patient's observed period

### By default, every carried value must be nonmissing

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

### require() can allow a matched record whose carried value is missing

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
