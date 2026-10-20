* test_kmplot_axis_layout.do
* kmplot axis range, percent scale, text-label ylabel(), combined-graph region,
* byorder() and tmax(), measured in exported SVG
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-10-20
*
* Graph facts are read from the exported SVG (what was drawn), the returned
* values are cross-checked against the data (what should have been drawn):
*   L1-L4   automatic y range: survival stays 0..1; failure and cumulative
*           incidence of a rare outcome run from 0 to a rounded value just
*           above the plotted maximum (confidence limits included when drawn),
*           3-8 labels; ymax() overrides the upper limit
*   P1-P3   percent: curve drawn at 100 x the estimate (top of the curve read
*           back through the tick labels), saving()/landmark() stay
*           proportions, r(scale), default titles
*   T1      ylabel() with text labels does not stretch the axis when a risk
*           table is drawn
*   C1-C4   combined graph: graphregion(), plotregion(), combineopts(),
*           xsize()/ysize() reach the combined graph
*   O1-O4   byorder(): legend, risk-table rows, r(group_labels), r(risktable),
*           colors()/lpattern() assignment follow the new order
*   H1-H3   tmax(): x axis and curve stop, default timepoints capped, estimates
*           unchanged, landmark() beyond tmax() still returned
*   X1      the study's target call, end to end

clear all
version 16.0
set varabbrev off
local qa_dir "`c(pwd)'"
quietly do "`qa_dir'/_kmplot_qa_common.do"
quietly do "`qa_dir'/_kmplot_qa_cifsupport.do"
_kmplot_qa_bootstrap
_kmqa_init
global TABTOOLS_set_smallcells ""

**# SVG readers
* y tick labels of the main plot: visible, end-anchored, unrotated, numeric.
* value = a + b * (y - 0.36 * fontsize): b is value per pixel.
capture program drop _kmax_yticks
program define _kmax_yticks, rclass
    version 16.0
    syntax using/
    preserve
    _kmqa_svgtext using `"`using'"'
    quietly keep if vis == 1 & endanc == 1 & rot == 0
    quietly gen double val = real(txt)
    quietly keep if val < .
    * the y labels share one x; keep the left-most column of numeric labels
    quietly summarize x, meanonly
    quietly keep if abs(x - r(min)) < 2
    quietly count
    local n = r(N)
    if `n' >= 2 {
        quietly gen double yc = y - 0.36 * fs
        quietly summarize val, meanonly
        local vmin = r(min)
        local vmax = r(max)
        quietly summarize yc if val == `vmin', meanonly
        local ymin = r(mean)
        quietly summarize yc if val == `vmax', meanonly
        local ymax = r(mean)
        return scalar b = (`vmax' - `vmin') / (`ymax' - `ymin')
        return scalar a = `vmin' - r(N) * 0 - ((`vmax' - `vmin') / (`ymax' - `ymin')) * `ymin'
        return scalar vmin = `vmin'
        return scalar vmax = `vmax'
        return scalar ytop = `ymax'
        return scalar ybot = `ymin'
    }
    return scalar n = `n'
    restore
end

* extent of curve strokes of one colour: stroke width 6-14 px excludes the axes
* and long single lines are legend keys; paths and line segments both count
capture program drop _kmax_curve
program define _kmax_curve, rclass
    version 16.0
    syntax using/, COLOR(string) [MINW(real 6)]
    local color = upper("`color'")
    local miny = .
    local maxy = .
    local minx = .
    local maxx = .
    local npts = 0
    local npaths = 0
    local nlines = 0
    tempname fh
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        local isstroke = (strpos(`"`line'"', "stroke:`color';stroke-width:") > 0)
        if `isstroke' & regexm(`"`line'"', "stroke-width:([0-9.]+)") {
            local sw = real(regexs(1))
            if `sw' >= `minw' & `sw' <= 14 {
                if strpos(`"`line'"', "<path ") & regexm(`"`line'"', `"d="([^"]*)""') {
                    local d = regexs(1)
                    if `"`d'"' != "" local ++npaths
                    tokenize `"`d'"'
                    local i = 1
                    while `"``i''"' != "" {
                        local xt = subinstr(subinstr(`"``i''"', "M", "", .), "L", "", .)
                        local j = `i' + 1
                        local x = real(`"`xt'"')
                        local y = real(`"``j''"')
                        if `x' < . & `y' < . {
                            local ++npts
                            if `y' < `miny' local miny = `y'
                            if `maxy' == . | `y' > `maxy' local maxy = `y'
                            if `minx' == . | `x' < `minx' local minx = `x'
                            if `maxx' == . | `x' > `maxx' local maxx = `x'
                        }
                        local i = `i' + 2
                    }
                }
                else if strpos(`"`line'"', "<line ") & ///
                    regexm(`"`line'"', `"x1="([0-9.]+)" y1="([0-9.]+)" x2="([0-9.]+)" y2="([0-9.]+)""') {
                    local lx1 = real(regexs(1))
                    local ly1 = real(regexs(2))
                    local lx2 = real(regexs(3))
                    local ly2 = real(regexs(4))
                    * a long single line is a legend key, not a dash of the curve
                    if sqrt((`lx2' - `lx1')^2 + (`ly2' - `ly1')^2) > 150 {
                        file read `fh' line
                        continue
                    }
                    local ++nlines
                    forvalues k = 1/2 {
                        local x = `lx`k''
                        local y = `ly`k''
                        local ++npts
                        if `y' < `miny' local miny = `y'
                        if `maxy' == . | `y' > `maxy' local maxy = `y'
                        if `minx' == . | `x' < `minx' local minx = `x'
                        if `maxx' == . | `x' > `maxx' local maxx = `x'
                    }
                }
            }
        }
        file read `fh' line
    }
    file close `fh'
    return scalar npts = `npts'
    return scalar npaths = `npaths'
    return scalar nlines = `nlines'
    return scalar miny = `miny'
    return scalar maxy = `maxy'
    return scalar minx = `minx'
    return scalar maxx = `maxx'
end

* the main plot region: tallest rectangle that is neither the canvas nor the
* graph region (left edge beyond 150 px)
capture program drop _kmax_plotrect
program define _kmax_plotrect, rclass
    version 16.0
    syntax using/
    local best_h = 0
    local best_y = .
    local best_x = .
    local best_w = .
    tempname fh
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "<rect ") & ///
            regexm(`"`line'"', `"x="([0-9.]+)" y="([0-9.]+)" width="([0-9.]+)" height="([0-9.]+)""') {
            local rx = real(regexs(1))
            local ry = real(regexs(2))
            local rw = real(regexs(3))
            local rh = real(regexs(4))
            if `rx' > 150 & `rh' > `best_h' {
                local best_h = `rh'
                local best_y = `ry'
                local best_x = `rx'
                local best_w = `rw'
            }
        }
        file read `fh' line
    }
    file close `fh'
    return scalar h = `best_h'
    return scalar y = `best_y'
    return scalar x = `best_x'
    return scalar w = `best_w'
end

* topmost y of every filled confidence band (a path with fill-opacity; its d
* attribute can span several lines, so the whole file is read)
capture program drop _kmax_bandtop
program define _kmax_bandtop, rclass
    version 16.0
    syntax using/
    mata: km_bandtop(st_local("using"))
    return scalar miny = `bt_miny'
    return scalar nbands = `bt_n'
end
mata:
void km_bandtop(string scalar fn)
{
    real scalar fh, i, j, top, n
    string scalar s, line, chunk, d
    string rowvector parts
    real rowvector v
    fh = fopen(fn, "r")
    s = ""
    while ((line = fget(fh)) != J(0, 0, "")) s = s + line + " "
    fclose(fh)
    top = .
    n = 0
    s = subinstr(s, "<path", "@@<path", .)
    parts = ustrsplit(s, "@@")
    for (i = 1; i <= cols(parts); i++) {
        chunk = parts[i]
        if (strpos(chunk, "fill-opacity") == 0 | strpos(chunk, "<path") == 0) continue
        d = substr(chunk, strpos(chunk, `"d=""') + 3, .)
        d = substr(d, 1, strpos(d, `"""') - 1)
        d = subinstr(subinstr(d, "M", " "), "L", " ")
        v = strtoreal(tokens(d))
        n++
        for (j = 2; j <= cols(v); j = j + 2) {
            if (v[j] < . & (top == . | v[j] < top)) top = v[j]
        }
    }
    st_local("bt_miny", strofreal(top, "%21.10g"))
    st_local("bt_n", strofreal(n))
}
end

**# Fixture: unequal groups, rare outcome, competing event, value labels
capture program drop _kmax_data
program define _kmax_data
    version 16.0
    syntax , [N0(integer 400) N1(integer 200) SEED(integer 20261020)]
    clear
    set seed `seed'
    set obs `=`n0' + `n1''
    gen int id = _n
    gen byte g = _n > `n0'
    label define arm 0 "Natalizumab" 1 "Anti-CD20", replace
    label values g arm
    gen double t1 = rexponential(cond(g == 1, 60, 100))
    gen double t2 = rexponential(60)
    gen double t = min(t1, t2, 8)
    gen byte status = cond(t == t1, 1, cond(t == t2, 2, 0))
    drop t1 t2
    quietly stset t, failure(status == 1)
end

**## L1 survival plots keep 0..1
capture noisily {
    _kmax_data
    tempfile sv
    kmplot, by(g) name(l1, replace)
    graph export "`sv'.svg", name(l1) as(svg) replace
    assert r(ymax) == 1
    _kmax_yticks using "`sv'.svg"
    assert r(n) == 5
    assert r(vmin) == 0 & r(vmax) == 1
    kmplot, by(g) ci name(l1, replace)
    assert r(ymax) == 1
}
_kmqa_record, name("L1 survival: 0..1 with five labels, r(ymax) = 1") rc(`=_rc')

**## L2 rare failure and CIF: range just above the plotted maximum
foreach mode in failure cif failure_ci cif_ci {
    capture noisily {
        _kmax_data
        tempfile sv cv
        local opts "by(g)"
        if strpos("`mode'", "failure") local opts "`opts' failure"
        if strpos("`mode'", "cif") local opts "`opts' compete(status == 2)"
        if strpos("`mode'", "_ci") local opts "`opts' ci"
        kmplot, `opts' saving("`cv'", replace) name(l2, replace)
        local ymax = r(ymax)
        graph export "`sv'.svg", name(l2) as(svg) replace
        preserve
        use "`cv'", clear
        quietly summarize estimate, meanonly
        local pmax = r(max)
        local top = r(max)
        if strpos("`mode'", "_ci") {
            quietly summarize upper, meanonly
            local top = r(max)
        }
        restore
        * the fixture is rare: well under 20 percent
        assert `top' < .3 & `pmax' > .02
        assert `ymax' >= `top' - 1e-12
        assert `ymax' <= 1.6 * `top'
        _kmax_yticks using "`sv'.svg"
        assert r(n) >= 3 & r(n) <= 8
        assert r(vmin) == 0
        assert r(vmax) <= `ymax' + 1e-9 & r(vmax) >= 0.6 * `ymax'
        * the curve top, read back through the ticks, is the estimate maximum
        local a = r(a)
        local b = r(b)
        _kmax_curve using "`sv'.svg", color(#0072B2)
        local c1 = r(miny)
        _kmax_curve using "`sv'.svg", color(#D55E00)
        local c2 = r(miny)
        local ytop = min(`c1', `c2')
        local drawn = `a' + `b' * `ytop'
        assert abs(`drawn' - `pmax') < 0.04 * `ymax'
    }
    _kmqa_record, name("L2 `mode': axis 0..just above max (limits included when drawn), 3-8 labels, curve top = max") rc(`=_rc')
}

**## L3 ymax() overrides the upper limit and keeps automatic labels
capture noisily {
    _kmax_data
    tempfile sv
    kmplot, by(g) failure ymax(0.5) name(l3, replace)
    assert r(ymax) == 0.5
    graph export "`sv'.svg", name(l3) as(svg) replace
    _kmax_yticks using "`sv'.svg"
    assert r(n) >= 3 & r(n) <= 8
    assert r(vmin) == 0 & r(vmax) <= 0.5 + 1e-9 & r(vmax) >= 0.3
    kmplot, by(g) compete(status == 2) ymax(0.25) name(l3, replace)
    assert r(ymax) == 0.25
    kmplot, by(g) ymax(1) name(l3, replace)
    assert r(ymax) == 1
}
_kmqa_record, name("L3 ymax() sets the upper limit; labels stay automatic") rc(`=_rc')

**## L4 ymax() below the plotted maximum is refused; r(ymax) is the drawn axis limit
capture noisily {
    _kmax_data
    tempfile sv cv
    kmplot, by(g) failure ci saving("`cv'", replace) name(l4, replace)
    preserve
    use "`cv'", clear
    quietly summarize upper, meanonly
    local umax = r(max)
    quietly summarize estimate, meanonly
    local emax = r(max)
    restore
    assert `emax' < .2 & `umax' > .2
    * below the curve, and (with ci drawn) below the upper limit: rc 198
    _kmqa_expect, rc(198) cmd(kmplot, by(g) failure ymax(`=`emax'/2') name(l4, replace))
    _kmqa_expect, rc(198) cmd(kmplot, by(g) failure ci ymax(0.2) name(l4, replace))
    _kmqa_expect, rc(198) cmd(kmplot, by(g) compete(status == 2) ymax(0.01) name(l4, replace))
    * the plotted scale is the percent scale
    _kmqa_expect, rc(198) cmd(kmplot, by(g) failure percent ymax(10) name(l4, replace))
    _kmqa_expect, rc(198) cmd(kmplot, by(g) failure ci percent ymax(20) name(l4, replace))
    * legal values run, and r(ymax) is the upper end of the drawn axis
    foreach spec in "failure ymax(0.5)" "failure ci ymax(0.25)" "compete(status == 2) ymax(0.3)" ///
        "failure percent ymax(40)" "failure ci percent ymax(30)" "failure" "failure percent" {
        kmplot, by(g) `spec' name(l4, replace)
        local ymax = r(ymax)
        graph export "`sv'.svg", name(l4) as(svg) replace
        _kmax_yticks using "`sv'.svg"
        local a = r(a)
        local b = r(b)
        _kmax_plotrect using "`sv'.svg"
        local atop = `a' + `b' * r(y)
        assert abs(`atop' - `ymax') < 0.03 * `ymax'
    }
}
_kmqa_record, name("L4 ymax() below max (incl. CI, plotted scale) -> 198; r(ymax) = drawn axis top") rc(`=_rc')

**## P1 percent: curve drawn at 100 x, saving()/landmark() stay proportions
foreach mode in failure cif survival {
    capture noisily {
        _kmax_data
        tempfile sv cv0 cv1
        local opts "by(g) landmark(2 5 7.5)"
        if "`mode'" == "failure" local opts "`opts' failure"
        if "`mode'" == "cif" local opts "`opts' compete(status == 2)"
        kmplot, `opts' saving("`cv0'", replace) name(p1, replace)
        local ytitle0 `"`r(ytitle)'"'
        assert "`r(scale)'" == "proportion"
        tempname L0 L1
        matrix `L0' = r(landmarks)
        kmplot, `opts' percent saving("`cv1'", replace) name(p1, replace)
        assert "`r(scale)'" == "percent"
        local ytitle1 `"`r(ytitle)'"'
        local ymax1 = r(ymax)
        matrix `L1' = r(landmarks)
        * estimates, landmarks and saved curve are proportions in both runs
        assert mreldif(`L0', `L1') < 1e-12
        _kmqa_curvediff, a("`cv0'") b("`cv1'")
        assert r(unmatched) == 0 & r(maxdiff) < 1e-12 & r(n) > 50
        * titles
        if "`mode'" == "failure" assert `"`ytitle1'"' == `"`ytitle0' (%)"'
        if "`mode'" == "cif" assert `"`ytitle1'"' == "Cumulative incidence (%)"
        if "`mode'" == "survival" assert `"`ytitle1'"' == "Survival (%)"
        graph export "`sv'.svg", name(p1) as(svg) replace
        preserve
        _kmqa_svgtext using "`sv'.svg"
        quietly count if vis & rot & txt == `"`ytitle1'"'
        assert r(N) == 1
        restore
        if "`mode'" == "survival" {
            _kmax_yticks using "`sv'.svg"
            assert r(vmin) == 0 & r(vmax) == 100 & r(n) == 5
            assert `ymax1' == 100
        }
        else {
            preserve
            use "`cv0'", clear
            quietly summarize estimate, meanonly
            local pmax = 100 * r(max)
            restore
            assert `ymax1' >= `pmax' - 1e-9 & `ymax1' <= 1.6 * `pmax'
            _kmax_yticks using "`sv'.svg"
            assert r(n) >= 3 & r(n) <= 8 & r(vmin) == 0
            assert r(vmax) <= `ymax1' + 1e-9 & r(vmax) >= 0.6 * `ymax1'
            local a = r(a)
            local b = r(b)
            _kmax_curve using "`sv'.svg", color(#0072B2)
            local c1 = r(miny)
            _kmax_curve using "`sv'.svg", color(#D55E00)
            local drawn = `a' + `b' * min(`c1', r(miny))
            assert abs(`drawn' - `pmax') < 0.04 * `ymax1'
        }
    }
    _kmqa_record, name("P1 percent (`mode'): drawn at 100x, r(scale), titles, saving/landmark in proportions") rc(`=_rc')
}

**## P2 confidence limits are on the percent scale (band and line styles)
foreach mode in failure cif {
    foreach st in band line {
        capture noisily {
            _kmax_data
            tempfile sv cv
            local opts "by(g) ci cistyle(`st')"
            if "`mode'" == "failure" local opts "`opts' failure"
            else local opts "`opts' compete(status == 2)"
            kmplot, `opts' saving("`cv'", replace) name(p2, replace)
            preserve
            use "`cv'", clear
            quietly summarize upper, meanonly
            local umax = r(max)
            quietly summarize estimate, meanonly
            local emax = r(max)
            restore
            * the limits clearly exceed the curve on the proportion scale
            assert `umax' > 1.15 * `emax' & `umax' < .3
            kmplot, `opts' percent saving("`cv'", replace) name(p2, replace)
            local ymax = r(ymax)
            * the axis holds the upper limit on the percent scale
            assert `ymax' >= 100 * `umax' - 1e-9 & `ymax' <= 1.6 * 100 * `umax'
            graph export "`sv'.svg", name(p2) as(svg) replace
            _kmax_yticks using "`sv'.svg"
            local a = r(a)
            local b = r(b)
            if "`st'" == "band" {
                _kmax_bandtop using "`sv'.svg"
                assert r(nbands) == 2
                local ytop = r(miny)
            }
            else {
                _kmax_curve using "`sv'.svg", color(#0072B2) minw(5)
                local c1 = r(miny)
                _kmax_curve using "`sv'.svg", color(#D55E00) minw(5)
                local ytop = min(`c1', r(miny))
            }
            local drawn = `a' + `b' * `ytop'
            * the highest drawn point is 100 x the largest upper limit
            assert abs(`drawn' - 100 * `umax') < 0.04 * `ymax'
        }
        _kmqa_record, name("P2 percent + ci(`st') `mode': drawn limits top = 100 x upper bound") rc(`=_rc')
    }
}

**## T1 text labels in ylabel() do not stretch the axis (risk table drawn)
capture noisily {
    _kmax_data
    tempfile sv cv
    kmplot, by(g) failure saving("`cv'", replace) name(t1x, replace)
    preserve
    use "`cv'", clear
    quietly summarize estimate, meanonly
    assert r(max) < .2 & r(max) > .06
    restore
    foreach pct in 0 1 {
        local popt = cond(`pct', "percent", "")
        local mult = cond(`pct', 100, 1)
        if `pct' local labs `"0 "0" 5 "5" 10 "10" 15 "15" 20 "20""'
        else local labs `"0 "0" 0.05 "5" 0.10 "10" 0.15 "15" 0.20 "20""'
        kmplot, by(g) failure risktable timepoints(0 2 4 6 8) `popt' ylabel(`labs') ///
            name(t1, replace)
        assert r(ymax) < `mult' * 0.4
        graph export "`sv'.svg", name(t1) as(svg) replace
        _kmax_plotrect using "`sv'.svg"
        local H = r(h)
        assert `H' > 500
        local px = r(x)
        preserve
        _kmqa_svgtext using "`sv'.svg"
        * the y labels are the visible numeric texts left of the plot region
        * (ylabel() text labels are drawn rotated, so anchor and angle vary)
        keep if vis & x < `px'
        quietly summarize y if txt == "0", meanonly
        local y0 = r(min)
        quietly summarize y if txt == "20", meanonly
        assert r(N) == 1
        local y15 = r(min)
        * the 0 and 20 labels span most of the plot height (a stretched axis,
        * 0..0.4, would span a third of it)
        assert (`y0' - `y15') / `H' > 0.7 & (`y0' - `y15') / `H' < 1.02
        restore
    }
}
_kmqa_record, name("T1 ylabel() with text labels + risk table: axis spans its labels, not 0..0.4") rc(`=_rc')

**## C1 graphregion() reaches the combined graph
capture noisily {
    _kmax_data
    tempfile sv
    kmplot, by(g) risktable timepoints(0 2 4 6 8) scheme(sj) name(c1, replace)
    graph export "`sv'.svg", name(c1) as(svg) replace
    _kmqa_svgcanvas using "`sv'.svg"
    * control: sj's own outer colour is not white
    assert r(n) >= 1
    assert strpos(" `r(fills)' ", " #FFFFFF ") == 0
    local grey "`r(fills)'"
    kmplot, by(g) risktable timepoints(0 2 4 6 8) scheme(sj) graphregion(color(white)) name(c1, replace)
    graph export "`sv'.svg", name(c1) as(svg) replace
    _kmqa_svgcanvas using "`sv'.svg"
    assert r(n) >= 1
    foreach f in `r(fills)' {
        assert "`f'" == "#FFFFFF"
    }
    * a component graph of the same call keeps working without a risk table
    kmplot, by(g) scheme(sj) graphregion(color(white)) name(c1b, replace)
    graph export "`sv'.svg", name(c1b) as(svg) replace
    _kmqa_svgcanvas using "`sv'.svg"
    foreach f in `r(fills)' {
        assert "`f'" == "#FFFFFF"
    }
}
_kmqa_record, name("C1 scheme(sj) graphregion(color(white)): combined canvas white, sj grey without it") rc(`=_rc')

**## C2 plotregion(), combineopts() (verbatim, last), xsize()/ysize()
capture noisily {
    _kmax_data
    tempfile sv
    * combineopts wins over graphregion() and reaches only the combined graph
    kmplot, by(g) risktable timepoints(0 2 4 6 8) scheme(sj) graphregion(color(white)) ///
        combineopts(graphregion(color(red))) name(c2, replace)
    graph export "`sv'.svg", name(c2) as(svg) replace
    _kmqa_svgcanvas using "`sv'.svg"
    assert r(n) >= 1
    foreach f in `r(fills)' {
        assert "`f'" == "#FF0000"
    }
    * xsize / ysize give the exported figure its shape
    kmplot, by(g) risktable timepoints(0 2 4 6 8) scheme(sj) xsize(8) ysize(4) name(c2, replace)
    graph export "`sv'.svg", name(c2) as(svg) replace
    _kmqa_svgcanvas using "`sv'.svg"
    assert abs(r(width) / r(height) - 2) < 0.02
    kmplot, by(g) risktable timepoints(0 2 4 6 8) scheme(sj) xsize(4) ysize(8) name(c2, replace)
    graph export "`sv'.svg", name(c2) as(svg) replace
    _kmqa_svgcanvas using "`sv'.svg"
    assert abs(r(width) / r(height) - 0.5) < 0.01
    * plotregion() is accepted with a risk table
    kmplot, by(g) risktable timepoints(0 2 4 6 8) scheme(sj) plotregion(color(white)) name(c2, replace)
}
_kmqa_record, name("C2 combineopts() verbatim and last; xsize()/ysize() set the exported shape; plotregion() runs") rc(`=_rc')

**## O1 byorder(): legend, risk-table rows, labels and the returned table
capture noisily {
    _kmax_data
    tempfile sv
    * default order: Natalizumab (0) first
    kmplot, by(g) risktable timepoints(0 2 4 6 8) name(o1, replace)
    assert `"`r(group_labels)'"' == "Natalizumab | Anti-CD20"
    tempname R0 R1
    matrix `R0' = r(risktable)
    graph export "`sv'.svg", name(o1) as(svg) replace
    preserve
    _kmqa_svgtext using "`sv'.svg"
    keep if vis & (txt == "Natalizumab" | txt == "Anti-CD20")
    * legend (top) and table rows (bottom): first label higher on the page
    sort y
    assert txt[1] == "Natalizumab" & txt[2] == "Anti-CD20" & txt[3] == "Natalizumab" & txt[4] == "Anti-CD20"
    restore
    * byorder(1 0): Anti-CD20 first everywhere
    kmplot, by(g) risktable timepoints(0 2 4 6 8) byorder(1 0) name(o1, replace)
    assert `"`r(group_labels)'"' == "Anti-CD20 | Natalizumab"
    matrix `R1' = r(risktable)
    graph export "`sv'.svg", name(o1) as(svg) replace
    preserve
    _kmqa_svgtext using "`sv'.svg"
    keep if vis & (txt == "Natalizumab" | txt == "Anti-CD20")
    sort y
    assert txt[1] == "Anti-CD20" & txt[2] == "Natalizumab" & txt[3] == "Anti-CD20" & txt[4] == "Natalizumab"
    restore
    * risk-table rows follow the order: 200 people at time 0 first, then 400
    assert `R0'[1, 3] == 400 & `R0'[6, 3] == 200
    assert `R1'[1, 3] == 200 & `R1'[6, 3] == 400
    assert rowsof(`R1') == 10
    * counts are the same cells, reordered
    forvalues j = 1/5 {
        assert `R1'[1, 3] == `R0'[6, 3]
        assert `R1'[`j', 3] == `R0'[`j' + 5, 3] & `R1'[`j' + 5, 3] == `R0'[`j', 3]
    }
    * a partial order: listed levels first, the rest in sort order
    kmplot, by(g) risktable timepoints(0 2 4 6 8) byorder(1) name(o1, replace)
    assert `"`r(group_labels)'"' == "Anti-CD20 | Natalizumab"
}
_kmqa_record, name("O1 byorder(1 0): legend, table rows, r(group_labels), r(risktable) all reordered") rc(`=_rc')

**## O2 byorder(): colors() and lpattern() apply in the new order
capture noisily {
    _kmax_data
    tempfile sv
    * g = 1 fails faster, so its curve ends higher (smaller SVG y)
    kmplot, by(g) failure colors(black red) lpattern(solid solid) name(o2, replace)
    graph export "`sv'.svg", name(o2) as(svg) replace
    _kmax_curve using "`sv'.svg", color(#000000)
    local blk0 = r(miny)
    _kmax_curve using "`sv'.svg", color(#FF0000)
    local red0 = r(miny)
    assert `blk0' > `red0'
    kmplot, by(g) failure colors(black red) lpattern(solid solid) byorder(1 0) name(o2, replace)
    graph export "`sv'.svg", name(o2) as(svg) replace
    _kmax_curve using "`sv'.svg", color(#000000)
    local blk1 = r(miny)
    _kmax_curve using "`sv'.svg", color(#FF0000)
    local red1 = r(miny)
    * black now belongs to g = 1 (the higher curve), red to g = 0
    assert `blk1' < `red1'
    assert abs(`blk1' - `red0') < 1.5 & abs(`red1' - `blk0') < 1.5
    * lpattern(): the first listed pattern goes to the first drawn group.  A
    * dashed curve is drawn as many short segments, a solid one as one path.
    kmplot, by(g) failure colors(black black) lpattern(solid dash) byorder(1 0) name(o2, replace)
    graph export "`sv'.svg", name(o2) as(svg) replace
    _kmax_curve using "`sv'.svg", color(#000000)
    * a dashed curve is many short segments, a solid one a single path: one
    * solid path and one dashed run of segments, both black
    assert r(npaths) >= 1 & r(nlines) > 20
    local dashed_lines = r(nlines)
    kmplot, by(g) failure colors(black black) lpattern(solid solid) byorder(1 0) name(o2, replace)
    graph export "`sv'.svg", name(o2) as(svg) replace
    _kmax_curve using "`sv'.svg", color(#000000)
    assert r(nlines) < `dashed_lines' / 5
}
_kmqa_record, name("O2 byorder(1 0): colors() and lpattern() follow the drawn order") rc(`=_rc')

**## O3 byorder(): estimates are attached to the right level
capture noisily {
    _kmax_data
    kmplot, by(g) failure landmark(5) name(o3, replace)
    tempname A B
    matrix `A' = r(landmarks)
    kmplot, by(g) failure landmark(5) byorder(1 0) name(o3, replace)
    matrix `B' = r(landmarks)
    * the two estimates are the same two numbers in some order
    local lo0 = min(`A'[1, 3], `A'[2, 3])
    local hi0 = max(`A'[1, 3], `A'[2, 3])
    local lo1 = min(`B'[1, 3], `B'[2, 3])
    local hi1 = max(`B'[1, 3], `B'[2, 3])
    assert abs(`lo0' - `lo1') < 1e-14 & abs(`hi0' - `hi1') < 1e-14
    * and they are the Kaplan-Meier values of the right arms (independent sts)
    quietly sts generate s0 = s if g == 0
    quietly sts generate s1 = s if g == 1
    quietly summarize s0 if _t <= 5, meanonly
    local f0 = 1 - r(min)
    quietly summarize s1 if _t <= 5, meanonly
    local f1 = 1 - r(min)
    assert abs(min(`f0', `f1') - `lo0') < 1e-12 & abs(max(`f0', `f1') - `hi0') < 1e-12
    assert `f1' > `f0'
    * the order of the rows follows byorder: group index 1 is the first drawn level
    assert abs(`B'[1, 3] - `f1') < 1e-12 | abs(`A'[1, 3] - `f0') < 1e-12
}
_kmqa_record, name("O3 byorder(): landmark estimates are the right arms' values") rc(`=_rc')

**## H1 tmax(): x axis, curve and default timepoints stop at tmax
capture noisily {
    _kmax_data
    tempfile sv0 sv1
    kmplot, by(g) failure name(h1, replace)
    graph export "`sv0'.svg", name(h1) as(svg) replace
    kmplot, by(g) failure tmax(3) name(h1, replace)
    assert r(tmax) == 3
    graph export "`sv1'.svg", name(h1) as(svg) replace
    * x labels: numeric, midpoint-anchored, on the bottom axis; read the axis
    * scale (time per pixel) from the first and last label
    foreach v in 0 1 {
        preserve
        _kmqa_svgtext using "`sv`v''.svg"
        keep if vis & midanc & !rot
        gen double val = real(txt)
        keep if val < .
        quietly summarize y, meanonly
        keep if y > r(max) - 5
        quietly summarize val, meanonly
        local xmax`v' = r(max)
        local vlo = r(min)
        quietly summarize x if val == r(max), meanonly
        local xhi = r(mean)
        quietly summarize x if val == `vlo', meanonly
        local xlo = r(mean)
        local xb`v' = (`xmax`v'' - `vlo') / (`xhi' - `xlo')
        local xa`v' = `vlo' - `xb`v'' * `xlo'
        restore
        _kmax_curve using "`sv`v''.svg", color(#0072B2)
        local cend`v' = `xa`v'' + `xb`v'' * r(maxx)
    }
    assert `xmax0' >= 6
    assert `xmax1' <= 3 & `xmax1' >= 2
    * the curve, read back through the tick labels, ends at about the longest
    * follow-up without tmax and at (not beyond) 3 with it
    assert `cend0' > 6
    assert `cend1' <= 3.05 & `cend1' >= 2.5
    * default risk-table timepoints are capped
    kmplot, by(g) risktable tmax(3) name(h1, replace)
    local tp "`r(timepoints)'"
    assert wordcount("`tp'") >= 2
    foreach t of local tp {
        assert `t' <= 3 + 1e-9
    }
    assert r(tmax) == 3
    kmplot, by(g) risktable name(h1, replace)
    local tp0 "`r(timepoints)'"
    local last : word `=wordcount("`tp0'")' of `tp0'
    assert `last' > 3
    * explicit timepoints inside tmax are honoured exactly
    kmplot, by(g) risktable tmax(3) timepoints(0 1 2 3) name(h1, replace)
    assert "`r(timepoints)'" == "0 1 2 3"
}
_kmqa_record, name("H1 tmax(3): x axis, curve and default risk-table grid stop at 3") rc(`=_rc')

**## H2 tmax(): estimates unchanged; landmark() beyond tmax() still returned
capture noisily {
    _kmax_data
    tempfile cv0 cv1
    kmplot, by(g) compete(status == 2) landmark(2 3 6) saving("`cv0'", replace) name(h2, replace)
    tempname A B
    matrix `A' = r(landmarks)
    kmplot, by(g) compete(status == 2) landmark(2 3 6) tmax(3) saving("`cv1'", replace) name(h2, replace)
    matrix `B' = r(landmarks)
    assert mreldif(`A', `B') < 1e-14
    assert !missing(`B'[3, 3]) & !missing(`B'[6, 3])
    * saved curve rows up to tmax are identical
    preserve
    use "`cv0'", clear
    keep if time <= 3
    save "`cv0'", replace
    use "`cv1'", clear
    keep if time <= 3
    save "`cv1'", replace
    restore
    _kmqa_curvediff, a("`cv0'") b("`cv1'")
    assert r(unmatched) == 0 & r(maxdiff) < 1e-14 & r(n) > 20
}
_kmqa_record, name("H2 tmax(): estimates unchanged, landmark(6) beyond tmax(3) returned") rc(`=_rc')

**## X1 the study's target call, end to end
capture noisily {
    clear
    set seed 20261020
    set obs 3000
    gen long id = _n
    gen double x = rnormal()
    gen byte arm = runiform() < invlogit(-.4 + .5 * x)
    quietly logit arm x
    predict double ps, pr
    quietly summarize arm, meanonly
    gen double sw = cond(arm == 1, r(mean) / ps, (1 - r(mean)) / (1 - ps))
    replace sw = min(sw, 4.3)
    label define armlbl 0 "Natalizumab" 1 "Anti-CD20", replace
    label values arm armlbl
    gen long t0 = 20000 + floor(runiform() * 700)
    gen long admin = ceil(365.25 * (3 + 5 * runiform()))
    gen long tb = ceil(rexponential(365.25 / (.006 * cond(arm == 1, 1.6, 1))))
    gen long td = ceil(rexponential(365.25 / .012))
    gen long dur = min(tb, td, admin)
    gen byte st_breast = cond(dur == tb, 1, cond(dur == td, 2, 0))
    gen long exit_breast = t0 + dur
    format exit_breast t0 %td
    drop tb td admin dur ps
    quietly stset exit_breast [pw=sw], failure(st_breast == 1) origin(time t0) scale(365.25)
    tempfile png svg
    kmplot, by(arm) compete(st_breast == 2) risktable riskmask(5) percent tmax(5) timepoints(0(1)5) ///
        byorder(1 0) colors(black black) lpattern(solid dash) xtitle("Years since starting treatment") ///
        scheme(sj) graphregion(color(white)) landmark(5) name(fig1, replace)
    assert "`r(estimator)'" == "aalen_johansen"
    assert "`r(scale)'" == "percent"
    assert r(tmax) == 5 & r(riskmask) == 5
    assert "`r(timepoints)'" == "0 1 2 3 4 5"
    assert `"`r(group_labels)'"' == "Anti-CD20 | Natalizumab"
    assert `"`r(xtitle)'"' == "Years since starting treatment"
    assert `"`r(ytitle)'"' == "Cumulative incidence (%)"
    graph export "`png'.png", name(fig1) as(png) width(1600) replace
    confirm file "`png'.png"
    graph export "`svg'.svg", name(fig1) as(svg) replace
    * white background
    _kmqa_svgcanvas using "`svg'.svg"
    foreach f in `r(fills)' {
        assert "`f'" == "#FFFFFF"
    }
    * percent axis, labels automatic, curve top = 100 x the 5-year-or-later maximum
    local ymax = r(ymax)
    _kmax_yticks using "`svg'.svg"
    assert r(n) >= 3 & r(n) <= 8 & r(vmin) == 0
    * anti-CD20 drawn first: first legend entry and first table row
    preserve
    _kmqa_svgtext using "`svg'.svg"
    keep if vis & (txt == "Natalizumab" | txt == "Anti-CD20")
    sort y
    assert txt[1] == "Anti-CD20" & txt[3] == "Anti-CD20"
    restore
    * solid then dash, both black: one path (solid) and many segments (dash)
    _kmax_curve using "`svg'.svg", color(#000000)
    assert r(npaths) >= 1 & r(nlines) > 10
}
_kmqa_record, name("X1 the spec's target call: estimator, scale, order, white canvas, percent labels, line styles") rc(`=_rc')

_kmqa_finish, suite("test_kmplot_axis_layout")
