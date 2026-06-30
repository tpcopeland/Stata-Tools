*! test_tvm_point_engine.do
*! Unit test for the half-open point-in-interval engine _tvmerge_point_pairs
*! (_tvm_build_pairs_point). A point matches a master interval iff
*!     low <= key < high     (closed-left, open-right)
*! with missing master low -> -inf, high -> +inf, missing point key dropped.
*! Verified against an independent joinby+filter oracle, for both the inner-join
*! and unmatched(master) modes.

clear all
set more off
set varabbrev off
version 16.0

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap
findfile _tvmerge_mata.ado
run "`r(fn)'"

local FAIL 0
tempfile IVL PTS ORACLE ENGINE ORACLE_UM ENGINE_UM

* intervals (master): gid, low, high   -- include open-ended + a no-point gid
clear
set obs 40
set seed 5150
gen int    gid  = 1 + mod(_n, 6)
gen double low  = floor(runiform()*30)
gen double high = low + 1 + floor(runiform()*7)
gen long   iobs = _n
replace low  = . in 5
replace high = . in 9
save "`IVL'"

* points (using): gid, key  -- non-integer keys to exercise open-right exactly
clear
set obs 80
set seed 90210
gen int    gid = 1 + mod(_n, 7)
gen double key = runiform()*32                 // continuous, not integer
gen long   pobs = _n
replace key = . in 11                          // missing key -> never match
save "`PTS'"

* ---- ORACLE (inner): joinby gid, half-open filter, missing -> +/- inf ----
use "`IVL'", clear
joinby gid using "`PTS'"
gen double _lo = cond(missing(low),  -1e300, low)
gen double _hi = cond(missing(high),  1e300, high)
keep if !missing(key) & _lo <= key & key < _hi
keep iobs pobs
gsort iobs pobs
save "`ORACLE'"
quietly count
local n_oracle = r(N)

* ---- ENGINE (inner) ----
capture frame drop _pe_m
capture frame drop _pe_u
capture frame drop _pe_o
frame create _pe_m
frame _pe_m {
    use "`IVL'", clear
    keep gid low high iobs
    order gid low high iobs
}
frame create _pe_u
frame _pe_u {
    use "`PTS'", clear
    keep gid key pobs
    order gid key pobs
}
frame create _pe_o
_tvmerge_point_pairs _pe_m _pe_u _pe_o
frame _pe_o {
    rename __tvm_mi iobs
    rename __tvm_ui pobs
    gsort iobs pobs
    save "`ENGINE'", replace
    quietly count
    local n_engine = r(N)
}

display as text "inner: oracle=`n_oracle' engine=`n_engine'"
if `n_engine' != `n_oracle' {
    di as error "POINT inner count mismatch: engine=`n_engine' oracle=`n_oracle'"
    local ++FAIL
}
else {
    use "`ENGINE'", clear
    capture cf _all using "`ORACLE'"
    if _rc {
        di as error "POINT inner SET mismatch (cf rc=`=_rc')"
        local ++FAIL
    }
}

* ---- ORACLE (unmatched master): every interval appears >=1 time; intervals
*      with no point get pobs == . ----
use "`IVL'", clear
joinby gid using "`PTS'", unmatched(master)
gen double _lo = cond(missing(low),  -1e300, low)
gen double _hi = cond(missing(high),  1e300, high)
gen byte _ok = !missing(key) & _lo <= key & key < _hi
* keep matched point rows; for intervals with zero matches keep one pobs=.
bysort iobs: egen byte _any = max(_ok)
keep if _ok | _any == 0
replace pobs = . if !_ok
keep iobs pobs
duplicates drop
gsort iobs pobs
save "`ORACLE_UM'"
quietly count
local n_oracle_um = r(N)

* ---- ENGINE (unmatched master) ----
capture frame drop _pe_o2
frame create _pe_o2
_tvmerge_point_pairs _pe_m _pe_u _pe_o2, unmatched
frame _pe_o2 {
    rename __tvm_mi iobs
    rename __tvm_ui pobs
    gsort iobs pobs
    save "`ENGINE_UM'", replace
    quietly count
    local n_engine_um = r(N)
}

display as text "unmatched: oracle=`n_oracle_um' engine=`n_engine_um'"
if `n_engine_um' != `n_oracle_um' {
    di as error "POINT unmatched count mismatch: engine=`n_engine_um' oracle=`n_oracle_um'"
    local ++FAIL
}
else {
    use "`ENGINE_UM'", clear
    capture cf _all using "`ORACLE_UM'"
    if _rc {
        di as error "POINT unmatched SET mismatch (cf rc=`=_rc')"
        local ++FAIL
    }
}

capture frame drop _pe_m
capture frame drop _pe_u
capture frame drop _pe_o
capture frame drop _pe_o2

display as text "{hline 60}"
if `FAIL' > 0 {
    di as error "test_tvm_point_engine: FAILED (`FAIL')"
    exit 9
}
di as result "test_tvm_point_engine: PASSED (engine == joinby oracle, inner + unmatched)"
