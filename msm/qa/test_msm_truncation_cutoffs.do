* test_msm_truncation_cutoffs.do
* Percentile cutoffs held at full precision (R-tabtools wttab review, item 2).
* Written against msm 1.4.9 before any fix:
*   TC1  msm_weight, truncate(1 99) counts as truncated exactly the risk-set
*        weights below P1 or above P99 of the untruncated weights, and caps
*        them at exactly those cutoffs. The cutoffs used to pass through a
*        local macro, whose decimal text need not read back as the same
*        double: a weight equal to P99 was then counted as above it and
*        rewritten one unit in the last place lower (off by one in
*        r(n_truncated) for several of these seeds)
*   TC2  msm_diagnose r(n_extreme) counts the risk-set weights strictly above
*        the P99 of summarize, detail, compared at full precision
* Oracles: _pctile / summarize, detail results held in scalars, counted and
* capped here from a copy of the untruncated weights.

version 16.0
clear all
set more off
set varabbrev off

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture log close _all
log using "test_msm_truncation_cutoffs.log", replace text nomsg

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

* A small person-period panel with a time-varying confounder.
capture program drop _tc_panel
program define _tc_panel
    version 16.0
    args seed
    clear
    set seed `seed'
    quietly set obs 1200
    gen long id = ceil(_n / 6)
    bysort id: gen int period = _n - 1
    gen byte bl = mod(id, 2)
    gen double L = rnormal() + 0.2 * period + 0.3 * bl
    gen byte treatment = runiform() < invlogit(-0.5 + 0.4 * bl + 0.5 * L)
    gen byte outcome = runiform() < invlogit(-4 + 0.4 * treatment + 0.2 * L)
    quietly bysort id (period): gen byte _prior = sum(outcome[_n-1]) >= 1 if _n > 1
    quietly replace _prior = 0 if missing(_prior)
    quietly drop if _prior
    drop _prior
    quietly msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L) baseline_covariates(bl)
end

**# TC1: truncation counts and caps at the exact cutoffs
foreach seed in 1 3 4 5 {
    local ++test_count
    capture noisily {
        _tc_panel `seed'
        quietly msm_weight, treat_d_cov(L bl) treat_n_cov(bl) nolog
        gen double w0 = _msm_weight
        tempname lo hi
        quietly _pctile w0 if _msm_decision_risk & !missing(w0), percentiles(1 99)
        scalar `lo' = r(r1)
        scalar `hi' = r(r2)
        quietly count if _msm_decision_risk & !missing(w0) & (w0 < `lo' | w0 > `hi')
        local want = r(N)
        quietly msm_weight, treat_d_cov(L bl) treat_n_cov(bl) nolog ///
            truncate(1 99) replace
        local got = r(n_truncated)
        gen double wexp = cond(_msm_decision_risk & !missing(w0), ///
            min(max(w0, `lo'), `hi'), w0)
        quietly count if _msm_weight != wexp
        local ndiff = r(N)
        display as text "  seed `seed': n_truncated `got' (oracle `want'), weights off the cap `ndiff'"
        assert `got' == `want'
        assert `ndiff' == 0
    }
    if _rc == 0 {
        display as result "  PASS TC1: seed `seed' truncates at the exact P1/P99 cutoffs"
        local ++pass_count
    }
    else {
        display as error "  FAIL TC1: seed `seed' truncation cutoffs (rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' TC1(`seed')"
    }
}

**# TC2: msm_diagnose extreme-weight count at the exact P99
local ++test_count
capture noisily {
    local mism 0
    foreach seed in 1 3 4 5 {
        _tc_panel `seed'
        quietly msm_weight, treat_d_cov(L bl) treat_n_cov(bl) nolog
        tempname p99
        quietly summarize _msm_weight if _msm_decision_risk, detail
        scalar `p99' = r(p99)
        quietly count if _msm_decision_risk & _msm_weight > `p99' & !missing(_msm_weight)
        local want = r(N)
        quietly msm_diagnose, balance_covariates(L)
        display as text "  seed `seed': n_extreme `r(n_extreme)' (oracle `want')"
        if r(n_extreme) != `want' local ++mism
    }
    assert `mism' == 0
}
if _rc == 0 {
    display as result "  PASS TC2: msm_diagnose counts weights above the exact P99"
    local ++pass_count
}
else {
    display as error "  FAIL TC2: msm_diagnose extreme-weight count (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' TC2"
}

display as text ""
display as text "Tests run: " as result `test_count'
display as text "Passed:    " as result `pass_count'
display as text "Failed:    " as result `fail_count'
do "`qa_dir'/_record_qa_result.do" test_msm_truncation_cutoffs ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: test_msm_truncation_cutoffs tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 459
}
display as result "All msm truncation-cutoff tests passed"
