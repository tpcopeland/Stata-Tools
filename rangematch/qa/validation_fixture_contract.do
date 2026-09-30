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
local tests=0
local pass=0
local fail=0

**# All closure and directional-nearest routes against direct joinby
foreach op in friendly ties boundary_values missing_anchor dup_key unsorted {
    foreach closed in both left right none {
        foreach direction in all before after both {
            local ++tests
            capture noisily {
                if "`op'"=="friendly" qa_fx_a4_asof, clear tier(micro) seed(931)
                else {
                    * expect: EXACT
                    qa_fx_a4_asof, clear tier(micro) seed(931) perturb(`op')
                }
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
}
di "RESULT: validation_fixture_contract tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
