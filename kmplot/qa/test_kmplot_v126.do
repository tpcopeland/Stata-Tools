* test_kmplot_v126.do
* Regression tests for kmplot 1.2.6
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-08-11

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
**## R1: Time axis precedes the separated risk table with readable defaults

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    tempfile svgbase
    local svg "`svgbase'.svg"

    kmplot, risktable timepoints(0 10 20 30) ///
        xlabel(0 "BASE" 10 "TEN" 20 "TWENTY" 30 "THIRTY") ///
        export("`svg'", replace) name(v126_r1, replace)

    local axis_y = .
    local title_y = .
    local separator_y = .
    local risk_y = .
    local axis_size = .
    local risk_size = .
    tempname fh
    file open `fh' using "`svg'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', ">BASE</text>") {
            if regexm(`"`line'"', `" y="([0-9.]+)""') {
                local axis_y = real(regexs(1))
            }
            if regexm(`"`line'"', "font-size:([0-9.]+)px") {
                local axis_size = real(regexs(1))
            }
        }
        if strpos(`"`line'"', ">Analysis time</text>") {
            if regexm(`"`line'"', `" y="([0-9.]+)""') {
                local title_y = real(regexs(1))
            }
        }
        if strpos(`"`line'"', "stroke:#808080") {
            if regexm(`"`line'"', `" y1="([0-9.]+)""') {
                local separator_y = real(regexs(1))
            }
        }
        if strpos(`"`line'"', ">48</text>") {
            if regexm(`"`line'"', `" y="([0-9.]+)""') {
                local risk_y = real(regexs(1))
            }
            if regexm(`"`line'"', "font-size:([0-9.]+)px") {
                local risk_size = real(regexs(1))
            }
        }
        file read `fh' line
    }
    file close `fh'

    assert `axis_y' < `separator_y'
    assert `title_y' < `separator_y'
    assert `separator_y' < `risk_y'
    assert `axis_size' > 50
    assert `risk_size' > 50
    erase "`svg'"
}
if _rc == 0 {
    display as result "  PASS: R1 Time axis, separator, and risk-table sizing"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 Time axis, separator, and risk-table sizing (rc=`=_rc')"
    local ++fail_count
}

**# Summary
if `fail_count' > 0 {
    display as error "RESULT: test_kmplot_v126 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "RESULT: test_kmplot_v126 tests=`test_count' pass=`pass_count' fail=`fail_count'"
