# Comprehensive Stress Test Data for tvtools Reimplementations

## Overview

This directory contains comprehensive synthetic test datasets specifically designed to stress-test the tvtools reimplementations (Python and R). The data includes numerous edge cases and boundary conditions that real-world implementations must handle correctly.

## Generated Files

### 1. `stress_cohort.csv` (1,000 patients)
**Columns:** `patient_id`, `study_entry`, `study_exit`, `age`, `sex`

**Characteristics:**
- 1,000 patients (IDs 1-1000)
- Study entry dates spread across 2015-2016
- Study exit dates 2-6 years after entry (range: 734-2,189 days)
- Age uniformly distributed 30-80 years
- Sex: ~50% M, ~50% F

**Statistics:**
- Mean study duration: 1,469.75 days (~4 years)
- Median study duration: 1,486.50 days

---

### 2. `stress_exposures.csv` (4,708 records)
**Columns:** `patient_id`, `exp_start`, `exp_stop`, `drug_type`

**Drug types:** 0 (reference), 1, 2, 3 (evenly distributed)

**Edge Cases Included:**

| Edge Case | Count | Percentage |
|-----------|-------|------------|
| Zero-duration exposures | 206 | 4.4% |
| Very short (1-3 days) | 414 | 8.8% |
| Short (4-14 days) | 433 | 9.2% |
| Medium (15-180 days) | 2,014 | 42.8% |
| Long (181-730 days) | 773 | 16.4% |
| Very long (>730 days) | 868 | 18.4% |
| Exposures before study entry | 217 | 4.6% |
| Exposures after study exit | 1,083 | 23.0% |
| Overlapping exposure pairs | 1,745 | 37.1% of pairs |
| Adjacent exposure pairs | 77 | 1.6% of pairs |

**Coverage:**
- 895 patients with exposures (89.5%)
- 105 patients with NO exposures (10.5%)
- Average 5.26 exposures per exposed patient
- Duration range: 0 to 2,309 days

---

### 3. `stress_exposures2.csv` (2,857 records)
**Columns:** `patient_id`, `exp_start`, `exp_stop`, `drug_type`

**Purpose:** Second exposure dataset for testing `tvmerge` and multi-exposure scenarios

**Drug types:** 0 (reference), 1, 2, 3 (evenly distributed)

**Edge Cases Included:**

| Edge Case | Count | Percentage |
|-----------|-------|------------|
| Zero-duration exposures | 126 | 4.4% |
| Very short (1-3 days) | 257 | 9.0% |
| Short (4-14 days) | 224 | 7.8% |
| Medium (15-180 days) | 1,321 | 46.2% |
| Long (181-730 days) | 433 | 15.2% |
| Very long (>730 days) | 496 | 17.4% |
| Overlapping exposure pairs | 806 | 28.2% of pairs |
| Adjacent exposure pairs | 70 | 2.4% of pairs |

**Coverage:**
- 854 patients with exposures (85.4%)
- 146 patients with NO exposures (14.6%)
- Average 3.35 exposures per exposed patient
- Duration range: 0 to 2,297 days

---

### 4. `stress_events.csv` (1,000 records)
**Columns:** `patient_id`, `mi_date`, `death_date`, `emigration_date`

**Event Types:**
- `mi_date`: Primary event (myocardial infarction) - 286 patients (28.6%)
- `death_date`: Competing risk 1 - 157 patients (15.7%)
- `emigration_date`: Competing risk 2 - 93 patients (9.3%)

**Date Format:** String format "YYYY-MM-DD" (tests date parsing)

**Edge Cases Included:**

| Edge Case | Count | Description |
|-----------|-------|-------------|
| Events before study entry | 24 | Invalid dates (should be excluded) |
| Events after study exit | 23 | Invalid dates (should be excluded) |
| Events at study entry | ~5% each | Boundary condition |
| Events at study exit | ~5% each | Boundary condition |
| MI and death same date | 6 | Competing risks on same day |
| MI and emigration same date | 4 | Competing risks on same day |
| Death and emigration same date | 0 | (rare in this dataset) |

**Event Distribution:**
- Patients with 0 events: 540 (54.0%)
- Patients with 1 event: 389 (38.9%)
- Patients with 2 events: 66 (6.6%)
- Patients with 3 events: 5 (0.5%)

---

## Key Edge Cases to Test

### 1. Zero-Duration Exposures
**Challenge:** Exposures where `exp_start == exp_stop`
**Expected Behavior:** Should be handled gracefully (0-day exposure or excluded based on function)
**Test with:** `tvsplit`, `tvmerge`, `tvcoxph`

### 2. Overlapping Exposures
**Challenge:** Same patient has overlapping exposure periods
**Expected Behavior:** Functions should handle overlaps (merge, split, or error depending on function)
**Test with:** `tvmerge`, `tvcoxph`
**Example:** Patient 1 has exposure 2016-12-27 to 2019-09-30 overlapping with 2017-01-06 to 2018-07-10

### 3. Adjacent Exposures
**Challenge:** One exposure ends exactly when the next begins (end date = start date)
**Expected Behavior:** No gap between exposures
**Test with:** `tvmerge`, `tvsplit`
**Count:** 77 adjacent pairs (147 total adjacent pairs across both datasets)

### 4. Exposures Outside Study Period
**Challenge:** Exposures that start before `study_entry` or end after `study_exit`
**Expected Behavior:** Should be clipped to study boundaries
**Test with:** `tvsplit`, `tvmerge`
- Before entry: 217 exposures (4.6%)
- After exit: 1,083 exposures (23.0%)

### 5. Very Short vs Very Long Exposures
**Challenge:** Wide range of exposure durations
**Expected Behavior:** All durations should be handled correctly
**Range:** 0 to 2,309 days
- Very short (1-3 days): 414 exposures
- Very long (>730 days): 868 exposures

### 6. Multiple Events on Same Date
**Challenge:** Competing risks occurring on the same day
**Expected Behavior:** Functions should handle ties appropriately
**Test with:** `tvcoxph` (competing risks)
- MI and death same date: 6 patients
- MI and emigration same date: 4 patients

### 7. Events Outside Study Period
**Challenge:** Invalid event dates (before entry or after exit)
**Expected Behavior:** Should be excluded or flagged
**Test with:** `tvcoxph`, `tvsplit`
- Before entry: 24 events
- After exit: 23 events

### 8. Events at Exact Boundaries
**Challenge:** Events occurring exactly at `study_entry` or `study_exit`
**Expected Behavior:** Should be included correctly at boundaries
**Frequency:** ~5% of each event type

### 9. Patients with No Exposures
**Challenge:** Patients in cohort but absent from exposure dataset
**Expected Behavior:** Should be handled (reference category or excluded)
**Count:** 105 patients (10.5%)

### 10. Patients with No Events
**Challenge:** Censored observations (no event during study)
**Expected Behavior:** Should contribute to risk set calculation
**Count:** 540 patients (54.0%)

---

## Usage Examples

### Python

```python
import pandas as pd

# Load datasets
cohort = pd.read_csv('stress_cohort.csv', parse_dates=['study_entry', 'study_exit'])
exposures = pd.read_csv('stress_exposures.csv', parse_dates=['exp_start', 'exp_stop'])
exposures2 = pd.read_csv('stress_exposures2.csv', parse_dates=['exp_start', 'exp_stop'])
events = pd.read_csv('stress_events.csv')

# Parse event dates
for col in ['mi_date', 'death_date', 'emigration_date']:
    events[col] = pd.to_datetime(events[col], errors='coerce')

# Test tvtools functions
from tvtools import tvsplit, tvmerge, tvcoxph

# Example: tvsplit
result = tvsplit(
    cohort=cohort,
    exposures=exposures,
    id_col='patient_id',
    start_col='study_entry',
    end_col='study_exit',
    exp_start_col='exp_start',
    exp_stop_col='exp_stop',
    exp_type_col='drug_type'
)

# Example: tvmerge
merged = tvmerge(
    cohort=cohort,
    exposures1=exposures,
    exposures2=exposures2,
    id_col='patient_id',
    start_col='study_entry',
    end_col='study_exit'
)
```

### R

```r
# Load datasets
cohort <- read.csv('stress_cohort.csv')
cohort$study_entry <- as.Date(cohort$study_entry)
cohort$study_exit <- as.Date(cohort$study_exit)

exposures <- read.csv('stress_exposures.csv')
exposures$exp_start <- as.Date(exposures$exp_start)
exposures$exp_stop <- as.Date(exposures$exp_stop)

exposures2 <- read.csv('stress_exposures2.csv')
exposures2$exp_start <- as.Date(exposures2$exp_start)
exposures2$exp_stop <- as.Date(exposures2$exp_stop)

events <- read.csv('stress_events.csv')
events$mi_date <- as.Date(events$mi_date)
events$death_date <- as.Date(events$death_date)
events$emigration_date <- as.Date(events$emigration_date)

# Test tvtools functions
library(tvtools)

# Example: tvsplit
result <- tvsplit(
  cohort = cohort,
  exposures = exposures,
  id_col = 'patient_id',
  start_col = 'study_entry',
  end_col = 'study_exit',
  exp_start_col = 'exp_start',
  exp_stop_col = 'exp_stop',
  exp_type_col = 'drug_type'
)

# Example: tvmerge
merged <- tvmerge(
  cohort = cohort,
  exposures1 = exposures,
  exposures2 = exposures2,
  id_col = 'patient_id',
  start_col = 'study_entry',
  end_col = 'study_exit'
)
```

---

## Validation Checklist

When testing with this data, verify that your implementation correctly handles:

- [ ] Zero-duration exposures (206 in dataset 1, 126 in dataset 2)
- [ ] Very short exposures (1-3 days: 414 in dataset 1, 257 in dataset 2)
- [ ] Very long exposures (>730 days: 868 in dataset 1, 496 in dataset 2)
- [ ] Overlapping exposure periods (1,745 pairs in dataset 1, 806 in dataset 2)
- [ ] Adjacent exposure periods (77 pairs in dataset 1, 70 in dataset 2)
- [ ] Exposures starting before study entry (217 in dataset 1)
- [ ] Exposures ending after study exit (1,083 in dataset 1)
- [ ] Patients with no exposures (105 patients)
- [ ] Events before study entry (24 events - should be invalid)
- [ ] Events after study exit (23 events - should be invalid)
- [ ] Events at exact boundaries (study entry/exit)
- [ ] Multiple events on same date (10 occurrences)
- [ ] Patients with no events (540 patients)
- [ ] String date format parsing (events dataset)

---

## Data Generation

The data was generated using `generate_comprehensive_test_data.py` with seed 42 for reproducibility.

**To regenerate:**
```bash
cd /home/user/Stata-Tools/Reimplementations/Testing
python3 generate_comprehensive_test_data.py
```

This will overwrite existing stress test files with identical data (deterministic seed).

---

## Expected Output Characteristics

### tvsplit Output
- Should create multiple rows per patient based on exposure changes
- Total rows >> 1,000 (due to exposure splitting)
- Each row should have consistent start/end times
- No gaps or overlaps in individual patient timelines

### tvmerge Output
- Should merge two exposure datasets into single timeline
- Handle overlaps from both datasets
- Create interaction categories where both exposures present

### tvcoxph Output
- Should produce hazard ratios for each drug type vs reference
- Should handle competing risks if specified
- Should exclude invalid events (before entry/after exit)
- Should handle tied event times correctly

---

## Notes

1. **Deterministic Generation:** All data uses seed 42, so re-running the generator produces identical datasets
2. **Realistic Patterns:** Exposure counts follow Poisson distribution (realistic variation)
3. **Comprehensive Coverage:** Includes all major edge cases from real epidemiological studies
4. **Large Scale:** Dataset sizes (1K cohort, 4.7K exposures) stress computational performance
5. **Date Formats:** Mixed datetime and string formats test parsing robustness

---

## File Sizes

- `stress_cohort.csv`: 31 KB (1,000 patients)
- `stress_exposures.csv`: 129 KB (4,708 exposures)
- `stress_exposures2.csv`: 78 KB (2,857 exposures)
- `stress_events.csv`: 13 KB (1,000 patients with events)
- **Total:** 251 KB

---

## Version

**Generated:** 2025-12-03
**Generator Script:** `generate_comprehensive_test_data.py`
**Seed:** 42 (deterministic)
**Python Version:** 3.11+
**Dependencies:** numpy, pandas

---

## Contact

For questions or issues with the test data, please refer to the main repository documentation.
