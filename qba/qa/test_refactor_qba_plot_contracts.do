* test_refactor_qba_plot_contracts.do -- branch helper public returns
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
    tempfile mc
    qba_misclass, a(80) b(120) c(200) d(600) seca(.85) spca(.95) ///
        reps(100) seed(51) dist_se("constant .85") dist_sp("constant .95") ///
        saving("`mc'", replace)

    qba_plot, tornado a(80) b(120) c(200) d(600) ///
        param1(se) range1(.7 .95) param2(sp) range2(.8 .99)
    assert "`r(plot_type)'" == "tornado"
    assert "`r(measure)'" == "OR"
    assert "`r(scheme)'" != ""
    assert r(n_missing) >= 0

    qba_plot, distribution using("`mc'") observed(2)
    assert "`r(plot_type)'" == "distribution"
    assert "`r(measure)'" == "OR"
    assert "`r(scheme)'" != ""
    capture confirm scalar r(n_missing)
    assert _rc != 0

    qba_plot, tipping a(80) b(120) c(200) d(600) ///
        param1(se) range1(.7 .95) param2(sp) range2(.8 .99)
    assert "`r(plot_type)'" == "tipping"
    assert "`r(measure)'" == "OR"
    assert "`r(scheme)'" != ""
    assert r(n_missing) >= 0
}
local rc = _rc

_qba_qa_restore_isolation, origplus("`orig_plus'") ///
    origpersonal("`orig_personal'") plusdir("`plusdir'") ///
    personaldir("`personaldir'") uninstall

if `rc' exit `rc'
display as result "test_refactor_qba_plot_contracts passed"
