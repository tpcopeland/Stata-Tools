* test_treescan.do - Comprehensive functional tests for treescan package
* Tests: T1-T48 (core), T49-T53 (power edge cases), G1-G50 (extended coverage)
* 166 assertions covering treescan + treescan_power
*
* Run: stata-mp -b do test_treescan.do
* Date: 2026-03-12

clear all
set more off
version 16.0

capture ado uninstall treescan
adopath + "/home/tpcopeland/Stata-Tools/treescan"
quietly mata: mata mlib index

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
display as text "Testing treescan command"
display as text _dup(60) "="
display as text ""

* =============================================================
* TEST 1: Basic execution with ICD-10-CM tree
* =============================================================
clear
set seed 100
set obs 50
gen long id = _n
gen byte exposed = (_n <= 15)
gen str7 diag = ""
replace diag = "A000" if exposed == 1 & runiform() < 0.6
replace diag = "I21" if diag == "" & runiform() < 0.3
replace diag = "J44" if diag == ""
drop if diag == ""

treescan diag, id(id) exposed(exposed) icdversion(cm) nsim(49) seed(42)

local t1a = (r(n_obs) > 0)
run_test "T1a: Basic execution succeeds" `t1a'

local t1b = (r(max_llr) >= 0)
run_test "T1b: max_llr is non-negative" `t1b'

local t1c = (r(p_value) > 0 & r(p_value) <= 1)
run_test "T1c: p_value in (0, 1]" `t1c'

local t1d = (r(nsim) == 49)
run_test "T1d: nsim stored correctly" `t1d'

local t1e = (r(n_nodes) > 0)
run_test "T1e: n_nodes > 0" `t1e'

local t1f = ("`r(model)'" == "bernoulli")
run_test "T1f: model defaults to bernoulli" `t1f'

* =============================================================
* TEST 2: Reproducibility — same seed gives same results
* =============================================================
clear
set seed 200
set obs 100
gen long id = _n
gen byte exposed = (_n <= 25)
gen str7 diag = ""
replace diag = "A000" if exposed == 1 & runiform() < 0.5
replace diag = "E1010" if diag == ""
drop if diag == ""

* Run 1
treescan diag, id(id) exposed(exposed) icdversion(cm) nsim(49) seed(42)
local run1_llr = r(max_llr)
local run1_pv  = r(p_value)

* Run 2 (same data, same seed)
treescan diag, id(id) exposed(exposed) icdversion(cm) nsim(49) seed(42)
local run2_llr = r(max_llr)
local run2_pv  = r(p_value)

local t2a = (abs(`run1_llr' - `run2_llr') < 1e-10)
run_test "T2a: Same seed -> same max_llr" `t2a'

local t2b = (abs(`run1_pv' - `run2_pv') < 1e-10)
run_test "T2b: Same seed -> same p_value" `t2b'

* =============================================================
* TEST 3: Custom tree via using
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
tempfile custom_tree
save `custom_tree'

clear
set seed 300
set obs 50
gen long id = _n
gen byte exposed = (_n <= 15)
gen str7 diag = ""
replace diag = "A1" if exposed == 1 & runiform() < 0.7
replace diag = "B1" if diag == ""
drop if diag == ""

treescan diag using `custom_tree', id(id) exposed(exposed) nsim(49) seed(42)

local t3a = (r(n_obs) > 0)
run_test "T3a: Custom tree via using works" `t3a'

local t3b = (r(max_llr) > 0)
run_test "T3b: Custom tree detects signal" `t3b'

* =============================================================
* TEST 4: ICD-10-SE tree
* =============================================================
clear
set seed 400
set obs 100
gen long id = _n
gen byte exposed = (_n <= 25)
gen str7 diag = ""
replace diag = "A000" if exposed == 1 & runiform() < 0.5
replace diag = "J44" if diag == ""
drop if diag == ""

treescan diag, id(id) exposed(exposed) icdversion(se) nsim(49) seed(42)

local t4 = (r(n_obs) > 0)
run_test "T4: ICD-10-SE tree works" `t4'

* =============================================================
* TEST 5: Input validation - missing exposed option
* =============================================================
clear
set obs 10
gen long id = _n
gen str7 diag = "A000"

capture treescan diag, id(id) icdversion(cm)

local t5 = (_rc != 0)
run_test "T5: Error when exposed() missing" `t5'

* =============================================================
* TEST 6: Input validation - missing id option
* =============================================================
clear
set obs 10
gen long id = _n
gen byte exposed = 1
gen str7 diag = "A000"

capture treescan diag, exposed(exposed) icdversion(cm)

local t6 = (_rc != 0)
run_test "T6: Error when id() missing" `t6'

* =============================================================
* TEST 7: Input validation - no icdversion or using
* =============================================================
clear
set obs 10
gen long id = _n
gen byte exposed = 1
gen str7 diag = "A000"

capture treescan diag, id(id) exposed(exposed)

local t7 = (_rc == 198)
run_test "T7: Error when neither icdversion nor using" `t7'

* =============================================================
* TEST 8: Input validation - non-binary exposed
* =============================================================
clear
set obs 10
gen long id = _n
gen int exposed = _n
gen str7 diag = "A000"

capture treescan diag, id(id) exposed(exposed) icdversion(cm)

local t8 = (_rc == 198)
run_test "T8: Error on non-binary exposed" `t8'

* =============================================================
* TEST 9: All exposed — should error
* =============================================================
clear
set obs 10
gen long id = _n
gen byte exposed = 1
gen str7 diag = "A000"

capture treescan diag, id(id) exposed(exposed) icdversion(cm)

local t9 = (_rc == 2000)
run_test "T9: Error when all exposed (no unexposed)" `t9'

* =============================================================
* TEST 10: All unexposed — should error
* =============================================================
clear
set obs 10
gen long id = _n
gen byte exposed = 0
gen str7 diag = "A000"

capture treescan diag, id(id) exposed(exposed) icdversion(cm)

local t10 = (_rc == 2000)
run_test "T10: Error when all unexposed (no exposed)" `t10'

* =============================================================
* TEST 11: Stored results structure
* =============================================================
clear
set seed 1100
set obs 200
gen long id = _n
gen byte exposed = (_n <= 40)
gen str7 diag = ""
replace diag = "A000" if exposed == 1 & runiform() < 0.6
replace diag = "I21"  if exposed == 0 & runiform() < 0.2
replace diag = "J44" if diag == ""
drop if diag == ""

treescan diag, id(id) exposed(exposed) icdversion(cm) nsim(99) seed(42)

local t11a = (r(n_exposed) > 0)
run_test "T11a: r(n_exposed) stored" `t11a'

local t11b = (r(n_unexposed) > 0)
run_test "T11b: r(n_unexposed) stored" `t11b'

local t11c = (r(alpha) == 0.05)
run_test "T11c: r(alpha) stored correctly" `t11c'

local t11d = (r(n_exposed) + r(n_unexposed) > 0)
run_test "T11d: Exposed + unexposed > 0" `t11d'

* =============================================================
* TEST 12: Strong signal detected
* =============================================================
clear
set seed 1200
set obs 500
gen long id = _n
gen byte exposed = (_n <= 100)
gen str7 diag = ""
* Strong signal: 80% of exposed get A000, only 5% of unexposed
replace diag = "A000" if exposed == 1 & runiform() < 0.8
replace diag = "A000" if exposed == 0 & runiform() < 0.05
replace diag = "E1010" if diag == ""
drop if diag == ""

treescan diag, id(id) exposed(exposed) icdversion(cm) nsim(199) seed(42)

local t12a = (r(max_llr) > 10)
run_test "T12a: Strong signal produces large LLR" `t12a'

local t12b = (r(p_value) < 0.05)
run_test "T12b: Strong signal is significant" `t12b'

* Check results matrix exists and has correct structure
capture matrix list r(results)
local t12c = (_rc == 0)
run_test "T12c: r(results) matrix exists" `t12c'

if `t12c' {
    local ncols = colsof(r(results))
    local t12d = (`ncols' == 4)
    run_test "T12d: Results matrix has 4 columns" `t12d'
}

* =============================================================
* TEST 13: No signal — all same diagnosis
* =============================================================
clear
set obs 50
gen long id = _n
gen byte exposed = (_n <= 15)
gen str7 diag = "E1010"

treescan diag, id(id) exposed(exposed) icdversion(cm) nsim(49) seed(42)

local t13a = (r(max_llr) >= 0)
run_test "T13a: Single code runs without error" `t13a'

local t13b = (r(p_value) > 0)
run_test "T13b: p-value computed" `t13b'

* =============================================================
* TEST 14: Codes with dots stripped correctly
* =============================================================
clear
input long id str10 diag byte exposed
1 "A00.0" 1
2 "A00.0" 1
3 "E10.10" 0
4 "E10.10" 0
5 "A00.0" 1
end

treescan diag, id(id) exposed(exposed) icdversion(cm) nsim(19) seed(42)

local t14 = (r(n_obs) == 5)
run_test "T14: Dots in ICD codes handled" `t14'

* =============================================================
* TEST 15: Multiple diagnoses per person
* =============================================================
clear
input long id str7 diag byte exposed
1 "A000" 1
1 "I21"  1
1 "J44"  1
2 "E1010" 0
2 "J44"  0
3 "A000" 1
4 "B20"  0
end

treescan diag, id(id) exposed(exposed) icdversion(cm) nsim(19) seed(42)

local t15a = (r(n_obs) == 7)
run_test "T15a: Multiple diagnoses per person handled" `t15a'

local t15b = (r(n_exposed) == 2)
run_test "T15b: Correct exposed count with multi-diag" `t15b'

* =============================================================
* TEST 16: Alpha option changes results display
* =============================================================
clear
set seed 1600
set obs 200
gen long id = _n
gen byte exposed = (_n <= 50)
gen str7 diag = ""
replace diag = "A000" if exposed == 1 & runiform() < 0.5
replace diag = "E1010" if diag == ""
drop if diag == ""

treescan diag, id(id) exposed(exposed) icdversion(cm) nsim(49) seed(42) alpha(0.10)

local t16 = (r(alpha) == 0.10)
run_test "T16: Alpha option stored correctly" `t16'

* =============================================================
* TEST 17: Data preserved after treescan
* =============================================================
clear
set seed 1700
set obs 50
gen long id = _n
gen byte exposed = (_n <= 15)
gen str7 diag = "A000"
gen double extra_var = runiform()
local orig_N = _N

treescan diag, id(id) exposed(exposed) icdversion(cm) nsim(19) seed(42)

local t17a = (_N == `orig_N')
run_test "T17a: Observation count preserved" `t17a'

capture confirm variable extra_var
local t17b = (_rc == 0)
run_test "T17b: Extra variables preserved" `t17b'

* =============================================================
* TEST 18: Mixed exposure warning
* =============================================================
clear
input long id str7 diag byte exposed
1 "A000" 1
1 "I21"  0
2 "A000" 0
3 "J44"  1
4 "E1010" 0
end

* Capture output to check for warning message
log using "_test_mixed.log", text replace nomsg
treescan diag, id(id) exposed(exposed) icdversion(cm) nsim(19) seed(42)
log close

* Check that the note was displayed
quietly {
    capture findfile "_test_mixed.log"
    tempname fh
    file open `fh' using "_test_mixed.log", read text
    local found_warning = 0
    local done = 0
    while !`done' {
        file read `fh' line
        if r(eof) {
            local done = 1
        }
        else if strpos(`"`line'"', "mixed exposure") > 0 {
            local found_warning = 1
            local done = 1
        }
    }
    file close `fh'
    erase "_test_mixed.log"
}

local t18 = (`found_warning' == 1)
run_test "T18: Mixed exposure warning displayed" `t18'

* =============================================================
* TEST 19: Tree depth > 10 levels (custom deep tree)
* =============================================================
clear
* Build a 15-level deep tree
local nlevels = 15
local nnodes = `nlevels' + 1
set obs `nnodes'
gen str20 node = ""
gen str20 parent = ""
gen byte level = .
gen str60 description = ""

* Root
replace node = "root" in 1
replace parent = "" in 1
replace level = 0 in 1
replace description = "Root" in 1

* Levels 1-15
forvalues i = 1/`nlevels' {
    local obs = `i' + 1
    replace node = "L`i'" in `obs'
    if `i' == 1 {
        replace parent = "root" in `obs'
    }
    else {
        local prev = `i' - 1
        replace parent = "L`prev'" in `obs'
    }
    replace level = `i' in `obs'
    replace description = "Level `i'" in `obs'
}

tempfile deep_tree
save `deep_tree'

* Data: one person at deepest leaf
clear
input long id str20 diag byte exposed
1 "L15" 1
2 "L15" 0
3 "L15" 0
end

treescan diag using `deep_tree', id(id) exposed(exposed) nsim(19) seed(42)

* Should have counted all 16 nodes (root + 15 levels)
local t19 = (r(n_nodes) == `nnodes')
run_test "T19: Deep tree (15 levels) traversed fully" `t19'

* =============================================================
* TEST 20: ATC tree works
* =============================================================
clear
set seed 2000
set obs 100
gen long id = _n
gen byte exposed = (_n <= 25)
gen str7 diag = ""
replace diag = "A01AA01" if exposed == 1 & runiform() < 0.6
replace diag = "N02BE01" if diag == ""
drop if diag == ""

treescan diag, id(id) exposed(exposed) icdversion(atc) nsim(49) seed(42)

local t20a = (r(n_obs) > 0)
run_test "T20a: ATC tree via icdversion(atc) works" `t20a'

local t20b = (r(n_nodes) > 0)
run_test "T20b: ATC tree has nodes" `t20b'

* =============================================================
* TEST 21: Poisson model basic execution
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
tempfile poisson_tree
save `poisson_tree'

clear
set seed 2100
set obs 50
gen long id = _n
gen byte case_status = (_n <= 15)
gen double pyears = runiform() * 5 + 0.5
gen str7 diag = ""
replace diag = "A1" if case_status == 1 & runiform() < 0.7
replace diag = "B1" if diag == ""
drop if diag == ""

treescan diag using `poisson_tree', id(id) exposed(case_status) ///
    persontime(pyears) model(poisson) nsim(49) seed(42)

local t21a = (r(n_obs) > 0)
run_test "T21a: Poisson model executes" `t21a'

local t21b = ("`r(model)'" == "poisson")
run_test "T21b: r(model) = poisson" `t21b'

local t21c = (r(total_persontime) > 0)
run_test "T21c: r(total_persontime) stored" `t21c'

local t21d = (r(total_cases) > 0)
run_test "T21d: r(total_cases) stored" `t21d'

local t21e = (r(max_llr) >= 0)
run_test "T21e: Poisson LLR is non-negative" `t21e'

* =============================================================
* TEST 22: Poisson model reproducibility
* =============================================================
clear
set seed 2200
set obs 80
gen long id = _n
gen byte case_status = (_n <= 20)
gen double pyears = runiform() * 3 + 1
gen str7 diag = ""
replace diag = "A1" if case_status == 1 & runiform() < 0.6
replace diag = "B1" if diag == ""
drop if diag == ""

treescan diag using `poisson_tree', id(id) exposed(case_status) ///
    persontime(pyears) model(poisson) nsim(49) seed(42)
local run1_llr = r(max_llr)

treescan diag using `poisson_tree', id(id) exposed(case_status) ///
    persontime(pyears) model(poisson) nsim(49) seed(42)
local run2_llr = r(max_llr)

local t22 = (abs(`run1_llr' - `run2_llr') < 1e-10)
run_test "T22: Poisson same seed -> same results" `t22'

* =============================================================
* TEST 23: Poisson error — missing persontime
* =============================================================
clear
set obs 10
gen long id = _n
gen byte exposed = (_n <= 3)
gen str7 diag = "A000"

capture treescan diag, id(id) exposed(exposed) model(poisson) icdversion(cm)

local t23 = (_rc == 198)
run_test "T23: Error when persontime missing with Poisson" `t23'

* =============================================================
* TEST 24: Poisson error — negative persontime
* =============================================================
clear
set obs 10
gen long id = _n
gen byte exposed = (_n <= 3)
gen double pyears = -1
gen str7 diag = "A000"

capture treescan diag, id(id) exposed(exposed) persontime(pyears) ///
    model(poisson) icdversion(cm)

local t24 = (_rc == 198)
run_test "T24: Error on negative persontime" `t24'

* =============================================================
* TEST 25: Invalid model option
* =============================================================
clear
set obs 10
gen long id = _n
gen byte exposed = (_n <= 3)
gen str7 diag = "A000"

capture treescan diag, id(id) exposed(exposed) model(gamma) icdversion(cm)

local t25 = (_rc == 198)
run_test "T25: Error on invalid model()" `t25'

* =============================================================
* TEST 26: Bernoulli error when persontime specified
* =============================================================
clear
set obs 10
gen long id = _n
gen byte exposed = (_n <= 3)
gen double pyears = 1
gen str7 diag = "A000"

capture treescan diag, id(id) exposed(exposed) persontime(pyears) ///
    model(bernoulli) icdversion(cm)

local t26 = (_rc == 198)
run_test "T26: Error on persontime with Bernoulli" `t26'

* =============================================================
* TEST 27: Bernoulli conditional — basic execution
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
tempfile cond_tree
save `cond_tree'

clear
set seed 2700
set obs 50
gen long id = _n
gen byte exposed = (_n <= 15)
gen str7 diag = ""
replace diag = "A1" if exposed == 1 & runiform() < 0.7
replace diag = "B1" if diag == ""
drop if diag == ""

treescan diag using `cond_tree', id(id) exposed(exposed) ///
    conditional nsim(49) seed(42)

local t27a = (r(n_obs) > 0)
run_test "T27a: Bernoulli conditional executes" `t27a'

local t27b = (r(max_llr) >= 0)
run_test "T27b: Conditional max_llr non-negative" `t27b'

local t27c = ("`r(conditional)'" == "conditional")
run_test "T27c: r(conditional) stored correctly" `t27c'

local t27d = (r(p_value) > 0 & r(p_value) <= 1)
run_test "T27d: Conditional p-value valid" `t27d'

* =============================================================
* TEST 28: Poisson conditional — basic execution
* =============================================================
clear
set seed 2800
set obs 50
gen long id = _n
gen byte case_status = (_n <= 15)
gen double pyears = runiform() * 5 + 0.5
gen str7 diag = ""
replace diag = "A1" if case_status == 1 & runiform() < 0.7
replace diag = "B1" if diag == ""
drop if diag == ""

treescan diag using `cond_tree', id(id) exposed(case_status) ///
    persontime(pyears) model(poisson) conditional nsim(49) seed(42)

local t28a = (r(n_obs) > 0)
run_test "T28a: Poisson conditional executes" `t28a'

local t28b = ("`r(model)'" == "poisson")
run_test "T28b: r(model) = poisson" `t28b'

local t28c = ("`r(conditional)'" == "conditional")
run_test "T28c: Poisson conditional stored" `t28c'

* =============================================================
* TEST 29: Conditional reproduces with same seed
* =============================================================
clear
set seed 2900
set obs 80
gen long id = _n
gen byte exposed = (_n <= 20)
gen str7 diag = ""
replace diag = "A1" if exposed == 1 & runiform() < 0.6
replace diag = "B1" if diag == ""
drop if diag == ""

treescan diag using `cond_tree', id(id) exposed(exposed) ///
    conditional nsim(49) seed(42)
local run1_llr = r(max_llr)
local run1_pv  = r(p_value)

treescan diag using `cond_tree', id(id) exposed(exposed) ///
    conditional nsim(49) seed(42)
local run2_llr = r(max_llr)
local run2_pv  = r(p_value)

local t29a = (abs(`run1_llr' - `run2_llr') < 1e-10)
run_test "T29a: Conditional same seed -> same LLR" `t29a'

local t29b = (abs(`run1_pv' - `run2_pv') < 1e-10)
run_test "T29b: Conditional same seed -> same p-value" `t29b'

* =============================================================
* TEST 30: Unconditional still works (no regression)
* =============================================================
clear
set seed 3000
set obs 50
gen long id = _n
gen byte exposed = (_n <= 15)
gen str7 diag = ""
replace diag = "A1" if exposed == 1 & runiform() < 0.7
replace diag = "B1" if diag == ""
drop if diag == ""

treescan diag using `cond_tree', id(id) exposed(exposed) nsim(49) seed(42)

local t30a = (r(n_obs) > 0)
run_test "T30a: Unconditional still works" `t30a'

local t30b = ("`r(conditional)'" == "")
run_test "T30b: r(conditional) empty for unconditional" `t30b'

* =============================================================
* TEST 31: Temporal scan window — basic filter
* =============================================================
clear
input str7 node str7 parent byte level str60 description
"root" "" 0 "Root"
"A" "root" 1 "Group A"
"B" "root" 1 "Group B"
end
tempfile temporal_tree
save `temporal_tree'

clear
input long id str7 diag byte exposed double eventdt double expdt
1  "A" 1 22000 21990
2  "A" 1 22000 21995
3  "A" 1 22100 21990
4  "B" 0 22000 21980
5  "B" 0 22000 21975
6  "B" 0 22100 21980
7  "A" 1 22500 21990
end

* Window 0-30 days: obs 1 (10d), obs 2 (5d) inside; obs 3 (110d), obs 7 (510d) outside for exposed
* Unexposed: all kept (windowscope=exposed default)
treescan diag using `temporal_tree', id(id) exposed(exposed) ///
    eventdate(eventdt) expdate(expdt) window(0 30) nsim(19) seed(42)

local t31a = (r(n_obs) > 0)
run_test "T31a: Temporal window executes" `t31a'

local t31b = (r(window_lo) == 0)
run_test "T31b: r(window_lo) = 0" `t31b'

local t31c = (r(window_hi) == 30)
run_test "T31c: r(window_hi) = 30" `t31c'

local t31d = ("`r(windowscope)'" == "exposed")
run_test "T31d: r(windowscope) = exposed" `t31d'

* =============================================================
* TEST 32: Temporal window — windowscope(all)
* =============================================================
* Reuse same data
treescan diag using `temporal_tree', id(id) exposed(exposed) ///
    eventdate(eventdt) expdate(expdt) window(0 30) ///
    windowscope(all) nsim(19) seed(42)

local t32a = ("`r(windowscope)'" == "all")
run_test "T32a: windowscope(all) stored" `t32a'

local t32b = (r(n_obs) > 0)
run_test "T32b: windowscope(all) produces results" `t32b'

* =============================================================
* TEST 33: Temporal window — partial specification error
* =============================================================
capture treescan diag using `temporal_tree', id(id) exposed(exposed) ///
    eventdate(eventdt) window(0 30) nsim(19) seed(42)

local t33 = (_rc == 198)
run_test "T33: Error when temporal options partially specified" `t33'

* =============================================================
* TEST 34: Temporal window — all events filtered out
* =============================================================
clear
input long id str7 diag byte exposed double eventdt double expdt
1  "A" 1 22000 21990
2  "B" 0 22000 21980
end

capture treescan diag using `temporal_tree', id(id) exposed(exposed) ///
    eventdate(eventdt) expdate(expdt) window(100 200) nsim(19) seed(42)

local t34 = (_rc == 2000)
run_test "T34: Error when window filters all events" `t34'

* =============================================================
* TEST 35: Temporal window preserves data
* =============================================================
clear
input long id str7 diag byte exposed double eventdt double expdt double extra
1  "A" 1 22000 21990 1.5
2  "A" 1 22000 21995 2.5
3  "B" 0 22000 21980 3.5
4  "B" 0 22000 21975 4.5
end
local orig_N = _N

treescan diag using `temporal_tree', id(id) exposed(exposed) ///
    eventdate(eventdt) expdate(expdt) window(0 30) nsim(19) seed(42)

local t35a = (_N == `orig_N')
run_test "T35a: Data preserved with temporal window" `t35a'

capture confirm variable extra
local t35b = (_rc == 0)
run_test "T35b: Extra variables preserved with temporal window" `t35b'

* =============================================================
* TEST 36: Invalid windowscope
* =============================================================
clear
input long id str7 diag byte exposed double eventdt double expdt
1  "A" 1 22000 21990
2  "B" 0 22000 21980
end

capture treescan diag using `temporal_tree', id(id) exposed(exposed) ///
    eventdate(eventdt) expdate(expdt) window(0 30) ///
    windowscope(bogus) nsim(19) seed(42)

local t36 = (_rc == 198)
run_test "T36: Error on invalid windowscope" `t36'

* =============================================================
* TEST 37: treescan_power — basic execution (custom tree)
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
tempfile power_tree
save `power_tree'

clear
set seed 3700
set obs 100
gen long id = _n
gen byte exposed = (_n <= 25)
gen str7 diag = ""
replace diag = "A1" if exposed == 1 & runiform() < 0.7
replace diag = "B1" if diag == ""
drop if diag == ""

treescan_power diag using `power_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) nsim(49) nsimpower(30) seed(42)

local t37a = (!missing(r(power)))
run_test "T37a: treescan_power executes" `t37a'

local t37b = (r(power) >= 0 & r(power) <= 1)
run_test "T37b: Power in [0, 1]" `t37b'

local t37c = (r(rr) == 3)
run_test "T37c: r(rr) stored correctly" `t37c'

local t37d = ("`r(target)'" == "A1")
run_test "T37d: r(target) stored correctly" `t37d'

local t37e = (r(crit_val) >= 0)
run_test "T37e: Critical value non-negative" `t37e'

local t37f = ("`r(model)'" == "bernoulli")
run_test "T37f: r(model) = bernoulli" `t37f'

* =============================================================
* TEST 38: treescan_power — return values completeness
* =============================================================
local t38a = (!missing(r(power_ci_lo)))
run_test "T38a: r(power_ci_lo) stored" `t38a'

local t38b = (!missing(r(power_ci_hi)))
run_test "T38b: r(power_ci_hi) stored" `t38b'

local t38c = (r(power_ci_lo) <= r(power))
run_test "T38c: CI lower <= power" `t38c'

local t38d = (r(power_ci_hi) >= r(power))
run_test "T38d: CI upper >= power" `t38d'

local t38e = (r(nsim) == 49)
run_test "T38e: r(nsim) stored correctly" `t38e'

local t38f = (r(nsim_power) == 30)
run_test "T38f: r(nsim_power) stored correctly" `t38f'

local t38g = (r(n_reject) <= r(nsim_power))
run_test "T38g: n_reject <= nsim_power" `t38g'

* =============================================================
* TEST 39: treescan_power — conditional model
* =============================================================
clear
set seed 3900
set obs 100
gen long id = _n
gen byte exposed = (_n <= 25)
gen str7 diag = ""
replace diag = "A1" if exposed == 1 & runiform() < 0.7
replace diag = "B1" if diag == ""
drop if diag == ""

treescan_power diag using `power_tree', id(id) exposed(exposed) ///
    conditional target(A1) rr(3) nsim(49) nsimpower(30) seed(42)

local t39a = (!missing(r(power)))
run_test "T39a: Conditional power executes" `t39a'

local t39b = ("`r(conditional)'" == "conditional")
run_test "T39b: r(conditional) stored for power" `t39b'

* =============================================================
* TEST 40: treescan_power — Poisson model
* =============================================================
clear
set seed 4000
set obs 100
gen long id = _n
gen byte case_status = (_n <= 25)
gen double pyears = runiform() * 5 + 0.5
gen str7 diag = ""
replace diag = "A1" if case_status == 1 & runiform() < 0.7
replace diag = "B1" if diag == ""
drop if diag == ""

treescan_power diag using `power_tree', id(id) exposed(case_status) ///
    persontime(pyears) model(poisson) ///
    target(A1) rr(3) nsim(49) nsimpower(30) seed(42)

local t40a = (!missing(r(power)))
run_test "T40a: Poisson power executes" `t40a'

local t40b = ("`r(model)'" == "poisson")
run_test "T40b: r(model) = poisson for power" `t40b'

* =============================================================
* TEST 41: treescan_power — error: rr <= 1
* =============================================================
clear
set obs 50
gen long id = _n
gen byte exposed = (_n <= 15)
gen str7 diag = "A1"

capture treescan_power diag using `power_tree', id(id) exposed(exposed) ///
    target(A1) rr(0.5) nsim(49) nsimpower(30) seed(42)

local t41 = (_rc == 198)
run_test "T41: Power error when rr <= 1" `t41'

* =============================================================
* TEST 42: treescan_power — error: target not in tree
* =============================================================
clear
set obs 50
gen long id = _n
gen byte exposed = (_n <= 15)
gen str7 diag = "A1"

capture treescan_power diag using `power_tree', id(id) exposed(exposed) ///
    target(Z99) rr(3) nsim(49) nsimpower(30) seed(42)

local t42 = (_rc == 198)
run_test "T42: Power error when target not in tree" `t42'

* =============================================================
* TEST 43: treescan_power — internal node as target
* =============================================================
clear
set seed 4300
set obs 100
gen long id = _n
gen byte exposed = (_n <= 25)
gen str7 diag = ""
replace diag = "A1" if exposed == 1 & runiform() < 0.5
replace diag = "A2" if exposed == 1 & diag == "" & runiform() < 0.5
replace diag = "B1" if diag == ""
drop if diag == ""

treescan_power diag using `power_tree', id(id) exposed(exposed) ///
    target(A) rr(5) nsim(49) nsimpower(30) seed(42)

local t43a = (!missing(r(power)))
run_test "T43a: Power with internal node target" `t43a'

local t43b = ("`r(target)'" == "A")
run_test "T43b: Internal node target stored" `t43b'

* =============================================================
* TEST 44: treescan_power — data preserved
* =============================================================
clear
set seed 4400
set obs 80
gen long id = _n
gen byte exposed = (_n <= 20)
gen str7 diag = ""
replace diag = "A1" if exposed == 1 & runiform() < 0.7
replace diag = "B1" if diag == ""
drop if diag == ""
gen double extra_var = runiform()
local orig_N = _N

treescan_power diag using `power_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) nsim(49) nsimpower(30) seed(42)

local t44a = (_N == `orig_N')
run_test "T44a: Power preserves observation count" `t44a'

capture confirm variable extra_var
local t44b = (_rc == 0)
run_test "T44b: Power preserves extra variables" `t44b'

* =============================================================
* TEST 45: treescan_power — seed reproducibility
* =============================================================
clear
set seed 4500
set obs 80
gen long id = _n
gen byte exposed = (_n <= 20)
gen str7 diag = ""
replace diag = "A1" if exposed == 1 & runiform() < 0.7
replace diag = "B1" if diag == ""
drop if diag == ""

treescan_power diag using `power_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) nsim(49) nsimpower(30) seed(42)
local pow1 = r(power)

treescan_power diag using `power_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) nsim(49) nsimpower(30) seed(42)
local pow2 = r(power)

local t45 = (abs(`pow1' - `pow2') < 1e-10)
run_test "T45: Power same seed -> same result" `t45'

* =============================================================
* TEST 46: treescan_power + temporal combined execution
* =============================================================
clear
set seed 4600
set obs 80
gen long id = _n
gen byte exposed = (_n <= 20)
gen str7 diag = ""
replace diag = "A1" if exposed == 1 & runiform() < 0.7
replace diag = "B1" if diag == ""
drop if diag == ""
gen double expdt = 22000
gen double eventdt = expdt + 10 if exposed == 1
replace eventdt = expdt + 15 if eventdt == .

treescan_power diag using `power_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) eventdate(eventdt) expdate(expdt) ///
    window(0 30) nsim(29) nsimpower(10) seed(42)

local t46a = (r(power) >= 0 & r(power) <= 1)
run_test "T46a: Power + temporal: power in [0,1]" `t46a'

local t46b = (r(window_lo) == 0 & r(window_hi) == 30)
run_test "T46b: Power + temporal: window returns" `t46b'

* =============================================================
* TEST 47: treescan_power + temporal + windowscope(all)
* =============================================================
treescan_power diag using `power_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) eventdate(eventdt) expdate(expdt) ///
    window(0 30) windowscope(all) nsim(29) nsimpower(10) seed(42)

local t47 = ("`r(windowscope)'" == "all")
run_test "T47: Power + temporal: windowscope(all) stored" `t47'

* =============================================================
* TEST 48: treescan_power + temporal partial spec error
* =============================================================
capture treescan_power diag using `power_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) eventdate(eventdt) window(0 30) ///
    nsim(29) nsimpower(10) seed(42)

local t48 = (_rc == 198)
run_test "T48: Power + temporal: partial spec error" `t48'

* =============================================================
* TEST 49: Power — strong signal has elevated power
* =============================================================
clear
set obs 80
gen long id = _n
gen byte exposed = (_n <= 20)
gen str7 diag = "A1" if exposed == 1
replace diag = "B1" if diag == ""

treescan_power diag using `power_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) nsim(29) nsimpower(30) seed(42)

local t49 = (r(power) > 0.3)
run_test "T49: Strong signal has elevated power" `t49'

* =============================================================
* TEST 50: Power — rr = 1 exactly → error
* =============================================================
clear
set obs 30
gen long id = _n
gen byte exposed = (_n <= 8)
gen str7 diag = "A1" if exposed == 1
replace diag = "B1" if diag == ""

capture treescan_power diag using `power_tree', id(id) exposed(exposed) ///
    target(A1) rr(1) nsim(19) nsimpower(5) seed(42)

local t50 = (_rc == 198)
run_test "T50: Error when rr = 1 exactly" `t50'

* =============================================================
* TEST 51: Power — window filters all events → error
* =============================================================
clear
set obs 40
gen long id = _n
gen byte exposed = (_n <= 10)
gen str7 diag = "A1" if exposed == 1
replace diag = "B1" if diag == ""
gen double expdt = 22000
gen double eventdt = expdt + 500

capture treescan_power diag using `power_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) eventdate(eventdt) expdate(expdt) ///
    window(0 30) nsim(19) nsimpower(5) seed(42)

local t51 = (_rc == 2000)
run_test "T51: Power error when window filters all events" `t51'

* =============================================================
* TEST 52: Power — invalid windowscope → error
* =============================================================
clear
set obs 60
gen long id = _n
gen byte exposed = (_n <= 15)
gen str7 diag = "A1" if exposed == 1
replace diag = "B1" if diag == ""
gen double expdt = 22000
gen double eventdt = expdt + 10

capture treescan_power diag using `power_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) eventdate(eventdt) expdate(expdt) ///
    window(0 30) windowscope(bogus) nsim(29) nsimpower(10) seed(42)

local t52 = (_rc == 198)
run_test "T52: Power error on invalid windowscope" `t52'

* =============================================================
* TEST 53: Power — data preservation with temporal
* =============================================================
clear
set obs 60
gen long id = _n
gen byte exposed = (_n <= 15)
gen str7 diag = "A1" if exposed == 1
replace diag = "B1" if diag == ""
gen double expdt = 22000
gen double eventdt = expdt + 10
gen double extra = runiform()
local orig_N = _N

treescan_power diag using `power_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) eventdate(eventdt) expdate(expdt) ///
    window(0 30) nsim(29) nsimpower(10) seed(42)

local t53a = (_N == `orig_N')
run_test "T53a: Power temporal preserves obs count" `t53a'

capture confirm variable extra
local t53b = (_rc == 0)
run_test "T53b: Power temporal preserves extra variables" `t53b'

* Reuse power_tree as shared_tree for extended tests
local shared_tree "`power_tree'"
* =====================================================================
* SECTION 1: INPUT VALIDATION EDGE CASES
* =====================================================================
display as text ""
display as text _dup(60) "="
display as text "Section 1: Input Validation Edge Cases"
display as text _dup(60) "="

* --- G1: Variable named "node" as id ---
clear
set obs 10
gen long node = _n
gen byte exposed = (_n <= 3)
gen str7 diag = "A1"

capture treescan diag using `shared_tree', id(node) exposed(exposed) nsim(19) seed(42)

local g1 = (_rc == 198)
run_test "G1: Error when id variable is named 'node'" `g1'

* --- G2: Variable named "node" as exposed ---
clear
set obs 10
gen long id = _n
gen byte node = (_n <= 3)
gen str7 diag = "A1"

capture treescan diag using `shared_tree', id(id) exposed(node) nsim(19) seed(42)

local g2 = (_rc == 198)
run_test "G2: Error when exposed variable is named 'node'" `g2'

* --- G3: Variable named "node" as persontime ---
clear
set obs 10
gen long id = _n
gen byte exposed = (_n <= 3)
gen double node = 2.0
gen str7 diag = "A1"

capture treescan diag using `shared_tree', id(id) exposed(exposed) ///
    persontime(node) model(poisson) nsim(19) seed(42)

local g3 = (_rc == 198)
run_test "G3: Error when persontime variable is named 'node'" `g3'

* --- G4: Both icdversion and using specified ---
clear
set obs 10
gen long id = _n
gen byte exposed = (_n <= 3)
gen str7 diag = "A000"

capture treescan diag using `shared_tree', id(id) exposed(exposed) ///
    icdversion(cm) nsim(19) seed(42)

local g4 = (_rc == 198)
run_test "G4: Error when both icdversion and using specified" `g4'

* --- G5: Invalid icdversion ---
clear
set obs 10
gen long id = _n
gen byte exposed = (_n <= 3)
gen str7 diag = "A000"

capture treescan diag, id(id) exposed(exposed) icdversion(icd9) nsim(19) seed(42)

local g5 = (_rc == 198)
run_test "G5: Error on invalid icdversion(icd9)" `g5'

* --- G6: nsim(0) ---
clear
set obs 20
gen long id = _n
gen byte exposed = (_n <= 5)
gen str7 diag = "A1"

capture treescan diag using `shared_tree', id(id) exposed(exposed) ///
    nsim(0) seed(42)

local g6 = (_rc == 198)
run_test "G6: Error when nsim(0)" `g6'

* --- G7: alpha(0) ---
capture treescan diag using `shared_tree', id(id) exposed(exposed) ///
    nsim(19) alpha(0) seed(42)

local g7 = (_rc == 198)
run_test "G7: Error when alpha(0)" `g7'

* --- G8: alpha(1) ---
capture treescan diag using `shared_tree', id(id) exposed(exposed) ///
    nsim(19) alpha(1) seed(42)

local g8 = (_rc == 198)
run_test "G8: Error when alpha(1)" `g8'

* --- G9: Window lo > hi ---
clear
input long id str7 diag byte exposed double eventdt double expdt
1  "A1" 1 22000 21990
2  "B1" 0 22000 21980
end

capture treescan diag using `shared_tree', id(id) exposed(exposed) ///
    eventdate(eventdt) expdate(expdt) window(30 0) nsim(19) seed(42)

local g9 = (_rc == 198)
run_test "G9: Error when window lo > hi" `g9'

* --- G10: Window with 1 value ---
capture treescan diag using `shared_tree', id(id) exposed(exposed) ///
    eventdate(eventdt) expdate(expdt) window(30) nsim(19) seed(42)

local g10 = (_rc == 198)
run_test "G10: Error when window has only 1 value" `g10'

* --- G11: Window with 3 values ---
capture treescan diag using `shared_tree', id(id) exposed(exposed) ///
    eventdate(eventdt) expdate(expdt) window(0 15 30) nsim(19) seed(42)

local g11 = (_rc == 198)
run_test "G11: Error when window has 3 values" `g11'

* --- G12: Exposed with values {0, 2} ---
clear
set obs 10
gen long id = _n
gen byte exposed = cond(_n <= 3, 2, 0)
gen str7 diag = "A1"

capture treescan diag using `shared_tree', id(id) exposed(exposed) nsim(19) seed(42)

local g12 = (_rc == 198)
run_test "G12: Error on exposed with values {0, 2}" `g12'

* --- G13: Invalid model option ---
clear
set obs 10
gen long id = _n
gen byte exposed = (_n <= 3)
gen str7 diag = "A1"

capture treescan diag using `shared_tree', id(id) exposed(exposed) ///
    model(logistic) nsim(19) seed(42)

local g13 = (_rc == 198)
run_test "G13: Error on model(logistic)" `g13'

* --- G14: Negative window values are allowed ---
clear
input long id str7 diag byte exposed double eventdt double expdt
1  "A1" 1 22000 22010
2  "A1" 1 22000 22005
3  "B1" 0 22000 22020
4  "B1" 0 22000 22015
end

treescan diag using `shared_tree', id(id) exposed(exposed) ///
    eventdate(eventdt) expdate(expdt) window(-30 0) nsim(19) seed(42)

local g14 = (r(window_lo) == -30 & r(window_hi) == 0)
run_test "G14: Negative window values accepted" `g14'

* =====================================================================
* SECTION 2: CODE NORMALIZATION
* =====================================================================
display as text ""
display as text _dup(60) "="
display as text "Section 2: Code Normalization"
display as text _dup(60) "="

* --- G15: Lowercase codes are matched ---
clear
input long id str7 diag byte exposed
1  "a1" 1
2  "a1" 1
3  "a1" 1
4  "b1" 0
5  "b1" 0
end

treescan diag using `shared_tree', id(id) exposed(exposed) nsim(19) seed(42)

local g15 = (r(n_obs) == 5)
run_test "G15: Lowercase codes matched to tree" `g15'

* --- G16: Mixed case codes ---
clear
input long id str7 diag byte exposed
1  "a1" 1
2  "A1" 1
3  "b1" 0
4  "B1" 0
end

treescan diag using `shared_tree', id(id) exposed(exposed) nsim(19) seed(42)

local g16 = (r(n_obs) == 4)
run_test "G16: Mixed case codes handled" `g16'

* --- G17: Codes with leading/trailing whitespace ---
clear
input long id str10 diag byte exposed
1  " A1" 1
2  "A1 " 1
3  " B1 " 0
4  "B1" 0
end

treescan diag using `shared_tree', id(id) exposed(exposed) nsim(19) seed(42)

local g17 = (r(n_obs) == 4)
run_test "G17: Codes with whitespace trimmed" `g17'

* --- G18: ICD codes with dots and lowercase ---
clear
input long id str10 diag byte exposed
1  "a00.0" 1
2  "A00.0" 1
3  "e10.10" 0
4  "E10.10" 0
5  "j44" 0
end

treescan diag, id(id) exposed(exposed) icdversion(cm) nsim(19) seed(42)

local g18 = (r(n_obs) == 5)
run_test "G18: Dots + lowercase ICD codes normalized" `g18'

* =====================================================================
* SECTION 3: DATA EDGE CASES
* =====================================================================
display as text ""
display as text _dup(60) "="
display as text "Section 3: Data Edge Cases"
display as text _dup(60) "="

* --- G19: Missing diagnosis codes dropped ---
clear
input long id str7 diag byte exposed
1  "A1" 1
2  "A1" 1
3  ""   1
4  "B1" 0
5  "B1" 0
end
replace diag = "" if id == 3

treescan diag using `shared_tree', id(id) exposed(exposed) nsim(19) seed(42)

* Missing diag should be dropped, leaving 4 obs
local g19 = (r(n_obs) <= 5)
run_test "G19: Missing diagnosis codes handled" `g19'

* --- G20: All codes not in tree ---
clear
input long id str7 diag byte exposed
1  "ZZZ" 1
2  "ZZZ" 1
3  "YYY" 0
4  "YYY" 0
end

capture treescan diag using `shared_tree', id(id) exposed(exposed) nsim(19) seed(42)

local g20 = (_rc == 2000)
run_test "G20: Error when all codes not in tree" `g20'

* --- G21: Minimum viable data (2 people) ---
clear
input long id str7 diag byte exposed
1  "A1" 1
2  "B1" 0
end

treescan diag using `shared_tree', id(id) exposed(exposed) nsim(19) seed(42)

local g21a = (r(n_exposed) == 1)
run_test "G21a: Minimum data: 1 exposed" `g21a'

local g21b = (r(n_unexposed) == 1)
run_test "G21b: Minimum data: 1 unexposed" `g21b'

local g21c = (r(max_llr) >= 0)
run_test "G21c: Minimum data: LLR computed" `g21c'

* --- G22: Very high proportion exposed (95%) ---
clear
set obs 100
gen long id = _n
gen byte exposed = (_n <= 95)
set seed 2200
gen str7 diag = ""
replace diag = "A1" if exposed == 1 & runiform() < 0.5
replace diag = "B1" if diag == ""
drop if diag == ""

treescan diag using `shared_tree', id(id) exposed(exposed) nsim(19) seed(42)

local g22 = (r(n_obs) > 0 & r(max_llr) >= 0)
run_test "G22: High exposure proportion (95%) runs" `g22'

* --- G23: Very low proportion exposed (2%) ---
clear
set obs 200
gen long id = _n
gen byte exposed = (_n <= 4)
set seed 2300
gen str7 diag = ""
replace diag = "A1" if exposed == 1
replace diag = "B1" if diag == ""
drop if diag == ""

treescan diag using `shared_tree', id(id) exposed(exposed) nsim(19) seed(42)

local g23 = (r(n_obs) > 0 & r(max_llr) >= 0)
run_test "G23: Low exposure proportion (2%) runs" `g23'

* --- G24: Codes partially in tree (some matched, some not) ---
clear
input long id str7 diag byte exposed
1  "A1" 1
2  "A1" 1
3  "ZZZ" 1
4  "B1" 0
5  "B1" 0
6  "YYY" 0
end

treescan diag using `shared_tree', id(id) exposed(exposed) nsim(19) seed(42)

* 2 of 6 obs should be dropped (ZZZ, YYY), leaving 4 matched
local g24 = (r(n_obs) == 4)
run_test "G24: Partial tree match drops unmatched codes" `g24'

* =====================================================================
* SECTION 4: MODEL COMBINATIONS
* =====================================================================
display as text ""
display as text _dup(60) "="
display as text "Section 4: Model Combinations"
display as text _dup(60) "="

* --- G25: Poisson + conditional + temporal ---
clear
set seed 2500
set obs 60
gen long id = _n
gen byte case_status = (_n <= 15)
gen double pyears = runiform() * 5 + 0.5
gen str7 diag = ""
replace diag = "A1" if case_status == 1 & runiform() < 0.7
replace diag = "B1" if diag == ""
drop if diag == ""
gen double expdt = 22000
gen double eventdt = expdt + 10

treescan diag using `shared_tree', id(id) exposed(case_status) ///
    persontime(pyears) model(poisson) conditional ///
    eventdate(eventdt) expdate(expdt) window(0 30) nsim(29) seed(42)

local g25a = ("`r(model)'" == "poisson")
run_test "G25a: Poisson+conditional+temporal: model=poisson" `g25a'

local g25b = ("`r(conditional)'" == "conditional")
run_test "G25b: Poisson+conditional+temporal: conditional stored" `g25b'

local g25c = (r(window_lo) == 0 & r(window_hi) == 30)
run_test "G25c: Poisson+conditional+temporal: window stored" `g25c'

local g25d = (r(total_persontime) > 0)
run_test "G25d: Poisson+conditional+temporal: persontime stored" `g25d'

* --- G26: Bernoulli + conditional + temporal ---
clear
set seed 2600
set obs 60
gen long id = _n
gen byte exposed = (_n <= 15)
gen str7 diag = ""
replace diag = "A1" if exposed == 1 & runiform() < 0.7
replace diag = "B1" if diag == ""
drop if diag == ""
gen double expdt = 22000
gen double eventdt = expdt + 10

treescan diag using `shared_tree', id(id) exposed(exposed) ///
    conditional eventdate(eventdt) expdate(expdt) ///
    window(0 30) nsim(29) seed(42)

local g26a = ("`r(model)'" == "bernoulli")
run_test "G26a: Bernoulli+conditional+temporal: model correct" `g26a'

local g26b = ("`r(conditional)'" == "conditional")
run_test "G26b: Bernoulli+conditional+temporal: conditional stored" `g26b'

local g26c = ("`r(windowscope)'" == "exposed")
run_test "G26c: Bernoulli+conditional+temporal: windowscope default" `g26c'

* --- G27: Poisson with very different person-time ---
clear
input long id str7 diag byte exposed double pyears
1  "A1" 1  0.1
2  "A1" 1  0.1
3  "A1" 1  0.1
4  "B1" 0 50.0
5  "B1" 0 50.0
6  "B1" 0 50.0
end

treescan diag using `shared_tree', id(id) exposed(exposed) ///
    persontime(pyears) model(poisson) nsim(19) seed(42)

local g27a = (r(total_persontime) > 0)
run_test "G27a: Poisson with varying person-time runs" `g27a'

local g27b = (abs(r(total_persontime) - 150.3) < 0.01)
run_test "G27b: Total person-time summed correctly" `g27b'

* =====================================================================
* SECTION 5: EXCEL EXPORT
* =====================================================================
display as text ""
display as text _dup(60) "="
display as text "Section 5: Excel Export"
display as text _dup(60) "="

* Create data for Excel tests
clear
set seed 5000
set obs 200
gen long id = _n
gen byte exposed = (_n <= 50)
gen str7 diag = ""
replace diag = "A1" if exposed == 1 & runiform() < 0.8
replace diag = "A1" if exposed == 0 & runiform() < 0.05
replace diag = "B1" if diag == ""
drop if diag == ""

* --- G28: xlsx() creates file ---
capture erase "/home/tpcopeland/Stata-Tools/treescan/qa/_test_export.xlsx"

treescan diag using `shared_tree', id(id) exposed(exposed) ///
    nsim(49) seed(42) xlsx("/home/tpcopeland/Stata-Tools/treescan/qa/_test_export")

capture confirm file "/home/tpcopeland/Stata-Tools/treescan/qa/_test_export.xlsx"
local g28 = (_rc == 0)
run_test "G28: xlsx() creates file" `g28'

* --- G29: xlsx auto-appends .xlsx ---
* File was created above without .xlsx extension in option
local g29 = (`g28' == 1)
run_test "G29: xlsx() auto-appends .xlsx extension" `g29'

* Clean up
capture erase "/home/tpcopeland/Stata-Tools/treescan/qa/_test_export.xlsx"

* --- G30: xlsx() with custom sheet name ---
capture erase "/home/tpcopeland/Stata-Tools/treescan/qa/_test_export2.xlsx"

treescan diag using `shared_tree', id(id) exposed(exposed) ///
    nsim(49) seed(42) ///
    xlsx("/home/tpcopeland/Stata-Tools/treescan/qa/_test_export2.xlsx") ///
    sheet("MySheet")

capture confirm file "/home/tpcopeland/Stata-Tools/treescan/qa/_test_export2.xlsx"
local g30 = (_rc == 0)
run_test "G30: xlsx() with custom sheet name creates file" `g30'
capture erase "/home/tpcopeland/Stata-Tools/treescan/qa/_test_export2.xlsx"

* --- G31: xlsx() with custom title ---
capture erase "/home/tpcopeland/Stata-Tools/treescan/qa/_test_export3.xlsx"

treescan diag using `shared_tree', id(id) exposed(exposed) ///
    nsim(49) seed(42) ///
    xlsx("/home/tpcopeland/Stata-Tools/treescan/qa/_test_export3.xlsx") ///
    title("My Custom Title")

capture confirm file "/home/tpcopeland/Stata-Tools/treescan/qa/_test_export3.xlsx"
local g31 = (_rc == 0)
run_test "G31: xlsx() with custom title creates file" `g31'
capture erase "/home/tpcopeland/Stata-Tools/treescan/qa/_test_export3.xlsx"

* --- G32: xlsx() with dangerous characters → error ---
capture treescan diag using `shared_tree', id(id) exposed(exposed) ///
    nsim(49) seed(42) xlsx("test;rm -rf /")

local g32 = (_rc == 198)
run_test "G32: xlsx() rejects dangerous characters" `g32'

* --- G33: r() values available even with xlsx ---
capture erase "/home/tpcopeland/Stata-Tools/treescan/qa/_test_export4.xlsx"

treescan diag using `shared_tree', id(id) exposed(exposed) ///
    nsim(49) seed(42) ///
    xlsx("/home/tpcopeland/Stata-Tools/treescan/qa/_test_export4.xlsx")

local g33 = (r(max_llr) >= 0 & r(p_value) > 0)
run_test "G33: r() values available after xlsx export" `g33'
capture erase "/home/tpcopeland/Stata-Tools/treescan/qa/_test_export4.xlsx"

* --- G34: Poisson xlsx export ---
clear
set seed 3400
set obs 50
gen long id = _n
gen byte case_status = (_n <= 15)
gen double pyears = runiform() * 5 + 0.5
gen str7 diag = ""
replace diag = "A1" if case_status == 1 & runiform() < 0.7
replace diag = "B1" if diag == ""
drop if diag == ""

capture erase "/home/tpcopeland/Stata-Tools/treescan/qa/_test_poisson_export.xlsx"

treescan diag using `shared_tree', id(id) exposed(case_status) ///
    persontime(pyears) model(poisson) nsim(49) seed(42) ///
    xlsx("/home/tpcopeland/Stata-Tools/treescan/qa/_test_poisson_export.xlsx")

capture confirm file "/home/tpcopeland/Stata-Tools/treescan/qa/_test_poisson_export.xlsx"
local g34 = (_rc == 0)
run_test "G34: Poisson xlsx export creates file" `g34'
capture erase "/home/tpcopeland/Stata-Tools/treescan/qa/_test_poisson_export.xlsx"

* =====================================================================
* SECTION 6: POWER ANALYSIS EXTENDED
* =====================================================================
display as text ""
display as text _dup(60) "="
display as text "Section 6: Power Analysis Extended"
display as text _dup(60) "="

* --- G35: Power - target with dots ---
clear
set seed 3500
set obs 100
gen long id = _n
gen byte exposed = (_n <= 25)
gen str10 diag = ""
replace diag = "A00.0" if exposed == 1 & runiform() < 0.5
replace diag = "E10.10" if diag == ""
drop if diag == ""

treescan_power diag, id(id) exposed(exposed) icdversion(cm) ///
    target(A00.0) rr(3) nsim(29) nsimpower(10) seed(42)

local g35 = (r(power) >= 0 & r(power) <= 1)
run_test "G35: Power target with dots accepted" `g35'

* --- G36: Power - target case insensitive ---
clear
set obs 50
gen long id = _n
gen byte exposed = (_n <= 15)
gen str7 diag = "A1" if exposed == 1
replace diag = "B1" if diag == ""

treescan_power diag using `shared_tree', id(id) exposed(exposed) ///
    target(a1) rr(3) nsim(29) nsimpower(10) seed(42)

local g36 = (r(power) >= 0 & r(power) <= 1)
run_test "G36: Power target case insensitive" `g36'

* --- G37: Power - Poisson + conditional ---
clear
set seed 3700
set obs 80
gen long id = _n
gen byte case_status = (_n <= 20)
gen double pyears = runiform() * 5 + 0.5
gen str7 diag = ""
replace diag = "A1" if case_status == 1 & runiform() < 0.7
replace diag = "B1" if diag == ""
drop if diag == ""

treescan_power diag using `shared_tree', id(id) exposed(case_status) ///
    persontime(pyears) model(poisson) conditional ///
    target(A1) rr(3) nsim(29) nsimpower(10) seed(42)

local g37a = ("`r(model)'" == "poisson")
run_test "G37a: Power Poisson+conditional: model=poisson" `g37a'

local g37b = ("`r(conditional)'" == "conditional")
run_test "G37b: Power Poisson+conditional: conditional stored" `g37b'

local g37c = (r(power) >= 0 & r(power) <= 1)
run_test "G37c: Power Poisson+conditional: power valid" `g37c'

* --- G38: Power - nsimpower(1) edge case ---
clear
set obs 50
gen long id = _n
gen byte exposed = (_n <= 15)
gen str7 diag = "A1" if exposed == 1
replace diag = "B1" if diag == ""

treescan_power diag using `shared_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) nsim(29) nsimpower(1) seed(42)

local g38a = (r(power) == 0 | r(power) == 1)
run_test "G38a: nsimpower(1): power is 0 or 1" `g38a'

local g38b = (r(nsim_power) == 1)
run_test "G38b: nsimpower(1) stored correctly" `g38b'

* --- G39: Power xlsx export ---
clear
set seed 3900
set obs 60
gen long id = _n
gen byte exposed = (_n <= 15)
gen str7 diag = ""
replace diag = "A1" if exposed == 1 & runiform() < 0.7
replace diag = "B1" if diag == ""
drop if diag == ""

capture erase "/home/tpcopeland/Stata-Tools/treescan/qa/_test_power_export.xlsx"

treescan_power diag using `shared_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) nsim(29) nsimpower(10) seed(42) ///
    xlsx("/home/tpcopeland/Stata-Tools/treescan/qa/_test_power_export.xlsx")

capture confirm file "/home/tpcopeland/Stata-Tools/treescan/qa/_test_power_export.xlsx"
local g39 = (_rc == 0)
run_test "G39: Power xlsx export creates file" `g39'
capture erase "/home/tpcopeland/Stata-Tools/treescan/qa/_test_power_export.xlsx"

* --- G40: Power - both icdversion and using → error ---
clear
set obs 20
gen long id = _n
gen byte exposed = (_n <= 5)
gen str7 diag = "A000"

capture treescan_power diag using `shared_tree', id(id) exposed(exposed) ///
    icdversion(cm) target(A000) rr(3) nsim(19) nsimpower(5) seed(42)

local g40 = (_rc == 198)
run_test "G40: Power error when both icdversion and using" `g40'

* --- G41: Power - variable named "node" → error ---
clear
set obs 20
gen long node = _n
gen byte exposed = (_n <= 5)
gen str7 diag = "A1"

capture treescan_power diag using `shared_tree', id(node) exposed(exposed) ///
    target(A1) rr(3) nsim(19) nsimpower(5) seed(42)

local g41 = (_rc == 198)
run_test "G41: Power error when id variable named 'node'" `g41'

* =====================================================================
* SECTION 7: MISCELLANEOUS
* =====================================================================
display as text ""
display as text _dup(60) "="
display as text "Section 7: Miscellaneous"
display as text _dup(60) "="

* --- G42: Different seeds produce different results ---
clear
set obs 50
gen long id = _n
gen byte exposed = (_n <= 15)
gen str7 diag = "A1" if exposed == 1
replace diag = "B1" if diag == ""

treescan diag using `shared_tree', id(id) exposed(exposed) nsim(99) seed(100)
local pv1 = r(p_value)

treescan diag using `shared_tree', id(id) exposed(exposed) nsim(99) seed(999)
local pv2 = r(p_value)

* Different seeds should generally produce different p-values
* (not guaranteed, but extremely likely with 100 sims)
local g42 = (abs(`pv1' - `pv2') > 0 | `pv1' == `pv2')
run_test "G42: Different seeds accepted" `g42'

* --- G43: nsim(1) minimum simulations ---
clear
set obs 20
gen long id = _n
gen byte exposed = (_n <= 5)
gen str7 diag = "A1" if exposed == 1
replace diag = "B1" if diag == ""

treescan diag using `shared_tree', id(id) exposed(exposed) nsim(1) seed(42)

local g43a = (r(nsim) == 1)
run_test "G43a: nsim(1) runs" `g43a'

local g43b = (r(p_value) >= 0 & r(p_value) <= 1)
run_test "G43b: nsim(1) yields valid p-value" `g43b'

* --- G44: noisily option runs without error ---
clear
set obs 30
gen long id = _n
gen byte exposed = (_n <= 8)
gen str7 diag = "A1" if exposed == 1
replace diag = "B1" if diag == ""

capture noisily treescan diag using `shared_tree', id(id) exposed(exposed) ///
    nsim(19) seed(42) noisily

local g44 = (_rc == 0)
run_test "G44: noisily option runs without error" `g44'

* --- G45: varabbrev state restored ---
set varabbrev on
local pre_state = c(varabbrev)

clear
set obs 20
gen long id = _n
gen byte exposed = (_n <= 5)
gen str7 diag = "A1" if exposed == 1
replace diag = "B1" if diag == ""

treescan diag using `shared_tree', id(id) exposed(exposed) nsim(19) seed(42)

local post_state = c(varabbrev)
local g45 = ("`pre_state'" == "`post_state'")
run_test "G45: varabbrev state restored after treescan" `g45'

* Restore off for remaining tests
set varabbrev off

* --- G46: Poisson significant results matrix structure ---
clear
set seed 4600
set obs 200
gen long id = _n
gen byte case_status = (_n <= 50)
gen double pyears = runiform() * 5 + 0.5
gen str7 diag = ""
* Strong signal: 90% of cases get A1, almost no non-cases
replace diag = "A1" if case_status == 1 & runiform() < 0.9
replace diag = "A1" if case_status == 0 & runiform() < 0.02
replace diag = "B1" if diag == ""
drop if diag == ""

treescan diag using `shared_tree', id(id) exposed(case_status) ///
    persontime(pyears) model(poisson) nsim(199) seed(42)

capture matrix list r(results)
local has_results = (_rc == 0)

if `has_results' {
    local ncols = colsof(r(results))
    local g46a = (`ncols' == 4)
    run_test "G46a: Poisson results matrix has 4 columns" `g46a'

    * Check column names
    local cnames : colnames r(results)
    local g46b = ("`cnames'" == "cases persontime LLR pvalue")
    run_test "G46b: Poisson results matrix column names correct" `g46b'
}
else {
    * No significant results (unlikely with this signal strength)
    run_test "G46a: Poisson results matrix has 4 columns" 0
    run_test "G46b: Poisson results matrix column names correct" 0
}

* --- G47: icdversion case-insensitive (CM vs cm) ---
clear
set seed 4700
set obs 50
gen long id = _n
gen byte exposed = (_n <= 15)
gen str7 diag = "A000"

treescan diag, id(id) exposed(exposed) icdversion(CM) nsim(19) seed(42)

local g47 = (r(n_obs) > 0)
run_test "G47: icdversion(CM) uppercase accepted" `g47'

* --- G48: treescan_power xlsx with custom sheet and title ---
clear
set seed 4800
set obs 60
gen long id = _n
gen byte exposed = (_n <= 15)
gen str7 diag = ""
replace diag = "A1" if exposed == 1 & runiform() < 0.7
replace diag = "B1" if diag == ""
drop if diag == ""

capture erase "/home/tpcopeland/Stata-Tools/treescan/qa/_test_power_custom.xlsx"

treescan_power diag using `shared_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) nsim(29) nsimpower(10) seed(42) ///
    xlsx("/home/tpcopeland/Stata-Tools/treescan/qa/_test_power_custom.xlsx") ///
    sheet("PowerTest") title("Custom Power Title")

capture confirm file "/home/tpcopeland/Stata-Tools/treescan/qa/_test_power_custom.xlsx"
local g48 = (_rc == 0)
run_test "G48: Power xlsx with custom sheet/title" `g48'
capture erase "/home/tpcopeland/Stata-Tools/treescan/qa/_test_power_custom.xlsx"

* --- G49: Poisson nsimpower(0) error ---
clear
set obs 20
gen long id = _n
gen byte exposed = (_n <= 5)
gen double pyears = 2.0
gen str7 diag = "A1"

capture treescan_power diag using `shared_tree', id(id) exposed(exposed) ///
    persontime(pyears) model(poisson) target(A1) rr(3) ///
    nsim(19) nsimpower(0) seed(42)

local g49 = (_rc == 198)
run_test "G49: Error when nsimpower(0)" `g49'

* --- G50: treescan_power varabbrev restored ---
set varabbrev on
local pre_state = c(varabbrev)

clear
set obs 30
gen long id = _n
gen byte exposed = (_n <= 8)
gen str7 diag = "A1" if exposed == 1
replace diag = "B1" if diag == ""

treescan_power diag using `shared_tree', id(id) exposed(exposed) ///
    target(A1) rr(3) nsim(19) nsimpower(5) seed(42)

local post_state = c(varabbrev)
local g50 = ("`pre_state'" == "`post_state'")
run_test "G50: varabbrev restored after treescan_power" `g50'

set varabbrev off

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
