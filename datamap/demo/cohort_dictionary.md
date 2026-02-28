# Synthetic Cohort Data Dictionary

Version 1.0

## Table of Contents

1. [Cohort](#1-cohort)
2. [Notes](#notes)
3. [Change Log](#change-log)

---

## 1. Cohort

**Filename:** `cohort.dta`  
**Description:** Dataset containing 12 variables and 15000 observations.

### Variables

| Variable | Label | Type | Missing | Statistics/Values |
|----------|-------|------|---------|-------------------|
| `id` | Person identifier | Numeric | 0 (0.0%) | N=15000<br>Median=7,500; IQR=3,750-11,250<br>Mean=7,500 (SD=4,330)<br>Range=1.00-15,000 |
| `female` | Female sex | Numeric | 0 (0.0%) | Unique=2<br>0 No (6028; 40.2%)<br>1 Yes (8972; 59.8%) |
| `study_entry` | Cohort entry date | Date | 0 (0.0%) | N=15000<br>Range: 2006/01/01 to 2020/12/30 |
| `index_age` | Age at cohort entry (years) | Numeric | 0 (0.0%) | N=15000<br>Median=59.29; IQR=48.75-68.89<br>Mean=58.36 (SD=13.35)<br>Range=19.23-84.86 |
| `birth_date` | Date of birth | Date | 0 (0.0%) | N=15000<br>Range: 1922/06/28 to 1998/09/06 |
| `education` | Education level | Numeric | 0 (0.0%) | Unique=3<br>1 Primary (3860; 25.7%)<br>2 Secondary (5884; 39.2%)<br>3 Tertiary (5256; 35.0%) |
| `income_quintile` | Disposable income quintile | Numeric | 0 (0.0%) | Unique=5<br>1 (2953; 19.7%)<br>2 (3032; 20.2%)<br>3 (2997; 20.0%)<br>4 (2995; 20.0%)<br>5 (3023; 20.2%) |
| `born_abroad` | Born outside Sweden | Numeric | 0 (0.0%) | Unique=2<br>0 No (12741; 84.9%)<br>1 Yes (2259; 15.1%) |
| `civil_status` | Marital status | Numeric | 0 (0.0%) | Unique=4<br>1 Single (4568; 30.5%)<br>2 Married (5236; 34.9%)<br>3 Divorced (2951; 19.7%)<br>4 Widowed (2245; 15.0%) |
| `region` | Healthcare region | Numeric | 0 (0.0%) | Unique=6<br>1 Stockholm (2613; 17.4%)<br>2 Uppsala/Orebro (2548; 17.0%)<br>3 Southeast (2501; 16.7%)<br>4 South (2474; 16.5%)<br>5 West (2385; 15.9%)<br>6 North (2479; 16.5%) |
| `death_date` | Date of death | Date | 13664 (91.1%) | N=1336<br>Range: 2006/06/03 to 2023/11/15 |
| `study_exit` | End of follow-up | Date | 0 (0.0%) | N=15000<br>Range: 2006/05/17 to 2023/12/31 |

---

## Notes

- All date variables are formatted as %tdCCYY/NN/DD (Stata date format)
- Missing values for categorical variables are typically coded as . (numeric missing) or empty string
- All datasets contain anonymous identifiers for linking

---

## Change Log

*No changes recorded.*

---

**Document Version:** 1.0

**Author:** Stata-Dev

**Last Updated:** 27 Feb 2026
