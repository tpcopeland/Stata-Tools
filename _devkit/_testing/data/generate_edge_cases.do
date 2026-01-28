/*******************************************************************************
* generate_edge_cases.do
*
* Purpose: Generate edge case test datasets for comprehensive testing
* Run with: stata-mp -b do generate_edge_cases.do
*
* Creates datasets that expose bugs in:
* - Empty data handling
* - Single observation cases
* - Missing value propagation
* - Zero variance variables
* - Multi-observation per person data
* - Boundary conditions
*******************************************************************************/

clear all
set more off
version 16.0

* Output directory - use current directory (run this from within data folder)
local outdir "."

display _dup(70) "="
display "Generating Edge Case Test Datasets"
display "Date: $S_DATE $S_TIME"
display _dup(70) "="

* ============================================================================
* 1. EMPTY DATASET
* ============================================================================
display "Creating: empty.dta"
clear
gen long id = .
gen double x = .
gen double y = .
save "`outdir'/empty.dta", replace

* ============================================================================
* 2. SINGLE OBSERVATION
* ============================================================================
display "Creating: single_obs.dta"
clear
set obs 1
gen long id = 1
gen double x = 100
gen double y = 200
gen str20 name = "Single"
save "`outdir'/single_obs.dta", replace

* ============================================================================
* 3. ALL MISSING VALUES
* ============================================================================
display "Creating: all_missing.dta"
clear
set obs 100
gen long id = _n
gen double x = .
gen double y = .
gen str20 name = ""
save "`outdir'/all_missing.dta", replace

* ============================================================================
* 4. ZERO VARIANCE (Constant Values)
* ============================================================================
display "Creating: zero_variance.dta"
clear
set obs 100
gen long id = _n
gen double x = 5          // Constant
gen double y = 10         // Constant
gen byte flag = 1         // Constant
save "`outdir'/zero_variance.dta", replace

* ============================================================================
* 5. MULTI-INTERVAL PER PERSON (Time-varying)
* ============================================================================
display "Creating: multi_interval.dta"
clear
set obs 15

* Person 1: 3 intervals
* Person 2: 3 intervals
* Person 3: 3 intervals
* Person 4: 3 intervals
* Person 5: 3 intervals
gen long id = ceil(_n / 3)
bysort id: gen byte interval = _n

* Create time intervals (days from 2020-01-01)
* Base date: 21915 = Jan 1, 2020
gen double start = 21915 + (interval - 1) * 30
gen double stop = start + 30

* Some variation in exposure
gen byte exposure = mod(_n, 2)

* Outcome at different times
gen double event_date = 21915 + 50 if _n == 2  // Person 1, interval 2
replace event_date = 21915 + 80 if _n == 7     // Person 3, interval 1

format start stop event_date %td
save "`outdir'/multi_interval.dta", replace

* ============================================================================
* 6. BOUNDARY CONDITIONS
* ============================================================================
display "Creating: boundary_conditions.dta"
clear
set obs 10
gen long id = _n
gen double x = .

* Various boundary values
replace x = 0 in 1                    // Zero
replace x = -1 in 2                   // Negative
replace x = 1 in 3                    // One
replace x = c(maxdouble) in 4         // Max double
replace x = c(mindouble) in 5         // Min double
replace x = c(epsdouble) in 6         // Epsilon
replace x = . in 7                    // Missing
replace x = .a in 8                   // Extended missing
replace x = 1e-10 in 9                // Very small
replace x = 1e10 in 10                // Very large

save "`outdir'/boundary_conditions.dta", replace

* ============================================================================
* 7. DATE BOUNDARIES (Leap year, year boundaries)
* ============================================================================
display "Creating: date_boundaries.dta"
clear
set obs 10
gen long id = _n
gen double event_date = .

* Key date boundaries
replace event_date = mdy(12, 31, 2019) in 1   // Year end
replace event_date = mdy(1, 1, 2020) in 2     // Year start (leap year)
replace event_date = mdy(2, 28, 2020) in 3    // Before leap day
replace event_date = mdy(2, 29, 2020) in 4    // Leap day
replace event_date = mdy(3, 1, 2020) in 5     // After leap day
replace event_date = mdy(6, 30, 2020) in 6    // Mid-year
replace event_date = mdy(12, 31, 2020) in 7   // Leap year end
replace event_date = mdy(1, 1, 2021) in 8     // Non-leap year
replace event_date = mdy(2, 28, 2021) in 9    // Feb end non-leap
replace event_date = mdy(3, 1, 2021) in 10    // Mar start non-leap

format event_date %td
gen str20 description = ""
replace description = "Year end 2019" in 1
replace description = "Year start 2020" in 2
replace description = "Before leap day" in 3
replace description = "Leap day" in 4
replace description = "After leap day" in 5
replace description = "Mid-year 2020" in 6
replace description = "Year end 2020" in 7
replace description = "Year start 2021" in 8
replace description = "Feb end non-leap" in 9
replace description = "Mar start non-leap" in 10

save "`outdir'/date_boundaries.dta", replace

* ============================================================================
* 8. DUPLICATE IDs (for testing uniqueness requirements)
* ============================================================================
display "Creating: duplicate_ids.dta"
clear
input long id double x str20 name
    1 100 "First"
    1 200 "Duplicate"
    2 300 "Single"
    3 400 "First"
    3 500 "Duplicate"
    3 600 "Triple"
end
save "`outdir'/duplicate_ids.dta", replace

* ============================================================================
* 9. MIXED TYPES (numeric and string)
* ============================================================================
display "Creating: mixed_types.dta"
clear
input long id str20 name double value byte flag
    1 "Alpha" 100.5 1
    2 "Beta" 200.7 0
    3 "Gamma" . 1
    4 "" 400.2 .
    5 "Epsilon" 0 0
end
save "`outdir'/mixed_types.dta", replace

* ============================================================================
* 10. LARGE OBSERVATION COUNT (for performance testing)
* ============================================================================
display "Creating: large_n.dta (10,000 obs)"
clear
set obs 10000
gen long id = _n
gen double x = rnormal(100, 15)
gen double y = x * 2 + rnormal(0, 5)
gen byte group = ceil(_n / 100)
save "`outdir'/large_n.dta", replace

* ============================================================================
* SUMMARY
* ============================================================================
display ""
display _dup(70) "="
display "Edge Case Datasets Created:"
display _dup(70) "="
display "  empty.dta              - Empty dataset (0 obs)"
display "  single_obs.dta         - Single observation"
display "  all_missing.dta        - All values missing"
display "  zero_variance.dta      - Constant values"
display "  multi_interval.dta     - Multiple intervals per person"
display "  boundary_conditions.dta - Numeric boundary values"
display "  date_boundaries.dta    - Date boundary cases"
display "  duplicate_ids.dta      - Duplicate ID values"
display "  mixed_types.dta        - Mixed numeric/string"
display "  large_n.dta            - 10,000 observations"
display _dup(70) "="
display "Output directory: `outdir'"
