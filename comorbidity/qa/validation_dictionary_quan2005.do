*! Known-answer validation of the Quan et al. (2005) Elixhauser ICD-10 definitions
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set varabbrev off
set more off
version 16.0

capture log close _all
log using "validation_dictionary_quan2005.log", replace nomsg

do "_comorbidity_qa_common.do"
_comorbidity_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Quan et al. (2005), Table 2

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1
    1 "E106"
    2 "E109"
    3 "R470"
    4 "R56"
    end
    comorbidity dx1, id(pid) elixhauser(vanwalraven) collapse nohierarchy
    assert dm_comp == 1 & dm_uncomp == 0 if pid == 1
    assert dm_comp == 0 & dm_uncomp == 1 if pid == 2
    assert neuro_other == 1 if inlist(pid, 3, 4)
}
if _rc == 0 {
    display as result "  PASS: diabetes and neurological definitions match Table 2"
    local ++pass_count
}
else {
    display as error "  FAIL: diabetes/neurological Table 2 definitions (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1
    1 "N033"
    2 "N053"
    3 "K705"
    4 "K720"
    5 "K250"
    6 "K257"
    end
    comorbidity dx1, id(pid) elixhauser(vanwalraven) collapse nohierarchy
    assert renal == 0 if inlist(pid, 1, 2)
    assert liver == 1 if inlist(pid, 3, 4)
    assert pud == 0 if pid == 5
    assert pud == 1 if pid == 6
}
if _rc == 0 {
    display as result "  PASS: renal, liver, and ulcer definitions match Table 2"
    local ++pass_count
}
else {
    display as error "  FAIL: renal/liver/ulcer Table 2 definitions (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1
    1 "C900"
    2 "C902"
    3 "C970"
    4 "M314"
    5 "M460"
    6 "M310"
    7 "M313"
    8 "M461"
    9 "M468"
    10 "M469"
    end
    comorbidity dx1, id(pid) elixhauser(vanwalraven) collapse nohierarchy
    assert lymphoma == 1 if inlist(pid, 1, 2)
    assert solid_tumor == 1 if pid == 3
    assert rheumatoid == 0 if inlist(pid, 4, 5)
    assert rheumatoid == 1 if inrange(pid, 6, 10)
}
if _rc == 0 {
    display as result "  PASS: neoplasm and rheumatologic definitions match Table 2"
    local ++pass_count
}
else {
    display as error "  FAIL: neoplasm/rheumatologic Table 2 definitions (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1
    1 "R64"
    2 "E52"
    3 "I426"
    4 "K292"
    5 "G621"
    6 "Z502"
    7 "Z714"
    8 "Z721"
    9 "Z715"
    10 "Z722"
    end
    comorbidity dx1, id(pid) elixhauser(vanwalraven) collapse nohierarchy
    assert weight_loss == 1 if pid == 1
    assert alcohol == 1 if inrange(pid, 2, 8)
    assert drug == 1 if inlist(pid, 9, 10)
}
if _rc == 0 {
    display as result "  PASS: weight-loss and substance definitions match Table 2"
    local ++pass_count
}
else {
    display as error "  FAIL: weight/substance Table 2 definitions (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1
    1 "F313"
    2 "F314"
    3 "F315"
    4 "F412"
    5 "F432"
    6 "F351"
    7 "F38"
    8 "F39"
    end
    comorbidity dx1, id(pid) elixhauser(vanwalraven) collapse nohierarchy
    assert depression == 1 if inrange(pid, 1, 5)
    assert depression == 0 if inrange(pid, 6, 8)
    assert psychoses == 0 if inlist(pid, 1, 2)
    assert psychoses == 1 if pid == 3
}
if _rc == 0 {
    display as result "  PASS: psychosis and depression definitions match Table 2"
    local ++pass_count
}
else {
    display as error "  FAIL: mental-health Table 2 definitions (error `=_rc')"
    local ++fail_count
}

**# Summary

_comorbidity_result validation_dictionary_quan2005 `test_count' `pass_count' `fail_count'
log close _all
