* test_iivw_v341_regressions.do
* Regression coverage for the inference-evidence defects fixed in 3.4.1:
*   T1  bare FIPTIW stays point-only at 600 clusters for Gaussian/identity
*   T2  non-identity links cannot inherit identity-link clearance
*   T3  explicit vce(stacked) remains available and explicitly uncleared
*   T4  the bare-call message does not contradict the returned inference
*   T5  README vce() syntax includes the explicit stacked method
*
* T1, T2, T4, and T5 fail on the released 3.4.0 files. T3 is the positive
* control: retracting an unsupported default must not remove the paper-grounded
* analytic variance from explicit use.

clear all
set varabbrev off
version 16.0

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"

**# Fixture

capture program drop _iivw_v341_panel
program define _iivw_v341_panel
    version 16.0
    clear
    set seed 20260810
    set obs 600
    gen long id = _n
    gen double z = rnormal()
    gen byte a = runiform() < invlogit(-0.2 + 0.4 * z)
    expand 3
    bysort id: gen byte visit = _n
    gen double t = (visit - 1) * 30 + id / 100000
    gen double y = 1 + 0.6 * a + 0.3 * z + rnormal()
    gen byte ybin = runiform() < invlogit(-0.5 + 0.7 * a + 0.2 * z)
    gen long ycount = rpoisson(exp(-0.5 + 0.3 * a + 0.1 * z))
    bysort id (t): egen double fu = max(t)
    replace fu = fu + 30
    quietly iivw_weight, id(id) time(t) visit_cov(z) treat(a) ///
        treat_cov(z) wtype(fiptiw) censor(fu) scores nolog
end

capture program drop _iivw_v341_count_phrase
program define _iivw_v341_count_phrase, rclass
    version 16.0
    syntax , File(string) PHrase(string)
    mata: _v341t = stritrim(subinstr(invtokens(cat(st_local("file"))', " "), char(9), " "))
    mata: _v341p = st_local("phrase")
    mata: st_local("v341n", strofreal((strlen(_v341t) - strlen(subinstr(_v341t, _v341p, "", .))) / strlen(_v341p)))
    mata: mata drop _v341t _v341p
    return scalar n = `v341n'
end

capture program drop _iivw_v341_readme_vce
program define _iivw_v341_readme_vce, rclass
    version 16.0
    syntax , File(string)
    mata: _v341r = cat(st_local("file"))
    mata: _v341m = select(_v341r, strpos(_v341r, "Weight-type dependent") :> 0)
    mata: st_local("v341rows", strofreal(rows(_v341m)))
    mata: st_local("v341stacked", strofreal(sum(strpos(_v341m, "stacked") :> 0)))
    mata: mata drop _v341r _v341m
    return scalar table_rows = `v341rows'
    return scalar stacked_rows = `v341stacked'
end

**# T1: 600 clusters do not promote an exploratory screen to a default

local ++test_count
capture noisily {
    _iivw_v341_panel
    quietly iivw_fit y a z, timespec(none) nolog
    assert "`e(iivw_inference_status)'" == "point-only-no-valid-interval"
    assert "`e(iivw_vce)'" == "none"
    assert e(iivw_interval_available) == 0
    assert "`e(properties)'" == "b"
    capture confirm matrix e(V)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: T1 - bare Gaussian FIPTIW remains point-only"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - bare Gaussian FIPTIW default (error `=_rc')"
    local ++fail_count
    local failed "`failed' T1"
}

**# T2: non-identity links cannot inherit identity-link evidence

local ++test_count
capture noisily {
    _iivw_v341_panel
    quietly iivw_fit ybin a z, family(binomial) link(logit) ///
        timespec(none) nolog
    assert "`e(iivw_inference_status)'" == "point-only-no-valid-interval"
    assert "`e(iivw_vce)'" == "none"
    assert e(iivw_interval_available) == 0
    assert "`e(properties)'" == "b"

    _iivw_v341_panel
    quietly iivw_fit ycount a z, family(poisson) link(log) ///
        timespec(none) nolog
    assert "`e(iivw_inference_status)'" == "point-only-no-valid-interval"
    assert "`e(iivw_vce)'" == "none"
    assert e(iivw_interval_available) == 0
    assert "`e(properties)'" == "b"
}
if _rc == 0 {
    display as result "  PASS: T2 - logit/Poisson FIPTIW receive no unsupported clearance"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - non-identity clearance boundary (error `=_rc')"
    local ++fail_count
    local failed "`failed' T2"
}

**# T3: explicit stacked inference remains available but uncleared

local ++test_count
capture noisily {
    _iivw_v341_panel
    quietly iivw_fit y a z, timespec(none) vce(stacked) nolog
    assert "`e(iivw_inference_status)'" == "uncleared-stacked-analytic"
    assert "`e(iivw_vce)'" == "stacked"
    assert e(iivw_interval_available) == 1
    assert "`e(properties)'" == "b V"
    assert e(iivw_stacked_nclust) == 600
}
if _rc == 0 {
    display as result "  PASS: T3 - explicit stacked inference remains available"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - explicit stacked inference (error `=_rc')"
    local ++fail_count
    local failed "`failed' T3"
}

**# T4: bare-call messaging agrees with point-only output

local ++test_count
capture noisily {
    _iivw_v341_panel
    tempfile fitlog
    log using "`fitlog'", replace text name(v341fit)
    iivw_fit ybin a z, family(binomial) link(logit) timespec(none) nolog
    log close v341fit

    _iivw_v341_count_phrase, file("`fitlog'") ///
        phrase("FIPTIW inference: returning point estimates only")
    assert r(n) == 1
    _iivw_v341_count_phrase, file("`fitlog'") ///
        phrase("citype(none) is a nominal, empirically uncleared interval")
    assert r(n) == 0
    _iivw_v341_count_phrase, file("`fitlog'") ///
        phrase("The stacked sandwich is calibrated at n>=600")
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: T4 - bare-call message matches point-only output"
    local ++pass_count
}
else {
    local t4_rc = _rc
    capture log close v341fit
    display as error "  FAIL: T4 - bare-call inference message (error `t4_rc')"
    local ++fail_count
    local failed "`failed' T4"
}

**# T5: README documents every accepted vce() method

local ++test_count
capture noisily {
    _iivw_v341_readme_vce, file("`pkg_dir'/README.md")
    assert r(table_rows) == 1
    assert r(stacked_rows) == 1
}
if _rc == 0 {
    display as result "  PASS: T5 - README vce() table includes stacked"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - README vce() syntax table (error `=_rc')"
    local ++fail_count
    local failed "`failed' T5"
}

**# Summary

capture log close _all
iivw_qa_summary, name(test_iivw_v341_regressions) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests("`failed'")
