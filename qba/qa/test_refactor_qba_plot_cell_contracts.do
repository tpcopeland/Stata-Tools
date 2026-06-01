* test_refactor_qba_plot_cell_contracts.do -- qba_plot cell validation helper
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
    capture qba_plot, tornado a(-1) b(1) c(1) d(1) ///
        param1(se) range1(.7 .95)
    assert _rc == 198

    capture qba_plot, tornado a(.) b(1) c(1) d(1) ///
        param1(se) range1(.7 .95)
    assert _rc == 198

    capture qba_plot, tornado a(0) b(0) c(0) d(0) ///
        param1(se) range1(.7 .95)
    assert _rc == 2000

    capture qba_plot, tipping a(-1) b(1) c(1) d(1) ///
        param1(se) range1(.7 .95) param2(sp) range2(.8 .99)
    assert _rc == 198

    capture qba_plot, tipping a(0) b(0) c(0) d(0) ///
        param1(se) range1(.7 .95) param2(sp) range2(.8 .99)
    assert _rc == 2000
}
local rc = _rc

_qba_qa_restore_isolation, origplus("`orig_plus'") ///
    origpersonal("`orig_personal'") plusdir("`plusdir'") ///
    personaldir("`personaldir'") uninstall

if `rc' exit `rc'
display as result "test_refactor_qba_plot_cell_contracts passed"
