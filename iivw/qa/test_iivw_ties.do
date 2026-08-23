clear all
version 16.0
set varabbrev off

* test_iivw_ties.do - the tie-density axis of the Andersen-Gill visit model
* Tests: 8
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_ties.do        Run all tests
*   stata-mp -b do test_iivw_ties.do 3      Run only test 3
*
* WHAT THIS SUITE IS FOR
* ----------------------
* UPDATED FOR 3.0.0: Efron is now the package default and `breslow' is the
* opt-out, so every arm of this suite that must PRINT the note asks for
* `breslow' explicitly. The note's firing rule inverted with the default; the
* MEASUREMENT axis this suite owns did not change at all, which is why the
* returns assertions below are untouched. The default axis itself is owned by
* test_iivw_tie_default.do.
*
* Through 2.4.x, stcox's default tie method is Breslow, and both iivw_weight and
* iivw_exogtest inherited it. Breslow and Efron agree EXACTLY when no two events
* share a time, and diverge as tie MULTIPLICITY grows -- the mean number of
* modeled events per distinct event time. Every IIW weight is exp(-xb) from
* that fit, so the divergence does not stay in the visit model: it rescales the
* whole weighted analysis.
*
* Measured on a known-truth DGP (true gamma = 0.8; 300 subjects; 25 reps),
* rounding visit times onto a grid of width g:
*
*   g          events/distinct time   gamma Breslow   gamma Efron   rel. gap
*   (none)                     1.00          0.7687        0.7687       0.0%
*   0.10                      20.00          0.7069        0.7580       6.7%
*   0.50                      79.28          0.5385        0.7011      23.2%
*   1.00                     126.48          0.4051        0.6151      34.1%
*   2.00                     180.29          0.2421        0.4565      47.0%
*
* THE BLIND AXIS THIS SUITE CLOSES
* --------------------------------
* Before 2.4.0 the package had no tie axis at all. `efron' appeared in ten QA
* files, but every call that actually passed it to iivw_weight was either a
* crossval reproducing R (crossval_iivw.do, whose own comment says "Efron
* ties, which is coxph's default and stcox's efron option") or an unrelated
* adversarial case. NOTHING compared the two methods on one fixture, and
* nothing asserted anything about what the DEFAULT does to gamma-hat. The
* axis the suite lived on was "does the construction reproduce the reference
* WHEN TOLD TO"; the axis the user lives on is "what do I get when I don't
* type efron". A ~50% attenuation shipped green through that gap.
*
* SCORE AGAINST THE 2.3.1 BUILD -- MEASURED, and it corrected me twice
* ---------------------------------------------------------------------
* Run as written against a git-archived 2.3.1 tree: 6 FAIL, 2 PASS.
*   FAIL: T1 T2 T3 T4 T6 T8      PASS: T5 T7
*
* The first draft of this suite scored 5/3 and its header predicted 6/2 with a
* DIFFERENT membership. Both discrepancies were real defects in the tests, not
* bookkeeping:
*
* 1. T4 passed VACUOUSLY on 2.3.1. It read three absent returns into locals and
*    compared them against three absent returns. In Stata `. == .' is TRUE and
*    reldif(., .) is 0 (measured, not recalled), so all three comparisons
*    succeeded while proving nothing whatever. T4 now asserts PRESENCE
*    (`< .', `> 0') before it compares anything, and fails on 2.3.1.
* 2. `assert r(tie_multiplicity) > 2' is satisfied by a MISSING return, since
*    missing sorts above every number. T1 and T6 both carried that form. Only
*    an unrelated assertion ordering made them fail on 2.3.1 rather than pass
*    for the wrong reason. Every such comparison is now `> 2 & < .'.
*
* T5 passing on both builds is CORRECT and deliberate: it asserts a property of
* the shipped weight column (Breslow attenuates relative to Efron when tied,
* and the two agree exactly when untied). 2.4.0 changed no numerics, so that
* property must be identical on both builds. T5 is the characterization test
* that establishes WHY the note is worth printing; it is not evidence of the
* fix, and it would be a red flag if it ever started failing.
*
* THREE WAYS THIS SUITE COULD BE FALSELY GREEN, AND WHAT ANSWERS EACH
* -------------------------------------------------------------------
* 1. "Always warn" would pass every note-fires test. T3 and T8(a) are the
*    POSITIVE CONTROLS against that: on continuous visit times the multiplicity
*    must be EXACTLY 1 and the note must NOT appear. A fix that adds the
*    returns but warns unconditionally passes T1/T2/T4/T5/T6/T7 and fails only
*    T3 and T8.
* 2. The measurement could be a display artifact that never reaches a caller,
*    or -- worse -- could be absent and compared against itself. T4 asserts the
*    returns are present and non-missing FIRST, then that they are unchanged by
*    efron. See the vacuous-pass note above; this is the trap that fired.
* 3. The note could fire once per bootstrap draw and drown the log. T7 counts
*    occurrences in a real refit bootstrap and requires ZERO. It passes on
*    2.3.1 too (no note exists there at all), which is why it is named as a
*    guard rather than as evidence of the fix.
*
* Sources:
*   B&L    Buzkova P, Lumley T. Can J Stat 2007;35(4):485-500.
*   IL     IrregLong 0.4.1 (Pullenayegum) -> coxph, whose ties default is efron

args run_only
do "`c(pwd)'/_iivw_qa_common.do"
iivw_qa_selector "`run_only'"
local run_only = `r(run_only)'

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_ties.do must be run from iivw/qa"
    exit 198
}
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace
discard

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Capture logs go to c(tmpdir) via tempfile, never into the package tree.
* qa/test_iivw_release_adversarial.do scans pkg_dir and pkg_dir/qa for stray
* .log/.smcl/.dta/.xlsx and fails the release gate on any it finds, and a
* suite that erases its own log only on the SUCCESS path leaves debris behind
* exactly when something has already gone wrong. A tempfile cannot leak: Stata
* removes it at the end of the do-file whatever happened.
tempfile tlog2 tlog3 tlog4 tlog6a tlog6b tlog7 tlog8a tlog8b

**# Fixture

* An irregular visit panel with a genuine intensity dependence on u.
* `grid' > 0 snaps visit times onto a grid of that width, which is what a
* registry does when it records a visit date rather than a visit instant.
* grid == 0 leaves the times continuous, which is the negative control.
capture program drop _tie_panel
program define _tie_panel
    version 16.0
    set varabbrev off
    args seed grid nsub tau
    if "`nsub'" == "" local nsub 200
    if "`tau'"  == "" local tau 10
    clear
    set seed `seed'
    set obs `nsub'
    gen long id = _n
    gen double u = rnormal()
    gen double rate = 0.6 * exp(0.8 * u)
    expand 80
    bysort id: gen j = _n
    gen double gap = -ln(runiform()) / rate
    bysort id (j): gen double t = sum(gap)
    drop if t > `tau'
    if `grid' > 0 {
        quietly replace t = ceil(t / `grid') * `grid'
        quietly duplicates drop id t, force
    }
    bysort id: gen byte nv = _N
    drop if nv < 2
    gen double fu_end = `tau'
    gen double y = 1 + 0.5 * t + u + rnormal()
    keep id t u y fu_end
    sort id t
end

* Count occurrences of a phrase in a text file. Used to assert on what the
* command actually PRINTED, which is the only axis a display contract lives
* on -- the returns are checked separately and cannot stand in for it.
capture program drop _tie_grep
program define _tie_grep, rclass
    version 16.0
    args fname phrase
    tempname fh
    local hits = 0
    file open `fh' using "`fname'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "`phrase'") > 0 local ++hits
        file read `fh' line
    }
    file close `fh'
    return scalar hits = `hits'
end

local NOTE "visit times are heavily tied"

**# TEST 1: the measurement is arithmetic, not a guess

* r(tie_multiplicity) must equal r(n_modeled_events)/r(n_event_times) exactly,
* and both counts must match a hand computation over the modeled events. Under
* baseline(entry) (the default) the modeled events are the FOLLOW-UP visits:
* each subject's first visit is study entry, not an event, and the terminal
* censoring interval is not an event either. That is the trap this test exists
* for -- counting all rows, or counting censoring rows, both give a wrong
* denominator and a wrong multiplicity.
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    capture noisily {
        _tie_panel 4242 1
        * Hand computation, entirely outside the command.
        preserve
        quietly bysort id (t): drop if _n == 1
        quietly count
        local want_ev = r(N)
        tempvar tg
        quietly egen byte `tg' = tag(t)
        quietly count if `tg'
        local want_nt = r(N)
        restore

        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace

        * PRESENCE FIRST. See the missing-value note in the header: `.' is
        * GREATER than any number, `. == .' is TRUE, and reldif(.,.) is 0 --
        * so a comparison against an absent return can pass vacuously.
        assert r(tie_multiplicity) < .
        assert r(n_modeled_events) < .
        assert r(n_event_times) < .

        assert r(n_modeled_events) == `want_ev'
        assert r(n_event_times) == `want_nt'
        assert reldif(r(tie_multiplicity), ///
            r(n_modeled_events)/r(n_event_times)) < 1e-12
        * This fixture must actually be tied, or the test proves nothing.
        assert !missing(r(tie_multiplicity))
        assert r(tie_multiplicity) > 2 & r(tie_multiplicity) < .
        display as text "  T1 events=" r(n_modeled_events) ///
            " times=" r(n_event_times) " mult=" r(tie_multiplicity)
    }
    if _rc == 0 {
        local ++pass_count
        display as result "TEST 1 PASSED: tie multiplicity is n_events/n_event_times over modeled events"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' 1"
        display as error "TEST 1 FAILED"
    }
}

**# TEST 2: the note fires on tied data when breslow was requested

* Since 3.0.0 the default is Efron, so there is nothing to advise under it.
* The note's job is inverted: it now fires only when the user explicitly chose
* the attenuating method on data that attenuates.

local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    capture noisily {
        _tie_panel 4242 1
        log using "`tlog2'", replace text nomsg
        iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) nolog replace ///
            breslow
        log close
        _tie_grep "`tlog2'" "`NOTE'"
        assert r(hits) == 1
        _tie_grep "`tlog2'" "You asked for breslow"
        assert r(hits) == 1
    }
    if _rc == 0 {
        local ++pass_count
        display as result "TEST 2 PASSED: tied data under breslow prints the note once"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' 2"
        capture log close
        display as error "TEST 2 FAILED"
    }
}

**# TEST 3: POSITIVE CONTROL -- continuous times, multiplicity exactly 1, no note

* This is the test that stops the lazy fix. "Warn whenever a Cox model is
* fitted" passes tests 2, 5, 6 and 8 cleanly and fails only here. The equality
* is exact, not approximate: with continuous times no two events share a value,
* so n_event_times == n_modeled_events by construction.
*
* `breslow' is requested deliberately. Since 3.0.0 a bare call takes the Efron
* default and is silent whatever the tie structure, so a bare call here would
* be a control on the METHOD and would pass on any build. Asking for breslow
* keeps this a control on the THRESHOLD, which is what it is for.
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    capture noisily {
        _tie_panel 4242 0
        log using "`tlog3'", replace text nomsg
        iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) nolog replace ///
            breslow
        log close
        _tie_grep "`tlog3'" "`NOTE'"
        assert r(hits) == 0

        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace
        assert r(tie_multiplicity) < .
        assert r(n_modeled_events) < . & r(n_modeled_events) > 0
        assert r(tie_multiplicity) == 1
        assert r(n_event_times) == r(n_modeled_events)
    }
    if _rc == 0 {
        local ++pass_count
        display as result "TEST 3 PASSED: continuous times give multiplicity exactly 1 and no note"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' 3"
        capture log close
        display as error "TEST 3 FAILED"
    }
}

**# TEST 4: the tie method changes the NOTE but never the MEASUREMENT

* A measurement that only exists when it is printed cannot be audited. The
* returns must be identical under both tie methods, because tie structure is a
* property of the data, not of the estimator option. Since 3.0.0 the arm that
* PRINTS is breslow and the silent arm is the default, so the two arms are
* swapped relative to 2.4.x -- the invariant they assert is not.
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    capture noisily {
        _tie_panel 4242 1
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace breslow
        * PRESENCE FIRST -- without this the whole test passes vacuously on a
        * build that returns nothing: reldif(.,.) is 0 and `. == .' is TRUE, so
        * the three comparisons below would all succeed against two ABSENT
        * values. Measured on the 2.3.1 build, which is exactly what happened
        * the first time this suite was scored against it.
        assert r(tie_multiplicity) < .
        assert r(n_modeled_events) < . & r(n_modeled_events) > 0
        assert r(n_event_times) < . & r(n_event_times) > 0
        local m_def = r(tie_multiplicity)
        local e_def = r(n_modeled_events)
        local n_def = r(n_event_times)

        log using "`tlog4'", replace text nomsg
        iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog efron replace
        log close
        _tie_grep "`tlog4'" "`NOTE'"
        assert r(hits) == 0

        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog efron replace
        assert !missing(r(tie_multiplicity), `m_def')
        assert reldif(r(tie_multiplicity), `m_def') < 1e-12
        assert r(n_modeled_events) == `e_def'
        assert r(n_event_times) == `n_def'
    }
    if _rc == 0 {
        local ++pass_count
        display as result "TEST 4 PASSED: the note follows the method, the returns do not"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' 4"
        capture log close
        display as error "TEST 4 FAILED"
    }
}

**# TEST 5: the two methods really do diverge on this fixture, and agree without ties

* The reason the note exists, asserted rather than assumed. gamma-hat is
* recovered from the weights themselves (log w = -gamma*u over modeled
* events), so this reads the shipped weight column and not an internal.
*
* Continuous times: the two methods must agree to numerical precision.
* Tied times: they must differ by more than 10% -- far outside any tolerance,
* and well below the ~34% measured at this grid width, so the assertion is a
* floor and not a re-statement of one run's number.
capture program drop _tie_gamma
program define _tie_gamma, rclass
    version 16.0
    set varabbrev off
    preserve
    quietly gen double _lw = -ln(_iivw_iw)
    quietly bysort id (t): drop if _n == 1
    quietly regress _lw u
    return scalar g = _b[u]
    restore
end

local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    capture noisily {
        * (a) continuous -- must agree
        * `breslow' is now explicit on the Breslow arm: through 2.4.x the bare
        * call WAS the Breslow arm, and leaving it bare here would compare the
        * Efron default against itself and pass while proving nothing.
        _tie_panel 4242 0
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace breslow
        _tie_gamma
        local g_b = r(g)
        capture drop _iivw_*
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog efron replace
        _tie_gamma
        local g_e = r(g)
        assert !missing(`g_b', `g_e')
        assert reldif(`g_b', `g_e') < 1e-10

        * (b) tied -- must diverge materially
        _tie_panel 4242 1
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace breslow
        _tie_gamma
        local h_b = r(g)
        capture drop _iivw_*
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog efron replace
        _tie_gamma
        local h_e = r(g)
        assert !missing(`h_b', `h_e')
        assert reldif(`h_b', `h_e') > 0.10
        * Breslow is the attenuated one: |gamma| must be SMALLER under Breslow.
        assert abs(`h_b') < abs(`h_e')
        display as text "  T5 continuous: " %8.5f `g_b' " vs " %8.5f `g_e'
        display as text "  T5 tied:       " %8.5f `h_b' " vs " %8.5f `h_e' ///
            "   reldif=" %6.3f reldif(`h_b', `h_e')
    }
    if _rc == 0 {
        local ++pass_count
        display as result "TEST 5 PASSED: methods agree untied, Breslow attenuates when tied"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' 5"
        display as error "TEST 5 FAILED"
    }
}

**# TEST 6: iivw_exogtest carries the same contract

* Same Andersen-Gill model, same Efron default since 3.0.0, same exposure.
* The note is
* emitted ONCE for the whole command rather than once per by() group, because
* tie structure is a property of time() and not of a subgroup.
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    capture noisily {
        _tie_panel 909 1
        gen byte arm = mod(id, 2)

        log using "`tlog6a'", replace text nomsg
        iivw_exogtest y, id(id) time(t) maxfu(10) by(arm) replace nolog breslow
        log close
        _tie_grep "`tlog6a'" "`NOTE'"
        * ONE note, not one per group -- there are two arms here.
        assert r(hits) == 1

        quietly iivw_exogtest y, id(id) time(t) maxfu(10) by(arm) replace
        assert r(tie_multiplicity) < .
        assert r(n_modeled_events) < . & r(n_event_times) < .
        assert !missing(r(tie_multiplicity))
        assert r(tie_multiplicity) > 2 & r(tie_multiplicity) < .
        assert r(n_event_times) < r(n_modeled_events)
        assert reldif(r(tie_multiplicity), ///
            r(n_modeled_events)/r(n_event_times)) < 1e-12

        * ... and the default (efron) is silent there too.
        log using "`tlog6b'", replace text nomsg
        iivw_exogtest y, id(id) time(t) maxfu(10) by(arm) replace nolog
        log close
        _tie_grep "`tlog6b'" "`NOTE'"
        assert r(hits) == 0
    }
    if _rc == 0 {
        local ++pass_count
        display as result "TEST 6 PASSED: iivw_exogtest reports tie density once, efron silences it"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' 6"
        capture log close
        display as error "TEST 6 FAILED"
    }
}

**# TEST 7: GUARD -- a refit bootstrap must not print the note per draw

* _iivw_bs_refit calls iivw_weight inside every replicate. The call is wrapped
* in `quietly', which suppresses a callee's `noisily', so the note must appear
* ZERO times across the whole bootstrap. Declared as a GUARD, not as evidence:
* it also passes on 2.3.1, where no note exists to be repeated.
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
    capture noisily {
        _tie_panel 4242 1
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace

        log using "`tlog7'", replace text nomsg
        quietly iivw_fit y u, vce(bootstrap, reps(5) seed(20260725)) nolog
        log close
        _tie_grep "`tlog7'" "`NOTE'"
        assert r(hits) == 0
        assert e(iivw_bs_reps_completed) == 5
    }
    if _rc == 0 {
        local ++pass_count
        display as result "TEST 7 PASSED: refit bootstrap prints the note zero times"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' 7"
        capture log close
        display as error "TEST 7 FAILED"
    }
}

**# TEST 8: the threshold is where the documentation says it is

* Multiplicity 2 is documented in iivw_weight.sthlp, iivw_exogtest.sthlp and
* the README as the point at which the note fires. Pin it with a fixture on
* each side of the boundary so a silent change to the constant is caught here
* rather than by a user reading prose that no longer matches the code.
*
* The panel is built by hand so the multiplicity is exact and not a property of
* a random draw: NSUB subjects each with the SAME follow-up visit times means
* every distinct event time carries exactly NSUB events.
local ++test_count
if `run_only' == 0 | `run_only' == 8 {
    capture noisily {
        * (a) multiplicity exactly 1 -> below threshold, silent.
        *     One subject, 6 visits: 5 modeled events at 5 distinct times.
        clear
        set obs 6
        gen long id = 1
        gen double t = _n
        gen double u = _n / 10
        gen double fu_end = 12
        * A second subject on disjoint times keeps every event time unique.
        expand 2
        bysort t: replace id = 2 if _n == 2
        quietly replace t = t + 20 if id == 2
        sort id t
        log using "`tlog8a'", replace text nomsg
        quietly replace fu_end = 40
        iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) nolog replace ///
            breslow
        log close
        _tie_grep "`tlog8a'" "`NOTE'"
        assert r(hits) == 0
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace
        assert r(tie_multiplicity) == 1

        * (b) multiplicity exactly 2 -> at the threshold, fires.
        *     Two subjects sharing identical visit times: every one of the 5
        *     distinct event times carries exactly 2 events.
        clear
        set obs 12
        gen long id = cond(_n <= 6, 1, 2)
        bysort id: gen double t = _n
        gen double u = cond(id == 1, 0.3, -0.4)
        gen double fu_end = 12
        sort id t
        log using "`tlog8b'", replace text nomsg
        iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) nolog replace ///
            breslow
        log close
        _tie_grep "`tlog8b'" "`NOTE'"
        assert r(hits) == 1
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace
        assert r(tie_multiplicity) == 2
        assert r(n_modeled_events) == 10
        assert r(n_event_times) == 5
    }
    if _rc == 0 {
        local ++pass_count
        display as result "TEST 8 PASSED: the note fires at multiplicity 2, not below"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' 8"
        capture log close
        display as error "TEST 8 FAILED"
    }
}

**# Summary

display as text ""
display as text "test_iivw_ties: `pass_count'/`test_count' passed"
if `fail_count' > 0 {
    display as error "FAILED tests:`failed_tests'"
    display "RESULT: test_iivw_ties tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display "RESULT: test_iivw_ties tests=`test_count' pass=`pass_count' fail=`fail_count'"
