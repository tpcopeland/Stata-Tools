*! validation_fixture_truth.do -- independently enumerated concordance and jackknife
version 16.0
clear all
set processors 1
set varabbrev off
capture log close _all
log using "validation_fixture_truth.log", text replace
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
quietly do "_qa_fx_a2.do"
quietly do "_qa_hostile.do"
quietly do "_qa_metamorphic.do"
capture mata: mata drop _qacs_pair_truth()
mata:
void _qacs_pair_truth(string scalar score, string scalar result)
{
    real colvector t,d,s,ci,ni,loo
    real matrix use,num,conc,ties
    real scalar n,den,c,se
    t=st_data(.,"_t"); d=st_data(.,"_d"); s=st_data(.,score); n=rows(t)
    // Orient every usable pair toward the earlier event; a same-time
    // event/censor pair is oriented toward its event. Dual events unusable.
    use=((t*J(1,n,1):<J(n,1,1)*t'):&(d*J(1,n,1):==1)) :|
        ((t*J(1,n,1):==J(n,1,1)*t'):&(d*J(1,n,1):==1):&(J(n,1,1)*d':==0))
    conc=use:*(s*J(1,n,1):>J(n,1,1)*s')
    ties=use:*(s*J(1,n,1):==J(n,1,1)*s')
    num=conc+.5*ties
    den=sum(use); c=sum(num)/den
    ci=rowsum(num)+colsum(num)'; ni=rowsum(use)+colsum(use)'
    // Delete each observation directly from pair totals, without refitting
    // the Cox model. This is the conditional pair-statistic jackknife.
    loo=(sum(num):-ci):/(den:-ni)
    if (any(den:-ni:<=0)) _error(9)
    se=sqrt((n-1)/n*sum((loo:-mean(loo)):^2))
    st_matrix(result,(c,se,den,sum(conc),sum(use)-sum(conc)-sum(ties),sum(ties)))
}
end
capture program drop _qacs_oracle
program define _qacs_oracle
    version 16.0
    args failure
    quietly stset t, failure(`failure') id(id)
    quietly stcox x2, nolog
    tempvar score
    tempname want
    generate double `score'=_b[x2]*x2
    mata: _qacs_pair_truth("`score'","`want'")
    quietly cstat_surv
    qa_assert_equal e(c) `want'[1,1], property("independent pair concordance") tol(1e-14)
    qa_assert_equal e(se) `want'[1,2], property("independent leave-one-out jackknife") tol(1e-14)
    qa_assert_equal e(N_comparable) `want'[1,3], property("exact usable pairs")
    qa_assert_equal e(N_concordant) `want'[1,4], property("exact concordant pairs")
    qa_assert_equal e(N_discordant) `want'[1,5], property("exact discordant pairs")
    qa_assert_equal e(N_tied) `want'[1,6], property("exact tied predictions")
    assert !missing(e(somers_d)) & abs(e(somers_d)-(2*`want'[1,1]-1))<1e-14
end

local tests=0
local pass=0
local fail=0
**# Population recovery precedes method parity
local ++tests
capture noisily {
    qa_fx_a2_pwexp, clear model(weibull) n(1200) seed(541)
    matrix truthb=r(truth_b_cs1)
    quietly stset t, failure(d) id(id)
    quietly stcox x1 x2, nolog
    foreach x in x1 x2 {
        scalar target=truthb[1,colnumb(truthb,"`x'")]
        assert !missing(target,_b[`x'],_se[`x']) & _se[`x']>0
        assert abs(_b[`x']-target)<4*_se[`x']
    }
    // Weibull cumulative hazard at admin time8 is (8/exp(mu))^1.5.
    // Two independent subjects in cells i,j yield a usable pair with
    // probability1-exp(-(lambda_i+lambda_j)*8^1.5); conditional first
    // event probability is lambda_i/(lambda_i+lambda_j). Enumerate cells.
    scalar denpop=0
    scalar numpop=0
    forvalues a=0/1 {
        forvalues x=0/1 {
            scalar li=exp(-1.5*(1+.4*`a'-.25*`x'))
            forvalues b=0/1 {
                forvalues z=0/1 {
                    scalar lj=exp(-1.5*(1+.4*`b'-.25*`z'))
                    scalar usable=1-exp(-(li+lj)*8^1.5)
                    scalar concord=cond(li==lj,.5,max(li,lj)/(li+lj))
                    scalar denpop=denpop+usable/16
                    scalar numpop=numpop+usable*concord/16
                }
            }
        }
    }
    scalar truthC=numpop/denpop
    // The analytic population C uses the true four-cell risk ordering.
    // Verify the fitted score preserves that ordering before using it.
    assert _b[x1]<0 & _b[x2]>0 & _b[x1]+_b[x2]<0
    quietly cstat_surv
    assert !missing(truthC,e(c),e(se)) & e(se)>0
    assert abs(e(c)-truthC)<4*e(se)
    display "RECOVERY C=" %12.8f e(c) " target=" %12.8f truthC " SE=" %12.8f e(se)
}
if _rc local ++fail
else local ++pass
**# Exact sample oracles for both all-cause and primary-cause routes
**## allcause: friendly
local ++tests
capture noisily {
    qa_fx_a2_lifetable, clear tier(micro)
    _qacs_oracle "d"
    scalar C_allcause=e(c)
    scalar SE_allcause=e(se)
    display "PAIR ORACLE allcause friendly: C=" %12.8f e(c) " pairs=" e(N_comparable)
}
if _rc local ++fail
else local ++pass

**## allcause: ties
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(ties)
    assert !missing(r(perturb_n_ties)) & r(perturb_n_ties)>0
    _qacs_oracle "d"
    display "PAIR ORACLE allcause ties: C=" %12.8f e(c) " pairs=" e(N_comparable)
}
if _rc local ++fail
else local ++pass

**## allcause: noevent
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(noevent)
    assert !missing(r(perturb_n_noevent)) & r(perturb_n_noevent)>0
    _qacs_oracle "d"
    display "PAIR ORACLE allcause noevent: C=" %12.8f e(c) " pairs=" e(N_comparable)
}
if _rc local ++fail
else local ++pass

**## allcause: absorb
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(absorb)
    assert !missing(r(perturb_n_absorb)) & r(perturb_n_absorb)>0
    _qacs_oracle "d"
    display "PAIR ORACLE allcause absorb: C=" %12.8f e(c) " pairs=" e(N_comparable)
}
if _rc local ++fail
else local ++pass

**## allcause: empty_stratum
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(empty_stratum)
    assert !missing(r(perturb_n_empty_stratum)) & r(perturb_n_empty_stratum)>0
    _qacs_oracle "d"
    display "PAIR ORACLE allcause empty_stratum: C=" %12.8f e(c) " pairs=" e(N_comparable)
}
if _rc local ++fail
else local ++pass

**## allcause: unsorted
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a2_lifetable, clear tier(micro) perturb(unsorted)
    assert !missing(r(perturb_n_unsorted)) & r(perturb_n_unsorted)>0
    _qacs_oracle "d"
    qa_assert_equal e(c) C_allcause, property("paired unsorted concordance")
    qa_assert_equal e(se) SE_allcause, property("paired unsorted jackknife") tol(1e-14)
    display "PAIR ORACLE allcause unsorted: C=" %12.8f e(c) " pairs=" e(N_comparable)
}
if _rc local ++fail
else local ++pass

**## allcause: codes_multidigit
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a2_lifetable, clear tier(micro) perturb(codes_multidigit)
    assert !missing(r(perturb_n_codes_multidigit)) & r(perturb_n_codes_multidigit)>0
    _qacs_oracle "d"
    qa_assert_equal e(c) C_allcause, property("paired codes_multidigit concordance")
    qa_assert_equal e(se) SE_allcause, property("paired codes_multidigit jackknife") tol(1e-14)
    display "PAIR ORACLE allcause codes_multidigit: C=" %12.8f e(c) " pairs=" e(N_comparable)
}
if _rc local ++fail
else local ++pass

**## primary: friendly
local ++tests
capture noisily {
    qa_fx_a2_lifetable, clear tier(micro)
    _qacs_oracle "cause==1"
    scalar C_primary=e(c)
    scalar SE_primary=e(se)
    display "PAIR ORACLE primary friendly: C=" %12.8f e(c) " pairs=" e(N_comparable)
}
if _rc local ++fail
else local ++pass

**## primary: ties
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(ties)
    assert !missing(r(perturb_n_ties)) & r(perturb_n_ties)>0
    _qacs_oracle "cause==1"
    display "PAIR ORACLE primary ties: C=" %12.8f e(c) " pairs=" e(N_comparable)
}
if _rc local ++fail
else local ++pass

**## primary: noevent
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(noevent)
    assert !missing(r(perturb_n_noevent)) & r(perturb_n_noevent)>0
    _qacs_oracle "cause==1"
    display "PAIR ORACLE primary noevent: C=" %12.8f e(c) " pairs=" e(N_comparable)
}
if _rc local ++fail
else local ++pass

**## primary: absorb
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(absorb)
    assert !missing(r(perturb_n_absorb)) & r(perturb_n_absorb)>0
    _qacs_oracle "cause==1"
    display "PAIR ORACLE primary absorb: C=" %12.8f e(c) " pairs=" e(N_comparable)
}
if _rc local ++fail
else local ++pass

**## primary: empty_stratum
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(empty_stratum)
    assert !missing(r(perturb_n_empty_stratum)) & r(perturb_n_empty_stratum)>0
    _qacs_oracle "cause==1"
    display "PAIR ORACLE primary empty_stratum: C=" %12.8f e(c) " pairs=" e(N_comparable)
}
if _rc local ++fail
else local ++pass

**## primary: unsorted
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a2_lifetable, clear tier(micro) perturb(unsorted)
    assert !missing(r(perturb_n_unsorted)) & r(perturb_n_unsorted)>0
    _qacs_oracle "cause==1"
    qa_assert_equal e(c) C_primary, property("paired unsorted concordance")
    qa_assert_equal e(se) SE_primary, property("paired unsorted jackknife") tol(1e-14)
    display "PAIR ORACLE primary unsorted: C=" %12.8f e(c) " pairs=" e(N_comparable)
}
if _rc local ++fail
else local ++pass

**## primary: codes_multidigit
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a2_lifetable, clear tier(micro) perturb(codes_multidigit)
    assert !missing(r(perturb_n_codes_multidigit)) & r(perturb_n_codes_multidigit)>0
    _qacs_oracle "cause==1"
    qa_assert_equal e(c) C_primary, property("paired codes_multidigit concordance")
    qa_assert_equal e(se) SE_primary, property("paired codes_multidigit jackknife") tol(1e-14)
    display "PAIR ORACLE primary codes_multidigit: C=" %12.8f e(c) " pairs=" e(N_comparable)
}
if _rc local ++fail
else local ++pass

**# Primitive time transport: a positive common scale preserves pair order
local ++tests
capture noisily {
    qa_fx_a2_lifetable, clear tier(micro)
    quietly stset t, failure(d) id(id)
    quietly stcox x2, nolog
    quietly cstat_surv
    matrix baseline=e(b)
    scalar basepairs=e(N_comparable)
    * expect: INVARIANT
    qa_hostile_times
    local scale "`r(up)'"
    replace t=t*`scale'
    quietly stset t, failure(d) id(id)
    quietly stcox x2, nolog
    quietly cstat_surv
    qa_assert_equal e(c) baseline[1,1], property("exact hostile-time rank invariance")
    qa_assert_equal e(N_comparable) basepairs, property("hostile-time comparable pairs")
}
if _rc local ++fail
else local ++pass
**# cilevel domain controls and interval arithmetic
local ++tests
capture noisily {
    qa_fx_a2_lifetable, clear tier(micro)
    quietly stset t, failure(d) id(id)
    * expect: REFUSED
    qa_option_domain, command(cstat_surv, level(@v@)) ///
        setup(stcox x2, nolog) check(assert !missing(e(c),e(se),e(ci_lo),e(ci_hi))) ///
        inside("10 99.99") outside("9.999999 99.990001")
    assert r(n_cells)==4 & r(n_violations)==0
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(boundary_values)
    // Native local-macro rounding at 99.99% changes an endpoint by 2e-14;
    // retain a relative 1e-13 interval tolerance and finite-value guards.
    foreach lev in 10 99.99 {
        quietly stset t, failure(d) id(id)
        quietly stcox x2, nolog
        quietly cstat_surv, level(`lev')
        scalar crit=invttail(e(N)-1,(100-`lev')/200)
        qa_assert_equal e(ci_lo) max(0,e(c)-crit*e(se)), property("lower cilevel boundary arithmetic") tol(1e-13)
        qa_assert_equal e(ci_hi) min(1,e(c)+crit*e(se)), property("upper cilevel boundary arithmetic") tol(1e-13)
    }
}
if _rc local ++fail
else local ++pass
display "RESULT: validation_fixture_truth tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
