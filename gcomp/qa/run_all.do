* run_all.do - Full QA suite runner for gcomp
* Usage: cd to qa/ and:  stata-mp -b do run_all.do

clear all
set more off
version 16.0

local qa_dir "`c(pwd)'"
local pass = 0
local fail = 0
local failed_files ""

* Clean any residue from aborted prior runs (gcomptab uses c(tmpdir))
local testdir "`c(tmpdir)'"
local stale : dir "`testdir'" files "_test_gcomptab*.xlsx"
foreach f of local stale {
    capture erase "`testdir'/`f'"
}
local stale2 : dir "`testdir'" files "_itest_*.xlsx"
foreach f of local stale2 {
    capture erase "`testdir'/`f'"
}
local stale3 : dir "`testdir'" files "_docex_*.xlsx"
foreach f of local stale3 {
    capture erase "`testdir'/`f'"
}
local stale4 : dir "`testdir'" files "_adv_gcomptab*.xlsx"
foreach f of local stale4 {
    capture erase "`testdir'/`f'"
}
foreach _ext in xlsx md csv {
    local stale5 : dir "`testdir'" files "_te_*.`_ext'"
    foreach f of local stale5 {
        capture erase "`testdir'/`f'"
    }
}

foreach f in ///
    test_gcomp ///
    test_adversarial_gcomp ///
    test_gcomp_validation ///
    test_gcomp_diagnostics ///
    test_stress ///
    test_interactions ///
    test_gcomp_imputation_mlogit ///
    test_gcomptab_regressions ///
    test_gcomptab_doseresponse ///
    test_gcomptab_text_export ///
    test_models ///
    test_adversarial_gcomptab ///
    test_install_smoke ///
    test_errors ///
    test_doc_examples ///
    validation_gcomp ///
    validation_adversarial_gcomp ///
    validation_extra ///
    validation_timevarying ///
    validation_gcomp_recovery ///
    crossval_gcomp ///
    crossval_external_replication ///
    crossval_mediation_se ///
    crossval_timevarying_se ///
    crossval_intervention_imputation ///
    crossval_timevarying {
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

display _n as result "=== QA Summary: `pass' passed, `fail' failed ==="
if `fail' > 0 {
    display as error "Failed files:`failed_files'"
    exit 1
}
