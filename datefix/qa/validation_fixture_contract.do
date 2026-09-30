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
local tests=0
local pass=0
local fail=0

**# String conversion/native pass-through and all output modes
foreach op in friendly boundary_values unsorted {
    foreach mode in inplace new drop numeric {
        local ++tests
        capture noisily {
            if "`op'"=="friendly" qa_fx_a4_spells, clear tier(micro)
            else {
                * expect: EXACT
                qa_fx_a4_spells, clear tier(micro) perturb(`op')
            }
            gen double want=start
            gen str12 text=string(start,"%tdCCYY-NN-DD")
            qa_state_snapshot, tag(date_f)
            if "`mode'"=="inplace" datefix text, order(YMD)
            if "`mode'"=="new" datefix text, order(YMD) newvar(converted)
            if "`mode'"=="drop" datefix text, order(YMD) newvar(converted) drop
            if "`mode'"=="numeric" datefix start
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
}
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
