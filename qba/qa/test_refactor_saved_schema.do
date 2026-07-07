* test_refactor_saved_schema.do -- saved Monte Carlo dataset schemas
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
    tempfile mis sel conf multi

    qba_misclass, a(80) b(120) c(200) d(600) seca(.85) spca(.95) ///
        reps(100) seed(41) dist_se("constant .85") dist_sp("constant .95") ///
        saving("`mis'", replace)
    use "`mis'", clear
    foreach v in se sp a_corr b_corr c_corr d_corr corrected_or {
        confirm variable `v'
    }
    assert _N == 100

    qba_selection, a(80) b(120) c(200) d(600) sela(.8) selb(.9) ///
        selc(.7) seld(.95) reps(100) seed(42) ///
        dist_sela("constant .8") dist_selb("constant .9") ///
        dist_selc("constant .7") dist_seld("constant .95") saving("`sel'", replace)
    use "`sel'", clear
    foreach v in sel_a sel_b sel_c sel_d a_corr b_corr c_corr d_corr corrected_or {
        confirm variable `v'
    }
    assert _N == 100

    qba_confound, estimate(2) p1(.4) p0(.2) rrcd(2) reps(100) seed(43) ///
        dist_p1("constant .4") dist_p0("constant .2") dist_rr("constant 2") ///
        saving("`conf'", replace)
    use "`conf'", clear
    foreach v in p1 p0 rr_confounder bias_factor corrected_rr {
        confirm variable `v'
    }
    assert _N == 100

    qba_multi, a(80) b(120) c(200) d(600) reps(100) seed(44) ///
        seca(.85) spca(.95) dist_se("constant .85") dist_sp("constant .95") ///
        saving("`multi'", replace)
    use "`multi'", clear
    foreach v in a_corr b_corr c_corr d_corr corrected_or {
        confirm variable `v'
    }
    assert _N == 100
}
local rc = _rc

_qba_qa_restore_isolation, origplus("`orig_plus'") ///
    origpersonal("`orig_personal'") plusdir("`plusdir'") ///
    personaldir("`personaldir'") uninstall

if `rc' exit `rc'
display as result "test_refactor_saved_schema passed"
