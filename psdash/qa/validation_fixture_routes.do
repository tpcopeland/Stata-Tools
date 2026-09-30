*! validation_fixture_routes.do -- direct PS diagnostics on canonical consumed roles
* Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set varabbrev off
set more off
set graphics off
capture log close _all
log using "validation_fixture_routes.log", text replace
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
quietly do "_qa_fx_a1.do"
quietly do "_qa_hostile.do"
quietly do "_qa_state.do"
mata:
real matrix qa_ps_balance(real matrix X, real colvector A, real colvector W)
{
    real matrix B
    real colvector v,t,c,wt,wc,points
    real scalar j,h,mt,mc,vt,vc,mwt,mwc,vwt,vwc,sd,bin,lo,hi,ks,kws
    B=J(cols(X),10,.)
    for (j=1;j<=cols(X);j++) {
        v=select(X[.,j],X[.,j]:<.)
        if (!rows(v)) continue
        t=select(X[.,j],(A:==1):&(X[.,j]:<.))
        c=select(X[.,j],(A:==0):&(X[.,j]:<.))
        wt=select(W,(A:==1):&(X[.,j]:<.))
        wc=select(W,(A:==0):&(X[.,j]:<.))
        lo=min(v); hi=max(v); points=uniqrows(sort(v,1))
        bin=rows(points)==2
        mt=mean(t); mc=mean(c); vt=variance(t); vc=variance(c)
        mwt=sum(wt:*t)/sum(wt); mwc=sum(wc:*c)/sum(wc)
        vwt=sum(wt:*(t:-mwt):^2)/(sum(wt)-sum(wt:^2)/sum(wt))
        vwc=sum(wc:*(c:-mwc):^2)/(sum(wc)-sum(wc:^2)/sum(wc))
        if (bin) {
            vt=(mt-lo)*(hi-mt); vc=(mc-lo)*(hi-mc)
            vwt=(mwt-lo)*(hi-mwt); vwc=(mwc-lo)*(hi-mwc)
        }
        sd=sqrt((vt+vc)/2)
        B[j,1]=mt; B[j,2]=mc; B[j,6]=mwt; B[j,7]=mwc
        if (sd>0 & sd<.) {
            B[j,3]=(mt-mc)/sd; B[j,8]=(mwt-mwc)/sd
        }
        else if (mt==mc) {
            B[j,3]=0; B[j,8]=0
        }
        if (vc>0 & vc<.) B[j,4]=vt/vc
        if (vwc>0 & vwc<.) B[j,9]=vwt/vwc
        ks=0; kws=0
        for (h=1;h<=rows(points);h++) {
            ks=max((ks,abs(mean(t:<=points[h])-mean(c:<=points[h]))))
            kws=max((kws,abs(sum(wt:*(t:<=points[h]))/sum(wt)-sum(wc:*(c:<=points[h]))/sum(wc))))
        }
        B[j,5]=ks; B[j,10]=kws
    }
    return(B)
}
end
local tests=0
local pass=0
local fail=0
local ++tests
capture noisily {
    * Friendly positive control
    qa_fx_a1_logit, clear n(360) seed(541)
    matrix cells=r(truth_cells)
    local c2=cond(""=="codes_multidigit",11,2)
    local c3=cond(""=="codes_multidigit",111,3)
    generate double original_x1=mod(floor((id-1)/20),3)-1
    generate byte original_x2=mod(floor((id-1)/60),2)
    generate byte original_cat=ceil(id/120)
    if ""=="single_level" replace original_x2=0
    generate double ps=invlogit(-.4+.6*original_x1+.5*original_x2+.3*(original_cat==2)-.3*(original_cat==3))
    if ""=="near_positivity" replace ps=1-1e-4 if original_cat==3 & original_x2==1
    // Verify support-cell PS truth before any diagnostic command.
    forvalues j=1/`=rowsof(cells)' {
        assert abs(ps-cells[`j',4])<1e-14 if original_x1==cells[`j',1] & original_x2==cells[`j',2] & original_cat==cells[`j',3]
    }
    generate double wantw=w*(a/ps+(1-a)/(1-ps))
    generate byte included=1
    if ""=="base_absent" replace included=insample
    local sample "if included"
    local covs "x1 x2 i.xcat"
    local oraclecovs "x1 x2 fxcat2 fxcat3"
    generate double fxcat2=xcat==`c2'
    generate double fxcat3=xcat==`c3'
    if ""=="base_absent" local oraclecovs "x1 x2 fxcat3"
    if ""=="collinear" {
        local covs "x1 x2 i.xcat x3 x4"
        local oraclecovs "x1 x2 fxcat2 fxcat3 x3 x4"
    }
    generate double w2=wantw^2
    quietly summarize wantw `sample', meanonly
    scalar wantMean=r(mean)
    scalar sumw=r(sum)
    scalar wantN=r(N)
    quietly summarize w2 `sample', meanonly
    scalar wantESS=sumw^2/r(sum)
    forvalues arm=0/1 {
        quietly summarize wantw if included & a==`arm', meanonly
        scalar sw`arm'=r(sum)
        scalar n`arm'=r(N)
        quietly summarize w2 if included & a==`arm', meanonly
        scalar ess`arm'=sw`arm'^2/r(sum)
        quietly summarize ps if included & a==`arm', meanonly
        scalar mn`arm'=r(min)
        scalar mx`arm'=r(max)
        scalar mp`arm'=r(mean)
    }
    scalar lower=max(mn0,mn1)
    scalar upper=min(mx0,mx1)
    quietly count if included & (ps<lower | ps>upper)
    scalar outside=r(N)
    mata: st_matrix("wantBalance",qa_ps_balance(st_data(.,tokens("`oraclecovs'"),"included"),st_data(.,"a","included"),st_data(.,"wantw","included")))
    quietly psdash_weights a ps `sample', wvar(wantw)
    qa_assert_equal r(N) wantN, property("weights exact diagnostic population")
    qa_assert_equal r(ess) wantESS, property("direct supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(mean_wt) wantMean, property("direct supplied-weight mean") tol(1e-12)
    qa_assert_equal r(ess_treated) ess1, property("treated supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(ess_control) ess0, property("control supplied-weight ESS") tol(1e-12)
    quietly psdash weights a ps `sample', wvar(wantw)
    qa_assert_equal r(ess) wantESS, property("dispatcher exact ESS") tol(1e-12)
    quietly psdash_detect a ps `sample', covariates(`covs') wvar(wantw) estimand(ate)
    assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(psvar)'"=="ps" & "`r(wvar)'"=="wantw"
    assert r(psvar_auto)==0 & r(multigroup)==0 & r(longitudinal)==0
    assert r(n_covariates)==`: word count `covs'' & "`r(covariates)'"=="`covs'"
    quietly psdash_overlap a ps `sample', nograph
    qa_assert_equal r(N) wantN, property("overlap exact diagnostic population")
    qa_assert_equal r(mean_ps_treated) mp1, property("treated known-score mean") tol(1e-12)
    qa_assert_equal r(mean_ps_control) mp0, property("control known-score mean") tol(1e-12)
    qa_assert_equal r(overlap_lower) lower, property("observed support intersection lower") tol(1e-12)
    qa_assert_equal r(overlap_upper) upper, property("observed support intersection upper") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support membership count")
    quietly psdash_support a ps `sample', nograph
    qa_assert_equal r(lower_bound) lower, property("support lower intersection") tol(1e-12)
    qa_assert_equal r(upper_bound) upper, property("support upper intersection") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support outside exact count")
    quietly psdash_balance a ps `sample', covariates(`covs') wvar(wantw)
    matrix gotBalance=r(balance)
    assert rowsof(gotBalance)==rowsof(wantBalance) & colsof(gotBalance)==10
    forvalues j=1/`=rowsof(wantBalance)' {
        forvalues k=1/10 {
            if missing(wantBalance[`j',`k']) assert missing(gotBalance[`j',`k'])
            else {
                local tol=1e-10
                if ""=="scale_shift" & inlist(`k',3,8) local tol=1e-6
                qa_assert_equal gotBalance[`j',`k'] wantBalance[`j',`k'], property("direct moments weighted ECDF cell") tol(`tol')
            }
        }
    }
    if ""=="miss_subgroup" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x1" & r(n_cov_min)==300
    if ""=="miss_all_column" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x2" & r(n_cov_min)==0
    // Dashboard pipeline must retain exact manual roles and common sample.
    generate byte common=included & !missing(x1,x2,xcat)
    quietly count if common
    scalar commonN=r(N)
    if commonN==0 {
        qa_state_snapshot, tag(common_empty)
        tempfile namedlog
        log using "`namedlog'.log", text replace name(commonerror)
        capture noisily psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        local refusal_rc=_rc
        log close commonerror
        qa_state_compare, tag(common_empty)
        mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("namedlog")+".log")),"no observations"))))
        assert `refusal_rc'==2000 & `named'==1
    }
    else {
        quietly summarize wantw if common, meanonly
        scalar commonW=r(sum)
        quietly summarize w2 if common, meanonly
        scalar commonESS=commonW^2/r(sum)
        forvalues arm=0/1 {
            quietly summarize ps if common & a==`arm', meanonly
            scalar cmn`arm'=r(min)
            scalar cmx`arm'=r(max)
        }
        quietly count if common & (ps<max(cmn0,cmn1) | ps>min(cmx0,cmx1))
        scalar commonOutside=r(N)
        quietly psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        assert r(n_panels)==4 & r(N_requested)==wantN & r(N_analysis)==commonN & r(n_common_excluded)==wantN-commonN
        assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(wvar)'"=="wantw"
        qa_assert_equal r(ess) commonESS, property("dashboard exact complete-case weight ESS") tol(1e-12)
        qa_assert_equal r(n_outside) commonOutside, property("dashboard exact complete-case outside count")
    }
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_logit, clear n(360) seed(541) perturb(unsorted)
    assert "`r(perturb_applied)'"=="unsorted"
    matrix cells=r(truth_cells)
    local c2=cond("unsorted"=="codes_multidigit",11,2)
    local c3=cond("unsorted"=="codes_multidigit",111,3)
    generate double original_x1=mod(floor((id-1)/20),3)-1
    generate byte original_x2=mod(floor((id-1)/60),2)
    generate byte original_cat=ceil(id/120)
    if "unsorted"=="single_level" replace original_x2=0
    generate double ps=invlogit(-.4+.6*original_x1+.5*original_x2+.3*(original_cat==2)-.3*(original_cat==3))
    if "unsorted"=="near_positivity" replace ps=1-1e-4 if original_cat==3 & original_x2==1
    // Verify support-cell PS truth before any diagnostic command.
    forvalues j=1/`=rowsof(cells)' {
        assert abs(ps-cells[`j',4])<1e-14 if original_x1==cells[`j',1] & original_x2==cells[`j',2] & original_cat==cells[`j',3]
    }
    generate double wantw=w*(a/ps+(1-a)/(1-ps))
    generate byte included=1
    if "unsorted"=="base_absent" replace included=insample
    local sample "if included"
    local covs "x1 x2 i.xcat"
    local oraclecovs "x1 x2 fxcat2 fxcat3"
    generate double fxcat2=xcat==`c2'
    generate double fxcat3=xcat==`c3'
    if "unsorted"=="base_absent" local oraclecovs "x1 x2 fxcat3"
    if "unsorted"=="collinear" {
        local covs "x1 x2 i.xcat x3 x4"
        local oraclecovs "x1 x2 fxcat2 fxcat3 x3 x4"
    }
    generate double w2=wantw^2
    quietly summarize wantw `sample', meanonly
    scalar wantMean=r(mean)
    scalar sumw=r(sum)
    scalar wantN=r(N)
    quietly summarize w2 `sample', meanonly
    scalar wantESS=sumw^2/r(sum)
    forvalues arm=0/1 {
        quietly summarize wantw if included & a==`arm', meanonly
        scalar sw`arm'=r(sum)
        scalar n`arm'=r(N)
        quietly summarize w2 if included & a==`arm', meanonly
        scalar ess`arm'=sw`arm'^2/r(sum)
        quietly summarize ps if included & a==`arm', meanonly
        scalar mn`arm'=r(min)
        scalar mx`arm'=r(max)
        scalar mp`arm'=r(mean)
    }
    scalar lower=max(mn0,mn1)
    scalar upper=min(mx0,mx1)
    quietly count if included & (ps<lower | ps>upper)
    scalar outside=r(N)
    mata: st_matrix("wantBalance",qa_ps_balance(st_data(.,tokens("`oraclecovs'"),"included"),st_data(.,"a","included"),st_data(.,"wantw","included")))
    quietly psdash_weights a ps `sample', wvar(wantw)
    qa_assert_equal r(N) wantN, property("weights exact diagnostic population")
    qa_assert_equal r(ess) wantESS, property("direct supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(mean_wt) wantMean, property("direct supplied-weight mean") tol(1e-12)
    qa_assert_equal r(ess_treated) ess1, property("treated supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(ess_control) ess0, property("control supplied-weight ESS") tol(1e-12)
    quietly psdash weights a ps `sample', wvar(wantw)
    qa_assert_equal r(ess) wantESS, property("dispatcher exact ESS") tol(1e-12)
    quietly psdash_detect a ps `sample', covariates(`covs') wvar(wantw) estimand(ate)
    assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(psvar)'"=="ps" & "`r(wvar)'"=="wantw"
    assert r(psvar_auto)==0 & r(multigroup)==0 & r(longitudinal)==0
    assert r(n_covariates)==`: word count `covs'' & "`r(covariates)'"=="`covs'"
    quietly psdash_overlap a ps `sample', nograph
    qa_assert_equal r(N) wantN, property("overlap exact diagnostic population")
    qa_assert_equal r(mean_ps_treated) mp1, property("treated known-score mean") tol(1e-12)
    qa_assert_equal r(mean_ps_control) mp0, property("control known-score mean") tol(1e-12)
    qa_assert_equal r(overlap_lower) lower, property("observed support intersection lower") tol(1e-12)
    qa_assert_equal r(overlap_upper) upper, property("observed support intersection upper") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support membership count")
    quietly psdash_support a ps `sample', nograph
    qa_assert_equal r(lower_bound) lower, property("support lower intersection") tol(1e-12)
    qa_assert_equal r(upper_bound) upper, property("support upper intersection") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support outside exact count")
    quietly psdash_balance a ps `sample', covariates(`covs') wvar(wantw)
    matrix gotBalance=r(balance)
    assert rowsof(gotBalance)==rowsof(wantBalance) & colsof(gotBalance)==10
    forvalues j=1/`=rowsof(wantBalance)' {
        forvalues k=1/10 {
            if missing(wantBalance[`j',`k']) assert missing(gotBalance[`j',`k'])
            else {
                local tol=1e-10
                if "unsorted"=="scale_shift" & inlist(`k',3,8) local tol=1e-6
                qa_assert_equal gotBalance[`j',`k'] wantBalance[`j',`k'], property("direct moments weighted ECDF cell") tol(`tol')
            }
        }
    }
    if "unsorted"=="miss_subgroup" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x1" & r(n_cov_min)==300
    if "unsorted"=="miss_all_column" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x2" & r(n_cov_min)==0
    // Dashboard pipeline must retain exact manual roles and common sample.
    generate byte common=included & !missing(x1,x2,xcat)
    quietly count if common
    scalar commonN=r(N)
    if commonN==0 {
        qa_state_snapshot, tag(common_empty)
        tempfile namedlog
        log using "`namedlog'.log", text replace name(commonerror)
        capture noisily psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        local refusal_rc=_rc
        log close commonerror
        qa_state_compare, tag(common_empty)
        mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("namedlog")+".log")),"no observations"))))
        assert `refusal_rc'==2000 & `named'==1
    }
    else {
        quietly summarize wantw if common, meanonly
        scalar commonW=r(sum)
        quietly summarize w2 if common, meanonly
        scalar commonESS=commonW^2/r(sum)
        forvalues arm=0/1 {
            quietly summarize ps if common & a==`arm', meanonly
            scalar cmn`arm'=r(min)
            scalar cmx`arm'=r(max)
        }
        quietly count if common & (ps<max(cmn0,cmn1) | ps>min(cmx0,cmx1))
        scalar commonOutside=r(N)
        quietly psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        assert r(n_panels)==4 & r(N_requested)==wantN & r(N_analysis)==commonN & r(n_common_excluded)==wantN-commonN
        assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(wvar)'"=="wantw"
        qa_assert_equal r(ess) commonESS, property("dashboard exact complete-case weight ESS") tol(1e-12)
        qa_assert_equal r(n_outside) commonOutside, property("dashboard exact complete-case outside count")
    }
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_logit, clear n(360) seed(541) perturb(collinear)
    assert "`r(perturb_applied)'"=="collinear"
    matrix cells=r(truth_cells)
    local c2=cond("collinear"=="codes_multidigit",11,2)
    local c3=cond("collinear"=="codes_multidigit",111,3)
    generate double original_x1=mod(floor((id-1)/20),3)-1
    generate byte original_x2=mod(floor((id-1)/60),2)
    generate byte original_cat=ceil(id/120)
    if "collinear"=="single_level" replace original_x2=0
    generate double ps=invlogit(-.4+.6*original_x1+.5*original_x2+.3*(original_cat==2)-.3*(original_cat==3))
    if "collinear"=="near_positivity" replace ps=1-1e-4 if original_cat==3 & original_x2==1
    // Verify support-cell PS truth before any diagnostic command.
    forvalues j=1/`=rowsof(cells)' {
        assert abs(ps-cells[`j',4])<1e-14 if original_x1==cells[`j',1] & original_x2==cells[`j',2] & original_cat==cells[`j',3]
    }
    generate double wantw=w*(a/ps+(1-a)/(1-ps))
    generate byte included=1
    if "collinear"=="base_absent" replace included=insample
    local sample "if included"
    local covs "x1 x2 i.xcat"
    local oraclecovs "x1 x2 fxcat2 fxcat3"
    generate double fxcat2=xcat==`c2'
    generate double fxcat3=xcat==`c3'
    if "collinear"=="base_absent" local oraclecovs "x1 x2 fxcat3"
    if "collinear"=="collinear" {
        local covs "x1 x2 i.xcat x3 x4"
        local oraclecovs "x1 x2 fxcat2 fxcat3 x3 x4"
    }
    generate double w2=wantw^2
    quietly summarize wantw `sample', meanonly
    scalar wantMean=r(mean)
    scalar sumw=r(sum)
    scalar wantN=r(N)
    quietly summarize w2 `sample', meanonly
    scalar wantESS=sumw^2/r(sum)
    forvalues arm=0/1 {
        quietly summarize wantw if included & a==`arm', meanonly
        scalar sw`arm'=r(sum)
        scalar n`arm'=r(N)
        quietly summarize w2 if included & a==`arm', meanonly
        scalar ess`arm'=sw`arm'^2/r(sum)
        quietly summarize ps if included & a==`arm', meanonly
        scalar mn`arm'=r(min)
        scalar mx`arm'=r(max)
        scalar mp`arm'=r(mean)
    }
    scalar lower=max(mn0,mn1)
    scalar upper=min(mx0,mx1)
    quietly count if included & (ps<lower | ps>upper)
    scalar outside=r(N)
    mata: st_matrix("wantBalance",qa_ps_balance(st_data(.,tokens("`oraclecovs'"),"included"),st_data(.,"a","included"),st_data(.,"wantw","included")))
    quietly psdash_weights a ps `sample', wvar(wantw)
    qa_assert_equal r(N) wantN, property("weights exact diagnostic population")
    qa_assert_equal r(ess) wantESS, property("direct supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(mean_wt) wantMean, property("direct supplied-weight mean") tol(1e-12)
    qa_assert_equal r(ess_treated) ess1, property("treated supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(ess_control) ess0, property("control supplied-weight ESS") tol(1e-12)
    quietly psdash weights a ps `sample', wvar(wantw)
    qa_assert_equal r(ess) wantESS, property("dispatcher exact ESS") tol(1e-12)
    quietly psdash_detect a ps `sample', covariates(`covs') wvar(wantw) estimand(ate)
    assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(psvar)'"=="ps" & "`r(wvar)'"=="wantw"
    assert r(psvar_auto)==0 & r(multigroup)==0 & r(longitudinal)==0
    assert r(n_covariates)==`: word count `covs'' & "`r(covariates)'"=="`covs'"
    quietly psdash_overlap a ps `sample', nograph
    qa_assert_equal r(N) wantN, property("overlap exact diagnostic population")
    qa_assert_equal r(mean_ps_treated) mp1, property("treated known-score mean") tol(1e-12)
    qa_assert_equal r(mean_ps_control) mp0, property("control known-score mean") tol(1e-12)
    qa_assert_equal r(overlap_lower) lower, property("observed support intersection lower") tol(1e-12)
    qa_assert_equal r(overlap_upper) upper, property("observed support intersection upper") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support membership count")
    quietly psdash_support a ps `sample', nograph
    qa_assert_equal r(lower_bound) lower, property("support lower intersection") tol(1e-12)
    qa_assert_equal r(upper_bound) upper, property("support upper intersection") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support outside exact count")
    quietly psdash_balance a ps `sample', covariates(`covs') wvar(wantw)
    matrix gotBalance=r(balance)
    assert rowsof(gotBalance)==rowsof(wantBalance) & colsof(gotBalance)==10
    forvalues j=1/`=rowsof(wantBalance)' {
        forvalues k=1/10 {
            if missing(wantBalance[`j',`k']) assert missing(gotBalance[`j',`k'])
            else {
                local tol=1e-10
                if "collinear"=="scale_shift" & inlist(`k',3,8) local tol=1e-6
                qa_assert_equal gotBalance[`j',`k'] wantBalance[`j',`k'], property("direct moments weighted ECDF cell") tol(`tol')
            }
        }
    }
    if "collinear"=="miss_subgroup" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x1" & r(n_cov_min)==300
    if "collinear"=="miss_all_column" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x2" & r(n_cov_min)==0
    // Dashboard pipeline must retain exact manual roles and common sample.
    generate byte common=included & !missing(x1,x2,xcat)
    quietly count if common
    scalar commonN=r(N)
    if commonN==0 {
        qa_state_snapshot, tag(common_empty)
        tempfile namedlog
        log using "`namedlog'.log", text replace name(commonerror)
        capture noisily psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        local refusal_rc=_rc
        log close commonerror
        qa_state_compare, tag(common_empty)
        mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("namedlog")+".log")),"no observations"))))
        assert `refusal_rc'==2000 & `named'==1
    }
    else {
        quietly summarize wantw if common, meanonly
        scalar commonW=r(sum)
        quietly summarize w2 if common, meanonly
        scalar commonESS=commonW^2/r(sum)
        forvalues arm=0/1 {
            quietly summarize ps if common & a==`arm', meanonly
            scalar cmn`arm'=r(min)
            scalar cmx`arm'=r(max)
        }
        quietly count if common & (ps<max(cmn0,cmn1) | ps>min(cmx0,cmx1))
        scalar commonOutside=r(N)
        quietly psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        assert r(n_panels)==4 & r(N_requested)==wantN & r(N_analysis)==commonN & r(n_common_excluded)==wantN-commonN
        assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(wvar)'"=="wantw"
        qa_assert_equal r(ess) commonESS, property("dashboard exact complete-case weight ESS") tol(1e-12)
        qa_assert_equal r(n_outside) commonOutside, property("dashboard exact complete-case outside count")
    }
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_logit, clear n(360) seed(541) perturb(single_level)
    assert "`r(perturb_applied)'"=="single_level"
    matrix cells=r(truth_cells)
    local c2=cond("single_level"=="codes_multidigit",11,2)
    local c3=cond("single_level"=="codes_multidigit",111,3)
    generate double original_x1=mod(floor((id-1)/20),3)-1
    generate byte original_x2=mod(floor((id-1)/60),2)
    generate byte original_cat=ceil(id/120)
    if "single_level"=="single_level" replace original_x2=0
    generate double ps=invlogit(-.4+.6*original_x1+.5*original_x2+.3*(original_cat==2)-.3*(original_cat==3))
    if "single_level"=="near_positivity" replace ps=1-1e-4 if original_cat==3 & original_x2==1
    // Verify support-cell PS truth before any diagnostic command.
    forvalues j=1/`=rowsof(cells)' {
        assert abs(ps-cells[`j',4])<1e-14 if original_x1==cells[`j',1] & original_x2==cells[`j',2] & original_cat==cells[`j',3]
    }
    generate double wantw=w*(a/ps+(1-a)/(1-ps))
    generate byte included=1
    if "single_level"=="base_absent" replace included=insample
    local sample "if included"
    local covs "x1 x2 i.xcat"
    local oraclecovs "x1 x2 fxcat2 fxcat3"
    generate double fxcat2=xcat==`c2'
    generate double fxcat3=xcat==`c3'
    if "single_level"=="base_absent" local oraclecovs "x1 x2 fxcat3"
    if "single_level"=="collinear" {
        local covs "x1 x2 i.xcat x3 x4"
        local oraclecovs "x1 x2 fxcat2 fxcat3 x3 x4"
    }
    generate double w2=wantw^2
    quietly summarize wantw `sample', meanonly
    scalar wantMean=r(mean)
    scalar sumw=r(sum)
    scalar wantN=r(N)
    quietly summarize w2 `sample', meanonly
    scalar wantESS=sumw^2/r(sum)
    forvalues arm=0/1 {
        quietly summarize wantw if included & a==`arm', meanonly
        scalar sw`arm'=r(sum)
        scalar n`arm'=r(N)
        quietly summarize w2 if included & a==`arm', meanonly
        scalar ess`arm'=sw`arm'^2/r(sum)
        quietly summarize ps if included & a==`arm', meanonly
        scalar mn`arm'=r(min)
        scalar mx`arm'=r(max)
        scalar mp`arm'=r(mean)
    }
    scalar lower=max(mn0,mn1)
    scalar upper=min(mx0,mx1)
    quietly count if included & (ps<lower | ps>upper)
    scalar outside=r(N)
    mata: st_matrix("wantBalance",qa_ps_balance(st_data(.,tokens("`oraclecovs'"),"included"),st_data(.,"a","included"),st_data(.,"wantw","included")))
    quietly psdash_weights a ps `sample', wvar(wantw)
    qa_assert_equal r(N) wantN, property("weights exact diagnostic population")
    qa_assert_equal r(ess) wantESS, property("direct supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(mean_wt) wantMean, property("direct supplied-weight mean") tol(1e-12)
    qa_assert_equal r(ess_treated) ess1, property("treated supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(ess_control) ess0, property("control supplied-weight ESS") tol(1e-12)
    quietly psdash weights a ps `sample', wvar(wantw)
    qa_assert_equal r(ess) wantESS, property("dispatcher exact ESS") tol(1e-12)
    quietly psdash_detect a ps `sample', covariates(`covs') wvar(wantw) estimand(ate)
    assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(psvar)'"=="ps" & "`r(wvar)'"=="wantw"
    assert r(psvar_auto)==0 & r(multigroup)==0 & r(longitudinal)==0
    assert r(n_covariates)==`: word count `covs'' & "`r(covariates)'"=="`covs'"
    quietly psdash_overlap a ps `sample', nograph
    qa_assert_equal r(N) wantN, property("overlap exact diagnostic population")
    qa_assert_equal r(mean_ps_treated) mp1, property("treated known-score mean") tol(1e-12)
    qa_assert_equal r(mean_ps_control) mp0, property("control known-score mean") tol(1e-12)
    qa_assert_equal r(overlap_lower) lower, property("observed support intersection lower") tol(1e-12)
    qa_assert_equal r(overlap_upper) upper, property("observed support intersection upper") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support membership count")
    quietly psdash_support a ps `sample', nograph
    qa_assert_equal r(lower_bound) lower, property("support lower intersection") tol(1e-12)
    qa_assert_equal r(upper_bound) upper, property("support upper intersection") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support outside exact count")
    quietly psdash_balance a ps `sample', covariates(`covs') wvar(wantw)
    matrix gotBalance=r(balance)
    assert rowsof(gotBalance)==rowsof(wantBalance) & colsof(gotBalance)==10
    forvalues j=1/`=rowsof(wantBalance)' {
        forvalues k=1/10 {
            if missing(wantBalance[`j',`k']) assert missing(gotBalance[`j',`k'])
            else {
                local tol=1e-10
                if "single_level"=="scale_shift" & inlist(`k',3,8) local tol=1e-6
                qa_assert_equal gotBalance[`j',`k'] wantBalance[`j',`k'], property("direct moments weighted ECDF cell") tol(`tol')
            }
        }
    }
    if "single_level"=="miss_subgroup" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x1" & r(n_cov_min)==300
    if "single_level"=="miss_all_column" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x2" & r(n_cov_min)==0
    // Dashboard pipeline must retain exact manual roles and common sample.
    generate byte common=included & !missing(x1,x2,xcat)
    quietly count if common
    scalar commonN=r(N)
    if commonN==0 {
        qa_state_snapshot, tag(common_empty)
        tempfile namedlog
        log using "`namedlog'.log", text replace name(commonerror)
        capture noisily psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        local refusal_rc=_rc
        log close commonerror
        qa_state_compare, tag(common_empty)
        mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("namedlog")+".log")),"no observations"))))
        assert `refusal_rc'==2000 & `named'==1
    }
    else {
        quietly summarize wantw if common, meanonly
        scalar commonW=r(sum)
        quietly summarize w2 if common, meanonly
        scalar commonESS=commonW^2/r(sum)
        forvalues arm=0/1 {
            quietly summarize ps if common & a==`arm', meanonly
            scalar cmn`arm'=r(min)
            scalar cmx`arm'=r(max)
        }
        quietly count if common & (ps<max(cmn0,cmn1) | ps>min(cmx0,cmx1))
        scalar commonOutside=r(N)
        quietly psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        assert r(n_panels)==4 & r(N_requested)==wantN & r(N_analysis)==commonN & r(n_common_excluded)==wantN-commonN
        assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(wvar)'"=="wantw"
        qa_assert_equal r(ess) commonESS, property("dashboard exact complete-case weight ESS") tol(1e-12)
        qa_assert_equal r(n_outside) commonOutside, property("dashboard exact complete-case outside count")
    }
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_logit, clear n(360) seed(541) perturb(base_absent)
    assert "`r(perturb_applied)'"=="base_absent"
    matrix cells=r(truth_cells)
    local c2=cond("base_absent"=="codes_multidigit",11,2)
    local c3=cond("base_absent"=="codes_multidigit",111,3)
    generate double original_x1=mod(floor((id-1)/20),3)-1
    generate byte original_x2=mod(floor((id-1)/60),2)
    generate byte original_cat=ceil(id/120)
    if "base_absent"=="single_level" replace original_x2=0
    generate double ps=invlogit(-.4+.6*original_x1+.5*original_x2+.3*(original_cat==2)-.3*(original_cat==3))
    if "base_absent"=="near_positivity" replace ps=1-1e-4 if original_cat==3 & original_x2==1
    // Verify support-cell PS truth before any diagnostic command.
    forvalues j=1/`=rowsof(cells)' {
        assert abs(ps-cells[`j',4])<1e-14 if original_x1==cells[`j',1] & original_x2==cells[`j',2] & original_cat==cells[`j',3]
    }
    generate double wantw=w*(a/ps+(1-a)/(1-ps))
    generate byte included=1
    if "base_absent"=="base_absent" replace included=insample
    local sample "if included"
    local covs "x1 x2 i.xcat"
    local oraclecovs "x1 x2 fxcat2 fxcat3"
    generate double fxcat2=xcat==`c2'
    generate double fxcat3=xcat==`c3'
    if "base_absent"=="base_absent" local oraclecovs "x1 x2 fxcat3"
    if "base_absent"=="collinear" {
        local covs "x1 x2 i.xcat x3 x4"
        local oraclecovs "x1 x2 fxcat2 fxcat3 x3 x4"
    }
    generate double w2=wantw^2
    quietly summarize wantw `sample', meanonly
    scalar wantMean=r(mean)
    scalar sumw=r(sum)
    scalar wantN=r(N)
    quietly summarize w2 `sample', meanonly
    scalar wantESS=sumw^2/r(sum)
    forvalues arm=0/1 {
        quietly summarize wantw if included & a==`arm', meanonly
        scalar sw`arm'=r(sum)
        scalar n`arm'=r(N)
        quietly summarize w2 if included & a==`arm', meanonly
        scalar ess`arm'=sw`arm'^2/r(sum)
        quietly summarize ps if included & a==`arm', meanonly
        scalar mn`arm'=r(min)
        scalar mx`arm'=r(max)
        scalar mp`arm'=r(mean)
    }
    scalar lower=max(mn0,mn1)
    scalar upper=min(mx0,mx1)
    quietly count if included & (ps<lower | ps>upper)
    scalar outside=r(N)
    mata: st_matrix("wantBalance",qa_ps_balance(st_data(.,tokens("`oraclecovs'"),"included"),st_data(.,"a","included"),st_data(.,"wantw","included")))
    quietly psdash_weights a ps `sample', wvar(wantw)
    qa_assert_equal r(N) wantN, property("weights exact diagnostic population")
    qa_assert_equal r(ess) wantESS, property("direct supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(mean_wt) wantMean, property("direct supplied-weight mean") tol(1e-12)
    qa_assert_equal r(ess_treated) ess1, property("treated supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(ess_control) ess0, property("control supplied-weight ESS") tol(1e-12)
    quietly psdash weights a ps `sample', wvar(wantw)
    qa_assert_equal r(ess) wantESS, property("dispatcher exact ESS") tol(1e-12)
    quietly psdash_detect a ps `sample', covariates(`covs') wvar(wantw) estimand(ate)
    assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(psvar)'"=="ps" & "`r(wvar)'"=="wantw"
    assert r(psvar_auto)==0 & r(multigroup)==0 & r(longitudinal)==0
    assert r(n_covariates)==`: word count `covs'' & "`r(covariates)'"=="`covs'"
    quietly psdash_overlap a ps `sample', nograph
    qa_assert_equal r(N) wantN, property("overlap exact diagnostic population")
    qa_assert_equal r(mean_ps_treated) mp1, property("treated known-score mean") tol(1e-12)
    qa_assert_equal r(mean_ps_control) mp0, property("control known-score mean") tol(1e-12)
    qa_assert_equal r(overlap_lower) lower, property("observed support intersection lower") tol(1e-12)
    qa_assert_equal r(overlap_upper) upper, property("observed support intersection upper") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support membership count")
    quietly psdash_support a ps `sample', nograph
    qa_assert_equal r(lower_bound) lower, property("support lower intersection") tol(1e-12)
    qa_assert_equal r(upper_bound) upper, property("support upper intersection") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support outside exact count")
    quietly psdash_balance a ps `sample', covariates(`covs') wvar(wantw)
    matrix gotBalance=r(balance)
    assert rowsof(gotBalance)==rowsof(wantBalance) & colsof(gotBalance)==10
    forvalues j=1/`=rowsof(wantBalance)' {
        forvalues k=1/10 {
            if missing(wantBalance[`j',`k']) assert missing(gotBalance[`j',`k'])
            else {
                local tol=1e-10
                if "base_absent"=="scale_shift" & inlist(`k',3,8) local tol=1e-6
                qa_assert_equal gotBalance[`j',`k'] wantBalance[`j',`k'], property("direct moments weighted ECDF cell") tol(`tol')
            }
        }
    }
    if "base_absent"=="miss_subgroup" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x1" & r(n_cov_min)==300
    if "base_absent"=="miss_all_column" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x2" & r(n_cov_min)==0
    // Dashboard pipeline must retain exact manual roles and common sample.
    generate byte common=included & !missing(x1,x2,xcat)
    quietly count if common
    scalar commonN=r(N)
    if commonN==0 {
        qa_state_snapshot, tag(common_empty)
        tempfile namedlog
        log using "`namedlog'.log", text replace name(commonerror)
        capture noisily psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        local refusal_rc=_rc
        log close commonerror
        qa_state_compare, tag(common_empty)
        mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("namedlog")+".log")),"no observations"))))
        assert `refusal_rc'==2000 & `named'==1
    }
    else {
        quietly summarize wantw if common, meanonly
        scalar commonW=r(sum)
        quietly summarize w2 if common, meanonly
        scalar commonESS=commonW^2/r(sum)
        forvalues arm=0/1 {
            quietly summarize ps if common & a==`arm', meanonly
            scalar cmn`arm'=r(min)
            scalar cmx`arm'=r(max)
        }
        quietly count if common & (ps<max(cmn0,cmn1) | ps>min(cmx0,cmx1))
        scalar commonOutside=r(N)
        quietly psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        assert r(n_panels)==4 & r(N_requested)==wantN & r(N_analysis)==commonN & r(n_common_excluded)==wantN-commonN
        assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(wvar)'"=="wantw"
        qa_assert_equal r(ess) commonESS, property("dashboard exact complete-case weight ESS") tol(1e-12)
        qa_assert_equal r(n_outside) commonOutside, property("dashboard exact complete-case outside count")
    }
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_logit, clear n(360) seed(541) perturb(codes_multidigit)
    assert "`r(perturb_applied)'"=="codes_multidigit"
    matrix cells=r(truth_cells)
    local c2=cond("codes_multidigit"=="codes_multidigit",11,2)
    local c3=cond("codes_multidigit"=="codes_multidigit",111,3)
    generate double original_x1=mod(floor((id-1)/20),3)-1
    generate byte original_x2=mod(floor((id-1)/60),2)
    generate byte original_cat=ceil(id/120)
    if "codes_multidigit"=="single_level" replace original_x2=0
    generate double ps=invlogit(-.4+.6*original_x1+.5*original_x2+.3*(original_cat==2)-.3*(original_cat==3))
    if "codes_multidigit"=="near_positivity" replace ps=1-1e-4 if original_cat==3 & original_x2==1
    // Verify support-cell PS truth before any diagnostic command.
    forvalues j=1/`=rowsof(cells)' {
        assert abs(ps-cells[`j',4])<1e-14 if original_x1==cells[`j',1] & original_x2==cells[`j',2] & original_cat==cells[`j',3]
    }
    generate double wantw=w*(a/ps+(1-a)/(1-ps))
    generate byte included=1
    if "codes_multidigit"=="base_absent" replace included=insample
    local sample "if included"
    local covs "x1 x2 i.xcat"
    local oraclecovs "x1 x2 fxcat2 fxcat3"
    generate double fxcat2=xcat==`c2'
    generate double fxcat3=xcat==`c3'
    if "codes_multidigit"=="base_absent" local oraclecovs "x1 x2 fxcat3"
    if "codes_multidigit"=="collinear" {
        local covs "x1 x2 i.xcat x3 x4"
        local oraclecovs "x1 x2 fxcat2 fxcat3 x3 x4"
    }
    generate double w2=wantw^2
    quietly summarize wantw `sample', meanonly
    scalar wantMean=r(mean)
    scalar sumw=r(sum)
    scalar wantN=r(N)
    quietly summarize w2 `sample', meanonly
    scalar wantESS=sumw^2/r(sum)
    forvalues arm=0/1 {
        quietly summarize wantw if included & a==`arm', meanonly
        scalar sw`arm'=r(sum)
        scalar n`arm'=r(N)
        quietly summarize w2 if included & a==`arm', meanonly
        scalar ess`arm'=sw`arm'^2/r(sum)
        quietly summarize ps if included & a==`arm', meanonly
        scalar mn`arm'=r(min)
        scalar mx`arm'=r(max)
        scalar mp`arm'=r(mean)
    }
    scalar lower=max(mn0,mn1)
    scalar upper=min(mx0,mx1)
    quietly count if included & (ps<lower | ps>upper)
    scalar outside=r(N)
    mata: st_matrix("wantBalance",qa_ps_balance(st_data(.,tokens("`oraclecovs'"),"included"),st_data(.,"a","included"),st_data(.,"wantw","included")))
    quietly psdash_weights a ps `sample', wvar(wantw)
    qa_assert_equal r(N) wantN, property("weights exact diagnostic population")
    qa_assert_equal r(ess) wantESS, property("direct supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(mean_wt) wantMean, property("direct supplied-weight mean") tol(1e-12)
    qa_assert_equal r(ess_treated) ess1, property("treated supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(ess_control) ess0, property("control supplied-weight ESS") tol(1e-12)
    quietly psdash weights a ps `sample', wvar(wantw)
    qa_assert_equal r(ess) wantESS, property("dispatcher exact ESS") tol(1e-12)
    quietly psdash_detect a ps `sample', covariates(`covs') wvar(wantw) estimand(ate)
    assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(psvar)'"=="ps" & "`r(wvar)'"=="wantw"
    assert r(psvar_auto)==0 & r(multigroup)==0 & r(longitudinal)==0
    assert r(n_covariates)==`: word count `covs'' & "`r(covariates)'"=="`covs'"
    quietly psdash_overlap a ps `sample', nograph
    qa_assert_equal r(N) wantN, property("overlap exact diagnostic population")
    qa_assert_equal r(mean_ps_treated) mp1, property("treated known-score mean") tol(1e-12)
    qa_assert_equal r(mean_ps_control) mp0, property("control known-score mean") tol(1e-12)
    qa_assert_equal r(overlap_lower) lower, property("observed support intersection lower") tol(1e-12)
    qa_assert_equal r(overlap_upper) upper, property("observed support intersection upper") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support membership count")
    quietly psdash_support a ps `sample', nograph
    qa_assert_equal r(lower_bound) lower, property("support lower intersection") tol(1e-12)
    qa_assert_equal r(upper_bound) upper, property("support upper intersection") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support outside exact count")
    quietly psdash_balance a ps `sample', covariates(`covs') wvar(wantw)
    matrix gotBalance=r(balance)
    assert rowsof(gotBalance)==rowsof(wantBalance) & colsof(gotBalance)==10
    forvalues j=1/`=rowsof(wantBalance)' {
        forvalues k=1/10 {
            if missing(wantBalance[`j',`k']) assert missing(gotBalance[`j',`k'])
            else {
                local tol=1e-10
                if "codes_multidigit"=="scale_shift" & inlist(`k',3,8) local tol=1e-6
                qa_assert_equal gotBalance[`j',`k'] wantBalance[`j',`k'], property("direct moments weighted ECDF cell") tol(`tol')
            }
        }
    }
    if "codes_multidigit"=="miss_subgroup" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x1" & r(n_cov_min)==300
    if "codes_multidigit"=="miss_all_column" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x2" & r(n_cov_min)==0
    // Dashboard pipeline must retain exact manual roles and common sample.
    generate byte common=included & !missing(x1,x2,xcat)
    quietly count if common
    scalar commonN=r(N)
    if commonN==0 {
        qa_state_snapshot, tag(common_empty)
        tempfile namedlog
        log using "`namedlog'.log", text replace name(commonerror)
        capture noisily psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        local refusal_rc=_rc
        log close commonerror
        qa_state_compare, tag(common_empty)
        mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("namedlog")+".log")),"no observations"))))
        assert `refusal_rc'==2000 & `named'==1
    }
    else {
        quietly summarize wantw if common, meanonly
        scalar commonW=r(sum)
        quietly summarize w2 if common, meanonly
        scalar commonESS=commonW^2/r(sum)
        forvalues arm=0/1 {
            quietly summarize ps if common & a==`arm', meanonly
            scalar cmn`arm'=r(min)
            scalar cmx`arm'=r(max)
        }
        quietly count if common & (ps<max(cmn0,cmn1) | ps>min(cmx0,cmx1))
        scalar commonOutside=r(N)
        quietly psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        assert r(n_panels)==4 & r(N_requested)==wantN & r(N_analysis)==commonN & r(n_common_excluded)==wantN-commonN
        assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(wvar)'"=="wantw"
        qa_assert_equal r(ess) commonESS, property("dashboard exact complete-case weight ESS") tol(1e-12)
        qa_assert_equal r(n_outside) commonOutside, property("dashboard exact complete-case outside count")
    }
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: DEGRADED-DECLARED
    qa_fx_a1_logit, clear n(360) seed(541) perturb(miss_subgroup)
    assert "`r(perturb_applied)'"=="miss_subgroup"
    matrix cells=r(truth_cells)
    local c2=cond("miss_subgroup"=="codes_multidigit",11,2)
    local c3=cond("miss_subgroup"=="codes_multidigit",111,3)
    generate double original_x1=mod(floor((id-1)/20),3)-1
    generate byte original_x2=mod(floor((id-1)/60),2)
    generate byte original_cat=ceil(id/120)
    if "miss_subgroup"=="single_level" replace original_x2=0
    generate double ps=invlogit(-.4+.6*original_x1+.5*original_x2+.3*(original_cat==2)-.3*(original_cat==3))
    if "miss_subgroup"=="near_positivity" replace ps=1-1e-4 if original_cat==3 & original_x2==1
    // Verify support-cell PS truth before any diagnostic command.
    forvalues j=1/`=rowsof(cells)' {
        assert abs(ps-cells[`j',4])<1e-14 if original_x1==cells[`j',1] & original_x2==cells[`j',2] & original_cat==cells[`j',3]
    }
    generate double wantw=w*(a/ps+(1-a)/(1-ps))
    generate byte included=1
    if "miss_subgroup"=="base_absent" replace included=insample
    local sample "if included"
    local covs "x1 x2 i.xcat"
    local oraclecovs "x1 x2 fxcat2 fxcat3"
    generate double fxcat2=xcat==`c2'
    generate double fxcat3=xcat==`c3'
    if "miss_subgroup"=="base_absent" local oraclecovs "x1 x2 fxcat3"
    if "miss_subgroup"=="collinear" {
        local covs "x1 x2 i.xcat x3 x4"
        local oraclecovs "x1 x2 fxcat2 fxcat3 x3 x4"
    }
    generate double w2=wantw^2
    quietly summarize wantw `sample', meanonly
    scalar wantMean=r(mean)
    scalar sumw=r(sum)
    scalar wantN=r(N)
    quietly summarize w2 `sample', meanonly
    scalar wantESS=sumw^2/r(sum)
    forvalues arm=0/1 {
        quietly summarize wantw if included & a==`arm', meanonly
        scalar sw`arm'=r(sum)
        scalar n`arm'=r(N)
        quietly summarize w2 if included & a==`arm', meanonly
        scalar ess`arm'=sw`arm'^2/r(sum)
        quietly summarize ps if included & a==`arm', meanonly
        scalar mn`arm'=r(min)
        scalar mx`arm'=r(max)
        scalar mp`arm'=r(mean)
    }
    scalar lower=max(mn0,mn1)
    scalar upper=min(mx0,mx1)
    quietly count if included & (ps<lower | ps>upper)
    scalar outside=r(N)
    mata: st_matrix("wantBalance",qa_ps_balance(st_data(.,tokens("`oraclecovs'"),"included"),st_data(.,"a","included"),st_data(.,"wantw","included")))
    quietly psdash_weights a ps `sample', wvar(wantw)
    qa_assert_equal r(N) wantN, property("weights exact diagnostic population")
    qa_assert_equal r(ess) wantESS, property("direct supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(mean_wt) wantMean, property("direct supplied-weight mean") tol(1e-12)
    qa_assert_equal r(ess_treated) ess1, property("treated supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(ess_control) ess0, property("control supplied-weight ESS") tol(1e-12)
    quietly psdash weights a ps `sample', wvar(wantw)
    qa_assert_equal r(ess) wantESS, property("dispatcher exact ESS") tol(1e-12)
    quietly psdash_detect a ps `sample', covariates(`covs') wvar(wantw) estimand(ate)
    assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(psvar)'"=="ps" & "`r(wvar)'"=="wantw"
    assert r(psvar_auto)==0 & r(multigroup)==0 & r(longitudinal)==0
    assert r(n_covariates)==`: word count `covs'' & "`r(covariates)'"=="`covs'"
    quietly psdash_overlap a ps `sample', nograph
    qa_assert_equal r(N) wantN, property("overlap exact diagnostic population")
    qa_assert_equal r(mean_ps_treated) mp1, property("treated known-score mean") tol(1e-12)
    qa_assert_equal r(mean_ps_control) mp0, property("control known-score mean") tol(1e-12)
    qa_assert_equal r(overlap_lower) lower, property("observed support intersection lower") tol(1e-12)
    qa_assert_equal r(overlap_upper) upper, property("observed support intersection upper") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support membership count")
    quietly psdash_support a ps `sample', nograph
    qa_assert_equal r(lower_bound) lower, property("support lower intersection") tol(1e-12)
    qa_assert_equal r(upper_bound) upper, property("support upper intersection") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support outside exact count")
    quietly psdash_balance a ps `sample', covariates(`covs') wvar(wantw)
    matrix gotBalance=r(balance)
    assert rowsof(gotBalance)==rowsof(wantBalance) & colsof(gotBalance)==10
    forvalues j=1/`=rowsof(wantBalance)' {
        forvalues k=1/10 {
            if missing(wantBalance[`j',`k']) assert missing(gotBalance[`j',`k'])
            else {
                local tol=1e-10
                if "miss_subgroup"=="scale_shift" & inlist(`k',3,8) local tol=1e-6
                qa_assert_equal gotBalance[`j',`k'] wantBalance[`j',`k'], property("direct moments weighted ECDF cell") tol(`tol')
            }
        }
    }
    if "miss_subgroup"=="miss_subgroup" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x1" & r(n_cov_min)==300
    if "miss_subgroup"=="miss_all_column" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x2" & r(n_cov_min)==0
    // Dashboard pipeline must retain exact manual roles and common sample.
    generate byte common=included & !missing(x1,x2,xcat)
    quietly count if common
    scalar commonN=r(N)
    if commonN==0 {
        qa_state_snapshot, tag(common_empty)
        tempfile namedlog
        log using "`namedlog'.log", text replace name(commonerror)
        capture noisily psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        local refusal_rc=_rc
        log close commonerror
        qa_state_compare, tag(common_empty)
        mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("namedlog")+".log")),"no observations"))))
        assert `refusal_rc'==2000 & `named'==1
    }
    else {
        quietly summarize wantw if common, meanonly
        scalar commonW=r(sum)
        quietly summarize w2 if common, meanonly
        scalar commonESS=commonW^2/r(sum)
        forvalues arm=0/1 {
            quietly summarize ps if common & a==`arm', meanonly
            scalar cmn`arm'=r(min)
            scalar cmx`arm'=r(max)
        }
        quietly count if common & (ps<max(cmn0,cmn1) | ps>min(cmx0,cmx1))
        scalar commonOutside=r(N)
        quietly psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        assert r(n_panels)==4 & r(N_requested)==wantN & r(N_analysis)==commonN & r(n_common_excluded)==wantN-commonN
        assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(wvar)'"=="wantw"
        qa_assert_equal r(ess) commonESS, property("dashboard exact complete-case weight ESS") tol(1e-12)
        qa_assert_equal r(n_outside) commonOutside, property("dashboard exact complete-case outside count")
    }
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: DEGRADED-DECLARED
    qa_fx_a1_logit, clear n(360) seed(541) perturb(miss_all_column)
    assert "`r(perturb_applied)'"=="miss_all_column"
    matrix cells=r(truth_cells)
    local c2=cond("miss_all_column"=="codes_multidigit",11,2)
    local c3=cond("miss_all_column"=="codes_multidigit",111,3)
    generate double original_x1=mod(floor((id-1)/20),3)-1
    generate byte original_x2=mod(floor((id-1)/60),2)
    generate byte original_cat=ceil(id/120)
    if "miss_all_column"=="single_level" replace original_x2=0
    generate double ps=invlogit(-.4+.6*original_x1+.5*original_x2+.3*(original_cat==2)-.3*(original_cat==3))
    if "miss_all_column"=="near_positivity" replace ps=1-1e-4 if original_cat==3 & original_x2==1
    // Verify support-cell PS truth before any diagnostic command.
    forvalues j=1/`=rowsof(cells)' {
        assert abs(ps-cells[`j',4])<1e-14 if original_x1==cells[`j',1] & original_x2==cells[`j',2] & original_cat==cells[`j',3]
    }
    generate double wantw=w*(a/ps+(1-a)/(1-ps))
    generate byte included=1
    if "miss_all_column"=="base_absent" replace included=insample
    local sample "if included"
    local covs "x1 x2 i.xcat"
    local oraclecovs "x1 x2 fxcat2 fxcat3"
    generate double fxcat2=xcat==`c2'
    generate double fxcat3=xcat==`c3'
    if "miss_all_column"=="base_absent" local oraclecovs "x1 x2 fxcat3"
    if "miss_all_column"=="collinear" {
        local covs "x1 x2 i.xcat x3 x4"
        local oraclecovs "x1 x2 fxcat2 fxcat3 x3 x4"
    }
    generate double w2=wantw^2
    quietly summarize wantw `sample', meanonly
    scalar wantMean=r(mean)
    scalar sumw=r(sum)
    scalar wantN=r(N)
    quietly summarize w2 `sample', meanonly
    scalar wantESS=sumw^2/r(sum)
    forvalues arm=0/1 {
        quietly summarize wantw if included & a==`arm', meanonly
        scalar sw`arm'=r(sum)
        scalar n`arm'=r(N)
        quietly summarize w2 if included & a==`arm', meanonly
        scalar ess`arm'=sw`arm'^2/r(sum)
        quietly summarize ps if included & a==`arm', meanonly
        scalar mn`arm'=r(min)
        scalar mx`arm'=r(max)
        scalar mp`arm'=r(mean)
    }
    scalar lower=max(mn0,mn1)
    scalar upper=min(mx0,mx1)
    quietly count if included & (ps<lower | ps>upper)
    scalar outside=r(N)
    mata: st_matrix("wantBalance",qa_ps_balance(st_data(.,tokens("`oraclecovs'"),"included"),st_data(.,"a","included"),st_data(.,"wantw","included")))
    quietly psdash_weights a ps `sample', wvar(wantw)
    qa_assert_equal r(N) wantN, property("weights exact diagnostic population")
    qa_assert_equal r(ess) wantESS, property("direct supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(mean_wt) wantMean, property("direct supplied-weight mean") tol(1e-12)
    qa_assert_equal r(ess_treated) ess1, property("treated supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(ess_control) ess0, property("control supplied-weight ESS") tol(1e-12)
    quietly psdash weights a ps `sample', wvar(wantw)
    qa_assert_equal r(ess) wantESS, property("dispatcher exact ESS") tol(1e-12)
    quietly psdash_detect a ps `sample', covariates(`covs') wvar(wantw) estimand(ate)
    assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(psvar)'"=="ps" & "`r(wvar)'"=="wantw"
    assert r(psvar_auto)==0 & r(multigroup)==0 & r(longitudinal)==0
    assert r(n_covariates)==`: word count `covs'' & "`r(covariates)'"=="`covs'"
    quietly psdash_overlap a ps `sample', nograph
    qa_assert_equal r(N) wantN, property("overlap exact diagnostic population")
    qa_assert_equal r(mean_ps_treated) mp1, property("treated known-score mean") tol(1e-12)
    qa_assert_equal r(mean_ps_control) mp0, property("control known-score mean") tol(1e-12)
    qa_assert_equal r(overlap_lower) lower, property("observed support intersection lower") tol(1e-12)
    qa_assert_equal r(overlap_upper) upper, property("observed support intersection upper") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support membership count")
    quietly psdash_support a ps `sample', nograph
    qa_assert_equal r(lower_bound) lower, property("support lower intersection") tol(1e-12)
    qa_assert_equal r(upper_bound) upper, property("support upper intersection") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support outside exact count")
    quietly psdash_balance a ps `sample', covariates(`covs') wvar(wantw)
    matrix gotBalance=r(balance)
    assert rowsof(gotBalance)==rowsof(wantBalance) & colsof(gotBalance)==10
    forvalues j=1/`=rowsof(wantBalance)' {
        forvalues k=1/10 {
            if missing(wantBalance[`j',`k']) assert missing(gotBalance[`j',`k'])
            else {
                local tol=1e-10
                if "miss_all_column"=="scale_shift" & inlist(`k',3,8) local tol=1e-6
                qa_assert_equal gotBalance[`j',`k'] wantBalance[`j',`k'], property("direct moments weighted ECDF cell") tol(`tol')
            }
        }
    }
    if "miss_all_column"=="miss_subgroup" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x1" & r(n_cov_min)==300
    if "miss_all_column"=="miss_all_column" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x2" & r(n_cov_min)==0
    // Dashboard pipeline must retain exact manual roles and common sample.
    generate byte common=included & !missing(x1,x2,xcat)
    quietly count if common
    scalar commonN=r(N)
    if commonN==0 {
        qa_state_snapshot, tag(common_empty)
        tempfile namedlog
        log using "`namedlog'.log", text replace name(commonerror)
        capture noisily psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        local refusal_rc=_rc
        log close commonerror
        qa_state_compare, tag(common_empty)
        mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("namedlog")+".log")),"no observations"))))
        assert `refusal_rc'==2000 & `named'==1
    }
    else {
        quietly summarize wantw if common, meanonly
        scalar commonW=r(sum)
        quietly summarize w2 if common, meanonly
        scalar commonESS=commonW^2/r(sum)
        forvalues arm=0/1 {
            quietly summarize ps if common & a==`arm', meanonly
            scalar cmn`arm'=r(min)
            scalar cmx`arm'=r(max)
        }
        quietly count if common & (ps<max(cmn0,cmn1) | ps>min(cmx0,cmx1))
        scalar commonOutside=r(N)
        quietly psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        assert r(n_panels)==4 & r(N_requested)==wantN & r(N_analysis)==commonN & r(n_common_excluded)==wantN-commonN
        assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(wvar)'"=="wantw"
        qa_assert_equal r(ess) commonESS, property("dashboard exact complete-case weight ESS") tol(1e-12)
        qa_assert_equal r(n_outside) commonOutside, property("dashboard exact complete-case outside count")
    }
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_logit, clear n(360) seed(541) perturb(zero_weight)
    assert "`r(perturb_applied)'"=="zero_weight"
    matrix cells=r(truth_cells)
    local c2=cond("zero_weight"=="codes_multidigit",11,2)
    local c3=cond("zero_weight"=="codes_multidigit",111,3)
    generate double original_x1=mod(floor((id-1)/20),3)-1
    generate byte original_x2=mod(floor((id-1)/60),2)
    generate byte original_cat=ceil(id/120)
    if "zero_weight"=="single_level" replace original_x2=0
    generate double ps=invlogit(-.4+.6*original_x1+.5*original_x2+.3*(original_cat==2)-.3*(original_cat==3))
    if "zero_weight"=="near_positivity" replace ps=1-1e-4 if original_cat==3 & original_x2==1
    // Verify support-cell PS truth before any diagnostic command.
    forvalues j=1/`=rowsof(cells)' {
        assert abs(ps-cells[`j',4])<1e-14 if original_x1==cells[`j',1] & original_x2==cells[`j',2] & original_cat==cells[`j',3]
    }
    generate double wantw=w*(a/ps+(1-a)/(1-ps))
    generate byte included=1
    if "zero_weight"=="base_absent" replace included=insample
    local sample "if included"
    local covs "x1 x2 i.xcat"
    local oraclecovs "x1 x2 fxcat2 fxcat3"
    generate double fxcat2=xcat==`c2'
    generate double fxcat3=xcat==`c3'
    if "zero_weight"=="base_absent" local oraclecovs "x1 x2 fxcat3"
    if "zero_weight"=="collinear" {
        local covs "x1 x2 i.xcat x3 x4"
        local oraclecovs "x1 x2 fxcat2 fxcat3 x3 x4"
    }
    generate double w2=wantw^2
    quietly summarize wantw `sample', meanonly
    scalar wantMean=r(mean)
    scalar sumw=r(sum)
    scalar wantN=r(N)
    quietly summarize w2 `sample', meanonly
    scalar wantESS=sumw^2/r(sum)
    forvalues arm=0/1 {
        quietly summarize wantw if included & a==`arm', meanonly
        scalar sw`arm'=r(sum)
        scalar n`arm'=r(N)
        quietly summarize w2 if included & a==`arm', meanonly
        scalar ess`arm'=sw`arm'^2/r(sum)
        quietly summarize ps if included & a==`arm', meanonly
        scalar mn`arm'=r(min)
        scalar mx`arm'=r(max)
        scalar mp`arm'=r(mean)
    }
    scalar lower=max(mn0,mn1)
    scalar upper=min(mx0,mx1)
    quietly count if included & (ps<lower | ps>upper)
    scalar outside=r(N)
    mata: st_matrix("wantBalance",qa_ps_balance(st_data(.,tokens("`oraclecovs'"),"included"),st_data(.,"a","included"),st_data(.,"wantw","included")))
    quietly psdash_weights a ps `sample', wvar(wantw)
    qa_assert_equal r(N) wantN, property("weights exact diagnostic population")
    qa_assert_equal r(ess) wantESS, property("direct supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(mean_wt) wantMean, property("direct supplied-weight mean") tol(1e-12)
    qa_assert_equal r(ess_treated) ess1, property("treated supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(ess_control) ess0, property("control supplied-weight ESS") tol(1e-12)
    quietly psdash weights a ps `sample', wvar(wantw)
    qa_assert_equal r(ess) wantESS, property("dispatcher exact ESS") tol(1e-12)
    quietly psdash_detect a ps `sample', covariates(`covs') wvar(wantw) estimand(ate)
    assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(psvar)'"=="ps" & "`r(wvar)'"=="wantw"
    assert r(psvar_auto)==0 & r(multigroup)==0 & r(longitudinal)==0
    assert r(n_covariates)==`: word count `covs'' & "`r(covariates)'"=="`covs'"
    quietly psdash_overlap a ps `sample', nograph
    qa_assert_equal r(N) wantN, property("overlap exact diagnostic population")
    qa_assert_equal r(mean_ps_treated) mp1, property("treated known-score mean") tol(1e-12)
    qa_assert_equal r(mean_ps_control) mp0, property("control known-score mean") tol(1e-12)
    qa_assert_equal r(overlap_lower) lower, property("observed support intersection lower") tol(1e-12)
    qa_assert_equal r(overlap_upper) upper, property("observed support intersection upper") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support membership count")
    quietly psdash_support a ps `sample', nograph
    qa_assert_equal r(lower_bound) lower, property("support lower intersection") tol(1e-12)
    qa_assert_equal r(upper_bound) upper, property("support upper intersection") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support outside exact count")
    quietly psdash_balance a ps `sample', covariates(`covs') wvar(wantw)
    matrix gotBalance=r(balance)
    assert rowsof(gotBalance)==rowsof(wantBalance) & colsof(gotBalance)==10
    forvalues j=1/`=rowsof(wantBalance)' {
        forvalues k=1/10 {
            if missing(wantBalance[`j',`k']) assert missing(gotBalance[`j',`k'])
            else {
                local tol=1e-10
                if "zero_weight"=="scale_shift" & inlist(`k',3,8) local tol=1e-6
                qa_assert_equal gotBalance[`j',`k'] wantBalance[`j',`k'], property("direct moments weighted ECDF cell") tol(`tol')
            }
        }
    }
    if "zero_weight"=="miss_subgroup" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x1" & r(n_cov_min)==300
    if "zero_weight"=="miss_all_column" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x2" & r(n_cov_min)==0
    // Dashboard pipeline must retain exact manual roles and common sample.
    generate byte common=included & !missing(x1,x2,xcat)
    quietly count if common
    scalar commonN=r(N)
    if commonN==0 {
        qa_state_snapshot, tag(common_empty)
        tempfile namedlog
        log using "`namedlog'.log", text replace name(commonerror)
        capture noisily psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        local refusal_rc=_rc
        log close commonerror
        qa_state_compare, tag(common_empty)
        mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("namedlog")+".log")),"no observations"))))
        assert `refusal_rc'==2000 & `named'==1
    }
    else {
        quietly summarize wantw if common, meanonly
        scalar commonW=r(sum)
        quietly summarize w2 if common, meanonly
        scalar commonESS=commonW^2/r(sum)
        forvalues arm=0/1 {
            quietly summarize ps if common & a==`arm', meanonly
            scalar cmn`arm'=r(min)
            scalar cmx`arm'=r(max)
        }
        quietly count if common & (ps<max(cmn0,cmn1) | ps>min(cmx0,cmx1))
        scalar commonOutside=r(N)
        quietly psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        assert r(n_panels)==4 & r(N_requested)==wantN & r(N_analysis)==commonN & r(n_common_excluded)==wantN-commonN
        assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(wvar)'"=="wantw"
        qa_assert_equal r(ess) commonESS, property("dashboard exact complete-case weight ESS") tol(1e-12)
        qa_assert_equal r(n_outside) commonOutside, property("dashboard exact complete-case outside count")
    }
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: DEGRADED-DECLARED
    qa_fx_a1_logit, clear n(360) seed(541) perturb(extreme_weight)
    assert "`r(perturb_applied)'"=="extreme_weight"
    matrix cells=r(truth_cells)
    local c2=cond("extreme_weight"=="codes_multidigit",11,2)
    local c3=cond("extreme_weight"=="codes_multidigit",111,3)
    generate double original_x1=mod(floor((id-1)/20),3)-1
    generate byte original_x2=mod(floor((id-1)/60),2)
    generate byte original_cat=ceil(id/120)
    if "extreme_weight"=="single_level" replace original_x2=0
    generate double ps=invlogit(-.4+.6*original_x1+.5*original_x2+.3*(original_cat==2)-.3*(original_cat==3))
    if "extreme_weight"=="near_positivity" replace ps=1-1e-4 if original_cat==3 & original_x2==1
    // Verify support-cell PS truth before any diagnostic command.
    forvalues j=1/`=rowsof(cells)' {
        assert abs(ps-cells[`j',4])<1e-14 if original_x1==cells[`j',1] & original_x2==cells[`j',2] & original_cat==cells[`j',3]
    }
    generate double wantw=w*(a/ps+(1-a)/(1-ps))
    generate byte included=1
    if "extreme_weight"=="base_absent" replace included=insample
    local sample "if included"
    local covs "x1 x2 i.xcat"
    local oraclecovs "x1 x2 fxcat2 fxcat3"
    generate double fxcat2=xcat==`c2'
    generate double fxcat3=xcat==`c3'
    if "extreme_weight"=="base_absent" local oraclecovs "x1 x2 fxcat3"
    if "extreme_weight"=="collinear" {
        local covs "x1 x2 i.xcat x3 x4"
        local oraclecovs "x1 x2 fxcat2 fxcat3 x3 x4"
    }
    generate double w2=wantw^2
    quietly summarize wantw `sample', meanonly
    scalar wantMean=r(mean)
    scalar sumw=r(sum)
    scalar wantN=r(N)
    quietly summarize w2 `sample', meanonly
    scalar wantESS=sumw^2/r(sum)
    forvalues arm=0/1 {
        quietly summarize wantw if included & a==`arm', meanonly
        scalar sw`arm'=r(sum)
        scalar n`arm'=r(N)
        quietly summarize w2 if included & a==`arm', meanonly
        scalar ess`arm'=sw`arm'^2/r(sum)
        quietly summarize ps if included & a==`arm', meanonly
        scalar mn`arm'=r(min)
        scalar mx`arm'=r(max)
        scalar mp`arm'=r(mean)
    }
    scalar lower=max(mn0,mn1)
    scalar upper=min(mx0,mx1)
    quietly count if included & (ps<lower | ps>upper)
    scalar outside=r(N)
    mata: st_matrix("wantBalance",qa_ps_balance(st_data(.,tokens("`oraclecovs'"),"included"),st_data(.,"a","included"),st_data(.,"wantw","included")))
    quietly psdash_weights a ps `sample', wvar(wantw)
    qa_assert_equal r(N) wantN, property("weights exact diagnostic population")
    qa_assert_equal r(ess) wantESS, property("direct supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(mean_wt) wantMean, property("direct supplied-weight mean") tol(1e-12)
    qa_assert_equal r(ess_treated) ess1, property("treated supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(ess_control) ess0, property("control supplied-weight ESS") tol(1e-12)
    quietly psdash weights a ps `sample', wvar(wantw)
    qa_assert_equal r(ess) wantESS, property("dispatcher exact ESS") tol(1e-12)
    quietly psdash_detect a ps `sample', covariates(`covs') wvar(wantw) estimand(ate)
    assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(psvar)'"=="ps" & "`r(wvar)'"=="wantw"
    assert r(psvar_auto)==0 & r(multigroup)==0 & r(longitudinal)==0
    assert r(n_covariates)==`: word count `covs'' & "`r(covariates)'"=="`covs'"
    quietly psdash_overlap a ps `sample', nograph
    qa_assert_equal r(N) wantN, property("overlap exact diagnostic population")
    qa_assert_equal r(mean_ps_treated) mp1, property("treated known-score mean") tol(1e-12)
    qa_assert_equal r(mean_ps_control) mp0, property("control known-score mean") tol(1e-12)
    qa_assert_equal r(overlap_lower) lower, property("observed support intersection lower") tol(1e-12)
    qa_assert_equal r(overlap_upper) upper, property("observed support intersection upper") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support membership count")
    quietly psdash_support a ps `sample', nograph
    qa_assert_equal r(lower_bound) lower, property("support lower intersection") tol(1e-12)
    qa_assert_equal r(upper_bound) upper, property("support upper intersection") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support outside exact count")
    quietly psdash_balance a ps `sample', covariates(`covs') wvar(wantw)
    matrix gotBalance=r(balance)
    assert rowsof(gotBalance)==rowsof(wantBalance) & colsof(gotBalance)==10
    forvalues j=1/`=rowsof(wantBalance)' {
        forvalues k=1/10 {
            if missing(wantBalance[`j',`k']) assert missing(gotBalance[`j',`k'])
            else {
                local tol=1e-10
                if "extreme_weight"=="scale_shift" & inlist(`k',3,8) local tol=1e-6
                qa_assert_equal gotBalance[`j',`k'] wantBalance[`j',`k'], property("direct moments weighted ECDF cell") tol(`tol')
            }
        }
    }
    if "extreme_weight"=="miss_subgroup" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x1" & r(n_cov_min)==300
    if "extreme_weight"=="miss_all_column" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x2" & r(n_cov_min)==0
    // Dashboard pipeline must retain exact manual roles and common sample.
    generate byte common=included & !missing(x1,x2,xcat)
    quietly count if common
    scalar commonN=r(N)
    if commonN==0 {
        qa_state_snapshot, tag(common_empty)
        tempfile namedlog
        log using "`namedlog'.log", text replace name(commonerror)
        capture noisily psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        local refusal_rc=_rc
        log close commonerror
        qa_state_compare, tag(common_empty)
        mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("namedlog")+".log")),"no observations"))))
        assert `refusal_rc'==2000 & `named'==1
    }
    else {
        quietly summarize wantw if common, meanonly
        scalar commonW=r(sum)
        quietly summarize w2 if common, meanonly
        scalar commonESS=commonW^2/r(sum)
        forvalues arm=0/1 {
            quietly summarize ps if common & a==`arm', meanonly
            scalar cmn`arm'=r(min)
            scalar cmx`arm'=r(max)
        }
        quietly count if common & (ps<max(cmn0,cmn1) | ps>min(cmx0,cmx1))
        scalar commonOutside=r(N)
        quietly psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        assert r(n_panels)==4 & r(N_requested)==wantN & r(N_analysis)==commonN & r(n_common_excluded)==wantN-commonN
        assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(wvar)'"=="wantw"
        qa_assert_equal r(ess) commonESS, property("dashboard exact complete-case weight ESS") tol(1e-12)
        qa_assert_equal r(n_outside) commonOutside, property("dashboard exact complete-case outside count")
    }
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: DEGRADED-DECLARED
    qa_fx_a1_logit, clear n(360) seed(541) perturb(near_positivity)
    assert "`r(perturb_applied)'"=="near_positivity"
    matrix cells=r(truth_cells)
    local c2=cond("near_positivity"=="codes_multidigit",11,2)
    local c3=cond("near_positivity"=="codes_multidigit",111,3)
    generate double original_x1=mod(floor((id-1)/20),3)-1
    generate byte original_x2=mod(floor((id-1)/60),2)
    generate byte original_cat=ceil(id/120)
    if "near_positivity"=="single_level" replace original_x2=0
    generate double ps=invlogit(-.4+.6*original_x1+.5*original_x2+.3*(original_cat==2)-.3*(original_cat==3))
    if "near_positivity"=="near_positivity" replace ps=1-1e-4 if original_cat==3 & original_x2==1
    // Verify support-cell PS truth before any diagnostic command.
    forvalues j=1/`=rowsof(cells)' {
        assert abs(ps-cells[`j',4])<1e-14 if original_x1==cells[`j',1] & original_x2==cells[`j',2] & original_cat==cells[`j',3]
    }
    generate double wantw=w*(a/ps+(1-a)/(1-ps))
    generate byte included=1
    if "near_positivity"=="base_absent" replace included=insample
    local sample "if included"
    local covs "x1 x2 i.xcat"
    local oraclecovs "x1 x2 fxcat2 fxcat3"
    generate double fxcat2=xcat==`c2'
    generate double fxcat3=xcat==`c3'
    if "near_positivity"=="base_absent" local oraclecovs "x1 x2 fxcat3"
    if "near_positivity"=="collinear" {
        local covs "x1 x2 i.xcat x3 x4"
        local oraclecovs "x1 x2 fxcat2 fxcat3 x3 x4"
    }
    generate double w2=wantw^2
    quietly summarize wantw `sample', meanonly
    scalar wantMean=r(mean)
    scalar sumw=r(sum)
    scalar wantN=r(N)
    quietly summarize w2 `sample', meanonly
    scalar wantESS=sumw^2/r(sum)
    forvalues arm=0/1 {
        quietly summarize wantw if included & a==`arm', meanonly
        scalar sw`arm'=r(sum)
        scalar n`arm'=r(N)
        quietly summarize w2 if included & a==`arm', meanonly
        scalar ess`arm'=sw`arm'^2/r(sum)
        quietly summarize ps if included & a==`arm', meanonly
        scalar mn`arm'=r(min)
        scalar mx`arm'=r(max)
        scalar mp`arm'=r(mean)
    }
    scalar lower=max(mn0,mn1)
    scalar upper=min(mx0,mx1)
    quietly count if included & (ps<lower | ps>upper)
    scalar outside=r(N)
    mata: st_matrix("wantBalance",qa_ps_balance(st_data(.,tokens("`oraclecovs'"),"included"),st_data(.,"a","included"),st_data(.,"wantw","included")))
    quietly psdash_weights a ps `sample', wvar(wantw)
    qa_assert_equal r(N) wantN, property("weights exact diagnostic population")
    qa_assert_equal r(ess) wantESS, property("direct supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(mean_wt) wantMean, property("direct supplied-weight mean") tol(1e-12)
    qa_assert_equal r(ess_treated) ess1, property("treated supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(ess_control) ess0, property("control supplied-weight ESS") tol(1e-12)
    quietly psdash weights a ps `sample', wvar(wantw)
    qa_assert_equal r(ess) wantESS, property("dispatcher exact ESS") tol(1e-12)
    quietly psdash_detect a ps `sample', covariates(`covs') wvar(wantw) estimand(ate)
    assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(psvar)'"=="ps" & "`r(wvar)'"=="wantw"
    assert r(psvar_auto)==0 & r(multigroup)==0 & r(longitudinal)==0
    assert r(n_covariates)==`: word count `covs'' & "`r(covariates)'"=="`covs'"
    quietly psdash_overlap a ps `sample', nograph
    qa_assert_equal r(N) wantN, property("overlap exact diagnostic population")
    qa_assert_equal r(mean_ps_treated) mp1, property("treated known-score mean") tol(1e-12)
    qa_assert_equal r(mean_ps_control) mp0, property("control known-score mean") tol(1e-12)
    qa_assert_equal r(overlap_lower) lower, property("observed support intersection lower") tol(1e-12)
    qa_assert_equal r(overlap_upper) upper, property("observed support intersection upper") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support membership count")
    quietly psdash_support a ps `sample', nograph
    qa_assert_equal r(lower_bound) lower, property("support lower intersection") tol(1e-12)
    qa_assert_equal r(upper_bound) upper, property("support upper intersection") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support outside exact count")
    quietly psdash_balance a ps `sample', covariates(`covs') wvar(wantw)
    matrix gotBalance=r(balance)
    assert rowsof(gotBalance)==rowsof(wantBalance) & colsof(gotBalance)==10
    forvalues j=1/`=rowsof(wantBalance)' {
        forvalues k=1/10 {
            if missing(wantBalance[`j',`k']) assert missing(gotBalance[`j',`k'])
            else {
                local tol=1e-10
                if "near_positivity"=="scale_shift" & inlist(`k',3,8) local tol=1e-6
                qa_assert_equal gotBalance[`j',`k'] wantBalance[`j',`k'], property("direct moments weighted ECDF cell") tol(`tol')
            }
        }
    }
    if "near_positivity"=="miss_subgroup" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x1" & r(n_cov_min)==300
    if "near_positivity"=="miss_all_column" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x2" & r(n_cov_min)==0
    // Dashboard pipeline must retain exact manual roles and common sample.
    generate byte common=included & !missing(x1,x2,xcat)
    quietly count if common
    scalar commonN=r(N)
    if commonN==0 {
        qa_state_snapshot, tag(common_empty)
        tempfile namedlog
        log using "`namedlog'.log", text replace name(commonerror)
        capture noisily psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        local refusal_rc=_rc
        log close commonerror
        qa_state_compare, tag(common_empty)
        mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("namedlog")+".log")),"no observations"))))
        assert `refusal_rc'==2000 & `named'==1
    }
    else {
        quietly summarize wantw if common, meanonly
        scalar commonW=r(sum)
        quietly summarize w2 if common, meanonly
        scalar commonESS=commonW^2/r(sum)
        forvalues arm=0/1 {
            quietly summarize ps if common & a==`arm', meanonly
            scalar cmn`arm'=r(min)
            scalar cmx`arm'=r(max)
        }
        quietly count if common & (ps<max(cmn0,cmn1) | ps>min(cmx0,cmx1))
        scalar commonOutside=r(N)
        quietly psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        assert r(n_panels)==4 & r(N_requested)==wantN & r(N_analysis)==commonN & r(n_common_excluded)==wantN-commonN
        assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(wvar)'"=="wantw"
        qa_assert_equal r(ess) commonESS, property("dashboard exact complete-case weight ESS") tol(1e-12)
        qa_assert_equal r(n_outside) commonOutside, property("dashboard exact complete-case outside count")
    }
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_logit, clear n(360) seed(541) perturb(scale_shift)
    assert "`r(perturb_applied)'"=="scale_shift"
    matrix cells=r(truth_cells)
    local c2=cond("scale_shift"=="codes_multidigit",11,2)
    local c3=cond("scale_shift"=="codes_multidigit",111,3)
    generate double original_x1=mod(floor((id-1)/20),3)-1
    generate byte original_x2=mod(floor((id-1)/60),2)
    generate byte original_cat=ceil(id/120)
    if "scale_shift"=="single_level" replace original_x2=0
    generate double ps=invlogit(-.4+.6*original_x1+.5*original_x2+.3*(original_cat==2)-.3*(original_cat==3))
    if "scale_shift"=="near_positivity" replace ps=1-1e-4 if original_cat==3 & original_x2==1
    // Verify support-cell PS truth before any diagnostic command.
    forvalues j=1/`=rowsof(cells)' {
        assert abs(ps-cells[`j',4])<1e-14 if original_x1==cells[`j',1] & original_x2==cells[`j',2] & original_cat==cells[`j',3]
    }
    generate double wantw=w*(a/ps+(1-a)/(1-ps))
    generate byte included=1
    if "scale_shift"=="base_absent" replace included=insample
    local sample "if included"
    local covs "x1 x2 i.xcat"
    local oraclecovs "x1 x2 fxcat2 fxcat3"
    generate double fxcat2=xcat==`c2'
    generate double fxcat3=xcat==`c3'
    if "scale_shift"=="base_absent" local oraclecovs "x1 x2 fxcat3"
    if "scale_shift"=="collinear" {
        local covs "x1 x2 i.xcat x3 x4"
        local oraclecovs "x1 x2 fxcat2 fxcat3 x3 x4"
    }
    generate double w2=wantw^2
    quietly summarize wantw `sample', meanonly
    scalar wantMean=r(mean)
    scalar sumw=r(sum)
    scalar wantN=r(N)
    quietly summarize w2 `sample', meanonly
    scalar wantESS=sumw^2/r(sum)
    forvalues arm=0/1 {
        quietly summarize wantw if included & a==`arm', meanonly
        scalar sw`arm'=r(sum)
        scalar n`arm'=r(N)
        quietly summarize w2 if included & a==`arm', meanonly
        scalar ess`arm'=sw`arm'^2/r(sum)
        quietly summarize ps if included & a==`arm', meanonly
        scalar mn`arm'=r(min)
        scalar mx`arm'=r(max)
        scalar mp`arm'=r(mean)
    }
    scalar lower=max(mn0,mn1)
    scalar upper=min(mx0,mx1)
    quietly count if included & (ps<lower | ps>upper)
    scalar outside=r(N)
    mata: st_matrix("wantBalance",qa_ps_balance(st_data(.,tokens("`oraclecovs'"),"included"),st_data(.,"a","included"),st_data(.,"wantw","included")))
    quietly psdash_weights a ps `sample', wvar(wantw)
    qa_assert_equal r(N) wantN, property("weights exact diagnostic population")
    qa_assert_equal r(ess) wantESS, property("direct supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(mean_wt) wantMean, property("direct supplied-weight mean") tol(1e-12)
    qa_assert_equal r(ess_treated) ess1, property("treated supplied-weight ESS") tol(1e-12)
    qa_assert_equal r(ess_control) ess0, property("control supplied-weight ESS") tol(1e-12)
    quietly psdash weights a ps `sample', wvar(wantw)
    qa_assert_equal r(ess) wantESS, property("dispatcher exact ESS") tol(1e-12)
    quietly psdash_detect a ps `sample', covariates(`covs') wvar(wantw) estimand(ate)
    assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(psvar)'"=="ps" & "`r(wvar)'"=="wantw"
    assert r(psvar_auto)==0 & r(multigroup)==0 & r(longitudinal)==0
    assert r(n_covariates)==`: word count `covs'' & "`r(covariates)'"=="`covs'"
    quietly psdash_overlap a ps `sample', nograph
    qa_assert_equal r(N) wantN, property("overlap exact diagnostic population")
    qa_assert_equal r(mean_ps_treated) mp1, property("treated known-score mean") tol(1e-12)
    qa_assert_equal r(mean_ps_control) mp0, property("control known-score mean") tol(1e-12)
    qa_assert_equal r(overlap_lower) lower, property("observed support intersection lower") tol(1e-12)
    qa_assert_equal r(overlap_upper) upper, property("observed support intersection upper") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support membership count")
    quietly psdash_support a ps `sample', nograph
    qa_assert_equal r(lower_bound) lower, property("support lower intersection") tol(1e-12)
    qa_assert_equal r(upper_bound) upper, property("support upper intersection") tol(1e-12)
    qa_assert_equal r(n_outside) outside, property("support outside exact count")
    quietly psdash_balance a ps `sample', covariates(`covs') wvar(wantw)
    matrix gotBalance=r(balance)
    assert rowsof(gotBalance)==rowsof(wantBalance) & colsof(gotBalance)==10
    forvalues j=1/`=rowsof(wantBalance)' {
        forvalues k=1/10 {
            if missing(wantBalance[`j',`k']) assert missing(gotBalance[`j',`k'])
            else {
                local tol=1e-10
                if "scale_shift"=="scale_shift" & inlist(`k',3,8) local tol=1e-6
                qa_assert_equal gotBalance[`j',`k'] wantBalance[`j',`k'], property("direct moments weighted ECDF cell") tol(`tol')
            }
        }
    }
    if "scale_shift"=="miss_subgroup" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x1" & r(n_cov_min)==300
    if "scale_shift"=="miss_all_column" assert r(n_cov_incomplete)==1 & "`r(cov_miss_vars)'"=="x2" & r(n_cov_min)==0
    // Dashboard pipeline must retain exact manual roles and common sample.
    generate byte common=included & !missing(x1,x2,xcat)
    quietly count if common
    scalar commonN=r(N)
    if commonN==0 {
        qa_state_snapshot, tag(common_empty)
        tempfile namedlog
        log using "`namedlog'.log", text replace name(commonerror)
        capture noisily psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        local refusal_rc=_rc
        log close commonerror
        qa_state_compare, tag(common_empty)
        mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("namedlog")+".log")),"no observations"))))
        assert `refusal_rc'==2000 & `named'==1
    }
    else {
        quietly summarize wantw if common, meanonly
        scalar commonW=r(sum)
        quietly summarize w2 if common, meanonly
        scalar commonESS=commonW^2/r(sum)
        forvalues arm=0/1 {
            quietly summarize ps if common & a==`arm', meanonly
            scalar cmn`arm'=r(min)
            scalar cmx`arm'=r(max)
        }
        quietly count if common & (ps<max(cmn0,cmn1) | ps>min(cmx0,cmx1))
        scalar commonOutside=r(N)
        quietly psdash_combined a ps `sample', covariates(`covs') wvar(wantw) threshold(100) overlapmax(100) essmin(0) imbalmax(99)
        assert r(n_panels)==4 & r(N_requested)==wantN & r(N_analysis)==commonN & r(n_common_excluded)==wantN-commonN
        assert "`r(source)'"=="manual" & "`r(treatment)'"=="a" & "`r(wvar)'"=="wantw"
        qa_assert_equal r(ess) commonESS, property("dashboard exact complete-case weight ESS") tol(1e-12)
        qa_assert_equal r(n_outside) commonOutside, property("dashboard exact complete-case outside count")
    }
}
if _rc local ++fail
else local ++pass
display "RESULT: validation_fixture_routes tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
