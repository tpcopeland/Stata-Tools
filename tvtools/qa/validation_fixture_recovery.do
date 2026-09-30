*! validation_fixture_recovery.do — canonical F/U numerical contract for tvtools
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
log using "validation_fixture_recovery.log", replace text nomsg
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
adopath ++ "`pkg_dir'"
do "`qa_dir'/_qa_fx_a4.do"
do "`qa_dir'/_qa_state.do"

capture program drop _fx_tvtools_1
program define _fx_tvtools_1, rclass
    version 16.0
    args op fixtureopts
    tempfile fx_input
    tempname fx_returns
    _return hold `fx_returns'
    quietly save `fx_input'
    local tests=0
    local pass=0
    local fail=0

    foreach model in logit mlogit {
    foreach route in iptw ato matching stabilized {
        local ++tests
        capture noisily {
            quietly use `fx_input', clear
                _return restore `fx_returns', hold
            tempname Cells
            matrix `Cells'=r(truth_cells)
            gen double canonical_s=s
            if inlist("`op'","codes_multidigit","codes_sparse") replace canonical_s=cond(s==1,0,1)
            gen double p=.
            forvalues j=1/4 {
                local row=2*`j'
                replace p=`Cells'[`row',4]/(`Cells'[`row',4]+`Cells'[`row'-1,4]) if canonical_s==`Cells'[`row',1] & x2==`Cells'[`row',2]
            }
            assert !missing(p)
            gen double want=cond(a,1/p,1/(1-p))
            local opts "wtype(`route')"
            if "`route'"=="ato" replace want=cond(a,1-p,p)
            if "`route'"=="matching" replace want=min(p,1-p)*want
            if "`route'"=="stabilized" {
                replace want=.5*want
                local opts "stabilized"
            }
            gen double expected_ps=p
            if "`model'"=="mlogit" {
                * Each canonical treated cell has an even count. Split it
                * exactly into two treatment categories; empirical category
                * probabilities are (1-p,p/2,p/2), all independently known.
                replace a=cond(a,1+mod(id,2),0)
                replace expected_ps=cond(a,p/2,1-p)
                replace want=1/expected_ps
                if "`route'"=="ato" replace want=(1/(1/(1-p)+4/p))*want
                if "`route'"=="matching" replace want=min(p/2,1-p)*want
                if "`route'"=="stabilized" replace want=cond(a,.25,.5)*want
            }
            qa_state_snapshot, tag(tvwt_f)
            tvweight a, covariates(i.s##i.x2) generate(got) denominator(ps) `opts' model(`model') nolog
            qa_state_compare, tag(tvwt_f) allow(data)
            assert !missing(got,want,ps,p)
            gen double numerical_error=max(reldif(got,want),reldif(ps,expected_ps))
            quietly summarize numerical_error, meanonly
            di "ORACLE tvweight `op' `route': maximum relative numerical error=" r(max)
            * Native logit's default convergence leaves residuals up to6e-8
            * in these exact cells; 1e-7 is a numerical optimization bound.
            assert numerical_error<1e-7
        }
        local case_rc=_rc
        if `case_rc'==0 local ++pass
        else {
            local ++fail
            di as error "FAIL tvweight `op' `route' rc=`case_rc'"
        }
    }

    }
    capture _return restore `fx_returns'
    return scalar qa_tests=`tests'
    return scalar qa_pass=`pass'
    return scalar qa_fail=`fail'
end

local tests=0
local pass=0
local fail=0

do "`qa_dir'/_qa_fx_a1.do"
**# All binary weighting targets and stabilization: exact saturated PS cells
qa_fx_a1_sat, clear
_fx_tvtools_1 friendly ""
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a1_sat, clear perturb(unsorted)
_fx_tvtools_1 unsorted "perturb(unsorted)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a1_sat, clear perturb(codes_multidigit)
_fx_tvtools_1 codes_multidigit "perturb(codes_multidigit)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a1_sat, clear perturb(codes_sparse)
_fx_tvtools_1 codes_sparse "perturb(codes_sparse)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
di "RESULT: validation_fixture_recovery tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
