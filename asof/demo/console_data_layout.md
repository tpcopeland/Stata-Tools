---
title: "console_data_layout"
---

## Start with a master cohort and a long measurement table

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
