/*******************************************************************************
* invariant_tests.do
*
* MATHEMATICAL INVARIANT TESTS FOR TVTOOLS COMMANDS
*
* Tests properties that must ALWAYS hold regardless of data:
* - Symmetry properties
* - Monotonicity
* - Boundary conditions
* - Consistency across representations
* - Conservation laws
*
* Author: Tim Copeland
* Date: 2025-12-30
*******************************************************************************/

clear all
set more off
version 16.0

* Reinstall tvtools
capture net uninstall tvtools
net install tvtools, from("/home/tpcopeland/Stata-Tools/tvtools")

display _n "{hline 78}"
display "{bf:MATHEMATICAL INVARIANT TESTS}"
display "{hline 78}"
display "Started: `c(current_date)' `c(current_time)'"
display "{hline 78}" _n

local total_tests = 0
local total_pass = 0
local total_fail = 0
local failed_tests ""

* =============================================================================
* INVARIANT 1: IPTW Weights - Positivity
* =============================================================================

display _n "{hline 78}"
display "{bf:INVARIANT 1: IPTW Weights Must Be Positive}"
display "{hline 78}" _n

display as text "Test I1.1: All weights > 0"
local ++total_tests

clear
set seed 11111
set obs 500

gen x1 = rnormal()
gen x2 = rnormal()
gen pr_treat = invlogit(-0.5 + 0.3*x1 + 0.2*x2)
gen treatment = runiform() < pr_treat

tvweight treatment, covariates(x1 x2) generate(w)

quietly count if w <= 0
local n_nonpos = r(N)

quietly count if missing(w)
local n_miss = r(N)

if `n_nonpos' == 0 & `n_miss' == 0 {
    display as result "  PASS: All " _N " weights are positive and non-missing"
    local ++total_pass
}
else {
    display as error "  FAIL: Found `n_nonpos' non-positive, `n_miss' missing"
    local ++total_fail
    local failed_tests "`failed_tests' I1.1"
}

* =============================================================================
* INVARIANT 2: Propensity Score Bounds
* =============================================================================

display _n "{hline 78}"
display "{bf:INVARIANT 2: Propensity Scores Must Be in (0,1)}"
display "{hline 78}" _n

display as text "Test I2.1: Propensity scores in valid range"
local ++total_tests

* Propensity score is 1/w for treated, 1-1/w for untreated
gen ps = cond(treatment == 1, 1/w, 1 - 1/w)

quietly summarize ps
local ps_min = r(min)
local ps_max = r(max)

if `ps_min' > 0 & `ps_max' < 1 {
    display as result "  PASS: All propensity scores in (0,1): [" %6.4f `ps_min' ", " %6.4f `ps_max' "]"
    local ++total_pass
}
else {
    display as error "  FAIL: Propensity scores outside (0,1)"
    local ++total_fail
    local failed_tests "`failed_tests' I2.1"
}

* =============================================================================
* INVARIANT 3: E-value Symmetry
* =============================================================================

display _n "{hline 78}"
display "{bf:INVARIANT 3: E-value Symmetry - E(RR) = E(1/RR)}"
display "{hline 78}" _n

display as text "Test I3.1: E-value(2.0) = E-value(0.5)"
local ++total_tests

tvsensitivity, rr(2.0)
local ev_2 = r(evalue)

tvsensitivity, rr(0.5)
local ev_half = r(evalue)

if abs(`ev_2' - `ev_half') < 0.01 {
    display as result "  PASS: E(2.0) = " %5.3f `ev_2' " = E(0.5) = " %5.3f `ev_half'
    local ++total_pass
}
else {
    display as error "  FAIL: E(2.0) = " %5.3f `ev_2' " != E(0.5) = " %5.3f `ev_half'
    local ++total_fail
    local failed_tests "`failed_tests' I3.1"
}

* -----------------------------------------------------------------------------
display as text "Test I3.2: E-value(3.0) = E-value(1/3)"
local ++total_tests

tvsensitivity, rr(3.0)
local ev_3 = r(evalue)

tvsensitivity, rr(0.333333)
local ev_third = r(evalue)

if abs(`ev_3' - `ev_third') < 0.02 {
    display as result "  PASS: E(3.0) = " %5.3f `ev_3' " ≈ E(1/3) = " %5.3f `ev_third'
    local ++total_pass
}
else {
    display as error "  FAIL: E(3.0) = " %5.3f `ev_3' " != E(1/3) = " %5.3f `ev_third'
    local ++total_fail
    local failed_tests "`failed_tests' I3.2"
}

* =============================================================================
* INVARIANT 4: E-value Monotonicity
* =============================================================================

display _n "{hline 78}"
display "{bf:INVARIANT 4: E-value Strictly Increasing with |log(RR)|}"
display "{hline 78}" _n

display as text "Test I4.1: E-value monotonicity for RR > 1"
local ++total_tests

local prev_ev = 1
local monotonic = 1

foreach rr in 1.1 1.5 2.0 3.0 5.0 10.0 {
    tvsensitivity, rr(`rr')
    local curr_ev = r(evalue)
    if `curr_ev' <= `prev_ev' {
        local monotonic = 0
    }
    local prev_ev = `curr_ev'
}

if `monotonic' {
    display as result "  PASS: E-value strictly increasing for RR = 1.1 to 10.0"
    local ++total_pass
}
else {
    display as error "  FAIL: E-value not monotonically increasing"
    local ++total_fail
    local failed_tests "`failed_tests' I4.1"
}

* =============================================================================
* INVARIANT 5: G-estimation Consistency
* =============================================================================

display _n "{hline 78}"
display "{bf:INVARIANT 5: G-estimation Consistent Across Seeds}"
display "{hline 78}" _n

display as text "Test I5.1: Same data, same result"
local ++total_tests

clear
set seed 22222
set obs 1000

gen x1 = rnormal()
gen x2 = rnormal()
gen pr_treat = invlogit(0.2*x1 + 0.1*x2)
gen treatment = runiform() < pr_treat
gen outcome = 50 + 2*treatment + 0.5*x1 + 0.3*x2 + rnormal(0, 3)

tempfile testdata
save `testdata', replace

* Run twice on same data
tvestimate outcome treatment, confounders(x1 x2)
local psi1 = e(psi)

use `testdata', clear
tvestimate outcome treatment, confounders(x1 x2)
local psi2 = e(psi)

if abs(`psi1' - `psi2') < 1e-10 {
    display as result "  PASS: Deterministic results (psi1 = psi2 = " %6.4f `psi1' ")"
    local ++total_pass
}
else {
    display as error "  FAIL: Results differ (psi1 = " %6.4f `psi1' ", psi2 = " %6.4f `psi2' ")"
    local ++total_fail
    local failed_tests "`failed_tests' I5.1"
}

* =============================================================================
* INVARIANT 6: tvtrial Clone Doubling
* =============================================================================

display _n "{hline 78}"
display "{bf:INVARIANT 6: Clone Approach Must Double Each Eligible Person}"
display "{hline 78}" _n

display as text "Test I6.1: Clone creates exactly 2 records per person"
local ++total_tests

clear
set seed 33333
set obs 50

gen id = _n
gen study_entry = mdy(1, 1, 2020)
gen study_exit = study_entry + 365
format %td study_entry study_exit
gen rx_start = .
replace rx_start = study_entry + 30 if _n <= 20  // 20 treated
format %td rx_start

* Single trial, clone approach
tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
    trials(1) clone graceperiod(14)

* Every id should appear exactly twice
bysort id: gen n_records = _N
quietly summarize n_records
local min_rec = r(min)
local max_rec = r(max)

if `min_rec' == 2 & `max_rec' == 2 {
    display as result "  PASS: Every person has exactly 2 clones"
    local ++total_pass
}
else {
    display as error "  FAIL: Record counts vary (min=`min_rec', max=`max_rec')"
    local ++total_fail
    local failed_tests "`failed_tests' I6.1"
}

* -----------------------------------------------------------------------------
display as text "Test I6.2: Each person has one record in each arm"
local ++total_tests

bysort id trial_arm: gen n_per_arm = _N
quietly summarize n_per_arm
local max_per_arm = r(max)

bysort id: egen arms = total(trial_arm)
* If one record in arm=0 and one in arm=1, sum = 1
quietly summarize arms
local arms_ok = (r(min) == 1 & r(max) == 1)

if `arms_ok' {
    display as result "  PASS: Each person has exactly one record per arm"
    local ++total_pass
}
else {
    display as error "  FAIL: Arm assignment incorrect"
    local ++total_fail
    local failed_tests "`failed_tests' I6.2"
}

* =============================================================================
* INVARIANT 7: Person-Time Conservation
* =============================================================================

display _n "{hline 78}"
display "{bf:INVARIANT 7: Total Person-Time Must Be Conserved}"
display "{hline 78}" _n

display as text "Test I7.1: tvpipeline preserves total person-time"
local ++total_tests

* Create simple cohort
clear
set seed 44444
set obs 100

gen id = _n
gen study_entry = mdy(1, 1, 2020)
gen study_exit = study_entry + 365
format %td study_entry study_exit

gen orig_pt = study_exit - study_entry
quietly summarize orig_pt
local total_pt_orig = r(sum)

tempfile cohort
save `cohort', replace

* Create exposure
clear
set obs 150
gen id = ceil(_n / 1.5)
replace id = min(id, 100)
gen rx_start = mdy(1, 15, 2020) + floor(runiform() * 100)
gen rx_stop = rx_start + 30
format %td rx_start rx_stop
gen drug = 1

tempfile exposure
save `exposure', replace

use `cohort', clear
tvpipeline using `exposure', id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) entry(study_entry) exit(study_exit)

gen split_pt = stop - start
quietly summarize split_pt
local total_pt_split = r(sum)

local pt_ratio = `total_pt_split' / `total_pt_orig'
* Allow 2% tolerance for boundary effects at exposure start/stop
if `pt_ratio' > 0.98 & `pt_ratio' <= 1.0 {
    display as result "  PASS: Person-time conserved (ratio: " %7.5f `pt_ratio' ")"
    local ++total_pass
}
else {
    display as error "  FAIL: Person-time not conserved (ratio: " %7.5f `pt_ratio' ")"
    local ++total_fail
    local failed_tests "`failed_tests' I7.1"
}

* =============================================================================
* INVARIANT 8: Truncation Bound Enforcement
* =============================================================================

display _n "{hline 78}"
display "{bf:INVARIANT 8: Weight Truncation Must Be Strictly Enforced}"
display "{hline 78}" _n

display as text "Test I8.1: Truncated weights within bounds"
local ++total_tests

clear
set seed 55555
set obs 1000

gen x1 = rnormal()
gen x2 = rnormal()
gen pr_treat = invlogit(-1 + 0.8*x1 + 0.6*x2)  // Strong confounding
gen treatment = runiform() < pr_treat

tvweight treatment, covariates(x1 x2) generate(tw) truncate(2 98)

* Get the percentile bounds
tvweight treatment, covariates(x1 x2) generate(uw)
quietly _pctile uw, p(2 98)
local p2 = r(r1)
local p98 = r(r2)

quietly summarize tw
local tw_min = r(min)
local tw_max = r(max)

if `tw_min' >= `p2' - 1e-10 & `tw_max' <= `p98' + 1e-10 {
    display as result "  PASS: All weights within truncation bounds"
    local ++total_pass
}
else {
    display as error "  FAIL: Weights outside bounds (min: `tw_min', max: `tw_max')"
    local ++total_fail
    local failed_tests "`failed_tests' I8.1"
}

* =============================================================================
* INVARIANT 9: Stabilized Weight Mean ~ 1
* =============================================================================

display _n "{hline 78}"
display "{bf:INVARIANT 9: Stabilized Weights Should Average Near 1}"
display "{hline 78}" _n

display as text "Test I9.1: Mean of stabilized weights ≈ 1"
local ++total_tests

tvweight treatment, covariates(x1 x2) generate(sw) stabilized

quietly summarize sw
local mean_sw = r(mean)

if abs(`mean_sw' - 1) < 0.1 {
    display as result "  PASS: Mean stabilized weight = " %5.3f `mean_sw' " (≈ 1.0)"
    local ++total_pass
}
else {
    display as error "  FAIL: Mean stabilized weight = " %5.3f `mean_sw' " (expected ≈ 1.0)"
    local ++total_fail
    local failed_tests "`failed_tests' I9.1"
}

* =============================================================================
* INVARIANT 10: Treatment Effect Sign Preservation
* =============================================================================

display _n "{hline 78}"
display "{bf:INVARIANT 10: Large Positive Effect Should Be Detected as Positive}"
display "{hline 78}" _n

display as text "Test I10.1: Sign of effect is correctly identified"
local ++total_tests

clear
set seed 66666
set obs 2000

gen x1 = rnormal()
gen treatment = runiform() > 0.5  // Random treatment

* Very large positive effect
gen outcome = 100 + 50*treatment + x1 + rnormal(0, 5)

tvestimate outcome treatment, confounders(x1)
local psi = e(psi)

if `psi' > 0 {
    display as result "  PASS: Positive effect correctly identified (psi = " %5.1f `psi' ")"
    local ++total_pass
}
else {
    display as error "  FAIL: Effect sign wrong (psi = " %5.1f `psi' ", expected > 0)"
    local ++total_fail
    local failed_tests "`failed_tests' I10.1"
}

* -----------------------------------------------------------------------------
display as text "Test I10.2: Large negative effect correctly signed"
local ++total_tests

replace outcome = 100 - 50*treatment + x1 + rnormal(0, 5)

tvestimate outcome treatment, confounders(x1)
local psi = e(psi)

if `psi' < 0 {
    display as result "  PASS: Negative effect correctly identified (psi = " %5.1f `psi' ")"
    local ++total_pass
}
else {
    display as error "  FAIL: Effect sign wrong (psi = " %5.1f `psi' ", expected < 0)"
    local ++total_fail
    local failed_tests "`failed_tests' I10.2"
}

* =============================================================================
* INVARIANT 11: tvtable Counts Sum Correctly
* =============================================================================

display _n "{hline 78}"
display "{bf:INVARIANT 11: Table Counts Must Sum to Total}"
display "{hline 78}" _n

display as text "Test I11.1: Exposure level counts sum to N"
local ++total_tests

clear
set obs 500
gen tv_exposure = floor(runiform() * 4)  // 4 levels
gen fu_time = 100 + runiform() * 200
gen _event = runiform() < 0.2

local N = _N

tvtable, exposure(tv_exposure)
local table_n = r(total_n)

if `table_n' == `N' {
    display as result "  PASS: Table total (`table_n') = N (`N')"
    local ++total_pass
}
else {
    display as error "  FAIL: Table total (`table_n') != N (`N')"
    local ++total_fail
    local failed_tests "`failed_tests' I11.1"
}

* =============================================================================
* INVARIANT 12: DML Cross-fitting K Value
* =============================================================================

display _n "{hline 78}"
display "{bf:INVARIANT 12: DML Result Stable Across K Values}"
display "{hline 78}" _n

display as text "Test I12.1: K=2 vs K=5 give similar results"
local ++total_tests

clear
set seed 77777
set obs 500

gen x1 = rnormal()
gen x2 = rnormal()
gen treatment = runiform() > 0.5
gen outcome = 10 + 3*treatment + 0.5*x1 + rnormal(0, 2)

tvdml outcome treatment, covariates(x1 x2) crossfit(2) seed(88888)
local psi_k2 = e(psi)

tvdml outcome treatment, covariates(x1 x2) crossfit(5) seed(88888)
local psi_k5 = e(psi)

local diff = abs(`psi_k2' - `psi_k5')
if `diff' < 0.5 {
    display as result "  PASS: K=2 (" %5.2f `psi_k2' ") ≈ K=5 (" %5.2f `psi_k5' "), diff = " %4.2f `diff'
    local ++total_pass
}
else {
    display as error "  FAIL: K=2 (" %5.2f `psi_k2' ") != K=5 (" %5.2f `psi_k5' ")"
    local ++total_fail
    local failed_tests "`failed_tests' I12.1"
}

* =============================================================================
* INVARIANT 13: ESS <= N
* =============================================================================

display _n "{hline 78}"
display "{bf:INVARIANT 13: Effective Sample Size <= Actual Sample Size}"
display "{hline 78}" _n

display as text "Test I13.1: ESS <= N always"
local ++total_tests

clear
set seed 99999
set obs 1000

gen x1 = rnormal()
gen treatment = runiform() > 0.5

tvweight treatment, covariates(x1) generate(w)
local ess = r(ess)
local N = _N

if `ess' <= `N' {
    display as result "  PASS: ESS (" %6.1f `ess' ") <= N (" `N' ")"
    local ++total_pass
}
else {
    display as error "  FAIL: ESS (" %6.1f `ess' ") > N (" `N' ")"
    local ++total_fail
    local failed_tests "`failed_tests' I13.1"
}

* =============================================================================
* INVARIANT 14: E-value >= 1 Always
* =============================================================================

display _n "{hline 78}"
display "{bf:INVARIANT 14: E-value Must Be >= 1}"
display "{hline 78}" _n

display as text "Test I14.1: E-value >= 1 for all RR values"
local ++total_tests

local all_ge_1 = 1

foreach rr in 0.1 0.5 0.9 1.0 1.1 2.0 5.0 10.0 {
    tvsensitivity, rr(`rr')
    local ev = r(evalue)
    if `ev' < 1 - 1e-10 {
        local all_ge_1 = 0
    }
}

if `all_ge_1' {
    display as result "  PASS: All E-values >= 1"
    local ++total_pass
}
else {
    display as error "  FAIL: Some E-value < 1"
    local ++total_fail
    local failed_tests "`failed_tests' I14.1"
}

* =============================================================================
* INVARIANT 15: Standard Error Positive
* =============================================================================

display _n "{hline 78}"
display "{bf:INVARIANT 15: Standard Errors Must Be Positive}"
display "{hline 78}" _n

display as text "Test I15.1: tvestimate SE > 0"
local ++total_tests

clear
set seed 10101
set obs 500

gen x1 = rnormal()
gen treatment = runiform() > 0.5
gen outcome = 10 + 2*treatment + x1 + rnormal()

tvestimate outcome treatment, confounders(x1)
local se = e(se_psi)

if `se' > 0 {
    display as result "  PASS: SE = " %6.4f `se' " > 0"
    local ++total_pass
}
else {
    display as error "  FAIL: SE = " %6.4f `se' " <= 0"
    local ++total_fail
    local failed_tests "`failed_tests' I15.1"
}

* -----------------------------------------------------------------------------
display as text "Test I15.2: tvdml SE > 0"
local ++total_tests

tvdml outcome treatment, covariates(x1) crossfit(3) seed(11112)
local se = e(se_psi)

if `se' > 0 {
    display as result "  PASS: SE = " %6.4f `se' " > 0"
    local ++total_pass
}
else {
    display as error "  FAIL: SE = " %6.4f `se' " <= 0"
    local ++total_fail
    local failed_tests "`failed_tests' I15.2"
}

* =============================================================================
* FINAL SUMMARY
* =============================================================================

display _n "{hline 78}"
display "{bf:INVARIANT TEST SUMMARY}"
display "{hline 78}"
display "Total invariants tested:  " as result `total_tests'
display "Invariants satisfied:     " as result `total_pass'
if `total_fail' > 0 {
    display "Invariants violated:      " as error `total_fail'
    display as error _n "VIOLATED INVARIANTS:`failed_tests'"
}
else {
    display "Invariants violated:      " as text `total_fail'
}
display "{hline 78}"

local pass_rate = 100 * `total_pass' / `total_tests'
display _n "Pass rate: " as result %5.1f `pass_rate' "%"

if `total_fail' == 0 {
    display _n as result "{bf:ALL MATHEMATICAL INVARIANTS SATISFIED!}"
    display as result "Commands obey all required mathematical properties."
}
else {
    display _n as error "{bf:SOME INVARIANTS VIOLATED - CRITICAL ISSUE}"
}

display _n "{hline 78}"
display "Completed: `c(current_date)' `c(current_time)'"
display "{hline 78}"
