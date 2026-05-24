clear all
set more off
version 16.0
set varabbrev off

* validation_iivw_diagnostics_known_answers.do - deterministic diagnostic QA
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do validation_iivw_diagnostics_known_answers.do

capture log close _all
tempfile validation_log
log using "`validation_log'", name(main) text replace

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "validation_iivw_diagnostics_known_answers.do must be run from iivw/qa"
    log close _all
    exit 198
}
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

ado dir
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _diag_post_result
program define _diag_post_result, eclass
    version 16.0
    args estname b se
    tempname bmat vmat
    matrix `bmat' = (`b')
    matrix colnames `bmat' = x
    matrix `vmat' = (`se'^2)
    matrix rownames `vmat' = x
    matrix colnames `vmat' = x
    ereturn post `bmat' `vmat', obs(24)
    ereturn local cmd "regress"
    estimates store `estname'
end

capture program drop _diag_known_triplet
program define _diag_known_triplet
    version 16.0
    estimates clear
    _diag_post_result D_unweighted 10 2
    _diag_post_result D_weighted 7 1
    _diag_post_result D_adjusted 4 0.5
end

capture program drop _fit_oracle_data
program define _fit_oracle_data
    version 16.0
    clear
    set obs 36
    gen int id = ceil(_n / 3)
    bysort id: gen byte t = _n - 1
    gen double x = mod(id, 4) - 1.5
    gen byte z = id > 6
    gen double y = 3 + 1.25 * x - 0.75 * z + 0.5 * t + sin(id) / 7
    sort id t
end

**# Known-answer diagnostics

local ++test_count
capture noisily {
    _diag_known_triplet
    local level_1se = 100 * (2 * normal(1) - 1)
    iivw_diagnose x, unweighted(D_unweighted) weighted(D_weighted) ///
        adjusted(D_adjusted) exogeneity(exogenous) true(5) ///
        level(`level_1se')

    assert abs(r(b_unweighted) - 10) < 1e-12
    assert abs(r(se_unweighted) - 2) < 1e-12
    assert abs(r(b_weighted) - 7) < 1e-12
    assert abs(r(se_weighted) - 1) < 1e-12
    assert abs(r(b_adjusted) - 4) < 1e-12
    assert abs(r(se_adjusted) - 0.5) < 1e-12
    assert abs(r(sampling_gap) - 3) < 1e-12
    assert abs(r(artifact_gap) - 3) < 1e-12
    assert abs(r(total_gap) - 6) < 1e-12
    assert abs(r(sampling_share) - 0.5) < 1e-12
    assert abs(r(artifact_share) - 0.5) < 1e-12
    assert abs(r(bounds_lower) - 4) < 1e-12
    assert abs(r(bounds_upper) - 7) < 1e-12
    assert abs(r(true) - 5) < 1e-12
    assert abs(r(bias_unweighted) - 5) < 1e-12
    assert abs(r(bias_weighted) - 2) < 1e-12
    assert abs(r(bias_adjusted) + 1) < 1e-12
    assert "`r(conclusion)'" == "point_decomposition"

    matrix E = r(estimates)
    local rn : rownames E
    local cn : colnames E
    assert "`rn'" == "unweighted weighted adjusted"
    assert "`cn'" == "b se ll ul"
    assert rowsof(E) == 3
    assert colsof(E) == 4
    assert abs(E[1,1] - 10) < 1e-12
    assert abs(E[1,2] - 2) < 1e-12
    assert abs(E[1,3] - 8) < 1e-12
    assert abs(E[1,4] - 12) < 1e-12
    assert abs(E[2,1] - 7) < 1e-12
    assert abs(E[2,2] - 1) < 1e-12
    assert abs(E[2,3] - 6) < 1e-12
    assert abs(E[2,4] - 8) < 1e-12
    assert abs(E[3,1] - 4) < 1e-12
    assert abs(E[3,2] - 0.5) < 1e-12
    assert abs(E[3,3] - 3.5) < 1e-12
    assert abs(E[3,4] - 4.5) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: D1 - iivw_diagnose exact gaps, shares, CIs, matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: D1 - iivw_diagnose exact returns (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D1"
}

local ++test_count
capture noisily {
    _diag_known_triplet
    tempfile diaglog
    log using "`diaglog'", name(diag) text replace
    iivw_diagnose x, unweighted(D_unweighted) weighted(D_weighted) ///
        adjusted(D_adjusted) exogeneity(endogenous)
    local ret_exogeneity "`r(exogeneity)'"
    local ret_conclusion "`r(conclusion)'"
    scalar ret_bounds_lower = r(bounds_lower)
    scalar ret_bounds_upper = r(bounds_upper)
    log close diag

    assert "`ret_exogeneity'" == "endogenous"
    assert "`ret_conclusion'" == "bounds"
    assert abs(ret_bounds_lower - 4) < 1e-12
    assert abs(ret_bounds_upper - 7) < 1e-12

    tempname fh
    file open `fh' using "`diaglog'", read text
    local found_suppress_note = 0
    local found_sampling_share = 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "Sampling/artifact shares are not displayed") > 0 {
            local found_suppress_note = 1
        }
        if strpos(`"`line'"', "Sampling share:") > 0 {
            local found_sampling_share = 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found_suppress_note' == 1
    assert `found_sampling_share' == 0
}
if _rc == 0 {
    display as result "  PASS: D2 - endogenous mode displays bounds and suppresses shares"
    local ++pass_count
}
else {
    display as error "  FAIL: D2 - endogenous display contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D2"
}

local ++test_count
capture noisily {
    _diag_known_triplet
    iivw_diagnose x, unweighted(D_unweighted) weighted(D_weighted) ///
        adjusted(D_adjusted) estimand(contrast)
    assert missing(r(sampling_share))
    assert missing(r(artifact_share))
    assert "`r(conclusion)'" == "movement_only"
    assert "`r(estimand)'" == "contrast"
}
if _rc == 0 {
    display as result "  PASS: D3 - contrast estimand suppresses share returns"
    local ++pass_count
}
else {
    display as error "  FAIL: D3 - contrast share suppression (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D3"
}

local ++test_count
capture noisily {
    _diag_known_triplet
    set varabbrev on
    iivw_diagnose x, unweighted(D_unweighted) weighted(D_weighted) ///
        adjusted(D_adjusted)
    assert "`c(varabbrev)'" == "on"
    capture noisily iivw_diagnose x, unweighted(D_unweighted) ///
        weighted(D_weighted) adjusted(D_adjusted) exogeneity(invalid)
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: D4 - iivw_diagnose restores varabbrev on success and error"
    local ++pass_count
}
else {
    display as error "  FAIL: D4 - diagnose varabbrev restoration (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D4"
    capture set varabbrev off
}

**# iivw_fit oracles

local ++test_count
capture noisily {
    _fit_oracle_data
    iivw_fit y x z, unweighted id(id) time(t) timespec(linear) nolog
    scalar fit_b_x = _b[x]
    scalar fit_b_z = _b[z]
    scalar fit_b_t = _b[t]
    scalar fit_se_x = _se[x]
    scalar fit_se_z = _se[z]
    scalar fit_se_t = _se[t]
    assert "`e(iivw_cmd)'" == "iivw_fit"
    assert "`e(iivw_weighttype)'" == "unweighted"
    assert "`e(iivw_unweighted)'" == "1"
    assert "`e(iivw_id)'" == "id"
    assert "`e(iivw_time)'" == "t"

    glm y x z t, family(gaussian) link(identity) vce(cluster id) nolog
    assert reldif(fit_b_x, _b[x]) < 1e-12
    assert reldif(fit_b_z, _b[z]) < 1e-12
    assert reldif(fit_b_t, _b[t]) < 1e-12
    assert reldif(fit_se_x, _se[x]) < 1e-10
    assert reldif(fit_se_z, _se[z]) < 1e-10
    assert reldif(fit_se_t, _se[t]) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: D5 - iivw_fit unweighted matches direct glm oracle"
    local ++pass_count
}
else {
    display as error "  FAIL: D5 - unweighted fit oracle (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D5"
}

local ++test_count
capture noisily {
    _fit_oracle_data
    set varabbrev on
    iivw_fit y x z, unweighted id(id) time(t) timespec(linear) nolog
    assert "`c(varabbrev)'" == "on"
    capture noisily iivw_fit y x z, unweighted id(id) time(t) ///
        timespec(bad) nolog
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: D6 - iivw_fit restores varabbrev on success and error"
    local ++pass_count
}
else {
    display as error "  FAIL: D6 - fit varabbrev restoration (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D6"
    capture set varabbrev off
}

**# Summary

capture log close _all
display as result "Diagnostic known-answer validation: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_iivw_diagnostics_known_answers tests=`test_count' pass=`pass_count' fail=`fail_count'"
    display as error "Failed tests:`failed_tests'"
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: validation_iivw_diagnostics_known_answers tests=`test_count' pass=`pass_count' fail=`fail_count'"
