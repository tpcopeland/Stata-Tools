# Data Dictionary: cohort

---

## 1. Cohort

**Filename:** `cohort.dta`  
**Description:** Dataset containing 16 variables and 1000 observations.

### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `id` | Patient ID | Numeric | Unique identifier |
| `female` | Female sex | Numeric | 0=Male, 1=Female |
| `age` | Age at study entry | Numeric |  |
| `edss_baseline` | Baseline EDSS score | Numeric |  |
| `bmi` | Body mass index | Numeric |  |
| `education` | Education level | Numeric | 1=Primary, 2=Secondary, 3=Tertiary, 4=Postgraduate |
| `income_q` | Income quintile | Numeric |  |
| `comorbidity` | Number of comorbidities | Numeric |  |
| `smoking` | Smoking status | Numeric | 0=Never, 1=Former, 2=Current |
| `region` | County of residence | Numeric |  |
| `mstype` | MS type | Numeric | 1=RRMS, 2=SPMS, 3=PPMS, 4=CIS |
| `study_entry` | Study entry date | Date | Date |
| `edss4_dt` | Date reached EDSS 4.0 | Date | Date |
| `death_dt` | Date of death | Date | Date |
| `emigration_dt` | Date of emigration | Date | Date |
| `study_exit` | Study exit date | Date | Date |

---

## Notes

- All date variables are formatted as %tdCCYY/NN/DD (Stata date format)
- Missing values coded as . (numeric missing) or empty string

---

**Last Updated:** 13 Dec 2025
