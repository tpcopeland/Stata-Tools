*! validation_fixture_domains.do — canonical interval option effects and refusals
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
do "`qa_dir'/_qa_fx_a4.do"
do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_metamorphic.do"
capture program drop _fx_tv_domains
program define _fx_tv_domains, rclass
    version 16.0
    args op
    tempfile source episodes cohort baseline
    save `source'
    quietly summarize start, meanonly
    local origin=r(min)
    replace stop=stop-1
    * Same-class episodes make grace/merge effects identifiable; all dates
    * and source order still come from the canonical half-open spells.
    replace category=1
    keep id start stop category
    save `episodes'
    keep id
    duplicates drop
    gen double entry=`origin'
    gen double exit=entry+10
    format entry exit %td
    save `cohort'
    local tests=0
    local pass=0
    local fail=0
    foreach key in merge grace lag washout fillgaps carryforward {
        local high=cond("`key'"=="merge",2,1)
        foreach value in 0 `high' {
            local ++tests
            capture noisily {
                use `cohort', clear
                if "`key'"=="carryforward" replace exit=entry+7
                tvexpose using `episodes', id(id) start(start) stop(stop) exposure(category) entry(entry) exit(exit) reference(0) generate(got) `key'(`value')
                expand stop-start+1
                bysort id start: gen double day=start+_n-1-`origin'
                gen byte want=inlist(day,0,1,3,4,6,7)
                if `value'>0 {
                    if inlist("`key'","merge","grace","carryforward") replace want=inrange(day,0,7)
                    if "`key'"=="lag" replace want=inlist(day,1,4,7)
                    if "`key'"=="washout" replace want=inrange(day,0,8)
                    if "`key'"=="fillgaps" replace want=inlist(day,0,1,3,4,6,7,8)
                }
                assert got==want
                bysort id: assert _N==cond("`key'"=="carryforward",8,11)
                di "ORACLE tvexpose `op' `key'(`value'): every day exact"
            }
            if _rc==0 local ++pass
            else {
                local ++fail
                di as error "FAIL tvexpose domain `op' `key'(`value') rc=`=_rc'"
            }
        }
        local ++tests
        capture noisily {
            use `cohort', clear
            * expect: EXACT
            qa_option_domain, command(tvexpose using `episodes', id(id) start(start) stop(stop) exposure(category) entry(entry) exit(exit) reference(0) generate(got) `key'(@v@)) inside(0;1) outside(-1)
        }
        if _rc==0 local ++pass
        else local ++fail
    }
    foreach threshold in 0 1 10000 {
        local ++tests
        capture noisily {
            use `episodes', clear
            qa_state_snapshot, tag(tvdiag)
            tvdiagnose, id(id) start(start) stop(stop) gaps threshold(`threshold')
            assert r(n_gaps)==4 & r(n_gap_ids)==2
            assert r(n_large_gaps)==cond(`threshold'==0,4,0)
            qa_state_compare, tag(tvdiag)
        }
        if _rc==0 local ++pass
        else local ++fail
    }
    foreach maximum in 1 2 {
        local ++tests
        capture noisily {
            use `episodes', clear
            qa_state_snapshot, tag(tvdiag)
            tvdiagnose, id(id) start(start) stop(stop) exposure(category) swimlane maxids(`maximum')
            assert r(graph_created)==1 & r(graph_rc)==0 & r(graph_ids_total)==2 & r(graph_ids_plotted)==`maximum' & r(graph_truncated)==(`maximum'==1)
            qa_state_compare, tag(tvdiag)
            graph drop tvd_swimlane
        }
        if _rc==0 local ++pass
        else local ++fail
    }
    local ++tests
    capture noisily {
        use `episodes', clear
        * expect: EXACT
        qa_option_domain, command(tvdiagnose, id(id) start(start) stop(stop) gaps threshold(@v@)) inside(0;1) outside(-1)
        capture graph drop tvd_swimlane
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        use `episodes', clear
        * expect: EXACT
        qa_option_domain, command(tvdiagnose, id(id) start(start) stop(stop) exposure(category) swimlane maxids(@v@)) inside(1;2) outside(0;-1)
        capture graph drop tvd_swimlane
    }
    if _rc==0 local ++pass
    else local ++fail
    foreach coverage in strict allow {
        local ++tests
        capture noisily {
            use `cohort', clear
            capture frame drop fx_boundary fx_boundary_manifest
            qa_state_snapshot, tag(tvbuild_domain)
            tvbuild, id(id) entry(entry) exit(exit) sourceusing(`episodes') start(start) stop(stop) exposure(category) generate(got) reference(0) frameout(fx_boundary) coverage(`coverage') replace
            frame fx_boundary {
                expand stop-start+1
                bysort id start: gen double day=start+_n-1-`origin'
                assert got==inlist(day,0,1,3,4,6,7)
                bysort id: assert _N==11
            }
            frame drop fx_boundary
            capture frame drop fx_boundary_manifest
            qa_state_compare, tag(tvbuild_domain)
        }
        if _rc==0 local ++pass
        else local ++fail
    }
    local ++tests
    capture noisily {
        use `cohort', clear
        * expect: EXACT
        qa_option_domain, command(tvbuild, id(id) entry(entry) exit(exit) sourceusing(`episodes') start(start) stop(stop) exposure(category) generate(got) reference(0) frameout(fx_boundary) coverage(@v@) replace) inside(strict;allow) outside(bad)
        capture frame drop fx_boundary
        capture frame drop fx_boundary_manifest
    }
    if _rc==0 local ++pass
    else local ++fail
    tempfile events
    use `cohort', clear
    gen double eventdate=entry+4
    keep id eventdate
    format eventdate %td
    generate double eventdate1=eventdate
    format eventdate1 %td
    save `events'
    foreach eventtype in single recurring {
        local ++tests
        capture noisily {
            use `cohort', clear
            capture frame drop fx_boundary fx_boundary_manifest
            qa_state_snapshot, tag(tvbuild_domain)
            tvbuild, id(id) entry(entry) exit(exit) sourceusing(`episodes') start(start) stop(stop) exposure(category) generate(got) reference(0) frameout(fx_boundary) eventusing(`events') eventdate(eventdate) eventtype(`eventtype') eventgenerate(failure) replace
            frame fx_boundary {
                gen double span=stop-start+1
                bysort id: egen double total=total(span)
                assert total==cond("`eventtype'"=="single",5,11)
                assert failure==1 if stop==`origin'+4
                quietly count if failure==1
                assert r(N)==2
            }
            frame drop fx_boundary
            capture frame drop fx_boundary_manifest
            qa_state_compare, tag(tvbuild_domain)
        }
        if _rc==0 local ++pass
        else local ++fail
    }
    local ++tests
    capture noisily {
        use `cohort', clear
        * expect: EXACT
        qa_option_domain, command(tvbuild, id(id) entry(entry) exit(exit) sourceusing(`episodes') start(start) stop(stop) exposure(category) generate(got) reference(0) frameout(fx_boundary) eventusing(`events') eventdate(eventdate) eventtype(@v@) eventgenerate(failure) replace) inside(single;recurring) outside(bad)
        capture frame drop fx_boundary
        capture frame drop fx_boundary_manifest
    }
    if _rc==0 local ++pass
    else local ++fail
    use `cohort', clear
    rename entry start
    rename exit stop
    generate byte exposure=0
    save `baseline'
    foreach unit in days months years {
        local ++tests
        capture noisily {
            use `cohort', clear
            generate double eventdate=entry+4
            format eventdate %td
            keep id eventdate
            tvevent using `baseline', id(id) date(eventdate) type(single) generate(failure) timegen(elapsed) timeunit(`unit')
            assert r(N_events)==2
            local divisor=cond("`unit'"=="days",1,cond("`unit'"=="months",30.4375,365.25))
            assert !missing(elapsed) & reldif(elapsed,(stop-`origin')/`divisor')<1e-7
            assert failure==1 if stop==`origin'+4
            assert stop<=`origin'+4
        }
        if _rc==0 local ++pass
        else local ++fail
    }
    local ++tests
    capture noisily {
        use `cohort', clear
        generate double eventdate=entry+4
        format eventdate %td
        keep id eventdate
        * expect: EXACT
        qa_option_domain, command(tvevent using `baseline', id(id) date(eventdate) type(single) generate(failure) timegen(elapsed) timeunit(@v@)) inside(days;months;years) outside(bad)
    }
    if _rc==0 local ++pass
    else local ++fail
    foreach category in all prep diag weight {
        local ++tests
        capture noisily {
            use `cohort', clear
            qa_state_snapshot, tag(tvcat)
            tvtools, category(`category') list
            assert r(n_commands)==cond("`category'"=="all",11,cond("`category'"=="prep",9,1))
            qa_state_compare, tag(tvcat)
        }
        if _rc==0 local ++pass
        else local ++fail
    }
    local ++tests
    capture noisily {
        use `cohort', clear
        * expect: EXACT
        qa_option_domain, command(tvtools, category(@v@) list) inside(all;prep;diag;weight) outside(bad)
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
qa_fx_a4_spells, clear tier(micro)
_fx_tv_domains friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(unsorted)
_fx_tv_domains unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
do "`qa_dir'/_qa_fx_a1.do"
capture program drop _fx_tv_weight_domain
program define _fx_tv_weight_domain, rclass
    version 16.0
    tempfile data
    save `data'
    local tests=0
    local pass=0
    local fail=0
    local ++tests
    capture noisily {
        use `data', clear
        * expect: EXACT
        qa_option_domain, command(tvweight a, covariates(i.s##i.x2) generate(got) model(@v@) nolog) inside(logit;mlogit) outside(bad)
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        use `data', clear
        * expect: EXACT
        qa_option_domain, command(tvweight a, covariates(i.s##i.x2) generate(got) wtype(@v@) nolog) inside(iptw;ato;matching) outside(bad)
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        use `data', clear
        * expect: EXACT
        qa_option_domain, command(tvweight a, covariates(i.s##i.x2) generate(got) truncate(@v@) nolog) inside(1 99;25 75) outside(0 99;1 100;75 25)
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        use `data', clear
        gen double p=cond(s==0,cond(x2==0,1/3,2/3),cond(x2==0,1/4,3/4))
        gen double want=min(3,max(4/3,cond(a,1/p,1/(1-p))))
        tvweight a, covariates(i.s##i.x2) generate(got) truncate(25 75) nolog
        * Canonical120 rows have weight multiplicities36*(4/3),48*1.5,
        *24*3,12*4: exact25th/75th percentiles are4/3 and3.
        assert !missing(got,want) & reldif(got,want)<1e-7
    }
    if _rc==0 local ++pass
    else local ++fail
    return scalar tests=`tests'
    return scalar pass=`pass'
    return scalar fail=`fail'
end
qa_fx_a1_sat, clear
_fx_tv_weight_domain
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a1_sat, clear perturb(unsorted)
_fx_tv_weight_domain
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
di "RESULT: validation_fixture_domains tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
