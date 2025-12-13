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

---

## 2. Deep Validation Principles

### 2.1 Known-Answer Testing

Create minimal datasets where you can calculate expected results by hand:

```
Input:
  Person 1: Study Jan 1-Dec 31, 2020
            Exposure Mar 1-Jun 30, 2020 (type=1)

Expected output:
  Person 1, Row 1: Jan 1 - Feb 29, tv_exp=0 (91 days unexposed)
  Person 1, Row 2: Mar 1 - Jun 30, tv_exp=1 (122 days exposed)
  Person 1, Row 3: Jul 1 - Dec 31, tv_exp=0 (184 days unexposed)
```

### 2.2 Invariant Testing

Properties that must hold regardless of input:

1. **Person-time conservation**: Sum of (stop - start) should equal original (exit - entry)
2. **ID preservation**: All input IDs appear in output
3. **Non-overlapping intervals**: Within each ID, no two rows should overlap
4. **Monotonic cumulative values**: Cumulative exposure should never decrease within person
5. **Date ordering**: start < stop for all rows; rows sorted by start within ID

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

* Verify EXACT values
assert _N == 3  // Three intervals

* Row 1: Before exposure
assert rx_start[1] == mdy(1,1,2020)
assert rx_stop[1] == mdy(2,29,2020)  // Day before exposure start
assert tv_exp[1] == 0

* Row 2: During exposure
assert rx_start[2] == mdy(3,1,2020)
assert rx_stop[2] == mdy(6,30,2020)
assert tv_exp[2] == 1

* Row 3: After exposure
assert rx_start[3] == mdy(7,1,2020)
assert rx_stop[3] == mdy(12,31,2020)
assert tv_exp[3] == 0

* Verify person-time conservation
gen ptime = rx_stop - rx_start + 1  // +1 for inclusive
egen total_ptime = total(ptime)
assert total_ptime == 366  // 2020 is leap year
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

## Appendix: Quick Reference Checklists

### tvexpose Validation Checklist

- [ ] Person-time equals input follow-up time
- [ ] No overlapping intervals within person
- [ ] All IDs from cohort present in output
- [ ] Exposure values match input categories
- [ ] Cumulative exposure never decreases
- [ ] Duration categories assigned at correct thresholds
- [ ] Grace period correctly merges gaps
- [ ] Lag delays exposure start
- [ ] Washout extends exposure end
- [ ] Priority resolves overlaps correctly
- [ ] evertreated never reverts
- [ ] currentformer transitions correctly

### tvevent Validation Checklist

- [ ] Event count matches input
- [ ] Events occur at interval boundaries (stop date)
- [ ] Continuous variables pro-rated correctly
- [ ] Competing risks assigned to earliest date
- [ ] type(single) censors after first event
- [ ] type(recurring) keeps all person-time
- [ ] Labels applied correctly

### tvmerge Validation Checklist

- [ ] Output intervals are intersection of inputs
- [ ] No duplicate intervals in output
- [ ] Continuous variables interpolated correctly
- [ ] IDs present in all input datasets appear in output
- [ ] Three-way merge creates correct intersection

---

*Document created: 2025-12-13*
*Last updated: 2025-12-13*
