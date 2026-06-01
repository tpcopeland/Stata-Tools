* test_refactor_distribution_autoload.do -- private loader autoload contract
* Package: qba

clear all
version 16.0

capture do "_qba_qa_common.do"
if _rc {
    do "qa/_qba_qa_common.do"
}

_qba_qa_bootstrap, isolated
local orig_plus `"`r(orig_plus)'"'
local orig_personal `"`r(orig_personal)'"'
local plusdir `"`r(plusdir)'"'
local personaldir `"`r(personaldir)'"'

capture noisily {
    discard
    which _qba_require_distributions
    _qba_require_distributions
    program list _qba_parse_dist
    program list _qba_draw_one
    _qba_parse_dist, dist("trapezoidal .7 .8 .9 1")
    assert "`r(dtype)'" == "trapezoidal"
    assert "`r(params)'" == ".7 .8 .9 1"
    set seed 123
    clear
    set obs 5
    _qba_draw_checked, dist("constant .85") gen(_se) n(5) ///
        invalid(_bad) lower(0) upper(1) loweropen
    assert _bad[1] == 0
    assert _se == .85 in 5
}
local rc = _rc

_qba_qa_restore_isolation, origplus("`orig_plus'") ///
    origpersonal("`orig_personal'") plusdir("`plusdir'") ///
    personaldir("`personaldir'") uninstall

if `rc' exit `rc'
display as result "test_refactor_distribution_autoload passed"
