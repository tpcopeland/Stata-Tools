* test_kmplot_v1211.do
* Regression tests for kmplot 1.2.11
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-08-21

clear all
version 16.0
set varabbrev off

**# Bootstrap
local qa_dir "`c(pwd)'"
do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Regression tests
**## R1: Row labels clear both the time-zero counts and vertical title

local ++test_count
capture noisily {
    clear
    set obs 12000
    generate byte grp = cond(_n <= 6000, 1, 2)
    bysort grp: generate long within = _n
    generate double ftime = 20
    generate byte fail = within <= 2000
    replace ftime = 1 + mod(within - 1, 19) if fail
    label define grplbl 1 "No HRT use" 2 "Current HRT use"
    label values grp grplbl
    stset ftime, failure(fail)

    tempfile svgbase
    local svg "`svgbase'.svg"
    kmplot, by(grp) colors(black gray) lpattern(solid dash) ///
        risktable riskevents riskmono timepoints(0(2)20) ///
        xlabel(0(2)20) scheme(s2color) name(v1211_spacing, replace)
    graph display v1211_spacing, xsize(7.5) ysize(4.5)
    graph export "`svg'", as(svg) replace

    local zero_n = 0
    local count_n = 0
    local count_x = .
    local group_x = .
    local ytitle_x = .
    tempname fh
    file open `fh' using "`svg'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', ">0</text>") & ///
            regexm(`"`line'"', `" x="([0-9.]+)""') {
            local ++zero_n
            if `zero_n' <= 2 local zero_x`zero_n' = real(regexs(1))
        }
        if strpos(`"`line'"', ">6000 (0)</text>") & ///
            regexm(`"`line'"', `" x="([0-9.]+)""') {
            local ++count_n
            local count_x = real(regexs(1))
        }
        if strpos(`"`line'"', ">Current HRT use</text>") & ///
            strpos(`"`line'"', `"text-anchor="end""') & ///
            regexm(`"`line'"', `" x="([0-9.]+)""') {
            local group_x = real(regexs(1))
        }
        if strpos(`"`line'"', ">No. at risk (events)</text>") & ///
            regexm(`"`line'"', `" x="([0-9.]+)""') {
            local ytitle_x = real(regexs(1))
        }
        file read `fh' line
    }
    file close `fh'

    assert `zero_n' == 2
    assert `count_n' == 2
    assert !missing(`count_x', `group_x', `ytitle_x')
    assert abs(`zero_x1' - `zero_x2') < 0.1
    assert `count_x' - `group_x' >= 180
    assert `group_x' - `ytitle_x' >= 600
    erase "`svg'"
}
if _rc == 0 {
    display as result "  PASS: R1 risk-table label spacing"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 risk-table label spacing (rc=`=_rc')"
    local ++fail_count
}

**# Summary
if `fail_count' > 0 {
    display as error "RESULT: test_kmplot_v1211 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "RESULT: test_kmplot_v1211 tests=`test_count' pass=`pass_count' fail=`fail_count'"
