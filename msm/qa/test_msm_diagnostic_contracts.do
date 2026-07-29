* test_msm_diagnostic_contracts.do
*
* Regression suite for the 1.3.0 diagnostic and fit-metadata contracts.
*
* Every test here fails on 1.2.4. The defects were all rc=0-but-wrong: a
* positivity gate that measured the wrong probability, a pooled balance summary
* computed over rows the estimator never sees, a command that handed the caller
* back a re-sorted dataset, and a cluster count taken from the sample msm_fit
* intended to supply rather than the one the estimator kept.
*
* Each check carries its own oracle, computed here from the raw fitted
* probabilities and the risk-set marker rather than read back out of the
* command under test.

version 16.0
clear all
set more off
set varabbrev off

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

**# Data builders

* Propensities bounded away from 0 but running up to ~0.98. This is the shape
* ps_min cannot see: min P(A=1) stays around 0.5 in every period, while the
* untreated rows at the top of the propensity range carry observed-decision
* probabilities near 0.02 and generate the extreme weights.
capture program drop _dc_upper_tail_panel
program define _dc_upper_tail_panel
    version 16.0
    syntax [, SEED(integer 20260725) NIDS(integer 1500) TPER(integer 4)]

    clear
    set seed `seed'
    set obs `nids'
    gen long id = _n
    gen byte L = mod(_n, 2)
    expand `tper'
    bysort id: gen int period = _n - 1
    * invlogit(4*L): 0.5 when L==0, 0.982 when L==1
    gen byte treat = runiform() < invlogit(4 * L)
    gen byte out   = runiform() < invlogit(-3 + 0.5 * treat + 0.3 * L)
    * Terminal event: drop post-event rows, then re-densify to consecutive periods
    bysort id (period): gen byte _prior = sum(out[_n-1]) >= 1 if _n > 1
    replace _prior = 0 if missing(_prior)
    drop if _prior
    drop _prior
    bysort id (period): gen int _p2 = _n - 1
    drop period
    rename _p2 period
end

* Panel that RETAINS post-event and post-censor rows, so the risk-set marker
* and the full row set genuinely differ. This is the shape in which a pooled
* SMD over all rows disagrees with the pooled SMD the estimator's sample sees.
capture program drop _dc_carryforward_panel
program define _dc_carryforward_panel
    version 16.0
    syntax [, SEED(integer 777) NIDS(integer 500) TPER(integer 5)]

    clear
    set seed `seed'
    set obs `nids'
    gen long id = _n
    gen byte L = mod(_n, 2)
    expand `tper'
    bysort id: gen int period = _n - 1
    gen byte treat = runiform() < invlogit(-0.5 + 1.6 * L)
    gen byte out   = runiform() < invlogit(-2.2 + 0.4 * treat + 0.9 * L)
    * Censoring never coincides with an event (msm_prepare refuses that tie).
    gen byte censored = (runiform() < 0.03) & out == 0
end

* Panel with a time-fixed outcome covariate missing for one subject in ten, so
* the estimator drops those subjects entirely and the fitted sample is strictly
* smaller than the intended risk set.
capture program drop _dc_dropped_rows_panel
program define _dc_dropped_rows_panel
    version 16.0
    syntax [, SEED(integer 4242) NIDS(integer 400) TPER(integer 4)]

    clear
    set seed `seed'
    set obs `nids'
    gen long id = _n
    gen byte L = mod(_n, 2)
    gen double V = rnormal()
    expand `tper'
    bysort id: gen int period = _n - 1
    gen byte treat = runiform() < invlogit(-0.2 + 1.0 * L + 0.3 * V)
    gen byte out   = runiform() < invlogit(-3 + 0.5 * treat + 0.3 * L)
    bysort id (period): gen byte _prior = sum(out[_n-1]) >= 1 if _n > 1
    replace _prior = 0 if missing(_prior)
    drop if _prior
    drop _prior
    bysort id (period): gen int _p2 = _n - 1
    drop period
    rename _p2 period
    * Time-fixed covariate, absent for every row of one subject in ten
    gen double Vb = V
    replace Vb = . if mod(id, 10) == 0
end

**# DC1: the positivity floor measures P(observed treatment), not P(A=1)

* On 1.2.4 the gate read ps_min, the smallest estimated P(A=1) in the period.
* That answers a different question. Here P(A=1) never drops below ~0.45, so
* 1.2.4 reports zero violations at positivity(0.10) while every period contains
* untreated rows whose observed-decision probability is around 0.015 -- the
* rows generating the maximum weight of ~19 and the 32% ESS. RED on HEAD.
local ++test_count
capture noisily {
    _dc_upper_tail_panel
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) ///
        baseline_covariates(L)
    msm_weight, treat_d_cov(L) nolog

    * Oracle: the probability of the decision each row actually took, built
    * from the raw fitted denominator probability, not from r(support).
    tempvar pobs
    quietly gen double `pobs' = cond(treat == 1, _msm_treat_den_raw, ///
        1 - _msm_treat_den_raw) if _msm_decision_risk

    msm_diagnose, balance_covariates(L) positivity(0.10)
    * Capture every return BEFORE the oracle loop: the summarize calls below
    * overwrite r(), so reading r(n_positivity_violations) afterwards would
    * silently compare against nothing.
    matrix S = r(support)
    local _rep_viol   = r(n_positivity_violations)
    local _rep_minobs = r(min_obs_probability)
    local _rep_maxw   = r(max_weight)
    local _rep_esspct = r(ess_pct)

    * The support matrix carries obs_min in a named column, in a fixed order.
    local scols : colnames S
    assert "`scols'" == "period N treated untreated ps_min ps_max obs_min common_lo common_hi n_outside ess"
    assert colsof(S) == 11

    * Per-period obs_min equals the oracle exactly, and ps_min does not.
    quietly levelsof period if _msm_decision_risk, local(_dcper)
    local _r = 0
    local _oracle_viol = 0
    local _psmin_viol  = 0
    foreach p of local _dcper {
        local ++_r
        quietly summarize `pobs' if _msm_decision_risk & period == `p', meanonly
        local _want = r(min)
        assert reldif(S[`_r', 7], `_want') < 1e-12
        if `_want' < 0.10 local ++_oracle_viol
        if S[`_r', 5] < 0.10 local ++_psmin_viol
    }

    * The reported count follows the oracle.
    assert `_rep_viol' == `_oracle_viol'
    assert `_rep_viol' == 4

    * ... and the two rules genuinely disagree on this panel, so the test is
    * not silently passing because both columns happen to coincide.
    assert `_psmin_viol' == 0
    assert `_oracle_viol' != `_psmin_viol'

    * The global minimum is returned and matches the oracle exactly. The
    * magnitude is bounded rather than pinned: it is a simulated quantity, and
    * the contract under test is "the command reports the oracle", not "the RNG
    * produced this digit". The bound still proves the panel breaches 0.10 by
    * roughly an order of magnitude, which is what makes DC1 discriminating.
    quietly summarize `pobs' if _msm_decision_risk, meanonly
    local _globmin = r(min)
    assert `_globmin' > 0.005 & `_globmin' < 0.05
    assert reldif(`_rep_minobs', `_globmin') < 1e-12

    * Sanity: this panel really is the extreme-weight case the gate exists for.
    assert `_rep_maxw' > 10
    assert `_rep_esspct' < 50
}
if _rc == 0 {
    display as result "  PASS DC1: positivity floor reads P(observed treatment), not P(A=1)"
    local ++pass_count
}
else {
    display as error "  FAIL DC1: positivity floor semantics (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' DC1"
}

**# DC2: a well-supported panel is not flagged (positive control)

* Guards the fix against over-correction: near-random treatment keeps the
* observed-decision probability comfortably away from 0 in both tails.
local ++test_count
capture noisily {
    clear
    set seed 20260726
    set obs 600
    gen long id = _n
    gen byte L = mod(_n, 2)
    expand 4
    bysort id: gen int period = _n - 1
    gen byte treat = runiform() < 0.5
    gen byte out   = runiform() < invlogit(-3 + 0.3 * treat)

    msm_prepare, id(id) period(period) treatment(treat) outcome(out) ///
        baseline_covariates(L)
    msm_weight, treat_d_cov(L) nolog

    tempvar pobs
    quietly gen double `pobs' = cond(treat == 1, _msm_treat_den_raw, ///
        1 - _msm_treat_den_raw) if _msm_decision_risk
    quietly summarize `pobs' if _msm_decision_risk, meanonly
    assert r(min) > 0.05

    msm_diagnose, balance_covariates(L) positivity(0.05)
    assert r(n_positivity_violations) == 0
    assert r(min_obs_probability) > 0.05
}
if _rc == 0 {
    display as result "  PASS DC2: well-overlapped panel is not falsely flagged"
    local ++pass_count
}
else {
    display as error "  FAIL DC2: positivity positive control (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' DC2"
}

**# DC2b: an unusable fitted probability reports obs_min = 0 and trips the floor

* Reachable only through the explicit probpolicy(clip) opt-in. summarize skips
* a missing probability, so without the sentinel a period whose remaining rows
* look fine reads as unviolated even though one decision has no usable
* probability at all -- the most extreme support failure there is.
local ++test_count
capture noisily {
    clear
    set seed 20260727
    set obs 400
    gen long id = _n
    gen byte L = mod(_n, 2)
    * A second covariate that perfectly separates treatment in one small cell,
    * so logit drops it and predict returns missing for those rows.
    gen byte Sep = (_n <= 12)
    expand 3
    bysort id: gen int period = _n - 1
    gen byte treat = runiform() < invlogit(-0.3 + 0.8 * L)
    replace treat = 1 if Sep == 1
    gen byte out = runiform() < invlogit(-3 + 0.4 * treat)

    msm_prepare, id(id) period(period) treatment(treat) outcome(out) ///
        baseline_covariates(L Sep)
    * Default probpolicy(error) must refuse this outright.
    capture msm_weight, treat_d_cov(L Sep) nolog
    assert _rc != 0

    * The explicit opt-in proceeds; the diagnostic must then be honest about it.
    msm_weight, treat_d_cov(L Sep) probpolicy(clip) clip(0.01) nolog
    quietly count if _msm_decision_risk & missing(_msm_treat_den_raw)
    local _n_unusable = r(N)
    assert `_n_unusable' > 0

    msm_diagnose, balance_covariates(L) positivity(0.01)
    matrix S2 = r(support)
    local _viol = r(n_positivity_violations)
    local _minobs = r(min_obs_probability)

    * Every period holding an unusable row reports obs_min == 0 exactly.
    local _n_zero = 0
    forvalues _r = 1/`=rowsof(S2)' {
        if S2[`_r', 7] == 0 local ++_n_zero
    }
    assert `_n_zero' > 0
    assert `_viol' >= `_n_zero'
    assert `_minobs' == 0
}
if _rc == 0 {
    display as result "  PASS DC2b: unusable fitted probability reports obs_min=0 and trips the floor"
    local ++pass_count
}
else {
    display as error "  FAIL DC2b: unusable-probability sentinel (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' DC2b"
}

**# DC3: msm_diagnose restores the caller's observation order

* 1.2.4 sorted by id/period to build the prior-treatment stratum and never
* restored, so the caller got the dataset back in a different row order. Seven
* other commands in the suite already honour this contract. RED on HEAD.
local ++test_count
capture noisily {
    _dc_carryforward_panel
    * Shuffle deliberately: the incoming order is NOT id/period order, so a
    * command that re-sorts cannot accidentally land back where it started.
    set seed 991
    gen double _u = runiform()
    sort _u
    drop _u
    gen long rowid = _n

    msm_prepare, id(id) period(period) treatment(treat) outcome(out) ///
        censor(censored) baseline_covariates(L)
    msm_weight, treat_d_cov(L) censor_d_cov(L) nolog

    * The weighting stage already honoured the contract; confirm the fixture.
    quietly count if rowid != _n
    assert r(N) == 0

    msm_diagnose, balance_covariates(L)
    quietly count if rowid != _n
    assert r(N) == 0

    * by_period and accumulate() take different code paths through the command.
    msm_diagnose, balance_covariates(L) by_period
    quietly count if rowid != _n
    assert r(N) == 0

    capture frame drop _dc_acc
    msm_diagnose, balance_covariates(L) accumulate(_dc_acc) contrast("a vs b")
    quietly count if rowid != _n
    assert r(N) == 0
    capture frame drop _dc_acc

    * An error path must restore the order too.
    capture msm_diagnose, balance_covariates(L) positivity(0.9)
    assert _rc == 198
    quietly count if rowid != _n
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS DC3: msm_diagnose restores observation order on every path"
    local ++pass_count
}
else {
    display as error "  FAIL DC3: msm_diagnose order restoration (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' DC3"
}

**# DC4: the pooled balance summary is computed on the risk set

* 1.2.4 pooled every row, including post-event and post-censor rows carrying the
* last cumulative weight forward. On this panel a third of the rows are
* post-risk, and including them turned a correctly weighted SMD of about -0.002
* into 0.28 -- reported to the user as an imbalanced covariate. RED on HEAD.
local ++test_count
capture noisily {
    _dc_carryforward_panel
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) ///
        censor(censored) baseline_covariates(L)
    msm_weight, treat_d_cov(L) censor_d_cov(L) nolog

    * The fixture must actually contain post-risk rows, or the test proves
    * nothing about which sample was used.
    quietly count if !_msm_decision_risk
    local _npostrisk = r(N)
    assert `_npostrisk' > 400

    * Oracle, weighted SMD on the risk set, built by explicit arithmetic rather
    * than by re-running the helper the command uses. L is binary, so Austin &
    * Stuart's dichotomous-covariate formula uses weighted prevalences and
    * p(1-p), not a sample-variance finite-N correction.
    tempvar wL
    quietly gen double `wL' = _msm_weight * L
    foreach g in 1 0 {
        quietly summarize _msm_weight if _msm_decision_risk & treat == `g', meanonly
        local sw = r(sum)
        quietly summarize `wL' if _msm_decision_risk & treat == `g', meanonly
        local m`g' = r(sum) / `sw'
        local v`g' = `m`g'' * (1 - `m`g'')
    }
    local _oracle_riskset = (`m1' - `m0') / sqrt((`v1' + `v0') / 2)

    * What the all-rows rule would have produced.
    foreach g in 1 0 {
        quietly summarize _msm_weight if treat == `g', meanonly
        local asw = r(sum)
        quietly summarize `wL' if treat == `g', meanonly
        local am`g' = r(sum) / `asw'
        local av`g' = `am`g'' * (1 - `am`g'')
    }
    local _all_rows = (`am1' - `am0') / sqrt((`av1' + `av0') / 2)

    msm_diagnose, balance_covariates(L) threshold(0.1)
    matrix B = r(balance)

    * The reported weighted SMD is the risk-set value ...
    assert reldif(B[1, 2], `_oracle_riskset') < 1e-8
    * ... and the two rules are far apart on this panel, so the assertion above
    * is a real discrimination and not a coincidence.
    assert abs(`_all_rows' - `_oracle_riskset') > 0.2
    * The risk-set answer is balanced; the all-rows answer would not be.
    assert abs(`_oracle_riskset') < 0.1
    assert abs(`_all_rows') > 0.1

    * The unweighted column follows the same sample.
    quietly summarize L if _msm_decision_risk & treat == 1, meanonly
    local um1 = r(mean)
    local uv1 = `um1' * (1 - `um1')
    quietly summarize L if _msm_decision_risk & treat == 0, meanonly
    local um0 = r(mean)
    local uv0 = `um0' * (1 - `um0')
    assert reldif(B[1, 1], (`um1' - `um0') / sqrt((`uv1' + `uv0') / 2)) < 1e-8
}
if _rc == 0 {
    display as result "  PASS DC4: pooled balance uses the risk set, not every stored row"
    local ++pass_count
}
else {
    display as error "  FAIL DC4: pooled balance sample (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' DC4"
}

**# DC5: fit metadata describes the sample the estimator kept

* 1.2.4 counted clusters from the intended risk set BEFORE estimating, so with
* a missing outcome_cov it stored e(msm_n_clusters)=400 while Stata's own
* header printed "adjusted for 360 clusters". The drop was silent. RED on HEAD
* both on the count and on the absence of e(msm_n_dropped).
local ++test_count
capture noisily {
    _dc_dropped_rows_panel
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) ///
        baseline_covariates(L)
    msm_weight, treat_d_cov(L) nolog

    * Intended risk-set rows, computed here from the mapped variables.
    tempvar postout intended
    quietly bysort id (period): gen byte `postout' = sum(out[_n-1]) >= 1 if _n > 1
    quietly replace `postout' = 0 if missing(`postout')
    quietly gen byte `intended' = (`postout' == 0 & !missing(_msm_weight))
    quietly count if `intended'
    local _n_intended = r(N)

    msm_fit, model(logistic) outcome_cov(L Vb) nolog

    * The estimator really did drop rows, or this test proves nothing.
    assert e(N) < `_n_intended'
    assert e(msm_n_dropped) == `_n_intended' - e(N)
    assert e(msm_n_dropped) > 0

    * The stored cluster count matches the clusters among the FITTED rows.
    tempvar ctag
    quietly bysort _msm_esample id: gen byte `ctag' = (_msm_esample & _n == 1)
    quietly count if `ctag'
    local _true_clusters = r(N)
    assert e(msm_n_clusters) == `_true_clusters'

    * The intended-sample count is strictly larger, so the old rule and the new
    * rule genuinely disagree here.
    quietly bysort `intended' id: gen byte _dc_itag = (`intended' & _n == 1)
    quietly count if _dc_itag
    local _intended_clusters = r(N)
    drop _dc_itag
    assert `_intended_clusters' > `_true_clusters'
    assert e(msm_n_clusters) != `_intended_clusters'

    * _msm_esample marks exactly the fitted rows.
    quietly count if _msm_esample
    assert r(N) == e(N)
}
if _rc == 0 {
    display as result "  PASS DC5: e(msm_n_clusters)/e(msm_n_dropped) describe the fitted sample"
    local ++pass_count
}
else {
    display as error "  FAIL DC5: fit-sample metadata (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' DC5"
}

**# DC6: a complete-case fit reports zero drops (positive control)

local ++test_count
capture noisily {
    _dc_dropped_rows_panel
    drop Vb
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) ///
        baseline_covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(logistic) outcome_cov(L) nolog

    assert e(msm_n_dropped) == 0
    tempvar ctag
    quietly bysort _msm_esample id: gen byte `ctag' = (_msm_esample & _n == 1)
    quietly count if `ctag'
    assert e(msm_n_clusters) == r(N)
    quietly count if _msm_esample
    assert r(N) == e(N)

    * Cox refuses a shrunken sample outright, so its drop count is always 0.
    msm_fit, model(cox) outcome_cov(L) nolog
    assert e(msm_n_dropped) == 0
}
if _rc == 0 {
    display as result "  PASS DC6: complete-case and Cox fits report zero dropped rows"
    local ++pass_count
}
else {
    display as error "  FAIL DC6: fit-sample positive control (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' DC6"
}

**# DC7: msm_diagnose does not leak generate/replace chatter to the console

* The balance block built its stratum and weight-square columns outside
* quietly, so users saw "(1,500 missing values generated)" and "(1,500 real
* changes made)" in the middle of the diagnostics. RED on HEAD.
local ++test_count
capture noisily {
    _dc_carryforward_panel
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) ///
        censor(censored) baseline_covariates(L)
    msm_weight, treat_d_cov(L) censor_d_cov(L) nolog

    * Stata only appends .log when the name carries no extension, and a
    * tempfile stem always contains a dot (St1234.000001), so build the name
    * with an explicit extension off the unique stem rather than guessing.
    tempfile dcstem
    local dclog "`dcstem'_noise.log"
    capture log close _all
    log using "`dclog'", replace text name(dcnoise)
    msm_diagnose, balance_covariates(L) by_period
    log close dcnoise

    tempname fh
    local _noise = 0
    local _lines = 0
    file open `fh' using "`dclog'", read text
    file read `fh' line
    while r(eof) == 0 {
        local ++_lines
        if strpos(`"`line'"', "real changes made") > 0 local ++_noise
        if strpos(`"`line'"', "missing values generated") > 0 local ++_noise
        if strpos(`"`line'"', "observations deleted") > 0 local ++_noise
        file read `fh' line
    }
    file close `fh'

    * The log really was captured (guards against asserting on an empty file).
    assert `_lines' > 20
    assert `_noise' == 0
    capture erase "`dclog'"
}
if _rc == 0 {
    display as result "  PASS DC7: msm_diagnose emits no generate/replace chatter"
    local ++pass_count
}
else {
    display as error "  FAIL DC7: msm_diagnose console noise (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' DC7"
}
capture log close _all

**# DC8: previously unreferenced stored results

* r(id) from the status controller and r(rr_scale) from msm_sensitivity were
* the two returns the package audit reported as unreferenced by any QA file.
* Assert their values, not merely their existence.
local ++test_count
capture noisily {
    _dc_dropped_rows_panel
    drop Vb
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) ///
        baseline_covariates(L)

    msm, status
    assert "`r(id)'" == "id"
    assert "`r(period)'" == "period"
    assert "`r(treatment)'" == "treat"

    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(logistic) outcome_cov(L) nolog

    * Drive both rarity branches off rarethreshold() rather than off whatever
    * event rate this DGP happens to realize, so the test states the contract
    * (r(rr_scale) tracks the rarity gate) and not an RNG outcome.
    msm_sensitivity, evalue
    local _cuminc = r(cumulative_incidence)
    assert `_cuminc' > 0.01 & `_cuminc' < 0.80

    * Threshold above the cumulative incidence: rare, OR used directly as RR.
    msm_sensitivity, evalue rarethreshold(0.9)
    local _scale_rare  = "`r(rr_scale)'"
    local _approx_rare = "`r(approximation)'"
    assert strpos("`_scale_rare'", "OR used directly") == 1
    assert "`_approx_rare'" == "rare-outcome"

    * Threshold below it: common, so the label switches to the sqrt(OR)
    * transform VanderWeele & Ding prescribe for a common outcome.
    msm_sensitivity, evalue rarethreshold(0.005)
    local _scale_common = "`r(rr_scale)'"
    assert "`_scale_common'" == "sqrt(OR) common-outcome approximation"
    assert "`r(approximation)'" == "common-outcome sqrt(OR)"
    assert "`_scale_common'" != "`_scale_rare'"

    * orapprox overrides the transform on a common outcome and says so.
    msm_sensitivity, evalue rarethreshold(0.005) orapprox
    assert strpos("`r(rr_scale)'", "OR used directly") == 1
    assert "`r(approximation)'" == "OR-direct override"
}
if _rc == 0 {
    display as result "  PASS DC8: r(id) and r(rr_scale) carry the documented values"
    local ++pass_count
}
else {
    display as error "  FAIL DC8: previously unreferenced returns (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' DC8"
}

**# DC9: SMDs implement the cited continuous and binary formulas exactly

* Stata's summarize [aw=] variance is not Austin & Stuart's
* reliability-weight variance. With unequal weights the two can differ
* materially, especially inside small period/history cells. The binary
* diagnostic has its own prevalence-based denominator and must not inherit a
* sample-variance correction.
local ++test_count
capture noisily {
    clear
    input byte treat double x double w
        0 0 100
        0 1   1
        0 2   1
        1 3   1
        1 4   1
        1 5 100
    end

    tempvar wx w2 dev2
    quietly gen double `wx' = w * x
    quietly gen double `w2' = w^2
    foreach g in 1 0 {
        quietly summarize w if treat == `g', meanonly
        local sw`g' = r(sum)
        quietly summarize `wx' if treat == `g', meanonly
        local cm`g' = r(sum) / `sw`g''
        quietly summarize `w2' if treat == `g', meanonly
        local sw2`g' = r(sum)
    }
    quietly gen double `dev2' = cond(treat == 1, ///
        w * (x - `cm1')^2, w * (x - `cm0')^2)
    foreach g in 1 0 {
        quietly summarize `dev2' if treat == `g', meanonly
        local cv`g' = `sw`g'' / (`sw`g''^2 - `sw2`g'') * r(sum)
    }
    local _continuous_oracle = (`cm1' - `cm0') / ///
        sqrt((`cv1' + `cv0') / 2)

    _msm_smd x, treatment(treat) weight(w)
    local _continuous_got = `_msm_smd_value'
    assert reldif(`_continuous_got', `_continuous_oracle') < 1e-12

    * The fixture is discriminating: Stata's normalized-aweight variance gives
    * a very different answer, so copying the implementation would not pass.
    quietly summarize x [aw=w] if treat == 1
    local _av1 = r(Var)
    local _am1 = r(mean)
    quietly summarize x [aw=w] if treat == 0
    local _av0 = r(Var)
    local _am0 = r(mean)
    local _aweight_smd = (`_am1' - `_am0') / sqrt((`_av1' + `_av0') / 2)
    assert abs(`_continuous_got' - `_aweight_smd') > 1

    clear
    input byte treat byte x double w
        0 0 1
        0 0 1
        0 0 1
        0 1 9
        1 0 9
        1 1 1
        1 1 1
        1 1 1
    end

    * Weighted prevalences are 0.25 and 0.75 in the treated and untreated
    * groups, respectively.
    local _binary_oracle = (0.25 - 0.75) / ///
        sqrt((0.25 * 0.75 + 0.75 * 0.25) / 2)
    _msm_smd x, treatment(treat) weight(w)
    local _binary_got = `_msm_smd_value'
    assert reldif(`_binary_got', `_binary_oracle') < 1e-12
    assert abs(`_binary_got' + 1) > 0.1
}
if _rc == 0 {
    display as result "  PASS DC9: continuous and binary SMD formulas match independent oracles"
    local ++pass_count
}
else {
    display as error "  FAIL DC9: exact Austin-Stuart SMD formulas (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' DC9"
}

**# DC10: Love-plot values use the decision risk set

* msm_diagnose already excludes post-event and post-censor carry-forward rows.
* The Love plot must use the same analysis sample and expose the plotted values
* so this can be checked without trying to compare unstable .gph binaries.
local ++test_count
capture noisily {
    _dc_carryforward_panel
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) ///
        censor(censored) baseline_covariates(L)
    msm_weight, treat_d_cov(L) censor_d_cov(L) nolog

    tempvar wL
    quietly gen double `wL' = _msm_weight * L
    foreach g in 1 0 {
        quietly summarize _msm_weight if _msm_decision_risk & ///
            treat == `g', meanonly
        local psw`g' = r(sum)
        quietly summarize `wL' if _msm_decision_risk & treat == `g', meanonly
        local ppm`g' = r(sum) / `psw`g''
        local ppv`g' = `ppm`g'' * (1 - `ppm`g'')

        quietly summarize L if _msm_decision_risk & treat == `g', meanonly
        local pum`g' = r(mean)
        local puv`g' = `pum`g'' * (1 - `pum`g'')

        quietly summarize _msm_weight if treat == `g', meanonly
        local asw`g' = r(sum)
        quietly summarize `wL' if treat == `g', meanonly
        local apm`g' = r(sum) / `asw`g''
        local apv`g' = `apm`g'' * (1 - `apm`g'')
    }
    local _plot_raw = (`pum1' - `pum0') / sqrt((`puv1' + `puv0') / 2)
    local _plot_weighted = (`ppm1' - `ppm0') / sqrt((`ppv1' + `ppv0') / 2)
    local _all_weighted = (`apm1' - `apm0') / sqrt((`apv1' + `apv0') / 2)
    quietly count if _msm_decision_risk & !missing(treat)
    local _nrisk = r(N)

    msm_plot, type(balance) covariates(L)
    matrix PB = r(balance)
    assert rowsof(PB) == 1
    assert colsof(PB) == 2
    assert reldif(PB[1, 1], `_plot_raw') < 1e-8
    assert reldif(PB[1, 2], `_plot_weighted') < 1e-8
    assert r(n_risk) == `_nrisk'
    assert abs(`_all_weighted' - `_plot_weighted') > 0.2
    capture graph drop _all
}
if _rc == 0 {
    display as result "  PASS DC10: Love plot excludes post-risk carry-forward rows"
    local ++pass_count
}
else {
    display as error "  FAIL DC10: Love-plot analysis sample (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' DC10"
}

**# DC11: the default Love plot contains balance targets, not numerator covariates

* Stabilized-numerator covariates are deliberately retained in the target
* distribution. Treating them as if weighting were supposed to balance them
* can make a valid stabilized analysis look diagnostically unsuccessful.
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        censor(censored) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) nolog

    * Default: denominator-only targets.
    msm_plot, type(balance)
    matrix DB = r(balance)
    local _default_rows : rownames DB
    assert "`_default_rows'" == "biomarker comorbidity"

    * Explicit requests remain literal, including numerator covariates.
    msm_plot, type(balance) covariates(age sex)
    matrix EB = r(balance)
    local _explicit_rows : rownames EB
    assert "`_explicit_rows'" == "age sex"
    capture graph drop _all
}
if _rc == 0 {
    display as result "  PASS DC11: default Love plot contains only balance targets"
    local ++pass_count
}
else {
    display as error "  FAIL DC11: Love-plot target selection (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' DC11"
}

**# Summary

display as text ""
display as text "{hline 72}"
display as text "Tests run: " as result `test_count'
display as text "Passed:    " as result `pass_count'
display as text "Failed:    " as result `fail_count'
do "`qa_dir'/_record_qa_result.do" test_msm_diagnostic_contracts ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: test_msm_diagnostic_contracts tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    display as text "{hline 72}"
    exit 459
}
display as result "All msm diagnostic-contract tests passed"
display as text "{hline 72}"
