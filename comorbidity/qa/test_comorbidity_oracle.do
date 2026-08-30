*! Seed: 26082431. 200 independent patient-level Charlson-original oracles.
clear all
set more off
set varabbrev off
version 16.0

capture log close _all
log using "test_comorbidity_oracle.log", replace text nomsg

do "_comorbidity_qa_common.do"
_comorbidity_qa_bootstrap

set seed 26082431

local test_count = 200
local pass_count = 0
local fail_count = 0
forvalues rep = 1/200 {
    clear
    set obs 40
    generate long pid = 1 + floor(runiform() * 10)
    generate str8 dx1 = word("I21 I50 E110 E112 C34 C78 Z000", 1 + floor(runiform() * 7))
    generate str8 dx2 = word("I21 I50 E110 E112 C34 C78 Z000", 1 + floor(runiform() * 7))
    generate long original_row = _n
    generate str24 _comorbidity_shadow = "keep_" + string(_n)
    generate double shuffle = runiform()
    sort shuffle
    drop shuffle

    * Plain equality tests plus patient maxima: independent of dictionary/helpers.
    generate byte exp_mi = dx1 == "I21" | dx2 == "I21"
    generate byte exp_chf = dx1 == "I50" | dx2 == "I50"
    generate byte exp_dm_uncomp = dx1 == "E110" | dx2 == "E110"
    generate byte exp_dm_comp = dx1 == "E112" | dx2 == "E112"
    generate byte exp_cancer = dx1 == "C34" | dx2 == "C34"
    generate byte exp_metastatic = dx1 == "C78" | dx2 == "C78"
    foreach v in mi chf dm_uncomp dm_comp cancer metastatic {
        bysort pid: egen byte p_`v' = max(exp_`v')
    }
    replace p_dm_uncomp = 0 if p_dm_comp
    replace p_cancer = 0 if p_metastatic
    generate double exp_score = p_mi + p_chf + p_dm_uncomp + 2*p_dm_comp + 2*p_cancer + 6*p_metastatic
    preserve
        keep pid p_mi p_chf p_dm_uncomp p_dm_comp p_cancer p_metastatic exp_score
        bysort pid: keep if _n == 1
        local expected_N = _N
        tempfile expected
        save "`expected'"
    restore

    capture noisily comorbidity dx1 dx2, id(pid) charlson(original) collapse generate(orc_)
    local call_rc = _rc
    if `call_rc' == 0 {
        capture noisily {
            merge 1:1 pid using "`expected'", nogen
            assert orc_mi == p_mi
            assert orc_chf == p_chf
            assert orc_dm_uncomp == p_dm_uncomp
            assert orc_dm_comp == p_dm_comp
            assert orc_cancer == p_cancer
            assert orc_metastatic == p_metastatic
            assert orc_score == exp_score
            assert _N == `expected_N'
        }
        local check_rc = _rc
    }
    else local check_rc = `call_rc'
    if `check_rc' == 0 local ++pass_count
    else local ++fail_count
}

_comorbidity_result test_comorbidity_oracle `test_count' `pass_count' `fail_count'
capture log close _all
