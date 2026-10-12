*! test_rangematch_v1510.do
*! Regression gates for the 1.5.10 tolerance() / open-bound semantics.
*!
*!   T1  tolerance(t): a master interval is empty only if (low - t) > (high + t).
*!       A point-mode interval inverted by decimal noise (0.1 + 0.2 > 0.3)
*!       matches at tolerance(1e-9) under all four closed() modes and matches
*!       nothing at tolerance(0); an equal pair (low - t == high + t) is not
*!       empty and so honours the closure.
*!   T2  unmatched(master) keeps the noise-inverted master row as unmatched at
*!       tolerance(0) and matches it at tolerance(1e-9): the retained-row count
*!       moves.
*!   T3  overlap mode: tolerance() widens the MASTER interval only; a using
*!       interval is judged on its recorded bounds, so r(N_using_inverted)
*!       still counts raw inversion at tolerance() > 0 and never matches.
*!   T4  a missing (open) bound removes its side's restriction exactly. A key
*!       equal to c(maxdouble) under a missing high bound, or to
*!       2*c(mindouble) (storable) under a missing low bound, matches under
*!       every closed() mode, on the sweep backend ...
*!   T5  ... and on the binary backend (nosort, master groups out of order).
*!   T6  nearest() with open bounds at the double limits.
*!   T7  overlap mode with open bounds at the double limits.
*!   T8  a tolerance() shift that runs past the double range is an open bound
*!       (point and overlap), not a clamp that a strict closure then excludes.
*!   T9  a missing-key master row with scalar-offset bounds matches nothing
*!       even at tolerance(0.5) and tolerance(8e307).
*!   T10 seeded fuzz: nearest(before|after|both) x ties(all|first|last) x
*!       closed() x tolerance() x by(), missing and extreme bounds, against an
*!       explicit oracle written from the help text.
*!
*! Every expected value is hand-computed from the documented rule or comes from
*! a cross/joinby construction that does not use rangematch.

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
clear all
version 16.1
set varabbrev off

local TESTS 0
local PASS 0
local FAIL 0

global V1510_BAD ""

**# Helpers
* Point mode: one target master row (variable bounds mlo/mhi, master key mkey)
* against one using row per word in ukeys. Expressions may not contain spaces.
* With binary, a filler master row in a later by() group precedes the target,
* so the group ids decrease and the sweep backend declines (r(backend) binary).
capture program drop _v1510_pt
program define _v1510_pt, rclass
    syntax , MLO(string) MHI(string) UKEYS(string) [CLosed(string) ///
        TOL(string) MKEY(string) BINARY NEAREST(string) TIES(string) ///
        UNmatched(string)]
    if "`closed'" == "" local closed both
    if "`tol'" == "" local tol 0
    if "`mkey'" == "" local mkey 0
    if "`unmatched'" == "" local unmatched none
    tempfile u
    clear
    local n : word count `ukeys'
    quietly set obs `n'
    quietly gen long uid = _n
    quietly gen byte g = 1
    quietly gen double key = .
    forvalues i = 1/`n' {
        local e : word `i' of `ukeys'
        quietly replace key = `e' in `i'
    }
    quietly save `"`u'"'
    clear
    if "`binary'" != "" {
        quietly set obs 2
        quietly gen double key = `mkey'
        quietly gen double lo = 0
        quietly gen double hi = 0
        quietly gen byte g = 2 in 1
        quietly replace g = 1 in 2
        quietly replace lo = `mlo' in 2
        quietly replace hi = `mhi' in 2
        quietly replace lo = 100 in 1
        quietly replace hi = 100 in 1
    }
    else {
        quietly set obs 1
        quietly gen double key = `mkey'
        quietly gen double lo = `mlo'
        quietly gen double hi = `mhi'
        quietly gen byte g = 1
    }
    local opts closed(`closed') tolerance(`tol') unmatched(`unmatched')
    if "`binary'" != "" local opts `opts' nosort
    if "`nearest'" != "" local opts `opts' nearest(`nearest')
    if "`ties'" != "" local opts `opts' ties(`ties')
    quietly rangematch key lo hi using `"`u'"', by(g) `opts' ///
        masterid(mid) usingid(uid2)
    return scalar mp = r(N_matched_pairs)
    return local be "`r(backend)'"
    quietly count if uid2 < . & mid < .
    return scalar real_pairs = r(N)
    quietly count if uid2 >= . & mid < . & g == 1
    return scalar unm = r(N)
end

* Assert one point-mode cell: matched-pair count and (optionally) backend.
capture program drop _v1510_cell
program define _v1510_cell
    syntax , Label(string) Expect(integer) MLO(string) MHI(string) ///
        UKEYS(string) [CLosed(string) TOL(string) MKEY(string) BINARY ///
        NEAREST(string) TIES(string) BE(string)]
    capture noisily _v1510_pt, mlo(`mlo') mhi(`mhi') ukeys(`ukeys') ///
        closed(`closed') tol(`tol') mkey(`mkey') `binary' ///
        nearest(`nearest') ties(`ties')
    if _rc {
        global V1510_BAD "$V1510_BAD [`label': rc=`=_rc']"
        exit
    }
    local got = r(mp)
    if "`be'" != "" & "`r(be)'" != "`be'" {
        global V1510_BAD "$V1510_BAD [`label': backend `r(be)' want `be']"
    }
    if `got' != `expect' {
        global V1510_BAD "$V1510_BAD [`label': got `got' want `expect']"
    }
end

* Overlap mode: one master interval vs one using interval.
capture program drop _v1510_ov
program define _v1510_ov, rclass
    syntax , MLO(string) MHI(string) ULO(string) UHI(string) ///
        [CLosed(string) TOL(string)]
    if "`closed'" == "" local closed both
    if "`tol'" == "" local tol 0
    tempfile u
    clear
    quietly set obs 1
    quietly gen double ulo = `ulo'
    quietly gen double uhi = `uhi'
    quietly save `"`u'"'
    clear
    quietly set obs 1
    quietly gen double mlo = `mlo'
    quietly gen double mhi = `mhi'
    quietly rangematch mlo mhi using `"`u'"', overlap(ulo uhi) ///
        closed(`closed') tolerance(`tol') unmatched(none)
    return scalar mp = r(N_matched_pairs)
    return scalar inv = r(N_using_inverted)
end

capture program drop _v1510_ocell
program define _v1510_ocell
    syntax , Label(string) Expect(integer) MLO(string) MHI(string) ///
        ULO(string) UHI(string) [CLosed(string) TOL(string) INV(integer -1)]
    capture noisily _v1510_ov, mlo(`mlo') mhi(`mhi') ulo(`ulo') uhi(`uhi') ///
        closed(`closed') tol(`tol')
    if _rc {
        global V1510_BAD "$V1510_BAD [`label': rc=`=_rc']"
        exit
    }
    if r(mp) != `expect' {
        global V1510_BAD "$V1510_BAD [`label': got `=r(mp)' want `expect']"
    }
    if `inv' >= 0 & r(inv) != `inv' {
        global V1510_BAD "$V1510_BAD [`label': N_using_inverted `=r(inv)' want `inv']"
    }
end

local KMAX "c(maxdouble)"
local KMIN "2*c(mindouble)"
local NOISE "(0.1+0.2)"

**# T1: master interval inverted by decimal noise, point mode, 4 closures x 2 tolerances
local ++TESTS
global V1510_BAD ""
capture noisily {
    foreach cl in both left right none {
        * tol 0: low 0.30000000000000004 > high 0.3, empty on every closure
        _v1510_cell, label("noise tol0 `cl'") expect(0) mlo(`NOISE') mhi(0.3) ///
            ukeys(0.3) closed(`cl') tol(0)
        * tol 1e-9: widened interval (0.299999999, 0.300000001) holds 0.3
        _v1510_cell, label("noise tol1e-9 `cl'") expect(1) mlo(`NOISE') mhi(0.3) ///
            ukeys(0.3) closed(`cl') tol(1e-9)
    }
    * low - t == high + t exactly (2 - .5 == 1 + .5 == 1.5): NOT empty, so the
    * closure decides whether key 1.5 matches: [1.5,1.5] yes, the rest empty
    _v1510_cell, label("equal both") expect(1) mlo(2) mhi(1) ukeys(1.5) ///
        closed(both) tol(0.5)
    _v1510_cell, label("equal left") expect(0) mlo(2) mhi(1) ukeys(1.5) ///
        closed(left) tol(0.5)
    _v1510_cell, label("equal right") expect(0) mlo(2) mhi(1) ukeys(1.5) ///
        closed(right) tol(0.5)
    _v1510_cell, label("equal none") expect(0) mlo(2) mhi(1) ukeys(1.5) ///
        closed(none) tol(0.5)
    * still inverted after widening (2 - .25 > 1 + .25): empty
    _v1510_cell, label("still inverted") expect(0) mlo(2) mhi(1) ukeys(1.5) ///
        closed(both) tol(0.25)
    * control: an ordinary interval is unaffected
    _v1510_cell, label("control") expect(1) mlo(0) mhi(1) ukeys(0.5) ///
        closed(none) tol(0)
    assert "$V1510_BAD" == ""
}
if _rc {
    local ++FAIL
    display as error "FAIL: T1 point-mode master interval judged on widened bounds: $V1510_BAD"
}
else {
    local ++PASS
    display as result "PASS: T1 point-mode master interval judged on widened bounds"
}

**# T2: unmatched(master) retained-row count follows the widened rule
local ++TESTS
capture noisily {
    * two master rows: m1 noise-inverted [0.1+0.2, 0.3], m2 far away (10,11);
    * using keys 0.3 and 0.5
    tempfile u
    clear
    quietly set obs 2
    quietly gen long uid = _n
    quietly gen double key = cond(_n == 1, 0.3, 0.5)
    quietly save `"`u'"'
    foreach cl in both left right none {
        * tol 0: nothing matches; both master rows are kept as unmatched
        clear
        quietly set obs 2
        quietly gen long mrow = _n
        quietly gen double lo = cond(_n == 1, 0.1 + 0.2, 10)
        quietly gen double hi = cond(_n == 1, 0.3, 11)
        quietly rangematch key lo hi using `"`u'"', closed(`cl') ///
            tolerance(0) unmatched(master) usingid(uid2)
        assert _N == 2
        assert r(N_matched_pairs) == 0
        quietly count if uid2 >= .
        assert r(N) == 2
        * tol 1e-9: m1 matches key 0.3; only m2 stays unmatched
        clear
        quietly set obs 2
        quietly gen long mrow = _n
        quietly gen double lo = cond(_n == 1, 0.1 + 0.2, 10)
        quietly gen double hi = cond(_n == 1, 0.3, 11)
        quietly rangematch key lo hi using `"`u'"', closed(`cl') ///
            tolerance(1e-9) unmatched(master) usingid(uid2)
        assert _N == 2
        assert r(N_matched_pairs) == 1
        quietly count if uid2 >= .
        assert r(N) == 1
        assert mrow == 2 if uid2 >= .
        assert uid2 == 1 if mrow == 1
    }
}
if _rc {
    local ++FAIL
    display as error "FAIL: T2 unmatched(master) retained rows follow the widened rule"
}
else {
    local ++PASS
    display as result "PASS: T2 unmatched(master) retained rows follow the widened rule"
}

**# T3: overlap mode widens the master only; using inversion is judged raw
local ++TESTS
global V1510_BAD ""
capture noisily {
    foreach cl in both none {
        * master noise-inverted vs using (0.3,0.4): tol 0 empty master; tol 1e-9
        * widens to (0.299999999,0.300000001), which overlaps (0.3,0.4)
        _v1510_ocell, label("ov master noise tol0 `cl'") expect(0) ///
            mlo(`NOISE') mhi(0.3) ulo(0.3) uhi(0.4) closed(`cl') tol(0) inv(0)
        _v1510_ocell, label("ov master noise tol1e-9 `cl'") expect(1) ///
            mlo(`NOISE') mhi(0.3) ulo(0.3) uhi(0.4) closed(`cl') tol(1e-9) inv(0)
        * USING interval inverted by the same noise: counted raw, never matches
        _v1510_ocell, label("ov using noise tol0 `cl'") expect(0) ///
            mlo(0) mhi(1) ulo(`NOISE') uhi(0.3) closed(`cl') tol(0) inv(1)
        _v1510_ocell, label("ov using noise tol1e-9 `cl'") expect(0) ///
            mlo(0) mhi(1) ulo(`NOISE') uhi(0.3) closed(`cl') tol(1e-9) inv(1)
        _v1510_ocell, label("ov using inverted tol5 `cl'") expect(0) ///
            mlo(0) mhi(10) ulo(8) uhi(2) closed(`cl') tol(5) inv(1)
    }
    * the master side widening is real: gap 5e-10 closed by tol 1e-9 ...
    _v1510_ocell, label("ov master widen") expect(1) mlo(0) mhi(1) ///
        ulo(1.0000000005) uhi(2) closed(both) tol(1e-9)
    * ... and the same gap is a miss at tolerance(0)
    _v1510_ocell, label("ov no using widen") expect(0) mlo(0) mhi(1) ///
        ulo(1.0000000005) uhi(2) closed(both) tol(0)
    * control: ordinary overlap
    _v1510_ocell, label("ov control") expect(1) mlo(0) mhi(2) ulo(1) uhi(3) ///
        closed(none) tol(0) inv(0)
    assert "$V1510_BAD" == ""
}
if _rc {
    local ++FAIL
    display as error "FAIL: T3 overlap tolerance widens master only: $V1510_BAD"
}
else {
    local ++PASS
    display as result "PASS: T3 overlap tolerance widens master only"
}

**# T4: open bounds at the double limits, sweep backend
local ++TESTS
global V1510_BAD ""
capture noisily {
    foreach cl in both left right none {
        * missing high removes the upper restriction: key = c(maxdouble) matches
        _v1510_cell, label("sweep maxkey openhi `cl'") expect(1) mlo(0) mhi(.) ///
            ukeys(`KMAX') closed(`cl') be(sweep)
        * missing low removes the lower restriction: key = 2*c(mindouble) matches
        _v1510_cell, label("sweep minkey openlo `cl'") expect(1) mlo(.) mhi(0) ///
            ukeys(`KMIN') closed(`cl') be(sweep)
        * both open: both extremes match
        _v1510_cell, label("sweep both open `cl'") expect(2) mlo(.) mhi(.) ///
            ukeys(`KMAX' `KMIN') closed(`cl') be(sweep)
        * the same through the tolerance path (finite tol must not re-impose a bound)
        _v1510_cell, label("sweep maxkey openhi tol `cl'") expect(1) mlo(0) mhi(.) ///
            ukeys(`KMAX') closed(`cl') tol(1e-9) be(sweep)
        _v1510_cell, label("sweep minkey openlo tol `cl'") expect(1) mlo(.) mhi(0) ///
            ukeys(`KMIN') closed(`cl') tol(1e-9) be(sweep)
        * controls: a FINITE bound still excludes the extreme key
        _v1510_cell, label("sweep maxkey finite hi `cl'") expect(0) mlo(0) mhi(1e300) ///
            ukeys(`KMAX') closed(`cl') be(sweep)
        _v1510_cell, label("sweep minkey finite lo `cl'") expect(0) mlo(-1e300) mhi(0) ///
            ukeys(`KMIN') closed(`cl') be(sweep)
    }
    assert "$V1510_BAD" == ""
}
if _rc {
    local ++FAIL
    display as error "FAIL: T4 open bounds at the double limits (sweep): $V1510_BAD"
}
else {
    local ++PASS
    display as result "PASS: T4 open bounds at the double limits (sweep)"
}

**# T5: the same on the binary backend
local ++TESTS
global V1510_BAD ""
capture noisily {
    foreach cl in both left right none {
        _v1510_cell, label("binary maxkey openhi `cl'") expect(1) mlo(0) mhi(.) ///
            ukeys(`KMAX') closed(`cl') binary be(binary)
        _v1510_cell, label("binary minkey openlo `cl'") expect(1) mlo(.) mhi(0) ///
            ukeys(`KMIN') closed(`cl') binary be(binary)
        _v1510_cell, label("binary both open `cl'") expect(2) mlo(.) mhi(.) ///
            ukeys(`KMAX' `KMIN') closed(`cl') binary be(binary)
        _v1510_cell, label("binary maxkey finite hi `cl'") expect(0) mlo(0) mhi(1e300) ///
            ukeys(`KMAX') closed(`cl') binary be(binary)
        _v1510_cell, label("binary minkey finite lo `cl'") expect(0) mlo(-1e300) mhi(0) ///
            ukeys(`KMIN') closed(`cl') binary be(binary)
    }
    assert "$V1510_BAD" == ""
}
if _rc {
    local ++FAIL
    display as error "FAIL: T5 open bounds at the double limits (binary): $V1510_BAD"
}
else {
    local ++PASS
    display as result "PASS: T5 open bounds at the double limits (binary)"
}

**# T6: nearest() with open bounds at the double limits
local ++TESTS
global V1510_BAD ""
capture noisily {
    foreach cl in left none {
        * master key 5, [0, .): the only using key is c(maxdouble), at or after 5
        foreach nr in after both {
            _v1510_cell, label("near `nr' maxkey `cl'") expect(1) mlo(0) mhi(.) ///
                mkey(5) ukeys(`KMAX') closed(`cl') nearest(`nr') be(binary)
        }
        _v1510_cell, label("near before maxkey `cl'") expect(0) mlo(0) mhi(.) ///
            mkey(5) ukeys(`KMAX') closed(`cl') nearest(before)
    }
    foreach cl in right none {
        foreach nr in before both {
            _v1510_cell, label("near `nr' minkey `cl'") expect(1) mlo(.) mhi(0) ///
                mkey(5) ukeys(`KMIN') closed(`cl') nearest(`nr') be(binary)
        }
    }
    * nearest picks the near row, not the extreme one, when both qualify
    _v1510_pt, mlo(.) mhi(.) mkey(5) ukeys(`KMAX' 7 `KMIN') closed(none) ///
        nearest(after)
    assert r(mp) == 1
    quietly levelsof uid2 if mid < . & uid2 < ., local(picked)
    assert "`picked'" == "2"
    _v1510_pt, mlo(.) mhi(.) mkey(5) ukeys(`KMAX' 3 `KMIN') closed(none) ///
        nearest(before)
    assert r(mp) == 1
    quietly levelsof uid2 if mid < . & uid2 < ., local(picked)
    assert "`picked'" == "2"
    * with tolerance and ties
    _v1510_cell, label("near maxkey tol ties") expect(1) mlo(0) mhi(.) ///
        mkey(5) ukeys(`KMAX') closed(none) tol(0.5) nearest(after) ties(first)
    assert "$V1510_BAD" == ""
}
if _rc {
    local ++FAIL
    display as error "FAIL: T6 nearest() with open bounds at the limits: $V1510_BAD"
}
else {
    local ++PASS
    display as result "PASS: T6 nearest() with open bounds at the limits"
}

**# T7: overlap mode with open bounds at the double limits
local ++TESTS
global V1510_BAD ""
capture noisily {
    * closed(none): master (-inf,3) vs using (-inf, 2*mindouble): both open below
    _v1510_ocell, label("ov none (.,3) vs (.,min)") expect(1) mlo(.) mhi(3) ///
        ulo(.) uhi(`KMIN') closed(none)
    * master (-inf, 2*mindouble) vs using (-inf,5)
    _v1510_ocell, label("ov none (.,min) vs (.,5)") expect(1) mlo(.) ///
        mhi(`KMIN') ulo(.) uhi(5) closed(none)
    * (maxdouble, inf) vs (maxdouble, inf) and vs (5, inf)
    _v1510_ocell, label("ov none (max,.) vs (max,.)") expect(1) mlo(`KMAX') ///
        mhi(.) ulo(`KMAX') uhi(.) closed(none)
    _v1510_ocell, label("ov none (max,.) vs (5,.)") expect(1) mlo(`KMAX') ///
        mhi(.) ulo(5) uhi(.) closed(none)
    _v1510_ocell, label("ov none (5,.) vs (max,.)") expect(1) mlo(5) mhi(.) ///
        ulo(`KMAX') uhi(.) closed(none)
    _v1510_ocell, label("ov none (.,min) vs (5,.)") expect(0) mlo(.) ///
        mhi(`KMIN') ulo(5) uhi(.) closed(none)
    _v1510_ocell, label("ov none (min,.) vs (.,min)") expect(0) mlo(`KMIN') ///
        mhi(.) ulo(.) uhi(`KMIN') closed(none)
    * (-inf,m) and (m,inf) touch only at m: empty intersection under none ...
    _v1510_ocell, label("ov none (.,min) vs (min,.)") expect(0) mlo(.) ///
        mhi(`KMIN') ulo(`KMIN') uhi(.) closed(none)
    * ... and meet at m under both
    _v1510_ocell, label("ov both (.,min) vs (min,.)") expect(1) mlo(.) ///
        mhi(`KMIN') ulo(`KMIN') uhi(.) closed(both)
    _v1510_ocell, label("ov both (max,.) vs (.,max)") expect(1) mlo(`KMAX') ///
        mhi(.) ulo(.) uhi(`KMAX') closed(both)
    _v1510_ocell, label("ov none (max,.) vs (.,max)") expect(0) mlo(`KMAX') ///
        mhi(.) ulo(.) uhi(`KMAX') closed(none)
    assert "$V1510_BAD" == ""
}
if _rc {
    local ++FAIL
    display as error "FAIL: T7 overlap open bounds at the limits: $V1510_BAD"
}
else {
    local ++PASS
    display as result "PASS: T7 overlap open bounds at the limits"
}

**# T8: tolerance shift past the double range is an open bound
local ++TESTS
global V1510_BAD ""
capture noisily {
    foreach cl in left none {
        * hi + 1e300 overflows: the upper side is open, so key = hi = maxdouble matches
        _v1510_cell, label("overflow hi `cl'") expect(1) mlo(0) mhi(`KMAX') ///
            ukeys(`KMAX') closed(`cl') tol(1e300) be(sweep)
        _v1510_cell, label("overflow hi binary `cl'") expect(1) mlo(0) mhi(`KMAX') ///
            ukeys(`KMAX') closed(`cl') tol(1e300) binary be(binary)
    }
    foreach cl in right none {
        _v1510_cell, label("overflow lo `cl'") expect(1) mlo(`KMIN') mhi(0) ///
            ukeys(`KMIN') closed(`cl') tol(1e300) be(sweep)
        _v1510_cell, label("overflow lo binary `cl'") expect(1) mlo(`KMIN') mhi(0) ///
            ukeys(`KMIN') closed(`cl') tol(1e300) binary be(binary)
    }
    * controls: no overflow (maxdouble + 1 rounds to maxdouble): strict closure
    * still excludes a key equal to the bound
    _v1510_cell, label("no-overflow none") expect(0) mlo(0) mhi(`KMAX') ///
        ukeys(`KMAX') closed(none) tol(1)
    _v1510_cell, label("tol0 none") expect(0) mlo(0) mhi(`KMAX') ///
        ukeys(`KMAX') closed(none) tol(0)
    * overlap: widened master upper end is open, so it overlaps (max,.)
    _v1510_ocell, label("ov overflow hi") expect(1) mlo(0) mhi(`KMAX') ///
        ulo(`KMAX') uhi(.) closed(none) tol(1e300)
    _v1510_ocell, label("ov no tol hi") expect(0) mlo(0) mhi(`KMAX') ///
        ulo(`KMAX') uhi(.) closed(none) tol(0)
    _v1510_ocell, label("ov overflow lo") expect(1) mlo(`KMIN') mhi(0) ///
        ulo(.) uhi(`KMIN') closed(none) tol(1e300)
    _v1510_ocell, label("ov no tol lo") expect(0) mlo(`KMIN') mhi(0) ///
        ulo(.) uhi(`KMIN') closed(none) tol(0)
    assert "$V1510_BAD" == ""
}
if _rc {
    local ++FAIL
    display as error "FAIL: T8 overflowing tolerance shift is open: $V1510_BAD"
}
else {
    local ++PASS
    display as result "PASS: T8 overflowing tolerance shift is open"
}

**# T9: missing-key master rows with scalar-offset bounds match nothing
local ++TESTS
capture noisily {
    tempfile u
    clear
    quietly set obs 4
    quietly gen long uid = _n
    quietly gen double key = cond(_n == 1, 0, cond(_n == 2, -1, cond(_n == 3, c(maxdouble), 2*c(mindouble))))
    quietly save `"`u'"'
    foreach tol in 0 0.5 1 8e307 {
        foreach cl in both left right none {
            clear
            quietly set obs 2
            quietly gen long mid0 = _n
            quietly gen double key = cond(_n == 1, ., 0)
            quietly rangematch key -2 2 using `"`u'"', closed(`cl') ///
                tolerance(`tol') unmatched(master) usingid(uid2)
            assert r(N_master_key_missing) == 1
            * the missing-key master row (mid0 == 1) is output once, unmatched
            quietly count if mid0 == 1
            assert r(N) == 1
            quietly count if mid0 == 1 & uid2 < .
            assert r(N) == 0
            * the control master row (key 0) is unaffected: keys 0 and -1 are inside
            quietly count if mid0 == 2 & uid2 < .
            assert r(N) == 2
        }
    }
}
if _rc {
    local ++FAIL
    display as error "FAIL: T9 missing-key master row matches nothing under tolerance"
}
else {
    local ++PASS
    display as result "PASS: T9 missing-key master row matches nothing under tolerance"
}

**# T10: seeded fuzz of nearest() x ties() with open bounds and tolerance
* Oracle (from the help text): a master row with a missing key matches nothing;
* a using row with a missing key never matches; a missing bound removes only its
* own side; a master interval is empty iff (low - t) > (high + t); the closure
* then decides the endpoints on the widened bounds; nearest() works inside that
* in-range set, with before = using key <= master key, after = using key >=
* master key, both = min |distance|; ties(first|last) keep the lowest|highest
* original using row, ties(all) keeps every equally near row (both sides for
* nearest(both)). Built with joinby/cross; rangematch is not involved.
capture program drop _v1510_fz_data
program define _v1510_fz_data
    args seed nm nu ng pm mpath upath
    clear
    set seed `seed'
    quietly set obs `nm'
    quietly gen long mrow = _n
    quietly gen byte g = 1 + floor(runiform() * `ng')
    quietly gen double key = floor(runiform() * 12)
    quietly gen double lo = floor(runiform() * 12) - 2
    quietly gen double hi = lo + floor(runiform() * 6) - 1
    quietly replace lo = 2*c(mindouble) if runiform() < .08
    quietly replace hi = c(maxdouble) if runiform() < .08
    quietly replace key = . if runiform() < `pm' / 2
    quietly replace lo = . if runiform() < `pm'
    quietly replace hi = . if runiform() < `pm'
    quietly save `"`mpath'"', replace
    clear
    quietly set obs `nu'
    quietly gen long urow = _n
    quietly gen byte g = 1 + floor(runiform() * `ng')
    quietly gen double key = floor(runiform() * 12)
    quietly replace key = . if runiform() < `pm' / 2
    quietly save `"`upath'"', replace
end

capture program drop _v1510_fz_oracle
program define _v1510_fz_oracle
    args closed tol near ties useby mpath upath opath
    quietly use `"`mpath'"', clear
    quietly rename key mkey
    if `useby' {
        quietly joinby g using `"`upath'"'
    }
    else {
        quietly drop g
        quietly cross using `"`upath'"'
    }
    quietly drop if missing(mkey) | missing(key)
    * widened emptiness only when both bounds exist
    quietly drop if !missing(lo, hi) & (lo - `tol') > (hi + `tol')
    local lc = inlist("`closed'", "both", "left")
    local hc = inlist("`closed'", "both", "right")
    if `lc' quietly drop if !missing(lo) & !(key >= lo - `tol')
    else    quietly drop if !missing(lo) & !(key >  lo - `tol')
    if `hc' quietly drop if !missing(hi) & !(key <= hi + `tol')
    else    quietly drop if !missing(hi) & !(key <  hi + `tol')
    quietly gen double d = key - mkey
    if "`near'" == "before" quietly keep if d <= 0
    if "`near'" == "after" quietly keep if d >= 0
    quietly gen double ad = abs(d)
    quietly bysort mrow (ad): keep if ad == ad[1]
    if "`ties'" == "first" quietly bysort mrow (urow): keep if _n == 1
    if "`ties'" == "last" quietly bysort mrow (urow): keep if _n == _N
    keep mrow urow
    sort mrow urow
    quietly save `"`opath'"', replace
end

local ++TESTS
local fz_bad 0
local fz_runs 0
local fz_nonempty 0
capture noisily {
    tempfile fm fu fo
    local closedlist both left right none
    local nearlist before after both
    local tieslist all first last
    local tollist 0.5 1 2
    forvalues s = 1/288 {
        local cl : word `=1 + mod(`s', 4)' of `closedlist'
        local nr : word `=1 + mod(`s', 3)' of `nearlist'
        local ti : word `=1 + mod(floor(`s' / 12), 3)' of `tieslist'
        local tol : word `=1 + mod(`s', 3)' of `tollist'
        if mod(`s', 5) == 0 local tol 0
        local useby = mod(floor(`s' / 3), 2)
        local nm = 6 + mod(`s' * 7, 25)
        local nu = 5 + mod(`s' * 11, 35)
        local pm = cond(mod(`s', 2) == 0, 0.25, 0.08)
        _v1510_fz_data `s' `nm' `nu' 3 `pm' `"`fm'"' `"`fu'"'
        _v1510_fz_oracle `cl' `tol' `nr' `ti' `useby' `"`fm'"' `"`fu'"' `"`fo'"'
        quietly use `"`fo'"', clear
        quietly count
        local exp_n = r(N)
        if `exp_n' > 0 local ++fz_nonempty
        quietly use `"`fm'"', clear
        local byopt = cond(`useby', "by(g)", "")
        capture quietly rangematch key lo hi using `"`fu'"', `byopt' ///
            closed(`cl') tolerance(`tol') nearest(`nr') ties(`ti') ///
            unmatched(none) keepusing(urow)
        local ++fz_runs
        if _rc {
            display as error "rc=`=_rc' s=`s' `cl' `nr' `ti' tol=`tol'"
            local ++fz_bad
            continue
        }
        local got_n = _N
        keep mrow urow
        sort mrow urow
        quietly merge 1:1 mrow urow using `"`fo'"'
        quietly count if _merge != 3
        if r(N) > 0 | `got_n' != `exp_n' {
            display as error "MISMATCH s=`s' `cl' near=`nr' ties=`ti' tol=`tol' by=`useby' got=`got_n' want=`exp_n'"
            local ++fz_bad
        }
    }
    display as text "fuzz runs `fz_runs', oracle-nonempty `fz_nonempty', mismatches `fz_bad'"
    assert `fz_runs' == 288
    * the fuzz must exercise matches, not compare empty to empty
    assert `fz_nonempty' > 200
    assert `fz_bad' == 0
}
if _rc {
    local ++FAIL
    display as error "FAIL: T10 nearest x ties fuzz matches the documented oracle"
}
else {
    local ++PASS
    display as result "PASS: T10 nearest x ties fuzz matches the documented oracle"
}

display "RESULT: test_rangematch_v1510 tests=`TESTS' pass=`PASS' fail=`FAIL'"
if `FAIL' > 0 exit 1
