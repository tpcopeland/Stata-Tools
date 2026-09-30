*! validation_fixture_domains.do — independent EDSS parameter/calendar oracles
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
log using "validation_fixture_domains.log", replace text nomsg
local qa_dir "`c(pwd)'"
local pkg_dir=regexr("`qa_dir'","/qa$","")
adopath ++ "`pkg_dir'"
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_metamorphic.do"
* Independent enumeration: evaluate all candidate/future assessment pairs,
* then take earliest accepted date. No production retry/group-min helpers.
capture mata: mata drop _fx_edss_parameter()
mata:
void _fx_edss_parameter(string scalar route, real scalar days, real scalar basewin, real scalar before, real scalar after, real scalar floor)
{
    real matrix D,V
    real colvector ids,answer,ci,fu,accepted,relapses
    real scalar i,j,b,cut,date,first,criterion,q
    D=st_data(.,("id","date","edss","dx_date","relapse_date"))
    ids=uniqrows(sort(D[.,1],1));answer=J(rows(D),1,.)
    for(i=1;i<=rows(ids);i++) {
        V=sort(select(D,(D[.,1]:==ids[i]):&(D[.,3]:<.)),(2,3))
        accepted=J(rows(V),1,.)
        if(substr(route,1,2)=="ss") {
            for(j=1;j<=rows(V);j++) {
                if(V[j,3]<6) continue
                fu=selectindex((V[.,2]:>V[j,2]):&(V[.,2]:<=V[j,2]+days))
                if(!rows(fu)) continue
                first=fu[1]
                if(V[first,3]>=6 & min(V[fu,3])>=floor) accepted[j]=V[j,2]
            }
        }
        else {
            ci=selectindex((V[.,2]:>=V[.,4]):&(V[.,2]:<=V[.,4]:+basewin))
            b=1
            if(rows(ci)) b=ci[1]
            cut=V[b,3]+(V[b,3]>5.5 ? .5 : 1)
            for(j=1;j<=rows(V);j++) {
                if(V[j,2]<=V[b,2] | V[j,3]<cut) continue
                fu=selectindex(V[.,2]:>=V[j,2]+days)
                if(!rows(fu)) continue
                criterion=(strpos(route,"visit") ? V[fu[1],3] : min(V[fu,3]))
                if(criterion>=cut) accepted[j]=V[j,2]
            }
        }
        date=min(accepted)
        if(substr(route,1,4)=="pira" & date<.) {
            relapses=select(V[.,5],V[.,5]:<.)
            if(any((relapses:>=date-before):&(relapses:<=date+after))) date=.
        }
        answer[selectindex(D[.,1]:==ids[i])]=J(sum(D[.,1]:==ids[i]),1,date)
    }
    q=st_addvar("double","want");st_store(.,q,answer)
}
end
capture program drop _fx_edss_parameters
program define _fx_edss_parameters, rclass
    version 16.0
    args op
    tempfile source relapse
    save `source'
    preserve
        keep id relapse_date
        drop if missing(relapse_date)
        duplicates drop
        save `relapse'
    restore
    local tests=0
    local pass=0
    local fail=0
    foreach route in cdp_sustained cdp_visit {
        foreach days in 1 180 10000 {
            foreach basewin in 1 730 {
                local ++tests
                capture noisily {
                    use `source', clear
                    mata: _fx_edss_parameter("`route'",`days',`basewin',0,0,6)
                    local mode=cond("`route'"=="cdp_visit","visit","sustained")
                    cdp id edss date, dxdate(dx_date) confirmdays(`days') baselinewindow(`basewin') confirmtype(`mode') keepall generate(got) quietly
                    assert r(confirmdays)==`days' & r(baselinewindow)==`basewin'
                    assert got==want
                }
                if _rc==0 local ++pass
                else {
                    local ++fail
                    di as error "FAIL EDSS `op' `route' days`days' baseline`basewin' rc=`=_rc'"
                }
            }
        }
    }
    foreach mode in sustained visit {
        foreach before in 0 90 {
            foreach after in 0 30 {
                local ++tests
                capture noisily {
                    use `source', clear
                    mata: _fx_edss_parameter("pira_`mode'",180,730,`before',`after',6)
                    pira id edss date, dxdate(dx_date) relapses(`relapse') relapseidvar(id) relapsedatevar(relapse_date) windowbefore(`before') windowafter(`after') confirmtype(`mode') keepall generate(got) quietly
                    assert got==want
                }
                if _rc==0 local ++pass
                else {
                    local ++fail
                    di as error "FAIL PIRA `op' `mode' before`before' after`after' rc=`=_rc'"
                }
            }
        }
    }
    foreach days in 1 10000 {
        foreach basewin in 1 730 {
            local ++tests
            capture noisily {
                use `source', clear
                mata: _fx_edss_parameter("pira_visit",`days',`basewin',90,30,6)
                pira id edss date, dxdate(dx_date) relapses(`relapse') relapseidvar(id) relapsedatevar(relapse_date) confirmdays(`days') baselinewindow(`basewin') confirmtype(visit) keepall generate(got) quietly
                assert got==want
            }
            if _rc==0 local ++pass
            else local ++fail
        }
    }
    foreach days in 1 180 10000 {
        foreach floor in 0 6 10 {
            local ++tests
            capture noisily {
                use `source', clear
                mata: _fx_edss_parameter("ss",`days',730,0,0,`floor')
                sustainedss id edss date, threshold(6) confirmwindow(`days') baselinethreshold(`floor') confirmvisit(window) keepall generate(got) quietly
                assert got==want
            }
            if _rc==0 local ++pass
            else {
                local ++fail
                di as error "FAIL sustainedss `op' days`days' floor`floor' rc=`=_rc'"
            }
        }
    }
    local ++tests
    capture noisily {
        use `source', clear
        * expect: EXACT
        qa_option_domain, command(cdp id edss date, dxdate(dx_date) confirmdays(@v@) keepall quietly) inside(1;180) outside(0;-1)
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        use `source', clear
        * expect: EXACT
        qa_option_domain, command(cdp id edss date, dxdate(dx_date) baselinewindow(@v@) keepall quietly) inside(1;730) outside(0;-1)
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        use `source', clear
        * expect: EXACT
        qa_option_domain, command(pira id edss date, dxdate(dx_date) relapses(`relapse') relapseidvar(id) relapsedatevar(relapse_date) windowbefore(@v@) keepall quietly) inside(0;90) outside(-1)
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        use `source', clear
        * expect: EXACT
        qa_option_domain, command(pira id edss date, dxdate(dx_date) relapses(`relapse') relapseidvar(id) relapsedatevar(relapse_date) windowafter(@v@) keepall quietly) inside(0;30) outside(-1)
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        use `source', clear
        * expect: EXACT
        qa_option_domain, command(pira id edss date, dxdate(dx_date) relapses(`relapse') relapseidvar(id) relapsedatevar(relapse_date) confirmtype(@v@) keepall quietly) inside(sustained;visit) outside(bad)
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        use `source', clear
        * expect: EXACT
        qa_option_domain, command(sustainedss id edss date, threshold(6) confirmwindow(@v@) keepall quietly) inside(1;180) outside(0;-1)
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        use `source', clear
        * expect: EXACT
        qa_option_domain, command(sustainedss id edss date, threshold(6) baselinethreshold(@v@) keepall quietly) inside(0;6) outside(-1)
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        use `source', clear
        * expect: EXACT
        qa_option_domain, command(pira id edss date, dxdate(dx_date) relapses(`relapse') relapseidvar(id) relapsedatevar(relapse_date) confirmdays(@v@) keepall quietly) inside(1;180) outside(0;-1)
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        use `source', clear
        * expect: EXACT
        qa_option_domain, command(pira id edss date, dxdate(dx_date) relapses(`relapse') relapseidvar(id) relapsedatevar(relapse_date) baselinewindow(@v@) keepall quietly) inside(1;730) outside(0;-1)
    }
    if _rc==0 local ++pass
    else local ++fail
    foreach category in all codes migration ms {
        local ++tests
        capture noisily {
            use `source', clear
            qa_state_snapshot, tag(setcat)
            setools, category(`category') list
            assert r(n_commands)==cond("`category'"=="all",5,cond("`category'"=="ms",3,1))
            assert "`r(category)'"=="`category'"
            qa_state_compare, tag(setcat)
        }
        if _rc==0 local ++pass
        else local ++fail
    }
    local ++tests
    capture noisily {
        use `source', clear
        qa_state_snapshot, tag(setcat)
        capture noisily setools, category(bad)
        local call_rc=_rc
        assert `call_rc'==198
        qa_state_compare, tag(setcat)
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        use `source', clear
        * expect: EXACT
        qa_option_domain, command(setools, category(@v@) list) inside(all;codes;migration;ms) outside(bad)
    }
    if _rc==0 local ++pass
    else local ++fail
    return scalar tests=`tests'
    return scalar pass=`pass'
    return scalar fail=`fail'
end
capture program drop _fx_mig_domain
program define _fx_mig_domain, rclass
    version 16.0
    tempfile mig persons
    preserve
        keep if role==2
        generate byte event_type=cond(mod(event_id-1,3)==1,2,1)
        rename date event_date
        keep id event_date event_type
        save `mig'
    restore
    keep if role==1
    sort id anchor_id
    by id: keep if _n==1
    rename date study_start
    save `persons'
    local tests=0
    local pass=0
    local fail=0
    foreach minimum in 0 1 2 {
        local ++tests
        capture noisily {
            use `persons', clear
            migrations, migfile(`mig') idvar(id) startvar(study_start) intype(1) outtype(2) minresidence(`minimum') flag quietly
            assert _N==2 & r(N_excluded_minresidence)==cond(`minimum'==2,2,0)
            assert mig_excluded==(`minimum'==2)
        }
        if _rc==0 local ++pass
        else local ++fail
    }
    local ++tests
    capture noisily {
        use `persons', clear
        * expect: EXACT
        qa_option_domain, command(migrations, migfile(`mig') idvar(id) startvar(study_start) intype(1) outtype(2) minresidence(@v@) flag quietly) inside(0;2) outside(-1)
    }
    if _rc==0 local ++pass
    else local ++fail
    return scalar tests=`tests'
    return scalar pass=`pass'
    return scalar fail=`fail'
end
local tests=0
local pass=0
local fail=0
qa_fx_a3_edss, clear tier(micro)
_fx_edss_parameters friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a3_edss, clear tier(micro) perturb(unsorted)
_fx_edss_parameters unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
do "`qa_dir'/_qa_fx_a4.do"
qa_fx_a4_asof, clear tier(micro)
_fx_mig_domain
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a4_asof, clear tier(micro) perturb(unsorted)
_fx_mig_domain
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
do "`qa_dir'/_qa_fx_a5.do"
qa_fx_a5_wide, clear tier(micro)
local ++tests
capture noisily {
    generate str8 textdate=string(date,"%tdCCYYNNDD")
    drop date
    rename textdate date
    * expect: EXACT
    qa_option_domain, command(cci_se, id(id) icd(dx1-dx4) date(date) dateformat(@v@)) inside(yyyymmdd) outside(bad)
}
if _rc==0 local ++pass
else local ++fail
qa_fx_a5_wide, clear tier(micro) perturb(unsorted)
local ++tests
capture noisily {
    generate str8 textdate=string(date,"%tdCCYYNNDD")
    drop date
    rename textdate date
    * expect: EXACT
    qa_option_domain, command(cci_se, id(id) icd(dx1-dx4) date(date) dateformat(@v@)) inside(yyyymmdd) outside(bad)
}
if _rc==0 local ++pass
else local ++fail
di "RESULT: validation_fixture_domains tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
