* test_refactor_mc_known_answer.do -- constant MC equals simple-mode contracts
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
    qba_misclass, a(80) b(120) c(200) d(600) seca(.85) spca(.95)
    local simple_mis = r(corrected)
    qba_misclass, a(80) b(120) c(200) d(600) seca(.85) spca(.95) ///
        reps(100) seed(21) dist_se("constant .85") dist_sp("constant .95")
    _qba_qa_assert_close `=r(corrected)' `simple_mis' 1e-10
    _qba_qa_assert_close `=r(mean)' `simple_mis' 1e-10
    assert r(sd) < 1e-10

    qba_selection, a(80) b(120) c(200) d(600) sela(.8) selb(.9) selc(.7) seld(.95)
    local simple_sel = r(corrected)
    qba_selection, a(80) b(120) c(200) d(600) sela(.8) selb(.9) ///
        selc(.7) seld(.95) reps(100) seed(22) ///
        dist_sela("constant .8") dist_selb("constant .9") ///
        dist_selc("constant .7") dist_seld("constant .95")
    _qba_qa_assert_close `=r(corrected)' `simple_sel' 1e-10
    _qba_qa_assert_close `=r(mean)' `simple_sel' 1e-10
    assert r(sd) < 1e-10

    qba_confound, estimate(2) p1(.4) p0(.2) rrcd(2)
    local simple_conf = r(corrected)
    qba_confound, estimate(2) p1(.4) p0(.2) rrcd(2) reps(100) seed(23) ///
        dist_p1("constant .4") dist_p0("constant .2") dist_rr("constant 2")
    _qba_qa_assert_close `=r(corrected)' `simple_conf' 1e-10
    _qba_qa_assert_close `=r(mean)' `simple_conf' 1e-10
    assert r(sd) < 1e-10
}
local rc = _rc

_qba_qa_restore_isolation, origplus("`orig_plus'") ///
    origpersonal("`orig_personal'") plusdir("`plusdir'") ///
    personaldir("`personaldir'") uninstall

if `rc' exit `rc'
display as result "test_refactor_mc_known_answer passed"
