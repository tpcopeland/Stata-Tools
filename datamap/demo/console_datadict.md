---
title: "console_datadict"
---

## Markdown dictionary with shared classification

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
. local dict_signature "`r(datasignature)'"
```

```stata
. tempfile dict_integrity
```

```stata
. quietly datadict,
>     output("`dict_integrity'.md")
>     missing stats dateformat(%tdDD/NN/CCYY)
```

```stata
. quietly datasignature
```

```stata
. assert "`dict_signature'" == "`r(datasignature)'"
```

```stata
. noisily display as result
```

```
>     "In-memory integrity check: datadict left the datasignature unchanged"
In-memory integrity check: datadict left the datasignature unchanged

```

```stata
. noisily datadict, single("`pkg_dir'/_demo_cohort.dta")
>     output("`pkg_dir'/datadict_clinical.md")
>     title("SYNTH-01 Clinical Trial Data Dictionary")
>     subtitle("Synthetic cohort for demonstration purposes")
>     version("1.1")
>     author("Timothy P Copeland, Karolinska Institutet")
>     missing stats dateformat(%tdDD/NN/CCYY)
```

```
Output written to: datamap/demo/datadict_clinical.md
Markdown dictionary generated: datamap/demo/datadict_clinical.md

```

```stata
. noisily _demo_type_head using "`pkg_dir'/datadict_clinical.md", lines(76)
```

```
# SYNTH-01 Clinical Trial Data Dictionary

Synthetic cohort for demonstration purposes

Version 1.1

## Table of Contents

1. [ Demo Cohort](#1--demo-cohort)
2. [Notes](#notes)
3. [Change Log](#change-log)


## 1.  Demo Cohort

**Filename:** `_demo_cohort.dta`
**Source path:** `datamap/demo/_demo_cohort.dta`
**Description:** Dataset containing 17 variables and 1200 observations.
**Observations:** 1200
**Variables in file:** 17
**Variables documented:** 17
**File size:** 204,694 bytes

### Variables

| Variable | Label | Type | Missing | Statistics/Values |
|---|---|---|---|---|
| `patient_id` | Patient identifier | Numeric | 0 (0.0%) | N=1200<br>Median=100,600; IQR=100,300-100,900<br>Mean=100,600
>  (SD=347)<br>Range=100,001-101,200 |
| `subject_id` | Study subject identifier | Numeric | 0 (0.0%) | N=1200<br>Median=5,600; IQR=5,300-5,900<br>Mean=5,600 (
```

```stata
> SD=347)<br>Range=5,001-6,200 |
```

```
| `patient_name` | Patient full name | String | 0 (0.0%) | N=1200; >1000 unique values |
| `age` | Age at enrollment (years) | Numeric | 0 (0.0%) | N=1200<br>Median=58.20; IQR=49.15-65.50<br>Mean=57.59 (SD=12.
> 10)<br>Range=-3.00-97.70 |
| `sex` | Biological sex | Numeric | 0 (0.0%) | Unique=2<br>0 Female (586; 48.8%)<br>1 Male (614; 51.2%) |
| `smoking` | Smoking status | Numeric | 188 (15.7%) | Unique=3<br>0 Never (352; 34.8%)<br>1 Former (315; 31.1%)<br>2 Cu
```

```stata
> rrent (345; 34.1%) |
```

```
| `bmi` | Body mass index (kg/m2) | Numeric | 91 (7.6%) | N=1109<br>Median=27.30; IQR=23.80-30.50<br>Mean=27.27 (SD=5.14
> )<br>Range=7.90-44.20 |
| `sbp` | Systolic blood pressure (mmHg) | Numeric | 51 (4.2%) | N=1149<br>Median=135; IQR=123-148<br>Mean=136 (SD=19.37
> )<br>Range=73.00-200 |
| `creatinine` | Serum creatinine (mg/dL) | Numeric | 142 (11.8%) | N=1058<br>Median=1.04; IQR=0.790-1.26<br>Mean=1.03 (
```

```stata
> SD=0.354)<br>Range=-0.070-2.27 |
```

```
| `pct_adherence` | Medication adherence (%) | Numeric | 232 (19.3%) | N=968<br>Median=78.20; IQR=66.80-89.25<br>Mean=78
> .01 (SD=17.96)<br>Range=25.10-147 |
| `enroll_date` | Date of enrollment | Date | 0 (0.0%) | N=1200<br>Range: 01/01/2021 to 18/06/2023 |
| `birth_date` | Date of birth | Date | 0 (0.0%) | N=1200<br>Range: 29/11/1924 to 30/11/2000 |
| `follow_up_time` | Follow-up time (years) | Numeric | 0 (0.0%) | N=1200<br>Median=0.200; IQR=0.090-0.400<br>Mean=0.288
>  (SD=0.277)<br>Range=0-1.98 |
| `event` | Primary endpoint | Numeric | 0 (0.0%) | Unique=2<br>0 Censored (872; 72.7%)<br>1 Event (328; 27.3%) |
| `treatment` | Randomization arm | Numeric | 0 (0.0%) | Unique=2<br>0 Control (617; 51.4%)<br>1 Active (583; 48.6%) |
| `site` | Study site | Numeric | 0 (0.0%) | Unique=7<br>1 Stockholm (207; 17.2%)<br>2 Gothenburg (202; 16.8%)<br>3 Malm
```

```stata
> o (189; 15.8%)<br>4 Uppsala (209; 17.4%)<br>5 Linkoping (196; 16.3%)<br>6 Lund (194; 16.2%)<br>9 Satellite clinic (sup
> pressed <5) |
```

```
| `rare_marker` | Rare clinical marker | Numeric | 0 (0.0%) | Unique=2<br>0 Absent (1197; 99.8%)<br>1 Present (suppresse
```

```stata
> d <5) |
```

```
## Notes

- All date variables are displayed using %tdDD/NN/CCYY format
- Missing values coded as . (numeric missing) or empty string


## Change Log

*No changes recorded.*


**Document Version:** 1.1

**Author:** Timothy P Copeland, Karolinska Institutet

**Last Updated:** 15 Jul 2026

```

```stata
. noisily display as text "Capped dictionary rows:"
```

```
Capped dictionary rows:

```

```stata
. noisily _demo_type_matches using "`pkg_dir'/datadict_clinical.md",
>     text(">1000") lines(6)
```

```
| `patient_name` | Patient full name | String | 0 (0.0%) | N=1200; >1000 unique values |

```
