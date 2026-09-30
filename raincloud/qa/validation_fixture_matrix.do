*! validation_fixture_matrix.do -- independent consumed scalar/group/weight summaries
* Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set varabbrev off
set more off
set graphics off
capture log close _all
log using "validation_fixture_matrix.log", text replace
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
quietly do "_qa_fx_a1.do"
quietly do "_qa_fx_a7.do"
quietly do "_qa_hostile.do"
quietly do "_qa_state.do"
// Independent weighted means, aweight-normalized variance and empirical
// percentiles, per fetched [R] summarize Methods/formulas pp9-10, 30Sep2026.
// https://www.stata.com/manuals/rsummarize.pdf . No candidate output enters.
mata:
real matrix qa_rain_stats(real colvector X, real colvector G, real colvector W)
{
    real colvector levels,ii,x,w,cw,ord
    real matrix out
    real scalar j,k,n,sw,m,p,target,at,q
    levels=uniqrows(sort(G,1)); out=J(rows(levels),8,.)
    for (j=1;j<=rows(levels);j++) {
        ii=selectindex(G:==levels[j]); x=X[ii]; w=W[ii]
        ord=order(x,1); x=x[ord]; w=w[ord]
        n=rows(x); sw=sum(w); m=sum(x:*w)/sw
        out[j,1]=n; out[j,2]=m
        if (n>1) out[j,3]=sqrt(n/(n-1)*sum(w:*(x:-m):^2)/sw)
        cw=runningsum(w)
        for (k=1;k<=3;k++) {
            p=(k==1 ? .5 : (k==2 ? .25 : .75)); target=sw*p
            at=selectindex(cw:>target)[1]; q=x[at]
            if (at>1) if (cw[at-1]==target) q=(x[at-1]+x[at])/2
            out[j,3+k]=q
        }
        out[j,7]=out[j,6]-out[j,5]
    }
    return(out)
}
end
local tests=0
local pass=0
local fail=0
local ++tests
capture noisily {
    * Friendly graphics initialization and an exact finite numeric oracle.
    * The native graph engine initializes T_gm_fix_span on its first draw;
    * fingerprints below cover the initialized graphics environment.
    qa_fx_a7_labelled, clear tier(micro)
    quietly raincloud x, nocloud norain name(initial,replace)
    assert r(N)==40 & r(n_groups)==1
    matrix initial=r(stats)
    assert initial[1,1]==40 & initial[1,2]==20.5 & initial[1,4]==20.5
    assert initial[1,5]==10.5 & initial[1,6]==30.5 & initial[1,7]==20
    qa_assert_equal initial[1,3] sqrt(410/3), property("independent initial sample SD") tol(1e-10)
}
if _rc local ++fail
else local ++pass
capture program drop _qa_rain_matrix
program define _qa_rain_matrix
    version 16.0
    args op
    local target y
    if inlist("`op'","miss_subgroup","scale_shift") local target x1
    if "`op'"=="miss_all_column" local target x2
    local group xcat
    if "`op'"=="near_positivity" local group a
    local qualifier ""
    if "`op'"=="base_absent" local qualifier "if insample"
    local weight ""
    if inlist("`op'","zero_weight","extreme_weight") local weight "[aw=w]"
    if "`op'"=="miss_all_column" {
        tempfile errorlog
        qa_state_snapshot, tag(empty)
        log using "`errorlog'", text replace name(refusal)
        capture noisily raincloud `target', over(`group') nocloud norain name(emptyplot,replace)
        local gotrc=_rc
        log close refusal
        qa_state_compare, tag(empty)
        mata: st_local("named",strofreal(any(strpos(cat(st_local("errorlog")),"no observations"))))
        assert `gotrc'==2000 & `named'==1
    }
    else {
        generate byte fit=!missing(`target',`group')
        if "`op'"=="base_absent" replace fit=fit & insample
        generate double oracleW=1
        if inlist("`op'","zero_weight","extreme_weight") {
            replace oracleW=w
            replace fit=fit & w>0
        }
        mata: ii=selectindex(st_data(.,"fit")); st_matrix("wanted",qa_rain_stats(st_data(ii,st_local("target")),st_data(ii,st_local("group")),st_data(ii,"oracleW")))
        quietly count if fit
        scalar wantedN=r(N)
        qa_state_snapshot, tag(plot)
        quietly raincloud `target' `qualifier' `weight', over(`group') nocloud norain name(fxcloud,replace)
        qa_state_compare, tag(plot)
        matrix got=r(stats)
        assert r(N)==wantedN & r(n_groups)==rowsof(wanted)
        forvalues j=1/`=rowsof(wanted)' {
            forvalues k=1/7 {
                if missing(wanted[`j',`k']) assert missing(got[`j',`k'])
                else qa_assert_equal got[`j',`k'] wanted[`j',`k'], property("independent weighted group summary") tol(1e-10)
            }
            assert missing(got[`j',8])
        }
    }
end
local ++tests
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541)
    _qa_rain_matrix ""
}
if _rc local ++fail
else local ++pass
local ++tests
* expect: EXACT
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541) perturb(separate)
    _qa_rain_matrix "separate"
}
if _rc local ++fail
else local ++pass
local ++tests
* expect: EXACT
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541) perturb(single_level)
    _qa_rain_matrix "single_level"
}
if _rc local ++fail
else local ++pass
local ++tests
* expect: EXACT
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541) perturb(base_absent)
    _qa_rain_matrix "base_absent"
}
if _rc local ++fail
else local ++pass
local ++tests
* expect: INVARIANT
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541) perturb(codes_multidigit)
    _qa_rain_matrix "codes_multidigit"
}
if _rc local ++fail
else local ++pass
local ++tests
* expect: EXACT
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541) perturb(miss_subgroup)
    _qa_rain_matrix "miss_subgroup"
}
if _rc local ++fail
else local ++pass
local ++tests
* expect: REFUSED
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541) perturb(miss_all_column)
    _qa_rain_matrix "miss_all_column"
}
if _rc local ++fail
else local ++pass
local ++tests
* expect: EXACT
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541) perturb(zero_weight)
    _qa_rain_matrix "zero_weight"
}
if _rc local ++fail
else local ++pass
local ++tests
* expect: EXACT
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541) perturb(extreme_weight)
    _qa_rain_matrix "extreme_weight"
}
if _rc local ++fail
else local ++pass
local ++tests
* expect: EXACT
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541) perturb(near_positivity)
    _qa_rain_matrix "near_positivity"
}
if _rc local ++fail
else local ++pass
local ++tests
* expect: SHIFTED
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541) perturb(scale_shift)
    _qa_rain_matrix "scale_shift"
}
if _rc local ++fail
else local ++pass

capture program drop _qa_rain_primitive
program define _qa_rain_primitive
    version 16.0
    args target group
    generate byte fit=!missing(`target',`group')
    generate byte oracleW=1
    mata: ii=selectindex(st_data(.,"fit")); st_matrix("wanted",qa_rain_stats(st_data(ii,st_local("target")),st_data(ii,st_local("group")),st_data(ii,"oracleW")))
    quietly count if fit
    scalar wantedN=r(N)
    qa_state_snapshot, tag(plot)
    quietly raincloud `target', over(`group') nocloud norain name(fxcloud,replace)
    qa_state_compare, tag(plot)
    matrix got=r(stats)
    assert r(N)==wantedN & r(n_groups)==rowsof(wanted)
    forvalues j=1/`=rowsof(wanted)' {
        forvalues k=1/7 {
            if missing(wanted[`j',`k']) assert missing(got[`j',`k'])
            else qa_assert_equal got[`j',`k'] wanted[`j',`k'], property("independent primitive group summary") tol(1e-10)
        }
        assert missing(got[`j',8])
    }
    drop fit oracleW
end
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear tier(micro) perturb(single_row)
    _qa_rain_primitive x group
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_codes, clear
    _qa_rain_primitive y code
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_names, clear
    local targets "`r(twins)' `r(long)'"
    generate byte group=1
    foreach target of local targets {
        _qa_rain_primitive `target' group
    }
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_missing, clear
    _qa_rain_primitive x group
}
if _rc local ++fail
else local ++pass
display "RESULT: validation_fixture_matrix tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
