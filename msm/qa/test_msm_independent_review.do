* test_msm_independent_review.do
*
* Independent-review regressions for the 2026-07-17 audit remediation.
* These probes target false-green paths found while reviewing A01-A06 and A10.

version 16.0
clear all
set more off
set varabbrev off

capture log close _all
log using "test_msm_independent_review.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as text ""
display as text "{hline 72}"
display as result "msm independent-review regressions"
display as text "{hline 72}"

* --- IR1: clear all must not make a UUID repeat in the same process ----------
local ++test_count
capture noisily {
    _msm_uuid
    local uuid1 "`r(uuid)'"
    clear all
    _msm_uuid
    local uuid2 "`r(uuid)'"
    assert "`uuid1'" != "`uuid2'"
}
if _rc == 0 {
    display as result "PASS IR1: UUID remains unique across clear all"
    local ++pass_count
}
else {
    display as error "FAIL IR1: UUID repeated across clear all (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' IR1"
}

* IR1 deliberately runs clear all, which removes user-defined programs. Define
* the shared panel helpers only after that state-survival probe.
capture program drop _ir_panel
program define _ir_panel
    version 16.0
    syntax [, N(integer 100) PERIODS(integer 4) SEED(integer 20260717)]

    clear
    set seed `seed'
    quietly set obs `n'
    gen long pid = _n
    gen double v = rnormal()
    quietly expand `periods'
    bysort pid: gen int per = _n - 1
    gen byte trt = runiform() < invlogit(-0.2 + 0.35 * v + 0.12 * per)
    bysort pid (per): gen byte lag_trt = cond(_n == 1, 0, trt[_n-1])
    gen byte outc = runiform() < invlogit(-3.2 + 0.35 * trt + 0.15 * per)
    gen byte cens = 0
    bysort pid (per): replace outc = 0 if sum(outc[_n-1]) > 0
    sort pid per
end

capture program drop _ir_fit
program define _ir_fit
    version 16.0
    syntax [, SEED(integer 20260717)]

    _ir_panel, seed(`seed')
    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) ///
        censor(cens) covariates(v)
    msm_weight, treat_d_cov(v) probpolicy(clip) clip(0.001) nolog
    msm_fit, model(logistic) nolog
end

* --- IR2: a preparation without an artifact UUID is not valid ----------------
local ++test_count
capture noisily {
    _ir_panel, seed(201)
    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) ///
        censor(cens) covariates(v)
    char _dta[_msm_prep_uuid]
    capture noisily _msm_verify prepare
    local verify_rc = _rc
    assert `verify_rc' == 0
    assert r(ok) == 0
}
if _rc == 0 {
    display as result "PASS IR2: UUID-less preparation rejected without verifier error"
    local ++pass_count
}
else {
    display as error "FAIL IR2: UUID-less preparation accepted or verifier errored (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' IR2"
}

* --- IR3: forged per-variable ownership tokens never authorize deletion ------
local ++test_count
capture noisily {
    _ir_panel, seed(301)
    gen double _msm_weight = 42
    char _msm_weight[_msm_owner] "foreign-token"

    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) ///
        censor(cens) covariates(v)

    confirm variable _msm_weight
    quietly summarize _msm_weight, meanonly
    assert r(min) == 42 & r(max) == 42
    _msm_own owned _msm_weight
    assert r(owned) == 0
}
if _rc == 0 {
    display as result "PASS IR3: forged owner token cannot delete user data"
    local ++pass_count
}
else {
    display as error "FAIL IR3: forged owner token authorized deletion (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' IR3"
}

* --- IR4: a failed fit leaves no unowned basis variable and is retryable ------
local ++test_count
capture noisily {
    _ir_panel, seed(401)
    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) ///
        censor(cens) covariates(v)
    msm_weight, treat_d_cov(v) nolog
    gen byte constant_exposure = 1

    capture msm_fit, model(logistic) exposure(constant_exposure) nolog
    local bad_rc = _rc
    assert `bad_rc' != 0

    capture confirm variable _msm_period_sq
    assert _rc != 0
    drop constant_exposure
    msm_fit, model(logistic) nolog
    _msm_verify fit, nohydrate
    assert r(ok) == 1
}
if _rc == 0 {
    display as result "PASS IR4: fit-error path is mutation-free and immediately retryable"
    local ++pass_count
}
else {
    display as error "FAIL IR4: failed fit leaked basis state or blocked retry (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' IR4"
}

* --- IR5: fitted b must be exactly 1 x k --------------------------------------
local ++test_count
capture noisily {
    _ir_fit, seed(501)
    tempname b badb
    matrix `b' = _msm_fit_b
    matrix `badb' = `b' \ `b'
    local fit_uuid : char _dta[_msm_fit_uuid]
    _msm_mat_save `badb', key(_msm_fit_b) token(`fit_uuid')

    capture noisily _msm_verify fit, nohydrate
    local verify_rc = _rc
    assert `verify_rc' == 0
    assert r(ok) == 0
    assert "`r(why)'" == "dims"
}
if _rc == 0 {
    display as result "PASS IR5: 2 x k coefficient artifact rejected"
    local ++pass_count
}
else {
    display as error "FAIL IR5: malformed coefficient shape accepted (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' IR5"
}

* --- IR6: b/V equation identities must agree ---------------------------------
local ++test_count
capture noisily {
    _ir_fit, seed(601)
    local k = colsof(_msm_fit_b)
    local alien_eq ""
    forvalues j = 1/`k' {
        local alien_eq "`alien_eq' alien"
    }
    local alien_eq : list retokenize alien_eq
    char _dta[_msm_fit_b_ce] "`alien_eq'"

    capture noisily _msm_verify fit, nohydrate
    local verify_rc = _rc
    assert `verify_rc' == 0
    assert r(ok) == 0
    assert "`r(why)'" == "dims"
}
if _rc == 0 {
    display as result "PASS IR6: mismatched b/V equation identities rejected"
    local ++pass_count
}
else {
    display as error "FAIL IR6: mismatched equation identities accepted (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' IR6"
}

* --- IR7: malformed serialized headers are data errors, not verifier crashes --
local ++test_count
capture noisily {
    _ir_fit, seed(701)
    char _dta[_msm_fit_b_r] "bogus"

    capture noisily _msm_verify fit, nohydrate
    local verify_rc = _rc
    assert `verify_rc' == 0
    assert r(ok) == 0
}
if _rc == 0 {
    display as result "PASS IR7: malformed matrix header rejected without verifier error"
    local ++pass_count
}
else {
    display as error "FAIL IR7: malformed matrix header crashed or passed verifier (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' IR7"
}

* --- IR8: model/spec metadata is part of the signed weight artifact -----------
local ++test_count
capture noisily {
    _ir_panel, seed(801)
    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) ///
        censor(cens) covariates(v)
    msm_weight, treat_d_cov(v) treat_n_cov(v) nolog

    char _dta[_msm_numer_covars] ""
    char _dta[_msm_treat_n_cov] ""
    _msm_verify weight
    assert r(ok) == 0
}
if _rc == 0 {
    display as result "PASS IR8: tampered numerator contract invalidates weighting"
    local ++pass_count
}
else {
    display as error "FAIL IR8: unsigned numerator metadata remained authorized (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' IR8"
}

* --- IR9: cluster values used by the fit are covered by freshness checks ------
local ++test_count
capture noisily {
    _ir_panel, seed(901)
    gen long cluster_id = pid
    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) ///
        censor(cens) covariates(v)
    msm_weight, treat_d_cov(v) nolog
    msm_fit, model(logistic) cluster(cluster_id) nolog
    replace cluster_id = 999999 in 1

    _msm_verify fit, nohydrate
    assert r(ok) == 0
    assert "`r(why)'" == "edited"
}
if _rc == 0 {
    display as result "PASS IR9: edited cluster mapping invalidates fitted variance"
    local ++pass_count
}
else {
    display as error "FAIL IR9: edited cluster mapping remained authorized (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' IR9"
}

* --- IR10: intermittent missingness is not a time-fixed covariate -------------
local ++test_count
capture noisily {
    _ir_panel, seed(1001)
    replace v = . if pid == 1 & per == 2
    capture msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) ///
        censor(cens) baseline_covariates(v)
    local prep_rc = _rc
    assert `prep_rc' == 198

    _ir_panel, seed(1002)
    replace v = . if pid == 1 & per == 2
    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) ///
        censor(cens) covariates(v)
    capture msm_weight, treat_d_cov(v) treat_n_cov(v) nolog
    local weight_rc = _rc
    assert `weight_rc' == 198

    _ir_panel, seed(1003)
    replace v = . if pid == 1 & per == 2
    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) ///
        censor(cens) covariates(v)
    msm_weight, treat_d_cov(v) probpolicy(clip) clip(0.01) nolog
    capture msm_fit, model(logistic) outcome_cov(v) nolog
    local fit_rc = _rc
    assert `fit_rc' == 198
}
if _rc == 0 {
    display as result "PASS IR10: all time-fixed contracts reject intermittent missingness"
    local ++pass_count
}
else {
    display as error "FAIL IR10: intermittent missingness passed a time-fixed contract (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' IR10"
}

* --- IR11: re-prepare clears all A10 weighting metadata -----------------------
local ++test_count
capture noisily {
    _ir_panel, seed(1101)
    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) ///
        censor(cens) covariates(v)
    msm_weight, treat_d_cov(v) treat_n_cov(v) nolog
    assert "`: char _dta[_msm_numer_covars]'" == "v"

    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) ///
        censor(cens) covariates(v)
    assert "`: char _dta[_msm_treat_n_cov]'" == ""
    assert "`: char _dta[_msm_censor_n_cov]'" == ""
    assert "`: char _dta[_msm_numer_covars]'" == ""
    assert "`: char _dta[_msm_historymsm]'" == ""
}
if _rc == 0 {
    display as result "PASS IR11: re-prepare clears numerator-contract metadata"
    local ++pass_count
}
else {
    display as error "FAIL IR11: stale A10 metadata survived re-prepare (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' IR11"
}

* --- IR12: serializer round-trips immediately below/above 40,000 chars --------
local ++test_count
capture noisily {
    clear
    set matsize 2500
    tempname below above below2 above2
    matrix `below' = J(1, 1818, 1/3)
    matrix `above' = J(1, 1819, c(pi))

    _msm_mat_save `below', key(_ir_below)
    assert r(nchunks) == 1
    _msm_mat_load `below2', key(_ir_below)
    assert r(ok) == 1
    assert mreldif(`below', `below2') == 0

    _msm_mat_save `above', key(_ir_above)
    assert r(nchunks) == 2
    _msm_mat_load `above2', key(_ir_above)
    assert r(ok) == 1
    assert mreldif(`above', `above2') == 0
}
if _rc == 0 {
    display as result "PASS IR12: matrix chunks round-trip on both sides of boundary"
    local ++pass_count
}
else {
    display as error "FAIL IR12: matrix chunk boundary round-trip (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' IR12"
}

* --- IR13: a committed weighting remains in the ownership inventory ---------
local ++test_count
capture noisily {
    _ir_panel, seed(1301)
    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) ///
        censor(cens) covariates(v)
    msm_weight, treat_d_cov(v) nolog

    _msm_own inventory
    local owned "`r(vars)'"
    foreach artifact in _msm_weight _msm_tw_weight _msm_ps {
        assert `: list artifact in owned'
        _msm_own owned `artifact'
        assert r(owned) == 1
    }

    msm_weight, treat_d_cov(v) replace nolog
    _msm_own inventory
    local owned "`r(vars)'"
    foreach artifact in _msm_weight _msm_tw_weight _msm_ps {
        assert `: list artifact in owned'
    }
}
if _rc == 0 {
    display as result "PASS IR13: weight commit preserves its ownership inventory"
    local ++pass_count
}
else {
    display as error "FAIL IR13: committed weights disappeared from ownership inventory (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' IR13"
}

* --- IR14: refitting to a simpler period form removes prior owned bases ------
local ++test_count
capture noisily {
    _ir_fit, seed(1401)
    msm_fit, model(logistic) period_spec(cubic) nolog
    confirm variable _msm_period_sq
    confirm variable _msm_period_cu

    msm_fit, model(logistic) period_spec(none) nolog
    capture confirm variable _msm_period_sq
    assert _rc != 0
    capture confirm variable _msm_period_cu
    assert _rc != 0

    msm_fit, model(logistic) period_spec(ns(3)) nolog
    confirm variable _msm_per_ns1
    confirm variable _msm_per_ns2
    confirm variable _msm_per_ns3

    msm_fit, model(logistic) period_spec(linear) nolog
    foreach artifact in _msm_per_ns1 _msm_per_ns2 _msm_per_ns3 {
        capture confirm variable `artifact'
        assert _rc != 0
    }
    _msm_verify fit, nohydrate
    assert r(ok) == 1
}
if _rc == 0 {
    display as result "PASS IR14: successful refits remove obsolete owned basis variables"
    local ++pass_count
}
else {
    display as error "FAIL IR14: refit left stale basis variables (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' IR14"
}

* --- IR15: missing equation metadata is a corrupt matrix header --------------
local ++test_count
capture noisily {
    _ir_fit, seed(1501)
    foreach key in _msm_fit_b _msm_fit_V {
        char _dta[`key'_re]
        char _dta[`key'_ce]
    }

    capture noisily _msm_verify fit, nohydrate
    local verify_rc = _rc
    assert `verify_rc' == 0
    assert r(ok) == 0
}
if _rc == 0 {
    display as result "PASS IR15: missing equation metadata invalidates fit artifacts"
    local ++pass_count
}
else {
    display as error "FAIL IR15: equation-less matrices remained authorized (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' IR15"
}

* --- IR16: a narrower matrix replacement clears obsolete payload chunks ------
local ++test_count
capture noisily {
    clear
    tempname wide narrow loaded
    matrix `wide' = J(1, 1819, c(pi))
    matrix `narrow' = J(1, 12, 1/7)

    _msm_mat_save `wide', key(_ir_reuse)
    assert r(nchunks) == 2
    assert "`: char _dta[_ir_reuse_d2]'" != ""

    _msm_mat_save `narrow', key(_ir_reuse)
    assert r(nchunks) == 1
    assert "`: char _dta[_ir_reuse_d2]'" == ""
    _msm_mat_load `loaded', key(_ir_reuse)
    assert r(ok) == 1
    assert mreldif(`narrow', `loaded') == 0
}
if _rc == 0 {
    display as result "PASS IR16: narrower replacements clear obsolete matrix chunks"
    local ++pass_count
}
else {
    display as error "FAIL IR16: stale matrix payload chunks survived replacement (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' IR16"
}

* --- IR17: matrix cleanup removes corrupt, gapped payload tails --------------
local ++test_count
capture noisily {
    clear
    char _dta[_ir_gap_d1] "head"
    char _dta[_ir_gap_d100] "orphaned-tail"
    char _dta[_ir_gap_nk] "1"

    _msm_mat_clear, key(_ir_gap)
    assert "`: char _dta[_ir_gap_d1]'" == ""
    assert "`: char _dta[_ir_gap_d100]'" == ""
    assert "`: char _dta[_ir_gap_nk]'" == ""

    tempname one
    matrix `one' = J(1, 1, 1)
    char _dta[_ir_gap_d100] "orphaned-tail"
    _msm_mat_save `one', key(_ir_gap)
    assert "`: char _dta[_ir_gap_d100]'" == ""
}
if _rc == 0 {
    display as result "PASS IR17: clear and replacement remove gapped matrix tails"
    local ++pass_count
}
else {
    display as error "FAIL IR17: gapped matrix payload survived cleanup (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' IR17"
}

* --- Summary ------------------------------------------------------------------
local qa_status = cond(`fail_count' > 0, "FAIL", "PASS")
display as text ""
display as text "RESULT: test_msm_independent_review tests=`test_count' pass=`pass_count' fail=`fail_count' status=`qa_status'"
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
}

capture log close
if `fail_count' > 0 exit 1
