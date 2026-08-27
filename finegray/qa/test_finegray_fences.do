*! test_finegray_fences Version 1.0.0  2026/08/26
*! The option-lattice fence matrix, asserted on (rc, tokens) not on wording
*! Author: Timothy P Copeland, Karolinska Institutet

* WHY THIS SUITE EXISTS.
*
* Before this file the package's scope fences were tested wherever the feature
* that owned them was tested, and each test pinned the refusal's SENTENCE.  That
* coupled correctness to wording in two bad ways.  One rewording of one message
* turned a lattice of tests red at once, in files that had nothing else to do
* with each other; and the pressure that creates is to soften the message rather
* than to keep the fence honest.
*
* THE CONTRACT (declared in qa/_finegray_qa_common.do, enforced here):
*
*   stable    the RETURN CODE, and the OPTION NAMES the refusal is about,
*             spelled the way a user types them.  198 = option/scope fence,
*             refused before any data is touched.  459 = data fence.  301 =
*             post-estimation fence: the fit in e() cannot support the request.
*   not       every other word in the message -- the citation, the suggested
*   stable    alternative, the help link.  Exactly ONE test in the whole suite
*             pins those, the wording canary in test_finegray_errors.do.
*
* HOW TO LIFT A FENCE.  Each row of the matrix below is one line.  Lifting a
* fence is editing that line from a `_finegray_qa_assert_fence' call to a
* positive assertion about the fit it now produces -- in one place, with the
* reason in the comment beside it.  A fence that is lifted anywhere else in the
* package without this file being edited fails here, which is the point: the
* matrix is the package's single statement of what it refuses.
*
* WHAT THIS SUITE IS NOT.  It does not test that the fences are RIGHT.  Whether
* a refusal should exist is a literature and derivation question answered in
* finegray.sthlp and in the plan documents; this file only holds the package to
* whatever it currently claims.

clear all
set varabbrev off
version 16.0

local qa_dir "`c(pwd)'"
capture log close _all
log using "test_finegray_fences.log", replace text name(_fgfen)
do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _fgfen_result
program define _fgfen_result, rclass
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

* Right-censoring fixture: two covariates, a three-level factor, a two-level
* baseline/censoring stratum, no delayed entry.
capture program drop _fgfen_data
program define _fgfen_data
    version 16.0
    syntax [, SEED(integer 20260826) N(integer 500)]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen double x = rnormal()
    gen double w = rnormal()
    gen byte grp = 1 + floor(3 * runiform())
    gen byte ctr = 1 + (runiform() < .5)
    gen double t = 1 + floor(12 * runiform())
    gen byte etype = cond(runiform() < .45, 1, cond(runiform() < .5, 2, 0))
    gen byte anyev = etype != 0
    quietly stset t, failure(anyev==1) id(id)
end

* Same fixture with delayed entry, for the ZZF-branch fences.
capture program drop _fgfen_data_lt
program define _fgfen_data_lt
    version 16.0
    syntax [, SEED(integer 20260826) N(integer 500)]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen double x = rnormal()
    gen double w = rnormal()
    gen byte grp = 1 + floor(3 * runiform())
    gen byte ctr = 1 + (runiform() < .5)
    gen double ent = cond(runiform() < .35, floor(3 * runiform()), 0)
    gen double t = ent + 1 + floor(12 * runiform())
    gen byte etype = cond(runiform() < .45, 1, cond(runiform() < .5, 2, 0))
    gen byte anyev = etype != 0
    quietly stset t, failure(anyev==1) id(id) enter(time ent)
end

* -----------------------------------------------------------------------------
**# 1. Variance-option fences that are contradictions, not scope
* -----------------------------------------------------------------------------
* These three refuse a request that cannot mean anything, whatever the
* literature says: every one asks for a property of a sandwich that the same
* command line has just declined to compute.  They are not lattice cells and
* nothing in the unification lifts them.
local ++test_count
capture noisily {
    _fgfen_data

    _finegray_qa_assert_fence, ///
        cmd(`"finegray x w, compete(etype) cause(1) noadjust norobust nolog"') ///
        rc(198) tokens("noadjust norobust")

    _finegray_qa_assert_fence, ///
        cmd(`"finegray x w, compete(etype) cause(1) cluster(ctr) norobust nolog"') ///
        rc(198) tokens("cluster() norobust")

    _finegray_qa_assert_fence, ///
        cmd(`"finegray x w, compete(etype) cause(1) nuisance norobust nolog"') ///
        rc(198) tokens("nuisance norobust")
}
local _rc = _rc
_fgfen_result `_rc' "FGFEN-01 sandwich-property fences (noadjust/cluster/nuisance x norobust)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 2. tvc()/tsplit() option grammar
* -----------------------------------------------------------------------------
* Neither option means anything without the other, and a boundary at or below
* zero would define an empty leading interval carrying its own unidentified
* coefficient.  Grammar, not scope; nothing lifts these either.
local ++test_count
capture noisily {
    _fgfen_data

    _finegray_qa_assert_fence, ///
        cmd(`"finegray x w, compete(etype) cause(1) tvc(x) nolog"') ///
        rc(198) tokens("tvc() tsplit()")

    _finegray_qa_assert_fence, ///
        cmd(`"finegray x w, compete(etype) cause(1) tsplit(5) nolog"') ///
        rc(198) tokens("tsplit() tvc()")

    _finegray_qa_assert_fence, ///
        cmd(`"finegray x w, compete(etype) cause(1) tvc(x) tsplit(0) nolog"') ///
        rc(198) tokens("tsplit()")

    * an ascending/duplicate boundary is refused by `numlist ascending' at the
    * syntax statement itself, which is r(124) and carries no finegray message
    _finegray_qa_fence, ///
        cmd(`"finegray x w, compete(etype) cause(1) tvc(x) tsplit(5 5) nolog"') ///
        rc(124) tokens("")
    assert r(rc) == 124
}
local _rc = _rc
_fgfen_result `_rc' "FGFEN-02 tvc()/tsplit() option grammar"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 3. THE LATTICE: right-censoring feature pairs
* -----------------------------------------------------------------------------
* The three cells the variance-unification work targets.  Each line is
* one cell.  When a cell is lifted, its `_finegray_qa_assert_fence' line becomes
* a positive assertion here and the reason goes in the comment beside it.
*
*   nuisance x bstrata()   LIFTED 2026-08-26.  Zhou et al. (2011) sec. 4.1 states
*                          the stratified psi exactly -- FG (1999) eq. 7-8
*                          "with the added subscript k" -- and crrSC::crrs
*                          computes it (crrvvs).  v1.3.0's refusal was about the
*                          implementation, not the quantity.  Now allowed, and
*                          crossval_bstrata.do gates it against crrs ctype=1 at
*                          1e-6 (measured 8.1e-09 to 3.1e-08).
*   nuisance x tvc()       LIFTED 2026-08-26.  psi is linear in the score and the
*                          score decomposes over intervals, so psi decomposes
*                          with it; the hand-split equivalence oracle in
*                          test_finegray_tvc.do is the evidence.
*   tvc() x bstrata()      LIFTED 2026-08-26.  The refusal's premise -- "no
*                          reference implementation to validate against" --
*                          was checked and is half wrong: crrSC::crrs's
*                          signature takes cov2/tf with strata, but its code
*                          path does not work (ctype=1 errors in the C call at
*                          any K; ctype=2 does not converge).  So there is no
*                          external oracle, and the pair is validated by
*                          independent internal ones instead -- stcox with
*                          strata() on a split-episode fit, the two degenerate
*                          identities, and the duplicate-stratum halving.  See
*                          test_finegray_tvc_bstrata.do.
local ++test_count
capture noisily {
    _fgfen_data

    * LIFTED: assert the fit, not the refusal.  The variance must actually be
    * the corrected one (e(vce_meat)) and must actually differ from the
    * eta-only fit -- "it ran" is what a silently-ignored option looks like.
    quietly finegray x w, compete(etype) cause(1) bstrata(ctr) nolog
    tempname VETA BETA
    matrix `VETA' = e(V)
    matrix `BETA' = e(b)
    quietly finegray x w, compete(etype) cause(1) nuisance bstrata(ctr) nolog
    assert `"`e(vce_meat)'"' == "nuisance_adjusted"
    assert e(k_bstrata) == 2
    tempname VPSI
    matrix `VPSI' = e(V)
    * psi is a variance-only correction: the point estimate must NOT move
    forvalues j = 1/`= colsof(`BETA')' {
        assert !missing(`BETA'[1, `j'], e(b)[1, `j'])
        assert reldif(`BETA'[1, `j'], e(b)[1, `j']) < 1e-12
    }
    local vmoved = 0
    forvalues j = 1/`= colsof(`VETA')' {
        assert !missing(`VETA'[`j', `j'], `VPSI'[`j', `j'])
        assert `VPSI'[`j', `j'] > 0
        if reldif(`VETA'[`j', `j'], `VPSI'[`j', `j']) > 1e-10 local vmoved = 1
    }
    assert `vmoved' == 1

    * LIFTED: same discipline under tvc()
    quietly finegray x w, compete(etype) cause(1) tvc(x) tsplit(6) nolog
    matrix `VETA' = e(V)
    matrix `BETA' = e(b)
    quietly finegray x w, compete(etype) cause(1) nuisance tvc(x) tsplit(6) nolog
    assert `"`e(vce_meat)'"' == "nuisance_adjusted"
    assert e(n_intervals) == 2
    matrix `VPSI' = e(V)
    forvalues j = 1/`= colsof(`BETA')' {
        assert !missing(`BETA'[1, `j'], e(b)[1, `j'])
        assert reldif(`BETA'[1, `j'], e(b)[1, `j']) < 1e-12
    }
    local vmoved = 0
    forvalues j = 1/`= colsof(`VETA')' {
        assert !missing(`VETA'[`j', `j'], `VPSI'[`j', `j'])
        assert `VPSI'[`j', `j'] > 0
        if reldif(`VETA'[`j', `j'], `VPSI'[`j', `j']) > 1e-10 local vmoved = 1
    }
    assert `vmoved' == 1

    * LIFTED: the composed fit must carry BOTH axes, not silently drop one
    quietly finegray x w, compete(etype) cause(1) bstrata(ctr) ///
        tvc(x) tsplit(6) nolog basehaz
    assert e(converged) == 1
    assert e(k_bstrata) == 2
    assert e(n_intervals) == 2
    assert `"`e(bstrata)'"' == "ctr"
    assert `"`e(tvc)'"' == "x"
    * the baseline is one curve per stratum AND the coefficient stripe is
    * piecewise: a build that dropped either would still converge
    assert colsof(e(basehaz)) == 3
    quietly finegray x w, compete(etype) cause(1) tvc(x) tsplit(6) nolog
    local ncoef_tvc = colsof(e(b))
    quietly finegray x w, compete(etype) cause(1) bstrata(ctr) ///
        tvc(x) tsplit(6) nolog
    assert colsof(e(b)) == `ncoef_tvc'
    * and all three of nuisance, bstrata and tvc together
    quietly finegray x w, compete(etype) cause(1) bstrata(ctr) ///
        tvc(x) tsplit(6) nuisance nolog
    assert `"`e(vce_meat)'"' == "nuisance_adjusted"
    assert e(k_bstrata) == 2
    assert e(n_intervals) == 2
}
local _rc = _rc
_fgfen_result `_rc' "FGFEN-03 lattice: nuisance x bstrata, nuisance x tvc and tvc x bstrata all fit"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 4. THE LATTICE: delayed entry (the ZZF branch)
* -----------------------------------------------------------------------------
* Three literature-forced cells.  Neither Zhou paper mentions left truncation,
* so a stratified or piecewise fit on the delayed-entry branch, and the psi term
* under it, would each be an unsourced package extension.  Lifting any of these
* is gated on a literature survey, not on implementation effort.
local ++test_count
capture noisily {
    _fgfen_data_lt

    _finegray_qa_assert_fence, ///
        cmd(`"finegray x w, compete(etype) cause(1) nuisance nolog"') ///
        rc(198) tokens("nuisance delayed entry")

    _finegray_qa_assert_fence, ///
        cmd(`"finegray x w, compete(etype) cause(1) bstrata(ctr) nolog"') ///
        rc(198) tokens("bstrata() delayed entry")

    _finegray_qa_assert_fence, ///
        cmd(`"finegray x w, compete(etype) cause(1) tvc(x) tsplit(6) nolog"') ///
        rc(198) tokens("tvc() delayed entry")

    * and its mirror: truncstrata() is meaningless WITHOUT delayed entry
    _fgfen_data
    _finegray_qa_assert_fence, ///
        cmd(`"finegray x w, compete(etype) cause(1) truncstrata(ctr) nolog"') ///
        rc(198) tokens("truncstrata() delayed entry")
}
local _rc = _rc
_fgfen_result `_rc' "FGFEN-04 lattice: nuisance/bstrata()/tvc() x delayed entry"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 5. Post-estimation fences under tvc()
* -----------------------------------------------------------------------------
* rc 198 for an option combination the fitted model cannot support.  The
* analytic CIF ci was LIFTED in the unification -- the CIF influence function has been
* re-derived for a piecewise beta(t) -- so what stays fenced is schoenfeld and
* finegray_phtest, which are descriptive diagnostics OF a proportional effect
* and cannot mean anything for a fit that models the effect as non-proportional.
* That pair is a scope decision, not an implementation gap.
local ++test_count
capture noisily {
    _fgfen_data
    quietly finegray x w, compete(etype) cause(1) tvc(x) tsplit(6) nolog
    assert `"`e(tvc)'"' == "x"

    * LIFTED: both analytic-ci surfaces now run and name their SE route
    quietly finegray_cif, at(x=0 w=0) attime(4) ci nograph
    assert `"`r(se_method)'"' == "analytic"
    tempname TC
    matrix `TC' = r(table)
    assert !missing(`TC'[1, 3], `TC'[1, 4], `TC'[1, 5])
    assert `TC'[1, 3] > 0
    assert `TC'[1, 4] < `TC'[1, 2]
    assert `TC'[1, 5] > `TC'[1, 2]

    quietly finegray_predict double cifq, cif ci
    quietly count if e(sample) & missing(cifq)
    assert r(N) == 0
    quietly count if e(sample) & missing(cifq_lci) & cifq != 0
    assert r(N) == 0

    * STILL FENCED
    _finegray_qa_assert_fence, ///
        cmd(`"finegray_predict double schq, schoenfeld"') ///
        rc(198) tokens("tvc()")

    _finegray_qa_assert_fence, ///
        cmd(`"finegray_phtest"') ///
        rc(198) tokens("tvc()")

    * and the bootstrap route stands beside the analytic one
    capture noisily quietly finegray_cif, at(x=0 w=0) ci bootstrap(30) seed(7) nograph
    assert _rc == 0
    assert `"`r(se_method)'"' == "bootstrap"
}
local _rc = _rc
_fgfen_result `_rc' "FGFEN-05 tvc(): analytic ci lifted; schoenfeld/phtest still fenced"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 6. Post-estimation fences under bstrata()
* -----------------------------------------------------------------------------
* Under bstrata() a covariate profile no longer identifies a curve, so
* finegray_cif requires bstratum().  The mirror fence -- bstratum() supplied to
* a fit that has only one baseline -- is refused too, so the option cannot be
* typed as a no-op.
local ++test_count
capture noisily {
    _fgfen_data
    quietly finegray x w, compete(etype) cause(1) bstrata(ctr) nolog
    assert e(k_bstrata) == 2

    _finegray_qa_assert_fence, ///
        cmd(`"finegray_cif, at(x=0 w=0) nograph"') ///
        rc(198) tokens("bstratum() bstrata(ctr)")

    * 459, not 198.  The taxonomy is deliberate and the package is right: the
    * OPTION is legal and correctly spelled, and what fails is a fact about the
    * estimation sample -- no such level was fitted.  That is a data fence.
    _finegray_qa_assert_fence, ///
        cmd(`"finegray_cif, at(x=0 w=0) bstratum(99) nograph"') ///
        rc(459) tokens("bstratum(99)")

    * with the stratum named, the same request succeeds and says which stratum
    capture noisily quietly finegray_cif, at(x=0 w=0) bstratum(1) nograph
    assert _rc == 0
    assert r(bstratum) == 1
    assert `"`r(bstrata)'"' == "ctr"

    * and the mirror: bstratum() on an unstratified fit is refused
    quietly finegray x w, compete(etype) cause(1) nolog
    _finegray_qa_assert_fence, ///
        cmd(`"finegray_cif, at(x=0 w=0) bstratum(1) nograph"') ///
        rc(198) tokens("bstratum()")
}
local _rc = _rc
_fgfen_result `_rc' "FGFEN-06 bstratum() is required, validated, and refused when meaningless"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 7. e(vce_meat) is the machine counterpart of the variance prose
* -----------------------------------------------------------------------------
* The help file answers "which standard error am I getting?" in words.  This is
* the same answer in a macro, and it must take exactly the documented values --
* no fourth spelling, no empty string, on every combination the parser allows.
local ++test_count
capture noisily {
    _fgfen_data

    quietly finegray x w, compete(etype) cause(1) nolog
    assert `"`e(vce_meat)'"' == "fixed_weight"
    assert `"`e(vce)'"' == "robust"

    quietly finegray x w, compete(etype) cause(1) nuisance nolog
    assert `"`e(vce_meat)'"' == "nuisance_adjusted"

    quietly finegray x w, compete(etype) cause(1) norobust nolog
    assert `"`e(vce_meat)'"' == "not_applicable"
    assert `"`e(vce)'"' == "oim"

    quietly finegray x w, compete(etype) cause(1) cluster(grp) nolog
    assert `"`e(vce_meat)'"' == "fixed_weight"
    assert `"`e(vce)'"' == "cluster"

    quietly finegray x w, compete(etype) cause(1) bstrata(ctr) nolog
    assert `"`e(vce_meat)'"' == "fixed_weight"

    quietly finegray x w, compete(etype) cause(1) tvc(x) tsplit(6) nolog
    assert `"`e(vce_meat)'"' == "fixed_weight"

    quietly finegray x w, compete(etype) cause(1) strata(ctr) nolog
    assert `"`e(vce_meat)'"' == "fixed_weight"

    * and on the delayed-entry branch, where e(lt_vce) is the second axis
    _fgfen_data_lt
    quietly finegray x w, compete(etype) cause(1) nolog
    assert `"`e(vce_meat)'"' == "fixed_weight"
    assert `"`e(lt_vce)'"' == "fixed_weight_sandwich"
    assert substr(`"`e(lt_weight)'"', 1, 5) == "zzf1_"

    quietly finegray x w, compete(etype) cause(1) norobust nolog
    assert `"`e(lt_vce)'"' == "model_based"

    _fgfen_data
    quietly finegray x w, compete(etype) cause(1) nolog
    assert `"`e(lt_vce)'"' == "not_applicable"
    assert `"`e(lt_weight)'"' == "right_censoring"
}
local _rc = _rc
_fgfen_result `_rc' "FGFEN-07 e(vce_meat)/e(lt_vce)/e(lt_weight) take only documented values"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 8. r(se_method) is the machine counterpart of the CIF's variance prose
* -----------------------------------------------------------------------------
* finegray_cif prints a note under the table when the analytic SE is not derived
* for the fit.  A note is prose; r(se_method) is the same statement a caller can
* branch on.  The two must agree, so this test asserts BOTH: the macro, and the
* SE column of r(table) actually being missing exactly when the macro says
* "none".
local ++test_count
capture noisily {
    _fgfen_data

    quietly finegray x w, compete(etype) cause(1) nolog
    quietly finegray_cif, at(x=0 w=0) attime(4) nograph
    assert `"`r(se_method)'"' == "analytic"
    tempname T
    matrix `T' = r(table)
    assert !missing(`T'[1, 3])
    assert `T'[1, 3] > 0

    quietly finegray_cif, at(x=0 w=0) attime(4) ci nograph
    assert `"`r(se_method)'"' == "analytic"

    quietly finegray_cif, at(x=0 w=0) attime(4) ci bootstrap(30) seed(11) nograph
    assert `"`r(se_method)'"' == "bootstrap"
    assert r(bootstrap_requested) == 30
    matrix `T' = r(table)
    assert !missing(`T'[1, 3])

    * the tvc() fit: since the unification the analytic route IS derived, so the macro
    * must say "analytic" and the SE column must actually be populated.  Through
    * v1.3.0 this cell read "none" beside a column of dots.
    quietly finegray x w, compete(etype) cause(1) tvc(x) tsplit(6) nolog
    quietly finegray_cif, at(x=0 w=0) attime(4) nograph
    assert `"`r(se_method)'"' == "analytic"
    matrix `T' = r(table)
    assert !missing(`T'[1, 3])
    assert `T'[1, 3] > 0

    quietly finegray_cif, at(x=0 w=0) attime(4) ci bootstrap(30) seed(11) nograph
    assert `"`r(se_method)'"' == "bootstrap"
    matrix `T' = r(table)
    assert !missing(`T'[1, 3])
}
local _rc = _rc
_fgfen_result `_rc' "FGFEN-08 r(se_method) agrees with the SE column it describes"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 9. Post-estimation fences on mi fits are r(301), by name
* -----------------------------------------------------------------------------
* e(postest) is the disclosure; r(301) plus the mi tokens are the channel.
local ++test_count
capture noisily {
    _fgfen_data
    quietly gen double zz = rnormal()
    quietly replace zz = . if runiform() < .3
    quietly mi set wide
    quietly mi register imputed zz
    quietly mi register regular x w grp ctr id t etype anyev
    quietly mi impute regress zz = x, add(2) rseed(20260826)
    quietly mi stset t, failure(anyev==1) id(id)
    quietly finegray x zz, compete(etype) cause(1) nolog
    assert `"`e(postest)'"' == "unavailable_mi"

    _finegray_qa_assert_fence, ///
        cmd(`"finegray_cif, at(x=0 zz=0) nograph"') ///
        rc(301) tokens("mi data")

    _finegray_qa_assert_fence, ///
        cmd(`"finegray_predict double xbq, xb"') ///
        rc(301) tokens("mi data")

    * and after a POOLED command, where e(cmd) is "mi estimate" rather than
    * "finegray", the refusal is a different one and names mi estimate
    quietly mi estimate, cmdok: finegray x zz, compete(etype) cause(1) nolog
    _finegray_qa_assert_fence, ///
        cmd(`"finegray_cif, at(x=0 zz=0) nograph"') ///
        rc(301) tokens("mi estimate")
}
local _rc = _rc
_fgfen_result `_rc' "FGFEN-09 mi post-estimation fences are r(301) and name their reason"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# Summary
display as text _newline ///
    "RESULT: test_finegray_fences tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture log close _fgfen
    exit 1
}
display as result "ALL TESTS PASSED"
capture log close _fgfen
