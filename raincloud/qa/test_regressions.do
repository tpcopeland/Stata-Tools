clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_regressions.log", replace nomsg

* test_regressions.do - Review regressions and weighted contracts for raincloud

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir  "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_raincloud_qa_common.do"
_raincloud_qa_bootstrap "`pkg_dir'"

**# Long group labels

local ++test_count
capture noisily {
    clear
    local label_a "abcdefghijklmnopqrstuvwxyz1234567890_A"
    local label_b "abcdefghijklmnopqrstuvwxyz1234567890_B"
    input double x str60 grp
        1 "abcdefghijklmnopqrstuvwxyz1234567890_A"
        2 "abcdefghijklmnopqrstuvwxyz1234567890_A"
        3 "abcdefghijklmnopqrstuvwxyz1234567890_B"
        4 "abcdefghijklmnopqrstuvwxyz1234567890_B"
    end

    raincloud x, over(grp) seed(11)
    local got_levels `"`r(group_levels)'"'
    local got_labels `"`r(group_labels)'"'
    matrix S = r(stats)
    local rnames : rownames S

    assert r(N) == 4
    assert r(n_groups) == 2
    assert rowsof(S) == 2
    assert S[1,1] == 2
    assert S[2,1] == 2
    assert abs(S[1,2] - 1.5) < 1e-12
    assert abs(S[2,2] - 3.5) < 1e-12
    assert "`rnames'" == "group1 group2"
    assert "`got_levels'" == "1 2"
    assert strpos(`"`got_labels'"', "`label_a'") > 0
    assert strpos(`"`got_labels'"', "`label_b'") > 0
}
if _rc == 0 {
    display as result "  PASS: long group labels retain usable statistics and exact label mapping"
    local ++pass_count
}
else {
    display as error "  FAIL: long group labels retain usable statistics and exact label mapping (error `=_rc')"
    local ++fail_count
}

**# Analytical returns after saving failure

local ++test_count
capture noisily {
    sysuse auto, clear
    tempfile missing_seed
    local bad_path "`missing_seed'_missing/out.gph"

    return clear
    capture noisily raincloud mpg, over(foreign) seed(19) ///
        saving("`bad_path'", replace)
    local got_rc = _rc
    local got_N = r(N)
    local got_n_groups = r(n_groups)
    local got_varname `"`r(varname)'"'
    local got_over `"`r(over)'"'
    local got_levels `"`r(group_levels)'"'
    local got_labels `"`r(group_labels)'"'
    matrix S = r(stats)

    assert `got_rc' == 603
    assert `got_N' == 74
    assert `got_n_groups' == 2
    assert "`got_varname'" == "mpg"
    assert "`got_over'" == "foreign"
    assert "`got_levels'" == "0 1"
    assert strpos(`"`got_labels'"', "Domestic") > 0
    assert strpos(`"`got_labels'"', "Foreign") > 0
    assert rowsof(S) == 2
    assert colsof(S) == 8
    assert S[1,1] == 52
    assert S[2,1] == 22
}
if _rc == 0 {
    display as result "  PASS: saving failure preserves the full analytical return surface"
    local ++pass_count
}
else {
    display as error "  FAIL: saving failure preserves the full analytical return surface (error `=_rc')"
    local ++fail_count
}

**# Frequency-weight semantics

local ++test_count
capture noisily {
    clear
    input double x int fw
        1 1
        3 3
    end

    raincloud x [fweight = fw], nocloud seed(23)
    matrix S = r(stats)

    * r(N) counts marked data rows; r(stats)[,n] is the weighted count.
    assert r(N) == 2
    assert S[1,1] == 4
    assert abs(S[1,2] - 2.5) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: frequency-weight count and mean semantics"
    local ++pass_count
}
else {
    display as error "  FAIL: frequency-weight count and mean semantics (error `=_rc')"
    local ++fail_count
}

**# Summary

local suite_rc = cond(`fail_count' > 0, 1, 0)
display "RESULT: test_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
exit `suite_rc'
