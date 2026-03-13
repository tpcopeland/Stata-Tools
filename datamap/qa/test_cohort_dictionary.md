# Data Dictionary: test_cohort

---

## 1. Test Cohort

**Filename:** `test_cohort.dta`  
**Description:** Dataset containing 8 variables and 100 observations.

### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `id` | Unique identifier | Numeric | Unique identifier |
| `age` | Age in years | Numeric |  |
| `sex` | Sex of participant | Numeric | 0=Female, 1=Male |
| `bmi` | Body mass index | Numeric |  |
| `region` | Geographic region | Numeric | 1=North, 2=South, 3=East, 4=West |
| `entry_date` | Study entry date | Date | Date |
| `exit_date` | Study exit date | Date | Date |
| `name` | Participant name | String |  |

---

## Notes

- All date variables are formatted as %tdCCYY/NN/DD (Stata date format)
- Missing values coded as . (numeric missing) or empty string

---

**Last Updated:** 13 Mar 2026
