---
title: "console_datacheck"
---

## Console QC profile

<!-- * datacheck profiles the data in memory: per-class distributions, missingness, -->

<!-- * key structure, and quality flags. The cohort carries a deliberate age = -3 -->

<!-- * outlier, a 115% adherence value, a rare "Satellite clinic" site, and missing -->

<!-- * biomarkers, so the flags and missingness blocks are populated. -->

```stata
. use "`pkg_dir'/_demo_cohort.dta", clear
```

```
(Synthetic Clinical Trial Cohort (N=160))

```

```stata
. noisily datacheck age sex smoking bmi pct_adherence site,
>     id(patient_id) outliers(3) rare(5)
```

```
datacheck: 160 obs, 6 variables profiled  (complete cases: 99 = 61.9%)

QUICK REFERENCE
  Variable              Class       Type       Miss%   Unique  Flag
  age                   continuous  double      0.0%      136  outliers
  sex                   categorical double      0.0%        2
  smoking               categorical double     16.3%        3  missing
  bmi                   continuous  double      8.1%      104  missing
  pct_adherence         continuous  double     23.8%      110  missing
  site                  categorical double      0.0%        7  rare

CONTINUOUS
  age:  N=160  mean=     57.27  sd=     13.43
    min=        -3  p25=      48.8  p50=      56.8  p75=     65.35  max=      96.8
    1 outlier(s) (0.6%) beyond 3 IQR
  bmi:  N=147  mean=     27.15  sd=      5.15
    min=      13.1  p25=      23.4  p50=      27.1  p75=      30.8  max=      41.8
  pct_adherence:  N=122  mean=     76.96  sd=      20.1
    min=      34.1  p25=      63.4  p50=     78.55  p75=      91.3  max=     120.5

CATEGORICAL
  sex:  2 levels
    1 Male                             83  (51.9%)
    0 Female                           77  (48.1%)
  smoking:  3 levels
    1 Former                           48  (30.0%)
    0 Never                            46  (28.8%)
    2 Current                          40  (25.0%)
    .                                  26  (16.2%)
  site:  7 levels
    2 Gothenburg                       34  (21.2%)
    1 Stockholm                        31  (19.4%)
    6 Lund                             26  (16.2%)
    4 Uppsala                          24  (15.0%)
    3 Malmo                            23  (14.4%)
    5 Linkoping                        19  (11.9%)
    9 Satellite clinic                  3  ( 1.9%)  <rare

MISSINGNESS
  smoking                 26 missing  (16.3%)
  bmi                     13 missing  ( 8.1%)
  pct_adherence           38 missing  (23.8%)

KEY STRUCTURE
  key (patient_id):  160 obs, 160 distinct, records/key min/median/max = 1/1/1, 0 key(s) with >1 record

```

## Expectation gate (warn mode)

<!-- * The same expectations run as a gate. With warn, violations are reported and -->

<!-- * execution continues; drop warn to halt the do-file with r(9) instead. -->

```stata
. noisily datacheck age pct_adherence, expectn(160) isid(patient_id)
>     notmissing(age sex) inrange(age 18 110 \ pct_adherence 0 100) warn
```

```
datacheck: 160 obs, 2 variables profiled  (complete cases: 122 = 76.3%)

QUICK REFERENCE
  Variable              Class       Type       Miss%   Unique  Flag
  age                   continuous  double      0.0%      136
  pct_adherence         continuous  double     23.8%      110  missing

CONTINUOUS
  age:  N=160  mean=     57.27  sd=     13.43
    min=        -3  p25=      48.8  p50=      56.8  p75=     65.35  max=      96.8
  pct_adherence:  N=122  mean=     76.96  sd=      20.1
    min=      34.1  p25=      63.4  p50=     78.55  p75=      91.3  max=     120.5

MISSINGNESS
  pct_adherence           38 missing  (23.8%)

KEY STRUCTURE
  (id() not given; inferred from identifier-like names)
  key (patient_id):  160 obs, 160 distinct, records/key min/median/max = 1/1/1, 0 key(s) with >1 record

WARNINGS (2)
  inrange(age): 1 obs outside [18, 110]  (min -3, max 96.8)
  inrange(pct_adherence): 14 obs outside [0, 100]  (min 34.1, max 120.5)

```
