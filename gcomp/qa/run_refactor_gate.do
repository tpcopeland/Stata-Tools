* run_refactor_gate.do - Refactor gate QA runner for gcomp
* Usage: cd to qa/ and run:  stata-mp -b do run_refactor_gate.do

clear all
set more off
version 16.0

local qa_dir "`c(pwd)'"
local pass = 0
local fail = 0
local failed_files ""

* Clean temporary workbooks left by aborted prior runs.
local testdir "`c(tmpdir)'"
foreach pattern in "_test_gcomptab*.xlsx" "_itest_*.xlsx" ///
    "_docex_*.xlsx" "_adv_gcomptab*.xlsx" {
    local stale : dir "`testdir'" files "`pattern'"
    foreach f of local stale {
        capture erase "`testdir'/`f'"
    }
}

foreach f in ///
    test_refactor_bootstrap_dispatch ///
    test_refactor_msm_omitted ///
    test_refactor_display_golden ///
    test_refactor_gcomptab_geometry ///
    test_install_smoke ///
    test_gcomp ///
    test_adversarial_gcomp ///
    test_gcomp_diagnostics ///
    test_adversarial_gcomptab ///
    test_gcomptab_regressions ///
    test_interactions ///
    validation_gcomp ///
    validation_timevarying ///
    crossval_mediation_se ///
    crossval_timevarying_se ///
    crossval_intervention_imputation ///
    crossval_longitudinal_extended ///
    crossval_mediation_extended ///
    validation_peripartum_readiness {
    display _n as text "=============================================="
    display as text "Running: `f'.do"
    display as text "=============================================="
    capture noisily do "`qa_dir'/`f'.do"
    if _rc {
        local ++fail
        local failed_files "`failed_files' `f'"
        display as error "FAILED: `f'.do (rc=`=_rc')"
    }
    else {
        local ++pass
        display as result "PASSED: `f'.do"
    }
}

display _n as result "=== Refactor Gate Summary: `pass' passed, `fail' failed ==="
if `fail' > 0 {
    display as error "Failed files:`failed_files'"
    exit 1
}
