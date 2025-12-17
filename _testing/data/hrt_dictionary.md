# Data Dictionary: hrt

---

## 1. Hrt

**Filename:** `hrt.dta`  
**Description:** Dataset containing 5 variables and 1858 observations.

### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `id` | Patient ID | Numeric | Unique identifier |
| `rx_start` | Prescription start date | Date | Date |
| `rx_stop` | Prescription end date | Date | Date |
| `hrt_type` | HRT type | Numeric | 1=Estrogen, 2=Combined, 3=Progestin |
| `dose` | Daily dose (mg) | Numeric |  |

---

## Notes

- All date variables are formatted as %tdCCYY/NN/DD (Stata date format)
- Missing values coded as . (numeric missing) or empty string

---

**Last Updated:** 13 Dec 2025
