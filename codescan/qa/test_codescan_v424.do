* test_codescan_v424.do - Regression tests for the v4.2.4 fixes
* Date: 2026-09-29
*
* Covers:
*   T1-T5:  tostring writes numeric codes exactly (codescan and codescan_describe)
*   T6-T9:  non-daily and left-aligned date formats under a window are refused;
*           the unwindowed non-daily path stays accepted and correct
*   T10:    export(.csv) honours an explicit format(); full precision without it
*   T11-T12: merge keeps the caller's sort marker, truncated at a replaced key
*   T13:    no session setting leaked
*
* The tostring oracle is independent of the conversion under test: the ground
* truth is the code TEXT, which is read into a numeric variable and must come
* back out of the scan as the same text.

clear all
version 16.0
set varabbrev off
set seed 42400
capture log close _all

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap
local _qa_owner "`r(owner)'"

local _qa_va0 "`c(varabbrev)'"


**# T1: a 13-digit double code matches its own digits (was 1.23457e+12)

local ++test_count
capture noisily {
    clear
    input double ndc
    1234567890123
    1234567890124
    987654321
    end
    codescan ndc, define(hit "1234567890123") tostring matched_code(mc)
    assert r(summary)[1, 4] == 1
    assert hit == (_n == 1)
    assert mc[1] == "1234567890123"
    assert mc[2] == "" & mc[3] == ""
    * The numeric source is untouched.
    confirm numeric variable ndc
    assert ndc[1] == 1234567890123
}
if _rc == 0 {
    display as result "  PASS: T1 - large integer code converted in full"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - large integer code (error `=_rc')"
    local ++fail_count
}


**# T2: float decimal codes read back as typed (was 401.8999939)

local ++test_count
capture noisily {
    clear
    input float icd9
    401.9
    250.01
    250
    .
    .a
    end
    codescan icd9, define(htn "4019" | dm "25001" | dmany "250") ///
        tostring nodots matched_code(mc)
    assert htn == (_n == 1)
    assert dm == (_n == 2)
    assert dmany == inlist(_n, 2, 3)
    assert mc[1] == "401.9"
    assert mc[2] == "250.01"
    assert mc[3] == "250"
    * Missing and extended missing stay empty, never ".a" -> "a".
    assert mc[4] == "" & mc[5] == ""
    assert htn[5] == 0 & dm[5] == 0 & dmany[5] == 0
}
if _rc == 0 {
    display as result "  PASS: T2 - float decimals and missings converted exactly"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - float decimal conversion (error `=_rc')"
    local ++fail_count
}


**# T3: extended missing never matches under nocase + nodots

local ++test_count
capture noisily {
    clear
    input double code
    .a
    .z
    12
    end
    codescan code, define(a "A" | z "Z") tostring nodots nocase
    assert a == 0 & z == 0
    assert r(summary)[1, 4] == 0 & r(summary)[2, 4] == 0
}
if _rc == 0 {
    display as result "  PASS: T3 - extended missing is an empty code"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - extended missing matched (error `=_rc')"
    local ++fail_count
}


**# T4: random numeric codes round-trip text -> number -> scanned text

local ++test_count
capture noisily {
    clear
    set obs 400
    * Ground-truth text: canonical decimal forms (no trailing zeros, no
    * leading zeros), built as strings BEFORE any number exists.
    gen str24 truth = ""
    gen double _u = runiform()
    gen long _i = floor(runiform() * 900000) + 100
    gen int _d = floor(runiform() * 99) + 1
    replace truth = string(_i) if _u < 0.3
    replace truth = string(_i) + string(floor(runiform() * 9000000) + 1000000) if _u >= 0.3 & _u < 0.5
    replace truth = string(floor(_i / 1000) + 1) + "." + string(_d) if _u >= 0.5
    replace truth = regexr(truth, "0+$", "") if strpos(truth, ".")
    replace truth = regexr(truth, "\.$", "")
    gen double dcode = real(truth)
    * Float storage only for codes a float holds to their written precision.
    gen float fcode = real(truth) if strlen(subinstr(truth, ".", "", 1)) <= 6
    codescan dcode, define(any ".") tostring matched_code(dmc)
    assert dmc == truth
    count if !missing(fcode)
    local _t4_nf = r(N)
    assert !missing(`_t4_nf') & `_t4_nf' > 100
    codescan fcode, define(anyf ".") tostring matched_code(fmc)
    assert fmc == truth if !missing(fcode)
    assert fmc == "" if missing(fcode)
}
if _rc == 0 {
    display as result "  PASS: T4 - 400 random codes round-trip exactly (double and float)"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - random round-trip (error `=_rc')"
    local ++fail_count
}


**# T5: codescan_describe inventories the codes that exist

local ++test_count
capture noisily {
    clear
    input double big float f
    1234567890123 401.9
    1234567890123 250.01
    . 401.9
    end
    tempfile before5
    save "`before5'"
    codescan_describe big f, tostring
    assert r(n_unique) == 3
    assert r(n_entries) == 5
    local codes ""
    forvalues i = 1/3 {
        local codes `"`codes' "`r(top_code_`i')'""'
    }
    assert `: list posof "1234567890123" in codes' > 0
    assert `: list posof "401.9" in codes' > 0
    assert `: list posof "250.01" in codes' > 0
    * The caller's numeric variables come back unchanged.
    unab _t5_vars : _all
    describe using "`before5'", varlist
    assert "`_t5_vars'" == "`r(varlist)'"
    cf _all using "`before5'", all
    assert "`_t5_vars'" == "big f"
    confirm numeric variable big f
}
if _rc == 0 {
    display as result "  PASS: T5 - codescan_describe converts exactly and restores the data"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - codescan_describe tostring (error `=_rc')"
    local ++fail_count
}


**# T6: a monthly date under lookback() is refused, data untouched

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 double vm double rm
    1 "E110" 700 712
    2 "E110" 600 712
    3 "Z00"  710 712
    end
    format vm rm %tm
    tempfile before6
    save "`before6'"
    capture codescan dx1, define(dm "E11") id(pid) date(vm) refdate(rm) ///
        lookback(365) collapse
    assert _rc == 198
    capture confirm variable dm
    assert _rc != 0
    assert _N == 3
    unab _t6_vars : _all
    describe using "`before6'", varlist
    assert "`_t6_vars'" == "`r(varlist)'"
    cf _all using "`before6'", all
    assert "`_t6_vars'" == "pid dx1 vm rm"
}
if _rc == 0 {
    display as result "  PASS: T6 - %tm date with lookback() refused"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - %tm date with lookback() (error `=_rc')"
    local ++fail_count
}


**# T7: a left-aligned datetime (%-tc) gets the datetime refusal, not r(2000)

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 double vc double rc
    1 "E110" 1000 90000000
    end
    format vc rc %-tc
    capture codescan dx1, define(dm "E11") id(pid) date(vc) refdate(rc) ///
        lookback(365) collapse
    assert _rc == 198
    assert _N == 1
}
if _rc == 0 {
    display as result "  PASS: T7 - %-tc refused as a datetime"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - %-tc datetime (error `=_rc')"
    local ++fail_count
}


**# T8: every non-daily unit, either variable, either window direction

local ++test_count
capture noisily {
    foreach fmt in %tw %tq %th %ty %tbx_cal %-tm %-tw {
        foreach which in date refdate {
            clear
            set obs 1
            gen long pid = 1
            gen str6 dx1 = "E110"
            gen double d = 10
            gen double r = 12
            format d r %td
            if "`which'" == "refdate" format r `fmt'
            if "`which'" == "date" format d `fmt'
            capture codescan dx1, define(dm "E11") date(d) refdate(r) lookforward(5)
            if _rc != 198 {
                display as error "    `fmt' on `which'(): rc=" _rc
                exit 9
            }
        }
    }
    * A daily format, including a left-aligned one, still runs.
    clear
    input long pid str6 dx1 double d double r
    1 "E110" 21914 21915
    end
    format d r %-tdCCYY-NN-DD
    codescan dx1, define(dm "E11") date(d) refdate(r) lookback(5)
    assert dm[1] == 1
}
if _rc == 0 {
    display as result "  PASS: T8 - non-daily units refused under a window; %-td accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 - non-daily units (error `=_rc')"
    local ++fail_count
}


**# T9: without a window, a monthly date still summarizes in its own unit

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 double vm
    1 "E110" 700
    1 "E119" 702
    1 "E119" 702
    2 "Z00"  705
    end
    format vm %tm
    codescan dx1, define(dm "E11") id(pid) date(vm) collapse alldates
    assert _N == 2
    assert dm_first[1] == 700 & dm_last[1] == 702 & dm_count[1] == 2
    assert dm[2] == 0 & missing(dm_first[2])
    local f : format dm_first
    assert "`f'" == "%tm"
}
if _rc == 0 {
    display as result "  PASS: T9 - unwindowed %tm date summaries still accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 - unwindowed %tm date (error `=_rc')"
    local ++fail_count
}


**# T10: export(.csv) honours an explicit format(); full precision without

local ++test_count
capture noisily {
    capture erase "`qa_dir'/_v424_fmt.csv"
    capture erase "`qa_dir'/_v424_full.csv"
    clear
    input long pid str6 dx1
    1 "E110"
    2 "I10"
    3 "Z00"
    end
    codescan dx1, define(dm "E11" | htn "I10") export("`qa_dir'/_v424_fmt.csv") ///
        format(%9.2f)
    codescan dx1, define(dm "E11" | htn "I10") export("`qa_dir'/_v424_full.csv") ///
        replace
    import delimited "`qa_dir'/_v424_fmt.csv", clear stringcols(_all) varnames(1)
    assert prevalence[1] == "33.33" & prevalence[2] == "33.33"
    * Column order is unchanged by the reformat.
    unab _t10_vars : _all
    assert "`_t10_vars'" == "condition label matches total_hits positive_units prevalence pattern exclusion"
    import delimited "`qa_dir'/_v424_full.csv", clear stringcols(_all) varnames(1)
    assert abs(real(prevalence[1]) - 100/3) < 1e-10
    capture erase "`qa_dir'/_v424_fmt.csv"
    capture erase "`qa_dir'/_v424_full.csv"
}
if _rc == 0 {
    display as result "  PASS: T10 - csv prevalence follows format(); full precision by default"
    local ++pass_count
}
else {
    display as error "  FAIL: T10 - csv export format (error `=_rc')"
    local ++fail_count
}


**# T11: merge keeps the caller's sort marker and row order

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 double v
    2 "E110" 3
    1 "E110" 1
    1 "Z00"  2
    1 "Z00"  2
    end
    sort pid v
    gen long _ord = _n
    codescan dx1, define(dm "E11") id(pid) merge
    assert "`: sortedby'" == "pid v"
    assert _ord == _n
    * by-group use without an explicit sort is what the marker is for.
    by pid: assert dm == dm[1]
    codescan dx1, define(dm2 "E11") id(pid) date(v) merge countdate
    assert "`: sortedby'" == "pid v"
    assert _ord == _n
    assert dm2_count == 1
}
if _rc == 0 {
    display as result "  PASS: T11 - merge keeps sortedby and order"
    local ++pass_count
}
else {
    display as error "  FAIL: T11 - merge sortedby (error `=_rc')"
    local ++fail_count
}


**# T12: a sort key the merge replaced ends the declared marker

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 byte dm
    1 "E110" 0
    1 "Z00"  0
    2 "Z00"  1
    end
    sort pid dm
    codescan dx1, define(dm "E11") id(pid) merge replace
    * dm was rewritten, so the data are no longer known to be sorted by it.
    assert "`: sortedby'" == "pid"
    assert dm == (pid == 1)
}
if _rc == 0 {
    display as result "  PASS: T12 - replaced sort key truncates sortedby"
    local ++pass_count
}
else {
    display as error "  FAIL: T12 - replaced sort key (error `=_rc')"
    local ++fail_count
}


**# T13: no session setting leaked

local ++test_count
capture noisily {
    assert "`c(varabbrev)'" == "`_qa_va0'"
    assert "`c(frame)'" == "default"
}
if _rc == 0 {
    display as result "  PASS: T13 - no session setting leaked"
    local ++pass_count
}
else {
    display as error "  FAIL: T13 - session setting leaked (error `=_rc')"
    local ++fail_count
}


**# Summary

_codescan_qa_restore "`_qa_owner'"
_codescan_qa_publish "test_codescan_v424" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_codescan_v424 tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Functional Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}

display as result "ALL TESTS PASSED"
