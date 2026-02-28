*! test_setools_fixes.do
*! Comprehensive tests for setools review fixes (issues 1-10)
*! Run: stata-mp -b do ../../_devkit/_testing/test_setools_fixes.do

version 16.0
set varabbrev off
set more off

local n_pass = 0
local n_fail = 0
local failures ""

// =========================================================================
// Reload all programs
// =========================================================================
capture program drop setools
capture program drop _setools_detail
capture program drop cdp
capture program drop pira
capture program drop procmatch
capture program drop procmatch_match
capture program drop procmatch_first
capture program drop icdexpand
capture program drop icdexpand_expand
capture program drop icdexpand_validate
capture program drop icdexpand_match
capture program drop _icdexpand_single
capture program drop _icdexpand_wildcard
capture program drop _icdexpand_range
capture program drop dateparse
capture program drop dateparse_window
capture program drop dateparse_parse
capture program drop dateparse_validate
capture program drop dateparse_inwindow
capture program drop dateparse_filerange
capture program drop cci_se
capture program drop covarclose
capture program drop sustainedss
capture program drop migrations

local basedir "`c(pwd)'"
run "`basedir'/setools/setools.ado"
run "`basedir'/setools/cdp.ado"
run "`basedir'/setools/pira.ado"
run "`basedir'/setools/procmatch.ado"
run "`basedir'/setools/icdexpand.ado"
run "`basedir'/setools/dateparse.ado"
run "`basedir'/setools/cci_se.ado"
run "`basedir'/setools/covarclose.ado"
run "`basedir'/setools/sustainedss.ado"

display as text _newline _dup(70) "="
display as result "SETOOLS PACKAGE - FIX VALIDATION TESTS"
display as text _dup(70) "="
display as text ""

// =========================================================================
// TEST 1: setools returns correct version (Fix #2)
// =========================================================================
display as text "TEST 1: setools returns correct version"
capture noisily {
    setools
    assert "`r(version)'" == "1.4.3"
}
if _rc == 0 {
    display as result "  PASS"
    local ++n_pass
}
else {
    display as error "  FAIL: version returned was not 1.4.2"
    local ++n_fail
    local failures "`failures' T1"
}

// =========================================================================
// TEST 2: setools basic display and categories
// =========================================================================
display as text "TEST 2: setools basic display and categories"
capture noisily {
    setools
    assert r(n_commands) == 9
    assert "`r(commands)'" != ""
    setools, list
    setools, detail
    setools, category(ms)
    assert r(n_commands) == 3
    setools, category(codes)
    assert r(n_commands) == 3
}
if _rc == 0 {
    display as result "  PASS"
    local ++n_pass
}
else {
    display as error "  FAIL"
    local ++n_fail
    local failures "`failures' T2"
}

// =========================================================================
// TEST 3: cdp allevents option works (Fix #1 - CRITICAL)
// =========================================================================
display as text "TEST 3: cdp allevents option (critical bug fix)"
capture noisily {
    clear
    * Create test data: 2 patients with multiple progressions possible
    input long id double edss long edss_date long dx_date
    1 2.0 21915 21550
    1 3.5 22100 21550
    1 3.5 22300 21550
    1 4.0 22500 21550
    1 5.0 22700 21550
    1 5.0 22900 21550
    2 3.0 21915 21550
    2 4.5 22100 21550
    2 4.5 22300 21550
    2 5.5 22500 21550
    2 6.0 22700 21550
    2 6.0 22900 21550
    end
    format edss_date %td
    format dx_date %td

    * Test with roving + allevents - should find multiple events
    cdp id edss edss_date, dxdate(dx_date) roving allevents keepall

    * Check that allevents produced multiple events (before fix it was ignored)
    assert r(N_events) >= 2

    * Check that event_num variable exists (only created with allevents)
    confirm variable event_num
    confirm variable baseline_edss_at_event
}
if _rc == 0 {
    display as result "  PASS"
    local ++n_pass
}
else {
    display as error "  FAIL: allevents option did not produce expected results"
    local ++n_fail
    local failures "`failures' T3"
}

// =========================================================================
// TEST 4: cdp basic (non-roving) still works
// =========================================================================
display as text "TEST 4: cdp basic non-roving"
capture noisily {
    clear
    input long id double edss long edss_date long dx_date
    1 2.0 21915 21550
    1 3.5 22100 21550
    1 3.5 22300 21550
    2 3.0 21915 21550
    2 3.5 22100 21550
    2 3.0 22300 21550
    end
    format edss_date %td
    format dx_date %td

    cdp id edss edss_date, dxdate(dx_date) keepall
    assert r(N_persons) >= 1
    confirm variable cdp_date
}
if _rc == 0 {
    display as result "  PASS"
    local ++n_pass
}
else {
    display as error "  FAIL"
    local ++n_fail
    local failures "`failures' T4"
}

// =========================================================================
// TEST 5: dateparse window uses long type (Fix #5)
// =========================================================================
display as text "TEST 5: dateparse window uses long type (no int overflow)"
capture noisily {
    clear
    set obs 5
    gen double indexdate = mdy(1, 1, 2040) + (_n - 1) * 365
    format indexdate %td

    * 50-year followup extends to ~2090
    dateparse window indexdate, followup(18262) generate(fu_start fu_end)

    * Verify dates not truncated (int max is 32767 ~ year 2049)
    assert fu_end[5] > mdy(1, 1, 2090)

    * Check variable type is long
    local endtype : type fu_end
    assert "`endtype'" == "long"
    local starttype : type fu_start
    assert "`starttype'" == "long"

    drop fu_start fu_end

    * Test lookback path too
    dateparse window indexdate, lookback(365) generate(lb_start lb_end)
    local lbtype : type lb_start
    assert "`lbtype'" == "long"
}
if _rc == 0 {
    display as result "  PASS"
    local ++n_pass
}
else {
    display as error "  FAIL: dateparse window type issue"
    local ++n_fail
    local failures "`failures' T5"
}

// =========================================================================
// TEST 6: dateparse parse, validate, filerange subcommands
// =========================================================================
display as text "TEST 6: dateparse parse, validate, filerange"
capture noisily {
    * ISO format
    dateparse parse, datestring("2020-01-15")
    assert r(date) == mdy(1, 15, 2020)

    * Compact ISO
    dateparse parse, datestring("20200115")
    assert r(date) == mdy(1, 15, 2020)

    * Validate
    dateparse validate, start("2015-01-01") end("2020-12-31")
    assert r(span_days) > 0

    * Filerange
    dateparse filerange, index_start("2015-01-01") index_end("2018-12-31") lookback(730)
    assert r(file_start_year) == 2013
    assert r(file_end_year) == 2018
}
if _rc == 0 {
    display as result "  PASS"
    local ++n_pass
}
else {
    display as error "  FAIL"
    local ++n_fail
    local failures "`failures' T6"
}

// =========================================================================
// TEST 7: dateparse inwindow subcommand
// =========================================================================
display as text "TEST 7: dateparse inwindow"
capture noisily {
    clear
    input long event_date long win_start long win_end
    22000 21900 22100
    22200 21900 22100
    21800 21900 22100
    end
    format event_date win_start win_end %td

    dateparse inwindow event_date, start(win_start) end(win_end) generate(in_win)
    assert r(n_inwindow) == 1
    assert in_win[1] == 1
    assert in_win[2] == 0
    assert in_win[3] == 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++n_pass
}
else {
    display as error "  FAIL"
    local ++n_fail
    local failures "`failures' T7"
}

// =========================================================================
// TEST 8: icdexpand expand, validate, match
// =========================================================================
display as text "TEST 8: icdexpand expand, validate, match"
capture noisily {
    * Expand
    icdexpand expand, pattern("I63*") noisily
    assert r(n_codes) > 100

    icdexpand expand, pattern("E10-E14")
    assert r(n_codes) > 50

    * Validate
    icdexpand validate, pattern("I63.4, E11.2") noisily
    assert r(valid) == 1

    icdexpand validate, pattern("123invalid") noisily
    assert r(valid) == 0

    * Match
    clear
    input str10 dx1 str10 dx2
    "I63"  "G35"
    "E11"  "I25"
    "G35"  ""
    "J44"  "E14"
    ""     ""
    end

    icdexpand match, codes("G35") dxvars(dx1 dx2) generate(ms_match) noisily
    assert r(n_matches) == 2

    icdexpand match, codes("I63*") dxvars(dx1 dx2) generate(stroke) noisily
    assert r(n_matches) == 1
}
if _rc == 0 {
    display as result "  PASS"
    local ++n_pass
}
else {
    display as error "  FAIL"
    local ++n_fail
    local failures "`failures' T8"
}

// =========================================================================
// TEST 9: procmatch match and first
// =========================================================================
display as text "TEST 9: procmatch match and first"
capture noisily {
    clear
    input long id str10 proc1 str10 proc2 long admitdt
    1 "LAE20" "ABC10" 22000
    2 "XYZ99" "LAF10" 22100
    3 "ABC10" ""      22200
    end
    format admitdt %td

    * Exact match
    procmatch match, codes("LAE20 LAF10") procvars(proc1 proc2) generate(ooph) noisily
    assert r(n_matches) == 2

    * Prefix match
    procmatch match, codes("LAE") procvars(proc1 proc2) generate(ooph_pfx) prefix noisily
    assert r(n_matches) == 1

    * First occurrence
    procmatch first, codes("ABC10") procvars(proc1 proc2) datevar(admitdt) idvar(id) ///
        generate(abc_ever) gendatevar(abc_dt) noisily
    assert r(n_persons) == 2
}
if _rc == 0 {
    display as result "  PASS"
    local ++n_pass
}
else {
    display as error "  FAIL"
    local ++n_fail
    local failures "`failures' T9"
}

// =========================================================================
// TEST 10: cci_se with tempvar refactor (Fix #8)
// =========================================================================
display as text "TEST 10: cci_se with tempvar refactor"
capture noisily {
    clear
    input long id str6 diagnos long utdatum
    1 "I252" 22000
    1 "E115" 22000
    2 "I634" 22000
    2 "G350" 22000
    3 "C501" 22000
    3 "K254" 22000
    end
    format utdatum %td

    cci_se, id(id) icd(diagnos) date(utdatum) components noisily

    assert r(N_patients) == 3
    assert r(N_any) >= 2
    confirm variable charlson
    confirm variable cci_mi
    confirm variable cci_cancer
}
if _rc == 0 {
    display as result "  PASS"
    local ++n_pass
}
else {
    display as error "  FAIL"
    local ++n_fail
    local failures "`failures' T10"
}

// =========================================================================
// TEST 11: cci_se with pre-existing conflicting var names (Fix #8)
// =========================================================================
display as text "TEST 11: cci_se with conflicting variable names"
capture noisily {
    clear
    * Include variables that collided with old hardcoded names
    input long id str6 diagnos long utdatum byte _yr
    1 "I252" 22000 1
    2 "G350" 22000 2
    end
    format utdatum %td

    * Would have failed before tempvar fix
    cci_se, id(id) icd(diagnos) date(utdatum) noisily
    assert r(N_patients) == 2
}
if _rc == 0 {
    display as result "  PASS"
    local ++n_pass
}
else {
    display as error "  FAIL: cci_se failed with pre-existing _yr variable"
    local ++n_fail
    local failures "`failures' T11"
}

// =========================================================================
// TEST 12: cci_se with YYYYMMDD dates
// =========================================================================
display as text "TEST 12: cci_se with YYYYMMDD dates"
capture noisily {
    clear
    input long id str6 diagnos long datum
    1 "I252" 20200115
    2 "G350" 20200601
    end

    cci_se, id(id) icd(diagnos) date(datum) dateformat(yyyymmdd) noisily
    assert r(N_patients) == 2
}
if _rc == 0 {
    display as result "  PASS"
    local ++n_pass
}
else {
    display as error "  FAIL"
    local ++n_fail
    local failures "`failures' T12"
}

// =========================================================================
// TEST 13: covarclose with conflicting var names (Fix #3)
// =========================================================================
display as text "TEST 13: covarclose with conflicting var names"
capture noisily {
    clear
    input long id long indexdate
    1 22000
    2 22100
    3 22200
    end
    format indexdate %td

    * Create covariate file WITH conflicting variable names
    preserve
    clear
    input long id long year double educ double has_before double has_after
    1 2019 3 99 99
    1 2020 4 99 99
    2 2020 2 99 99
    3 2019 5 99 99
    3 2020 5 99 99
    3 2021 5 99 99
    end
    tempfile covar_file
    save `covar_file'
    restore

    * prefer(before) - exercises the has_before code path
    covarclose using `covar_file', idvar(id) indexdate(indexdate) ///
        datevar(year) vars(educ) yearformat prefer(before) noisily
    assert r(n_total) == 3

    * prefer(after) - exercises the has_after code path
    drop educ
    covarclose using `covar_file', idvar(id) indexdate(indexdate) ///
        datevar(year) vars(educ) yearformat prefer(after) noisily
    assert r(n_total) == 3

    * prefer(closest)
    drop educ
    covarclose using `covar_file', idvar(id) indexdate(indexdate) ///
        datevar(year) vars(educ) yearformat prefer(closest) noisily
    assert r(n_total) == 3
}
if _rc == 0 {
    display as result "  PASS"
    local ++n_pass
}
else {
    display as error "  FAIL: covarclose with conflicting var names"
    local ++n_fail
    local failures "`failures' T13"
}

// =========================================================================
// TEST 14: sustainedss basic test
// =========================================================================
display as text "TEST 14: sustainedss basic"
capture noisily {
    clear
    set seed 12345
    set obs 100
    gen long id = ceil(_n/5)
    bysort id: gen visit = _n
    gen long edss_dt = mdy(1,1,2020) + visit*90 + floor(runiform()*30)
    gen double edss = floor(runiform()*10)
    format edss_dt %td

    sustainedss id edss edss_dt, threshold(4) keepall
    assert r(N_events) >= 0
    confirm variable sustained4_dt
}
if _rc == 0 {
    display as result "  PASS"
    local ++n_pass
}
else {
    display as error "  FAIL"
    local ++n_fail
    local failures "`failures' T14"
}

// =========================================================================
// TEST 15: pira basic test
// =========================================================================
display as text "TEST 15: pira basic test"
capture noisily {
    clear
    input long id double edss long edss_date long dx_date
    1 2.0 21915 21550
    1 3.5 22100 21550
    1 3.5 22300 21550
    2 3.0 21915 21550
    2 4.5 22100 21550
    2 4.5 22300 21550
    end
    format edss_date %td
    format dx_date %td

    * Create relapse file
    preserve
    clear
    input long id long relapse_date
    1 22090
    end
    format relapse_date %td
    tempfile relapse_file
    save `relapse_file'
    restore

    pira id edss edss_date, dxdate(dx_date) relapses(`relapse_file') keepall
    assert r(N_cdp) >= 1
    confirm variable pira_date
    confirm variable raw_date
}
if _rc == 0 {
    display as result "  PASS"
    local ++n_pass
}
else {
    display as error "  FAIL"
    local ++n_fail
    local failures "`failures' T15"
}

// =========================================================================
// TEST 16: pira rejects undocumented roving option (Fix #10)
// =========================================================================
display as text "TEST 16: pira rejects undocumented roving option"
capture noisily {
    clear
    input long id double edss long edss_date long dx_date
    1 2.0 21915 21550
    1 3.5 22100 21550
    1 3.5 22300 21550
    end
    format edss_date %td
    format dx_date %td

    preserve
    clear
    input long id long relapse_date
    1 22090
    end
    format relapse_date %td
    tempfile relapse_file2
    save `relapse_file2'
    restore

    * roving is NOT in the syntax, so this should error
    capture pira id edss edss_date, dxdate(dx_date) relapses(`relapse_file2') roving
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS"
    local ++n_pass
}
else {
    display as error "  FAIL: pira accepted undocumented roving option"
    local ++n_fail
    local failures "`failures' T16"
}

// =========================================================================
// SUMMARY
// =========================================================================
display as text _newline _dup(70) "="
display as text "TEST SUMMARY"
display as text _dup(70) "="
display as text "  Passed: " as result `n_pass'
display as text "  Failed: " as result `n_fail'
display as text "  Total:  " as result `n_pass' + `n_fail'

if `n_fail' > 0 {
    display as error _newline "FAILED TESTS: `failures'"
    exit 1
}
else {
    display as result _newline "ALL TESTS PASSED"
}
