---
title: "console_datamap_compact"
---

## Compact map

```stata
. noisily datamap, single("`pkg_dir'/_demo_cohort.dta") ///
>     output("`pkg_dir'/datamap_compact.md") ///
>     compact exclude(patient_id subject_id patient_name) datesafe mincell(5)
```

```
Output written to: datamap/demo/datamap_compact.md
Documentation generated successfully

```

```stata
. noisily _demo_type_head using "`pkg_dir'/datamap_compact.md", lines(60)
```

```
## 1. _demo_cohort

- Source: `datamap/demo/_demo_cohort.dta`
- Label: Synthetic Clinical Trial Cohort (N=1200)
- Observations: 1200
- Variables: 17
- Data signature: `1200:17(68284):809950434:1697081388`
- Disclosure: 3 excluded (`patient_id`, `subject_id`, `patient_name`); cells below 5 suppressed; date-safe on; likely identifiers not excluded: none

### Variables

| Variable | Type | Label | Missing | Unique |
|---|---|---|---|---|
| `patient_id` | double | Patient identifier | 0 (0.0%) | . |
| `subject_id` | double | Study subject identifier | 0 (0.0%) | . |
| `patient_name` | str32 | Patient full name | 0 (0.0%) | . |
| `age` | double | Age at enrollment (years) | 0 (0.0%) | 450 |
| `sex` | double | Biological sex | 0 (0.0%) | 2 |
| `smoking` | double | Smoking status | 188 (15.7%) | 3 |
| `bmi` | double | Body mass index (kg/m2) | 91 (7.6%) | 238 |
| `sbp` | double | Systolic blood pressure (mmHg) | 51 (4.3%) | 108 |
| `creatinine` | double | Serum creatinine (mg/dL) | 142 (11.8%) | 168 |
| `pct_adherence` | double | Medication adherence (%) | 232 (19.3%) | 534 |
| `enroll_date` | double %td daily | Date of enrollment | 0 (0.0%) | 649 |
| `birth_date` | double %td daily | Date of birth | 0 (0.0%) | >1000 |
| `follow_up_time` | double | Follow-up time (years) | 0 (0.0%) | 643 |
| `event` | double | Primary endpoint | 0 (0.0%) | 2 |
| `treatment` | double | Randomization arm | 0 (0.0%) | 2 |
| `site` | double | Study site | 0 (0.0%) | 7 |
| `rare_marker` | double | Rare clinical marker | 0 (0.0%) | 2 |


```

## Missing-data patterns

```stata
. noisily datamap, single("`pkg_dir'/_demo_missing.dta") ///
>     output("`pkg_dir'/datamap_missing.md") ///
>     exclude(id) missing(pattern) quality mincell(5)
```

```
Output written to: datamap/demo/datamap_missing.md
Documentation generated successfully

```

```stata
. noisily _demo_type_head using "`pkg_dir'/datamap_missing.md", lines(80)
```

```
## 1. _demo_missing

- Source: `datamap/demo/_demo_missing.dta`
- Label: Biomarker Study with Missing Data Patterns
- Observations: 80
- Variables: 6
- Data signature: `80:6(26080):323884870:1380290782`
- Disclosure: 1 excluded (`id`); cells below 5 suppressed; date-safe off; likely identifiers not excluded: none

### Variables

| Variable | Label | Type | Missing | Values/Statistics |
|---|---|---|---|---|
| `id` | Subject ID | double | 0 (0.0%) | excluded (structure only) |
| `x1` | Biomarker A | double | 20 (25.0%) | N=60; mean=-0.097; SD=1.13; median=-0.035; IQR=-0.659 to 0.361; range=-3.15 to 3.33 |
| `x2` | Biomarker B | double | 20 (25.0%) | N=60; mean=0.048; SD=1.19; median=0.134; IQR=-0.790 to 0.858; range=-2.79 to 2.81 |
| `x3` | Biomarker C | double | 28 (35.0%) | N=52; mean=0.010; SD=1.02; median=0.022; IQR=-0.712 to 0.816; range=-2.16 to 2.37 |
| `x4` | Biomarker D | double | 10 (12.5%) | N=70; mean=-0.011; SD=1.03; median=0.003; IQR=-0.679 to 0.433; range=-2.00 to 4.66 |
| `outcome` | Binary outcome | double | 0 (0.0%) | 0 No: 50 (62.5%)<br>1 Yes: 30 (37.5%) |

### Flags

No quality flags.

### Candidates (not applied)

No placeholder candidates.

### Missingness

- Variables more than 50% missing: 0
- Variables more than 10% missing: 4
- Complete rows: 38 (47.5%)
- Missing-value patterns (+ observed, . missing) over `x1`, `x2`, `x3`, `x4`: 8 distinct
  - `++++`: 38 (47.5%)
  - `+.++`: 14 (17.5%)
  - `.+.+`: suppressed (complementary)
  - `++.+`: suppressed (complementary)
  - `.+..`: suppressed (complementary)
  - `....`: suppressed (<5)
  - `...+`: suppressed (<5)
  - `+..+`: suppressed (<5)


```
