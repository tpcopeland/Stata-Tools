clear all
version 16.0
set varabbrev off

* test_iivw_v196_regressions.do - regressions for v1.9.6 review fixes
*
* Coverage:
*   T1  iivw_diagnose honours `set level' (was hardcoded at 95)
*   T2  iivw_diagnose, level(#) overrides `set level'
*   T3  iivw_diagnose, level(99.99) succeeds (cilevel upper bound)
*   T4  iivw_diagnose, level(9.99) errors (cilevel lower bound, rc 198)
*   T4b iivw_diagnose, level(#) capped at two decimal places (cilevel rule)
*   T5  iivw_diagnose Excel export CI header tracks `set level'
*   T6  iivw_exogtest r(n_ids) sums subjects over fitted by() groups
*   T7  iivw_exogtest r(N) is unaffected: rows partition across by() groups
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_v196_regressions.do

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_v196_regressions.do must be run from iivw/qa"
    exit 198
}
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Three nested models on a fixed dataset: the decomposition inputs are
* deterministic, so the only thing under test is the interval width.
capture program drop _iivw_v196_estimates
program define _iivw_v196_estimates
    version 16.0
    sysuse auto, clear
    quietly regress price mpg
    estimates store m_u
    quietly regress price mpg weight
    estimates store m_w
    quietly regress price mpg weight foreign
    estimates store m_a
end

* Balanced panel with a subject-constant by() variable (arm) and a
* time-varying one (late). Every subject contributes usable lagged
* intervals to both `late' groups, so n_ids must double while N does not.
capture program drop _iivw_v196_panel
program define _iivw_v196_panel
    version 16.0
    clear
    set obs 30
    gen long id = _n
    gen byte arm = mod(id, 2)
    expand 6
    bysort id: gen int visit = _n
    gen double days = visit * 30 + mod(id, 5)
    gen byte late = (visit > 3)
    gen double y = 0.4 * visit + sin(id + visit)
end

**# T1: iivw_diagnose honours `set level'

local ++test_count
capture noisily {
    _iivw_v196_estimates

    set level 90
    quietly iivw_diagnose mpg, unweighted(m_u) weighted(m_w) adjusted(m_a)
    matrix E90 = r(estimates)
    scalar ll90 = E90[1, 3]
    scalar ul90 = E90[1, 4]

    set level 95
    quietly iivw_diagnose mpg, unweighted(m_u) weighted(m_w) adjusted(m_a)
    matrix E95 = r(estimates)
    scalar ll95 = E95[1, 3]
    scalar ul95 = E95[1, 4]
    set level 95

    * A 90% interval must be strictly narrower than the 95% interval.
    assert (ul90 - ll90) < (ul95 - ll95)

    * And it must equal the analytic 90% interval for the same b/se.
    scalar b_u = E90[1, 1]
    scalar se_u = E90[1, 2]
    * H4: regress reports t intervals on e(df_r) residual degrees of freedom.
    * These assertions used to codify the NORMAL limits, which is what
    * iivw_diagnose wrongly applied to every input regardless of estimator: on
    * sysuse auto (df_r = 72) it put the mpg lower limit at -342.9227 where
    * regress itself gives -344.7008. The oracle is now the estimator's own
    * contract, not a normal approximation to it.
    assert reldif(ll90, b_u - invttail(72, 0.05) * se_u) < 1e-10
    assert reldif(ul90, b_u + invttail(72, 0.05) * se_u) < 1e-10
    assert abs(ll90 - (b_u - invnormal(0.95) * se_u)) > 1e-6
}
if _rc == 0 {
    display as result "  PASS: T1 - iivw_diagnose honours set level"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - set level ignored (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

**# T2: explicit level(#) overrides `set level'

local ++test_count
capture noisily {
    _iivw_v196_estimates
    set level 80
    quietly iivw_diagnose mpg, unweighted(m_u) weighted(m_w) adjusted(m_a) level(99)
    matrix E99 = r(estimates)
    set level 95

    scalar b_u = E99[1, 1]
    scalar se_u = E99[1, 2]
    * H4: regress reports t intervals on e(df_r) residual degrees of freedom.
    * These assertions used to codify the NORMAL limits, which is what
    * iivw_diagnose wrongly applied to every input regardless of estimator: on
    * sysuse auto (df_r = 72) it put the mpg lower limit at -342.9227 where
    * regress itself gives -344.7008. The oracle is now the estimator's own
    * contract, not a normal approximation to it.
    assert reldif(E99[1, 3], b_u - invttail(72, 0.005) * se_u) < 1e-10
    assert reldif(E99[1, 4], b_u + invttail(72, 0.005) * se_u) < 1e-10
    assert abs(E99[1, 3] - (b_u - invnormal(0.995) * se_u)) > 1e-6
}
if _rc == 0 {
    display as result "  PASS: T2 - explicit level() overrides set level"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - level() override (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

**# T3: level(99.99) succeeds (cilevel upper bound)

local ++test_count
capture noisily {
    _iivw_v196_estimates
    iivw_diagnose mpg, unweighted(m_u) weighted(m_w) adjusted(m_a) level(99.99)
    assert "`r(coefficient)'" == "mpg"
}
if _rc == 0 {
    display as result "  PASS: T3 - level(99.99) accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - level(99.99) rejected (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

**# T4: level(9.99) errors (cilevel lower bound)

local ++test_count
capture noisily {
    _iivw_v196_estimates
    capture iivw_diagnose mpg, unweighted(m_u) weighted(m_w) adjusted(m_a) level(9.99)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T4 - level(9.99) errors (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - level() lower-bound guard (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

**# T4b: level(#) allows at most two decimal places (cilevel rule)

local ++test_count
capture noisily {
    _iivw_v196_estimates
    * The exact one-SE level, 100*(2*normal(1)-1) = 68.2689..., is now illegal:
    * cilevel caps precision at two decimals, as in every official Stata command.
    capture iivw_diagnose mpg, unweighted(m_u) weighted(m_w) adjusted(m_a) ///
        level(68.268949)
    assert _rc == 198
    iivw_diagnose mpg, unweighted(m_u) weighted(m_w) adjusted(m_a) level(68.27)
    assert "`r(coefficient)'" == "mpg"
}
if _rc == 0 {
    display as result "  PASS: T4b - level() capped at two decimal places"
    local ++pass_count
}
else {
    display as error "  FAIL: T4b - level() precision rule (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4b"
}

**# T5: Excel export CI header tracks `set level'

local ++test_count
capture noisily {
    _iivw_v196_estimates
    tempfile xl
    local xlfile "`xl'.xlsx"

    set level 90
    quietly iivw_diagnose mpg, unweighted(m_u) weighted(m_w) adjusted(m_a) ///
        xlsx("`xlfile'") sheet(L90) replace
    set level 95

    * The CI column header sits at row 3, column E (frame column c3).
    import excel using "`xlfile'", sheet("L90") clear allstring
    local hdr = E[3]
    assert "`hdr'" == "90% CI"

    capture erase "`xlfile'"
}
if _rc == 0 {
    display as result "  PASS: T5 - exported CI header tracks set level"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - export CI header (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5"
}

**# T6: r(n_ids) sums subjects over fitted by() groups

local ++test_count
capture noisily {
    _iivw_v196_panel

    * Subject-constant by(): each subject lands in exactly one group,
    * so the sum equals the distinct subject count.
    quietly iivw_exogtest y, endatlastvisit id(id) time(days) by(arm) generate(a_) nolog
    assert r(n_models) == 2
    assert r(n_ids) == 30

    * H2: a time-varying by() is now REFUSED unless the user asks for
    * start-of-interval semantics. Assigning an interval the group value
    * realized at its own endpoint is end-of-interval conditioning.
    capture iivw_exogtest y, endatlastvisit id(id) time(days) by(late) generate(l_) replace nolog
    assert _rc == 198

    * With bystart, every subject still has usable lagged intervals in both
    * groups, so the documented per-group sum is 2 x 30. This is the contract
    * iivw_exogtest.sthlp describes; it is not a distinct count.
    quietly iivw_exogtest y, endatlastvisit id(id) time(days) by(late) bystart ///
        generate(l_) replace nolog
    assert r(n_models) == 2
    assert r(n_ids) == 60
}
if _rc == 0 {
    display as result "  PASS: T6 - r(n_ids) is a per-group sum, as documented"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - r(n_ids) semantics (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}

**# T7: r(N) partitions across by() groups (no double counting)

local ++test_count
capture noisily {
    _iivw_v196_panel

    * 30 subjects x 6 visits = 180 rows; the first visit per subject has a
    * missing lag, leaving 150 usable intervals regardless of grouping.
    quietly iivw_exogtest y, endatlastvisit id(id) time(days) generate(n_) nolog
    local n_overall = r(N)
    assert `n_overall' == 150

    quietly iivw_exogtest y, endatlastvisit id(id) time(days) by(arm) generate(a_) nolog
    assert r(N) == `n_overall'

    quietly iivw_exogtest y, endatlastvisit id(id) time(days) by(late) bystart ///
        generate(l_) nolog
    assert r(N) == `n_overall'
}
if _rc == 0 {
    display as result "  PASS: T7 - r(N) partitions across by() groups"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - r(N) partitioning (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T7"
}

**# Summary

display as result "Regression results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_iivw_v196_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL IIVW V1.9.6 REGRESSION TESTS PASSED"
display "RESULT: test_iivw_v196_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
