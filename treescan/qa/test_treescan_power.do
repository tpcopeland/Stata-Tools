* test_treescan_power.do - Functional tests for treescan_power command
* Part of treescan package testing

clear all
set more off

cap program drop treescan
cap program drop treescan_power
cap program drop _on_colon_parse
adopath + "/home/tpcopeland/Stata-Tools/treescan"
run "/home/tpcopeland/Stata-Tools/treescan/treescan.ado"
run "/home/tpcopeland/Stata-Tools/treescan/treescan_power.ado"

scalar n_tests = 0
scalar n_passed = 0
scalar n_failed = 0

capture program drop run_test
program define run_test
    args test_name result
    scalar n_tests = n_tests + 1
    if `result' {
        display as result "[PASS] `test_name'"
        scalar n_passed = n_passed + 1
    }
    else {
        display as error "[FAIL] `test_name'"
        scalar n_failed = n_failed + 1
    }
end

display as text ""
display as text _dup(60) "="
display as text "Testing treescan_power command"
display as text _dup(60) "="
display as text ""

* =============================================================
* Create shared test tree and data
* =============================================================
clear
input str7 node str7 parent byte level str60 description
"root" "" 0 "Root"
"A" "root" 1 "Group A"
"B" "root" 1 "Group B"
"A1" "A" 2 "Code A1"
"A2" "A" 2 "Code A2"
"B1" "B" 2 "Code B1"
end
tempfile test_tree
save `test_tree'

* =============================================================
* TEST 1: Basic power execution with strong signal
* =============================================================
clear
set seed 100
set obs 60
gen long id = _n
gen byte exposed = (_n <= 15)
gen str7 diag = ""
replace diag = "A1" if exposed == 1 & runiform() < 0.7
replace diag = "B1" if diag == ""
drop if diag == ""

treescan_power diag using `test_tree', id(id) exposed(exposed) ///
    target(A1) rr(5) nsim(49) nsimpower(20) seed(42)

local t1a = (r(power) >= 0 & r(power) <= 1)
run_test "T1a: Power in [0, 1]" `t1a'

local t1b = (r(crit_val) >= 0)
run_test "T1b: Critical value non-negative" `t1b'

local t1c = (r(rr) == 5)
run_test "T1c: r(rr) stored correctly" `t1c'

local t1d = ("`r(target)'" == "A1")
run_test "T1d: r(target) stored correctly" `t1d'

local t1e = (r(nsim) == 49)
run_test "T1e: r(nsim) stored correctly" `t1e'

local t1f = (r(nsim_power) == 20)
run_test "T1f: r(nsim_power) stored correctly" `t1f'

local t1g = ("`r(model)'" == "bernoulli")
run_test "T1g: r(model) = bernoulli" `t1g'

local t1h = (r(power_ci_lo) >= 0 & r(power_ci_hi) <= 1)
run_test "T1h: Power CI in [0, 1]" `t1h'

local t1i = (r(power_ci_lo) <= r(power) & r(power) <= r(power_ci_hi))
run_test "T1i: Power within its CI" `t1i'

* =============================================================
* TEST 2: Strong signal should have high power
* =============================================================
* Use clean data: only exposed have target diagnosis
clear
set obs 80
gen long id = _n
gen byte exposed = (_n <= 20)
gen str7 diag = "A1" if exposed == 1
replace diag = "B1" if diag == ""

treescan_power diag using `test_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) nsim(29) nsimpower(30) seed(42)

local t2 = (r(power) > 0.3)
run_test "T2: Strong signal has elevated power" `t2'

* =============================================================
* TEST 3: Reproducibility with same seed
* =============================================================
clear
set seed 300
set obs 60
gen long id = _n
gen byte exposed = (_n <= 15)
gen str7 diag = ""
replace diag = "A1" if exposed == 1 & runiform() < 0.6
replace diag = "B1" if diag == ""
drop if diag == ""

treescan_power diag using `test_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) nsim(29) nsimpower(15) seed(42)
local run1_power = r(power)

treescan_power diag using `test_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) nsim(29) nsimpower(15) seed(42)
local run2_power = r(power)

local t3 = (abs(`run1_power' - `run2_power') < 1e-10)
run_test "T3: Same seed -> same power" `t3'

* =============================================================
* TEST 4: Error — target not in tree
* =============================================================
clear
set seed 400
set obs 30
gen long id = _n
gen byte exposed = (_n <= 8)
gen str7 diag = ""
replace diag = "A1" if exposed == 1 & runiform() < 0.6
replace diag = "B1" if diag == ""
drop if diag == ""

capture treescan_power diag using `test_tree', id(id) exposed(exposed) ///
    target(ZZZZZ) rr(3) nsim(19) nsimpower(5) seed(42)

local t4 = (_rc == 198)
run_test "T4: Error when target not in tree" `t4'

* =============================================================
* TEST 5: Error — rr <= 1
* =============================================================
capture treescan_power diag using `test_tree', id(id) exposed(exposed) ///
    target(A1) rr(0.5) nsim(19) nsimpower(5) seed(42)

local t5 = (_rc == 198)
run_test "T5: Error when rr <= 1" `t5'

* =============================================================
* TEST 6: Error — rr = 1
* =============================================================
capture treescan_power diag using `test_tree', id(id) exposed(exposed) ///
    target(A1) rr(1) nsim(19) nsimpower(5) seed(42)

local t6 = (_rc == 198)
run_test "T6: Error when rr = 1" `t6'

* =============================================================
* TEST 7: Conditional power execution
* =============================================================
clear
set seed 700
set obs 60
gen long id = _n
gen byte exposed = (_n <= 15)
gen str7 diag = ""
replace diag = "A1" if exposed == 1 & runiform() < 0.7
replace diag = "B1" if diag == ""
drop if diag == ""

treescan_power diag using `test_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) conditional nsim(29) nsimpower(10) seed(42)

local t7a = (r(power) >= 0 & r(power) <= 1)
run_test "T7a: Conditional power in [0, 1]" `t7a'

local t7b = ("`r(conditional)'" == "conditional")
run_test "T7b: r(conditional) stored" `t7b'

* =============================================================
* TEST 8: Data preserved after treescan_power
* =============================================================
clear
set seed 800
set obs 40
gen long id = _n
gen byte exposed = (_n <= 10)
gen str7 diag = "A1" if exposed == 1
replace diag = "B1" if diag == ""
gen double extra = runiform()
local orig_N = _N

treescan_power diag using `test_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) nsim(19) nsimpower(5) seed(42)

local t8a = (_N == `orig_N')
run_test "T8a: Observation count preserved" `t8a'

capture confirm variable extra
local t8b = (_rc == 0)
run_test "T8b: Extra variables preserved" `t8b'

* =============================================================
* TEST 9: Internal node as target
* =============================================================
clear
set seed 900
set obs 60
gen long id = _n
gen byte exposed = (_n <= 15)
gen str7 diag = ""
replace diag = "A1" if exposed == 1 & runiform() < 0.5
replace diag = "A2" if exposed == 1 & diag == "" & runiform() < 0.5
replace diag = "B1" if diag == ""
drop if diag == ""

treescan_power diag using `test_tree', id(id) exposed(exposed) ///
    target(A) rr(3) nsim(29) nsimpower(10) seed(42)

local t9a = (r(power) >= 0 & r(power) <= 1)
run_test "T9a: Internal node target works" `t9a'

local t9b = ("`r(target)'" == "A")
run_test "T9b: Internal target stored correctly" `t9b'

* =============================================================
* Create shared temporal test data
* =============================================================
clear
set obs 80
gen long id = _n
gen byte exposed = (_n <= 20)
gen str7 diag = ""
set seed 1000
replace diag = "A1" if exposed == 1 & runiform() < 0.7
replace diag = "B1" if diag == ""
drop if diag == ""
* Add date variables: exposed get events 5-25 days post-exposure
gen double expdt = 22000
gen double eventdt = expdt + 10 if exposed == 1
replace eventdt = expdt + 50 if exposed == 0 & runiform() < 0.5
replace eventdt = expdt + 15 if eventdt == .
tempfile temporal_power_data
save `temporal_power_data'

* =============================================================
* TEST 10: Basic temporal power execution
* =============================================================
use `temporal_power_data', clear

treescan_power diag using `test_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) eventdate(eventdt) expdate(expdt) ///
    window(0 30) nsim(29) nsimpower(10) seed(42)

local t10a = (r(power) >= 0 & r(power) <= 1)
run_test "T10a: Temporal power in [0, 1]" `t10a'

local t10b = (r(window_lo) == 0)
run_test "T10b: r(window_lo) = 0" `t10b'

local t10c = (r(window_hi) == 30)
run_test "T10c: r(window_hi) = 30" `t10c'

local t10d = ("`r(windowscope)'" == "exposed")
run_test "T10d: r(windowscope) = exposed (default)" `t10d'

* =============================================================
* TEST 11: windowscope(all)
* =============================================================
use `temporal_power_data', clear

treescan_power diag using `test_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) eventdate(eventdt) expdate(expdt) ///
    window(0 30) windowscope(all) nsim(29) nsimpower(10) seed(42)

local t11a = ("`r(windowscope)'" == "all")
run_test "T11a: windowscope(all) stored" `t11a'

local t11b = (r(power) >= 0 & r(power) <= 1)
run_test "T11b: windowscope(all) power valid" `t11b'

* =============================================================
* TEST 12: Partial temporal specification error
* =============================================================
use `temporal_power_data', clear

capture treescan_power diag using `test_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) eventdate(eventdt) window(0 30) ///
    nsim(29) nsimpower(10) seed(42)

local t12 = (_rc == 198)
run_test "T12: Error on partial temporal specification" `t12'

* =============================================================
* TEST 13: All events filtered out by window
* =============================================================
clear
set obs 40
gen long id = _n
gen byte exposed = (_n <= 10)
gen str7 diag = "A1" if exposed == 1
replace diag = "B1" if diag == ""
gen double expdt = 22000
gen double eventdt = expdt + 500

capture treescan_power diag using `test_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) eventdate(eventdt) expdate(expdt) ///
    window(0 30) nsim(19) nsimpower(5) seed(42)

local t13 = (_rc == 2000)
run_test "T13: Error when window filters all events" `t13'

* =============================================================
* TEST 14: Invalid windowscope
* =============================================================
use `temporal_power_data', clear

capture treescan_power diag using `test_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) eventdate(eventdt) expdate(expdt) ///
    window(0 30) windowscope(bogus) nsim(29) nsimpower(10) seed(42)

local t14 = (_rc == 198)
run_test "T14: Error on invalid windowscope" `t14'

* =============================================================
* TEST 15: Data preservation with temporal options
* =============================================================
use `temporal_power_data', clear
gen double extra = runiform()
local orig_N = _N

treescan_power diag using `test_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) eventdate(eventdt) expdate(expdt) ///
    window(0 30) nsim(29) nsimpower(10) seed(42)

local t15a = (_N == `orig_N')
run_test "T15a: Obs count preserved with temporal" `t15a'

capture confirm variable extra
local t15b = (_rc == 0)
run_test "T15b: Extra variable preserved with temporal" `t15b'

* =============================================================
* SUMMARY
* =============================================================
display as text ""
display as text _dup(60) "="
display as text "Test Results: " scalar(n_passed) "/" scalar(n_tests) " passed, " scalar(n_failed) " failed"
display as text _dup(60) "="

if scalar(n_failed) > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
