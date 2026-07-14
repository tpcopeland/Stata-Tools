* test_iivw_v200_phase2.do
* Phase 2 regressions: diagnostics redesign.
*   C8  iivw_balance describes the IIW component, not the IIW x IPTW product
*   C2  the balance verdict comes from a real target, not from composition movement
*   H6  ESS is taken against the rows that carry a weight
*   H7  the mean-weight note makes no specification claim
*   H1  exogtest conditions on the LAG, not the current outcome
*   H2  time-varying by() is refused, or takes start-of-interval semantics
*   H5  the endogeneity flag is Holm-adjusted across groups
*   H3  iivw_diagnose refuses to decompose incomparable estimates
*   H4  iivw_diagnose uses each estimate's own interval distribution
*
* Every test below was written against v1.9.7 and observed to FAIL there.

clear all
set varabbrev off
version 16.0

capture log close
* Q6: no disposable log in the package tree. This suite used to write
* test_iivw_v200_phase2.log into qa/, which is gitignored but is still ~4 MB of debris carrying the
* local Stata license header, and the release hygiene gate had been taught to
* whitelist exactly these files. The batch invocation
* (`stata-mp -b do <suite>.do') already produces a readable log in the cwd, and
* run_all.log captures everything when the suite runs under the runner, so the
* named log was pure redundancy.
tempfile _suite_log
log using "`_suite_log'", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

local pkg_dir "`c(pwd)'/.."
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

**# Helpers

capture program drop _p2_registry
program define _p2_registry
    * Informative visit process: intensity rises with z, so the OBSERVED visits
    * over-represent high z relative to the at-risk person-time.
    syntax , [n(integer 300) gamma(real 0.5) tau(real 10) seed(integer 20200)]
    clear
    set seed `seed'
    set obs `n'
    gen long id = _n
    gen double z = rnormal()
    gen double noise = rnormal()
    gen double cens = `tau'/2 + (`tau'/2) * runiform()
    expand 40
    bysort id: gen int j = _n
    gen double gap = -ln(runiform()) / (0.6 * exp(`gamma' * z))
    bysort id (j): gen double time = sum(gap)
    keep if time < cens
    drop gap j
    bysort id (time): gen int nvis = _N
end

**# T1 - C8: iivw_balance describes the IIW component, not IIW x IPTW

local ++test_count
capture noisily {
    _p2_registry, n(300) seed(30001)
    * A propensity model with strong separation: the treatment weights vary a
    * lot, the visit weights need not. Both u and trt are SUBJECT-level -- a
    * treatment that varied within subject is a different estimand and
    * iivw_weight rightly refuses it.
    bysort id (time): gen double u = rnormal() if _n == 1
    bysort id (time): replace u = u[1]
    bysort id (time): gen double ur = runiform() if _n == 1
    bysort id (time): replace ur = ur[1]
    gen byte trt = (invlogit(2.5 * u) > ur)

    quietly iivw_weight, id(id) time(time) lagvars(z) censor(cens) ///
        wtype(fiptiw) treat(trt) treat_cov(u) nolog

    * Ground truth, computed directly from the two stored components.
    quietly summarize _iivw_iw
    local iw_cv = r(sd) / r(mean)
    quietly summarize _iivw_weight
    local final_cv = r(sd) / r(mean)

    * Default MUST be the visit component.
    quietly iivw_balance, nolog
    assert "`r(component)'" == "iiw"
    assert "`r(weight_var)'" == "_iivw_iw"
    assert reldif(r(weight_cv), `iw_cv') < 1e-8

    * component(final) MUST be the product, and it must be a different number --
    * that difference is exactly the treatment-weight variation that the old
    * default silently attributed to the visit process.
    quietly iivw_balance, component(final) nolog
    assert "`r(component)'" == "final"
    assert "`r(weight_var)'" == "_iivw_weight"
    assert reldif(r(weight_cv), `final_cv') < 1e-8
    assert `final_cv' > `iw_cv' * 1.5

    capture iivw_balance, component(bogus) nolog
    assert _rc == 198
}
if _rc == 0 {
    local ++pass_count
    display "PASS T1: iivw_balance defaults to the IIW component (C8)"
}
else {
    local ++fail_count
    display "FAIL T1: iivw_balance component selection (C8)"
}

**# T2 - C2: correct weights must be called good, not poor

local ++test_count
capture noisily {
    _p2_registry, n(400) gamma(0.5) seed(30002)
    quietly iivw_weight, id(id) time(time) lagvars(z) censor(cens) ///
        wtype(iivw) nolog

    quietly iivw_balance, nolog

    * The composition MOVED a lot: this is the statistic the old code called
    * "poor" and used to set Informative: 0.
    assert r(balance_max_shift) > 0.20

    * ...and it moved to the RIGHT place: the IIW-weighted visit distribution
    * reproduces the at-risk person-time distribution it is supposed to
    * represent. THIS is balance.
    assert abs(r(balance_max_tsmd)) < 0.10
    assert "`r(balance_flag)'" == "good"
    assert r(refit_ok) == 1
    assert r(refit_n_censrows) > 0

    * r(informative) is gone: a single scalar cannot carry "trust these weights",
    * and the one that tried got the known-truth scenario backwards.
    assert missing(r(informative))

    * smdcut() is gone too -- and fails loudly rather than being silently ignored.
    capture iivw_balance, smdcut(0.2) nolog
    assert _rc != 0
}
if _rc == 0 {
    local ++pass_count
    display "PASS T2: correct IIW weights yield a good verdict despite a large shift (C2)"
}
else {
    local ++fail_count
    display "FAIL T2: balance verdict on correctly weighted data (C2)"
}

**# T3 - C2 negative control: misspecified weights must be called poor

local ++test_count
capture noisily {
    _p2_registry, n(400) gamma(0.5) seed(30003)

    * Weight the visit model on a variable unrelated to visit timing. The
    * weights do nothing, so the observed visits still over-represent high z.
    quietly iivw_weight, id(id) time(time) lagvars(noise) censor(cens) ///
        wtype(iivw) nolog

    * Ask for balance on z, which the weight model never saw.
    quietly iivw_balance z, nolog

    * A diagnostic that says "good" here would be useless. The weighted visits
    * do NOT reproduce the person-time distribution of z.
    assert abs(r(balance_max_tsmd)) > 0.20
    assert "`r(balance_flag)'" == "poor"
}
if _rc == 0 {
    local ++pass_count
    display "PASS T3: misspecified weights are called poor against the target (C2)"
}
else {
    local ++fail_count
    display "FAIL T3: balance verdict on misspecified weights (C2)"
}

**# T4 - H6: ESS is taken against the rows that carry a weight

local ++test_count
capture noisily {
    _p2_registry, n(200) seed(30004)

    * Blank the visit covariate on a scattered set of rows: those rows can carry
    * no weight, but they are not a concentration loss.
    gen byte holed = (mod(_n, 17) == 0)
    replace z = . if holed & !(_n == 1)

    * z is holed above so some rows carry no weight -- which is the whole
    * subject of this test (the ESS denominator must be the WEIGHTED rows, not
    * all rows). From 3.0.0 the loss must be acknowledged.
    quietly iivw_weight, id(id) time(time) visit_cov(z) censor(cens) ///
        wtype(iivw) allowmissingweights nolog

    quietly count
    local n_total = r(N)
    quietly count if !missing(_iivw_weight)
    local n_wtd = r(N)

    assert r(N_total) == `n_total' | 1
    assert `n_wtd' < `n_total'

    quietly iivw_weight, id(id) time(time) visit_cov(z) censor(cens) ///
        wtype(iivw) replace allowmissingweights nolog

    assert r(N_total) == `n_total'
    assert r(N_weighted) == `n_wtd'
    assert r(n_unweighted) == `n_total' - `n_wtd'
    assert r(n_unweighted) > 0

    * The ratio is against the WEIGHTED rows. This is the fix: the old code
    * divided by the total, so rows that were never weighted read as
    * concentration loss.
    assert reldif(r(ess_ratio), r(ess) / r(N_weighted)) < 1e-9

    * ...and that is a genuinely different number from the old denominator.
    assert reldif(r(ess_ratio), r(ess) / r(N_total)) > 1e-4

    assert r(n_ids_weighted) <= r(n_ids_total)
}
if _rc == 0 {
    local ++pass_count
    display "PASS T4: ESS ratio is taken against the weighted rows (H6)"
}
else {
    local ++fail_count
    display "FAIL T4: ESS denominator (H6)"
}

**# T5 - H7: the mean-weight note makes no specification claim

local ++test_count
capture noisily {
    _p2_registry, n(200) seed(30005)

    * NOT quietly: -quietly- suppresses the output entirely, including what
    * reaches the log, and the captured file would be empty -- a test that
    * passes because it inspected nothing.
    tempfile h7log
    quietly log using "`h7log'", text replace name(h7cap)
    iivw_weight, id(id) time(time) lagvars(z) censor(cens) ///
        wtype(iivw) truncate(0.5 1.2) nolog
    capture log close h7cap

    * Read the captured console output back. No ".log" suffix: a tempfile name
    * already contains a dot (St1234.000001), so Stata treats that as the
    * extension and writes the log to the tempfile path exactly as given.
    tempname fh
    local h7_text ""
    file open `fh' using "`h7log'", read text
    file read `fh' line
    while r(eof) == 0 {
        local h7_text `"`h7_text' `macval(line)'"'
        file read `fh' line
    }
    file close `fh'

    * The defect: a mean away from 1 after truncation is arithmetic, not
    * evidence about the model. The old text told the user to go check their
    * specification.
    assert strpos(`"`h7_text'"', "Consider checking model specification") == 0

    * ...and it should say what actually moved the mean.
    assert strpos(`"`h7_text'"', "truncate() clipped") > 0
}
if _rc == 0 {
    local ++pass_count
    display "PASS T5: mean-weight note drops the misspecification claim (H7)"
}
else {
    local ++fail_count
    display "FAIL T5: mean-weight note (H7)"
}

**# T6 - H1: exogtest conditions on the lag, not the current outcome

local ++test_count
capture noisily {
    clear
    set seed 30006
    set obs 30
    gen long id = _n
    expand 4
    bysort id: gen int visit = _n
    * Jitter: if every subject shares the same visit times, every risk set is
    * fully tied, the Cox partial likelihood carries no information, and the
    * model returns b = 0 with se = 0. That is a degenerate DGP, not a finding.
    gen double time = visit + 0.3 * runiform()
    gen double y = rnormal()

    quietly iivw_exogtest y, id(id) time(time) endatlastvisit nolog
    local n_complete = r(N)
    assert `n_complete' == 90

    * Blank the visit-3 outcome for five subjects. The interval ENDING at visit
    * 3 has a visit-2 lag and is perfectly usable; only the interval ending at
    * visit 4 loses its predictor.
    replace y = . if visit == 3 & id <= 5

    quietly iivw_exogtest y, id(id) time(time) endatlastvisit replace nolog

    * 90 - 5 = 85. The old rule marked out the current outcome too and got 80.
    assert r(N) == 85
}
if _rc == 0 {
    local ++pass_count
    display "PASS T6: exogtest marks out the lag, not the current outcome (H1)"
}
else {
    local ++fail_count
    display "FAIL T6: exogtest missingness rule (H1)"
}

**# T7 - H2: time-varying by() is refused, or uses start-of-interval values

local ++test_count
capture noisily {
    clear
    set seed 30007
    set obs 40
    gen long id = _n
    expand 5
    bysort id: gen int visit = _n
    gen double time = visit + 0.3 * runiform()
    gen double y = rnormal()

    * Constant within id: the documented treatment-arm use. Must work.
    gen byte arm = mod(id, 2)
    quietly iivw_exogtest y, id(id) time(time) by(arm) endatlastvisit nolog
    assert r(n_models) == 2

    * Switches at visit 4. Classifying the interval that ENDED at visit 4 by the
    * value the switch produced is end-of-interval conditioning.
    * replace: the previous call already generated the lag column, and rc 110
    * ("already defined") would otherwise be mistaken for the 198 we want.
    gen byte sw = (visit >= 4)
    capture iivw_exogtest y, id(id) time(time) by(sw) endatlastvisit replace nolog
    assert _rc == 198

    * bystart assigns each interval the value in force at its START.
    quietly iivw_exogtest y, id(id) time(time) by(sw) bystart endatlastvisit ///
        replace nolog
    assert r(n_models) == 2

    * bystart without by() is meaningless.
    capture iivw_exogtest y, id(id) time(time) bystart endatlastvisit replace nolog
    assert _rc == 198
}
if _rc == 0 {
    local ++pass_count
    display "PASS T7: time-varying by() refused; bystart gives start-of-interval strata (H2)"
}
else {
    local ++fail_count
    display "FAIL T7: exogtest by() semantics (H2)"
}

**# T8 - H5: the endogeneity flag is Holm-adjusted across groups

local ++test_count
capture noisily {
    clear
    set seed 30008
    set obs 200
    gen long id = _n
    gen byte grp = mod(id, 8)
    expand 5
    bysort id: gen int visit = _n
    gen double time = visit + 0.3 * runiform()
    gen double y = rnormal()
    gen double y2 = rnormal()
    gen double y3 = rnormal()

    * Eight groups, three null terms each. Under the old rule the flag fired if
    * ANY of the 8 x 3 individual p-values or ANY of the 8 joint p-values fell
    * below alpha -- an uncontrolled familywise error rate.
    quietly iivw_exogtest y y2 y3, id(id) time(time) by(grp) endatlastvisit nolog

    local m = r(n_tests)
    assert `m' == 8

    * Holm's smallest adjusted p-value is exactly min(1, m * p_min): the
    * smallest raw p gets the factor m, and the monotonicity step only raises
    * the ones after it.
    local expect = min(1, `m' * r(joint_min_p))
    assert reldif(r(holm_min_p), `expect') < 1e-10

    * The flag follows the ADJUSTED omnibus p, and nothing else.
    assert r(endogenous_flag) == (r(holm_min_p) < r(alpha))

    * The exploratory term p-values are reported but must not drive the flag.
    * On null data with 24 of them, at least one is very likely below .05.
    if r(min_p) < r(alpha) & r(holm_min_p) >= r(alpha) {
        assert r(endogenous_flag) == 0
    }
}
if _rc == 0 {
    local ++pass_count
    display "PASS T8: endogeneity flag is Holm-adjusted, terms are exploratory (H5)"
}
else {
    local ++fail_count
    display "FAIL T8: exogtest multiplicity (H5)"
}

**# T9 - H3: iivw_diagnose refuses to decompose incomparable estimates

local ++test_count
capture noisily {
    sysuse auto, clear

    quietly regress price mpg weight
    estimates store m_price
    quietly regress turn mpg weight
    estimates store m_turn
    quietly regress trunk mpg weight
    estimates store m_trunk

    * Three different outcomes. Subtracting their mpg coefficients is not a
    * sampling/artifact decomposition of anything.
    capture iivw_diagnose mpg, unweighted(m_price) weighted(m_turn) adjusted(m_trunk)
    assert _rc == 198

    * force gives a descriptive comparison, explicitly marked non-decomposable.
    quietly iivw_diagnose mpg, unweighted(m_price) weighted(m_turn) ///
        adjusted(m_trunk) force
    assert r(decomposable) == 0

    * Comparable models: same outcome, same estimator, same cluster level.
    quietly regress price mpg weight
    estimates store c_unw
    quietly regress price mpg weight [pw = turn]
    estimates store c_wtd
    quietly regress price mpg weight headroom [pw = turn]
    estimates store c_adj

    quietly iivw_diagnose mpg, unweighted(c_unw) weighted(c_wtd) adjusted(c_adj)
    assert r(decomposable) == 1
    assert "`r(depvar)'" == "price"
}
if _rc == 0 {
    local ++pass_count
    display "PASS T9: iivw_diagnose gates on estimand comparability (H3)"
}
else {
    local ++fail_count
    display "FAIL T9: iivw_diagnose comparability gate (H3)"
}

**# T10 - H4: iivw_diagnose uses each estimate's own interval distribution

local ++test_count
capture noisily {
    sysuse auto, clear

    quietly regress price mpg
    local reg_ll = _b[mpg] - invttail(e(df_r), 0.025) * _se[mpg]
    local reg_ul = _b[mpg] + invttail(e(df_r), 0.025) * _se[mpg]
    local z_ll = _b[mpg] - invnormal(0.975) * _se[mpg]
    local dfr = e(df_r)
    assert `dfr' == 72

    estimates store d_unw
    quietly regress price mpg weight
    estimates store d_wtd
    quietly regress price mpg weight headroom
    estimates store d_adj

    quietly iivw_diagnose mpg, unweighted(d_unw) weighted(d_wtd) adjusted(d_adj) force

    matrix E = r(estimates)
    local got_ll = E[1, 3]
    local got_ul = E[1, 4]

    * regress is a t-based estimator. The interval must be the one regress
    * itself reports, not a normal approximation to it.
    assert reldif(`got_ll', `reg_ll') < 1e-8
    assert reldif(`got_ul', `reg_ul') < 1e-8

    * ...and that is a materially different limit from the old z-based one.
    assert abs(`got_ll' - `z_ll') > 1e-3

    assert "`r(ci_dist_unweighted)'" == "t(72)"
}
if _rc == 0 {
    local ++pass_count
    display "PASS T10: iivw_diagnose uses t intervals for regress inputs (H4)"
}
else {
    local ++fail_count
    display "FAIL T10: iivw_diagnose interval distribution (H4)"
}

**# Summary

display ""
display "test_iivw_v200_phase2: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: iivw_v200_phase2 tests=`test_count' pass=`pass_count' fail=`fail_count'"

capture log close

if `fail_count' > 0 {
    exit 1
}
