clear all
version 16.0
set varabbrev off

* test_iivw_failclosed.do - Gate 4 probes: diagnostics must fail closed
*
* Covers audit findings SOL-05, SOL-07, SOL-08, SOL-11.
*
* Every probe here was written to FAIL against the pre-fix build. A probe that
* is green both before and after the fix is not evidence, so the pre-fix score
* is recorded in qa/README.md alongside the post-fix score.
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_failclosed.do

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_failclosed.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"
local repo_dir "`r(repo_dir)'"
ado dir
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace
discard

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* _fc_panel -- recurrent-visit panel with a visit-intensity covariate z, a
* separate outcome covariate x, and administrative censoring.
capture program drop _fc_panel
program define _fc_panel
    version 16.0
    syntax , [n(integer 250) gamma(real 0.5) tau(real 10) seed(integer 77101)]
    clear
    set seed `seed'
    set obs `n'
    gen long id = _n
    gen double z = rnormal()
    gen double x = rnormal()
    gen double cens = `tau'/2 + (`tau'/2) * runiform()
    expand 40
    bysort id: gen int j = _n
    gen double gap = -ln(runiform()) / (0.6 * exp(`gamma' * z))
    bysort id (j): gen double time = sum(gap)
    keep if time < cens
    drop gap j
    gen double y = 1 + 0.5 * x + 0.3 * z * time + rnormal()
end

**# S5a - stabcov() satisfied only by an interaction is refused (SOL-05)

* z enters the outcome design ONLY as z x time. At time == 0 the design cannot
* recover z, so a numerator stabilized on z is not a function of what this model
* conditions on. The pre-fix guard put interaction() into design_sources and
* certified this as validated.
local ++test_count
capture noisily {
    _fc_panel, n(250) seed(77101)
    quietly iivw_weight, id(id) time(time) visit(z) censor(cens) stabcov(z)

    capture iivw_fit y x, interaction(z) vce(fixed)
    local _rc_ixonly = _rc
    assert `_rc_ixonly' == 198
}
if _rc == 0 {
    local ++pass_count
    display "PASS S5a: interaction-only stabcov() is refused"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S5a"
    display "FAIL S5a: interaction-only stabcov() was accepted (rc=`_rc_ixonly')"
}

**# S5b - positive control: a genuine main effect still validates (SOL-05)

* Same stabcov(z), but now z is a main effect in the outcome model as well as an
* interaction source. This must still be accepted, or S5a would merely prove the
* guard rejects everything.
local ++test_count
capture noisily {
    _fc_panel, n(250) seed(77101)
    quietly iivw_weight, id(id) time(time) visit(z) censor(cens) stabcov(z)

    quietly iivw_fit y x z, interaction(z) vce(fixed)
    assert e(iivw_stabilization_validated) == 1
}
if _rc == 0 {
    local ++pass_count
    display "PASS S5b: main-effect stabcov() still validates"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S5b"
    display "FAIL S5b: main-effect stabcov() was rejected"
}

**# S7a - equal N, different people is not a decomposition (SOL-07)

* The pre-fix H3 gate compared e(N). Two 52-observation samples over different
* people have the same N, and returned decomposable == 1.
*
* NOT `if _n <= 52': sysuse auto is stored sorted by foreign, so the first 52
* rows ARE foreign == 0 and the fixture cannot distinguish equal-N from
* equal-sample. `if _n > 22' is also 52 rows and differs from foreign == 0 in
* 44 of them -- verified in the probe below before the assertion.
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly count if foreign == 0
    assert r(N) == 52
    quietly count if (foreign == 0) != (_n > 22)
    assert r(N) > 0

    quietly regress price mpg weight if foreign == 0
    estimates store d_unw
    quietly regress price mpg weight if _n > 22
    estimates store d_wt
    quietly regress price mpg weight if foreign == 0
    estimates store d_adj

    capture iivw_diagnose mpg, unweighted(d_unw) weighted(d_wt) adjusted(d_adj)
    local _rc_eqn = _rc
    assert `_rc_eqn' == 198

    * force still gives a labelled descriptive comparison.
    quietly iivw_diagnose mpg, unweighted(d_unw) weighted(d_wt) ///
        adjusted(d_adj) force
    assert r(decomposable) == 0
    assert r(sample_identical) == 0
}
if _rc == 0 {
    local ++pass_count
    display "PASS S7a: equal-N-different-people is refused"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S7a"
    display "FAIL S7a: equal-N-different-people decomposed (rc=`_rc_eqn')"
}

**# S7b - positive control: identical samples still decompose (SOL-07)

local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store c_unw
    quietly regress price mpg weight [pw = turn]
    estimates store c_wt
    quietly regress price mpg weight headroom [pw = turn]
    estimates store c_adj

    quietly iivw_diagnose mpg, unweighted(c_unw) weighted(c_wt) adjusted(c_adj)
    assert r(decomposable) == 1
    assert r(sample_identical) == 1

    * The per-role sample sizes are what the marker check is built on, so they
    * must be present and agree with each other on an identical-sample fit.
    assert r(n_sample_unweighted) == 74
    assert r(n_sample_weighted)   == 74
    assert r(n_sample_adjusted)   == 74
    assert "`r(noncollapsible)'" == ""
}
if _rc == 0 {
    local ++pass_count
    display "PASS S7b: identical samples still decompose"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S7b"
    display "FAIL S7b: identical-sample decomposition regressed"
}

**# S7c - a nonlinear link is not decomposable (SOL-07)

* Under randomization the true artifact gap is zero, but logit is noncollapsible
* so adding a covariate moves the coefficient anyway. The pre-fix build reported
* that movement as artifact share 1.0 with decomposable == 1.
local ++test_count
capture noisily {
    clear
    set seed 77103
    set obs 4000
    gen byte trt = runiform() < 0.5
    gen double u = rnormal()
    gen byte outc = runiform() < invlogit(-0.5 + 0.4 * trt + 1.5 * u)

    quietly logit outc trt
    estimates store g_unw
    quietly logit outc trt
    estimates store g_wt
    quietly logit outc trt u
    estimates store g_adj

    quietly iivw_diagnose trt, unweighted(g_unw) weighted(g_wt) adjusted(g_adj)
    assert r(decomposable) == 0
    assert "`r(noncollapsible)'" != ""
}
if _rc == 0 {
    local ++pass_count
    display "PASS S7c: nonlinear link is marked non-decomposable"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S7c"
    display "FAIL S7c: nonlinear link decomposed as if collapsible"
}

**# S7d - min/max of three coefficients is a range, not a bound (SOL-07)

local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store c_unw
    quietly regress price mpg weight [pw = turn]
    estimates store c_wt
    quietly regress price mpg weight headroom [pw = turn]
    estimates store c_adj

    quietly iivw_diagnose mpg, unweighted(c_unw) weighted(c_wt) adjusted(c_adj)
    matrix D = r(decomp)
    local _rn : rownames D
    assert strpos("`_rn'", "range_min") > 0
    assert strpos("`_rn'", "range_max") > 0
    assert strpos("`_rn'", "bounds_lower") == 0
    assert strpos("`_rn'", "bounds_upper") == 0
}
if _rc == 0 {
    local ++pass_count
    display "PASS S7d: decomp reports a range, not a partial-identification bound"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S7d"
    display "FAIL S7d: decomp still labels min/max as bounds"
}

**# S8a - a suppressed joint test is unknown, not "no evidence" (SOL-08)

* local group_sig = (joint_p < alpha) sent a MISSING joint p down the reassuring
* branch. A group whose omnibus test could not be computed must be reported as
* unknown and must not feed the overall flag.
local ++test_count
capture noisily {
    _fc_panel, n(200) seed(77104)
    quietly iivw_weight, id(id) time(time) visit(z) censor(cens)

    quietly iivw_exogtest y, id(id) time(time) censor(cens) nolog
    local _n_unknown = r(n_unknown)
    assert `_n_unknown' < .
    assert r(history_association_flag) < .
}
if _rc == 0 {
    local ++pass_count
    display "PASS S8a: exogtest reports an unknown-group count and a renamed flag"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S8a"
    display "FAIL S8a: exogtest has no unknown state / flag not renamed"
}

**# S8b - a nonconverged Cox fit is not silently counted (SOL-08)

* set maxiter 1 stops stcox at the iteration ceiling. It returns rc 0 with
* e(converged) == 0, so the pre-fix build counted the group as fitted and read
* its p-value as if the model had converged.
*
* maxiter is restored BEFORE the assertions: a `set' between the run and the
* verdict resets _rc and would make this probe pass unconditionally.
*
* The single group here is the only group, so once it is ruled unknown the
* command has no valid test left and fails closed with r(2000) rather than
* returning a flag of 0.
*
* The control is the SAME fixture and the SAME call at the default maxiter: it
* must return rc 0, a nonmissing flag, and n_unknown == 0. Only the iteration
* ceiling differs between the two runs, so a fixture that broke for an
* unrelated reason would fail the control instead of quietly satisfying the
* probe. Asserting a bare "rc != 0" alone would not carry that.
local ++test_count
capture noisily {
    _fc_panel, n(120) seed(77105)
    quietly iivw_weight, id(id) time(time) visit(z) censor(cens)

    * Control: converges, so the group is interpretable.
    quietly iivw_exogtest y, id(id) time(time) censor(cens) nolog replace
    assert r(n_unknown) == 0
    assert r(history_association_flag) < .

    local _maxiter_orig = c(maxiter)
    set maxiter 1
    capture quietly iivw_exogtest y, id(id) time(time) censor(cens) nolog replace
    local _s8b_rc   = _rc
    local _s8b_flag = r(history_association_flag)
    set maxiter `_maxiter_orig'

    assert `_s8b_rc' == 2000
    assert `_s8b_flag' >= .

    * A group ruled unknown is named, not just counted. by() gives a run that
    * survives to the return block so unknown_label_# can be read.
    _fc_panel, n(200) seed(77105)
    quietly iivw_weight, id(id) time(time) visit(z) censor(cens)
    quietly generate byte grp = mod(id, 2)
    quietly iivw_exogtest y, id(id) time(time) censor(cens) by(grp) nolog replace
    assert r(n_unknown) < .
    if r(n_unknown) >= 1 {
        assert `"`r(unknown_label_1)'"' != ""
    }
}
if _rc == 0 {
    local ++pass_count
    display "PASS S8b: nonconverged group is reported unknown"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S8b"
    display "FAIL S8b: nonconverged group counted as a valid test"
}

**# S11a - balance replay reproduces the stored weights (SOL-11)

* iivw_balance recomputes exp(-xb) from the stored visit-model specification.
* Nothing tested that this replay agrees with the weight iivw_weight actually
* committed after the SOL-01 normalization change.
local ++test_count
capture noisily {
    _fc_panel, n(250) seed(77106)
    quietly iivw_weight, id(id) time(time) visit(z) censor(cens)

    quietly iivw_balance, nolog
    assert r(replay_max_reldif) < 1e-8
    * replay_scale separates a normalization-convention mismatch from a
    * specification mismatch; it must be present and finite either way.
    assert r(replay_scale) < .
    assert r(replay_scale) > 0
}
if _rc == 0 {
    local ++pass_count
    display "PASS S11a: replay agrees with the stored weights"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S11a"
    display "FAIL S11a: replay/stored weight agreement is untested or violated"
}

**# S11b - if/in reports one weight system, and says which (SOL-11)

local ++test_count
capture noisily {
    _fc_panel, n(250) seed(77106)
    quietly iivw_weight, id(id) time(time) visit(z) censor(cens)

    quietly iivw_balance if z > 0, nolog
    assert "`r(replay_mode)'" == "stored"
    assert r(replay_max_reldif) < 1e-8
    assert r(N) < r(N_replay)
}
if _rc == 0 {
    local ++pass_count
    display "PASS S11b: if/in restricts the report, not the weight system"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S11b"
    display "FAIL S11b: if/in mixes two weight systems"
}

**# S11c - no terminal at-risk interval means the target is not identified

local ++test_count
capture noisily {
    _fc_panel, n(250) seed(77107)
    quietly iivw_weight, id(id) time(time) visit(z) endatlastvisit

    quietly iivw_balance, nolog
    assert "`r(target_status)'" == "not_identified"
    assert "`r(balance_flag)'" == "" | "`r(balance_flag)'" == "not_identified"
}
if _rc == 0 {
    local ++pass_count
    display "PASS S11c: no terminal interval withdraws the verdict"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S11c"
    display "FAIL S11c: verdict issued with no identified target"
}

**# S11d - a nonconverged balance replay withdraws the verdict (SOL-11)

* The three stcox refits inside iivw_balance were checked for _rc only, and
* stcox returns rc 0 when it stops at the iteration ceiling. A replay that
* solves nothing produced an exp(-xb) that the target SMD -- and the printed
* verdict -- were computed from, with no qualification anywhere in the output.
*
* Control first, at the default maxiter: same fixture, same call, must produce
* an identified target and a real verdict. Only the ceiling differs.
local ++test_count
capture noisily {
    _fc_panel, n(250) seed(77108)
    quietly iivw_weight, id(id) time(time) visit(z) censor(cens)

    quietly iivw_balance, nolog
    assert "`r(target_status)'" == "identified"
    assert inlist("`r(balance_flag)'", "within_rule", "exceeds_rule")

    local _maxiter_orig = c(maxiter)
    set maxiter 1
    capture quietly iivw_balance, nolog
    local _s11d_rc     = _rc
    local _s11d_flag   = "`r(balance_flag)'"
    local _s11d_status = "`r(target_status)'"
    local _s11d_ok     = r(refit_ok)
    set maxiter `_maxiter_orig'

    * The command still returns (leverage and shift do not depend on the
    * refit), but the verdict is withdrawn rather than computed from a model
    * that never converged.
    assert `_s11d_rc' == 0
    assert `_s11d_ok' == 0
    assert "`_s11d_status'" == "unavailable"
    assert "`_s11d_flag'" == "unknown"
}
if _rc == 0 {
    local ++pass_count
    display "PASS S11d: nonconverged replay withdraws the balance verdict"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S11d"
    display "FAIL S11d: verdict computed from a nonconverged replay"
}

**# S12a - one-sided trimming is expressible (SOL-12)

* trunc*() required two percentiles strictly inside (0, 100), so Tompkins et
* al. (2025, section 4.4) literal upper-95th rule could not be written at all
* and anyone following the paper had to invent a lower cut it never asked for.
* 0 and 100 now mean "no trim on that side": p0 is the sample minimum and p100
* its maximum, so clipping there is exactly a no-op.
local ++test_count
capture noisily {
    _fc_panel, n(250) seed(77109)
    quietly iivw_weight, id(id) time(time) visit(z) censor(cens) truncvisit(0 95)
    assert r(trunc_visit_lo) >= .
    assert r(trunc_visit_hi) < .

    * Upper tail clipped, lower tail untouched: the minimum must survive.
    quietly summarize _iivw_iw_raw, meanonly
    local _raw_min = r(min)
    quietly summarize _iivw_iw, meanonly
    assert reldif(r(min), `_raw_min') < 1e-12
    assert r(max) < .

    * A request that trims nothing is refused rather than silently accepted.
    _fc_panel, n(120) seed(77109)
    capture quietly iivw_weight, id(id) time(time) visit(z) censor(cens) ///
        truncvisit(0 100)
    assert _rc == 198
    capture quietly iivw_weight, id(id) time(time) visit(z) censor(cens) ///
        truncvisit(-1 95)
    assert _rc == 198
}
if _rc == 0 {
    local ++pass_count
    display "PASS S12a: one-sided trimming works and no-op/out-of-range are refused"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S12a"
    display "FAIL S12a: one-sided trimming rejected or mis-applied"
}

**# S12b - a one-sided cutpoint does not wipe the balance replay (SOL-12)

* The replay clips at the STORED cutpoints. With one side missing, an
* unguarded `w < .' comparison is true for every nonmissing value and would
* replace the whole weight column with missing -- silently, at rc 0. The
* replay-vs-stored check is the probe that can see it.
local ++test_count
capture noisily {
    _fc_panel, n(250) seed(77110)
    quietly iivw_weight, id(id) time(time) visit(z) censor(cens) truncvisit(0 95)

    quietly iivw_balance, nolog
    assert r(replay_n) > 0
    assert r(replay_max_reldif) < 1e-8
    assert r(weight_cv) < .
    assert r(ess) > 0
}
if _rc == 0 {
    local ++pass_count
    display "PASS S12b: one-sided cutpoint survives the balance replay"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S12b"
    display "FAIL S12b: one-sided cutpoint corrupts the balance replay"
}

**# S13a - concentration is reported at both units (SOL-13)

* The Kish ESS was computed on panel ROWS and labelled as if it described the
* analysis. Inference is clustered on the subject, so the two measures answer
* different questions and can disagree; the cluster-level one was absent.
local ++test_count
capture noisily {
    _fc_panel, n(250) seed(77111)
    quietly iivw_weight, id(id) time(time) visit(z) censor(cens)
    quietly iivw_balance, nolog

    assert r(ess_cluster) < .
    assert r(ess_cluster_ratio) < .
    assert r(ess_cluster_ratio) > 0 & r(ess_cluster_ratio) <= 1
    assert r(ess_cluster) <= r(n_ids) + 1e-8

    * The two ESS measures are computed on different units, so the cluster one
    * must be bounded by the cluster count, not by the row count.
    assert r(ess) <= r(N) + 1e-8
    assert r(n_ids) < r(N)
}
if _rc == 0 {
    local ++pass_count
    display "PASS S13a: row and cluster concentration both reported"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S13a"
    display "FAIL S13a: cluster-level concentration missing or malformed"
}

**# S13b - extreme propensity scores are counted in subjects (SOL-13)

* The propensity model is fitted once per subject and merged m:1 onto the
* panel, so counting ROWS multiplied every extreme subject by their visit
* count and reported a far larger overlap problem than the data contain.
local ++test_count
capture noisily {
    clear
    set seed 77112
    set obs 300
    gen long id = _n
    gen double zt = rnormal()
    * A strong treatment model drives some propensities past 0.01/0.99.
    gen byte trt = runiform() < invlogit(4 * zt)
    gen double cens = 5 + 5 * runiform()
    expand 30
    bysort id: gen int j = _n
    gen double gap = -ln(runiform()) / 0.6
    bysort id (j): gen double time = sum(gap)
    keep if time < cens
    drop gap j
    gen double y = zt + rnormal()

    quietly iivw_weight, id(id) time(time) visit(zt) censor(cens) ///
        treat(trt) treat_cov(zt) nolog
    assert r(n_ps_extreme_id) < .
    assert r(n_ps_extreme_id) >= 1
    * Rows must exceed subjects on a multi-visit panel, which is exactly the
    * inflation the old row-only count reported as an overlap problem.
    assert r(n_ps_extreme) > r(n_ps_extreme_id)
    assert r(n_ps_extreme_id) <= 300
}
if _rc == 0 {
    local ++pass_count
    display "PASS S13b: extreme propensities counted in subjects"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S13b"
    display "FAIL S13b: extreme propensity count is row-inflated"
}

**# S17 - the cluster-nesting guard is LIVE, not dead code (SOL-17 disproven)

* Audit finding SOL-17 asserted that iivw_fit.ado's nesting/new-ID machinery
* for higher-level clusters is dead, because help and README call such clusters
* unsupported, and recommended deleting the branch.
*
* That is a misreading of the two guards, which cover different paths:
*   - the refitweights guard rejects cluster() != panel id, because the refit
*     bootstrap resamples at the subject level by construction;
*   - the nesting guard fires for a NON-refit bootstrap, where a different
*     cluster() IS supported and documented (iivw_fit.sthlp, "clustering at the
*     clinic level").
*
* Both arms below were run against the shipped build before this test was
* written: clinic-level clustering returns rc 0 with e(clustvar) == clinic, and
* a subject spanning two clinics errors 459. Deleting the branch would remove
* the only thing stopping an incoherent resampling scheme -- a subject split
* across clusters is silently halved by one draw and duplicated by another --
* from being reported as a valid interval.
*
* This test exists so the deletion cannot be re-proposed without a failure.
local ++test_count
capture noisily {
    clear
    set seed 77113
    set obs 150
    gen long id = _n
    gen double z = rnormal()
    gen double x = rnormal()
    gen byte clinic = mod(_n, 10) + 1
    gen double cens = 5 + 5 * runiform()
    expand 25
    bysort id: gen int j = _n
    gen double gap = -ln(runiform()) / (0.6 * exp(0.4 * z))
    bysort id (j): gen double time = sum(gap)
    keep if time < cens
    drop gap j
    gen double y = 1 + 0.5 * x + rnormal()
    quietly iivw_weight, id(id) time(time) visit(z) censor(cens)

    * Nested subject-within-clinic: a supported, documented path.
    quietly iivw_fit y x, bootstrap(30) cluster(clinic) nolog
    assert "`e(clustvar)'" == "clinic"
    assert e(N_clust) == 10

    * Subject spanning two clinics: refused, and refused for this reason.
    quietly replace clinic = clinic + 1 if mod(_n, 7) == 0
    capture quietly iivw_fit y x, bootstrap(30) cluster(clinic) nolog replace
    assert _rc == 459
}
if _rc == 0 {
    local ++pass_count
    display "PASS S17: cluster-nesting guard is live and discriminating"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S17"
    display "FAIL S17: cluster-nesting path broken or removed"
}

**# SUMMARY

* The shared summary emits the RESULT: shape qa/README.md documents and that
* test_iivw_v200_phase3b Q7 enforces, and it fails closed on counter corruption
* or a zero-executed run.
iivw_qa_summary, name(test_iivw_failclosed) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests("`failed_tests'")
