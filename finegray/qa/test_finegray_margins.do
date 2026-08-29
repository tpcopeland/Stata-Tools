* test_finegray_margins.do
* Native margins on factor terms, and the widened coefficient stripe behind it.
*
* Through 2026-08-28 `margins pelnode' after `finegray i.pelnode ...' stopped
* with r(322): the design-column list was posted as e(covariates), a name
* margins reads as the fit's covariate list, and the stripe had no base-level
* column for margins to enumerate a factor's levels from.  The fix posts the
* full fit-time expansion (0b.pelnode 1.pelnode ...) as e(b)/e(V) with zero
* base entries, records the design columns as e(designvars), and routes every
* positional consumer through _finegray_bnb (Stata) / _finegray_beta() (Mata).
*
* Two contracts are pinned here.  (1) margins now runs and agrees with hand
* computation.  (2) Nothing downstream moved: the CIF, the linear predictor,
* the Schoenfeld residuals and finegray_phtest on a factor fit equal the same
* quantities from a fit on hand-built indicator columns EXACTLY (mreldif 0),
* because a mis-pairing in the non-base filter would show there first.
*
*   MG-01  the posted stripe: names, zero base entries, e(designvars),
*          e(marginsok), e(covariates) absent, both accessors agree
*   MG-02  the estimate in the design frame equals a manual-indicator fit
*   MG-03  margins pelnode == at(pelnode=(0 1)) == at(...) predict(xb) ==
*          hand-computed counterfactual means; dydx(pelnode) by hand
*   MG-04  the delta-method SE by hand from e(V)
*   MG-05  design columns dropped: margins unchanged
*   MG-06  estimates store/restore: margins runs; e(b) intact after margins
*   MG-07  ib2. base and a changed fvset base: margins honours the FITTED base
*   MG-08  a re-striped e(b) (what margins posts while it runs): xb scores by
*          name, cif refuses
*   MG-09  results without e(designvars): every consumer refuses r(301)
*   MG-10  post-estimation identity with the manual-indicator fit: predict
*          cif/xb/schoenfeld, finegray_cif at()/over(), finegray_phtest
*   MG-11  bootstrap refits conform (e(designvars) guard) and run
*   MG-12  test/testparm/contrast/lincom/estimates table on the wide stripe
*   MG-13  tvc() fit: narrow stripe, e(marginsok) empty; non-factor fit:
*          stripe unchanged
*   MG-14  mi estimate pools the wide stripe

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_margins.log", replace name(_mg)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _mg_hypoxia
program define _mg_hypoxia
    webuse hypoxia, clear
    gen byte status = failtype
    quietly stset dftime, failure(dfcens==1) id(stnum)
    * hand-built indicator columns for the manual-fit comparisons
    gen byte pel_1 = (pelnode == 1)
    gen double pel_1_ifp = pel_1 * ifp
end

* Repost e(b) renamed onto variables, the way margins does while it runs.
capture program drop _mg_restripe
program define _mg_restripe, eclass
    args names
    tempname b
    matrix `b' = e(b)
    matrix colnames `b' = `names'
    ereturn repost b = `b', rename
end

* Results as a finegray before e(designvars) posted them.
capture program drop _mg_predate
program define _mg_predate, eclass
    args cols
    ereturn local designvars ""
    ereturn local covariates "`cols'"
end

**# MG-01: the posted stripe
* Stata spells a base level's continuous partner with the omitted marker:
* 0b.pelnode#co.ifp, exactly as stcox/stcrreg post it.
local ++test_count
capture noisily {
    _mg_hypoxia
    quietly finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    local cn : colnames e(b)
    assert "`cn'" == "0b.pelnode 1.pelnode ifp 0b.pelnode#co.ifp 1.pelnode#c.ifp tumsize"
    local rn : rownames e(V)
    assert "`rn'" == "`cn'"
    assert "`e(designvars)'" == "_fg_pelnode_1 ifp _fg_pelnode_1Xifp tumsize"
    assert "`e(covariates)'" == ""
    assert "`e(marginsok)'" == "xb"
    * base entries are exactly zero, in b and in every row/column of V
    assert e(b)[1, 1] == 0 & e(b)[1, 4] == 0
    tempname V
    matrix `V' = e(V)
    forvalues j = 1/6 {
        assert `V'[1, `j'] == 0 & `V'[`j', 1] == 0
        assert `V'[4, `j'] == 0 & `V'[`j', 4] == 0
    }
    * the non-base accessor: one column per design column, in order
    tempname bnb vnb
    _finegray_bnb, b(`bnb') v(`vnb')
    assert colsof(`bnb') == 4 & rowsof(`vnb') == 4 & colsof(`vnb') == 4
    local nn : colnames `bnb'
    assert "`nn'" == "1.pelnode ifp 1.pelnode#c.ifp tumsize"
    assert `bnb'[1, 1] == e(b)[1, 2] & `bnb'[1, 2] == e(b)[1, 3]
    assert `bnb'[1, 3] == e(b)[1, 5] & `bnb'[1, 4] == e(b)[1, 6]
    assert `vnb'[1, 1] == `V'[2, 2] & `vnb'[3, 3] == `V'[5, 5]
    assert `vnb'[1, 3] == `V'[2, 5] & `vnb'[2, 4] == `V'[3, 6]
    * the Mata accessor agrees with the Stata one
    mata: st_matrix("MG_beta", _finegray_beta()')
    assert mreldif(MG_beta, `bnb') == 0
    * ibn. carries a real coefficient in every level: no base marker, no
    * widening, the accessors are the identity
    quietly finegray ibn.pelnode#c.ifp tumsize, compete(status) cause(1) nolog
    local cn : colnames e(b)
    assert strpos("`cn'", "b.") == 0
    _finegray_bnb, b(`bnb')
    assert mreldif(`bnb', e(b)) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: MG-01 posted stripe"
}
else {
    local ++fail_count
    display as error "  FAIL: MG-01 posted stripe (rc=`=_rc')"
}

**# MG-02: the estimate in the design frame equals a manual-indicator fit
local ++test_count
capture noisily {
    _mg_hypoxia
    quietly finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    local ll_fv = e(ll)
    tempname bnb vnb
    _finegray_bnb, b(`bnb') v(`vnb')
    drop _fg_*
    quietly finegray pel_1 ifp pel_1_ifp tumsize, compete(status) cause(1) nolog
    assert reldif(e(ll), `ll_fv') < 1e-12
    assert mreldif(`bnb', e(b)) < 1e-10
    assert mreldif(`vnb', e(V)) < 1e-10
    * the manual fit has no base column: stripe and accessors are the identity
    assert colsof(e(b)) == 4
    _finegray_bnb, b(`bnb')
    assert mreldif(`bnb', e(b)) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: MG-02 estimate equals manual-indicator fit"
}
else {
    local ++fail_count
    display as error "  FAIL: MG-02 estimate equals manual-indicator fit (rc=`=_rc')"
}

**# MG-03: every margins form agrees, and with hand computation
* margins reaches xb two ways: analytically (predict(xb): design means times
* e(b)) and through finegray_predict (default predict: it reposts e(b) renamed
* onto its own fvrevar'd level indicators, sets those to the at() values and
* scores).  Both build the factor columns as FLOAT temporaries, so agreement
* with the double-precision rebuild is at ~1e-7, not 1e-15.
local ++test_count
capture noisily {
    _mg_hypoxia
    quietly finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    quietly margins pelnode
    tempname M1 V1 M2 V2 M3 V3
    matrix `M1' = r(b)
    matrix `V1' = r(V)
    assert colsof(`M1') == 2
    quietly margins, at(pelnode=(0 1))
    matrix `M2' = r(b)
    matrix `V2' = r(V)
    quietly margins, at(pelnode=(0 1)) predict(xb)
    matrix `M3' = r(b)
    matrix `V3' = r(V)
    assert mreldif(`M1', `M2') < 1e-12
    assert mreldif(`M1', `M3') < 1e-12
    assert mreldif(`V1', `V3') < 1e-6
    assert mreldif(`V2', `V3') < 1e-6
    * hand: the mean linear predictor with every subject at pelnode = 0, then 1
    preserve
    replace pelnode = 0
    quietly finegray_predict double h0, xb
    quietly summarize h0 if e(sample), meanonly
    local m0 = r(mean)
    replace pelnode = 1
    quietly finegray_predict double h1, xb
    quietly summarize h1 if e(sample), meanonly
    local m1 = r(mean)
    restore
    assert reldif(`M1'[1, 1], `m0') < 1e-6
    assert reldif(`M1'[1, 2], `m1') < 1e-6
    * dydx(pelnode) is the discrete change m1 - m0, and by hand it is
    * b[1.pelnode] + b[1.pelnode#c.ifp] * mean(ifp)
    quietly margins, dydx(pelnode)
    tempname D
    matrix `D' = r(b)
    assert reldif(`D'[1, 2], `m1' - `m0') < 1e-6
    quietly summarize ifp if e(sample), meanonly
    local dhand = e(b)[1, 2] + e(b)[1, 5] * r(mean)
    assert reldif(`D'[1, 2], `dhand') < 1e-6
    * the continuous margin in the same fit is untouched by the widening
    quietly margins, dydx(ifp)
    assert !missing(r(b)[1, 1])
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: MG-03 margins forms agree with hand computation"
}
else {
    local ++fail_count
    display as error "  FAIL: MG-03 margins forms agree with hand computation (rc=`=_rc')"
}

**# MG-04: the delta-method SE by hand from e(V)
* margins, at(pelnode=1 ifp=15) predict(xb) is xbar' b with xbar the design
* means under that profile (tumsize as observed); its SE is sqrt(xbar' V xbar)
* on the WIDE stripe, where the base columns contribute exact zeros.
local ++test_count
capture noisily {
    _mg_hypoxia
    quietly finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    quietly summarize tumsize if e(sample), meanonly
    local mt = r(mean)
    tempname X est XVX
    matrix `X' = (0, 1, 15, 0, 15, `mt')
    matrix `est' = `X' * e(b)'
    matrix `XVX' = `X' * e(V) * `X''
    local se_hand = sqrt(`XVX'[1, 1])
    quietly margins, at(pelnode=1 ifp=15) predict(xb)
    assert reldif(r(b)[1, 1], `est'[1, 1]) < 1e-6
    assert reldif(sqrt(r(V)[1, 1]), `se_hand') < 1e-6
    quietly margins, at(pelnode=1 ifp=15)
    assert reldif(r(b)[1, 1], `est'[1, 1]) < 1e-6
    assert reldif(sqrt(r(V)[1, 1]), `se_hand') < 1e-5
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: MG-04 delta-method SE by hand"
}
else {
    local ++fail_count
    display as error "  FAIL: MG-04 delta-method SE by hand (rc=`=_rc')"
}

**# MG-05: design columns dropped -- margins unchanged
local ++test_count
capture noisily {
    _mg_hypoxia
    quietly finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    quietly margins pelnode
    tempname M1 M2
    matrix `M1' = r(b)
    drop _fg_*
    quietly margins pelnode
    matrix `M2' = r(b)
    assert mreldif(`M1', `M2') == 0
    quietly margins, at(pelnode=(0 1))
    assert mreldif(`M1', r(b)) < 1e-12
    * and the data are as the user left them: no rebuilt column left behind
    capture confirm variable _fg_pelnode_1
    assert _rc != 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: MG-05 margins with design columns dropped"
}
else {
    local ++fail_count
    display as error "  FAIL: MG-05 margins with design columns dropped (rc=`=_rc')"
}

**# MG-06: estimates save/use, and e(b) intact after margins
local ++test_count
capture noisily {
    _mg_hypoxia
    quietly finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    tempname B0 M1
    matrix `B0' = e(b)
    quietly finegray_predict xb_before, xb
    quietly margins pelnode
    matrix `M1' = r(b)
    * margins hands the fit back as it found it
    assert mreldif(`B0', e(b)) == 0
    local cn : colnames e(b)
    assert "`cn'" == "0b.pelnode 1.pelnode ifp 0b.pelnode#co.ifp 1.pelnode#c.ifp tumsize"
    quietly finegray_predict xb_after, xb
    assert xb_before == xb_after
    * a stored-and-restored fit answers margins the same way (estimates use
    * would need `estimates esample:' first, as after any estimator)
    quietly estimates store mg_fit
    quietly finegray ifp, compete(status) cause(1) nolog
    quietly estimates restore mg_fit
    quietly margins pelnode
    assert mreldif(`M1', r(b)) == 0
    estimates drop mg_fit
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: MG-06 estimates restore; e(b) intact after margins"
}
else {
    local ++fail_count
    display as error "  FAIL: MG-06 estimates restore; e(b) intact after margins (rc=`=_rc')"
}

**# MG-07: a non-default base, and a changed fvset base after the fit
* The stripe carries the FITTED base (2b.grp).  margins enumerates levels from
* the stripe, so `fvset base 3 grp' after the fit must not move a single number.
local ++test_count
capture noisily {
    _mg_hypoxia
    gen byte grp = 1 + (ifp > 5) + (ifp > 15)
    quietly finegray ib2.grp tumsize, compete(status) cause(1) nolog
    local cn : colnames e(b)
    assert "`cn'" == "1.grp 2b.grp 3.grp tumsize"
    assert e(b)[1, 2] == 0
    tempname bnb
    _finegray_bnb, b(`bnb')
    * Stata normalises a re-striped vector with no base level to `Nbn.', so
    * compare on the level numbers and the variable, not the marker
    local nn : colnames `bnb'
    assert colsof(`bnb') == 3
    assert regexm("`: word 1 of `nn''", "^1(bn)?\.grp$")
    assert "`: word 2 of `nn''" == "3.grp" & "`: word 3 of `nn''" == "tumsize"
    assert "`e(designvars)'" == "_fg_grp_1 _fg_grp_3 tumsize"
    quietly margins grp
    tempname M1
    matrix `M1' = r(b)
    assert colsof(`M1') == 3
    * level 2 is the base: its margin is the mean of b[tumsize] * tumsize
    quietly summarize tumsize if e(sample), meanonly
    assert reldif(`M1'[1, 2], e(b)[1, 4] * r(mean)) < 1e-6
    * level 1 differs from it by b[1.grp], level 3 by b[3.grp]
    assert reldif(`M1'[1, 1] - `M1'[1, 2], e(b)[1, 1]) < 1e-6
    assert reldif(`M1'[1, 3] - `M1'[1, 2], e(b)[1, 3]) < 1e-6
    fvset base 3 grp
    quietly margins grp
    assert mreldif(`M1', r(b)) == 0
    quietly margins, at(grp=(1 2 3))
    assert mreldif(`M1', r(b)) < 1e-12
    fvset clear grp
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: MG-07 non-default base; fvset change after the fit"
}
else {
    local ++fail_count
    display as error "  FAIL: MG-07 non-default base; fvset change after the fit (rc=`=_rc')"
}

**# MG-08: a re-striped e(b) -- xb scores by name, cif refuses
* This is what margins posts while it runs (the "-13.78 for both levels" defect
* in development was finegray_predict keeping every column of the renamed
* stripe and mislabelling them by repetition).  `double' throughout: without a
* type the new variable is c(type) = float, and a float xb differs from the
* double hand computation at ~5e-8, which is storage, not scoring.
local ++test_count
capture noisily {
    _mg_hypoxia
    quietly finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    quietly finegray_predict double xb_fit, xb
    * the renamed stripe names real variables holding the level indicators
    gen byte mg_z0 = (pelnode == 0)
    gen byte mg_z1 = (pelnode == 1)
    gen double mg_i0 = mg_z0 * ifp
    gen double mg_i1 = mg_z1 * ifp
    _mg_restripe "mg_z0 mg_z1 ifp mg_i0 mg_i1 tumsize"
    local cn : colnames e(b)
    assert "`cn'" == "mg_z0 mg_z1 ifp mg_i0 mg_i1 tumsize"
    quietly finegray_predict double xb_ren, xb
    gen double mg_d = abs(xb_ren - xb_fit)
    quietly summarize mg_d
    assert r(max) < 1e-12
    * ...and with the indicators moved, xb follows the NAMED columns
    quietly replace mg_z1 = 0
    quietly replace mg_i1 = 0
    quietly finegray_predict double xb_ren0, xb
    gen double mg_hand0 = e(b)[1, 3] * ifp + e(b)[1, 6] * tumsize
    quietly replace mg_d = abs(xb_ren0 - mg_hand0)
    quietly summarize mg_d
    assert r(max) < 1e-12
    * the CIF pairs by design column and cannot honour a renamed stripe
    capture finegray_predict cif_ren, cif
    assert _rc == 498
    * a stripe naming nothing scoreable fails closed, not by repetition
    _mg_restripe "mg_q0 mg_q1 mg_q2 mg_q3 mg_q4 mg_q5"
    capture finegray_predict xb_bad, xb
    assert _rc == 498
    capture confirm variable xb_bad
    assert _rc != 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: MG-08 re-striped e(b): xb by name, cif refuses"
}
else {
    local ++fail_count
    display as error "  FAIL: MG-08 re-striped e(b): xb by name, cif refuses (rc=`=_rc')"
}

**# MG-09: results without e(designvars) are refused by every consumer
local ++test_count
capture noisily {
    _mg_hypoxia
    quietly finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    local cols "`e(designvars)'"
    _mg_predate "`cols'"
    assert "`e(designvars)'" == "" & "`e(covariates)'" == "`cols'"
    capture finegray_predict xb_old, xb
    assert _rc == 301
    capture finegray_predict cif_old, cif
    assert _rc == 301
    capture finegray_cif, attime(2) nograph
    assert _rc == 301
    capture finegray_phtest
    assert _rc == 301
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: MG-09 results without e(designvars) refused"
}
else {
    local ++fail_count
    display as error "  FAIL: MG-09 results without e(designvars) refused (rc=`=_rc')"
}

**# MG-10: post-estimation identity with the manual-indicator fit
* The design-frame consumers must not have moved.  Every quantity from the
* factor fit equals the manual-indicator fit's EXACTLY: same columns, same
* arithmetic, so mreldif is 0, not a tolerance.
local ++test_count
capture noisily {
    _mg_hypoxia
    quietly finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    quietly finegray_predict fv_cif, cif ci
    quietly finegray_predict fv_xb, xb
    quietly finegray_predict fv_sch, schoenfeld
    quietly finegray_cif, at(pelnode=1 ifp=10) attime(2 5) ci nograph
    tempname C1 C1o P1
    matrix `C1' = r(table)
    quietly finegray_cif, over(pelnode) attime(2 5) nograph
    matrix `C1o' = r(table)
    quietly finegray_phtest
    matrix `P1' = r(phtest)
    drop _fg_*
    quietly finegray pel_1 ifp pel_1_ifp tumsize, compete(status) cause(1) nolog
    quietly finegray_predict mn_cif, cif ci
    quietly finegray_predict mn_xb, xb
    quietly finegray_predict mn_sch, schoenfeld
    foreach v in cif cif_lci cif_uci xb {
        quietly count if fv_`v' != mn_`v' & !(missing(fv_`v') & missing(mn_`v'))
        assert r(N) == 0
    }
    foreach sfx in "" "_2" "_3" "_4" {
        quietly count if fv_sch`sfx' != mn_sch`sfx' & !(missing(fv_sch`sfx') & missing(mn_sch`sfx'))
        assert r(N) == 0
    }
    quietly finegray_cif, at(pel_1=1 ifp=10 pel_1_ifp=10) attime(2 5) ci nograph
    assert mreldif(`C1', r(table)) == 0
    * over(pelnode) on the factor fit == the two manual profiles stacked
    quietly finegray_cif, at(pel_1=0 pel_1_ifp=0) attime(2 5) nograph
    tempname O0
    matrix `O0' = r(table)
    quietly finegray_cif, at(pel_1=1) attime(2 5) nograph
    * at(pel_1=1) alone leaves pel_1_ifp at its sample mean; the factor fit's
    * over() sets the interaction from the level, so build that profile
    quietly summarize ifp if e(sample), meanonly
    quietly finegray_cif, at(pel_1=1 pel_1_ifp=`r(mean)') attime(2 5) nograph
    tempname O1 S0 S1
    matrix `O1' = r(table)
    matrix `S0' = `C1o'[1..2, 1..5]
    matrix `S1' = `C1o'[3..4, 1..5]
    assert mreldif(`S0', `O0') == 0
    assert mreldif(`S1', `O1') == 0
    quietly finegray_phtest
    assert mreldif(`P1', r(phtest)) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: MG-10 post-estimation identity with manual fit"
}
else {
    local ++fail_count
    display as error "  FAIL: MG-10 post-estimation identity with manual fit (rc=`=_rc')"
}

**# MG-11: bootstrap refits conform and run on the wide stripe
local ++test_count
capture noisily {
    _mg_hypoxia
    quietly finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    quietly finegray_cif, at(pelnode=1 ifp=10) attime(2 5) ci bootstrap(25) seed(7) nograph
    assert r(bootstrap_requested) == 25
    assert r(bootstrap_success) == 25
    tempname T
    matrix `T' = r(table)
    assert `T'[1, 3] > 0 & !missing(`T'[1, 3])
    quietly finegray_predict bs_cif, cif ci bootstrap(25) seed(7)
    quietly count if !missing(bs_cif_lci) & e(sample)
    assert r(N) > 0
    * the point estimate did not move through the refits
    quietly finegray_cif, at(pelnode=1 ifp=10) attime(2 5) nograph
    tempname Tb Ta
    matrix `Tb' = `T'[1..2, 1..2]
    matrix `Ta' = r(table)
    matrix `Ta' = `Ta'[1..2, 1..2]
    assert mreldif(`Tb', `Ta') == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: MG-11 bootstrap on the wide stripe"
}
else {
    local ++fail_count
    display as error "  FAIL: MG-11 bootstrap on the wide stripe (rc=`=_rc')"
}

**# MG-12: the official post-estimation commands address the wide stripe
local ++test_count
capture noisily {
    _mg_hypoxia
    quietly finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    quietly test 1.pelnode
    assert r(df) == 1 & !missing(r(chi2))
    quietly testparm i.pelnode
    assert r(df) == 1
    quietly testparm i.pelnode#c.ifp
    assert r(df) == 1
    quietly lincom 1.pelnode + 1.pelnode#c.ifp * 10
    assert reldif(r(estimate), e(b)[1, 2] + 10 * e(b)[1, 5]) < 1e-12
    quietly contrast pelnode
    assert !missing(r(chi2)[1, 1])
    quietly estimates table
    quietly pwcompare pelnode
    assert !missing(r(b)[1, 1])
    * e(rank) and e(df_m) count the estimated coefficients, not the stripe
    assert e(df_m) == 4
    assert e(rank) == 4
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: MG-12 test/testparm/contrast/lincom/pwcompare"
}
else {
    local ++fail_count
    display as error "  FAIL: MG-12 test/testparm/contrast/lincom/pwcompare (rc=`=_rc')"
}

**# MG-13: tvc() fits are posted narrow; non-factor fits are unchanged
local ++test_count
capture noisily {
    _mg_hypoxia
    quietly finegray i.pelnode ifp tumsize, compete(status) cause(1) tvc(ifp) tsplit(3) nolog
    local cn : colnames e(b)
    assert strpos("`cn'", "b.") == 0
    assert "`cn'" == "1.pelnode tumsize ifp ifp"
    assert "`e(marginsok)'" == ""
    tempname bnb
    _finegray_bnb, b(`bnb')
    assert mreldif(`bnb', e(b)) == 0
    local eq : coleq `bnb'
    assert "`eq'" == "main main tvc1 tvc2"
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    local cn : colnames e(b)
    assert "`cn'" == "ifp tumsize pelnode"
    assert "`e(designvars)'" == "ifp tumsize pelnode"
    assert "`e(marginsok)'" == "xb"
    _finegray_bnb, b(`bnb')
    assert mreldif(`bnb', e(b)) == 0
    quietly margins, dydx(pelnode)
    assert reldif(r(b)[1, 1], e(b)[1, 3]) < 1e-12
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: MG-13 tvc() narrow; non-factor unchanged"
}
else {
    local ++fail_count
    display as error "  FAIL: MG-13 tvc() narrow; non-factor unchanged (rc=`=_rc')"
}

**# MG-14: mi estimate pools the wide stripe
local ++test_count
capture noisily {
    _mg_hypoxia
    quietly replace tumsize = . if mod(stnum, 9) == 0
    quietly mi set wide
    quietly mi register imputed tumsize
    quietly mi register regular ifp pelnode status dftime dfcens stnum
    quietly mi impute regress tumsize ifp pelnode, add(3) rseed(11)
    quietly mi estimate, cmdok: finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    local cn : colnames e(b_mi)
    assert "`cn'" == "0b.pelnode 1.pelnode ifp 0b.pelnode#co.ifp 1.pelnode#c.ifp tumsize"
    assert e(b_mi)[1, 1] == 0 & e(b_mi)[1, 4] == 0
    assert !missing(e(b_mi)[1, 2]) & !missing(e(b_mi)[1, 5])
    assert e(V_mi)[1, 1] == 0 & e(V_mi)[4, 4] == 0
    assert e(V_mi)[2, 2] > 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: MG-14 mi estimate pools the wide stripe"
}
else {
    local ++fail_count
    display as error "  FAIL: MG-14 mi estimate pools the wide stripe (rc=`=_rc')"
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_margins tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _mg
    exit 1
}
display as result "ALL TESTS PASSED"
log close _mg
