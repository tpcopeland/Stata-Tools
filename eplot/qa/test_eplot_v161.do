*! test_eplot_v161.do - Regression tests for eplot 1.6.1
*! Covers favors() labels anchored at the null: the left label's right edge
*! and the right label's left edge sit gap() from the null whatever the text
*! length, the tick span (0.8-1.6 and 0.1-5), the axis (log and linear), or
*! graph combine; below hangs them under the tick labels in the scheme's
*! axis metrics (s2color and economist) with the title, centred or atnull,
*! kept below them; unboxed inside rows; the estimates and matrix modes; the
*! bottom plot-region margin; the changed gap() refusals; the inside-row
*! fallback for axes that cannot be measured (rotated or multi-line tick
*! labels, absolute-unit sizes); and the room kept under xtitle("").
*! Positions are read back from SVG exports.  SVG text is centred on its x,
*! so a label's half-width comes from a calibration graph of the same size
*! drawing the same text at one point with placement(c) and placement(e).

clear all
set varabbrev off
set graphics off
version 16.0

capture log close _all
log using "test_eplot_v161.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

* Reads one drawn text element back from an SVG export: count, size, x, y.
capture program drop _v161_svgtext
program define _v161_svgtext, rclass
    version 16.0
    syntax , Graph(name) Text(string asis)
    gettoken text : text
    tempfile svg
    * Dropping the current graph (the calibration graphs) leaves no window
    * for export, so the graph is displayed first.
    quietly graph display `graph'
    quietly graph export "`svg'", name(`graph') as(svg) replace
    tempname fh
    local n 0
    local size .
    local x .
    local y .
    file open `fh' using "`svg'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `">`text'</text>"') {
            local ++n
            if `n' == 1 {
                if regexm(`"`macval(line)'"', "font-size:([0-9.]+)px") local size = real(regexs(1))
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
end

* Half the drawn width of a text, in SVG units, at a given text size on a
* graph of the given dimensions.
capture program drop _v161_halfwidth
program define _v161_halfwidth, rclass
    version 16.0
    syntax , Text(string asis) Size(string) XSize(real) YSize(real)
    gettoken text : text
    foreach p in c e {
        quietly twoway scatteri 0.5 0.5, msymbol(none) ///
            text(0.5 0.5 `"`text'"', size(`size') placement(`p') margin(zero)) ///
            xsize(`xsize') ysize(`ysize') name(_v161_cal_`p', replace)
        _v161_svgtext, graph(_v161_cal_`p') text(`"`text'"')
        local x`p' = r(x)
        local s`p' = r(size)
    }
    capture graph drop _v161_cal_c _v161_cal_e
    return scalar half = `xe' - `xc'
    return scalar size = `sc'
end

* Measures the two favors() gaps from the null in one graph.  The null is
* the x of its tick label; pxunit is SVG units per relative size unit.
capture program drop _v161_gaps
program define _v161_gaps, rclass
    version 16.0
    syntax , Graph(name) Null(string) Left(string asis) Right(string asis) ///
        Size(string) Sizeval(real) XSize(real) YSize(real) [Cal(real 1)]
    gettoken left : left
    gettoken right : right
    _v161_svgtext, graph(`graph') text("`null'")
    assert !missing(r(n), r(x), r(y)) & r(n) >= 1
    local xn = r(x)
    local yt = r(y)
    local fs = r(size)
    _v161_svgtext, graph(`graph') text(`"`left'"')
    assert r(n) == 1 & !missing(r(x), r(y), r(size))
    local xl = r(x)
    local yl = r(y)
    local fl = r(size)
    _v161_svgtext, graph(`graph') text(`"`right'"')
    assert r(n) == 1 & !missing(r(x), r(y), r(size))
    local xr = r(x)
    local yr = r(y)
    _v161_halfwidth, text(`"`left'"') size(`size') xsize(`xsize') ysize(`ysize')
    local hl = r(half)
    local cs = r(size)
    _v161_halfwidth, text(`"`right'"') size(`size') xsize(`xsize') ysize(`ysize')
    local hr = r(half)
    * cal() rescales the calibration when the graph is shrunk (combine).
    local k = `fl' / `cs'
    if `cal' == 1 assert reldif(`fl', `cs') < 1e-4
    return scalar gapl = `xn' - (`xl' + `hl' * `k')
    return scalar gapr = (`xr' - `hr' * `k') - `xn'
    return scalar unit = `fl' / `sizeval'
    return scalar ytick = `yt'
    return scalar yfav = `yl'
    return scalar yfavr = `yr'
    return scalar xnull = `xn'
    return scalar favsize = `fl'
end

* The reported figure: 11 rows, intervals around 0.8-1.5 under ticks 0.8-1.6.
clear
set seed 20261010
set obs 11
gen str20 lab = "Row " + string(_n)
gen double tr = exp(rnormal(0.08, 0.1))
gen double lo = tr * 0.88
gen double hi = tr * 1.14
tempfile v161_base
quietly save `v161_base'
local larr = uchar(8592)
local rarr = uchar(8594)
local dims "xsize(6.5) ysize(5.2)"
local ticks "xlabel(0.8 1 1.2 1.4 1.6, format(%3.1f) labsize(small))"
* small is 2.777 relative units; the default gap is 1.5 units.
local small 2.777

**# below: anchored at the null

**## Figure 2 panel B: equal gaps from the null, title on the null below
* Pre-1.6.1 "<- Shorter depletion" was centred on 0.8-1.0 and ran over the
* null and the 1.0 tick label.
local ++test_count
capture noisily {
    use `v161_base', clear
    * xtitle(, size(small)) matches the title to the rows above it, so the
    * baseline steps are equal.
    eplot tr lo hi, labels(lab) logscale values `ticks' ///
        effect("Time ratio", atnull) xtitle(, size(small)) ///
        favors("Shorter depletion" "Longer depletion", below arrows color(gs4)) ///
        `dims' name(v161_t1, replace)
    _v161_gaps, graph(v161_t1) null("1.0") ///
        left("`larr' Shorter depletion") right("Longer depletion `rarr'") ///
        size(small) sizeval(`small') xsize(6.5) ysize(5.2)
    local u = r(unit)
    assert !missing(r(gapl), r(gapr)) & r(gapl) > 0 & r(gapr) > 0
    assert abs(r(gapl) - 1.5 * `u') < 0.1 * 1.5 * `u'
    assert abs(r(gapr) - 1.5 * `u') < 0.1 * 1.5 * `u'
    assert abs(r(gapl) - r(gapr)) < 0.05 * 1.5 * `u'
    local ytick = r(ytick)
    local yfav = r(yfav)
    local xnull = r(xnull)
    assert r(yfav) == r(yfavr)
    * One tick-label row plus the 1-unit gap below the tick labels.
    local step = (`yfav' - `ytick') / `u'
    assert abs(`step' - (1 + `small')) < 0.1
    _v161_svgtext, graph(v161_t1) text("Time ratio")
    * The values header also reads "Time ratio"; the title is the lower one.
    assert !missing(r(n)) & r(n) >= 1
    tempfile svg
    quietly graph display v161_t1
    quietly graph export "`svg'", name(v161_t1) as(svg) replace
    tempname fh
    local ytitle -1
    local xtitle .
    file open `fh' using "`svg'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', ">Time ratio</text>") {
            if regexm(`"`macval(line)'"', `" y="(-?[0-9.]+)""') {
                if real(regexs(1)) > `ytitle' {
                    local ytitle = real(regexs(1))
                    if regexm(`"`macval(line)'"', `"<text x="(-?[0-9.]+)""') local xtitle = real(regexs(1))
                }
            }
        }
        file read `fh' line
    }
    file close `fh'
    assert abs(`xtitle' - `xnull') < 1
    * Even steps: tick labels to favors to title.
    local s1 = `yfav' - `ytick'
    local s2 = `ytitle' - `yfav'
    assert `s2' > 0 & abs(`s1' - `s2') < 0.1 * `s1'
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**## Fixture ticks 0.1-5, long and short labels: the same gap
local ++test_count
capture noisily {
    use `v161_base', clear
    local wide "xlabel(0.1 0.2 0.5 1 2 5, labsize(small))"
    eplot tr lo hi, labels(lab) logscale `wide' effect("Time ratio") ///
        favors("Favors treatment group" "Favors control group", below) ///
        `dims' name(v161_t2, replace)
    _v161_gaps, graph(v161_t2) null("1") left("Favors treatment group") ///
        right("Favors control group") size(small) sizeval(`small') ///
        xsize(6.5) ysize(5.2)
    local u = r(unit)
    assert abs(r(gapl) - 1.5 * `u') < 0.1 * 1.5 * `u'
    assert abs(r(gapr) - 1.5 * `u') < 0.1 * 1.5 * `u'
    local yfav = r(yfav)
    * The centred title is drawn, below the favors row (pre-fix it vanished).
    _v161_svgtext, graph(v161_t2) text("Time ratio")
    assert !missing(r(y), r(size), `yfav') & r(n) == 1 & r(y) > `yfav' + r(size) * 0.5
    eplot tr lo hi, labels(lab) logscale `wide' ///
        favors("Shorter" "Longer", below) `dims' name(v161_t2b, replace)
    _v161_gaps, graph(v161_t2b) null("1") left("Shorter") right("Longer") ///
        size(small) sizeval(`small') xsize(6.5) ysize(5.2)
    assert abs(r(gapl) - 1.5 * r(unit)) < 0.1 * 1.5 * r(unit)
    assert abs(r(gapr) - 1.5 * r(unit)) < 0.1 * 1.5 * r(unit)
    * gap() moves both labels.
    eplot tr lo hi, labels(lab) logscale `wide' ///
        favors("Shorter" "Longer", below gap(4)) `dims' name(v161_t2c, replace)
    _v161_gaps, graph(v161_t2c) null("1") left("Shorter") right("Longer") ///
        size(small) sizeval(`small') xsize(6.5) ysize(5.2)
    assert abs(r(gapl) - 4 * r(unit)) < 0.1 * 4 * r(unit)
    assert abs(r(gapr) - 4 * r(unit)) < 0.1 * 4 * r(unit)
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**## Unchanged in graph combine
local ++test_count
capture noisily {
    use `v161_base', clear
    eplot tr lo hi, labels(lab) logscale values `ticks' ///
        effect("Time ratio", atnull) ///
        favors("Shorter depletion" "Longer depletion", below arrows) ///
        `dims' name(v161_t3a, replace)
    quietly twoway scatteri 0 0 1 1, name(v161_t3b, replace)
    graph combine v161_t3a v161_t3b, rows(1) xsize(13) ysize(5.2) ///
        name(v161_t3, replace)
    _v161_gaps, graph(v161_t3) null("1.0") ///
        left("`larr' Shorter depletion") right("Longer depletion `rarr'") ///
        size(small) sizeval(`small') xsize(6.5) ysize(5.2) cal(0)
    local u = r(unit)
    assert !missing(r(gapl), r(gapr)) & r(gapl) > 0 & r(gapr) > 0
    assert abs(r(gapl) - 1.5 * `u') < 0.12 * 1.5 * `u'
    assert abs(r(gapr) - 1.5 * `u') < 0.12 * 1.5 * `u'
    assert !missing(r(yfav), r(ytick)) & r(yfav) > r(ytick)
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**## Scheme metrics: economist (inside ticks, medium labels) and size()
local ++test_count
capture noisily {
    use `v161_base', clear
    * economist ticks point inward, so only the tick gap and label height
    * separate the axis from the favors row.
    eplot tr lo hi, labels(lab) logscale xlabel(0.8 1 1.2 1.4 1.6, format(%3.1f)) ///
        favors("Shorter" "Longer", below) scheme(economist) `dims' ///
        name(v161_t4, replace)
    local cmd `"`r(cmd)'"'
    * tickgap half_tiny .6944 + label medium 3.8194 + 1; no tick.
    assert strpos(`"`cmd'"', "margin(t=5.5138 r=1.5 l=0 b=0)") > 0
    _v161_svgtext, graph(v161_t4) text("1.0")
    local yt = r(y)
    local u = r(size) / 3.8194
    _v161_svgtext, graph(v161_t4) text("Shorter")
    local step = (r(y) - `yt') / `u'
    assert abs(`step' - (1 + 3.8194)) < 0.1
    * size() larger than the tick labels: the row clears them by its own
    * height.
    eplot tr lo hi, labels(lab) logscale `ticks' ///
        favors("Shorter" "Longer", below size(large)) `dims' ///
        name(v161_t4b, replace)
    _v161_svgtext, graph(v161_t4b) text("1.0")
    local yt = r(y)
    local u = r(size) / `small'
    _v161_svgtext, graph(v161_t4b) text("Shorter")
    * The larger row's baseline lies past the 1-unit gap and the tick-label
    * row by at least half of its extra height (its ascent), and no further
    * than its whole height.
    local step = (r(y) - `yt') / `u'
    assert `step' > 1 + `small' + 0.5 * (4.8611 - `small')
    assert `step' < 1 + 4.8611
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**## Estimates and matrix modes, linear null 0, and no values column
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight headroom
    eplot ., drop(_cons) favors("Cheaper" "Dearer", below) ///
        xlabel(-1000(500)1000, labsize(small)) `dims' name(v161_t5, replace)
    _v161_gaps, graph(v161_t5) null("0") left("Cheaper") right("Dearer") ///
        size(small) sizeval(`small') xsize(6.5) ysize(5.2)
    assert abs(r(gapl) - 1.5 * r(unit)) < 0.1 * 1.5 * r(unit)
    assert abs(r(gapr) - 1.5 * r(unit)) < 0.1 * 1.5 * r(unit)
    matrix R = (1.2, 0.9, 1.6 \ 0.8, 0.6, 1.05 \ 1.0, 0.7, 1.4)
    matrix colnames R = b ll ul
    matrix rownames R = A B C
    eplot, matrix(R) logscale xlabel(0.5 1 2, labsize(small)) ///
        favors("Treatment better" "Control better", below) `dims' ///
        name(v161_t5b, replace)
    _v161_gaps, graph(v161_t5b) null("1") left("Treatment better") ///
        right("Control better") size(small) sizeval(`small') ///
        xsize(6.5) ysize(5.2)
    assert abs(r(gapl) - 1.5 * r(unit)) < 0.1 * 1.5 * r(unit)
    assert abs(r(gapr) - 1.5 * r(unit)) < 0.1 * 1.5 * r(unit)
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

**# Inside the plot: the labels stop gap() from the null, unboxed
* A white box reaching the null blanked the null line across the row, and
* bmargin() does not move added text, so the row carries no box.

local ++test_count
capture noisily {
    use `v161_base', clear
    gen double d = ln(tr)
    gen double dl = ln(lo)
    gen double du = ln(hi)
    eplot d dl du, labels(lab) xlabel(-0.2(0.2)0.4, labsize(small)) ///
        favors("Favors treatment group" "Longer", size(small)) `dims' ///
        name(v161_t6, replace)
    local cmd `"`r(cmd)'"'
    _v161_gaps, graph(v161_t6) null("0") left("Favors treatment group") ///
        right("Longer") size(small) sizeval(`small') xsize(6.5) ysize(5.2)
    local u = r(unit)
    assert abs(r(gapl) - 1.5 * `u') < 0.1 * 1.5 * `u'
    assert abs(r(gapr) - 1.5 * `u') < 0.1 * 1.5 * `u'
    assert strpos(`"`cmd'"', " box") == 0
    * Inside the plot region, above the tick labels.
    assert !missing(r(yfav), r(ytick)) & r(yfav) < r(ytick)
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

**# Plot region and refusals

**## below runs the axis along the plot-region edge, named margins included
local ++test_count
capture noisily {
    use `v161_base', clear
    eplot tr lo hi, labels(lab) logscale `ticks' favors("A" "B", below) ///
        name(v161_t7, replace)
    assert strpos(`"`r(cmd)'"', "plotregion(margin(b=0)") > 0
    eplot tr lo hi, labels(lab) logscale `ticks' favors("A" "B", below) ///
        plotregion(margin(small) lcolor(red)) name(v161_t7b, replace)
    local cmd `"`r(cmd)'"'
    tempname m
    .`m' = .margin.new, style(small)
    assert strpos(`"`cmd'"', "plotregion(margin(l=`.`m'.left' r=`.`m'.right' t=`.`m'.top' b=`.`m'.bottom' b=0) lcolor(red))") > 0
    * Without below, the plot region is left alone.
    eplot tr lo hi, labels(lab) logscale `ticks' favors("A" "B") ///
        name(v161_t7c, replace)
    assert strpos(`"`r(cmd)'"', "plotregion(") == 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}

**## gap() refusals and acceptance
local ++test_count
capture noisily {
    use `v161_base', clear
    local ok "labels(lab) logscale"
    eplot tr lo hi, `ok' favors("A" "B", gap(0)) name(v161_t8, replace)
    eplot tr lo hi, `ok' favors("A" "B", below gap(*2)) name(v161_t8b, replace)
    assert strpos(`"`r(cmd)'"', " r=3 l=0 b=0))") > 0
    foreach bad in "ends gap(2)" "below gap(3pt)" "gap(-1)" "gap(wide)" {
        capture noisily eplot tr lo hi, `ok' favors("A" "B", `bad')
        assert _rc == 198
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}

**# Review findings

**## Axes below cannot measure fall back to the inside row with a note
* Pre-fix rotated, multi-line, and absolute-unit tick labels were measured as
* one level line in the scheme size, and the hung row overprinted them.
local ++test_count
capture noisily {
    use `v161_base', clear
    local F favors("Shorter" "Longer", below)
    local tk "0.8 1 1.2 1.4 1.6"
    foreach x in "angle(90)" "angle(45)" "labsize(24pt)" "labgap(3pt)" "tlength(0.2in)" {
        tempfile lg
        log using "`lg'", text replace name(v161_fb)
        eplot tr lo hi, labels(lab) logscale xlabel(`tk', `x') `F' ///
            name(v161_t9, replace)
        local cmd `"`r(cmd)'"'
        log close v161_fb
        assert strpos(`"`cmd'"', "placement(sw)") == 0
        assert strpos(`"`cmd'"', `"1 `"Shorter"', tstyle(tick_label)"') > 0
        assert strpos(`"`cmd'"', "placement(w) margin(r=1.5") > 0
        local hits 0
        tempname fh
        file open `fh' using "`lg'", read text
        file read `fh' line
        while r(eof) == 0 {
            if strpos(`"`macval(line)'"', "cannot measure the effect axis") local ++hits
            file read `fh' line
        }
        file close `fh'
        assert `hits' == 1
    }
    eplot tr lo hi, labels(lab) logscale xlabel(0.8 `""0.8" "(low)""' 1 1.6) ///
        `F' name(v161_t9b, replace)
    assert strpos(`"`r(cmd)'"', "placement(sw)") == 0
    eplot tr lo hi, labels(lab) logscale xlabel(`tk') ///
        favors("Shorter" "Longer", below size(10pt)) name(v161_t9c, replace)
    assert strpos(`"`r(cmd)'"', "placement(sw)") == 0
    * Level labels in any spelling are measured.
    foreach x in "angle(0)" "angle(horizontal)" "angle(hor)" {
        eplot tr lo hi, labels(lab) logscale xlabel(`tk', `x') `F' ///
            name(v161_t9d, replace)
        assert strpos(`"`r(cmd)'"', "placement(sw)") > 0
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}

**## A passed-through xtitle("") keeps the room under the favors row
* Pre-fix the user's xtitle("") replaced the blank title holding the room,
* and a note() printed over the row.
local ++test_count
capture noisily {
    use `v161_base', clear
    eplot tr lo hi, labels(lab) logscale `ticks' ///
        favors("Shorter" "Longer", below) xtitle("") note("Source note") ///
        `dims' name(v161_t10, replace)
    local cmd `"`r(cmd)'"'
    local p1 = strpos(`"`cmd'"', `"xtitle("")"')
    local p2 = strpos(`"`cmd'"', `"xtitle(" ", margin(t+"')
    assert `p1' > 0 & `p2' > `p1'
    _v161_svgtext, graph(v161_t10) text("Shorter")
    assert !missing(r(y), r(size)) & r(n) == 1
    local yfav = r(y)
    local fs = r(size)
    _v161_svgtext, graph(v161_t10) text("Source note")
    assert !missing(r(y)) & r(n) == 1
    assert !missing(r(y), r(size), `yfav', `fs') & r(y) - r(size) > `yfav' + 0.2 * `fs'
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 10"
}

capture graph drop _all
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
_eplot_qa_result test_eplot_v161, tests(`test_count') pass(`pass_count') fail(`fail_count') skip(0)

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    capture log close
    exit 1
}
capture log close
