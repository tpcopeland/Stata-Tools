---
title: "console_datamap_safe"
---

## datamap, safe

<!-- * safe = mincell(5) or more, datesafe, exclude(auto), no sample rows and no listed -->

<!-- * values of text. It limits printed output and written files; stored results are -->

<!-- * not masked. -->

```stata
. noisily datamap, single("`pkg_dir'/_demo_cohort.dta") ///
>     output("`pkg_dir'/datamap_safe.md") safe
```

```
Output written to: datamap/demo/datamap_safe.md
Documentation generated successfully

```

```stata
. noisily display as text "Excluded as likely identifiers: `r(excluded_vars)'"
```

```
Excluded as likely identifiers: patient_id subject_id patient_name

```

```stata
. noisily display as text "safe stored as r(safe) = `r(safe)'"
```

```
safe stored as r(safe) = 1

```

```stata
. noisily _demo_type_head using "`pkg_dir'/datamap_safe.md", lines(36)
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


```

## safe refuses sample rows

```stata
. capture noisily datamap, single("`pkg_dir'/_demo_cohort.dta") ///
>     output("`pkg_dir'/datamap_safe.md") safe samples(3)
```

```
samples() prints rows of data; it cannot be combined with safe

```

```stata
. noisily display as text "return code: " _rc
```

```
return code: 198

```

## saving(): one row per variable as a table

```stata
. noisily datamap, single("`pkg_dir'/_demo_cohort.dta") ///
>     output("`pkg_dir'/datamap_safe.md") safe ///
>     saving("`pkg_dir'/datamap_vars", replace csv)
```

```
Output written to: datamap/demo/datamap_safe.md
Documentation generated successfully

```

```stata
. noisily display as text "CSV written: `r(metadata_csv)'"
```

```
CSV written: datamap/demo/datamap_vars.csv

```

```stata
. preserve
```

```stata
. quietly import delimited using "`pkg_dir'/datamap_vars.csv", clear varnames(1) stringcols(_all)
```

```stata
. noisily display as text "Columns in the metadata table: " c(k)
```

```
Columns in the metadata table: 37

```

```stata
. noisily list variable class storage_type missing missing_pct in 1/6, noobs abbreviate(14)
```

```
  +-------------------------------------------------------------------+
  |     variable         class   storage_type   missing   missing_pct |
  |-------------------------------------------------------------------|
  |   patient_id      excluded         double         0             0 |
  |   subject_id      excluded         double         0             0 |
  | patient_name      excluded          str32         0             0 |
  |          age    continuous         double         0             0 |
  |          sex   categorical         double         0             0 |
  |-------------------------------------------------------------------|
  |      smoking   categorical         double       188          15.7 |
  +-------------------------------------------------------------------+

```

```stata
. restore
```

```stata
. capture erase "`pkg_dir'/datamap_vars.dta"
```

## dataqa set agent

<!-- * dataqa set agent makes safe the session default for datamap and dataprobe. -->

```stata
. use "`pkg_dir'/_demo_cohort.dta", clear
```

```
(Synthetic Clinical Trial Cohort (N=1200))

```

```stata
. noisily dataqa set agent
```

```
dataqa session defaults: safe
  safe: datamap, dataprobe and datamvp print and write under their safe preset (maskrare, mincell(5) or more, datesafe, likely identifiers excluded); stored results are not masked

```

```stata
. noisily datamap, output("`pkg_dir'/datamap_agent.md")
```

```
Output written to: datamap/demo/datamap_agent.md
Documentation generated successfully

```

```stata
. noisily display as text "Session default applied: r(safe) = `r(safe)'"
```

```
Session default applied: r(safe) = 1

```

```stata
. noisily dataqa set clear
```

```
dataqa: session defaults cleared

```
