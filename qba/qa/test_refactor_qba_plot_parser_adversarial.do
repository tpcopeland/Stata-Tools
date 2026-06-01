* test_refactor_qba_plot_parser_adversarial.do -- qba_plot parser passthrough cases
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
        reps(100) seed(61) saving("`mc'", replace)

    qba_plot, distribution using("`mc'") observed(2) ///
        name(qba_refactor_parser, replace) title("Parser, comma title") ///
        note("note with comma, preserved")
    assert "`r(plot_type)'" == "distribution"

    graph drop qba_refactor_parser

    capture qba_plot, tornado a(80) b(120) c(200) d(600) ///
        param1(se) range1(.7 .95) param2(seca) range2(.75 .9)
    assert _rc == 198

    capture qba_plot, tipping a(80) b(120) c(200) d(600) ///
        param1(se) range1(.7 .95) param2(sela) range2(.7 .95)
    assert _rc == 198
}
local rc = _rc

_qba_qa_restore_isolation, origplus("`orig_plus'") ///
    origpersonal("`orig_personal'") plusdir("`plusdir'") ///
    personaldir("`personaldir'") uninstall

if `rc' exit `rc'
display as result "test_refactor_qba_plot_parser_adversarial passed"
