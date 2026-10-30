*! validation_fixture_qa29_bspool.do — A3 SEQ operator cells for iivw_bspool
*! Author: Timothy P Copeland, Karolinska Institutet
* iivw_bspool reads shard files, so each cell perturbs the upstream data:
* build a qa_fx_a3_seq fixture with one operator, adapt it (_qa29_adapt),
* weight it, save two fixed-weight bootstrap shards on distinct RNG
* substreams, and pool them. The oracle (_qa29_pool_oracle) restacks the
* saved draws itself: e(b) must be the anchor fit, e(V) the centered outer
* product of all 40 draws, e(iivw_ci) the Wald interval that V implies. An
* INVARIANT cell pools the friendly and the perturbed shards and requires
* identical results. Operators refused upstream cannot produce a shard and
* are listed in the round report instead.
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

tempfile stub
local W "`stub'_q29b"
capture mkdir "`W'"
confirm file "`W'/."
global Q29B_W "`W'"

* Two shards of one fit on RNG substreams 1 and 2; the anchor estimates are
* restored and left in matrix Q29B_A.
capture program drop _q29b_shards
program define _q29b_shards
    version 16.0
    syntax , FIT(string asis) STEM(name) [CLUSTER(string)]
    local cl ""
    if "`cluster'" != "" local cl "cluster(`cluster')"
    forvalues s = 1/2 {
        quietly iivw_fit `fit' `cl' vce(bootstrap, reps(20) seed(2911) fixedweights) rngstream(`s') saving("$Q29B_W/`stem'_`s'", replace) nolog replace
        if `s' == 1 {
            estimates store q29b_anchor
            matrix Q29B_A = e(b)
        }
    }
    estimates restore q29b_anchor
    estimates drop q29b_anchor
end

local tests=0
local pass=0
local fail=0

**# B1 separate: the omitted category pools as a declared zero column
local ++tests
capture noisily {
    * expect: DEGRADED-DECLARED
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(separate)
    _qa29_adapt
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    _q29b_shards, fit(y a0 xcat, categorical(xcat) family(binomial) timespec(linear)) stem(b1)
    iivw_bspool using "$Q29B_W/b1_1.dta $Q29B_W/b1_2.dta", citype(wald) notable
    _qa29_pool_oracle, files($Q29B_W/b1_1.dta $Q29B_W/b1_2.dta) anchor(Q29B_A) reps(40)
    assert e(iivw_bs_shards) == 2
    quietly _ms_omit_info e(b)
    tempname om V
    matrix `om' = r(omit)
    local j = colnumb(e(b), "o._iivw_cat_xcat_3")
    assert !missing(`j') & `om'[1, `j'] == 1
    matrix `V' = e(V)
    forvalues k = 1/`=colsof(`V')' {
        assert `V'[`j', `k'] == 0 & `V'[`k', `j'] == 0
    }
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL B1 separate rc=`rc'"
}

**# B2 separate(switch): FIPTIW shards on the never-switching subgroup
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(separate(switch))
    _qa29_adapt
    quietly keep if xcat == 3
    quietly iivw_weight, id(id) time(time) visit_cov(l0) treat(a) treat_cov(l0) maxfu(4) wtype(fiptiw) nolog
    _q29b_shards, fit(y a, timespec(linear)) stem(b2)
    iivw_bspool using "$Q29B_W/b2_1.dta $Q29B_W/b2_2.dta", citype(wald) notable
    _qa29_pool_oracle, files($Q29B_W/b2_1.dta $Q29B_W/b2_2.dta) anchor(Q29B_A) reps(40)
    assert e(iivw_bs_shards) == 2 & e(N) == _N
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL B2 separate(switch) rc=`rc'"
}

**# B3 separate(censor): shards of a censor()-weighted fit
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(separate(censor))
    _qa29_adapt
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) censor(cend) nolog
    _q29b_shards, fit(y a0 x3, timespec(quadratic)) stem(b3)
    iivw_bspool using "$Q29B_W/b3_1.dta $Q29B_W/b3_2.dta", citype(wald) notable
    _qa29_pool_oracle, files($Q29B_W/b3_1.dta $Q29B_W/b3_2.dta) anchor(Q29B_A) reps(40)
    assert e(iivw_bs_shards) == 2 & e(N) == _N
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL B3 separate(censor) rc=`rc'"
}

**# B4 separate_time: the omitted visit wave pools as a declared zero column
local ++tests
capture noisily {
    * expect: DEGRADED-DECLARED
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(separate_time)
    _qa29_adapt
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    _q29b_shards, fit(y a0, family(binomial) timespec(categorical)) stem(b4)
    iivw_bspool using "$Q29B_W/b4_1.dta $Q29B_W/b4_2.dta", citype(wald) notable
    _qa29_pool_oracle, files($Q29B_W/b4_1.dta $Q29B_W/b4_2.dta) anchor(Q29B_A) reps(40)
    local j = colnumb(e(b), "o._iivw_tcat_1")
    assert !missing(`j')
    tempname V
    matrix `V' = e(V)
    assert `V'[`j', `j'] == 0
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL B4 separate_time rc=`rc'"
}

**# B5 absorb: shards with design-omitted interaction columns
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(absorb)
    _qa29_adapt
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    _q29b_shards, fit(y a0, interaction(a0) timespec(categorical)) stem(b5)
    iivw_bspool using "$Q29B_W/b5_1.dta $Q29B_W/b5_2.dta", citype(wald) notable
    _qa29_pool_oracle, files($Q29B_W/b5_1.dta $Q29B_W/b5_2.dta) anchor(Q29B_A) reps(40)
    assert !missing(colnumb(e(b), "o._iivw_ix_a0_tcat_2"))
    assert !missing(colnumb(e(b), "o._iivw_ix_a0_tcat_3"))
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL B5 absorb rc=`rc'"
}

**# B6 gap: shards of a fit on a panel with skipped visits
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(gap)
    assert r(perturb_n_gap) > 0 & !missing(r(perturb_n_gap))
    _qa29_adapt
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) lagvars(l_t) maxfu(4) nolog
    _q29b_shards, fit(y a0, timespec(categorical)) stem(b6)
    iivw_bspool using "$Q29B_W/b6_1.dta $Q29B_W/b6_2.dta", citype(wald) notable
    _qa29_pool_oracle, files($Q29B_W/b6_1.dta $Q29B_W/b6_2.dta) anchor(Q29B_A) reps(40)
    assert e(N) == _N
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL B6 gap rc=`rc'"
}

**# B7 single_period: IPTW shards on one row per subject
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(single_period)
    _qa29_adapt
    quietly iivw_weight, id(id) time(time) treat(a0) treat_cov(l0 x2 x3) wtype(iptw) nolog
    _q29b_shards, fit(y a0, timespec(none)) stem(b7)
    iivw_bspool using "$Q29B_W/b7_1.dta $Q29B_W/b7_2.dta", citype(wald) notable
    _qa29_pool_oracle, files($Q29B_W/b7_1.dta $Q29B_W/b7_2.dta) anchor(Q29B_A) reps(40)
    assert e(N) == 400
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL B7 single_period rc=`rc'"
}

**# B8 miss_irrelevant: missing values outside the analysis leave the pool unchanged
local ++tests
capture noisily {
    tempname b0 V0 C0
    qa_fx_a3_seq, clear n(400) seed(2929)
    _qa29_adapt
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    _q29b_shards, fit(y a0, timespec(linear)) stem(b8f)
    quietly iivw_bspool using "$Q29B_W/b8f_1.dta $Q29B_W/b8f_2.dta", citype(wald) notable
    matrix `b0' = e(b)
    matrix `V0' = e(V)
    matrix `C0' = e(iivw_ci)
    * expect: INVARIANT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(miss_irrelevant)
    assert r(perturb_n_miss_irrelevant) > 0 & !missing(r(perturb_n_miss_irrelevant))
    _qa29_adapt
    assert !missing(a0)
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    _q29b_shards, fit(y a0, timespec(linear)) stem(b8u)
    iivw_bspool using "$Q29B_W/b8u_1.dta $Q29B_W/b8u_2.dta", citype(wald) notable
    _qa29_pool_oracle, files($Q29B_W/b8u_1.dta $Q29B_W/b8u_2.dta) anchor(Q29B_A) reps(40)
    assert !missing(mreldif(e(b), `b0')) & mreldif(e(b), `b0') == 0
    assert !missing(mreldif(e(V), `V0')) & mreldif(e(V), `V0') == 0
    assert !missing(mreldif(e(iivw_ci), `C0')) & mreldif(e(iivw_ci), `C0') == 0
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL B8 miss_irrelevant rc=`rc'"
}

**# B9 miss_partial: shards of a complete-case outcome fit
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(miss_partial)
    _qa29_adapt
    quietly count if !missing(l0)
    local keep_n = r(N)
    assert `keep_n' < _N
    quietly iivw_weight, id(id) time(time) visit_cov(x2 x3) maxfu(4) nolog
    _q29b_shards, fit(y a0 l0, timespec(linear)) stem(b9)
    iivw_bspool using "$Q29B_W/b9_1.dta $Q29B_W/b9_2.dta", citype(wald) notable
    _qa29_pool_oracle, files($Q29B_W/b9_1.dta $Q29B_W/b9_2.dta) anchor(Q29B_A) reps(40)
    assert e(N) == `keep_n'
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL B9 miss_partial rc=`rc'"
}

**# B10 codes_multidigit: relabelled codes pool to the same result under mapped names
local ++tests
capture noisily {
    tempname b0 V0 b1 V1
    qa_fx_a3_seq, clear n(400) seed(2929)
    _qa29_adapt
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    _q29b_shards, fit(y a0 xcat, categorical(xcat) timespec(linear)) stem(b10f)
    quietly iivw_bspool using "$Q29B_W/b10f_1.dta $Q29B_W/b10f_2.dta", citype(wald) notable
    matrix `b0' = e(b)
    matrix `V0' = e(V)
    * expect: INVARIANT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(codes_multidigit)
    _qa29_adapt
    assert inlist(xcat, 1, 11, 111)
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    _q29b_shards, fit(y a0 xcat, categorical(xcat) timespec(linear)) stem(b10u)
    iivw_bspool using "$Q29B_W/b10u_1.dta $Q29B_W/b10u_2.dta", citype(wald) notable
    _qa29_pool_oracle, files($Q29B_W/b10u_1.dta $Q29B_W/b10u_2.dta) anchor(Q29B_A) reps(40)
    matrix `b1' = e(b)
    matrix `V1' = e(V)
    assert "`: colnames `b1''" == "a0 _iivw_cat_xcat_11 _iivw_cat_xcat_111 time _cons"
    assert !missing(mreldif(`b0', `b1')) & mreldif(`b0', `b1') == 0
    assert !missing(mreldif(`V0', `V1')) & mreldif(`V0', `V1') == 0
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL B10 codes_multidigit rc=`rc'"
}

**# B11 singleton_clusters: cluster(cl) with cl = id resamples exactly as id
local ++tests
capture noisily {
    tempname V0 Vf
    * Positive control: five ids per cluster resample as 80 units, so the
    * pooled cluster(cl) variance must differ from the id-resampled one.
    qa_fx_a3_seq, clear n(400) seed(2929)
    _qa29_adapt
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    _q29b_shards, fit(y a0, timespec(linear)) stem(b11fd)
    quietly iivw_bspool using "$Q29B_W/b11fd_1.dta $Q29B_W/b11fd_2.dta", citype(wald) notable
    matrix `Vf' = e(V)
    _q29b_shards, fit(y a0, timespec(linear)) stem(b11fc) cluster(cl)
    quietly iivw_bspool using "$Q29B_W/b11fc_1.dta $Q29B_W/b11fc_2.dta", citype(wald) notable
    _qa29_pool_oracle, files($Q29B_W/b11fc_1.dta $Q29B_W/b11fc_2.dta) anchor(Q29B_A) reps(40)
    tempname Vfc
    matrix `Vfc' = e(V)
    assert !missing(`Vfc'[1,1], `Vf'[1,1]) & abs(`Vfc'[1,1]/`Vf'[1,1] - 1) > .05
    * expect: INVARIANT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(singleton_clusters)
    _qa29_adapt
    assert cl == id
    quietly iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    _q29b_shards, fit(y a0, timespec(linear)) stem(b11d)
    iivw_bspool using "$Q29B_W/b11d_1.dta $Q29B_W/b11d_2.dta", citype(wald) notable
    _qa29_pool_oracle, files($Q29B_W/b11d_1.dta $Q29B_W/b11d_2.dta) anchor(Q29B_A) reps(40)
    matrix `V0' = e(V)
    _q29b_shards, fit(y a0, timespec(linear)) stem(b11c) cluster(cl)
    iivw_bspool using "$Q29B_W/b11c_1.dta $Q29B_W/b11c_2.dta", citype(wald) notable
    _qa29_pool_oracle, files($Q29B_W/b11c_1.dta $Q29B_W/b11c_2.dta) anchor(Q29B_A) reps(40)
    assert !missing(mreldif(e(V), `V0')) & mreldif(e(V), `V0') == 0
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL B11 singleton_clusters rc=`rc'"
}

**# B12 dup_key: unweighted shards keep the duplicated visit as a row
* Unweighted time() is the outcome clock, not a visit key (see F7b of
* validation_fixture_qa29_fit.do), so a duplicated row is resampled with its
* subject; the pool must still be exactly the restacked draws.
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(dup_key)
    _qa29_adapt
    quietly duplicates report id time
    assert r(unique_value) == r(N) - 1
    _q29b_shards, fit(y a0, unweighted id(id) time(time) timespec(linear)) stem(b12)
    iivw_bspool using "$Q29B_W/b12_1.dta $Q29B_W/b12_2.dta", citype(wald) notable
    _qa29_pool_oracle, files($Q29B_W/b12_1.dta $Q29B_W/b12_2.dta) anchor(Q29B_A) reps(40)
    assert e(N) == _N & e(iivw_bs_shards) == 2
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL B12 dup_key rc=`rc'"
}

**# B13 prefix_collision: pooling leaves user columns with reserved names intact
* iivw_weight refuses to overwrite the user's _iivw_weight (see W10), so the
* shards come from the unweighted route; neither the fits nor the pool may
* touch the two user columns.
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(prefix_collision) collide(_iivw_weight _iivw_time_sq)
    _qa29_adapt
    assert _iivw_weight == 999 & _iivw_time_sq == 999
    _q29b_shards, fit(y a0, unweighted id(id) time(time) timespec(linear)) stem(b13)
    assert _iivw_weight == 999 & _iivw_time_sq == 999
    iivw_bspool using "$Q29B_W/b13_1.dta $Q29B_W/b13_2.dta", citype(wald) notable
    _qa29_pool_oracle, files($Q29B_W/b13_1.dta $Q29B_W/b13_2.dta) anchor(Q29B_A) reps(40)
    assert _iivw_weight == 999 & _iivw_time_sq == 999
    assert e(N) == _N
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL B13 prefix_collision rc=`rc'"
}

capture matrix drop Q29B_A
capture estimates drop q29b_anchor
shell rm -rf "$Q29B_W"
macro drop Q29B_W
display "RESULT: validation_fixture_qa29_bspool tests=`tests' pass=`pass' fail=`fail' skip=0"
iivw_qa_sandbox_restore
if `fail'>0 exit 1
