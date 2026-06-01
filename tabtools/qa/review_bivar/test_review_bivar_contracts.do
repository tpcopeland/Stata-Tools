*! test_review_bivar_contracts.do - review QA for bivariate/descriptive tabtools commands

clear all
version 17.0
set more off

capture log close _review_bivar
log using "review_bivar/test_review_bivar_contracts.log", replace text name(_review_bivar)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

ado dir
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Helpers
capture program drop _review_build_comptab_frame
program define _review_build_comptab_frame
    version 17.0
    capture frame drop rb_src
    frame create rb_src
    frame rb_src {
        clear
        set obs 5
        gen str244 A = ""
        gen str244 c1 = ""
        gen str244 c2 = ""
        gen str244 c3 = ""
        replace A = "Variable" in 2
        replace c1 = "Estimate" in 2
        replace c2 = "95% CI" in 2
        replace c3 = "p-value" in 2
        replace A = "Characteristic" in 3
        replace c1 = "b" in 3
        replace c2 = "95% CI" in 3
        replace c3 = "p-value" in 3
        replace A = "Age" in 4
        replace c1 = "1.23" in 4
        replace c2 = "(0.50, 1.96)" in 4
        replace c3 = "0.040" in 4
        replace A = "Sex" in 5
        replace c1 = "0.88" in 5
        replace c2 = "(0.40, 1.36)" in 5
        replace c3 = "0.520" in 5
        gen long _orig_n = _n
        gen byte _keep = 99
    }
end

**# Tests

local ++test_count
capture noisily {
    set varabbrev on
    clear
    set obs 10
    gen double x = _n
    gen double y = _n
    capture corrtab x y, lower upper
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: corrtab validation error restores varabbrev"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab validation error restores varabbrev (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    set varabbrev on
    clear
    input byte outcome byte exposure
    0 0
    0 1
    0 2
    1 0
    1 1
    1 2
    end
    capture crosstab outcome exposure, or
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: crosstab non-2x2 association error restores varabbrev"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab non-2x2 association error restores varabbrev (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    set varabbrev on
    clear
    input byte outcome byte exposure
    0 0
    0 1
    1 0
    1 1
    end
    capture crosstab outcome exposure, rowpct totalpct
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: crosstab percent-mode conflict restores varabbrev"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab percent-mode conflict restores varabbrev (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    set varabbrev on
    _review_build_comptab_frame
    capture comptab rb_src, rows(1) rownames(age) display
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: comptab rows()/rownames() conflict restores varabbrev"
    local ++pass_count
}
else {
    display as error "  FAIL: comptab rows()/rownames() conflict restores varabbrev (rc=`=_rc')"
    local ++fail_count
}
capture frame drop rb_src

local ++test_count
capture noisily {
    _review_build_comptab_frame
    capture frame drop rb_out
    comptab rb_src, rows(1 2) frame(rb_out, replace)
    assert r(N_rows) == 5
    frame rb_out {
        assert A[4] == "Age"
        assert A[5] == "Sex"
        capture confirm variable _orig_n
        assert _rc != 0
        capture confirm variable _keep
        assert _rc != 0
    }
}
if _rc == 0 {
    display as result "  PASS: comptab source helper-name columns do not leak into output"
    local ++pass_count
}
else {
    display as error "  FAIL: comptab source helper-name columns do not leak into output (rc=`=_rc')"
    local ++fail_count
}
capture frame drop rb_src
capture frame drop rb_out

local ++test_count
capture noisily {
    set varabbrev on
    sysuse auto, clear
    capture frame drop rb_star_desc
    capture frame drop rb_star_asc
    quietly corrtab price mpg weight length, full star(0.1 0.05 0.01) ///
        frame(rb_star_desc, replace)
    local desc_methods `"`r(methods)'"'
    quietly corrtab price mpg weight length, full star(0.01 0.05 0.1) ///
        frame(rb_star_asc, replace)
    local asc_methods `"`r(methods)'"'
    assert `"`desc_methods'"' == `"`asc_methods'"'
    assert strpos(`"`desc_methods'"', "* p<.1") > 0 | ///
        strpos(`"`desc_methods'"', "* p<0.1") > 0
    assert strpos(`"`desc_methods'"', "** p<.05") > 0 | ///
        strpos(`"`desc_methods'"', "** p<0.05") > 0
    assert strpos(`"`desc_methods'"', "*** p<.01") > 0 | ///
        strpos(`"`desc_methods'"', "*** p<0.01") > 0
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: corrtab star() thresholds normalize order and restore varabbrev"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab star() threshold-order contract (rc=`=_rc')"
    local ++fail_count
}
capture frame drop rb_star_desc
capture frame drop rb_star_asc

local ++test_count
capture noisily {
    set varabbrev on
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(count price)
    capture desctab, keep(3) drop(4)
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: desctab keep()/drop() conflict restores varabbrev"
    local ++pass_count
}
else {
    display as error "  FAIL: desctab keep()/drop() conflict restores varabbrev (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as result "review_bivar QA summary: `pass_count' passed, `fail_count' failed"
display "RESULT: test_review_bivar_contracts tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    log close _review_bivar
    exit 1
}

log close _review_bivar
