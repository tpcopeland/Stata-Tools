* run_all.do - curated QA runner for finegray
* Usage: cd finegray/qa && stata-mp -b do run_all.do [quick|core|python|full]

version 16.0
set more off
set varabbrev off

args lane extra

local lane = lower(strtrim("`lane'"))
if "`lane'" == "" local lane "full"

if "`extra'" != "" {
    display as error "run_all.do accepts at most one lane argument."
    exit 198
}

if !inlist("`lane'", "quick", "core", "python", "full") {
    display as error "Unknown QA lane: `lane'"
    display as error "Supported lanes: quick, core, python, full"
    exit 198
}

local qa_dir "`c(pwd)'"
do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap

local orig_plus "`r(orig_plus)'"
local orig_personal "`r(orig_personal)'"
local plus_dir "`r(plus_dir)'"
local personal_dir "`r(personal_dir)'"
local skip_file "`qa_dir'/_skip.txt"

* Explicit lane membership. Do not auto-discover files here; new suites should
* be reviewed and added deliberately so release coverage cannot drift silently.
local quick_files test_finegray.do test_finegray_v110.do test_finegray_v111.do ///
    test_finegray_v112.do test_finegray_v114.do
local core_files `quick_files' ///
    validation_finegray.do validation_finegray_recovery.do ///
    validation_finegray_recovery_paths.do validation_finegray_cif_recovery.do ///
    validation_finegray_cif_se.do validation_finegray_lt_se.do ///
    crossval_predict_stcrreg.do
local python_files crossval_cif.do crossval_predict_phtest.do crossval_finegray.do
local full_files `core_files' `python_files'

local all_files ``lane'_files'

* Read optional skip list: one "file.do | reason" per line.
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

display as text "finegray QA lane: `lane'"
display as text "Curated QA files: `n_discovered'"

foreach f of local all_files {
    local in_skip : list f in skip_names
    if `in_skip' {
        local ++n_skip
        local skip_key = subinstr("`f'", ".", "_", .)
        display _newline as text "=== Skipping: `f' ==="
        display as text "  Reason: `skip_reason_`skip_key''"
        continue
    }

    capture confirm file "`qa_dir'/`f'"
    if _rc {
        local ++n_fail
        local failed_files "`failed_files' `f'"
        display _newline as error "=== Missing: `f' ==="
        continue
    }

    local ++n_run
    display _newline as text "=== Running: `f' ==="
    clear all
    set more off
    set varabbrev off
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
}

display _newline as result ///
    "=== QA Summary (`lane'): `n_pass'/`n_run' passed, `n_fail' failed, `n_skip' skipped ==="
display as text "RESULT: run_all tests=`n_run' pass=`n_pass' fail=`n_fail' skip=`n_skip'"

local suite_rc = 0
if `n_fail' > 0 {
    display as error "Failed files:`failed_files'"
    local suite_rc = 1
}
else {
    display as result "ALL CURATED QA FILES PASSED"
}

capture ado uninstall finegray
sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'"

if `suite_rc' > 0 exit `suite_rc'
