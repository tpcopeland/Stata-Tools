*! run_all.do Version 2.0.0  2026/08/11
*! Curated lane runner for the datamap QA suite
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set varabbrev off
version 16.0

args mode extra
if "`mode'" == "" local mode "full"
if "`extra'" != "" {
    display as error "run_all.do accepts at most one lane argument"
    exit 198
}
if !inlist("`mode'", "quick", "core", "full") {
    display as error "lane must be quick, core, or full"
    exit 198
}

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

local quick_suites ///
    test_datamap.do ///
    test_datadict_v14.do ///
    test_datacheck.do ///
    test_datamvp.do ///
    test_regressions.do ///
    test_help_render.do

local core_suites ///
    `quick_suites' ///
    test_datamap_bugfixes.do ///
    test_datamap_paths.do ///
    test_datamap_float_format.do ///
    test_datamap_golden.do ///
    test_datamap_privacy.do ///
    test_datamap_v2.do ///
    test_datamap_v11.do ///
    test_datamap_v15.do ///
    test_datamap_v152.do ///
    test_datamap_v154.do ///
    test_datamap_v160.do ///
    test_datamvp_labels.do ///
    validation_datamap.do ///
    validation_datamvp.do

local suites "`core_suites'"
if "`mode'" == "quick" local suites "`quick_suites'"

local old_plus : sysdir PLUS
local old_personal : sysdir PERSONAL
tempfile sandbox_base
local sandbox_plus "`sandbox_base'_plus"
local sandbox_personal "`sandbox_base'_personal"
capture mkdir "`sandbox_plus'"
capture mkdir "`sandbox_personal'"
sysdir set PLUS "`sandbox_plus'"
sysdir set PERSONAL "`sandbox_personal'"

local suite_count : word count `suites'
local suite_pass = 0
local suite_fail = 0

capture ado uninstall datamap
capture noisily net install datamap, from("`pkg_dir'") replace
local install_rc = _rc
if `install_rc' {
    local suite_fail = `suite_count'
    display as error "datamap local install failed with rc `install_rc'"
}
else {
    foreach suite of local suites {
        capture noisily do "`qa_dir'/`suite'"
        local suite_rc = _rc
        if `suite_rc' {
            display as error "`suite' failed with rc `suite_rc'"
            local ++suite_fail
        }
        else {
            local ++suite_pass
        }
        discard
    }
}

sysdir set PLUS "`old_plus'"
sysdir set PERSONAL "`old_personal'"

display "RESULT: run_all_`mode' tests=`suite_count' pass=`suite_pass' fail=`suite_fail'"
if `suite_fail' > 0 exit 1
