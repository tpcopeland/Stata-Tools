*! validation_fixture_windows.do — canonical CCI date-format/window oracles
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
log using "validation_fixture_windows.log", replace text nomsg
local qa_dir "`c(pwd)'"
local pkg_dir=regexr("`qa_dir'","/qa$","")
adopath ++ "`pkg_dir'"
do "`qa_dir'/_qa_fx_a5.do"
do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_metamorphic.do"
capture program drop _fx_cci_windows
program define _fx_cci_windows, rclass
    version 16.0
    args op
    tempname T
    matrix `T'=r(truth_ids)
    tempfile source expected
    quietly save `source'
    local tests=0
    local pass=0
    local fail=0
    foreach fmt in stata yyyymmdd_numeric yyyymmdd_string ymd {
        foreach width in 1 3 {
            local ++tests
            capture noisily {
                use `source', clear
                generate double ref=mdy(1,4,2020)
                format ref %td
                preserve
                    keep if inrange(date,ref-`width',ref)
                    generate double want=.
                    forvalues i=1/`=_N' {
                        replace want=`T'[id[`i'],8] in `i'
                    }
                    keep id want
                    sort id
                    local persons=_N
                    save `expected', replace
                restore
                local dateopts "dateformat(stata)"
                if "`fmt'"!="stata" {
                    generate str10 datestring=string(date,cond("`fmt'"=="ymd","%tdCCYY-NN-DD","%tdCCYYNNDD"))
                    drop date
                    rename datestring date
                    local dateopts "dateformat(yyyymmdd)"
                    if "`fmt'"=="yyyymmdd_numeric" destring date, replace
                    if "`fmt'"=="ymd" local dateopts "dateformat(ymd)"
                }
                cci_se, id(id) icd(dx1-dx4) date(date) `dateopts' indexdate(ref) lookback(`width') components dates
                assert _N==`persons'
                sort id
                rename charlson got
                merge 1:1 id using `expected'
                assert _merge==3 & got==want & !missing(got,want)
                di "ORACLE cci_se `op' `fmt' lookback(`width'): all`persons' scores exact"
            }
            if _rc==0 local ++pass
            else {
                local ++fail
                di as error "FAIL cci_se `op' `fmt' `width' rc=`=_rc'"
            }
        }
    }
    local ++tests
    capture noisily {
        use `source', clear
        generate double ref=mdy(1,4,2020)
        format ref %td
        * expect: EXACT
        qa_option_domain, command(cci_se, id(id) icd(dx1-dx4) date(date) indexdate(ref) lookback(@v@)) inside(1;3) outside(0;-1;0.5)
    }
    if _rc==0 local ++pass
    else local ++fail
    foreach bad in "lookback(0) indexdate(ref)" "dateformat(bad)" "dateformat(ymd)" {
        local ++tests
        capture noisily {
            use `source', clear
            generate double ref=mdy(1,4,2020)
            format ref %td
            qa_state_snapshot, tag(cci_refuse)
            capture noisily cci_se, id(id) icd(dx1-dx4) date(date) `bad'
            local rc=_rc
            assert `rc'==198
            qa_state_compare, tag(cci_refuse)
        }
        if _rc==0 local ++pass
        else local ++fail
    }
    return scalar tests=`tests'
    return scalar pass=`pass'
    return scalar fail=`fail'
end
local tests=0
local pass=0
local fail=0
qa_fx_a5_wide, clear tier(micro)
_fx_cci_windows friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) perturb(unsorted)
_fx_cci_windows unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
di "RESULT: validation_fixture_windows tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
