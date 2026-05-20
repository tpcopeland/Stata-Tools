*! test_regtab_nopvalue.do - QA for regtab p-value suppression
*! Validates that regtab, nopvalue removes p-value columns from rendered
*! outputs while preserving internal p-values for significance stars.

clear all
set more off
version 17.0

local _cwd "`c(pwd)'"
if regexm("`_cwd'", "/qa/regtab$") {
    local pkg_root = regexr("`_cwd'", "/qa/regtab$", "")
    local qa_dir = regexr("`_cwd'", "/regtab$", "")
}
else if regexm("`_cwd'", "/qa$") {
    local pkg_root = regexr("`_cwd'", "/qa$", "")
    local qa_dir "`_cwd'"
}
else {
    local pkg_root "`_cwd'"
    local qa_dir "`pkg_root'/qa"
}

local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture log close _rt_nop
log using "`output_dir'/test_regtab_nopvalue.log", replace text name(_rt_nop)

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_root'") replace
discard

local pass = 0
local fail = 0
local total = 0

**# Test 1: default output keeps p-value column
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    capture frame drop _rt_np_default
    regtab, frame(_rt_np_default, replace)
    local got_ncols = r(N_cols)

    frame _rt_np_default {
        quietly ds c*
        local ncvars : word count `r(varlist)'
        assert `ncvars' == 3
        assert strtrim(c3[3]) == "p-value"
    }
    assert `got_ncols' == 5
}
if _rc == 0 {
    display as result "  PASS: Test 1 - default regtab keeps p-value column"
    local ++pass
}
else {
    display as error "  FAIL: Test 1 - default p-value column contract changed (rc=`=_rc')"
    local ++fail
}
capture frame drop _rt_np_default

**# Test 2: nopvalue removes p-value column from frame output
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    capture frame drop _rt_np_frame
    regtab, frame(_rt_np_frame, replace) nopvalue
    local got_ncols = r(N_cols)

    frame _rt_np_frame {
        quietly ds c*
        local ncvars : word count `r(varlist)'
        assert `ncvars' == 2
        assert strtrim(c1[3]) == "Coef."
        assert strpos(c2[3], "CI") > 0
        capture confirm variable c3
        assert _rc != 0
    }
    assert `got_ncols' == 4
}
if _rc == 0 {
    display as result "  PASS: Test 2 - nopvalue suppresses frame p-value column"
    local ++pass
}
else {
    display as error "  FAIL: Test 2 - nopvalue frame output kept p-values (rc=`=_rc')"
    local ++fail
}
capture frame drop _rt_np_frame

**# Test 3: compact + nopvalue leaves one estimate-and-CI column per model
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    capture frame drop _rt_np_compact
    regtab, frame(_rt_np_compact, replace) compact nopvalue
    local got_ncols = r(N_cols)

    frame _rt_np_compact {
        quietly ds c*
        local ncvars : word count `r(varlist)'
        assert `ncvars' == 1
        assert strpos(c1[3], "CI") > 0
        assert strpos(c1[4], "(") > 0
        assert strpos(c1[4], ")") > 0
        capture confirm variable c2
        assert _rc != 0
    }
    assert `got_ncols' == 3
}
if _rc == 0 {
    display as result "  PASS: Test 3 - compact nopvalue has one data column"
    local ++pass
}
else {
    display as error "  FAIL: Test 3 - compact nopvalue column contract failed (rc=`=_rc')"
    local ++fail
}
capture frame drop _rt_np_compact

**# Test 4: stars still use internal p-values when p-value columns are hidden
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    capture frame drop _rt_np_stars
    regtab, frame(_rt_np_stars, replace) nopvalue stars

    frame _rt_np_stars {
        quietly ds c*
        local ncvars : word count `r(varlist)'
        assert `ncvars' == 2
        gen byte _has_star = strpos(c1, "*") > 0 if _n >= 4
        summarize _has_star, meanonly
        assert r(max) == 1
        capture confirm variable c3
        assert _rc != 0
    }
}
if _rc == 0 {
    display as result "  PASS: Test 4 - stars survive p-value suppression"
    local ++pass
}
else {
    display as error "  FAIL: Test 4 - stars not computed under nopvalue (rc=`=_rc')"
    local ++fail
}
capture frame drop _rt_np_stars

**# Test 5: multi-model nopvalue removes one p-value column per model
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    collect: regress price mpg weight i.foreign

    capture frame drop _rt_np_multi
    regtab, frame(_rt_np_multi, replace) nopvalue models("Base \ Adjusted")
    local got_ncols = r(N_cols)

    frame _rt_np_multi {
        quietly ds c*
        local ncvars : word count `r(varlist)'
        assert `ncvars' == 4
        assert strtrim(c1[2]) == "Base"
        assert strtrim(c3[2]) == "Adjusted"
        assert strpos(c2[3], "CI") > 0
        assert strpos(c4[3], "CI") > 0
        capture confirm variable c5
        assert _rc != 0
    }
    assert `got_ncols' == 6
}
if _rc == 0 {
    display as result "  PASS: Test 5 - multi-model nopvalue suppresses both p columns"
    local ++pass
}
else {
    display as error "  FAIL: Test 5 - multi-model nopvalue layout failed (rc=`=_rc')"
    local ++fail
}
capture frame drop _rt_np_multi

**# Test 6: CSV and Excel exports do not contain rendered p-value headers
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    local csvout "`output_dir'/_test_regtab_nopvalue.csv"
    local xlsxout "`output_dir'/_test_regtab_nopvalue.xlsx"
    capture erase "`csvout'"
    capture erase "`xlsxout'"

    regtab, csv("`csvout'") xlsx("`xlsxout'") sheet("NoP") nopvalue
    confirm file "`csvout'"
    confirm file "`xlsxout'"

    import delimited using "`csvout'", clear varnames(1) stringcols(_all)
    quietly ds
    local csvvars "`r(varlist)'"
    assert strpos("`csvvars'", "p") == 0

    import excel "`xlsxout'", sheet("NoP") clear allstring
    ds
    foreach v of varlist _all {
        quietly count if strtrim(`v') == "p-value"
        assert r(N) == 0
    }
}
if _rc == 0 {
    display as result "  PASS: Test 6 - CSV and Excel omit p-value headers"
    local ++pass
}
else {
    display as error "  FAIL: Test 6 - exported nopvalue output exposed p-values (rc=`=_rc')"
    local ++fail
}

**# Test 7: compact nopvalue exports to Excel without a p-value column
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    local xlsxout "`output_dir'/_test_regtab_nopvalue_compact.xlsx"
    capture erase "`xlsxout'"

    regtab, xlsx("`xlsxout'") sheet("CompactNoP") compact nopvalue
    confirm file "`xlsxout'"

    import excel "`xlsxout'", sheet("CompactNoP") clear allstring
    ds
    foreach v of varlist _all {
        quietly count if strtrim(`v') == "p-value"
        assert r(N) == 0
    }
}
if _rc == 0 {
    display as result "  PASS: Test 7 - compact nopvalue Excel export succeeds"
    local ++pass
}
else {
    display as error "  FAIL: Test 7 - compact nopvalue Excel export failed (rc=`=_rc')"
    local ++fail
}

display "RESULT: test_regtab_nopvalue tests=`total' pass=`pass' fail=`fail'"
log close _rt_nop

if `fail' > 0 exit 9
