* test_kmplot_v142.do
* Regression tests for kmplot 1.4.2: p-value text placement
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-10-12
*
* Through 1.4.1 the default pvaluepos(bottomright) anchored the text at
* y = 0.02 with placement(sw), so it hung below that point onto the time axis
* (struck through by the axis line with a risk table), and the keyword
* positions assumed a 0-1 y axis: with ylabel(0(.2).6) the top positions fell
* outside the axis and Stata did not draw the text at all.  These tests read
* the rendered SVG, so they measure where the text was drawn rather than what
* kmplot says it asked for, and pin the returned coordinates to oracles built
* from sts generate.

clear all
version 16.0
set varabbrev off

**# Bootstrap
local qa_dir "`c(pwd)'"
do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap

**# Rendered geometry of the p-value text against the main panel's axes.
* SVG text y is the baseline.  The main y axis is the tallest vertical rule;
* its lower end is the time axis.  Ticks are the short horizontal rules that
* start on it; the lowest is y = 0 when the y range starts at 0.
capture program drop _km_pv_geom
program define _km_pv_geom, rclass
    version 16.0
    syntax using/, TEXT(string)

    local height = .
    local ax_x = .
    local ax_top = .
    local ax_bot = .
    local t_y = .
    local t_fs = .
    local t_n = 0
    local nl = 0
    tempname fh
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "viewBox=") & ///
            regexm(`"`line'"', `"viewBox="0 0 ([0-9.]+) ([0-9.]+)""') {
            local height = real(regexs(2))
        }
        if strpos(`"`line'"', "<line ") & ///
            regexm(`"`line'"', ///
            `"x1="([0-9.]+)" y1="([0-9.]+)" x2="([0-9.]+)" y2="([0-9.]+)""') {
            local ++nl
            local lx1_`nl' = real(regexs(1))
            local ly1_`nl' = real(regexs(2))
            local lx2_`nl' = real(regexs(3))
            local ly2_`nl' = real(regexs(4))
        }
        if strpos(`"`line'"', "<text ") & strpos(`"`line'"', `"`text'"') {
            if regexm(`"`line'"', `"<text x="([0-9.-]+)" y="([0-9.-]+)""') {
                local t_y = real(regexs(2))
            }
            if regexm(`"`line'"', "font-size:([0-9.]+)px") {
                local t_fs = real(regexs(1))
            }
            local ++t_n
        }
        file read `fh' line
    }
    file close `fh'

    * tallest vertical rule = main y axis
    local best = 0
    forvalues i = 1/`nl' {
        if abs(`lx1_`i'' - `lx2_`i'') < 0.01 {
            local len = abs(`ly2_`i'' - `ly1_`i'')
            if `len' > `best' {
                local best = `len'
                local ax_x = `lx1_`i''
                local ax_top = min(`ly1_`i'', `ly2_`i'')
                local ax_bot = max(`ly1_`i'', `ly2_`i'')
            }
        }
    }
    * ticks on that axis, inside its span
    local tick_lo = .
    local tick_hi = .
    forvalues i = 1/`nl' {
        if abs(`ly1_`i'' - `ly2_`i'') < 0.01 & ///
            abs(`lx1_`i'' - `ax_x') < 0.01 & `lx2_`i'' < `lx1_`i'' & ///
            `ly1_`i'' >= `ax_top' - 0.01 & `ly1_`i'' <= `ax_bot' + 0.01 {
            if missing(`tick_lo') | `ly1_`i'' > `tick_lo' local tick_lo = `ly1_`i''
            if missing(`tick_hi') | `ly1_`i'' < `tick_hi' local tick_hi = `ly1_`i''
        }
    }
    return scalar t_n = `t_n'
    return scalar t_y = `t_y'
    return scalar t_fs = `t_fs'
    * glyph extent around the baseline: ascenders/caps 0.75 em above,
    * descenders ("p", "g") 0.22 em below
    return scalar t_top = `t_y' - 0.75 * `t_fs'
    return scalar t_bot = `t_y' + 0.22 * `t_fs'
    return scalar ax_top = `ax_top'
    return scalar ax_bot = `ax_bot'
    return scalar tick_lo = `tick_lo'
    return scalar tick_hi = `tick_hi'
end

**# Fixture: built-in cancer data, three drug groups, p < 0.001.
capture program drop _km_v142_data
program define _km_v142_data
    version 16.0
    sysuse cancer, clear
    stset studytime, failure(died)
end

local test_count = 0
local pass_count = 0
local fail_count = 0

**# P1-P16: every keyword position x survival/failure x risk table.
* The text lies inside the plot region and wholly above y = 0 (the lowest
* tick, which is also the time axis with a risk table), and below the top.
foreach f in surv fail {
    foreach rt in no rt {
        foreach pos in bottomright bottomleft topleft topright {
            local ++test_count
            capture noisily {
                _km_v142_data
                local fo = cond("`f'" == "fail", "failure", "")
                local ro = cond("`rt'" == "rt", "risktable", "")
                tempfile svgbase
                local svg "`svgbase'.svg"
                kmplot, by(drug) `fo' `ro' pvalue pvaluepos(`pos') ///
                    name(v142, replace)
                local ry = r(pvalue_y)
                local rx = r(pvalue_x)
                local rp "`r(pvalue_placement)'"
                local rtext `"`r(pvalue_text)'"'
                graph export "`svg'", as(svg) replace
                graph drop v142

                * returned coordinates: default y axis spans 0..1
                quietly summarize _t
                local tmax = r(max)
                local top = inlist("`pos'", "topleft", "topright")
                local left = inlist("`pos'", "topleft", "bottomleft")
                local wanty = cond(`top', 0.95, 0.05)
                local xf = cond(`left', 0.05, cond("`pos'" == "topright", 0.95, 0.98))
                local wantx = `tmax' * `xf'
                assert !missing(`ry', `rx', `wanty', `wantx')
                assert reldif(`ry', `wanty') < 1e-12
                assert reldif(`rx', `wantx') < 1e-12
                local wantp = cond("`pos'" == "topleft", "e", ///
                    cond("`pos'" == "topright", "w", ///
                    cond("`pos'" == "bottomleft", "ne", "nw")))
                assert "`rp'" == "`wantp'"

                * rendered geometry
                _km_pv_geom using "`svg'", text("Log-rank p &lt; 0.001")
                assert r(t_n) == 1
                assert !missing(r(t_y), r(t_fs), r(t_top), r(t_bot))
                assert !missing(r(ax_top), r(ax_bot), r(tick_lo), r(tick_hi))
                assert r(t_top) > r(ax_top)
                assert r(t_bot) < r(ax_bot)
                assert r(t_bot) < r(tick_lo)
                assert !missing(r(t_top), r(tick_hi))
                assert r(t_top) > r(tick_hi)
                * bottom positions stay clear of the axis by a visible gap
                if !`top' {
                    assert !missing(r(t_bot), r(tick_lo), r(t_fs))
                    assert r(tick_lo) - r(t_bot) > 0.25 * r(t_fs)
                }
            }
            if _rc == 0 {
                local ++pass_count
                display as result "PASS: P`test_count' `f' `rt' `pos'"
            }
            else {
                local ++fail_count
                display as error "FAIL: P`test_count' `f' `rt' `pos' (rc=" _rc ")"
            }
        }
    }
}

**# Y1: custom ylabel() narrower than 0..1 keeps top positions on the axis.
* 1.4.1 anchored at 0.95 on a 0..0.6 axis and the text was not drawn.
* Oracle: the axis spans 0 to max(0.6, largest plotted failure probability).
local ++test_count
capture noisily {
    _km_v142_data
    tempvar s
    sts generate `s' = s, by(drug)
    quietly summarize `s'
    local hi = max(0.6, 1 - r(min))
    local lo = 0
    local want = `hi' - 0.05 * (`hi' - `lo')
    tempfile svgbase
    local svg "`svgbase'.svg"
    kmplot, by(drug) failure pvalue pvaluepos(topleft) ylabel(0(.2).6) ///
        name(v142, replace)
    assert !missing(r(pvalue_y), `want')
    assert reldif(r(pvalue_y), `want') < 1e-12
    assert "`r(pvalue_placement)'" == "e"
    graph export "`svg'", as(svg) replace
    graph drop v142
    _km_pv_geom using "`svg'", text("Log-rank p &lt; 0.001")
    assert r(t_n) == 1
    assert !missing(r(t_top), r(t_bot), r(ax_top), r(tick_lo))
    assert r(t_top) > r(ax_top)
    assert r(t_bot) < r(tick_lo)
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: Y1 ylabel(0(.2).6) topleft drawn on the axis"
}
else {
    local ++fail_count
    display as error "FAIL: Y1 ylabel(0(.2).6) topleft (rc=" _rc ")"
}

**# Y2: ylabel() starting above 0 moves the bottom anchor up with the axis.
* Survival, no CI, no median: the axis bottom is min(lowest S, 0.4).
local ++test_count
capture noisily {
    _km_v142_data
    tempvar s
    sts generate `s' = s, by(drug)
    quietly summarize `s'
    local lo = min(0.4, r(min))
    local hi = max(1, r(max))
    local want = `lo' + 0.05 * (`hi' - `lo')
    kmplot, by(drug) pvalue ylabel(.4(.2)1) risktable name(v142, replace)
    assert !missing(r(pvalue_y), `want')
    assert reldif(r(pvalue_y), `want') < 1e-12
    assert "`r(pvalue_placement)'" == "nw"
    assert "`r(pvalue_pos)'" == "bottomright"
    graph drop v142
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: Y2 ylabel(.4(.2)1) bottom anchor tracks the axis"
}
else {
    local ++fail_count
    display as error "FAIL: Y2 ylabel(.4(.2)1) bottom anchor (rc=" _rc ")"
}

**# Y3: median lines reach y = 0, so they hold the axis bottom at 0.
local ++test_count
capture noisily {
    _km_v142_data
    kmplot, by(drug) median pvalue ylabel(.4(.2)1) name(v142, replace)
    assert !missing(r(pvalue_y))
    assert reldif(r(pvalue_y), 0.05) < 1e-12
    graph drop v142
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: Y3 median lines keep the axis bottom at 0"
}
else {
    local ++fail_count
    display as error "FAIL: Y3 median lines and the axis bottom (rc=" _rc ")"
}

**# A1: pvalueat() is unchanged and reports placement c.
local ++test_count
capture noisily {
    _km_v142_data
    kmplot, by(drug) pvalue pvalueat(.5 10) name(v142, replace)
    assert r(pvalue_y) == .5
    assert r(pvalue_x) == 10
    assert "`r(pvalue_placement)'" == "c"
    assert `"`r(pvalue_at)'"' == ".5 10"
    graph drop v142
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: A1 pvalueat() coordinates and placement"
}
else {
    local ++fail_count
    display as error "FAIL: A1 pvalueat() (rc=" _rc ")"
}

**# A2: without pvalue no placement returns are posted.
local ++test_count
capture noisily {
    _km_v142_data
    kmplot, by(drug) name(v142, replace)
    assert missing(r(pvalue_y))
    assert missing(r(pvalue_x))
    assert "`r(pvalue_placement)'" == ""
    graph drop v142
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: A2 no placement returns without pvalue"
}
else {
    local ++fail_count
    display as error "FAIL: A2 placement returns without pvalue (rc=" _rc ")"
}

**# Summary
display "RESULT: test_kmplot_v142 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    exit 1
}
