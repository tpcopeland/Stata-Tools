* run_all.do - Curated QA runner for diagtab
* Usage: cd diagtab/qa; stata-mp -b do run_all.do [full|quick]

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
local plus_dir "`run_token'_diagtab_plus"
local personal_dir "`run_token'_diagtab_personal"
local output_dir "`run_token'_diagtab_output"

capture mkdir "`plus_dir'"
capture mkdir "`personal_dir'"
capture mkdir "`output_dir'"
sysdir set PLUS "`plus_dir'"
sysdir set PERSONAL "`personal_dir'"
global DIAGTAB_QA_OUTPUT_DIR "`output_dir'"
discard

capture ado uninstall diagtab
capture noisily net install diagtab, from("`pkg_dir'") replace
local install_rc = _rc
if `install_rc' {
    sysdir set PLUS "`orig_plus'"
    sysdir set PERSONAL "`orig_personal'"
    global DIAGTAB_QA_OUTPUT_DIR
    discard
    capture shell rm -rf "`plus_dir'" "`personal_dir'" "`output_dir'"
    exit `install_rc'
}

local files "test_diagtab.do test_diagtab_errors.do test_diagtab_documentation_examples.do"
if "`lane'" == "full" local files "`files' validation_diagtab.do"

local suite_pass = 0
local suite_fail = 0
foreach file of local files {
    capture noisily do "`qa_dir'/`file'"
    if _rc local ++suite_fail
    else local ++suite_pass
}

sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
global DIAGTAB_QA_OUTPUT_DIR
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'" "`output_dir'"

local suite_total = `suite_pass' + `suite_fail'
display "RESULT: run_all_diagtab tests=`suite_total' pass=`suite_pass' fail=`suite_fail'"
if `suite_fail' exit 1
