* run_all.do - QA runner for tabtools (flat layout, v1.7.0)
* Usage: cd into qa/ directory, then: stata-mp -b do run_all.do [full|quick|release|benchmark]
*
* Lanes:
*   full      - curated functional, validation, and crossval suite (default)
*   quick     - curated functional suite, minus the adversarial suite
*   release   - full plus benchmark_tabtools_speed.do
*   benchmark - benchmark_tabtools_speed.do only
*
* The runner installs the package into a sandboxed PLUS/PERSONAL so the
* user's real ado tree is never touched, and restores it afterwards.
* Individual files can be skipped via _skip.txt ("file.do | reason" lines).

clear all

args lane
local lane = lower(strtrim("`lane'"))
if "`lane'" == "" local lane "full"
if !inlist("`lane'", "full", "quick", "release", "benchmark") {
    display as error "Usage: run_all.do [full|quick|release|benchmark]"
    exit 198
}

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local skip_file "`qa_dir'/_skip.txt"
local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
tempname install_id
local install_tag = subinstr("`install_id'", "__", "", .)
local plus_dir "`c(tmpdir)'/tabtools_plus_`install_tag'"
local personal_dir "`c(tmpdir)'/tabtools_personal_`install_tag'"
local run_output_dir "`c(tmpdir)'/tabtools_qa_output_`install_tag'"

capture mkdir "`plus_dir'"
capture mkdir "`personal_dir'"
capture mkdir "`run_output_dir'"
global TABTOOLS_QA_OUTPUT_DIR "`run_output_dir'"
sysdir set PLUS "`plus_dir'"
sysdir set PERSONAL "`personal_dir'"
discard

* Full/release lanes require their external simulation oracles. Install them
* inside the disposable ado tree so an absent user installation cannot turn a
* release run into an unreported embedded skip.
local oracle_rc = 0
if inlist("`lane'", "full", "release") {
    foreach dep in simsum sencode labelsof {
        capture noisily ssc install `dep', replace
        if _rc {
            display as error "required QA dependency `dep' could not be installed"
            local oracle_rc = _rc
        }
    }
    capture noisily net install siman, ///
        from("https://raw.githubusercontent.com/UCL/siman/master/") replace
    if _rc {
        display as error "required QA dependency siman could not be installed"
        local oracle_rc = _rc
    }
    foreach dep in simsum sencode labelsof siman {
        capture which `dep'
        if _rc {
            display as error "required QA dependency `dep' is not discoverable in the sandbox"
            local oracle_rc = 111
        }
    }
}
if `oracle_rc' {
    sysdir set PLUS "`orig_plus'"
    sysdir set PERSONAL "`orig_personal'"
    discard
    global TABTOOLS_QA_OUTPUT_DIR
    capture shell rm -rf "`plus_dir'" "`personal_dir'" "`run_output_dir'"
    exit `oracle_rc'
}

capture ado uninstall tabtools
capture noisily net install tabtools, from("`pkg_dir'") replace
local install_rc = _rc
if `install_rc' {
    sysdir set PLUS "`orig_plus'"
    sysdir set PERSONAL "`orig_personal'"
    discard
    global TABTOOLS_QA_OUTPUT_DIR
    capture shell rm -rf "`plus_dir'" "`personal_dir'" "`run_output_dir'"
    exit `install_rc'
}

* Explicit lane membership. Do not auto-discover files here; new suites should
* be reviewed and added deliberately so release coverage cannot drift silently.
local test_files ""
local test_files "`test_files' test_ci_level_provenance.do"
local test_files "`test_files' test_comptab.do"
local test_files "`test_files' test_corrtab.do"
local test_files "`test_files' test_crosstab.do"
local test_files "`test_files' test_desctab.do"
local test_files "`test_files' test_diagtab.do"
local test_files "`test_files' test_deep_audit_core.do"
local test_files "`test_files' test_deep_audit_output.do"
local test_files "`test_files' test_effecttab.do"
local test_files "`test_files' test_hrcomptab.do"
local test_files "`test_files' test_package_adversarial.do"
local test_files "`test_files' test_package_hardening.do"
local test_files "`test_files' test_package_helpers.do"
local test_files "`test_files' test_package_integration.do"
local test_files "`test_files' test_package_release.do"
local test_files "`test_files' test_puttab.do"
local test_files "`test_files' test_regtab.do"
local test_files "`test_files' test_simtab.do"
local test_files "`test_files' test_stacktab.do"
local test_files "`test_files' test_stratetab.do"
local test_files "`test_files' test_survtab.do"
local test_files "`test_files' test_table1_tc.do"
local test_files "`test_files' test_tabtools.do"
local test_files "`test_files' test_tabtools_tips.do"
local test_files "`test_files' test_option_coverage.do"

local validation_files ""
local validation_files "`validation_files' validation_corrtab.do"
local validation_files "`validation_files' validation_crosstab.do"
local validation_files "`validation_files' validation_diagtab.do"
local validation_files "`validation_files' validation_effecttab.do"
local validation_files "`validation_files' validation_package.do"
local validation_files "`validation_files' validation_regtab.do"
local validation_files "`validation_files' validation_simtab.do"
local validation_files "`validation_files' validation_stratetab.do"
local validation_files "`validation_files' validation_survtab.do"
local validation_files "`validation_files' validation_table1_tc.do"

local crossval_files "crossval_tabtools.do"
local benchmark_files "benchmark_tabtools_speed.do"

local quick_files "`test_files'"
local adversarial "test_package_adversarial.do"
local quick_files : list quick_files - adversarial

local full_files "`test_files' `validation_files' `crossval_files'"

if "`lane'" == "quick" {
    local all_files "`quick_files'"
}
else if "`lane'" == "benchmark" {
    local all_files "`benchmark_files'"
}
else if "`lane'" == "release" {
    local all_files "`full_files' `benchmark_files'"
}
else {
    local all_files "`full_files'"
}

* Read skip list
local skip_names ""
capture confirm file "`skip_file'"
if _rc == 0 {
    tempname skipfh
    file open `skipfh' using "`skip_file'", read text
    file read `skipfh' line
    while r(eof) == 0 {
        local raw = strtrim(`"`line'"')
        if "`raw'" != "" & substr("`raw'", 1, 1) != "#" {
            gettoken skip_name skip_reason : raw, parse("|")
            local skip_name = strtrim("`skip_name'")
            local skip_reason = subinstr(`"`skip_reason'"', "|", "", 1)
            local skip_reason = strtrim(`"`skip_reason'"')
            if "`skip_name'" != "" {
                local skip_names : list skip_names | skip_name
                if "`skip_reason'" == "" {
                    local skip_reason "listed in _skip.txt"
                }
                local skip_key = subinstr("`skip_name'", ".", "_", .)
                local skip_reason_`skip_key' `"`skip_reason'"'
            }
        }
        file read `skipfh' line
    }
    file close `skipfh'
}

local n_discovered = 0
foreach f of local all_files {
    local ++n_discovered
}

local n_run = 0
local n_pass = 0
local n_fail = 0
local n_skip = 0
local failed_files ""

display as text "QA lane: `lane'"
display as text "Discovered QA files: `n_discovered'"
if "`skip_names'" != "" {
    display as text "Skip file: `skip_file'"
}

if inlist("`lane'", "full", "release") global TABTOOLS_QA_REQUIRE_ORACLES 1
else global TABTOOLS_QA_REQUIRE_ORACLES

foreach f of local all_files {
    local in_skip : list f in skip_names
    if `in_skip' {
        local ++n_skip
        local skip_key = subinstr("`f'", ".", "_", .)
        display _newline
        display as text "=== Skipping: `f' ==="
        display as text "  Reason: `skip_reason_`skip_key''"
        continue
    }

    local ++n_run
    display _newline
    display as text "=== Running: `f' ==="
    clear all
    discard
    set more off
    capture noisily do "`qa_dir'/`f'"
    if _rc == 0 {
        local ++n_pass
        display as result "  PASSED: `f'"
    }
    else {
        local ++n_fail
        local failed_files "`failed_files' `f'"
        display as error "  FAILED: `f' (rc=`=_rc')"
    }
    capture shell rm -f /tmp/St${c(pid)}*.dta
}

display _newline
display as result "=== Suite Summary: `n_pass'/`n_run' passed, `n_fail' failed, `n_skip' skipped, `n_discovered' discovered ==="
if `n_skip' > 0 {
    display as text "Skipped files came from _skip.txt."
}

local suite_rc = 0
if `n_fail' > 0 {
    display as error "Failed files:`failed_files'"
    local suite_rc = 1
}
else {
    display as result "ALL DISCOVERED QA FILES PASSED"
}

capture ado uninstall tabtools
global TABTOOLS_QA_REQUIRE_ORACLES
global TABTOOLS_QA_OUTPUT_DIR
sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'" "`run_output_dir'"

if `suite_rc' > 0 exit `suite_rc'
