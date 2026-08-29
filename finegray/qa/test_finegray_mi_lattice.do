*! test_finegray_mi_lattice Version 1.0.0  2026/08/26
*! mi x v1.2.0/v1.3.0 machinery lattice probe for finegray
*! Author: Timothy P Copeland, Karolinska Institutet

* WHY THIS SUITE EXISTS.
*
* test_finegray_mi.do proves that the mi branch exists and that its POINT
* estimates pool correctly.  Everything it fits is a plain right-censoring
* model with a single record per subject.  The v1.2.0 machinery -- delayed
* entry (the ZZF branch), truncstrata(), strata() -- and the v1.3.0 machinery
* -- bstrata(), tvc(), nuisance -- had never been run under mi at all, in
* either of the two reachability modes the v1.3.0 work identified:
*
*   (a) under `mi estimate, cmdok:', where mi hands the command a completed
*       single-imputation dataset and throws it away afterwards, and
*   (b) typed DIRECTLY on mi data, which is where the v1.3.0 residue defect
*       lived -- mi's sandbox HID it, so a suite that only tests (a) is blind.
*
* WHAT THIS SUITE FOUND (2026-08-26).
*
* D0-1.  A mi-mode fit wrote SEVEN _dta[_finegray_*] characteristics into the
*        caller's dataset.  finegray.ado's own comments state the contract twice
*        -- "nothing is written to the caller's mi dataset" at the tempvar
*        branches, and the `if !_fg_is_mi' guard that skips the SUCCESS marks --
*        but the INVALIDATION mark ("0" plus six blanks) was written
*        unconditionally, before the mi test.  The mark exists so that a re-fit
*        which dies mid-mutation cannot masquerade as the prior success; on mi
*        data the fit mutates nothing permanent (entry column and every
*        _fg_<term> design column are tempvars), so it had nothing to
*        invalidate and no business writing.
*
*        The compounding half is the CLEANUP: blanking _dta[_finegray_fvvars]
*        while the same block dropped the columns that characteristic named left
*        a prior ordinary fit's e() pointing at design columns that no longer
*        existed, with no characteristic recording that finegray had ever owned
*        them.  Verified on the pre-fix tree: after `finegray i.grp x' (chars
*        estimated=1, fvvars="_fg_grp_2 _fg_grp_3", both columns present),
*        `mi set wide' and any mi-mode fit left estimated="0", fvvars="", and
*        ZERO _fg_ columns.  Fixed by making the whole block -- mark and
*        cleanup together -- off-mi-data only.  FGML-01/02/03 are the
*        regressions and fail on the pre-fix tree.
*
* The remaining tests are the lattice probe proper: every v1.2.0/v1.3.0
* mechanism under mi, in both reachability modes, with the mi-style detection
* matrix re-run for a DELAYED-ENTRY fit (test_finegray_mi.do's matrix is for a
* right-censoring fit only, and the ZZF branch dispatches on data the detection
* never saw).

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_mi_lattice.log", replace name(_fgml)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _fgml_result
program define _fgml_result, rclass
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

* Count the _dta[_finegray_*] characteristics currently on the dataset.
capture program drop _fgml_nchars
program define _fgml_nchars, rclass
    version 16.0
    local cs : char _dta[]
    local n = 0
    foreach c of local cs {
        if substr("`c'", 1, 10) == "_finegray_" local ++n
    }
    return scalar n = `n'
end

* Count variables whose name starts with _fg_ (package-owned permanent columns).
capture program drop _fgml_nfgvars
program define _fgml_nfgvars, rclass
    version 16.0
    local n = 0
    foreach v of varlist _all {
        if substr("`v'", 1, 4) == "_fg_" local ++n
    }
    return scalar n = `n'
end

* Single-record delayed-entry competing-risks fixture with one MAR-incomplete
* covariate (z), one factor covariate (grp), and a two-level weight-stratum
* variable (wstr) usable by strata()/truncstrata()/bstrata().
capture program drop _fgml_data
program define _fgml_data
    version 16.0
    syntax [, SEED(integer 20260826) N(integer 600) LT(integer 1)]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen double x = rnormal()
    gen double z = rnormal()
    gen byte grp = 1 + floor(3 * runiform())
    gen byte wstr = 1 + (runiform() < .5)
    if `lt' gen double ent = cond(runiform() < .35, floor(3 * runiform()), 0)
    else gen double ent = 0
    gen double t = ent + 1 + floor(12 * runiform())
    gen byte etype = cond(runiform() < .45, 1, cond(runiform() < .5, 2, 0))
    gen byte anyev = etype != 0
    quietly replace z = . if invlogit(-1.2 + 0.6 * x) > runiform()
end

* mi set / impute / stset the fixture in one step.
capture program drop _fgml_set
program define _fgml_set
    version 16.0
    syntax [, STYle(string) M(integer 3) LT(integer 1) SEPname(string)]
    if "`style'" == "" local style "mlong"
    if "`style'" == "flongsep" {
        if "`sepname'" == "" local sepname "_fgmlsep"
        quietly mi set flongsep `sepname'
    }
    else {
        quietly mi set `style'
    }
    quietly mi register imputed z
    quietly mi register regular x grp wstr id t ent etype anyev
    quietly mi impute regress z = x, add(`m') rseed(20260826)
    if `lt' quietly mi stset t, failure(anyev==1) id(id) enter(time ent)
    else quietly mi stset t, failure(anyev==1) id(id)
end

* -----------------------------------------------------------------------------
**# 1. A mi-mode fit writes NO _dta[_finegray_*] characteristic (D0-1)
* -----------------------------------------------------------------------------
* The discriminating half of the D0-1 regression.  On the pre-fix tree this
* returns 7.  Both reachability modes are asserted: `mi estimate' hands the
* command a scratch dataset and restores the original, so it is the DIRECT fit
* that leaves residue in the user's data -- which is exactly why testing only
* the sandboxed mode is blind.
local ++test_count
capture noisily {
    _fgml_data, lt(1)
    _fgml_set, style(wide) lt(1)

    _fgml_nchars
    assert r(n) == 0

    quietly finegray x z, compete(etype) cause(1) nolog
    assert `"`e(mi_data)'"' == "1"
    assert `"`e(postest)'"' == "unavailable_mi"
    _fgml_nchars
    assert !missing(r(n))
    assert r(n) == 0

    * and the delayed-entry branch really did dispatch on this fit.
    * e(lt_weight) is "right_censoring" off the ZZF branch and never empty, so
    * a non-empty test would be vacuous: assert the zzf1_ family by name.
    assert !missing(e(N_delayed))
    assert e(N_delayed) > 0
    assert substr(`"`e(lt_weight)'"', 1, 5) == "zzf1_"

    * the sandboxed mode too, for completeness
    quietly mi estimate, cmdok: finegray x z, compete(etype) cause(1) nolog
    _fgml_nchars
    assert r(n) == 0
}
local _rc = _rc
_fgml_result `_rc' ///
    "FGML-01 mi-mode ZZF fit writes no _dta[_finegray_*] characteristic"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 2. A mi-mode fit does not destroy a prior ordinary fit's state (D0-1)
* -----------------------------------------------------------------------------
* The compounding half.  Sequence: ordinary factor-variable fit (leaves
* _fg_grp_2/_fg_grp_3 and chars naming them) -> mi set -> mi-mode fit.  On the
* pre-fix tree the mi fit dropped both columns AND blanked the characteristic
* that named them, so nothing in the dataset recorded that finegray had ever
* created them.  After the fix the prior fit's state is untouched and stays
* internally consistent: the characteristic names columns that still exist.
local ++test_count
capture noisily {
    _fgml_data, lt(0)
    quietly stset t, failure(anyev==1) id(id)
    quietly finegray i.grp x, compete(etype) cause(1) nolog

    local prev_fv `"`: char _dta[_finegray_fvvars]'"'
    local prev_est `"`: char _dta[_finegray_estimated]'"'
    assert "`prev_est'" == "1"
    assert "`prev_fv'" != ""
    _fgml_nfgvars
    local nfg0 = r(n)
    assert `nfg0' == 2

    _fgml_set, style(wide) lt(0)
    quietly finegray x z, compete(etype) cause(1) nolog
    assert `"`e(mi_data)'"' == "1"

    * the prior fit's characteristics survive verbatim ...
    assert `"`: char _dta[_finegray_estimated]'"' == "`prev_est'"
    assert `"`: char _dta[_finegray_fvvars]'"' == "`prev_fv'"
    * ... and every column they name still exists
    foreach v of local prev_fv {
        confirm variable `v'
    }
    _fgml_nfgvars
    assert !missing(r(n))
    assert r(n) == `nfg0'
}
local _rc = _rc
_fgml_result `_rc' ///
    "FGML-02 mi-mode fit leaves a prior ordinary fit's columns and chars intact"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 3. The mi fit's own post-estimation still fails closed, by name (D0-1)
* -----------------------------------------------------------------------------
* The reason FGML-02's leniency is safe.  With a prior fit's chars left standing
* and e() now describing the mi fit, a post-estimation command must NOT answer
* from the stale characteristics.  It does not: the e(postest) guard fires
* first, before any characteristic is consulted, and it fires by NAME.
local ++test_count
capture noisily {
    _fgml_data, lt(0)
    quietly stset t, failure(anyev==1) id(id)
    quietly finegray i.grp x, compete(etype) cause(1) nolog
    _fgml_set, style(wide) lt(0)
    quietly finegray x z, compete(etype) cause(1) nolog
    assert `"`e(postest)'"' == "unavailable_mi"

    capture finegray_predict double xbhat, xb
    assert _rc != 0
    capture finegray_cif, at(x=0 z=0)
    assert _rc != 0
    capture finegray_phtest
    assert _rc != 0
}
local _rc = _rc
_fgml_result `_rc' ///
    "FGML-03 post-estimation on the mi fit fails closed despite stale prior chars"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 4. Delayed entry under mi estimate: dispatches, and pools by Rubin's rules
* -----------------------------------------------------------------------------
* The ZZF branch had never been run under mi.  Two claims: (a) each
* per-imputation fit really takes the delayed-entry branch (e(N_delayed) > 0 and
* e(lt_weight) non-empty inside `mi xeq'), and (b) mi estimate's pooled output
* is Rubin's rules applied to those fits' e(b)/e(V) -- computed here by hand, so
* a wrong scale or a wrong variance shows as a number rather than as an eyeball.
local ++test_count
capture noisily {
    _fgml_data, lt(1)
    _fgml_set, style(mlong) m(5) lt(1)
    local M = 5

    quietly mi estimate, cmdok: finegray x z, compete(etype) cause(1) nolog
    tempname Qmi Tmi
    matrix `Qmi' = e(b_mi)
    matrix `Tmi' = e(V_mi)
    local p = colsof(`Qmi')
    assert e(M_mi) == `M'

    tempname Qbar Ubar Bmat Qm Um Tman
    matrix `Qbar' = J(1, `p', 0)
    matrix `Ubar' = J(`p', `p', 0)
    forvalues m = 1/`M' {
        quietly mi xeq `m': finegray x z, compete(etype) cause(1) nolog
        assert !missing(e(N_delayed))
        assert e(N_delayed) > 0
        assert substr(`"`e(lt_weight)'"', 1, 5) == "zzf1_"
        matrix `Qm' = e(b)
        matrix `Um' = e(V)
        matrix `Qbar' = `Qbar' + `Qm' / `M'
        matrix `Ubar' = `Ubar' + `Um' / `M'
        matrix QL`m' = `Qm'
    }
    matrix `Bmat' = J(`p', `p', 0)
    forvalues m = 1/`M' {
        tempname dev
        matrix `dev' = QL`m' - `Qbar'
        matrix `Bmat' = `Bmat' + (`dev'' * `dev') / (`M' - 1)
    }
    matrix `Tman' = `Ubar' + (1 + 1 / `M') * `Bmat'

    forvalues j = 1/`p' {
        assert !missing(`Qbar'[1, `j'], `Qmi'[1, `j'])
        assert reldif(`Qbar'[1, `j'], `Qmi'[1, `j']) < 1e-12
        forvalues k = 1/`p' {
            assert !missing(`Tman'[`j', `k'], `Tmi'[`j', `k'])
            assert reldif(`Tman'[`j', `k'], `Tmi'[`j', `k']) < 1e-10
        }
    }
}
local _rc = _rc
_fgml_result `_rc' ///
    "FGML-04 delayed-entry fit dispatches under mi and pools by hand Rubin"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 5. truncstrata() under mi -- both modes, and it changes the answer
* -----------------------------------------------------------------------------
* truncstrata() requires delayed entry, so this cell is reachable only on the
* ZZF branch.  Asserting rc==0 would be vacuous: the option could be parsed and
* dropped.  The discriminating assertion is that the stratified-entry fit
* differs from the pooled-entry fit on the SAME imputation, and that
* e(lt_weight) records the cross-classified construction.
local ++test_count
capture noisily {
    _fgml_data, lt(1)
    _fgml_set, style(mlong) m(3) lt(1)

    quietly mi xeq 1: finegray x z, compete(etype) cause(1) nolog
    tempname bPool
    matrix `bPool' = e(b)
    local ltw_pool `"`e(lt_weight)'"'

    quietly mi xeq 1: finegray x z, compete(etype) cause(1) truncstrata(wstr) nolog
    tempname bStr
    matrix `bStr' = e(b)
    local ltw_str `"`e(lt_weight)'"'
    assert `"`e(truncstrata)'"' == "wstr"

    assert substr("`ltw_str'", 1, 5) == "zzf1_"
    assert substr("`ltw_pool'", 1, 5) == "zzf1_"
    assert "`ltw_str'" != "`ltw_pool'"
    local moved = 0
    forvalues j = 1/`= colsof(`bPool')' {
        assert !missing(`bPool'[1, `j'], `bStr'[1, `j'])
        if reldif(`bPool'[1, `j'], `bStr'[1, `j']) > 1e-10 local moved = 1
    }
    assert `moved' == 1

    * and the pooled command runs
    quietly mi estimate, cmdok: finegray x z, compete(etype) cause(1) ///
        truncstrata(wstr) nolog
    assert e(M_mi) == 3
    _fgml_nchars
    assert r(n) == 0
}
local _rc = _rc
_fgml_result `_rc' ///
    "FGML-05 truncstrata() runs under mi and moves the estimate off pooled entry"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 6. strata() and nuisance under mi -- e(vce_meat) is the machine counterpart
* -----------------------------------------------------------------------------
* This mi cell is a right-censoring fit (the delayed-entry nuisance cell is
* test_finegray_nuisance_lt.do's).  The claim under test is not "it runs" but that the option reaches the
* engine: e(vce_meat) must read nuisance_adjusted and e(V) must actually differ
* from the fixed-weight fit on the same imputation.
local ++test_count
capture noisily {
    _fgml_data, lt(0)
    _fgml_set, style(mlong) m(3) lt(0)

    quietly mi xeq 1: finegray x z, compete(etype) cause(1) nolog
    tempname Vfix
    matrix `Vfix' = e(V)
    assert `"`e(vce_meat)'"' == "fixed_weight"

    quietly mi xeq 1: finegray x z, compete(etype) cause(1) nuisance nolog
    tempname Vnui
    matrix `Vnui' = e(V)
    assert `"`e(vce_meat)'"' == "nuisance_adjusted"
    local moved = 0
    forvalues j = 1/`= colsof(`Vnui')' {
        assert !missing(`Vfix'[`j', `j'], `Vnui'[`j', `j'])
        assert `Vnui'[`j', `j'] > 0
        if reldif(`Vfix'[`j', `j'], `Vnui'[`j', `j']) > 1e-10 local moved = 1
    }
    assert `moved' == 1

    quietly mi estimate, cmdok: finegray x z, compete(etype) cause(1) nuisance nolog
    assert e(M_mi) == 3

    * strata(): the censoring-KM axis, again asserted by movement not by rc
    quietly mi xeq 1: finegray x z, compete(etype) cause(1) strata(wstr) nolog
    assert `"`e(strata)'"' == "wstr"
    tempname bStr
    matrix `bStr' = e(b)
    quietly mi xeq 1: finegray x z, compete(etype) cause(1) nolog
    tempname bPool
    matrix `bPool' = e(b)
    local moved2 = 0
    forvalues j = 1/`= colsof(`bPool')' {
        assert !missing(`bPool'[1, `j'], `bStr'[1, `j'])
        if reldif(`bPool'[1, `j'], `bStr'[1, `j']) > 1e-10 local moved2 = 1
    }
    assert `moved2' == 1

    _fgml_nchars
    assert r(n) == 0
}
local _rc = _rc
_fgml_result `_rc' ///
    "FGML-06 nuisance and strata() reach the engine under mi (e(vce_meat), movement)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 7. bstrata() and tvc() under mi -- both modes, no residue
* -----------------------------------------------------------------------------
* The v1.3.0 modelling features had never been run under mi either.  Same
* discipline: the option must move the fit, and neither may leave a column or a
* characteristic behind on the caller's mi dataset.
local ++test_count
capture noisily {
    _fgml_data, lt(0)
    _fgml_set, style(wide) m(3) lt(0)

    quietly finegray x z, compete(etype) cause(1) nolog
    tempname bPlain
    matrix `bPlain' = e(b)

    quietly finegray x z, compete(etype) cause(1) bstrata(wstr) nolog
    assert `"`e(bstrata)'"' == "wstr"
    assert e(k_bstrata) == 2
    assert `"`e(mi_data)'"' == "1"
    tempname bBs
    matrix `bBs' = e(b)
    assert colsof(`bBs') == colsof(`bPlain')
    local moved = 0
    forvalues j = 1/`= colsof(`bPlain')' {
        assert !missing(`bPlain'[1, `j'], `bBs'[1, `j'])
        if reldif(`bPlain'[1, `j'], `bBs'[1, `j']) > 1e-10 local moved = 1
    }
    assert `moved' == 1

    quietly finegray x z, compete(etype) cause(1) tvc(x) tsplit(6) nolog
    assert `"`e(tvc)'"' == "x"
    assert e(n_intervals) == 2
    assert `"`e(mi_data)'"' == "1"
    assert colsof(e(b)) == colsof(`bPlain') + 1

    _fgml_nchars
    assert r(n) == 0
    _fgml_nfgvars
    assert r(n) == 0

    quietly mi estimate, cmdok: finegray x z, compete(etype) cause(1) ///
        bstrata(wstr) nolog
    assert e(M_mi) == 3
    quietly mi estimate, cmdok: finegray x z, compete(etype) cause(1) ///
        tvc(x) tsplit(6) nolog
    assert e(M_mi) == 3
    _fgml_nchars
    assert r(n) == 0
    _fgml_nfgvars
    assert r(n) == 0
}
local _rc = _rc
_fgml_result `_rc' ///
    "FGML-07 bstrata() and tvc() run under mi in both modes with no residue"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 8. mi-style detection for a DELAYED-ENTRY fit, four styles x three contexts
* -----------------------------------------------------------------------------
* test_finegray_mi.do pins the detection matrix for a right-censoring fit.  The
* ZZF branch reaches the detection through a different route (the multi-record
* reduction and the entry column), so the matrix is re-run here for a fit that
* actually takes it.  Detection is "does the DATASET carry any _mi_*
* characteristic"; the cell it must not lose is flong inside `mi estimate',
* where _dta[_mi_style] is ABSENT and only _dta[_mi_substyle] survives.
*
* A direct fit on mlong/flong is NOT asserted to succeed: those styles stack
* m=0..M in one dataset, so every subject appears M+1 times and finegray's own
* multiple-record checks refuse it.  What IS asserted is that mi xeq -- the one
* context that gives a stacked style a single completed dataset -- detects mi
* in all four styles.
local ++test_count
capture noisily {
    foreach sty in wide mlong flong flongsep {
        _fgml_data, lt(1)
        capture shell rm -f _fgmlsep*.dta
        _fgml_set, style(`sty') m(2) lt(1) sepname(_fgmlsep)

        * context 3: mi xeq -- available in every style
        quietly mi xeq 1: finegray x z, compete(etype) cause(1) nolog
        assert `"`e(mi_data)'"' == "1"
        assert `"`e(postest)'"' == "unavailable_mi"
        assert !missing(e(N_delayed))
        assert e(N_delayed) > 0

        * context 2: mi estimate -- available in every style
        quietly mi estimate, cmdok: finegray x z, compete(etype) cause(1) nolog
        assert e(M_mi) == 2

        * context 1: typed directly -- only the non-stacked styles present a
        * single record per subject
        if inlist("`sty'", "wide", "flongsep") {
            quietly finegray x z, compete(etype) cause(1) nolog
            assert `"`e(mi_data)'"' == "1"
            assert `"`e(postest)'"' == "unavailable_mi"
        }

        _fgml_nchars
        assert r(n) == 0
        if "`sty'" == "flongsep" quietly mi convert wide, clear
    }
    capture shell rm -f _fgmlsep*.dta
}
local _rc = _rc
_fgml_result `_rc' ///
    "FGML-08 mi detection holds for a ZZF fit across four styles x three contexts"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 9. mi update after a fit on mi data flags and destroys nothing
* -----------------------------------------------------------------------------
* The point of D0-1's fix is that the mi dataset comes back unchanged.  The
* strongest available statement of that is a datasignature taken before the fit
* and re-checked after `mi update' -- which would report a difference if the fit
* had added, dropped or rewritten any column.
*
* The signature is measured around the DIRECT fits only, and the style is
* `wide'.  Two reasons, both measured on this build:
*   - mlong/flong stack m=0..M in one dataset, so every subject appears M+1
*     times and a directly-typed fit is refused by finegray's own
*     multiple-record checks (correctly).  Only wide/flongsep present one
*     record per subject to a direct fit.
*   - `mi xeq' and `mi estimate' move the datasignature ON THEIR OWN: a bare
*     `mi xeq 1: summarize x' took 800:19(47754):... to 800:19(113291):... with
*     k and N unchanged.  A signature assertion wrapped around them would be
*     measuring mi, not finegray, so those two contexts are asserted on the
*     residue counts instead.
local ++test_count
capture noisily {
    _fgml_data, lt(1)
    _fgml_set, style(wide) m(3) lt(1)
    quietly datasignature
    local sig0 `"`r(datasignature)'"'
    assert "`sig0'" != ""
    local nv0 = c(k)

    quietly finegray x z, compete(etype) cause(1) nolog
    quietly finegray x z, compete(etype) cause(1) truncstrata(wstr) nolog
    quietly datasignature
    assert `"`r(datasignature)'"' == "`sig0'"
    assert c(k) == `nv0'

    capture noisily mi update
    assert _rc == 0
    quietly datasignature
    assert `"`r(datasignature)'"' == "`sig0'"
    assert c(k) == `nv0'
    _fgml_nchars
    assert r(n) == 0

    * the sandboxed contexts: residue counts, not the signature
    quietly mi estimate, cmdok: finegray x z, compete(etype) cause(1) nolog
    quietly mi xeq 2: finegray x z, compete(etype) cause(1) truncstrata(wstr) nolog
    capture noisily mi update
    assert _rc == 0
    assert c(k) == `nv0'
    _fgml_nchars
    assert r(n) == 0
    _fgml_nfgvars
    assert r(n) == 0

}
local _rc = _rc
_fgml_result `_rc' ///
    "FGML-09 mi update after mi-mode fits leaves the datasignature unchanged"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 10. Multi-record id() + factor variables + delayed entry, direct on mi data
* -----------------------------------------------------------------------------
* The exact shape that produced the v1.3.0 residue defect, now with all three
* mechanisms at once: the reduction writes an entry column, the factor terms
* write design columns, and the ZZF branch consumes both.  Every one of those
* writes must be a tempvar on mi data.
local ++test_count
capture noisily {
    clear
    set seed 20260826
    quietly set obs 400
    gen long id = _n
    gen double x = rnormal()
    gen double z = rnormal()
    gen byte grp = 1 + floor(3 * runiform())
    gen double ent = cond(runiform() < .4, floor(2 * runiform() + 1), 0)
    gen double t = ent + 3 + floor(9 * runiform())
    gen byte etype = cond(runiform() < .45, 1, cond(runiform() < .5, 2, 0))
    * z is imputed at SUBJECT level: it must be constant within id, or
    * finegray's own time-varying-covariate refusal fires (correctly) instead.
    quietly replace z = . if invlogit(-1.0 + 0.5 * x) > runiform()
    expand 2
    bysort id: gen byte rec = _n
    gen double start = cond(rec == 1, ent, (ent + t) / 2)
    gen double stop  = cond(rec == 1, (ent + t) / 2, t)
    gen byte anyev = cond(rec == 2, etype != 0, 0)
    gen byte etype_r = cond(rec == 2, etype, 0)

    mi set wide
    quietly mi register imputed z
    quietly mi register regular x grp id start stop anyev etype_r rec
    * impute on the first record only, then copy within id, so the imputed
    * covariate is subject-constant as the estimator requires
    quietly mi impute regress z = x if rec == 1, add(2) rseed(20260826)
    forvalues m = 1/2 {
        quietly bysort id (rec): replace _`m'_z = _`m'_z[1]
    }
    quietly mi update
    quietly mi stset stop, failure(anyev==1) id(id) enter(time start)

    * The signature is taken around the DIRECT fit.  `mi xeq' moves the
    * signature on its own (see FGML-09's note), so the sandboxed context is
    * asserted on residue counts only.
    quietly datasignature
    local sig0 `"`r(datasignature)'"'
    local nv0 = c(k)

    quietly finegray i.grp x z, compete(etype_r) cause(1) nolog
    assert `"`e(mi_data)'"' == "1"
    assert `"`e(postest)'"' == "unavailable_mi"
    assert !missing(e(N_delayed))
    assert e(N_delayed) > 0
    * the entry column is a TEMPVAR, so e(entryvar) is not the public name
    assert `"`e(entryvar)'"' != "_fg_entry"
    assert `"`e(entryvar)'"' != ""
    * and the factor design columns are tempvars too, so their public names are
    * absent from the caller's data
    assert `"`e(fvvarlist)'"' == "i.grp x z"

    _fgml_nfgvars
    assert r(n) == 0
    _fgml_nchars
    assert r(n) == 0
    capture confirm variable _fg_entry
    assert _rc != 0
    capture confirm variable _fg_grp_2
    assert _rc != 0

    quietly datasignature
    assert `"`r(datasignature)'"' == "`sig0'"
    assert c(k) == `nv0'

    * same shape under mi xeq: residue counts only
    quietly mi xeq 1: finegray i.grp x z, compete(etype_r) cause(1) nolog
    assert `"`e(mi_data)'"' == "1"
    assert !missing(e(N_delayed))
    assert e(N_delayed) > 0
    _fgml_nfgvars
    assert r(n) == 0
    _fgml_nchars
    assert r(n) == 0
    assert c(k) == `nv0'
}
local _rc = _rc
_fgml_result `_rc' ///
    "FGML-10 multi-record + factor + delayed entry on mi data leaves no residue"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 11. e(refitcmd) reproduces e(b) on an mi-mode ZZF fit (Z24 under mi)
* -----------------------------------------------------------------------------
* Gate Z24 asserts the refitcmd contract off mi data.  It is asserted here for
* the mi cell too, because the option set that reaches e(refitcmd) is built from
* the same parsed locals whichever mode the fit ran in, and a bootstrap replay
* on an mi-mode fit is the one place a dropped option would not error.
local ++test_count
capture noisily {
    _fgml_data, lt(1)
    _fgml_set, style(wide) m(3) lt(1)

    foreach spec in "" "truncstrata(wstr)" "strata(wstr)" ///
        "strata(wstr) truncstrata(wstr)" {
        quietly finegray x z, compete(etype) cause(1) `spec' nolog
        tempname b0
        matrix `b0' = e(b)
        local rfc `"`e(refitcmd)'"'
        assert "`rfc'" != ""
        quietly `rfc'
        tempname b1
        matrix `b1' = e(b)
        assert colsof(`b1') == colsof(`b0')
        forvalues j = 1/`= colsof(`b0')' {
            assert !missing(`b0'[1, `j'], `b1'[1, `j'])
            assert reldif(`b0'[1, `j'], `b1'[1, `j']) < 1e-12
        }
    }

    * the right-censoring v1.3.0 options too
    _fgml_data, lt(0)
    _fgml_set, style(wide) m(3) lt(0)
    foreach spec in "bstrata(wstr)" "tvc(x) tsplit(6)" {
        quietly finegray x z, compete(etype) cause(1) `spec' nolog
        tempname b0
        matrix `b0' = e(b)
        local rfc `"`e(refitcmd)'"'
        quietly `rfc'
        tempname b1
        matrix `b1' = e(b)
        assert colsof(`b1') == colsof(`b0')
        forvalues j = 1/`= colsof(`b0')' {
            assert !missing(`b0'[1, `j'], `b1'[1, `j'])
            assert reldif(`b0'[1, `j'], `b1'[1, `j']) < 1e-12
        }
    }
}
local _rc = _rc
_fgml_result `_rc' ///
    "FGML-11 e(refitcmd) reproduces e(b) on mi-mode fits across the option set"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 12. Post-estimation refusals fire on every mi-mode fit shape
* -----------------------------------------------------------------------------
* The fences are stated on e(postest), so they must hold for the ZZF,
* truncstrata, bstrata and tvc shapes exactly as they do for the plain fit.  The
* assertion is on the return code plus the presence of the stable token, not on
* the full sentence.
local ++test_count
capture noisily {
    _fgml_data, lt(1)
    _fgml_set, style(wide) m(2) lt(1)
    foreach spec in "" "truncstrata(wstr)" {
        quietly finegray x z, compete(etype) cause(1) `spec' nolog
        assert `"`e(postest)'"' == "unavailable_mi"
        capture finegray_predict double xbq, xb
        assert _rc == 301
        capture finegray_cif, at(x=0 z=0)
        assert _rc == 301
        capture finegray_phtest
        assert _rc != 0
    }

    _fgml_data, lt(0)
    _fgml_set, style(wide) m(2) lt(0)
    foreach spec in "bstrata(wstr)" "tvc(x) tsplit(6)" "nuisance" {
        quietly finegray x z, compete(etype) cause(1) `spec' nolog
        assert `"`e(postest)'"' == "unavailable_mi"
        capture finegray_predict double xbq2, xb
        assert _rc == 301
        capture finegray_cif, at(x=0 z=0)
        assert _rc == 301
    }
}
local _rc = _rc
_fgml_result `_rc' ///
    "FGML-12 post-estimation refuses r(301) on every mi-mode fit shape"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# Summary
display as text _newline ///
    "RESULT: test_finegray_mi_lattice tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fgml
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fgml
