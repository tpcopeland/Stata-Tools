* test_refactor_rng_contracts.do -- seeded MC reproducibility contracts
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
        reps(250) seed(12345) dist_se("uniform .8 .9") dist_sp("uniform .9 .99")
    local first = r(corrected)
    local first_mean = r(mean)

    qba_misclass, a(80) b(120) c(200) d(600) seca(.85) spca(.95) ///
        reps(250) seed(12345) dist_se("uniform .8 .9") dist_sp("uniform .9 .99")
    _qba_qa_assert_close `=r(corrected)' `first' 1e-12
    _qba_qa_assert_close `=r(mean)' `first_mean' 1e-12

    qba_misclass, a(80) b(120) c(200) d(600) seca(.85) spca(.95) ///
        reps(250) seed(12346) dist_se("uniform .8 .9") dist_sp("uniform .9 .99")
    assert abs(r(corrected) - `first') > 1e-10 | abs(r(mean) - `first_mean') > 1e-10
}
local rc = _rc

_qba_qa_restore_isolation, origplus("`orig_plus'") ///
    origpersonal("`orig_personal'") plusdir("`plusdir'") ///
    personaldir("`personaldir'") uninstall

if `rc' exit `rc'
display as result "test_refactor_rng_contracts passed"
