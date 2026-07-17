*! run_all.do — canonical QA runner for codescan
*! Usage: cd codescan/qa && stata-mp -b do run_all.do [quick|core|full]

version 16.0
local _runner_more0 "`c(more)'"
local _runner_va0 "`c(varabbrev)'"
set more off
set varabbrev off

args mode extra

local qa_dir "`c(pwd)'"
local _runner_plus0 "`c(sysdir_plus)'"
local _runner_personal0 "`c(sysdir_personal)'"
do "`qa_dir'/_codescan_qa_common.do"
quietly _codescan_qa_bootstrap
local pass = 0
local fail = 0

local mode = lower(trim("`mode'"))
if "`mode'" == "" | "`mode'" == "default" local mode "full"

if "`extra'" != "" {
    display as error "run_all.do accepts at most one mode argument."
    exit 198
}

if !inlist("`mode'", "quick", "core", "full") {
    display as error "Unknown QA mode: `mode'"
    display as error "Supported modes: quick, core, full"
    exit 198
}

* Routine development lane: fast functional coverage plus the two headline
* validation suites. No install/docs smoke, no adversarial stress.
* test_codescan.do was split at its section boundaries (audit Q8); the seven
* test_codescan* suites below together carry the 308 tests it used to run, plus
* one settings-hygiene test each.
local quick_suites test_codescan test_codescan_v1_fixes test_codescan_errors ///
    test_codescan_functional test_codescan_edge_cases ///
    test_codescan_install_verify test_codescan_coverage ///
    test_countrows test_mata_opt ///
    test_codescan_regressions test_codescan_v208 test_codescan_v2_no_scoring ///
    test_codescan_v203_hardening test_codescan_v300_critical ///
    test_codescan_perf_equiv ///
    validation_codescan validation_codescan_extended validation_countrows

* Correctness lane: quick plus every validation suite and the adversarial
* functional suites.
local core_suites `quick_suites' ///
    validation_codescan_known_answers validation_codescan_dgp_recovery ///
    validation_codescan_dgp_recovery2 ///
    validation_mata ///
    validation_codescan_io ///
    validation_codescan_output validation_codescan_describe ///
    validation_codescan_describe_adversarial validation_codescan_crosscheck ///
    test_codescan_adversarial test_codescan_describe_adversarial ///
    test_codescan_stress_adversarial

* Canonical release gate: core plus install smoke, documentation examples,
* and release-surface metadata. No-argument run_all.do maps here.
local full_suites `core_suites' ///
    test_codescan_install_docs test_documentation_examples ///
    test_release_integrity

local suite_list ``mode'_suites'

display as text "codescan QA mode: `mode'"
foreach f in `suite_list' {
    cd "`qa_dir'"
    clear all
    set more off
    set varabbrev off
    capture macro drop CODESCAN_QA_RESULT_NAME
    capture macro drop CODESCAN_QA_RESULT_TESTS
    capture macro drop CODESCAN_QA_RESULT_PASS
    capture macro drop CODESCAN_QA_RESULT_FAIL
    capture noisily do "`qa_dir'/`f'.do"
    local suite_rc = _rc
    local report_name "$CODESCAN_QA_RESULT_NAME"
    local report_tests = real("$CODESCAN_QA_RESULT_TESTS")
    local report_pass = real("$CODESCAN_QA_RESULT_PASS")
    local report_fail = real("$CODESCAN_QA_RESULT_FAIL")

    local report_ok = 1
    if "`report_name'" != "`f'" local report_ok = 0
    if missing(`report_tests') | `report_tests' <= 0 local report_ok = 0
    if missing(`report_pass') | missing(`report_fail') local report_ok = 0
    if `report_tests' != `report_pass' + `report_fail' local report_ok = 0
    if `report_fail' != 0 local report_ok = 0

    cd "`qa_dir'"
    if `suite_rc' | !`report_ok' {
        local ++fail
        if `suite_rc' {
            display as error "FAILED: `f'.do (rc=`suite_rc')"
        }
        else {
            display as error "FAILED: `f'.do (missing, malformed, empty, or failing RESULT handshake)"
        }
    }
    else {
        local ++pass
        display as result "PASSED: `f'.do"
    }
}

* Erase generated artifacts left at the qa/ root so the working tree stays clean.
* .log is intentionally NOT erased here: this runner's own batch log
* (run_all.log) is open while this code runs. Input fixtures under qa/data/ are
* untouched.
cd "`qa_dir'"
shell bash -lc 'find "$1" -maxdepth 1 -type f \( -name "*.csv" -o -name "*.dta" -o -name "*.xlsx" -o -name "*.smcl" \) -delete' bash "`qa_dir'"

* Leave an interactive caller's adopath settings exactly as run_all.do found
* them.  Batch Stata exits immediately afterward, but restoration is still part
* of the runner's state contract.
sysdir set PLUS "`_runner_plus0'"
sysdir set PERSONAL "`_runner_personal0'"
set more `_runner_more0'
set varabbrev `_runner_va0'
capture macro drop CODESCAN_QA_RESULT_NAME
capture macro drop CODESCAN_QA_RESULT_TESTS
capture macro drop CODESCAN_QA_RESULT_PASS
capture macro drop CODESCAN_QA_RESULT_FAIL
capture macro drop CODESCAN_QA_PLUS
capture macro drop CODESCAN_QA_PERSONAL
capture macro drop CODESCAN_QA_ISOLATED

display _n as result "codescan QA summary (`mode'): `pass' passed, `fail' failed"

* Final machine-readable aggregate sentinel.
*
* This is the signal CI must gate on. `stata-mp -b do' exits with OS status 0
* even when the do-file ends in r(1), so the shell status is not a verdict; and
* each suite must also publish a nonempty, internally consistent RESULT
* handshake. This line is emitted last and always, so CI can require it to be
* present, well-formed, and fail=0 — an absent or malformed sentinel is itself a
* failure, which a crashed or vacuous suite cannot fake.
local _total = `pass' + `fail'
display as text "RESULT: run_all_`mode' tests=`_total' pass=`pass' fail=`fail'"

if `fail' > 0 exit 1
