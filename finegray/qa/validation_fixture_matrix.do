*! validation_fixture_matrix.do -- direct Fine-Gray risk weights and public postestimation
version 16.0
clear all
set processors 1
set varabbrev off
capture log close _all
log using "validation_fixture_matrix.log", text replace
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
quietly do "_qa_fx_a2.do"
quietly do "_qa_hostile.do"
quietly do "_qa_state.do"
// Fine & Gray1999 eqs6,8: retained competitors carry G(v-)/G(T_i-).
// Right-censored ties use ordinary flipped-status KM as stcrreg documents.
// LT ties order events before censorings (Geskus2011 eq5). One-cause entry
// reduces to the ordinary Cox risk set (t0,v] (Fine & Gray1999,p500).
mata:
void _qafg_direct(string scalar bname, string scalar wtype)
{
    real colvector t,c,e,x,g,us,et,w,rr,H,sr,xb,a,kmw
    real scalar n,j,k,v,gg,r,m,h,den,zbar,ne
    real matrix out
    t=st_data(.,"_t"); e=st_data(.,"_t0"); c=st_data(.,"cause")
    x=st_data(.,"x2"); n=rows(t); xb=x*st_matrix(bname)[1,1]
    a=J(n,1,1); if (wtype!="") a=st_data(.,"w")
    kmw=(wtype=="fweight" ? a : J(n,1,1))
    // G(t-) is evaluated independently at each observation's exit.
    us=uniqrows(sort(t,1)); g=J(n,1,1); gg=1
    for (j=1;j<=rows(us);j++) {
        v=us[j]; g[selectindex(t:==v)]=J(sum(t:==v),1,gg)
        r=sum(((t:>=v):&(e:<v)):*kmw)
        if (sum(e:>0)) r=r-sum(((t:==v):&(c:>0):&(e:<v)):*kmw)
        m=sum(((t:==v):&(c:==0):&(e:<v)):*kmw)
        if (m & r>0) gg=gg*(1-m/r)
    }
    et=uniqrows(sort(select(t,c:==1),1)); H=J(n,1,0); sr=J(n,1,.); h=0
    out=J(rows(et)+2,2,0); out[1,.]=(0,0)
    for (k=1;k<=rows(et);k++) {
        v=et[k]; w=(t:>=v):&(e:<v)
        if (sum(c:==2)) {
            if (sum(e:>0)) _error(9) // LT competitors need a different sourced weight.
            gg=min(select(g,t:==v))
            w=w+((t:<v):&(c:==2)) :* (gg:/g)
        }
        rr=w:*a:*exp(xb); den=sum(rr); if (den<=0) _error(9)
        zbar=sum(rr:*x)/den; ne=sum(((t:==v):&(c:==1)):*a)
        sr[selectindex((t:==v):&(c:==1))]=select(x,(t:==v):&(c:==1)):-zbar
        h=h+ne/den
        H[selectindex(t:>=v)]=J(sum(t:>=v),1,h)
        out[k+1,.]=(v,h)
    }
    out[rows(out),.]=(max(t)+1,h)
    st_store(.,"oracle_xb",xb); st_store(.,"oracle_H",H); st_store(.,"oracle_sch",sr)
    st_matrix("oracle_baseline",out)
}
real scalar _qafg_h(real scalar v)
{
    real matrix a
    a=st_matrix("oracle_baseline")
    return(max(select(a[.,2],a[.,1]:<=v)))
}
end
capture program drop _qafg_oracle
program define _qafg_oracle
    version 16.0
    args route
    local weights ""
    local fitopts ""
    if inlist("`route'","fweight","pweight") local weights "[`route'=w]"
    if "`route'"=="cluster" local fitopts "cluster(cl)"
    if "`route'"=="norobust" local fitopts "norobust"
    quietly stset t, failure(d) enter(time t0) id(id)
    quietly finegray x2 `weights', compete(cause) cause(1) nolog tolerance(1e-10) `fitopts'
    assert e(converged)==1 & !missing(_b[x2])
    matrix fitted=e(b)
    matrix before_replay=e(V)
    quietly finegray, noshr level(90)
    assert mreldif(fitted,e(b))==0 & mreldif(before_replay,e(V))==0
    generate double oracle_xb=.
    generate double oracle_H=.
    generate double oracle_sch=.
    local wt ""
    if inlist("`route'","fweight","pweight") local wt "`route'"
    mata: _qafg_direct("fitted","`wt'")
    quietly finegray_predict double gotxb, xb
    assert !missing(gotxb,oracle_xb) & abs(gotxb-oracle_xb)<1e-12
    quietly finegray_predict double gotH, basecshazard
    assert !missing(gotH,oracle_H) & abs(gotH-oracle_H)<1e-10
    quietly finegray_predict double gotcif, cif
    assert !missing(gotcif,oracle_H,oracle_xb) & abs(gotcif-(1-exp(-oracle_H*exp(oracle_xb))))<1e-10
    quietly finegray_predict double gotsch, schoenfeld
    assert missing(gotsch)==missing(oracle_sch)
    assert abs(gotsch-oracle_sch)<1e-10 if cause==1
    quietly correlate oracle_sch t if cause==1
    scalar want_rho=r(rho)
    scalar want_N=r(N)
    if "`weights'"!="" {
        qa_state_snapshot, tag(phweight) predict(xb)
        tempfile phlog
        log using "`phlog'.log", name(phrefusal) text replace
        * expect: REFUSED
        capture noisily finegray_phtest, time(identity)
        local rc=_rc
        log close phrefusal
        qa_state_compare, tag(phweight)
        mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("phlog")+".log")),"fit with "+st_local("wt")+"s"))))
        assert `rc'==198 & `named'==1
    }
    else {
    quietly finegray_phtest, time(identity)
    matrix gotph=r(phtest)
    assert rowsof(gotph)==1 & colsof(gotph)==2
    qa_assert_equal gotph[1,1] want_rho, property("direct raw residual/time correlation") tol(1e-10)
    qa_assert_equal gotph[1,2] want_N, property("cause-event diagnostic count")
    }
    quietly finegray_cif, at(x2=0) attime(0 1 2 3 4 5) nograph
    matrix gotc=r(table)
    assert rowsof(gotc)==6 & colsof(gotc)==5
    forvalues j=1/6 {
        scalar tv=gotc[`j',1]
        mata: st_numscalar("target_cif",1-exp(-_qafg_h(st_numscalar("tv"))))
        qa_assert_equal gotc[`j',2] target_cif, property("modified Breslow CIF including support endpoints") tol(1e-10)
    }
    // Independent score equation from the direct residuals. PW score uses
    // design weights and unweighted censoring KM (the documented contract).
    tempvar score_term
    generate double `score_term'=oracle_sch*cond("`wt'"=="",1,w) if cause==1
    quietly summarize `score_term', meanonly
    assert !missing(r(mean)) & abs(r(mean))<1e-8
    // Check an independent solver only after direct postestimation truth.
    // Native stcrreg requires stset weights and does not share the explicit
    // PW censoring-KM contract; do not label that unaligned fit a comparator.
    if "`route'"!="pweight" {
    preserve
    if "`route'"=="fweight" {
        expand w
        local weights ""
    }
    quietly count if cause==2
    if r(N)==0 {
        quietly stcox x2 `weights', nolog
    }
    else {
        quietly stset t, failure(cause==1)
        quietly stcrreg x2 `weights', compete(cause==2) nolog nrtolerance(1e-12) tolerance(1e-12)
    }
    assert !missing(_b[x2]) & abs(_b[x2]-fitted[1,1])<1e-6
    restore
    }
    display "DIRECT MATRIX b=" %12.8f fitted[1,1] " events=" want_N " rho=" %12.8f want_rho
end
local tests=0
local pass=0
local fail=0

local ++tests
capture noisily {
    qa_fx_a2_lifetable, clear tier(micro)
    _qafg_oracle
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(ties)
    assert !missing(r(perturb_n_ties)) & r(perturb_n_ties)>0
    _qafg_oracle
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(noevent)
    assert !missing(r(perturb_n_noevent)) & r(perturb_n_noevent)>0
    _qafg_oracle
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(absorb)
    assert !missing(r(perturb_n_absorb)) & r(perturb_n_absorb)>0
    _qafg_oracle
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(empty_stratum)
    assert !missing(r(perturb_n_empty_stratum)) & r(perturb_n_empty_stratum)>0
    _qafg_oracle
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(boundary_values)
    assert !missing(r(perturb_n_boundary_values)) & r(perturb_n_boundary_values)>0
    _qafg_oracle
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_pwexp, clear model(weibull) n(240) seed(541) perturb(late_entry)
    assert !missing(r(perturb_n_late_entry)) & r(perturb_n_late_entry)>0
    _qafg_oracle
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    qa_fx_a2_lifetable, clear tier(micro)
    _qafg_oracle
    matrix base=fitted
    * expect: INVARIANT
    qa_hostile_times
    local scale "`r(up)'"
    replace t=t*`scale'
    drop oracle_xb oracle_H oracle_sch gotxb gotH gotcif gotsch
    _qafg_oracle
    qa_assert_equal fitted[1,1] base[1,1], property("positive time scale leaves Fine-Gray slope unchanged") tol(1e-10)
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    qa_fx_a2_lifetable, clear tier(micro)
    replace w=1+mod(id,3)
    _qafg_oracle fweight
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(unsorted)
    replace w=1+mod(id,3)
    _qafg_oracle fweight
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    qa_fx_a2_lifetable, clear tier(micro)
    replace w=1+mod(id,3)
    _qafg_oracle pweight
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(unsorted)
    replace w=1+mod(id,3)
    _qafg_oracle pweight
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    qa_fx_a2_lifetable, clear tier(micro)
    replace w=1+mod(id,3)
    _qafg_oracle cluster
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(unsorted)
    replace w=1+mod(id,3)
    _qafg_oracle cluster
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    qa_fx_a2_lifetable, clear tier(micro)
    replace w=1+mod(id,3)
    _qafg_oracle norobust
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(unsorted)
    replace w=1+mod(id,3)
    _qafg_oracle norobust
}
if _rc local ++fail
else local ++pass

display "RESULT: validation_fixture_matrix tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
