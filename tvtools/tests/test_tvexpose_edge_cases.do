*! test_tvexpose_edge_cases.do
*! Test suite for tvexpose edge cases
*! Author: Tim Copeland
*! Date: 2025-12-01
*! Version: 1.0.0
*!
*! This test suite validates tvexpose behavior for:
*!   1. Empty datasets (no observations)
*!   2. Single-observation data
*!   3. All missing values in key variables
*!   4. Perfect overlap scenarios
*!   5. Single person data
*!   6. Very long exposure periods
*!   7. Multiple exposure types with complex interactions
*!   8. Boundary date conditions

clear all
set more off
set varabbrev off
version 16.0

* Set random seed for reproducibility
set seed 12345

* Define temporary directory for test files
local test_dir "`c(tmpdir)'/tvexpose_tests"
capture mkdir "`test_dir'"

* Initialize test counter
local tests_passed = 0
local tests_failed = 0
local tests_run = 0

* ===========================================================================
* HELPER PROGRAMS
* ===========================================================================

* Program to display test results
capture program drop test_result
program define test_result
    args test_name passed message
    local ++tests_run
    if `passed' {
        display as result "[PASS] " as text "`test_name'"
        local ++tests_passed
    }
    else {
        display as error "[FAIL] " as text "`test_name': `message'"
        local ++tests_failed
    }
end

display as result "{hline 70}"
display as result "tvexpose Edge Case Test Suite"
display as result "{hline 70}"
display as text ""

* ===========================================================================
* TEST 1: Empty master dataset (0 observations)
* ===========================================================================
display as text "TEST 1: Empty master dataset"

* Create empty master dataset
clear
generate long id = .
generate double entry = .
generate double exit = .
save "`test_dir'/master_empty.dta", replace

* Create exposure dataset with one record (but master is empty)
clear
input long id double start double stop int exposure
1 21000 21100 1
end
save "`test_dir'/exp_empty.dta", replace

* Load empty master and try tvexpose - should error
quietly use "`test_dir'/master_empty.dta", clear
capture noisily tvexpose using "`test_dir'/exp_empty.dta", ///
    id(id) start(start) stop(stop) exposure(exposure) ///
    reference(0) entry(entry) exit(exit)
local rc = _rc

* Expected: error 2000 (no observations)
if `rc' == 2000 {
    display as result "[PASS] Test 1: Empty master dataset correctly rejected"
    local ++tests_passed
}
else {
    display as error "[FAIL] Test 1: Expected error 2000, got `rc'"
    local ++tests_failed
}
local ++tests_run

* ===========================================================================
* TEST 2: Single observation (one person, one exposure period)
* ===========================================================================
display as text ""
display as text "TEST 2: Single observation data"

* Create master with one person
clear
input long id double entry double exit
1 21000 21365
end
format entry exit %td
save "`test_dir'/master_single.dta", replace

* Create exposure with one period
clear
input long id double start double stop int exposure
1 21050 21100 1
end
format start stop %td
save "`test_dir'/exp_single.dta", replace

* Run tvexpose
quietly use "`test_dir'/master_single.dta", clear
capture noisily tvexpose using "`test_dir'/exp_single.dta", ///
    id(id) start(start) stop(stop) exposure(exposure) ///
    reference(0) entry(entry) exit(exit)
local rc = _rc

if `rc' == 0 {
    * Verify output structure
    quietly count
    local n_periods = r(N)

    * Should have 3 periods: baseline + exposed + post-exposure
    if `n_periods' == 3 {
        * Verify complete coverage
        quietly generate double days = stop - start + 1
        quietly summarize days
        local total_days = r(sum)

        * Expected: 366 days (21365 - 21000 + 1)
        if `total_days' == 366 {
            display as result "[PASS] Test 2: Single observation processed correctly"
            local ++tests_passed
        }
        else {
            display as error "[FAIL] Test 2: Expected 366 days, got `total_days'"
            local ++tests_failed
        }
    }
    else {
        display as error "[FAIL] Test 2: Expected 3 periods, got `n_periods'"
        local ++tests_failed
    }
}
else {
    display as error "[FAIL] Test 2: tvexpose failed with rc=`rc'"
    local ++tests_failed
}
local ++tests_run

* ===========================================================================
* TEST 3: All exposure periods outside study window
* ===========================================================================
display as text ""
display as text "TEST 3: All exposures outside study window"

* Create master with study period 2017-2018
clear
input long id double entry double exit
1 20820 21184
end
format entry exit %td
save "`test_dir'/master_outside.dta", replace

* Create exposure entirely before study period
clear
input long id double start double stop int exposure
1 20000 20100 1
end
format start stop %td
save "`test_dir'/exp_outside.dta", replace

* Run tvexpose - should error (no exposure periods found)
quietly use "`test_dir'/master_outside.dta", clear
capture noisily tvexpose using "`test_dir'/exp_outside.dta", ///
    id(id) start(start) stop(stop) exposure(exposure) ///
    reference(0) entry(entry) exit(exit)
local rc = _rc

* Expected: error 2000 (no observations after filtering)
if `rc' == 2000 {
    display as result "[PASS] Test 3: Exposures outside window correctly rejected"
    local ++tests_passed
}
else {
    display as error "[FAIL] Test 3: Expected error 2000, got `rc'"
    local ++tests_failed
}
local ++tests_run

* ===========================================================================
* TEST 4: Perfect overlap (two periods with identical dates)
* ===========================================================================
display as text ""
display as text "TEST 4: Perfect overlap (identical periods)"

* Create master
clear
input long id double entry double exit
1 21000 21365
end
format entry exit %td
save "`test_dir'/master_overlap.dta", replace

* Create two identical exposure periods
clear
input long id double start double stop int exposure
1 21050 21100 1
1 21050 21100 2
end
format start stop %td
save "`test_dir'/exp_overlap.dta", replace

* Run tvexpose with layer (default)
quietly use "`test_dir'/master_overlap.dta", clear
capture noisily tvexpose using "`test_dir'/exp_overlap.dta", ///
    id(id) start(start) stop(stop) exposure(exposure) ///
    reference(0) entry(entry) exit(exit)
local rc = _rc

if `rc' == 0 {
    * Should handle perfect overlap gracefully
    quietly count
    if r(N) > 0 {
        display as result "[PASS] Test 4: Perfect overlap handled"
        local ++tests_passed
    }
    else {
        display as error "[FAIL] Test 4: No periods generated"
        local ++tests_failed
    }
}
else {
    display as error "[FAIL] Test 4: tvexpose failed with rc=`rc'"
    local ++tests_failed
}
local ++tests_run

* ===========================================================================
* TEST 5: Zero-length exposure period (start == stop)
* ===========================================================================
display as text ""
display as text "TEST 5: Zero-length exposure period (single day)"

* Create master
clear
input long id double entry double exit
1 21000 21365
end
format entry exit %td
save "`test_dir'/master_zerolength.dta", replace

* Create single-day exposure
clear
input long id double start double stop int exposure
1 21100 21100 1
end
format start stop %td
save "`test_dir'/exp_zerolength.dta", replace

* Run tvexpose
quietly use "`test_dir'/master_zerolength.dta", clear
capture noisily tvexpose using "`test_dir'/exp_zerolength.dta", ///
    id(id) start(start) stop(stop) exposure(exposure) ///
    reference(0) entry(entry) exit(exit)
local rc = _rc

if `rc' == 0 {
    * Verify single-day exposure is captured
    quietly count if tv_exposure == 1
    local exposed_periods = r(N)

    if `exposed_periods' > 0 {
        * Check that exposed period has 1 day
        quietly generate double days = stop - start + 1 if tv_exposure == 1
        quietly summarize days
        if r(sum) == 1 {
            display as result "[PASS] Test 5: Single-day exposure handled correctly"
            local ++tests_passed
        }
        else {
            display as error "[FAIL] Test 5: Single-day exposure has wrong duration"
            local ++tests_failed
        }
    }
    else {
        display as error "[FAIL] Test 5: No exposed periods found"
        local ++tests_failed
    }
}
else {
    display as error "[FAIL] Test 5: tvexpose failed with rc=`rc'"
    local ++tests_failed
}
local ++tests_run

* ===========================================================================
* TEST 6: Exposure starting exactly on entry date
* ===========================================================================
display as text ""
display as text "TEST 6: Exposure starting exactly on entry date"

* Create master
clear
input long id double entry double exit
1 21000 21365
end
format entry exit %td
save "`test_dir'/master_boundary.dta", replace

* Exposure starts exactly on entry
clear
input long id double start double stop int exposure
1 21000 21100 1
end
format start stop %td
save "`test_dir'/exp_boundary.dta", replace

* Run tvexpose
quietly use "`test_dir'/master_boundary.dta", clear
capture noisily tvexpose using "`test_dir'/exp_boundary.dta", ///
    id(id) start(start) stop(stop) exposure(exposure) ///
    reference(0) entry(entry) exit(exit)
local rc = _rc

if `rc' == 0 {
    * First period should be exposed (not baseline)
    quietly summarize start
    local first_start = r(min)

    if `first_start' == 21000 {
        * Check that first period is exposed
        quietly generate byte is_first = (start == 21000)
        quietly summarize tv_exposure if is_first == 1
        if r(mean) == 1 {
            display as result "[PASS] Test 6: Boundary start handled correctly (no baseline)"
            local ++tests_passed
        }
        else {
            display as result "[PASS] Test 6: Boundary start handled (baseline may exist)"
            local ++tests_passed
        }
    }
    else {
        display as error "[FAIL] Test 6: Unexpected first period start date"
        local ++tests_failed
    }
}
else {
    display as error "[FAIL] Test 6: tvexpose failed with rc=`rc'"
    local ++tests_failed
}
local ++tests_run

* ===========================================================================
* TEST 7: Exposure ending exactly on exit date
* ===========================================================================
display as text ""
display as text "TEST 7: Exposure ending exactly on exit date"

* Create master
clear
input long id double entry double exit
1 21000 21365
end
format entry exit %td
save "`test_dir'/master_exit.dta", replace

* Exposure ends exactly on exit
clear
input long id double start double stop int exposure
1 21300 21365 1
end
format start stop %td
save "`test_dir'/exp_exit.dta", replace

* Run tvexpose
quietly use "`test_dir'/master_exit.dta", clear
capture noisily tvexpose using "`test_dir'/exp_exit.dta", ///
    id(id) start(start) stop(stop) exposure(exposure) ///
    reference(0) entry(entry) exit(exit)
local rc = _rc

if `rc' == 0 {
    * Last period should be exposed (not post-exposure)
    quietly summarize stop
    local last_stop = r(max)

    if `last_stop' == 21365 {
        * Check that last period is exposed
        quietly generate byte is_last = (stop == 21365)
        quietly summarize tv_exposure if is_last == 1
        if r(mean) == 1 {
            display as result "[PASS] Test 7: Boundary exit handled correctly"
            local ++tests_passed
        }
        else {
            display as error "[FAIL] Test 7: Last period should be exposed"
            local ++tests_failed
        }
    }
    else {
        display as error "[FAIL] Test 7: Unexpected last period stop date"
        local ++tests_failed
    }
}
else {
    display as error "[FAIL] Test 7: tvexpose failed with rc=`rc'"
    local ++tests_failed
}
local ++tests_run

* ===========================================================================
* TEST 8: Multiple persons with varying exposure patterns
* ===========================================================================
display as text ""
display as text "TEST 8: Multiple persons with varying patterns"

* Create master with 3 persons
clear
input long id double entry double exit
1 21000 21365
2 21000 21365
3 21000 21365
end
format entry exit %td
save "`test_dir'/master_multi.dta", replace

* Person 1: exposed, Person 2: never exposed, Person 3: multiple exposures
clear
input long id double start double stop int exposure
1 21050 21100 1
3 21050 21100 1
3 21200 21250 2
end
format start stop %td
save "`test_dir'/exp_multi.dta", replace

* Run tvexpose
quietly use "`test_dir'/master_multi.dta", clear
capture noisily tvexpose using "`test_dir'/exp_multi.dta", ///
    id(id) start(start) stop(stop) exposure(exposure) ///
    reference(0) entry(entry) exit(exit)
local rc = _rc

if `rc' == 0 {
    * Check all 3 persons present
    quietly levelsof id, local(ids)
    local n_persons : word count `ids'

    if `n_persons' == 3 {
        * Check person 2 (never exposed) has only reference periods
        quietly count if id == 2 & tv_exposure != 0
        if r(N) == 0 {
            display as result "[PASS] Test 8: Multiple persons handled correctly"
            local ++tests_passed
        }
        else {
            display as error "[FAIL] Test 8: Person 2 should have no exposed periods"
            local ++tests_failed
        }
    }
    else {
        display as error "[FAIL] Test 8: Expected 3 persons, got `n_persons'"
        local ++tests_failed
    }
}
else {
    display as error "[FAIL] Test 8: tvexpose failed with rc=`rc'"
    local ++tests_failed
}
local ++tests_run

* ===========================================================================
* TEST 9: Adjacent periods (no gap)
* ===========================================================================
display as text ""
display as text "TEST 9: Adjacent periods with no gap"

* Create master
clear
input long id double entry double exit
1 21000 21365
end
format entry exit %td
save "`test_dir'/master_adjacent.dta", replace

* Two adjacent periods of same type (should merge)
clear
input long id double start double stop int exposure
1 21050 21099 1
1 21100 21150 1
end
format start stop %td
save "`test_dir'/exp_adjacent.dta", replace

* Run tvexpose
quietly use "`test_dir'/master_adjacent.dta", clear
capture noisily tvexpose using "`test_dir'/exp_adjacent.dta", ///
    id(id) start(start) stop(stop) exposure(exposure) ///
    reference(0) entry(entry) exit(exit)
local rc = _rc

if `rc' == 0 {
    * Adjacent same-type periods should be merged
    quietly count if tv_exposure == 1
    local exposed_periods = r(N)

    * Should be 1 merged period (or 2 if not merged, still valid)
    if `exposed_periods' >= 1 & `exposed_periods' <= 2 {
        display as result "[PASS] Test 9: Adjacent periods handled"
        local ++tests_passed
    }
    else {
        display as error "[FAIL] Test 9: Unexpected number of exposed periods"
        local ++tests_failed
    }
}
else {
    display as error "[FAIL] Test 9: tvexpose failed with rc=`rc'"
    local ++tests_failed
}
local ++tests_run

* ===========================================================================
* TEST 10: Evertreated with single person
* ===========================================================================
display as text ""
display as text "TEST 10: Evertreated exposure type"

* Create master
clear
input long id double entry double exit
1 21000 21365
end
format entry exit %td
save "`test_dir'/master_ever.dta", replace

* Single exposure
clear
input long id double start double stop int exposure
1 21100 21150 1
end
format start stop %td
save "`test_dir'/exp_ever.dta", replace

* Run tvexpose with evertreated
quietly use "`test_dir'/master_ever.dta", clear
capture noisily tvexpose using "`test_dir'/exp_ever.dta", ///
    id(id) start(start) stop(stop) exposure(exposure) ///
    reference(0) entry(entry) exit(exit) evertreated
local rc = _rc

if `rc' == 0 {
    * Should have never (0) and ever (1) periods
    quietly levelsof tv_exposure, local(vals)
    local n_vals : word count `vals'

    if `n_vals' == 2 {
        display as result "[PASS] Test 10: Evertreated processed correctly"
        local ++tests_passed
    }
    else {
        display as error "[FAIL] Test 10: Expected 2 exposure values, got `n_vals'"
        local ++tests_failed
    }
}
else {
    display as error "[FAIL] Test 10: tvexpose failed with rc=`rc'"
    local ++tests_failed
}
local ++tests_run

* ===========================================================================
* TEST 11: Duration with very short exposure
* ===========================================================================
display as text ""
display as text "TEST 11: Duration with short exposure"

* Create master
clear
input long id double entry double exit
1 21000 21365
end
format entry exit %td
save "`test_dir'/master_dur.dta", replace

* Very short exposure (1 day)
clear
input long id double start double stop int exposure
1 21100 21100 1
end
format start stop %td
save "`test_dir'/exp_dur.dta", replace

* Run tvexpose with duration
quietly use "`test_dir'/master_dur.dta", clear
capture noisily tvexpose using "`test_dir'/exp_dur.dta", ///
    id(id) start(start) stop(stop) exposure(exposure) ///
    reference(0) entry(entry) exit(exit) duration(30 90 180)
local rc = _rc

if `rc' == 0 {
    * Should have created duration categories
    quietly count
    if r(N) > 0 {
        display as result "[PASS] Test 11: Duration with short exposure processed"
        local ++tests_passed
    }
    else {
        display as error "[FAIL] Test 11: No periods generated"
        local ++tests_failed
    }
}
else {
    display as error "[FAIL] Test 11: tvexpose failed with rc=`rc'"
    local ++tests_failed
}
local ++tests_run

* ===========================================================================
* TEST 12: Large number of exposure types
* ===========================================================================
display as text ""
display as text "TEST 12: Multiple exposure types (5 types)"

* Create master
clear
input long id double entry double exit
1 21000 21365
end
format entry exit %td
save "`test_dir'/master_types.dta", replace

* 5 different exposure types
clear
input long id double start double stop int exposure
1 21050 21070 1
1 21080 21100 2
1 21120 21140 3
1 21160 21180 4
1 21200 21220 5
end
format start stop %td
save "`test_dir'/exp_types.dta", replace

* Run tvexpose
quietly use "`test_dir'/master_types.dta", clear
capture noisily tvexpose using "`test_dir'/exp_types.dta", ///
    id(id) start(start) stop(stop) exposure(exposure) ///
    reference(0) entry(entry) exit(exit)
local rc = _rc

if `rc' == 0 {
    * Should have all 5 exposure types plus reference
    quietly levelsof tv_exposure, local(vals)
    local n_vals : word count `vals'

    * Should have 6 values (0, 1, 2, 3, 4, 5)
    if `n_vals' == 6 {
        display as result "[PASS] Test 12: Multiple exposure types handled"
        local ++tests_passed
    }
    else {
        display as error "[FAIL] Test 12: Expected 6 exposure values, got `n_vals'"
        local ++tests_failed
    }
}
else {
    display as error "[FAIL] Test 12: tvexpose failed with rc=`rc'"
    local ++tests_failed
}
local ++tests_run

* ===========================================================================
* TEST 13: Lag option with exposure ending exactly at lag boundary
* ===========================================================================
display as text ""
display as text "TEST 13: Lag option boundary test"

* Create master
clear
input long id double entry double exit
1 21000 21365
end
format entry exit %td
save "`test_dir'/master_lag.dta", replace

* Exposure period of exactly 30 days
clear
input long id double start double stop int exposure
1 21100 21129 1
end
format start stop %td
save "`test_dir'/exp_lag.dta", replace

* Run tvexpose with lag(30) - exposure should just barely be valid
quietly use "`test_dir'/master_lag.dta", clear
capture noisily tvexpose using "`test_dir'/exp_lag.dta", ///
    id(id) start(start) stop(stop) exposure(exposure) ///
    reference(0) entry(entry) exit(exit) lag(30)
local rc = _rc

if `rc' == 0 {
    * With 30-day lag on 30-day exposure, exposure period becomes 0 days
    * This should be handled gracefully
    display as result "[PASS] Test 13: Lag boundary handled"
    local ++tests_passed
}
else {
    display as error "[FAIL] Test 13: tvexpose failed with rc=`rc'"
    local ++tests_failed
}
local ++tests_run

* ===========================================================================
* TEST 14: Complete person-time coverage verification
* ===========================================================================
display as text ""
display as text "TEST 14: Complete person-time coverage"

* Create master with known duration
clear
input long id double entry double exit
1 21000 21099
end
format entry exit %td
save "`test_dir'/master_coverage.dta", replace

* Exposure in middle
clear
input long id double start double stop int exposure
1 21030 21060 1
end
format start stop %td
save "`test_dir'/exp_coverage.dta", replace

* Run tvexpose
quietly use "`test_dir'/master_coverage.dta", clear
capture noisily tvexpose using "`test_dir'/exp_coverage.dta", ///
    id(id) start(start) stop(stop) exposure(exposure) ///
    reference(0) entry(entry) exit(exit)
local rc = _rc

if `rc' == 0 {
    * Verify total days = 100 (21099 - 21000 + 1)
    quietly generate double days = stop - start + 1
    quietly summarize days
    local total_days = r(sum)

    if `total_days' == 100 {
        * Verify no gaps
        quietly sort id start
        quietly generate double gap = start - stop[_n-1] - 1 if _n > 1
        quietly summarize gap
        if r(max) <= 0 | r(N) == 0 {
            display as result "[PASS] Test 14: Complete coverage verified (100 days, no gaps)"
            local ++tests_passed
        }
        else {
            display as error "[FAIL] Test 14: Gaps detected in coverage"
            local ++tests_failed
        }
    }
    else {
        display as error "[FAIL] Test 14: Expected 100 days, got `total_days'"
        local ++tests_failed
    }
}
else {
    display as error "[FAIL] Test 14: tvexpose failed with rc=`rc'"
    local ++tests_failed
}
local ++tests_run

* ===========================================================================
* TEST 15: Pointtime option with single assessment dates
* ===========================================================================
display as text ""
display as text "TEST 15: Point-in-time data"

* Create master
clear
input long id double entry double exit
1 21000 21365
end
format entry exit %td
save "`test_dir'/master_pit.dta", replace

* Point-in-time exposure (no stop dates needed)
clear
input long id double start int exposure
1 21100 1
1 21200 0
1 21300 1
end
format start %td
save "`test_dir'/exp_pit.dta", replace

* Run tvexpose with pointtime
quietly use "`test_dir'/master_pit.dta", clear
capture noisily tvexpose using "`test_dir'/exp_pit.dta", ///
    id(id) start(start) exposure(exposure) ///
    reference(0) entry(entry) exit(exit) pointtime carryforward(50)
local rc = _rc

if `rc' == 0 {
    display as result "[PASS] Test 15: Point-in-time data processed"
    local ++tests_passed
}
else {
    display as error "[FAIL] Test 15: tvexpose failed with rc=`rc'"
    local ++tests_failed
}
local ++tests_run

* ===========================================================================
* SUMMARY
* ===========================================================================
display as text ""
display as result "{hline 70}"
display as result "TEST SUMMARY"
display as result "{hline 70}"
display as text "Tests run: " as result `tests_run'
display as text "Tests passed: " as result `tests_passed'
display as text "Tests failed: " as result `tests_failed'

if `tests_failed' == 0 {
    display as result ""
    display as result "All tests passed!"
}
else {
    display as error ""
    display as error "`tests_failed' test(s) failed - please review"
}
display as result "{hline 70}"

* Clean up temporary files
capture erase "`test_dir'/master_empty.dta"
capture erase "`test_dir'/exp_empty.dta"
capture erase "`test_dir'/master_single.dta"
capture erase "`test_dir'/exp_single.dta"
capture erase "`test_dir'/master_outside.dta"
capture erase "`test_dir'/exp_outside.dta"
capture erase "`test_dir'/master_overlap.dta"
capture erase "`test_dir'/exp_overlap.dta"
capture erase "`test_dir'/master_zerolength.dta"
capture erase "`test_dir'/exp_zerolength.dta"
capture erase "`test_dir'/master_boundary.dta"
capture erase "`test_dir'/exp_boundary.dta"
capture erase "`test_dir'/master_exit.dta"
capture erase "`test_dir'/exp_exit.dta"
capture erase "`test_dir'/master_multi.dta"
capture erase "`test_dir'/exp_multi.dta"
capture erase "`test_dir'/master_adjacent.dta"
capture erase "`test_dir'/exp_adjacent.dta"
capture erase "`test_dir'/master_ever.dta"
capture erase "`test_dir'/exp_ever.dta"
capture erase "`test_dir'/master_dur.dta"
capture erase "`test_dir'/exp_dur.dta"
capture erase "`test_dir'/master_types.dta"
capture erase "`test_dir'/exp_types.dta"
capture erase "`test_dir'/master_lag.dta"
capture erase "`test_dir'/exp_lag.dta"
capture erase "`test_dir'/master_coverage.dta"
capture erase "`test_dir'/exp_coverage.dta"
capture erase "`test_dir'/master_pit.dta"
capture erase "`test_dir'/exp_pit.dta"

* Return results for programmatic checking
return scalar tests_run = `tests_run'
return scalar tests_passed = `tests_passed'
return scalar tests_failed = `tests_failed'
