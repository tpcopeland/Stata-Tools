---
title: "console_datamap_privacy"
---

## Likely identifier warning

```stata
. noisily datamap, single("`pkg_dir'/_demo_cohort.dta")
>     output("`pkg_dir'/datamap_warning.txt")
>     mincell(5) noguidance compact
```

```
(file /tmp/St647618.000003 not found)
warning: likely identifier variable(s) not in exclude(): patient_id subject_id patient_name
Output written to: datamap/demo/datamap_warning.txt
Documentation generated successfully

```

```stata
. noisily _demo_strip_trailing_spaces using "`pkg_dir'/datamap_warning.txt"
```

```
(file /tmp/St647618.000001 not found)

```

```stata
. noisily display as text ""
```

```stata
. noisily display as text "Disclosure-risk summary excerpt:"
```

```
Disclosure-risk summary excerpt:

```

```stata
. noisily _demo_type_head using "`pkg_dir'/datamap_warning.txt", lines(32)
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
Excluded variables: 0
Small-cell threshold: 5
Date-safe mode: off
Likely identifiers not excluded: patient_id subject_id patient_name

DESCRIPTION
-----------
This dataset contains cross-sectional data. It includes 160 observations and 17 variables. The data spans from 1925/03/1
> 7 to 2023/06/16. Key variable categories include: identifiers, demographics, clinical data, outcomes.

========================================
VARIABLE SUMMARY
========================================

QUICK REFERENCE
----------------------------------------
  Variable                Type      Class          Miss%  Unique
... [output truncated]

```

## Privacy-safe text map

```stata
. noisily datamap, single("`pkg_dir'/_demo_cohort.dta")
>     output("`pkg_dir'/datamap_clinical.txt")
>     exclude(patient_id subject_id patient_name)
>     datesafe mincell(5) autodetect quality samples(3) missing(detail)
```

```
(file datamap/demo/datamap_clinical.txt not found)
(file /tmp/St647618.000003 not found)
Output written to: datamap/demo/datamap_clinical.txt
Documentation generated successfully

```

```stata
. noisily _demo_strip_trailing_spaces using "`pkg_dir'/datamap_clinical.txt"
```

```
(file /tmp/St647618.000001 not found)

```

```stata
. noisily display as text ""
```

```stata
. noisily display as text "Privacy-safe map excerpt:"
```

```
Privacy-safe map excerpt:

```

```stata
. noisily _demo_type_head using "`pkg_dir'/datamap_clinical.txt", lines(72)
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
Survival Analysis Variables Detected
  Likely time variables: follow_up_time
    follow_up_time range: 0 to 1.7
  Likely event indicators: event
    event rate: 25%

Common Variable Patterns Detected
  Likely IDs: patient_id subject_id patient_name
  Likely dates: enroll_date birth_date
  Likely outcomes: event
  Likely exposures: treatment
  Demographics: age sex

Missing Data Summary
  Variables with >50% missing: 0
  Variables with >10% missing: 3
  Observations with complete data: 79 (49.4%)

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
... [output truncated]

```

```stata
. noisily display as text ""
```

```stata
. noisily display as text "Suppressed frequency cells:"
```

```
Suppressed frequency cells:

```

```stata
. noisily _demo_type_matches using "`pkg_dir'/datamap_clinical.txt",
>     text("suppressed (<5)") lines(8)
```

```
    9 = Satellite clinic: suppressed (<5)
    1 = Present: suppressed (<5)
    1 (Present): suppressed (<5)

```

```stata
. noisily display as text ""
```

```stata
. noisily display as text "Date-safe sample rows:"
```

```
Date-safe sample rows:

```

```stata
. noisily _demo_type_matches using "`pkg_dir'/datamap_clinical.txt",
>     text("[DATE SUPPRESSED]") lines(6)
```

```
| [MASKED] | [MASKED] | [MASKED] | -3 | 1 | 1 | 27.5 | 157 | 1.39 | 83.7 | [DATE SUPPRESSED] | [DATE SUPPRESSED] | .29 |
>  1 | 1 | 9 | 1 |
| [MASKED] | [MASKED] | [MASKED] | 56.1 | 0 | 2 | 26.1 | 143 | 1.2 | 66.6 | [DATE SUPPRESSED] | [DATE SUPPRESSED] | .1 |
>  0 | 0 | 9 | 1 |
| [MASKED] | [MASKED] | [MASKED] | 84.2 | 0 | . | 31.5 | 147 | . | 63.4 | [DATE SUPPRESSED] | [DATE SUPPRESSED] | .07 |
> 0 | 1 | 9 | 1 |

```
