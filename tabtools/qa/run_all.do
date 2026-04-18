* run_all.do — auto-discovering full-suite QA runner for tabtools
* Usage: cd into qa/ directory, then: stata-mp -b do run_all.do

clear all

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local skip_file "`qa_dir'/_skip.txt"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_files : dir "`qa_dir'" files "test_*.do"
local val_files : dir "`qa_dir'" files "validation_*.do"
local xval_files : dir "`qa_dir'" files "crossval_*.do"
local all_files : list test_files | val_files
local all_files : list all_files | xval_files
local all_files : list sort all_files

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
    if "`f'" != "run_all.do" & "`f'" != "refactor_baseline.do" {
        local ++n_discovered
    }
}

local n_run = 0
local n_pass = 0
local n_fail = 0
local n_skip = 0
local failed_files ""

display as text "Discovered QA files: `n_discovered'"
if "`skip_names'" != "" {
    display as text "Skip file: `skip_file'"
}

foreach f of local all_files {
    if "`f'" == "run_all.do" | "`f'" == "refactor_baseline.do" {
        continue
    }

    local in_skip : list f in skip_names
    if `in_skip' {
        local ++n_skip
        local skip_key = subinstr("`f'", ".", "_", .)
        local skip_reason `"`skip_reason_`skip_key''"'
        display _newline
        display as text "=== Skipping: `f' ==="
        display as text "  Reason: `skip_reason'"
        continue
    }

    local ++n_run
    display _newline
    display as text "=== Running: `f' ==="
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

if `suite_rc' > 0 exit `suite_rc'
