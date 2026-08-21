* test_kmplot_v128.do
* Regression tests for kmplot 1.2.8
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-08-21

clear all
version 16.0
set varabbrev off

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
if "`pkg_dir'" == "`qa_dir'" {
    local pkg_dir "`qa_dir'/.."
}
do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Regression tests
**## R1: stcolor margins correct the supplied Stata 19.5 SVG coordinates

local ++test_count
capture noisily {
    local helper "`pkg_dir'/_kmplot_risktable.ado"
    tempname fh
    local stcolor_branch = 0
    local stcolor_left = .
    local stcolor_right = .

    file open `fh' using "`helper'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', `"== "stcolor""') {
            local stcolor_branch = 1
        }
        if `stcolor_branch' & regexm(`"`line'"', ///
            "local plot_margin_left = ([0-9.]+)") {
            local stcolor_left = real(regexs(1))
        }
        if `stcolor_branch' & regexm(`"`line'"', ///
            "local plot_margin_right = ([0-9.]+)") {
            local stcolor_right = real(regexs(1))
        }
        file read `fh' line
    }
    file close `fh'

    assert `stcolor_branch' == 1
    assert abs(`stcolor_left' - 5.9) < 1e-10
    assert abs(`stcolor_right' - 3.85) < 1e-10

    * Coordinates measured from the original 7.5 x 4.5 inch stcolor SVG.
    * Stata graph-margin units are one percent of the 3240-unit height.
    local margin_unit = 32.4
    local corrected_zero = 914.63 - (16.1 - `stcolor_left') * `margin_unit'
    local corrected_last = 5326.26 - (`stcolor_right' - 2.2) * `margin_unit'
    assert abs(`corrected_zero' - 584.21) < 1
    assert abs(`corrected_last' - 5272.76) < 1
}
if _rc == 0 {
    display as result "  PASS: R1 stcolor SVG alignment calibration"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 stcolor SVG alignment calibration (rc=`=_rc')"
    local ++fail_count
}

**## R2: Stata applies the calibrated margins by the expected SVG distances

local ++test_count
capture noisily {
    clear
    set obs 2
    generate double x = 20 * (_n - 1)
    generate double y = _n

    tempfile oldbase newbase
    local oldsvg "`oldbase'.svg"
    local newsvg "`newbase'.svg"

    twoway scatter y x, xscale(range(0 20) noextend) ///
        xlabel(0 "LEFT" 20 "RIGHT") ///
        plotregion(margin(l=16.1 r=2.2)) name(v128_old, replace) nodraw
    graph display v128_old, xsize(7.5) ysize(4.5)
    graph export "`oldsvg'", as(svg) replace

    twoway scatter y x, xscale(range(0 20) noextend) ///
        xlabel(0 "LEFT" 20 "RIGHT") ///
        plotregion(margin(l=5.9 r=3.85)) name(v128_new, replace) nodraw
    graph display v128_new, xsize(7.5) ysize(4.5)
    graph export "`newsvg'", as(svg) replace

    local old_left = .
    local old_right = .
    local new_left = .
    local new_right = .
    foreach version in old new {
        tempname svgfh
        file open `svgfh' using "``version'svg'", read text
        file read `svgfh' line
        while r(eof) == 0 {
            if strpos(`"`line'"', ">LEFT</text>") & ///
                regexm(`"`line'"', `" x="([0-9.]+)""') {
                local `version'_left = real(regexs(1))
            }
            if strpos(`"`line'"', ">RIGHT</text>") & ///
                regexm(`"`line'"', `" x="([0-9.]+)""') {
                local `version'_right = real(regexs(1))
            }
            file read `svgfh' line
        }
        file close `svgfh'
    }

    assert !missing(`old_left', `old_right', `new_left', `new_right')
    assert abs((`old_left' - `new_left') - (914.63 - 584.21)) < 1
    assert abs((`old_right' - `new_right') - (5326.26 - 5272.76)) < 1
    erase "`oldsvg'"
    erase "`newsvg'"
}
if _rc == 0 {
    display as result "  PASS: R2 rendered SVG margin displacement"
    local ++pass_count
}
else {
    display as error "  FAIL: R2 rendered SVG margin displacement (rc=`=_rc')"
    local ++fail_count
}

**# Summary
if `fail_count' > 0 {
    display as error "RESULT: test_kmplot_v128 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "RESULT: test_kmplot_v128 tests=`test_count' pass=`pass_count' fail=`fail_count'"
