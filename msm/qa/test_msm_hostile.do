* test_msm_hostile.do - Cross-command hostile name, missingness, and state checks.
* Seed: 20260823. This suite has no randomized draws.

version 16.0
clear all
set more off
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
capture log close _all
log using "test_msm_hostile.log", replace text name(_msm_hostile)
do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _msm_hostile_panel
program define _msm_hostile_panel
    version 16.0
    clear
    set obs 12
    generate long id = ceil(_n / 3)
    bysort id: generate int period = _n - 1
    generate byte treatment_1234567890123456789012 = mod(id + period, 2)
    generate byte outcome_123456789012345678901234 = 0
    generate byte censor_1234567890123456789012345 = 0
    generate double covariate_1234567890123456789012 = id + period / 10
end

**# Thirty-two-character role names survive preparation and shuffled order
local ++test_count
capture noisily {
    _msm_hostile_panel
    set seed 20260823
    generate double shuffle = runiform()
    sort shuffle
    generate long row_before = _n
    set varabbrev on
    msm_prepare, id(id) period(period) treatment(treatment_1234567890123456789012) ///
        outcome(outcome_123456789012345678901234) censor(censor_1234567890123456789012345) ///
        covariates(covariate_1234567890123456789012)
    assert c(varabbrev) == "on"
    assert row_before == _n
    assert "`r(treatment)'" == "treatment_1234567890123456789012"
    assert "`r(outcome)'" == "outcome_123456789012345678901234"
    assert "`r(censor)'" == "censor_1234567890123456789012345"
    set varabbrev off
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Extended-missing mapped outcomes are reported by strict validation without mutation
local ++test_count
capture noisily {
    _msm_hostile_panel
    replace outcome_123456789012345678901234 = .a in 5
    set seed 20260824
    generate double shuffle = runiform()
    sort shuffle
    generate long row_before = _n
    clonevar outcome_before = outcome_123456789012345678901234
    quietly msm_prepare, id(id) period(period) treatment(treatment_1234567890123456789012) ///
        outcome(outcome_123456789012345678901234) censor(censor_1234567890123456789012345) ///
        covariates(covariate_1234567890123456789012)
    capture noisily msm_validate, strict
    local call_rc = _rc
    assert `call_rc' != 0
    assert outcome_123456789012345678901234 == outcome_before
    assert row_before == _n
    assert "`: char _dta[_msm_prepared]'" == "1"
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Factor notation is rejected at the public varname boundary before state creation
local ++test_count
capture noisily {
    _msm_hostile_panel
    generate long row_before = _n
    capture noisily msm_prepare, id(id) period(period) treatment(i.treatment_1234567890123456789012) ///
        outcome(outcome_123456789012345678901234)
    local call_rc = _rc
    assert `call_rc' == 101
    assert row_before == _n
    assert "`: char _dta[_msm_prepared]'" == ""
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_msm_hostile tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
do "`qa_dir'/_record_qa_result.do" test_msm_hostile `test_count' `pass_count' `fail_count' 0
capture log close _msm_hostile
if `fail_count' > 0 exit 1
