---
title: "console_datamap_map"
---

## Markdown map with document options

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
. quietly datamap, output("`map_integrity'.md") exclude(patient_id subject_id patient_name) ///
>     datesafe mincell(5) autodetect quality samples(3) missing(detail)
```

```stata
. quietly datasignature
```

```stata
. assert "`map_signature'" == "`r(datasignature)'"
```

```stata
. noisily display as result "In-memory integrity check: datamap left the datasignature unchanged"
```

```
In-memory integrity check: datamap left the datasignature unchanged

```

```stata
. noisily datamap, single("`pkg_dir'/_demo_cohort.dta") ///
>     output("`pkg_dir'/datamap_clinical.md") ///
>     title("SYNTH-01 Clinical Trial Map") ///
>     subtitle("Synthetic cohort for demonstration purposes") ///
>     version("1.1") docdate("10 Nov 2026") author("Timothy P Copeland, Karolinska Institutet") ///
>     exclude(patient_id subject_id patient_name) ///
>     datesafe mincell(5) autodetect quality samples(3) missing(detail)
```

```
Output written to: datamap/demo/datamap_clinical.md
Documentation generated successfully

```

```stata
. noisily display as text "Map excerpt:"
```

```
Map excerpt:

```

```stata
. noisily _demo_type_head using "`pkg_dir'/datamap_clinical.md", lines(90)
```

```
# SYNTH-01 Clinical Trial Map

Synthetic cohort for demonstration purposes

Version 1.1

## Contents

1. [_demo_cohort](#1-_demo_cohort)

## 1. _demo_cohort

- Source: `datamap/demo/_demo_cohort.dta`
- Label: Synthetic Clinical Trial Cohort (N=1200)
- Observations: 1200
- Variables: 17
- Data signature: `1200:17(68284):809950434:1697081388`
- Disclosure: 3 excluded (`patient_id`, `subject_id`, `patient_name`); cells below 5 suppressed; date-safe on; likely identifiers not excluded: none

### Variables

| Variable | Label | Type | Missing | Values/Statistics |
|---|---|---|---|---|
| `patient_id` | Patient identifier | double | 0 (0.0%) | excluded (structure only) |
| `subject_id` | Study subject identifier | double | 0 (0.0%) | excluded (structure only) |
| `patient_name` | Patient full name | str32 | 0 (0.0%) | excluded (structure only) |
| `age` | Age at enrollment (years) | double | 0 (0.0%) | N=1200; mean=57.59; SD=12.10; median=58.20; IQR=49.15-65.50; range=-3.00 to 97.70 |
| `sex` | Biological sex | double | 0 (0.0%) | 0 Female: 586 (48.8%)<br>1 Male: 614 (51.2%) |
| `smoking` | Smoking status | double | 188 (15.7%) | 0 Never: 352 (29.3%)<br>1 Former: 315 (26.3%)<br>2 Current: 345 (28.8%) |
| `bmi` | Body mass index (kg/m2) | double | 91 (7.6%) | N=1109; mean=27.27; SD=5.14; median=27.30; IQR=23.80-30.50; range=7.90-44.20 |
| `sbp` | Systolic blood pressure (mmHg) | double | 51 (4.3%) | N=1149; mean=136; SD=19.37; median=135; IQR=123-148; range=73.00-200.00 |
| `creatinine` | Serum creatinine (mg/dL) | double | 142 (11.8%) | N=1058; mean=1.03; SD=0.354; median=1.04; IQR=0.790-1.260; range=-0.070 to 2.270 |
| `pct_adherence` | Medication adherence (%) | double | 232 (19.3%) | N=968; mean=78.01; SD=17.96; median=78.20; IQR=66.80-89.25; range=25.10-147.30 |
| `enroll_date` | Date of enrollment | double %td daily | 0 (0.0%) | N=1200; span 898 days (exact dates withheld) |
| `birth_date` | Date of birth | double %td daily | 0 (0.0%) | N=1200; span 27760 days (exact dates withheld) |
| `follow_up_time` | Follow-up time (years) | double | 0 (0.0%) | N=1200; mean=3.53; SD=3.40; median=2.48; IQR=1.08-4.86; range=0.00-24.21 |
| `event` | Primary endpoint | double | 0 (0.0%) | 0 Censored: 872 (72.7%)<br>1 Event: 328 (27.3%) |
| `treatment` | Randomization arm | double | 0 (0.0%) | 0 Control: 617 (51.4%)<br>1 Active: 583 (48.6%) |
| `site` | Study site | double | 0 (0.0%) | 1 Stockholm: 207 (17.3%)<br>2 Gothenburg: 202 (16.8%)<br>3 Malmo: suppressed (complementary)<br>4 Uppsala: 209 (17.4%)<br>5 Linkoping: 196 (16.3%)<br>6 Lund: 194 (16.2%)<br>9 Satellite clinic: suppressed (<5) |
| `rare_marker` | Rare clinical marker | double | 0 (0.0%) | 0 Absent: suppressed (complementary)<br>1 Present: suppressed (<5) |

### Flags

- `age`: negative age values

### Candidates (not applied)

No placeholder candidates.

### Structure (inferred)

- Survival time variables: `follow_up_time`
  - `follow_up_time` range: 0 to 24.2
- Survival event indicators: `event`
  - `event` rate: 27.3% of nonmissing values
- Name patterns: IDs `patient_id`, `subject_id`, `patient_name`; dates `enroll_date`, `birth_date`; outcomes `event`; exposures `treatment`; demographics `age`, `sex`

### Missingness

- Variables more than 50% missing: 0
- Variables more than 10% missing: 3
- Complete rows: 624 (52.0%)

### Sample rows

First 3 rows (excluded variables masked; dates suppressed):

| patient_id | subject_id | patient_name | age | sex | smoking | bmi | sbp | creatinine | pct_adherence | enroll_date | birth_date | follow_up_time | event | treatment | site | rare_marker |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [MASKED] | [MASKED] | [MASKED] | -3 | 1 | 2 | 24.1 | 107 | 1.14 | . | [DATE SUPPRESSED] | [DATE SUPPRESSED] | 1.3 | 0 | 1 | 9 | 1 |
| [MASKED] | [MASKED] | [MASKED] | 56.1 | 1 | 1 | 26.3 | 90 | 1.49 | 69.9 | [DATE SUPPRESSED] | [DATE SUPPRESSED] | 4.84 | 0 | 1 | 9 | 1 |
| [MASKED] | [MASKED] | [MASKED] | 84.2 | 1 | 0 | 25 | 136 | .64 | 83.5 | [DATE SUPPRESSED] | [DATE SUPPRESSED] | .52 | 1 | 1 | 9 | 1 |

**Document Version:** 1.1

**Author:** Timothy P Copeland, Karolinska Institutet

**Last Updated:** 10 Nov 2026

```

```stata
. noisily display as text "Suppressed frequency cells:"
```

```
Suppressed frequency cells:

```

```stata
. noisily _demo_type_matches using "`pkg_dir'/datamap_clinical.md", ///
>     text("suppressed (") lines(8)
```

```
| `site` | Study site | double | 0 (0.0%) | 1 Stockholm: 207 (17.3%)<br>2 Gothenburg: 202 (16.8%)<br>3 Malmo: suppressed (complementary)<br>4 Uppsala: 209 (17.4%)<br>5 Linkoping: 196 (16.3%)<br>6 Lund: 194 (16.2%)<br>9 Satellite clinic: suppressed (<5) |
| `rare_marker` | Rare clinical marker | double | 0 (0.0%) | 0 Absent: suppressed (complementary)<br>1 Present: suppressed (<5) |

```
