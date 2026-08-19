*! test_tabtools_v1163.do - Regression tests for tabtools 1.16.3
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set processors 1
set varabbrev off
version 17.0

capture log close _all
log using "test_tabtools_v1163.log", replace text name(_v1163)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

**# R1. missingsummary rows remain attached to their variables
local ++test_count
capture noisily {
    clear
    set obs 12
    gen byte group = _n > 6
    gen byte category = mod(_n, 3)
    replace category = . in 2
    gen double first = _n
    replace first = . in 1
    gen double second = 100 + _n
    replace second = . in 8/9
    gen double complete = 200 + _n

    label define category_lbl 0 "Zero" 1 "One" 2 "Two"
    label values category category_lbl
    label variable category "Category variable"
    label variable first "First variable"
    label variable second "Second variable"
    label variable complete "Complete variable"

    table1_tc, by(group) ///
        vars(category cat \ first contn \ second contn \ complete contn) ///
        missingsummary frame(_v1163_table, replace)

    frame _v1163_table {
        assert _N == 12
        assert factor[3] == "Category variable"
        assert factor[4] == "   Zero"
        assert factor[5] == "   One"
        assert factor[6] == "   Two"
        assert factor[7] == "   Missing"
        assert group_0[7] == "1 (17)"
        assert group_1[7] == "0"

        assert factor[8] == "First variable"
        assert factor[9] == "   Missing"
        assert group_0[9] == "1 (17)"
        assert group_1[9] == "0"

        assert factor[10] == "Second variable"
        assert factor[11] == "   Missing"
        assert group_0[11] == "0"
        assert group_1[11] == "2 (33)"

        assert factor[12] == "Complete variable"
    }
    frame drop _v1163_table
}
if _rc == 0 {
    display as result "  PASS: missingsummary rows remain attached to their variables"
    local ++pass_count
}
else {
    display as error "  FAIL: missingsummary variable attachment (rc=`=_rc')"
    local ++fail_count
    capture frame drop _v1163_table
}

**# Summary
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_tabtools_v1163 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _v1163
if `fail_count' > 0 exit 1
