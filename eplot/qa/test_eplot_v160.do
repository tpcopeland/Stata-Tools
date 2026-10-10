*! test_eplot_v160.do - Regression tests for eplot 1.6.0
*! Covers favors() labels (anchored at the null since 1.6.1; log and linear,
*! below and inside), their tick-label text size and the size(),
*! color() and gap() suboptions, the ends fallback when the null sits on a tick
*! span end, effect(, atnull) placing the axis title on the null in every mode
*! and both orientations, its fallbacks and refusals, and the effect axis line
*! stopping at the end of the effect range when a values column is drawn,
*! plus the 1.6.0 design-review items: eform+rescale order, block-wise sort,
*! off-axis null line, plotregion merge, repeated xline(), null() styling,
*! baselevels, diamondcolor(), offset scaling, data-mode level(), export(),
*! symmetric narrow log ticks, hetrow, xline() label placement and styling,
*! order() typos, noci range, and the shortened default title with values.
*! Positions are read back from SVG exports of the drawn graph.

clear all
set varabbrev off
set graphics off
version 16.0

capture log close _all
log using "test_eplot_v160.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

* Reads one drawn text element back from an SVG export: count, size, x, y.
capture program drop _v160_svgtext
program define _v160_svgtext, rclass
    version 16.0
    syntax , Graph(name) Text(string asis)
    gettoken text : text
    tempfile svg
    quietly graph export "`svg'", name(`graph') as(svg) replace
    tempname fh
    local n 0
    local size .
    local fill ""
    local x .
    local y .
    file open `fh' using "`svg'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `">`text'</text>"') {
            local ++n
            if `n' == 1 {
                if regexm(`"`macval(line)'"', "font-size:([0-9.]+)px") local size = real(regexs(1))
                if regexm(`"`macval(line)'"', "fill:(#[0-9A-Fa-f]+)") local fill = regexs(1)
                if regexm(`"`macval(line)'"', `"<text x="(-?[0-9.]+)""') local x = real(regexs(1))
                if regexm(`"`macval(line)'"', `" y="(-?[0-9.]+)""') local y = real(regexs(1))
            }
        }
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
    return scalar size = `size'
    return scalar x = `x'
    return scalar y = `y'
    return local fill "`fill'"
end

* Reads the lowest horizontal line of an SVG export (the x axis line).
capture program drop _v160_axisline
program define _v160_axisline, rclass
    version 16.0
    syntax , Graph(name)
    tempfile svg
    quietly graph export "`svg'", name(`graph') as(svg) replace
    tempname fh
    local x1 .
    local x2 .
    local y -1
    file open `fh' using "`svg'", read text
    file read `fh' line
    while r(eof) == 0 {
        if regexm(`"`macval(line)'"', `"<line x1="([0-9.]+)" y1="([0-9.]+)" x2="([0-9.]+)" y2="([0-9.]+)""') {
            local a1 = real(regexs(1))
            local b1 = real(regexs(2))
            local a2 = real(regexs(3))
            local b2 = real(regexs(4))
            if `b1' == `b2' & `b1' > `y' {
                local y = `b1'
                local x1 = min(`a1', `a2')
                local x2 = max(`a1', `a2')
            }
        }
        file read `fh' line
    }
    file close `fh'
    return scalar x1 = `x1'
    return scalar x2 = `x2'
    return scalar y = `y'
end

* The reported figure: intervals 0.83-1.49 under ticks 0.8-1.6.
clear
input str20 lab byte t double(tr lo hi)
"Group A" 0 .    .    .
"Row 1"   1 1.13 1.05 1.21
"Row 2"   1 0.91 0.83 0.99
"Row 3"   1 1.22 1.01 1.49
end
tempfile v160_base
quietly save `v160_base'
local tick_opts "xlabel(0.8 1 1.2 1.4 1.6, format(%3.1f) labsize(small))"

**# favors() placement and text

**## below: labels under the tick labels, reading outward from the null
* Pre-1.6.0 the labels sat midway between the null and the interval ends.
* 1.6.0 centred them on each half of the tick span; 1.6.1 anchors them at
* the null (test_eplot_v161.do measures the gaps).
local ++test_count
capture noisily {
    use `v160_base', clear
    eplot tr lo hi, labels(lab) type(t) logscale values `tick_opts' ///
        vtitle("TR (95% CI)") favors("Shorter" "Longer", below) ///
        name(v160_t1, replace)
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "xmlabel(") == 0
    assert strpos(`"`cmd'"', `" 1 `"Shorter"', tstyle(tick_label) size(small) color(gs5) placement(sw)"') > 0
    assert strpos(`"`cmd'"', `" 1 `"Longer"', tstyle(tick_label) size(small) color(gs5) placement(se)"') > 0
    * Drawn either side of the null, below the tick labels, in their size.
    _v160_svgtext, graph(v160_t1) text("0.8")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    local tsize = r(size)
    _v160_svgtext, graph(v160_t1) text("1.0")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    local x10 = r(x)
    local ytick = r(y)
    _v160_svgtext, graph(v160_t1) text("Shorter")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    assert r(n) == 1
    assert r(x) < `x10'
    assert !missing(r(size), `tsize') & reldif(r(size), `tsize') < 1e-6
    assert !missing(r(y), `ytick') & r(y) > `ytick'
    _v160_svgtext, graph(v160_t1) text("Longer")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    assert r(n) == 1
    assert r(x) > `x10'
    assert !missing(r(size), `tsize') & reldif(r(size), `tsize') < 1e-6
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**## Inside the plot and on a linear axis the labels meet at the null
* 1.6.1: anchored at the null gap() clear of it, unboxed (was centred).
local ++test_count
capture noisily {
    use `v160_base', clear
    drop if t == 0
    gen double d = tr - 1
    gen double dl = lo - 1
    gen double du = hi - 1
    eplot d dl du, labels(lab) xlabel(-0.4(0.2)0.6) ///
        favors("Less" "More") name(v160_t2, replace)
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', `"text(4.5 0 `"Less"', tstyle(tick_label) color(gs5) placement(w) margin(r=1.5 l=0 t=0 b=0))"') > 0
    assert strpos(`"`cmd'"', `"text(4.5 0 `"More"', tstyle(tick_label) color(gs5) placement(e) margin(l=1.5 r=0 t=0 b=0))"') > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**## size(), color(), and gap() style the labels; xlabel labsize() is inherited
local ++test_count
capture noisily {
    use `v160_base', clear
    eplot tr lo hi, labels(lab) type(t) logscale `tick_opts' ///
        favors("Shorter" "Longer", below size(medium) color(navy) gap(*6)) ///
        name(v160_t3, replace)
    local cmd `"`r(cmd)'"'
    * 1.6.1: gap() is the gap from the null; *6 is six times the default 1.5.
    assert strpos(`"`cmd'"', "size(medium) color(navy) placement(sw)") > 0
    assert strpos(`"`cmd'"', " r=9 l=0 b=0))") > 0
    _v160_svgtext, graph(v160_t3) text("1.0")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    local tsize = r(size)
    _v160_svgtext, graph(v160_t3) text("Shorter")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    assert !missing(r(size), `tsize') & r(size) > `tsize'
    assert lower("`r(fill)'") == "#1a476f"
    * Without size() the xlabel() labsize() is reused; the default gap is 1.5.
    eplot tr lo hi, labels(lab) type(t) logscale `tick_opts' ///
        favors("Shorter" "Longer", below) name(v160_t3b, replace)
    assert strpos(`"`r(cmd)'"', "tstyle(tick_label) size(small) color(gs5) placement(sw)") > 0
    assert strpos(`"`r(cmd)'"', " r=1.5 l=0 b=0))") > 0
    eplot tr lo hi, labels(lab) type(t) logscale `tick_opts' ///
        favors("Shorter" "Longer", size(small)) name(v160_t3c, replace)
    assert strpos(`"`r(cmd)'"', `"tstyle(tick_label) size(small) color(gs5) placement(w) margin(r=1.5"') > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**## A null on a tick span end moves the labels to the axis ends
local ++test_count
capture noisily {
    use `v160_base', clear
    eplot tr lo hi, labels(lab) type(t) logscale xlabel(1 1.2 1.4 1.6) ///
        favors("Shorter" "Longer", below) name(v160_t4, replace)
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "xmlabel(") == 0
    assert strpos(`"`cmd'"', `"`"Shorter"', tstyle(tick_label) color(gs5) placement(e))"') > 0
    assert strpos(`"`cmd'"', `"`"Longer"', tstyle(tick_label) color(gs5) placement(w))"') > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**## favors() suboption refusals
* logscale with type() rows, so the suboption is the only possible failure:
* the same call without the bad suboption succeeds.
local ++test_count
capture noisily {
    use `v160_base', clear
    local ok "labels(lab) type(t) logscale"
    * 1.6.1: gap() no longer requires below; it is refused with ends and
    * takes a relative size only.
    eplot tr lo hi, `ok' favors("A" "B", below gap(*5)) name(v160_t5, replace)
    eplot tr lo hi, `ok' favors("A" "B", gap(2)) name(v160_t5b, replace)
    foreach bad in "ends gap(2)" "below gap(wide)" "below gap(3pt)" "size(huge2)" ///
        "color(notacolor)" "color(red blue)" "sideways" {
        capture noisily eplot tr lo hi, `ok' favors("A" "B", `bad')
        assert _rc == 198
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

**# effect(, atnull)

**## The title sits on the null, below the favors row, in the xtitle() size
* Pre-1.6.0 ", atnull" became part of the title text.
local ++test_count
capture noisily {
    use `v160_base', clear
    eplot tr lo hi, labels(lab) type(t) logscale values `tick_opts' ///
        vtitle("TR (95% CI)") effect("Time ratio", atnull) ///
        xtitle(, size(small)) favors("Shorter" "Longer", below arrows) ///
        xscale(extend) name(v160_t6, replace)
    _v160_svgtext, graph(v160_t6) text("1.0")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    local x10 = r(x)
    local ytick = r(y)
    local tsize = r(size)
    _v160_svgtext, graph(v160_t6) text("Longer `=uchar(8594)'")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    local yfav = r(y)
    assert r(n) == 1
    _v160_svgtext, graph(v160_t6) text("Time ratio")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    assert r(n) == 1
    assert abs(r(x) - `x10') < 1
    assert !missing(r(size), `tsize') & reldif(r(size), `tsize') < 1e-6
    assert !missing(`ytick', `yfav', r(y)) & `ytick' < `yfav' & `yfav' < r(y)
    * Even steps: tick labels to favors to title within a quarter.
    local step1 = `yfav' - `ytick'
    local step2 = r(y) - `yfav'
    assert !missing(`step1', `step2') & abs(`step1' - `step2') < 0.25 * `step1'
    _v160_svgtext, graph(v160_t6) text("Time ratio , atnull")
    assert r(n) == 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

**## Linear axis, no values, vertical layout, and estimates and matrix modes
local ++test_count
capture noisily {
    use `v160_base', clear
    gen double d = ln(tr)
    gen double dl = ln(lo)
    gen double du = ln(hi)
    eplot d dl du, labels(lab) type(t) xlabel(-0.2(0.2)0.4) ///
        effect("Log ratio", atnull) name(v160_t7, replace)
    _v160_svgtext, graph(v160_t7) text("0")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    local x0 = r(x)
    _v160_svgtext, graph(v160_t7) text("Log ratio")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    assert r(n) == 1 & abs(r(x) - `x0') < 1
    * Vertical: the title is on the left, level with the null tick.
    eplot tr lo hi, labels(lab) type(t) logscale vertical ///
        xlabel(0.8 1 1.2 1.4 1.6) effect("Time ratio", atnull) ///
        name(v160_t7b, replace)
    assert strpos(`"`r(cmd)'"', "yscale(axis(2) log range(") > 0
    _v160_svgtext, graph(v160_t7b) text("1")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    local y1 = r(y)
    local xt = r(x)
    _v160_svgtext, graph(v160_t7b) text("Time ratio")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    assert !missing(r(x), `xt') & r(n) == 1 & r(x) < `xt'
    * Rotated text: its anchor is level with the tick label's centre.
    assert !missing(r(y), `y1') & abs(r(y) - `y1') < 60
    sysuse auto, clear
    quietly logit foreign mpg weight headroom
    eplot ., drop(_cons) eform values effect("Odds ratio", atnull) ///
        vtitle("OR (95% CI)") name(v160_t7c, replace)
    _v160_svgtext, graph(v160_t7c) text("1")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    local x1 = r(x)
    _v160_svgtext, graph(v160_t7c) text("Odds ratio")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    assert r(n) == 1 & abs(r(x) - `x1') < 1
    matrix R = (0.5, 0.1, 0.9 \ -0.3, -0.6, 0.1)
    matrix rownames R = a b
    eplot, matrix(R) values effect("Diff", atnull) vtitle("D (95% CI)") ///
        name(v160_t7d, replace)
    _v160_svgtext, graph(v160_t7d) text("0")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    local x0 = r(x)
    _v160_svgtext, graph(v160_t7d) text("Diff")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    assert r(n) == 1 & abs(r(x) - `x0') < 1
    * graph combine keeps the second axis.
    graph combine v160_t7c v160_t7d, name(v160_t7e, replace)
    _v160_svgtext, graph(v160_t7e) text("Odds ratio")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    assert r(n) == 1
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}

**## Fallbacks and refusals: off-axis null, xtitle() text, default label
local ++test_count
capture noisily {
    use `v160_base', clear
    gen double h = tr + 1
    gen double hl = lo + 1
    gen double hu = hi + 1
    eplot h hl hu, labels(lab) type(t) logscale nonull ///
        effect("TR", atnull) name(v160_t8, replace)
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "axis(2)") == 0
    assert strpos(`"`cmd'"', `"xtitle(`"TR"')"') > 0
    capture noisily eplot tr lo hi, labels(lab) type(t) logscale ///
        effect("TR", atnull) xtitle("Other")
    assert _rc == 198
    eplot tr lo hi, labels(lab) type(t) logscale effect(, atnull) ///
        name(v160_t8b, replace)
    assert strpos(`"`r(cmd)'"', `"xlabel(1 `"Estimate (95% CI)"', axis(2)"') > 0
    * An unquoted label with a comma is still one title.
    eplot tr lo hi, labels(lab) type(t) logscale effect(Ratio, adjusted) ///
        name(v160_t8c, replace)
    assert strpos(`"`r(cmd)'"', `"xtitle(`"Ratio, adjusted"')"') > 0
    assert strpos(`"`r(cmd)'"', "axis(2)") == 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}

**## atnull through frame(), multi-model, nonull, and xtitle() color
local ++test_count
capture noisily {
    use `v160_base', clear
    capture frame drop v160_fr
    frame put lab t tr lo hi, into(v160_fr)
    frame v160_fr: rename (tr lo hi) (estimate ll ul)
    eplot, frame(v160_fr) labels(lab) type(t) logscale ///
        xlabel(0.8 1 1.2 1.4 1.6, format(%3.1f)) ///
        effect("Time ratio", atnull) xtitle(, color(red)) ///
        name(v160_t10, replace)
    _v160_svgtext, graph(v160_t10) text("1.0")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    local x10 = r(x)
    _v160_svgtext, graph(v160_t10) text("Time ratio")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    assert r(n) == 1 & abs(r(x) - `x10') < 1
    assert upper("`r(fill)'") == "#FF0000"
    frame drop v160_fr
    * nonull hides the line but the title still sits on the null value.
    eplot tr lo hi, labels(lab) type(t) logscale nonull ///
        xlabel(0.8 1 1.2 1.4 1.6, format(%3.1f)) ///
        effect("Time ratio", atnull) name(v160_t10b, replace)
    assert strpos(`"`r(cmd)'"', "xline(1,") == 0
    _v160_svgtext, graph(v160_t10b) text("Time ratio")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    assert abs(r(x) - `x10') < 1
    * Multi-model estimates.
    sysuse auto, clear
    quietly logit foreign mpg weight
    estimates store v160_m1
    quietly logit foreign mpg weight headroom
    estimates store v160_m2
    eplot v160_m1 v160_m2, eform drop(_cons) effect("Odds ratio", atnull) ///
        name(v160_t10c, replace)
    _v160_svgtext, graph(v160_t10c) text("1")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    local x1 = r(x)
    _v160_svgtext, graph(v160_t10c) text("Odds ratio")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    assert r(n) == 1 & abs(r(x) - `x1') < 1
    estimates drop v160_m1 v160_m2
    * Abbreviated xscale() line styling reaches the drawn axis line.
    use `v160_base', clear
    eplot tr lo hi, labels(lab) type(t) logscale values ///
        xscale(lc(red) lw(thick) lp(dash)) name(v160_t10d, replace)
    assert regexm(`"`r(cmd)'"', "\(pci [^)]*lstyle\(axisline\) lcolor\(red\) lwidth\(thick\) lpattern\(dash\)\)")
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 10"
}

**# Axis line with a values column

**## The axis line stops at the end of the effect range, not the column
* Pre-1.6.0 it ran on under the values column (to the plot edge with extend).
local ++test_count
capture noisily {
    use `v160_base', clear
    eplot tr lo hi, labels(lab) type(t) logscale values `tick_opts' ///
        xscale(extend) name(v160_t9, replace)
    _v160_svgtext, graph(v160_t9) text("0.8")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    local x08 = r(x)
    _v160_svgtext, graph(v160_t9) text("1.6")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    local x16 = r(x)
    _v160_axisline, graph(v160_t9)
    assert !missing(r(x1), r(x2))
    assert abs(r(x1) - `x08') < 1
    assert abs(r(x2) - `x16') < 1
    * Line styling passed in xscale() is forwarded to the drawn line.
    eplot tr lo hi, labels(lab) type(t) logscale values ///
        xscale(lcolor(red) lwidth(thick)) name(v160_t9b, replace)
    assert regexm(`"`r(cmd)'"', "\(pci [^)]*lstyle\(axisline\) lcolor\(red\) lwidth\(thick\)\)")
    * noline, a user plotregion(), or no values column keeps twoway's line.
    eplot tr lo hi, labels(lab) type(t) logscale values xscale(noline) ///
        name(v160_t9c, replace)
    assert strpos(`"`r(cmd)'"', "(pci ") == 0
    eplot tr lo hi, labels(lab) type(t) logscale values ///
        plotregion(margin(small)) name(v160_t9d, replace)
    assert strpos(`"`r(cmd)'"', "(pci ") == 0
    eplot tr lo hi, labels(lab) type(t) logscale name(v160_t9e, replace)
    assert strpos(`"`r(cmd)'"', "(pci ") == 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}

**# Design review items folded into 1.6.0

**## eform with rescale() plots exp(k*b), in every mode and the PI path
* Pre-1.6.0 the ratio was multiplied: rescale(10) gave 10*exp(b).
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly logit foreign mpg weight
    local b = _b[mpg]
    quietly logit foreign mpg weight, or
    matrix S = r(table)
    quietly logit foreign mpg weight
    eplot ., noconstant eform rescale(10) nodraw
    matrix T = r(table)
    assert !missing(T[1,1], exp(10 * `b')) & reldif(T[1,1], exp(10 * `b')) < 1e-10
    eplot ., noconstant eform rescale(-1) nodraw
    matrix T = r(table)
    assert !missing(T[1,1], exp(-`b')) & reldif(T[1,1], exp(-`b')) < 1e-10
    assert !missing(T[1,2], T[1,3]) & T[1,2] <= T[1,3]
    clear
    input str4 lab double(b lo hi plo phi)
    "a" 0.1 0.05 0.15 0.0 0.2
    end
    eplot b lo hi, labels(lab) eform rescale(10) pi(plo phi) nodraw
    * The PI reaches exp(10*0.2) = 7.39; pre-1.6.0 it was 10*exp(0.2) = 12.2.
    assert regexm(`"`r(cmd)'"', "xscale\(range\([^ ]+ ([^)]+)\)\)")
    assert !missing(real(regexs(1))) & real(regexs(1)) >= exp(2) & real(regexs(1)) < 10
    matrix T = r(table)
    assert !missing(T[1,1], exp(1)) & reldif(T[1,1], exp(1)) < 1e-10
    assert !missing(T[1,3], exp(1.5)) & reldif(T[1,3], exp(1.5)) < 1e-10
    matrix M = (0.1, 0.05, 0.15)
    matrix rownames M = a
    eplot, matrix(M) eform rescale(10) nodraw
    matrix T = r(table)
    assert !missing(T[1,1], exp(1)) & reldif(T[1,1], exp(1)) < 1e-10
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 11"
}

**## sort orders effects within header, pooled, and groups() blocks
local ++test_count
capture noisily {
    clear
    input str8 lab byte t double(es lo hi)
    "Men"     0 .   .   .
    "M1"      1 1.5 1.2 1.8
    "M2"      1 0.8 0.6 1.0
    "Women"   0 .   .   .
    "W1"      1 1.1 0.9 1.3
    "W2"      1 0.5 0.3 0.7
    end
    eplot es lo hi, labels(lab) type(t) sort nodraw
    local rows : rownames r(table)
    assert "`rows'" == "M2 M1 W2 W1"
    sysuse auto, clear
    quietly regress price mpg weight length turn foreign rep78
    eplot ., drop(_cons) sort ///
        groups(mpg weight length turn = "Vehicle" foreign rep78 = "Other") nodraw
    * Each group is sorted within its own rows (turn length mpg weight;
    * rep78 foreign), and each header sits above its group.
    matrix T = r(table)
    assert rowsof(T) == 6
    assert !missing(T[1,1], _b[turn], T[2,1], _b[length])
    assert reldif(T[1,1], _b[turn]) < 1e-12 & reldif(T[2,1], _b[length]) < 1e-12
    assert !missing(T[3,1], _b[mpg], T[4,1], _b[weight])
    assert reldif(T[3,1], _b[mpg]) < 1e-12 & reldif(T[4,1], _b[weight]) < 1e-12
    assert !missing(T[5,1], _b[rep78], T[6,1], _b[foreign])
    assert reldif(T[5,1], _b[rep78]) < 1e-12 & reldif(T[6,1], _b[foreign]) < 1e-12
    local c `"`r(cmd)'"'
    local bq = char(96)
    local dq = char(34)
    assert strpos(`"`c'"', "ylabel( 1 `bq'`dq'Vehicle`dq'") > 0
    assert strpos(`"`c'"', " 6 `bq'`dq'Other`dq'") > 0
    * Without structure the sort is global (ascending estimates).
    eplot ., drop(_cons) sort nodraw
    matrix T = r(table)
    forvalues i = 2/6 {
        assert !missing(T[`i',1], T[`i'-1,1]) & T[`i',1] >= T[`i'-1,1]
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 12"
}

**## The null line is not emitted off the axis; favors() reaches the null
local ++test_count
capture noisily {
    clear
    input str4 lab double(es lo hi)
    "a" 0.9 0.6 1.28
    "b" 1.1 0.8 1.2
    end
    eplot es lo hi, labels(lab) nodraw
    assert strpos(`"`r(cmd)'"', "xline(0,") == 0
    eplot es lo hi, labels(lab) favors("L" "R") nodraw
    local c `"`r(cmd)'"'
    assert strpos(`"`c'"', "xline(0,") > 0
    assert regexm(`"`c'"', "xscale\(range\(([^ ]+) ")
    assert real(regexs(1)) < 0
    assert strpos(`"`c'"', "placement(e))") == 0
    * noci ranges on the point estimates.
    clear
    input str4 lab double(es lo hi)
    "a" 0.1 -5 5
    "b" 0.2 -5 5
    end
    eplot es lo hi, labels(lab) noci nonull nodraw
    assert regexm(`"`r(cmd)'"', "xscale\(range\(([^ ]+) ([^)]+)\)\)")
    assert real(regexs(1)) > -1 & real(regexs(2)) < 1
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 13"
}

**## A user plotregion() keeps the values-column margin
local ++test_count
capture noisily {
    use `v160_base', clear
    eplot tr lo hi, labels(lab) type(t) logscale values ///
        plotregion(lcolor(black)) name(v160_t14, replace)
    assert regexm(`"`r(cmd)'"', "plotregion\(margin\(l\+2 r\+[0-9.]+ t\+2 b=0\) lcolor\(black\)")
    eplot tr lo hi, labels(lab) type(t) logscale values ///
        plotregion(margin(l=0 t=1)) nodraw
    assert regexm(`"`r(cmd)'"', "plotregion\(margin\(l=0 t=1 r\+[0-9.]+\)")
    assert strpos(`"`r(cmd)'"', "(pci ") == 0
    * The values text is inside the graph: its x is left of the right edge.
    _v160_svgtext, graph(v160_t14) text("1.13 (1.05, 1.21)")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 14"
}

**## Repeated xline() is validated, ranged, and styled per occurrence
local ++test_count
capture noisily {
    use `v160_base', clear
    eplot tr lo hi, labels(lab) type(t) logscale ///
        xline(0.5, lcolor(red)) xline(2, lcolor(blue)) nodraw
    local c `"`r(cmd)'"'
    assert strpos(`"`c'"', "xline(.5,  lcolor(red))") > 0
    assert strpos(`"`c'"', "xline(2,  lcolor(blue))") > 0
    assert regexm(`"`c'"', "xscale\(log range\(([^ ]+) ([^)]+)\)\)")
    assert real(regexs(1)) <= 0.5 & real(regexs(2)) >= 2
    capture noisily eplot tr lo hi, labels(lab) type(t) logscale ///
        xline(0.9) xline(-1) nodraw
    assert _rc == 198
    * null(#, line_options) restyles the null line.
    eplot tr lo hi, labels(lab) type(t) logscale ///
        null(1, lcolor(black) lpattern(solid)) nodraw
    assert strpos(`"`r(cmd)'"', "xline(1, lcolor(black) lpattern(solid))") > 0
    assert strpos(`"`r(cmd)'"', "xline(1, lcolor(gs8)") == 0
    capture noisily eplot tr lo hi, labels(lab) null(abc) nodraw
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 15"
}

**## baselevels shows reference rows; r(k) and r(table) exclude them
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly logit foreign mpg i.rep78
    eplot ., eform drop(_cons) nodraw
    local k0 = r(k)
    local n0 = r(N)
    eplot ., eform drop(_cons) baselevels values name(v160_t16, replace)
    assert r(k) == `k0'
    assert r(N) == `n0' + 1
    matrix T = r(table)
    assert rowsof(T) == `k0'
    _v160_svgtext, graph(v160_t16) text("1.00 (reference)")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) == 1
    eplot ., eform drop(_cons) baselevels values vreference("ref") ///
        name(v160_t16b, replace)
    _v160_svgtext, graph(v160_t16b) text("ref")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) == 1
    estimates store v160_b1
    quietly logit foreign mpg
    estimates store v160_b2
    capture noisily eplot v160_b1 v160_b2, baselevels nodraw
    assert _rc == 198
    estimates drop v160_b1 v160_b2
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 16"
}

**## diamondcolor(), offset() scaling, level() labelling, order() typos
local ++test_count
capture noisily {
    clear
    input str6 lab byte t double(es lo hi)
    "S1"   1 0.9 0.6 1.3
    "S2"   1 1.1 0.8 1.5
    "Pool" 5 0.9 0.75 1.08
    end
    eplot es lo hi, labels(lab) type(t) logscale diamondcolor(navy) nodraw
    assert strpos(`"`r(cmd)'"', "lcolor(black)") == 0
    assert strpos(`"`r(cmd)'"', "== 5, lcolor(navy)") > 0
    capture noisily eplot es lo hi, labels(lab) type(t) diamondcolor(a b c)
    assert _rc == 198
    eplot es lo hi, labels(lab) type(t) logscale level(90) nodraw
    assert strpos(`"`r(cmd)'"', `"xtitle(`"Estimate (90% CI)"')"') > 0
    capture noisily eplot es lo hi, labels(lab) order(S2 S9) nodraw
    assert _rc == 198
    sysuse auto, clear
    forvalues i = 1/7 {
        quietly regress price mpg weight
        estimates store v160_o`i'
    }
    eplot v160_o1 v160_o2 v160_o3 v160_o4 v160_o5 v160_o6 v160_o7, ///
        drop(_cons) export(v160_fo, replace) nodraw
    frame v160_fo {
        quietly summarize pos if label == label[1]
        assert !missing(r(max), r(min)) & r(max) - r(min) <= 0.6 + 1e-9
        assert r(max) - r(min) >= 0.6 - 1e-9
    }
    frame drop v160_fo
    estimates drop v160_o*
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 17"
}

**## export() round-trips through frame(); name clashes are refused
local ++test_count
capture noisily {
    use `v160_base', clear
    capture frame drop v160_ex
    eplot tr lo hi, labels(lab) type(t) logscale values export(v160_ex) nodraw
    matrix A = r(table)
    frame v160_ex {
        confirm numeric variable estimate ll ul type pos weight
        confirm string variable label values
    }
    capture noisily eplot tr lo hi, labels(lab) type(t) export(v160_ex) nodraw
    assert _rc == 110
    frame v160_ex {
        quietly count if type == 1
        assert r(N) == rowsof(A)
        local _r 0
        forvalues i = 1/`=_N' {
            if type[`i'] != 1 continue
            local ++_r
            assert !missing(estimate[`i'], A[`_r', 1], ll[`i'], A[`_r', 2])
            assert reldif(estimate[`i'], A[`_r', 1]) < 1e-12
            assert reldif(ll[`i'], A[`_r', 2]) < 1e-12
            if `i' > 1 assert pos[`i'] > pos[`i' - 1]
        }
        assert values[2] == "1.13 (1.05, 1.21)"
        assert type[1] == 0 & label[1] == "Group A"
    }
    eplot, frame(v160_ex) logscale nodraw
    matrix B = r(table)
    assert mreldif(A, B) < 1e-12
    capture noisily eplot, frame(v160_ex) export(v160_ex, replace) nodraw
    assert _rc == 198
    frame drop v160_ex
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 18"
}

**## Narrow log spread: default ticks symmetric about the null
local ++test_count
capture noisily {
    clear
    input str4 lab double(es lo hi)
    "a" 1.0  0.85 1.19
    "b" 1.05 0.9  1.15
    end
    eplot es lo hi, labels(lab) logscale nodraw
    local c `"`r(cmd)'"'
    assert regexm(`"`c'"', "xlabel\( ([.0-9]+) [^ ]+ ([.0-9]+) [^ ]+ 1 ")
    local t1 = real(regexs(1))
    local t2 = real(regexs(2))
    * Ticks below 1 mirror ticks above it in log space.
    assert regexm(`"`c'"', " 1 " + char(34) + "1" + char(34) + " ([.0-9]+) [^ ]+ ([.0-9]+) ")
    local u1 = real(regexs(1))
    local u2 = real(regexs(2))
    assert !missing(`t1', `t2', `u1', `u2')
    assert !missing(`t2' * `u1') & reldif(`t2' * `u1', 1) < 1e-9
    assert !missing(`t1' * `u2') & reldif(`t1' * `u2', 1) < 1e-9
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 19"
}

**## hetrow, xline() label placement and styling, default title with values
local ++test_count
capture noisily {
    clear
    input str6 lab byte t double(es lo hi)
    "S1"   1 0.9 0.6 1.3
    "S2"   1 1.1 0.8 1.5
    "Pool" 5 0.9 0.75 1.08
    end
    eplot es lo hi, labels(lab) type(t) logscale i2(42%) tau2(0.02) hetrow ///
        name(v160_t20, replace)
    local c `"`r(cmd)'"'
    assert strpos(`"`c'"', "I`=uchar(178)' = 42%, `=uchar(964)'`=uchar(178)' = 0.02") > 0
    assert strpos(`"`c'"', "I-squared") == 0
    assert r(N) == 4
    capture noisily eplot es lo hi, labels(lab) type(t) hetrow nodraw
    assert _rc == 198
    * A line in the right half labels to its left; label() suboptions apply.
    eplot es lo hi, labels(lab) type(t) logscale ///
        xline(1.4, label("Right", size(small) color(black))) ///
        xline(0.65, label("Left, low")) nodraw
    local c `"`r(cmd)'"'
    assert strpos(`"`c'"', `"`"Right"', size(small) color(black) placement(w) margin(r+1))"') > 0
    assert strpos(`"`c'"', `"`"Left, low"', size(vsmall) color(gs5) placement(e) margin(l+1))"') > 0
    capture noisily eplot es lo hi, labels(lab) type(t) ///
        xline(1.4, label("R", size(huge2))) nodraw
    assert _rc == 198
    * values: the default axis title drops the CI suffix the header carries.
    eplot es lo hi, labels(lab) type(t) logscale values nodraw
    assert strpos(`"`r(cmd)'"', `"xtitle(`"Estimate"', size(medsmall))"') > 0
    assert strpos(`"`r(cmd)'"', "{bf:Estimate (95% CI)}") > 0
    * A user effect() is never shortened.
    eplot es lo hi, labels(lab) type(t) logscale values ///
        effect("Ratio (95% CI)") nodraw
    assert strpos(`"`r(cmd)'"', `"xtitle(`"Ratio (95% CI)"', size(medsmall))"') > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 20"
}

**# Second review: fixes

**## Frame mode: export() may not overwrite the caller's frame
local ++test_count
capture noisily {
    clear
    input str4 label double(estimate ll ul)
    "a" 1 0.5 1.5
    "b" 2 1.5 2.5
    end
    capture frame drop v160_res
    frame put label estimate ll ul, into(v160_res)
    sysuse auto, clear
    local here = c(frame)
    capture noisily eplot, frame(v160_res) export(`here', replace) nodraw
    assert _rc == 198
    quietly count
    assert r(N) == 74
    capture noisily eplot, frame(v160_res) export(v160_res, replace) nodraw
    assert _rc == 198
    frame drop v160_res
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 21"
}

**## values: xscale() line styling does not bring back the full-width axis
local ++test_count
capture noisily {
    use `v160_base', clear
    eplot tr lo hi, labels(lab) type(t) logscale values `tick_opts' ///
        xscale(lcolor(red) lwidth(thick)) name(v160_t22, replace)
    assert regexm(`"`r(cmd)'"', "lwidth\(thick\)\) xscale\(noline\)")
    _v160_svgtext, graph(v160_t22) text("0.8")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    local x08 = r(x)
    _v160_svgtext, graph(v160_t22) text("1.6")
    assert !missing(r(n), r(x), r(y), r(size)) & r(n) >= 1
    local x16 = r(x)
    _v160_axisline, graph(v160_t22)
    assert !missing(r(x1), r(x2))
    assert abs(r(x1) - `x08') < 1 & abs(r(x2) - `x16') < 1
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 22"
}

**## diamondcolor() accepts quoted RGB triplets
local ++test_count
capture noisily {
    clear
    input str6 lab byte t double(es lo hi)
    "S1"   1 0.9 0.6 1.3
    "Sub"  3 0.9 0.7 1.2
    "Pool" 5 0.9 0.75 1.08
    end
    eplot es lo hi, labels(lab) type(t) logscale diamondcolor("255 0 0") nodraw
    assert strpos(`"`r(cmd)'"', `"== 5, lcolor("255 0 0")"') > 0
    eplot es lo hi, labels(lab) type(t) logscale ///
        diamondcolor("255 0 0" blue) nodraw
    assert strpos(`"`r(cmd)'"', `"== 3, lcolor(blue)"') > 0
    eplot es lo hi, labels(lab) type(t) logscale ///
        diamondcolor(red "0 0 255") name(v160_t23, replace)
    assert strpos(`"`r(cmd)'"', `"== 3, lcolor("0 0 255")"') > 0
    capture frame drop v160_dc
    frame put lab t es lo hi, into(v160_dc)
    frame v160_dc: rename (es lo hi) (estimate ll ul)
    eplot, frame(v160_dc) labels(lab) type(t) logscale ///
        diamondcolor("255 0 0") nodraw
    frame drop v160_dc
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 23"
}

**## Data mode: the default title says 95% whatever c(level) is
local ++test_count
capture noisily {
    use `v160_base', clear
    local oldlevel = c(level)
    set level 90
    eplot tr lo hi, labels(lab) type(t) logscale nodraw
    local c `"`r(cmd)'"'
    set level `oldlevel'
    assert strpos(`"`c'"', "Estimate (95% CI)") > 0
    capture noisily eplot tr lo hi, labels(lab) level(abc) nodraw
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 24"
}

**## sort with baselevels keeps reference rows in estimate order at the null
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price i.rep78 i.foreign mpg weight
    eplot ., drop(_cons) baselevels sort export(v160_bs, replace) nodraw
    frame v160_bs {
        gen double key = cond(type == 2, 0, estimate)
        assert !missing(key)
        forvalues i = 2/`=_N' {
            assert key[`i'] >= key[`i' - 1]
        }
        quietly count if type == 2
        assert r(N) == 2
    }
    frame drop v160_bs
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 25"
}

**## Abbreviated repeats of xline() are collected; repeated labels work
local ++test_count
capture noisily {
    use `v160_base', clear
    eplot tr lo hi, labels(lab) type(t) logscale xline(0.9) xli(1.8) nodraw
    assert regexm(`"`r(cmd)'"', "xscale\(log range\([^ ]+ ([^)]+)\)\)")
    assert real(regexs(1)) >= 1.8
    assert strpos(`"`r(cmd)'"', "xli(") == 0
    capture noisily eplot tr lo hi, labels(lab) type(t) logscale ///
        xline(0.9) xli(-1) nodraw
    assert _rc == 198
    eplot tr lo hi, labels(lab) type(t) logscale ///
        xline(0.9, label("Low")) xline(1.3, lcolor(red) label("High")) nodraw
    local c `"`r(cmd)'"'
    assert strpos(`"`c'"', `"`"Low"', size(vsmall) color(gs5) placement(e)"') > 0
    assert strpos(`"`c'"', `"`"High"', size(vsmall) color(gs5) placement(w)"') > 0
    assert strpos(`"`c'"', "xline(1.3, lcolor(red))") > 0
    * The null line is emitted once.
    assert (strlen(`"`c'"') - strlen(subinstr(`"`c'"', "xline(1, lcolor(gs8)", "", .))) ///
        == strlen("xline(1, lcolor(gs8)")
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 26"
}

**## Ineffective combinations: null() styling with nonull, bare vreference()
local ++test_count
capture noisily {
    use `v160_base', clear
    tempfile v160_log27
    log using `v160_log27', text name(v160_l27) replace
    eplot tr lo hi, labels(lab) type(t) logscale null(1, lcolor(red)) nonull nodraw
    log close v160_l27
    tempname fh
    local hits 0
    file open `fh' using `v160_log27', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "no effect with nonull") local ++hits
        file read `fh' line
    }
    file close `fh'
    assert `hits' == 1
    sysuse auto, clear
    quietly logit foreign mpg i.rep78
    capture noisily eplot ., eform vreference("ref") nodraw
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 27"
}

capture graph drop _all
capture estimates drop _all
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
_eplot_qa_result test_eplot_v160, tests(`test_count') pass(`pass_count') fail(`fail_count') skip(0)

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    capture log close
    exit 1
}
capture log close
