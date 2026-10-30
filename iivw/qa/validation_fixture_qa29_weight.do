*! validation_fixture_qa29_weight.do — A3 SEQ operator cells for iivw_weight
*! Author: Timothy P Copeland, Karolinska Institutet
* Each test builds a qa_fx_a3_seq fixture with one operator, adapts it to an
* IIVW visit panel (_qa29_adapt: every SEQ row is a visit at time = period),
* and checks the declared outcome class against an oracle the package does
* not share: a hand-built Andersen-Gill counting process fitted by stcox
* (_qa29_iw_oracle), a person-level logit (_qa29_ps_oracle), the exact rc
* plus an unchanged caller fingerprint, or equality with the friendly
* fixture. Operators with no input to reach in iivw_weight are listed in the
* round report, not faked here.
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

**# W1 separate(switch): the never-switching subgroup admits a time-invariant treat()
* In the friendly fixture xcat 3 ids switch treatment, so treat(a) is refused
* (198). Under separate(switch) they never change treatment after period 0,
* so the same call is valid and every component must equal the oracles.
local ++tests
capture noisily {
    qa_fx_a3_seq, clear n(400) seed(2929)
    _qa29_adapt
    quietly keep if xcat == 3
    _qa29_ref_open, tag(w1f)
    capture noisily iivw_weight, id(id) time(time) visit_cov(l0) treat(a) treat_cov(l0) maxfu(4) wtype(fiptiw) nolog
    _qa29_ref_close, tag(w1f) rc(198) got(`=_rc') cause("treat() must be time-invariant within subjects")
    * expect: EXACT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(separate(switch))
    _qa29_adapt
    quietly keep if xcat == 3
    tempvar amin amax
    bysort id: egen byte `amin' = min(a)
    bysort id: egen byte `amax' = max(a)
    assert `amin' == `amax'
    drop `amin' `amax'
    quietly count
    local rows = r(N)
    _qa29_design_n, end(4) ids(nids) tails(ntail)
    assert `nids' > 0 & `ntail' > 0
    iivw_weight, id(id) time(time) visit_cov(l0) treat(a) treat_cov(l0) maxfu(4) wtype(fiptiw) nolog
    assert r(N_weighted) == `rows' & r(n_ids_weighted) == `nids'
    assert r(n_censor_rows) == `ntail'
    * The package adds treat() to the visit model by construction.
    _qa29_iw_oracle, cov(l0 a) end(4) generate(o_iw)
    _qa29_ps_oracle, treat(a) cov(l0) ps(o_ps) tw(o_tw)
    assert !missing(_iivw_iw, o_iw, _iivw_ps, o_ps, _iivw_tw, o_tw, _iivw_weight)
    assert !missing(_iivw_iw, o_iw) & reldif(_iivw_iw, o_iw) < 1e-10
    assert !missing(_iivw_ps, o_ps) & reldif(_iivw_ps, o_ps) < 1e-10
    assert !missing(_iivw_tw, o_tw) & reldif(_iivw_tw, o_tw) < 1e-10
    assert !missing(_iivw_weight, o_iw*o_tw) & reldif(_iivw_weight, o_iw*o_tw) < 1e-10
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL W1 separate(switch) rc=`rc'"
}

**# W2 separate(censor): per-id censor() ends, xcat 3 followed to the common end
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(separate(censor))
    _qa29_adapt
    quietly count if xcat == 3 & c == 1
    assert r(N) == 0
    quietly count if xcat != 3 & c == 1
    assert r(N) > 0 & !missing(r(N))
    quietly count if xcat == 3 & cend != 4
    assert r(N) == 0
    quietly count if cend < 4
    assert r(N) > 0 & !missing(r(N))
    iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) censor(cend) nolog
    assert "`r(censor_mode)'" == "censor" & "`r(censor_var)'" == "cend"
    * Every id ends strictly after its last visit (last + .5, or 4 > 3), so
    * every id contributes exactly one terminal at-risk interval.
    assert r(n_censor_rows) == 400
    * Modeled events: every visit after the first.
    assert r(n_modeled_events) == _N - 400
    _qa29_iw_oracle, cov(l0 x2 x3) end(cend) generate(o_iw)
    assert !missing(_iivw_iw, o_iw)
    assert !missing(_iivw_iw, o_iw) & reldif(_iivw_iw, o_iw) < 1e-10
    assert !missing(_iivw_weight, _iivw_iw) & reldif(_iivw_weight, _iivw_iw) < 1e-12
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL W2 separate(censor) rc=`rc'"
}

**# W3 absorb: an arm whose visit process ends by period 1
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(absorb)
    _qa29_adapt
    quietly count if a0 == 1 & time >= 2
    assert r(N) == 0
    quietly count if a0 == 0 & time >= 2
    assert r(N) > 0 & !missing(r(N))
    _qa29_design_n, end(4) ids(nids) tails(ntail)
    iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) treat(a0) treat_cov(l0 x2 x3) maxfu(4) wtype(fiptiw) nolog
    assert r(n_censor_rows) == `ntail' & r(n_ids_weighted) == `nids'
    _qa29_iw_oracle, cov(l0 x2 x3 a0) end(4) generate(o_iw)
    _qa29_ps_oracle, treat(a0) cov(l0 x2 x3) ps(o_ps) tw(o_tw)
    assert !missing(_iivw_iw, o_iw, _iivw_ps, o_ps, _iivw_weight)
    assert !missing(_iivw_iw, o_iw) & reldif(_iivw_iw, o_iw) < 1e-10
    assert !missing(_iivw_ps, o_ps) & reldif(_iivw_ps, o_ps) < 1e-10
    assert !missing(_iivw_tw, o_tw) & reldif(_iivw_tw, o_tw) < 1e-10
    assert !missing(_iivw_weight, o_iw*o_tw) & reldif(_iivw_weight, o_iw*o_tw) < 1e-10
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL W3 absorb rc=`rc'"
}

**# W4 gap: a skipped visit is an irregular visit, not an error
* The at-risk interval spans the gap and lagvars() carries the previous
* visit's value across it (period 0 explains the interval ending at 2).
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(gap)
    local ngap = r(perturb_n_gap)
    assert `ngap' > 0 & !missing(`ngap')
    _qa29_adapt
    tempvar has1 nrow
    bysort id: egen byte `has1' = max(time == 1)
    bysort id: generate long `nrow' = _N
    quietly count if !`has1' & `nrow' >= 2 & time == 0
    assert r(N) == `ngap'
    drop `has1' `nrow'
    _qa29_design_n, end(4) ids(nids) tails(ntail)
    iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) lagvars(l_t) maxfu(4) nolog
    assert r(n_modeled_events) == _N - `nids'
    assert r(n_censor_rows) == `ntail'
    _qa29_iw_oracle, cov(l0 x2 x3) lag(l_t) end(4) generate(o_iw)
    assert !missing(_iivw_iw, o_iw)
    assert !missing(_iivw_iw, o_iw) & reldif(_iivw_iw, o_iw) < 1e-10
    * The generated lag column really crosses the gap.
    tempvar want
    bysort id (time): generate double `want' = l_t[_n-1]
    assert (l_t_lag1 == `want') | (missing(l_t_lag1) & missing(`want'))
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL W4 gap rc=`rc'"
}

**# W5 dup_key: a duplicated (id, time) visit is refused with no state change
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(dup_key)
    _qa29_adapt
    quietly duplicates report id time
    assert r(unique_value) == r(N) - 1
    _qa29_ref_open, tag(w5)
    capture noisily iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    _qa29_ref_close, tag(w5) rc(198) got(`=_rc') cause("duplicate id-time combinations found")
    capture confirm variable _iivw_weight
    assert _rc == 111
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL W5 dup_key rc=`rc'"
}

**# W6 single_period: an intensity model with no follow-up visit is refused
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(single_period)
    _qa29_adapt
    assert _N == 400 & time == 0
    _qa29_ref_open, tag(w6)
    capture noisily iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    _qa29_ref_close, tag(w6) rc(198) got(`=_rc') cause("requires at least one subject with 2 or more visits")
    capture confirm variable _iivw_iw
    assert _rc == 111
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL W6 single_period IIW rc=`rc'"
}

**# W7 single_period: IPTW needs one row per subject and is exact
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(single_period)
    _qa29_adapt
    iivw_weight, id(id) time(time) treat(a0) treat_cov(l0 x2 x3) wtype(iptw) nolog
    assert r(N_weighted) == 400 & r(n_ids_weighted) == 400
    _qa29_ps_oracle, treat(a0) cov(l0 x2 x3) ps(o_ps) tw(o_tw)
    assert !missing(_iivw_ps, o_ps, _iivw_tw, _iivw_weight)
    assert !missing(_iivw_ps, o_ps) & reldif(_iivw_ps, o_ps) < 1e-10
    assert !missing(_iivw_tw, o_tw) & reldif(_iivw_tw, o_tw) < 1e-10
    assert !missing(_iivw_weight, o_tw) & reldif(_iivw_weight, o_tw) < 1e-10
    capture confirm variable _iivw_iw
    assert _rc == 111
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL W7 single_period IPTW rc=`rc'"
}

**# W8 miss_partial: a visit covariate missing on follow-up rows is refused
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(miss_partial)
    _qa29_adapt
    quietly count if missing(l0)
    assert r(N) > 0 & !missing(r(N))
    quietly count if missing(l0) & (time == 0 | mod(id, 7) != 0)
    assert r(N) == 0
    _qa29_ref_open, tag(w8)
    capture noisily iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    _qa29_ref_close, tag(w8) rc(416) got(`=_rc') cause("observations have no weight")
    capture confirm variable _iivw_weight
    assert _rc == 111
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL W8 miss_partial visit model rc=`rc'"
}

**# W9 miss_partial: a baseline-only treat_cov() is untouched by follow-up gaps
* The propensity model is fitted on each subject's first row, where l0 is
* always observed, so every weight equals the friendly fixture's.
local ++tests
capture noisily {
    tempfile friendly
    qa_fx_a3_seq, clear n(400) seed(2929)
    _qa29_adapt
    quietly iivw_weight, id(id) time(time) visit_cov(x2 x3) treat(a0) treat_cov(l0) maxfu(4) wtype(fiptiw) nolog
    keep id time _iivw_ps _iivw_tw _iivw_iw _iivw_weight
    rename (_iivw_ps _iivw_tw _iivw_iw _iivw_weight) (f_ps f_tw f_iw f_w)
    quietly save `friendly'
    * expect: INVARIANT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(miss_partial)
    _qa29_adapt
    quietly count if missing(l0)
    assert r(N) > 0 & !missing(r(N))
    iivw_weight, id(id) time(time) visit_cov(x2 x3) treat(a0) treat_cov(l0) maxfu(4) wtype(fiptiw) nolog
    assert r(N_weighted) == _N & r(n_missing_weight) == 0
    quietly merge 1:1 id time using `friendly', assert(match) nogenerate
    assert !missing(_iivw_ps, f_ps, _iivw_weight, f_w)
    assert !missing(_iivw_ps, f_ps) & reldif(_iivw_ps, f_ps) < 1e-12
    assert !missing(_iivw_tw, f_tw) & reldif(_iivw_tw, f_tw) < 1e-12
    assert !missing(_iivw_iw, f_iw) & reldif(_iivw_iw, f_iw) < 1e-12
    assert !missing(_iivw_weight, f_w) & reldif(_iivw_weight, f_w) < 1e-12
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL W9 miss_partial treatment model rc=`rc'"
}

**# W10 prefix_collision: a user _iivw_weight is never overwritten
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(prefix_collision) collide(_iivw_weight)
    _qa29_adapt
    assert _iivw_weight == 999
    _qa29_ref_open, tag(w10a)
    capture noisily iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog
    _qa29_ref_close, tag(w10a) rc(110) got(`=_rc') cause("variable _iivw_weight already exists; use the replace option")
    * replace overwrites only package-owned columns; this one is the user's.
    _qa29_ref_open, tag(w10b)
    capture noisily iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) maxfu(4) nolog replace
    _qa29_ref_close, tag(w10b) rc(110) got(`=_rc') cause("was not created by iivw")
    assert _iivw_weight == 999
    capture confirm variable _iivw_iw
    assert _rc == 111
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL W10 prefix_collision rc=`rc'"
}

**# W11 separate: outcome separation never reaches the weight models
* iivw_weight fits no outcome model. Without y-terminated trajectories xcat 3
* ids keep visiting, so the visit panel differs from the friendly one; the
* weights must still be the exact counting-process oracle, with no refusal.
local ++tests
capture noisily {
    * expect: EXACT
    * Five periods (0..4) with maxfu(4): ids seen at 4 end ON the endpoint
    * (no terminal interval), the rest have one; visits at 4 lie in (3,4].
    qa_fx_a3_seq, clear n(400) seed(2929) k(5) perturb(separate)
    _qa29_adapt
    _qa29_design_n, end(4) ids(nids) tails(ntail)
    quietly count if time == 4
    assert r(N) > 0 & !missing(r(N))
    assert `ntail' < `nids'
    quietly count if xcat == 3 & y == 1
    assert r(N) == 0
    iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) lagvars(l_t) maxfu(4) nolog
    assert r(N_weighted) == _N & r(n_modeled_events) == _N - `nids'
    assert r(n_censor_rows) == `ntail'
    _qa29_iw_oracle, cov(l0 x2 x3) lag(l_t) end(4) generate(o_iw)
    assert !missing(_iivw_iw, o_iw)
    assert !missing(_iivw_iw, o_iw) & reldif(_iivw_iw, o_iw) < 1e-10
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL W11 separate rc=`rc'"
}

**# W12 separate_time: an event-free visit wave never reaches the weight models
local ++tests
capture noisily {
    * expect: EXACT
    * Five periods (0..4) with maxfu(4): ids seen at 4 end ON the endpoint
    * (no terminal interval), the rest have one; visits at 4 lie in (3,4].
    qa_fx_a3_seq, clear n(400) seed(2929) k(5) perturb(separate_time)
    _qa29_adapt
    _qa29_design_n, end(4) ids(nids) tails(ntail)
    quietly count if time == 4
    assert r(N) > 0 & !missing(r(N))
    assert `ntail' < `nids'
    quietly count if time == 1 & y == 1
    assert r(N) == 0
    iivw_weight, id(id) time(time) visit_cov(l0 x2 x3) lagvars(l_t) maxfu(4) nolog
    assert r(N_weighted) == _N & r(n_modeled_events) == _N - `nids'
    assert r(n_censor_rows) == `ntail'
    _qa29_iw_oracle, cov(l0 x2 x3) lag(l_t) end(4) generate(o_iw)
    assert !missing(_iivw_iw, o_iw)
    assert !missing(_iivw_iw, o_iw) & reldif(_iivw_iw, o_iw) < 1e-10
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL W12 separate_time rc=`rc'"
}

**# W13 codes_multidigit: raw multi-digit codes enter the visit model as numbers
* A raw numeric covariate is taken at its value, so the relabel 1 2 3 ->
* 1 11 111 changes the visit model; the weights must be the counting-process
* oracle fitted on the same multi-digit values, and must differ from the
* friendly fixture's.
local ++tests
capture noisily {
    tempfile friendly
    qa_fx_a3_seq, clear n(400) seed(2929)
    _qa29_adapt
    quietly iivw_weight, id(id) time(time) visit_cov(l0 xcat) maxfu(4) nolog
    keep id time _iivw_iw
    rename _iivw_iw f_iw
    quietly save `friendly'
    * expect: EXACT
    qa_fx_a3_seq, clear n(400) seed(2929) perturb(codes_multidigit)
    _qa29_adapt
    assert inlist(xcat, 1, 11, 111)
    _qa29_design_n, end(4) ids(nids) tails(ntail)
    iivw_weight, id(id) time(time) visit_cov(l0 xcat) maxfu(4) nolog
    assert "`r(visit_covars)'" == "l0 xcat"
    assert r(n_censor_rows) == `ntail' & r(n_ids_weighted) == `nids'
    _qa29_iw_oracle, cov(l0 xcat) end(4) generate(o_iw)
    assert !missing(_iivw_iw, o_iw) & reldif(_iivw_iw, o_iw) < 1e-10
    assert !missing(_iivw_weight, _iivw_iw) & reldif(_iivw_weight, _iivw_iw) < 1e-12
    quietly merge 1:1 id time using `friendly', assert(match) nogenerate
    quietly count if reldif(_iivw_iw, f_iw) > 1e-6
    assert r(N) > 0 & !missing(r(N))
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL W13 codes_multidigit rc=`rc'"
}

display "RESULT: validation_fixture_qa29_weight tests=`tests' pass=`pass' fail=`fail' skip=0"
iivw_qa_sandbox_restore
if `fail'>0 exit 1
