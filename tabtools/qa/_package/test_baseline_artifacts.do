* test_baseline_artifacts.do — validate tabtools baseline summaries as semantic oracles

clear all
version 16.0
set more off

capture log close _baseline_artifacts
log using "test_baseline_artifacts.log", replace text name(_baseline_artifacts)

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
if regexm("`qa_dir'", "/qa/_package$") {
    local pkg_dir = regexr("`qa_dir'", "/qa/_package$", "")
    local qa_dir = regexr("`qa_dir'", "/_package$", "")
}
else if regexm("`qa_dir'", "/qa$") {
    local pkg_dir = regexr("`qa_dir'", "/qa$", "")
}
else {
    local pkg_dir "`qa_dir'"
    local qa_dir "`pkg_dir'/qa"
}

local baseline_dir "`qa_dir'/baseline"
local summary_dir "`baseline_dir'/summaries"
local manifest_file "`baseline_dir'/baseline_manifest.tsv"
local summary_tool "`qa_dir'/tools/summarize_xlsx.py"
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

local python_cmd ""
capture noisily shell python3 --version
if _rc == 0 {
    local python_cmd "python3"
}
else {
    capture noisily shell python --version
    if _rc == 0 local python_cmd "python"
}

capture confirm file "`summary_tool'"
if _rc {
    display as error "FAIL: summarize_xlsx.py not available"
    log close _baseline_artifacts
    exit 601
}
if "`python_cmd'" == "" {
    display as error "FAIL: python/openpyxl summary runtime not available"
    log close _baseline_artifacts
    exit 601
}

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

* Assert a summarize_xlsx.py verdict file says PASS. Stata's `shell` does not
* propagate the tool's exit code to _rc, so the comparison result must be read
* from the --status-file the tool writes and asserted here.
capture program drop _assert_summary_status
program define _assert_summary_status
    args status_file
    capture confirm file "`status_file'"
    if _rc {
        display as error "summary status file not written: `status_file'"
        exit 459
    }
    tempname fh
    file open `fh' using "`status_file'", read text
    file read `fh' _line
    file close `fh'
    if substr("`_line'", 1, 4) != "PASS" {
        display as error "summary comparison failed: `_line'"
        exit 9
    }
end

**# T1: Manifest lists only passing, materialized baseline summary artifacts
local ++test_count
capture noisily {
    capture confirm file "`manifest_file'"
    assert _rc == 0

    preserve
    import delimited "`manifest_file'", varnames(1) stringcols(_all) clear
    assert _N >= 15
    forvalues i = 1/`=_N' {
        assert status[`i'] == "PASS"
        assert xlsx[`i'] != ""
        assert summary_file[`i'] != ""
        local _summary = summary_file[`i']
        capture confirm file "`pkg_dir'/`_summary'"
        assert _rc == 0
    }
    restore
}
if _rc == 0 {
    display as result "  PASS: T1 - baseline manifest summaries are present and PASS"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - baseline manifest has missing summaries or non-PASS rows (rc=`=_rc')"
    local ++fail_count
}

**# T2: Every summary carries a content-sensitive digest and never SKIP
local ++test_count
capture noisily {
    preserve
    import delimited "`manifest_file'", varnames(1) stringcols(_all) clear
    forvalues i = 1/`=_N' {
        local _summary = "`pkg_dir'/" + summary_file[`i']
        tempname fh
        file open `fh' using "`_summary'", read text
        file read `fh' _header
        file read `fh' _row
        file close `fh'
        assert strpos(`"`_header'"', "content_digest") > 0
        assert strpos(`"`_header'"', "nonempty_text_count") > 0
        assert substr(`"`_row'"', 1, 4) == "PASS"
        assert strpos(`"`_row'"', "SKIP") == 0
    }
    restore
}
if _rc == 0 {
    display as result "  PASS: T2 - baseline summaries include payload digests with no SKIP rows"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - baseline summaries are missing digest data or contain SKIP (rc=`=_rc')"
    local ++fail_count
}

**# T3: crosstab 2x2 current output matches baseline payload digest
local ++test_count
capture noisily {
    local xlsx "`output_dir'/_baseline_crosstab_2x2.xlsx"
    local actual "`output_dir'/_baseline_crosstab_2x2.tsv"
    capture erase "`xlsx'"
    capture erase "`actual'"
    clear
    input byte outcome byte exposure int freq
    0 0 40
    0 1 20
    1 0 10
    1 1 30
    end
    expand freq
    crosstab outcome exposure, xlsx("`xlsx'") sheet("Cross2x2") ///
        title("Refactor Baseline: crosstab 2x2")
    local status "`output_dir'/_baseline_crosstab_2x2_status.txt"
    capture erase "`status'"
    shell `python_cmd' "`summary_tool'" "`xlsx'" --sheet "Cross2x2" ///
        --result-file "`actual'" ///
        --expect-file "`summary_dir'/crosstab_2x2_chi2.tsv" ///
        --compare-columns status sheet title max_row max_col n_merges nonempty_text_count content_digest ///
        --status-file "`status'"
    _assert_summary_status "`status'"
    capture erase "`status'"
}
if _rc == 0 {
    display as result "  PASS: T3 - crosstab baseline payload reproduces"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - crosstab baseline payload changed (rc=`=_rc')"
    local ++fail_count
}

**# T4: regtab single-model current output matches baseline payload digest
local ++test_count
capture noisily {
    local xlsx "`output_dir'/_baseline_regtab_single.xlsx"
    local actual "`output_dir'/_baseline_regtab_single.tsv"
    capture erase "`xlsx'"
    capture erase "`actual'"
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    regtab, xlsx("`xlsx'") sheet("Single") title("Refactor Baseline: regtab single")
    local status "`output_dir'/_baseline_regtab_single_status.txt"
    capture erase "`status'"
    shell `python_cmd' "`summary_tool'" "`xlsx'" --sheet "Single" ///
        --result-file "`actual'" ///
        --expect-file "`summary_dir'/regtab_single_model.tsv" ///
        --compare-columns status sheet title max_row max_col n_merges nonempty_text_count content_digest ///
        --status-file "`status'"
    _assert_summary_status "`status'"
    capture erase "`status'"
}
if _rc == 0 {
    display as result "  PASS: T4 - regtab baseline payload reproduces"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - regtab baseline payload changed (rc=`=_rc')"
    local ++fail_count
}

**# T5: table1_tc current output matches baseline payload digest
local ++test_count
capture noisily {
    local xlsx "`output_dir'/_baseline_table1_auto.xlsx"
    local actual "`output_dir'/_baseline_table1_auto.tsv"
    capture erase "`xlsx'"
    capture erase "`actual'"
    sysuse auto, clear
    table1_tc, by(foreign) vars(price auto \ mpg auto \ rep78 auto \ headroom auto) ///
        xlsx("`xlsx'") sheet("Auto") title("Refactor Baseline: table1 auto")
    local status "`output_dir'/_baseline_table1_auto_status.txt"
    capture erase "`status'"
    shell `python_cmd' "`summary_tool'" "`xlsx'" --sheet "Auto" ///
        --result-file "`actual'" ///
        --expect-file "`summary_dir'/table1_tc_autodetect.tsv" ///
        --compare-columns status sheet title max_row max_col n_merges nonempty_text_count content_digest ///
        --status-file "`status'"
    _assert_summary_status "`status'"
    capture erase "`status'"
}
if _rc == 0 {
    display as result "  PASS: T5 - table1_tc baseline payload reproduces"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - table1_tc baseline payload changed (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_baseline_artifacts tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _baseline_artifacts
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_baseline_artifacts tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _baseline_artifacts
