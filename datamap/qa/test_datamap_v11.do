clear all
set more off
version 16.0

* test_datamap_v11.do - Regression tests for datamap 1.1.0 behavior
* Generated: 2026-06-14
* Covers: JSON output, small-cell suppression, compact/noguidance,
*         identifier warnings, shared helper install, richer returns, dateformat

local test_count = 0
local pass_count = 0
local fail_count = 0

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force

capture program drop _v11_file_contains
program define _v11_file_contains, rclass
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

tempfile v11_base v11_out v11_out0 v11_json v11_nog v11_compact v11_samples v11_date v11_dd
local v11_dta "`v11_base'.dta"

clear
set obs 30
gen double patient_id = _n
gen byte group = 2
replace group = 1 in 1/3
replace group = 3 in 24/30
label define groupl 1 "Rare" 2 "Common" 3 "Small"
label values group groupl
gen byte sex = mod(_n, 2)
gen double score = _n * 10 + .5
gen double visit_date = td(01jan2020) + _n
format visit_date %td
gen str12 nickname = "code" + string(_n, "%02.0f")
label variable patient_id "Synthetic patient identifier"
label variable group "Exposure group"
label variable sex "Sex indicator"
label variable score "Continuous score"
label variable visit_date "Visit date"
label variable nickname "Pseudonym"
save "`v11_dta'", replace

* ============================================================
* Tests
* ============================================================

local ++test_count
capture {
    which datamap
    which datadict
    which _datamap_classify
}
if _rc == 0 {
    display as result "  PASS: installed public commands and shared classifier helper resolve"
    local ++pass_count
}
else {
    display as error "  FAIL: installed commands/helpers do not resolve (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture {
    datamap, single("`v11_dta'") output("`v11_out'") mincell(5) noguidance
    assert r(nfiles) == 1
    assert r(nobs) == 30
    assert r(nvars) == 6
    assert r(mincell) == 5
    assert r(n_categorical) == 2
    assert r(n_continuous) == 2
    assert r(n_date) == 1
    assert r(n_string) == 1
    assert r(n_excluded) == 0
    assert r(n_suggested_exclude) == 1
    assert strpos("`r(categorical_vars)'", "group") > 0
    assert strpos("`r(categorical_vars)'", "sex") > 0
    assert strpos("`r(continuous_vars)'", "patient_id") > 0
    assert strpos("`r(continuous_vars)'", "score") > 0
    assert strpos("`r(date_vars)'", "visit_date") > 0
    assert strpos("`r(string_vars)'", "nickname") > 0
    assert strpos("`r(suggested_exclude)'", "patient_id") > 0
    _v11_file_contains using "`v11_out'", needle("Likely identifiers not excluded:")
    assert r(found) == 1
    _v11_file_contains using "`v11_out'", needle("patient_id")
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: rich stored results and identifier suggestion are correct"
    local ++pass_count
}
else {
    display as error "  FAIL: rich stored results or identifier suggestion incorrect (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture {
    datamap, single("`v11_dta'") output("`v11_out'") exclude(patient_id) noguidance
    assert r(n_excluded) == 1
    assert r(n_suggested_exclude) == 0
    assert strpos("`r(excluded_vars)'", "patient_id") > 0
    assert strpos("`r(suggested_exclude)'", "patient_id") == 0
}
if _rc == 0 {
    display as result "  PASS: exclude() clears suggested identifier"
    local ++pass_count
}
else {
    display as error "  FAIL: exclude() did not clear suggested identifier (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture {
    datamap, single("`v11_dta'") output("`v11_out'") mincell(5) noguidance
    _v11_file_contains using "`v11_out'", needle("suppressed (<5)")
    assert r(found) == 1
    datamap, single("`v11_dta'") output("`v11_out0'") mincell(0) noguidance
    assert r(mincell) == 0
    _v11_file_contains using "`v11_out0'", needle("suppressed (<5)")
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS: mincell() suppresses small cells and mincell(0) disables suppression"
    local ++pass_count
}
else {
    display as error "  FAIL: mincell() suppression behavior incorrect (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture {
    datamap, single("`v11_dta'") output("`v11_json'") format(json) mincell(5)
    assert "`r(format)'" == "json"
    assert "`r(output)'" == "`v11_json'"
    _v11_file_contains using "`v11_json'", needle("datasets")
    assert r(found) == 1
    _v11_file_contains using "`v11_json'", needle("suppressed")
    assert r(found) == 1
    _v11_file_contains using "`v11_json'", needle("null")
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: format(json) writes JSON-shaped output with suppression markers"
    local ++pass_count
}
else {
    display as error "  FAIL: format(json) output contract incorrect (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture {
    datamap, single("`v11_dta'") output("`v11_nog'") noguidance
    _v11_file_contains using "`v11_nog'", needle("ANALYSIS GUIDANCE")
    assert r(found) == 0
    datamap, single("`v11_dta'") output("`v11_compact'") compact
    _v11_file_contains using "`v11_compact'", needle("QUICK REFERENCE")
    assert r(found) == 1
    _v11_file_contains using "`v11_compact'", needle("ANALYSIS GUIDANCE")
    assert r(found) == 0
    _v11_file_contains using "`v11_compact'", needle("CATEGORICAL VARIABLES")
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS: noguidance and compact suppress guidance/detail sections"
    local ++pass_count
}
else {
    display as error "  FAIL: noguidance or compact output contract incorrect (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture {
    datamap, single("`v11_dta'") output("`v11_samples'") samples(3) datesafe noguidance
    _v11_file_contains using "`v11_samples'", needle("[DATE SUPPRESSED]")
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: samples() respects datesafe date suppression"
    local ++pass_count
}
else {
    display as error "  FAIL: samples() datesafe suppression missing (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture {
    datamap, single("`v11_dta'") output("`v11_date'") dateformat(%tdDD/NN/CCYY) noguidance
    assert r(n_date) == 1
    datadict, single("`v11_dta'") output("`v11_dd'") dateformat(%tdDD/NN/CCYY)
    assert r(nfiles) == 1
    capture datamap, single("`v11_dta'") output("`v11_date'") dateformat(YYYY)
    assert _rc == 198
    capture datadict, single("`v11_dta'") output("`v11_dd'") dateformat(YYYY)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: dateformat() accepted and invalid formats rejected for both commands"
    local ++pass_count
}
else {
    display as error "  FAIL: dateformat() validation incorrect (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture {
    capture datamap, single("`v11_dta'") output("`v11_json'") format(json) append
    assert _rc == 198
    capture datamap, single("`v11_dta'") output("`v11_out'") mincell(-1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: new option error paths reject invalid combinations"
    local ++pass_count
}
else {
    display as error "  FAIL: new option error paths incorrect (error `=_rc')"
    local ++fail_count
}

capture erase "`v11_dta'"

* ============================================================
* Summary
* ============================================================

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_datamap_v11 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_datamap_v11 tests=`test_count' pass=`pass_count' fail=`fail_count'"
