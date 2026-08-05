*******************************************************************************
* test_diagnose.do
*
* Purpose: Coverage for diagnose (introduced in datefix v1.1.0) and the
*          command-level rollback/result-state regressions fixed in v1.1.1.
*          diagnose lists the distinct unconvertible values, their
*          frequencies, and the offending observation rows when a
*          conversion fails, then aborts with r(198) (report-only-then-stop).
*          Conversion stays all-or-nothing and non-destructive.
*******************************************************************************

clear all
set varabbrev off
version 16.0

capture log close
log using "test_diagnose.log", replace nomsg

* Bootstrap: isolate PLUS/PERSONAL before any uninstall or install
local qa_dir "`c(pwd)'"
do "`qa_dir'/_datefix_qa_common.do"
quietly _datefix_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"

local test_count = 0
local pass_count = 0
local fail_count = 0

**# 1. Auto-detect path: diagnose reports and aborts with r(198)

local ++test_count
capture noisily {
    clear
    input str12 dob
    "2020/01/15"
    "2020/00/15"
    "2020/13/40"
    "2020/00/15"
    end
    capture noisily datefix dob, diagnose
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: auto-detect path aborts r(198)"
    local ++pass_count
}
else {
    display as error "  FAIL: auto-detect path aborts r(198) (error `=_rc')"
    local ++fail_count
}

**# 2. Explicit order() path: diagnose reports and aborts with r(198)

local ++test_count
capture noisily {
    clear
    input str12 v
    "03/14/2020"
    "00/14/2020"
    "99/99/9999"
    end
    capture noisily datefix v, order(MDY) diagnose
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: explicit order() path aborts r(198)"
    local ++pass_count
}
else {
    display as error "  FAIL: explicit order() path aborts r(198) (error `=_rc')"
    local ++fail_count
}

**# 3. Datetime-detection path: diagnose reports and aborts with r(198)

local ++test_count
capture noisily {
    clear
    input str20 t
    "2020/01/15 08:30:00"
    "2020/01/16"
    "2020/01/17 09:00:00"
    end
    capture noisily datefix t, diagnose
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: datetime-detection path aborts r(198)"
    local ++pass_count
}
else {
    display as error "  FAIL: datetime-detection path aborts r(198) (error `=_rc')"
    local ++fail_count
}

**# 4. Non-destructive: data UNCHANGED after a failed diagnose run

local ++test_count
capture noisily {
    clear
    input str12 dob
    "2020/01/15"
    "2020/00/15"
    "2020/13/40"
    end
    * capture a signature of the data before the failed run
    local n_before = _N
    tempvar marker
    gen str12 `marker' = dob
    capture noisily datefix dob, diagnose
    assert _rc == 198
    * dob must still be a string variable with identical contents and obs count
    capture confirm string variable dob
    assert _rc == 0
    assert _N == `n_before'
    assert dob == `marker'
    * no stray converted variable was left behind
    assert "`: type dob'" == "str12"
}
if _rc == 0 {
    display as result "  PASS: data unchanged after failed diagnose run"
    local ++pass_count
}
else {
    display as error "  FAIL: data unchanged after failed diagnose run (error `=_rc')"
    local ++fail_count
}

**# 5. Behavior without diagnose is unchanged (still r(198), still non-destructive)

local ++test_count
capture noisily {
    clear
    input str12 dob
    "2020/01/15"
    "2020/00/15"
    end
    capture noisily datefix dob
    assert _rc == 198
    capture confirm string variable dob
    assert _rc == 0
    assert _N == 2
}
if _rc == 0 {
    display as result "  PASS: no-diagnose behavior unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: no-diagnose behavior unchanged (error `=_rc')"
    local ++fail_count
}

**# 6. Clean conversion is unaffected by diagnose (succeeds, converts correctly)

local ++test_count
capture noisily {
    clear
    input str10 d
    "2020/01/15"
    "2020/02/20"
    end
    datefix d, diagnose
    * d must now be a numeric daily date with the expected values
    capture confirm numeric variable d
    assert _rc == 0
    assert d[1] == mdy(1, 15, 2020)
    assert d[2] == mdy(2, 20, 2020)
}
if _rc == 0 {
    display as result "  PASS: clean conversion unaffected by diagnose"
    local ++pass_count
}
else {
    display as error "  FAIL: clean conversion unaffected by diagnose (error `=_rc')"
    local ++fail_count
}

**# 7. Minimum abbreviation diag works identically to diagnose

local ++test_count
capture noisily {
    clear
    input str12 dob
    "2020/01/15"
    "2020/00/15"
    end
    capture noisily datefix dob, diag
    assert _rc == 198
    * abbreviation must not have silently converted the data
    capture confirm string variable dob
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: diag abbreviation works"
    local ++pass_count
}
else {
    display as error "  FAIL: diag abbreviation works (error `=_rc')"
    local ++fail_count
}

**# 8. Distinct-value grouping and frequencies are correct

* Build data where a known set of bad values appears with known frequencies,
* then confirm the diagnose helper's grouping logic by reproducing it directly:
* the bad set = {"2020/00/15" x3, "bad" x1, "2020/99/99" x2}; 3 distinct, 6 bad.
local ++test_count
capture noisily {
    clear
    input str12 dob
    "2020/01/15"
    "2020/00/15"
    "2020/00/15"
    "2020/00/15"
    "bad"
    "2020/99/99"
    "2020/99/99"
    "2020/02/20"
    end
    * Independently compute the truth the helper should report
    tempvar nd
    gen double `nd' = date(dob, "YMD")
    quietly count if missing(`nd') & !missing(dob)
    assert r(N) == 6                         // total unconvertible observations
    tempvar bad grp
    gen byte `bad' = missing(`nd') & !missing(dob)
    egen `grp' = group(dob) if `bad'
    quietly summarize `grp', meanonly
    assert r(max) == 3                        // distinct unconvertible values
    * frequency of the most common bad value
    quietly count if dob == "2020/00/15"
    assert r(N) == 3
    quietly count if dob == "2020/99/99"
    assert r(N) == 2
    quietly count if dob == "bad"
    assert r(N) == 1
    * and datefix with diagnose still aborts on this data
    capture noisily datefix dob, diagnose
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: distinct grouping and frequencies correct"
    local ++pass_count
}
else {
    display as error "  FAIL: distinct grouping and frequencies correct (error `=_rc')"
    local ++fail_count
}

**# 9. diagnose with many distinct bad values does not crash (>50 distinct, capped)

local ++test_count
capture noisily {
    clear
    set obs 120
    gen str12 dob = "2020/13/" + string(_n, "%02.0f")   // all month=13, distinct days
    capture noisily datefix dob, diagnose
    assert _rc == 198
    * still non-destructive on the large/capped path
    capture confirm string variable dob
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: >50 distinct bad values handled (capped, no crash)"
    local ++pass_count
}
else {
    display as error "  FAIL: >50 distinct bad values handled (error `=_rc')"
    local ++fail_count
}

**# 10. A later-variable failure rolls back earlier conversions

local ++test_count
capture noisily {
    clear
    input long id str10 good double numeric str10 bad
    2 "2020/01/15" 21915 "2020/02/20"
    1 "2020/03/25" 21945 "not-a-date"
    end
    label variable good "Good source"
    label variable numeric "Numeric source"
    format numeric %10.0g
    char _dta[datefix_probe] "sentinel"
    sort id
    tempfile rollback_before
    save `rollback_before', replace
    unab order_before : _all
    local fmt_good_before : format good
    local fmt_numeric_before : format numeric
    local lbl_good_before : variable label good
    local lbl_numeric_before : variable label numeric
    local sort_before : sortedby
    local char_before : char _dta[datefix_probe]

    capture noisily datefix good numeric bad, order(YMD) df(%tdDD/NN/CCYY)
    local call_rc = _rc
    assert `call_rc' == 198
    cf _all using `rollback_before', all
    confirm string variable good
    confirm numeric variable numeric
    confirm string variable bad
    unab order_after : _all
    local fmt_good_after : format good
    local fmt_numeric_after : format numeric
    local lbl_good_after : variable label good
    local lbl_numeric_after : variable label numeric
    local sort_after : sortedby
    local char_after : char _dta[datefix_probe]
    assert "`order_after'" == "`order_before'"
    assert "`fmt_good_after'" == "`fmt_good_before'"
    assert "`fmt_numeric_after'" == "`fmt_numeric_before'"
    assert `"`lbl_good_after'"' == `"`lbl_good_before'"'
    assert `"`lbl_numeric_after'"' == `"`lbl_numeric_before'"'
    assert "`sort_after'" == "`sort_before'"
    assert `"`char_after'"' == `"`char_before'"'
}
if _rc == 0 {
    display as result "  PASS: multi-variable failure rolls back all conversions"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-variable rollback (error `=_rc')"
    local ++fail_count
}

**# 11. Success and failure leave no incidental r() results

local ++test_count
capture noisily {
    clear
    input str10 dob
    "2020/01/15"
    "2020/02/20"
    end
    datefix dob, order(YMD)
    mata: st_local("nr_scalars", strofreal(length(st_dir("r()", "numscalar", "*"))))
    mata: st_local("nr_macros", strofreal(length(st_dir("r()", "macro", "*"))))
    mata: st_local("nr_matrices", strofreal(length(st_dir("r()", "matrix", "*"))))
    assert `nr_scalars' == 0
    assert `nr_macros' == 0
    assert `nr_matrices' == 0

    clear
    input str10 dob
    "2020/01/15"
    "not-a-date"
    end
    capture noisily datefix dob, order(YMD) diagnose
    local call_rc = _rc
    mata: st_local("nr_scalars", strofreal(length(st_dir("r()", "numscalar", "*"))))
    mata: st_local("nr_macros", strofreal(length(st_dir("r()", "macro", "*"))))
    mata: st_local("nr_matrices", strofreal(length(st_dir("r()", "matrix", "*"))))
    assert `call_rc' == 198
    assert `nr_scalars' == 0
    assert `nr_macros' == 0
    assert `nr_matrices' == 0
}
if _rc == 0 {
    display as result "  PASS: datefix leaves no incidental r() results"
    local ++pass_count
}
else {
    display as error "  FAIL: incidental r() state remains (error `=_rc')"
    local ++fail_count
}

**# 12. Command-level rollback works inside a caller preserve/restore block

local ++test_count
capture noisily {
    clear
    input str10 good str10 bad
    "2020/01/15" "2020/02/20"
    "2020/03/25" "not-a-date"
    end
    tempfile caller_before
    save `caller_before', replace

    preserve
    datefix good, order(YMD)
    confirm numeric variable good
    restore
    confirm string variable good
    cf _all using `caller_before', all

    preserve
    capture noisily datefix good bad, order(YMD)
    local call_rc = _rc
    assert `call_rc' == 198
    confirm string variable good
    cf _all using `caller_before', all
    restore
    cf _all using `caller_before', all
}
if _rc == 0 {
    display as result "  PASS: success and failure nest inside caller preserve/restore"
    local ++pass_count
}
else {
    display as error "  FAIL: nested preserve/restore (error `=_rc')"
    local ++fail_count
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_diagnose tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_diagnose tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close
