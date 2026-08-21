* test_kmplot_v127.do
* Regression tests for kmplot 1.2.7
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
**## R1: Risk-table columns align with the main x axis

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    tempfile svgbase
    local svg "`svgbase'.svg"

    kmplot, by(drug) risktable timepoints(0 5 10 15 20 25 30 35) ///
        xlabel(0 "T0" 5 "T5" 10 "T10" 15 "T15" 20 "T20" ///
            25 "T25" 30 "T30" 35 "T35") ///
        xline(0, lcolor(purple) lwidth(vthick)) ///
        xline(35, lcolor(orange) lwidth(vthick)) ///
        export("`svg'", replace) name(v127_r1, replace)

    local xline_first = .
    local xline_last = .
    local tick_first = .
    local tick_last = .
    local risk_first = .
    local risk_size = .
    local group_label_found = 0
    local group_label_size = .
    local ytitle_x = .
    tempname fh
    file open `fh' using "`svg'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "stroke:#800080") & ///
            regexm(`"`line'"', `" x1="([0-9.]+)""') {
            local xline_first = real(regexs(1))
        }
        if strpos(`"`line'"', "stroke:#FF7F00") & ///
            regexm(`"`line'"', `" x1="([0-9.]+)""') {
            local xline_last = real(regexs(1))
        }
        if strpos(`"`line'"', ">T0</text>") & ///
            regexm(`"`line'"', `" x="([0-9.]+)""') {
            local tick_first = real(regexs(1))
        }
        if strpos(`"`line'"', ">T35</text>") & ///
            regexm(`"`line'"', `" x="([0-9.]+)""') {
            local tick_last = real(regexs(1))
        }
        if strpos(`"`line'"', ">20</text>") & ///
            regexm(`"`line'"', `" x="([0-9.]+)""') {
            local risk_first = real(regexs(1))
            if regexm(`"`line'"', "font-size:([0-9.]+)px") {
                local risk_size = real(regexs(1))
            }
        }
        if strpos(`"`line'"', ">Placebo</text>") {
            local group_label_found = 1
            if regexm(`"`line'"', "font-size:([0-9.]+)px") {
                local group_label_size = real(regexs(1))
            }
        }
        if strpos(`"`line'"', ">No. at risk</text>") & ///
            regexm(`"`line'"', `" x="([0-9.]+)""') {
            local ytitle_x = real(regexs(1))
        }
        file read `fh' line
    }
    file close `fh'

    assert !missing(`xline_first')
    assert !missing(`xline_last')
    assert !missing(`tick_first')
    assert !missing(`tick_last')
    assert !missing(`risk_first')
    assert !missing(`risk_size')
    assert `group_label_found' == 1
    assert !missing(`group_label_size')
    assert !missing(`ytitle_x')
    assert abs(`xline_first' - `tick_first') < 1
    assert abs(`xline_last' - `tick_last') < 1
    assert abs(`tick_first' - `risk_first') < 1
    assert `group_label_size' >= `risk_size'
    assert `ytitle_x' > 0
    erase "`svg'"
}
if _rc == 0 {
    display as result "  PASS: R1 Risk-table columns align with main x axis"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 Risk-table alignment (rc=`=_rc')"
    local ++fail_count
}

**# Summary
if `fail_count' > 0 {
    display as error "RESULT: test_kmplot_v127 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "RESULT: test_kmplot_v127 tests=`test_count' pass=`pass_count' fail=`fail_count'"
