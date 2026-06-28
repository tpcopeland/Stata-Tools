clear all
set more off
set varabbrev off
version 16.0

capture log close
log using "test_tvtools.log", replace nomsg

* Shared scaffold: test globals + helpers + sandboxed install bootstrap
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""
local run_only = 0
local quiet = 0

* run_test/test_pass/test_fail harness counters (folded into the totals below)
global TVQA_PASS = 0
global TVQA_FAIL = 0
global TVQA_FAILED ""
global TVQA_CURRENT ""

display as result "tvtools QA: tvtools dispatcher -- $S_DATE $S_TIME"


**# ===== merged from test_tvtools.do L12438-12669: SECTION 1 TVTOOLS dispatcher =====

* SECTION 1: TVTOOLS — dispatcher command

* TEST 1.1: Default invocation with stored results
local ++test_count
capture noisily {
    clear
    tvtools
    assert "`r(version)'" != ""
    assert r(n_commands) > 0
    assert "`r(commands)'" != ""
    assert "`r(categories)'" == "prep diag weight"
}
if _rc == 0 {
    display as result "  PASS: Default invocation returns stored results"
    local ++pass_count
}
else {
    display as error "  FAIL: Default invocation returns stored results (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
}

* TEST 1.2: Category filter — prep
local ++test_count
capture noisily {
    tvtools, category(prep)
    assert r(n_commands) == 5
    local cmds "`r(commands)'"
    assert strpos("`cmds'", "tvexpose") > 0
    assert strpos("`cmds'", "tvmerge") > 0
    assert strpos("`cmds'", "tvevent") > 0
    assert strpos("`cmds'", "tvage") > 0
    assert strpos("`cmds'", "tvpanel") > 0
}
if _rc == 0 {
    display as result "  PASS: category(prep) returns 5 commands"
    local ++pass_count
}
else {
    display as error "  FAIL: category(prep) returns 4 commands (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
}

* TEST 1.3: Category filter — diag
local ++test_count
capture noisily {
    tvtools, category(diag)
    assert r(n_commands) == 1
    local cmds "`r(commands)'"
    assert strpos("`cmds'", "tvdiagnose") > 0
}
if _rc == 0 {
    display as result "  PASS: category(diag) returns 1 command"
    local ++pass_count
}
else {
    display as error "  FAIL: category(diag) returns 1 command (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.3"
}

* TEST 1.4: Category filter — weight
local ++test_count
capture noisily {
    tvtools, category(weight)
    assert r(n_commands) == 1
    local cmds "`r(commands)'"
    assert strpos("`cmds'", "tvweight") > 0
}
if _rc == 0 {
    display as result "  PASS: category(weight) returns 1 command"
    local ++pass_count
}
else {
    display as error "  FAIL: category(weight) returns 1 command (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.4"
}

* TEST 1.5: Category filter — special (removed, no longer exists)

* TEST 1.6: Category filter — all
local ++test_count
capture noisily {
    tvtools, category(all)
    assert r(n_commands) == 7
    assert strpos("`r(commands)'", "tvpanel") > 0
}
if _rc == 0 {
    display as result "  PASS: category(all) returns 7 commands"
    local ++pass_count
}
else {
    display as error "  FAIL: category(all) returns 6 commands (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.6"
}

* TEST 1.7: Invalid category — error 198
local ++test_count
capture noisily {
    capture tvtools, category(bogus)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Invalid category returns error 198"
    local ++pass_count
}
else {
    display as error "  FAIL: Invalid category returns error 198 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.7"
}

* TEST 1.8: list option
local ++test_count
capture noisily {
    tvtools, list
    assert "`r(commands)'" != ""
    assert r(n_commands) == 7
}
if _rc == 0 {
    display as result "  PASS: list option works"
    local ++pass_count
}
else {
    display as error "  FAIL: list option works (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.8"
}

* TEST 1.9: detail option
local ++test_count
capture noisily {
    tvtools, detail
    assert "`r(version)'" != ""
}
if _rc == 0 {
    display as result "  PASS: detail option works"
    local ++pass_count
}
else {
    display as error "  FAIL: detail option works (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.9"
}

* TEST 1.10: list + category combination
local ++test_count
capture noisily {
    tvtools, list category(prep)
    assert r(n_commands) == 5
}
if _rc == 0 {
    display as result "  PASS: list + category(prep) combination works"
    local ++pass_count
}
else {
    display as error "  FAIL: list + category(prep) combination works (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.10"
}

* TEST 1.11: detail + category combination
local ++test_count
capture noisily {
    tvtools, detail category(weight)
    assert r(n_commands) == 1
}
if _rc == 0 {
    display as result "  PASS: detail + category(weight) combination works"
    local ++pass_count
}
else {
    display as error "  FAIL: detail + category(weight) combination works (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.11"
}

* TEST 1.12: Case-insensitive category
local ++test_count
capture noisily {
    tvtools, category(PREP)
    assert r(n_commands) == 5
}
if _rc == 0 {
    display as result "  PASS: Case-insensitive category(PREP) works"
    local ++pass_count
}
else {
    display as error "  FAIL: Case-insensitive category(PREP) works (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.12"
}

* TEST 1.13: Varabbrev restore after tvtools
local ++test_count
capture noisily {
    set varabbrev on
    tvtools
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: Varabbrev restored after tvtools"
    local ++pass_count
}
else {
    display as error "  FAIL: Varabbrev restored after tvtools (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.13"
}

* TEST 1.14: Varabbrev restore after tvtools error
local ++test_count
capture noisily {
    set varabbrev on
    capture tvtools, category(bogus)
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: Varabbrev restored after tvtools error"
    local ++pass_count
}
else {
    display as error "  FAIL: Varabbrev restored after tvtools error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.14"
}

* TEST 1.15: tvpanel listed in default and detail views (index completeness)
local ++test_count
capture noisily {
    tvtools
    assert strpos("`r(commands)'", "tvpanel") > 0
    tvtools, detail
    assert strpos("`r(commands)'", "tvpanel") > 0
}
if _rc == 0 {
    display as result "  PASS: tvpanel present in default and detail command index"
    local ++pass_count
}
else {
    display as error "  FAIL: tvpanel present in default and detail command index (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.15"
}




* ===== Summary =====
* Fold the run_test/test_pass/test_fail harness counters into the totals.
local pass_count = `pass_count' + $TVQA_PASS
local fail_count = `fail_count' + $TVQA_FAIL
local failed_tests "`failed_tests' $TVQA_FAILED"
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA tvtools dispatcher Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: test_tvtools tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"

