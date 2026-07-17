* validation_rangematch_overlap_oracle.do
* Overlap matching checked against a brute-force oracle, plus the scaling
* contract the oracle cannot see.
*
* WHY AN ORACLE AND NOT A DIFF. The overlap backend was rewritten from a
* prefix-rescan into a forward-scan plane sweep. Diffing new output against old
* output would only prove the rewrite preserved whatever the old code did,
* including any defect it carried -- and the old code's own tests were written
* by reading it. So the expectation here is built independently: `cross' forms
* the entire master x using product and the overlap definition is applied to it
* literally, as documented, with Stata's own primitives. It shares no code, no
* data structure, and no search strategy with the sweep. It is O(M*U) on
* purpose; that is affordable only because the fixtures are small, which is
* exactly why T7/T8 exist to cover the axis it cannot.
*
* The sweep's correctness rests on a claim the old scan did not need: that each
* branch may test ONE inequality and get the other for free, which holds only
* because both intervals are known nonempty. T3/T4 aim straight at that claim
* with inverted and degenerate intervals under both closures.

clear all
version 16.1
set varabbrev off

local cwd "`c(pwd)'"
local cwd_len = strlen("`cwd'")
if substr("`cwd'", `cwd_len' - 2, 3) == "/qa" {
    local pkg_dir = substr("`cwd'", 1, `cwd_len' - 3)
}
else {
    local pkg_dir "`cwd'"
}

capture ado uninstall rangematch
quietly net install rangematch, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* Build a random master/using pair of files. Deliberately adversarial:
* p_inv inverted intervals (lo > hi), p_deg degenerate ones (lo == hi), and
* p_miss open-ended bounds -- the three shapes whose disposition the sweep's
* free half-test depends on.
capture program drop _orc_build
program define _orc_build
    syntax , Nmaster(integer) Nusing(integer) Ngroups(integer) Seed(integer) ///
        Master(string) Using(string)

    clear
    set seed `seed'
    quietly set obs `nusing'
    quietly generate int g = 1 + int(runiform() * `ngroups')
    quietly generate double ulo = int(runiform() * 40)
    quietly generate double uhi = ulo + int(runiform() * 8) - 2
    quietly replace uhi = ulo if runiform() < 0.08
    quietly replace ulo = . if runiform() < 0.06
    quietly replace uhi = . if runiform() < 0.06
    quietly save "`using'", replace

    clear
    quietly set obs `nmaster'
    quietly generate int g = 1 + int(runiform() * `ngroups')
    quietly generate double mlo = int(runiform() * 40)
    quietly generate double mhi = mlo + int(runiform() * 8) - 2
    quietly replace mhi = mlo if runiform() < 0.08
    quietly replace mlo = . if runiform() < 0.06
    quietly replace mhi = . if runiform() < 0.06
    quietly save "`master'", replace
end

* The oracle. A literal reading of the documented contract:
*   closed(both): ulo <= mhi+tol & uhi >= mlo-tol
*   closed(none): ulo <  mhi+tol & uhi >  mlo-tol
* screened by closure-aware nonemptiness on BOTH sides, evaluated on the raw
* bounds after the open-ended missing -> +/-inf substitution and deliberately
* not widened by tolerance().
capture program drop _orc_expect
program define _orc_expect
    syntax , Master(string) Using(string) Both(integer) TOLerance(real) ///
        Saving(string)

    use "`using'", clear
    quietly generate long _uid = _n
    quietly rename g ug
    tempfile utmp
    quietly save "`utmp'", replace

    use "`master'", clear
    quietly generate long _mid = _n
    quietly rename g mg
    quietly cross using "`utmp'"

    quietly replace mlo = c(mindouble) if mlo >= .
    quietly replace mhi = c(maxdouble) if mhi >= .
    quietly replace ulo = c(mindouble) if ulo >= .
    quietly replace uhi = c(maxdouble) if uhi >= .

    if `both' {
        quietly generate byte _ok = mg == ug              ///
            & mlo <= mhi & ulo <= uhi                     ///
            & ulo <= mhi + `tolerance' & uhi >= mlo - `tolerance'
    }
    else {
        quietly generate byte _ok = mg == ug              ///
            & mlo < mhi & ulo < uhi                       ///
            & ulo < mhi + `tolerance' & uhi > mlo - `tolerance'
    }
    quietly keep if _ok == 1
    keep _mid _uid
    sort _mid _uid
    quietly save "`saving'", replace
end

* Compare a rangematch overlap run against the oracle for one configuration.
* Sets `r(agree)' to 1/0 rather than asserting, so the caller reports which
* configuration disagreed.
capture program drop _orc_compare
program define _orc_compare, rclass
    syntax , Master(string) Using(string) Closed(string) TOLerance(real) ///
        Both(integer)

    tempfile exp
    _orc_expect, master("`master'") using("`using'") both(`both') ///
        tolerance(`tolerance') saving("`exp'")
    quietly count
    local n_exp = r(N)

    use "`master'", clear
    quietly rangematch mlo mhi using "`using'", overlap(ulo uhi) by(g) ///
        closed(`closed') tolerance(`tolerance') unmatched(none) ///
        masterid(_mid) usingid(_uid)
    keep _mid _uid
    sort _mid _uid
    quietly count
    local n_got = r(N)

    return scalar n_pairs = `n_got'
    if `n_got' != `n_exp' {
        display as error "    pair count `n_got' != oracle `n_exp'"
        return scalar agree = 0
        exit
    }
    if `n_got' > 0 {
        * Explicit varnames, never `cf _all': cf compares only the master's
        * varlist, so `_all' would pass on output missing a variable entirely.
        capture cf _mid _uid using "`exp'"
        if _rc {
            display as error "    pair SET differs from oracle"
            return scalar agree = 0
            exit
        }
    }
    return scalar agree = 1
end

**# T0: the fixtures actually contain the shapes the tests claim to cover
* _orc_build reaches for inverted, degenerate, and open-ended rows with
* probabilities, not guarantees. If a future edit to the builder (or a change in
* Stata's RNG) stopped producing them, T1-T3 would keep passing while silently
* testing nothing but well-formed intervals -- the exact shapes the sweep's
* correctness argument turns on. Assert the fixture discriminates.
local ++test_count
capture noisily {
    tempfile m0 u0
    _orc_build, nmaster(60) nusing(90) ngroups(4) seed(1001) ///
        master("`m0'") using("`u0'")
    use "`u0'", clear
    quietly count if !missing(ulo, uhi) & ulo > uhi
    assert r(N) > 0
    quietly count if !missing(ulo, uhi) & ulo == uhi
    assert r(N) > 0
    quietly count if missing(ulo) | missing(uhi)
    assert r(N) > 0
    use "`m0'", clear
    quietly count if !missing(mlo, mhi) & mlo > mhi
    assert r(N) > 0
    quietly count if missing(mlo) | missing(mhi)
    assert r(N) > 0
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T0 fixtures contain inverted, degenerate and open-ended rows"
}
else {
    local ++pass_count
    display as text "[ok] T0 fixtures contain inverted, degenerate and open-ended rows"
}

**# T1: closed(both), tolerance 0 -- 12 random configurations vs the oracle
local ++test_count
capture noisily {
    tempfile m u
    local bad = 0
    local any_pairs = 0
    forvalues s = 1/12 {
        _orc_build, nmaster(60) nusing(90) ngroups(4) seed(`=1000 + `s'') ///
            master("`m'") using("`u'")
        _orc_compare, master("`m'") using("`u'") closed(both) tolerance(0) both(1)
        if r(agree) != 1 {
            display as error "    seed `=1000 + `s'' disagreed"
            local ++bad
        }
        local any_pairs = `any_pairs' + r(n_pairs)
    }
    assert `bad' == 0
    * Agreement on "both sides returned nothing" is not agreement.
    assert `any_pairs' > 0
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T1 closed(both) matches the brute-force oracle"
}
else {
    local ++pass_count
    display as text "[ok] T1 closed(both) matches the brute-force oracle"
}

**# T2: closed(none) -- strict boundaries change BOTH the match test and the
* nonemptiness screen, so it is a distinct code path, not a variant of T1.
local ++test_count
capture noisily {
    tempfile m u
    local bad = 0
    forvalues s = 1/12 {
        _orc_build, nmaster(60) nusing(90) ngroups(4) seed(`=2000 + `s'') ///
            master("`m'") using("`u'")
        _orc_compare, master("`m'") using("`u'") closed(none) tolerance(0) both(0)
        if r(agree) != 1 {
            display as error "    seed `=2000 + `s'' disagreed"
            local ++bad
        }
    }
    assert `bad' == 0
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T2 closed(none) matches the brute-force oracle"
}
else {
    local ++pass_count
    display as text "[ok] T2 closed(none) matches the brute-force oracle"
}

**# T3: nonzero tolerance() under both closures
* tolerance shifts the match test but must NOT widen the nonemptiness screen.
* If the sweep ever screened on the shifted bounds, a degenerate closed(none)
* interval (x,x) would be promoted into a match here and the oracle would not
* follow.
local ++test_count
capture noisily {
    tempfile m u
    local bad = 0
    forvalues s = 1/6 {
        _orc_build, nmaster(50) nusing(70) ngroups(3) seed(`=3000 + `s'') ///
            master("`m'") using("`u'")
        _orc_compare, master("`m'") using("`u'") closed(both) tolerance(1.5) both(1)
        if r(agree) != 1 {
            display as error "    seed `=3000 + `s'' closed(both) tol disagreed"
            local ++bad
        }
        _orc_compare, master("`m'") using("`u'") closed(none) tolerance(1.5) both(0)
        if r(agree) != 1 {
            display as error "    seed `=3000 + `s'' closed(none) tol disagreed"
            local ++bad
        }
    }
    assert `bad' == 0
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T3 tolerance() matches the oracle under both closures"
}
else {
    local ++pass_count
    display as text "[ok] T3 tolerance() matches the oracle under both closures"
}

**# T4: hand-built boundary table -- every ordering of two intervals
* The random configurations above will hit most of these, but not provably and
* not identifiably. Here each row is named, so a failure says WHICH relation
* broke. Includes the shapes the sweep's free half-test depends on: inverted
* (never matches), degenerate (matches iff closed(both)), touching endpoints,
* containment both ways, and open-ended bounds.
local ++test_count
capture noisily {
    tempfile m4 u4
    clear
    input int g double ulo double uhi
        1  10  20
        2  10  20
        3  10  20
        4  10  20
        5  10  20
        6  10  20
        7  15  15
        8  20  10
        9   .  20
       10  10   .
    end
    quietly save "`u4'", replace

    clear
    input int g double mlo double mhi str24 relation
        1   0   5  "disjoint-before"
        2  25  30  "disjoint-after"
        3   0  10  "touch-at-using-low"
        4  20  30  "touch-at-using-high"
        5  12  18  "master-inside-using"
        6   0  30  "using-inside-master"
        7  10  20  "using-degenerate"
        8  10  20  "using-inverted"
        9  -5   0  "using-open-low"
       10  25  30  "using-open-high"
    end
    quietly save "`m4'", replace

    * closed(both)
    use "`m4'", clear
    quietly rangematch mlo mhi using "`u4'", overlap(ulo uhi) by(g) ///
        closed(both) unmatched(none) masterid(_mid)
    quietly levelsof relation, local(hit_both) clean
    * closed(none)
    use "`m4'", clear
    quietly rangematch mlo mhi using "`u4'", overlap(ulo uhi) by(g) ///
        closed(none) unmatched(none) masterid(_mid)
    quietly levelsof relation, local(hit_none) clean

    * Expected under closed(both): everything overlapping incl. touching and
    * the degenerate point; never the inverted using row.
    local want_both "master-inside-using touch-at-using-high touch-at-using-low using-degenerate using-inside-master using-open-high using-open-low"
    * Expected under closed(none): touching endpoints and the degenerate point
    * drop out; the open-ended rows survive because -inf/+inf still overlap.
    local want_none "master-inside-using using-inside-master using-open-high using-open-low"

    assert "`hit_both'" == "`want_both'"
    assert "`hit_none'" == "`want_none'"
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T4 every interval relation resolves as documented"
    display as error "    closed(both) got: `hit_both'"
    display as error "    closed(none) got: `hit_none'"
}
else {
    local ++pass_count
    display as text "[ok] T4 every interval relation resolves as documented"
}

**# T5: the oracle can actually fail
* Without this, T1-T4 pass vacuously if _orc_expect returns whatever rangematch
* returned. Feed the comparison a deliberately wrong tolerance and require
* disagreement: the oracle must be sensitive to the thing it claims to measure.
local ++test_count
capture noisily {
    tempfile m5 u5
    _orc_build, nmaster(60) nusing(90) ngroups(4) seed(4001) ///
        master("`m5'") using("`u5'")
    tempfile exp5
    _orc_expect, master("`m5'") using("`u5'") both(1) tolerance(0) saving("`exp5'")
    quietly count
    local n_tol0 = r(N)
    _orc_expect, master("`m5'") using("`u5'") both(1) tolerance(5) saving("`exp5'")
    quietly count
    local n_tol5 = r(N)
    * A wider tolerance must admit strictly more pairs, or the oracle is not
    * reading tolerance at all.
    assert `n_tol5' > `n_tol0'

    * And closure must matter to the oracle too.
    _orc_expect, master("`m5'") using("`u5'") both(0) tolerance(0) saving("`exp5'")
    quietly count
    assert r(N) < `n_tol0'
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T5 the oracle discriminates tolerance and closure"
}
else {
    local ++pass_count
    display as text "[ok] T5 the oracle discriminates tolerance and closure"
}

**# T6: emission order is unchanged -- pairs grouped by master row, ascending
* in using position within a master.
* The sweep visits masters in lower-bound order, not row order; nothing but the
* reserved-slot bookkeeping puts them back. A set comparison (T1-T3) is blind
* to that by construction, so it is asserted directly here.
local ++test_count
capture noisily {
    tempfile m6 u6
    _orc_build, nmaster(40) nusing(60) ngroups(3) seed(5001) ///
        master("`m6'") using("`u6'")
    use "`m6'", clear
    quietly rangematch mlo mhi using "`u6'", overlap(ulo uhi) by(g) ///
        closed(both) unmatched(none) masterid(_mid) usingid(_uid) nosort

    * The output must be in emission order already; asserting on it means NOT
    * sorting it first. Every check below reads the data in the order the
    * backend wrote it.
    quietly generate long _row = _n
    quietly count
    assert r(N) > 100

    * An ordering contract is only testable where there is something to order.
    * If every master had at most one pair, every assertion below would hold on
    * any implementation, correct or not. Require real multi-pair blocks, and
    * require ties on ulo so the _uid tiebreak is exercised rather than assumed.
    tempvar npairs
    quietly bysort _mid: generate long `npairs' = _N
    quietly summarize `npairs', meanonly
    assert r(max) >= 3
    sort _row
    quietly count if _n > 1 & _mid == _mid[_n-1] & ulo == ulo[_n-1]
    assert r(N) > 0

    * Master ids appear in one ascending, non-interleaved run: ascending alone
    * would still admit a master's pairs being split across two blocks, so the
    * run length is checked against the number of distinct masters.
    assert _mid >= _mid[_n-1] if _n > 1
    tempvar newblock
    quietly generate byte `newblock' = (_n == 1) | (_mid != _mid[_n-1])
    quietly summarize `newblock', meanonly
    local n_blocks = r(sum)
    tempvar tag
    quietly egen byte `tag' = tag(_mid)
    quietly summarize `tag', meanonly
    assert `n_blocks' == r(sum)

    * Within a master, pairs ascend in sorted-using position = (ulo, _uid).
    * ulo and _uid both come from the using side of the join, so they are
    * already in memory -- no merge needed, and none possible: the using file
    * carries no id of its own.
    *
    * The backend sorts on the SUBSTITUTED bound: a missing ulo means
    * open-ended, so it becomes -inf and sorts first. The output column keeps
    * the user's original `.', which sorts LAST in Stata. Comparing the raw
    * column would therefore report a false ordering violation on every
    * open-ended row -- reconstruct the key the sort actually used.
    * _row is unique, so this restores emission order exactly. It is here
    * because the checks above used bysort/egen, and a helper that quietly
    * leaves the data in ITS order would turn every assertion below into a
    * statement about the wrong sequence.
    sort _row
    tempvar ulo_key
    quietly generate double `ulo_key' = cond(ulo >= ., c(mindouble), ulo)
    assert `ulo_key' >= `ulo_key'[_n-1] if _n > 1 & _mid == _mid[_n-1]
    * _uid is the tiebreaker only because no using row was dropped here (the
    * default missing(wildcard) policy keeps every row), which makes the
    * original id and the physical row position coincide.
    assert _uid > _uid[_n-1] ///
        if _n > 1 & _mid == _mid[_n-1] & `ulo_key' == `ulo_key'[_n-1]
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T6 pair emission order preserved"
}
else {
    local ++pass_count
    display as text "[ok] T6 pair emission order preserved"
}

**# T7: the I10 defect -- early-start/early-end nonmatches must not be
* quadratic.
* This is the shape from the audit: every using interval starts before every
* master interval and ends before any of them begin, so the old code's
* candidate prefix was the ENTIRE using dataset while the answer was empty.
* Measured 0.257/0.935/3.637/15.129s at 2k/4k/8k/16k -- a fourfold cost per
* doubling for zero pairs.
*
* Asserting a wall-clock ceiling would be a flaky test on a shared box, so the
* assertion is on the SHAPE of the curve: doubling the data must not multiply
* the time by ~4. The ratio ceiling is loose enough to absorb noise and still
* far below the quadratic signal it exists to catch.
local ++test_count
capture noisily {
    tempfile u7
    local t_prev = 0
    local worst_ratio = 0
    local n_ratios = 0
    foreach n of numlist 4000 8000 16000 {
        clear
        quietly set obs `n'
        quietly generate int g = 1
        quietly generate double ulo = 0
        quietly generate double uhi = 1
        quietly save "`u7'", replace

        clear
        quietly set obs `n'
        quietly generate int g = 1
        quietly generate double mlo = 2
        quietly generate double mhi = 3

        timer clear 97
        timer on 97
        quietly rangematch mlo mhi using "`u7'", overlap(ulo uhi) by(g) ///
            closed(both) unmatched(none) count
        timer off 97
        quietly timer list 97
        local t = r(t97)
        * The premise of the shape: zero pairs. If this ever stops holding the
        * timing below is measuring something else entirely.
        assert r(N_pairs) == 0 | r(N_pairs) >= .

        display as text "    n=`n' pairs=0 time=`t's"
        if `t_prev' > 0 {
            * Guard against dividing by a timer floor: below ~50ms the ratio is
            * quantization noise, not signal.
            if `t_prev' >= 0.05 {
                local ratio = `t' / `t_prev'
                local ++n_ratios
                if `ratio' > `worst_ratio' local worst_ratio = `ratio'
            }
        }
        local t_prev = `t'
    }
    display as text "    worst doubling ratio: `worst_ratio' (quadratic ~= 4), from `n_ratios' ratio(s)"
    * Without this the test is a trapdoor: if every run came in under the 50ms
    * floor, worst_ratio would still be 0 and the ceiling below would pass
    * having measured NOTHING. A machine that fast is a reason to raise the
    * fixture size, not to accept a silent skip.
    assert `n_ratios' > 0
    * Ceiling sits between the two regimes, not near the linear expectation.
    * Measured: this backend 1.70-2.24 across runs, the prefix-rescan it
    * replaced 3.94-3.95. At these absolute times a fair chunk of each run is
    * fixed setup cost, which inflates the ratio and would make a tight ceiling
    * flake on a loaded box for no diagnostic gain.
    assert `worst_ratio' < 3.0
    * Absolute backstop. The old code took 15.1s at 16k; any machine slow
    * enough to need more than 5s for a linear sweep of 16k rows would fail
    * every other timed suite in this lane first.
    assert `t_prev' < 5
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T7 no-match overlap does not scale quadratically"
}
else {
    local ++pass_count
    display as text "[ok] T7 no-match overlap does not scale quadratically"
}

**# T8: the same scaling contract on a shape that DOES produce output
* T7 alone could be satisfied by a backend that bails out early on empty
* results. Here each master matches a bounded number of using rows, so K grows
* linearly and the sweep must too.
local ++test_count
capture noisily {
    tempfile u8
    local t_prev = 0
    local worst_ratio = 0
    local n_ratios = 0
    foreach n of numlist 4000 8000 16000 {
        clear
        quietly set obs `n'
        quietly generate int g = 1
        quietly generate double ulo = _n
        quietly generate double uhi = _n + 2
        quietly save "`u8'", replace

        clear
        quietly set obs `n'
        quietly generate int g = 1
        quietly generate double mlo = _n
        quietly generate double mhi = _n + 1

        timer clear 96
        timer on 96
        quietly rangematch mlo mhi using "`u8'", overlap(ulo uhi) by(g) ///
            closed(both) unmatched(none) count
        timer off 96
        quietly timer list 96
        local t = r(t96)
        local k = r(N_pairs)
        display as text "    n=`n' pairs=`k' time=`t's"
        * Output must grow linearly, ~4 pairs per master. If K went quadratic
        * the timing assertion below would be meaningless.
        assert `k' > 3 * `n' & `k' < 5 * `n'
        if `t_prev' > 0 & `t_prev' >= 0.05 {
            local ratio = `t' / `t_prev'
            local ++n_ratios
            if `ratio' > `worst_ratio' local worst_ratio = `ratio'
        }
        local t_prev = `t'
    }
    display as text "    worst doubling ratio: `worst_ratio' (quadratic ~= 4), from `n_ratios' ratio(s)"
    assert `n_ratios' > 0
    * Ceiling sits between the two regimes, not near the linear expectation.
    * Measured: this backend 1.70-2.24 across runs, the prefix-rescan it
    * replaced 3.94-3.95. At these absolute times a fair chunk of each run is
    * fixed setup cost, which inflates the ratio and would make a tight ceiling
    * flake on a loaded box for no diagnostic gain.
    assert `worst_ratio' < 3.0
    * The absolute backstop is the blunter but sturdier of the two checks: the
    * prefix-rescan took 22.9s on this shape at 16k, this backend 0.2s.
    assert `t_prev' < 5
}
if _rc {
    local ++fail_count
    display as error "[FAIL] T8 matching overlap scales linearly in output"
}
else {
    local ++pass_count
    display as text "[ok] T8 matching overlap scales linearly in output"
}

**# Summary
display as text _newline "validation_rangematch_overlap_oracle"
display as text "Tests:  `test_count'"
display as text "Passed: `pass_count'"
display as text "Failed: `fail_count'"
display "RESULT: validation_rangematch_overlap_oracle tests=`test_count' pass=`pass_count' fail=`fail_count'"

if `fail_count' > 0 exit 9
