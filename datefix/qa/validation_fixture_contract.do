*! validation_fixture_contract.do — canonical F/U numerical contract for datefix
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
do "`qa_dir'/_qa_fx_a4.do"
do "`qa_dir'/_qa_state.do"

capture program drop _fx_datefix_1
program define _fx_datefix_1, rclass
    version 16.0
    args op fixtureopts
    tempfile fx_input
    tempname fx_returns
    _return hold `fx_returns'
    quietly save `fx_input'
    local tests=0
    local pass=0
    local fail=0

    foreach mode in inplace new drop numeric {
        local ++tests
        capture noisily {
            quietly use `fx_input', clear
                _return restore `fx_returns', hold
            gen double want=start
            gen str12 text=string(start,"%tdCCYY-NN-DD")
            qa_state_snapshot, tag(date_f)
            local input "text"
            local options "order(YMD)"
            if "`mode'"=="new" local options "order(YMD) newvar(converted)"
            if "`mode'"=="drop" local options "order(YMD) newvar(converted) drop"
            if "`mode'"=="numeric" {
                local input "start"
                local options ""
            }
            datefix `input', `options'
            qa_state_compare, tag(date_f) allow(data)
            if "`mode'"=="inplace" assert text==want
            if inlist("`mode'","new","drop") assert converted==want
            if "`mode'"=="numeric" assert start==want
            if "`mode'"=="drop" {
                capture confirm variable text
                assert _rc==111
            }
        }
        if _rc==0 local ++pass
        else local ++fail
    }

    capture _return restore `fx_returns'
    return scalar qa_tests=`tests'
    return scalar qa_pass=`pass'
    return scalar qa_fail=`fail'
end

local tests=0
local pass=0
local fail=0

**# String conversion/native pass-through and all output modes
qa_fx_a4_spells, clear tier(micro)
_fx_datefix_1 friendly ""
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(boundary_values)
_fx_datefix_1 boundary_values "perturb(boundary_values)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(unsorted)
_fx_datefix_1 unsorted "perturb(unsorted)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
**# Explicit invalid order refusal with friendly positive control above
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a4_spells, clear tier(micro) perturb(boundary_values)
    gen str12 text=string(start,"%tdCCYY-NN-DD")
    qa_state_snapshot, tag(date_u)
    capture noisily datefix text, order(bad)
    assert _rc==198
    qa_state_compare, tag(date_u)
}
if _rc==0 local ++pass
else local ++fail
di "RESULT: validation_fixture_contract tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
