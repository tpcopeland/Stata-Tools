# SYNTH-01 Clinical Trial Data Dictionary

Synthetic cohort for demonstration purposes

Version 1.1

## Table of Contents

1. [ Demo Cohort](#1--demo-cohort)
2. [Notes](#notes)
3. [Change Log](#change-log)


## 1.  Demo Cohort

**Filename:** `_demo_cohort.dta`  
**Description:** Dataset containing 17 variables and 160 observations.

### Variables

| Variable | Label | Type | Missing | Statistics/Values |
|----------|-------|------|---------|-------------------|
| `patient_id` | Patient identifier | Numeric | 0 (0.0%) | N=160<br>Median=100,080; IQR=100,040-100,120<br>Mean=100,080 (SD=46.33)<br>Range=100,001-100,160 |
| `subject_id` | Study subject identifier | Numeric | 0 (0.0%) | N=160<br>Median=5,080; IQR=5,040-5,120<br>Mean=5,080 (SD=46.33)<br>Range=5,001-5,160 |
| `patient_name` | Patient full name | String | 0 (0.0%) | N=160; 160 unique values |
| `age` | Age at enrollment (years) | Numeric | 0 (0.0%) | N=160<br>Median=56.80; IQR=48.80-65.35<br>Mean=57.27 (SD=13.43)<br>Range=-3.00-96.80 |
| `sex` | Biological sex | Numeric | 0 (0.0%) | Unique=2<br>0 Female (77; 48.1%)<br>1 Male (83; 51.9%) |
| `smoking` | Smoking status | Numeric | 26 (16.2%) | Unique=3<br>0 Never (46; 34.3%)<br>1 Former (48; 35.8%)<br>2 Current (40; 29.9%) |
| `bmi` | Body mass index (kg/m2) | Numeric | 13 (8.1%) | N=147<br>Median=27.10; IQR=23.40-30.80<br>Mean=27.15 (SD=5.15)<br>Range=13.10-41.80 |
| `sbp` | Systolic blood pressure (mmHg) | Numeric | 10 (6.2%) | N=150<br>Median=137; IQR=122-148<br>Mean=136 (SD=19.07)<br>Range=74.00-192 |
| `creatinine` | Serum creatinine (mg/dL) | Numeric | 23 (14.4%) | N=137<br>Median=1.05; IQR=0.810-1.24<br>Mean=1.03 (SD=0.333)<br>Range=0.160-1.73 |
| `pct_adherence` | Medication adherence (%) | Numeric | 38 (23.8%) | N=122<br>Median=78.55; IQR=63.40-91.30<br>Mean=76.96 (SD=20.10)<br>Range=34.10-120 |
| `enroll_date` | Date of enrollment | Date | 0 (0.0%) | N=160<br>Range: 02/01/2021 to 16/06/2023 |
| `birth_date` | Date of birth | Date | 0 (0.0%) | N=160<br>Range: 17/03/1925 to 04/05/2000 |
| `follow_up_time` | Follow-up time (years) | Numeric | 0 (0.0%) | N=160<br>Median=0.240; IQR=0.100-0.445<br>Mean=0.309 (SD=0.282)<br>Range=0-1.72 |
| `event` | Primary endpoint | Numeric | 0 (0.0%) | Unique=2<br>0 Censored (120; 75.0%)<br>1 Event (40; 25.0%) |
| `treatment` | Randomization arm | Numeric | 0 (0.0%) | Unique=2<br>0 Control (88; 55.0%)<br>1 Active (72; 45.0%) |
| `site` | Study site | Numeric | 0 (0.0%) | Unique=7<br>1 Stockholm (31; 19.4%)<br>2 Gothenburg (34; 21.2%)<br>3 Malmo (23; 14.4%)<br>4 Uppsala (24; 15.0%)<br>5 Linkoping (19; 11.9%)<br>6 Lund (26; 16.2%)<br>9 Satellite clinic (3; 1.9%) |
| `rare_marker` | Rare clinical marker | Numeric | 0 (0.0%) | Unique=2<br>0 Absent (157; 98.1%)<br>1 Present (3; 1.9%) |


## Notes

- No additional notes provided


## Change Log

*No changes recorded.*


**Document Version:** 1.1

**Author:** Timothy P Copeland, Karolinska Institutet

**Last Updated:** 17 Jun 2026
