clear all
version 16.0
set varabbrev off

* test_iivw_tie_default.do - the 3.0.0 tie-method DEFAULT and its escape hatch
* Tests: 12
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_tie_default.do        Run all tests
*   stata-mp -b do test_iivw_tie_default.do 3      Run only test 3
*
* WHAT THIS SUITE IS FOR
* ----------------------
* 3.0.0 made Efron the default tie method for every Andersen-Gill stcox fit in
* the package. test_iivw_ties.do owns the MEASUREMENT axis (multiplicity, the
* returns, when the note fires). This suite owns the DEFAULT axis: which method
* is actually in force when the user types nothing, that `breslow' restores the
* old one, and -- the part that is easy to get wrong -- that a dataset weighted
* under Breslow still REPLAYS under Breslow everywhere the package refits it.
*
* Sources for the default:
*   HPR    Hertz-Picciotto I, Rockhill B. Biometrics 1997;53(3):1151-1156.
*          Breslow underestimates beta, bias grows with tie load, Efron's bias
*          is under 2% at n=25/group: "the Efron method for handling ties is to
*          be preferred". Abstract read 2026-07-25; see
*          _literature/iivw/hertz-picciotto-rockhill-1997.notes.md.
*   IL     IrregLong 0.4.1 -> coxph, whose ties default is efron.
*
* THE DEFECT CLASS THIS SUITE EXISTS FOR
* --------------------------------------
* The stored contract records the tie method in STCOX form: char
* _dta[_iivw_efron] is "" for Breslow and "efron" for Efron. That encoding is
* correct for a consumer that splices it into its own stcox (iivw_balance),
* because stcox's own default is Breslow. It is WRONG for a consumer that
* re-enters iivw_weight, whose default is now Efron -- there "" means "take the
* default" and silently upgrades a Breslow contract to Efron. The bootstrap
* refit path (iivw_fit, refitweights -> _iivw_bs_refit -> iivw_weight) is
* exactly that consumer, and it would have produced an interval around a
* different estimator than the point estimate, at rc=0. T9 and T10 are that
* axis. This is the same class as the dropped agrefit option: a fit-time
* setting the refit path fails to thread.
*
* FOUR WAYS THIS SUITE COULD BE FALSELY GREEN, AND WHAT ANSWERS EACH
* ------------------------------------------------------------------
* 1. "The two methods agree on this fixture anyway." Then every difference test
*    passes for the wrong reason. T1 requires the fixture's multiplicity to
*    exceed 2 AND requires breslow to differ from the default by more than 5%
*    RELATIVE before it concludes anything, so a fixture that stopped being
*    tied fails the suite instead of silently disarming it.
* 2. "Compare the p-value." The first draft of T7 did, and it passed vacuously
*    in the WRONG direction: on this DGP the association is overwhelming, every
*    p-value underflows to 0, and reldif(0, 0) is 0 -- so a p-value comparison
*    "proves" the two methods agree. T7 discriminates on the b column, which
*    moves. Measured, not reasoned: default 0.251377 vs breslow 0.170645.
* 3. A missing return satisfies almost any assertion: `. == .' is TRUE,
*    reldif(., .) is 0, and `. > 2' is TRUE because missing sorts above every
*    number. Every comparison here asserts PRESENCE (`< .') first.
* 4. "Both options error, so the guard must work." On the 2.4.0 build `breslow'
*    is not an option at all, so a test that merely asserts rc==198 on a
*    breslow call passes there for a reason that has nothing to do with the
*    change. T4 and T5 are exactly that shape and are labelled GUARDS below --
*    they are worth keeping, but they are not evidence.
*
* SCORE AGAINST THE 2.4.0 BUILD (commit 0e783d2) -- MEASURED, not predicted
* --------------------------------------------------------------------------
* Run as written against a git-archived 2.4.0 tree: 10 FAIL, 2 PASS.
*   FAIL: T1 T2 T3 T6 T7 T8 T9 T10 T11 T12      PASS: T4 T5
* On 3.0.0: 12 PASS, 0 FAIL.
*
* The measurement corrected the labelling twice, which is why it was run rather
* than reasoned about:
*
* 1. T8 was drafted as a GUARD on the theory that any method() call errors on
*    2.4.0 for lack of the option. It is not a guard -- it FAILS there, because
*    its first assertion is that a VALID method() call SUCCEEDS and returns
*    r(tie_method). Asserting the positive path first is what turned it from a
*    tautology into a discriminating test.
* 2. T9 was expected to PASS on 2.4.0, on the reasoning that a Breslow contract
*    replayed correctly there (an empty stored token meant Breslow, which was
*    also the default, so identity held). It fails instead -- the setup calls
*    iivw_weight with `breslow', which 2.4.0 rejects outright. The axis T9
*    really covers is only reachable on a build that HAS the option, so its
*    old-build failure is bookkeeping, not evidence. T10 is the test that
*    actually pins the replay behaviour, by comparing three refits.

args run_only
do "`c(pwd)'/_iivw_qa_common.do"
iivw_qa_selector "`run_only'"
local run_only = `r(run_only)'

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_tie_default.do must be run from iivw/qa"
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

* Tied-visit panel with a known visit-intensity coefficient of 0.8 on u.
* grid > 0 rounds visit times onto a grid, which is what manufactures the ties.
capture program drop _td_panel
program define _td_panel
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

capture program drop _td_grep
program define _td_grep, rclass
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

* Rebuild the package's OWN risk set by hand so stcox can be fitted on it
* directly. Two pieces, and an oracle that drops either one is a different
* estimator: (a) the first visit is study ENTRY, not an event -- baseline(entry),
* the default since 2.0.0 -- and (b) a terminal event=0 row runs from each
* subject's last visit to their end of follow-up, the addcensoredrows contract
* inherited from IrregLong. The first draft of this oracle omitted (b) and
* disagreed with the package under BOTH tie methods; that was the oracle being
* wrong, not the package, and it is why this is spelled out rather than eyeballed.
capture program drop _td_oracle
program define _td_oracle, rclass
    version 16.0
    set varabbrev off
    quietly bysort id (t): gen double _ora_t0 = cond(_n == 1, t, t[_n-1])
    quietly bysort id (t): gen byte _ora_ev = (_n > 1)
    quietly bysort id (t): gen byte _ora_last = (_n == _N)
    preserve
    quietly keep if _ora_last
    quietly keep id t u fu_end
    quietly rename t _ora_t0
    quietly gen double _ora_tnew = fu_end
    quietly gen byte _ora_ev = 0
    quietly drop if _ora_tnew <= _ora_t0
    quietly rename _ora_tnew t
    tempfile censrows
    quietly save `censrows'
    restore
    quietly append using `censrows'
    quietly drop _ora_last
    quietly stset t, enter(time _ora_t0) failure(_ora_ev) id(id) exit(time .)
    quietly stcox u, nolog
    return scalar b_breslow = _b[u]
    quietly stcox u, nolog efron
    return scalar b_efron = _b[u]
end

**# T1 - the fixture is genuinely tied and the two methods genuinely diverge.
* This is the enabling condition for the whole suite: if it fails, every
* difference test below is meaningless rather than merely failing.

local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    display as text "T1: the fixture is tied and the two methods diverge"
    capture noisily {
        _td_panel 4242 1
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace
        assert r(tie_multiplicity) < .
        assert r(tie_multiplicity) > 2 & r(tie_multiplicity) < .
        matrix _bd = r(visit_b)
        local b_def = _bd[1,1]

        _td_panel 4242 1
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace breslow
        matrix _bb = r(visit_b)
        local b_bre = _bb[1,1]

        assert `b_def' < . & `b_bre' < .
        assert reldif(`b_def', `b_bre') > 0.05
        display as text "  T1 default=" %9.6f `b_def' "  breslow=" %9.6f `b_bre'
    }
    if _rc == 0 {
        local ++pass_count
        display as result "TEST 1 PASSED: fixture is tied and the methods diverge"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' 1"
        display as error "TEST 1 FAILED"
    }
}

**# T2 - the DEFAULT is Efron. Asked for explicitly, efron must be a no-op.

local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    display as text "T2: iivw_weight's default tie method is Efron"
    capture noisily {
        _td_panel 4242 1
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace
        matrix _bd = r(visit_b)
        local b_def = _bd[1,1]

        _td_panel 4242 1
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace efron
        matrix _be = r(visit_b)
        local b_efr = _be[1,1]

        assert `b_def' < . & `b_efr' < .
        assert reldif(`b_def', `b_efr') < 1e-12
    }
    if _rc == 0 {
        local ++pass_count
        display as result "TEST 2 PASSED: default == efron (efron is a no-op)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' 2"
        display as error "TEST 2 FAILED"
    }
}

**# T3 - EXTERNAL ANCHOR. The default must equal a hand-built stcox efron fit,
* and breslow a hand-built Breslow fit, on the package's own risk set. T2 only
* proves the two package paths agree with each other; this proves WHICH method
* they agree on, using stcox directly rather than any package code.

local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    display as text "T3: the default matches an independent stcox efron fit"
    capture noisily {
        _td_panel 4242 1
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace
        matrix _bd = r(visit_b)
        local b_def = _bd[1,1]

        _td_panel 4242 1
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace breslow
        matrix _bb = r(visit_b)
        local b_bre = _bb[1,1]

        _td_panel 4242 1
        _td_oracle
        local o_efr = r(b_efron)
        local o_bre = r(b_breslow)

        assert `o_efr' < . & `o_bre' < .
        assert reldif(`b_def', `o_efr') < 1e-8
        assert reldif(`b_bre', `o_bre') < 1e-8
        * ...and the oracle itself must show the two methods differ, or the
        * anchor is satisfied by a degenerate fixture.
        assert reldif(`o_efr', `o_bre') > 0.05
        display as text "  T3 pkg default=" %9.6f `b_def' "  stcox efron=" %9.6f `o_efr'
        display as text "  T3 pkg breslow=" %9.6f `b_bre' "  stcox breslow=" %9.6f `o_bre'
    }
    if _rc == 0 {
        local ++pass_count
        display as result "TEST 3 PASSED: default is Efron against an external stcox anchor"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' 3"
        display as error "TEST 3 FAILED"
    }
}

**# T4 - GUARD (passes on 2.4.0 for an unrelated reason): the two options may
* not be combined.

local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    display as text "T4: efron and breslow may not be combined"
    capture noisily {
        _td_panel 4242 1
        capture quietly iivw_weight, id(id) time(t) visit_cov(u) ///
            censor(fu_end) nolog replace efron breslow
        assert _rc == 198
        capture quietly iivw_exogtest y, id(id) time(t) censor(fu_end) ///
            nolog replace efron breslow
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        display as result "TEST 4 PASSED: efron + breslow rejected"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' 4"
        display as error "TEST 4 FAILED"
    }
}

**# T5 - GUARD: wtype(iptw) fits no Cox model, so BOTH tie options are refused
* and the stored method is empty. The empty contract matters beyond tidiness:
* iivw_fit reads it back, and a stamped "efron" would assert a visit-intensity
* fit that never happened.

local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    display as text "T5: wtype(iptw) refuses both tie options and stores none"
    capture noisily {
        clear
        set seed 99
        set obs 400
        gen long id = _n
        gen double x = rnormal()
        gen byte a = runiform() < invlogit(0.4 * x)
        gen double t = 1
        gen double y = a + x + rnormal()

        capture quietly iivw_weight, id(id) time(t) wtype(iptw) treat(a) ///
            treat_cov(x) nolog replace breslow
        assert _rc == 198
        capture quietly iivw_weight, id(id) time(t) wtype(iptw) treat(a) ///
            treat_cov(x) nolog replace efron
        assert _rc == 198

        quietly iivw_weight, id(id) time(t) wtype(iptw) treat(a) ///
            treat_cov(x) nolog replace
        local ch : char _dta[_iivw_efron]
        assert "`ch'" == ""
    }
    if _rc == 0 {
        local ++pass_count
        display as result "TEST 5 PASSED: iptw refuses both and stores an empty method"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' 5"
        display as error "TEST 5 FAILED"
    }
}

**# T6 - the CONTRACT records the resolved method, in stcox form. This is what
* makes a saved 2.x dataset keep replaying under Breslow, so it is asserted on
* the characteristic itself and not merely on behaviour.

local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    display as text "T6: char _dta[_iivw_efron] records the RESOLVED method"
    capture noisily {
        _td_panel 4242 1
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace
        local ch_def : char _dta[_iivw_efron]

        _td_panel 4242 1
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace efron
        local ch_efr : char _dta[_iivw_efron]

        _td_panel 4242 1
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace breslow
        local ch_bre : char _dta[_iivw_efron]

        assert "`ch_def'" == "efron"
        assert "`ch_efr'" == "efron"
        assert "`ch_bre'" == ""
    }
    if _rc == 0 {
        local ++pass_count
        display as result "TEST 6 PASSED: the contract stores the resolved method"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' 6"
        display as error "TEST 6 FAILED"
    }
}

**# T7 - iivw_exogtest takes the SAME default. These two commands must agree:
* a user reads iivw_exogtest as a check on the model iivw_weight fits.
*
* Discriminates on the b column, NOT on min_p. See falsely-green note 2.

local ++test_count
if `run_only' == 0 | `run_only' == 7 {
    display as text "T7: iivw_exogtest's default tie method is Efron too"
    capture noisily {
        _td_panel 4242 1
        quietly iivw_exogtest y, id(id) time(t) censor(fu_end) nolog replace
        matrix _Rd = r(results)
        local b_def = _Rd[1, colnumb(_Rd, "b")]

        _td_panel 4242 1
        quietly iivw_exogtest y, id(id) time(t) censor(fu_end) nolog replace efron
        matrix _Re = r(results)
        local b_efr = _Re[1, colnumb(_Re, "b")]

        _td_panel 4242 1
        quietly iivw_exogtest y, id(id) time(t) censor(fu_end) nolog replace breslow
        matrix _Rb = r(results)
        local b_bre = _Rb[1, colnumb(_Rb, "b")]

        assert `b_def' < . & `b_efr' < . & `b_bre' < .
        assert reldif(`b_def', `b_efr') < 1e-12
        assert reldif(`b_def', `b_bre') > 0.05
        display as text "  T7 default=" %9.6f `b_def' "  breslow=" %9.6f `b_bre'
    }
    if _rc == 0 {
        local ++pass_count
        display as result "TEST 7 PASSED: iivw_exogtest default == efron"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' 7"
        display as error "TEST 7 FAILED"
    }
}

**# T8 - GUARD: _iivw_tie_density FAILS CLOSED on a bad or absent method().
* An advisory whose whole job is to decide whether to warn must not treat a
* caller mistake as "nothing to warn about" -- that hides exactly the case it
* exists for. iivw_diagnose shipped an INVERTED gate once; this is the guard.

local ++test_count
if `run_only' == 0 | `run_only' == 8 {
    display as text "T8: _iivw_tie_density requires a valid method()"
    capture noisily {
        _td_panel 4242 1
        quietly bysort id (t): gen double _t0 = cond(_n == 1, t, t[_n-1])
        quietly bysort id (t): gen byte _ev = (_n > 1)
        quietly gen byte _tu = 1

        * A valid call succeeds and returns the measurement...
        capture quietly _iivw_tie_density, event(_ev) stop(t) touse(_tu) ///
            method(efron)
        assert _rc == 0
        assert r(tie_multiplicity) < .
        assert "`r(tie_method)'" == "efron"

        capture quietly _iivw_tie_density, event(_ev) stop(t) touse(_tu) ///
            method(breslow)
        assert _rc == 0
        assert "`r(tie_method)'" == "breslow"

        * ...and a missing or misspelled one is refused, not silently ignored.
        capture quietly _iivw_tie_density, event(_ev) stop(t) touse(_tu)
        assert _rc != 0
        capture quietly _iivw_tie_density, event(_ev) stop(t) touse(_tu) ///
            method(EFRON_TYPO)
        assert _rc == 198
    }
    if _rc == 0 {
        local ++pass_count
        display as result "TEST 8 PASSED: _iivw_tie_density fails closed on method()"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' 8"
        display as error "TEST 8 FAILED"
    }
}

**# T9 - THE REPLAY AXIS. A Breslow contract must survive a refit bootstrap.
* _iivw_bs_refit refuses to run without an explicit tie method, so a clean run
* here is itself the evidence that iivw_fit threaded the token rather than
* letting the replicates fall through to the new default.

local ++test_count
if `run_only' == 0 | `run_only' == 9 {
    display as text "T9: refitweights replays a Breslow contract"
    capture noisily {
        _td_panel 4242 1
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace breslow
        local ch : char _dta[_iivw_efron]
        assert "`ch'" == ""
        capture quietly iivw_fit y, bootstrap(15) refitweights nolog
        assert _rc == 0

        * ...and an Efron contract too, so T9 is not passing merely because the
        * refit path is broken in a way that ignores the token entirely.
        _td_panel 4242 1
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace
        local ch : char _dta[_iivw_efron]
        assert "`ch'" == "efron"
        capture quietly iivw_fit y, bootstrap(15) refitweights nolog
        assert _rc == 0
    }
    if _rc == 0 {
        local ++pass_count
        display as result "TEST 9 PASSED: refitweights replays both contracts"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' 9"
        display as error "TEST 9 FAILED"
    }
}

**# T10 - the half of T9 that makes it evidence rather than a smoke test.
* An unthreaded _iivw_bs_refit must resolve the tie method from the STORED
* CONTRACT, not from iivw_weight's current default. Asserted by behaviour: on a
* Breslow contract with no token passed, the refit must reproduce the explicit
* `breslow' refit EXACTLY and must differ from the explicit `efron' one. If the
* helper fell through to the default instead, the first comparison fails and
* the second one collapses to equality -- so this cannot pass for both reasons
* at once.

local ++test_count
if `run_only' == 0 | `run_only' == 10 {
    display as text "T10: an unthreaded refit resolves the method from the contract"
    capture noisily {
        * Build a BRESLOW contract, then drive the helper three ways on it.
        _td_panel 4242 1
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace breslow
        local ch : char _dta[_iivw_efron]
        assert "`ch'" == ""
        quietly gen long _nid = id
        tempfile bres_contract
        quietly save "`bres_contract'"

        quietly _iivw_bs_refit y u, newid(_nid) panelid(id) ///
            timevar(t) wtype(iivw) prefix(_iivw_) model(gee) ///
            visitcov(u) censor(fu_end) baseline(entry) nolog
        matrix _n0 = e(b)
        local b_none = _n0[1, 1]

        quietly use "`bres_contract'", clear
        quietly _iivw_bs_refit y u, newid(_nid) panelid(id) ///
            timevar(t) wtype(iivw) prefix(_iivw_) model(gee) ///
            visitcov(u) censor(fu_end) baseline(entry) nolog breslow
        matrix _n1 = e(b)
        local b_bres = _n1[1, 1]

        quietly use "`bres_contract'", clear
        quietly _iivw_bs_refit y u, newid(_nid) panelid(id) ///
            timevar(t) wtype(iivw) prefix(_iivw_) model(gee) ///
            visitcov(u) censor(fu_end) baseline(entry) nolog efron
        matrix _n2 = e(b)
        local b_efr = _n2[1, 1]

        assert `b_none' < . & `b_bres' < . & `b_efr' < .
        * The unthreaded call followed the contract...
        assert reldif(`b_none', `b_bres') < 1e-12
        * ...and the two methods are genuinely distinguishable on this fixture,
        * so the equality above is not satisfied by a degenerate refit.
        assert reldif(`b_bres', `b_efr') > 1e-6
        display as text "  T10 none=" %9.6f `b_none' "  breslow=" %9.6f `b_bres' ///
            "  efron=" %9.6f `b_efr'
    }
    if _rc == 0 {
        local ++pass_count
        display as result "TEST 10 PASSED: the refit helper follows the stored contract"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' 10"
        display as error "TEST 10 FAILED"
    }
}

**# T11 - the NOTE is inverted. It must be silent under the default and fire
* only when breslow was explicitly asked for on tied data. A fix that simply
* kept warning unconditionally passes most of this suite and fails here.

local ++test_count
if `run_only' == 0 | `run_only' == 11 {
    display as text "T11: the tie note fires under breslow only"
    capture noisily {
        local NOTE "visit times are heavily tied"
        tempfile lg_def lg_bre lg_cont

        _td_panel 4242 1
        quietly log using "`lg_def'", replace text name(tdd)
        noisily iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace
        quietly log close tdd
        _td_grep "`lg_def'" "`NOTE'"
        assert r(hits) == 0

        _td_panel 4242 1
        quietly log using "`lg_bre'", replace text name(tdb)
        noisily iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace breslow
        quietly log close tdb
        _td_grep "`lg_bre'" "`NOTE'"
        assert r(hits) == 1

        * POSITIVE CONTROL against "always warn under breslow": on continuous
        * visit times multiplicity is exactly 1 and the note must stay silent
        * even though breslow was requested.
        _td_panel 4242 0
        quietly log using "`lg_cont'", replace text name(tdc)
        noisily iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace breslow
        * Read r() BEFORE log close. r() does not survive the intervening
        * commands, and an assert placed after them reads a cleared return --
        * which fails here, but in the other direction would have passed
        * vacuously, since `. == .' is TRUE.
        local m_cont = r(tie_multiplicity)
        quietly log close tdc
        assert `m_cont' < .
        assert `m_cont' == 1
        _td_grep "`lg_cont'" "`NOTE'"
        assert r(hits) == 0
    }
    if _rc == 0 {
        local ++pass_count
        display as result "TEST 11 PASSED: the note is silent by default, fires on breslow+ties"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' 11"
        capture log close
        display as error "TEST 11 FAILED"
    }
}

**# T12 - CHARACTERIZATION: on continuous visit times the two methods agree
* EXACTLY, so the default flip cannot move an untied analysis. This is the
* boundary that limits the blast radius of the 3.0.0 change, and it is asserted
* rather than assumed.
*
* Also: iivw_balance accepts both tie options and ignores both.

local ++test_count
if `run_only' == 0 | `run_only' == 12 {
    display as text "T12: untied data is unaffected; iivw_balance ignores both options"
    capture noisily {
        _td_panel 4242 0
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace
        assert r(tie_multiplicity) == 1
        matrix _bd = r(visit_b)
        local b_def = _bd[1,1]

        _td_panel 4242 0
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace breslow
        matrix _bb = r(visit_b)
        local b_bre = _bb[1,1]

        assert `b_def' < . & `b_bre' < .
        assert reldif(`b_def', `b_bre') < 1e-10

        * iivw_balance takes both and honours neither.
        _td_panel 4242 1
        quietly iivw_weight, id(id) time(t) visit_cov(u) censor(fu_end) ///
            nolog replace breslow
        capture quietly iivw_balance, nolog breslow
        assert _rc == 0
        capture quietly iivw_balance, nolog efron
        assert _rc == 0
    }
    if _rc == 0 {
        local ++pass_count
        display as result "TEST 12 PASSED: untied data unmoved; iivw_balance ignores both"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' 12"
        display as error "TEST 12 FAILED"
    }
}

**# Summary

display as text ""
display as text "test_iivw_tie_default: `pass_count'/`test_count' passed"
if `fail_count' > 0 {
    display as error "FAILED tests:`failed_tests'"
    display "RESULT: test_iivw_tie_default tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display "RESULT: test_iivw_tie_default tests=`test_count' pass=`pass_count' fail=`fail_count'"
