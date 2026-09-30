*! validation_fixture_route_minima.do — actual interval minima at merge/diagnose boundaries
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
log using "validation_fixture_route_minima.log", text replace nomsg
local qa_dir "`c(pwd)'"
local pkg_dir=regexr("`qa_dir'","/qa$","")
adopath ++ "`pkg_dir'"
do "`qa_dir'/_qa_fx_a4.do"
do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_hostile.do"

program define _fx_min_refuse
    version 16.0
    args command expected_rc cause
    tempfile cause_log
    tempname fh
    qa_state_snapshot, tag(min_refuse)
    capture log close min_cause
    log using `cause_log', name(min_cause) text replace nomsg
    capture noisily `command'
    local call_rc=_rc
    log close min_cause
    local named=0
    file open `fh' using `cause_log', read text
    file read `fh' line
    while !r(eof) {
        if strpos(`"`macval(line)'"',"`cause'") local named=1
        file read `fh' line
    }
    file close `fh'
    assert `call_rc'==`expected_rc' & `named'
    qa_state_compare, tag(min_refuse)
end

program define _fx_route_minima, rclass
    version 16.0
    args op
    tempname P E
    matrix `P'=r(truth_panel)
    local window=`P'[1,2]
    * Half-open SPELLS map to inclusive daily bounds. Open ends remain missing
    * and zero-length bounds become reversed: both must reach public refusal.
    replace stop=stop-1
    if "`op'"=="time_hostile" {
        qa_hostile_times, generate(hostile_time)
        replace start=hostile_time
        replace stop=8
        drop hostile_time
        assert start!=floor(start) if mod(_n-1,5)<2
    }
    keep id start stop category
    format start stop %td
    tempfile source baseline
    save `source'
    preserve
        keep id
        duplicates drop
        generate double start=`window'
        generate double stop=`window'+7
        generate byte base=0
        if "`op'"=="time_hostile" {
            replace start=0
            replace stop=8
        }
        format start stop %td
        save `baseline'
    restore
    local tests=0
    local pass=0
    local fail=0
    foreach route in merge diagnose {
        local ++tests
        capture noisily {
            use `source', clear
            if inlist("`op'","open_end","zero_length","time_hostile") {
                if "`route'"=="merge" {
                    use `baseline', clear
                    _fx_min_refuse `"tvmerge "`baseline'" "`source'", id(id) start(start start) stop(stop stop) exposure(base category) generate(b0 got) startname(start) stopname(stop)"' 498 "Malformed input"
                }
                else {
                    local refusal_rc=cond("`op'"=="open_end",416,cond("`op'"=="zero_length",459,498))
                    local cause=cond("`op'"=="open_end","missing id/start/stop",cond("`op'"=="zero_length","stop < start","non-whole daily dates"))
                    _fx_min_refuse `"tvdiagnose, id(id) start(start) stop(stop) exposure(category) all entry(start) exit(stop)"' `refusal_rc' "`cause'"
                }
                display "ORACLE `route' `op': actual malformed bounds reach exact named native refusal and non-r rollback"
            }
            else if "`route'"=="diagnose" {
                * Enumerate each integer day and source row independently. The
                * union ignores repeated coverage; raw time retains duplicates.
                scalar raw=0
                scalar union=0
                scalar covered=0
                quietly summarize start, meanonly
                local firstday=r(min)
                quietly summarize stop, meanonly
                local lastday=r(max)
                forvalues j=1/`=_N' {
                    scalar raw=scalar(raw)+stop[`j']-start[`j']+1
                }
                forvalues ident=1/2 {
                    forvalues day=`firstday'/`lastday' {
                        local active=0
                        forvalues j=1/`=_N' {
                            if id[`j']==`ident' & inrange(`day',start[`j'],stop[`j']) local active=1
                        }
                        scalar union=scalar(union)+`active'
                        if inrange(`day',`window',`window'+7) scalar covered=scalar(covered)+`active'
                    }
                }
                generate double entry=`window'
                generate double exit=`window'+7
                qa_state_snapshot, tag(min_diag)
                tvdiagnose, id(id) start(start) stop(stop) exposure(category) entry(entry) exit(exit) all
                qa_state_compare, tag(min_diag)
                assert r(n_persons)==2 & r(total_person_time)==scalar(union)
                assert r(raw_interval_person_time)==scalar(raw)
                assert r(overlap_excess_person_time)==scalar(raw)-scalar(union)
                assert r(mean_coverage)==100*scalar(covered)/16
                display "ORACLE diagnose `op': raw=" scalar(raw) " union=" scalar(union)
            }
            else {
                * Cartesian one baseline row x each raw source episode. Build
                * expected interval multiset directly, then remove exact output
                * duplicates as the documented public output contract requires.
                matrix `E'=J(`=_N',4,.)
                local rows=0
                forvalues j=1/`=_N' {
                    local lo=max(start[`j'],`window')
                    local hi=min(stop[`j'],`window'+7)
                    if `lo'<=`hi' {
                        local ++rows
                        matrix `E'[`rows',1]=id[`j']
                        matrix `E'[`rows',2]=`lo'
                        matrix `E'[`rows',3]=`hi'
                        matrix `E'[`rows',4]=category[`j']
                    }
                }
                matrix `E'=`E'[1..`rows',1..4]
                tempfile expected
                clear
                svmat double `E', names(col)
                rename c1 id
                rename c2 start
                rename c3 stop
                rename c4 got
                duplicates drop
                sort id start stop got
                save `expected'
                local expected_n=_N
                use `baseline', clear
                tvmerge "`baseline'" "`source'", id(id) start(start start) stop(stop stop) exposure(base category) generate(b0 got) startname(start) stopname(stop)
                assert r(N_persons)==2 & r(N_datasets)==2 & _N==`expected_n'
                assert b0==0
                keep id start stop got
                sort id start stop got
                cf id start stop got using `expected', all
                display "ORACLE merge `op': every Cartesian pair interval/exposure exact, rows=" _N
            }
        }
        local rc=_rc
        capture log close min_cause
        if `rc'==0 local ++pass
        else {
            local ++fail
            display as error "FAIL route minima `route' `op' rc=`rc'"
        }
    }
    return scalar tests=`tests'
    return scalar pass=`pass'
    return scalar fail=`fail'
end
program define _fx_daily_minima, rclass
    version 16.0
    args op
    keep id
    duplicates drop
    if "`op'"=="unsorted" {
        gsort -id
        assert id[1]>id[2]
    }
    qa_hostile_times, generate(start)
    assert start!=floor(start)
    generate double stop=8
    generate double dob=-1000
    generate double origin=0
    format start stop dob origin %td
    tempfile source intervals
    save `source'
    preserve
        keep id start stop
        save `intervals'
    restore
    local tests=0
    local pass=0
    local fail=0
    foreach route in age elapsed calendar split event {
        local ++tests
        capture noisily {
            use `source', clear
            local command "tvage, id(id) dob(dob) entry(start) exit(stop) generate(got)"
            local cause "non-whole daily dates"
            if "`route'"=="elapsed" local command "tvband, id(id) start(start) stop(stop) type(elapsed) origin(origin) width(1) unit(day) generate(got)"
            if "`route'"=="calendar" local command "tvband, id(id) start(start) stop(stop) type(calendar) width(1) generate(got)"
            if "`route'"=="split" local command "tvsplit, id(id) start(start) stop(stop) elapsed(origin, width(1) unit(day) generate(got))"
            if "`route'"=="event" {
                keep id
                generate double eventdate=4
                local command "tvevent using `intervals', id(id) date(eventdate) type(single) generate(got)"
                local cause "Malformed interval input"
            }
            _fx_min_refuse `"`command'"' 498 "`cause'"
            di "ORACLE TV `route' `op' time_hostile: shared binary64 fractional dates reach named native498 with exact non-r state"
        }
        local rc=_rc
        capture log close min_cause
        if `rc'==0 local ++pass
        else {
            local ++fail
            di as error "FAIL daily route `route' `op' rc=`rc'"
        }
    }
    return scalar tests=`tests'
    return scalar pass=`pass'
    return scalar fail=`fail'
end

local tests=0
local pass=0
local fail=0

qa_fx_a4_spells, clear tier(micro)
_fx_route_minima friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)

qa_fx_a4_spells, clear tier(micro) perturb(unsorted)
_fx_route_minima unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)

qa_fx_a4_spells, clear tier(micro) perturb(overlap)
_fx_route_minima overlap
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)

qa_fx_a4_spells, clear tier(micro) perturb(abut)
_fx_route_minima abut
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)

qa_fx_a4_spells, clear tier(micro) perturb(dup_key)
_fx_route_minima dup_key
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)

qa_fx_a4_spells, clear tier(micro) perturb(boundary_values)
_fx_route_minima boundary_values
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)

qa_fx_a4_spells, clear tier(micro) perturb(open_end)
_fx_route_minima open_end
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)

qa_fx_a4_spells, clear tier(micro) perturb(zero_length)
_fx_route_minima zero_length
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)

qa_fx_a4_spells, clear tier(micro)
_fx_route_minima time_hostile
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)

qa_fx_a4_spells, clear tier(micro)
_fx_daily_minima friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
qa_fx_a4_spells, clear tier(micro) perturb(unsorted)
_fx_daily_minima unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
di "RESULT: validation_fixture_route_minima tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
