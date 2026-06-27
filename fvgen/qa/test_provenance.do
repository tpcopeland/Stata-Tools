clear all
set varabbrev off
version 16.0

* Provenance characteristics (fvgen_role / fvgen_term) and the drop teardown
* that uses them. These two features are one mechanism: every generated variable
* is tagged, and fvgen, drop removes exactly the tagged variables.

do _fvgen_qa_common.do
_fvgen_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# 1. Role/term characteristics on main, interaction, and centered vars
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm##c.age
    * categorical indicator -> role main, term = the fv factor-level
    assert "`: char _arm_1[fvgen_role]'" == "main"
    assert "`: char _arm_1[fvgen_term]'" == "1.arm"
    * product -> role interaction, term = the fv interaction
    assert "`: char _armXage_1[fvgen_role]'" == "interaction"
    assert "`: char _armXage_1[fvgen_term]'" == "1.arm#c.age"
    * a pass-through original carries NO fvgen characteristic
    assert "`: char age[fvgen_role]'" == ""
}
if _rc == 0 {
    display as result "  PASS: role/term chars on main + interaction"
    local ++pass_count
}
else {
    display as error "  FAIL: role/term chars (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**# 2. Centered copies carry role=centered
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen c.age##c.bmi, center
    assert "`: char _age_c[fvgen_role]'" == "centered"
    assert "`: char _age_c[fvgen_term]'" == "c.age"
    assert "`: char _ageXbmi[fvgen_role]'" == "interaction"
}
if _rc == 0 {
    display as result "  PASS: centered copies tagged role=centered"
    local ++pass_count
}
else {
    display as error "  FAIL: centered char (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**# 3. drop removes exactly the generated vars; originals survive; returns
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm##c.age
    local gen "`r(genvars)'"
    local ng : word count `gen'
    fvgen, drop
    assert r(k_dropped) == `ng'
    local dropped "`r(dropped)'"
    * every generated var is gone
    foreach v of local gen {
        capture confirm variable `v'
        assert _rc != 0
    }
    * r(dropped) lists exactly those names (set compare; drop order may differ)
    local _extra : list gen - dropped
    local _miss  : list dropped - gen
    assert "`_extra'`_miss'" == ""
    * pass-through originals untouched
    confirm variable age
    confirm variable arm
}
if _rc == 0 {
    display as result "  PASS: drop removes genvars, keeps originals, returns"
    local ++pass_count
}
else {
    display as error "  FAIL: drop teardown (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**# 4. drop is idempotent: a second drop finds nothing
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.grp##c.age
    fvgen, drop
    fvgen, drop
    assert r(k_dropped) == 0
    assert "`r(dropped)'" == ""
}
if _rc == 0 {
    display as result "  PASS: drop is idempotent (second drop = 0)"
    local ++pass_count
}
else {
    display as error "  FAIL: drop idempotent (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**# 5. drop also clears centered copies (incl. absorbed under simple+center)
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm##c.age, simple(arm) center
    * _age_c is a created helper (absorbed), still tagged + dropped
    confirm variable _age_c
    fvgen, drop
    capture confirm variable _age_c
    assert _rc != 0
    capture confirm variable _armXage_0
    assert _rc != 0
    * underlying age survives
    confirm variable age
}
if _rc == 0 {
    display as result "  PASS: drop clears absorbed centered copies"
    local ++pass_count
}
else {
    display as error "  FAIL: drop absorbed centered (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

**# 6. drop error/edge paths: stray varlist -> 198; empty dataset -> 0
local ++test_count
capture noisily {
    _fvgen_make_data
    capture fvgen i.arm, drop
    assert _rc == 198
    * empty dataset: no fvgen vars to find, clean rc=0
    clear
    fvgen, drop
    assert r(k_dropped) == 0
}
if _rc == 0 {
    display as result "  PASS: drop edge paths (stray varlist 198, empty 0)"
    local ++pass_count
}
else {
    display as error "  FAIL: drop edge paths (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

**# 7. drop must be used alone: qualifiers, weights, and other options are errors
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm##c.age
    foreach badcmd in ///
        `"fvgen if arm == 1, drop"' ///
        `"fvgen in 1/10, drop"' ///
        `"fvgen [aweight=age], drop"' ///
        `"fvgen, drop center"' ///
        `"fvgen, drop prefix(z_)"' ///
        `"fvgen, drop replace"' ///
        `"fvgen, drop xsymbol(x)"' ///
        `"fvgen, drop ref(arm 1)"' ///
        `"fvgen, drop simple(arm)"' ///
        `"fvgen, drop alllevels"' {
        capture `badcmd'
        assert _rc == 198
    }
    * A clean drop still works afterwards and removes the generated variables.
    fvgen, drop
    assert r(k_dropped) == 2
}
if _rc == 0 {
    display as result "  PASS: drop rejects companion syntax"
    local ++pass_count
}
else {
    display as error "  FAIL: drop companion syntax (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}

**# Summary
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED:`failed_tests'"
    display "RESULT: test_provenance tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_provenance tests=`test_count' pass=`pass_count' fail=`fail_count'"
