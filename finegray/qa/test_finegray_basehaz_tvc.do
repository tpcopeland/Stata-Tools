*! test_finegray_basehaz_tvc Version 1.0.0 2026/10/10
*! The e(basehaz_tvc) payload: layout, interval-mass identity, posting rule, saved-fit prediction
*! Author: Timothy P Copeland, Karolinska Institutet
* Oracles: e(basehaz) is the running sum of the interval masses, and a CIF
* computed by hand from the payload and the per-interval coefficients.
version 16.0
clear all
set processors 1
capture log close _all
log using test_finegray_basehaz_tvc.log, text replace
local qa_dir "`c(pwd)'"
if substr("`qa_dir'",-3,3)!="/qa" error 198
local pkg_dir=substr("`qa_dir'",1,strlen("`qa_dir'")-3)
do "`qa_dir'/_finegray_qa_common.do"
_finegray_qa_bootstrap
local orig_plus "`r(orig_plus)'"
local orig_personal "`r(orig_personal)'"
local plus_dir "`r(plus_dir)'"
local personal_dir "`r(personal_dir)'"
which finegray
findfile finegray.ado
assert strpos(`"`r(fn)'"', `"`plus_dir'"')==1
local test_count=0
local pass_count=0
local fail_count=0

tempfile bhdata savedfit
clear
set seed 20261010
set obs 300
generate long id=_n
generate double x=rnormal()
generate byte g=mod(_n,2)
generate double t=ceil(10*runiform())/2
generate byte status=cond(runiform()<.4,1,cond(runiform()<.5,2,0))
stset t, failure(status) id(id)
quietly save `bhdata'

* Checks one stratum block of e(basehaz_tvc) against e(basehaz): the interval
* index is 1..nint and nondecreasing, every time lies in its interval's
* (lower, upper] range, each interval's cumhazard is positive and
* nondecreasing, and the running sum of interval masses reproduces e(basehaz)
* at the same time.  bh_s is the stratum's rows of e(basehaz) as (time, cum).
capture mata: mata drop qa_bhtvc_block()
mata:
void qa_bhtvc_block(real matrix tv, real matrix bh_s, real rowvector cuts)
{
    real scalar i, j, lo, hi, carry, last
    real colvector intv, tm, cm

    intv = tv[., 2]; tm = tv[., 3]; cm = tv[., 4]
    assert(rows(tv) == rows(bh_s))
    assert(all(tm :== bh_s[., 1]))
    assert(all(intv :>= 1) & all(intv :<= cols(cuts) + 1))
    assert(all(intv[|2 \ rows(intv)|] :>= intv[|1 \ (rows(intv)-1)|]))
    carry = 0
    last  = .
    for (i = 1; i <= rows(tv); i++) {
        j  = intv[i]
        lo = 0
        hi = .
        if (j > 1) lo = cuts[j-1]
        if (j <= cols(cuts)) hi = cuts[j]
        assert(tm[i] > lo & tm[i] <= hi)
        if (i > 1) {
            if (j != intv[i-1]) {
                carry = carry + cm[i-1]
                last  = .
            }
        }
        assert(cm[i] > 0)
        if (last < .) assert(cm[i] >= last)
        last = cm[i]
        assert(reldif(carry + cm[i], bh_s[i, 2]) < 1e-12)
    }
}
end

**# B1: unstratified layout and the running-sum identity
local ++test_count
capture noisily {
    use `bhdata', clear
    quietly finegray x, compete(status) cause(1) tvc(x) tsplit(2 3.5) basehaz nolog
    confirm matrix e(basehaz_tvc)
    tempname tv bh
    matrix `tv'=e(basehaz_tvc)
    matrix `bh'=e(basehaz)
    assert colsof(`tv')==4
    assert "`: colnames `tv''"=="bstratum interval time cumhazard"
    assert rowsof(`tv')==rowsof(`bh')
    * Unstratified fits carry the constant stratum label 1.
    mata: st_local("bad", strofreal(any(st_matrix("`tv'")[.,1] :!= 1)))
    assert `bad'==0
    mata: qa_bhtvc_block(st_matrix("`tv'"), st_matrix("`bh'"), (2, 3.5))
    * All three intervals hold cause events in this fixture.
    mata: st_local("nint", strofreal(max(st_matrix("`tv'")[.,2])))
    assert `nint'==3
}
local test_rc=_rc
if `test_rc'==0 {
    local ++pass_count
    display as result "PASS: B1"
}
else {
    local ++fail_count
    display as error "FAIL: B1 rc=`test_rc'"
}

**# B2: bstrata() layout, labels, and the identity within every stratum
local ++test_count
capture noisily {
    use `bhdata', clear
    quietly finegray x, compete(status) cause(1) tvc(x) tsplit(2 3.5) bstrata(g) basehaz nolog
    tempname tv bh
    matrix `tv'=e(basehaz_tvc)
    matrix `bh'=e(basehaz)
    assert "`: colnames `tv''"=="bstratum interval time cumhazard"
    assert "`: colnames `bh''"=="bstratum time cumhazard"
    assert rowsof(`tv')==rowsof(`bh')
    mata: qa_tv=st_matrix("`tv'"); qa_bh=st_matrix("`bh'")
    * The stratum column holds the bstrata() values, not 1..K.
    mata: assert(uniqrows(qa_tv[.,1]) == (0 \ 1))
    foreach s in 0 1 {
        mata: qa_tvs=select(qa_tv, qa_tv[.,1]:==`s')
        mata: qa_bhs=select(qa_bh, qa_bh[.,1]:==`s')[., (2,3)]
        mata: qa_tvs=sort(qa_tvs, (2,3))
        mata: qa_bhtvc_block(qa_tvs, qa_bhs, (2, 3.5))
    }
    mata: mata drop qa_tv qa_bh qa_tvs qa_bhs
}
local test_rc=_rc
if `test_rc'==0 {
    local ++pass_count
    display as result "PASS: B2"
}
else {
    local ++fail_count
    display as error "FAIL: B2 rc=`test_rc'"
}

**# B3: posted only with both tvc() and basehaz
local ++test_count
capture noisily {
    use `bhdata', clear
    quietly finegray x, compete(status) cause(1) tvc(x) tsplit(2) nolog
    capture confirm matrix e(basehaz_tvc)
    assert _rc==111
    quietly finegray x, compete(status) cause(1) basehaz nolog
    confirm matrix e(basehaz)
    capture confirm matrix e(basehaz_tvc)
    assert _rc==111
    quietly finegray x, compete(status) cause(1) bstrata(g) basehaz nolog
    capture confirm matrix e(basehaz_tvc)
    assert _rc==111
}
local test_rc=_rc
if `test_rc'==0 {
    local ++pass_count
    display as result "PASS: B3"
}
else {
    local ++fail_count
    display as error "FAIL: B3 rc=`test_rc'"
}

**# B4: a saved TVC fit predicts from the payload alone, equal to a hand CIF
local ++test_count
capture noisily {
    use `bhdata', clear
    quietly finegray x, compete(status) cause(1) tvc(x) tsplit(2 3.5) basehaz nolog
    tempname b tv
    matrix `b'=e(b)
    matrix `tv'=e(basehaz_tvc)
    quietly estimates save `savedfit', replace
    clear
    quietly set obs 4
    generate double x=cond(_n<=2,-.7,1.3)
    generate double horizon=cond(mod(_n,2),1.5,4.5)
    finegray_predict double p_live, cif timevar(horizon)
    * Hand CIF: 1-exp(-sum_j exp(x*b_j)*dH_j(h)), dH_j(h) the last interval-j
    * cumhazard at or before h.
    generate double p_hand=.
    mata: qa_tv=st_matrix("`tv'"); qa_b=st_matrix("`b'")
    forvalues i=1/4 {
        mata: qa_h=st_data(`i',"horizon"); qa_x=st_data(`i',"x"); qa_s=0
        mata: for (qa_j=1; qa_j<=3; qa_j++) { qa_r=select(qa_tv[.,4], qa_tv[.,2]:==qa_j :& qa_tv[.,3]:<=qa_h); if (rows(qa_r)) qa_s=qa_s+exp(qa_x*qa_b[qa_j])*qa_r[rows(qa_r)]; }
        mata: st_store(`i', "p_hand", 1-exp(-qa_s))
    }
    mata: mata drop qa_tv qa_b qa_h qa_x qa_s qa_j qa_r
    assert !missing(p_live, p_hand)
    assert reldif(p_live, p_hand)<1e-12
    * A fresh session: no Mata cache and no fitting data in memory.
    preserve
    clear all
    estimates use `savedfit'
    restore
    finegray_predict double p_saved, cif timevar(horizon)
    assert reldif(p_saved, p_live)<1e-12
}
local test_rc=_rc
if `test_rc'==0 {
    local ++pass_count
    display as result "PASS: B4"
}
else {
    local ++fail_count
    display as error "FAIL: B4 rc=`test_rc'"
}

**# B5: without the payload or the fitting data, CIF prediction refuses
local ++test_count
capture noisily {
    use `bhdata', clear
    quietly finegray x, compete(status) cause(1) tvc(x) tsplit(2 3.5) nolog
    capture confirm matrix e(basehaz_tvc)
    assert _rc==111
    quietly estimates save `savedfit', replace
    clear all
    estimates use `savedfit'
    quietly set obs 1
    generate double x=.5
    generate double horizon=4.5
    capture finegray_predict double p, cif timevar(horizon)
    assert _rc==459
    capture confirm variable p
    assert _rc==111
}
local test_rc=_rc
if `test_rc'==0 {
    local ++pass_count
    display as result "PASS: B5"
}
else {
    local ++fail_count
    display as error "FAIL: B5 rc=`test_rc'"
}

capture mata: mata drop qa_bhtvc_block()
sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'"
display as result "RESULT: test_finegray_basehaz_tvc tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close
if `fail_count' exit 1
