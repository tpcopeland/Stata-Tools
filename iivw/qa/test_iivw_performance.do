clear all
set more off
version 16.0
set varabbrev off

* test_iivw_performance.do - lightweight runtime and scaling sanity checks
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_performance.do

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_performance.do must be run from iivw/qa"
    log close _all
    exit 198
}
* Sysdir sandbox + path resolution (Q3/Q8): the sandbox keeps this suite's
* net install out of the USER's real ado tree even when run standalone, and
* the "/qa" suffix is stripped by length, not by first-occurrence subinstr()
* (which mangles any path whose ancestors contain "qa").
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"
local repo_dir "`r(repo_dir)'"

ado dir
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace
discard

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _perf_panel
program define _perf_panel
    version 16.0
    syntax , NIDS(integer) VISITS(integer) SEED(integer)
    clear
    set seed `seed'
    set obs `=`nids' * `visits''
    gen long id = ceil(_n / `visits')
    bysort id: gen byte visit = _n
    gen double months = visit + runiform() / 10
    gen double age = 30 + mod(id, 35)
    bysort id: replace age = age[1]
    gen byte female = mod(id, 2)
    bysort id: replace female = female[1]
    gen byte treat = mod(id, 3) == 0
    bysort id: replace treat = treat[1]
    gen double severity = 0.03 * age + 0.4 * female + 0.15 * visit + ///
        0.20 * sin(id / 5) + rnormal(0, 0.05)
    gen double biomarker = 0.5 * severity + 0.1 * visit + rnormal()
    gen double y = 1 + 0.30 * treat + 0.25 * severity + 0.08 * months + ///
        0.10 * biomarker + rnormal(0, 0.2)
    sort id months
end

**# P1: moderate panel completes core pipeline within a generous budget

local ++test_count
capture noisily {
    _perf_panel, nids(120) visits(5) seed(20260525)
    * severity is time-varying, and treat_cov() is a BASELINE model (one row per
    * subject). From 2.0.0 passing it directly is refused rather than silently
    * reduced to the earliest row's value, so take the baseline explicitly.
    bysort id (months): gen double severity_bl = severity[1]
    timer clear 1
    timer on 1
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(age female severity) ///
        treat(treat) treat_cov(age female severity_bl) truncfinal(1 99) nolog
    iivw_balance severity biomarker, balcut(10) nolog
    local balance_covars "`r(balance_covars)'"
    iivw_fit y treat severity biomarker, vce(fixed) timespec(linear) nolog
    timer off 1
    quietly timer list 1
    local elapsed = r(t1)

    assert `elapsed' < 45
    * treat is in the list because FIPTIW now puts it in the visit-intensity
    * model by construction (Phase 2). iivw_balance reports on the design that
    * was actually fitted, so the treatment term appears here too -- and it
    * should: whether the weights balance treatment across the at-risk set is
    * precisely the question FIPTIW exists to answer.
    assert "`balance_covars'" == "age female severity treat biomarker"
    assert "`e(iivw_cmd)'" == "iivw_fit"
    assert "`e(iivw_weighttype)'" == "fiptiw"
    quietly count if missing(_iivw_weight) | _iivw_weight <= 0
    assert r(N) == 0
    quietly count if missing(_iivw_iw) | missing(_iivw_tw)
    assert r(N) == 0
    display as text "  P1 elapsed seconds: " %8.3f `elapsed'
}
if _rc == 0 {
    display as result "  PASS: P1 - core pipeline runtime and finite outputs"
    local ++pass_count
}
else {
    display as error "  FAIL: P1 - core pipeline runtime and finite outputs (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P1"
}

**# P2: larger panel scales without runaway runtime or variable debris

local ++test_count
capture noisily {
    _perf_panel, nids(180) visits(5) seed(20260526)
    local n_before = _N
    ds
    local vars_before : word count `r(varlist)'
    timer clear 2
    timer on 2
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(age female severity) ///
        wtype(iivw) nolog
    iivw_fit y treat severity biomarker, vce(fixed) timespec(quadratic) nolog
    timer off 2
    quietly timer list 2
    local elapsed = r(t2)
    ds
    local vars_after : word count `r(varlist)'

    assert `elapsed' < 60
    assert _N == `n_before'
    assert `vars_after' <= `vars_before' + 4
    assert "`e(iivw_timespec)'" == "quadratic"
    confirm variable _iivw_time_sq
    quietly count if missing(_iivw_weight) | _iivw_weight <= 0
    assert r(N) == 0
    display as text "  P2 elapsed seconds: " %8.3f `elapsed'
}
if _rc == 0 {
    display as result "  PASS: P2 - larger panel scaling and bounded generated variables"
    local ++pass_count
}
else {
    display as error "  FAIL: P2 - larger panel scaling and bounded generated variables (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P2"
}

**# P3: the weight-contract signature scales without N-length scratch columns

local ++test_count
local orig_processors = c(processors)
capture noisily {
    clear
    set obs 1000000
    gen long id = ceil(_n / 5)
    gen byte t = mod(_n - 1, 5)
    forvalues j = 1/10 {
        gen double x`j' = mod(_n + `j', 17)
    }
    gen double iw = mod(_n, 11) + 1
    gen double w = iw

    char _dta[_iivw_id] "id"
    char _dta[_iivw_time] "t"
    char _dta[_iivw_weight_var] "w"
    char _dta[_iivw_iw_var] "iw"
    char _dta[_iivw_visit_cov_raw] "x1 x2 x3 x4 x5 x6 x7 x8 x9 x10"
    char _dta[_iivw_weighttype] "iivw"
    char _dta[_iivw_contract_version] "3"

    set processors 1
    timer clear 3
    timer on 3
    capture noisily _iivw_weight_signature
    local sig_rc = _rc
    timer off 3
    set processors `orig_processors'
    if `sig_rc' exit `sig_rc'

    local sig_before "`r(signature)'"
    quietly timer list 3
    local elapsed = r(t3)

    * The pre-optimization implementation took 1.61 seconds on this machine
    * because it generated three million-row scratch variables per bound column;
    * the vectorized Mata scan that replaced it measured 0.92.
    *
    * Those two numbers are only 1.75x apart, so the original absolute
    * `elapsed < 1.25' gate had about 36% headroom -- less than the cost of
    * sharing the machine. Measured: 1.196 s with one other lane running
    * (PASS) and 1.296 s with three (FAIL), with no change to the package
    * between the runs. An absolute second-count on a shared machine reports
    * contention as a regression, which is the failure this repo already
    * documents for ratio gates against fixed reference times.
    *
    * The property the optimization actually changed is how signature cost
    * scales in the number of BOUND COLUMNS: the old implementation generated
    * three dataset-sized scratch variables per bound column, so its cost was
    * dominated by per-column work, while the vectorized scan pays a large
    * fixed cost for the id/time/weight pass and only a small increment per
    * additional column. Measure that directly by timing the same signature on
    * the same data with 10 bound covariates and with 1, and gate the median of
    * three paired ratios. Both halves are the same code in the same run under
    * the same load. Taking the median keeps a single scheduling or frequency
    * excursion from deciding the verdict while still requiring at least two
    * of three measurements to remain below the scaling gate. A calibration
    * against cheap `generate' calls was tried first
    * and rejected: the unit measured 0.035 s standalone and 0.016 s in-run,
    * so the denominator was not stable enough to gate on.
    *
    * Each timing is preceded by an untimed warm-up call so the comparison is
    * cold-cache-free on both sides rather than only on the second, and both
    * are taken BEFORE the row permutation below: sorting randomly-ordered
    * 1M-row data adds a large fixed cost to each half and compresses the
    * ratio toward 1, which is exactly the signal being measured.
    *
    * Review evidence on 2026-08-11 showed why one pair is not enough: identical
    * code produced ratios 2.41, 1.98, 1.89, and 1.75 in consecutive lane and
    * standalone runs. The first value falsely crossed the old 2.2 gate even
    * though the next three passed. The median-of-three gate preserves the
    * scaling signal but no longer treats one timing excursion as a regression.
    *
    * Honest limit: the pre-optimization implementation no longer exists, so
    * its ratio was NOT measured. What this gate enforces is that signature
    * cost must not become dominated by per-bound-column work again; the exact
    * sort-invariance and edit-detection assertions below protect correctness.
    forvalues rep = 1/3 {
        char _dta[_iivw_visit_cov_raw] "x1 x2 x3 x4 x5 x6 x7 x8 x9 x10"
        quietly _iivw_weight_signature
        timer clear 4
        timer on 4
        quietly _iivw_weight_signature
        timer off 4
        quietly timer list 4
        local t_wide`rep' = r(t4)

        char _dta[_iivw_visit_cov_raw] "x1"
        quietly _iivw_weight_signature
        timer clear 5
        timer on 5
        quietly _iivw_weight_signature
        timer off 5
        quietly timer list 5
        local t_narrow`rep' = r(t5)

        * Fail closed if timer resolution floors the narrow measurement.
        assert `t_narrow`rep'' > 0
        local colratio`rep' = `t_wide`rep'' / `t_narrow`rep''
        display as text "  P3 column-scaling ratio, pair `rep': " ///
            %8.2f `colratio`rep''
    }

    * Restore the fixture's declared contract so nothing downstream inherits
    * the one-covariate spec this measurement installed.
    char _dta[_iivw_visit_cov_raw] "x1 x2 x3 x4 x5 x6 x7 x8 x9 x10"

    local colratio = `colratio1' + `colratio2' + `colratio3' - ///
        min(`colratio1', `colratio2', `colratio3') - ///
        max(`colratio1', `colratio2', `colratio3')
    display as text "  P3 median wide/narrow column-scaling ratio (gate: < 2.2): " ///
        %8.2f `colratio'
    assert `colratio' < 2.2

    * A harmless row permutation must leave the signature byte-identical. The
    * stale-state suite repeats this with general floating-point covariates; this
    * large integer fixture keeps the performance assertion reproducible.
    set seed 20260729
    gen double order_key = runiform()
    sort order_key
    drop order_key
    quietly _iivw_weight_signature
    assert "`r(signature)'" == "`sig_before'"

    * A bound-column edit must still trip the signature after the optimization.
    replace x7 = x7 + 1 in 500000
    quietly _iivw_weight_signature
    assert "`r(signature)'" != "`sig_before'"


    * Backstop only. The ratio above is the real gate; this catches a gross
    * across-the-board slowdown (say, a sort added to the fixed pass) that
    * would leave the ratio flat. Set far enough above the 0.92 s reference
    * that ordinary contention cannot reach it.
    display as text "  P3 signature seconds (1M rows, 13 columns): " %8.3f `elapsed'
    assert `elapsed' < 5.0
}
local p3_rc = _rc
capture set processors `orig_processors'
if `p3_rc' == 0 {
    display as result "  PASS: P3 - signature scaling, invariance, and edit detection"
    local ++pass_count
}
else {
    display as error "  FAIL: P3 - signature scaling/contract (error `p3_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P3"
}

display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "FAILED TESTS: `failed_tests'"
    display "RESULT: test_iivw_performance tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _all
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_iivw_performance tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _all
