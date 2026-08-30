clear all
set varabbrev off
set more off
version 16.0

capture log close _all
log using "test_weights.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall comorbidity
do "`pkg_dir'/_comorbidity_weights.ado"

**# Weight vectors

local ++test_count
capture noisily {
    _comorbidity_weights, index(charlson) scheme(original) ///
        names("mi chf dm_comp metastatic hiv liver_severe")
    assert "`r(w_chf)'" == "1"
    assert "`r(w_metastatic)'" == "6"
    assert "`r(w_hiv)'" == "6"
    assert "`r(w_liver_severe)'" == "3"
    assert "`r(weights)'" == "1 1 2 6 6 3"
}
if _rc == 0 {
    display as result "  PASS: Charlson original weights"
    local ++pass_count
}
else {
    display as error "  FAIL: Charlson original weights (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _comorbidity_weights, index(charlson) scheme(quan2011) ///
        names("mi chf dm_comp metastatic hiv liver_severe")
    assert "`r(w_mi)'" == "0"
    assert "`r(w_chf)'" == "2"
    assert "`r(w_hiv)'" == "4"
    assert "`r(w_liver_severe)'" == "4"
    assert "`r(weights)'" == "0 2 1 6 4 4"
}
if _rc == 0 {
    display as result "  PASS: Charlson Quan 2011 weights"
    local ++pass_count
}
else {
    display as error "  FAIL: Charlson Quan 2011 weights (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _comorbidity_weights, index(elixhauser) scheme(vanwalraven) ///
        names("liver metastatic drug obesity depression")
    assert "`r(w_liver)'" == "11"
    assert "`r(w_metastatic)'" == "12"
    assert "`r(w_drug)'" == "-7"
    assert "`r(w_obesity)'" == "-4"
    assert "`r(w_depression)'" == "-3"
    assert "`r(weights)'" == "11 12 -7 -4 -3"
}
if _rc == 0 {
    display as result "  PASS: Elixhauser van Walraven weights"
    local ++pass_count
}
else {
    display as error "  FAIL: Elixhauser van Walraven weights (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    local names "chf arrhythmia valvular pulmonary_circ pvd htn_uncomp htn_comp"
    local names "`names' paralysis neuro_other copd dm_uncomp dm_comp hypothyroid renal"
    local names "`names' liver pud hiv lymphoma metastatic solid_tumor rheumatoid"
    local names "`names' coagulopathy obesity weight_loss fluid_electrolyte"
    local names "`names' blood_loss_anemia deficiency_anemia alcohol drug psychoses depression"
    _comorbidity_weights, index(elixhauser) scheme(vanwalraven) names("`names'")
    local weights "`r(weights)'"
    assert wordcount("`weights'") == 31
    tempname negative positive
    scalar `negative' = 0
    scalar `positive' = 0
    foreach weight of local weights {
        if `weight' < 0 scalar `negative' = `negative' + `weight'
        if `weight' > 0 scalar `positive' = `positive' + `weight'
    }
    assert `negative' == -19
    assert `positive' == 89
}
if _rc == 0 {
    display as result "  PASS: van Walraven published score extrema"
    local ++pass_count
}
else {
    display as error "  FAIL: van Walraven score extrema (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _comorbidity_weights, index(elixhauser) scheme(vanwalraven) ///
        names("cmb_chf cmb_drug") prefix(cmb_)
    assert "`r(w_cmb_chf)'" == "7"
    assert "`r(w_cmb_drug)'" == "-7"
    assert "`r(weights)'" == "7 -7"
}
if _rc == 0 {
    display as result "  PASS: prefixed condition weights"
    local ++pass_count
}
else {
    display as error "  FAIL: prefixed condition weights (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    capture _comorbidity_weights, index(charlson) scheme(original) ///
        names("not_a_condition")
    assert _rc == 498
}
if _rc == 0 {
    display as result "  PASS: unknown condition names fail closed"
    local ++pass_count
}
else {
    display as error "  FAIL: unknown condition names fail closed (error `=_rc')"
    local ++fail_count
}

**# Summary

do "`qa_dir'/_comorbidity_qa_common.do"
_comorbidity_result test_weights `test_count' `pass_count' `fail_count'
log close _all
