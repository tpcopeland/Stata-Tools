* =============================================================================
* test_iivw_v190_regressions.do
* Regression tests for iivw v1.9.0:
*   - IIW component normalized to mean 1 (estimate/SE invariant)
*   - weighted model(mixed) fence note
*   - few-cluster inference note
* =============================================================================
clear all
set varabbrev off
version 16.0

capture log close
* Q6: no disposable log in the package tree. This suite used to write
* test_iivw_v190_regressions.log into qa/, which is gitignored but is still ~4 MB of debris carrying the
* local Stata license header, and the release hygiene gate had been taught to
* whitelist exactly these files. The batch invocation
* (`stata-mp -b do <suite>.do') already produces a readable log in the cwd, and
* run_all.log captures everything when the suite runs under the runner, so the
* named log was pure redundancy.
tempfile _suite_log
log using "`_suite_log'", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

* Bootstrap: derive package root from qa/ working directory
local qa_dir "`c(pwd)'"
* Sysdir sandbox + path resolution (Q3/Q8): the sandbox keeps this suite's
* net install out of the USER's real ado tree even when run standalone, and
* the "/qa" suffix is stripped by length, not by first-occurrence subinstr()
* (which mangles any path whose ancestors contain "qa").
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"
local repo_dir "`r(repo_dir)'"

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

* Helper: does a text log file contain a given substring?
capture program drop _iivw_log_has
program define _iivw_log_has, rclass
    version 16.0
    syntax using/, PATtern(string)
    tempname fh
    local found 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', `"`pattern'"') > 0 local found 1
        file read `fh' line
    }
    file close `fh'
    return scalar found = `found'
end

* Helper: build an irregular-visit panel with a chosen number of subjects
capture program drop _iivw_v190_panel
program define _iivw_v190_panel
    version 16.0
    syntax , NSUBJ(integer) [SEED(integer 20260701)]
    clear
    set seed `seed'
    set obs `=`nsubj' * 4'
    gen long id = ceil(_n / 4)
    bysort id: gen byte visit = _n
    gen double days = (visit - 1) * 90 + runiform() * 20
    replace days = 0 if visit == 1
    gen double edss_bl = 2 + 3 * runiform()
    bysort id: replace edss_bl = edss_bl[1]
    gen double age = 35 + 15 * runiform()
    bysort id: replace age = age[1]
    gen byte sex = runiform() > 0.5
    bysort id: replace sex = sex[1]
    gen byte treated = (runiform() < invlogit(-0.8 + 0.5 * edss_bl))
    bysort id: replace treated = treated[1]
    gen double edss = edss_bl + 0.012 * days - 0.7 * treated + rnormal(0, 0.45)
    gen byte relapse = (runiform() < invlogit(-2 + 0.4 * edss))
end

**# T1: IIW component normalized to mean 1

local ++test_count
capture noisily {
    _iivw_v190_panel, nsubj(80)
    iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(edss_bl age sex) ///
        lagvars(edss relapse) nolog
    * final IIW weight mean is exactly 1
    assert abs(r(mean_weight) - 1) < 1e-8
    * component variable itself averages 1 over nonmissing rows
    quietly summarize _iivw_iw if !missing(_iivw_iw), meanonly
    assert abs(r(mean) - 1) < 1e-8
    * FIPTIW: iw component mean 1 (final weight ~ mean of stabilized tw)
    iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(edss_bl age sex) ///
        lagvars(edss relapse) treat(treated) treat_cov(age sex edss_bl) ///
        replace nolog
    quietly summarize _iivw_iw if !missing(_iivw_iw), meanonly
    assert abs(r(mean) - 1) < 1e-8
}
if _rc == 0 {
    display as result "  PASS: T1 - IIW component normalized to mean 1"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - mean-1 normalization (error `=_rc')"
    local ++fail_count
}

**# T2: normalization is estimate- and robust-SE-invariant

local ++test_count
capture noisily {
    _iivw_v190_panel, nsubj(80)
    iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(edss_bl age sex) ///
        lagvars(edss relapse) nolog
    * A constant rescale of the weights must not move beta or the sandwich SE
    gen double w_scaled = _iivw_weight * 1000
    quietly glm edss treated edss_bl days [pw=_iivw_weight], ///
        family(gaussian) vce(cluster id)
    scalar b_norm = _b[treated]
    scalar se_norm = _se[treated]
    quietly glm edss treated edss_bl days [pw=w_scaled], ///
        family(gaussian) vce(cluster id)
    assert reldif(b_norm, _b[treated]) < 1e-10
    assert reldif(se_norm, _se[treated]) < 1e-10
    * iivw_fit (timespec(linear) adds the panel time term, matching the manual
    * glm covariate set {treated, edss_bl, days}) reproduces the coefficient
    iivw_fit edss treated edss_bl, vce(fixed) model(gee) timespec(linear) nolog
    assert reldif(_b[treated], b_norm) < 1e-8
}
if _rc == 0 {
    display as result "  PASS: T2 - beta and robust SE invariant to weight scale"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - scale invariance (error `=_rc')"
    local ++fail_count
}

**# T3: few-cluster note fires <40, absent >=40 and under bootstrap()

* Explicit .log path: `log using file, text` assumes a .log extension when the
* name has none, so an extensionless tempfile would not match on read-back.
local capf "`c(tmpdir)'/iivw_v190_cap.log"
local ++test_count
capture noisily {
    * 20 clusters -> note present
    _iivw_v190_panel, nsubj(20)
    iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(edss_bl age sex) nolog
    capture log close iivwcap
    log using "`capf'", replace text name(iivwcap)
    iivw_fit edss treated edss_bl, vce(fixed) model(gee) timespec(linear) nolog
    log close iivwcap
    _iivw_log_has using "`capf'", pattern("cluster-robust SEs can be")
    assert r(found) == 1

    * 60 clusters -> note absent
    _iivw_v190_panel, nsubj(60)
    iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(edss_bl age sex) nolog
    capture log close iivwcap
    log using "`capf'", replace text name(iivwcap)
    iivw_fit edss treated edss_bl, vce(fixed) model(gee) timespec(linear) nolog
    log close iivwcap
    _iivw_log_has using "`capf'", pattern("cluster-robust SEs can be")
    assert r(found) == 0

    * 20 clusters but bootstrap() -> block skipped, note absent
    _iivw_v190_panel, nsubj(20)
    iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(edss_bl age sex) nolog
    capture log close iivwcap
    log using "`capf'", replace text name(iivwcap)
    iivw_fit edss treated edss_bl, model(gee) timespec(linear) bootstrap(20) nolog
    log close iivwcap
    _iivw_log_has using "`capf'", pattern("cluster-robust SEs can be")
    assert r(found) == 0
}
local t3rc = _rc
capture log close iivwcap
if `t3rc' == 0 {
    display as result "  PASS: T3 - few-cluster note fires <40, absent otherwise"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - few-cluster note (error `=_rc')"
    local ++fail_count
}

**# T4: weighted model(mixed) is GATED (2.0.0); the note fires once acknowledged
*
* Before 2.0.0 this fence was only a `note:'. A note does not stop anyone, and
* the variance components it warns about print immediately below it looking as
* authoritative as anything else. 2.0.0 requires experimentalmixed instead, so
* this test now pins the gate as well as the note.

local ++test_count
if c(stata_version) >= 17 {
    capture noisily {
        _iivw_v190_panel, nsubj(80)
        iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(edss_bl age sex) nolog

        * weighted mixed WITHOUT the acknowledgment -> hard error, no fit
        capture iivw_fit edss treated edss_bl, vce(fixed) model(mixed) timespec(linear) nolog
        assert _rc == 198

        * weighted mixed WITH the acknowledgment -> fits, and the note fires
        capture log close iivwcap
        log using "`capf'", replace text name(iivwcap)
        iivw_fit edss treated edss_bl, vce(fixed) model(mixed) timespec(linear) ///
            experimentalmixed nolog
        log close iivwcap
        _iivw_log_has using "`capf'", pattern("consistently weight-estimated")
        assert r(found) == 1

        * unweighted mixed -> no gate, no note
        capture log close iivwcap
        log using "`capf'", replace text name(iivwcap)
        iivw_fit edss treated edss_bl, model(mixed) timespec(linear) ///
            unweighted id(id) time(days) nolog
        log close iivwcap
        _iivw_log_has using "`capf'", pattern("consistently weight-estimated")
        assert r(found) == 0
    }
    local t4rc = _rc
    capture log close iivwcap
    if `t4rc' == 0 {
        display as result "  PASS: T4 - weighted mixed gated; note fires once acknowledged; unweighted clean"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T4 - mixed fence note (error `=_rc')"
        local ++fail_count
    }
}
else {
    display as text "  SKIP: T4 - model(mixed) requires Stata 17+"
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_iivw_v190_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_iivw_v190_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
