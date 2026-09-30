*! validation_fixture_contract.do — canonical F/U numerical contract for comorbidity
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
tempfile sysbase
capture mkdir "`sysbase'_plus"
capture mkdir "`sysbase'_personal"
sysdir set PLUS "`sysbase'_plus"
sysdir set PERSONAL "`sysbase'_personal"
quietly net install codescan, from("`pkg_dir'/../codescan") replace
do "`qa_dir'/_qa_fx_a5.do"
do "`qa_dir'/_qa_state.do"

capture program drop _fx_comorbidit_1
program define _fx_comorbidit_1, rclass
    version 16.0
    args op fixtureopts
    tempfile fx_input
    tempname fx_returns
    _return hold `fx_returns'
    quietly save `fx_input'
    local tests=0
    local pass=0
    local fail=0

    foreach index in original quan2011 vanwalraven {
        foreach shape in collapse merge {
            local ++tests
            capture noisily {
                quietly use `fx_input', clear
                _return restore `fx_returns', hold
                tempname T
                matrix `T'=r(truth_ids)
                gen double ref=mdy(1,4,2020)
                format ref %td
                local opt "charlson(`index')"
                local out charlson
                if "`index'"=="vanwalraven" {
                    local opt "elixhauser(vanwalraven)"
                    local out elixhauser
                }
                comorbidity dx1-dx4, id(id) `opt' `shape' date(date) refdate(ref) lookback(3) inclusive
                forvalues i=1/`=_N' {
                    local ident=id[`i']
                    scalar mi_w=`T'[`ident',2]
                    scalar dm_w=`T'[`ident',3]
                    scalar renal_w=`T'[`ident',4]
                    scalar meta_w=`T'[`ident',5]
                    if "`index'"=="original" scalar want=mi_w+dm_w+2*renal_w+6*meta_w
                    if "`index'"=="quan2011" scalar want=renal_w+6*meta_w
                    if "`index'"=="vanwalraven" scalar want=5*renal_w+12*meta_w
                    * codescan dictionary matching is start-anchored and case
                    * sensitive by default; this combined U is not normalized.
                    if "`op'"=="case_whitespace_variants" scalar want=0
                    if "`shape'"=="merge" & "`op'"=="dates_out_of_window" & `ident'==1 scalar want=.
                    assert `out'[`i']==scalar(want)
                }
                assert _N==cond("`shape'"=="collapse" & "`op'"=="dates_out_of_window",3,4)
            }
            local case_rc=_rc
            capture restore
            if `case_rc'==0 local ++pass
            else {
                local ++fail
                di as error "FAIL comorbidity `op' `index' `shape' rc=`case_rc'"
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

**# Built-in weighting schemes: four fixture diseases, exact hand weights
qa_fx_a5_wide, clear tier(micro)
_fx_comorbidit_1 friendly ""
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) perturb(codes_sparse)
_fx_comorbidit_1 codes_sparse "perturb(codes_sparse)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) perturb(prefix_ambiguous_codes)
_fx_comorbidit_1 prefix_ambiguous_codes "perturb(prefix_ambiguous_codes)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) perturb(empty_slots)
_fx_comorbidit_1 empty_slots "perturb(empty_slots)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) perturb(case_whitespace_variants)
_fx_comorbidit_1 case_whitespace_variants "perturb(case_whitespace_variants)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) perturb(dates_out_of_window)
_fx_comorbidit_1 dates_out_of_window "perturb(dates_out_of_window)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) perturb(unsorted)
_fx_comorbidit_1 unsorted "perturb(unsorted)"
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
di "RESULT: validation_fixture_contract tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
