* test_refactor_option_abbrev_contract.do
* Option spelling and abbreviation contracts for psdash refactors
* Usage: cd psdash/qa && stata-mp -b do test_refactor_option_abbrev_contract.do

clear all
version 16.0
set more off

capture log close _all
log using "test_refactor_option_abbrev_contract.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"

local test_count = 0
global PSDASH_OPT_PASS_COUNT = 0
global PSDASH_OPT_FAIL_COUNT = 0

capture program drop _option_result
program define _option_result
    args rc
    if `rc' == 0 {
        global PSDASH_OPT_PASS_COUNT = $PSDASH_OPT_PASS_COUNT + 1
        display as result "  PASS"
    }
    else {
        global PSDASH_OPT_FAIL_COUNT = $PSDASH_OPT_FAIL_COUNT + 1
        display as error "  FAIL (rc=`rc')"
    }
end

capture program drop _option_data
program define _option_data
    clear
    set obs 40
    gen byte treat = (_n > 20)
    gen double x1 = rnormal()
    gen double x2 = rnormal() + treat * .25
    gen double ps = cond(treat, .65, .35)
    replace ps = ps + (_n - 20) / 1000
end

local ++test_count
display as text _n "--- O1: balance, noweights aliases nowvar and suppresses adjusted columns ---"
capture noisily {
    _option_data
    psdash balance treat ps, covariates(x1 x2) noweights
    matrix B = r(balance)
    assert colsof(B) == 10
    assert missing(B[1, 8])
    assert "`r(wvar)'" == ""
}
_option_result `=_rc'

local ++test_count
display as text _n "--- O2: shortest documented balance alias now:eights is accepted ---"
capture noisily {
    _option_data
    psdash balance treat ps, covariates(x1 x2) nowe
    matrix B = r(balance)
    assert missing(B[1, 8])
}
_option_result `=_rc'

local ++test_count
display as text _n "--- O3: legacy nowvar spelling remains accepted ---"
capture noisily {
    _option_data
    psdash balance treat ps, covariates(x1 x2) nowvar
    matrix B = r(balance)
    assert missing(B[1, 8])
}
_option_result `=_rc'

display as text _n "RESULT: test_refactor_option_abbrev_contract tests=`test_count' pass=$PSDASH_OPT_PASS_COUNT fail=$PSDASH_OPT_FAIL_COUNT"

_psdash_qa_cleanup
capture log close _all
if $PSDASH_OPT_FAIL_COUNT > 0 exit 9
global PSDASH_OPT_PASS_COUNT
global PSDASH_OPT_FAIL_COUNT
