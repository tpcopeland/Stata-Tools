*! test_finegray_codexaudit_2026_09_27_b.do - Codex audit 2026-09-27, findings F03 F07 F08 F09
*! Author: Timothy P Copeland, Karolinska Institutet
*
* F03  No-id() weighted fit: exchanging two external scalars that feed the
*      weight expression kept the data, e(sum_w) and the multiset of weights,
*      so the value-only digest reconciled and post-estimation used the
*      reassigned weights with the old coefficients at rc 0.
* F07  finegray's cleanup dropped seventeen fixed _finegray_* matrices even
*      when the call failed in syntax, destroying same-named caller matrices;
*      on a successful fit a pre-existing caller matrix could also be read
*      back as if the engine had written it.
* F08  Loading the Mata engine left `matastrict on' in the caller's session.
* F09  Additive covariate origin: fits of x and x+c must agree (b, V, ll,
*      CIF), and an offset the engine cannot represent must fail explicitly,
*      never return a silently different fit.

clear all
set more off
set varabbrev off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
capture log close _all
log using "test_finegray_codexaudit_2026_09_27_b.log", replace text name(_test_fgcab)
do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap

capture program drop _fgcab_data
program define _fgcab_data
    clear
    set seed 280927
    set obs 800
    generate double x = rnormal()
    generate double z = rnormal()
    generate double t1 = -ln(runiform())/exp(.5*x-.2*z)
    generate double t2 = -ln(runiform())/.5
    generate double tc = -ln(runiform())/.3
    generate double t = min(t1,t2,tc)
    generate byte status = cond(t==t1,1,cond(t==t2,2,0))
    generate long id = _n
    generate byte g = mod(_n,2)
    generate double pw = 0.5 + runiform()
    generate double u = runiform()
end

capture program drop _fgcab_record
program define _fgcab_record
    args rc label
    if `rc' == 0 display as result "  PASS: `label'"
    else display as error "  FAIL: `label' (error `rc')"
end

* The seventeen names finegray's cleanup owns.
local fgmats _finegray_b _finegray_V _finegray_ll _finegray_ll_0 ///
    _finegray_chi2 _finegray_df_m _finegray_conv _finegray_rank ///
    _finegray_nclust _finegray_basehaz _finegray_kbstrata ///
    _finegray_nwstrata _finegray_minprob _finegray_maxwt ///
    _finegray_nprobwarn _finegray_nwtwarn _finegray_nprehole

* Create one distinctly valued, distinctly striped caller matrix per name.
capture program drop _fgcab_mkmats
program define _fgcab_mkmats
    local k = 0
    foreach m of local 0 {
        local ++k
        matrix `m' = (`k', `k'+0.5 \ -`k', 1/`k')
        matrix rownames `m' = row`k'a eq`k':row`k'b
        matrix colnames `m' = c`k'a c`k'b
    }
end

* Assert every caller matrix still holds its content and stripes.
capture program drop _fgcab_chkmats
program define _fgcab_chkmats
    local k = 0
    foreach m of local 0 {
        local ++k
        confirm matrix `m'
        tempname want
        matrix `want' = (`k', `k'+0.5 \ -`k', 1/`k')
        assert rowsof(`m') == 2 & colsof(`m') == 2
        assert mreldif(`m', `want') == 0
        local rn : rowfullnames `m'
        local cn : colfullnames `m'
        assert `"`rn'"' == "row`k'a eq`k':row`k'b"
        assert `"`cn'"' == "c`k'a c`k'b"
    }
end

**# F03  no-id() weight assignment

* -----------------------------------------------------------------------------
**## CAB-01  pweight: exchanging the scalars under no id() is refused
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgcab_data
    scalar wa = 1
    scalar wb = 3
    quietly stset t, failure(status==1 2)
    quietly finegray x z [pw=cond(g,scalar(wa),scalar(wb))], compete(status) cause(1) nolog
    assert "`e(idvar)'" == ""
    quietly finegray_cif, at(x=0 z=0) attime(1) ci nograph
    assert abs(r(table)[1,2] - .53268102) < 1e-7
    quietly finegray_predict double cc0, cif timevar(t)
    scalar wa = 3
    scalar wb = 1
    capture finegray_cif, at(x=0 z=0) attime(1) ci nograph
    local rc_cif = _rc
    capture finegray_predict double cc, cif ci timevar(t)
    local rc_pr = _rc
    capture drop cc cc_lci cc_uci
    * a plain CIF prediction reads the fit's own baseline and never rebuilds
    * the weights: it must either be refused or equal the fit-time answer
    capture finegray_predict double cc, cif timevar(t)
    local rc_pp = _rc
    if `rc_pp' == 0 {
        assert !missing(cc, cc0)
        assert reldif(cc, cc0) < 1e-12
        drop cc
    }
    display "CAB-01 rc_cif=`rc_cif' rc_predict_ci=`rc_pr' rc_predict_plain=`rc_pp'"
    assert `rc_cif' == 459
    assert `rc_pr' == 459
    assert inlist(`rc_pp', 0, 459)
    * restoring the scalars restores the fit's column: accepted again
    scalar wa = 1
    scalar wb = 3
    quietly finegray_cif, at(x=0 z=0) attime(1) ci nograph
    assert abs(r(table)[1,2] - .53268102) < 1e-7
}
local block_rc = _rc
_fgcab_record `block_rc' "CAB-01 F03 no-id() pweight scalar exchange refused r(459) by cif and predict"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

* -----------------------------------------------------------------------------
**## CAB-02  fweight: the same exchange under no id() is refused
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgcab_data
    scalar wa = 1
    scalar wb = 3
    quietly stset t, failure(status==1 2)
    quietly finegray x z [fw=cond(g,scalar(wa),scalar(wb))], compete(status) cause(1) nolog
    assert "`e(wtype)'" == "fweight"
    quietly finegray_cif, at(x=0 z=0) attime(1) ci nograph
    local cif0 = r(table)[1,2]
    scalar wa = 3
    scalar wb = 1
    capture finegray_cif, at(x=0 z=0) attime(1) ci nograph
    local rc_cif = _rc
    display "CAB-02 rc_cif=`rc_cif'"
    assert `rc_cif' == 459
    scalar wa = 1
    scalar wb = 3
    quietly finegray_cif, at(x=0 z=0) attime(1) ci nograph
    assert r(table)[1,2] == `cif0'
}
local block_rc = _rc
_fgcab_record `block_rc' "CAB-02 F03 no-id() fweight scalar exchange refused r(459)"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

* -----------------------------------------------------------------------------
**## CAB-03  legitimate re-sorts and variable weights still reconcile; id() control
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgcab_data
    scalar wa = 1
    scalar wb = 3
    quietly stset t, failure(status==1 2)
    quietly finegray x z [pw=cond(g,scalar(wa),scalar(wb))], compete(status) cause(1) nolog
    quietly finegray_cif, at(x=0 z=0) attime(1 2) ci nograph
    tempname tab0
    matrix `tab0' = r(table)
    assert !matmissing(`tab0')
    sort u
    quietly finegray_cif, at(x=0 z=0) attime(1 2) ci nograph
    assert mreldif(r(table), `tab0') < 1e-12
    gsort -x
    quietly finegray_cif, at(x=0 z=0) attime(1 2) ci nograph
    assert mreldif(r(table), `tab0') < 1e-12
    * a variable weight under no id(): re-sort accepted, one changed value refused
    _fgcab_data
    quietly stset t, failure(status==1 2)
    quietly finegray x z [pw=pw], compete(status) cause(1) nolog
    quietly finegray_cif, at(x=0 z=0) attime(1) ci nograph
    local c1 = r(table)[1,2]
    sort u
    quietly finegray_cif, at(x=0 z=0) attime(1) ci nograph
    assert !missing(r(table)[1,2], `c1')
    assert reldif(r(table)[1,2], `c1') < 1e-12
    quietly replace pw = pw * 2 in 5
    capture finegray_cif, at(x=0 z=0) attime(1) ci nograph
    assert _rc == 459
    * the explicit id() control still refuses the scalar exchange
    _fgcab_data
    scalar wa = 1
    scalar wb = 3
    quietly stset t, failure(status==1 2) id(id)
    quietly finegray x z [pw=cond(g,scalar(wa),scalar(wb))], compete(status) cause(1) nolog
    scalar wa = 3
    scalar wb = 1
    capture finegray_cif, at(x=0 z=0) attime(1) ci nograph
    assert _rc == 459
    scalar wa = 1
    scalar wb = 3
}
local block_rc = _rc
_fgcab_record `block_rc' "CAB-03 F03 re-sorts reconcile, changed variable weight refused, id() control refuses"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

* -----------------------------------------------------------------------------
**## CAB-04  saved and restored no-id() weighted estimates
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgcab_data
    scalar wa = 1
    scalar wb = 3
    quietly stset t, failure(status==1 2)
    quietly finegray x z [pw=cond(g,scalar(wa),scalar(wb))], compete(status) cause(1) nolog
    quietly finegray_cif, at(x=0 z=0) attime(1) ci nograph
    tempname tab0
    matrix `tab0' = r(table)
    assert !matmissing(`tab0')
    tempfile ster
    quietly estimates save "`ster'"
    estimates store fgcab_w
    quietly finegray x z, compete(status) cause(1) nolog
    quietly estimates restore fgcab_w
    sort u
    quietly finegray_cif, at(x=0 z=0) attime(1) ci nograph
    assert mreldif(r(table), `tab0') < 1e-12
    ereturn clear
    quietly estimates use "`ster'"
    quietly estimates esample: `e(datasignaturevars)'
    quietly finegray_cif, at(x=0 z=0) attime(1) ci nograph
    assert mreldif(r(table), `tab0') < 1e-12
    scalar wa = 3
    scalar wb = 1
    capture finegray_cif, at(x=0 z=0) attime(1) ci nograph
    assert _rc == 459
    quietly estimates restore fgcab_w
    capture finegray_cif, at(x=0 z=0) attime(1) ci nograph
    assert _rc == 459
    scalar wa = 1
    scalar wb = 3
    estimates drop fgcab_w
}
local block_rc = _rc
_fgcab_record `block_rc' "CAB-04 F03 estimates store/restore and save/use reconcile; exchange still refused"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

**# F07  caller matrices named like finegray's internal results

* -----------------------------------------------------------------------------
**## CAB-05  a syntax failure leaves every caller matrix intact
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgcab_data
    quietly stset t, failure(status==1 2)
    _fgcab_mkmats `fgmats'
    capture finegray x, cause(1)
    assert _rc == 198
    _fgcab_chkmats `fgmats'
    * a failure after parsing (unknown cause value) too
    capture finegray x, compete(status) cause(7) nolog
    assert _rc != 0
    _fgcab_chkmats `fgmats'
    matrix drop `fgmats'
}
local block_rc = _rc
_fgcab_record `block_rc' "CAB-05 F07 failed calls leave all 17 caller _finegray_* matrices (content, stripes) intact"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

* -----------------------------------------------------------------------------
**## CAB-06  a successful fit leaves caller matrices intact and does not read them
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgcab_data
    quietly stset t, failure(status==1 2)
    foreach m of local fgmats {
        capture matrix drop `m'
    }
    quietly finegray x z, compete(status) cause(1) nolog
    tempname b0 V0
    matrix `b0' = e(b)
    matrix `V0' = e(V)
    assert !matmissing(`b0') & !matmissing(`V0')
    local nc0 = e(N_clust)
    local ll0 = e(ll)
    local kbs0 = e(k_bstrata)
    local nph0 = e(N_lt_prehole)
    local nws0 = e(N_weight_strata)
    _fgcab_mkmats `fgmats'
    quietly finegray x z, compete(status) cause(1) nolog
    assert mreldif(e(b), `b0') == 0
    assert mreldif(e(V), `V0') == 0
    assert e(ll) == `ll0'
    assert e(k_bstrata) == `kbs0'
    assert e(N_lt_prehole) == `nph0'
    assert e(N_weight_strata) == `nws0'
    assert missing(`nc0')
    display "CAB-06 N_clust after caller _finegray_nclust = " e(N_clust)
    assert missing(e(N_clust))
    _fgcab_chkmats `fgmats'
    * the same with basehaz requested: the posted curve is the fit's
    quietly finegray x z, compete(status) cause(1) nolog basehaz
    assert colsof(e(basehaz)) == 2 & rowsof(e(basehaz)) > 2
    _fgcab_chkmats `fgmats'
    matrix drop `fgmats'
}
local block_rc = _rc
_fgcab_record `block_rc' "CAB-06 F07 successful fit: caller matrices intact and never read into e()"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

**# F08  matastrict is the caller's setting

* -----------------------------------------------------------------------------
**## CAB-07  cold and warm engine loads preserve matastrict on and off
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgcab_data
    quietly stset t, failure(status==1 2)
    foreach s in off on {
        * cold: the engine is not in memory
        mata: mata clear
        mata: mata set matastrict `s'
        quietly finegray x z, compete(status) cause(1) nolog
        display "CAB-07 cold fit start=`s' after=`c(matastrict)'"
        assert "`c(matastrict)'" == "`s'"
        * warm: already loaded
        quietly finegray x z, compete(status) cause(1) nolog
        assert "`c(matastrict)'" == "`s'"
        * cold through each post-estimation loader
        mata: mata clear
        quietly finegray_cif, at(x=0 z=0) attime(1) nograph
        assert "`c(matastrict)'" == "`s'"
        mata: mata clear
        quietly finegray_phtest
        assert "`c(matastrict)'" == "`s'"
        mata: mata clear
        quietly finegray_predict double cc, cif timevar(t)
        drop cc
        assert "`c(matastrict)'" == "`s'"
    }
    mata: mata set matastrict off
}
local block_rc = _rc
mata: mata set matastrict off
_fgcab_record `block_rc' "CAB-07 F08 cold/warm loads by fit, cif, phtest, predict keep matastrict on/off"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

* -----------------------------------------------------------------------------
**## CAB-08  a failing engine load also restores matastrict
* -----------------------------------------------------------------------------
local ++test_count
local brokendir ""
capture noisily {
    _fgcab_data
    quietly stset t, failure(status==1 2)
    quietly finegray x z, compete(status) cause(1) nolog
    * a private copy of the engine with a compile error after the strict switch
    findfile _finegray_mata.ado
    local src `"`r(fn)'"'
    tempfile anchor
    local brokendir "`anchor'_brokenmata"
    mkdir "`brokendir'"
    filefilter `"`src'"' "`brokendir'/_finegray_mata.ado", ///
        from("void _finegray_mata_ok() {}") to("void _finegray_mata_ok() {}\Ureal scalar _fgcab_broken( {")
    assert r(occurrences) == 1
    adopath ++ "`brokendir'"
    foreach s in off on {
        mata: mata clear
        mata: mata set matastrict `s'
        capture finegray x z, compete(status) cause(1) nolog
        local rc_fit = _rc
        display "CAB-08 fit load-failure rc=`rc_fit' start=`s' after=`c(matastrict)'"
        assert `rc_fit' != 0
        assert "`c(matastrict)'" == "`s'"
    }
}
local block_rc = _rc
capture adopath - "`brokendir'"
mata: mata clear
mata: mata set matastrict off
_fgcab_record `block_rc' "CAB-08 F08 engine load failure in finegray restores matastrict on/off"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

**# F09  additive covariate origin

* -----------------------------------------------------------------------------
**## CAB-09  x and x+c give the same fit, CIF and CIF SE on every route
* -----------------------------------------------------------------------------
* The CIF influence function squares the risk-set sum S0; with x + 1000 and a
* coefficient near .35, S0^2 overflowed while exp(eta) and the fit did not,
* the at-risk term vanished, and the CIF SE moved by 4% (plain) or 170%
* (cluster()) at rc 0 while b, V and the point CIF stayed right.
local ++test_count
capture noisily {
    foreach spec in plain lt clus tvc pw {
        _fgcab_data
        generate double t0 = cond(mod(_n,3)==0, 0.3*u*t, 0)
        generate byte cl = mod(_n, 40)
        local opt ""
        local wt ""
        if "`spec'" == "lt" quietly stset t, failure(status==1 2) enter(t0)
        else quietly stset t, failure(status==1 2)
        if "`spec'" == "clus" local opt "cluster(cl)"
        if "`spec'" == "tvc" local opt "tvc(x) tsplit(1)"
        if "`spec'" == "pw" local wt "[pw=pw]"
        quietly finegray x z `wt', compete(status) cause(1) nolog `opt'
        tempname b0 V0 tab0
        matrix `b0' = e(b)
        matrix `V0' = e(V)
        local ll0 = e(ll)
        quietly finegray_cif, at(x=0.25 z=-0.5) attime(0.5 1 2) ci nograph
        matrix `tab0' = r(table)
        assert !matmissing(`b0') & !matmissing(`V0') & !matmissing(`tab0')
        quietly finegray_predict double pc in 1/20, cif ci timevar(t)
        rename (pc pc_lci pc_uci) (pc0 pc0_lci pc0_uci)
        foreach c in 10 100 1000 1300 -1000 {
            generate double xs = x + `c'
            local optc : subinstr local opt "tvc(x)" "tvc(xs)"
            quietly finegray xs z `wt', compete(status) cause(1) nolog `optc'
            local db = mreldif(e(b), `b0')
            local dV = mreldif(e(V), `V0')
            local dll = reldif(e(ll), `ll0')
            local xat = 0.25 + `c'
            quietly finegray_cif, at(xs=`xat' z=-0.5) attime(0.5 1 2) ci nograph
            local dcif = mreldif(r(table), `tab0')
            quietly finegray_predict double pc in 1/20, cif ci timevar(t)
            generate double _d1 = reldif(pc_lci, pc0_lci) + reldif(pc_uci, pc0_uci) in 1/20
            summarize _d1, meanonly
            local dpr = r(max)
            display "CAB-09 `spec' c=`c' b=" %8.1e `db' " V=" %8.1e `dV' ///
                " ll=" %8.1e `dll' " cif=" %8.1e `dcif' " pred=" %8.1e `dpr'
            assert `db' < 1e-9
            assert `dV' < 1e-8
            assert `dll' < 1e-9
            assert `dcif' < 1e-8
            assert `dpr' < 1e-8
            drop xs pc pc_lci pc_uci _d1
        }
    }
}
local block_rc = _rc
_fgcab_record `block_rc' "CAB-09 F09 additive-origin invariance of b, V, ll, CIF and CIF CI (plain/lt/cluster/tvc/pw)"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

* -----------------------------------------------------------------------------
**## CAB-10  an unrepresentable offset fails explicitly, never silently
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgcab_data
    quietly stset t, failure(status==1 2)
    quietly finegray x z, compete(status) cause(1) nolog
    tempname b0
    matrix `b0' = e(b)
    assert !matmissing(`b0')
    foreach c in 2000 10000 {
        generate double xs = x + `c'
        ereturn clear
        capture finegray xs z, compete(status) cause(1) nolog
        local rc = _rc
        display "CAB-10 c=`c' rc=`rc'"
        if `rc' == 0 {
            * accepted only if it is the same fit
            assert mreldif(e(b), `b0') < 1e-9
        }
        else {
            assert "`e(cmd)'" != "finegray"
        }
        drop xs
    }
}
local block_rc = _rc
_fgcab_record `block_rc' "CAB-10 F09 offsets 2000/10000 either reproduce the fit or fail with no e() posted"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_finegray_codexaudit_2026_09_27_b tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _test_fgcab
if `fail_count' > 0 exit 1
exit 0
