* crossval_compress_tc.do
* Cross-validation tests for compress_tc v1.1.0
* Author: Timothy P Copeland
* Date: 2026-03-21
* Tests: 7
*
* Cross-validates compress_tc against manual Stata equivalents:
*   - compress_tc nostrl vs plain compress
*   - compress_tc vs manual recast strL + compress
*   - compress_tc bytes vs memory command
*   - Internal consistency across modes

clear all
set more off
version 16.0

* Setup: find local package
capture ado uninstall compress_tc
local pkg_dir "`c(pwd)'/.."
adopath ++ "`pkg_dir'"

local test_count 0
local pass_count 0
local fail_count 0

* =============================================================================
* CV1: compress_tc nostrl matches plain compress
* =============================================================================

local ++test_count
capture noisily {
    * Run compress_tc nostrl on one copy
    sysuse auto, clear
    compress_tc, nostrl quietly
    local tc_final = r(bytes_final)
    local tc_type_make : type make
    local tc_type_price : type price

    * Run plain compress on fresh copy
    sysuse auto, clear
    quietly memory
    local pre_mem = `r(data_data_u)' + `r(data_strl_u)'
    quietly compress
    quietly memory
    local plain_final = `r(data_data_u)' + `r(data_strl_u)'

    * Memory should match (both do only compress, no strL)
    assert `tc_final' == `plain_final'

    * Variable types should match
    local plain_type_make : type make
    local plain_type_price : type price
    assert "`tc_type_make'" == "`plain_type_make'"
    assert "`tc_type_price'" == "`plain_type_price'"
}
if _rc == 0 {
    display as result "RESULT: PASS CV`test_count' — nostrl matches plain compress"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL CV`test_count' — nostrl vs compress (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* CV2: compress_tc vs manual two-step (recast strL + compress)
* =============================================================================

local ++test_count
capture noisily {
    * Run compress_tc (full pipeline) on one copy
    clear
    set obs 500
    gen str100 text = "Category " + string(mod(_n, 10))
    gen str50 code = "CODE_" + string(mod(_n, 5))
    gen double value = runiform() * 1000
    tempfile base
    save `base'

    compress_tc, quietly
    local tc_final = r(bytes_final)
    local tc_type_text : type text
    local tc_type_code : type code

    * Run manual two-step on fresh copy
    use `base', clear
    quietly ds, has(type str#)
    local strvars `r(varlist)'
    recast strL `strvars'
    quietly compress
    quietly memory
    local manual_final = `r(data_data_u)' + `r(data_strl_u)'

    * Results should match
    assert `tc_final' == `manual_final'

    * Types should match
    local manual_type_text : type text
    local manual_type_code : type code
    assert "`tc_type_text'" == "`manual_type_text'"
    assert "`tc_type_code'" == "`manual_type_code'"
}
if _rc == 0 {
    display as result "RESULT: PASS CV`test_count' — matches manual recast+compress"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL CV`test_count' — vs manual two-step (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* CV3: Running compress_tc twice: second run saves 0
* =============================================================================

local ++test_count
capture noisily {
    sysuse auto, clear
    * First compress_tc does strL + compress
    compress_tc, quietly
    local first_final = r(bytes_final)

    * Second compress_tc should find nothing more to save
    compress_tc, quietly
    assert r(bytes_saved) == 0
    assert r(bytes_final) == `first_final'
}
if _rc == 0 {
    display as result "RESULT: PASS CV`test_count' — second compress_tc saves 0"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL CV`test_count' — idempotent compress_tc (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* CV4: bytes_initial matches memory command output
* =============================================================================

local ++test_count
capture noisily {
    sysuse auto, clear
    quietly memory
    local mem_before = `r(data_data_u)' + `r(data_strl_u)'
    compress_tc, quietly
    * bytes_initial should match what memory reported before compress_tc
    assert r(bytes_initial) == `mem_before'
}
if _rc == 0 {
    display as result "RESULT: PASS CV`test_count' — bytes_initial matches memory"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL CV`test_count' — bytes_initial vs memory (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* CV5: bytes_final matches memory command output post-run
* =============================================================================

local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, quietly
    local tc_final = r(bytes_final)
    quietly memory
    local mem_after = `r(data_data_u)' + `r(data_strl_u)'
    assert `tc_final' == `mem_after'
}
if _rc == 0 {
    display as result "RESULT: PASS CV`test_count' — bytes_final matches post-run memory"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL CV`test_count' — bytes_final vs memory (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* CV6: Varlist subset type matches full-data compression
* =============================================================================

local ++test_count
capture noisily {
    * compress_tc on specific variable
    sysuse auto, clear
    compress_tc make, quietly
    local subset_type : type make

    * compress_tc on all variables — make should end up same type
    sysuse auto, clear
    compress_tc, quietly
    local full_type : type make

    assert "`subset_type'" == "`full_type'"
}
if _rc == 0 {
    display as result "RESULT: PASS CV`test_count' — varlist subset type matches full"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL CV`test_count' — subset vs full type (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* CV7: Internal consistency: nocompress + compress ≈ full pipeline
* =============================================================================

local ++test_count
capture noisily {
    * Step 1: Full pipeline in one shot
    clear
    set obs 1000
    gen str100 text = "Repeated category " + string(mod(_n, 10))
    gen str50 code = "C" + string(mod(_n, 5))
    tempfile base
    save `base'

    compress_tc, quietly
    local full_final = r(bytes_final)
    local full_type_text : type text
    local full_type_code : type code

    * Step 2: Two-step: nocompress then manual compress
    use `base', clear
    compress_tc, nocompress quietly
    local after_strl = r(bytes_final)
    quietly compress
    quietly memory
    local twostep_final = `r(data_data_u)' + `r(data_strl_u)'

    * Final memory should match
    assert `full_final' == `twostep_final'

    * Types should match
    local twostep_type_text : type text
    local twostep_type_code : type code
    assert "`full_type_text'" == "`twostep_type_text'"
    assert "`full_type_code'" == "`twostep_type_code'"
}
if _rc == 0 {
    display as result "RESULT: PASS CV`test_count' — nocompress+compress == full pipeline"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL CV`test_count' — two-step consistency (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text ""
display as text "COMPRESS_TC CROSS-VALIDATION SUMMARY"
display as text "Total:  `test_count'"
display as result "Passed: `pass_count'"
if `fail_count' > 0 {
    display as error "Failed: `fail_count'"
}
else {
    display as text "Failed: `fail_count'"
}

if `fail_count' > 0 {
    exit 1
}
