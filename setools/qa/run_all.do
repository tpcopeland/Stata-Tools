/*******************************************************************************
* run_all.do
* Runner for the full setools QA suite
*
* Run from setools/qa/ directory:
*   stata-mp -b do run_all.do
*******************************************************************************/

version 16.0
capture log close _all

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

* Install the local package under test so an SSC/GitHub copy on the adopath
* cannot shadow the source being validated (path derived from c(pwd)).
capture ado uninstall setools
quietly net install setools, from("`pkg_dir'") replace

local pass = 0
local fail = 0

foreach f in ///
    test_setools ///
    test_setools_v130_features ///
    test_release_integrity ///
    test_documentation_examples ///
    _test_cci_mata ///
    _test_cci_dates ///
    test_cci_se_adversarial ///
    validation_cci_se_era_boundaries ///
    test_cdp_adversarial ///
    validation_cdp_known_answers ///
    validation_setools ///
    validation_known_answer_boundaries ///
    validation_cci_se_v121 ///
    test_migrations_perm_emig_bug ///
    test_migrations_keepimmigrants ///
    test_migrations_minresidence ///
    test_migrations_malformed_rollback ///
    validation_migrations_adversarial_boundaries ///
    validation_migrations_longwide_equivalence ///
    validation_sustainedss_known_answers ///
    validation_pira_known_answers ///
    crossval_setools {
    capture discard
    capture program drop _all
    capture noisily do "`qa_dir'/`f'.do"
    if _rc {
        local ++fail
        display as error "FAILED: `f'.do"
    }
    else {
        local ++pass
        display as result "PASSED: `f'.do"
    }
}

display as text ""
display as result "=== QA Summary: `pass' passed, `fail' failed ==="
if `fail' > 0 exit 1
