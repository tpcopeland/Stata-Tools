clear all
set more off
version 16.0

* test_datamap_v15.do - Regression tests for datamap 1.5.0 integration features

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir  "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local tmp_dir "`qa_dir'/data"

capture mkdir "`tmp_dir'"

capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace
discard

capture program drop _v15_contains
program define _v15_contains, rclass
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

capture program drop _v15_common_schema
program define _v15_common_schema
    version 16.0
    args command

    foreach v in source_command source output dataset dataset_label variable ///
        storage_type display_format value_label class N nvars missing ///
        missing_pct unique variable_label notes characteristics mean sd p50 ///
        p25 p75 min max datasignature {
        confirm variable `v'
    }
    quietly count
    assert r(N) > 0
    quietly count if source_command == "`command'"
    assert r(N) == _N
end

capture program drop _v15_make_data
program define _v15_make_data
    version 16.0
    clear
    set obs 30
    gen long id = _n
    gen byte arm = cond(_n == 1, 1, 2)
    gen byte score = mod(_n, 3)
    gen double visit_date = mdy(1, 1, 2020) + _n
    format visit_date %td
    gen str8 note = cond(_n <= 15, "alpha", "beta")
    replace score = . in 30
    label define arml 1 "Rare arm" 2 "Common arm", replace
    label values arm arml
    label variable id "Identifier"
    label variable arm "Treatment arm"
    label variable score "Score forced continuous"
    label variable visit_date "Visit date"
    label variable note "Text category"
    label data "v15 QA dataset"
end

local dta "`tmp_dir'/v15_source.dta"
local dta_changed "`tmp_dir'/v15_changed.dta"
local map_txt "`tmp_dir'/v15_datamap.txt"
local map_meta "`tmp_dir'/v15_datamap_meta.dta"
local dict_md "`tmp_dir'/v15_datadict.md"
local dict_meta "`tmp_dir'/v15_datadict_meta.dta"
local check_meta "`tmp_dir'/v15_datacheck_meta.dta"
local base_meta "`tmp_dir'/v15_datacheck_base.dta"
local changed_meta "`tmp_dir'/v15_datacheck_changed_meta.dta"
local cfg "`tmp_dir'/v15_config.txt"

_v15_make_data
quietly save "`dta'", replace

quietly file open cf using "`cfg'", write text replace
file write cf "exclude = id" _n
file write cf "continuous = score" _n
file write cf "categorical = note" _n
file write cf "datevars = visit_date" _n
file write cf "mincell = 5" _n
file close cf

* ============================================================
* 1. datamap saving() writes the common metadata schema and honors overrides
* ============================================================
local ++test_count
capture noisily {
    datamap, single("`dta'") output("`map_txt'") ///
        saving("`map_meta'", replace) exclude(id) continuous(score) ///
        categorical(note) date(visit_date)
    assert "`r(metadata)'" == "`map_meta'"
    assert strpos("`r(excluded_vars)'", "id") > 0
    assert strpos("`r(continuous_vars)'", "score") > 0
    assert strpos("`r(categorical_vars)'", "note") > 0
    assert strpos("`r(date_vars)'", "visit_date") > 0

    preserve
    use "`map_meta'", clear
    _v15_common_schema datamap
    assert _N == 5
    quietly count if variable == "id" & class == "excluded"
    assert r(N) == 1
    quietly count if variable == "score" & class == "continuous"
    assert r(N) == 1
    quietly count if variable == "note" & class == "categorical"
    assert r(N) == 1
    quietly count if variable == "visit_date" & class == "date"
    assert r(N) == 1
    assert N[1] == 30
    assert nvars[1] == 5
    restore
}
if _rc == 0 {
    display as result "  PASS: datamap saving() common schema and classification overrides"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap saving() common schema and overrides (error `=_rc')"
    local ++fail_count
}

* ============================================================
* 2. datadict privacy parity: exclude() and mincell() suppress disclosures
* ============================================================
local ++test_count
capture noisily {
    datadict, single("`dta'") output("`dict_md'") stats mincell(5) ///
        exclude(id) continuous(score) categorical(note) datevars(visit_date) ///
        saving("`dict_meta'", replace)

    _v15_contains using "`dict_md'", needle("(suppressed <5)")
    assert r(found) == 1
    _v15_contains using "`dict_md'", needle("Identifier")
    assert r(found) == 0

    preserve
    use "`dict_meta'", clear
    _v15_common_schema datadict
    quietly count if variable == "id"
    assert r(N) == 0
    quietly count if variable == "score" & class == "continuous"
    assert r(N) == 1
    quietly count if variable == "note" & class == "categorical"
    assert r(N) == 1
    quietly count if variable == "visit_date" & class == "date"
    assert r(N) == 1
    confirm variable source_command
    confirm variable missing_pct
    confirm variable datasignature
    restore
}
if _rc == 0 {
    display as result "  PASS: datadict exclude()/mincell() privacy and common saving schema"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict privacy/common schema regression (error `=_rc')"
    local ++fail_count
}

* ============================================================
* 3. datacheck saving() uses the common schema and preserves legacy aliases
* ============================================================
local ++test_count
capture noisily {
    use "`dta'", clear
    datacheck, saving("`check_meta'", replace) exclude(id) ///
        continuous(score) categorical(note) date(visit_date) warn

    assert strpos("`r(excluded_vars)'", "id") > 0
    assert strpos("`r(continuous_vars)'", "score") > 0
    assert strpos("`r(categorical_vars)'", "note") > 0
    assert strpos("`r(date_vars)'", "visit_date") > 0

    preserve
    use "`check_meta'", clear
    _v15_common_schema datacheck
    confirm variable varname
    confirm variable dc_class
    quietly count if variable == "score" & class == "continuous" & dc_class == "continuous"
    assert r(N) == 1
    quietly count if variable == "id" & class == "excluded"
    assert r(N) == 1
    restore
}
if _rc == 0 {
    display as result "  PASS: datacheck saving() common schema and legacy aliases"
    local ++pass_count
}
else {
    display as error "  FAIL: datacheck saving() schema regression (error `=_rc')"
    local ++fail_count
}

* ============================================================
* 4. Shared config() drives privacy, mincell, and classifier overrides
* ============================================================
local ++test_count
capture noisily {
    datamap, single("`dta'") output("`map_txt'") ///
        saving("`map_meta'", replace) config("`cfg'")
    assert r(mincell) == 5
    assert strpos("`r(excluded_vars)'", "id") > 0
    assert strpos("`r(continuous_vars)'", "score") > 0
    assert strpos("`r(categorical_vars)'", "note") > 0
    assert strpos("`r(date_vars)'", "visit_date") > 0

    use "`dta'", clear
    datacheck, config("`cfg'") saving("`check_meta'", replace) warn
    assert r(mincell) == 5
    assert strpos("`r(excluded_vars)'", "id") > 0
    assert strpos("`r(continuous_vars)'", "score") > 0
    assert strpos("`r(categorical_vars)'", "note") > 0
    assert strpos("`r(date_vars)'", "visit_date") > 0
}
if _rc == 0 {
    display as result "  PASS: shared config() applies across datamap and datacheck"
    local ++pass_count
}
else {
    display as error "  FAIL: shared config() regression (error `=_rc')"
    local ++fail_count
}

* ============================================================
* 5. datacheck compare() detects schema drift from saved metadata
* ============================================================
local ++test_count
capture noisily {
    use "`dta'", clear
    datacheck, saving("`base_meta'", replace) exclude(id) warn gatesonly

    use "`dta'", clear
    drop note
    recast double score
    gen byte bmi = 20 + mod(_n, 4)
    quietly save "`dta_changed'", replace
    datacheck, compare("`base_meta'") saving("`changed_meta'", replace) ///
        exclude(id) continuous(score) warn
    assert r(compare_added) == 1
    assert r(compare_dropped) == 1
    assert r(compare_type_changed) == 1
    assert r(compare_class_changed) == 1
    assert r(compare_changed) == 4
    assert strpos("`r(compare_added_vars)'", "bmi") > 0
    assert strpos("`r(compare_dropped_vars)'", "note") > 0
    assert strpos("`r(compare_type_changed_vars)'", "score") > 0
    assert strpos("`r(compare_class_changed_vars)'", "score") > 0
    assert strpos("`r(violations)'", "compare") > 0
}
if _rc == 0 {
    display as result "  PASS: datacheck compare() detects saved-profile schema drift"
    local ++pass_count
}
else {
    display as error "  FAIL: datacheck compare() regression (error `=_rc')"
    local ++fail_count
}

* ============================================================
* 6. datacheck compare() accepts legacy datacheck saving aliases
* ============================================================
local ++test_count
capture noisily {
    use "`base_meta'", clear
    keep variable storage_type dc_class N
    rename variable varname
    rename storage_type vartype
    tempfile legacy_meta
    quietly save "`legacy_meta'", replace

    use "`dta_changed'", clear
    datacheck, compare("`legacy_meta'") exclude(id) warn gatesonly
    assert r(compare_added) == 1
    assert strpos("`r(compare_added_vars)'", "bmi") > 0
}
if _rc == 0 {
    display as result "  PASS: datacheck compare() accepts legacy metadata aliases"
    local ++pass_count
}
else {
    display as error "  FAIL: datacheck compare() legacy alias regression (error `=_rc')"
    local ++fail_count
}

foreach f in "`dta'" "`dta_changed'" "`map_txt'" "`map_meta'" "`dict_md'" ///
    "`dict_meta'" "`check_meta'" "`base_meta'" "`changed_meta'" "`cfg'" {
    capture erase "`f'"
}

display as text "datamap v15 tests: `pass_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_datamap_v15 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 9
}
display as result "ALL TESTS PASSED"
display "RESULT: test_datamap_v15 tests=`test_count' pass=`pass_count' fail=`fail_count'"
exit 0
