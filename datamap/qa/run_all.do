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
if !inlist("`mode'", "quick", "core", "full", "benchmark") {
    display as error "lane must be quick, core, full, or benchmark"
    exit 198
}

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

local quick_suites ///
    test_datamap.do ///
    test_datamap_errors.do ///
    test_datadict_v14.do ///
    test_dataprobe.do ///
    test_dataprobe_gates.do ///
    test_dataqa.do ///
    test_datamvp.do ///
    test_regressions.do ///
    test_datamap_documentation_examples.do ///
    test_help_render.do ///
    test_datamap_v168.do ///
    test_datamap_v169.do ///
    test_datamap_v171.do ///
    test_datamap_v180.do ///
    test_datamap_v182.do ///
    test_dataprobe_v190_groupstat.do ///
    test_dataprobe_v190_coverage.do ///
    test_dataqa_v190.do ///
    test_dataqa_v190_collect.do ///
    test_dataprobe_v190_byrule.do ///
    test_dataprobe_v190_smallcells.do ///
    test_dataqa_v190_defaults.do ///
    test_dataprobe_v190_groupfreq.do ///
    test_dataqa_v190_groupkeys.do ///
    test_dataprobe_v190_hostile.do ///
    test_datamap_v190_review.do ///
    test_datamap_quoting_linebreaks.do ///
    test_datamap_v193.do ///
    test_datamvp_graph_text.do

local core_suites ///
    validation_datamap_precision.do validation_dataqa_writer_precision.do ///
    validation_datamap_fixture_contract.do validation_datamap_fixture_primitives.do test_datamap_fixture_domains.do test_datamap_fixture_option_strings.do test_datamvp_fixture_groupgap.do test_datamvp_fixture_reshape_state.do test_datamap_fixture_files.do test_dataprobe_fixture_ledger_quotes.do validation_datadict_fixture_contract.do validation_dataqa_fixture_contract.do test_dataqa_fixture_state.do test_datamvp_fixture_state.do ///
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
    test_datamvp_oracle.do ///
    validation_datamap.do ///
    validation_datamvp.do

* timing on a 1M-row file; never part of quick, core, or full
local benchmark_suites ///
    benchmark_gatesonly.do ///
    benchmark_study.do

local suites "`core_suites'"
if "`mode'" == "quick" local suites "`quick_suites'"
if "`mode'" == "benchmark" local suites "`benchmark_suites'"

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
local old_adopath `"$S_ADO"'
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
        * the suite must leave the sandbox-installed copy as the one that resolves
        local resolved ""
        capture quietly findfile datamap.ado
        if !_rc local resolved `"`r(fn)'"'
        if strpos(`"`resolved'"', `"`sandbox_plus'"') != 1 {
            display as error "`suite' left datamap.ado resolving outside the install sandbox: `resolved'"
            if !`suite_rc' {
                local --suite_pass
                local ++suite_fail
            }
            global S_ADO `"`old_adopath'"'
            capture ado uninstall datamap
            quietly net install datamap, from("`pkg_dir'") replace
            discard
        }
    }
}

sysdir set PLUS "`old_plus'"
sysdir set PERSONAL "`old_personal'"

display "RESULT: run_all_`mode' tests=`suite_count' pass=`suite_pass' fail=`suite_fail'"
if `suite_fail' > 0 exit 1
