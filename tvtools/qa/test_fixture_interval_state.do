*! test_fixture_interval_state.do — native merge filename and diagnose globals
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
log using "test_fixture_interval_state.log", text replace nomsg
args caller_strict
if "`caller_strict'"=="" local caller_strict off
if !inlist("`caller_strict'","off","on") {
    display "RESULT: test_fixture_interval_state tests=0 pass=0 fail=1 skip=0"
    log close _all
    exit 198
}
local qa_dir "`c(pwd)'"
local pkg_dir=regexr("`qa_dir'","/qa$","")
adopath ++ "`pkg_dir'"
do _qa_fx_a4.do
do _qa_state.do
do _qa_metamorphic.do
capture program drop _fx_merge_filename
program define _fx_merge_filename, rclass
    version 16.0
    args op
    tempname P fh
    matrix `P'=r(truth_panel)
    local win=`P'[1,2]
    tempfile source episodes bad caller
    save `source'
    replace stop=`win'+8 if missing(stop)
    replace stop=stop-1
    keep id start stop category
    save `episodes'
    replace start=start+.5 in 1
    assert start[1]!=floor(start[1])
    save `bad'
    use `source', clear
    keep id
    duplicates drop
    generate double entry=`win'
    generate double exit=entry+7
    generate double start=entry
    generate double stop=exit
    generate byte base=0
    format entry exit start stop %td
    save `caller'
    local pass=0
    local fail=0
    foreach status in absent opaque empty native {
        foreach route in success direct_refusal frame_refusal {
            capture noisily {
                capture macro drop S_FN S_FNDATE
                if "`status'"=="opaque" {
                    foreach key in S_FN S_FNDATE {
                        mata: st_global(st_local("key"),char(36)+"OPAQUE"+char(34)+char(96)+"filename"+char(39))
                    }
                }
                if "`status'"=="empty" {
                    global S_FN ""
                    global S_FNDATE ""
                    mata: assert(sum(st_dir("global","macro","*"):=="S_FN")==0)
                }
                if "`status'"=="native" {
                    use `caller', clear
                    mata: assert(sum(st_dir("global","macro","*"):=="S_FN")==1)
                }
                qa_state_snapshot, tag(filename)
                local input "`bad'"
                local opts ""
                if "`route'"=="success" {
                    local input "`episodes'"
                    local opts "frameout(fx_filename)"
                }
                if "`route'"=="frame_refusal" local opts "frameout(fx_filename)"
                tempfile cause_log
                log using `cause_log', name(filename_cause) text replace nomsg
                capture noisily tvmerge "`caller'" "`input'", id(id) start(start start) stop(stop stop) exposure(base category) generate(b0 got) startname(start) stopname(stop) `opts'
                local call_rc=_rc
                local person_time=r(N_persons)
                log close filename_cause
                if "`route'"=="success" {
                    assert `call_rc'==0 & `person_time'==2
                    frame fx_filename {
                        expand stop-start+1
                        bysort id start: generate double day=start+_n-1
                        sort id day
                        assert _N==12
                        local observed=0
                        forvalues i=1/16 {
                            if `P'[`i',3]!=0 {
                                local ++observed
                                assert id[`observed']==`P'[`i',1] & day[`observed']==`P'[`i',2] & got[`observed']==`P'[`i',3] & b0[`observed']==0
                            }
                        }
                    }
                    frame drop fx_filename
                }
                else {
                    local named=0
                    file open `fh' using `cause_log', read text
                    file read `fh' line
                    while !r(eof) {
                        if strpos(`"`macval(line)'"',"Malformed input") local named=1
                        file read `fh' line
                    }
                    file close `fh'
                    assert `call_rc'==498 & `named'==1
                    capture frame fx_filename: describe
                    assert _rc==111
                }
                qa_state_compare, tag(filename)
                * Full fingerprint includes exact S_FN/S_FNDATE presence/bytes.
                * The next actual native load must still publish its filename
                * and read the saved caller data correctly.
                use `caller', clear
                assert _N==2 & entry==`win' & exit==`win'+7
                assert "`c(filename)'"=="`caller'"
                mata: assert(st_global("S_FN")==st_local("caller"))
                display "ORACLE TV merge filename `op' `status' `route': exact non-r caller state, actual frame rows/refusal cause and next native use"
            }
            local rc=_rc
            capture log close filename_cause
            capture frame change default
            capture frame drop fx_filename
            if `rc'==0 local ++pass
            else {
                local ++fail
                display as error "FAIL TV merge filename `op' `status' `route' rc=`rc'"
                use `caller', clear
            }
        }
    }
    foreach mode in memory saveas {
        capture noisily {
            use `caller', clear
            tempfile resultfile nextsave
            local opts ""
            if "`mode'"=="saveas" local opts `"saveas("`resultfile'")"'
            tvmerge "`caller'" "`episodes'", id(id) start(start start) stop(stop stop) exposure(base category) generate(b0 got) startname(start) stopname(stop) `opts'
            assert r(N_persons)==2
            display "OBSERVED TV `mode' native filename: `c(filename)'"
            if "`mode'"=="memory" {
                assert "`c(filename)'"==""
                mata: assert(st_global("S_FN")=="")
            }
            else {
                assert "`c(filename)'"=="`resultfile'"
                mata: assert(st_global("S_FN")==st_local("resultfile"))
                confirm file `resultfile'
                * Compare the returned saved-date bytes with the actual native
                * saved artifact, then run the independent day oracle on that
                * reloaded payload rather than merely checking file existence.
                mata: st_local("saved_date_bytes",st_global("S_FNDATE"))
                mata: assert(sum(st_dir("global","macro","*"):=="S_FNDATE")==1)
                use `resultfile', clear
                assert "`c(filename)'"=="`resultfile'"
                mata: assert(st_global("S_FN")==st_local("resultfile"))
                mata: assert(st_global("S_FNDATE")==st_local("saved_date_bytes"))
            }
            expand stop-start+1
            bysort id start: generate double day=start+_n-1
            sort id day
            assert _N==12
            local observed=0
            forvalues i=1/16 {
                if `P'[`i',3]!=0 {
                    local ++observed
                    assert id[`observed']==`P'[`i',1] & day[`observed']==`P'[`i',2] & got[`observed']==`P'[`i',3] & b0[`observed']==0
                }
            }
            save `nextsave'
            use `nextsave', clear
            assert _N==12
            assert "`c(filename)'"=="`nextsave'"
            display "ORACLE TV merge filename `op' `mode': actual new-output metadata, exact every-day output and next native save/use"
        }
        local rc=_rc
        if `rc'==0 local ++pass
        else {
            local ++fail
            display as error "FAIL TV merge filename `op' `mode' rc=`rc'"
        }
    }
    return scalar tests=14
    return scalar pass=`pass'
    return scalar fail=`fail'
end
program define _fx_diag_globals, rclass
    args op
    local tests=0
    local pass=0
    local fail=0

    tempname P
    matrix `P'=r(truth_panel)
    local win=`P'[1,2]
    replace stop=stop-1
    generate double entry=`win'
    generate double exit=`win'+7
    generate double native_value=_n
    tempfile source
    save `source'
    foreach status in absent present present_empty native {
        foreach route in success refusal {
            local ++tests
            capture noisily {
                use `source', clear
                capture macro drop S_1 S_2
                if "`status'"=="present" {
                    mata: st_global("S_1",char(36)+"QA_SENTINEL"+char(34)+"one")
                    mata: st_global("S_2",char(96)+"two"+char(39))
                }
                if "`status'"=="present_empty" {
                    global S_1 ""
                    global S_2 ""
                    mata: assert(sum(st_dir("global","macro","*"):=="S_1")==0)
                    mata: assert(sum(st_dir("global","macro","*"):=="S_2")==0)
                }
                if "`status'"=="native" {
                    quietly ttest native_value==0
                    mata: assert(sum(st_dir("global","macro","*"):=="S_1")==1)
                    mata: assert(sum(st_dir("global","macro","*"):=="S_2")==1)
                    mata: assert(strtoreal(st_global("S_1"))==st_nobs())
                    mata: assert(strtoreal(st_global("S_2"))==(st_nobs()+1)/2)
                }
                qa_state_snapshot, tag(sglobals)
                if "`route'"=="success" {
                    tvdiagnose, id(id) start(start) stop(stop) exposure(category) entry(entry) exit(exit) all
                    assert r(n_persons)==2 & r(n_observations)==6 & r(raw_interval_person_time)==12
                    qa_state_compare, tag(sglobals)
                }
                else {
                    * expect: REFUSED
                    replace stop=start-1 in 1
                    qa_state_snapshot, tag(sglobals)
                    qa_option_effect, command(tvdiagnose, id(id) start(start) stop(stop) exposure(category) threshold(@v@) summarize) values(30) returns(r(n_persons)) refused cause("stop < start")
                    capture noisily tvdiagnose, id(id) start(start) stop(stop) exposure(category) summarize
                    local refusal_rc=_rc
                    assert `refusal_rc'==459
                    qa_state_compare, tag(sglobals)
                }
                if "`status'"=="native" {
                    quietly ttest native_value==0
                    assert r(N_1)==_N & r(mu_1)==(_N+1)/2
                    mata: assert(strtoreal(st_global("S_1"))==st_nobs())
                    mata: assert(strtoreal(st_global("S_2"))==(st_nobs()+1)/2)
                }
                di "ORACLE legacy globals `op' `status' `route': bytes/existence preserved"
            }
            local case_rc=_rc
            capture restore
            if `case_rc'==0 local ++pass
            else {
                local ++fail
                di as error "FAIL globals `op' `status' `route' rc=`case_rc'"
            }
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
set matastrict `caller_strict'
_fx_merge_filename friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
qa_fx_a4_spells, clear tier(micro)
set matastrict `caller_strict'
_fx_diag_globals friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
qa_fx_a4_spells, clear tier(micro) perturb(unsorted)
set matastrict `caller_strict'
_fx_merge_filename unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
qa_fx_a4_spells, clear tier(micro) perturb(unsorted)
set matastrict `caller_strict'
_fx_diag_globals unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
display "RESULT: test_fixture_interval_state tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
