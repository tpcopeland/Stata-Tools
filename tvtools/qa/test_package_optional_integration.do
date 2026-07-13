*! test_package_optional_integration.do
*! External-lane contracts for tvweight's optional psdash integration.

clear all
set varabbrev off
version 16.0

capture log close _all
quietly log using "test_package_optional_integration.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"
local tools_dir = substr("`pkg_dir'", 1, strrpos("`pkg_dir'", "/") - 1)
local psdash_dir "`tools_dir'/psdash"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _psdash_on
program define _psdash_on
    args source
    capture confirm file "`source'/psdash.ado"
    if _rc exit 601
    capture ado uninstall psdash
    quietly net install psdash, from("`source'") replace
    discard
end

capture program drop _psdash_off
program define _psdash_off
    capture ado uninstall psdash
    capture program drop psdash
    discard
end

capture program drop _mk_binary
program define _mk_binary
    clear
    set seed 90210
    set obs 4000
    generate double x1 = rnormal()
    generate double x2 = rnormal()
    generate byte a = runiform() < invlogit(0.3 + 0.7*x1 - 0.5*x2)
end

capture program drop _mk_multinomial
program define _mk_multinomial
    clear
    set seed 24680
    set obs 4000
    generate double x1 = rnormal()
    generate double x2 = rnormal()
    generate double u1 = 0.3 + 0.6*x1
    generate double u2 = -0.2 + 0.5*x2
    generate double den = 1 + exp(u1) + exp(u2)
    generate double p1 = exp(u1)/den
    generate double p2 = exp(u2)/den
    generate double draw = runiform()
    generate byte a = cond(draw < p1, 1, cond(draw < p1 + p2, 2, 0))
    drop u1 u2 den p1 p2 draw
end

**# Delegated plotting

local ++test_count
capture noisily {
    _psdash_on "`psdash_dir'"
    _mk_binary
    graph drop _all
    tvweight a, covariates(x1 x2) generate(w) balance loveplot histogram
    graph describe tvw_loveplot
    graph describe tvw_histogram
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' binary"
}

local ++test_count
capture noisily {
    _psdash_on "`psdash_dir'"
    _mk_multinomial
    graph drop _all
    tvweight a, covariates(x1 x2) generate(w) model(mlogit) balance loveplot
    graph describe tvw_loveplot
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' multinomial"
}

**# Dependency-absent behavior

local ++test_count
capture noisily {
    _psdash_off
    _mk_binary
    graph drop _all
    tvweight a, covariates(x1 x2) generate(w) balance loveplot
    matrix B = r(balance)
    assert rowsof(B) == 2 & colsof(B) == 2
    capture graph describe tvw_loveplot
    assert _rc != 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' absent"
}

**# Caller data preservation

local ++test_count
capture noisily {
    _psdash_on "`psdash_dir'"
    _mk_binary
    datasignature set
    tvweight a, covariates(x1 x2) generate(w) balance loveplot
    drop w
    datasignature confirm
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' data"
}

capture _psdash_off

**# Summary

display "RESULT: test_package_optional_integration tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "optional-integration failures:`failed_tests'"
    exit 1
}
