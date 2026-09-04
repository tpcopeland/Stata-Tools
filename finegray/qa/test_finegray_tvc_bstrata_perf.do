*! test_finegray_tvc_bstrata_perf Version 1.0.0  2026/09/04
*! tvc() x bstrata(): one baseline scan per interval, none per stratum
*! Author: Timothy P Copeland, Karolinska Institutet

* WHY THIS SUITE EXISTS.
*
* _finegray_basehazard() is a full pass over the risk set, and under bstrata()
* one call returns EVERY stratum's rows -- the stratum is column 1 of what it
* hands back.  _finegray_basehazard_pw() nevertheless called it inside the
* stratum loop AND the interval loop, so a K-stratum, J-interval fit ran K x J
* full scans to keep J of them and discard K - 1 results each time.  Correct,
* and K times more work than the answer needs.
*
* WHY THIS IS A COUNTER AND NOT A STOPWATCH.  A wall-clock test for "time does
* not grow with K" has to separate the scan cost from everything else the fit
* does, on a shared machine, and then pick a threshold; it goes flaky long
* before it goes informative.  The claim is discrete -- the assembly makes
* exactly nint calls and none of them depend on the number of strata -- so it
* is asserted directly.  _finegray_basehazard() increments the Mata external
* _finegray_bh_calls, and _finegray_bh_calls_reset() / _finegray_bh_calls_get()
* read it.
*
* WHAT WOULD MAKE THIS FILE RED.  On the pre-fix engine TBP-1 measured 6 calls
* where nint is 3 (K = 2) and TBP-2 measured 12 (K = 4), so both cells go red
* the moment the stratum loop is put back outside the interval loop.  TBP-3
* is the correctness half: the assembly has to stay stratum-major with strictly
* ascending times and a non-decreasing cumulative hazard inside each stratum
* block, which is the layout every K x 3 consumer assumes.
*
* BIT-IDENTITY was verified separately at the time of the change rather than
* pinned here: the same fit's e(basehaz), e(b) and e(V) before and after the
* restructure compared exactly equal element by element (mreldif == 0, not a
* tolerance).  The numbers themselves are gated by test_finegray_tvc_bstrata.do,
* which is where a moved curve belongs.

clear all
set varabbrev off
version 16.0

local qa_dir "`c(pwd)'"
capture log close _all
log using "test_finegray_tvc_bstrata_perf.log", replace text name(_fgtbp)
do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _fgtbp_result
program define _fgtbp_result, rclass
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

* The tvc() x bstrata() fixture of test_finegray_tvc_bstrata.do, with K a
* parameter so the same data-generating process can be run at two stratum
* counts.
capture program drop _fgtbp_data
program define _fgtbp_data
    version 16.0
    args seed nobs K
    if "`seed'" == "" local seed 20260904
    if "`nobs'" == "" local nobs 900
    if "`K'" == "" local K 2
    clear
    set seed `seed'
    quietly set obs `nobs'
    gen long id = _n
    gen byte ctr = 1 + mod(_n - 1, `K')
    gen double x1 = rnormal()
    gen double x2 = rbinomial(1, 0.4)
    local tau = 0.7
    gen double h1a = (0.4 + 0.30 * ctr) * exp(0.80 * x1 - 0.50 * x2)
    gen double h1b = (0.4 + 0.30 * ctr) * exp(0.00 * x1 - 0.50 * x2)
    gen double E   = -ln(runiform())
    gen double tt1 = cond(E <= h1a * `tau', E / h1a, `tau' + (E - h1a * `tau') / h1b)
    gen double tt2 = -ln(runiform()) / (0.35 * exp(0.30 * x1))
    gen double tc  = rexponential(2.0)
    gen double t   = min(tt1, tt2, tc)
    gen byte status = cond(t == tt1, 1, cond(t == tt2, 2, 0))
    gen byte anyev = status != 0
    quietly stset t, failure(anyev == 1) id(id)
end

* Fit once with the counter zeroed just before, and return the count.  The
* engine is loaded lazily by finegray (finegray.ado probes _finegray_mata_ok()
* and reloads the file if the probe errors), so the reset can only run after
* at least one fit has loaded it -- and the reset itself must be the LAST thing
* before the measured fit.
capture program drop _fgtbp_count
program define _fgtbp_count, rclass
    version 16.0
    syntax , SPEC(string)
    mata: _finegray_bh_calls_reset()
    `spec'
    mata: _finegray_bh_calls_get()
    return scalar calls = real("`_fg_bh_calls'")
end

display as text _newline "test_finegray_tvc_bstrata_perf: baseline scans per fit"

* -----------------------------------------------------------------------------
**# TBP-1  K = 2, J = 3: the assembly makes exactly J baseline scans
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgtbp_data 20260904 900 2
    * warm-up fit: loads the Mata engine, so the measured fit below is not
    * charged for it (loading runs no scan, but the probe/reload path does
    * touch Mata and the reset has to happen after it)
    quietly finegray x1 x2, compete(status) cause(1) tvc(x1) tsplit(0.4 0.9) ///
        bstrata(ctr) nolog

    _fgtbp_count, spec("quietly finegray x1 x2, compete(status) cause(1) tvc(x1) tsplit(0.4 0.9) bstrata(ctr) nolog basehaz")
    local c2 = r(calls)
    quietly levelsof ctr, local(levs)
    local nlev : word count `levs'
    display as text "  TBP-1 K = `nlev', nint = 3, baseline scans = `c2'"
    assert !missing(`c2')
    assert `nlev' == 2
    assert `c2' == 3
}
local _rc = _rc
_fgtbp_result `_rc' "TBP-1 K = 2, J = 3: exactly 3 baseline scans (pre-fix: 6)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# TBP-2  doubling K does not change the number of scans
* -----------------------------------------------------------------------------
* The scaling claim itself.  TBP-1 alone would pass a build that had merely
* changed the constant.
local ++test_count
capture noisily {
    _fgtbp_data 20260904 900 4
    quietly finegray x1 x2, compete(status) cause(1) tvc(x1) tsplit(0.4 0.9) ///
        bstrata(ctr) nolog

    _fgtbp_count, spec("quietly finegray x1 x2, compete(status) cause(1) tvc(x1) tsplit(0.4 0.9) bstrata(ctr) nolog basehaz")
    local c4 = r(calls)
    quietly levelsof ctr, local(levs)
    local nlev : word count `levs'
    display as text "  TBP-2 K = `nlev', nint = 3, baseline scans = `c4'"
    assert !missing(`c4')
    assert `nlev' == 4
    assert `c4' == 3
}
local _rc = _rc
_fgtbp_result `_rc' "TBP-2 K = 4, J = 3: still exactly 3 baseline scans (pre-fix: 12)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# TBP-3  the assembled curve is still stratum-major and ascending
* -----------------------------------------------------------------------------
* _finegray_bh_stratum selects a block by its stratum VALUE in column 1 and then
* runs an ordinary ascending-time search inside it, so the layout is a contract:
* all of stratum 1's intervals in time order, then stratum 2's.  Interleaving
* the strata, or letting a block restart in time, would answer a CIF from the
* wrong row at rc 0.
local ++test_count
capture noisily {
    _fgtbp_data 20260904 900 4
    quietly finegray x1 x2, compete(status) cause(1) tvc(x1) tsplit(0.4 0.9) ///
        bstrata(ctr) nolog basehaz
    tempname BH
    matrix `BH' = e(basehaz)
    assert colsof(`BH') == 3
    local K = rowsof(`BH')
    assert `K' > 4

    * stratum-major: column 1 changes value at most nlev - 1 times, and never
    * returns to a value it has left
    local nblocks = 1
    local seen "`=`BH'[1, 1]'"
    forvalues i = 2/`K' {
        if `BH'[`i', 1] != `BH'[`i' - 1, 1] {
            local ++nblocks
            local v = `BH'[`i', 1]
            assert strpos(" `seen' ", " `v' ") == 0
            local seen "`seen' `v'"
        }
    }
    display as text "  TBP-3 rows = `K', stratum blocks = `nblocks' (levels 4)"
    assert `nblocks' == 4

    * ascending time and non-decreasing cumulative hazard inside each block
    forvalues i = 2/`K' {
        if `BH'[`i', 1] == `BH'[`i' - 1, 1] {
            assert !missing(`BH'[`i', 2], `BH'[`i', 3])
            assert `BH'[`i', 2] > `BH'[`i' - 1, 2]
            assert `BH'[`i', 3] >= `BH'[`i' - 1, 3]
        }
    }
}
local _rc = _rc
_fgtbp_result `_rc' "TBP-3 e(basehaz) is stratum-major with ascending time and non-decreasing cumhaz per block"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# Summary
display as text _newline ///
    "RESULT: test_finegray_tvc_bstrata_perf tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture log close _fgtbp
    exit 1
}
display as result "ALL TESTS PASSED"
capture log close _fgtbp
