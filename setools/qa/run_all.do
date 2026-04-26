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
local pass = 0
local fail = 0

foreach f in ///
    test_setools ///
    _test_cci_mata ///
    _test_cci_dates ///
    validation_setools ///
    validation_known_answer_boundaries ///
    validation_cci_se_v121 ///
    test_migrations_perm_emig_bug ///
    test_migrations_keepimmigrants ///
    test_migrations_minresidence ///
    validation_migrations_longwide_equivalence ///
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
