*! validation_fixture_matrix.do -- consumed design roles, exact rows and native clones
* Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set more off
set varabbrev off
set graphics off
capture log close _all
log using "validation_fixture_matrix.log", text replace
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
quietly do "_qa_fx_a1.do"
quietly do "_qa_fx_a7.do"
quietly do "_qa_hostile.do"
quietly do "_qa_state.do"
local tests=0
local pass=0
local fail=0
capture program drop _qa_fv_matrix
program define _qa_fv_matrix
    version 16.0
    args op
    local cont "x1 x2 y"
    if "`op'"=="collinear" local cont "`cont' x3 x4"
    local design "i.a##i.xcat"
    foreach v of local cont {
        local design "`design' c.`v'"
    }
    local restriction ""
    if "`op'"=="base_absent" local restriction "if insample"
    local wopt ""
    if inlist("`op'","zero_weight","extreme_weight") local wopt "[aw=w]"
    if "`op'"=="miss_all_column" {
        tempfile errorlog
        qa_state_snapshot, tag(empty)
        log using "`errorlog'", text replace name(refusal)
        capture noisily fvgen `design', center prefix(fx_)
        local gotrc=_rc
        log close refusal
        qa_state_compare, tag(empty)
        mata: st_local("named",strofreal(any(strpos(cat(st_local("errorlog")),"no observations"))))
        assert `gotrc'==2000 & `named'==1
    }
    else {
        generate byte fit=!missing(a,xcat,x1,x2,y)
        if "`op'"=="base_absent" replace fit=fit & insample
        generate double oracleW=fit
        if inlist("`op'","zero_weight","extreme_weight") replace oracleW=fit*w
        matrix mean=J(1,`: word count `cont'',.)
        mata: W=st_data(.,"oracleW"); ii=selectindex(W:>0); st_matrix("mean",(W[ii]'*st_data(ii,tokens(st_local("cont"))))/sum(W[ii]))
        quietly fvgen `design' `restriction' `wopt', center prefix(fx_)
        local generated "`r(genvars)'"
        assert `: word count `generated''>=3
        local centered ""
        foreach v of local generated {
            local role : char `v'[fvgen_role]
            local term : char `v'[fvgen_term]
            if "`role'"=="centered" {
                local source=substr("`term'",3,.)
                local j : list posof "`source'" in cont
                assert `j'>0 & !missing(mean[1,`j'])
                local centered "`centered' `source'"
                assert missing(`v')==missing(`source')
                assert abs(`v'-(`source'-mean[1,`j']))<1e-7 if !missing(`source')
            }
            else {
                local pieces : subinstr local term "#" " ", all
                local expression "1"
                foreach part of local pieces {
                    assert regexm("`part'","^([0-9]+)[bn]*[.]([a-zA-Z0-9_]+)$")
                    local level=real(regexs(1))
                    local source=regexs(2)
                    local expression "`expression'*(`source'==`level')"
                }
                assert inlist("`role'","main","interaction")
                assert `v'==`expression'
            }
        }
        local unique_centered : list uniq centered
        assert `: word count `centered''==`: word count `cont''
        assert `: list unique_centered == cont'
        quietly fvgen, drop
        assert r(k_dropped)==`: word count `generated''
    }
end
local ++tests
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541)
    _qa_fv_matrix ""
}
if _rc local ++fail
else local ++pass
local ++tests
* expect: EXACT
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541) perturb(separate)
    _qa_fv_matrix "separate"
}
if _rc local ++fail
else local ++pass
local ++tests
* expect: EXACT
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541) perturb(collinear)
    _qa_fv_matrix "collinear"
}
if _rc local ++fail
else local ++pass
local ++tests
* expect: EXACT
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541) perturb(single_level)
    _qa_fv_matrix "single_level"
}
if _rc local ++fail
else local ++pass
local ++tests
* expect: EXACT
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541) perturb(base_absent)
    _qa_fv_matrix "base_absent"
}
if _rc local ++fail
else local ++pass
local ++tests
* expect: INVARIANT
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541) perturb(codes_multidigit)
    _qa_fv_matrix "codes_multidigit"
}
if _rc local ++fail
else local ++pass
local ++tests
* expect: EXACT
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541) perturb(miss_subgroup)
    _qa_fv_matrix "miss_subgroup"
}
if _rc local ++fail
else local ++pass
local ++tests
* expect: REFUSED
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541) perturb(miss_all_column)
    _qa_fv_matrix "miss_all_column"
}
if _rc local ++fail
else local ++pass
local ++tests
* expect: EXACT
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541) perturb(zero_weight)
    _qa_fv_matrix "zero_weight"
}
if _rc local ++fail
else local ++pass
local ++tests
* expect: EXACT
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541) perturb(extreme_weight)
    _qa_fv_matrix "extreme_weight"
}
if _rc local ++fail
else local ++pass
local ++tests
* expect: EXACT
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541) perturb(near_positivity)
    _qa_fv_matrix "near_positivity"
}
if _rc local ++fail
else local ++pass
local ++tests
* expect: SHIFTED
capture noisily {
    qa_fx_a1_logit, clear n(360) seed(541) perturb(scale_shift)
    _qa_fv_matrix "scale_shift"
}
if _rc local ++fail
else local ++pass

foreach op in friendly unsorted {
    local ++tests
    capture noisily {
        if "`op'"=="friendly" qa_fx_a1_gauss, clear n(360) sigma(1) seed(541)
        * expect: EXACT (native-factor stored/active clone and derivatives)
        if "`op'"=="unsorted" qa_fx_a1_gauss, clear n(360) sigma(1) seed(541) perturb(unsorted)
        generate double cat2=xcat==2
        generate double cat3=xcat==3
        generate double one=1
        generate double wanted=.
        mata: X=st_data(.,tokens("a x1 x2 cat2 cat3 one")); B=invsym(cross(X,X))*cross(X,st_data(.,"y")); st_store(.,"wanted",X*B); st_numscalar("slope",B[2])
        quietly fvgen c.a c.x1 c.x2 i.xcat, prefix(fx_)
        local regressors "`r(allvars)'"
        quietly regress y `regressors'
        quietly predict double flat
        assert !missing(flat,wanted) & abs(flat-wanted)<1e-8
        * A replace control already owns this native esample marker.
        estimates store fx_native
        qa_state_snapshot, tag(clone)
        quietly fvgen, margins store(fx_native) replace
        assert "`r(margins)'"=="stored" & "`r(stored)'"=="fx_native"
        qa_state_compare, tag(clone)
        estimates restore fx_native
        quietly predict double clone
        assert !missing(clone,wanted) & abs(clone-wanted)<1e-8
        quietly margins, dydx(x1)
        matrix effect=r(b)
        qa_assert_equal effect[1,1] slope, property("independent native-factor clone derivative") tol(1e-10)
        quietly regress y `regressors'
        quietly fvgen, margins
        assert "`r(margins)'"=="active"
        quietly predict double active
        assert !missing(active,wanted) & abs(active-wanted)<1e-8
    }
    if _rc local ++fail
    else local ++pass
}
display "RESULT: validation_fixture_matrix tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
