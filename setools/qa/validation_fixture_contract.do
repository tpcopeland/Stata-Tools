*! validation_fixture_contract.do — canonical F/U numerical contract for setools
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

**# Separate sustained/visit/two-/three-tier CDP and EDSS6 truth
foreach op in friendly ties unsorted miss_irrelevant boundary_values {
    foreach route in cdp2s cdp2v cdp3s cdp3v ss6 ss6v pira {
        local ++tests
        capture noisily {
            if "`op'"=="friendly" qa_fx_a3_edss, clear tier(micro)
            else {
                * expect: EXACT
                qa_fx_a3_edss, clear tier(micro) perturb(`op')
            }
            local n_input=_N
            tempname T
            matrix `T'=r(truth_events)
            local col=.
            local opts ""
            if "`route'"=="cdp2s" local col=2
            if "`route'"=="cdp2v" local col=3
            if "`route'"=="cdp3s" local col=4
            if "`route'"=="cdp3v" local col=5
            if inlist("`route'","cdp2v","cdp3v") local opts "confirmtype(visit)"
            if inlist("`route'","cdp3s","cdp3v") local opts "`opts' threetier"
            if substr("`route'",1,3)=="cdp" cdp id edss date, dxdate(dx_date) confirmdays(180) keepall generate(got) quietly `opts'
            if "`route'"=="ss6" {
                local col=8
                sustainedss id edss date, threshold(6) keepall generate(got) quietly
            }
            if "`route'"=="ss6v" {
                local col=9
                sustainedss id edss date, threshold(6) confirmvisit(unlimited) keepall generate(got) quietly
            }
            if "`route'"=="pira" {
                tempfile relapse
                preserve
                    keep id relapse_date
                    drop if missing(relapse_date)
                    duplicates drop
                    save `relapse'
                restore
                pira id edss date, dxdate(dx_date) relapses(`relapse') relapseidvar(id) relapsedatevar(relapse_date) keepall generate(got) rawgenerate(raw) quietly
                local col=6
                forvalues i=1/`=_N' {
                    local ident=id[`i']
                    assert raw[`i']==`T'[`ident',7]
                }
            }
            forvalues i=1/`=_N' {
                local ident=id[`i']
                assert got[`i']==`T'[`ident',`col']
            }
            assert _N==`n_input'
        }
        local case_rc=_rc
        capture restore
        if `case_rc'==0 local ++pass
        else {
            local ++fail
            di as error "FAIL setools `op' `route' rc=`case_rc'"
        }
    }
}
**# Roving CDP every event/date/baseline against fixture truth
foreach op in friendly boundary_values unsorted {
    local ++tests
    capture noisily {
        if "`op'"=="friendly" qa_fx_a3_edss, clear tier(micro)
        else {
            * expect: EXACT
            qa_fx_a3_edss, clear tier(micro) perturb(`op')
        }
        tempname R
        matrix `R'=r(truth_roving)
        cdp id edss date, dxdate(dx_date) confirmtype(visit) roving allevents generate(got) eventnumvar(eventnum) baseedssvar(base) quietly
        sort id eventnum
        assert _N==rowsof(`R')
        forvalues i=1/`=_N' {
            assert id[`i']==`R'[`i',1]
            assert eventnum[`i']==`R'[`i',2]
            assert got[`i']==`R'[`i',3]
            assert base[`i']==`R'[`i',5]
        }
    }
    if _rc==0 local ++pass
    else local ++fail
}
di "RESULT: validation_fixture_contract tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
