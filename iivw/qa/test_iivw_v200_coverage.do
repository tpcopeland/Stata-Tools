* test_iivw_v200_coverage.do
* Surface introduced in Phases 0-2 that no QA file exercised. Every gap below
* was found by `validate package iivw --view findings` during the Phase 2
* review, not by the implementer.
*
*   R1  _iivw_require_converged errors 430; allownonconverged downgrades it
*   R2  a nonconverged nuisance model SUPPRESSES the balance verdict
*   R3  iivw_fit does not launder the weight-stage nonconverged stamp
*   R4  r(refit_N) / r(refit_n_censrows)          (iivw_balance, Phase 2)
*   R5  r(censor_mode) / r(censor_var)            (iivw_weight,  Phase 1)
*   R6  iivw_exogtest, censor()                   (Phase 1)
*   R7  r(ci_dist_weighted) / r(ci_dist_adjusted) (iivw_diagnose, Phase 2)
*
* R2 and R3 are regressions: before this suite, `allownonconverged` promised the
* fit was "not usable for the automatic diagnostics" while nothing read the
* stamp, and iivw_fit cleared it outright.

clear all
set varabbrev off
version 16.0

capture log close
* Q6: no disposable log in the package tree. This suite used to write
* test_iivw_v200_coverage.log into qa/, which is gitignored but is still ~4 MB of debris carrying the
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

capture program drop _cov_registry
program define _cov_registry
    syntax , [n(integer 250) gamma(real 0.5) tau(real 10) seed(integer 55501)]
    clear
    set seed `seed'
    set obs `n'
    gen long id = _n
    gen double z = rnormal()
    gen double cens = `tau'/2 + (`tau'/2) * runiform()
    expand 40
    bysort id: gen int j = _n
    gen double gap = -ln(runiform()) / (0.6 * exp(`gamma' * z))
    bysort id (j): gen double time = sum(gap)
    keep if time < cens
    drop gap j
    gen double y = 1 + 0.5 * z + rnormal()
end

**# R1 - the convergence guard errors, and allownonconverged downgrades it

local ++test_count
capture noisily {
    * Without the escape hatch: a hard error, not a warning (C9).
    capture _iivw_require_converged, model(test)
    assert _rc == 430

    * With it: the command continues (exit 0) so the caller can proceed.
    capture _iivw_require_converged, model(test) allownonconverged
    assert _rc == 0
}
if _rc == 0 {
    local ++pass_count
    display "PASS R1: convergence guard errors 430; allownonconverged exits 0"
}
else {
    local ++fail_count
    display "FAIL R1: convergence guard"
}

**# R2 - a nonconverged nuisance model suppresses the balance verdict

local ++test_count
capture noisily {
    _cov_registry, n(250) seed(55502)
    quietly iivw_weight, id(id) time(time) visit(z) censor(cens)

    * Baseline: with clean weights the verdict is issued.
    quietly iivw_balance
    assert inlist("`r(balance_flag)'", "good", "poor")
    assert r(refit_ok) == 1

    * Now mark the weights as coming from a nonconverged nuisance model, exactly
    * as iivw_weight ... allownonconverged would. The weights are unchanged; only
    * their provenance is. The verdict must withdraw, because the target-SMD null
    * assumes the visit model solves its estimating equation.
    char _dta[_iivw_nonconverged] "1"
    quietly iivw_balance
    assert "`r(balance_flag)'" == "unknown"
    assert r(refit_ok) == 0
}
if _rc == 0 {
    local ++pass_count
    display "PASS R2: nonconverged weights -> no balance verdict"
}
else {
    local ++fail_count
    display "FAIL R2: nonconverged weights still got a verdict"
}

**# R3 - iivw_fit must not launder the weight-stage nonconverged stamp

local ++test_count
capture noisily {
    _cov_registry, n(250) seed(55503)
    quietly iivw_weight, id(id) time(time) visit(z) censor(cens)
    char _dta[_iivw_nonconverged] "1"

    * A CONVERGED outcome fit must not erase the record that the WEIGHTS are
    * untrustworthy. Before the fix, iivw_fit cleared _iivw_nonconverged in its
    * own char reset loop and the taint vanished silently.
    quietly iivw_fit y z

    local stamp : char _dta[_iivw_nonconverged]
    assert "`stamp'" == "1"

    _iivw_get_settings
    assert "`r(nonconverged)'" == "1"

    * And the verdict stays withdrawn downstream of the fit.
    quietly iivw_balance
    assert "`r(balance_flag)'" == "unknown"
}
if _rc == 0 {
    local ++pass_count
    display "PASS R3: iivw_fit preserves the weight-stage nonconverged stamp"
}
else {
    local ++fail_count
    display "FAIL R3: converged fit laundered the nonconverged weight stamp"
}

**# R4 - r(refit_N) and r(refit_n_censrows)

local ++test_count
capture noisily {
    _cov_registry, n(250) seed(55504)
    quietly iivw_weight, id(id) time(time) visit(z) censor(cens)
    quietly count
    local n_visits = r(N)
    quietly iivw_balance
    local n_ids = r(n_ids)

    * The refit adds one terminal at-risk interval per subject -- that interval
    * is what makes the person-time target computable at all.
    assert r(refit_ok) == 1
    assert r(refit_n_censrows) == `n_ids'

    * Under the default baseline(entry) the first visit is study entry, not a
    * modeled event, so it is dropped from the refit. That drop removes exactly
    * n_ids rows while the expand ADDED exactly n_ids rows, so refit_N lands back
    * on the visit count by pure arithmetic coincidence. Asserting
    * refit_N == n_visits would therefore pass even if the terminal intervals were
    * never built. Pin the signed identity instead.
    assert r(refit_N) == `n_visits' - `n_ids' + r(refit_n_censrows)

    * And break the coincidence: with baseline(event) no entry row is dropped, so
    * the terminal intervals have to show up in refit_N or they are not there.
    _cov_registry, n(250) seed(55504)
    quietly iivw_weight, id(id) time(time) visit(z) censor(cens) baseline(event)
    quietly iivw_balance
    assert r(refit_n_censrows) == `n_ids'
    assert r(refit_N) == `n_visits' + `n_ids'
}
if _rc == 0 {
    local ++pass_count
    display "PASS R4: refit_N = visit rows + one terminal interval per subject"
}
else {
    local ++fail_count
    display "FAIL R4: refit_N / refit_n_censrows"
}

**# R5 - r(censor_mode) and r(censor_var)

local ++test_count
capture noisily {
    _cov_registry, n(250) seed(55505)
    quietly iivw_weight, id(id) time(time) visit(z) censor(cens)
    assert "`r(censor_mode)'" == "censor"
    assert "`r(censor_var)'"  == "cens"

    * maxfu() is the other risk-set mode and must report itself as such.
    _cov_registry, n(250) seed(55505)
    quietly iivw_weight, id(id) time(time) visit(z) maxfu(10)
    assert "`r(censor_mode)'" == "maxfu"
    assert "`r(censor_var)'"  == ""
}
if _rc == 0 {
    local ++pass_count
    display "PASS R5: censor_mode / censor_var report the risk-set spec"
}
else {
    local ++fail_count
    display "FAIL R5: censor_mode / censor_var"
}

**# R6 - iivw_exogtest, censor()

local ++test_count
capture noisily {
    _cov_registry, n(250) seed(55506)
    quietly iivw_weight, id(id) time(time) visit(z) censor(cens)
    iivw_exogtest y, id(id) time(time) censor(cens)
    assert r(n_models) > 0
    assert r(holm_min_p) >= 0 & r(holm_min_p) <= 1
    assert inlist(r(endogenous_flag), 0, 1)
}
if _rc == 0 {
    local ++pass_count
    display "PASS R6: iivw_exogtest accepts censor()"
}
else {
    local ++fail_count
    display "FAIL R6: iivw_exogtest censor()"
}

**# R7 - r(ci_dist_weighted) and r(ci_dist_adjusted)

local ++test_count
capture noisily {
    _cov_registry, n(250) seed(55507)
    quietly iivw_weight, id(id) time(time) visit(z) censor(cens)

    quietly regress y z, vce(cluster id)
    estimates store m_unw
    quietly regress y z [pw=_iivw_weight], vce(cluster id)
    estimates store m_wt
    quietly regress y z time [pw=_iivw_weight], vce(cluster id)
    estimates store m_adj

    iivw_diagnose z, unweighted(m_unw) weighted(m_wt) adjusted(m_adj)

    * Each estimate's interval is built from its OWN reference distribution (H4).
    * regress has finite residual df, so all three must report a t with its df --
    * not a normal. The df is carried in the string, e.g. "t(237)".
    assert substr("`r(ci_dist_unweighted)'", 1, 2) == "t("
    assert substr("`r(ci_dist_weighted)'",   1, 2) == "t("
    assert substr("`r(ci_dist_adjusted)'",   1, 2) == "t("
    assert r(decomposable) == 1
}
if _rc == 0 {
    local ++pass_count
    display "PASS R7: ci_dist_* reported per estimate"
}
else {
    local ++fail_count
    display "FAIL R7: ci_dist_weighted / ci_dist_adjusted"
}

**# R8 - allownonconverged is a strict no-op when the models DO converge

local ++test_count
capture noisily {
    * The option only ever fires through _iivw_require_converged, which is only
    * reached when e(converged)==0 (covered in R1). What must also hold is that
    * merely PASSING it changes nothing when the models converge normally: same
    * weights, and no nonconverged stamp on clean output.
    _cov_registry, n(250) seed(55508)
    quietly iivw_weight, id(id) time(time) visit(z) censor(cens)
    quietly summarize _iivw_weight, meanonly
    local w_plain = r(mean)
    local n_plain = r(N)

    quietly iivw_weight, id(id) time(time) visit(z) censor(cens) ///
        allownonconverged replace
    quietly summarize _iivw_weight, meanonly
    assert r(N) == `n_plain'
    assert reldif(r(mean), `w_plain') < 1e-12

    * A converged fit must NOT be stamped just because the option was offered.
    local stamp : char _dta[_iivw_nonconverged]
    assert "`stamp'" == ""
    quietly iivw_balance
    assert inlist("`r(balance_flag)'", "good", "poor")

    quietly iivw_fit y z, allownonconverged
    local fstamp : char _dta[_iivw_fit_nonconverged]
    assert "`fstamp'" == ""
}
if _rc == 0 {
    local ++pass_count
    display "PASS R8: allownonconverged is a no-op on converging models"
}
else {
    local ++fail_count
    display "FAIL R8: allownonconverged changed a converging fit"
}

**# R9 - iivw_exogtest, maxfu()

local ++test_count
capture noisily {
    _cov_registry, n(250) seed(55509)
    quietly iivw_weight, id(id) time(time) visit(z) maxfu(10)
    iivw_exogtest y, id(id) time(time) maxfu(10)
    assert r(n_models) > 0
    assert r(holm_min_p) >= 0 & r(holm_min_p) <= 1
}
if _rc == 0 {
    local ++pass_count
    display "PASS R9: iivw_exogtest accepts maxfu()"
}
else {
    local ++fail_count
    display "FAIL R9: iivw_exogtest maxfu()"
}

**# R10 - the target SMD must CONVERGE to 0, and the shift must not

local ++test_count
capture noisily {
    * A single-N "|tsmd| < 0.10" assertion cannot distinguish a consistent
    * estimator from one carrying a small systematic bias. If the identity, the
    * Lambda0-at-start LOCF join, or the in/out membership of the terminal
    * at-risk rows were wrong by one interval, |tsmd| would settle on a NONZERO
    * constant while still passing a 0.10 threshold at every N. So assert the
    * residual shrinks. This is the only check here that could have caught a
    * subtly wrong target, and it is deliberately not one the implementer chose.
    * Average over seeds at each N. A SINGLE seed cannot separate noise from bias
    * -- an early draft of this test asserted a 2x drop on one seed and failed on
    * a lucky small-N draw while the estimator was perfectly consistent.
    local tsmd_small = 0
    local shift_small = 0
    local tsmd_big = 0
    local shift_big = 0
    foreach s in 77001 77011 77021 77031 {
        quietly _cov_registry, n(400) seed(`s')
        quietly iivw_weight, id(id) time(time) visit(z) censor(cens)
        quietly iivw_balance
        local tsmd_small = `tsmd_small' + abs(r(balance_max_tsmd)) / 4
        local shift_small = `shift_small' + abs(r(balance_max_shift)) / 4

        quietly _cov_registry, n(6400) seed(`s')
        quietly iivw_weight, id(id) time(time) visit(z) censor(cens)
        quietly iivw_balance
        local tsmd_big = `tsmd_big' + abs(r(balance_max_tsmd)) / 4
        local shift_big = `shift_big' + abs(r(balance_max_shift)) / 4
    }

    * 16x the subjects: 1/sqrt(N) noise should fall by ~4x (measured: 0.0216 ->
    * 0.0056, a 3.9x drop). Require a conservative 2x, which noise clears easily
    * and a systematic bias -- which does not shrink at all -- cannot.
    assert `tsmd_big' < `tsmd_small' / 2
    assert `tsmd_big' < 0.015

    * The composition shift is NOT an error measure: it is what a correct weight
    * DOES to the observed visits, so it must persist at large N. If it shrank,
    * the weights would be doing nothing and the whole diagnostic is vacuous.
    assert `shift_big' > 0.20
    assert reldif(`shift_big', `shift_small') < 0.5
}
if _rc == 0 {
    local ++pass_count
    display "PASS R10: target SMD converges to 0; composition shift persists"
}
else {
    local ++fail_count
    display "FAIL R10: target SMD did not converge (bias, not noise)"
}

**# R11 - a degenerate person-time target must not pass as a confident "good"

local ++test_count
capture noisily {
    * endatlastvisit ends the risk set at each subject's last visit, so there is
    * NO terminal at-risk interval and the person-time target collapses toward
    * the observed visits. |target SMD| then comes out small almost regardless of
    * the weights. The verdict is still self-consistent, but the user must be
    * told the check is weak -- otherwise a degenerate target reads exactly like
    * a strong pass.
    _cov_registry, n(600) seed(77002)
    quietly iivw_weight, id(id) time(time) visit(z) endatlastvisit

    * A NAMED log alongside the suite's own -- never `log close _all', which
    * would close the suite log and silently swallow every later test.
    tempfile r11log
    quietly log using "`r11log'", text replace name(r11cap)
    iivw_balance

    * Grab r() BEFORE closing the log: `log close' is a command like any other and
    * it clears r(). Asserting on r(refit_n_censrows) after the close reads a
    * destroyed return (.), not the command's answer.
    local r11_censrows = r(refit_n_censrows)
    local r11_flag "`r(balance_flag)'"
    capture log close r11cap

    assert `r11_censrows' == 0
    assert "`r11_flag'" != ""

    tempname fh
    local r11_text ""
    file open `fh' using "`r11log'", read text
    file read `fh' line
    while r(eof) == 0 {
        local r11_text `"`r11_text' `macval(line)'"'
        file read `fh' line
    }
    file close `fh'
    assert strpos(`"`r11_text'"', "much weaker than it looks") > 0
}
if _rc == 0 {
    local ++pass_count
    display "PASS R11: degenerate target is flagged as weak, not sold as good"
}
else {
    local ++fail_count
    display "FAIL R11: degenerate person-time target reported without warning"
}

**# Summary

display ""
display "test_iivw_v200_coverage: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_iivw_v200_coverage tests=`test_count' pass=`pass_count' fail=`fail_count'"

capture log close
if `fail_count' > 0 exit 1
