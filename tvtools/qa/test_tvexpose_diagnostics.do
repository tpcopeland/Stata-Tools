*! test_tvexpose_diagnostics.do
*! Contract pins for the extracted tvexpose report-only diagnostics helper.
*!
*! check, gaps, overlaps, summarize, and validate moved out of tvexpose.ado
*! into _tvexpose_diagnostics.ado. They had to move: a Stata program may hold
*! at most 3500 statements, tvexpose.ado held 3498, and adding one brace pair
*! made the whole command fail to load with r(1000). qa/test_program_limits.do
*! guards the margin; this suite guards the behaviour.
*!
*! Axes probed, and why each one is here:
*!   D1-D2   the helper resolves for an installed user, and tvexpose refuses
*!           with r(111) rather than r(199) when it is missing.
*!   D3-D4   dispatch, proved by swapping a sentinel stub in for the helper:
*!           check and validate must reach it and a plain call must not.
*!           Without this, D5-D10 would pass just as happily if every option
*!           branch were dead code.
*!   D5-D10  REPORT-ONLY is the contract. Every diagnostic option must leave
*!           the committed schema and the data signature identical to the same
*!           call without it. This is the general form of the defect D11 pins.
*!   D11     summarize with a continuous exposure type used to weld an
*!           undocumented period_length column onto the committed output: the
*!           restore sat inside the categorical branch, so the continuous arm
*!           never ran it. Fails on the pre-1.9.1 code.
*!   D12-D14 validate writes its file, carries its documented per-person
*!           schema, honours saveas(), and still restores the caller's data.
*!           A saveas() with no .dta extension must not collide with the main
*!           output.
*!   D15     an absent saveas() must not arrive at the helper as the literal
*!           two-character string `""'. Declaring the option `string asis' did
*!           exactly that and broke validate with r(198).

clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_tvexpose_diagnostics.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

global TVD_PASS = 0
global TVD_FAIL = 0
global TVD_FAILED ""
local test_count = 0

display as result "tvtools QA: tvexpose diagnostics helper -- $S_DATE $S_TIME"

capture program drop _tvd_check
program define _tvd_check
    args ok label detail
    if `ok' {
        global TVD_PASS = $TVD_PASS + 1
        display as result "  PASS `label'"
    }
    else {
        global TVD_FAIL = $TVD_FAIL + 1
        global TVD_FAILED "$TVD_FAILED `label'"
        display as error "  FAIL `label': `detail'"
    }
end

* _tvd_base: the reference call, with no diagnostic option at all.
capture program drop _tvd_base
program define _tvd_base
    version 16.0
    args extra
    quietly use "$DATA_DIR/cohort.dta", clear
    quietly tvexpose using "$DATA_DIR/dmt.dta", id(id) ///
        start(dmt_start) stop(dmt_stop) exposure(dmt) reference(0) ///
        entry(study_entry) exit(study_exit) generate(tv_dmt) `extra'
end

**# D1 the helper resolves for an installed user
local ++test_count
capture which _tvexpose_diagnostics
local ok = (_rc == 0)
_tvd_check `ok' "D1 _tvexpose_diagnostics resolves after installation" "rc=`=_rc'"

**# D2 a missing helper is refused with r(111), not r(199)
local ++test_count
capture findfile _tvexpose_diagnostics.ado
local helper_path "`r(fn)'"
local helper_bak "`c(tmpdir)'/_tvexpose_diagnostics.ado.bak"
quietly copy "`helper_path'" "`helper_bak'", replace
quietly erase "`helper_path'"
capture program drop _tvexpose_diagnostics
discard
quietly use "$DATA_DIR/cohort.dta", clear
capture noisily tvexpose using "$DATA_DIR/dmt.dta", id(id) ///
    start(dmt_start) stop(dmt_stop) exposure(dmt) reference(0) ///
    entry(study_entry) exit(study_exit) generate(tv_dmt) check
local missing_rc = _rc
local ok = (`missing_rc' == 111)
_tvd_check `ok' ///
    "D2 a missing diagnostics helper is refused with r(111)" ///
    "rc=`missing_rc' (199 = unguarded, 0 = branch never reached)"

**# D3 dispatch: the diagnostic options reach the helper, a plain call does not
* Substituting a sentinel stub for the real helper is the only way to tell
* "the option branch ran" from "the option branch is dead code and the output
* happens to be right anyway". D4-D9 assert that nothing changes; on their own
* they would pass just as happily if no diagnostic ever ran.
local ++test_count
tempname fh
file open `fh' using "`helper_path'", write text replace
file write `fh' "program define _tvexpose_diagnostics" _n
file write `fh' "    syntax [anything] [, *]" _n
file write `fh' "    global TVD_HIT = 1" _n
file write `fh' "end" _n
file close `fh'
capture program drop _tvexpose_diagnostics
discard

global TVD_HIT = 0
_tvd_base
local hit_plain = $TVD_HIT
global TVD_HIT = 0
_tvd_base "check"
local hit_check = $TVD_HIT
global TVD_HIT = 0
_tvd_base "validate replace"
local hit_validate = $TVD_HIT

local ok = (`hit_plain' == 0 & `hit_check' == 1 & `hit_validate' == 1)
_tvd_check `ok' ///
    "D3 the helper runs for check/validate and not for a plain call" ///
    "plain=`hit_plain' check=`hit_check' validate=`hit_validate'"

quietly copy "`helper_bak'" "`helper_path'", replace
capture program drop _tvexpose_diagnostics
discard
local ++test_count
capture which _tvexpose_diagnostics
local ok = (_rc == 0)
_tvd_check `ok' "D4 the real helper was restored for the rest of the suite" ///
    "rc=`=_rc'"

**# D4-D9 report-only: the committed result is identical with and without
_tvd_base
quietly datasignature
local base_sig "`r(datasignature)'"
quietly ds
local base_vars "`r(varlist)'"

local optlist `""check" "check verbose" "gaps" "overlaps" "summarize" "gaps overlaps verbose""'
foreach opt of local optlist {
    local ++test_count
    _tvd_base "`opt'"
    quietly datasignature
    local sig "`r(datasignature)'"
    quietly ds
    local vars "`r(varlist)'"
    local ok = ("`sig'" == "`base_sig'" & "`vars'" == "`base_vars'")
    _tvd_check `ok' ///
        "D`test_count' `opt' leaves the committed result unchanged" ///
        "sig=`sig' vs `base_sig'; vars=`vars' vs `base_vars'"
}

**# D9 summarize with a continuous exposure type adds no column
* The restore used to sit inside the categorical branch, so this arm returned
* an undocumented period_length column. Fails on the pre-1.9.1 code.
local ++test_count
quietly use "$DATA_DIR/cohort.dta", clear
quietly tvexpose using "$DATA_DIR/dmt.dta", id(id) start(dmt_start) ///
    stop(dmt_stop) exposure(dmt) reference(0) entry(study_entry) ///
    exit(study_exit) bytype continuousunit(years)
quietly ds
local cont_base "`r(varlist)'"

quietly use "$DATA_DIR/cohort.dta", clear
quietly tvexpose using "$DATA_DIR/dmt.dta", id(id) start(dmt_start) ///
    stop(dmt_stop) exposure(dmt) reference(0) entry(study_entry) ///
    exit(study_exit) bytype continuousunit(years) summarize
quietly ds
local cont_sum "`r(varlist)'"
capture confirm variable period_length
local no_leak = (_rc != 0)
local ok = ("`cont_sum'" == "`cont_base'" & `no_leak')
_tvd_check `ok' ///
    "D`test_count' summarize on a continuous exposure type adds no column" ///
    "with=`cont_sum'; without=`cont_base'; period_length_absent=`no_leak'"

**# D10 validate writes its default file and restores the data
local ++test_count
capture erase "tv_validation.dta"
_tvd_base "validate replace"
quietly ds
local val_vars "`r(varlist)'"
capture confirm file "tv_validation.dta"
local val_written = (_rc == 0)
local ok = (`val_written' & "`val_vars'" == "`base_vars'")
_tvd_check `ok' ///
    "D`test_count' validate writes tv_validation.dta and restores the data" ///
    "written=`val_written'; vars=`val_vars'"

**# D11 the validation dataset carries its documented per-person schema
local ++test_count
quietly use "tv_validation.dta", clear
local val_ok = 1
foreach v in id total_covered expected_days pct_covered total_exposed_days ///
    n_periods n_transitions any_gaps n_gaps first_exposure last_exposure {
    capture confirm variable `v', exact
    if _rc local val_ok = 0
}
quietly duplicates report id
local val_unique = (r(unique_value) == r(N))
local ok = (`val_ok' & `val_unique')
_tvd_check `ok' ///
    "D`test_count' the validation dataset is one complete row per person" ///
    "schema_ok=`val_ok'; one_row_per_id=`val_unique'"

**# D12 saveas() without a .dta extension does not collide with the main output
local ++test_count
capture erase "vd_noext"
capture erase "vd_noext_validation.dta"
_tvd_base "validate saveas(vd_noext) replace"
capture confirm file "vd_noext_validation.dta"
local noext_ok = (_rc == 0)
local ok = `noext_ok'
_tvd_check `ok' ///
    "D`test_count' saveas() without .dta gets a distinct validation filename" ///
    "vd_noext_validation.dta present=`noext_ok'"

**# D13 an absent saveas() does not arrive as the literal string `""'
* Declaring the helper's saveas() `string asis' kept the option's own quotes,
* so "`saveas'" != "" was true with no saveas() at all and subinstr() produced
* invalid '"'_validation.dta', r(198). D10 covers the success path; this pins
* the specific failure mode by asserting the default filename is used.
local ++test_count
capture erase "tv_validation.dta"
_tvd_base "validate replace"
local val_rc = _rc
capture confirm file "tv_validation.dta"
local default_name = (_rc == 0)
local ok = (`val_rc' == 0 & `default_name')
_tvd_check `ok' ///
    "D`test_count' validate with no saveas() writes the default filename" ///
    "rc=`val_rc'; tv_validation.dta present=`default_name'"

capture erase "tv_validation.dta"
capture erase "vd_noext"
capture erase "vd_noext_validation.dta"

**# Summary
local pass_count = $TVD_PASS
local fail_count = $TVD_FAIL
display "RESULT: test_tvexpose_diagnostics tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "tvexpose diagnostics failures:$TVD_FAILED"
    exit 1
}
