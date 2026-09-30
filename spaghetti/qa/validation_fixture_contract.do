*! validation_fixture_contract.do — canonical F/U numerical contract for spaghetti
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
log using "validation_fixture_contract.log", replace text nomsg
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
adopath ++ "`pkg_dir'"
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_state.do"
local tests=0
local pass=0
local fail=0
* Prime Stata graphics initialization before measuring package state.
qa_fx_a3_traj, clear tier(micro) noiseless
quietly twoway scatter y time, name(fx_prime, replace)
graph drop fx_prime

**# Every graph overlay/group/sample route retains the analytic population
foreach op in friendly unsorted single_time_id overlapping_groups empty_group {
    foreach route in plain group mean sample {
        local ++tests
        capture noisily {
            if "`op'"=="friendly" qa_fx_a3_traj, clear tier(micro) noiseless seed(931)
            else {
                * expect: EXACT
                qa_fx_a3_traj, clear tier(micro) noiseless seed(931) perturb(`op')
            }
            local nobs=_N
            quietly levelsof id, local(ids)
            local nids : word count `ids'
            quietly levelsof group, local(groups)
            local ngroups : word count `groups'
            local opts ""
            if "`route'"=="group" local opts "by(group)"
            if "`route'"=="mean" local opts "mean(ci)"
            if "`route'"=="sample" local opts "sample(8) seed(931)"
            qa_state_snapshot, tag(spag_f)
            spaghetti y, id(id) time(time) `opts' name(fx_graph, replace)
            qa_state_compare, tag(spag_f) allow(rng)
            assert r(N)==`nobs' & r(n_ids)==`nids'
            assert r(n_groups)==cond("`route'"=="group",`ngroups',1)
            assert r(n_sampled)==cond("`route'"=="sample",8,`nids')
            assert strpos(`"`r(cmd)'"',"twoway")>0
            graph drop fx_graph
        }
        if _rc==0 local ++pass
        else {
            local ++fail
            di as error "FAIL spaghetti `op' `route' rc=" _rc
        }
    }
}
di "RESULT: validation_fixture_contract tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
