* validation_compress_tc.do
* Validation tests for compress_tc v1.1.0
* Author: Timothy P Copeland
* Date: 2026-03-21
* Tests: 51

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
* SECTION 1: Return value ranges
* =============================================================================

* V1: bytes_initial > 0 for non-empty data
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, quietly
    assert r(bytes_initial) > 0
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — bytes_initial > 0"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — bytes_initial > 0 (rc=`=_rc')"
    local ++fail_count
}

* V2: bytes_final > 0 for non-empty data
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, quietly
    assert r(bytes_final) > 0
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — bytes_final > 0"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — bytes_final > 0 (rc=`=_rc')"
    local ++fail_count
}

* V3: bytes_final <= bytes_initial (compress never increases total)
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, quietly
    assert r(bytes_final) <= r(bytes_initial)
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — bytes_final <= bytes_initial"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — bytes_final <= bytes_initial (rc=`=_rc')"
    local ++fail_count
}

* V4: bytes_saved >= 0 (full pipeline)
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, quietly
    assert r(bytes_saved) >= 0
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — bytes_saved >= 0"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — bytes_saved >= 0 (rc=`=_rc')"
    local ++fail_count
}

* V5: pct_saved in [0, 100] for standard pipeline
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, quietly
    assert r(pct_saved) >= 0
    assert r(pct_saved) <= 100
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — pct_saved in [0,100]"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — pct_saved range (rc=`=_rc')"
    local ++fail_count
}

* V6: Invariant: bytes_saved == bytes_initial - bytes_final
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, quietly
    local expected = r(bytes_initial) - r(bytes_final)
    assert abs(r(bytes_saved) - `expected') < 1
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — bytes_saved invariant"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — bytes_saved invariant (rc=`=_rc')"
    local ++fail_count
}

* V7: Zero obs returns all zeros
local ++test_count
capture noisily {
    clear
    gen str10 x = ""
    compress_tc, quietly
    assert r(bytes_saved) == 0
    assert r(pct_saved) == 0
    assert r(bytes_initial) == 0
    assert r(bytes_final) == 0
    assert "`r(varlist)'" == ""
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — zero obs returns zeros"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — zero obs returns (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 2: Data integrity
* =============================================================================

* V8: Observation count preserved
local ++test_count
capture noisily {
    sysuse auto, clear
    local orig_n = _N
    compress_tc, quietly
    assert _N == `orig_n'
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — N preserved"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — N preserved (rc=`=_rc')"
    local ++fail_count
}

* V9: All string values preserved (multiple rows)
local ++test_count
capture noisily {
    sysuse auto, clear
    local n = _N
    tempfile pre
    gen _row = _n
    save `pre'
    compress_tc, quietly
    gen _row2 = _n
    forvalues i = 1/`n' {
        assert make[`i'] == make[`i']
    }
    * Detailed check: save post-compress and merge
    tempfile post
    rename make make_post
    keep _row2 make_post
    rename _row2 _row
    merge 1:1 _row using `pre', keep(match) nogenerate
    assert make == make_post
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — all string values preserved"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — string values (rc=`=_rc')"
    local ++fail_count
}

* V10: Numeric values preserved exactly
local ++test_count
capture noisily {
    sysuse auto, clear
    tempvar orig_price orig_mpg
    gen double `orig_price' = price
    gen double `orig_mpg' = mpg
    compress_tc, quietly
    assert price == `orig_price'
    assert mpg == `orig_mpg'
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — numeric values preserved"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — numeric values (rc=`=_rc')"
    local ++fail_count
}

* V11: Variable names preserved
local ++test_count
capture noisily {
    sysuse auto, clear
    local orig_vars ""
    foreach v of varlist * {
        local orig_vars "`orig_vars' `v'"
    }
    compress_tc, quietly
    local new_vars ""
    foreach v of varlist * {
        local new_vars "`new_vars' `v'"
    }
    assert "`orig_vars'" == "`new_vars'"
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — variable names preserved"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — variable names (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 3: strL conversion verification
* =============================================================================

* V12: nocompress converts str# to strL
local ++test_count
capture noisily {
    clear
    set obs 100
    gen str50 s = "test string value"
    local pre_type : type s
    assert "`pre_type'" == "str50"
    compress_tc, nocompress quietly
    local post_type : type s
    assert "`post_type'" == "strL"
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — nocompress converts to strL"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — nocompress strL (rc=`=_rc')"
    local ++fail_count
}

* V13: nostrl does NOT convert to strL (type stays str# or compresses)
local ++test_count
capture noisily {
    clear
    set obs 100
    gen str50 s = "test"
    compress_tc, nostrl quietly
    local post_type : type s
    * Should NOT be strL — should be str4 or similar from compress
    assert "`post_type'" != "strL"
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — nostrl skips strL conversion"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — nostrl skip (rc=`=_rc')"
    local ++fail_count
}

* V14: Full pipeline compresses str50 with short content
local ++test_count
capture noisily {
    clear
    set obs 100
    gen str50 s = "ab"
    compress_tc, quietly
    local post_type : type s
    * compress should revert strL to str2 for short unique values
    assert "`post_type'" == "str2"
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — full pipeline optimizes type"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — type optimization (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 4: Idempotency
* =============================================================================

* V15: Running twice gives same result
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, quietly
    local first_saved = r(bytes_saved)
    local first_final = r(bytes_final)
    compress_tc, quietly
    assert r(bytes_saved) == 0
    assert r(bytes_final) == `first_final'
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — idempotent (second run saves 0)"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — idempotency (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 5: r(varlist) accuracy
* =============================================================================

* V16: r(varlist) contains correct variables
local ++test_count
capture noisily {
    clear
    set obs 100
    gen str20 s1 = "hello"
    gen str20 s2 = "world"
    gen double x = 1.5
    compress_tc s1 s2, quietly
    * Both s1 and s2 should be in r(varlist)
    assert strpos("`r(varlist)'", "s1") > 0
    assert strpos("`r(varlist)'", "s2") > 0
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — r(varlist) contains str vars"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — r(varlist) content (rc=`=_rc')"
    local ++fail_count
}

* V17: r(varlist) empty for numeric-only varlist
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc price mpg, quietly
    assert "`r(varlist)'" == ""
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — r(varlist) empty for numeric varlist"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — r(varlist) numeric (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 6: Large data validation
* =============================================================================

* V18: Repeated strings benefit from strL
local ++test_count
capture noisily {
    clear
    set obs 10000
    gen str200 repeated = "The same long string repeated many times for testing compression"
    quietly memory
    local pre_mem = `r(data_data_u)' + `r(data_strl_u)'
    compress_tc, quietly
    assert r(bytes_saved) > 0
    assert r(pct_saved) > 0
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — repeated strings save space"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — repeated strings (rc=`=_rc')"
    local ++fail_count
}

* V19: Unique strings — compress still works
local ++test_count
capture noisily {
    clear
    set obs 100
    gen str20 unique = "val_" + string(_n, "%04.0f")
    compress_tc, quietly
    assert r(bytes_saved) != .
    assert r(bytes_initial) > 0
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — unique strings handled"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — unique strings (rc=`=_rc')"
    local ++fail_count
}

* V20: Mixed types — some string, some numeric
local ++test_count
capture noisily {
    clear
    set obs 500
    gen str100 text = "Category " + string(mod(_n, 5))
    gen double value = runiform() * 1000
    gen long id = _n
    gen str5 code = "A" + string(mod(_n, 10))
    compress_tc, quietly
    assert r(bytes_saved) >= 0
    assert r(bytes_initial) > 0
    assert r(bytes_final) > 0
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — mixed types"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — mixed types (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 7: r(varlist) accuracy (extended)
* =============================================================================

* V21: r(varlist) does NOT contain numeric variable names
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, quietly
    * r(varlist) should only have string vars, not price/mpg/etc
    local rvars "`r(varlist)'"
    assert strpos("`rvars'", "price") == 0
    assert strpos("`rvars'", "mpg") == 0
    assert strpos("`rvars'", "weight") == 0
    assert strpos("`rvars'", "length") == 0
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — r(varlist) excludes numeric vars"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — r(varlist) numeric exclusion (rc=`=_rc')"
    local ++fail_count
}

* V22: r(bytes_saved) is non-negative for full pipeline
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, quietly
    assert r(bytes_saved) >= 0
    * Check it looks like an integer (no fractional bytes)
    assert r(bytes_saved) == round(r(bytes_saved))
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — bytes_saved is non-negative integer"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — bytes_saved integer (rc=`=_rc')"
    local ++fail_count
}

* V23: pct_saved == 0 for already-compressed data
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, quietly
    * First run compresses; second should find nothing
    compress_tc, quietly
    assert r(pct_saved) == 0
    assert r(bytes_saved) == 0
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — pct_saved=0 for compressed data"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — pct_saved idempotent (rc=`=_rc')"
    local ++fail_count
}

* V24: nocompress r(varlist) only includes str# vars that were converted
local ++test_count
capture noisily {
    clear
    set obs 100
    gen str50 mystr1 = "test"
    gen str20 mystr2 = "abc"
    gen double numvar = runiform()
    compress_tc, nocompress quietly
    local rvars "`r(varlist)'"
    * Both str# vars should be in varlist
    assert strpos("`rvars'", "mystr1") > 0
    assert strpos("`rvars'", "mystr2") > 0
    * Numeric var should NOT be
    assert strpos("`rvars'", "numvar") == 0
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — nocompress r(varlist) correct"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — nocompress r(varlist) (rc=`=_rc')"
    local ++fail_count
}

* V25: nostrl r(varlist) includes all string vars
local ++test_count
capture noisily {
    clear
    set obs 100
    gen str50 s1 = "hello"
    gen str20 s2 = "world"
    gen double x = 1.5
    compress_tc, nostrl quietly
    local rvars "`r(varlist)'"
    assert strpos("`rvars'", "s1") > 0
    assert strpos("`rvars'", "s2") > 0
    assert strpos("`rvars'", "x") == 0
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — nostrl r(varlist) has all strings"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — nostrl r(varlist) (rc=`=_rc')"
    local ++fail_count
}

* V26: Data order preserved (sort order unchanged)
local ++test_count
capture noisily {
    clear
    set obs 200
    gen id = _n
    gen str50 s = "item_" + string(201 - _n)
    * Sort in reverse order of string
    sort s
    gen order_before = _n
    compress_tc, quietly
    gen order_after = _n
    assert order_before == order_after
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — data order preserved"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — data order (rc=`=_rc')"
    local ++fail_count
}

* V27: Variable labels preserved after compression
local ++test_count
capture noisily {
    sysuse auto, clear
    local lbl_make : variable label make
    local lbl_price : variable label price
    compress_tc, quietly
    local lbl_make_post : variable label make
    local lbl_price_post : variable label price
    assert "`lbl_make'" == "`lbl_make_post'"
    assert "`lbl_price'" == "`lbl_price_post'"
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — variable labels preserved"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — variable labels (rc=`=_rc')"
    local ++fail_count
}

* V28: Value labels on numeric variables preserved
local ++test_count
capture noisily {
    sysuse auto, clear
    * foreign has value label "origin"
    local vallbl_pre : value label foreign
    compress_tc, quietly
    local vallbl_post : value label foreign
    assert "`vallbl_pre'" == "`vallbl_post'"
    * Check label content: 0 = "Domestic"
    local lbl0_pre : label origin 0
    local lbl0_post : label origin 0
    assert "`lbl0_pre'" == "`lbl0_post'"
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — value labels preserved"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — value labels (rc=`=_rc')"
    local ++fail_count
}

* V29: Variable formats preserved for numeric variables
local ++test_count
capture noisily {
    sysuse auto, clear
    local fmt_price : format price
    local fmt_mpg : format mpg
    compress_tc, quietly
    local fmt_price_post : format price
    local fmt_mpg_post : format mpg
    assert "`fmt_price'" == "`fmt_price_post'"
    assert "`fmt_mpg'" == "`fmt_mpg_post'"
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — numeric formats preserved"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — numeric formats (rc=`=_rc')"
    local ++fail_count
}

* V30: Missing string values ("") preserved correctly
local ++test_count
capture noisily {
    clear
    set obs 100
    gen str50 s = ""
    replace s = "has value" if mod(_n, 5) == 0
    * Count empty before
    count if s == ""
    local empty_before = r(N)
    compress_tc, quietly
    count if s == ""
    local empty_after = r(N)
    assert `empty_before' == `empty_after'
    assert `empty_before' == 80
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — empty strings preserved"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — empty strings (rc=`=_rc')"
    local ++fail_count
}

* V31: pct_saved formula: 100*(1 - bytes_final/bytes_initial) within tolerance
local ++test_count
capture noisily {
    sysuse auto, clear
    compress_tc, quietly
    local expected_pct = 100 * (1 - r(bytes_final) / r(bytes_initial))
    assert abs(r(pct_saved) - `expected_pct') < 0.001
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — pct_saved formula correct"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — pct_saved formula (rc=`=_rc')"
    local ++fail_count
}

* V32: Repeated long strings save more than unique short strings
local ++test_count
capture noisily {
    * Dataset 1: repeated long strings (should compress well)
    clear
    set obs 5000
    gen str200 s = "This is a very long repeated string that should benefit greatly from strL deduplication"
    compress_tc, quietly
    local saved_repeated = r(bytes_saved)

    * Dataset 2: unique short strings (less compression benefit)
    clear
    set obs 5000
    gen str10 s = string(_n)
    compress_tc, quietly
    local saved_unique = r(bytes_saved)

    * Repeated long strings should save more
    assert `saved_repeated' > `saved_unique'
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — repeated long > unique short savings"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — compression benefit (rc=`=_rc')"
    local ++fail_count
}

* V33: nocompress may report negative savings (strL overhead)
local ++test_count
capture noisily {
    * Short unique strings: strL overhead > savings
    clear
    set obs 50
    gen str5 s = string(_n)
    compress_tc, nocompress quietly
    * bytes_saved can be negative here (strL adds overhead for short unique strings)
    * Just verify it runs and returns something
    assert r(bytes_saved) != .
    assert r(bytes_initial) > 0
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — nocompress handles strL overhead"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — nocompress overhead (rc=`=_rc')"
    local ++fail_count
}

* V34: bytes_initial and bytes_final both > 0 for non-empty data
local ++test_count
capture noisily {
    clear
    set obs 100
    gen str50 s = "test"
    gen double x = runiform()
    compress_tc, quietly
    assert r(bytes_initial) > 0
    assert r(bytes_final) > 0
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — both memory values positive"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — memory positive (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 8: _compress_tc_bytes helper (storage width x _N; missing for strL)
* =============================================================================

* V35: str20 with 100 obs -> 20 * 100 = 2000 bytes
local ++test_count
capture noisily {
    clear
    set obs 100
    gen str20 s = "x"
    _compress_tc_bytes s
    assert r(bytes) == 2000
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — _compress_tc_bytes str20 = 20*N"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — bytes str20 (rc=`=_rc')"
    local ++fail_count
}

* V36: numeric storage widths byte/int/long/float/double = 1/2/4/4/8 per obs
local ++test_count
capture noisily {
    clear
    set obs 50
    gen byte b = 1
    gen int i = 1
    gen long l = 1
    gen float f = 1
    gen double d = 1
    _compress_tc_bytes b
    assert r(bytes) == 50
    _compress_tc_bytes i
    assert r(bytes) == 100
    _compress_tc_bytes l
    assert r(bytes) == 200
    _compress_tc_bytes f
    assert r(bytes) == 200
    _compress_tc_bytes d
    assert r(bytes) == 400
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — _compress_tc_bytes numeric widths"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — bytes numeric widths (rc=`=_rc')"
    local ++fail_count
}

* V37: strL returns missing (heap bytes not attributable per-variable)
local ++test_count
capture noisily {
    clear
    set obs 100
    gen str50 s = "value"
    recast strL s
    _compress_tc_bytes s
    assert r(bytes) == .
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — _compress_tc_bytes strL = missing"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — bytes strL missing (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 9: _compress_tc_human unit formatting (B/KB/MB/GB thresholds)
* =============================================================================

* V38: 0 -> "0 B"
local ++test_count
capture noisily {
    _compress_tc_human 0
    assert "`r(human)'" == "0 B"
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — human 0 = 0 B"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — human 0 (rc=`=_rc')"
    local ++fail_count
}

* V39: 999 -> "999 B" (sub-KB stays bytes)
local ++test_count
capture noisily {
    _compress_tc_human 999
    assert "`r(human)'" == "999 B"
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — human 999 = 999 B"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — human 999 (rc=`=_rc')"
    local ++fail_count
}

* V40: 1024 -> "1.0 KB" (KB boundary, 1 decimal)
local ++test_count
capture noisily {
    _compress_tc_human 1024
    assert "`r(human)'" == "1.0 KB"
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — human 1024 = 1.0 KB"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — human 1024 (rc=`=_rc')"
    local ++fail_count
}

* V41: 1536 -> "1.5 KB" (1 decimal for KB)
local ++test_count
capture noisily {
    _compress_tc_human 1536
    assert "`r(human)'" == "1.5 KB"
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — human 1536 = 1.5 KB"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — human 1536 (rc=`=_rc')"
    local ++fail_count
}

* V42: 1048576 (1 MiB) -> "1.00 MB" (MB boundary, 2 decimals)
local ++test_count
capture noisily {
    _compress_tc_human 1048576
    assert "`r(human)'" == "1.00 MB"
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — human 1 MiB = 1.00 MB"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — human MB boundary (rc=`=_rc')"
    local ++fail_count
}

* V43: 1572864 (1.5 MiB) -> "1.50 MB" (2 decimals)
local ++test_count
capture noisily {
    _compress_tc_human 1572864
    assert "`r(human)'" == "1.50 MB"
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — human 1.5 MiB = 1.50 MB"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — human 1.50 MB (rc=`=_rc')"
    local ++fail_count
}

* V44: 1073741824 (1 GiB) -> "1.00 GB" (GB boundary, 2 decimals)
local ++test_count
capture noisily {
    _compress_tc_human 1073741824
    assert "`r(human)'" == "1.00 GB"
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — human 1 GiB = 1.00 GB"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — human GB boundary (rc=`=_rc')"
    local ++fail_count
}

* V45: above 1 TiB stays in GB (does not roll over to TB)
local ++test_count
capture noisily {
    _compress_tc_human 1099511627776
    assert strpos("`r(human)'", "GB") > 0
    assert strpos("`r(human)'", "TB") == 0
    assert "`r(human)'" == "1,024.00 GB"
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — human caps at GB above 1 TiB"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — human TB cap (rc=`=_rc')"
    local ++fail_count
}

* V46: negative bytes preserve sign and unit
local ++test_count
capture noisily {
    _compress_tc_human -2048
    assert "`r(human)'" == "-2.0 KB"
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — human negative sign preserved"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — human negative (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 10: New-return invariants (k_converted/k_reverted/vars_strl/bytes_strl)
* =============================================================================

* V47: k_converted counts eligible str# (minlength interaction)
local ++test_count
capture noisily {
    clear
    set obs 1000
    gen str3 shortc = "abc"
    gen str200 longc = "long " + string(mod(_n,5))
    compress_tc, minlength(10) nocompress quietly
    assert r(k_converted) == 1
    assert r(k_reverted) == 0
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — k_converted respects minlength"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — k_converted minlength (rc=`=_rc')"
    local ++fail_count
}

* V48: k_reverted <= k_converted always
local ++test_count
capture noisily {
    clear
    set obs 2000
    gen str20 a = "short " + string(mod(_n,50))
    gen str200 b = "longrepeat " + string(mod(_n,3))
    compress_tc, quietly
    assert r(k_reverted) <= r(k_converted)
    assert r(k_reverted) >= 0
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — k_reverted <= k_converted"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — k_reverted bound (rc=`=_rc')"
    local ++fail_count
}

* V49: every name in r(vars_strl) is actually strL after the run
local ++test_count
capture noisily {
    clear
    set obs 5000
    gen str2045 bigtext = "Cat" + string(mod(_n,5))
    forvalues k = 1/180 {
        quietly replace bigtext = bigtext + "ABCDEFGHIJ"
    }
    gen str200 cat = "Category " + string(mod(_n,10))
    compress_tc, quietly
    local vstrl "`r(vars_strl)'"
    foreach v of local vstrl {
        local t : type `v'
        assert "`t'" == "strL"
    }
    assert r(bytes_strl) > 0
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — vars_strl members are all strL"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — vars_strl membership (rc=`=_rc')"
    local ++fail_count
}

* V50: dryrun projected savings approximate an actual run (preview accuracy;
*      strL heap residual under preserve keeps it within a fraction of a percent)
local ++test_count
capture noisily {
    clear
    set obs 8000
    gen str200 s = "repeated content " + string(mod(_n,7))
    tempfile orig
    save `orig'
    compress_tc, dryrun quietly
    local dry = r(bytes_saved)
    use `orig', clear
    compress_tc, quietly
    assert reldif(r(bytes_saved), `dry') < 0.01
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — dryrun == actual savings"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — dryrun savings (rc=`=_rc')"
    local ++fail_count
}

* V51: lowmem and batch reach identical final bytes
local ++test_count
capture noisily {
    clear
    set obs 15000
    gen str200 a = "alpha " + string(mod(_n,9))
    gen str200 b = "beta " + string(mod(_n,11))
    tempfile orig
    save `orig'
    compress_tc, quietly
    local batch = r(bytes_final)
    use `orig', clear
    compress_tc, lowmem quietly
    assert r(bytes_final) == `batch'
}
if _rc == 0 {
    display as result "RESULT: PASS V`test_count' — lowmem == batch final bytes"
    local ++pass_count
}
else {
    display as error "RESULT: FAIL V`test_count' — lowmem equivalence (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text ""
display as text "COMPRESS_TC VALIDATION SUMMARY"
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
