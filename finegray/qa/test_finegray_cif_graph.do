* test_finegray_cif_graph.do
* finegray_cif graph defaults and plot-level pass-through, read back from the
* LIVE graph object -- the styles twoway actually resolved, not the command
* line the program assembled.  Plot order in the drawn graph: with ci, the
* bands come first (plot1..plotK), then the lines (plotK+1..plot2K).
*
*   GR-01  default single-profile graph: no note(); y labels %3.1f
*   GR-02  default over() graph: no note(); the band level is named inside
*          the legend, and legend(note("")) removes it
*   GR-03  plotopts()/ciopts() reach the line and band (single profile), and
*          lpattern(solid) wins over scheme(sj)'s dashed line
*   GR-04  plotopts()/ciopts() reach every line and band in over() mode
*   GR-05  plot2opts()/ci2opts() reach curve 2 only; curve 1 keeps defaults
*   GR-06  user options override the built-in lwidth(medthick) and
*          color(%30) lwidth(none); plot#opts() overrides plotopts()
*   GR-07  a user note() is drawn in both modes
*   GR-08  y-label format: user format() wins; a user ylabel() rule without
*          format() still gets a leading zero with decimals from its step
*   GR-09  refusals: # out of range, # = 0, repeats, ciopts()/ci#opts()
*          without ci; attime() ignores plot options with a note
*   GR-10  styling never touches the estimates: r(table) identical, and the
*          y-format probe leaves no stray graph in memory
*
* Helper programs: _gr_fit, _gr_style

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_cif_graph.log", replace name(_gr)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _gr_fit
program define _gr_fit
    webuse hiv_si, clear
    gen byte any_event = status > 0
    quietly stset time, failure(any_event==1) id(patnr)
    quietly finegray ccr5, compete(status) cause(2)
end

* Resolved style of plot k of the current graph, returned in r():
*   r(pat) line pattern, r(lrgb) line colour, r(lw) line width,
*   r(frgb) band fill colour, r(fop) band fill opacity, r(flw) band outline width
capture program drop _gr_style
program define _gr_style, rclass
    version 16.0
    args k
    return local pat  `"`.Graph.plotregion1.plot`k'.style.line.pattern.snm'"'
    return local lrgb `"`.Graph.plotregion1.plot`k'.style.line.color.rgb'"'
    return local lw   `"`.Graph.plotregion1.plot`k'.style.line.width.snm'"'
    return local frgb `"`.Graph.plotregion1.plot`k'.style.area.shadestyle.color.rgb'"'
    return local fop  `"`.Graph.plotregion1.plot`k'.style.area.shadestyle.color.opacity'"'
    return local flw  `"`.Graph.plotregion1.plot`k'.style.area.linestyle.width.snm'"'
end

local navy "26 71 111"
local red  "255 0 0"

_gr_fit

**# GR-01 default single-profile graph
local ++test_count
capture noisily {
    finegray_cif, at(ccr5=0) ci
    * the pre-change default wrote note("at: ccr5=0") here
    assert `.Graph.note.text.arrnels' == 0
    assert "`.Graph.yaxis1.major.label_format'" == "%3.1f"
    * leading zero on a drawn label: 0.1 in the chosen format
    assert string(.1, "`.Graph.yaxis1.major.label_format'") == "0.1"
    _gr_style 1
    assert "`r(fop)'" == "30"
    assert "`r(flw)'" == "none"
    _gr_style 2
    assert "`r(lw)'" == "medthick"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: GR-01 default single-profile graph"
}
else {
    local ++fail_count
    display as error "  FAIL: GR-01 default single-profile graph (rc=`=_rc')"
}

**# GR-02 default over() graph
local ++test_count
capture noisily {
    finegray_cif, over(ccr5) ci
    assert `.Graph.note.text.arrnels' == 0
    assert `"`.Graph.legend.note.text[1]'"' == "Shaded: 95% CI"
    assert "`.Graph.yaxis1.major.label_format'" == "%3.1f"
    finegray_cif, over(ccr5) ci level(90)
    assert `"`.Graph.legend.note.text[1]'"' == "Shaded: 90% CI"
    finegray_cif, over(ccr5) ci legend(note(""))
    assert `"`.Graph.legend.note.text[1]'"' == ""
    * without ci there are no bands to name
    finegray_cif, over(ccr5)
    assert `"`.Graph.legend.note.text[1]'"' == ""
    assert `.Graph.note.text.arrnels' == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: GR-02 default over() graph"
}
else {
    local ++fail_count
    display as error "  FAIL: GR-02 default over() graph (rc=`=_rc')"
}

**# GR-03 plotopts()/ciopts(), single profile
local ++test_count
capture noisily {
    * control: scheme(sj) draws the curve dashed
    finegray_cif, at(ccr5=0) ci scheme(sj)
    _gr_style 2
    assert "`r(pat)'" == "dash"
    finegray_cif, at(ccr5=0) ci scheme(sj) plotopts(lpattern(solid) lcolor(red)) ///
        ciopts(color(red%20))
    _gr_style 2
    assert "`r(pat)'" == "solid"
    assert "`r(lrgb)'" == "`red'"
    _gr_style 1
    assert "`r(frgb)'" == "`red'"
    assert "`r(fop)'" == "20"
    * abbreviations follow marginsplot: plotop(), ciop(), plot#()
    finegray_cif, at(ccr5=0) ci plotop(lpattern(dot)) ciop(color(navy%10))
    _gr_style 2
    assert "`r(pat)'" == "dot"
    _gr_style 1
    assert "`r(fop)'" == "10"
    finegray_cif, at(ccr5=0) ci plot1(lpattern(dash_dot)) ci1(color(red%40))
    _gr_style 2
    assert "`r(pat)'" == "dash_dot"
    _gr_style 1
    assert "`r(frgb)'" == "`red'"
    assert "`r(fop)'" == "40"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: GR-03 plotopts()/ciopts() single profile"
}
else {
    local ++fail_count
    display as error "  FAIL: GR-03 plotopts()/ciopts() single profile (rc=`=_rc')"
}

**# GR-04 plotopts()/ciopts() reach every curve in over() mode
local ++test_count
capture noisily {
    finegray_cif, over(ccr5) ci scheme(sj) ///
        plotopts(lpattern(solid) lcolor(red)) ciopts(color(red%20))
    foreach k in 3 4 {
        _gr_style `k'
        assert "`r(pat)'" == "solid"
        assert "`r(lrgb)'" == "`red'"
    }
    foreach k in 1 2 {
        _gr_style `k'
        assert "`r(frgb)'" == "`red'"
        assert "`r(fop)'" == "20"
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: GR-04 plotopts()/ciopts() over() mode"
}
else {
    local ++fail_count
    display as error "  FAIL: GR-04 plotopts()/ciopts() over() mode (rc=`=_rc')"
}

**# GR-05 plot2opts()/ci2opts() reach curve 2 only
local ++test_count
capture noisily {
    finegray_cif, over(ccr5) ci
    _gr_style 3
    local p3 "`r(pat)'"
    local c3 "`r(lrgb)'"
    _gr_style 1
    local f1 "`r(frgb)'"
    finegray_cif, over(ccr5) ci plot2opts(lpattern(dash) lcolor(red)) ///
        ci2opts(color(red%15))
    _gr_style 4
    assert "`r(pat)'" == "dash"
    assert "`r(lrgb)'" == "`red'"
    _gr_style 2
    assert "`r(frgb)'" == "`red'"
    assert "`r(fop)'" == "15"
    * curve 1 unchanged
    _gr_style 3
    assert "`r(pat)'" == "`p3'"
    assert "`r(lrgb)'" == "`c3'"
    assert "`r(pat)'" != "dash"
    _gr_style 1
    assert "`r(frgb)'" == "`f1'"
    assert "`r(fop)'" == "30"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: GR-05 plot2opts()/ci2opts() curve 2 only"
}
else {
    local ++fail_count
    display as error "  FAIL: GR-05 plot2opts()/ci2opts() curve 2 only (rc=`=_rc')"
}

**# GR-06 user options come after the built-in defaults
local ++test_count
capture noisily {
    finegray_cif, at(ccr5=0) ci plotopts(lwidth(thin)) ///
        ciopts(color(navy) lwidth(medium))
    _gr_style 2
    assert "`r(lw)'" == "thin"
    _gr_style 1
    assert "`r(fop)'" != "30"
    assert "`r(flw)'" == "medium"
    * plot#opts() and ci#opts() come after plotopts() and ciopts()
    finegray_cif, over(ccr5) ci plotopts(lcolor(navy)) plot1opts(lcolor(red)) ///
        ciopts(color(navy%20)) ci1opts(color(red%20))
    _gr_style 3
    assert "`r(lrgb)'" == "`red'"
    _gr_style 4
    assert "`r(lrgb)'" == "`navy'"
    _gr_style 1
    assert "`r(frgb)'" == "`red'"
    _gr_style 2
    assert "`r(frgb)'" == "`navy'"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: GR-06 user options override built-in defaults"
}
else {
    local ++fail_count
    display as error "  FAIL: GR-06 user options override built-in defaults (rc=`=_rc')"
}

**# GR-07 a user note() is drawn
local ++test_count
capture noisily {
    finegray_cif, at(ccr5=0) ci note("x")
    assert `.Graph.note.text.arrnels' == 1
    assert `"`.Graph.note.text[1]'"' == "x"
    finegray_cif, over(ccr5) ci note("profile y")
    assert `"`.Graph.note.text[1]'"' == "profile y"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: GR-07 user note()"
}
else {
    local ++fail_count
    display as error "  FAIL: GR-07 user note() (rc=`=_rc')"
}

**# GR-08 y-label format
local ++test_count
capture noisily {
    finegray_cif, at(ccr5=0) ci ylabel(0(.05).3, format(%5.3f))
    assert "`.Graph.yaxis1.major.label_format'" == "%5.3f"
    finegray_cif, at(ccr5=0) ci ylabel(, format(%9.0g))
    assert "`.Graph.yaxis1.major.label_format'" == "%9.0g"
    * a rule without format(): decimals from ITS step
    finegray_cif, at(ccr5=0) ci ylabel(0(.05).3)
    assert "`.Graph.yaxis1.major.label_format'" == "%4.2f"
    assert "`.Graph.yaxis1.major.delta'" == ".05"
    finegray_cif, at(ccr5=0) ci ylabel(0(.02).1)
    assert "`.Graph.yaxis1.major.label_format'" == "%4.2f"
    finegray_cif, at(ccr5=0) ci ylabel(0(.2).6)
    assert "`.Graph.yaxis1.major.label_format'" == "%3.1f"
    * explicit values: 0.25 needs two decimals
    finegray_cif, at(ccr5=0) ci ylabel(0 .25 .5)
    assert "`.Graph.yaxis1.major.label_format'" == "%4.2f"
    * a text-labelled tick does not vote
    finegray_cif, at(ccr5=0) ci ylabel(0 .1 .2 .333333333 "third")
    assert "`.Graph.yaxis1.major.label_format'" == "%3.1f"
    * a tick needing more than six decimals keeps Stata's default
    finegray_cif, at(ccr5=0) ci ylabel(0 .2 .333333333)
    assert !ustrregexm("`.Graph.yaxis1.major.label_format'", "^%[0-9]+[.][0-9]+f$")
    * over() mode gets the same default
    finegray_cif, over(ccr5) ci ylabel(0(.05).5)
    assert "`.Graph.yaxis1.major.label_format'" == "%4.2f"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: GR-08 y-label format"
}
else {
    local ++fail_count
    display as error "  FAIL: GR-08 y-label format (rc=`=_rc')"
}

**# GR-09 refusals
local ++test_count
capture noisily {
    capture finegray_cif, over(ccr5) ci plot3opts(lpattern(solid))
    assert _rc == 198
    capture finegray_cif, over(ccr5) ci ci3opts(color(red))
    assert _rc == 198
    capture finegray_cif, at(ccr5=0) ci plot2opts(lpattern(solid))
    assert _rc == 198
    capture finegray_cif, over(ccr5) ci plot0opts(lpattern(solid))
    assert _rc == 198
    capture finegray_cif, over(ccr5) ci plot01opts(lpattern(solid))
    assert _rc == 198
    capture finegray_cif, over(ccr5) ci plot1opts(lpattern(solid)) plot1opts(lcolor(red))
    assert _rc == 198
    capture finegray_cif, over(ccr5) ci plotopts(lpattern(solid)) plotopts(lcolor(red))
    assert _rc == 198
    capture finegray_cif, at(ccr5=0) ciopts(color(red))
    assert _rc == 198
    capture finegray_cif, over(ccr5) ci2opts(color(red))
    assert _rc == 198
    * refused before the analysis: no graph drawn and no r(table) posted
    * (twoway rejecting the option after the fact would post both)
    capture graph drop _all
    _gr_style 1
    capture confirm matrix r(table)
    assert _rc != 0
    capture finegray_cif, over(ccr5) ci plot3opts(lpattern(solid))
    assert _rc == 198
    capture confirm matrix r(table)
    assert _rc != 0
    capture graph describe Graph
    assert _rc != 0
    * attime(): no graph, so the plot options are ignored with a note
    capture noisily finegray_cif, at(ccr5=0) attime(5) ci plotopts(lpattern(solid)) ///
        ciopts(color(red))
    assert _rc == 0
    confirm matrix r(table)
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: GR-09 refusals"
}
else {
    local ++fail_count
    display as error "  FAIL: GR-09 refusals (rc=`=_rc')"
}

**# GR-10 styling leaves the estimates and graph memory alone
local ++test_count
capture noisily {
    tempname T0 T1
    finegray_cif, over(ccr5) ci
    matrix `T0' = r(table)
    capture graph drop _all
    finegray_cif, over(ccr5) ci plotopts(lpattern(solid)) ciopts(color(red%20)) ///
        plot2opts(lcolor(navy)) ci1opts(color(%10)) ylabel(0(.05).5) ///
        name(grcheck, replace)
    matrix `T1' = r(table)
    assert mreldif(`T0', `T1') == 0
    * the y-format probe graph is dropped: only the user's named graph remains
    quietly graph dir, memory
    assert strtrim("`r(list)'") == "grcheck"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: GR-10 estimates and graph memory unchanged"
}
else {
    local ++fail_count
    display as error "  FAIL: GR-10 estimates and graph memory unchanged (rc=`=_rc')"
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_cif_graph tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _gr
    exit 1
}
display as result "ALL TESTS PASSED"
log close _gr
