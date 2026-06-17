---
title: "console_datamvp"
---

## Missing-value pattern table

<!-- * datamvp (datacheck's patterns engine) tabulates which variables are jointly -->

<!-- * missing. The biomarker dataset has nested missingness (x1 absent after obs 60, -->

<!-- * x4 after obs 70), so a few patterns dominate. -->

```stata
. use "`pkg_dir'/_demo_missing.dta", clear
```

```
(Biomarker Study with Missing Data Patterns)

```

```stata
. noisily datamvp x1 x2 x3 x4, percent sort
```

```
Variable     | Type     Obs    Miss   %Miss   Variable label
-------------+----------------------------------------
x3           |  double     52     28   35.0   Biomarker C
x2           |  double     60     20   25.0   Biomarker B
x1           |  double     60     20   25.0   Biomarker A
x4           |  double     70     10   12.5   Biomarker D
------------------------------------------------------

Missing value patterns

  +----------------------------------+
  | _pattern   _miss   _freq    _pct |
  |----------------------------------|
  |     ++++       0      38   47.50 |
  |     +.++       1      14   17.50 |
  |     .+.+       2       8   10.00 |
  |     .+++       1       7    8.75 |
  |     .+..       3       7    8.75 |
  |     ....       4       3    3.75 |
  |     ...+       3       2    2.50 |
  |     ..++       2       1    1.25 |
  +----------------------------------+

--------------------------------------------------
Total observations:              80
Complete cases:                  38  ( 47.5%)
Incomplete cases:                42  ( 52.5%)
Unique patterns:                  8
Variables analyzed:               4
Max missing/obs:                  4
Mean missing/obs:              0.97
--------------------------------------------------

```

## Monotone-missingness test

<!-- * Monotone missingness is the key precondition for sequential multiple -->

<!-- * imputation; datamvp tests for it directly. -->

```stata
. noisily datamvp x1 x2 x3 x4, monotone
```

```
Variable     | Type     Obs    Miss   %Miss   Variable label
-------------+----------------------------------------
x1           |  double     60     20   25.0   Biomarker A
x2           |  double     60     20   25.0   Biomarker B
x3           |  double     52     28   35.0   Biomarker C
x4           |  double     70     10   12.5   Biomarker D
------------------------------------------------------

Missing value patterns

  +--------------------------+
  | _pattern   _miss   _freq |
  |--------------------------|
  |     ++++       0      38 |
  |     +.++       1      14 |
  |     .+.+       2       8 |
  |     ++.+       1       7 |
  |     .+..       3       7 |
  |     ....       4       3 |
  |     ...+       3       2 |
  |     +..+       2       1 |
  +--------------------------+

--------------------------------------------------
Total observations:              80
Complete cases:                  38  ( 47.5%)
Incomplete cases:                42  ( 52.5%)
Unique patterns:                  8
Variables analyzed:               4
Max missing/obs:                  4
Mean missing/obs:              0.97
--------------------------------------------------

Monotone missingness test:
  Observations with monotone pattern:       41 ( 51.2%)
  Pattern is non-monotone

```
