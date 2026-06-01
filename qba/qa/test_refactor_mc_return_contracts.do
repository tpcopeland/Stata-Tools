* test_refactor_mc_return_contracts.do -- MC summary helper return contracts
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
    qba_misclass, a(80) b(120) c(200) d(600) seca(.85) spca(.95) ///
        reps(100) seed(11) dist_se("constant .85") dist_sp("constant .95")
    foreach s in observed corrected mean sd ci_lower ci_upper reps n_valid {
        assert r(`s') < .
    }
    assert "`r(method)'" == "probabilistic"
    assert "`r(type)'" == "exposure"

    qba_selection, a(80) b(120) c(200) d(600) sela(.8) selb(.9) ///
        selc(.7) seld(.95) reps(100) seed(12) ///
        dist_sela("constant .8") dist_selb("constant .9") ///
        dist_selc("constant .7") dist_seld("constant .95")
    foreach s in observed corrected mean sd ci_lower ci_upper reps n_valid {
        assert r(`s') < .
    }
    assert "`r(method)'" == "probabilistic"

    qba_confound, estimate(2) p1(.4) p0(.2) rrcd(2) reps(100) seed(13) ///
        dist_p1("constant .4") dist_p0("constant .2") dist_rr("constant 2")
    foreach s in observed corrected mean sd ci_lower ci_upper reps n_valid n_draw_invalid {
        assert r(`s') < .
    }
    assert "`r(method)'" == "probabilistic"

    qba_multi, a(80) b(120) c(200) d(600) reps(100) seed(14) ///
        seca(.85) spca(.95) dist_se("constant .85") dist_sp("constant .95") ///
        sela(.8) selb(.9) selc(.7) seld(.95) ///
        dist_sela("constant .8") dist_selb("constant .9") ///
        dist_selc("constant .7") dist_seld("constant .95")
    foreach s in observed corrected mean sd ci_lower ci_upper reps n_valid ///
        n_draw_invalid n_biases {
        assert r(`s') < .
    }
    assert "`r(method)'" == "multi-bias"
}
local rc = _rc

_qba_qa_restore_isolation, origplus("`orig_plus'") ///
    origpersonal("`orig_personal'") plusdir("`plusdir'") ///
    personaldir("`personaldir'") uninstall

if `rc' exit `rc'
display as result "test_refactor_mc_return_contracts passed"
