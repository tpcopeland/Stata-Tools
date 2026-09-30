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
local tests=0
local pass=0
local fail=0

**# Built-in weighting schemes: four fixture diseases, exact hand weights
foreach op in friendly codes_sparse prefix_ambiguous_codes empty_slots case_whitespace_variants dates_out_of_window unsorted {
    foreach index in original quan2011 vanwalraven {
        foreach shape in collapse merge {
            local ++tests
            capture noisily {
                if "`op'"=="friendly" qa_fx_a5_wide, clear tier(micro)
                else {
                    * expect: EXACT
                    qa_fx_a5_wide, clear tier(micro) perturb(`op')
                }
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
}
di "RESULT: validation_fixture_contract tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
