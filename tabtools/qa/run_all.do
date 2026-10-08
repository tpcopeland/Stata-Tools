* run_all.do - QA runner for tabtools (flat layout)
* Usage: cd into qa/ directory, then: stata-mp -b do run_all.do [full|core|quick|release|benchmark]
*
* Lanes:
*   full      - curated functional, validation, and crossval suite (default)
*   quick     - curated functional suite, minus the adversarial suite
*   core      - functional and known-answer validation suites
*   release   - full plus benchmark_tabtools_speed.do
*   benchmark - benchmark_tabtools_speed.do only
*
* The runner installs the package into a sandboxed PLUS/PERSONAL so the
* user's real ado tree is never touched, and restores it afterwards.
* Individual files can be skipped via _skip.txt ("file.do | reason" lines).

clear all
set processors 1
set varabbrev off
version 17.0

args lane extra
local lane = lower(strtrim("`lane'"))
if "`lane'" == "" local lane "full"
if "`extra'" != "" | !inlist("`lane'", "full", "core", "quick", "release", "benchmark") {
    display as error "Usage: run_all.do [full|core|quick|release|benchmark]"
    exit 198
}

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local skip_file "`qa_dir'/_skip.txt"
local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
* tempfile paths are process-unique in Stata 16/17. c(pid) is undefined in
* those versions and silently expands to empty inside a quoted path.
tempfile run_token
local plus_dir "`run_token'_tabtools_plus"
local personal_dir "`run_token'_tabtools_personal"
local run_output_dir "`run_token'_tabtools_qa_output"

capture mkdir "`plus_dir'"
capture mkdir "`personal_dir'"
capture mkdir "`run_output_dir'"
global TABTOOLS_QA_OUTPUT_DIR "`run_output_dir'"
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
    global TABTOOLS_QA_OUTPUT_DIR
    capture shell rm -rf "`plus_dir'" "`personal_dir'" "`run_output_dir'"
    exit `install_rc'
}

* Explicit lane membership. Do not auto-discover files here; new suites should
* be reviewed and added deliberately so release coverage cannot drift silently.
local test_files "validation_tabtools_fixture_contract.do validation_tabtools_fixture_descriptive.do validation_tabtools_fixture_models.do validation_tabtools_fixture_catalogue_primitives.do validation_tabtools_fixture_numeric_primitives.do test_tabtools_fixture_files.do test_tabtools_fixture_path_macros.do test_tabtools_fixture_rreturns.do test_tabtools_fixture_publication.do validation_tabtools_fixture_domains.do test_corrtab_fixture_stars.do validation_corrtab_fixture_inputs.do test_corrtab_fixture_legacy.do validation_tabtools_fixture_fonts.do validation_tabtools_fixture_strings.do validation_tabtools_fixture_remaining.do test_survtab_fixture_state.do"
local test_files "`test_files' test_ci_level_provenance.do"
local test_files "`test_files' test_column_widths.do"
local test_files "`test_files' test_comptab.do"
local test_files "`test_files' test_corrtab.do"
local test_files "`test_files' test_crosstab.do"
local test_files "`test_files' test_desctab.do"
local test_files "`test_files' test_deep_audit_core.do"
local test_files "`test_files' test_deep_audit_output.do"
local test_files "`test_files' test_effecttab.do"
local test_files "`test_files' test_effecttab_omitted.do"
local test_files "`test_files' test_effecttab_layout.do"
local test_files "`test_files' test_audit_2026_09_02.do"
local test_files "`test_files' test_hrcomptab.do"
local test_files "`test_files' test_package_adversarial.do"
local test_files "`test_files' test_package_hardening.do"
local test_files "`test_files' test_package_helpers.do"
local test_files "`test_files' test_package_integration.do"
local test_files "`test_files' test_package_release.do"
local test_files "`test_files' test_puttab.do"
local test_files "`test_files' test_regtab.do"
local test_files "`test_files' test_regtab_omitted.do"
local test_files "`test_files' test_regtab_multieq_mixed.do"
local test_files "`test_files' test_smallcells.do"
local test_files "`test_files' test_stacktab.do"
local test_files "`test_files' test_stratetab.do"
local test_files "`test_files' test_survtab.do"
local test_files "`test_files' test_table1_tc.do"
local test_files "`test_files' test_tabtools.do"
local test_files "`test_files' test_tabtools_errors.do"
local test_files "`test_files' test_tabtools_documentation_examples.do"
local test_files "`test_files' test_tabtools_oracle.do"
local test_files "`test_files' test_tabtools_tips.do"
local test_files "`test_files' test_tabtools_v1163.do"
local test_files "`test_files' test_tabtools_v202.do"
local test_files "`test_files' test_theme_removed.do"
local test_files "`test_files' test_option_coverage.do"
local test_files "`test_files' test_issue_review_1_11_0.do"
local test_files "`test_files' test_synthesis_review.do"
local test_files "`test_files' test_review_2026_08_13.do"
local test_files "`test_files' test_review_2026_09_15.do"
local test_files "`test_files' test_review_2026_09_25_rates_puttab.do"
local test_files "`test_files' test_xlsx_style_compaction.do"
local test_files "`test_files' test_xlsx_deferred_styles.do"
local test_files "`test_files' test_final_review_helpers.do"
local test_files "`test_files' test_final_review_models.do"
local test_files "`test_files' test_final_review_docs.do"
local test_files "`test_files' test_output_sinks_markdown.do"
local test_files "`test_files' test_table1_overflow.do"
local test_files "`test_files' test_audit_2026_09_26_fixes.do"
local test_files "`test_files' test_puttab_stacktab_2026_09_27.do"
local test_files "`test_files' test_regtab_backlog_2026_09_26.do"
local test_files "`test_files' test_followups_2026_09_27.do"
local test_files "`test_files' test_review_2026_09_26_fixes.do"
local test_files "`test_files' test_regtab_crossmodel_ancillary.do"
local test_files "`test_files' test_codex_audit_2026_09_26.do"
local test_files "`test_files' test_codex_parity_2026_09_26.do"
local test_files "`test_files' test_open_items_2026_09_27.do"
local test_files "`test_files' test_codex_audit_2026_09_27.do"
local test_files "`test_files' test_tabtools_state_sweep.do"
local test_files "`test_files' test_tabtools_surfaces.do"
local test_files "`test_files' test_review_2026_09_29.do"
local test_files "`test_files' test_smallcells_derivable.do"
local test_files "`test_files' test_review_2026_10_01_composition.do"
local test_files "`test_files' test_review_2026_10_01_models.do"
local test_files "`test_files' test_review_2026_10_01_statistics.do"
local test_files "`test_files' test_runner_contracts.do"
local test_files "`test_files' test_border_geometry.do"
* 2.3.0 features
local test_files "`test_files' test_puttab_v230.do"
local test_files "`test_files' test_smallcells_v230.do"
local test_files "`test_files' test_tabtools_v230.do"
local test_files "`test_files' test_stacktab_v230.do"
local test_files "`test_files' test_desctab_v230.do"
local test_files "`test_files' test_writers_v230.do"
local test_files "`test_files' test_regtab_v230.do"
local test_files "`test_files' test_effecttab_v230.do"
local test_files "`test_files' test_tabcell_v230.do"
local test_files "`test_files' test_comptab_v230.do"
local test_files "`test_files' test_stratetab_v230.do"
local test_files "`test_files' test_outtab_v230.do"
local test_files "`test_files' test_regtab_v230_review.do"
local test_files "`test_files' test_v230_review.do"
local test_files "`test_files' test_outtab_v230_review.do"
local test_files "`test_files' test_comptab_v230_review.do"
* 2.3.1 features
local test_files "`test_files' test_v231_formats.do"
local test_files "`test_files' test_session_sinks_v231.do"
local test_files "`test_files' test_tabcell_v231.do"
local test_files "`test_files' test_ratetab_v231.do"
local test_files "`test_files' test_stratetab_v231.do"
local test_files "`test_files' test_regtab_v231.do"
local test_files "`test_files' test_fitcount_v231.do"
* 2.4.0 features
local test_files "`test_files' test_regtab_v240.do"
local test_files "`test_files' test_regtab_v240b.do"
local test_files "`test_files' test_ratetab_v240.do"
local test_files "`test_files' test_tabtools_set_v240.do"
local test_files "`test_files' test_tabcell_v240.do"
local test_files "`test_files' test_puttab_v240.do"
local test_files "`test_files' test_desctab_v240.do"
* 2.5.0 features
local test_files "`test_files' test_regtab_v250.do"
local test_files "`test_files' test_regtab_stats_v250.do"
local test_files "`test_files' test_puttab_v250.do"
local test_files "`test_files' test_tabcell_v250.do"
local test_files "`test_files' test_sep_v250.do"
* 2.5.2 bug-report fixes (2026-10-06)
local test_files "`test_files' test_bugfix_2026_10_06_a.do"
local test_files "`test_files' test_bugfix_2026_10_06_b.do"
local test_files "`test_files' test_bugfix_2026_10_06_c.do"
local test_files "`test_files' test_bugfix_2026_10_06_d.do"
local test_files "`test_files' test_bugfix_2026_10_06_e.do"
local test_files "`test_files' test_bugfix_2026_10_06_f.do"
local test_files "`test_files' test_bugfix_2026_10_06_g.do"
local test_files "`test_files' test_bugfix_2026_10_06_i.do"
local test_files "`test_files' test_bugfix_2026_10_06_j.do"
local test_files "`test_files' test_bugfix_2026_10_06_l.do"
local test_files "`test_files' test_bugfix_2026_10_06_m.do"
local test_files "`test_files' test_bugfix_2026_10_06_n.do"
local test_files "`test_files' test_ratetab_v254_cluster.do"
local test_files "`test_files' test_pct_floor.do"

local validation_files "validation_tabtools_precision.do validation_stacktab_precision_controls.do"
local validation_files "`validation_files' validation_corrtab.do"
local validation_files "`validation_files' validation_crosstab.do"
local validation_files "`validation_files' validation_effecttab.do"
local validation_files "`validation_files' validation_package.do"
local validation_files "`validation_files' validation_regtab.do"
local validation_files "`validation_files' validation_smallcells.do"
local validation_files "`validation_files' validation_stratetab.do"
local validation_files "`validation_files' validation_survtab.do"
local validation_files "`validation_files' validation_table1_tc.do"
local validation_files "`validation_files' validation_regtab_return_contracts.do"

local crossval_files "crossval_tabtools.do"
local crossval_files "`crossval_files' crossval_crosstab_cochran.do"
local crossval_files "`crossval_files' crossval_ratetab_v230.do"
local crossval_files "`crossval_files' test_ratetab_v230_review.do"
local benchmark_files "benchmark_tabtools_speed.do"

local quick_files "`test_files'"
local adversarial "test_package_adversarial.do"
local quick_files : list quick_files - adversarial

local full_files "`test_files' `validation_files' `crossval_files'"
local core_files "`test_files' `validation_files'"

if "`lane'" == "quick" {
    local all_files "`quick_files'"
}
else if "`lane'" == "core" {
    local all_files "`core_files'"
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
                * Index the reason by POSITION, not by a name derived from the
                * filename. "skip_reason_" plus a mangled filename exceeds
                * Stata's 31-character local-name limit for any name longer than
                * 19 characters (test_tabtools_tips.do -> 33 chars), which made
                * the whole runner die with r(198) "invalid name" as soon as a
                * realistic filename was listed in _skip.txt.
                local skip_idx : list sizeof skip_names
                local skip_reason_`skip_idx' `"`skip_reason'"'
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

foreach f of local all_files {
    local in_skip : list f in skip_names
    if `in_skip' {
        local ++n_skip
        local skipped_files "`skipped_files' `f'"
        local skip_pos : list posof "`f'" in skip_names
        display _newline
        display as text "=== Skipping: `f' ==="
        display as text "  Reason: `skip_reason_`skip_pos''"
        continue
    }

    local ++n_run
    display _newline
    display as text "=== Running: `f' ==="
    clear all
    discard
    set more off
    local child_name = substr("`f'", 1, strlen("`f'") - 3)
    local child_log "`qa_dir'/`child_name'.log"
    if "`f'" == "benchmark_tabtools_speed.do" ///
        local child_log "`run_output_dir'/`child_name'.log"
    capture erase "`child_log'"
    capture confirm file "`child_log'"
    if !_rc {
        local ++n_fail
        local failed_files "`failed_files' `f'"
        display as error "  FAILED: `f' (cannot remove stale child log)"
        continue
    }
    tempfile child_capture child_status
    capture log close _qa_child
    log using "`child_capture'", text replace name(_qa_child)
    capture noisily do "`qa_dir'/`f'"
    local child_rc = _rc
    capture log close _qa_child
    if `child_rc' == 0 {
        local skip_option ""
        if "`lane'" == "quick" local skip_option "--allow-skip"
        capture noisily shell python3 "`qa_dir'/tools/check_suite_result.py" ///
            "`child_name'" "`child_log'" "`child_capture'" ///
            --status "`child_status'" `skip_option'
        capture confirm file "`child_status'"
        if _rc local child_rc = 1
        else {
            tempname receipt_fh
            file open `receipt_fh' using "`child_status'", read text
            file read `receipt_fh' receipt
            file close `receipt_fh'
            if "`receipt'" != "PASS" local child_rc = 1
        }
    }
    if `child_rc' == 0 {
        local ++n_pass
        display as result "  PASSED: `f'"
    }
    else {
        local ++n_fail
        local failed_files "`failed_files' `f'"
        display as error "  FAILED: `f' (rc=`child_rc')"
    }
}

display _newline
display as result "=== Suite Summary: `n_pass'/`n_run' passed, `n_fail' failed, `n_skip' skipped, `n_discovered' discovered ==="

local suite_rc = 0
if `n_fail' > 0 {
    display as error "Failed files:`failed_files'"
    local suite_rc = 1
}

* A SKIP IS NOT A PASS. The verdict used to depend on n_fail alone, so adding a
* file to _skip.txt removed it from the suite while the run still printed
* "ALL DISCOVERED QA FILES PASSED" and exited 0 -- a gate that can be disarmed
* by editing a text file is not a gate. The curated full and release lanes now
* fail on any skip; quick remains advisory.
if `n_skip' > 0 {
    display as text "Skipped files came from _skip.txt:`skipped_files'"
    if inlist("`lane'", "core", "full", "release", "benchmark") {
        display as error "`n_skip' file(s) were skipped; the `lane' lane requires every discovered file to run"
        display as error "remove the _skip.txt entries, or use the quick lane if a skip is intended"
        local suite_rc = 1
    }
}

if `suite_rc' == 0 {
    display as result "ALL DISCOVERED QA FILES PASSED"
}

capture ado uninstall tabtools
global TABTOOLS_QA_OUTPUT_DIR
sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'" "`run_output_dir'"

* Keep the canonical runner name literal so external launchers parse this
* aggregate verdict instead of mistaking a green final child for a green lane.
display "RESULT: run_all tests=`n_discovered' pass=`n_pass' fail=`n_fail' skip=`n_skip'"
if `suite_rc' > 0 exit `suite_rc'
