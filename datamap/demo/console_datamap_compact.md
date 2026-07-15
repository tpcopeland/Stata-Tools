---
title: "console_datamap_compact"
---

## Compact text map

```stata
. noisily datamap, single("`pkg_dir'/_demo_cohort.dta")
>     output("`pkg_dir'/datamap_compact.txt")
>     compact exclude(patient_id subject_id patient_name) datesafe mincell(5)
```

```
Output written to: datamap/demo/datamap_compact.txt
Documentation generated successfully

```

```stata
. quietly _demo_strip_trailing_spaces using "`pkg_dir'/datamap_compact.txt"
```

```stata
. noisily _demo_type_head using "`pkg_dir'/datamap_compact.txt", lines(56)
```

```
Dataset Documentation
Generated: 15 Jul 2026 00:26:56

========================================
DATASET: _demo_cohort.dta
========================================

METADATA
--------
Observations: 1200
Variables: 17
Label: Synthetic Clinical Trial Cohort (N=1200)
Data Signature: 1200:17(68284):2844760337:3810411015

DISCLOSURE RISK SUMMARY
-----------------------
Excluded variables: 3
Small-cell threshold: 5
Date-safe mode: on
Likely identifiers not excluded: 0

DESCRIPTION
-----------
This dataset contains cross-sectional data. It includes 1200 observations and 17 variables. The data includes date varia
```

```stata
> bles (exact range suppressed for privacy). Key variable categories include: identifiers, demographics, clinical data,
> outcomes.
```

```
========================================
VARIABLE SUMMARY
========================================

QUICK REFERENCE
----------------------------------------
  Variable                Type      Class          Miss%  Unique
  patient_id              double    excluded        0.0%       .
  subject_id              double    excluded        0.0%       .
  patient_name            str32     excluded        0.0%       .
  age                     double    continuous      0.0%     450
  sex                     double    categorical     0.0%       2
  smoking                 double    categorical    15.7%       3
  bmi                     double    continuous      7.6%     238
  sbp                     double    continuous      4.3%     108
  creatinine              double    continuous     11.8%     168
  pct_adherence           double    continuous     19.3%     534
  enroll_date             double    date            0.0%     649
  birth_date              double    date            0.0%   >1000
  follow_up_time          double    continuous      0.0%     123
  event                   double    categorical     0.0%       2
  treatment               double    categorical     0.0%       2
  site                    double    categorical     0.0%       7
  rare_marker             double    categorical     0.0%       2
----------------------------------------

  patient_id
    Type: double
    Format: %10.0g
    Label: Patient identifier
    Missing: 0 (0.0%)
... [output truncated]

```
