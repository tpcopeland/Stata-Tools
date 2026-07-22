* test_tabtools_tips.do - tabtools_tips command and merged help aliases

clear all
set more off
set varabbrev off
version 16.0

capture log close _tips
log using "test_tabtools_tips.log", replace text name(_tips)

local cwd "`c(pwd)'"
if regexm("`cwd'", "/qa/_package$") {
    local qa_dir = regexr("`cwd'", "/_package$", "")
}
else if regexm("`cwd'", "/qa$") {
    local qa_dir "`cwd'"
}
else {
    local qa_dir "`cwd'"
}
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local ++test_count
capture noisily {
    which tabtools_tips
    findfile tabtools_tips.sthlp
    capture findfile tabtools_cheatsheet.sthlp
    assert _rc != 0
    capture findfile tabtools_cookbook.sthlp
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: tabtools_tips resolves; retired alias help files absent"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools_tips command/help resolution (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' resolution"
}

local ++test_count
capture noisily {
    tabtools_tips
}
if _rc == 0 {
    display as result "  PASS: tabtools_tips index display runs"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools_tips index display (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' display"
}

local ++test_count
capture noisily {
    capture tabtools_tips, open
    assert inlist(_rc, 0, 199)
}
if _rc == 0 {
    display as result "  PASS: tabtools_tips open option dispatches in batch"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools_tips open option dispatch (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' open"
}

local ++test_count
capture noisily {
    tabtools, category(general)
    assert r(n_commands) == 2
    local commands " `r(commands)' "
    assert strpos("`commands'", " tabtools ") > 0
    assert strpos("`commands'", " tabtools_tips ") > 0
}
if _rc == 0 {
    display as result "  PASS: tabtools general category includes tabtools_tips"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools general category inventory (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' general_category"
}

local ++test_count
capture noisily {
    capture frame drop quick_table1
    capture frame drop quick_model
    sysuse auto, clear
    generate byte expensive = price > 6000
    table1_tc price mpg weight rep78, by(foreign) smd ///
        frame(quick_table1, replace)
    frame quick_table1: assert _N > 4

    collect clear
    collect: logistic expensive mpg weight i.foreign
    regtab, nointercept frame(quick_model, replace)
    frame quick_model: assert _N > 3
    frame quick_model: local _quick_ci : char _dta[tabtools_ci_level]
    assert real("`_quick_ci'") == 95
    capture frame drop quick_table1
    capture frame drop quick_model
}
if _rc == 0 {
    display as result "  PASS: README Quick Start runs and produces reusable frames"
    local ++pass_count
}
else {
    display as error "  FAIL: README Quick Start (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' readme_quick_start"
    capture frame drop quick_table1
    capture frame drop quick_model
}

local ++test_count
capture noisily {
    tempname _tips_rate_tag
    local _tips_rate_base "`c(tmpdir)'/`c(pid)'_tabtools_tips_rate_`_tips_rate_tag'"
    webuse diet, clear
    quietly stset dox, failure(fail) origin(time dob) enter(time doe) ///
        scale(365.25) id(id)
    quietly strate hienergy, per(1) output(`_tips_rate_base', replace)

    preserve
    quietly use "`_tips_rate_base'.dta", clear
    quietly summarize _Y if hienergy == 0, meanonly
    local _tips_py0 = r(mean)
    quietly summarize _Rate if hienergy == 0, meanonly
    local _tips_rate0 = r(mean) * 1000
    quietly summarize _Lower if hienergy == 0, meanonly
    local _tips_lo0 = r(mean) * 1000
    quietly summarize _Upper if hienergy == 0, meanonly
    local _tips_hi0 = r(mean) * 1000
    restore

    stratetab, using(`_tips_rate_base') outcomes(1) ///
        outlabels("CHD Death") explabels("Energy Intake") ///
        frame(_tips_rate_recipe, replace)
    matrix _tips_rates = r(rates)
    assert abs(_tips_rates[1,1] - `_tips_rate0') < 1e-10
    frame _tips_rate_recipe: quietly count if c4 == "Per 1,000 PY (95% CI)"
    assert r(N) == 1
    frame _tips_rate_recipe: generate long _tips_recipe_row = _n
    frame _tips_rate_recipe: quietly summarize _tips_recipe_row if strtrim(c1) == "0", meanonly
    local _tips_rate_row = r(min)
    assert `_tips_rate_row' < .
    frame _tips_rate_recipe: local _tips_py_display = c3[`_tips_rate_row']
    local _tips_py_display : subinstr local _tips_py_display "," "", all
    assert abs(real("`_tips_py_display'") - `_tips_py0') < 0.5
    frame _tips_rate_recipe: local _tips_ci_display = c4[`_tips_rate_row']
    assert regexm("`_tips_ci_display'", "^([0-9.]+) \(([0-9.]+)-([0-9.]+)\)$")
    assert abs(real(regexs(1)) - `_tips_rate0') < 0.05
    assert abs(real(regexs(2)) - `_tips_lo0') < 0.05
    assert abs(real(regexs(3)) - `_tips_hi0') < 0.05
    capture frame drop _tips_rate_recipe
    capture erase "`_tips_rate_base'.dta"
}
if _rc == 0 {
    display as result "  PASS: incidence-rate recipe preserves rate, CI, person-years, and units"
    local ++pass_count
}
else {
    display as error "  FAIL: incidence-rate recipe numerical contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' incidence_recipe"
    capture frame drop _tips_rate_recipe
    capture erase "`_tips_rate_base'.dta"
}

local ++test_count
capture noisily {
    tempname _tips_recipe_tag
    local _tips_recipe_dir "`c(tmpdir)'/`c(pid)'_tabtools_tips_recipes_`_tips_recipe_tag'"
    capture mkdir "`_tips_recipe_dir'"
    tempfile _tips_recipe_result
    shell python3 "`qa_dir'/tools/run_help_recipes.py" ///
        --help-file "`pkg_dir'/tabtools_tips.sthlp" ///
        --package-dir "`pkg_dir'" ///
        --output-dir "`_tips_recipe_dir'" > "`_tips_recipe_result'"
    assert _rc == 0

    tempname _tips_recipe_fh
    local _tips_recipe_green 0
    file open `_tips_recipe_fh' using "`_tips_recipe_result'", read text
    file read `_tips_recipe_fh' _tips_recipe_line
    while r(eof) == 0 {
        if strpos(`"`_tips_recipe_line'"', ///
            "RESULT: tabtools_tips_recipes tests=21 pass=21 fail=0") > 0 {
            local _tips_recipe_green 1
        }
        file read `_tips_recipe_fh' _tips_recipe_line
    }
    file close `_tips_recipe_fh'
    assert `_tips_recipe_green' == 1
    capture shell rm -rf "`_tips_recipe_dir'"
}
if _rc == 0 {
    display as result "  PASS: all 21 help recipes run in independent Stata processes"
    local ++pass_count
}
else {
    display as error "  FAIL: fresh-process help recipes (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' all_help_recipes"
    capture shell rm -rf "`_tips_recipe_dir'"
}

display as text ""
display as text "test_tabtools_tips.do summary"
display as text "  Tests:  " as result `test_count'
display as text "  Passed: " as result `pass_count'
display as text "  Failed: " as result `fail_count'
display "RESULT: test_tabtools_tips tests=`test_count' pass=`pass_count' fail=`fail_count'"

log close _tips

if `fail_count' > 0 {
    display as error "Failed tests: `failed_tests'"
    exit 9
}

exit 0
