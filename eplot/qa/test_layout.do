/*******************************************************************************
* test_layout.do
* Focused regression tests for eplot v1.1.0
*
* Covers:
*   - gap() spacing in data mode
*   - gap() spacing in single-model estimates mode
*   - effect-axis xlabel() passthrough in horizontal layout
*   - effect-axis xlabel() remapping in vertical layout
*   - dynamic values-column margin for wide vformat()
*   - documented mode-detection precedence when estimate names collide with vars
*******************************************************************************/

version 16.0

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall eplot
quietly net install eplot, from("`pkg_dir'") replace

capture log close _all
log using "`qa_dir'/test_layout.log", replace text nomsg name(test_layout)

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

* -----------------------------------------------------------------------------
* Test 1: Package installs and command resolves
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    which eplot
}
if _rc == 0 {
    display as result "  PASS: Test 1 - eplot installs from package directory"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 1 - install/which failed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

* -----------------------------------------------------------------------------
* Test 2: gap() adds spacing rows in data mode groups()
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    clear
    input str12 lab double(es lci uci)
    "A" 0.50 0.20 0.80
    "B" 0.30 0.10 0.50
    "C" 1.50 1.10 1.90
    "D" 1.20 0.90 1.50
    end

    eplot es lci uci, labels(lab) ///
        groups(A B = "Group 1" C D = "Group 2") gap(0.75) ///
        name(_v110_t2, replace)

    assert r(N) == 7
    assert r(k) == 4
}
if _rc == 0 {
    display as result "  PASS: Test 2 - gap() works in data mode"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 2 - data-mode gap() failed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}
capture graph drop _v110_t2

* -----------------------------------------------------------------------------
* Test 3: gap() adds spacing rows in single-model estimates mode
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight foreign

    eplot ., drop(_cons) ///
        groups(mpg weight = "Core Covariates" foreign = "Indicator") ///
        gap(0.50) name(_v110_t3, replace)

    assert r(N) == 6
    assert r(k) == 3
}
if _rc == 0 {
    display as result "  PASS: Test 3 - gap() works in estimates mode"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 3 - estimates-mode gap() failed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}
capture graph drop _v110_t3

* -----------------------------------------------------------------------------
* Test 4: Default horizontal effect axis keeps auto-generated ticks
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight foreign

    eplot ., drop(_cons) name(_v110_t4, replace)

    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "xlabel(`""')") == 0
    assert strpos(`"`cmd'"', "grid glcolor(gs12) glwidth(vthin)") > 0
}
if _rc == 0 {
    display as result "  PASS: Test 4 - default effect axis keeps auto ticks"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 4 - default effect axis ticks missing (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}
capture graph drop _v110_t4

* -----------------------------------------------------------------------------
* Test 5: xlabel() passes through to the horizontal effect axis
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    clear
    input str12 lab double(es lci uci)
    "A" 0.50 0.20 0.80
    "B" 1.20 0.90 1.50
    end

    eplot es lci uci, labels(lab) ///
        xlabel(0.2 `"Low"' 1.2 `"High"') ///
        name(_v110_t5, replace)

    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "xlabel(") > 0
    assert strpos(`"`cmd'"', `"Low"' ) > 0
    assert strpos(`"`cmd'"', `"High"' ) > 0
}
if _rc == 0 {
    display as result "  PASS: Test 5 - horizontal xlabel() passthrough"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 5 - horizontal xlabel() failed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}
capture graph drop _v110_t5

* -----------------------------------------------------------------------------
* Test 6: xlabel() remaps to the effect axis in vertical layout
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight

    eplot ., drop(_cons) vertical ///
        xlabel(-150 `"Low"' 0 `"Zero"' 75 `"High"') ///
        name(_v110_t6, replace)

    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "ylabel(") > 0
    assert strpos(`"`cmd'"', `"Low"' ) > 0
    assert strpos(`"`cmd'"', `"Zero"' ) > 0
    assert strpos(`"`cmd'"', `"High"' ) > 0
}
if _rc == 0 {
    display as result "  PASS: Test 6 - vertical xlabel() remaps to effect axis"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 6 - vertical xlabel() remap failed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}
capture graph drop _v110_t6

* -----------------------------------------------------------------------------
* Test 7: Wide vformat() expands the values-column margin
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    clear
    input str12 lab double(es lci uci)
    "A" 0.5123 0.2123 0.8123
    "B" 1.2345 0.9345 1.5345
    end

    eplot es lci uci, labels(lab) values ///
        name(_v110_t7_default, replace)

    local cmd_default `"`r(cmd)'"'
    local prefix "plotregion(margin(l+2 r+"
    local start_default = strpos(`"`cmd_default'"', "`prefix'")
    assert `start_default' > 0
    local rest_default = substr(`"`cmd_default'"', `start_default' + length("`prefix'"), .)
    local stop_default = strpos(`"`rest_default'"', " t+2 b+2))")
    assert `stop_default' > 1
    local default_margin = real(substr(`"`rest_default'"', 1, `stop_default' - 1))

    eplot es lci uci, labels(lab) values vformat(%8.4f) ///
        name(_v110_t7, replace)

    local cmd `"`r(cmd)'"'
    local start = strpos(`"`cmd'"', "`prefix'")
    assert `start' > 0
    local rest = substr(`"`cmd'"', `start' + length("`prefix'"), .)
    local stop = strpos(`"`rest'"', " t+2 b+2))")
    assert `stop' > 1
    local right_margin = real(substr(`"`rest'"', 1, `stop' - 1))
    assert `right_margin' > `default_margin'
    assert `right_margin' >= 18
}
if _rc == 0 {
    display as result "  PASS: Test 7 - values margin scales with wide vformat()"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 7 - dynamic values margin failed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}
capture graph drop _v110_t7
capture graph drop _v110_t7_default

* -----------------------------------------------------------------------------
* Test 8: Mode detection still prefers data mode when names collide
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double y = rnormal()
    gen double x = rnormal()
    gen double es = _n / 10
    gen double lci = es - 0.05
    gen double uci = es + 0.05

    quietly regress y x
    estimates store es

    eplot es lci uci, name(_v110_t8, replace)

    assert r(N) == 5
    assert r(k) == 5
}
if _rc == 0 {
    display as result "  PASS: Test 8 - documented mode-detection precedence holds"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 8 - mode-detection precedence changed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}
capture graph drop _v110_t8
capture estimates drop es

display _newline as result "=== v1.1.0 QA Summary: `pass_count' passed, `fail_count' failed ==="
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 1
}

log close test_layout
