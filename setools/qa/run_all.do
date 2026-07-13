*! run_all.do  2.0.0  2026/07/13
*! Curated isolated runner with quick/core/full/python/network lanes

version 16.0
capture log close _all
set more off
args mode
local mode = lower(strtrim("`mode'"))
if "`mode'" == "" local mode "core"
if !inlist("`mode'", "quick", "core", "full", "python", "network") {
    display as error "run_all.do mode must be quick, core, full, python, or network"
    display "RESULT: run_all mode=`mode' suites=0 pass=0 fail=1"
    exit 198
}

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

local quick ///
    test_setools ///
    test_release_integrity ///
    test_documentation_examples ///
    test_audit_regressions ///
    test_cci_engine_smoke ///
    test_cci_dates_parity ///
    test_cdp_adversarial ///
    validation_sustainedss_known_answers ///
    validation_pira_known_answers ///
    test_edss_fixture

local core_extra ///
    test_setools_v130_features ///
    test_setools_v140_features ///
    test_cci_se_adversarial ///
    validation_cci_se_era_boundaries ///
    validation_cci_se_known_scores ///
    validation_cci_se_date_hierarchy ///
    validation_cci_se_v121 ///
    test_cdp_roving_determinism ///
    validation_cdp_known_answers ///
    validation_cdp_threetier_confirmtype ///
    validation_cdp_roving_exit ///
    validation_known_answer_boundaries ///
    test_migrations_perm_emig_bug ///
    test_migrations_keepimmigrants ///
    test_migrations_minresidence ///
    test_migrations_malformed_rollback ///
    validation_migrations_adversarial_boundaries ///
    validation_migrations_type2_censoring ///
    validation_migrations_longwide_equivalence ///
    validation_setools ///
    crossval_setools

local core "`quick' `core_extra'"
local full "`core' crossval_cci_se_python"
local python "crossval_cci_se_python"
local network "test_network_smoke"
local suites "``mode''"

do "`qa_dir'/_setools_qa_common.do" setup_runner "`pkg_dir'"

local pass = 0
local fail = 0
local contract_fail = 0
local total : word count `suites'

foreach suite of local suites {
    tempfile contract_ok
    capture erase "`contract_ok'"
    shell grep -Fq -- "RESULT:" "`qa_dir'/`suite'.do" && touch "`contract_ok'"
    capture confirm file "`contract_ok'"
    if _rc {
        local ++fail
        local ++contract_fail
        display as error "FAILED CONTRACT: `suite'.do has no RESULT sentinel"
        continue
    }

    capture discard
    capture program drop _all
    capture noisily do "`qa_dir'/`suite'.do"
    local suite_rc = _rc
    if `suite_rc' {
        local ++fail
        display as error "FAILED: `suite'.do (rc=`suite_rc')"
    }
    else {
        local ++pass
        display as result "PASSED: `suite'.do"
    }
}

do "`qa_dir'/_setools_qa_common.do" teardown_runner

display as result "=== QA `mode' summary: `pass' passed, `fail' failed ==="
display "RESULT: run_all mode=`mode' suites=`total' pass=`pass' fail=`fail' contract_fail=`contract_fail'"
if `fail' > 0 exit 9
