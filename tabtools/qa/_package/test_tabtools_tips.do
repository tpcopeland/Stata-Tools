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

display as text ""
display as text "test_tabtools_tips.do summary"
display as text "  Tests:  " as result `test_count'
display as text "  Passed: " as result `pass_count'
display as text "  Failed: " as result `fail_count'

log close _tips

if `fail_count' > 0 {
    display as error "Failed tests: `failed_tests'"
    exit 9
}

exit 0
