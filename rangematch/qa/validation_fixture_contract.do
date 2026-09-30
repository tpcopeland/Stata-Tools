*! validation_fixture_contract.do — canonical F/U numerical contract for rangematch
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

capture program drop _fx_rangematch_1
program define _fx_rangematch_1, rclass
    version 16.0
    args op fixtureopts
    tempfile fx_input
    tempname fx_returns
    _return hold `fx_returns'
    quietly save `fx_input'
    local tests=0
    local pass=0
    local fail=0

    foreach closed in both left right none {
        foreach direction in all before after both {
            local ++tests
            capture noisily {
                quietly use `fx_input', clear
                _return restore `fx_returns', hold
                tempfile events master expected actual
                preserve
                    keep if role==2
                    keep id date event_id
                    rename date key
                    save `events'
                restore
                keep if role==1
                keep id anchor_id date
                rename date key
                gen double lo=key-2
                gen double hi=key+2
                save `master'
                preserve
                    rename key anchor
                    joinby id using `events'
                    keep if !missing(anchor,key,lo,hi)
                    keep if cond(inlist("`closed'","both","left"),key>=lo,key>lo) & cond(inlist("`closed'","both","right"),key<=hi,key<hi)
                    if "`direction'"=="before" keep if key<=anchor
                    if "`direction'"=="after" keep if key>=anchor
                    if "`direction'"!="all" & _N>0 {
                        gen double dist=abs(key-anchor)
                        bysort anchor_id: egen double mindist=min(dist)
                        keep if dist==mindist
                    }
                    keep anchor_id event_id
                    sort anchor_id event_id
                    save `expected'
                restore
                local opt ""
                if "`direction'"!="all" local opt "nearest(`direction') ties(all)"
                rangematch key lo hi using `events', by(id) keepusing(event_id) unmatched(none) closed(`closed') missing(drop) `opt'
                keep anchor_id event_id
                sort anchor_id event_id
                save `actual'
                cf _all using `expected', all
            }
            local case_rc=_rc
            capture restore
            if `case_rc'==0 local ++pass
            else {
                local ++fail
                di as error "FAIL rangematch `op' `closed' `direction' rc=" _rc
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

**# All closure and directional-nearest routes against direct joinby
qa_fx_a4_asof, clear tier(micro) seed(931)
_fx_rangematch_1 friendly ""
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_asof, clear tier(micro) seed(931) perturb(ties)
_fx_rangematch_1 ties "perturb(ties)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_asof, clear tier(micro) seed(931) perturb(boundary_values)
_fx_rangematch_1 boundary_values "perturb(boundary_values)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_asof, clear tier(micro) seed(931) perturb(missing_anchor)
_fx_rangematch_1 missing_anchor "perturb(missing_anchor)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_asof, clear tier(micro) seed(931) perturb(dup_key)
_fx_rangematch_1 dup_key "perturb(dup_key)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_asof, clear tier(micro) seed(931) perturb(unsorted)
_fx_rangematch_1 unsorted "perturb(unsorted)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
di "RESULT: validation_fixture_contract tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
