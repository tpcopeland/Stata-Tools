*! run_all.do — canonical QA runner for tvtools
*! Usage: cd tvtools/qa && stata-mp -b do run_all.do [quick|core|python|full]

version 16.0
set more off
set varabbrev off

args mode extra

local qa_dir "`c(pwd)'"
do "`qa_dir'/_tvtools_qa_common.do"
quietly _tvtools_qa_bootstrap
local pass = 0
local fail = 0

local mode = lower(trim("`mode'"))
if "`mode'" == "" local mode "full"

if "`extra'" != "" {
    display as error "run_all.do accepts at most one mode argument."
    exit 198
}

if !inlist("`mode'", "quick", "core", "python", "full") {
    display as error "Unknown QA mode: `mode'"
    display as error "Supported modes: quick, core, python, full"
    exit 198
}

* _tvtools_qa_bootstrap owns the isolated PLUS/PERSONAL sandbox and the local
* package install; each suite re-sources the scaffold and re-bootstraps after
* its own `clear all`, so install side effects are never duplicated here.

* Routine development lane: fast functional coverage and state preservation.
* One file per command plus the cross-cutting concern suites.
local quick_suites test_tvage test_tvband test_tvsplit ///
    test_tvevent test_tvexpose test_tvmerge ///
    test_tvpanel test_tvweight test_tvdiagnose test_tvtools ///
    test_options test_integration test_edge_cases test_verbose ///
    test_frames_input

* Correctness lane: quick lane plus regression fixes and the hand-computable
* known-answer / invariant / person-time validation oracles.
* crossval_tvmerge_mata is a pure-Stata parity gate (no external dependency):
* it lives in the always-run correctness lane, not the python lane.
local core_suites `quick_suites' test_regressions ///
    validation_known_answers ///
    validation_tvage validation_tvband validation_tvsplit ///
    validation_tvevent validation_tvexpose ///
    validation_tvmerge validation_tvweight validation_tvweight_balance ///
    validation_tvdiagnose validation_flow ///
    validation_boundary validation_pipeline validation_supplemental ///
    crossval_tvmerge_mata crossval_tvexpose_expand crossval_tvsplit_lexis

* Cross-validation lane: parity against the external reference implementation.
local python_suites crossval_tvtools

* Canonical release QA. A no-argument run_all.do maps here.
local full_suites `core_suites' `python_suites'

local suite_list ``mode'_suites'

display as text "tvtools QA mode: `mode'"
foreach f in `suite_list' {
    clear all
    set more off
    set varabbrev off
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

display _n as result "=== tvtools QA Summary (`mode'): `pass' passed, `fail' failed ==="
if `fail' > 0 exit 1
