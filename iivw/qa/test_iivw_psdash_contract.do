clear all
version 16.0
set varabbrev off

* test_iivw_psdash_contract.do - iivw treatment-PS contract for psdash
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_psdash_contract.do

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_psdash_contract.do must be run from iivw/qa"
    exit 198
}
* Sysdir sandbox + path resolution (Q3/Q8): the sandbox keeps this suite's
* net install out of the USER's real ado tree even when run standalone, and
* the "/qa" suffix is stripped by length, not by first-occurrence subinstr()
* (which mangles any path whose ancestors contain "qa").
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"
local repo_dir "`r(repo_dir)'"

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _iivw_psdash_panel
program define _iivw_psdash_panel
    version 16.0

    clear
    set seed 20260529
    set obs 80
    gen long id = _n
    gen double age = 30 + id / 2
    gen byte sex = mod(id, 2)
    gen double bl_edss = 2 + 0.03 * id + rnormal(0, 0.2)
    gen double bl_sdmt = 60 - 0.15 * id + rnormal(0, 1)
    gen byte treated = (runiform() < invlogit(-2 + 0.03 * age + 0.35 * sex + 0.2 * bl_edss))
    replace treated = 0 in 1/4
    replace treated = 1 in 77/80
    expand 4
    bysort id: gen byte visit = _n
    gen double months = 3 * visit + id / 1000
    gen double sdmt = bl_sdmt - 0.4 * visit + rnormal(0, 1)
    gen byte relapse = (runiform() < invlogit(-3 + 0.2 * bl_edss + 0.1 * visit))
end

capture program drop _iivw_psdash_result
program define _iivw_psdash_result
    args test_id rc

    if `rc' == 0 {
        display as result "  PASS: `test_id'"
        c_local pass_increment 1
    }
    else {
        display as error "  FAIL: `test_id' (error `rc')"
        c_local pass_increment 0
    }
end

**# T1: FIPTIW creates treatment PS contract

local ++test_count
capture noisily {
    _iivw_psdash_panel
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
        visit_cov(age sex bl_edss) lagvars(sdmt relapse) ///
        treat(treated) treat_cov(age sex bl_edss bl_sdmt) ///
        truncate(1 99) efron nolog

    confirm variable _iivw_iw
    confirm variable _iivw_tw
    confirm variable _iivw_ps
    confirm variable _iivw_weight
    assert !missing(_iivw_ps)
    assert inrange(_iivw_ps, 0, 1)

    assert "`: char _dta[_iivw_iw_var]'" == "_iivw_iw"
    assert "`: char _dta[_iivw_tw_var]'" == "_iivw_tw"
    assert "`: char _dta[_iivw_ps_var]'" == "_iivw_ps"
    assert "`: char _dta[_iivw_treat]'" == "treated"
    assert "`: char _dta[_iivw_treat_covars]'" == "age sex bl_edss bl_sdmt"
    assert "`: char _dta[_iivw_ps_estimand]'" == "ate"
    assert "`: char _dta[_iivw_contract_version]'" == "2"

    assert "`r(ps_var)'" == "_iivw_ps"
    assert "`r(tw_var)'" == "_iivw_tw"
    assert "`r(iw_var)'" == "_iivw_iw"
    assert "`r(treat_covars)'" == "age sex bl_edss bl_sdmt"
    assert "`r(ps_estimand)'" == "ate"
    assert "`r(contract_version)'" == "2"
    assert r(ps_min) >= 0
    assert r(ps_max) <= 1
    assert r(n_ps_extreme) >= 0

    _iivw_get_settings
    assert "`r(ps_var)'" == "_iivw_ps"
    assert "`r(tw_var)'" == "_iivw_tw"
    assert "`r(iw_var)'" == "_iivw_iw"
    assert "`r(treat_covars)'" == "age sex bl_edss bl_sdmt"
    assert "`r(ps_estimand)'" == "ate"
    assert "`r(contract_version)'" == "2"
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T1 - FIPTIW treatment PS contract"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - FIPTIW treatment PS contract (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

**# T2: IIW-only rerun clears treatment PS metadata

local ++test_count
capture noisily {
    _iivw_psdash_panel
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
        visit_cov(age sex bl_edss) lagvars(sdmt relapse) ///
        treat(treated) treat_cov(age sex bl_edss bl_sdmt) ///
        replace nolog
    assert "`: char _dta[_iivw_ps_var]'" == "_iivw_ps"

    iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
        visit_cov(age sex bl_edss) lagvars(sdmt relapse) ///
        replace nolog

    capture confirm variable _iivw_ps
    assert _rc != 0
    capture confirm variable _iivw_tw
    assert _rc != 0
    assert "`: char _dta[_iivw_weighttype]'" == "iivw"
    assert "`: char _dta[_iivw_iw_var]'" == "_iivw_iw"
    assert "`: char _dta[_iivw_tw_var]'" == ""
    assert "`: char _dta[_iivw_ps_var]'" == ""
    assert "`: char _dta[_iivw_treat]'" == ""
    assert "`: char _dta[_iivw_treat_covars]'" == ""
    assert "`: char _dta[_iivw_ps_estimand]'" == ""
    assert "`: char _dta[_iivw_contract_version]'" == "2"
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T2 - IIW-only clears treatment PS metadata"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - IIW-only metadata clearing (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

**# T3: generate(prefix) creates matching PS metadata

local ++test_count
capture noisily {
    _iivw_psdash_panel
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
        visit_cov(age sex bl_edss) lagvars(sdmt relapse) ///
        treat(treated) treat_cov(age sex bl_edss bl_sdmt) ///
        generate(custom_) replace nolog

    confirm variable custom_ps
    confirm variable custom_tw
    confirm variable custom_iw
    confirm variable custom_weight
    assert "`: char _dta[_iivw_ps_var]'" == "custom_ps"
    assert "`: char _dta[_iivw_tw_var]'" == "custom_tw"
    assert "`: char _dta[_iivw_iw_var]'" == "custom_iw"
    assert "`r(ps_var)'" == "custom_ps"
    assert "`r(tw_var)'" == "custom_tw"
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T3 - custom prefix PS contract"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - custom prefix contract (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

**# T4: generated-name collision guard covers prefix_ps

local ++test_count
capture noisily {
    _iivw_psdash_panel
    gen double _iivw_ps = 0.5
    capture noisily iivw_weight, id(id) time(months) ///
        treat(treated) treat_cov(age sex bl_edss bl_sdmt) ///
        wtype(iptw) nolog
    assert _rc == 110
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T4 - prefix_ps collision guard"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - prefix_ps collision guard (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

**# Summary

display as result "iivw psdash contract results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_iivw_psdash_contract tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL IIVW PSDASH CONTRACT TESTS PASSED"
display "RESULT: test_iivw_psdash_contract tests=`test_count' pass=`pass_count' fail=`fail_count'"
