* test_iivw_v413_regressions.do
* Regression coverage for the two defects confirmed in the 2026-09-04 4.1.2
* error report. Both were invisible to every green suite that preceded them.
*
*   T1  vce(stacked) Wald endpoints are formed from the POSTED covariance
*   T2  the same identity holds at a second confidence level
*   T3  the printed interval agrees with the ereturn display replay
*   T4  a finite edit to a saved score column is refused
*   T5  a finite edit to a saved derivative column is refused
*   T6  an edited inverse-information metadata string is refused
*   T7  an untouched contract still passes, so T4-T6 are not blanket refusal
*
* C1: the interval matrices were built before vce(stacked) replaced e(V), so a
* stacked fit printed and stored fixed-weight Wald limits alongside stacked
* standard errors and p-values. Observed on clean data: stored ll 0.58723462
* against 0.60648534 from the posted SE.
*
* I1: _iivw_weight_signature bound the raw inputs and weight columns but not
* the ndN/nsN influence-function columns or the score metadata. Multiplying
* every _iivw_nsN column by 100 left _iivw_check_weighted and iivw_fit both at
* rc 0 while the stacked treatment SE moved from 0.0896 to 4.098. The fixed-
* sandwich self-check inside iivw_fit compares FIXED covariances and stayed at
* 1.5e-16 throughout, so it could not see it.

clear all
set varabbrev off
version 16.0

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed ""

local qa_dir "`c(pwd)'"
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"

* The error report's own fixture, reproduced exactly: the RNG draws that are
* never used in the fit are kept so the panel is bit-identical to the one the
* quoted numbers came from.
capture program drop _iivw_v413_panel
program define _iivw_v413_panel
    version 16.0
    clear
    set seed 4713
    set obs 200
    gen long id = _n
    gen double k1 = rnormal()
    gen double z1 = rnormal()
    gen byte a = runiform() < invlogit(.8*k1)
    expand 6
    bysort id: gen int j = _n
    gen double t = j
    gen double y = 1 + .5*a + .4*z1 + .3*k1 + .1*t + rnormal()
    gen byte ybin = runiform() < invlogit(-.2 + .5*a + .3*z1)
    gen int ycnt = rpoisson(exp(.1 + .3*a + .2*z1))
    gen double keeppr = invlogit(.4 + .9*z1 - .3*a)
    drop if runiform() > keeppr & j > 1
    sort id t
end

capture program drop _iivw_v413_weight
program define _iivw_v413_weight
    version 16.0
    _iivw_v413_panel
    quietly iivw_weight, id(id) time(t) visit_cov(z1) treat(a) treat_cov(k1) ///
        wtype(fiptiw) maxfu(7) scores nolog
end

**# T1: stacked Wald endpoints use the posted covariance

* The oracle is the Wald identity itself, evaluated against e(V) AFTER the fit
* returns. It cannot share the ordering bug because it does not depend on when
* the endpoints were formed -- only on what they must equal at the end.
local ++test_count
capture noisily {
    _iivw_v413_weight
    quietly iivw_fit y a z1, timespec(linear) vce(stacked)

    assert "`e(vce)'" == "stacked"
    tempname B V CI
    matrix `B'  = e(b)
    matrix `V'  = e(V)
    matrix `CI' = e(iivw_ci)
    local k = colsof(`B')
    local z = invnormal(.975)
    local nfinite = 0
    forvalues c = 1/`k' {
        local ll = el(`CI', 1, `c')
        local ul = el(`CI', 2, `c')
        if !missing(`ll', `ul') {
            local ++nfinite
            local bc = el(`B', 1, `c')
            local sec = sqrt(el(`V', `c', `c'))
            assert reldif(`ll', `bc' - `z'*`sec') < 1e-12
            assert reldif(`ul', `bc' + `z'*`sec') < 1e-12
        }
    }
    * A vacuous pass -- every endpoint missing -- must not read as green.
    assert `nfinite' >= 3

    * The pre-fix build stored 0.58723462 for `a'; the posted SE gives
    * 0.60648534. Pin the direction so a future reordering cannot pass T1 by
    * making both sides wrong in the same way.
    local ac = colnumb(e(b), "a")
    assert abs(el(`CI', 1, `ac') - 0.58723462) > 1e-3
}
if _rc == 0 {
    display as result "  PASS: T1 - stacked Wald limits match the posted covariance"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - stacked interval/covariance mismatch (error `=_rc')"
    local ++fail_count
    local failed "`failed' T1"
}

**# T2: the identity holds at a second confidence level

* level() changes only the quantile. If the endpoints were being taken from
* some other matrix, a second level is where that shows.
local ++test_count
capture noisily {
    _iivw_v413_weight
    quietly iivw_fit y a z1, timespec(linear) vce(stacked) level(90)

    tempname B2 V2 CI2
    matrix `B2'  = e(b)
    matrix `V2'  = e(V)
    matrix `CI2' = e(iivw_ci)
    local z90 = invnormal(.95)
    local k = colsof(`B2')
    local nfinite = 0
    forvalues c = 1/`k' {
        local ll = el(`CI2', 1, `c')
        local ul = el(`CI2', 2, `c')
        if !missing(`ll', `ul') {
            local ++nfinite
            local bc = el(`B2', 1, `c')
            local sec = sqrt(el(`V2', `c', `c'))
            assert reldif(`ll', `bc' - `z90'*`sec') < 1e-12
            assert reldif(`ul', `bc' + `z90'*`sec') < 1e-12
        }
    }
    assert `nfinite' >= 3
    * And the 90% interval must actually be narrower than the 95% one.
    local ac = colnumb(e(b), "a")
    local w90 = el(`CI2', 2, `ac') - el(`CI2', 1, `ac')
    quietly iivw_fit y a z1, timespec(linear) vce(stacked) replace
    tempname CI95
    matrix `CI95' = e(iivw_ci)
    local w95 = el(`CI95', 2, `ac') - el(`CI95', 1, `ac')
    assert `w90' < `w95'
}
if _rc == 0 {
    display as result "  PASS: T2 - the Wald identity holds at level(90)"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - level(90) interval is not the posted-SE interval (error `=_rc')"
    local ++fail_count
    local failed "`failed' T2"
}

**# T3: the printed interval agrees with the ordinary Wald replay

* Ordinary replay goes through ereturn display and the final covariance. Before
* the fix, the initial table and the replay disagreed for a stacked fit.
local ++test_count
capture noisily {
    _iivw_v413_weight
    quietly iivw_fit y a z1, timespec(linear) vce(stacked)

    tempname CI3
    matrix `CI3' = e(iivw_ci)
    local ac = colnumb(e(b), "a")
    local stored_ll = el(`CI3', 1, `ac')
    local stored_ul = el(`CI3', 2, `ac')

    * _b/_se read the posted results, which is what ereturn display formats.
    local replay_ll = _b[a] - invnormal(.975)*_se[a]
    local replay_ul = _b[a] + invnormal(.975)*_se[a]
    assert reldif(`stored_ll', `replay_ll') < 1e-12
    assert reldif(`stored_ul', `replay_ul') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: T3 - stored interval agrees with the Wald replay"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - initial output and replay disagree (error `=_rc')"
    local ++fail_count
    local failed "`failed' T3"
}

**# T4: a finite edit to a saved score column is refused

* The edit is deliberately benign-looking: a constant rescale preserves within-
* subject score constancy and every column stays finite, so the missing-column
* probe (which correctly errors 459) never fires. This is the acceptance of
* altered FINITE values that I1 named.
local ++test_count
capture noisily {
    _iivw_v413_weight
    local terms : char _dta[_iivw_score_terms]
    local q : word count `terms'
    assert `q' >= 1

    quietly iivw_fit y a z1, timespec(linear) vce(stacked)
    local se_clean = _se[a]

    forvalues s = 1/`q' {
        quietly replace _iivw_ns`s' = 100*_iivw_ns`s'
    }
    capture noisily _iivw_check_weighted
    assert _rc != 0
    capture noisily iivw_fit y a z1, timespec(linear) vce(stacked) replace
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: T4 - a rescaled score column is refused"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - edited score columns were accepted (error `=_rc')"
    local ++fail_count
    local failed "`failed' T4"
}

**# T5: a finite edit to a saved derivative column is refused

local ++test_count
capture noisily {
    _iivw_v413_weight
    local terms : char _dta[_iivw_score_terms]
    local q : word count `terms'
    * A single-cell edit, not a whole-column rescale: the signature binds the
    * cross terms, so one changed row must be enough.
    quietly replace _iivw_nd1 = _iivw_nd1 + 0.5 in 1

    capture noisily _iivw_check_weighted
    assert _rc != 0
    capture noisily iivw_fit y a z1, timespec(linear) vce(stacked)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: T5 - an edited derivative cell is refused"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - an edited derivative column was accepted (error `=_rc')"
    local ++fail_count
    local failed "`failed' T5"
}

**# T6: edited inverse-information metadata is refused

* The ainv string is what turns the stored scores into a variance correction.
* Editing it changes the reported SE with no data edit at all, so the columns
* alone are not a sufficient binding.
local ++test_count
capture noisily {
    _iivw_v413_weight
    local ainv : char _dta[_iivw_score_ainv]
    assert "`ainv'" != ""
    local first : word 1 of `ainv'
    local rest = subinstr("`ainv'", "`first'", "", 1)
    local newfirst = strofreal(real(string(`first')) * 2, "%21x")
    char _dta[_iivw_score_ainv] "`newfirst'`rest'"

    capture noisily _iivw_check_weighted
    assert _rc != 0
    capture noisily iivw_fit y a z1, timespec(linear) vce(stacked)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: T6 - edited inverse-information metadata is refused"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - edited ainv metadata was accepted (error `=_rc')"
    local ++fail_count
    local failed "`failed' T6"
}

**# T7: an untouched contract still passes

* T4-T6 would all pass if the signature had simply been made to refuse
* everything. This is the control that says it did not.
local ++test_count
capture noisily {
    _iivw_v413_weight
    _iivw_check_weighted
    assert _rc == 0
    quietly iivw_fit y a z1, timespec(linear) vce(stacked)
    assert _rc == 0
    assert e(iivw_stacked_selfcheck) < 1e-10

    * A harmless resort must not trip the signature either: it is built from
    * canonical-order sums precisely so that it does not.
    gsort -id -t
    _iivw_check_weighted
    assert _rc == 0
    quietly iivw_fit y a z1, timespec(linear) vce(stacked) replace
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: T7 - an untouched contract is still accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - the integrity gate refuses valid data (error `=_rc')"
    local ++fail_count
    local failed "`failed' T7"
}

capture log close _all
iivw_qa_summary, name(test_iivw_v413_regressions) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests("`failed'")
