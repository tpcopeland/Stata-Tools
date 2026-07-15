---
title: "console_datacheck"
---

## Console QC profile

<!-- * datacheck profiles the data in memory: per-class distributions, missingness, -->

<!-- * key structure, and quality flags. The cohort carries a deliberate age = -3 -->

<!-- * outlier, a 115% adherence value, a rare "Satellite clinic" site, and missing -->

<!-- * biomarkers. Its 1,200 distinct IDs also exercise v1.6.0's capped count display. -->

```stata
. use "`pkg_dir'/_demo_cohort.dta", clear
```

```
(Synthetic Clinical Trial Cohort (N=1200))

```

```stata
. noisily datacheck patient_id age sex smoking bmi pct_adherence site,
>     id(patient_id) outliers(3) rare(5)
```

```
datacheck: 1200 obs, 7 variables profiled  (complete cases: 760 = 63.3%)

QUICK REFERENCE
  Variable              Class       Type       Miss%   Unique  Flag
  patient_id            continuous  double      0.0%    >1000
  age                   continuous  double      0.0%      450  outliers
  sex                   categorical double      0.0%        2
  smoking               categorical double     15.7%        3  missing
  bmi                   continuous  double      7.6%      238  missing
  pct_adherence         continuous  double     19.3%      534  missing
  site                  categorical double      0.0%        7  rare

CONTINUOUS
  patient_id:  N=1200  mean=    100601  sd=     346.6
    min=    100001  p25=    100301  p50=    100601  p75=    100901  max=    101200
  age:  N=1200  mean=     57.59  sd=      12.1
    min=        -3  p25=     49.15  p50=      58.2  p75=      65.5  max=      97.7
    1 outlier(s) (0.1%) beyond 3 IQR
  bmi:  N=1109  mean=     27.27  sd=     5.145
    min=       7.9  p25=      23.8  p50=      27.3  p75=      30.5  max=      44.2
  pct_adherence:  N=968  mean=     78.01  sd=     17.96
    min=      25.1  p25=      66.8  p50=      78.2  p75=     89.25  max=     147.3

CATEGORICAL
  sex:  2 levels
    1 Male                            614  (51.2%)
    0 Female                          586  (48.8%)
  smoking:  3 levels
    0 Never                           352  (29.3%)
    2 Current                         345  (28.8%)
    1 Former                          315  (26.2%)
    .                                 188  (15.7%)
  site:  7 levels
    4 Uppsala                         209  (17.4%)
    1 Stockholm                       207  (17.2%)
    2 Gothenburg                      202  (16.8%)
    5 Linkoping                       196  (16.3%)
    6 Lund                            194  (16.2%)
    3 Malmo                           189  (15.8%)
    9 Satellite clinic                  3  ( 0.2%)  <rare

MISSINGNESS
  smoking                 188 missing  (15.7%)
  bmi                     91 missing  ( 7.6%)
  pct_adherence           232 missing  (19.3%)

KEY STRUCTURE
  key (patient_id):  1200 obs, 1200 distinct, records/key min/median/max = 1/1/1, 0 key(s) with >1 record

```

## Expectation gate (warn mode)

<!-- * The same expectations run as a gate. With warn, violations are reported and -->

<!-- * execution continues; drop warn to halt the do-file with r(9) instead. -->

```stata
. noisily datacheck age pct_adherence, expectn(1200) isid(patient_id)
>     notmissing(age sex) inrange(age 18 110 \ pct_adherence 0 100) warn
```

```
datacheck: 1200 obs, 2 variables profiled  (complete cases: 968 = 80.7%)

QUICK REFERENCE
  Variable              Class       Type       Miss%   Unique  Flag
  age                   continuous  double      0.0%      450
  pct_adherence         continuous  double     19.3%      534  missing

CONTINUOUS
  age:  N=1200  mean=     57.59  sd=      12.1
    min=        -3  p25=     49.15  p50=      58.2  p75=      65.5  max=      97.7
  pct_adherence:  N=968  mean=     78.01  sd=     17.96
    min=      25.1  p25=      66.8  p50=      78.2  p75=     89.25  max=     147.3

MISSINGNESS
  pct_adherence           232 missing  (19.3%)

KEY STRUCTURE
  (id() not given; inferred from identifier-like names)
  key (patient_id):  1200 obs, 1200 distinct, records/key min/median/max = 1/1/1, 0 key(s) with >1 record

WARNINGS (2)
  inrange(age): 1 obs outside [18, 110]  (min -3, max 97.7)
  inrange(pct_adherence): 110 obs outside [0, 100]  (min 25.1, max 147.3)

```
