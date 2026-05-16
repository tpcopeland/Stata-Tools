# Data Dictionary

## Table of Contents

1. [Test Cohort Miss](#1-test-cohort-miss)
2. [Notes](#notes)
3. [Change Log](#change-log)


## 1. Test Cohort Miss

**Filename:** `test_cohort_miss.dta`  
**Description:** Dataset containing 8 variables and 100 observations.

### Variables

| Variable | Label | Type | Missing | Statistics/Values |
|----------|-------|------|---------|-------------------|
| `id` | Unique identifier | Numeric | 0 (0.0%) | N=100<br>Median=50.50; IQR=25.50-75.50<br>Mean=50.50 (SD=29.01)<br>Range=1.00-100 |
| `age` | Age in years | Numeric | 10 (10.0%) | N=90<br>Median=46.00; IQR=31.00-68.00<br>Mean=49.31 (SD=18.87)<br>Range=20.00-79.00 |
| `sex` | Sex of participant | Numeric | 0 (0.0%) | Unique=2<br>0 Female (46; 46.0%)<br>1 Male (54; 54.0%) |
| `bmi` | Body mass index | Numeric | 11 (11.0%) | N=89<br>Median=25.81; IQR=21.22-29.54<br>Mean=25.55 (SD=4.39)<br>Range=18.61-32.95 |
| `region` | Geographic region | Numeric | 6 (6.0%) | Unique=4<br>1 North (21; 22.3%)<br>2 South (30; 31.9%)<br>3 East (23; 24.5%)<br>4 West (20; 21.3%) |
| `entry_date` | Study entry date | Date | 0 (0.0%) | N=100<br>Range: 2020/01/03 to 2020/12/25 |
| `exit_date` | Study exit date | Date | 0 (0.0%) | N=100<br>Range: 2020/02/23 to 2021/11/09 |
| `name` | Participant name | String | 0 (0.0%) | N=100; 100 unique values |


## Notes

- No additional notes provided


## Change Log

*No changes recorded.*


**Last Updated:** <normalized>
