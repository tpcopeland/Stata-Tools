*! test_fixture_filename_state.do — tvexpose readonly/refusal native filename bytes
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
log using "test_fixture_filename_state.log", replace text nomsg
args caller_strict
if "`caller_strict'"=="" local caller_strict off
if !inlist("`caller_strict'","off","on") {
    display "RESULT: test_fixture_filename_state tests=0 pass=0 fail=1 skip=0"
    log close _all
    exit 198
}
local qa_dir "`c(pwd)'"
local pkg_dir=regexr("`qa_dir'","/qa$","")
adopath ++ "`pkg_dir'"
do _qa_fx_a4.do
do _qa_state.do
capture program drop _fx_filename
program define _fx_filename, rclass
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
    format entry exit %td
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
                capture noisily tvexpose using `input', id(id) entry(entry) exit(exit) start(start) stop(stop) exposure(category) reference(0) generate(got) `opts'
                local call_rc=_rc
                local person_time=r(total_time)
                log close filename_cause
                if "`route'"=="success" {
                    assert `call_rc'==0 & `person_time'==16
                    frame fx_filename {
                        expand stop-start+1
                        bysort id start: generate double day=start+_n-1
                        sort id day
                        assert _N==16
                        forvalues i=1/16 {
                            assert id[`i']==`P'[`i',1] & day[`i']==`P'[`i',2] & got[`i']==`P'[`i',3]
                        }
                    }
                    frame drop fx_filename
                }
                else {
                    local named=0
                    file open `fh' using `cause_log', read text
                    file read `fh' line
                    while !r(eof) {
                        if strpos(`"`macval(line)'"',"Malformed exposure input") local named=1
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
                display "ORACLE TV filename `op' `status' `route': exact non-r caller state, actual frame rows/refusal cause and next native use"
            }
            local rc=_rc
            capture log close filename_cause
            capture frame change default
            capture frame drop fx_filename
            if `rc'==0 local ++pass
            else {
                local ++fail
                display as error "FAIL TV filename `op' `status' `route' rc=`rc'"
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
            tvexpose using `episodes', id(id) entry(entry) exit(exit) start(start) stop(stop) exposure(category) reference(0) generate(got) `opts'
            assert r(total_time)==16 & r(N_persons)==2
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
            assert _N==16
            forvalues i=1/16 {
                assert id[`i']==`P'[`i',1] & day[`i']==`P'[`i',2] & got[`i']==`P'[`i',3]
            }
            save `nextsave'
            use `nextsave', clear
            assert _N==16
            assert "`c(filename)'"=="`nextsave'"
            display "ORACLE TV filename `op' `mode': actual new-output metadata, exact every-day output and next native save/use"
        }
        local rc=_rc
        if `rc'==0 local ++pass
        else {
            local ++fail
            display as error "FAIL TV filename `op' `mode' rc=`rc'"
        }
    }
    return scalar tests=14
    return scalar pass=`pass'
    return scalar fail=`fail'
end
local tests=0
local pass=0
local fail=0
qa_fx_a4_spells, clear tier(micro)
set matastrict `caller_strict'
_fx_filename friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
qa_fx_a4_spells, clear tier(micro) perturb(unsorted)
set matastrict `caller_strict'
_fx_filename unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
display "RESULT: test_fixture_filename_state tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
