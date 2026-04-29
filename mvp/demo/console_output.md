---
title: "console_output"
---

```stata
. noisily mvp age female bmi sbp ldl hba1c,
>     percent sort monotone correlate
```

```
Variables with no missing: age female


Variable     | Type     Obs    Miss   %Miss   Variable label
-------------+-----------------------------------------
hba1c        |  double    369    131   26.2   HbA1c
ldl          |  double    417     83   16.6   LDL cholesterol
bmi          |  double    452     48    9.6   Body mass index
sbp          |  double    470     30    6.0   Systolic BP
-------------------------------------------------------

Missing value patterns

  +----------------------------------+
  | _pattern   _miss   _freq    _pct |
  |----------------------------------|
  |     ++++       0     276   55.20 |
  |     .+++       1      74   14.80 |
  |     ..++       2      40    8.00 |
  |     +.++       1      35    7.00 |
  |     ++.+       1      32    6.40 |
  |     +++.       1      18    3.60 |
  |     .+.+       2       9    1.80 |
  |     .++.       2       5    1.00 |
  |     ++..       2       3    0.60 |
  |     +..+       2       3    0.60 |
  |     +.+.       2       2    0.40 |
  |     ..+.       3       2    0.40 |
  |     ...+       3       1    0.20 |
  +----------------------------------+

--------------------------------------------------
Total observations:             500
Complete cases:                 276  ( 55.2%)
Incomplete cases:               224  ( 44.8%)
Unique patterns:                 13
Variables analyzed:               4
Max missing/obs:                  3
Mean missing/obs:              0.58
--------------------------------------------------

Monotone missingness test:
  Observations with monotone pattern:      297 ( 59.4%)
  Pattern is non-monotone

Tetrachoric correlations of missingness:
(correlations among missingness indicators)

        hba1c     ldl     bmi     sbp
hba1c   1.000
  ldl   0.453   1.000
  bmi  -0.097  -0.217   1.000
  sbp  -0.045  -0.070   0.012   1.000

```
