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
warning: likely identifier variable(s) not in exclude(): patient_id subject_id patient_name
Output written to: datamap/demo/datamap_warning.txt
Documentation generated successfully

```

```stata
. quietly _demo_strip_trailing_spaces using "`pkg_dir'/datamap_warning.txt"
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
Excluded variables: 0
Small-cell threshold: 5
Date-safe mode: off
Likely identifiers not excluded: patient_id subject_id patient_name

DESCRIPTION
-----------
This dataset contains cross-sectional data. It includes 1200 observations and 17 variables. The data spans from 1924/11/
> 29 to 2023/06/18. Key variable categories include: identifiers, demographics, clinical data, outcomes.

========================================
VARIABLE SUMMARY
========================================

QUICK REFERENCE
----------------------------------------
  Variable                Type      Class          Miss%  Unique
... [output truncated]

```

```stata
. noisily display as text "Capped unique-count excerpt:"
```

```
Capped unique-count excerpt:

```

```stata
. noisily _demo_type_matches using "`pkg_dir'/datamap_warning.txt",
>     text(">1000") lines(6)
```

```
  patient_id              double    continuous      0.0%   >1000
  subject_id              double    continuous      0.0%   >1000
  patient_name            str32     string          0.0%   >1000
  birth_date              double    date            0.0%   >1000

```

## Privacy-safe text map

```stata
. use "`pkg_dir'/_demo_cohort.dta", clear
```

```
(Synthetic Clinical Trial Cohort (N=1200))

```

```stata
. quietly datasignature
```

```stata
. local map_signature "`r(datasignature)'"
```

```stata
. tempfile map_integrity
```

```stata
. quietly datamap,
>     output("`map_integrity'.txt")
>     exclude(patient_id subject_id patient_name)
>     datesafe mincell(5) autodetect quality samples(3) missing(detail)
```

```stata
. quietly datasignature
```

```stata
. assert "`map_signature'" == "`r(datasignature)'"
```

```stata
. noisily display as result
```

```
>     "In-memory integrity check: datamap left the datasignature unchanged"
In-memory integrity check: datamap left the datasignature unchanged

```

```stata
. noisily datamap, single("`pkg_dir'/_demo_cohort.dta")
>     output("`pkg_dir'/datamap_clinical.txt")
>     exclude(patient_id subject_id patient_name)
>     datesafe mincell(5) autodetect quality samples(3) missing(detail)
```

```
Output written to: datamap/demo/datamap_clinical.txt
Documentation generated successfully

```

```stata
. quietly _demo_strip_trailing_spaces using "`pkg_dir'/datamap_clinical.txt"
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
Survival Analysis Variables Detected
  Likely time variables: follow_up_time
    follow_up_time range: 0 to 2
  Likely event indicators: event
    event rate: 27.3%

Common Variable Patterns Detected
  Likely IDs: patient_id subject_id patient_name
  Likely dates: enroll_date birth_date
  Likely outcomes: event
  Likely exposures: treatment
  Demographics: age sex

Missing Data Summary
  Variables with >50% missing: 0
  Variables with >10% missing: 3
  Observations with complete data: 624 (52%)

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
... [output truncated]

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
| [MASKED] | [MASKED] | [MASKED] | -3 | 1 | 2 | 24.1 | 107 | 1.14 | . | [DATE SUPPRESSED] | [DATE SUPPRESSED] | .11 | 0
> | 1 | 9 | 1 |
| [MASKED] | [MASKED] | [MASKED] | 56.1 | 1 | 1 | 26.3 | 90 | 1.49 | 69.9 | [DATE SUPPRESSED] | [DATE SUPPRESSED] | .39
> | 0 | 1 | 9 | 1 |
| [MASKED] | [MASKED] | [MASKED] | 84.2 | 1 | 0 | 25 | 136 | .64 | 83.5 | [DATE SUPPRESSED] | [DATE SUPPRESSED] | .04 |
> 1 | 1 | 9 | 1 |

```
