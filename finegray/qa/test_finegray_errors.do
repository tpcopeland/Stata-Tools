*! test_finegray_errors.do - Public error-contract coverage for finegray
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set more off
set varabbrev off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
capture log close _all
log using "test_finegray_errors.log", replace text name(_test_finegray_errors)
do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap

capture program drop _fge_make
program define _fge_make
    clear
    set seed 20260823
    set obs 240
    generate long id = _n
    generate double x = rnormal()
    generate byte event = cond(_n <= 90, 1, cond(_n <= 150, 2, 0))
    generate double time = 1 + mod(_n, 12)
    generate byte marker = 97
    quietly stset time, failure(event) id(id)
end

capture program drop _fge_record
program define _fge_record
    args rc label
    if `rc' == 0 display as result "  PASS: `label'"
    else display as error "  FAIL: `label' (error `rc')"
end

**# Estimation command early option conflict and legal fit
local ++test_count
capture noisily {
    _fge_make
    capture noisily finegray x, compete(event) cause(1) adjust(noadjust) robust(norobust)
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker == 97
    assert _N == 240
    capture noisily finegray x, compete(event) cause(1) nolog
    local legal_rc = _rc
    assert `legal_rc' == 0
    assert "`e(cmd)'" == "finegray"
    matrix FGE_b = e(b)
}
local block_rc = _rc
_fge_record `block_rc' "finegray rejects incompatible adjustment/robust options; legal fit posts e()"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

**# CIF mid-path grid conflict preserves fitted state and data
local ++test_count
capture noisily {
    capture noisily finegray_cif, attime(4) timepoints(2 4) nograph
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker == 97
    assert "`e(cmd)'" == "finegray"
    assert mreldif(FGE_b, e(b)) < 1e-12
    capture noisily finegray_cif, attime(4) nograph
    local legal_rc = _rc
    assert `legal_rc' == 0
    tempname cif_table cif_profile
    matrix `cif_table' = r(table)
    matrix `cif_profile' = r(at)
    assert rowsof(`cif_table') == 1
    assert `cif_table'[1, 1] == 4
    assert !missing(`cif_table'[1, 1], `cif_table'[1, 2], `cif_table'[1, 3])
    assert missing(`cif_table'[1, 4], `cif_table'[1, 5])
    mata: assert(!hasmissing(st_matrix("`cif_profile'")))
}
local block_rc = _rc
_fge_record `block_rc' "finegray_cif rejects competing grids without mutating fit; attime() works"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

**# PH diagnostic option contract
local ++test_count
capture noisily {
    quietly finegray_phtest
    assert "`r(time)'" == "rank"
    capture noisily finegray_phtest, time(badscale)
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker == 97
    assert "`e(cmd)'" == "finegray"
    assert mreldif(FGE_b, e(b)) < 1e-12
    capture noisily finegray_phtest, time(rank)
    local legal_rc = _rc
    assert `legal_rc' == 0
    confirm matrix r(phtest)
}
local block_rc = _rc
_fge_record `block_rc' "finegray_phtest defaults to rank, rejects invalid time scales, and preserves fit"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

**# Prediction option ignored-success probe and legal inverse
local ++test_count
capture noisily {
    capture noisily finegray_predict badxb, xb seed(1)
    local call_rc = _rc
    assert `call_rc' == 198
    capture confirm variable badxb
    assert _rc == 111
    assert marker == 97
    assert "`e(cmd)'" == "finegray"
    assert mreldif(FGE_b, e(b)) < 1e-12
    capture noisily finegray_predict goodxb, xb
    local legal_rc = _rc
    assert `legal_rc' == 0
    confirm variable goodxb
    assert !missing(goodxb)
}
local block_rc = _rc
_fge_record `block_rc' "finegray_predict refuses ignored seed(); legal xb creates exactly its target"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_finegray_errors tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _test_finegray_errors
if `fail_count' > 0 exit 1
exit 0
