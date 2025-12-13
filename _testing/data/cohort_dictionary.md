# Data Dictionary: cohort

---

## 1. Cohort

**Filename:** `cohort.dta`  
**Description:** Dataset containing 9 variables and 1000 observations.

### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `id` | Patient ID | Numeric | Unique identifier |
| `female` | Female sex | Numeric | 0=Male, 1=Female |
| `age` | Age at study entry | Numeric |  |
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
