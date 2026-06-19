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
(file datamap/demo/datamap_compact.txt not found)
(file /tmp/St647618.000003 not found)
Output written to: datamap/demo/datamap_compact.txt
Documentation generated successfully

```

```stata
. noisily _demo_strip_trailing_spaces using "`pkg_dir'/datamap_compact.txt"
```

```
(file /tmp/St647618.000001 not found)

```

```stata
. noisily _demo_type_head using "`pkg_dir'/datamap_compact.txt", lines(56)
```

```
Dataset Documentation
Generated: 19 Jun 2026 15:17:40

========================================
DATASET: _demo_cohort.dta
========================================

METADATA
--------
Observations: 160
Variables: 17
Label: Synthetic Clinical Trial Cohort (N=160)
Data Signature: 160:17(68284):1184352066:4157885057

DISCLOSURE RISK SUMMARY
-----------------------
Excluded variables: 3
Small-cell threshold: 5
Date-safe mode: on
Likely identifiers not excluded: 0

DESCRIPTION
-----------
This dataset contains cross-sectional data. It includes 160 observations and 17 variables. The data includes date variab
```

```stata
> les (exact range suppressed for privacy). Key variable categories include: identifiers, demographics, clinical data, o
> utcomes.
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
  age                     double    continuous      0.0%     136
  sex                     double    categorical     0.0%       2
  smoking                 double    categorical    16.3%       3
  bmi                     double    continuous      8.1%     104
  sbp                     double    continuous      6.3%      64
  creatinine              double    continuous     14.4%      84
  pct_adherence           double    continuous     23.8%     110
  enroll_date             double    date            0.0%     152
  birth_date              double    date            0.0%     160
  follow_up_time          double    continuous      0.0%      72
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
