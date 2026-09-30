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

capture program drop _fx_setools_4
program define _fx_setools_4, rclass
    version 16.0
    args op fixtureopts
    tempfile fx_input
    tempname fx_returns
    _return hold `fx_returns'
    quietly save `fx_input'
    local tests=0
    local pass=0
    local fail=0

    foreach route in ordinary flag permanent permanentflag {
        local ++tests
        capture noisily {
            quietly use `fx_input', clear
                _return restore `fx_returns', hold
            tempfile migration expected
            preserve
                keep if role==2
                gen byte event_type=cond(mod(event_id-1,3)==1,2,1)
                rename date event_date
                keep id event_date event_type
                bysort id: egen double outday=min(cond(event_type==2,event_date,.))
                if inlist("`route'","permanent","permanentflag") drop if event_type==1 & event_date>outday
                drop outday
                save `migration'
                bysort id: egen double lastin=max(cond(event_type==1,event_date,.))
                keep if event_type==2
                gen double want=cond(event_date>=lastin,event_date,.)
                keep id want
                save `expected'
            restore
            keep if role==1
            sort id anchor_id
            by id: keep if _n==1
            rename date study_start
            merge 1:1 id using `expected', nogen
            local opts ""
            if inlist("`route'","flag","permanentflag") local opts "flag"
            migrations, migfile(`migration') idvar(id) startvar(study_start) intype(1) outtype(2) quietly `opts'
            assert _N==2 & r(N_excluded_total)==0 & r(N_censored)==cond(inlist("`route'","permanent","permanentflag"),2,0) & r(N_final)==2
            assert migration_out_dt==want
            if inlist("`route'","flag","permanentflag") assert mig_excluded==0 & mig_exclude_reason==""
        }
        local case_rc=_rc
        capture restore
        if `case_rc'==0 local ++pass
        else {
            local ++fail
            di as error "FAIL migrations `op' `route' rc=`case_rc'"
        }
    }

    capture _return restore `fx_returns'
    return scalar qa_tests=`tests'
    return scalar qa_pass=`pass'
    return scalar qa_fail=`fail'
end

capture program drop _fx_setools_3
program define _fx_setools_3, rclass
    version 16.0
    args op fixtureopts
    tempfile fx_input
    tempname fx_returns
    _return hold `fx_returns'
    quietly save `fx_input'
    
local tests=0
    local pass=0
    local fail=0

    local ++tests
    capture noisily {
        quietly use `fx_input', clear
                _return restore `fx_returns', hold
        tempname T
        matrix `T'=r(truth_ids)
        gen double ref=mdy(1,4,2020)
        format ref %td
        cci_se, id(id) icd(dx1-dx4) date(date) indexdate(ref) lookback(3) components dates
        assert _N==cond("`op'"=="dates_out_of_window",3,4)
        forvalues j=1/`=_N' {
            local ident=id[`j']
            assert charlson[`j']==`T'[`ident',8]
            assert cci_mi[`j']==`T'[`ident',2]
            assert cci_diab[`j']==`T'[`ident',3]
            assert cci_renal[`j']==`T'[`ident',4]
            assert cci_mets[`j']==`T'[`ident',5]
        }
    }
    if _rc==0 local ++pass
    else local ++fail

    capture _return restore `fx_returns'
    return scalar qa_tests=`tests'
    return scalar qa_pass=`pass'
    return scalar qa_fail=`fail'
end

capture program drop _fx_setools_2
program define _fx_setools_2, rclass
    version 16.0
    args op fixtureopts
    tempfile fx_input
    tempname fx_returns
    _return hold `fx_returns'
    quietly save `fx_input'
    
local tests=0
    local pass=0
    local fail=0

    local ++tests
    capture noisily {
        quietly use `fx_input', clear
                _return restore `fx_returns', hold
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

    capture _return restore `fx_returns'
    return scalar qa_tests=`tests'
    return scalar qa_pass=`pass'
    return scalar qa_fail=`fail'
end

capture program drop _fx_setools_1
program define _fx_setools_1, rclass
    version 16.0
    args op fixtureopts
    tempfile fx_input
    tempname fx_returns
    _return hold `fx_returns'
    quietly save `fx_input'
    
local tests=0
    local pass=0
    local fail=0

    foreach route in cdp2s cdp2v cdp3s cdp3v ss6 ss6v pira {
        local ++tests
        capture noisily {
            quietly use `fx_input', clear
                _return restore `fx_returns', hold
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

    capture _return restore `fx_returns'
    return scalar qa_tests=`tests'
    return scalar qa_pass=`pass'
    return scalar qa_fail=`fail'
end

local tests=0
local pass=0
local fail=0

**# Separate sustained/visit/two-/three-tier CDP and EDSS6 truth
qa_fx_a3_edss, clear tier(micro)
_fx_setools_1 friendly ""
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a3_edss, clear tier(micro) perturb(ties)
_fx_setools_1 ties "perturb(ties)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a3_edss, clear tier(micro) perturb(unsorted)
_fx_setools_1 unsorted "perturb(unsorted)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a3_edss, clear tier(micro) perturb(miss_irrelevant)
_fx_setools_1 miss_irrelevant "perturb(miss_irrelevant)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a3_edss, clear tier(micro) perturb(boundary_values)
_fx_setools_1 boundary_values "perturb(boundary_values)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
**# Roving CDP every event/date/baseline against fixture truth
qa_fx_a3_edss, clear tier(micro)
_fx_setools_2 friendly ""
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a3_edss, clear tier(micro) perturb(boundary_values)
_fx_setools_2 boundary_values "perturb(boundary_values)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a3_edss, clear tier(micro) perturb(unsorted)
_fx_setools_2 unsorted "perturb(unsorted)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)

do "`qa_dir'/_qa_fx_a5.do"
do "`qa_dir'/_qa_fx_a4.do"
**# Swedish CCI at every canonical code profile and inclusive date window
qa_fx_a5_wide, clear tier(micro)
_fx_setools_3 friendly ""
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) perturb(codes_sparse)
_fx_setools_3 codes_sparse "perturb(codes_sparse)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) perturb(prefix_ambiguous_codes)
_fx_setools_3 prefix_ambiguous_codes "perturb(prefix_ambiguous_codes)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) perturb(case_whitespace_variants)
_fx_setools_3 case_whitespace_variants "perturb(case_whitespace_variants)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) perturb(empty_slots)
_fx_setools_3 empty_slots "perturb(empty_slots)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) perturb(dates_out_of_window)
_fx_setools_3 dates_out_of_window "perturb(dates_out_of_window)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) perturb(unsorted)
_fx_setools_3 unsorted "perturb(unsorted)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
**# Long migration history: arrival before entry, censor at next departure
qa_fx_a4_asof, clear tier(micro)
_fx_setools_4 friendly ""
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_asof, clear tier(micro) perturb(unsorted)
_fx_setools_4 unsorted "perturb(unsorted)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_asof, clear tier(micro) perturb(dup_key)
_fx_setools_4 dup_key "perturb(dup_key)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_asof, clear tier(micro) perturb(ties)
_fx_setools_4 ties "perturb(ties)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a4_asof, clear tier(micro) perturb(boundary_values)
_fx_setools_4 boundary_values "perturb(boundary_values)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
di "RESULT: validation_fixture_contract tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
