*! run_all.do — canonical QA runner for eplot
*! Usage: cd eplot/qa && stata-mp -b do run_all.do [quick|core|full]

version 16.0
set more off
set varabbrev off

args mode extra

local qa_dir "`c(pwd)'"
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap
local pass = 0
local fail = 0

local mode = lower(trim("`mode'"))
if "`mode'" == "" local mode "full"

if "`extra'" != "" {
    display as error "run_all.do accepts at most one mode argument."
    exit 198
}

if !inlist("`mode'", "quick", "core", "full") {
    display as error "Unknown QA mode: `mode'"
    display as error "Supported modes: quick, core, full"
    exit 198
}

* _eplot_qa_bootstrap owns isolated sysdir setup and the local package install.
* Each suite reinstalls eplot from the package dir itself; that is intentional
* and harmless under the sandboxed PLUS/PERSONAL.

* Routine development lane: fast functional coverage across the four input modes.
local quick_suites test_eplot test_options test_edge_cases

* Release smoke lane: quick plus the per-feature regression suites and frame mode.
local core_suites `quick_suites' ///
    test_eplot_frame test_graph_options test_layout ///
    test_colors_routing test_axis_coeflabels test_stars_matrix

* Canonical release QA: core plus known-answer validation.
local full_suites `core_suites' validation_eplot

local suite_list ``mode'_suites'

display as text "eplot QA mode: `mode'"
foreach f in `suite_list' {
    clear all
    set more off
    set varabbrev off
    capture noisily do "`qa_dir'/`f'.do"
    if _rc {
        local ++fail
        display as error "FAILED: `f'.do (rc=`=_rc')"
    }
    else {
        local ++pass
        display as result "PASSED: `f'.do"
    }
}

display _n as result "=== eplot QA Summary (`mode'): `pass' passed, `fail' failed ==="
display "RESULT: run_all mode=`mode' tests=`=`pass'+`fail'' pass=`pass' fail=`fail'"
if `fail' > 0 exit 1
