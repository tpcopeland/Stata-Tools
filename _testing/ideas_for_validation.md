# Deep Validation Strategy for tvtools Package

**Document Purpose**: Plan comprehensive validation tests for `tvexpose`, `tvevent`, and `tvmerge` that go beyond "did it run without error" to verify that computed values match expected results.

**Core Philosophy**: The current tests verify *that* commands run successfully. Deep validation tests verify *how* the commands transform data by using small, hand-crafted datasets where every output value can be mathematically verified.

---

## Table of Contents

1. [Current Testing Gaps](#1-current-testing-gaps)
2. [Deep Validation Principles](#2-deep-validation-principles)
3. [tvexpose Validation Plan](#3-tvexpose-validation-plan)
4. [tvevent Validation Plan](#4-tvevent-validation-plan)
5. [tvmerge Validation Plan](#5-tvmerge-validation-plan)
6. [Test Data Requirements](#6-test-data-requirements)
7. [Implementation Recommendations](#7-implementation-recommendations)

---

## 1. Current Testing Gaps

### What Current Tests Do Well
- Verify commands execute without errors
- Confirm expected variables exist in output
- Check basic value ranges (min/max)
- Test most option combinations
- Validate workflow integration (tvexpose -> tvmerge -> tvevent -> Cox)

### What Current Tests Miss

| Gap | Description | Risk |
|-----|-------------|------|
| **Mathematical Verification** | No tests verify computed values match hand-calculated expectations | Silent calculation errors |
| **Boundary Conditions** | Limited testing of exact date boundaries (exposure start = study entry) | Off-by-one errors |
| **Interval Integrity** | No verification that intervals are properly non-overlapping | Overlapping person-time |
| **Proportional Calculations** | No verification of continuous variable splitting math | Incorrect dose allocation |
| **Event Timing** | No verification events fall at correct interval boundaries | Misattributed events |
| **Competing Risk Resolution** | No verification earliest date wins correctly | Wrong competing risk assignment |
| **Label Verification** | No tests check value labels are applied correctly | Missing/wrong labels |
| **Missing Value Handling** | Limited testing of missing date scenarios | Unexpected missing data behavior |
| **Date Format Preservation** | No verification that date formats from input are preserved | Display issues |
| **Error Handling** | Limited testing of graceful failure with invalid inputs | Cryptic errors |
| **String ID Handling** | Most tests use numeric IDs, string IDs not tested | ID matching failures |
| **Same-Day Events** | No testing of multiple events on same date | Event loss or duplication |

---

## 2. Deep Validation Principles

### 2.1 Known-Answer Testing

Create minimal datasets where you can calculate expected results by hand:

```
Input:
  Person 1: Study Jan 1-Dec 31, 2020 (leap year)
            Exposure Mar 1-Jun 30, 2020 (type=1)

Expected output (assuming exclusive stop dates, i.e., stop = day after last day):
  Person 1, Row 1: Jan 1 - Mar 1, tv_exp=0 (60 days: Jan=31, Feb=29)
  Person 1, Row 2: Mar 1 - Jul 1, tv_exp=1 (122 days: Mar=31, Apr=30, May=31, Jun=30)
  Person 1, Row 3: Jul 1 - Jan 1 2021, tv_exp=0 (184 days: Jul-Dec)
  Total: 60 + 122 + 184 = 366 days ✓

Note: Verify whether tvexpose uses inclusive or exclusive stop dates!
The above assumes exclusive (stop = first day NOT in interval).
If inclusive (stop = last day IN interval), adjust accordingly.
```

### 2.2 Invariant Testing

Properties that must hold regardless of input:

1. **Person-time conservation**: Sum of (stop - start) should equal original (exit - entry)
2. **ID preservation**: All input IDs appear in output (for tvexpose); intersection of IDs (for tvmerge)
3. **Non-overlapping intervals**: Within each ID, no two rows should have overlapping periods
4. **Monotonic cumulative values**: Cumulative exposure should never decrease within person
5. **Date ordering**: start < stop for all rows; rows sorted by start within ID
6. **Contiguous coverage**: For tvexpose, intervals should cover entire study period with no gaps (unless fillgaps/carryforward not used)
7. **Date format preservation**: Output dates should retain input date format (%td, %tc, etc.)
8. **Exposure category values**: Output exposure values should only contain valid input categories plus reference

### 2.3 Boundary Condition Testing

Explicit tests for edge cases:

- Exposure starts exactly at study entry
- Exposure ends exactly at study exit
- Exposure spans entire study period
- Zero-length gaps between exposures
- Single-day exposures
- Exposure outside study period (should be ignored)

---

## 3. tvexpose Validation Plan

### 3.1 Core Transformation Tests

#### Test 3.1.1: Basic Interval Splitting
**Purpose**: Verify exposure periods are correctly split at boundaries

**CRITICAL**: First determine whether tvexpose uses inclusive or exclusive stop dates.
- Inclusive: stop date is the LAST day of the interval (person-time = stop - start + 1)
- Exclusive: stop date is the FIRST day AFTER the interval (person-time = stop - start)

```stata
* Create known data
clear
input long id double(study_entry study_exit)
    1 21915 22280  // 2020-01-01 to 2020-12-31
end
format %td study_entry study_exit
save cohort_test, replace

clear
input long id double(rx_start rx_stop) byte exp_type
    1 21975 22096 1  // 2020-03-01 to 2020-06-30
end
format %td rx_start rx_stop
save exp_test, replace

* Run tvexpose
use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

* First: determine how many rows and list them
assert _N == 3  // Three intervals expected
sort rx_start
list id rx_start rx_stop tv_exp, noobs

* Verify person-time conservation FIRST (determines inclusive vs exclusive)
* Input: 2020 is leap year = 366 days
* If inclusive stop: ptime = stop - start + 1
* If exclusive stop: ptime = stop - start
gen ptime_inclusive = rx_stop - rx_start + 1
gen ptime_exclusive = rx_stop - rx_start
egen total_incl = total(ptime_inclusive)
egen total_excl = total(ptime_exclusive)

* One of these should equal 366
di "Inclusive total: " total_incl[1]
di "Exclusive total: " total_excl[1]

* Assert the correct one (adjust based on actual tvexpose behavior)
* assert total_incl == 366  // Use if inclusive
* assert total_excl == 366  // Use if exclusive

* Then verify specific date boundaries match expected
* (exact assertions depend on inclusive/exclusive determination above)
```

#### Test 3.1.2: Person-Time Conservation (General)
**Purpose**: Verify total follow-up time is preserved through transformation

```stata
* Calculate input person-time
use cohort, clear
gen double input_ptime = study_exit - study_entry
sum input_ptime
local input_total = r(sum)

* Run tvexpose
tvexpose using exposures, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

* Calculate output person-time
gen double output_ptime = rx_stop - rx_start
sum output_ptime
local output_total = r(sum)

* Allow 0.1% tolerance for rounding
local pct_diff = abs(`output_total' - `input_total') / `input_total' * 100
assert `pct_diff' < 0.1
```

#### Test 3.1.3: Non-Overlapping Intervals
**Purpose**: Verify no intervals overlap within a person

```stata
* After tvexpose
sort id rx_start rx_stop
by id: gen double prev_stop = rx_stop[_n-1] if _n > 1
by id: gen byte overlap = (rx_start < prev_stop) if _n > 1
count if overlap == 1
assert r(N) == 0, "Found overlapping intervals"
```

### 3.2 Cumulative Exposure Tests

#### Test 3.2.1: continuousunit() Calculation Verification
**Purpose**: Verify cumulative exposure is calculated correctly

```stata
* Create data with known cumulative exposure
clear
input long id double(study_entry study_exit)
    1 21915 22280  // 2020 full year
end
format %td study_entry study_exit
save cohort_test, replace

* Single 365-day exposure
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 22279 1  // Full year exposure (365 days)
end
format %td rx_start rx_stop
save exp_test, replace

* Test years
use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    continuousunit(years) generate(cum_exp)

* At end of follow-up, cumulative should be ~1 year
sum cum_exp
assert abs(r(max) - 1.0) < 0.01  // Within 1% of 1 year
```

#### Test 3.2.2: Cumulative Monotonicity
**Purpose**: Verify cumulative exposure never decreases

```stata
* After tvexpose with continuousunit()
sort id rx_start
by id: gen double cum_change = cum_exp - cum_exp[_n-1] if _n > 1
count if cum_change < -0.0001  // Allow tiny floating point tolerance
assert r(N) == 0, "Cumulative exposure decreased"
```

### 3.3 Current/Former Status Tests

#### Test 3.3.1: currentformer Transitions
**Purpose**: Verify never->current->former transitions are correct

```stata
* Create person with exposure in middle of follow-up
clear
input long id double(study_entry study_exit)
    1 21915 22280  // 2020 full year
end
save cohort_test, replace

clear
input long id double(rx_start rx_stop) byte exp_type
    1 21975 22036 1  // Mar 1 - May 1, 2020
end
save exp_test, replace

use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    currentformer generate(cf_status)

* Verify: Before exposure = 0 (never)
*         During exposure = 1 (current)
*         After exposure = 2 (former)
sort rx_start
assert cf_status[1] == 0  // Never
assert cf_status[2] == 1  // Current
assert cf_status[3] == 2  // Former
```

#### Test 3.3.2: currentformer Never Returns to Current
**Purpose**: Verify once "former", status doesn't revert to "current" without new exposure

```stata
* After currentformer transformation
sort id rx_start
by id: gen byte went_back = (cf_status == 1 & cf_status[_n-1] == 2)
count if went_back == 1
assert r(N) == 0, "Status incorrectly went from former to current"
```

### 3.4 Grace Period Tests

#### Test 3.4.1: Grace Period Merges Adjacent Exposures
**Purpose**: Verify grace period correctly bridges small gaps

```stata
* Two exposures with 15-day gap
clear
input long id double(rx_start rx_stop) byte exp_type
    1 21915 21945 1  // Jan 1-31, 2020
    1 21961 21991 1  // Feb 16 - Mar 16, 2020 (15 day gap)
end
save exp_test, replace

* With grace(14) - should NOT merge (gap > grace)
use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    grace(14) generate(tv_exp)

count if tv_exp == 0  // Should have unexposed period between
assert r(N) >= 1

* With grace(15) - SHOULD merge (gap <= grace)
use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    grace(15) generate(tv_exp)

* Verify continuous exposure (no unexposed gap in Feb 1-15)
sort rx_start
by id: gen gap_exists = (rx_start - rx_stop[_n-1] > 1 & tv_exp[_n-1] == 1 & tv_exp == 1) if _n > 1
count if gap_exists == 1
// Note: actual assertion depends on exact grace period implementation
```

### 3.5 Duration Category Tests

#### Test 3.5.1: duration() Cutpoint Verification
**Purpose**: Verify duration categories are assigned correctly

```stata
* Person with 2.5 years of exposure
clear
input long id double(study_entry study_exit)
    1 mdy(1,1,2015) mdy(12,31,2020)  // 6 years
end
format %td study_entry study_exit
save cohort_test, replace

clear
input long id double(rx_start rx_stop) byte exp_type
    1 mdy(1,1,2015) mdy(6,30,2017) 1  // 2.5 years exposure
end
format %td rx_start rx_stop
save exp_test, replace

use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    duration(1 3) continuousunit(years) generate(dur_cat)

* Verify categories:
*   0 = Unexposed
*   1 = <1 year exposure
*   2 = 1-<3 years exposure
*   3 = 3+ years exposure

* During first year of exposure: category should be 1 (<1 year)
* After 1 year, before 3 years: category should be 2 (1-<3)
* After exposure ends (2.5 years total): should stay in category 2

tab dur_cat
// Verify specific row assignments by date
```

### 3.6 Lag and Washout Tests

#### Test 3.6.1: lag() Delays Exposure Start
**Purpose**: Verify exposure becomes active only after lag period

```stata
* Single exposure starting Mar 1
clear
input long id double(rx_start rx_stop) byte exp_type
    1 mdy(3,1,2020) mdy(6,30,2020) 1
end
save exp_test, replace

use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    lag(30) generate(tv_exp)

* Exposure should become active on Mar 31 (Mar 1 + 30 days)
* Days Mar 1-30 should still be unexposed
sort rx_start
* Find row containing Mar 15
gen has_mar15 = (rx_start <= mdy(3,15,2020) & rx_stop >= mdy(3,15,2020))
assert tv_exp == 0 if has_mar15 == 1
```

#### Test 3.6.2: washout() Extends Exposure End
**Purpose**: Verify exposure persists after nominal stop date

```stata
use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    washout(30) generate(tv_exp)

* Exposure should end Jul 30 (Jun 30 + 30 days)
* Days Jul 1-30 should still be exposed
sort rx_start
gen has_jul15 = (rx_start <= mdy(7,15,2020) & rx_stop >= mdy(7,15,2020))
assert tv_exp == 1 if has_jul15 == 1
```

### 3.7 Overlapping Exposure Tests

#### Test 3.7.1: priority() Resolves Overlaps Correctly
**Purpose**: Verify higher priority exposure takes precedence

```stata
* Two overlapping exposures
clear
input long id double(rx_start rx_stop) byte exp_type
    1 mdy(1,1,2020) mdy(6,30,2020) 1  // Type 1: Jan-Jun
    1 mdy(4,1,2020) mdy(9,30,2020) 2  // Type 2: Apr-Sep (overlaps)
end
save exp_test, replace

use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    priority(2 1) generate(tv_exp)  // Type 2 has priority

* During overlap (Apr-Jun), should be type 2 (higher priority)
sort rx_start
gen has_may = (rx_start <= mdy(5,15,2020) & rx_stop >= mdy(5,15,2020))
assert tv_exp == 2 if has_may == 1
```

#### Test 3.7.2: split() Creates Correct Boundaries
**Purpose**: Verify split creates intervals at all exposure change points

```stata
use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    split generate(tv_exp)

* With split, should have intervals:
*   Jan 1 - Mar 31: type 1 only
*   Apr 1 - Jun 30: types 1+2 overlap
*   Jul 1 - Sep 30: type 2 only
*   Oct 1 - Dec 31: unexposed

count
assert r(N) >= 4  // At least 4 distinct intervals
```

### 3.8 evertreated Tests

#### Test 3.8.1: evertreated Never Reverts
**Purpose**: Verify once exposed, status never returns to unexposed

```stata
use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    evertreated generate(ever)

sort id rx_start
by id: gen byte reverted = (ever == 0 & ever[_n-1] == 1) if _n > 1
count if reverted == 1
assert r(N) == 0, "evertreated incorrectly reverted to unexposed"
```

#### Test 3.8.2: evertreated Switches at First Exposure
**Purpose**: Verify exact timing of ever-treated transition

```stata
* Find the row containing first exposure start date
gen is_first_exp_day = (rx_start == mdy(3,1,2020))

* The row STARTING at first exposure should be ever=1
assert ever == 1 if is_first_exp_day == 1

* The row BEFORE first exposure should be ever=0
// (requires finding the previous row)
```

### 3.9 bytype Tests

#### Test 3.9.1: bytype Creates Correct Variables
**Purpose**: Verify separate variables track each exposure type independently

```stata
* Multiple exposure types
clear
input long id double(rx_start rx_stop) byte exp_type
    1 mdy(1,1,2020) mdy(3,31,2020) 1
    1 mdy(6,1,2020) mdy(9,30,2020) 2
end
save exp_test, replace

use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    evertreated bytype generate(ever)

* Should have ever1 and ever2 variables
confirm variable ever1 ever2

* Type 1 active Jan-Mar, stays ever1=1 thereafter
* Type 2 active Jun-Sep, stays ever2=1 thereafter
sort rx_start

* During Apr-May: ever1=1 (was exposed), ever2=0 (not yet exposed)
gen has_apr = (rx_start <= mdy(4,15,2020) & rx_stop >= mdy(4,15,2020))
assert ever1 == 1 & ever2 == 0 if has_apr == 1
```

### 3.10 Dose Accumulation Tests

#### Test 3.10.1: dose Cumulative Calculation
**Purpose**: Verify dose accumulates correctly over time

```stata
clear
input long id double(rx_start rx_stop) double dose_amt
    1 mdy(1,1,2020) mdy(1,31,2020) 100  // 100mg for 31 days
    1 mdy(3,1,2020) mdy(3,31,2020) 200  // 200mg for 31 days
end
save exp_test, replace

use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(dose_amt) entry(study_entry) exit(study_exit) ///
    dose generate(cum_dose)

* At end of study:
*   - First period contributed 100mg
*   - Second period contributed 200mg
*   - Total should be 300mg
sort rx_start
egen max_dose = max(cum_dose), by(id)
assert abs(max_dose - 300) < 0.1
```

#### Test 3.10.2: dosecuts() Category Assignment
**Purpose**: Verify dose categories are assigned at correct thresholds

```stata
use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(dose_amt) entry(study_entry) exit(study_exit) ///
    dose dosecuts(50 150 250) generate(dose_cat)

* Categories should be:
*   0: 0 dose
*   1: >0 to <50
*   2: 50 to <150
*   3: 150 to <250
*   4: 250+

* After first period (100mg cumulative): should be category 2 (50-<150)
* After second period (300mg cumulative): should be category 4 (250+)
```

### 3.11 merge() Option Tests

#### Test 3.11.1: merge() Combines Same-Type Periods
**Purpose**: Verify periods of same exposure type within merge window are combined

```stata
* Two same-type exposures 60 days apart (within default 120-day merge window)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 mdy(1,1,2020) mdy(1,31,2020) 1   // Jan
    1 mdy(4,1,2020) mdy(4,30,2020) 1   // Apr (60 days after Jan 31)
end
save exp_test, replace

* With default merge(120) - should merge into single period
use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

* Count exposed periods (should be 1 merged period, not 2 separate)
count if tv_exp == 1
* Note: Verify expected behavior - does merge() fill the gap or just combine?

* With merge(30) - should NOT merge (gap > 30 days)
use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    merge(30) generate(tv_exp)

* Should have 2 separate exposed periods
```

### 3.12 window() Option Tests

#### Test 3.12.1: window() Creates Acute Exposure Period
**Purpose**: Verify window() limits exposure to specified time range

```stata
* Single exposure starting Jan 1
clear
input long id double(rx_start rx_stop) byte exp_type
    1 mdy(1,1,2020) mdy(6,30,2020) 1
end
save exp_test, replace

* Window of 30-90 days after exposure start
use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    window(30 90) generate(tv_exp)

* Exposed period should only be day 30-90 after Jan 1
* Days 1-29: unexposed (before window)
* Days 30-90: exposed (within window)
* Days 91+: unexposed (after window)
sort rx_start
list rx_start rx_stop tv_exp
```

### 3.13 layer Option Tests

#### Test 3.13.1: layer() Resumes Earlier Exposure After Overlap
**Purpose**: Verify layer allows overlapping exposures with later taking precedence

```stata
* Two overlapping exposures
clear
input long id double(rx_start rx_stop) byte exp_type
    1 mdy(1,1,2020) mdy(6,30,2020) 1  // Type 1: Jan-Jun
    1 mdy(3,1,2020) mdy(4,30,2020) 2  // Type 2: Mar-Apr (overlaps, later in data)
end
save exp_test, replace

use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    layer generate(tv_exp)

* Expected with layer:
*   Jan-Feb: type 1
*   Mar-Apr: type 2 (later exposure takes precedence)
*   May-Jun: type 1 RESUMES after type 2 ends
sort rx_start
list rx_start rx_stop tv_exp

* Verify May-Jun is type 1
gen has_may = (rx_start <= mdy(5,15,2020) & rx_stop >= mdy(5,15,2020))
assert tv_exp == 1 if has_may == 1
```

### 3.14 fillgaps() and carryforward() Tests

#### Test 3.14.1: fillgaps() Extends Exposure Beyond Last Record
**Purpose**: Verify fillgaps() continues exposure for specified days

```stata
* Exposure ending before study exit
clear
input long id double(rx_start rx_stop) byte exp_type
    1 mdy(1,1,2020) mdy(3,31,2020) 1
end
save exp_test, replace

* With fillgaps(30) - exposure should continue 30 days past last record
use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    fillgaps(30) generate(tv_exp)

* Check that Apr 15 (15 days after Mar 31) is still exposed
gen has_apr15 = (rx_start <= mdy(4,15,2020) & rx_stop >= mdy(4,15,2020))
assert tv_exp == 1 if has_apr15 == 1

* Check that May 15 (45 days after Mar 31) is NOT exposed
gen has_may15 = (rx_start <= mdy(5,15,2020) & rx_stop >= mdy(5,15,2020))
assert tv_exp == 0 if has_may15 == 1
```

#### Test 3.14.2: carryforward() Bridges Gaps in Exposure
**Purpose**: Verify carryforward() continues exposure through gaps

```stata
* Two exposures with a gap
clear
input long id double(rx_start rx_stop) byte exp_type
    1 mdy(1,1,2020) mdy(2,29,2020) 1   // Jan-Feb
    1 mdy(4,1,2020) mdy(5,31,2020) 1   // Apr-May (31-day gap in March)
end
save exp_test, replace

* With carryforward(45) - should bridge the 31-day gap
use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    carryforward(45) generate(tv_exp)

* March (the gap) should be exposed
gen has_mar15 = (rx_start <= mdy(3,15,2020) & rx_stop >= mdy(3,15,2020))
assert tv_exp == 1 if has_mar15 == 1
```

### 3.15 switching and switchingdetail Tests

#### Test 3.15.1: switching Creates Binary Indicator
**Purpose**: Verify switching flag is set when exposure type changes

```stata
* Two different exposure types
clear
input long id double(rx_start rx_stop) byte exp_type
    1 mdy(1,1,2020) mdy(3,31,2020) 1
    1 mdy(4,1,2020) mdy(6,30,2020) 2  // Switch from type 1 to 2
end
save exp_test, replace

use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    switching generate(tv_exp)

* Verify switching indicator exists
confirm variable _switching

* After the switch (Apr 1), _switching should be 1
gen has_apr = (rx_start <= mdy(4,15,2020) & rx_stop >= mdy(4,15,2020))
assert _switching == 1 if has_apr == 1

* Before the switch (Jan), _switching should be 0
gen has_jan = (rx_start <= mdy(1,15,2020) & rx_stop >= mdy(1,15,2020))
assert _switching == 0 if has_jan == 1
```

### 3.16 statetime Tests

#### Test 3.16.1: statetime Tracks Cumulative Time in Current State
**Purpose**: Verify statetime accumulates correctly within each exposure state

```stata
use cohort_test, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    statetime generate(tv_exp)

* Verify statetime variable exists
confirm variable _statetime

* Statetime should increase within each exposure state
* and reset when state changes
sort id rx_start
by id tv_exp: assert _statetime >= _statetime[_n-1] if _n > 1
```

### 3.17 Error Handling Tests

#### Test 3.17.1: Missing Required Options
**Purpose**: Verify informative errors for missing required inputs

```stata
* Missing reference()
capture tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) entry(study_entry) exit(study_exit)
assert _rc == 198

* Missing exposure()
capture tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    reference(0) entry(study_entry) exit(study_exit)
assert _rc != 0

* Missing id()
capture tvexpose using exp_test, start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit)
assert _rc != 0
```

#### Test 3.17.2: Invalid Input Values
**Purpose**: Verify graceful handling of invalid data

```stata
* Exposure file with stop < start (invalid interval)
clear
input long id double(rx_start rx_stop) byte exp_type
    1 mdy(6,30,2020) mdy(1,1,2020) 1  // Stop before start!
end
save exp_invalid, replace

capture tvexpose using exp_invalid, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    generate(tv_exp)
* Should error or warn about invalid intervals
```

#### Test 3.17.3: Variable Not Found
**Purpose**: Verify clear errors when specified variables don't exist

```stata
* Reference to non-existent variable
capture tvexpose using exp_test, id(nonexistent_id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit)
assert _rc == 111  // Variable not found
```

### 3.18 Date Format Preservation Tests

#### Test 3.18.1: Format Retained Through Transformation
**Purpose**: Verify date format from input is preserved in output

```stata
* Create data with specific date format
clear
input long id double(study_entry study_exit)
    1 mdy(1,1,2020) mdy(12,31,2020)
end
format %tdCCYY-NN-DD study_entry study_exit
save cohort_formatted, replace

use cohort_formatted, clear
tvexpose using exp_test, id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

* Check format is preserved
local fmt : format rx_start
assert "`fmt'" == "%tdCCYY-NN-DD" | "`fmt'" == "%td"
```

---

## 4. tvevent Validation Plan

### 4.1 Event Integration Tests

#### Test 4.1.1: Event Placed at Correct Boundary
**Purpose**: Verify event occurs at interval endpoint, not mid-interval

```stata
* Create interval data
clear
input long id double(start stop) byte tv_exp
    1 mdy(1,1,2020) mdy(6,30,2020) 1
    1 mdy(7,1,2020) mdy(12,31,2020) 0
end
save intervals_test, replace

* Create event data - event on May 15
clear
input long id double event_dt
    1 mdy(5,15,2020)
end
save events_test, replace

* Run tvevent
use events_test, clear
tvevent using intervals_test, id(id) date(event_dt) ///
    startvar(start) stopvar(stop) type(single) generate(outcome)

* Event should split the Jan-Jun interval
* The row WITH the event should have stop=May 15
sort start
list id start stop outcome

* Verify event row has outcome=1 and stop=event date
count if outcome == 1 & stop == mdy(5,15,2020)
assert r(N) == 1
```

#### Test 4.1.2: Event Count Preservation
**Purpose**: Verify number of events in output matches input

```stata
* Count events in source
use events_test, clear
count if !missing(event_dt)
local source_events = r(N)

* Run tvevent
tvevent using intervals_test, id(id) date(event_dt) ///
    startvar(start) stopvar(stop) type(single) generate(outcome)

* Count events in output
count if outcome == 1
local output_events = r(N)

assert `source_events' == `output_events'
```

### 4.2 Interval Splitting Tests

#### Test 4.2.1: Split Preserves Total Duration
**Purpose**: Verify splitting doesn't create/lose person-time

```stata
* Before tvevent: calculate total duration
use intervals_test, clear
gen double dur = stop - start
sum dur
local pre_total = r(sum)

* Run tvevent
use events_test, clear
tvevent using intervals_test, id(id) date(event_dt) ///
    startvar(start) stopvar(stop) type(single) generate(outcome)

* After tvevent: calculate total duration (should match)
gen double dur = stop - start
sum dur
local post_total = r(sum)

assert abs(`pre_total' - `post_total') < 1  // Within 1 day
```

#### Test 4.2.2: Continuous Variable Proportional Adjustment
**Purpose**: Verify continuous() variables are correctly pro-rated

```stata
* Interval with known duration and cumulative value
clear
input long id double(start stop) double cum_exp
    1 mdy(1,1,2020) mdy(12,31,2020) 365  // 365 days, cum_exp = 365
end
save intervals_test, replace

* Event at mid-year splits interval
clear
input long id double event_dt
    1 mdy(7,1,2020)  // Day 183
end
save events_test, replace

use events_test, clear
tvevent using intervals_test, id(id) date(event_dt) ///
    startvar(start) stopvar(stop) continuous(cum_exp) ///
    type(single) generate(outcome)

* After split:
*   Row 1: Jan 1 - Jun 30 (181 days) → cum_exp should be ~181
*   Row 2: Jul 1 - Dec 31 (184 days) → cum_exp should be ~184
* Total should still be 365

sort start
assert abs(cum_exp[1] - 181) < 1
assert abs(cum_exp[2] - 184) < 1

egen total_cum = total(cum_exp)
assert abs(total_cum - 365) < 1
```

### 4.3 Competing Risk Tests

#### Test 4.3.1: Earliest Event Wins
**Purpose**: Verify competing risk resolution picks earliest date

```stata
* Primary event May 15, competing event Apr 1
clear
input long id double(primary_dt compete_dt)
    1 mdy(5,15,2020) mdy(4,1,2020)  // Competing is earlier
end
save events_test, replace

use events_test, clear
tvevent using intervals_test, id(id) date(primary_dt) ///
    startvar(start) stopvar(stop) compete(compete_dt) ///
    type(single) generate(outcome)

* Outcome should be 2 (competing risk) since Apr 1 < May 15
count if outcome == 2
assert r(N) == 1

* Event should occur at Apr 1
count if outcome == 2 & stop == mdy(4,1,2020)
assert r(N) == 1
```

#### Test 4.3.2: Multiple Competing Risks
**Purpose**: Verify correct assignment among multiple competing risks

```stata
* Three events: primary, death, emigration
clear
input long id double(primary_dt death_dt emig_dt)
    1 mdy(6,1,2020) mdy(4,1,2020) mdy(5,1,2020)
    // Earliest is death (Apr 1) → outcome should be 2
end
save events_test, replace

use events_test, clear
tvevent using intervals_test, id(id) date(primary_dt) ///
    startvar(start) stopvar(stop) compete(death_dt emig_dt) ///
    type(single) generate(outcome)

* Outcome codes: 0=censored, 1=primary, 2=death, 3=emigration
* Should be 2 (death) since Apr 1 is earliest
count if outcome == 2
assert r(N) == 1
```

### 4.4 Single vs Recurring Tests

#### Test 4.4.1: type(single) Censors After First Event
**Purpose**: Verify follow-up ends after first event for single events

```stata
use events_test, clear
tvevent using intervals_test, id(id) date(event_dt) ///
    startvar(start) stopvar(stop) type(single) generate(outcome)

* Should have no rows after the event row
sort id start
by id: egen event_time = max(stop * (outcome == 1))
by id: gen post_event = (start > event_time & !missing(event_time))
count if post_event == 1
assert r(N) == 0, "Found follow-up after event in type(single)"
```

#### Test 4.4.2: type(recurring) Allows Multiple Events
**Purpose**: Verify all person-time is retained for recurring events

```stata
* Wide format recurring events
clear
input long id double(event_dt1 event_dt2 event_dt3)
    1 mdy(3,1,2020) mdy(6,1,2020) mdy(9,1,2020)
end
save events_test, replace

use events_test, clear
tvevent using intervals_test, id(id) date(event_dt) ///
    startvar(start) stopvar(stop) type(recurring) generate(outcome)

* Should have 3 event rows
count if outcome == 1
assert r(N) == 3

* Should still have follow-up to end of study
sum stop
assert r(max) == mdy(12,31,2020)
```

### 4.5 Value Label Tests

#### Test 4.5.1: Labels Applied Correctly
**Purpose**: Verify outcome variable has correct value labels

```stata
use events_test, clear
tvevent using intervals_test, id(id) date(primary_dt) ///
    startvar(start) stopvar(stop) compete(death_dt) ///
    eventlabel(0 "Censored" 1 "Progression" 2 "Death") ///
    type(single) generate(outcome)

* Check labels exist
local lblname : value label outcome
assert "`lblname'" != ""

* Check specific label values
local lbl0 : label `lblname' 0
assert "`lbl0'" == "Censored"

local lbl1 : label `lblname' 1
assert "`lbl1'" == "Progression"

local lbl2 : label `lblname' 2
assert "`lbl2'" == "Death"
```

### 4.6 Boundary Condition Tests

#### Test 4.6.1: Event Exactly at Interval Start
**Purpose**: Verify event at start boundary is handled correctly

**IMPORTANT**: tvevent uses `start < date < stop` (strictly between), so events
exactly at start should NOT be captured in that interval.

```stata
* Create interval Jan 1 - Dec 31
clear
input long id double(start stop) byte tv_exp
    1 mdy(1,1,2020) mdy(12,31,2020) 1
end
save intervals_test, replace

* Event exactly on Jan 1 (interval start)
clear
input long id double event_dt
    1 mdy(1,1,2020)
end
save events_test, replace

use events_test, clear
tvevent using intervals_test, id(id) date(event_dt) ///
    startvar(start) stopvar(stop) type(single) generate(outcome)

* Event should NOT be captured (date not > start)
count if outcome == 1
assert r(N) == 0  // Event at exact start is NOT within interval
```

#### Test 4.6.2: Event Exactly at Interval Stop
**Purpose**: Verify event at stop boundary is handled correctly

```stata
* Event exactly on Dec 31 (interval stop)
clear
input long id double event_dt
    1 mdy(12,31,2020)
end
save events_test, replace

use events_test, clear
tvevent using intervals_test, id(id) date(event_dt) ///
    startvar(start) stopvar(stop) type(single) generate(outcome)

* Event should NOT be captured (date not < stop)
count if outcome == 1
assert r(N) == 0  // Event at exact stop is NOT within interval
```

#### Test 4.6.3: Event One Day Inside Boundaries
**Purpose**: Verify events just inside boundaries ARE captured

```stata
* Event on Jan 2 (one day after start)
clear
input long id double event_dt
    1 mdy(1,2,2020)
end
save events_test, replace

use events_test, clear
tvevent using intervals_test, id(id) date(event_dt) ///
    startvar(start) stopvar(stop) type(single) generate(outcome)

* Event SHOULD be captured (Jan 2 > Jan 1 and < Dec 31)
count if outcome == 1
assert r(N) == 1
```

### 4.7 Edge Case Tests

#### Test 4.7.1: Event Outside Study Period
**Purpose**: Verify events outside all intervals are ignored

```stata
* Create interval Jan 1 - Jun 30
clear
input long id double(start stop) byte tv_exp
    1 mdy(1,1,2020) mdy(6,30,2020) 1
end
save intervals_test, replace

* Event on Dec 15 (after interval ends)
clear
input long id double event_dt
    1 mdy(12,15,2020)
end
save events_test, replace

use events_test, clear
tvevent using intervals_test, id(id) date(event_dt) ///
    startvar(start) stopvar(stop) type(single) generate(outcome)

* No event should be recorded (event outside all intervals)
count if outcome == 1
assert r(N) == 0
```

#### Test 4.7.2: Person with No Events
**Purpose**: Verify persons without events are properly censored

```stata
* Two persons in interval data
clear
input long id double(start stop) byte tv_exp
    1 mdy(1,1,2020) mdy(12,31,2020) 1
    2 mdy(1,1,2020) mdy(12,31,2020) 1
end
save intervals_test, replace

* Only person 1 has event
clear
input long id double event_dt
    1 mdy(6,15,2020)
    2 .                // Person 2: missing event date (no event)
end
save events_test, replace

use events_test, clear
tvevent using intervals_test, id(id) date(event_dt) ///
    startvar(start) stopvar(stop) type(single) generate(outcome)

* Person 2 should have all outcome = 0 (censored)
count if id == 2 & outcome == 1
assert r(N) == 0

* Person 2 should still have follow-up
count if id == 2
assert r(N) >= 1
```

#### Test 4.7.3: Same-Day Competing Events
**Purpose**: Verify handling when primary and competing events occur on same day

```stata
* Primary and competing event on same day
clear
input long id double(primary_dt compete_dt)
    1 mdy(6,15,2020) mdy(6,15,2020)  // Same day!
end
save events_test, replace

use events_test, clear
tvevent using intervals_test, id(id) date(primary_dt) ///
    startvar(start) stopvar(stop) compete(compete_dt) ///
    type(single) generate(outcome)

* When dates are equal, which wins? Document the behavior.
* Typically primary should take precedence (outcome = 1)
tab outcome
* Assert expected behavior (adjust based on actual implementation)
```

#### Test 4.7.4: Multiple Events on Same Day (Recurring)
**Purpose**: Verify multiple events on same day are counted correctly

```stata
* Two events on same day in recurring format
clear
input long id double(event_dt1 event_dt2)
    1 mdy(6,15,2020) mdy(6,15,2020)  // Both on June 15
end
save events_test, replace

use events_test, clear
tvevent using intervals_test, id(id) date(event_dt) ///
    startvar(start) stopvar(stop) type(recurring) generate(outcome)

* How many event rows? Should it be 2 (both counted) or 1 (deduplicated)?
count if outcome == 1
* Document and assert expected behavior
```

### 4.8 Error Handling Tests

#### Test 4.8.1: Missing Required Variables
**Purpose**: Verify informative errors for invalid inputs

```stata
* Missing id variable
capture tvevent using intervals_test, date(event_dt) ///
    startvar(start) stopvar(stop) type(single) generate(outcome)
assert _rc != 0

* Missing date variable
capture tvevent using intervals_test, id(id) ///
    startvar(start) stopvar(stop) type(single) generate(outcome)
assert _rc != 0
```

#### Test 4.8.2: Invalid Type Option
**Purpose**: Verify invalid type values are rejected

```stata
capture tvevent using intervals_test, id(id) date(event_dt) ///
    startvar(start) stopvar(stop) type(invalid) generate(outcome)
assert _rc == 198
```

### 4.9 timegen and timeunit Tests

#### Test 4.9.1: timegen Creates Time-to-Event Variable
**Purpose**: Verify time-to-event calculation is correct

```stata
* Create known interval
clear
input long id double(start stop) byte tv_exp
    1 mdy(1,1,2020) mdy(12,31,2020) 1
end
save intervals_test, replace

* Event on Jul 1 (182 days from Jan 1)
clear
input long id double event_dt
    1 mdy(7,1,2020)
end
save events_test, replace

use events_test, clear
tvevent using intervals_test, id(id) date(event_dt) ///
    startvar(start) stopvar(stop) type(single) ///
    timegen(time_to_event) timeunit(days) generate(outcome)

* Verify time variable exists
confirm variable time_to_event

* Time to event should be 182 days (Jan 1 to Jul 1)
sum time_to_event if outcome == 1
assert abs(r(mean) - 182) < 1
```

#### Test 4.9.2: timeunit Conversion
**Purpose**: Verify time conversion to different units

```stata
use events_test, clear
tvevent using intervals_test, id(id) date(event_dt) ///
    startvar(start) stopvar(stop) type(single) ///
    timegen(time_yrs) timeunit(years) generate(outcome)

* Time in years should be ~0.5 (182 days / 365.25)
sum time_yrs if outcome == 1
assert abs(r(mean) - 0.5) < 0.05
```

---

## 5. tvmerge Validation Plan

### 5.1 Cartesian Product Tests

#### Test 5.1.1: Complete Intersection Coverage
**Purpose**: Verify all overlapping intervals from both datasets appear

```stata
* Dataset 1: Single interval
clear
input long id double(start1 stop1) byte exp1
    1 mdy(1,1,2020) mdy(12,31,2020) 1
end
save ds1_test, replace

* Dataset 2: Two intervals covering same period
clear
input long id double(start2 stop2) byte exp2
    1 mdy(1,1,2020) mdy(6,30,2020) 1
    1 mdy(7,1,2020) mdy(12,31,2020) 2
end
save ds2_test, replace

tvmerge ds1_test ds2_test, id(id) ///
    start(start1 start2) stop(stop1 stop2) ///
    exposure(exp1 exp2)

* Should produce 2 intervals (Jan-Jun, Jul-Dec)
assert _N == 2

* Verify both exposure values present
assert exp1 == 1 in 1/2
assert exp2 == 1 in 1
assert exp2 == 2 in 2
```

#### Test 5.1.2: Non-Overlapping Periods Excluded
**Purpose**: Verify intervals that don't overlap produce no output

```stata
* Dataset 1: Jan-Mar
clear
input long id double(start1 stop1) byte exp1
    1 mdy(1,1,2020) mdy(3,31,2020) 1
end
save ds1_test, replace

* Dataset 2: Jul-Dec (no overlap with ds1)
clear
input long id double(start2 stop2) byte exp2
    1 mdy(7,1,2020) mdy(12,31,2020) 2
end
save ds2_test, replace

tvmerge ds1_test ds2_test, id(id) ///
    start(start1 start2) stop(stop1 stop2) ///
    exposure(exp1 exp2)

* Should produce 0 intervals (no overlap)
assert _N == 0
```

### 5.2 Person-Time Tests

#### Test 5.2.1: Merged Duration Equals Intersection
**Purpose**: Verify output duration matches overlap duration

```stata
* Known overlap: Jan 1 - Jun 30 (181 days)
clear
input long id double(start1 stop1) byte exp1
    1 mdy(1,1,2020) mdy(6,30,2020) 1  // 181 days
end
save ds1_test, replace

clear
input long id double(start2 stop2) byte exp2
    1 mdy(3,1,2020) mdy(9,30,2020) 2  // Overlaps Mar-Jun
end
save ds2_test, replace

tvmerge ds1_test ds2_test, id(id) ///
    start(start1 start2) stop(stop1 stop2) ///
    exposure(exp1 exp2)

* Overlap is Mar 1 - Jun 30 (122 days)
gen dur = stop - start
sum dur
assert abs(r(sum) - 122) < 1
```

### 5.3 Continuous Variable Tests

#### Test 5.3.1: Continuous Interpolation
**Purpose**: Verify continuous values are pro-rated correctly

```stata
* Dataset 1: Full year, cumulative = 365
clear
input long id double(start1 stop1) double cum1
    1 mdy(1,1,2020) mdy(12,31,2020) 365
end
save ds1_test, replace

* Dataset 2: First half, cumulative = 100
clear
input long id double(start2 stop2) double cum2
    1 mdy(1,1,2020) mdy(6,30,2020) 100
end
save ds2_test, replace

tvmerge ds1_test ds2_test, id(id) ///
    start(start1 start2) stop(stop1 stop2) ///
    exposure(cum1 cum2) ///
    continuous(cum1 cum2)

* Output overlap is Jan-Jun (181/365 of ds1)
* cum1 should be ~181, cum2 should be 100
gen dur = stop - start
assert abs(cum1 - 181) < 2
assert abs(cum2 - 100) < 1
```

### 5.4 ID Matching Tests

#### Test 5.4.1: ID Intersection Behavior
**Purpose**: Verify only matching IDs appear in output

```stata
* Dataset 1: IDs 1, 2, 3
clear
input long id double(start1 stop1) byte exp1
    1 mdy(1,1,2020) mdy(12,31,2020) 1
    2 mdy(1,1,2020) mdy(12,31,2020) 1
    3 mdy(1,1,2020) mdy(12,31,2020) 1
end
save ds1_test, replace

* Dataset 2: IDs 2, 3, 4
clear
input long id double(start2 stop2) byte exp2
    2 mdy(1,1,2020) mdy(12,31,2020) 2
    3 mdy(1,1,2020) mdy(12,31,2020) 2
    4 mdy(1,1,2020) mdy(12,31,2020) 2
end
save ds2_test, replace

* Without force: should error on mismatch
capture tvmerge ds1_test ds2_test, id(id) ///
    start(start1 start2) stop(stop1 stop2) ///
    exposure(exp1 exp2)
assert _rc != 0  // Should error

* With force: should warn and keep only intersection (IDs 2, 3)
tvmerge ds1_test ds2_test, id(id) ///
    start(start1 start2) stop(stop1 stop2) ///
    exposure(exp1 exp2) force

distinct id
assert r(ndistinct) == 2  // Only IDs 2 and 3
```

### 5.5 Three-Way Merge Tests

#### Test 5.5.1: Three Dataset Intersection
**Purpose**: Verify three-way merge creates correct intervals

```stata
* Three datasets with overlapping periods
clear
input long id double(s1 e1) byte x1
    1 mdy(1,1,2020) mdy(9,30,2020) 1  // Jan-Sep
end
save ds1, replace

clear
input long id double(s2 e2) byte x2
    1 mdy(4,1,2020) mdy(12,31,2020) 2  // Apr-Dec
end
save ds2, replace

clear
input long id double(s3 e3) byte x3
    1 mdy(6,1,2020) mdy(12,31,2020) 3  // Jun-Dec
end
save ds3, replace

tvmerge ds1 ds2 ds3, id(id) ///
    start(s1 s2 s3) stop(e1 e2 e3) ///
    exposure(x1 x2 x3)

* Three-way overlap is Jun-Sep (ds1 ends Sep, ds2&ds3 start Apr/Jun)
* Should have intersection Jun 1 - Sep 30
sum start
assert r(min) == mdy(6,1,2020)
sum stop
assert r(max) == mdy(9,30,2020)
```

---

## 6. Test Data Requirements

### 6.1 Minimal Verification Datasets

Create small datasets where every row of output can be verified:

```stata
* Cohort: 3 persons, 1 year each
clear
input long id double(study_entry study_exit)
    1 mdy(1,1,2020) mdy(12,31,2020)
    2 mdy(1,1,2020) mdy(12,31,2020)
    3 mdy(1,1,2020) mdy(12,31,2020)
end
save validation_cohort, replace

* Exposures: Carefully designed patterns
clear
input long id double(rx_start rx_stop) byte exp_type
    // Person 1: Single mid-year exposure
    1 mdy(4,1,2020) mdy(6,30,2020) 1

    // Person 2: Two non-overlapping exposures
    2 mdy(2,1,2020) mdy(3,31,2020) 1
    2 mdy(8,1,2020) mdy(10,31,2020) 2

    // Person 3: No exposure (test reference handling)
    // (no rows)
end
save validation_exposures, replace

* Events: Known event timing
clear
input long id double(event_dt death_dt)
    1 mdy(5,15,2020) .             // Event during exposure
    2 mdy(9,15,2020) .             // Event during second exposure
    3 . mdy(7,1,2020)              // Death only (competing risk)
end
save validation_events, replace
```

### 6.2 Boundary Condition Datasets

```stata
* Exposure exactly at study boundaries
clear
input long id double(rx_start rx_stop) byte exp_type
    1 mdy(1,1,2020) mdy(12,31,2020) 1  // Entire study period
    2 mdy(1,1,2020) mdy(6,30,2020) 1   // Starts at entry
    3 mdy(7,1,2020) mdy(12,31,2020) 1  // Ends at exit
end
save validation_boundary, replace
```

### 6.3 Edge Case Datasets

```stata
* Single-day exposures
clear
input long id double(rx_start rx_stop) byte exp_type
    1 mdy(6,15,2020) mdy(6,15,2020) 1  // Single day
end
save validation_singleday, replace

* Zero-gap adjacent exposures
clear
input long id double(rx_start rx_stop) byte exp_type
    1 mdy(1,1,2020) mdy(3,31,2020) 1
    1 mdy(4,1,2020) mdy(6,30,2020) 2  // Starts day after previous ends
end
save validation_adjacent, replace
```

---

## 7. Implementation Recommendations

### 7.1 Test File Organization

```
_testing/
├── validation/
│   ├── data/
│   │   ├── validation_cohort.dta
│   │   ├── validation_exposures.dta
│   │   ├── validation_events.dta
│   │   └── validation_expected.dta
│   ├── test_tvexpose_validation.do
│   ├── test_tvevent_validation.do
│   └── test_tvmerge_validation.do
```

### 7.2 Test Structure Template

```stata
/*******************************************************************************
* test_tvexpose_validation.do
*
* Purpose: Deep validation tests using known-answer verification
*******************************************************************************/

clear all
set more off
version 16.0

* Load validation data
use validation_cohort, clear

* TEST CATEGORY: Interval Splitting
* ---------------------------------

* Test 1: Basic split creates correct intervals
capture {
    // ... test code ...
}
if _rc == 0 {
    display "PASS: Test 1 - Basic interval splitting"
}
else {
    display "FAIL: Test 1 - Basic interval splitting"
}

* Test 2: Person-time conserved
capture {
    // ... test code ...
}
// ...
```

### 7.3 Helper Programs

Create reusable validation programs:

```stata
* Program to verify non-overlapping intervals
capture program drop _verify_no_overlap
program define _verify_no_overlap, rclass
    syntax, id(varname) start(varname) stop(varname)

    sort `id' `start' `stop'
    tempvar prev_stop overlap
    by `id': gen double `prev_stop' = `stop'[_n-1] if _n > 1
    by `id': gen byte `overlap' = (`start' < `prev_stop') if _n > 1
    count if `overlap' == 1
    return scalar n_overlaps = r(N)
end

* Program to verify person-time conservation
capture program drop _verify_ptime_conserved
program define _verify_ptime_conserved, rclass
    syntax, id(varname) start(varname) stop(varname) ///
            expected_ptime(real) [tolerance(real 0.001)]

    tempvar dur
    gen double `dur' = `stop' - `start'
    sum `dur'
    local actual = r(sum)
    local pct_diff = abs(`actual' - `expected_ptime') / `expected_ptime'
    return scalar pct_diff = `pct_diff'
    return scalar passed = (`pct_diff' < `tolerance')
end
```

### 7.4 Execution Strategy

1. **Phase 1**: Create validation datasets and expected results
2. **Phase 2**: Implement core mathematical verification tests
3. **Phase 3**: Add boundary condition tests
4. **Phase 4**: Add edge case tests
5. **Phase 5**: Integrate with existing test runner

### 7.5 Priority Order

| Priority | Test Category | Rationale |
|----------|--------------|-----------|
| P0 | Person-time conservation | Most fundamental invariant |
| P0 | Non-overlapping intervals | Data integrity |
| P1 | Event placement | Core tvevent functionality |
| P1 | Cumulative calculation | Core continuousunit() math |
| P2 | Competing risk resolution | Important for survival analysis |
| P2 | Grace/lag/washout timing | Complex date arithmetic |
| P3 | Value labels | User experience |
| P3 | Three-way merge | Less common use case |

---

## Appendix A: Quick Reference Checklists

### tvexpose Validation Checklist

**Core Invariants**
- [ ] Person-time equals input follow-up time
- [ ] No overlapping intervals within person
- [ ] All IDs from cohort present in output
- [ ] Intervals cover entire study period (contiguous)
- [ ] Date format preserved from input

**Exposure Tracking**
- [ ] Exposure values match input categories plus reference
- [ ] Cumulative exposure never decreases
- [ ] Duration categories assigned at correct thresholds
- [ ] evertreated never reverts to unexposed
- [ ] currentformer transitions: never→current→former only

**Timing Options**
- [ ] Grace period correctly bridges gaps of specified length
- [ ] Lag delays exposure activation by specified days
- [ ] Washout extends exposure persistence after stop
- [ ] Window restricts exposure to specified time range

**Overlap Resolution**
- [ ] Priority assigns higher priority exposure during overlaps
- [ ] Split creates intervals at all change points
- [ ] Layer resumes earlier exposure after later one ends

**Edge Cases**
- [ ] Exposure exactly at study entry handled correctly
- [ ] Exposure exactly at study exit handled correctly
- [ ] Single-day exposures processed correctly
- [ ] Missing/invalid inputs produce informative errors

### tvevent Validation Checklist

**Core Behavior**
- [ ] Event count in output matches input (non-missing events)
- [ ] Events placed at correct row (stop = event date)
- [ ] Interval splitting preserves total person-time

**Boundary Conditions**
- [ ] Event exactly at interval start NOT captured (strict >)
- [ ] Event exactly at interval stop NOT captured (strict <)
- [ ] Event one day inside boundaries IS captured
- [ ] Event outside all intervals results in censoring

**Competing Risks**
- [ ] Earliest event wins when multiple events exist
- [ ] Correct outcome code assigned (1=primary, 2+=competing)
- [ ] Same-day primary and competing: document tiebreaker

**Type Handling**
- [ ] type(single) truncates follow-up at first event
- [ ] type(recurring) preserves all person-time
- [ ] Wide-format recurring events (var1, var2, ...) detected

**Continuous Variables**
- [ ] Continuous variables pro-rated during interval splitting
- [ ] Total value preserved across split intervals

**Error Handling**
- [ ] Missing id/date variables produce errors
- [ ] Invalid type() value rejected
- [ ] Person not in interval file handled gracefully

### tvmerge Validation Checklist

**Core Behavior**
- [ ] Output intervals are intersection of all inputs
- [ ] All overlapping periods from all datasets represented
- [ ] No duplicate intervals in output

**ID Handling**
- [ ] Only IDs present in ALL datasets appear (without force)
- [ ] force option allows mismatched IDs with warning

**Continuous Variables**
- [ ] Continuous variables interpolated proportionally
- [ ] Original total value preserved

**Multi-Way Merges**
- [ ] Three-way merge produces correct intersection
- [ ] Non-overlapping periods excluded from output

---

## Appendix B: Potential Issues Identified

During review of the validation plan, the following potential issues were identified that should be investigated:

### Critical Questions to Resolve

1. **Inclusive vs Exclusive Stop Dates**
   - Does tvexpose use inclusive stop (last day in interval) or exclusive stop (first day after)?
   - This affects ALL person-time calculations and boundary assertions
   - **Action**: Run a simple test case and document the convention

2. **tvevent Strict Inequality**
   - Code uses `start < date < stop` (strictly between)
   - Events exactly at start or stop are NOT captured
   - **Risk**: User may not expect this behavior
   - **Action**: Document clearly in help file; consider optional `<=` mode

3. **Same-Day Event Tiebreaker**
   - When primary and competing events occur on same day, which wins?
   - Code order suggests primary wins, but verify
   - **Action**: Add explicit test and document behavior

4. **merge() vs grace() Distinction**
   - merge() combines same-type periods within window
   - grace() extends exposure through gaps
   - The distinction may be confusing to users
   - **Action**: Document clearly with examples

### Potential Bugs to Investigate

1. **Leap Year Handling**
   - 2020 is a leap year (366 days)
   - Verify all tests use leap years intentionally or document limitation

2. **Floating Point Precision**
   - Continuous exposure calculations may accumulate rounding errors
   - Use tolerance in all assertions (e.g., `abs(x - expected) < 0.01`)

3. **Empty Input Handling**
   - What happens with zero-observation exposure files?
   - What happens when no events occur for any person?

4. **String IDs**
   - All test examples use numeric IDs
   - tvmerge in particular may have issues with string ID matching

5. **Date Format Edge Cases**
   - What if cohort uses %td but exposure uses %tc?
   - What about datetime variables?

### Documentation Gaps

1. Add examples showing exact boundary behavior
2. Document the merge() vs grace() difference
3. Clarify whether person-time calculation is inclusive or exclusive
4. Add troubleshooting section for common issues

---

## Appendix C: Test Data Generation Script

Create a master script that generates all validation datasets:

```stata
/*******************************************************************************
* generate_validation_data.do
*
* Purpose: Create all datasets needed for deep validation testing
*******************************************************************************/

clear all
set more off
version 16.0

* Define output directory
global VAL_DATA "${STATA_TOOLS_PATH}/_testing/validation/data"
capture mkdir "${VAL_DATA}"

* =============================================================================
* COHORT DATA
* =============================================================================

* Standard 3-person cohort for most tests
clear
input long id double(study_entry study_exit)
    1 `=mdy(1,1,2020)' `=mdy(12,31,2020)'
    2 `=mdy(1,1,2020)' `=mdy(12,31,2020)'
    3 `=mdy(1,1,2020)' `=mdy(12,31,2020)'
end
format %td study_entry study_exit
label data "Standard 3-person cohort, 2020 (leap year)"
save "${VAL_DATA}/cohort_standard.dta", replace

* =============================================================================
* EXPOSURE DATA
* =============================================================================

* Basic single exposure
clear
input long id double(rx_start rx_stop) byte exp_type
    1 `=mdy(3,1,2020)' `=mdy(6,30,2020)' 1
end
format %td rx_start rx_stop
label data "Single exposure Mar-Jun 2020"
save "${VAL_DATA}/exp_basic.dta", replace

* Two non-overlapping exposures
clear
input long id double(rx_start rx_stop) byte exp_type
    1 `=mdy(2,1,2020)' `=mdy(3,31,2020)' 1
    1 `=mdy(8,1,2020)' `=mdy(10,31,2020)' 2
end
format %td rx_start rx_stop
label data "Two non-overlapping exposures, different types"
save "${VAL_DATA}/exp_two_types.dta", replace

* Overlapping exposures
clear
input long id double(rx_start rx_stop) byte exp_type
    1 `=mdy(1,1,2020)' `=mdy(6,30,2020)' 1
    1 `=mdy(4,1,2020)' `=mdy(9,30,2020)' 2
end
format %td rx_start rx_stop
label data "Overlapping exposures Apr-Jun"
save "${VAL_DATA}/exp_overlap.dta", replace

* Boundary conditions
clear
input long id double(rx_start rx_stop) byte exp_type
    1 `=mdy(1,1,2020)' `=mdy(12,31,2020)' 1  // Entire study
    2 `=mdy(1,1,2020)' `=mdy(6,30,2020)' 1   // Starts at entry
    3 `=mdy(7,1,2020)' `=mdy(12,31,2020)' 1  // Ends at exit
end
format %td rx_start rx_stop
label data "Boundary condition exposures"
save "${VAL_DATA}/exp_boundary.dta", replace

* =============================================================================
* EVENT DATA
* =============================================================================

* Single event per person
clear
input long id double event_dt
    1 `=mdy(5,15,2020)'
    2 `=mdy(9,15,2020)'
    3 .
end
format %td event_dt
label data "Single events, person 3 censored"
save "${VAL_DATA}/events_single.dta", replace

* Events with competing risks
clear
input long id double(primary_dt death_dt)
    1 `=mdy(6,15,2020)' .
    2 . `=mdy(4,1,2020)'
    3 `=mdy(8,1,2020)' `=mdy(7,1,2020)'
end
format %td primary_dt death_dt
label data "Events with competing risks"
save "${VAL_DATA}/events_competing.dta", replace

* =============================================================================
* INTERVAL DATA (pre-processed by tvexpose)
* =============================================================================

* Simple intervals for tvevent testing
clear
input long id double(start stop) byte tv_exp
    1 `=mdy(1,1,2020)' `=mdy(6,30,2020)' 1
    1 `=mdy(7,1,2020)' `=mdy(12,31,2020)' 0
    2 `=mdy(1,1,2020)' `=mdy(12,31,2020)' 0
end
format %td start stop
label data "Pre-split intervals for tvevent tests"
save "${VAL_DATA}/intervals_test.dta", replace

di as result "Validation data generated successfully in: ${VAL_DATA}"
```

---

*Document created: 2025-12-13*
*Last updated: 2025-12-13*
