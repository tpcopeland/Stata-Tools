clear all
set more off
version 16.0

* test_datamap_v11.do - Regression tests for datamap 1.1.0 behavior
* Generated: 2026-06-14
* Covers: JSON output, small-cell suppression, compact/noguidance,
*         identifier warnings, shared helper install, richer returns, dateformat
*
* 2026-11-10 (datamap 2.0.0): format(json), and datadict are removed.
*   - the JSON test is now "saving() carries the suppression contract": the
*     machine-readable table has no summary for a small-cell categorical row
*     (REMOVED FEATURE: the JSON "datasets"/"suppressed"/"null" markers)
*   - no longer exists (rc 198, test_datamap_v200_removed); the
*     guidance/detail sections are gone from the one document, so that test
*     asserts they are absent from the default document and that compact is the
*     five-column preset
*   - the datadict dateformat() call is a datamap call with a document option
*   - "append" with a document option is refused (rc 198), replacing the
*     "format(json) append" combination
* Documents are read through _qa_md.do (Mata): a line may end in a backtick.

local test_count = 0
local pass_count = 0
local fail_count = 0

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
do "`qa_dir'/_qa_md.do"

capture program drop _v11_file_contains
program define _v11_file_contains, rclass
    version 16.0
    syntax using/ , NEEDLE(string)
    qa_md_contains using `"`using'"', needle(`"`needle'"')
    return scalar found = r(found)
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
* stata-dev-ignore: rc-only-test — installation probe: whether each command/helper resolves on the adopath IS the whole content under test; `which' produces nothing else to assert
* 2.0.0 (2026-11-10): datadict is removed (test_datamap_errors asserts rc
* 199); the Markdown renderer _datamap_md_document takes its place here
capture {
    which datamap
    which _datamap_md_document
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
    datamap, single("`v11_dta'") output("`v11_out'") mincell(5)
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
    qa_md_contains using "`v11_out'", needle("likely identifiers not excluded: `=char(96)'patient_id`=char(96)'")
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
    datamap, single("`v11_dta'") output("`v11_out'") exclude(patient_id)
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
    datamap, single("`v11_dta'") output("`v11_out'") mincell(5)
    _v11_file_contains using "`v11_out'", needle("suppressed (<5)")
    assert r(found) == 1
    datamap, single("`v11_dta'") output("`v11_out0'") mincell(0)
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
    tempfile v11_meta
    datamap, single("`v11_dta'") output("`v11_json'") mincell(5) saving("`v11_meta'", replace)
    assert "`r(output)'" == "`v11_json'"
    assert "`r(format)'" == ""
    * the document marks the suppressed cells ...
    _v11_file_contains using "`v11_json'", needle("1 Rare: suppressed (<5)")
    assert r(found) == 1
    * ... and the machine-readable table carries no summary for those rows
    preserve
    quietly use "`v11_meta'", clear
    assert class == "categorical" & missing(mean, sd, p50, p25, p75, min, max) if variable == "group"
    assert class == "continuous" & !missing(mean, sd) if variable == "score"
    restore
}
if _rc == 0 {
    display as result "  PASS: saving() and the document carry the small-cell suppression markers (was format(json))"
    local ++pass_count
}
else {
    display as error "  FAIL: suppression markers in saving()/document incorrect (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture {
    * no guidance prose in the default document (noguidance is gone with it)
    datamap, single("`v11_dta'") output("`v11_nog'")
    _v11_file_contains using "`v11_nog'", needle("ANALYSIS GUIDANCE")
    assert r(found) == 0
    _v11_file_contains using "`v11_nog'", needle("QUICK REFERENCE")
    assert r(found) == 0
    _v11_file_contains using "`v11_nog'", needle("| Variable | Label | Type | Missing | Values/Statistics |")
    assert r(found) == 1
    * compact is the five-column preset: variable type label missing unique
    datamap, single("`v11_dta'") output("`v11_compact'") compact
    _v11_file_contains using "`v11_compact'", needle("| Variable | Type | Label | Missing | Unique |")
    assert r(found) == 1
    _v11_file_contains using "`v11_compact'", needle("ANALYSIS GUIDANCE")
    assert r(found) == 0
    _v11_file_contains using "`v11_compact'", needle("CATEGORICAL VARIABLES")
    assert r(found) == 0
    qa_md_rows using "`v11_compact'"
    assert r(n) == 6
    * the preset has no statistics or level cells
    _v11_file_contains using "`v11_compact'", needle("mean=")
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS: and compact suppress guidance/detail sections"
    local ++pass_count
}
else {
    display as error "  FAIL: or compact output contract incorrect (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture {
    datamap, single("`v11_dta'") output("`v11_samples'") samples(3) datesafe
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
    datamap, single("`v11_dta'") output("`v11_date'") dateformat(%tdDD/NN/CCYY)
    assert r(n_date) == 1
    _v11_file_contains using "`v11_date'", needle("range 02/01/2020 to 31/01/2020")
    assert r(found) == 1
    * (was datadict) the document mode takes the same option
    datamap, single("`v11_dta'") output("`v11_dd'") dateformat(%tdDD/NN/CCYY) title("T")
    assert r(nfiles) == 1
    _v11_file_contains using "`v11_dd'", needle("range 02/01/2020 to 31/01/2020")
    assert r(found) == 1
    capture datamap, single("`v11_dta'") output("`v11_date'") dateformat(YYYY)
    assert _rc == 198
    capture datamap, single("`v11_dta'") output("`v11_dd'") dateformat(YYYY) title("T")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: dateformat() accepted (plain and document mode) and invalid formats rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: dateformat() validation incorrect (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture {
    * append adds dataset sections only: with a document option it is refused
    capture datamap, single("`v11_dta'") output("`v11_json'") append title("T")
    assert _rc == 198
    capture datamap, single("`v11_dta'") output("`v11_json'") append notes("n")
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
