*! test_tvm_point_engine.do
*! Unit test for the half-open point-in-interval engine _tvmerge_point_pairs
*! (_tvm_build_pairs_point). A point matches a master interval iff
*!     low <= key < high     (closed-left, open-right)
*! with missing master low -> -inf, high -> +inf, missing point key dropped.
*! Verified against an independent joinby+filter oracle, for both the inner-join
*! and unmatched(master) modes.

clear all
set varabbrev off
version 16.0

capture log close _all
quietly log using "test_tvm_point_engine.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap
findfile _tvmerge_mata.ado
run "`r(fn)'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""
tempfile IVL PTS ORACLE ENGINE ORACLE_UM ENGINE_UM

**# Deterministic boundary fixture

* Master intervals include closed-left/open-right equality, open bounds, and a
* group with no points. This fixture deliberately hits exact boundaries.
clear
input int gid double(low high) long iobs
1  0 10 1
1 10 20 2
1  .  0 3
1 20  . 4
2  0  5 5
end
save "`IVL'"

* key==low must match; key==high must not. Missing keys never match.
clear
input int gid double key long pobs
1 -1      1
1  0      2
1  5      3
1  9.999  4
1 10      5
1 19.999  6
1 20      7
1  .      8
3  2      9
end
save "`PTS'"

**# Inner-join oracle
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
local ++test_count
if `n_engine' == `n_oracle' local ++pass_count
else {
    di as error "POINT inner count mismatch: engine=`n_engine' oracle=`n_oracle'"
    local ++fail_count
    local failed_tests "`failed_tests' inner_count"
}

local ++test_count
use "`ENGINE'", clear
capture cf _all using "`ORACLE'"
if _rc == 0 local ++pass_count
else {
    di as error "POINT inner SET mismatch (cf rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' inner_set"
}

**# Unmatched-master oracle
* Every interval appears at least once; intervals
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
local ++test_count
if `n_engine_um' == `n_oracle_um' local ++pass_count
else {
    di as error "POINT unmatched count mismatch: engine=`n_engine_um' oracle=`n_oracle_um'"
    local ++fail_count
    local failed_tests "`failed_tests' unmatched_count"
}

local ++test_count
use "`ENGINE_UM'", clear
capture cf _all using "`ORACLE_UM'"
if _rc == 0 local ++pass_count
else {
    di as error "POINT unmatched SET mismatch (cf rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' unmatched_set"
}

capture frame drop _pe_m
capture frame drop _pe_u
capture frame drop _pe_o
capture frame drop _pe_o2

**# Summary
display "RESULT: test_tvm_point_engine tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "point-engine failures:`failed_tests'"
    exit 1
}
