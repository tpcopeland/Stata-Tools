clear all
set more off
version 16.0

* test_datamap_privacy.do - Regression tests for the exclude() privacy contract
* Generated: 2026-06-16 (datamap 1.1.1)
* Guards the v1.1.1 fix: excluded variables must never leak their values,
* cardinality, max length, or value-label coding in ANY output surface
* (Binary section, QUICK REFERENCE, JSON, or VALUE LABEL DEFINITIONS).
* Also includes a structural JSON-validity check.

local test_count = 0
local pass_count = 0
local fail_count = 0

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force

* Helper: does a file contain a needle anywhere?
capture program drop _priv_file_contains
program define _priv_file_contains, rclass
    version 16.0
    syntax using/ , NEEDLE(string)
    tempname fh
    local found 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`needle'"') > 0 local found 1
        file read `fh' line
    }
    file close `fh'
    return scalar found = `found'
end

* Helper: structural JSON validity (balanced braces/brackets, no trailing commas)
capture program drop _priv_json_ok
program define _priv_json_ok, rclass
    version 16.0
    syntax using/
    tempname fh
    local nopen 0
    local nclose 0
    local nbopen 0
    local nbclose 0
    local trailing 0
    local blob ""
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        local t = strtrim(`"`macval(line)'"')
        local nopen   = `nopen'   + length(`"`t'"') - length(subinstr(`"`t'"', "{", "", .))
        local nclose  = `nclose'  + length(`"`t'"') - length(subinstr(`"`t'"', "}", "", .))
        local nbopen  = `nbopen'  + length(`"`t'"') - length(subinstr(`"`t'"', "[", "", .))
        local nbclose = `nbclose' + length(`"`t'"') - length(subinstr(`"`t'"', "]", "", .))
        local blob `"`blob'`t'"'
        file read `fh' line
    }
    file close `fh'
    if strpos(`"`blob'"', ",}") > 0 local trailing 1
    if strpos(`"`blob'"', ",]") > 0 local trailing 1
    return scalar braces_ok   = (`nopen' == `nclose')
    return scalar brackets_ok = (`nbopen' == `nbclose')
    return scalar trailing    = `trailing'
end

* === Adversarial fixture: sensitive vars the user excludes for privacy ===
tempfile pbase ptxt pjson ptxt2
local pdta "`pbase'.dta"
clear
set obs 50
gen double patient_id = _n
gen byte hiv_status = mod(_n, 2)
label define yn 0 "Negative" 1 "Positive"
label values hiv_status yn
gen byte sex = mod(_n, 2)
label define sexl 0 "Female" 1 "Male"
label values sex sexl
gen str20 mrn = "MRN" + string(_n, "%03.0f")
* Shared value label across an excluded var (arm) and a kept var (study_arm)
gen byte arm = mod(_n, 2)
gen byte study_arm = mod(_n, 2)
label define arml 0 "Control" 1 "Treated"
label values arm arml
label values study_arm arml
label variable patient_id "Identifier"
label variable hiv_status "HIV status (sensitive)"
save "`pdta'", replace

* ============================================================
* Test 1: excluded binary variable does NOT leak via the Binary section
*         (frequencies print value labels, so the labels must be absent)
* ============================================================
local ++test_count
capture {
    datamap, single("`pdta'") output("`ptxt'") exclude(hiv_status patient_id mrn) detect(binary)
    * The sensitive coding "Negative"/"Positive" belongs only to the excluded
    * hiv_status; it must not appear anywhere (binary freqs or value labels).
    _priv_file_contains using "`ptxt'", needle("Negative")
    assert r(found) == 0
    _priv_file_contains using "`ptxt'", needle("Positive")
    assert r(found) == 0
    * The kept binary var (sex) is still documented.
    _priv_file_contains using "`ptxt'", needle("Female")
    assert r(found) == 1
    * The excluded var's STRUCTURE is still documented (name + excluded marker).
    _priv_file_contains using "`ptxt'", needle("VARIABLE: hiv_status")
    assert r(found) == 1
    _priv_file_contains using "`ptxt'", needle("excluded (privacy)")
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: excluded binary variable does not leak values in Binary section"
    local ++pass_count
}
else {
    display as error "  FAIL: excluded binary variable leaked (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Test 2: excluded variable's cardinality/max-length not exposed in returns/JSON
* ============================================================
local ++test_count
capture {
    datamap, single("`pdta'") output("`pjson'") format(json) ///
        exclude(hiv_status patient_id mrn) detect(binary)
    * Excluded vars carry null cardinality and null max length in JSON.
    _priv_file_contains using "`pjson'", needle(`""unique_values": null"')
    assert r(found) == 1
    _priv_file_contains using "`pjson'", needle(`""max_length": null"')
    assert r(found) == 1
    * No leak of the sensitive coding in JSON either.
    _priv_file_contains using "`pjson'", needle("Negative")
    assert r(found) == 0
    * Excluded classification is still recorded (structure documented).
    _priv_file_contains using "`pjson'", needle(`""classification": "excluded""')
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: excluded variable cardinality/max-length suppressed in JSON"
    local ++pass_count
}
else {
    display as error "  FAIL: excluded variable cardinality/max-length leaked in JSON (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Test 3: VALUE LABEL DEFINITIONS - excluded-only labels dropped,
*         shared labels preserved and attributed to the kept variable
* ============================================================
local ++test_count
capture {
    * Exclude arm (shares arml with kept study_arm) and hiv_status (yn only on it).
    datamap, single("`pdta'") output("`ptxt2'") exclude(arm hiv_status patient_id mrn)
    * Label used only by an excluded var disappears entirely.
    _priv_file_contains using "`ptxt2'", needle("yn (used by:")
    assert r(found) == 0
    * Shared label still printed, attributed to the kept var only.
    _priv_file_contains using "`ptxt2'", needle("arml (used by: study_arm)")
    assert r(found) == 1
    _priv_file_contains using "`ptxt2'", needle("Control")
    assert r(found) == 1
    _priv_file_contains using "`ptxt2'", needle("Treated")
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: value-label definitions drop excluded-only labels, keep shared"
    local ++pass_count
}
else {
    display as error "  FAIL: value-label definitions privacy contract incorrect (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Test 4: stored results unaffected - excluded count and names still correct
* ============================================================
local ++test_count
capture {
    datamap, single("`pdta'") output("`ptxt'") exclude(hiv_status arm)
    assert r(n_excluded) == 2
    assert strpos("`r(excluded_vars)'", "hiv_status") > 0
    assert strpos("`r(excluded_vars)'", "arm") > 0
}
if _rc == 0 {
    display as result "  PASS: exclude() stored results correct"
    local ++pass_count
}
else {
    display as error "  FAIL: exclude() stored results incorrect (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Test 5: JSON output is structurally valid (balanced, no trailing commas)
*         across plain, privacy, and all-missing inputs
* ============================================================
local ++test_count
capture {
    * (a) privacy-rich JSON from above
    _priv_json_ok using "`pjson'"
    assert r(braces_ok) == 1
    assert r(brackets_ok) == 1
    assert r(trailing) == 0
    * (b) all-missing edge case
    tempfile emiss ejson
    clear
    set obs 10
    gen double allmiss = .
    gen byte g = mod(_n, 2)
    gen str5 s = ""
    save "`emiss'.dta", replace
    datamap, single("`emiss'") output("`ejson'") format(json)
    _priv_json_ok using "`ejson'"
    assert r(braces_ok) == 1
    assert r(brackets_ok) == 1
    assert r(trailing) == 0
}
if _rc == 0 {
    display as result "  PASS: JSON output is structurally valid (balanced, no trailing commas)"
    local ++pass_count
}
else {
    display as error "  FAIL: JSON output malformed (error `=_rc')"
    local ++fail_count
}

capture erase "`pdta'"

* ============================================================
* Summary
* ============================================================
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_datamap_privacy tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_datamap_privacy tests=`test_count' pass=`pass_count' fail=`fail_count'"
