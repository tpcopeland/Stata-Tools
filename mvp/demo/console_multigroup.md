---
title: "console_multigroup"
---

```stata
. noisily display as text "--- Placebo ---"
```

```
--- Placebo ---

```

```stata
. noisily mvp bmi sbp ldl hba1c if arm == 0, percent sort
```

```
Variable     | Type     Obs    Miss   %Miss   Variable label
-------------+-----------------------------------------
hba1c        |  double    130     37   22.2   HbA1c
ldl          |  double    144     23   13.8   LDL cholesterol
bmi          |  double    151     16    9.6   Body mass index
sbp          |  double    153     14    8.4   Systolic BP
-------------------------------------------------------

Missing value patterns

  +----------------------------------+
  | _pattern   _miss   _freq    _pct |
  |----------------------------------|
  |     ++++       0      95   56.89 |
  |     .+++       1      22   13.17 |
  |     ++.+       1      13    7.78 |
  |     +.++       1      11    6.59 |
  |     ..++       2      11    6.59 |
  |     +++.       1       8    4.79 |
  |     .++.       2       3    1.80 |
  |     ++..       2       2    1.20 |
  |     +.+.       2       1    0.60 |
  |     .+.+       2       1    0.60 |
  +----------------------------------+

--------------------------------------------------
Total observations:             167
Complete cases:                  95  ( 56.9%)
Incomplete cases:                72  ( 43.1%)
Unique patterns:                 10
Variables analyzed:               4
Max missing/obs:                  2
Mean missing/obs:              0.54
--------------------------------------------------

```

```stata
. noisily display as text ""
```

```stata
. noisily display as text "--- Low dose ---"
```

```
--- Low dose ---

```

```stata
. noisily mvp bmi sbp ldl hba1c if arm == 1, percent sort
```

```
Variable     | Type     Obs    Miss   %Miss   Variable label
-------------+-----------------------------------------
hba1c        |  double    121     46   27.5   HbA1c
ldl          |  double    144     23   13.8   LDL cholesterol
bmi          |  double    149     18   10.8   Body mass index
sbp          |  double    163      4    2.4   Systolic BP
-------------------------------------------------------

Missing value patterns

  +----------------------------------+
  | _pattern   _miss   _freq    _pct |
  |----------------------------------|
  |     ++++       0      94   56.29 |
  |     .+++       1      30   17.96 |
  |     +.++       1      11    6.59 |
  |     ++.+       1      10    5.99 |
  |     ..++       2      10    5.99 |
  |     .+.+       2       6    3.59 |
  |     +++.       1       4    2.40 |
  |     +..+       2       2    1.20 |
  +----------------------------------+

--------------------------------------------------
Total observations:             167
Complete cases:                  94  ( 56.3%)
Incomplete cases:                73  ( 43.7%)
Unique patterns:                  8
Variables analyzed:               4
Max missing/obs:                  2
Mean missing/obs:              0.54
--------------------------------------------------

```

```stata
. noisily display as text ""
```

```stata
. noisily display as text "--- High dose ---"
```

```
--- High dose ---

```

```stata
. noisily mvp bmi sbp ldl hba1c if arm == 2, percent sort
```

```
Variable     | Type     Obs    Miss   %Miss   Variable label
-------------+-----------------------------------------
hba1c        |  double     97     69   41.6   HbA1c
ldl          |  double    116     50   30.1   LDL cholesterol
bmi          |  double    152     14    8.4   Body mass index
sbp          |  double    154     12    7.2   Systolic BP
-------------------------------------------------------

Missing value patterns

  +----------------------------------+
  | _pattern   _miss   _freq    _pct |
  |----------------------------------|
  |     ++++       0      67   40.36 |
  |     .+++       1      31   18.67 |
  |     ..++       2      26   15.66 |
  |     +.++       1      17   10.24 |
  |     .+.+       2       6    3.61 |
  |     +++.       1       4    2.41 |
  |     ++.+       1       4    2.41 |
  |     .++.       2       3    1.81 |
  |     +.+.       2       2    1.20 |
  |     +..+       2       2    1.20 |
  |     ..+.       3       2    1.20 |
  |     ++..       2       1    0.60 |
  |     ...+       3       1    0.60 |
  +----------------------------------+

--------------------------------------------------
Total observations:             166
Complete cases:                  67  ( 40.4%)
Incomplete cases:                99  ( 59.6%)
Unique patterns:                 13
Variables analyzed:               4
Max missing/obs:                  3
Mean missing/obs:              0.87
--------------------------------------------------

```
