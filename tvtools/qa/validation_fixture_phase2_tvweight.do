*! validation_fixture_phase2_tvweight.do  2026/09/30
*! Author: Timothy P Copeland, Karolinska Institutet
*! Numerical scope: exact saturated-cell targets, estimator relations, double outputs.
clear all
version 16.0
set more off
set varabbrev off
capture log close _all
log using "validation_fixture_phase2_tvweight.log", text replace name(phase2)
local pkg=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkg'"
do _qa_fx_a1.do
do _qa_metamorphic.do
capture program drop _p2_tv_relation
program define _p2_tv_relation, rclass
    version 16.0
    syntax , TREATMENT(varname) [COVARIATES(string) GENerate(name) PS(name) ORDER(numlist)]
    if "`covariates'"=="" local covariates "i.s##i.x2"
    if "`order'"!="" {
        local canonical : list sort order
        assert "`canonical'"=="1 2"
        local covariates ""
        foreach role of numlist `order' {
            if `role'==1 local covariates "`covariates' i.s"
            if `role'==2 local covariates "`covariates' i.x2"
        }
        local covariates "`covariates' i.s#i.x2"
    }
    if "`generate'"=="" local generate _p2_weight
    if "`ps'"=="" local ps _p2_ps
    local N=_N
    tempname Payload
    tempvar probability expected
    local sfield s
    local xfield x2
    capture confirm variable _cell_s
    if !_rc local sfield _cell_s
    capture confirm variable _cell_x2
    if !_rc local xfield _cell_x2
    bysort `sfield' `xfield': egen double `probability'=mean(`treatment')
    generate double `expected'=cond(`treatment',1/`probability',1/(1-`probability'))
    tvweight `treatment', covariates(`covariates') generate(`generate') denominator(`ps') nolog
    assert _N==`N' & !missing(`generate',`ps',`expected',`probability')
    assert reldif(`generate',`expected')<1e-7 & reldif(`ps',`probability')<1e-7
    sort id
    mkmat `generate' `ps', matrix(`Payload')
    return matrix prediction=`Payload'
    return scalar N=`N'
end
local tests=0
local pass=0
local fail=0
foreach source in a s x2 {
    local ++tests
    capture noisily {
        qa_fx_a1_sat, clear
        local command "_p2_tv_relation, treatment(a)"
        if "`source'"=="a" local command "_p2_tv_relation, treatment(@var@)"
        if "`source'"=="s" local command "_p2_tv_relation, treatment(a) covariates(i.@var@##i.x2)"
        if "`source'"=="x2" local command "_p2_tv_relation, treatment(a) covariates(i.s##i.@var@)"
        * Long covariate-name oracle cannot hardcode the renamed raw field.
        * Existing canonical cell truth is saved in a separate original field.
        if "`source'"=="s" clonevar _cell_s=s
        if "`source'"=="x2" clonevar _cell_x2=x2
        * expect: INVARIANT
        qa_metamorphic long_names, command(`command') returns(r(prediction) r(N)) var(`source') tol(1e-9)
    }
    local rc=_rc
    if `rc'==0 local ++pass
    else {
        local ++fail
        di as error "FAIL phase2 TV long source `source' rc=`rc'"
    }
}
foreach relation in unsorted codes_multidigit codes_sparse {
    local ++tests
    capture noisily {
        qa_fx_a1_sat, clear
        clonevar _cell_s=s
        * expect: INVARIANT
        qa_metamorphic `relation', command(_p2_tv_relation, treatment(a)) returns(r(prediction) r(N)) var(s) tol(1e-9)
    }
    local rc=_rc
    if `rc'==0 local ++pass
    else {
        local ++fail
        di as error "FAIL phase2 TV actual helper `relation' rc=`rc'"
    }
}
local ++tests
capture noisily {
    qa_fx_a1_sat, clear
    * expect: INVARIANT
    qa_metamorphic unsorted_list, command(_p2_tv_relation, treatment(a) order(@list@)) returns(r(prediction) r(N)) list(1 2) tol(1e-9)
    di "ORACLE phase2 TV actual unsorted_list covariate adapter: every PS/weight by original ID"
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL phase2 TV covariate order rc=`rc'"
}
local ++tests
capture noisily {
    qa_fx_a1_sat, clear
    tempfile source
    save `source'
    tempname P0 P1
    _p2_tv_relation, treatment(a)
    matrix `P0'=r(prediction)
    use `source', clear
    local w output_weight_123456789012345678
    local ps propensity_123456789012345678901
    assert strlen("`w'")==32 & strlen("`ps'")==32
    _p2_tv_relation, treatment(a) generate(`w') ps(`ps')
    matrix `P1'=r(prediction)
    assert mreldif(`P0',`P1')<1e-9
}
local rc=_rc
if `rc'==0 local ++pass
else {
    local ++fail
    di as error "FAIL phase2 TV32-character output names rc=`rc'"
}
foreach target in iptw ato matching stabilized {
    local ++tests
    capture noisily {
        qa_fx_a1_sat, clear
        * Declared count adapter: four canonical covariate patterns,1001 rows
        * each, treatment counts1/1000/17/984. Finite exact probabilities are
        * close to0/1 and require more than7 significant digits; no Monte Carlo.
        bysort s x2: keep if _n==1
        egen byte cell=group(s x2)
        expand 1001
        bysort cell: generate int within=_n
        replace a=within<=cond(cell==1,1,cond(cell==2,1000,cond(cell==3,17,984)))
        drop id
        generate long id=_n
        bysort cell: egen double empirical=mean(a)
        assert inlist(empirical,1/1001,1000/1001,17/1001,984/1001)
        local opts "wtype(`target')"
        if "`target'"=="stabilized" local opts stabilized
        tvweight a, covariates(i.cell) generate(got) denominator(ps) `opts' nolog
        local wt : type got
        local pt : type ps
        assert "`wt'"=="double" & "`pt'"=="double"
        assert !missing(got,ps) & ps>0 & ps<1
        generate double decrement=(empirical-ps)^2/(ps*(1-ps))
        quietly summarize decrement, meanonly
        * Installed maximize.sthlp250–252: default native nrtolerance1e-5.
        * This constrains optimization separately from output transport.
        assert r(sum)<1e-5
        generate double expected=cond(a,1/ps,1/(1-ps))
        if "`target'"=="ato" replace expected=cond(a,1-ps,ps)
        if "`target'"=="matching" replace expected=min(ps,1-ps)*expected
        if "`target'"=="stabilized" replace expected=.5*expected
        assert !missing(expected) & abs(got-expected)<1e-12*(1+abs(expected))
        quietly summarize ps if cell==1, meanonly
        assert r(mean)<.0011
        quietly summarize ps if cell==2, meanonly
        assert r(mean)>.9989
        di "ORACLE phase2 TV `target': exact observed cell likelihood criterion and raw double formula outputs"
    }
    local rc=_rc
    if `rc'==0 local ++pass
    else {
        local ++fail
        di as error "FAIL phase2 TV precision `target' rc=`rc'"
    }
}
di "RESULT: validation_fixture_phase2_tvweight tests=`tests' pass=`pass' fail=`fail' skip=0"
log close phase2
if `fail'>0 exit 1
