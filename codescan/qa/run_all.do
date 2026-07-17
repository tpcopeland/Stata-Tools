*! run_all.do — canonical QA runner for codescan
*! Usage: cd codescan/qa && stata-mp -b do run_all.do [quick|core|full]

version 16.0
set more off
set varabbrev off

args mode extra

local qa_dir "`c(pwd)'"
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
local quick_suites test_codescan test_countrows test_mata_opt ///
    test_codescan_regressions test_codescan_v208 test_codescan_v2_no_scoring ///
    test_codescan_v203_hardening test_codescan_v300_critical ///
    test_codescan_perf_equiv ///
    validation_codescan validation_countrows

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
    capture noisily do "`qa_dir'/`f'.do"
    local suite_rc = _rc
    cd "`qa_dir'"
    if `suite_rc' {
        local ++fail
        display as error "FAILED: `f'.do"
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
capture shell bash -lc 'find "$1" -maxdepth 1 -type f \( -name "*.csv" -o -name "*.dta" -o -name "*.xlsx" -o -name "*.smcl" \) -delete' bash "`qa_dir'"

display _n as result "codescan QA summary (`mode'): `pass' passed, `fail' failed"

* Final machine-readable aggregate sentinel.
*
* This is the signal CI must gate on. `stata-mp -b do' exits with OS status 0
* even when the do-file ends in r(1), so the shell status is not a verdict; and
* a suite that dies before printing its own RESULT: line leaves no per-suite
* sentinel to notice. This line is emitted last and always, so CI can require it
* to be present, well-formed, and fail=0 — an absent or malformed sentinel is
* itself a failure, which a crashed runner cannot fake.
local _total = `pass' + `fail'
display as text "RESULT: run_all_`mode' tests=`_total' pass=`pass' fail=`fail'"

if `fail' > 0 exit 1
