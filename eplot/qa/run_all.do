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
local quick_suites test_eplot test_options test_edge_cases test_eplot_errors

* Release smoke lane: quick plus the per-feature regression suites and frame mode.
local core_suites `quick_suites' ///
    test_eplot_frame test_graph_options test_layout ///
    test_colors_routing test_axis_coeflabels test_stars_matrix ///
    test_selection_labels ///
    test_regressions test_eplot_v128 test_eplot_v129

* Canonical release QA: core plus known-answer validation.
local full_suites `core_suites' validation_eplot test_examples

local suite_list ``mode'_suites'

* Stale sentinels from an earlier run must not be able to satisfy this one.
foreach f in `suite_list' {
    capture erase "`qa_dir'/.eplot_qa_sentinel_`f'.txt"
}

display as text "eplot QA mode: `mode'"
local total_cases 0
foreach f in `suite_list' {
    clear all
    set more off
    set varabbrev off
    capture noisily do "`qa_dir'/`f'.do"
    local _suite_rc = _rc

    * Reconcile the suite's own RESULT sentinel.  Exit status alone is not
    * evidence: a suite that returns zero without writing a consistent
    * sentinel has not demonstrated that its cases ran.
    local _sent_msg ""
    local _sent_cases 0
    capture confirm file "`qa_dir'/.eplot_qa_sentinel_`f'.txt"
    if _rc {
        local _sent_msg "no RESULT sentinel written"
    }
    else {
        tempname _fh
        local _line ""
        capture noisily {
            file open `_fh' using "`qa_dir'/.eplot_qa_sentinel_`f'.txt", read text
            file read `_fh' _line
            file close `_fh'
        }
        if _rc {
            local _sent_msg "RESULT sentinel unreadable"
        }
        else if !regexm(`"`_line'"', ///
            "^RESULT: ([A-Za-z0-9_]+) tests=([0-9]+) pass=([0-9]+) fail=([0-9]+) skip=([0-9]+)$") {
            local _sent_msg "RESULT sentinel malformed"
        }
        else {
            local _sname = regexs(1)
            local _stests = real(regexs(2))
            local _spass  = real(regexs(3))
            local _sfail  = real(regexs(4))
            local _sskip  = real(regexs(5))
            if "`_sname'" != "`f'" {
                local _sent_msg "RESULT sentinel names `_sname', not `f'"
            }
            else if `_stests' != `_spass' + `_sfail' + `_sskip' {
                local _sent_msg "RESULT sentinel does not reconcile (tests=`_stests', pass+fail+skip=`=`_spass'+`_sfail'+`_sskip'')"
            }
            else if `_stests' == 0 {
                local _sent_msg "RESULT sentinel reports zero cases"
            }
            else if `_sfail' > 0 {
                local _sent_msg "RESULT sentinel reports `_sfail' failing case(s)"
            }
            else if `_sskip' > 0 & "`mode'" == "full" {
                local _sent_msg "RESULT sentinel reports `_sskip' skipped case(s); the full lane accepts none"
            }
            else {
                local _sent_cases = `_stests'
            }
        }
    }

    if `_suite_rc' {
        local ++fail
        display as error "FAILED: `f'.do (rc=`_suite_rc')"
    }
    else if "`_sent_msg'" != "" {
        local ++fail
        display as error "FAILED: `f'.do (rc=0 but `_sent_msg')"
    }
    else {
        local ++pass
        local total_cases = `total_cases' + `_sent_cases'
        display as result "PASSED: `f'.do (`_sent_cases' cases)"
    }
}

display _n as result "=== eplot QA Summary (`mode'): `pass' passed, `fail' failed, `total_cases' cases ==="
display as text "eplot QA lane: `mode'"
* Canonical runner contract, in the exact shape the devkit CLI parses. The
* mode belongs on its own line above: an interposed `mode=' token made this
* line unmatchable, so the CLI fell back to whichever child suite it happened
* to read last.
display "RESULT: run_all tests=`=`pass'+`fail'' pass=`pass' fail=`fail' skip=0"
if `fail' > 0 exit 1
