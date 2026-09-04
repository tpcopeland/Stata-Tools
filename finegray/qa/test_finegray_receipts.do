*! test_finegray_receipts Version 1.0.0  2026/09/04
*! Coverage for the baseline-cache receipts e(bh_seq) and e(bh_key)
*! Author: Timothy P Copeland, Karolinska Institutet

* WHY THIS SUITE EXISTS.
*
* finegray keeps the baseline curve in Mata -- building the K x 2 (or K x 3)
* Stata matrix is O(K^2) and was the package's entire superlinearity -- and
* posts two receipts for it:
*
*   e(bh_key)  the token a consumer must present to be handed the cache back.
*              It is minted from a Stata global counter (which `mata clear'
*              does not reset), the wall clock, and a digest of e(b) and the
*              fit scalars, so it cannot be re-minted and a stale curve can
*              never answer for a different fit.  Gated all over the suite,
*              most sharply by NC-5 in test_finegray_nullcase.do.
*
*   e(bh_seq)  the human-readable serial number of the cached curve within the
*              current Mata session.  Nothing gates on it since e(bh_key)
*              landed, which is what the CLI reported as
*              `return_not_covered' -- an undocumented-by-test stored result
*              in a RELEASED package.
*
* WHY bh_seq IS ASSERTED RATHER THAN DROPPED.  Three reasons, in order of
* weight.  (1) It is a documented stored result of a released package
* (finegray.sthlp), so removing it breaks a published contract for users who
* read it, and buys nothing: the post is one line.  (2) It answers a question
* e(bh_key) deliberately cannot -- "how many curves has this session cached,
* and is mine still the last one" -- which is the first thing to look at in a
* bug report about a stale CIF.  (3) The counter behind it has to exist
* regardless: finegray.ado mints e(bh_key) only `if `_fg_bh_seq' != ""', so
* the Mata counter is load-bearing whether or not its value is posted.
*
* WHAT THIS FILE PINS, therefore, is the receipt's ACTUAL semantics rather than
* its mere presence -- including the one place it is deliberately WEAKER than
* e(bh_key), namely that `mata clear' resets it to 1 while the key it
* accompanies stays unrepeatable (RC-4).  That asymmetry is the reason the key
* replaced the counter in the first place, and an assertion that only checked
* "nonempty" would let a regression to the old integer-keyed cache pass.

clear all
set varabbrev off
version 16.0

local qa_dir "`c(pwd)'"
capture log close _all
log using "test_finegray_receipts.log", replace text name(_fgrc)
do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _fgrc_result
program define _fgrc_result, rclass
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

capture program drop _fgrc_data
program define _fgrc_data
    version 16.0
    syntax [, N(integer 400) SEED(integer 20260904)]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen double x1 = rnormal()
    gen byte grp = 1 + floor(runiform() * 3)
    gen double eta = 0.5 * x1 + 0.3 * (grp == 2) - 0.4 * (grp == 3)
    gen double u = runiform()
    gen double f1inf = 1 - (1 - 0.5)^exp(eta)
    gen byte cause = cond(u < f1inf, 1, 2)
    gen double tev = -ln(1 - (1 - (1 - u)^exp(-eta)) / 0.5) if cause == 1
    quietly replace tev = -ln(runiform()) if cause == 2
    gen double tc = -ln(runiform()) / 0.15
    gen double time = min(tev, tc)
    gen byte status = cond(tev <= tc, cause, 0)
    quietly replace time = 1e-6 if time <= 0
    drop u f1inf tev tc eta
    quietly stset time, failure(status) id(id)
end

display as text _newline "test_finegray_receipts: baseline-cache receipts"

* -----------------------------------------------------------------------------
**# RC-1  e(bh_seq) is a nonempty positive integer, posted beside e(bh_key)
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgrc_data
    finegray x1 i.grp, compete(status) cause(1) nolog
    local s1 `"`e(bh_seq)'"'
    local k1 `"`e(bh_key)'"'
    display as text "  RC-1 e(bh_seq) = `s1'"
    assert `"`s1'"' != ""
    assert `"`k1'"' != ""
    * an INTEGER, not a formatted or truncated number: the round trip through
    * real() and back has to be the identical string
    assert !missing(real(`"`s1'"'))
    assert real(`"`s1'"') > 0
    assert real(`"`s1'"') == int(real(`"`s1'"'))
    assert strofreal(real(`"`s1'"'), "%18.0g") == `"`s1'"'
}
local _rc = _rc
_fgrc_result `_rc' "RC-1 e(bh_seq) is a nonempty positive integer posted with e(bh_key)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# RC-2  it strictly increases across successive fits in one session
* -----------------------------------------------------------------------------
* One cached curve per fit, so the step is exactly 1.  A receipt that did not
* move would be reporting the previous fit's curve, which is the whole failure
* class the cache key exists to close.
local ++test_count
capture noisily {
    _fgrc_data
    finegray x1 i.grp, compete(status) cause(1) nolog
    local s1 = real(`"`e(bh_seq)'"')
    local k1 `"`e(bh_key)'"'
    finegray x1, compete(status) cause(1) nolog
    local s2 = real(`"`e(bh_seq)'"')
    local k2 `"`e(bh_key)'"'
    display as text "  RC-2 bh_seq: `s1' -> `s2'"
    assert !missing(`s1', `s2')
    assert `s2' == `s1' + 1
    assert `"`k1'"' != `"`k2'"'
}
local _rc = _rc
_fgrc_result `_rc' "RC-2 e(bh_seq) advances by exactly 1 per fit, with a new e(bh_key)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# RC-3  both receipts survive estimates store/restore
* -----------------------------------------------------------------------------
* The receipt is only useful if it travels with the estimates it describes: a
* restored fit that had lost its key could not be answered from the cache at
* all, and one that had lost its seq would misreport which curve it holds.
local ++test_count
capture noisily {
    _fgrc_data
    finegray x1 i.grp, compete(status) cause(1) nolog
    local s1 `"`e(bh_seq)'"'
    local k1 `"`e(bh_key)'"'
    estimates store _fgrc_A

    * a second fit moves the receipts and overwrites the cache slot
    finegray x1, compete(status) cause(1) nolog
    assert `"`e(bh_seq)'"' != `"`s1'"'

    estimates restore _fgrc_A
    display as text "  RC-3 restored bh_seq = `=e(bh_seq)' (stored `s1')"
    assert `"`e(bh_seq)'"' == `"`s1'"'
    assert `"`e(bh_key)'"' == `"`k1'"'
    * and the restored fit is still answerable, so the receipts are not just
    * strings that happen to round trip
    quietly finegray_cif, at(x1=0.3 grp=2) attime(1) nograph
    tempname RC3
    matrix `RC3' = r(table)
    assert !missing(`RC3'[1, 2])
    assert `RC3'[1, 2] > 0 & `RC3'[1, 2] < 1
}
local _rc = _rc
capture estimates drop _fgrc_A
_fgrc_result `_rc' "RC-3 e(bh_seq) and e(bh_key) survive estimates store/restore and the fit still answers"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# RC-4  `mata clear' resets the seq but CANNOT re-mint the key
* -----------------------------------------------------------------------------
* This is the defect that retired the integer counter as the cache key: the
* counter lives in Mata, so `mata clear' handed the next fit key 1 again, and an
* `estimates restore' of an earlier fit that also held key 1 then scored its
* betas on the new fit's baseline at rc 0.  The salt behind e(bh_key) is a
* Stata GLOBAL plus the wall clock, which `mata clear' does not touch.  So two
* fits may legitimately share e(bh_seq) == 1 and must never share e(bh_key).
local ++test_count
capture noisily {
    mata: mata clear
    _fgrc_data
    finegray x1 i.grp, compete(status) cause(1) nolog
    local s1 `"`e(bh_seq)'"'
    local k1 `"`e(bh_key)'"'

    mata: mata clear
    _fgrc_data
    finegray x1 i.grp, compete(status) cause(1) nolog
    local s2 `"`e(bh_seq)'"'
    local k2 `"`e(bh_key)'"'

    display as text "  RC-4 bh_seq after each mata clear: `s1' and `s2'"
    assert `"`s1'"' == "1"
    assert `"`s2'"' == "1"
    assert `"`k1'"' != ""
    assert `"`k2'"' != ""
    assert `"`k1'"' != `"`k2'"'
}
local _rc = _rc
_fgrc_result `_rc' "RC-4 mata clear resets e(bh_seq) to 1 while e(bh_key) stays unrepeatable"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# Summary
display as text _newline ///
    "RESULT: test_finegray_receipts tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture log close _fgrc
    exit 1
}
display as result "ALL TESTS PASSED"
capture log close _fgrc
