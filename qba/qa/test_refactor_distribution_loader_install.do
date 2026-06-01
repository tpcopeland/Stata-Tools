* test_refactor_distribution_loader_install.do -- installed helper manifest smoke
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
    foreach f in _qba_distributions _qba_require_distributions ///
        _qba_parse_saving _qba_mc_summary _qba_draw_checked ///
        _qba_flag_misclass_pair {
        findfile `f'.ado
        confirm file "`r(fn)'"
    }

    qba_misclass, a(80) b(120) c(200) d(600) seca(.85) spca(.95) ///
        reps(100) seed(101) dist_se("constant .85") dist_sp("constant .95")
    assert r(corrected) < .

    qba_selection, a(80) b(120) c(200) d(600) sela(.8) selb(.9) ///
        selc(.7) seld(.95) reps(100) seed(102) ///
        dist_sela("constant .8") dist_selb("constant .9") ///
        dist_selc("constant .7") dist_seld("constant .95")
    assert r(corrected) < .
}
local rc = _rc

_qba_qa_restore_isolation, origplus("`orig_plus'") ///
    origpersonal("`orig_personal'") plusdir("`plusdir'") ///
    personaldir("`personaldir'") uninstall

if `rc' exit `rc'
display as result "test_refactor_distribution_loader_install passed"
