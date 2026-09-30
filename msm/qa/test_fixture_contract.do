* test_fixture_contract.do -- canonical F/U fixture adoption (2026-09-30)
* Author: Timothy P Copeland, Karolinska Institutet
* guard: dup_key/gap/prefix refusal fingerprints are red on pre-fix 1e593bb7; other cells are catalog adoption.
version 16.0
clear all
set more off
set varabbrev off
set processors 1
capture log close _all
local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_state.do"
local test_count 0
local pass_count 0
local fail_count 0


**# F: preparation and weighting preserve caller order, settings and foreign estimates
local ++test_count
capture noisily {
    qa_fx_a3_seq, clear n(1600) seed(9101)
    sort id, stable
    gen long fx_row = _n
    quietly regress y l_t l0
    set varabbrev on
    local fx_sorted : sortedby
    local fx_rng `"`c(rngstate)'"'
    local fx_cmdline `"`e(cmdline)'"'
    tempname fx_b fx_v
    matrix `fx_b' = e(b)
    matrix `fx_v' = e(V)
    gen byte fx_sample = e(sample)
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    assert r(N) == _N & r(n_ids) == 1600
    assert fx_row == _n
    assert "`e(cmd)'" == "regress"
    assert c(varabbrev) == "on"
    local fx_after_sorted : sortedby
    assert `"`fx_after_sorted'"' == `"`fx_sorted'"'
    assert `"`c(rngstate)'"' == `"`fx_rng'"'
    assert `"`e(cmdline)'"' == `"`fx_cmdline'"'
    assert mreldif(`fx_b', e(b)) == 0 & mreldif(`fx_v', e(V)) == 0
    assert fx_sample == e(sample)
    assert `"`: char _dta[_msm_id]'"' == "id"
    assert `"`: char _dta[_msm_period]'"' == "period"
    assert `"`: char _dta[_msm_prepared]'"' == "1"
    quietly msm_weight, treat_d_cov(l_t l0) nolog
    assert !missing(r(ess)) & r(ess) > 1
    local fx_weight_sorted : sortedby
    assert `"`fx_weight_sorted'"' == `"`fx_sorted'"'
    assert fx_row == _n & fx_sample == e(sample)
    assert `"`c(rngstate)'"' == `"`fx_rng'"'
    assert `"`e(cmdline)'"' == `"`fx_cmdline'"'
    assert mreldif(`fx_b', e(b)) == 0 & mreldif(`fx_v', e(V)) == 0
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: F: preparation and weighting preserve caller order, settings and foreign estimates"
}
else {
    local ++fail_count
    display as error "FAIL: F: preparation and weighting preserve caller order, settings and foreign estimates (rc=`=_rc')"
}

**# U: preparation and weighting preserve caller order, settings and foreign estimates
local ++test_count
capture noisily {
    * expect: INVARIANT
    qa_fx_a3_seq, clear n(1600) seed(9101) perturb(unsorted)
    gen long fx_row = _n
    quietly regress y l_t l0
    set varabbrev on
    local fx_sorted : sortedby
    local fx_rng `"`c(rngstate)'"'
    local fx_cmdline `"`e(cmdline)'"'
    tempname fx_b fx_v
    matrix `fx_b' = e(b)
    matrix `fx_v' = e(V)
    gen byte fx_sample = e(sample)
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    assert r(N) == _N & r(n_ids) == 1600
    assert fx_row == _n
    assert "`e(cmd)'" == "regress"
    assert c(varabbrev) == "on"
    local fx_after_sorted : sortedby
    assert `"`fx_after_sorted'"' == `"`fx_sorted'"'
    assert `"`c(rngstate)'"' == `"`fx_rng'"'
    assert `"`e(cmdline)'"' == `"`fx_cmdline'"'
    assert mreldif(`fx_b', e(b)) == 0 & mreldif(`fx_v', e(V)) == 0
    assert fx_sample == e(sample)
    assert `"`: char _dta[_msm_id]'"' == "id"
    assert `"`: char _dta[_msm_period]'"' == "period"
    assert `"`: char _dta[_msm_prepared]'"' == "1"
    quietly msm_weight, treat_d_cov(l_t l0) nolog
    assert !missing(r(ess)) & r(ess) > 1
    local fx_weight_sorted : sortedby
    assert `"`fx_weight_sorted'"' == `"`fx_sorted'"'
    assert fx_row == _n & fx_sample == e(sample)
    assert `"`c(rngstate)'"' == `"`fx_rng'"'
    assert `"`e(cmdline)'"' == `"`fx_cmdline'"'
    assert mreldif(`fx_b', e(b)) == 0 & mreldif(`fx_v', e(V)) == 0
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: preparation and weighting preserve caller order, settings and foreign estimates"
}
else {
    local ++fail_count
    display as error "FAIL: U: preparation and weighting preserve caller order, settings and foreign estimates (rc=`=_rc')"
}

**# F: exact preparation population and weight diagnostics
local ++test_count
capture noisily {
    qa_fx_a3_seq, clear n(1600) seed(9101)
    tempname rows events
    scalar `rows' = r(N)
    scalar `events' = r(n_events)
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    assert r(N) == `rows' & r(n_ids) == 1600 & r(n_events) == `events'
    quietly msm_validate
    assert r(n_errors) == 0
    quietly msm_weight, treat_d_cov(l_t l0) nolog
    * ESS from direct double-precision sums, not a package marker.
    quietly summarize _msm_weight, meanonly
    tempname sw sw2 truthess
    scalar `sw' = r(sum)
    gen double fx_w2 = _msm_weight^2
    quietly summarize fx_w2, meanonly
    scalar `sw2' = r(sum)
    scalar `truthess' = `sw'^2/`sw2'
    quietly msm_diagnose
    assert !missing(r(ess), `truthess') & reldif(r(ess), `truthess') < 1e-10
    quietly msm_fit, model(logistic) period_spec(cubic) nolog
    assert e(N) == `rows' & e(msm_n_clusters) == 1600
    quietly msm_predict, times(3) difference samples(20) seed(9122)
    assert r(n_ref) == 1600
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: F: exact preparation population and weight diagnostics"
}
else {
    local ++fail_count
    display as error "FAIL: F: exact preparation population and weight diagnostics (rc=`=_rc')"
}

**# U: shuffled panel preserves coefficients and point predictions
local ++test_count
capture noisily {
    tempname b0 b1 p0 p1
    qa_fx_a3_seq, clear n(1600) seed(9101)
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    quietly msm_weight, treat_d_cov(l_t l0) nolog
    quietly msm_fit, model(logistic) period_spec(cubic) nolog
    matrix `b0' = e(b)
    quietly msm_predict, times(1 3) difference samples(20) seed(9122)
    matrix `p0' = r(predictions)
    * expect: INVARIANT
    qa_fx_a3_seq, clear n(1600) seed(9101) perturb(unsorted)
    assert "`r(perturb_applied)'" == "unsorted"
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    quietly msm_weight, treat_d_cov(l_t l0) nolog
    quietly msm_fit, model(logistic) period_spec(cubic) nolog
    matrix `b1' = e(b)
    quietly msm_predict, times(1 3) difference samples(20) seed(9122)
    matrix `p1' = r(predictions)
    assert !missing(mreldif(`b0', `b1')) & mreldif(`b0', `b1') < 1e-10
    * Point estimates are independent of coefficient-draw RNG; CI draw order is separate.
    assert !missing(`p0'[1,2], `p1'[1,2], `p0'[2,5], `p1'[2,5])
    assert reldif(`p0'[1,2], `p1'[1,2]) < 1e-10
    assert reldif(`p0'[2,5], `p1'[2,5]) < 1e-10
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: shuffled panel preserves coefficients and point predictions"
}
else {
    local ++fail_count
    display as error "FAIL: U: shuffled panel preserves coefficients and point predictions (rc=`=_rc')"
}

**# U: duplicate panel key is refused without caller mutation
local ++test_count
capture noisily {
    qa_fx_a3_seq, clear n(1600) seed(9101)
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    assert r(n_ids) == 1600
    * expect: REFUSED
    qa_fx_a3_seq, clear n(1600) seed(9101) perturb(dup_key)
    gen long fx_tie_row = _n
    quietly regress y l0 l_t
    tempfile msg
    tempname lh fh
    capture log close _all
    log using "`msg'", text replace name(`lh') nomsg
    qa_state_snapshot, tag(fxdup)
    capture noisily msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    local rc = _rc
    assert `rc' == 198
    qa_state_compare, tag(fxdup)
    log close `lh'
    file open `fh' using "`msg'", read text
    file read `fh' line
    local cause 0
    while r(eof) == 0 {
        if strpos("`line'", "duplicate (id, period)") local cause 1
        file read `fh' line
    }
    file close `fh'
    assert `cause' == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: duplicate panel key is refused without caller mutation"
}
else {
    local ++fail_count
    display as error "FAIL: U: duplicate panel key is refused without caller mutation (rc=`=_rc')"
}

**# U: initially unsorted duplicate key is refused with tied-row order intact
local ++test_count
capture noisily {
    qa_fx_a3_seq, clear n(1600) seed(9101)
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    assert r(n_ids) == 1600
    * expect: REFUSED
    qa_fx_a3_seq, clear n(1600) seed(9101) perturb(dup_key unsorted)
    gen long fx_tie_row = _n
    quietly regress y l0 l_t
    tempfile msg
    tempname lh fh
    capture log close _all
    log using "`msg'", text replace name(`lh') nomsg
    qa_state_snapshot, tag(fxdupunsorted)
    capture noisily msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    local rc = _rc
    assert `rc' == 198
    qa_state_compare, tag(fxdupunsorted)
    log close `lh'
    file open `fh' using "`msg'", read text
    file read `fh' line
    local cause 0
    while r(eof) == 0 {
        if strpos("`line'", "duplicate (id, period)") local cause 1
        file read `fh' line
    }
    file close `fh'
    assert `cause' == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: initially unsorted duplicate key is refused with tied-row order intact"
}
else {
    local ++fail_count
    display as error "FAIL: U: initially unsorted duplicate key is refused with tied-row order intact (rc=`=_rc')"
}

**# U: gapped decision history is refused atomically
local ++test_count
capture noisily {
    qa_fx_a3_seq, clear n(1600) seed(9101)
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    quietly msm_weight, treat_d_cov(l_t l0) nolog
    assert !missing(r(ess)) & r(ess) > 1
    * expect: REFUSED
    qa_fx_a3_seq, clear n(1600) seed(9101) perturb(gap)
    assert r(perturb_n_gap) > 0 & !missing(r(perturb_n_gap))
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    quietly regress y l0 l_t
    tempfile msg
    tempname lh fh
    capture log close _all
    log using "`msg'", text replace name(`lh') nomsg
    qa_state_snapshot, tag(fxgap)
    capture noisily msm_weight, treat_d_cov(l_t l0) nolog
    local rc = _rc
    assert `rc' == 459
    qa_state_compare, tag(fxgap)
    log close `lh'
    file open `fh' using "`msg'", read text
    file read `fh' line
    local cause 0
    while r(eof) == 0 {
        if strpos("`line'", "non-consecutive (gapped)") local cause 1
        file read `fh' line
    }
    file close `fh'
    assert `cause' == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: gapped decision history is refused atomically"
}
else {
    local ++fail_count
    display as error "FAIL: U: gapped decision history is refused atomically (rc=`=_rc')"
}

**# U: initially unsorted gapped history is refused atomically
local ++test_count
capture noisily {
    qa_fx_a3_seq, clear n(1600) seed(9101)
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    quietly msm_weight, treat_d_cov(l_t l0) nolog
    assert !missing(r(ess)) & r(ess) > 1
    * expect: REFUSED
    qa_fx_a3_seq, clear n(1600) seed(9101) perturb(gap unsorted)
    assert r(perturb_n_gap) > 0 & !missing(r(perturb_n_gap))
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    quietly regress y l0 l_t
    tempfile msg
    tempname lh fh
    capture log close _all
    log using "`msg'", text replace name(`lh') nomsg
    qa_state_snapshot, tag(fxgapunsorted)
    capture noisily msm_weight, treat_d_cov(l_t l0) nolog
    local rc = _rc
    assert `rc' == 459
    qa_state_compare, tag(fxgapunsorted)
    log close `lh'
    file open `fh' using "`msg'", read text
    file read `fh' line
    local cause 0
    while r(eof) == 0 {
        if strpos("`line'", "non-consecutive (gapped)") local cause 1
        file read `fh' line
    }
    file close `fh'
    assert `cause' == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: initially unsorted gapped history is refused atomically"
}
else {
    local ++fail_count
    display as error "FAIL: U: initially unsorted gapped history is refused atomically (rc=`=_rc')"
}

**# U: singleton clusters retain exact estimation population
local ++test_count
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear n(1600) seed(9101) perturb(singleton_clusters)
    assert cl == id
    tempname rows
    scalar `rows' = r(N)
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    quietly msm_weight, treat_d_cov(l_t l0) nolog
    quietly msm_fit, model(logistic) period_spec(cubic) cluster(cl) nolog
    assert e(N) == `rows' & e(msm_n_clusters) == 1600
    assert e(msm_n_dropped) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: singleton clusters retain exact estimation population"
}
else {
    local ++fail_count
    display as error "FAIL: U: singleton clusters retain exact estimation population (rc=`=_rc')"
}

**# U: codes_multidigit keeps correctly mapped factor indicators invariant
local ++test_count
capture noisily {
    tempname b0 b1
    qa_fx_a3_seq, clear n(1600) seed(9101)
    gen byte fx_c2 = xcat == 2
    gen byte fx_c3 = xcat == 3
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0 fx_c2 fx_c3)
    quietly msm_weight, treat_d_cov(l_t l0 fx_c2 fx_c3) nolog
    quietly msm_fit, model(logistic) period_spec(cubic) nolog
    matrix `b0' = e(b)
    * expect: INVARIANT
    qa_fx_a3_seq, clear n(1600) seed(9101) perturb(codes_multidigit)
    gen byte fx_c2 = xcat == 11
    gen byte fx_c3 = xcat == 111
    assert inlist(xcat, 1, 11, 111)
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0 fx_c2 fx_c3)
    quietly msm_weight, treat_d_cov(l_t l0 fx_c2 fx_c3) nolog
    quietly msm_fit, model(logistic) period_spec(cubic) nolog
    matrix `b1' = e(b)
    assert !missing(mreldif(`b0', `b1')) & mreldif(`b0', `b1') < 1e-10
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: codes_multidigit keeps correctly mapped factor indicators invariant"
}
else {
    local ++fail_count
    display as error "FAIL: U: codes_multidigit keeps correctly mapped factor indicators invariant (rc=`=_rc')"
}

**# U: codes_sparse keeps correctly mapped factor indicators invariant
local ++test_count
capture noisily {
    tempname b0 b1
    qa_fx_a3_seq, clear n(1600) seed(9101)
    gen byte fx_c2 = xcat == 2
    gen byte fx_c3 = xcat == 3
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0 fx_c2 fx_c3)
    quietly msm_weight, treat_d_cov(l_t l0 fx_c2 fx_c3) nolog
    quietly msm_fit, model(logistic) period_spec(cubic) nolog
    matrix `b0' = e(b)
    * expect: INVARIANT
    qa_fx_a3_seq, clear n(1600) seed(9101) perturb(codes_sparse)
    gen byte fx_c2 = xcat == 5
    gen byte fx_c3 = xcat == 17
    assert inlist(xcat, 1, 5, 17)
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0 fx_c2 fx_c3)
    quietly msm_weight, treat_d_cov(l_t l0 fx_c2 fx_c3) nolog
    quietly msm_fit, model(logistic) period_spec(cubic) nolog
    matrix `b1' = e(b)
    assert !missing(mreldif(`b0', `b1')) & mreldif(`b0', `b1') < 1e-10
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: codes_sparse keeps correctly mapped factor indicators invariant"
}
else {
    local ++fail_count
    display as error "FAIL: U: codes_sparse keeps correctly mapped factor indicators invariant (rc=`=_rc')"
}

**# U: reserved output collision is refused without deleting user data
local ++test_count
capture noisily {
    qa_fx_a3_seq, clear n(1600) seed(9101)
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    quietly msm_weight, treat_d_cov(l_t l0) nolog
    assert !missing(r(ess)) & r(ess) > 1
    * expect: REFUSED
    qa_fx_a3_seq, clear n(1600) seed(9101) perturb(prefix_collision) collide(_msm_weight)
    assert _msm_weight == 999
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    quietly regress y l0 l_t
    tempfile msg
    tempname lh fh
    capture log close _all
    log using "`msg'", text replace name(`lh') nomsg
    qa_state_snapshot, tag(fxname)
    capture noisily msm_weight, treat_d_cov(l_t l0) nolog
    local rc = _rc
    assert `rc' == 110
    qa_state_compare, tag(fxname)
    log close `lh'
    file open `fh' using "`msg'", read text
    file read `fh' line
    local cause 0
    while r(eof) == 0 {
        if strpos("`line'", "reserved MSM variable name(s) already in use") local cause 1
        file read `fh' line
    }
    file close `fh'
    assert `cause' == 1
    assert _msm_weight == 999
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: reserved output collision is refused without deleting user data"
}
else {
    local ++fail_count
    display as error "FAIL: U: reserved output collision is refused without deleting user data (rc=`=_rc')"
}

**# U: initially unsorted reserved output collision preserves caller state
local ++test_count
capture noisily {
    qa_fx_a3_seq, clear n(1600) seed(9101)
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    quietly msm_weight, treat_d_cov(l_t l0) nolog
    assert !missing(r(ess)) & r(ess) > 1
    * expect: REFUSED
    qa_fx_a3_seq, clear n(1600) seed(9101) perturb(prefix_collision unsorted) collide(_msm_weight)
    assert _msm_weight == 999
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    quietly regress y l0 l_t
    tempfile msg
    tempname lh fh
    capture log close _all
    log using "`msg'", text replace name(`lh') nomsg
    qa_state_snapshot, tag(fxnameunsorted)
    capture noisily msm_weight, treat_d_cov(l_t l0) nolog
    local rc = _rc
    assert `rc' == 110
    qa_state_compare, tag(fxnameunsorted)
    log close `lh'
    file open `fh' using "`msg'", read text
    file read `fh' line
    local cause 0
    while r(eof) == 0 {
        if strpos("`line'", "reserved MSM variable name(s) already in use") local cause 1
        file read `fh' line
    }
    file close `fh'
    assert `cause' == 1
    assert _msm_weight == 999
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: initially unsorted reserved output collision preserves caller state"
}
else {
    local ++fail_count
    display as error "FAIL: U: initially unsorted reserved output collision preserves caller state (rc=`=_rc')"
}

do "`qa_dir'/_record_qa_result.do" test_fixture_contract `test_count' `pass_count' `fail_count' 0
display as text "RESULT: test_fixture_contract tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1
