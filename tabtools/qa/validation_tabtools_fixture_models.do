*! validation_tabtools_fixture_models.do -- canonical labelled designs and independent contents
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using "validation_tabtools_fixture_models.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
do _qa_hostile.do
local tests 0
local pass 0
local fail 0
do _qa_fx_a1.do
do _qa_fx_a6.do
* Oracle: direct full-rank cell least squares, not native regression output.
* Stata regress manual Methods/formulas fetched2026-09-30:
* https://www.stata.com/manuals/rregress.pdf
mata:
void _qa_tt_ols(string scalar out)
{
    real matrix X, V, T
    real colvector y, bb, rr, ss, cat
    real scalar df, z
    cat=st_data(.,"xcat")
    X=(st_data(.,("a","x1","x2")),cat:==max(select(cat,cat:<max(cat))),cat:==max(cat),J(st_nobs(),1,1))
    y=st_data(.,"y")
    bb=luinv(cross(X,X))*cross(X,y)
    rr=y-X*bb
    df=rows(X)-cols(X)
    V=quadcross(rr,rr)/df*luinv(cross(X,X))
    ss=sqrt(diagonal(V))
    z=invttail(df,.025)
    T=(bb,bb-z*ss,bb+z*ss,2*ttail(df,abs(bb:/ss)))
    st_matrix(out,T)
}
end

**# Effect matrix exact friendly
local ++tests
capture noisily {
    qa_fx_a6_estmat, clear seed(37)
    tempname source display analytic
    * Adapter keeps coefficient order/identity and the four documented columns.
    matrix `source'=r(truth_table)
    matrix `source'=(`source'[1,1...] \ `source'[3,1...] \ `source'[4,1...] \ `source'[5,1...])'
    local terms : rownames `source'
    qa_state_snapshot, tag(tt_model)
    quietly effecttab, from(`source') type(margins) frame(`display') eplotframe(`analytic') digits(4) pdp(4) highpdp(3)
    assert r(N_rows)==6 & r(N_cols)==5 & `"`r(type)'"'=="margins"
    forvalues j=1/3 {
        local rawterm : word `j' of `terms'
        local index=0
        forvalues i=1/3 {
            if term[`i']=="`rawterm'" local index=`i'
        }
        assert `index'>0
        local term=subinstr("`rawterm'","_cons","cons",.)
        frame `analytic': assert _N==3 & strtrim(label[`j'])=="`term'"
        local target=b[`index']
        frame `analytic': assert !missing(estimate[`j']) & abs(estimate[`j']-`target')<1e-14
        foreach field in ll ul p {
            local v=`field'[`index']
            local targetvar=cond("`field'"=="p","pvalue","`field'")
            if missing(`v') {
                frame `analytic': assert missing(`targetvar'[`j'])
            }
            else {
                frame `analytic': assert !missing(`targetvar'[`j']) & abs(`targetvar'[`j']-`v')<1e-12
            }
        }
        local formatted=strtrim(string(b[`index'],"%12.4f"))
        frame `display': assert strtrim(A[`j'+3])=="`term'" & strtrim(c1[`j'+3])=="`formatted'"
    }
    frame drop `display' `analytic'
    qa_state_compare, tag(tt_model)

}
local outcome=_rc
capture frame drop `display'
capture frame drop `analytic'
if `outcome' {
    local ++fail
    display as error "FAIL: Effect matrix exact friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Effect matrix exact friendly"
}

**# Effect matrix exact factor_names
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(factor_names)
    tempname source display analytic
    * Adapter keeps coefficient order/identity and the four documented columns.
    matrix `source'=r(truth_table)
    matrix `source'=(`source'[1,1...] \ `source'[3,1...] \ `source'[4,1...] \ `source'[5,1...])'
    local terms : rownames `source'
    qa_state_snapshot, tag(tt_model)
    quietly effecttab, from(`source') type(margins) frame(`display') eplotframe(`analytic') digits(4) pdp(4) highpdp(3)
    assert r(N_rows)==6 & r(N_cols)==5 & `"`r(type)'"'=="margins"
    forvalues j=1/3 {
        local rawterm : word `j' of `terms'
        local index=0
        forvalues i=1/3 {
            if term[`i']=="`rawterm'" local index=`i'
        }
        assert `index'>0
        local term=subinstr("`rawterm'","_cons","cons",.)
        frame `analytic': assert _N==3 & strtrim(label[`j'])=="`term'"
        local target=b[`index']
        frame `analytic': assert !missing(estimate[`j']) & abs(estimate[`j']-`target')<1e-14
        foreach field in ll ul p {
            local v=`field'[`index']
            local targetvar=cond("`field'"=="p","pvalue","`field'")
            if missing(`v') {
                frame `analytic': assert missing(`targetvar'[`j'])
            }
            else {
                frame `analytic': assert !missing(`targetvar'[`j']) & abs(`targetvar'[`j']-`v')<1e-12
            }
        }
        local formatted=strtrim(string(b[`index'],"%12.4f"))
        frame `display': assert strtrim(A[`j'+3])=="`term'" & strtrim(c1[`j'+3])=="`formatted'"
    }
    frame drop `display' `analytic'
    qa_state_compare, tag(tt_model)

}
local outcome=_rc
capture frame drop `display'
capture frame drop `analytic'
if `outcome' {
    local ++fail
    display as error "FAIL: Effect matrix exact factor_names; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Effect matrix exact factor_names"
}

**# Effect matrix exact long_row_names
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(long_row_names)
    tempname source display analytic
    * Adapter keeps coefficient order/identity and the four documented columns.
    matrix `source'=r(truth_table)
    matrix `source'=(`source'[1,1...] \ `source'[3,1...] \ `source'[4,1...] \ `source'[5,1...])'
    local terms : rownames `source'
    qa_state_snapshot, tag(tt_model)
    quietly effecttab, from(`source') type(margins) frame(`display') eplotframe(`analytic') digits(4) pdp(4) highpdp(3)
    assert r(N_rows)==6 & r(N_cols)==5 & `"`r(type)'"'=="margins"
    forvalues j=1/3 {
        local rawterm : word `j' of `terms'
        local index=0
        forvalues i=1/3 {
            if term[`i']=="`rawterm'" local index=`i'
        }
        assert `index'>0
        local term=subinstr("`rawterm'","_cons","cons",.)
        frame `analytic': assert _N==3 & strtrim(label[`j'])=="`term'"
        local target=b[`index']
        frame `analytic': assert !missing(estimate[`j']) & abs(estimate[`j']-`target')<1e-14
        foreach field in ll ul p {
            local v=`field'[`index']
            local targetvar=cond("`field'"=="p","pvalue","`field'")
            if missing(`v') {
                frame `analytic': assert missing(`targetvar'[`j'])
            }
            else {
                frame `analytic': assert !missing(`targetvar'[`j']) & abs(`targetvar'[`j']-`v')<1e-12
            }
        }
        local formatted=strtrim(string(b[`index'],"%12.4f"))
        frame `display': assert strtrim(A[`j'+3])=="`term'" & strtrim(c1[`j'+3])=="`formatted'"
    }
    frame drop `display' `analytic'
    qa_state_compare, tag(tt_model)

}
local outcome=_rc
capture frame drop `display'
capture frame drop `analytic'
if `outcome' {
    local ++fail
    display as error "FAIL: Effect matrix exact long_row_names; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Effect matrix exact long_row_names"
}

**# Effect matrix exact boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(boundary_values)
    tempname source display analytic
    * Adapter keeps coefficient order/identity and the four documented columns.
    matrix `source'=r(truth_table)
    matrix `source'=(`source'[1,1...] \ `source'[3,1...] \ `source'[4,1...] \ `source'[5,1...])'
    local terms : rownames `source'
    qa_state_snapshot, tag(tt_model)
    quietly effecttab, from(`source') type(margins) frame(`display') eplotframe(`analytic') digits(4) pdp(4) highpdp(3)
    assert r(N_rows)==6 & r(N_cols)==5 & `"`r(type)'"'=="margins"
    forvalues j=1/3 {
        local rawterm : word `j' of `terms'
        local index=0
        forvalues i=1/3 {
            if term[`i']=="`rawterm'" local index=`i'
        }
        assert `index'>0
        local term=subinstr("`rawterm'","_cons","cons",.)
        frame `analytic': assert _N==3 & strtrim(label[`j'])=="`term'"
        local target=b[`index']
        frame `analytic': assert !missing(estimate[`j']) & abs(estimate[`j']-`target')<1e-14
        foreach field in ll ul p {
            local v=`field'[`index']
            local targetvar=cond("`field'"=="p","pvalue","`field'")
            if missing(`v') {
                frame `analytic': assert missing(`targetvar'[`j'])
            }
            else {
                frame `analytic': assert !missing(`targetvar'[`j']) & abs(`targetvar'[`j']-`v')<1e-12
            }
        }
        local formatted=strtrim(string(b[`index'],"%12.4f"))
        frame `display': assert strtrim(A[`j'+3])=="`term'" & strtrim(c1[`j'+3])=="`formatted'"
    }
    frame drop `display' `analytic'
    qa_state_compare, tag(tt_model)

}
local outcome=_rc
capture frame drop `display'
capture frame drop `analytic'
if `outcome' {
    local ++fail
    display as error "FAIL: Effect matrix exact boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Effect matrix exact boundary_values"
}

**# Effect matrix exact missing_se
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(missing_se)
    tempname source display analytic
    * Adapter keeps coefficient order/identity and the four documented columns.
    matrix `source'=r(truth_table)
    matrix `source'=(`source'[1,1...] \ `source'[3,1...] \ `source'[4,1...] \ `source'[5,1...])'
    local terms : rownames `source'
    qa_state_snapshot, tag(tt_model)
    quietly effecttab, from(`source') type(margins) frame(`display') eplotframe(`analytic') digits(4) pdp(4) highpdp(3)
    assert r(N_rows)==6 & r(N_cols)==5 & `"`r(type)'"'=="margins"
    forvalues j=1/3 {
        local rawterm : word `j' of `terms'
        local index=0
        forvalues i=1/3 {
            if term[`i']=="`rawterm'" local index=`i'
        }
        assert `index'>0
        local term=subinstr("`rawterm'","_cons","cons",.)
        frame `analytic': assert _N==3 & strtrim(label[`j'])=="`term'"
        local target=b[`index']
        frame `analytic': assert !missing(estimate[`j']) & abs(estimate[`j']-`target')<1e-14
        foreach field in ll ul p {
            local v=`field'[`index']
            local targetvar=cond("`field'"=="p","pvalue","`field'")
            if missing(`v') {
                frame `analytic': assert missing(`targetvar'[`j'])
            }
            else {
                frame `analytic': assert !missing(`targetvar'[`j']) & abs(`targetvar'[`j']-`v')<1e-12
            }
        }
        local formatted=strtrim(string(b[`index'],"%12.4f"))
        frame `display': assert strtrim(A[`j'+3])=="`term'" & strtrim(c1[`j'+3])=="`formatted'"
    }
    frame drop `display' `analytic'
    qa_state_compare, tag(tt_model)

}
local outcome=_rc
capture frame drop `display'
capture frame drop `analytic'
if `outcome' {
    local ++fail
    display as error "FAIL: Effect matrix exact missing_se; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Effect matrix exact missing_se"
}

**# Effect matrix exact infinite_ci
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(infinite_ci)
    tempname source display analytic
    * Adapter keeps coefficient order/identity and the four documented columns.
    matrix `source'=r(truth_table)
    matrix `source'=(`source'[1,1...] \ `source'[3,1...] \ `source'[4,1...] \ `source'[5,1...])'
    local terms : rownames `source'
    qa_state_snapshot, tag(tt_model)
    quietly effecttab, from(`source') type(margins) frame(`display') eplotframe(`analytic') digits(4) pdp(4) highpdp(3)
    assert r(N_rows)==6 & r(N_cols)==5 & `"`r(type)'"'=="margins"
    forvalues j=1/3 {
        local rawterm : word `j' of `terms'
        local index=0
        forvalues i=1/3 {
            if term[`i']=="`rawterm'" local index=`i'
        }
        assert `index'>0
        local term=subinstr("`rawterm'","_cons","cons",.)
        frame `analytic': assert _N==3 & strtrim(label[`j'])=="`term'"
        local target=b[`index']
        frame `analytic': assert !missing(estimate[`j']) & abs(estimate[`j']-`target')<1e-14
        foreach field in ll ul p {
            local v=`field'[`index']
            local targetvar=cond("`field'"=="p","pvalue","`field'")
            if missing(`v') {
                frame `analytic': assert missing(`targetvar'[`j'])
            }
            else {
                frame `analytic': assert !missing(`targetvar'[`j']) & abs(`targetvar'[`j']-`v')<1e-12
            }
        }
        local formatted=strtrim(string(b[`index'],"%12.4f"))
        frame `display': assert strtrim(A[`j'+3])=="`term'" & strtrim(c1[`j'+3])=="`formatted'"
    }
    frame drop `display' `analytic'
    qa_state_compare, tag(tt_model)

}
local outcome=_rc
capture frame drop `display'
capture frame drop `analytic'
if `outcome' {
    local ++fail
    display as error "FAIL: Effect matrix exact infinite_ci; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Effect matrix exact infinite_ci"
}

**# Effect matrix exact omitted
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(omitted)
    tempname source display analytic
    * Adapter keeps coefficient order/identity and the four documented columns.
    matrix `source'=r(truth_table)
    matrix `source'=(`source'[1,1...] \ `source'[3,1...] \ `source'[4,1...] \ `source'[5,1...])'
    local terms : rownames `source'
    qa_state_snapshot, tag(tt_model)
    quietly effecttab, from(`source') type(margins) frame(`display') eplotframe(`analytic') digits(4) pdp(4) highpdp(3)
    assert r(N_rows)==6 & r(N_cols)==5 & `"`r(type)'"'=="margins"
    forvalues j=1/3 {
        local rawterm : word `j' of `terms'
        local index=0
        forvalues i=1/3 {
            if term[`i']=="`rawterm'" local index=`i'
        }
        assert `index'>0
        local term=subinstr("`rawterm'","_cons","cons",.)
        frame `analytic': assert _N==3 & strtrim(label[`j'])=="`term'"
        local target=b[`index']
        frame `analytic': assert !missing(estimate[`j']) & abs(estimate[`j']-`target')<1e-14
        foreach field in ll ul p {
            local v=`field'[`index']
            local targetvar=cond("`field'"=="p","pvalue","`field'")
            if missing(`v') {
                frame `analytic': assert missing(`targetvar'[`j'])
            }
            else {
                frame `analytic': assert !missing(`targetvar'[`j']) & abs(`targetvar'[`j']-`v')<1e-12
            }
        }
        local formatted=strtrim(string(b[`index'],"%12.4f"))
        frame `display': assert strtrim(A[`j'+3])=="`term'" & strtrim(c1[`j'+3])=="`formatted'"
    }
    frame drop `display' `analytic'
    qa_state_compare, tag(tt_model)

}
local outcome=_rc
capture frame drop `display'
capture frame drop `analytic'
if `outcome' {
    local ++fail
    display as error "FAIL: Effect matrix exact omitted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Effect matrix exact omitted"
}

**# Effect matrix exact base_rows
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(base_rows)
    tempname source display analytic
    * Adapter keeps coefficient order/identity and the four documented columns.
    matrix `source'=r(truth_table)
    matrix `source'=(`source'[1,1...] \ `source'[3,1...] \ `source'[4,1...] \ `source'[5,1...])'
    local terms : rownames `source'
    qa_state_snapshot, tag(tt_model)
    quietly effecttab, from(`source') type(margins) frame(`display') eplotframe(`analytic') digits(4) pdp(4) highpdp(3)
    assert r(N_rows)==6 & r(N_cols)==5 & `"`r(type)'"'=="margins"
    forvalues j=1/3 {
        local rawterm : word `j' of `terms'
        local index=0
        forvalues i=1/3 {
            if term[`i']=="`rawterm'" local index=`i'
        }
        assert `index'>0
        local term=subinstr("`rawterm'","_cons","cons",.)
        frame `analytic': assert _N==3 & strtrim(label[`j'])=="`term'"
        local target=b[`index']
        frame `analytic': assert !missing(estimate[`j']) & abs(estimate[`j']-`target')<1e-14
        foreach field in ll ul p {
            local v=`field'[`index']
            local targetvar=cond("`field'"=="p","pvalue","`field'")
            if missing(`v') {
                frame `analytic': assert missing(`targetvar'[`j'])
            }
            else {
                frame `analytic': assert !missing(`targetvar'[`j']) & abs(`targetvar'[`j']-`v')<1e-12
            }
        }
        local formatted=strtrim(string(b[`index'],"%12.4f"))
        frame `display': assert strtrim(A[`j'+3])=="`term'" & strtrim(c1[`j'+3])=="`formatted'"
    }
    frame drop `display' `analytic'
    qa_state_compare, tag(tt_model)

}
local outcome=_rc
capture frame drop `display'
capture frame drop `analytic'
if `outcome' {
    local ++fail
    display as error "FAIL: Effect matrix exact base_rows; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Effect matrix exact base_rows"
}

**# Effect matrix exact positional_mismatch
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(positional_mismatch)
    tempname source display analytic
    * Adapter keeps coefficient order/identity and the four documented columns.
    matrix `source'=r(truth_table)
    matrix `source'=(`source'[1,1...] \ `source'[3,1...] \ `source'[4,1...] \ `source'[5,1...])'
    local terms : rownames `source'
    qa_state_snapshot, tag(tt_model)
    quietly effecttab, from(`source') type(margins) frame(`display') eplotframe(`analytic') digits(4) pdp(4) highpdp(3)
    assert r(N_rows)==6 & r(N_cols)==5 & `"`r(type)'"'=="margins"
    forvalues j=1/3 {
        local rawterm : word `j' of `terms'
        local index=0
        forvalues i=1/3 {
            if term[`i']=="`rawterm'" local index=`i'
        }
        assert `index'>0
        local term=subinstr("`rawterm'","_cons","cons",.)
        frame `analytic': assert _N==3 & strtrim(label[`j'])=="`term'"
        local target=b[`index']
        frame `analytic': assert !missing(estimate[`j']) & abs(estimate[`j']-`target')<1e-14
        foreach field in ll ul p {
            local v=`field'[`index']
            local targetvar=cond("`field'"=="p","pvalue","`field'")
            if missing(`v') {
                frame `analytic': assert missing(`targetvar'[`j'])
            }
            else {
                frame `analytic': assert !missing(`targetvar'[`j']) & abs(`targetvar'[`j']-`v')<1e-12
            }
        }
        local formatted=strtrim(string(b[`index'],"%12.4f"))
        frame `display': assert strtrim(A[`j'+3])=="`term'" & strtrim(c1[`j'+3])=="`formatted'"
    }
    frame drop `display' `analytic'
    qa_state_compare, tag(tt_model)

}
local outcome=_rc
capture frame drop `display'
capture frame drop `analytic'
if `outcome' {
    local ++fail
    display as error "FAIL: Effect matrix exact positional_mismatch; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Effect matrix exact positional_mismatch"
}

**# Collected Gaussian exact friendly
local ++tests
capture noisily {
    qa_fx_a1_gauss, clear tier(micro) seed(37)
    tempname truth display analytic
    * Missing-all design tests refusal before publication, not fitted truth.
    mata: _qa_tt_ols("`truth'")
    collect clear
    quietly collect: regress y a x1 x2 i.xcat
    qa_state_snapshot, tag(tt_model)
    quietly regtab, frame(`display') eplotframe(`analytic') noint digits(4) pdp(4) highpdp(3)
    assert r(N_models)==1 & r(ci_level)==95
    forvalues j=1/5 {
        local wanted=cond(`j'<=3,word("a x1 x2",`j'),string(cond(""=="codes_sparse",cond(`j'==4,5,17),`j'-2)))
        frame `analytic': quietly count if strtrim(label)=="`wanted'" & rowtype=="effect"
        assert r(N)==1
        forvalues k=1/4 {
            local field : word `k' of estimate ll ul pvalue
            local target=`truth'[`j',`k']
            assert !missing(`target')
            frame `analytic': assert !missing(`field') & abs(`field'-`target')<1e-10 if strtrim(label)=="`wanted'" & rowtype=="effect"
        }
    }
    frame `analytic': assert _N==6
    frame `analytic': assert rowtype=="reference" & missing(estimate,ll,ul,pvalue) if strtrim(label)=="1"
    frame drop `display' `analytic'
    qa_state_compare, tag(tt_model)

}
local outcome=_rc
capture frame drop `display'
capture frame drop `analytic'
if `outcome' {
    local ++fail
    display as error "FAIL: Collected Gaussian exact friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Collected Gaussian exact friendly"
}

**# Collected Gaussian exact unsorted
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_gauss, clear tier(micro) seed(37) perturb(unsorted)
    tempname truth display analytic
    * Missing-all design tests refusal before publication, not fitted truth.
    mata: _qa_tt_ols("`truth'")
    collect clear
    quietly collect: regress y a x1 x2 i.xcat
    qa_state_snapshot, tag(tt_model)
    quietly regtab, frame(`display') eplotframe(`analytic') noint digits(4) pdp(4) highpdp(3)
    assert r(N_models)==1 & r(ci_level)==95
    forvalues j=1/5 {
        local wanted=cond(`j'<=3,word("a x1 x2",`j'),string(cond("unsorted"=="codes_sparse",cond(`j'==4,5,17),`j'-2)))
        frame `analytic': quietly count if strtrim(label)=="`wanted'" & rowtype=="effect"
        assert r(N)==1
        forvalues k=1/4 {
            local field : word `k' of estimate ll ul pvalue
            local target=`truth'[`j',`k']
            assert !missing(`target')
            frame `analytic': assert !missing(`field') & abs(`field'-`target')<1e-10 if strtrim(label)=="`wanted'" & rowtype=="effect"
        }
    }
    frame `analytic': assert _N==6
    frame `analytic': assert rowtype=="reference" & missing(estimate,ll,ul,pvalue) if strtrim(label)=="1"
    frame drop `display' `analytic'
    qa_state_compare, tag(tt_model)

}
local outcome=_rc
capture frame drop `display'
capture frame drop `analytic'
if `outcome' {
    local ++fail
    display as error "FAIL: Collected Gaussian exact unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Collected Gaussian exact unsorted"
}

**# Collected Gaussian exact codes_sparse
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_gauss, clear tier(micro) seed(37) perturb(codes_sparse)
    tempname truth display analytic
    * Missing-all design tests refusal before publication, not fitted truth.
    mata: _qa_tt_ols("`truth'")
    collect clear
    quietly collect: regress y a x1 x2 i.xcat
    qa_state_snapshot, tag(tt_model)
    quietly regtab, frame(`display') eplotframe(`analytic') noint digits(4) pdp(4) highpdp(3)
    assert r(N_models)==1 & r(ci_level)==95
    forvalues j=1/5 {
        local wanted=cond(`j'<=3,word("a x1 x2",`j'),string(cond("codes_sparse"=="codes_sparse",cond(`j'==4,5,17),`j'-2)))
        frame `analytic': quietly count if strtrim(label)=="`wanted'" & rowtype=="effect"
        assert r(N)==1
        forvalues k=1/4 {
            local field : word `k' of estimate ll ul pvalue
            local target=`truth'[`j',`k']
            assert !missing(`target')
            frame `analytic': assert !missing(`field') & abs(`field'-`target')<1e-10 if strtrim(label)=="`wanted'" & rowtype=="effect"
        }
    }
    frame `analytic': assert _N==6
    frame `analytic': assert rowtype=="reference" & missing(estimate,ll,ul,pvalue) if strtrim(label)=="1"
    frame drop `display' `analytic'
    qa_state_compare, tag(tt_model)

}
local outcome=_rc
capture frame drop `display'
capture frame drop `analytic'
if `outcome' {
    local ++fail
    display as error "FAIL: Collected Gaussian exact codes_sparse; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Collected Gaussian exact codes_sparse"
}

**# Collected Gaussian exact miss_all_column
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a1_gauss, clear tier(micro) seed(37) perturb(miss_all_column)
    tempname truth display analytic
    * Missing-all design tests refusal before publication, not fitted truth.
    collect clear
    capture noisily collect: regress y a x1 x2 i.xcat
    assert _rc==2000
    qa_state_snapshot, tag(tt_model)
    capture noisily regtab, frame(`display') digits(4)
    assert _rc==119
    qa_state_compare, tag(tt_model)

}
local outcome=_rc
capture frame drop `display'
capture frame drop `analytic'
if `outcome' {
    local ++fail
    display as error "FAIL: Collected Gaussian exact miss_all_column; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Collected Gaussian exact miss_all_column"
}

**# Composite selected identity friendly
local ++tests
capture noisily {
    qa_fx_a6_estmat, clear seed(37)
    tempname source display composite
    quietly mkmat b ll ul p, matrix(`source')
    local terms ""
    forvalues j=1/3 {
        local terms `terms' `=term[`j']'
    }
    matrix rownames `source'=`terms'
    quietly effecttab, from(`source') frame(`display') digits(4)
    qa_state_snapshot, tag(tt_composite)
    quietly comptab `display' `display', rows(1 3 \ 2) frame(`composite') separator(1 3)
    assert r(N_rows)==6 & r(N_frames)==2 & r(N_models)==1
    forvalues j=1/3 {
        local index : word `j' of 1 3 2
        local term=subinstr(term[`index'],"_cons","cons",.)
        local target=strtrim(string(b[`index'],"%12.4f"))
        frame `composite': assert strtrim(A[`j'+3])=="`term'" & strtrim(c1[`j'+3])=="`target'"
    }
    frame drop `composite'
    qa_state_compare, tag(tt_composite)
    frame drop `display'

}
local outcome=_rc
capture frame drop `display'
capture frame drop `composite'
if `outcome' {
    local ++fail
    display as error "FAIL: Composite selected identity friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Composite selected identity friendly"
}

**# Composite selected identity boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(boundary_values)
    tempname source display composite
    quietly mkmat b ll ul p, matrix(`source')
    local terms ""
    forvalues j=1/3 {
        local terms `terms' `=term[`j']'
    }
    matrix rownames `source'=`terms'
    quietly effecttab, from(`source') frame(`display') digits(4)
    qa_state_snapshot, tag(tt_composite)
    quietly comptab `display' `display', rows(1 3 \ 2) frame(`composite') separator(1 3)
    assert r(N_rows)==6 & r(N_frames)==2 & r(N_models)==1
    forvalues j=1/3 {
        local index : word `j' of 1 3 2
        local term=subinstr(term[`index'],"_cons","cons",.)
        local target=strtrim(string(b[`index'],"%12.4f"))
        frame `composite': assert strtrim(A[`j'+3])=="`term'" & strtrim(c1[`j'+3])=="`target'"
    }
    frame drop `composite'
    qa_state_compare, tag(tt_composite)
    frame drop `display'

}
local outcome=_rc
capture frame drop `display'
capture frame drop `composite'
if `outcome' {
    local ++fail
    display as error "FAIL: Composite selected identity boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Composite selected identity boundary_values"
}

**# Composite selected identity long_row_names
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(long_row_names)
    tempname source display composite
    quietly mkmat b ll ul p, matrix(`source')
    local terms ""
    forvalues j=1/3 {
        local terms `terms' `=term[`j']'
    }
    matrix rownames `source'=`terms'
    quietly effecttab, from(`source') frame(`display') digits(4)
    qa_state_snapshot, tag(tt_composite)
    quietly comptab `display' `display', rows(1 3 \ 2) frame(`composite') separator(1 3)
    assert r(N_rows)==6 & r(N_frames)==2 & r(N_models)==1
    forvalues j=1/3 {
        local index : word `j' of 1 3 2
        local term=subinstr(term[`index'],"_cons","cons",.)
        local target=strtrim(string(b[`index'],"%12.4f"))
        frame `composite': assert strtrim(A[`j'+3])=="`term'" & strtrim(c1[`j'+3])=="`target'"
    }
    frame drop `composite'
    qa_state_compare, tag(tt_composite)
    frame drop `display'

}
local outcome=_rc
capture frame drop `display'
capture frame drop `composite'
if `outcome' {
    local ++fail
    display as error "FAIL: Composite selected identity long_row_names; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Composite selected identity long_row_names"
}

**# Catalogue exact friendly
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    * Catalogue truth is the public command inventory, independent of data.
    qa_state_snapshot, tag(tt_catalogue)
    quietly tabtools, list category(all)
    assert `"`r(commands)'"'=="table1_tc desctab crosstab corrtab regtab effecttab stratetab survtab comptab hrcomptab puttab stacktab tabtools tabtools_tips"
    assert r(n_commands)==14
    qa_state_compare, tag(tt_catalogue)
    qa_state_snapshot, tag(tt_catalogue)
    quietly tabtools, list category(composite)
    assert r(n_commands)==2 & `"`r(commands)'"'=="comptab hrcomptab"
    qa_state_compare, tag(tt_catalogue)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Catalogue exact friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Catalogue exact friendly"
}

**# Catalogue exact unsorted
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    * Catalogue truth is the public command inventory, independent of data.
    qa_state_snapshot, tag(tt_catalogue)
    quietly tabtools, list category(all)
    assert `"`r(commands)'"'=="table1_tc desctab crosstab corrtab regtab effecttab stratetab survtab comptab hrcomptab puttab stacktab tabtools tabtools_tips"
    assert r(n_commands)==14
    qa_state_compare, tag(tt_catalogue)
    qa_state_snapshot, tag(tt_catalogue)
    quietly tabtools, list category(composite)
    assert r(n_commands)==2 & `"`r(commands)'"'=="comptab hrcomptab"
    qa_state_compare, tag(tt_catalogue)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Catalogue exact unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Catalogue exact unsorted"
}

display "RESULT: validation_tabtools_fixture_models tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
