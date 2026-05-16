# SYNTH-01 Clinical Trial Data Dictionary

Synthetic cohort for demonstration purposes

Version 1.0

## Table of Contents

1. [ Demo Cohort](#1--demo-cohort)
2. [Notes](#notes)
3. [Change Log](#change-log)


## 1.  Demo Cohort

**Filename:** `_demo_cohort.dta`  
**Description:** Dataset containing 15 variables and 200 observations.

### Variables

| Variable | Label | Type | Missing | Statistics/Values |
|----------|-------|------|---------|-------------------|
| `patient_id` | Patient identifier | Numeric | 0 (0.0%) | N=200<br>Median=100; IQR=50.50-150<br>Mean=100 (SD=57.88)<br>Range=1.00-200 |
| `patient_name` | Patient full name | String | 0 (0.0%) | N=200; 200 unique values |
| `age` | Age at enrollment (years) | Numeric | 0 (0.0%) | N=200<br>Median=53.65; IQR=44.05-63.20<br>Mean=53.86 (SD=14.68)<br>Range=-3.00-100 |
| `sex` | Biological sex | Numeric | 0 (0.0%) | Unique=2<br>0 Female (114; 57.0%)<br>1 Male (86; 43.0%) |
| `smoking` | Smoking status | Numeric | 36 (18.0%) | Unique=3<br>0 Never (59; 36.0%)<br>1 Former (53; 32.3%)<br>2 Current (52; 31.7%) |
| `bmi` | Body mass index (kg/m2) | Numeric | 17 (8.5%) | N=183<br>Median=27.30; IQR=23.10-30.60<br>Mean=26.90 (SD=5.27)<br>Range=11.60-42.30 |
| `sbp` | Systolic blood pressure (mmHg) | Numeric | 7 (3.5%) | N=193<br>Median=136; IQR=122-147<br>Mean=135 (SD=18.06)<br>Range=84.00-178 |
| `creatinine` | Serum creatinine (mg/dL) | Numeric | 24 (12.0%) | N=176<br>Median=1.04; IQR=0.770-1.28<br>Mean=1.03 (SD=0.368)<br>Range=0.200-1.88 |
| `pct_adherence` | Medication adherence (%) | Numeric | 38 (19.0%) | N=162<br>Median=78.65; IQR=64.20-90.80<br>Mean=78.32 (SD=19.86)<br>Range=28.20-138 |
| `enroll_date` | Date of enrollment | Date | 0 (0.0%) | N=200<br>Range: 2018/01/06 to 2019/12/28 |
| `birth_date` | Date of birth | Date | 0 (0.0%) | N=200<br>Range: 1918/03/29 to 2022/01/16 |
| `follow_up_time` | Follow-up time (years) | Numeric | 0 (0.0%) | N=200<br>Median=0.190; IQR=0.080-0.395<br>Mean=0.278 (SD=0.270)<br>Range=0-1.22 |
| `event` | Primary endpoint | Numeric | 0 (0.0%) | Unique=2<br>0 Censored (146; 73.0%)<br>1 Event (54; 27.0%) |
| `treatment` | Randomization arm | Numeric | 0 (0.0%) | Unique=2<br>0 Control (100; 50.0%)<br>1 Active (100; 50.0%) |
| `site` | Study site | Numeric | 0 (0.0%) | Unique=8<br>1 Stockholm (34; 17.0%)<br>2 Gothenburg (23; 11.5%)<br>3 Malmo (25; 12.5%)<br>4 Uppsala (23; 11.5%)<br>5 Linkoping (22; 11.0%)<br>6 Lund (16; 8.0%)<br>7 Umea (34; 17.0%)<br>8 Orebro (23; 11.5%) |


## Notes

- No additional notes provided


## Change Log

*No changes recorded.*


**Document Version:** 1.0

**Author:** T. Copeland, Karolinska Institutet

**Last Updated:** 15 May 2026
