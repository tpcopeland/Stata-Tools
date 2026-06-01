* test_refactor_qba_plot_sideeffects.do -- graph export failure return gate
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
    local existing "`c(tmpdir)'/qba_refactor_existing_plot.svg"
    capture erase "`existing'"
    graph drop _all
    qba_plot, tornado a(80) b(120) c(200) d(600) ///
        param1(se) range1(.7 .95) saving("`existing'") replace
    assert "`r(plot_type)'" == "tornado"

    capture qba_plot, tornado a(80) b(120) c(200) d(600) ///
        param1(se) range1(.7 .95) saving("`existing'")
    assert _rc == 602
    assert "`r(plot_type)'" == "tornado"
    assert "`r(measure)'" == "OR"
    assert r(n_missing) >= 0
    capture erase "`existing'"
}
local rc = _rc

_qba_qa_restore_isolation, origplus("`orig_plus'") ///
    origpersonal("`orig_personal'") plusdir("`plusdir'") ///
    personaldir("`personaldir'") uninstall

if `rc' exit `rc'
display as result "test_refactor_qba_plot_sideeffects passed"
