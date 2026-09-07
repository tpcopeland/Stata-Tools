*! test_eplot_v140.do - Regression tests for eplot 1.4.0
*! Covers the logarithmic effect axis (logscale) and the xscale()/yscale()
*! passthrough guard.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_eplot_v140.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

**# Padded effect-axis range

**## Ratio data pad multiplicatively and stay strictly positive
* Pre-1.4.0 the padded minimum of this range was -0.37: linear padding of a
* ratio scale, which twoway renders as a collapsed log axis at rc=0.
local ++test_count
capture noisily {
    clear
    input str6 lab double(es lci uci)
    "a" 1.20 0.90 1.60
    "b" 0.85 0.60 1.20
    "c" 6.00 3.00 20.0
    end

    eplot es lci uci, labels(lab) logscale name(eplot_v140_t1, replace)
    local cmd = r(cmd)
    assert regexm(`"`cmd'"', "xscale\(log range\(([^ ]+) ([^)]+)\)\)")
    local _rmin = real(regexs(1))
    local _rmax = real(regexs(2))
    assert !missing(`_rmin', `_rmax')
    assert `_rmin' > 0
    assert `_rmin' < 0.6
    assert `_rmax' > 20
    * 5% of the plotted range in log units, on both ends.
    local _want_min = exp(ln(0.6) - 0.05 * (ln(20) - ln(0.6)))
    local _want_max = exp(ln(20) + 0.05 * (ln(20) - ln(0.6)))
    assert !missing(`_rmin', `_want_min')
    assert reldif(`_rmin', `_want_min') < 1e-6
    assert !missing(`_rmax', `_want_max')
    assert reldif(`_rmax', `_want_max') < 1e-6
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}
capture graph drop eplot_v140_t1

**## Linear padding is unchanged without logscale
local ++test_count
capture noisily {
    eplot es lci uci, labels(lab) name(eplot_v140_t2, replace)
    local cmd = r(cmd)
    assert regexm(`"`cmd'"', "xscale\(range\(([^ ]+) ([^)]+)\)\)")
    local _rmin = real(regexs(1))
    assert !missing(`_rmin')
    assert reldif(`_rmin', 0.6 - 0.05 * (20 - 0.6)) < 1e-6
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}
capture graph drop eplot_v140_t2

**# Effect-axis ticks

**## No tick at or below zero on a log axis
* The 1/2/5 linear lattice put the first tick at 0 for this range, which drags
* a log axis onto a value it cannot show.
local ++test_count
capture noisily {
    eplot es lci uci, labels(lab) logscale name(eplot_v140_t3, replace)
    local cmd = r(cmd)
    assert regexm(`"`cmd'"', "xlabel\( *([-0-9.eE+]+)")
    local _first = real(regexs(1))
    assert !missing(`_first')
    assert `_first' > 0
    assert `_first' <= 0.6
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}
capture graph drop eplot_v140_t3

**## Decade lattice brackets the data and stays positive
local ++test_count
capture noisily {
    quietly run "`pkg_dir'/eplot.ado"
    _eplot_log_ticks, min(0.6) max(20)
    local _t "`s(ticks)'"
    assert `"`_t'"' != ""
    * Positions alternate with quoted labels; check the numeric positions.
    local _nw : word count `_t'
    assert mod(`_nw', 2) == 0
    local _lo = .
    local _hi = .
    forvalues _i = 1(2)`_nw' {
        local _v : word `_i' of `_t'
        assert real("`_v'") > 0
        if missing(`_lo') local _lo = real("`_v'")
        local _hi = real("`_v'")
    }
    assert `_lo' <= 0.6
    assert `_hi' >= 20
    assert `_nw' / 2 >= 4 & `_nw' / 2 <= 9

    * Wide ranges fall back to whole decades rather than 60 ticks.
    _eplot_log_ticks, min(0.001) max(1000)
    local _nw2 : word count `s(ticks)'
    assert `_nw2' / 2 <= 12

    * Below a threefold spread there is no usable lattice; the caller then
    * falls back to linear ticks, which must still be positive.
    _eplot_log_ticks, min(0.9) max(1.6)
    assert `"`s(ticks)'"' == ""
    _eplot_effect_axis_labels, min(0.9) max(1.6) logscale
    assert regexm(`"`s(axisopts)'"', "^ *([-0-9.eE+]+)")
    assert real(regexs(1)) > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**# Negative paths

**## Non-positive plotted values are refused
local ++test_count
capture noisily {
    capture eplot es lci uci, labels(lab) logscale rescale(-1) name(eplot_v140_t5, replace)
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}
capture graph drop eplot_v140_t5

**## Non-positive reference-line positions are refused
local ++test_count
capture noisily {
    capture eplot es lci uci, labels(lab) logscale null(0) name(eplot_v140_t6, replace)
    assert _rc == 198
    capture eplot es lci uci, labels(lab) logscale xline(0) name(eplot_v140_t6, replace)
    assert _rc == 198
    * nonull removes the constraint the default null would impose.
    eplot es lci uci, labels(lab) logscale nonull name(eplot_v140_t6, replace)
    assert _rc == 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}
capture graph drop eplot_v140_t6

**## xscale()/yscale() passthrough is refused rather than silently dropped
local ++test_count
capture noisily {
    capture eplot es lci uci, labels(lab) xscale(log) name(eplot_v140_t7, replace)
    assert _rc == 198
    capture eplot es lci uci, labels(lab) yscale(range(0 1)) name(eplot_v140_t7, replace)
    assert _rc == 198
    * Other twoway passthrough options are untouched.
    eplot es lci uci, labels(lab) ysize(4) name(eplot_v140_t7, replace)
    assert _rc == 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}
capture graph drop eplot_v140_t7

**# Mode and layout coverage

**## logscale reaches every mode and both orientations
local ++test_count
capture noisily {
    * Data mode, horizontal and vertical, with the annotations that consume
    * the axis range.
    eplot es lci uci, labels(lab) logscale values favors("Lower" "Higher") ///
        name(eplot_v140_t8a, replace)
    assert r(k) == 3
    local cmd = r(cmd)
    assert strpos(`"`cmd'"', "xscale(log range(") > 0

    eplot es lci uci, labels(lab) logscale vertical name(eplot_v140_t8b, replace)
    local cmd = r(cmd)
    assert strpos(`"`cmd'"', "yscale(log range(") > 0

    * Frame mode forwards logscale through to data mode.
    clear
    input str6 label double(estimate ll ul)
    "a" 2 1.1 4
    "b" 8 5 14
    end
    frame rename default eplot_v140_fr
    eplot, frame(eplot_v140_fr) logscale name(eplot_v140_t8c, replace)
    assert strpos(`"`=r(cmd)'"', "xscale(log range(") > 0

    * Estimates mode, single and multi-model.
    sysuse auto, clear
    quietly logit foreign mpg weight turn
    estimates store eplot_v140_m1
    quietly logit foreign mpg weight
    estimates store eplot_v140_m2

    eplot eplot_v140_m1, eform noconstant logscale name(eplot_v140_t8d, replace)
    assert strpos(`"`=r(cmd)'"', "xscale(log range(") > 0
    eplot eplot_v140_m1 eplot_v140_m2, eform noconstant logscale ///
        name(eplot_v140_t8e, replace)
    assert r(n_models) == 2

    * Matrix mode.
    matrix eplot_v140_b = e(b)
    matrix eplot_v140_V = e(V)
    matrix eplot_v140_M = J(2, 2, .)
    matrix eplot_v140_M[1, 1] = eplot_v140_b[1, 1]
    matrix eplot_v140_M[1, 2] = sqrt(eplot_v140_V[1, 1])
    matrix eplot_v140_M[2, 1] = eplot_v140_b[1, 2]
    matrix eplot_v140_M[2, 2] = sqrt(eplot_v140_V[2, 2])
    matrix rownames eplot_v140_M = mpg weight
    eplot, matrix(eplot_v140_M) eform logscale name(eplot_v140_t8f, replace)
    assert strpos(`"`=r(cmd)'"', "xscale(log range(") > 0
    assert r(k) == 2
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}
capture graph drop eplot_v140_t8a
capture graph drop eplot_v140_t8b
capture graph drop eplot_v140_t8c
capture graph drop eplot_v140_t8d
capture graph drop eplot_v140_t8e
capture graph drop eplot_v140_t8f
capture frame drop eplot_v140_fr

**## The default null moves to 1 under logscale without eform
local ++test_count
capture noisily {
    clear
    input str6 lab double(es lci uci)
    "a" 2 1.1 4
    "b" 8 5 14
    "c" 30 12 60
    end
    eplot es lci uci, labels(lab) logscale name(eplot_v140_t9, replace)
    assert strpos(`"`=r(cmd)'"', "xline(1,") > 0
    * Without logscale the default is still 0.
    eplot es lci uci, labels(lab) name(eplot_v140_t9, replace)
    assert strpos(`"`=r(cmd)'"', "xline(0,") > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}
capture graph drop eplot_v140_t9

**# Summary

capture graph drop _all
capture estimates drop _all
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
_eplot_qa_result test_eplot_v140, tests(`test_count') pass(`pass_count') fail(`fail_count') skip(0)

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    capture log close
    exit 1
}
capture log close
