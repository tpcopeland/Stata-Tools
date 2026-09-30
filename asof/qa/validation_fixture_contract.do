*! validation_fixture_contract.do — canonical F/U numerical contract for asof
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

capture program drop _fx_asof_1
program define _fx_asof_1, rclass
    version 16.0
    args op fixtureopts
    tempfile fx_input
    tempname fx_returns
    _return hold `fx_returns'
    quietly save `fx_input'
    local tests=0
    local pass=0
    local fail=0

    foreach direction in before onorbefore after onorafter both {
        foreach select in nearest first last {
            local ++tests
            capture noisily {
                quietly use `fx_input', clear
                _return restore `fx_returns', hold
                tempfile events expected
                preserve
                    keep if role==2
                    keep id date event_id value
                    sort event_id
                    rename date eventdate
                    save `events'
                restore
                keep if role==1
                keep id anchor_id date
                rename date anchor
                gen double want=.
                gen double wantdate=.
                preserve
                    joinby id using `events'
                    keep if !missing(anchor,eventdate) & inrange(eventdate-anchor,-2,2)
                    if "`direction'"=="before" keep if eventdate<anchor
                    if "`direction'"=="onorbefore" keep if eventdate<=anchor
                    if "`direction'"=="after" keep if eventdate>anchor
                    if "`direction'"=="onorafter" keep if eventdate>=anchor
                    gen double criterion=cond("`select'"=="nearest",abs(eventdate-anchor),cond("`select'"=="first",eventdate,-eventdate))
                    sort anchor_id criterion event_id
                    by anchor_id: keep if _n==1
                    drop want wantdate
                    rename value want
                    rename eventdate wantdate
                    keep anchor_id want wantdate
                    save `expected'
                restore
                drop want wantdate
                merge 1:1 anchor_id using `expected', nogen
                qa_state_snapshot, tag(asof_f)
                asof value using `events', id(id) date(eventdate) anchor(anchor) direction(`direction') select(`select') window(-2 2) ties(first) generate(got) datename(gotdate) matchname(found) nowarn
                qa_state_compare, tag(asof_f) allow(data sort)
                assert got==want & gotdate==wantdate
                assert found==!missing(want) if !missing(anchor)
                assert missing(found) if missing(anchor)
                assert r(N_nokey)==cond("`op'"=="missing_anchor",2,0)
                assert r(N_master)==6
                di "ORACLE asof `op' `direction' `select': six anchors exact"
            }
            if _rc==0 local ++pass
            else {
                local ++fail
                di as error "FAIL asof `op' `direction' `select' rc=" _rc
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

**# Every direction/selection route: brute-force source-row oracle
qa_fx_a4_asof, clear tier(micro) seed(931)
_fx_asof_1 friendly ""
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_asof, clear tier(micro) seed(931) perturb(ties)
_fx_asof_1 ties "perturb(ties)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_asof, clear tier(micro) seed(931) perturb(boundary_values)
_fx_asof_1 boundary_values "perturb(boundary_values)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_asof, clear tier(micro) seed(931) perturb(missing_anchor)
_fx_asof_1 missing_anchor "perturb(missing_anchor)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_asof, clear tier(micro) seed(931) perturb(dup_key)
_fx_asof_1 dup_key "perturb(dup_key)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_asof, clear tier(micro) seed(931) perturb(unsorted)
_fx_asof_1 unsorted "perturb(unsorted)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
di "RESULT: validation_fixture_contract tests=`tests' pass=`pass' fail=`fail' skip=0"
global ASOF_QA_STATUS = cond(`fail'==0,"pass","fail")
log close _all
if `fail'>0 exit 1
