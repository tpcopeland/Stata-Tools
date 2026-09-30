*! QA isolation regression for comorbidity 1.0.2
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
capture log close _all
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
local test_count = 0
local pass_count = 0
local fail_count = 0

foreach entry in "run_all.do quick" "test_dictionary.do" "test_weights.do" "test_hierarchy.do" {
    local ++test_count
    capture noisily {
        clear
        tempfile outer
        foreach dir in PLUS PERSONAL SITE OLDPLACE {
            local path "`outer'_`dir'"
            mkdir "`path'"
            sysdir set `dir' "`path'"
        }
        ado dir
        net install comorbidity, from("`pkg_dir'") replace
        local seeded_plus "`c(sysdir_plus)'"
        checksum "`seeded_plus'c/comorbidity.ado"
        local ado_checksum = r(checksum)
        checksum "`seeded_plus'stata.trk"
        local trk_checksum = r(checksum)
        do `entry'
        confirm file "`seeded_plus'c/comorbidity.ado"
        checksum "`seeded_plus'c/comorbidity.ado"
        assert r(checksum) == `ado_checksum'
        checksum "`seeded_plus'stata.trk"
        assert r(checksum) == `trk_checksum'
        sysdir set PLUS "`seeded_plus'"
        ado dir
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: outer installation survives `entry'"
    }
    else {
        local ++fail_count
        display as error "FAIL: outer installation survives `entry' (error `=_rc')"
    }
}
capture log close _all
log using "test_qa_isolation.log", replace nomsg
do "_comorbidity_qa_common.do"
_comorbidity_result test_qa_isolation `test_count' `pass_count' `fail_count'
log close _all
