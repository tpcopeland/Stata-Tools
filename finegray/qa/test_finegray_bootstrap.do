* test_finegray_bootstrap.do
* Bootstrap and refit integrity (fg_plan Phase 4).
*
* Each test below fails against v1.1.4 and passes after the phase:
*   FG-H01   the bootstrap replayed e(cmdline) verbatim, including if/in.  After
*            `finegray x in 101/200' the refit dataset holds 100 resampled rows,
*            `in 101/200' selects none of them, and every replication failed:
*            rc 498, 0/B.  The refit now replays e(refitcmd), which carries no
*            sample qualifier.
*   FG-M07   `if _bok < 2' was the only floor -- a confidence band could be, and
*            was, built from two replications.
*   FG-H12   multi-record reduction wrote _fg_entry BEFORE the input validation
*            that could reject the fit; the cleanup zone then dropped it while a
*            prior fit's e() still referenced it.
*   FG-M08a  seed() without bootstrap() was silently ignored.
clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_bootstrap.log", replace name(_tboot)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _mk_hypoxia_boot
program define _mk_hypoxia_boot
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)
end

* Multi-record (delayed-entry) data: each subject contributes two contiguous
* intervals, so finegray's within-id reduction runs and _fg_entry is created.
capture program drop _mk_multirec_boot
program define _mk_multirec_boot
    webuse hypoxia, clear
    gen byte status = failtype
    expand 2
    bysort stnum: gen double mr_t0 = cond(_n == 1, 0, dftime/2)
    by stnum: gen double mr_t1 = cond(_n == 1, dftime/2, dftime)
    by stnum: gen byte mr_ev = cond(_n == _N, dfcens == 1, 0)
    by stnum: replace status = 0 if _n < _N
    stset mr_t1, failure(mr_ev==1) enter(time mr_t0) id(stnum)
end

**# 1. FG-H01: an `in'-qualified fit can be bootstrapped
local ++test_count
capture noisily {
    _mk_hypoxia_boot
    quietly finegray ifp tumsize in 1/100, compete(status) cause(1) nolog

    * The refit line must carry no sample qualifier at all.  Guard the tokens,
    * not a substring: "if"/"in" appear inside variable names.
    local rcmd `"`e(refitcmd)'"'
    assert `"`rcmd'"' != ""
    assert strpos(`"`rcmd'"', " in ") == 0
    assert strpos(`"`rcmd'"', " if ") == 0
    * e(cmdline) is the user's command AS TYPED and must be unchanged.
    assert strpos(`"`e(cmdline)'"', "in 1/100") > 0

    * v1.1.4: rc 498, 0/B replications.  Every replication must now succeed.
    finegray_cif, attime(1 5) ci bootstrap(25) seed(7) nograph
    assert r(bootstrap_requested) == 25
    assert r(bootstrap_success) == 25
    assert r(bootstrap_failed) == 0

    * The band must be a real interval, not a collapsed point.
    matrix T = r(table)
    assert T[1,3] > 0 & T[1,3] < .
    assert T[1,4] < T[1,2] & T[1,2] < T[1,5]

    * Same defect, same fix, in finegray_predict.
    quietly finegray ifp tumsize in 1/100, compete(status) cause(1) nolog
    finegray_predict cb, cif ci bootstrap(25) seed(7)
    quietly summarize cb_lci if !missing(cb_lci)
    assert r(N) > 0
    quietly count if !missing(cb) & !missing(cb_lci) & cb_lci >= cb
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: in-qualified fit bootstraps with all replications succeeding"
    local ++pass_count
}
else {
    display as error "  FAIL: in-qualified bootstrap (rc=`=_rc')"
    local ++fail_count
}

**# 2. A variable-based `if' fit still bootstraps (it always did; keep it so)
local ++test_count
capture noisily {
    _mk_hypoxia_boot
    quietly finegray ifp tumsize if tumsize < 8, compete(status) cause(1) nolog
    local n_est = e(N)

    finegray_cif, attime(1 5) ci bootstrap(25) seed(11) nograph
    assert r(bootstrap_success) == 25

    * Dropping `if' from the refit line must not change WHICH subjects are
    * resampled: the bootstrap keeps e(sample) first, so the refit population is
    * the estimation sample either way.  Assert that, or the fix would have
    * silently widened the bootstrap to the full dataset.
    quietly finegray ifp tumsize if tumsize < 8, compete(status) cause(1) nolog
    assert e(N) == `n_est'
    quietly count
    assert r(N) > `n_est'
}
if _rc == 0 {
    display as result "  PASS: if-qualified bootstrap resamples the estimation sample only"
    local ++pass_count
}
else {
    display as error "  FAIL: if-qualified bootstrap population (rc=`=_rc')"
    local ++fail_count
}

**# 3. FG-M07: the bootstrap replication floor
local ++test_count
capture noisily {
    _mk_hypoxia_boot
    quietly finegray ifp tumsize, compete(status) cause(1) nolog

    * A two-replication confidence band was accepted by v1.1.4.  Reject it.
    capture finegray_cif, attime(5) ci bootstrap(2) seed(1) nograph
    assert _rc == 198
    capture finegray_predict cb2, cif ci bootstrap(2) seed(1)
    assert _rc == 198
    * The rejected call must leave no variable behind.
    capture confirm variable cb2
    assert _rc != 0

    * The floor is 25; 24 is below it and 25 is not.
    capture finegray_cif, attime(5) ci bootstrap(24) seed(1) nograph
    assert _rc == 198
    finegray_cif, attime(5) ci bootstrap(25) seed(1) nograph
    assert r(bootstrap_success) == 25

    * bootstrap(0) is "no bootstrap", not a below-floor request.
    quietly finegray_cif, attime(5) ci bootstrap(0) nograph
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: bootstrap replication floor of 25 enforced"
    local ++pass_count
}
else {
    display as error "  FAIL: bootstrap floor (rc=`=_rc')"
    local ++fail_count
}

**# 4. FG-M08a: seed() without bootstrap() is an error, not a silent no-op
local ++test_count
capture noisily {
    _mk_hypoxia_boot
    quietly finegray ifp tumsize, compete(status) cause(1) nolog

    capture finegray_cif, attime(5) seed(1) nograph
    assert _rc == 198
    capture finegray_predict cb3, cif seed(1)
    assert _rc == 198
    capture confirm variable cb3
    assert _rc != 0

    * seed() WITH bootstrap() is honoured and reproducible.  Not bit-exactness:
    * the replicate accumulation reorders floating-point additions, so the same
    * seed reproduces to ~1e-16, not to the last bit.
    finegray_cif, attime(5) ci bootstrap(25) seed(999) nograph
    matrix T1 = r(table)
    finegray_cif, attime(5) ci bootstrap(25) seed(999) nograph
    matrix T2 = r(table)
    assert mreldif(T1, T2) < 1e-12

    * A different seed gives a materially different bootstrap SE -- so the check
    * above is testing the seed, not a deterministic code path that would agree
    * whatever we passed.  The gap must be far larger than the 1e-12 tolerance.
    finegray_cif, attime(5) ci bootstrap(25) seed(1234) nograph
    matrix T3 = r(table)
    assert reldif(T1[1,3], T3[1,3]) > 1e-6
}
if _rc == 0 {
    display as result "  PASS: seed() requires bootstrap(); seeded runs reproduce"
    local ++pass_count
}
else {
    display as error "  FAIL: seed() contract (rc=`=_rc')"
    local ++fail_count
}

**# 5. FG-H12: a failed re-fit cannot strand the prior fit's _fg_entry
local ++test_count
capture noisily {
    _mk_multirec_boot
    quietly finegray ifp tumsize, compete(status) cause(1) nolog

    * The reduction ran and persisted each subject's earliest entry.
    assert `"`: char _dta[_finegray_entryvar]'"' == "_fg_entry"
    confirm variable _fg_entry
    quietly finegray_cif, attime(1) nograph
    matrix ok_before = r(table)

    * Now force a re-fit that fails INPUT VALIDATION (no such cause).  v1.1.4
    * had already dropped and recreated _fg_entry by this point, so the cleanup
    * zone deleted it -- leaving the prior fit's e() pointing at a variable that
    * no longer existed.  Validation now runs before any mutation.
    capture finegray ifp tumsize, compete(status) cause(99) nolog
    assert _rc == 198

    * The prior fit survives intact: its entry column, its chars, and its
    * postestimation results.
    confirm variable _fg_entry
    assert `"`: char _dta[_finegray_entryvar]'"' == "_fg_entry"
    assert `"`: char _dta[_finegray_estimated]'"' == "1"
    quietly finegray_cif, attime(1) nograph
    assert mreldif(r(table), ok_before) < 1e-12

    * And the surviving fit can still be bootstrapped.
    finegray_cif, attime(1) ci bootstrap(25) seed(5) nograph
    assert r(bootstrap_success) == 25
}
if _rc == 0 {
    display as result "  PASS: failed validation leaves the prior multi-record fit intact"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-record validate-then-mutate (rc=`=_rc')"
    local ++fail_count
}

**# 6. The refit line reproduces the fit: same options, same coefficients
local ++test_count
capture noisily {
    _mk_hypoxia_boot
    * Exercise every option the refit line has to carry through.
    quietly finegray i.pelnode ifp, compete(status) cause(1) nolog ///
        censvalue(0) strata(pelnode) iterate(150) tolerance(1e-9) noadjust
    matrix b_fit = e(b)
    matrix V_fit = e(V)
    local rcmd `"`e(refitcmd)'"'

    * Replaying e(refitcmd) on the estimation sample must reproduce the fit
    * exactly.  If the line dropped an option, the refit would silently be a
    * different model -- which is precisely what the bootstrap would then
    * resample.
    quietly keep if e(sample)
    `rcmd'
    assert mreldif(e(b), b_fit) < 1e-10
    assert mreldif(e(V), V_fit) < 1e-10
    assert "`e(strata)'" == "pelnode"
    assert e(iterate) == 150
    assert e(vce) == "robust"
}
if _rc == 0 {
    display as result "  PASS: e(refitcmd) reproduces the original fit exactly"
    local ++pass_count
}
else {
    display as error "  FAIL: refit command fidelity (rc=`=_rc')"
    local ++fail_count
}

**# 7. FG-H14: a bootstrap must not poison the Mata baseline cache
*
* The baseline cache is a SINGLE SLOT: one Mata matrix `_finegray_bh_cache'
* plus one sequence scalar `_finegray_bh_seq'.  Every finegray fit overwrites
* the slot and bumps the seq, and post-estimation resolves the baseline only
* when e(bh_seq) still equals the cache's current seq.  A bootstrap refits B
* times, so afterwards the cache holds the LAST resample's curve while the
* restored e(bh_seq) names the original fit.
*
* `_estimates hold' does NOT cover this: it protects e(), and the cache is a
* Mata global invisible to it.  The failure is fail-closed rather than silent
* -- the seq increases monotonically, so a stale cache can never be mistaken
* for a matching one -- but it strands the user at r(459) on a later predict
* against new data, with the estimation sample gone and no way to rebuild.
*
* Measured 2026-07-22 on 1.2.0: after `finegray_cif, bootstrap(25)' the cache
* seq was 27 while e(bh_seq) was 2.  finegray_predict carried the stash fix;
* finegray_cif ran the same refit loop without it.  Both directions are tested
* below, because a test that only covered cif would let the predict fix -- the
* older of the two, and until now untested -- regress unnoticed.
foreach _cmd in cif predict {
    local ++test_count
    capture noisily {
        _mk_hypoxia_boot
        quietly finegray ifp tumsize, compete(status) cause(1) nolog
        local _seq_fit = e(bh_seq)

        if "`_cmd'" == "cif" ///
            quietly finegray_cif, attime(1 5) ci bootstrap(25) seed(7) nograph
        else ///
            quietly finegray_predict _cb_`_cmd', cif ci bootstrap(25) seed(7)

        * Read the cache's live seq straight out of Mata.  Asserting on
        * e(bh_seq) alone would pass vacuously: _estimates hold restores it
        * correctly even when the cache underneath has moved.
        mata: st_local("_seq_cache", strofreal(_finegray_bh_seq))
        assert `_seq_cache' == `_seq_fit'

        * Drop the estimation data so the rebuild fallback cannot rescue the
        * lookup.  Without this the test passes on BROKEN code -- finegray
        * rebuilds the baseline from e(sample) and never touches the cache.
        quietly {
            drop _all
            set obs 5
            gen double ifp = 20
            gen double tumsize = 5
            gen double newt = 2
        }
        quietly finegray_predict _p_`_cmd', cif timevar(newt)
        * A resolved baseline must also be a USABLE one: r(459) is the failure
        * this guards, but an all-missing column would be the quieter one.
        quietly count if missing(_p_`_cmd')
        assert r(N) == 0
    }
    if _rc == 0 {
        display as result "  PASS: `_cmd' bootstrap preserves the baseline cache"
        local ++pass_count
    }
    else {
        display as error "  FAIL: `_cmd' bootstrap poisons the baseline cache (rc=`=_rc')"
        local ++fail_count
    }
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_bootstrap tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _tboot
    exit 1
}
display as result "ALL TESTS PASSED"
log close _tboot
