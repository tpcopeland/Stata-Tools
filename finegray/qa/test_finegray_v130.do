*! test_finegray_v130 Version 1.0.0  2026/08/19
*! Regression tests for the 2026-08-18 reconciled finegray audit (D1/D2/D4/D8)
*! Author: Timothy P Copeland, Karolinska Institutet

* WHY THIS SUITE EXISTS.
*
* D1 -- `finegray' passed compete() to `markout'.  compete() is the OUTCOME
*   CLASSIFICATION, not a covariate, so an unknown event type was dropped from
*   the estimation sample with no message, no e() count and no note -- INCLUDING
*   failure records, where the drop removes an event from the estimand.  Live on
*   webuse hypoxia, blanking compete() on five records (three of them cause-1
*   failures) returned rc 0 with N 109 -> 104, N_fail 33 -> 30 and b(ifp)
*   .0326664 -> .04609379: a 41% coefficient change with nothing on screen.  The
*   package meanwhile fails CLOSED at r(198) on a record whose event type merely
*   DISAGREES with _d, so the stricter case was the one that survived.
*
* D2 -- the common route into D1.  `stset t, failure(status) id(id)' names the
*   failure indicator BY VARIABLE; a later `stsplit' then sets that variable to
*   missing on every non-terminal episode.  With compete(status) the markout
*   removed every non-terminal episode, the multiple-record machinery never saw
*   a multi-record subject, and the fit ended at r(459) "positivity violation in
*   the delayed-entry weights ... use coarser strata()" -- a message about a
*   cause that was not the cause.
*
* D4 -- `finegray' parses Level(cilevel) and inherits Stata's 10..99.99 rule;
*   the three hand-written validators rejected only `>= 100'.  So
*   `finegray x, compete(...) level(99.995)' stopped at r(198) while the REPLAY
*   `finegray, level(99.995)', finegray_cif and finegray_predict all accepted it
*   at rc 0 -- and each printed "must be a number between 10 and 99.99" while
*   accepting 99.995.
*
* D8 -- seed() is documented seed(#) and went to `set seed' raw, so seed(abc)
*   cleared both curated guards and died on Stata's own message.
*
* Verified 2026-08-19 against the pre-fix tree (git HEAD of Stata-Tools) in an
* isolated scratch copy: 4 pass / 7 fail there, 11 pass / 0 fail here.  Tests 1,
* 2, 4, 6, 8, 10 and 11 are the discriminating half.  Tests 3, 5, 7 and 9 pass
* on both and are the no-regression half -- 7 in particular, because the loose
* validators already rejected 9.99 and 100; only 99.995 fell through the gap
* between `>= 100' and Stata's two-decimal cilevel rule.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_v130.log", replace name(_fg130)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _fg130_result
program define _fg130_result, rclass
    args rc label
    if `rc' == 0 {
        display as result "  PASS: `label'"
        return scalar pass = 1
        return scalar fail = 0
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        return scalar pass = 0
        return scalar fail = 1
    }
end

* Competing-risks fixture with an expression-form stset, so compete() is an
* ordinary classification column that stsplit would not touch.  Test 4 rebuilds
* it with the by-VARIABLE form, which is the configuration stsplit blanks.
capture program drop _fg130_data
program define _fg130_data
    version 16.0
    clear
    set seed 20260819
    quietly set obs 500
    gen long id = _n
    gen double x = rnormal()
    gen double t = 1 + floor(10 * runiform())
    gen byte status = cond(runiform() < .40, 1, cond(runiform() < .45, 2, 0))
    gen byte anyev = status != 0
    quietly stset t, failure(anyev) id(id)
end

* Read a captured log back and report whether a phrase appears in it.  Message
* text -- not rc -- is the assertion for D2, D4 and D8: in each of those the
* return code was already 198/459 before the fix and is 198 after, so rc alone
* cannot tell the right diagnosis from the wrong one.
capture program drop _fg130_saw
program define _fg130_saw, rclass
    version 16.0
    syntax using/, PHrase(string)
    tempname fh
    local saw = 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', `"`phrase'"') > 0 local saw = 1
        file read `fh' line
    }
    file close `fh'
    return scalar saw = `saw'
end

* -----------------------------------------------------------------------------
**# 1. D1: a blanked FAILURE record is refused, not silently dropped
* -----------------------------------------------------------------------------
* The sharp case.  Pre-fix this fit ran to convergence at rc 0 on a sample three
* events short of the one the user asked for.
local ++test_count
capture noisily {
    _fg130_data
    sort id
    quietly gen long _seln = sum(status == 1)
    quietly replace status = . if status == 1 & _seln <= 3
    quietly count if missing(status)
    assert r(N) == 3
    quietly count if missing(status) & _d == 1
    assert r(N) == 3

    tempfile cap1
    capture log close _c1
    log using "`cap1'", replace text name(_c1)
    capture noisily finegray x, compete(status) cause(1) nolog
    local rc1 = _rc
    log close _c1

    assert `rc1' == 198
    _fg130_saw using "`cap1'", phrase("compete() is missing on 3 record(s)")
    assert r(saw) == 1
    _fg130_saw using "`cap1'", phrase("3 of them are stset failures")
    assert r(saw) == 1
}
local _rc = _rc
_fg130_result `_rc' "FG130-1 blanked failure record refused, count named"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 2. D1: a blanked CENSORED record is refused too
* -----------------------------------------------------------------------------
* Uniform refusal.  A censored record with an unknown event type is still a
* record finegray cannot classify, and the count reported must separate the two
* kinds so the user can see which they have.
local ++test_count
capture noisily {
    _fg130_data
    sort id
    quietly gen long _seln = sum(status == 0)
    quietly replace status = . if status == 0 & _seln <= 4
    quietly count if missing(status)
    assert r(N) == 4
    quietly count if missing(status) & _d == 1
    assert r(N) == 0

    tempfile cap2
    capture log close _c2
    log using "`cap2'", replace text name(_c2)
    capture noisily finegray x, compete(status) cause(1) nolog
    local rc2 = _rc
    log close _c2

    assert `rc2' == 198
    _fg130_saw using "`cap2'", phrase("compete() is missing on 4 record(s)")
    assert r(saw) == 1
    _fg130_saw using "`cap2'", phrase("0 of them are stset failures")
    assert r(saw) == 1
}
local _rc = _rc
_fg130_result `_rc' "FG130-2 blanked censored record refused, count named"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 3. D1 no-regression: the refusal is scoped to the estimation sample
* -----------------------------------------------------------------------------
* Three things the new guard must NOT do: fire on clean data; fire on a record
* the user excluded with if/in; or fire on a record already excluded because a
* COVARIATE is missing.  The last one matters most -- markout drops those rows
* for a reason finegray is entitled to act on, and turning them into a hard
* error would be a new refusal of data that used to fit.  The clean fit is also
* pinned NUMERICALLY, so a future change to the guard cannot quietly move the
* estimation sample and still pass.
local ++test_count
capture noisily {
    _fg130_data
    quietly finegray x, compete(status) cause(1) nolog
    local n_clean = e(N)
    local nf_clean = e(N_fail)
    local b_clean = e(b)[1, 1]
    assert `n_clean' == 500

    * (a) a missing compete() on rows excluded by if
    _fg130_data
    quietly replace status = . if id <= 5
    quietly finegray x if id > 5, compete(status) cause(1) nolog
    assert e(N) == 495

    * (b) a missing compete() on rows already dropped for a missing covariate
    _fg130_data
    quietly replace status = . if id <= 5
    quietly replace x = . if id <= 5
    quietly finegray x, compete(status) cause(1) nolog
    assert e(N) == 495

    * (c) clean data is bit-unchanged
    _fg130_data
    quietly finegray x, compete(status) cause(1) nolog
    assert e(N) == `n_clean'
    assert e(N_fail) == `nf_clean'
    * reldif, not equality: `local b_clean = e(b)[1,1]' stores a DECIMAL STRING,
    * and round-tripping the double through it costs up to an ULP.  The claim is
    * "the fit did not move"; exact equality would be testing Stata's macro
    * formatter (same trap documented in test_finegray_estimates_use.do).
    assert !missing(e(b)[1, 1], `b_clean')
    assert reldif(e(b)[1, 1], `b_clean') < 1e-15
}
local _rc = _rc
_fg130_result `_rc' "FG130-3 guard scoped to the estimation sample, clean fit unchanged"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 4. D2: stsplit after failure(<compete var>) names the REAL cause
* -----------------------------------------------------------------------------
* Pre-fix this ended at r(459) "positivity violation in the delayed-entry
* weights ... use coarser strata()/truncstrata(), or a later time origin" --
* every word of which is about a cause that is not the cause.  The premise is
* asserted first: if a future Stata stopped blanking the failure variable on
* stsplit, this test would otherwise stop exercising anything silently.
local ++test_count
capture noisily {
    _fg130_data
    quietly stset t, failure(status) id(id)
    quietly stsplit cat, at(2 4)
    quietly count if missing(status)
    assert !missing(r(N))
    assert r(N) > 0
    local n_blank = r(N)

    tempfile cap4
    capture log close _c4
    log using "`cap4'", replace text name(_c4)
    capture noisily finegray x, compete(status) cause(1) nolog
    local rc4 = _rc
    log close _c4

    assert `rc4' == 198
    _fg130_saw using "`cap4'", phrase("compete() is missing on `n_blank' record(s)")
    assert r(saw) == 1
    _fg130_saw using "`cap4'", phrase("stsplit")
    assert r(saw) == 1
    * and NOT the misattributed diagnosis
    _fg130_saw using "`cap4'", phrase("positivity violation")
    assert r(saw) == 0
}
local _rc = _rc
_fg130_result `_rc' "FG130-4 stsplit + failure(compete var) names the real cause"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 5. D4 no-regression: 99.99 is accepted on all four surfaces
* -----------------------------------------------------------------------------
* The upper edge of Stata's own cilevel rule.  A validator tightened past the
* parent would be as wrong as one loosened past it, so the accept side is
* pinned before the reject side.
local ++test_count
capture noisily {
    _fg130_data
    quietly finegray x, compete(status) cause(1) nolog level(99.99)
    assert e(level) == 99.99
    quietly finegray, level(99.99)
    quietly finegray_cif, attime(5) ci level(99.99) nograph
    assert r(level) == 99.99
    capture drop _p130a*
    quietly finegray_predict _p130a, cif ci level(99.99)
}
local _rc = _rc
_fg130_result `_rc' "FG130-5 level(99.99) accepted by fit, replay, cif and predict"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 6. D4: 99.995 is refused on all four surfaces, with one message
* -----------------------------------------------------------------------------
* Pre-fix: the FIT refused it (Level(cilevel)) and the other three accepted it
* at rc 0 -- finegray_cif printed a table headed "99.995% CI".  The replay is
* the third surface: `finegray, level()' with no varlist goes to
* _finegray_display, which had its own copy of the loose check.
local ++test_count
capture noisily {
    _fg130_data
    quietly finegray x, compete(status) cause(1) nolog

    capture noisily finegray x, compete(status) cause(1) nolog level(99.995)
    assert _rc == 198

    tempfile cap6
    capture log close _c6
    log using "`cap6'", replace text name(_c6)
    capture noisily finegray, level(99.995)
    local rc_replay = _rc
    capture noisily finegray_cif, attime(5) ci level(99.995) nograph
    local rc_cif = _rc
    capture drop _p130b*
    capture noisily finegray_predict _p130b, cif ci level(99.995)
    local rc_pred = _rc
    log close _c6

    assert `rc_replay' == 198
    assert `rc_cif' == 198
    assert `rc_pred' == 198
    * One message everywhere: Stata's own cilevel wording, so it cannot drift
    * from the fit path again.  The pre-fix text said "between 10 and 99.99"
    * while accepting 99.995.
    _fg130_saw using "`cap6'", phrase("must be between 10 and 99.99 inclusive")
    assert r(saw) == 1
}
local _rc = _rc
_fg130_result `_rc' "FG130-6 level(99.995) refused everywhere with one message"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 7. D4: the lower edge and the round number are refused everywhere too
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fg130_data
    quietly finegray x, compete(status) cause(1) nolog
    foreach L in 9.99 100 {
        capture noisily finegray x, compete(status) cause(1) nolog level(`L')
        assert _rc == 198
        capture noisily finegray, level(`L')
        assert _rc == 198
        capture noisily finegray_cif, attime(5) ci level(`L') nograph
        assert _rc == 198
        capture drop _p130c*
        capture noisily finegray_predict _p130c, cif ci level(`L')
        assert _rc == 198
    }
}
local _rc = _rc
_fg130_result `_rc' "FG130-7 level(9.99) and level(100) refused on all four surfaces"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 8. D8: a non-numeric seed() gets the package's own message
* -----------------------------------------------------------------------------
* Pre-fix the rc was already 198 -- from `set seed', after both curated seed
* guards had passed -- so the assertion has to be on the text.
local ++test_count
capture noisily {
    _fg130_data
    quietly finegray x, compete(status) cause(1) nolog

    tempfile cap8
    capture log close _c8
    log using "`cap8'", replace text name(_c8)
    capture noisily finegray_cif, attime(5) ci bootstrap(25) seed(abc) nograph
    local rc_cif8 = _rc
    capture drop _p130d*
    capture noisily finegray_predict _p130d, cif ci bootstrap(25) seed(abc)
    local rc_pred8 = _rc
    log close _c8

    assert `rc_cif8' == 198
    assert `rc_pred8' == 198
    _fg130_saw using "`cap8'", phrase("seed() must be an integer between 0 and 2147483647")
    assert r(saw) == 1
    _fg130_saw using "`cap8'", phrase("is not a usable random-number seed")
    assert r(saw) == 1
}
local _rc = _rc
_fg130_result `_rc' "FG130-8 seed(abc) refused with the package's own message"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 9. D8 no-regression: a valid seed still seeds a reproducible bootstrap
* -----------------------------------------------------------------------------
* The guard must not have become a refusal of the documented usage, and seed()
* must still do the one thing it exists for.
local ++test_count
capture noisily {
    _fg130_data
    quietly finegray x, compete(status) cause(1) nolog

    quietly finegray_cif, attime(5) ci bootstrap(25) seed(12345) nograph
    tempname B1
    matrix `B1' = r(table)
    quietly finegray_cif, attime(5) ci bootstrap(25) seed(12345) nograph
    tempname B2
    matrix `B2' = r(table)
    assert mreldif(`B1', `B2') == 0

    quietly finegray_cif, attime(5) ci bootstrap(25) seed(999) nograph
    tempname B3
    matrix `B3' = r(table)
    * A different seed must move the bootstrap SE; equal here would mean seed()
    * is being ignored, which is what the guard exists to make impossible.
    assert `B3'[1, 3] != `B1'[1, 3]

    quietly finegray_predict _p130s1, cif ci bootstrap(25) seed(12345)
    quietly finegray_predict _p130s2, cif ci bootstrap(25) seed(12345)
    quietly count if !missing(_p130s1_lci, _p130s2_lci, _p130s1_uci, _p130s2_uci)
    assert r(N) > 0
    assert _p130s1_lci == _p130s2_lci if !missing(_p130s1_lci, _p130s2_lci)
    assert _p130s1_uci == _p130s2_uci if !missing(_p130s1_uci, _p130s2_uci)
}
local _rc = _rc
_fg130_result `_rc' "FG130-9 seed() controls reproducible CIF and prediction bootstraps"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 10. D8: a negative and a fractional seed are refused as well
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fg130_data
    quietly finegray x, compete(status) cause(1) nolog
    foreach S in -1 3.5 {
        capture noisily finegray_cif, attime(5) ci bootstrap(25) seed(`S') nograph
        assert _rc == 198
        capture drop _p130e*
        capture noisily finegray_predict _p130e, cif ci bootstrap(25) seed(`S')
        assert _rc == 198
    }
}
local _rc = _rc
_fg130_result `_rc' "FG130-10 negative and fractional seeds refused"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 11. D1: the shipped helper file list carries the new level validator
* -----------------------------------------------------------------------------
* The single-bound fix put the rule in _finegray_check_level.ado.  A helper that
* is not in the .pkg does not reach an installed user, and the three commands
* that call it would then fail at r(199) on a machine that is not this one.
* This suite installs from the package directory, so `which' here is the
* installed-user question.
local ++test_count
capture noisily {
    capture which _finegray_check_level
    assert _rc == 0
    * and it enforces Stata's rule rather than a copy of it
    capture noisily _finegray_check_level, level(99.995)
    assert _rc == 198
    capture noisily _finegray_check_level, level(99.99)
    assert _rc == 0
    capture noisily _finegray_check_level, level(95)
    assert _rc == 0
}
local _rc = _rc
_fg130_result `_rc' "FG130-11 _finegray_check_level ships and enforces the cilevel rule"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# Summary
display as text _newline ///
    "RESULT: test_finegray_v130 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fg130
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fg130
