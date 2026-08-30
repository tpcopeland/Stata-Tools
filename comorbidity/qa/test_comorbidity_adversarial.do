clear all
set varabbrev off
set more off
version 16.0

capture log close _all
log using "test_comorbidity_adversarial.log", replace nomsg

do "_comorbidity_qa_common.do"
_comorbidity_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Error paths

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1
    1 "E119"
    end
    capture comorbidity dx1, id(pid) charlson(bogus)
    assert _rc == 198
    capture comorbidity dx1, id(pid) elixhauser(bogus)
    assert _rc == 198
    capture comorbidity dx1, id(pid) charlson(original) elixhauser(vanwalraven)
    assert _rc == 198
    capture comorbidity dx1, id(pid) elixhauser(ahrq_mortality)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: invalid index schemes rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: invalid index schemes (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1
    1 "E119"
    end
    capture comorbidity dx1, charlson(original)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: missing id rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: missing id rejected (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1
    1 "E119"
    end
    tempfile cf
    preserve
    clear
    input str8 name str8 pattern
    "dm" "E11"
    end
    export delimited "`cf'.csv", replace
    restore
    capture comorbidity dx1, id(pid) custom("`cf'.csv")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: custom codefile without weight rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: custom codefile without weight (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1
    1 "E119"
    end
    local before = c(varabbrev)
    set varabbrev on
    capture comorbidity dx1, id(pid) charlson(bogus)
    assert _rc == 198
    assert c(varabbrev) == "on"
    comorbidity dx1, id(pid) charlson(original) collapse
    assert c(varabbrev) == "on"
    set varabbrev `before'
}
if _rc == 0 {
    display as result "  PASS: varabbrev restored on success and error"
    local ++pass_count
}
else {
    display as error "  FAIL: varabbrev restoration (error `=_rc')"
    local ++fail_count
}

**# Summary

_comorbidity_result test_comorbidity_adversarial `test_count' `pass_count' `fail_count'
log close _all
