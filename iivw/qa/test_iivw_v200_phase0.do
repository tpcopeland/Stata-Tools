clear all
set more off
version 16.0
set varabbrev off

* test_iivw_v200_phase0.do
*
* v2.0.0 Phase 0 regressions: data integrity and convergence.
*
* Every test here reproduces a defect confirmed in the 2026-07-12 comprehensive
* audit (_take_action/iivw_clarity.md) and independently re-verified in
* iivw_clarity_claude.md. Each one FAILS on v1.9.7 and must pass on v2.0.0.
*
*   C3  replace / generated-name collisions destroy scientific inputs
*       C3-1 iivw_weight   output name collides with a visit_cov() predictor
*       C3-2 iivw_fit      generated time name collides with a predictor
*       C3-3 iivw_exogtest generated lag name collides with an input varlist term
*       C3-4 a failed rerun destroys the prior valid weights (no rollback)
*   C4  a long generate() prefix collapses two categorical levels onto one
*       32-char dummy name, pooling a level into the base category with rc 0
*   C9  a nonconverged model is accepted and stamped as a successful fit
*       (per the audit verification, the GEE/iterate(0) probe does NOT
*       reproduce -- glm reports e(converged)=1 -- so this uses model(mixed))

capture log close
* Q6: no disposable log in the package tree. This suite used to write
* test_iivw_v200_phase0.log into qa/, which is gitignored but is still ~4 MB of debris carrying the
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

**# Bootstrap

local qa_dir "`c(pwd)'"
local pkg_dir = substr("`qa_dir'", 1, strlen("`qa_dir'") - strlen("/qa"))

do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap, pkgdir("`pkg_dir'")

* Seeded panel builder: n subjects x k visits, informative visit covariate.
capture program drop _v200_panel
program define _v200_panel
    syntax , [N(integer 40) K(integer 4) SEED(integer 20260713)]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long pid = _n
    gen double z = rnormal()
    gen byte trt = (runiform() < invlogit(0.5 * z))
    quietly expand `k'
    bysort pid: gen double vtime = _n
    gen double y = 1 + 0.5 * z + 0.3 * vtime + rnormal()
    quietly compress
end

**# C3-1: iivw_weight must not destroy a visit_cov() predictor it would overwrite

local ++test_count
capture noisily {
    _v200_panel
    * With generate(x) the weight output is named `xweight'. Name a *predictor*
    * xweight: the output name now collides with a scientific input.
    gen double xweight = z + 0.1 * vtime
    tempvar snap
    quietly gen double `snap' = xweight

    capture noisily iivw_weight, endatlastvisit baseline(event) id(pid) time(vtime) visit_cov(xweight) ///
        generate(x) replace
    local got_rc = _rc

    * The predictor must still exist and be byte-for-byte unchanged, whatever
    * the command decided to do. v1.9.7 drops it at :369-379 before the Cox
    * model reads it, then exits rc 111 leaving it deleted.
    capture confirm variable xweight
    if _rc {
        display as error "C3-1 FAIL: iivw_weight DELETED the predictor xweight"
        error 9
    }
    capture assert xweight == `snap'
    if _rc {
        display as error "C3-1 FAIL: iivw_weight OVERWROTE the predictor xweight"
        error 9
    }
    * A collision between an output name and a scientific input is not
    * something `replace' may authorize: it must be rejected outright.
    if `got_rc' != 198 {
        display as error "C3-1 FAIL: expected rc 198 (collision rejected), got rc `got_rc'"
        error 9
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: C3-1 iivw_weight rejects output/predictor name collision"
}
else {
    local ++fail_count
    display as error "FAIL: C3-1 iivw_weight output/predictor name collision"
}

**# C3-2: iivw_fit must not silently overwrite a predictor with a generated time term

local ++test_count
capture noisily {
    _v200_panel
    quietly iivw_weight, endatlastvisit baseline(event) id(pid) time(vtime) visit_cov(z) generate(x)

    * `xtime_sq' is the name iivw_fit generates for quadratic time under prefix x.
    * Hand it to the command as a genuine predictor.
    gen double xtime_sq = z * 2 + 1
    tempvar snap
    quietly gen double `snap' = xtime_sq

    capture noisily iivw_fit y xtime_sq, vce(fixed) timespec(quadratic) replace
    local got_rc = _rc

    capture confirm variable xtime_sq
    if _rc {
        display as error "C3-2 FAIL: iivw_fit DELETED the predictor xtime_sq"
        error 9
    }
    * v1.9.7 returns rc 0 here and silently replaces every value of the user's
    * xtime_sq with time^2, fitting a different model than the one requested.
    capture assert xtime_sq == `snap'
    if _rc {
        display as error "C3-2 FAIL: iivw_fit OVERWROTE the predictor xtime_sq with time^2"
        error 9
    }
    if `got_rc' != 198 {
        display as error "C3-2 FAIL: expected rc 198 (collision rejected), got rc `got_rc'"
        error 9
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: C3-2 iivw_fit rejects generated-time/predictor collision"
}
else {
    local ++fail_count
    display as error "FAIL: C3-2 iivw_fit generated-time/predictor collision"
}

**# C3-3: iivw_exogtest must not overwrite an input with its own generated lag

local ++test_count
capture noisily {
    _v200_panel
    * Under generate(x) the lag of `y' is named `xy_lag1'. Supply xy_lag1 as a
    * second tested variable: the generated name for term 1 IS input term 2.
    gen double xy_lag1 = z + 0.25 * vtime
    tempvar snap
    quietly gen double `snap' = xy_lag1

    capture noisily iivw_exogtest y xy_lag1, endatlastvisit id(pid) time(vtime) ///
        generate(x) replace
    local got_rc = _rc

    capture confirm variable xy_lag1
    if _rc {
        display as error "C3-3 FAIL: iivw_exogtest DELETED the input xy_lag1"
        error 9
    }
    * v1.9.7 returns rc 0, replaces xy_lag1 with lag(y), then lags *that*,
    * printing the second term as "y (lag 1) (lag 1)".
    capture assert xy_lag1 == `snap'
    if _rc {
        display as error "C3-3 FAIL: iivw_exogtest OVERWROTE the input xy_lag1 with lag(y)"
        error 9
    }
    if `got_rc' != 198 {
        display as error "C3-3 FAIL: expected rc 198 (collision rejected), got rc `got_rc'"
        error 9
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: C3-3 iivw_exogtest rejects generated-lag/input collision"
}
else {
    local ++fail_count
    display as error "FAIL: C3-3 iivw_exogtest generated-lag/input collision"
}

**# C3-4: a failed rerun must leave the prior valid weights intact

local ++test_count
capture noisily {
    _v200_panel

    * Establish a valid weighting state.
    quietly iivw_weight, endatlastvisit baseline(event) id(pid) time(vtime) visit_cov(z)
    confirm variable _iivw_iw
    confirm variable _iivw_weight
    tempvar snap_iw snap_w
    quietly gen double `snap_iw' = _iivw_iw
    quietly gen double `snap_w'  = _iivw_weight

    * Now force a failing rerun with replace: an all-missing visit covariate
    * gives the Cox model nothing to fit.
    gen double zbad = .
    capture noisily iivw_weight, endatlastvisit baseline(event) id(pid) time(vtime) visit_cov(zbad) replace
    local got_rc = _rc
    if `got_rc' == 0 {
        display as error "C3-4 FAIL: rerun with an all-missing covariate returned rc 0"
        error 9
    }

    * v1.9.7 drops _iivw_iw/_iivw_weight up front and can only drop, never
    * restore, on rollback -- so a failed rerun destroys the prior valid run.
    capture confirm variable _iivw_iw
    if _rc {
        display as error "C3-4 FAIL: failed rerun DESTROYED the prior valid _iivw_iw"
        error 9
    }
    capture confirm variable _iivw_weight
    if _rc {
        display as error "C3-4 FAIL: failed rerun DESTROYED the prior valid _iivw_weight"
        error 9
    }
    capture assert _iivw_iw == `snap_iw' & _iivw_weight == `snap_w'
    if _rc {
        display as error "C3-4 FAIL: failed rerun CHANGED the prior valid weights"
        error 9
    }
    * The dataset contract must still describe the surviving weights.
    local wv : char _dta[_iivw_weight_var]
    if "`wv'" != "_iivw_weight" {
        display as error "C3-4 FAIL: failed rerun left the contract stale (_iivw_weight_var='`wv'')"
        error 9
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: C3-4 failed rerun preserves prior valid weights and contract"
}
else {
    local ++fail_count
    display as error "FAIL: C3-4 failed rerun rollback"
}

**# C4: a maximum-length prefix must not collapse two categorical levels

local ++test_count
capture noisily {
    _v200_panel
    * Levels 0 / 1000 / 1001 with the longest accepted (23-char) prefix.
    * v1.9.7 builds `<23>cat_grp_1000' and `<23>cat_grp_1001', truncates both
    * to the same 32-char string `abcdefghijklmnopqrstuvwcat_grp_1', and with
    * replace silently overwrites the first dummy with the second: rc 0, level
    * 1000 pooled into the base, both rows labelled 1001.
    gen int grp = 0
    quietly replace grp = 1000 if mod(pid, 3) == 1
    quietly replace grp = 1001 if mod(pid, 3) == 2

    local pfx "abcdefghijklmnopqrstuvw"
    quietly iivw_weight, endatlastvisit baseline(event) id(pid) time(vtime) visit_cov(z) generate(`pfx')

    capture noisily iivw_fit y grp, vce(fixed) categorical(grp) basecat(0) replace
    local got_rc = _rc

    if `got_rc' != 0 {
        * A clean refusal with no mutation is also an acceptable contract, but
        * uniqueness IS achievable here, so a working fit is what we require.
        display as error "C4 FAIL: iivw_fit errored rc `got_rc' on a 23-char prefix"
        error 9
    }

    * Two non-base levels must produce two DISTINCT indicator variables, each
    * selecting exactly its own level.
    local cats : char _dta[_iivw_cat_vars]
    local n_cats : word count `cats'
    if `n_cats' != 2 {
        display as error "C4 FAIL: expected 2 dummies for levels {1000,1001}, got `n_cats' (`cats')"
        error 9
    }
    local d1 : word 1 of `cats'
    local d2 : word 2 of `cats'
    if "`d1'" == "`d2'" {
        display as error "C4 FAIL: both dummies share the name `d1'"
        error 9
    }

    * Each dummy must be an exact indicator for one distinct level.
    quietly count if `d1' == 1 & grp == 1000
    local n1_ok = r(N)
    quietly count if `d1' == 1
    local n1_all = r(N)
    quietly count if `d2' == 1 & grp == 1001
    local n2_ok = r(N)
    quietly count if `d2' == 1
    local n2_all = r(N)
    quietly count if grp == 1000
    local n_1000 = r(N)
    quietly count if grp == 1001
    local n_1001 = r(N)

    if `n1_ok' != `n_1000' | `n1_all' != `n_1000' {
        display as error "C4 FAIL: `d1' is not an exact indicator for grp==1000"
        error 9
    }
    if `n2_ok' != `n_1001' | `n2_all' != `n_1001' {
        display as error "C4 FAIL: `d2' is not an exact indicator for grp==1001"
        error 9
    }

    * And level 1000 must not have been silently pooled into the base.
    if `n_1000' == 0 {
        display as error "C4 FAIL: level 1000 vanished from the design matrix"
        error 9
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: C4 long prefix yields unique, exact categorical dummies"
}
else {
    local ++fail_count
    display as error "FAIL: C4 long-prefix categorical dummy collapse"
}

**# C9: a nonconverged model must not be accepted as a successful fit

local ++test_count
capture noisily {
    _v200_panel
    quietly iivw_weight, endatlastvisit baseline(event) id(pid) time(vtime) visit_cov(z)

    * mixedopts(iterate(0)) stops the optimizer before it converges. v1.9.7
    * returns rc 0, e(converged)=0, and stamps _dta[_iivw_fitted]=1.
    * (The audit cited geeopts(iterate(0)); that probe does not reproduce --
    * glm reports e(converged)=1 with iterate(0) -- so mixed is used here.)
    capture noisily iivw_fit y z, vce(fixed) model(mixed) experimentalmixed mixedopts(iterate(0))
    local got_rc = _rc

    if `got_rc' == 0 {
        display as error "C9 FAIL: nonconverged mixed fit returned rc 0"
        error 9
    }
    * No success metadata may survive a nonconverged fit.
    local fitted : char _dta[_iivw_fitted]
    if "`fitted'" == "1" {
        display as error "C9 FAIL: nonconverged fit stamped _dta[_iivw_fitted]=1"
        error 9
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: C9 nonconverged fit errors and posts no success metadata"
}
else {
    local ++fail_count
    display as error "FAIL: C9 nonconverged model accepted as successful"
}

**# Summary

display _newline as text "v2.0.0 Phase 0 regressions"
display as text "  tests:  " as result `test_count'
display as text "  passed: " as result `pass_count'
display as text "  failed: " as result `fail_count'

display "RESULT: iivw_v200_phase0 tests=`test_count' pass=`pass_count' fail=`fail_count'"

capture program drop _v200_panel

if `fail_count' > 0 {
    log close
    exit 1
}

log close
