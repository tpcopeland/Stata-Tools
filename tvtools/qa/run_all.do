*! run_all.do — canonical QA runner for tvtools
*! Usage: cd tvtools/qa && stata-mp -b do run_all.do [quick|core|external|full|release|meta]

version 16.0
args mode extra

local _orig_more = c(more)
local _orig_varabbrev = c(varabbrev)
local _orig_plus "`c(sysdir_plus)'"
local _orig_personal "`c(sysdir_personal)'"
set more off
set varabbrev off

local qa_dir "`c(pwd)'"
local mode = lower(trim("`mode'"))
if "`mode'" == "" local mode "full"
if "`mode'" == "python" local mode "external"

if "`extra'" != "" {
    display as error "run_all.do accepts at most one mode argument"
    set more `_orig_more'
    set varabbrev `_orig_varabbrev'
    exit 198
}

if !inlist("`mode'", "quick", "core", "external", "full", "release", "meta") {
    display as error "unknown QA mode: `mode'"
    display as error "supported modes: quick, core, external, full, release, meta"
    set more `_orig_more'
    set varabbrev `_orig_varabbrev'
    exit 198
}

include "`qa_dir'/_tvtools_qa_manifest.do"
local suite_list ``mode'_suites'

local n_manifest : word count `manifest_suites'
local n_counts : word count `manifest_counts'
local n_skip_flags : word count `manifest_allow_skips'
if `n_manifest' != `n_counts' | `n_manifest' != `n_skip_flags' {
    display as error "QA manifest columns are not positionally aligned"
    set more `_orig_more'
    set varabbrev `_orig_varabbrev'
    exit 9
}

foreach delegated of local release_delegated_suites {
    capture confirm file "`qa_dir'/`delegated'"
    if _rc {
        display as error "Delegated release suite is missing: `delegated'"
        set more `_orig_more'
        set varabbrev `_orig_varabbrev'
        exit 601
    }
}

do "`qa_dir'/_tvtools_qa_common.do"
global TVTOOLS_QA_MANAGED_BY_RUNNER "1"
capture noisily _tvtools_qa_bootstrap
local bootstrap_rc = _rc
if `bootstrap_rc' | "$TVTOOLS_QA_BOOTSTRAP_COUNT" != "1" {
    capture noisily _tvtools_qa_cleanup
    sysdir set PLUS "`_orig_plus'"
    sysdir set PERSONAL "`_orig_personal'"
    set more `_orig_more'
    set varabbrev `_orig_varabbrev'
    if `bootstrap_rc' exit `bootstrap_rc'
    display as error "QA bootstrap ran more than once before suite execution"
    exit 9
}

local pass = 0
local fail = 0
local total_skip = 0
local require_zero_skip = inlist("`mode'", "full", "release")

display as text "tvtools QA mode: `mode'"

foreach f of local suite_list {
    local manifest_pos : list posof "`f'" in manifest_suites
    if `manifest_pos' == 0 {
        local ++fail
        display as error "FAILED: `f'.do is absent from the QA manifest"
        continue
    }
    local expected : word `manifest_pos' of `manifest_counts'
    local allow_skip : word `manifest_pos' of `manifest_allow_skips'

    capture erase "`qa_dir'/`f'.log"
    capture cd "`qa_dir'"
    set more off
    set varabbrev off
    capture noisily do "`qa_dir'/`f'.do"
    local suite_rc = _rc
    capture log close _all
    capture cd "`qa_dir'"

    * A suite may clear programs before failing. Reload the parser from source,
    * then judge both process rc and the pinned RESULT contract.
    capture noisily do "`qa_dir'/_tvtools_qa_common.do"
    local common_rc = _rc
    local contract_valid = 0
    local contract_reason "result parser could not be loaded"
    local suite_skip = 0
    if `common_rc' == 0 {
        local skip_option ""
        if `allow_skip' local skip_option "allowskip"
        local zero_option ""
        if `require_zero_skip' local zero_option "requirezeroskip"
        capture noisily _tvtools_qa_validate_result, ///
            logfile("`qa_dir'/`f'.log") suite(`f') expected(`expected') ///
            `skip_option' `zero_option'
        local contract_rc = _rc
        if `contract_rc' == 0 {
            local contract_valid = r(valid)
            local contract_reason "`r(reason)'"
            local suite_skip = r(skip)
            if missing(`suite_skip') local suite_skip = 0
        }
        else local contract_reason "result parser failed with rc `contract_rc'"
    }
    if "$TVTOOLS_QA_BOOTSTRAP_COUNT" != "1" {
        local contract_valid = 0
        local contract_reason "QA bootstrap count changed from one"
    }

    local total_skip = `total_skip' + `suite_skip'
    if `suite_rc' == 0 & `contract_valid' == 1 {
        local ++pass
        display as result "PASSED: `f'.do (`expected' checks)"
    }
    else {
        local ++fail
        display as error "FAILED: `f'.do (suite rc=`suite_rc'; `contract_reason')"
    }
}

capture noisily _tvtools_qa_cleanup
global TVTOOLS_QA_MANAGED_BY_RUNNER ""
sysdir set PLUS "`_orig_plus'"
sysdir set PERSONAL "`_orig_personal'"
set more `_orig_more'
set varabbrev `_orig_varabbrev'

local n_suites : word count `suite_list'
display as result "tvtools QA summary (`mode'): `pass' passed, `fail' failed, `total_skip' skipped checks"
display "RESULT: run_all tests=`n_suites' pass=`pass' fail=`fail' skip=`total_skip'"
if `fail' > 0 exit 1
