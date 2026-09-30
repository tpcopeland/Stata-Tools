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

capture program drop _fx_spaghetti_1
program define _fx_spaghetti_1, rclass
    version 16.0
    args op fixtureopts
    tempfile fx_input
    tempname fx_returns
    _return hold `fx_returns'
    quietly save `fx_input'
    local tests=0
    local pass=0
    local fail=0

    foreach route in plain group mean sample {
        local ++tests
        capture noisily {
            quietly use `fx_input', clear
                _return restore `fx_returns', hold
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

    capture _return restore `fx_returns'
    return scalar qa_tests=`tests'
    return scalar qa_pass=`pass'
    return scalar qa_fail=`fail'
end

local tests=0
local pass=0
local fail=0
* Prime Stata graphics initialization before measuring package state.
qa_fx_a3_traj, clear tier(micro) noiseless
quietly twoway scatter y time, name(fx_prime, replace)
graph drop fx_prime

**# Every graph overlay/group/sample route retains the analytic population
qa_fx_a3_traj, clear tier(micro) noiseless seed(931)
_fx_spaghetti_1 friendly ""
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a3_traj, clear tier(micro) noiseless seed(931) perturb(unsorted)
_fx_spaghetti_1 unsorted "perturb(unsorted)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a3_traj, clear tier(micro) noiseless seed(931) perturb(single_time_id)
_fx_spaghetti_1 single_time_id "perturb(single_time_id)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a3_traj, clear tier(micro) noiseless seed(931) perturb(overlapping_groups)
_fx_spaghetti_1 overlapping_groups "perturb(overlapping_groups)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a3_traj, clear tier(micro) noiseless seed(931) perturb(empty_group)
_fx_spaghetti_1 empty_group "perturb(empty_group)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
di "RESULT: validation_fixture_contract tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
