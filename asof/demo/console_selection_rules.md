---
title: "console_selection_rules"
---

## Compare selection rules for the same patient and anchor

### Patient 101 has equidistant records before and after index

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

### first and last select the earliest and latest eligible dates

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
