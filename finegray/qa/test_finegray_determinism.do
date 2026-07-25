* test_finegray_determinism.do
* Repeat-call determinism for every finegray command (v1.2.0).
*
* WHY THIS SUITE EXISTS -- the axis nobody was probing.
*
* Before this suite the package had 15 test suites, 9 validations and 6 crossvals,
* and every assertion in all of them asked the same KIND of question: "is this
* value right, against an oracle or a known truth?"  Not one asked "does an
* identical call return an identical value?"  A defect on that axis was
* therefore invisible at any suite size -- and there was one.
*
* finegray_phtest sorted the estimation sample with a bare `sort _t'.  The Mata
* scan breaks its own ties by ROW INDEX (order((t, row_id), (1, 2))), so the
* incoming Stata row order IS the tiebreak; and Stata resolves `sort' ties from
* a seed that ADVANCES on every sort.  Two identical finegray_phtest calls
* therefore accumulated the risk sets in different floating-point orders.
* Measured on the T1 fixture below: rho moved by ~8e-16 across six identical
* calls.  finegray.ado:792 and finegray_predict.ado:700,777 had stamped a row
* id for exactly this reason since 1.1.x; finegray_phtest was the one command
* that had not.
*
* T2 FAILS on the pre-fix build (1.2.0 as of 2026-07-23) and passes on the
* shipped 1.2.0.  Watched failing before the fix landed.
*
* The tolerance here is ZERO -- these are bit-equality assertions, deliberately.
* A "small enough" tolerance would defeat the purpose: the whole point is that
* the same input must produce the same output, and any nonzero drift means the
* accumulation order is not pinned.  This is the one place in the suite where
* exact equality is the correct assertion rather than a summation-order test
* (contrast test_finegray_ties.do FG-C03, which compares two GENUINELY
* different datasets and rightly uses 1e-12).
clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_determinism.log", replace name(_fgdet)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* Heavily TIED fixture.  Ties are the whole mechanism: with continuous times
* every _t is distinct, `sort _t' is already a total order, and the defect
* cannot appear.  Discrete times 1..12 put hundreds of rows on each event time.
* Verified below (T0) rather than assumed -- a fixture that silently stopped
* being tied would make every test here vacuously green.
capture program drop _mk_fgdet
program define _mk_fgdet
    version 16.0
    syntax [, N(integer 1200) SEED(integer 20260725) LT(integer 0)]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen double x1 = rnormal()
    gen byte x2 = rbinomial(1, 0.4)
    gen byte grp = 1 + int(runiform() * 3)
    gen double lat  = ceil(runiform() * 12)
    gen double lat2 = ceil(runiform() * 12)
    gen double cen  = ceil(runiform() * 15)
    gen byte ev = cond(lat <= lat2, 1, 2)
    gen double t = min(lat, lat2)
    quietly replace ev = 0 if cen < t
    quietly replace t = min(t, cen)
    if `lt' {
        gen double ent = cond(runiform() < 0.5, ceil(runiform() * 4), 0)
        quietly drop if t <= ent
        quietly stset t, failure(ev == 1 2) id(id) enter(time ent)
    }
    else {
        quietly stset t, failure(ev == 1 2) id(id)
    }
    drop lat lat2 cen
end

**# 0. The fixture really is tied (guards every test below from going vacuous)
local ++test_count
capture noisily {
    _mk_fgdet
    quietly count
    local _n_all = r(N)
    tempvar nt
    quietly bysort t: gen long `nt' = _N
    quietly summarize `nt', meanonly
    local _maxtie = r(max)
    quietly levelsof t, local(_ut)
    local _nut : word count `_ut'
    display as text "  n=`_n_all', distinct event times=`_nut', max rows sharing a time=`_maxtie'"
    * Hundreds of rows per time, and far fewer distinct times than rows.
    assert `_maxtie' >= 50
    assert `_nut' < `_n_all' / 10
}
if _rc == 0 {
    display as result "  PASS: DET-0 fixture is heavily tied (ties are the mechanism)"
    local ++pass_count
}
else {
    display as error "  FAIL: DET-0 fixture tie density (rc=`=_rc')"
    local ++fail_count
}

**# 1. finegray: six identical fits are bit-identical in e(b) AND e(V)
local ++test_count
capture noisily {
    _mk_fgdet
    forvalues r = 1/6 {
        quietly finegray x1 x2, compete(ev) cause(1) nolog
        tempname B`r' V`r'
        matrix `B`r'' = e(b)
        matrix `V`r'' = e(V)
    }
    forvalues r = 2/6 {
        * mreldif of identical matrices is exactly 0; anything else is drift.
        assert mreldif(`B`r'', `B1') == 0
        assert mreldif(`V`r'', `V1') == 0
    }
    display as text "  6 fits, mreldif(e(b)) = 0, mreldif(e(V)) = 0"
}
if _rc == 0 {
    display as result "  PASS: DET-1 finegray fit is bit-reproducible"
    local ++pass_count
}
else {
    display as error "  FAIL: DET-1 finegray fit reproducibility (rc=`=_rc')"
    local ++fail_count
}

**# 2. finegray_phtest: six identical calls are bit-identical  [FAILS PRE-FIX]
* This is the regression test for the phtest sort fix.  Before it, the correlations
* drift in their last digits between calls and the exact-equality assert fires.
local ++test_count
capture noisily {
    _mk_fgdet
    quietly finegray x1 x2, compete(ev) cause(1) nolog
    forvalues r = 1/6 {
        quietly finegray_phtest, time(rank)
        tempname P`r'
        matrix `P`r'' = r(phtest)
    }
    local _maxdrift = 0
    forvalues r = 2/6 {
        forvalues k = 1/2 {
            local _d = abs(`P`r''[`k', 1] - `P1'[`k', 1])
            local _maxdrift = max(`_maxdrift', `_d')
        }
    }
    display as text "  max |rho_r - rho_1| over 5 repeats = " %10.3e `_maxdrift'
    assert `_maxdrift' == 0
}
if _rc == 0 {
    display as result "  PASS: DET-2 finegray_phtest is bit-reproducible"
    local ++pass_count
}
else {
    display as error "  FAIL: DET-2 finegray_phtest reproducibility (rc=`=_rc')"
    local ++fail_count
}

**# 3. finegray_phtest is reproducible on every time() transform
local ++test_count
capture noisily {
    _mk_fgdet
    quietly finegray x1 x2, compete(ev) cause(1) nolog
    foreach tf in rank log identity {
        quietly finegray_phtest, time(`tf')
        tempname A_`tf'
        matrix `A_`tf'' = r(phtest)
        quietly finegray_phtest, time(`tf')
        tempname B_`tf'
        matrix `B_`tf'' = r(phtest)
        assert mreldif(`A_`tf'', `B_`tf'') == 0
    }
    display as text "  rank/log/identity all bit-stable across repeat calls"
}
if _rc == 0 {
    display as result "  PASS: DET-3 phtest stable on all time() transforms"
    local ++pass_count
}
else {
    display as error "  FAIL: DET-3 phtest time() transforms (rc=`=_rc')"
    local ++fail_count
}

**# 4. finegray_phtest is reproducible under delayed entry + strata
* The ZZF branch is a DIFFERENT Mata routine (_finegray_schoenfeld_zzf) with its
* own tie handling, so right-censoring coverage does not speak for it.
local ++test_count
capture noisily {
    _mk_fgdet, lt(1)
    quietly finegray x1 x2, compete(ev) cause(1) nolog ///
        strata(grp) truncstrata(grp)
    assert "`e(lt_weight)'" != "right_censoring"
    display as text "  lt_weight = `e(lt_weight)'"
    forvalues r = 1/4 {
        quietly finegray_phtest
        tempname L`r'
        matrix `L`r'' = r(phtest)
    }
    forvalues r = 2/4 {
        assert mreldif(`L`r'', `L1') == 0
    }
}
if _rc == 0 {
    display as result "  PASS: DET-4 phtest bit-stable on the ZZF/LT branch"
    local ++pass_count
}
else {
    display as error "  FAIL: DET-4 phtest under delayed entry (rc=`=_rc')"
    local ++fail_count
}

**# 5. finegray_predict, schoenfeld: repeat calls produce identical columns
local ++test_count
capture noisily {
    _mk_fgdet
    quietly finegray x1 x2, compete(ev) cause(1) nolog
    quietly finegray_predict sra, schoenfeld
    quietly finegray_predict srb, schoenfeld
    * Schoenfeld residuals are defined only at cause-event rows, so most rows
    * are missing in BOTH columns -- and in Stata `. == .' is TRUE, so a bare
    * `assert sra == srb' would pass on two all-missing columns.  Pin the
    * non-missing count first so the equality assert cannot go vacuous.
    quietly count if !missing(sra)
    local _nnm = r(N)
    assert `_nnm' > 100
    quietly count if !missing(srb)
    assert r(N) == `_nnm'
    * `==' on doubles is bit equality.
    assert sra == srb
    assert sra_2 == srb_2
    display as text "  `_nnm' residual rows, bit-identical in both columns"
}
if _rc == 0 {
    display as result "  PASS: DET-5 predict, schoenfeld is bit-reproducible"
    local ++pass_count
}
else {
    display as error "  FAIL: DET-5 predict schoenfeld reproducibility (rc=`=_rc')"
    local ++fail_count
}

**# 6. finegray_predict, cif and xb: repeat calls produce identical columns
local ++test_count
capture noisily {
    _mk_fgdet
    quietly finegray x1 x2, compete(ev) cause(1) nolog
    quietly finegray_predict cifa, cif
    quietly finegray_predict cifb, cif
    quietly count if !missing(cifa)
    assert r(N) > 100
    assert cifa == cifb
    quietly finegray_predict xba, xb
    quietly finegray_predict xbb, xb
    quietly count if !missing(xba)
    assert r(N) > 100
    assert xba == xbb
    display as text "  cif and xb both bit-identical across repeat calls"
}
if _rc == 0 {
    display as result "  PASS: DET-6 predict cif/xb are bit-reproducible"
    local ++pass_count
}
else {
    display as error "  FAIL: DET-6 predict cif/xb reproducibility (rc=`=_rc')"
    local ++fail_count
}

**# 7. finegray_cif: repeat calls return an identical r(table)
local ++test_count
capture noisily {
    _mk_fgdet
    quietly finegray x1 x2, compete(ev) cause(1) nolog
    quietly finegray_cif, at(x1=0 x2=1) attime(3 5 8) ci
    tempname C1
    matrix `C1' = r(table)
    quietly finegray_cif, at(x1=0 x2=1) attime(3 5 8) ci
    tempname C2
    matrix `C2' = r(table)
    assert mreldif(`C1', `C2') == 0
    display as text "  r(table) identical across repeat finegray_cif calls"
}
if _rc == 0 {
    display as result "  PASS: DET-7 finegray_cif is bit-reproducible"
    local ++pass_count
}
else {
    display as error "  FAIL: DET-7 finegray_cif reproducibility (rc=`=_rc')"
    local ++fail_count
}

**# 8. Interleaving post-estimation calls does not perturb any of them
* Each post-est command rebuilds the weight design from e(); if any of them left
* residue (a sort order, a stale cache slot, a leftover column) the SECOND
* sequence would differ from the first.  This is the ordering-independence
* contract, which repeat-call tests alone do not cover.
local ++test_count
capture noisily {
    _mk_fgdet
    quietly finegray x1 x2, compete(ev) cause(1) nolog

    quietly finegray_phtest
    tempname S1
    matrix `S1' = r(phtest)
    quietly finegray_cif, at(x1=0 x2=1) attime(5) ci
    tempname S2
    matrix `S2' = r(table)

    * ... now run them in the other order, with a predict in between ...
    quietly finegray_predict zz, cif
    quietly finegray_cif, at(x1=0 x2=1) attime(5) ci
    tempname S4
    matrix `S4' = r(table)
    quietly finegray_phtest
    tempname S3
    matrix `S3' = r(phtest)

    assert mreldif(`S3', `S1') == 0
    assert mreldif(`S4', `S2') == 0
    display as text "  phtest and cif agree regardless of call order"
}
if _rc == 0 {
    display as result "  PASS: DET-8 post-estimation calls are order-independent"
    local ++pass_count
}
else {
    display as error "  FAIL: DET-8 post-estimation call ordering (rc=`=_rc')"
    local ++fail_count
}

**# 9. phtest agrees with the raw Schoenfeld residuals it claims to scale
* The reported correlation is invariant to the diagonal scaling (a positive
* per-column constant), so it must equal the correlation of the UNSCALED
* residuals from finegray_predict, schoenfeld with the same time function.
* This is an independent-route oracle: it recomputes rho through a different
* command and Stata's own correlate, not through the phtest code path.  It also
* pins the documented claim in finegray_phtest.sthlp that the scaling cannot
* change the reported number.
local ++test_count
capture noisily {
    _mk_fgdet
    quietly finegray x1 x2, compete(ev) cause(1) nolog
    quietly finegray_phtest, time(rank)
    tempname PH
    matrix `PH' = r(phtest)
    local rho1 = `PH'[1, 1]
    local rho2 = `PH'[2, 1]

    quietly finegray_predict sr, schoenfeld
    preserve
        quietly keep if !missing(sr)
        tempvar rk
        quietly egen double `rk' = rank(_t)
        quietly correlate sr `rk'
        local orho1 = r(rho)
        quietly correlate sr_2 `rk'
        local orho2 = r(rho)
    restore
    display as text "  phtest rho = " %12.9f `rho1' " / " %12.9f `rho2'
    display as text "  unscaled  rho = " %12.9f `orho1' " / " %12.9f `orho2'
    * ABSOLUTE tolerance, not relative.  rho lives in [-1,1] and is near zero
    * here, so its covariance is a small difference of large sums: the two
    * paths feed correlate() residuals that differ by a constant factor, and
    * that cancellation costs a few ulp of the SUMS, not of rho.  A relative
    * tolerance divides by a near-zero rho and turns 8e-9 of absolute noise
    * into 1.6e-7 of "relative error" -- which is why 1e-9 relative failed on
    * a claim that is exactly true.
    *
    * 1e-6 is ~2 orders above the observed noise (8e-9 on this fixture) and 4+
    * orders below the effect it guards: a genuine off-diagonal (full-matrix)
    * scaling mixes covariates and moves these correlations by O(0.01-0.1).
    local _d1 = abs(`rho1' - `orho1')
    local _d2 = abs(`rho2' - `orho2')
    display as text "  absolute difference = " %10.3e `_d1' " / " %10.3e `_d2'
    assert `_d1' < 1e-6
    assert `_d2' < 1e-6
}
if _rc == 0 {
    display as result "  PASS: DET-9 phtest rho == unscaled Schoenfeld/time rho"
    local ++pass_count
}
else {
    display as error "  FAIL: DET-9 phtest vs unscaled residual correlation (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_determinism tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fgdet
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fgdet
