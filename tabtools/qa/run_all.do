* run_all.do - auto-discovering QA runner for tabtools
* Usage: cd into qa/ directory, then: stata-mp -b do run_all.do [full|quick|release|benchmark]

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

capture mkdir "`plus_dir'"
capture mkdir "`personal_dir'"
sysdir set PLUS "`plus_dir'"
sysdir set PERSONAL "`personal_dir'"
discard
capture ado uninstall tabtools
capture noisily net install tabtools, from("`pkg_dir'") replace
local install_rc = _rc
if `install_rc' {
    sysdir set PLUS "`orig_plus'"
    sysdir set PERSONAL "`orig_personal'"
    discard
    capture shell rm -rf "`plus_dir'" "`personal_dir'"
    exit `install_rc'
}

local scan_dirs "."
local child_dirs : dir "`qa_dir'" dirs "*"
local child_dirs : list sort child_dirs
foreach d of local child_dirs {
    if inlist("`d'", "baseline", "data", "output", "output_issue_regressions", ///
        "output_issue_rendering", "tools") {
        continue
    }
    local scan_dirs `"`scan_dirs' `d'"'
}

local all_files ""
if "`lane'" != "benchmark" {
    foreach d of local scan_dirs {
        local scan_path "`qa_dir'"
        if "`d'" != "." {
            local scan_path "`qa_dir'/`d'"
        }

        local test_files : dir "`scan_path'" files "test_*.do"
        local val_files : dir "`scan_path'" files "validation_*.do"
        local xval_files : dir "`scan_path'" files "crossval_*.do"
        local dir_files : list test_files | val_files
        local dir_files : list dir_files | xval_files
        local dir_files : list sort dir_files

        foreach f of local dir_files {
            local rel_file "`f'"
            if "`d'" != "." {
                local rel_file "`d'/`f'"
            }
            local all_files : list all_files | rel_file
        }
    }
}

if inlist("`lane'", "release", "benchmark") {
    local benchmark_files "_package/benchmark_tabtools_speed.do"
    foreach f of local benchmark_files {
        capture confirm file "`qa_dir'/`f'"
        if _rc == 0 {
            local all_files : list all_files | f
        }
    }
}

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
                local skip_key = subinstr(subinstr("`skip_name'", "/", "_", .), ".", "_", .)
                local skip_reason_`skip_key' `"`skip_reason'"'
            }
        }
        file read `skipfh' line
    }
    file close `skipfh'
}

local n_discovered = 0
local quick_package_files "test_collect_json_render_contracts.do test_console_display_contracts.do test_export_failure_returns.do test_mata_backend_contracts.do test_public_inventory_v136.do test_refactor_contracts.do test_regression_fixes.do test_shared_style_engine_after_migration.do test_style_engine_apply_styles.do test_table1_tc_aggregation_contracts.do test_table1_tc_before_fixtures_parity.do test_xlsx_read_current_contracts.do"
foreach f of local all_files {
    local base "`f'"
    if regexm("`f'", ".*/([^/]+)$") {
        local base = regexs(1)
    }
    if "`base'" != "run_all.do" & "`base'" != "refactor_baseline.do" {
        local is_quick_package_drop = 0
        if "`lane'" == "quick" & substr("`f'", 1, 9) == "_package/" {
            local quick_keep : list base in quick_package_files
            if !`quick_keep' local is_quick_package_drop = 1
        }
        if "`lane'" == "quick" & (substr("`base'", 1, 11) == "validation_" | ///
            substr("`base'", 1, 9) == "crossval_" | `is_quick_package_drop' | ///
            "`base'" == "test_stress.do" | "`base'" == "test_coverage_gaps.do" | ///
            "`base'" == "test_adversarial_breakage.do") {
            continue
        }
        local ++n_discovered
    }
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

foreach f of local all_files {
    local base "`f'"
    if regexm("`f'", ".*/([^/]+)$") {
        local base = regexs(1)
    }
    if "`base'" == "run_all.do" | "`base'" == "refactor_baseline.do" {
        continue
    }
    local is_quick_package_drop = 0
    if "`lane'" == "quick" & substr("`f'", 1, 9) == "_package/" {
        local quick_keep : list base in quick_package_files
        if !`quick_keep' local is_quick_package_drop = 1
    }
    if "`lane'" == "quick" & (substr("`base'", 1, 11) == "validation_" | ///
        substr("`base'", 1, 9) == "crossval_" | `is_quick_package_drop' | ///
        "`base'" == "test_stress.do" | "`base'" == "test_coverage_gaps.do" | ///
        "`base'" == "test_adversarial_breakage.do") {
        continue
    }

    local in_skip : list f in skip_names
    local in_skip_base : list base in skip_names
    if `in_skip' | `in_skip_base' {
        local ++n_skip
        local skip_name "`f'"
        if `in_skip_base' {
            local skip_name "`base'"
        }
        local skip_key = subinstr(subinstr("`skip_name'", "/", "_", .), ".", "_", .)
        local skip_reason `"`skip_reason_`skip_key''"'
        display _newline
        display as text "=== Skipping: `f' ==="
        display as text "  Reason: `skip_reason'"
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
sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'"

if `suite_rc' > 0 exit `suite_rc'
