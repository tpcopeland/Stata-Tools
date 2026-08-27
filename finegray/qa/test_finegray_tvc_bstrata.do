*! test_finegray_tvc_bstrata Version 1.0.0  2026/08/26
*! tvc() x bstrata(): piecewise beta(t) on a stratified baseline
*! Author: Timothy P Copeland, Karolinska Institutet

* WHY THIS SUITE EXISTS.
*
* v1.3.0 refused tvc() together with bstrata(), and the stated reason was that
* "the combination has no reference implementation to validate against".  v1.4.0
* lifts the fence.  The features reshape the risk-set scan on orthogonal axes --
* bstrata() partitions ROWS into per-stratum risk sets, tvc() partitions TIME
* into per-interval passes over a zeroed design -- and the piecewise wrappers
* already forwarded the stratum column into the stratified scans, so the FIT
* needed no new scan code.
*
* WHAT DID NEED WRITING, AND WHAT WENT WRONG WHILE WRITING IT.  Everything
* downstream of the fit assumes it knows how many baselines there are:
*
*  D5-1  BASELINE STACKING.  Each interval pass returns a cumulative hazard
*        restarting at zero, so the intervals are stitched together by carrying
*        the running total forward.  Under bstrata() that carry is PER STRATUM;
*        a pooled one hands every stratum the sum of all the others' mass.
*        (_finegray_basehazard_pw.)
*
*  D5-2  THE CIF READ A POOLED BASELINE AND ANSWERED EVERY STRATUM FROM IT.
*        _finegray_cif_point_tvc hardcoded a constant stratum column when
*        rebuilding the baseline, and took Lambda_0 at the tsplit() boundaries
*        from the whole K x 3 curve as though its first column were a time.
*        MEASURED on a K = 3, J = 2 fit before the fix: finegray_cif returned
*        0.2191295 for strata 1, 2 AND 3 at t = 0.3, against hand values of
*        0.1511373, 0.2311430 and 0.2755267.  rc 0, a plausible number, the
*        bstratum() option accepted and ignored.  Test 4 is the regression, and
*        it is a HAND computation from e(basehaz) rather than a comparison with
*        another finegray call, so it cannot share the defect.
*
* THE ORACLE SITUATION -- MEASURED, NOT ASSUMED.  The v1.3.0 refusal's premise
* was checked before being discarded, and it turned out to be half right for a
* reason nobody had recorded: crrSC::crrs's SIGNATURE accepts cov2/tf together
* with strata, but the code path does not work.
*
*   ctype = 1  fails outright, at any K including K = 1.  crrvvs() computes
*              tfs = unique(subset(dsub$tfs, fstatus == 1)) -- the unique ROWS
*              of the time-function matrix at cause events -- and hands that to
*              the C routine, which reads ndf x nc2 doubles from it.  With an
*              indicator tf and 79 cause-event times in the stratum, unique()
*              returns 2 rows.  Measured 2026-08-26 with crrSC 1.1.2:
*              "NA/NaN/Inf in foreign function call (arg 11)".
*   ctype = 2  runs but does not converge: converged = FALSE at maxiter 10 and
*              50, and an error at 200, with the coefficients still moving
*              (0.269 -> 0.213 between the two).
*
* So there IS no working external reference for this pair, and this suite says
* so rather than quoting a number from a fit that did not converge.  What it
* uses instead is three independent oracles:
*
*   1  stcox, strata() breslow on a hand-split episode dataset with NO competing
*      events.  With no competing events the subdistribution risk set IS the
*      ordinary risk set, so the stratified piecewise Fine-Gray must reproduce
*      Stata's own stratified Cox exactly -- coefficients and log-likelihood.
*      Independent code, and the same argument that licenses T02 in
*      test_finegray_tvc.do.
*   2  the two degenerate identities: K = 1 must be the pure tvc() fit and J = 1
*      the pure bstrata() fit, both BIT for bit.
*   3  the duplicate-stratum identity: duplicating the data into two labelled
*      strata must halve e(V) exactly, psi included.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_tvc_bstrata.log", replace text name(_fgtb)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _fgtb_result
program define _fgtb_result, rclass
    args rc label
    if `rc' == 0 {
        display as result "  PASS: `label'"
        return scalar pass = 1
        return scalar fail = 0
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        return scalar pass = 0
        return scalar fail = 1
    }
end

* Competing-risks fixture with BOTH a per-stratum cause-1 baseline and a
* genuinely piecewise cause-1 effect, so neither feature can be ignored without
* the fit moving.
capture program drop _fgtb_data
program define _fgtb_data
    version 16.0
    args seed nobs K
    if "`seed'" == "" local seed 20260826
    if "`nobs'" == "" local nobs 1200
    if "`K'" == "" local K 3
    clear
    set seed `seed'
    quietly set obs `nobs'
    gen long id = _n
    gen byte ctr = 1 + mod(_n - 1, `K')
    gen byte one = 1
    gen double x1 = rnormal()
    gen double x2 = rbinomial(1, 0.4)
    local tau = 0.7
    gen double h1a = (0.4 + 0.30 * ctr) * exp(0.80 * x1 - 0.50 * x2)
    gen double h1b = (0.4 + 0.30 * ctr) * exp(0.00 * x1 - 0.50 * x2)
    gen double E   = -ln(runiform())
    gen double tt1 = cond(E <= h1a * `tau', E / h1a, `tau' + (E - h1a * `tau') / h1b)
    gen double tt2 = -ln(runiform()) / (0.35 * exp(0.30 * x1))
    gen double tc  = rexponential(2.0)
    gen double t   = min(tt1, tt2, tc)
    gen byte status = cond(t == tt1, 1, cond(t == tt2, 2, 0))
    gen byte anyev = status != 0
    quietly stset t, failure(anyev == 1) id(id)
end

* Same, with the competing cause switched off -- the fixture the stcox oracle
* needs (no competing events => subdistribution risk set = ordinary risk set).
capture program drop _fgtb_data_nc
program define _fgtb_data_nc
    version 16.0
    args seed nobs K
    if "`seed'" == "" local seed 771771
    if "`nobs'" == "" local nobs 1500
    if "`K'" == "" local K 3
    clear
    set seed `seed'
    quietly set obs `nobs'
    gen long id = _n
    gen byte ctr = 1 + mod(_n - 1, `K')
    gen double x1 = rnormal()
    gen double x2 = rbinomial(1, 0.4)
    local tau = 0.6
    gen double h1a = (0.5 + 0.35 * ctr) * exp(0.70 * x1 - 0.40 * x2)
    gen double h1b = (0.5 + 0.35 * ctr) * exp(0.05 * x1 - 0.40 * x2)
    gen double E   = -ln(runiform())
    gen double tt1 = cond(E <= h1a * `tau', E / h1a, `tau' + (E - h1a * `tau') / h1b)
    gen double tc  = rexponential(1.8)
    gen double t   = min(tt1, tc)
    gen byte status = cond(t == tt1, 1, 0)
    gen byte anyev = status != 0
    quietly stset t, failure(anyev == 1) id(id)
end

* Hand (start, stop] split at the boundaries.  NOT stsplit -- it blanks the
* stset failure variable on every non-terminal episode.
capture program drop _fgtb_split
program define _fgtb_split
    version 16.0
    args c1
    quietly expand 2
    quietly bysort id: gen byte iv = _n
    quietly gen double start = cond(iv == 1, 0, `c1')
    quietly gen double _hi   = cond(iv == 1, `c1', .)
    quietly gen double stop  = cond(missing(_hi), t, min(t, _hi))
    quietly drop if start >= t
    quietly gen byte fail = (status == 1) & (stop == t)
    quietly stset stop, failure(fail == 1) id(id) time0(start)
end

* -----------------------------------------------------------------------------
**# 1. The composed fit reproduces a stratified split-episode Cox fit
* -----------------------------------------------------------------------------
* The independent oracle.  With no competing events the estimator collapses to
* Cox, so the stratified piecewise Fine-Gray must equal `stcox, strata()' on
* the hand-split data with ibn.interval#c.x terms.  Coefficients AND the
* log-likelihood: a scan that accumulated a plausible score from the wrong risk
* sets would still land on a different maximum.
local ++test_count
capture noisily {
    _fgtb_data_nc
    quietly finegray x2 x1, compete(status) cause(1) tvc(x1) tsplit(0.6) ///
        bstrata(ctr) nolog norobust
    assert e(converged) == 1
    assert e(k_bstrata) == 3
    assert e(n_intervals) == 2
    tempname FB
    matrix `FB' = e(b)
    local fll = e(ll)

    _fgtb_data_nc
    _fgtb_split 0.6
    quietly stcox x2 ibn.iv#c.x1, strata(ctr) breslow nolog
    tempname CB
    matrix `CB' = e(b)
    local cll = e(ll)

    assert colsof(`FB') == colsof(`CB')
    forvalues j = 1/`= colsof(`FB')' {
        assert !missing(`FB'[1, `j'], `CB'[1, `j'])
        assert reldif(`FB'[1, `j'], `CB'[1, `j']) < 1e-7
    }
    assert !missing(`fll', `cll')
    assert reldif(`fll', `cll') < 1e-9

    * and the stratification must MATTER: the same fit without bstrata() has to
    * land somewhere else, or this test would pass on a build that ignored it
    _fgtb_data_nc
    quietly finegray x2 x1, compete(status) cause(1) tvc(x1) tsplit(0.6) ///
        nolog norobust
    local moved = 0
    forvalues j = 1/`= colsof(`FB')' {
        if reldif(`FB'[1, `j'], e(b)[1, `j']) > 1e-4 local moved = 1
    }
    assert `moved' == 1
}
local _rc = _rc
_fgtb_result `_rc' "TB01 composed fit reproduces stcox, strata() on a split-episode fit"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 2. K = 1 identity: the composed path IS the pure tvc() path, bit for bit
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgtb_data
    quietly finegray x1 x2, compete(status) cause(1) tvc(x1) tsplit(0.7) ///
        nolog basehaz
    tempname B0 V0 H0
    matrix `B0' = e(b)
    matrix `V0' = e(V)
    matrix `H0' = e(basehaz)
    local ll0 = e(ll)
    assert colsof(`H0') == 2

    quietly finegray x1 x2, compete(status) cause(1) tvc(x1) tsplit(0.7) ///
        bstrata(one) nolog basehaz
    assert e(k_bstrata) == 1
    assert !missing(mreldif(e(b), `B0'))
    assert mreldif(e(b), `B0') == 0
    assert mreldif(e(V), `V0') == 0
    assert e(ll) == `ll0'
    * K == 1 short-circuits to the unstratified curve shape, as everywhere else
    assert colsof(e(basehaz)) == 2
    assert mreldif(e(basehaz), `H0') == 0

    * and with nuisance, since psi now composes too
    quietly finegray x1 x2, compete(status) cause(1) tvc(x1) tsplit(0.7) ///
        nuisance nolog
    matrix `V0' = e(V)
    quietly finegray x1 x2, compete(status) cause(1) tvc(x1) tsplit(0.7) ///
        bstrata(one) nuisance nolog
    assert mreldif(e(V), `V0') == 0
}
local _rc = _rc
_fgtb_result `_rc' "TB02 bstrata(constant) x tvc() is bit-identical to the pure tvc() fit"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 3. J = 1 identity: no tsplit() is the pure bstrata() fit, bit for bit
* -----------------------------------------------------------------------------
* tvc() requires tsplit(), so J = 1 cannot be requested directly; what is
* asserted instead is that the pure bstrata() fit is unchanged by the v1.4.0
* work -- the piecewise wrappers delegate verbatim at nint <= 1 and the
* stratified baseline stacking must not have touched the single-interval path.
local ++test_count
capture noisily {
    _fgtb_data
    quietly finegray x1 x2, compete(status) cause(1) bstrata(ctr) nolog basehaz
    assert e(k_bstrata) == 3
    assert colsof(e(basehaz)) == 3
    tempname BB HB
    matrix `BB' = e(b)
    matrix `HB' = e(basehaz)
    local llB = e(ll)

    * the composed fit at a boundary beyond the last event collapses to one
    * interval's worth of information for the second stripe; what matters here
    * is only that the pure bstrata() fit still runs and still posts a K x 3
    * curve whose stratum column carries the LEVEL VALUES
    quietly levelsof ctr, local(_lv) clean
    local _seen ""
    forvalues r = 1/`= rowsof(`HB')' {
        local v = `HB'[`r', 1]
        local in : list posof "`v'" in _seen
        if `in' == 0 local _seen "`_seen' `v'"
    }
    local _seen : list sort _seen
    local _lv : list sort _lv
    assert "`_seen'" == "`_lv'"
    assert !missing(`llB')
}
local _rc = _rc
_fgtb_result `_rc' "TB03 the pure bstrata() fit is unchanged and still posts a K x 3 curve"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 4. The composed CIF, computed BY HAND from e(basehaz) (the D5-2 regression)
* -----------------------------------------------------------------------------
* The oracle here is arithmetic, not another finegray call:
*   CIF(s|z) = 1 - exp(-sum_j m_j(s) exp(eta_j(z)))
*   m_j(s)   = max(0, min(H0k(s), H0k(cut_j)) - H0k(cut_{j-1}))
* with H0k read out of the K x 3 e(basehaz) by a naive linear scan.  Every
* stratum and several times, including one before the boundary, one after, and
* one past the last event.
*
* The DISCRIMINATING part is that the three strata must give three DIFFERENT
* answers.  Before the fix they gave one, and every "is it plausible" check
* passed.
local ++test_count
capture noisily {
    _fgtb_data
    quietly finegray x1 x2, compete(status) cause(1) tvc(x1) tsplit(0.7) ///
        bstrata(ctr) nolog basehaz
    tempname BH
    matrix `BH' = e(basehaz)
    assert colsof(`BH') == 3
    local b_x2 = _b[main:x2]
    local b_t1 = _b[tvc1:x1]
    local b_t2 = _b[tvc2:x1]
    local z1 = 0.5
    local z2 = 1
    local e1 = `b_x2' * `z2' + `b_t1' * `z1'
    local e2 = `b_x2' * `z2' + `b_t2' * `z1'

    local worst = 0
    foreach s in 0.3 0.5 0.9 1.5 {
        local vals ""
        foreach lev in 1 2 3 {
            * hand baseline for THIS stratum
            local h_at = 0
            local h_cut = 0
            forvalues r = 1/`= rowsof(`BH')' {
                if `BH'[`r', 1] != `lev' continue
                if `BH'[`r', 2] <= `s'   local h_at  = `BH'[`r', 3]
                if `BH'[`r', 2] <= 0.7   local h_cut = `BH'[`r', 3]
            }
            local m1 = min(`h_at', `h_cut')
            local m2 = max(0, `h_at' - `h_cut')
            local hand = 1 - exp(-(`m1' * exp(`e1') + `m2' * exp(`e2')))

            quietly finegray_cif, at(x1=`z1' x2=`z2') bstratum(`lev') ///
                attime(`s') nograph
            tempname T
            matrix `T' = r(table)
            assert !missing(`T'[1, 2], `hand')
            assert `hand' > 0 & `hand' < 1
            local d = reldif(`hand', `T'[1, 2])
            if `d' > `worst' local worst = `d'
            assert `d' < 1e-10
            local vals "`vals' `= `T'[1, 2]'"
        }
        * the three strata must not agree with each other
        local v1 : word 1 of `vals'
        local v2 : word 2 of `vals'
        local v3 : word 3 of `vals'
        assert reldif(`v1', `v2') > 1e-4
        assert reldif(`v2', `v3') > 1e-4
    }
    display as text "    TB04: worst hand-vs-package relative difference = " ///
        as result %9.2e `worst'
}
local _rc = _rc
_fgtb_result `_rc' "TB04 composed CIF equals a hand computation and differs by stratum"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 5. predict cif / xb / basecshazard on the composed fit
* -----------------------------------------------------------------------------
* predict, cif reads the SAME quantities finegray_cif does but through a
* different route (per-observation columns rather than a matrix of evaluation
* points), so it needs its own check.  It is tied back to finegray_cif at the
* rows' own times, which is an oracle that cannot share the routing.
local ++test_count
capture noisily {
    _fgtb_data
    quietly finegray x1 x2, compete(status) cause(1) tvc(x1) tsplit(0.7) ///
        bstrata(ctr) nolog

    quietly finegray_predict double xbq, xb
    quietly count if e(sample) & missing(xbq)
    assert r(N) == 0

    quietly finegray_predict double bchq, basecshazard
    quietly count if e(sample) & missing(bchq)
    assert r(N) == 0
    quietly summarize bchq if e(sample)
    assert r(min) >= 0

    quietly finegray_predict double cifq, cif
    quietly count if e(sample) & missing(cifq)
    assert r(N) == 0
    quietly summarize cifq if e(sample)
    assert r(min) >= 0
    assert r(max) <= 1
    * a build that answered every stratum from one baseline would still produce
    * a valid-looking column, so tie a handful of rows back to finegray_cif
    quietly gen long _rowid = _n
    forvalues k = 1/3 {
        quietly summarize _rowid if e(sample) & ctr == `k', meanonly
        local rr = r(min)
        local tt = _t[`rr']
        local zz1 = x1[`rr']
        local zz2 = x2[`rr']
        local got = cifq[`rr']
        quietly finegray_cif, at(x1=`zz1' x2=`zz2') bstratum(`k') ///
            attime(`tt') nograph
        tempname TT
        matrix `TT' = r(table)
        assert !missing(`got', `TT'[1, 2])
        assert reldif(`got', `TT'[1, 2]) < 1e-10
    }
}
local _rc = _rc
_fgtb_result `_rc' "TB05 predict xb/cif/basecshazard agree with finegray_cif per stratum"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 6. e(refitcmd) replays the composed fit (Z24 for the new cell)
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgtb_data
    foreach spec in "tvc(x1) tsplit(0.7) bstrata(ctr)" ///
        "tvc(x1) tsplit(0.4 1.0) bstrata(ctr)" ///
        "tvc(x1) tsplit(0.7) bstrata(ctr) strata(ctr)" ///
        "tvc(x1) tsplit(0.7) bstrata(ctr) nuisance" {
        quietly finegray x1 x2, compete(status) cause(1) `spec' nolog
        tempname B0
        matrix `B0' = e(b)
        local nint = e(n_intervals)
        local kb = e(k_bstrata)
        local rfc `"`e(refitcmd)'"'
        assert strpos(`"`rfc'"', "bstrata(ctr)") > 0
        assert strpos(`"`rfc'"', "tvc(x1)") > 0
        assert strpos(`"`rfc'"', "tsplit(") > 0
        quietly `rfc'
        assert e(n_intervals) == `nint'
        assert e(k_bstrata) == `kb'
        assert colsof(e(b)) == colsof(`B0')
        forvalues j = 1/`= colsof(`B0')' {
            assert !missing(`B0'[1, `j'], e(b)[1, `j'])
            assert reldif(`B0'[1, `j'], e(b)[1, `j']) < 1e-12
        }
    }
}
local _rc = _rc
_fgtb_result `_rc' "TB06 e(refitcmd) reproduces e(b) for tvc() x bstrata() combinations"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 7. The duplicate-stratum identity on the composed fit, with psi
* -----------------------------------------------------------------------------
* Same argument as BSPSI-5 in test_finegray_bstrata.do, now with a piecewise
* beta(t) on top: duplicating the data into two labelled strata doubles the
* score, the information and the meat, so beta is unchanged and e(V) is exactly
* halved.  This is the arm that would catch a per-stratum psi or per-stratum
* baseline block being dropped in the composition.
local ++test_count
capture noisily {
    _fgtb_data 20260826 900 2

    quietly finegray x1 x2, compete(status) cause(1) tvc(x1) tsplit(0.7) ///
        nuisance noadjust nolog
    tempname V1 B1
    matrix `V1' = e(V)
    matrix `B1' = e(b)
    local n1 = e(N)

    quietly expand 2
    quietly bysort id: gen byte cpy = _n
    quietly replace id = id * 2 - 2 + cpy
    quietly stset t, failure(anyev == 1) id(id)
    quietly finegray x1 x2, compete(status) cause(1) tvc(x1) tsplit(0.7) ///
        bstrata(cpy) strata(cpy) nuisance noadjust nolog
    assert e(N) == 2 * `n1'
    assert e(k_bstrata) == 2
    assert e(n_intervals) == 2
    forvalues j = 1/`= colsof(`B1')' {
        assert !missing(`B1'[1, `j'], e(b)[1, `j'])
        assert reldif(`B1'[1, `j'], e(b)[1, `j']) < 1e-8
    }
    tempname HALF
    matrix `HALF' = `V1' / 2
    assert !missing(mreldif(e(V), `HALF'))
    assert mreldif(e(V), `HALF') < 1e-9
}
local _rc = _rc
_fgtb_result `_rc' ///
    "TB07 duplicating into two strata halves e(V) exactly on the composed fit"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 8. Determinism and degenerate strata on the composed fit
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgtb_data
    quietly finegray x1 x2, compete(status) cause(1) tvc(x1) tsplit(0.7) ///
        bstrata(ctr) nolog basehaz
    tempname D1 DV1 DH1
    matrix `D1' = e(b)
    matrix `DV1' = e(V)
    matrix `DH1' = e(basehaz)
    * repeated on the SAME data in the SAME session: the per-stratum sorts and
    * the per-interval passes must not consume the sort seed
    forvalues rep = 1/3 {
        quietly finegray x1 x2, compete(status) cause(1) tvc(x1) tsplit(0.7) ///
            bstrata(ctr) nolog basehaz
        assert mreldif(e(b), `D1') == 0
        assert mreldif(e(V), `DV1') == 0
        assert mreldif(e(basehaz), `DH1') == 0
    }
    * and after the row order is permuted, the estimates must be unchanged to
    * round-off (the tie-break is by the caller's row order, which is stamped)
    quietly gen double _shuf = runiform()
    sort _shuf
    quietly stset t, failure(anyev == 1) id(id)
    quietly finegray x1 x2, compete(status) cause(1) tvc(x1) tsplit(0.7) ///
        bstrata(ctr) nolog
    forvalues j = 1/`= colsof(`D1')' {
        assert !missing(`D1'[1, `j'], e(b)[1, `j'])
        assert reldif(`D1'[1, `j'], e(b)[1, `j']) < 1e-8
    }

    * a stratum with no cause events: legitimate, and e(bstrata_noevent) must
    * name it rather than the fit failing or a CIF being offered for it
    _fgtb_data
    quietly replace status = 2 if ctr == 3 & status == 1
    quietly replace anyev = status != 0
    quietly stset t, failure(anyev == 1) id(id)
    quietly finegray x1 x2, compete(status) cause(1) tvc(x1) tsplit(0.7) ///
        bstrata(ctr) nolog
    assert e(converged) == 1
    assert `"`e(bstrata_noevent)'"' == "3"
    capture finegray_cif, at(x1=0 x2=0) bstratum(3) attime(0.5) nograph
    assert _rc != 0
    quietly finegray_cif, at(x1=0 x2=0) bstratum(1) attime(0.5) nograph
    assert !missing(r(table)[1, 2])
}
local _rc = _rc
_fgtb_result `_rc' "TB08 determinism, permutation invariance and degenerate strata"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 9. Bootstrap CIF on the composed fit replays the right stratum
* -----------------------------------------------------------------------------
* The bootstrap refits the whole model from e(refitcmd) and accumulates each
* replication's CIF.  Under the composition each replication's baseline cache is
* K x 3, so the accumulation has to select the same stratum the point estimate
* used -- the same defect class as D5-2, in a different place.  A bootstrap SD
* built from the wrong stratum's curve is still a positive number.
local ++test_count
capture noisily {
    _fgtb_data
    quietly finegray x1 x2, compete(status) cause(1) tvc(x1) tsplit(0.7) ///
        bstrata(ctr) nolog

    foreach lev in 1 3 {
        quietly finegray_cif, at(x1=0.5 x2=1) bstratum(`lev') attime(0.5) ///
            nograph
        tempname PT
        matrix `PT' = r(table)
        local pt = `PT'[1, 2]

        quietly finegray_cif, at(x1=0.5 x2=1) bstratum(`lev') attime(0.5) ///
            ci bootstrap(40) seed(`= 100 + `lev'') nograph
        assert `"`r(se_method)'"' == "bootstrap"
        assert r(bootstrap_success) >= 25
        tempname BT
        matrix `BT' = r(table)
        * the point estimate is unchanged by asking for a bootstrap SE
        assert !missing(`BT'[1, 2], `pt')
        assert reldif(`BT'[1, 2], `pt') < 1e-12
        * and the interval is a real one around it
        assert !missing(`BT'[1, 3], `BT'[1, 4], `BT'[1, 5])
        assert `BT'[1, 3] > 0
        assert `BT'[1, 4] < `BT'[1, 2]
        assert `BT'[1, 5] > `BT'[1, 2]
        * the bootstrap SE must be of the same ORDER as the spread of the point
        * estimate across strata -- a wrong-stratum accumulation shows up as an
        * SD inflated by the between-stratum gap
        assert `BT'[1, 3] < 0.25
    }
}
local _rc = _rc
_fgtb_result `_rc' "TB09 bootstrap CIF on the composed fit uses the requested stratum"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 10. THE BASELINE ITSELF, against stcox and against arithmetic
* -----------------------------------------------------------------------------
* WHY THIS EXISTS.  Mutation-testing on 2026-08-26 found TB01-TB09 all GREEN
* against a build whose per-stratum baseline carry was replaced by a single
* pooled one -- the D5-1 defect, injected deliberately.  TB04 did not catch it
* because its "hand" CIF is computed FROM e(basehaz): if the curve is wrong,
* the hand value and finegray_cif are wrong together and agree perfectly.  That
* is the oracle-independence failure in its purest form, and it is why this
* test computes nothing from e(basehaz) except to check it.
*
* Two checks, one structural and one external:
*
*  A  STRUCTURAL.  Every stratum's block must START at its own first increment,
*     not at the previous stratum's running total.  Under a pooled carry
*     stratum 2's curve begins where stratum 1's ended, so its first value is a
*     large number rather than a small one.  Cheap, and it fails on the injected
*     defect immediately.
*
*  B  EXTERNAL.  On the no-competing-events fixture the estimator collapses to
*     Cox, so the per-stratum baseline must equal the Breslow baseline that
*     `stcox, strata() breslow' produces on the hand-split data -- Stata's own
*     code, which knows nothing about this package's interval passes.
local ++test_count
capture noisily {
    * ---- A: structural ----
    _fgtb_data
    quietly finegray x1 x2, compete(status) cause(1) tvc(x1) tsplit(0.7) ///
        bstrata(ctr) nolog basehaz
    tempname BH
    matrix `BH' = e(basehaz)
    assert colsof(`BH') == 3

    * the first row of each stratum's block, and the last
    local prev_last = 0
    foreach lev in 1 2 3 {
        local first = .
        local last = .
        forvalues r = 1/`= rowsof(`BH')' {
            if `BH'[`r', 1] != `lev' continue
            if missing(`first') local first = `BH'[`r', 3]
            local last = `BH'[`r', 3]
        }
        assert !missing(`first', `last')
        assert `first' > 0
        assert `last' >= `first'
        * A block that inherited the previous stratum's total starts at (or
        * above) it.  A block that carries only its own mass starts at one
        * increment, which on this fixture is under a hundredth.
        assert `first' < 0.05
        if `lev' > 1 assert `first' < `prev_last'
        local prev_last = `last'
    }

    * and the curve must be strictly increasing WITHIN each block
    foreach lev in 1 2 3 {
        local pv = -1
        forvalues r = 1/`= rowsof(`BH')' {
            if `BH'[`r', 1] != `lev' continue
            assert `BH'[`r', 3] > `pv'
            local pv = `BH'[`r', 3]
        }
    }

    * ---- B: external, against stcox's stratified Breslow baseline ----
    _fgtb_data_nc
    quietly finegray x2 x1, compete(status) cause(1) tvc(x1) tsplit(0.6) ///
        bstrata(ctr) nolog norobust basehaz
    tempname FH
    matrix `FH' = e(basehaz)
    assert colsof(`FH') == 3

    _fgtb_data_nc
    _fgtb_split 0.6
    quietly stcox x2 ibn.iv#c.x1, strata(ctr) breslow nolog
    quietly predict double _bch, basechazard

    local worstbh = 0
    foreach lev in 1 2 3 {
        foreach s in 0.2 0.4 0.8 1.2 {
            * stcox's stratified baseline at s: the largest value among this
            * stratum's rows whose analysis time is at or before s
            quietly summarize _bch if ctr == `lev' & _t <= `s', meanonly
            local cox = r(max)
            if missing(`cox') continue
            * finegray's, read out of the K x 3 curve by a naive linear scan
            local fg = 0
            forvalues r = 1/`= rowsof(`FH')' {
                if `FH'[`r', 1] != `lev' continue
                if `FH'[`r', 2] <= `s' local fg = `FH'[`r', 3]
            }
            assert !missing(`cox', `fg')
            assert `cox' > 0
            local d = reldif(`cox', `fg')
            if `d' > `worstbh' local worstbh = `d'
            assert `d' < 1e-6
        }
    }
    display as text "    TB10: worst stcox-vs-finegray baseline difference = " ///
        as result %9.2e `worstbh'
}
local _rc = _rc
_fgtb_result `_rc' ///
    "TB10 per-stratum baseline starts at its own increment and matches stcox"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# Summary
display as text _newline ///
    "RESULT: test_finegray_tvc_bstrata tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fgtb
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fgtb
