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
local tests=0
local pass=0
local fail=0

do "`qa_dir'/_qa_fx_a1.do"
**# All binary weighting targets and stabilization: exact saturated PS cells
foreach op in friendly unsorted codes_multidigit codes_sparse {
    foreach route in iptw ato matching stabilized {
        local ++tests
        capture noisily {
            if "`op'"=="friendly" qa_fx_a1_sat, clear
            else {
                * expect: EXACT
                qa_fx_a1_sat, clear perturb(`op')
            }
            gen double p=cond(x2==0,cond(s==0,1/3,1/4),cond(s==0,2/3,3/4))
            if inlist("`op'","codes_multidigit","codes_sparse") replace p=cond(x2==0,cond(s==1,1/3,1/4),cond(s==1,2/3,3/4))
            gen double want=cond(a,1/p,1/(1-p))
            local opts "wtype(`route')"
            if "`route'"=="ato" replace want=cond(a,1-p,p)
            if "`route'"=="matching" replace want=min(p,1-p)*want
            if "`route'"=="stabilized" {
                replace want=.5*want
                local opts "stabilized"
            }
            qa_state_snapshot, tag(tvwt_f)
            tvweight a, covariates(i.s##i.x2) generate(got) denominator(ps) `opts' nolog
            qa_state_compare, tag(tvwt_f) allow(data)
            assert !missing(got,want,ps,p) & reldif(got,want)<1e-8 & reldif(ps,p)<1e-8
        }
        if _rc==0 local ++pass
        else local ++fail
    }
}
di "RESULT: validation_fixture_recovery tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
