* test_refactor_qba_plot_install_smoke.do -- installed plot helper manifest smoke
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
    foreach f in _qba_plot_validate_cells _qba_plot_tornado ///
        _qba_plot_distribution _qba_plot_tipping {
        findfile `f'.ado
        confirm file "`r(fn)'"
    }

    qba_plot, tornado a(80) b(120) c(200) d(600) ///
        param1(se) range1(.7 .95)
    assert "`r(plot_type)'" == "tornado"

    qba_plot, tipping a(80) b(120) c(200) d(600) ///
        param1(se) range1(.7 .95) param2(sp) range2(.8 .99)
    assert "`r(plot_type)'" == "tipping"
}
local rc = _rc

_qba_qa_restore_isolation, origplus("`orig_plus'") ///
    origpersonal("`orig_personal'") plusdir("`plusdir'") ///
    personaldir("`personaldir'") uninstall

if `rc' exit `rc'
display as result "test_refactor_qba_plot_install_smoke passed"
