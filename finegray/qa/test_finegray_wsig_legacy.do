*! test_finegray_wsig_legacy Version 1.0.0  2026/09/04
*! Weighted post-estimation on an e() that carries no e(wsig) digest
*! Author: Timothy P Copeland, Karolinska Institutet

* WHY THIS SUITE EXISTS.
*
* _finegray_weight_var rebuilds the fit's design-weight column from e(wexp) and
* reconciles it two ways: its TOTAL over e(sample) against e(sum_w), and its
* per-observation values against e(wsig), a subject-keyed digest of the fit's
* own column.  The second check is the one that catches the two changes the
* total cannot see:
*
*   COMPENSATED   [pw = cond(odd == 0, k, 4 - k)] after `scalar k = 2'.  Every
*                 per-observation weight moves; e(sum_w) does not move at all.
*   PERMUTED      two subjects exchange their weights.  The multiset of weight
*                 values, e(sum_w), and e(datasignature) are all untouched.
*
* Both are r(459) when e(wsig) is present.  But the digest check ran only
* `if e(wsig) != ""', so a weighted e() that carries no digest fell through to
* the total-only reconciliation AT rc 0 and said nothing.  That state is
* reachable: weighted fits shipped WITHOUT e(wsig) in released commits
* d2cb1bda and 789e2635, so `estimates use' of a legitimate weighted fit made
* by an installed release lands there.
*
* WARNING, NOT REFUSAL -- and the choice is licensed by what can reach the code
* rather than by taste.  A hard exit would break `estimates use' of a correct
* weighted fit for users who cannot re-fit.  The other state named in the
* helper's comment, an e() assembled by `mi estimate', never arrives at all:
* finegray_cif, finegray_predict and finegray_phtest each exit 301 on
* e(cmd) == "mi estimate" & e(cmd_mi) == "finegray" before any weight is
* rebuilt (finegray_cif.ado, finegray_predict.ado, finegray_phtest.ado), so a
* refusal here would buy nothing on the mi path and cost the legacy one.
*
* HOW THE LEGACY STATE IS REPRODUCED, and why it is the real thing.  WL-3
* builds a private copy of the package with the two lines
*
*     ereturn scalar wsig_n = `_fg_wsig_n'
*     ereturn local  wsig  "`_fg_wsig'"
*
* deleted from finegray.ado, installs it, and fits.  The resulting e() has
* never held a digest -- WL-3 asserts both e(wsig) == "" and e(wsig_n) == . --
* which is exactly the state a pre-digest build leaves behind.  It is NOT
* simulated with `ereturn local wsig ""' on a current fit: that would leave
* e(wsig_n) posted and would prove only that the helper reads the macro it is
* written to read.  Every other file in the package is the CURRENT one, so what
* is under test is the current helper meeting a legacy e().
*
* WHAT WOULD MAKE THIS FILE RED.  WL-1/WL-2 go red if the digest refusal is
* weakened (they are the same two changes, with the digest present, and both
* must stay r(459)).  WL-4/WL-5 go red if the degradation goes silent again.
* WL-6 goes red if the warning fires only on a tampered weight -- it is a
* property of the ESTIMATES, not of the tamper, and an untouched legacy fit
* must say so too.  WL-7 goes red if the warning starts firing on a current
* fit, which would train users to ignore it.

clear all
set varabbrev off
version 16.0

local qa_dir "`c(pwd)'"
capture log close _all
log using "test_finegray_wsig_legacy.log", replace text name(_fgwl)
do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap
local pkg_dir `"`r(pkg_dir)'"'

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _fgwl_result
program define _fgwl_result, rclass
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

* Run `cmd' with its console output teed into a throwaway log, and report both
* its return code and whether `expect' appeared anywhere in that output.  The
* warning under test is a `display as error' rather than an exit, so nothing
* but the text itself can witness it.
capture program drop _fgwl_capture
program define _fgwl_capture, rclass
    version 16.0
    syntax , CMD(string) EXPect(string)
    tempfile cap
    capture log close _fgwlcap
    quietly log using "`cap'", replace text name(_fgwlcap)
    capture noisily `cmd'
    local _crc = _rc
    capture log close _fgwlcap
    tempname fh
    local saw = 0
    file open `fh' using "`cap'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', `"`expect'"') > 0 local saw = 1
        file read `fh' line
    }
    file close `fh'
    return scalar saw = `saw'
    return scalar rc = `_crc'
end

* Competing-risks fixture with an id() and an EVEN split on `odd', so the
* compensated weight expression leaves e(sum_w) exactly invariant.
capture program drop _fgwl_data
program define _fgwl_data
    version 16.0
    syntax [, N(integer 400) SEED(integer 20260904)]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen byte odd = mod(_n, 2)
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
    gen double pw = 0.5 + 2.5 * runiform()
    drop u f1inf tev tc eta
    quietly stset time, failure(status) id(id)
end

display as text _newline "test_finegray_wsig_legacy: weighted post-estimation without e(wsig)"

* -----------------------------------------------------------------------------
**# WL-1  digest PRESENT: a compensated change is still refused r(459)
* -----------------------------------------------------------------------------
* The control for WL-4.  If this cell ever passes at rc 0, the legacy branch
* added below has swallowed the live refusal and WL-4 proves nothing.
local ++test_count
capture noisily {
    _fgwl_data
    scalar _fgwl_k = 1
    finegray x1 i.grp [pw = cond(odd == 0, _fgwl_k, 4 - _fgwl_k)], ///
        compete(status) cause(1) nolog
    assert `"`e(wsig)'"' != ""
    assert e(wsig_n) == e(N)
    local _wl1sum = e(sum_w)

    * the compensated change: the TOTAL is untouched, every weight is not
    scalar _fgwl_k = 2
    tempvar wl1
    quietly generate double `wl1' = cond(odd == 0, _fgwl_k, 4 - _fgwl_k) if e(sample)
    quietly summarize `wl1' if e(sample), meanonly
    display as text "  WL-1 e(sum_w) = " %12.0g `_wl1sum' ///
        "  rebuilt total = " %12.0g r(sum)
    assert !missing(r(sum), `_wl1sum')
    assert reldif(r(sum), `_wl1sum') < 1e-10

    capture finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph
    assert _rc == 459
    capture predict double wl1cif, cif ci
    assert _rc == 459
}
local _rc = _rc
capture scalar drop _fgwl_k
_fgwl_result `_rc' "WL-1 digest present: compensated weight change refused r(459)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# WL-2  digest PRESENT: a subject-weight exchange is still refused r(459)
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgwl_data
    scalar _fgwl_a = 1
    scalar _fgwl_b = 2
    finegray x1 i.grp [pw = cond(id == _fgwl_a, 3, cond(id == _fgwl_b, 1, 2))], ///
        compete(status) cause(1) nolog
    assert "`e(idvar)'" == "id"
    assert `"`e(wsig)'"' != ""
    local _wl2sum = e(sum_w)

    * the exchange: subject 1 now carries 1 and subject 2 carries 3
    scalar _fgwl_a = 2
    scalar _fgwl_b = 1
    tempvar wl2
    quietly generate double `wl2' = ///
        cond(id == _fgwl_a, 3, cond(id == _fgwl_b, 1, 2)) if e(sample)
    quietly summarize `wl2' if e(sample), meanonly
    assert !missing(r(sum), `_wl2sum')
    assert reldif(r(sum), `_wl2sum') < 1e-12
    capture datasignature confirm
    display as text "  WL-2 swap: datasignature rc = `=_rc' (unchanged data)"

    capture finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph
    assert _rc == 459
    capture predict double wl2cif, cif ci
    assert _rc == 459
}
local _rc = _rc
capture scalar drop _fgwl_a
capture scalar drop _fgwl_b
_fgwl_result `_rc' "WL-2 digest present: subject-weight exchange refused r(459)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# WL-3  build and install a genuinely pre-digest build
* -----------------------------------------------------------------------------
* Everything except finegray.ado is the CURRENT file, and finegray.ado differs
* from the current one only by the two deleted `ereturn ... wsig' lines.  The
* deletion is asserted twice: once on the source (exactly two lines gone) and
* once on the resulting e() (no e(wsig), no e(wsig_n)).
local ++test_count
* tempname counters restart at __000000 in every Stata process, so they are not
* safe directory identifiers for concurrent lanes; a tempfile path carries
* Stata's process id (/tmp/St12345.000001) and is unique.  Same argument as
* _finegray_qa_common.do.
tempfile legacy_anchor
local legacy_dir "`legacy_anchor'_fglegacy"
capture noisily {
    * TWO Stata parser traps live in these four lines, both silent.
    *   1  `shell' hands its whole line to the OS verbatim, so a line-join
    *      marker inside it is passed to the shell, not acted on: every shell
    *      command here has to fit on one physical line.
    *   2  a glob written "dir"/[star].ado puts a slash immediately before the
    *      star, and Stata reads that pair as the start of a block comment --
    *      it then swallows the rest of the file and reports only "matching
    *      close brace not found" hundreds of lines later.  Hence `cd' first.
    local L "`legacy_dir'"
    local P "`pkg_dir'"
    quietly shell rm -rf "`L'"
    quietly shell mkdir -p "`L'"
    quietly shell cd "`P'" && cp *.ado *.sthlp *.pkg stata.toc "`L'"
    quietly shell sed -i '/ereturn scalar wsig_n =/d' "`L'/finegray.ado"
    quietly shell sed -i '/ereturn local wsig /d' "`L'/finegray.ado"

    capture ado uninstall finegray
    quietly net install finegray, from("`legacy_dir'") replace
    discard

    _fgwl_data
    finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog
    assert "`e(wtype)'" == "pweight"
    assert `"`e(wsig)'"' == ""
    assert missing(e(wsig_n))
    display as text "  WL-3 legacy fit posts e(wsig) = <empty>, e(wsig_n) = `=e(wsig_n)'"
}
local _rc = _rc
_fgwl_result `_rc' "WL-3 a pre-digest build is installed and its weighted fit posts no e(wsig)/e(wsig_n)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# WL-4  legacy e(): a compensated change is AUDIBLE, not silent
* -----------------------------------------------------------------------------
* Measured on the pre-warning helper: this cell answered rc 0 with no output at
* all, from a weight column the fit never saw.
local ++test_count
capture noisily {
    _fgwl_data
    scalar _fgwl_k = 1
    finegray x1 i.grp [pw = cond(odd == 0, _fgwl_k, 4 - _fgwl_k)], ///
        compete(status) cause(1) nolog
    assert `"`e(wsig)'"' == ""
    local _wl4sum = e(sum_w)

    scalar _fgwl_k = 2
    tempvar wl4
    quietly generate double `wl4' = cond(odd == 0, _fgwl_k, 4 - _fgwl_k) if e(sample)
    quietly summarize `wl4' if e(sample), meanonly
    display as text "  WL-4 e(sum_w) = " %12.0g `_wl4sum' ///
        "  rebuilt total = " %12.0g r(sum)
    assert !missing(r(sum), `_wl4sum')
    assert reldif(r(sum), `_wl4sum') < 1e-10

    _fgwl_capture, cmd("finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph") ///
        expect("carries no weight digest e(wsig)")
    display as text "  WL-4 finegray_cif rc = `=r(rc)', warning seen = `=r(saw)'"
    assert r(saw) == 1
    assert r(rc) == 0

    * `predict, cif ci', not `predict, cif'.  MEASURED: the point CIF alone
    * does not rebuild the weight column at all -- it is answered from the
    * cached baseline curve and e(b), neither of which needs one -- so it
    * prints nothing here and is not a missed warning.  The ci variant needs
    * the influence function, which needs the weights, and warns.
    _fgwl_capture, cmd("predict double wl4cif, cif ci") ///
        expect("carries no weight digest e(wsig)")
    display as text "  WL-4 predict rc = `=r(rc)', warning seen = `=r(saw)'"
    assert r(saw) == 1
    assert r(rc) == 0
}
local _rc = _rc
capture scalar drop _fgwl_k
_fgwl_result `_rc' "WL-4 legacy e(): compensated weight change is reported by name, not passed in silence"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# WL-5  legacy e(): a subject-weight exchange is AUDIBLE, not silent
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgwl_data
    scalar _fgwl_a = 1
    scalar _fgwl_b = 2
    finegray x1 i.grp [pw = cond(id == _fgwl_a, 3, cond(id == _fgwl_b, 1, 2))], ///
        compete(status) cause(1) nolog
    assert `"`e(wsig)'"' == ""
    local _wl5sum = e(sum_w)

    scalar _fgwl_a = 2
    scalar _fgwl_b = 1
    tempvar wl5
    quietly generate double `wl5' = ///
        cond(id == _fgwl_a, 3, cond(id == _fgwl_b, 1, 2)) if e(sample)
    quietly summarize `wl5' if e(sample), meanonly
    assert !missing(r(sum), `_wl5sum')
    assert reldif(r(sum), `_wl5sum') < 1e-12

    _fgwl_capture, cmd("finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph") ///
        expect("carries no weight digest e(wsig)")
    display as text "  WL-5 finegray_cif rc = `=r(rc)', warning seen = `=r(saw)'"
    assert r(saw) == 1
    assert r(rc) == 0
}
local _rc = _rc
capture scalar drop _fgwl_a
capture scalar drop _fgwl_b
_fgwl_result `_rc' "WL-5 legacy e(): subject-weight exchange is reported by name, not passed in silence"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# WL-6  the warning is a property of the ESTIMATES, not of a tamper
* -----------------------------------------------------------------------------
* An untouched legacy fit is still reconciled by total only, so it must warn
* too.  This is also the positive control for WL-4/WL-5: the command answers,
* it does not merely complain, so the warning has not become a refusal.
local ++test_count
capture noisily {
    _fgwl_data
    finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog
    assert `"`e(wsig)'"' == ""

    _fgwl_capture, cmd("finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph") ///
        expect("carries no weight digest e(wsig)")
    display as text "  WL-6 untouched legacy fit: rc = `=r(rc)', warning seen = `=r(saw)'"
    assert r(saw) == 1
    assert r(rc) == 0

    * and it really answered.  r(table) from finegray_cif is 1 x 5, columns
    * time, cif, se, lci, uci -- one ROW per requested time, not the coefficient
    * table's one row per statistic.
    quietly finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph
    tempname WL6
    matrix `WL6' = r(table)
    assert rowsof(`WL6') == 1 & colsof(`WL6') == 5
    assert !missing(`WL6'[1, 2], `WL6'[1, 3])
    assert `WL6'[1, 2] > 0 & `WL6'[1, 2] < 1
    assert `WL6'[1, 3] > 0
}
local _rc = _rc
_fgwl_result `_rc' "WL-6 an untouched legacy fit warns and still answers (warning, not refusal)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# WL-7  the current build does NOT warn
* -----------------------------------------------------------------------------
* A warning that fires on every weighted fit is a warning users learn to skip.
local ++test_count
capture noisily {
    capture ado uninstall finegray
    quietly net install finegray, from("`pkg_dir'") replace
    discard

    _fgwl_data
    finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog
    assert `"`e(wsig)'"' != ""

    _fgwl_capture, cmd("finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph") ///
        expect("carries no weight digest e(wsig)")
    display as text "  WL-7 current build: rc = `=r(rc)', warning seen = `=r(saw)'"
    assert r(saw) == 0
    assert r(rc) == 0
}
local _rc = _rc
capture shell rm -rf "`legacy_dir'"
_fgwl_result `_rc' "WL-7 a current weighted fit carries the digest and prints no warning"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# Summary
display as text _newline ///
    "RESULT: test_finegray_wsig_legacy tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture log close _fgwl
    exit 1
}
display as result "ALL TESTS PASSED"
capture log close _fgwl
