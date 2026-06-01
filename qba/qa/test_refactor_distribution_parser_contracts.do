* test_refactor_distribution_parser_contracts.do -- distribution parser contracts
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
    _qba_require_distributions

    _qba_parse_dist, dist("constant .85")
    assert "`r(dtype)'" == "constant"
    assert "`r(params)'" == ".85"

    _qba_parse_dist, dist("uniform .2 .8")
    assert "`r(dtype)'" == "uniform"
    assert "`r(params)'" == ".2 .8"

    _qba_parse_dist, dist("beta 10 3")
    assert "`r(dtype)'" == "beta"

    capture _qba_parse_dist, dist("constant .8 .9")
    assert _rc == 198
    capture _qba_parse_dist, dist("uniform .8 .2")
    assert _rc == 198
    capture _qba_parse_dist, dist("unknown .8")
    assert _rc == 198
}
local rc = _rc

_qba_qa_restore_isolation, origplus("`orig_plus'") ///
    origpersonal("`orig_personal'") plusdir("`plusdir'") ///
    personaldir("`personaldir'") uninstall

if `rc' exit `rc'
display as result "test_refactor_distribution_parser_contracts passed"
