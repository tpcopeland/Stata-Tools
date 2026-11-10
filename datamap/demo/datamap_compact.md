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

