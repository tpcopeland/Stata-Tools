* run_all.do - Curated QA runner for simtab
* Usage: cd simtab/qa; stata-mp -b do run_all.do [full|quick]

clear all
set processors 1
set varabbrev off
version 17.0

args lane extra
local lane = lower(strtrim("`lane'"))
if "`lane'" == "" local lane "full"
if "`extra'" != "" | !inlist("`lane'", "quick", "full") {
    display as error "Usage: run_all.do [full|quick]"
    exit 198
}

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
tempfile run_token
local plus_dir "`run_token'_simtab_plus"
local personal_dir "`run_token'_simtab_personal"
local output_dir "`run_token'_simtab_output"

capture mkdir "`plus_dir'"
capture mkdir "`personal_dir'"
capture mkdir "`output_dir'"
sysdir set PLUS "`plus_dir'"
sysdir set PERSONAL "`personal_dir'"
global SIMTAB_QA_OUTPUT_DIR "`output_dir'"
discard

* Full lanes require live reference implementations. Install them inside the
* disposable ado tree so a missing user installation cannot become a skip.
local oracle_rc = 0
if "`lane'" == "full" {
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
    global SIMTAB_QA_OUTPUT_DIR
    discard
    capture shell rm -rf "`plus_dir'" "`personal_dir'" "`output_dir'"
    exit `oracle_rc'
}

capture ado uninstall simtab
capture noisily net install simtab, from("`pkg_dir'") replace
local install_rc = _rc
if `install_rc' {
    sysdir set PLUS "`orig_plus'"
    sysdir set PERSONAL "`orig_personal'"
    global SIMTAB_QA_OUTPUT_DIR
    discard
    capture shell rm -rf "`plus_dir'" "`personal_dir'" "`output_dir'"
    exit `install_rc'
}

local files "test_simtab.do"
if "`lane'" == "full" local files "`files' validation_simtab.do"
if "`lane'" == "full" global SIMTAB_QA_REQUIRE_ORACLES 1
else global SIMTAB_QA_REQUIRE_ORACLES

local suite_pass = 0
local suite_fail = 0
foreach file of local files {
    capture noisily do "`qa_dir'/`file'"
    if _rc local ++suite_fail
    else local ++suite_pass
}

sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
global SIMTAB_QA_OUTPUT_DIR
global SIMTAB_QA_REQUIRE_ORACLES
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'" "`output_dir'"

local suite_total = `suite_pass' + `suite_fail'
display "RESULT: run_all_simtab tests=`suite_total' pass=`suite_pass' fail=`suite_fail'"
if `suite_fail' exit 1
