*! validation_fixture_qa29_fit.do — A3 SEQ operator cells for iivw_fit
*! Author: Timothy P Copeland, Karolinska Institutet
* Each test builds a qa_fx_a3_seq fixture with one operator, adapts it to an
* IIVW visit panel (_qa29_adapt), weights it, and checks the outcome fit
* against an oracle the package does not share: weighted least squares by
* Mata QR, weighted logistic MLE by Newton-Raphson in Mata, weighted means,
* the exact rc plus an unchanged caller fingerprint, or equality with the
* friendly fixture. The oracles condition on the fitted weights; the weights
* themselves are checked in validation_fixture_qa29_weight.do.
version 16.0
clear all
set more off
set varabbrev off
local qa_dir "`c(pwd)'"
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_metamorphic.do"
do "`qa_dir'/_iivw_qa29_oracles.do"

local tests=0
local pass=0
local fail=0

**# F1 separate: a category with no events is declared omitted, the rest exact
local ++tests
capture noisily {
    * Positive control: with events in every category nothing is omitted.
    qa_fx_a3_seq, clear n(400) seed(2929)
    _qa29_adapt
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    quietly iivw_fit y a0 xcat, categorical(xcat) family(binomial) timespec(linear) vce(fixed) nolog
    quietly _ms_omit_info e(b)
    assert r(k_omit) == 0
    * expect: DEGRADED-DECLARED
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(separate)
    _qa29_adapt
    quietly count if xcat == 3 & y == 1
    assert r(N) == 0
    quietly count if xcat != 3
    local keep_n = r(N)
    tempvar idtag
    egen byte `idtag' = tag(id) if xcat != 3
    quietly count if `idtag' == 1
    local keep_ids = r(N)
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    iivw_fit y a0 xcat, categorical(xcat) family(binomial) timespec(linear) vce(fixed) nolog
    assert e(N) == `keep_n'
    quietly count if e(sample) != (xcat != 3)
    assert r(N) == 0
    assert e(iivw_outcome_nclust) == `keep_ids'
    _qa29_irls_oracle y a0 x2 time if xcat != 3, matrix(O) wvar(_iivw_weight) names(a0 _iivw_cat_xcat_2 time _cons)
    _qa29_match_b, oracle(O) tol(1e-6) omitted(_iivw_cat_xcat_3)
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL F1 separate rc=`rc'"
}

**# F2 separate(switch): FIPTIW fit on the never-switching subgroup
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(separate(switch))
    _qa29_adapt
    quietly keep if xcat == 3
    quietly iivw_weight, id(id) time(time) visit_cov(l0) treat(a) treat_cov(l0) maxfu(4) wtype(fiptiw) nolog
    iivw_fit y a, timespec(linear) vce(fixed) nolog
    assert e(N) == _N & "`e(iivw_weighttype)'" == "fiptiw"
    _qa29_wls_oracle y a time, matrix(O) wvar(_iivw_weight)
    _qa29_match_b, oracle(O) tol(1e-9)
    * vce(fixed): the cluster-robust sandwich over ids, by hand.
    _qa29_cluster_V y a time, matrix(OV) cluster(id) wvar(_iivw_weight)
    _qa29_match_V, oracle(OV) tol(1e-9)
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL F2 separate(switch) rc=`rc'"
}

**# F3 separate(censor): censor()-ended weights through a quadratic fit
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(separate(censor))
    _qa29_adapt
    quietly count if xcat == 3 & cend != 4
    assert r(N) == 0
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) censor(cend) nolog
    iivw_fit y a0 x3, timespec(quadratic) vce(fixed) nolog
    tempvar tsq
    generate double `tsq' = time^2
    _qa29_wls_oracle y a0 x3 time `tsq', matrix(O) wvar(_iivw_weight) names(a0 x3 time _iivw_time_sq _cons)
    _qa29_match_b, oracle(O) tol(1e-9)
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL F3 separate(censor) rc=`rc'"
}

**# F4 separate_time: a visit wave with no events is declared omitted
local ++tests
capture noisily {
    qa_fx_a3_seq, clear n(400) seed(2929)
    _qa29_adapt
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    quietly iivw_fit y a0, family(binomial) timespec(categorical) vce(fixed) nolog
    quietly _ms_omit_info e(b)
    assert r(k_omit) == 0
    * expect: DEGRADED-DECLARED
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(separate_time)
    _qa29_adapt
    quietly count if time == 1 & y == 1
    assert r(N) == 0
    quietly count if time != 1
    local keep_n = r(N)
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    iivw_fit y a0, family(binomial) timespec(categorical) vce(fixed) nolog
    assert e(N) == `keep_n'
    quietly count if e(sample) != (time != 1)
    assert r(N) == 0
    tempvar t2 t3
    generate byte `t2' = time == 2
    generate byte `t3' = time == 3
    _qa29_irls_oracle y a0 `t2' `t3' if time != 1, matrix(O) wvar(_iivw_weight) names(a0 _iivw_tcat_2 _iivw_tcat_3 _cons)
    _qa29_match_b, oracle(O) tol(1e-6) omitted(_iivw_tcat_1)
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL F4 separate_time rc=`rc'"
}

**# F5 absorb: the absorbed arm leaves exactly its late interactions unidentified
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(absorb)
    _qa29_adapt
    quietly count if a0 == 1 & time >= 2
    assert r(N) == 0
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    iivw_fit y a0, interaction(a0) timespec(categorical) vce(fixed) nolog
    assert e(N) == _N
    tempvar t1 t2 t3 ix1
    generate byte `t1' = time == 1
    generate byte `t2' = time == 2
    generate byte `t3' = time == 3
    generate byte `ix1' = a0 * (time == 1)
    _qa29_wls_oracle y a0 `t1' `t2' `t3' `ix1', matrix(O) wvar(_iivw_weight) names(a0 _iivw_tcat_1 _iivw_tcat_2 _iivw_tcat_3 _iivw_ix_a0_tcat_1 _cons)
    _qa29_match_b, oracle(O) tol(1e-9) omitted(_iivw_ix_a0_tcat_2 _iivw_ix_a0_tcat_3)
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL F5 absorb rc=`rc'"
}

**# F6 gap: categorical visit waves with a skipped wave
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(gap)
    assert r(perturb_n_gap) > 0 & !missing(r(perturb_n_gap))
    _qa29_adapt
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) lagvars(l_t) maxfu(4) nolog
    iivw_fit y a0, timespec(categorical) vce(fixed) nolog
    assert e(N) == _N
    tempvar t1 t2 t3
    generate byte `t1' = time == 1
    generate byte `t2' = time == 2
    generate byte `t3' = time == 3
    _qa29_wls_oracle y a0 `t1' `t2' `t3', matrix(O) wvar(_iivw_weight) names(a0 _iivw_tcat_1 _iivw_tcat_2 _iivw_tcat_3 _cons)
    _qa29_match_b, oracle(O) tol(1e-9)
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL F6 gap rc=`rc'"
}

**# F7 dup_key: a duplicated visit cannot be weighted, so the weighted fit is refused
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(dup_key)
    _qa29_adapt
    quietly duplicates report id time
    assert r(unique_value) == r(N) - 1
    capture iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    assert _rc == 198
    estimates clear
    _qa29_ref_open, tag(f7)
    capture noisily iivw_fit y a0, timespec(quadratic) vce(fixed) nolog
    _qa29_ref_close, tag(f7) rc(198) got(`=_rc') cause("data has not been weighted")
    capture confirm variable _iivw_time_sq
    assert _rc == 111
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL F7 dup_key weighted rc=`rc'"
}

**# F7b dup_key: the unweighted route has no visit key, so the duplicate is a row
* Unweighted time() is the outcome-model clock, not a visit key: a binned
* wave legitimately repeats within a subject (validation_fixture_domains.do
* fits floor(time) categories). The duplicated row is therefore one more
* observation, and the fit must be exact OLS on every row including it.
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(dup_key)
    _qa29_adapt
    quietly duplicates report id time
    assert r(unique_value) == r(N) - 1
    iivw_fit y a0, unweighted id(id) time(time) timespec(quadratic) nolog
    assert e(N) == _N
    tempvar tsq
    generate double `tsq' = time^2
    _qa29_wls_oracle y a0 time `tsq', matrix(O) names(a0 time _iivw_time_sq _cons)
    _qa29_match_b, oracle(O) tol(1e-9)
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL F7b dup_key unweighted rc=`rc'"
}

**# F8 single_period: IPTW on one row per subject is a weighted mean contrast
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(single_period)
    _qa29_adapt
    assert _N == 400
    quietly iivw_weight, id(id) time(time) treat(a0) treat_cov(l0 x2 x3) wtype(iptw) nolog
    iivw_fit y a0, timespec(none) vce(fixed) nolog
    assert e(N) == 400
    quietly summarize y [aweight=_iivw_weight] if a0 == 1, meanonly
    local m1 = r(mean)
    quietly summarize y [aweight=_iivw_weight] if a0 == 0, meanonly
    local m0 = r(mean)
    matrix O = (`m1' - `m0', `m0')
    matrix colnames O = a0 _cons
    _qa29_match_b, oracle(O) tol(1e-9)
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL F8 single_period rc=`rc'"
}

**# F9 miss_partial: rows with a missing outcome covariate leave the outcome sample
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(miss_partial)
    _qa29_adapt
    quietly count if !missing(l0)
    local keep_n = r(N)
    assert `keep_n' < _N
    quietly iivw_weight, id(id) time(time) visit_cov(x2 x3) maxfu(4) nolog
    assert !missing(_iivw_weight)
    iivw_fit y a0 l0, timespec(linear) vce(fixed) nolog
    assert e(N) == `keep_n'
    quietly count if e(sample) != !missing(l0)
    assert r(N) == 0
    _qa29_wls_oracle y a0 l0 time if !missing(l0), matrix(O) wvar(_iivw_weight)
    _qa29_match_b, oracle(O) tol(1e-9)
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL F9 miss_partial rc=`rc'"
}

**# F10 codes_multidigit: relabelled codes give the same fit under mapped names
local ++tests
capture noisily {
    tempname b0 V0 c0 b1 V1 c1
    qa_fx_a3_seq, clear n(400) seed(2929)
    _qa29_adapt
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    quietly iivw_fit y a0 xcat, categorical(xcat) timespec(linear) vce(fixed) nolog
    matrix `b0' = e(b)
    matrix `V0' = e(V)
    assert "`: colnames `b0''" == "a0 _iivw_cat_xcat_2 _iivw_cat_xcat_3 time _cons"
    quietly iivw_fit y a0 xcat, categorical(xcat) basecat(3) timespec(linear) vce(fixed) nolog replace
    matrix `c0' = e(b)
    assert "`: colnames `c0''" == "a0 _iivw_cat_xcat_1 _iivw_cat_xcat_2 time _cons"
    * expect: INVARIANT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(codes_multidigit)
    _qa29_adapt
    assert inlist(xcat, 1, 11, 111)
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    iivw_fit y a0 xcat, categorical(xcat) timespec(linear) vce(fixed) nolog
    matrix `b1' = e(b)
    matrix `V1' = e(V)
    assert "`: colnames `b1''" == "a0 _iivw_cat_xcat_11 _iivw_cat_xcat_111 time _cons"
    assert !missing(mreldif(`b0', `b1')) & mreldif(`b0', `b1') < 1e-12
    assert !missing(mreldif(`V0', `V1')) & mreldif(`V0', `V1') < 1e-12
    * basecat() names the 3-digit code exactly, never its 1-digit prefix.
    iivw_fit y a0 xcat, categorical(xcat) basecat(111) timespec(linear) vce(fixed) nolog replace
    matrix `c1' = e(b)
    assert "`: colnames `c1''" == "a0 _iivw_cat_xcat_1 _iivw_cat_xcat_11 time _cons"
    assert !missing(mreldif(`c0', `c1')) & mreldif(`c0', `c1') < 1e-12
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL F10 codes_multidigit rc=`rc'"
}

**# F11 prefix_collision: a user column with a generated name is refused
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(prefix_collision) collide(_iivw_time_sq)
    _qa29_adapt
    assert _iivw_time_sq == 999
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    estimates clear
    _qa29_ref_open, tag(f11)
    capture noisily iivw_fit y a0, timespec(quadratic) vce(fixed) nolog
    _qa29_ref_close, tag(f11) rc(110) got(`=_rc') cause("variable _iivw_time_sq already exists; use the replace option")
    assert _iivw_time_sq == 999
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL F11 prefix_collision rc=`rc'"
}

**# F12 singleton_clusters: cluster(cl) with cl = id is the default fit
local ++tests
capture noisily {
    tempname bd Vd bc Vc
    * Positive control: five ids per cluster gives a different variance.
    qa_fx_a3_seq, clear n(400) seed(2929)
    _qa29_adapt
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    quietly iivw_fit y a0, timespec(linear) vce(fixed) nolog
    matrix `Vd' = e(V)
    quietly iivw_fit y a0, timespec(linear) cluster(cl) vce(fixed) nolog
    assert e(N_clust) == 80
    _qa29_cluster_V y a0 time, matrix(OV) cluster(cl) wvar(_iivw_weight)
    _qa29_match_V, oracle(OV) tol(1e-9)
    matrix `Vc' = e(V)
    * mreldif() is absolute at variance scale; compare the a0 variance ratio.
    assert !missing(`Vc'[1,1], `Vd'[1,1]) & abs(`Vc'[1,1]/`Vd'[1,1] - 1) > .01
    * expect: INVARIANT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(singleton_clusters)
    _qa29_adapt
    assert cl == id
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    iivw_fit y a0, timespec(linear) vce(fixed) nolog
    matrix `bd' = e(b)
    matrix `Vd' = e(V)
    iivw_fit y a0, timespec(linear) cluster(cl) vce(fixed) nolog
    matrix `bc' = e(b)
    matrix `Vc' = e(V)
    _qa29_cluster_V y a0 time, matrix(OV) cluster(cl) wvar(_iivw_weight)
    _qa29_match_V, oracle(OV) tol(1e-9)
    assert e(N_clust) == 400 & "`e(iivw_cluster)'" == "cl"
    assert !missing(mreldif(`bd', `bc')) & mreldif(`bd', `bc') == 0
    assert !missing(mreldif(`Vd', `Vc')) & mreldif(`Vd', `Vc') < 1e-12
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL F12 singleton_clusters rc=`rc'"
}

display "RESULT: validation_fixture_qa29_fit tests=`tests' pass=`pass' fail=`fail' skip=0"
iivw_qa_sandbox_restore
if `fail'>0 exit 1
