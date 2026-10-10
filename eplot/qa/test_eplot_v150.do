*! test_eplot_v150.do - Regression tests for eplot 1.5.0
*! Covers values-column text styling (vsize, vcolor, labsize), axis style
*! passthrough through xscale()/yscale(), grid suppression under a user
*! xlabel() or nogrid, labelled xline() reference lines, favors() placement
*! (ends, below, arrows, off-range null), vtitle(), and the "Not estimated"
*! text for type 2 rows.  Drawn output is read back from the graph object or
*! from an SVG export rather than inferred from r(cmd) alone.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_eplot_v150.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

* Exports graph g to SVG and reports drawn text: r(n) is the number of text
* elements whose content equals TEXT exactly, r(size) the font size of the
* first, r(fill) its fill color, r(x) and r(y) its coordinates (SVG y grows
* downward), r(bold) 1 if bold.
capture program drop _v150_svgtext
program define _v150_svgtext, rclass
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
    local bold 0
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
                local bold = strpos(`"`macval(line)'"', "font-weight:bold") > 0
            }
        }
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
    return scalar size = `size'
    return scalar x = `x'
    return scalar y = `y'
    return scalar bold = `bold'
    return local fill "`fill'"
end

* Forest data in the shape of the reported use case: one type 2 row.
clear
input str20 lab double(es lo hi) byte t
"Men, 18-39"   1.20 1.05 1.37 1
"Men, 40-59"   1.10 0.98 1.24 1
"Men, 60+"     .    .    .    2
"Women, 18-39" 1.35 1.18 1.55 1
"Women, 40-59" 0.92 0.80 1.06 1
end
tempfile v150_base
quietly save `v150_base'

* A scheme that draws a grid on the x axis, as user schemes such as
* white_tableau do.  None of Stata's shipped schemes does, and the QA sandbox
* hides user schemes, so the suite writes its own onto the adopath.
local scheme_dir "`c(tmpdir)'/eplot_v150_scheme_`c(processid)'"
capture mkdir "`scheme_dir'"
tempname sfh
file open `sfh' using "`scheme_dir'/scheme-eplotvgrid.scheme", write text replace
file write `sfh' "#include s2color" _n
file write `sfh' "yesno draw_major_vgrid yes" _n
file close `sfh'
adopath + "`scheme_dir'"

**# Values-column and row-label text

**## Defaults are unchanged: vsmall gs4 values, small row labels
local ++test_count
capture noisily {
    use `v150_base', clear
    eplot es lo hi, labels(lab) type(t) values null(1) name(v150_t1, replace)
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "mlabsize(vsmall) mlabcolor(gs4)") > 0
    assert strpos(`"`cmd'"', "angle(0) labsize(small) nogrid noticks") > 0
    assert strpos(`"`cmd'"', "size(vsmall) placement(e) justification(left)") > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**## vsize(small) draws the values at the row-label size; vcolor() colors them
* Pre-1.5.0 the values were fixed at vsmall gs4 and the options were refused.
local ++test_count
capture noisily {
    use `v150_base', clear
    eplot es lo hi, labels(lab) type(t) values null(1) ///
        vsize(small) vcolor(black) name(v150_t2, replace)
    _v150_svgtext, graph(v150_t2) text("Men, 18-39")
    local lab_size = r(size)
    assert r(n) == 1
    _v150_svgtext, graph(v150_t2) text("1.20 (1.05, 1.37)")
    assert r(n) == 1
    assert !missing(r(size), `lab_size')
    assert reldif(r(size), `lab_size') < 1e-6
    assert "`r(fill)'" == "#000000"
    * The column header follows vsize() too.  1.6.0: with values the default
    * axis title drops the " (95% CI)" the header carries.
    _v150_svgtext, graph(v150_t2) text("Estimate (95% CI)")
    assert r(n) == 1
    _v150_svgtext, graph(v150_t2) text("Estimate")
    assert r(n) == 1
    * An RGB triplet is drawn as specified, not as the default color.
    eplot es lo hi, labels(lab) type(t) values null(1) vcolor("255 0 0") ///
        name(v150_t2c, replace)
    _v150_svgtext, graph(v150_t2c) text("1.20 (1.05, 1.37)")
    assert "`r(fill)'" == "#FF0000"
    * Default values are drawn smaller than the labels.
    eplot es lo hi, labels(lab) type(t) values null(1) name(v150_t2b, replace)
    _v150_svgtext, graph(v150_t2b) text("1.20 (1.05, 1.37)")
    assert r(size) < `lab_size'
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**## labsize() sets the row labels; *# resolves against eplot's defaults
local ++test_count
capture noisily {
    use `v150_base', clear
    eplot es lo hi, labels(lab) type(t) values null(1) labsize(medium) ///
        vsize(*1.5) name(v150_t3, replace)
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "angle(0) labsize(medium) nogrid") > 0
    * *1.5 of eplot's vsmall (2.0833), not of the scheme's label size
    assert strpos(`"`cmd'"', "mlabsize(3.125)") > 0
    eplot es lo hi, labels(lab) type(t) values null(1) vsize(10pt) ///
        name(v150_t3b, replace)
    assert strpos(`"`r(cmd)'"', "mlabsize(10pt)") > 0
    * Vertical layout carries labsize() onto the row axis.
    eplot es lo hi, labels(lab) type(t) vertical null(1) labsize(vsmall) ///
        name(v150_t3c, replace)
    assert strpos(`"`r(cmd)'"', "angle(45) labsize(vsmall) nogrid") > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**## A larger vsize() widens the values margin
local ++test_count
capture noisily {
    use `v150_base', clear
    eplot es lo hi, labels(lab) type(t) values null(1) name(v150_t4, replace)
    assert regexm(`"`r(cmd)'"', "margin\(l\+2 r\+([0-9]+) ")
    local r_default = real(regexs(1))
    eplot es lo hi, labels(lab) type(t) values null(1) vsize(medlarge) ///
        name(v150_t4b, replace)
    assert regexm(`"`r(cmd)'"', "margin\(l\+2 r\+([0-9]+) ")
    assert real(regexs(1)) > `r_default'
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**## Invalid sizes and colors are refused in every mode, varabbrev restored
local ++test_count
capture noisily {
    use `v150_base', clear
    set varabbrev on
    capture noisily eplot es lo hi, labels(lab) values vsize(huuuge)
    assert _rc == 198
    assert c(varabbrev) == "on"
    set varabbrev off
    capture noisily eplot es lo hi, labels(lab) values labsize(12 small)
    assert _rc == 198
    capture noisily eplot es lo hi, labels(lab) values vcolor(notacolor)
    assert _rc == 198
    matrix R = (0.5, 0.1 \ -0.3, 0.2)
    matrix rownames R = a b
    capture noisily eplot, matrix(R) values vsize(bogus)
    assert _rc == 198
    sysuse auto, clear
    quietly regress price mpg weight
    capture noisily eplot ., drop(_cons) values vcolor(nocolor)
    assert _rc == 198
    capture noisily eplot ., drop(_cons) values labsize(bogus)
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}
set varabbrev off

**# Axis styling through xscale()/yscale()

**## Style suboptions reach the drawn axis in every mode; eplot keeps range()
* Pre-1.5.0 any xscale() was refused, including lcolor() and fextend.
local ++test_count
capture noisily {
    use `v150_base', clear
    eplot es lo hi, labels(lab) type(t) null(1) logscale ///
        xscale(lcolor(red) lwidth(medthick) fextend) name(v150_t6, replace)
    assert strpos(`"`r(cmd)'"', "xscale(log range(") > 0
    assert "`.v150_t6.xaxis1.style.linestyle.color.setting'" == "255 0 0"
    assert "`.v150_t6.xaxis1.style.extend_low.setting'" == "yes"
    matrix R = (0.5, 0.1 \ -0.3, 0.2)
    matrix rownames R = a b
    eplot, matrix(R) xscale(lcolor(red)) name(v150_t6b, replace)
    assert "`.v150_t6b.xaxis1.style.linestyle.color.setting'" == "255 0 0"
    sysuse auto, clear
    quietly regress price mpg weight
    eplot ., drop(_cons) xscale(lcolor(red)) name(v150_t6c, replace)
    assert "`.v150_t6c.xaxis1.style.linestyle.color.setting'" == "255 0 0"
    * yscale(line ...) turns on the row axis line eplot hides by default.
    eplot ., drop(_cons) yscale(line lcolor(blue)) name(v150_t6d, replace)
    assert "`.v150_t6d.yaxis1.style.linestyle.color.setting'" == "0 0 255"
    assert strpos(`"`r(cmd)'"', "yscale(reverse noline range(") > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

**## Geometry suboptions are still refused, including in a repeated xscale()
local ++test_count
capture noisily {
    use `v150_base', clear
    * twoway accepts range() abbreviated to r() and ra().
    foreach bad in "range(0 3)" "r(0 3)" "ra(0 3)" "log" "nolog" "reverse" ///
        "noreverse" "axis(2)" {
        capture noisily eplot es lo hi, labels(lab) xscale(`bad')
        assert _rc == 198
    }
    * syntax binds only the first occurrence; the second must still be read.
    capture noisily eplot es lo hi, labels(lab) xscale(lcolor(red)) xscale(log)
    assert _rc == 198
    capture noisily eplot es lo hi, labels(lab) yscale(range(0 1))
    assert _rc == 198
    capture noisily eplot es lo hi, labels(lab) vertical yscale(r(0 3))
    assert _rc == 198
    capture noisily eplot es lo hi, labels(lab) yscale(lcolor(red)) yscale(reverse)
    assert _rc == 198
    matrix R = (0.5, 0.1 \ -0.3, 0.2)
    capture noisily eplot, matrix(R) xscale(range(-5 5))
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}

**# Grid under a user xlabel()

**## A user xlabel() suppresses a scheme grid unless it asks for one
* Pre-1.5.0 eplot dropped only its own grid, so a grid-drawing scheme still
* put lines behind the rows.
local ++test_count
capture noisily {
    use `v150_base', clear
    eplot es lo hi, labels(lab) type(t) null(1) xlabel(0.8 1 1.2 1.5) ///
        scheme(eplotvgrid) name(v150_t8, replace)
    assert "`.v150_t8.xaxis1.style.draw_major_grid.setting'" == "no"
    assert strpos(`"`r(cmd)'"', "xlabel(0.8 1 1.2 1.5, nogrid)") > 0
    * Suboptions are kept and nogrid is appended after them.
    eplot es lo hi, labels(lab) type(t) null(1) ///
        xlabel(0.8 1 1.2, format(%3.1f)) scheme(eplotvgrid) name(v150_t8b, replace)
    assert strpos(`"`r(cmd)'"', "xlabel(0.8 1 1.2, format(%3.1f) nogrid)") > 0
    assert "`.v150_t8b.xaxis1.style.draw_major_grid.setting'" == "no"
    * An explicit grid is honored.
    eplot es lo hi, labels(lab) type(t) null(1) xlabel(0.8 1 1.2, grid) ///
        scheme(eplotvgrid) name(v150_t8c, replace)
    assert "`.v150_t8c.xaxis1.style.draw_major_grid.setting'" == "yes"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}

**## nogrid removes eplot's own grid and conflicts with xlabel(..., grid)
local ++test_count
capture noisily {
    use `v150_base', clear
    eplot es lo hi, labels(lab) type(t) null(1) name(v150_t9, replace)
    assert "`.v150_t9.xaxis1.style.draw_major_grid.setting'" == "yes"
    eplot es lo hi, labels(lab) type(t) null(1) nogrid name(v150_t9b, replace)
    assert "`.v150_t9b.xaxis1.style.draw_major_grid.setting'" == "no"
    assert strpos(`"`r(cmd)'"', "glcolor(gs12)") == 0
    capture noisily eplot es lo hi, labels(lab) nogrid xlabel(1 2, grid)
    assert _rc == 198
    sysuse auto, clear
    quietly regress price mpg weight
    eplot ., drop(_cons) nogrid name(v150_t9c, replace)
    assert "`.v150_t9c.xaxis1.style.draw_major_grid.setting'" == "no"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}

**# Labelled reference lines

**## xline(#, label()) draws the label at the top, beside the line
local ++test_count
capture noisily {
    use `v150_base', clear
    eplot es lo hi, labels(lab) type(t) null(1) logscale ///
        xline(1.13, label("Women against men at 18-39")) name(v150_t10, replace)
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "xline(1.13, lcolor(gs10) lpattern(shortdash))") > 0
    assert strpos(`"`cmd'"', `"text(.3 1.13 `"Women against men at 18-39"'"') > 0
    assert !regexm(`"`cmd'"', "xline\([^)]*label\(")
    * The top row of the plot is opened to hold the label.
    assert strpos(`"`cmd'"', "yscale(reverse noline range(-.2 ") > 0
    _v150_svgtext, graph(v150_t10) text("Women against men at 18-39")
    assert r(n) == 1
    * Unquoted single label, and user line style kept beside label().
    eplot es lo hi, labels(lab) type(t) null(1) ///
        xline(1.13, lcolor(red) label(Women at 18-39)) name(v150_t10b, replace)
    assert strpos(`"`r(cmd)'"', "xline(1.13, lcolor(red))") > 0
    _v150_svgtext, graph(v150_t10b) text("Women at 18-39")
    assert r(n) == 1
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 10"
}

**## One label per position; empty labels skip; mismatches are refused
local ++test_count
capture noisily {
    use `v150_base', clear
    eplot es lo hi, labels(lab) type(t) null(1) ///
        xline(1.1 1.3, label("A line" "")) name(v150_t11, replace)
    _v150_svgtext, graph(v150_t11) text("A line")
    assert r(n) == 1
    assert strpos(`"`r(cmd)'"', "text(.3 1.3 ") == 0
    capture noisily eplot es lo hi, labels(lab) xline(1.1 1.3, label("only one"))
    assert _rc == 198
    capture noisily eplot es lo hi, labels(lab) xline(1.1, label("a" "b"))
    assert _rc == 198
    * Vertical layout labels the horizontal line beside the first row.
    eplot es lo hi, labels(lab) type(t) null(1) vertical ///
        xline(1.13, label("V label")) name(v150_t11b, replace)
    assert strpos(`"`r(cmd)'"', "yline(1.13, ") > 0
    assert strpos(`"`r(cmd)'"', `"text(1.13 .05 `"V label"'"') > 0
    * Estimates and matrix modes.
    matrix R = (0.5, 0.1 \ -0.3, 0.2)
    matrix rownames R = a b
    eplot, matrix(R) xline(0.2, label("M line")) name(v150_t11c, replace)
    _v150_svgtext, graph(v150_t11c) text("M line")
    assert r(n) == 1
    sysuse auto, clear
    quietly regress price mpg weight
    eplot ., drop(_cons) xline(10, label("E line")) name(v150_t11d, replace)
    _v150_svgtext, graph(v150_t11d) text("E line")
    assert r(n) == 1
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 11"
}

**# favors() placement

**## Default centred placement; ends anchors labels at the axis ends
* 1.6.0: favors() text takes the tick_label style (was size(vsmall)).
* 1.6.1: the labels are anchored at the null, reading outward (was centred).
local ++test_count
capture noisily {
    use `v150_base', clear
    eplot es lo hi, labels(lab) type(t) null(1) favors("Shorter" "Longer") ///
        name(v150_t12, replace)
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', `"text(6.5 1 `"Shorter"', tstyle(tick_label) color(gs5) placement(w) margin(r=1.5 l=0 t=0 b=0))"') > 0
    assert strpos(`"`cmd'"', `"text(6.5 1 `"Longer"', tstyle(tick_label) color(gs5) placement(e) margin(l=1.5 r=0 t=0 b=0))"') > 0
    assert strpos(`"`cmd'"', "range(0 7))") > 0
    eplot es lo hi, labels(lab) type(t) null(1) ///
        favors("Shorter" "Longer", ends) name(v150_t12b, replace)
    local cmd `"`r(cmd)'"'
    assert regexm(`"`cmd'"', "xscale\(range\(([^ ]+) ([^)]+)\)\)")
    local xlo = regexs(1)
    local xhi = regexs(2)
    assert strpos(`"`cmd'"', `"text(6.5 `xlo' `"Shorter"', tstyle(tick_label) color(gs5) placement(e))"') > 0
    assert strpos(`"`cmd'"', `"text(6.5 `xhi' `"Longer"', tstyle(tick_label) color(gs5) placement(w))"') > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 12"
}

**## below puts the labels under the axis; arrows point away from the null
local ++test_count
capture noisily {
    use `v150_base', clear
    eplot es lo hi, labels(lab) type(t) null(1) ///
        favors("Shorter" "Longer", below arrows) name(v150_t13, replace)
    local cmd `"`r(cmd)'"'
    * 1.6.1: hung under the tick labels from the null (was xmlabel()).
    assert strpos(`"`cmd'"', "xmlabel(") == 0
    assert strpos(`"`cmd'"', "placement(c)") == 0
    assert strpos(`"`cmd'"', "placement(sw)") > 0 & strpos(`"`cmd'"', "placement(se)") > 0
    * No extra bottom row when the labels are outside the plot.
    assert strpos(`"`cmd'"', "range(0 6))") > 0
    local larr = uchar(8592)
    local rarr = uchar(8594)
    _v150_svgtext, graph(v150_t13) text("`larr' Shorter")
    assert r(n) == 1
    _v150_svgtext, graph(v150_t13) text("Longer `rarr'")
    assert r(n) == 1
    * Unquoted single-word labels still work, with and without suboptions.
    eplot es lo hi, labels(lab) type(t) null(1) favors(Lower Higher) ///
        name(v150_t13b, replace)
    _v150_svgtext, graph(v150_t13b) text("Higher")
    assert r(n) == 1
    eplot es lo hi, labels(lab) type(t) null(1) ///
        favors(Lower "Much higher", ends arrows) name(v150_t13c, replace)
    _v150_svgtext, graph(v150_t13c) text("Much higher `rarr'")
    assert r(n) == 1
    capture noisily eplot es lo hi, labels(lab) null(1) favors(A B C)
    assert _rc == 198
    capture noisily eplot es lo hi, labels(lab) null(1) favors("A" "B", below ends)
    assert _rc == 198
    capture noisily eplot es lo hi, labels(lab) null(1) favors("A" "B", sideways)
    assert _rc == 198
    capture noisily eplot es lo hi, labels(lab) null(1) favors("A", ends)
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 13"
}

**## A null outside the plotted range moves centred labels onto the axis
* Pre-1.5.0 the labels were centred on an off-axis null and dropped at rc=0.
local ++test_count
capture noisily {
    use `v150_base', clear
    keep if t == 1 & es > 1
    * 1.6.0: favors() widens the range to the null, so the labels centre on
    * each side of it; with nonull the range is not widened and the labels
    * still move to the axis ends.
    eplot es lo hi, labels(lab) favors("Left" "Right") name(v150_t14a, replace)
    local cmd `"`r(cmd)'"'
    assert regexm(`"`cmd'"', "xscale\(range\(([^ ]+) ([^)]+)\)\)")
    assert real(regexs(1)) < 0
    assert strpos(`"`cmd'"', `"`"Left"', tstyle(tick_label) color(gs5) placement(w) margin(r=1.5"') > 0
    eplot es lo hi, labels(lab) nonull favors("Left" "Right") name(v150_t14, replace)
    local cmd `"`r(cmd)'"'
    assert regexm(`"`cmd'"', "xscale\(range\(([^ ]+) ([^)]+)\)\)")
    local xlo = regexs(1)
    local xhi = regexs(2)
    assert strpos(`"`cmd'"', `"`xlo' `"Left"', tstyle(tick_label) color(gs5) placement(e))"') > 0
    assert strpos(`"`cmd'"', `"`xhi' `"Right"', tstyle(tick_label) color(gs5) placement(w))"') > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 14"
}

**# vtitle() and type 2 rows

**## vtitle() heads the values column; effect() keeps the axis title
local ++test_count
capture noisily {
    use `v150_base', clear
    eplot es lo hi, labels(lab) type(t) values null(1) effect("Time ratio") ///
        vtitle("Time ratio (95% CI)") name(v150_t15, replace)
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', `"xtitle(`"Time ratio"', size(medsmall))"') > 0
    assert strpos(`"`cmd'"', `"`"{bf:Time ratio (95% CI)}"'"') > 0
    _v150_svgtext, graph(v150_t15) text("Time ratio (95% CI)")
    assert r(n) == 1 & r(bold) == 1
    _v150_svgtext, graph(v150_t15) text("Time ratio")
    assert r(n) == 1 & r(bold) == 0
    matrix R = (0.5, 0.1 \ -0.3, 0.2)
    matrix rownames R = a b
    eplot, matrix(R) values vtitle("Beta (95% CI)") name(v150_t15b, replace)
    _v150_svgtext, graph(v150_t15b) text("Beta (95% CI)")
    assert r(n) == 1
    sysuse auto, clear
    quietly regress price mpg weight
    eplot ., drop(_cons) values vtitle("Coef (95% CI)") name(v150_t15c, replace)
    _v150_svgtext, graph(v150_t15c) text("Coef (95% CI)")
    assert r(n) == 1
    * values-column options are single-model only.
    estimates store m1
    quietly regress price mpg
    estimates store m2
    foreach o in "vtitle(x)" "vsize(small)" "vcolor(black)" {
        capture noisily eplot m1 m2, drop(_cons) `o'
        assert _rc == 198
    }
    estimates drop m1 m2
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 15"
}

**## Type 2 rows print "Not estimated"; vmissing() changes or blanks it
* Pre-1.5.0 the values column was empty on type 2 rows.
local ++test_count
capture noisily {
    use `v150_base', clear
    eplot es lo hi, labels(lab) type(t) values null(1) name(v150_t16, replace)
    _v150_svgtext, graph(v150_t16) text("Not estimated")
    assert r(n) == 1
    local x_ne = r(x)
    _v150_svgtext, graph(v150_t16) text("1.20 (1.05, 1.37)")
    assert !missing(r(x), `x_ne')
    assert reldif(r(x), `x_ne') < 1e-6
    eplot es lo hi, labels(lab) type(t) values null(1) vmissing("n/a") ///
        name(v150_t16b, replace)
    _v150_svgtext, graph(v150_t16b) text("n/a")
    assert r(n) == 1
    _v150_svgtext, graph(v150_t16b) text("Not estimated")
    assert r(n) == 0
    eplot es lo hi, labels(lab) type(t) values null(1) vmissing("") ///
        name(v150_t16c, replace)
    _v150_svgtext, graph(v150_t16c) text("Not estimated")
    assert r(n) == 0
    * Without values nothing is printed.
    eplot es lo hi, labels(lab) type(t) null(1) name(v150_t16d, replace)
    _v150_svgtext, graph(v150_t16d) text("Not estimated")
    assert r(n) == 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 16"
}

**## String types: "missing" prints the text, "reference" stays blank
local ++test_count
capture noisily {
    clear
    input str12 lab double(es lo hi) str12 ty
    "Ref group" .    .    .    "reference"
    "Exposed"   1.40 1.10 1.80 "effect"
    "Lost"      .    .    .    "missing"
    end
    eplot es lo hi, labels(lab) type(ty) values null(1) name(v150_t17, replace)
    _v150_svgtext, graph(v150_t17) text("Not estimated")
    assert r(n) == 1
    * Frame mode forwards vmissing() to the data-mode builder.
    capture frame drop v150fr
    frame put lab es lo hi ty, into(v150fr)
    frame v150fr: rename (es lo hi ty) (estimate ll ul rowtype)
    eplot, frame(v150fr) labels(lab) values null(1) vmissing("Excluded") name(v150_t17b, replace)
    _v150_svgtext, graph(v150_t17b) text("Excluded")
    assert r(n) == 1
    frame drop v150fr
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 17"
}

**# Review fixes (folded into 1.5.0)

**## A user xlabel() widens the effect range to every tick, log and linear
* Before the fix eplot emitted xscale(log range(.853 2.26)) for these ticks:
* twoway does not widen a log axis to its labels, so .5 was drawn off the
* canvas and .7 left of the axis line.
local ++test_count
capture noisily {
    clear
    input str16 sg double(es lci uci) byte type
    "Age < 60" 1.18 0.88 1.58 1
    "Age 60+"  1.31 1.05 1.63 1
    "Overall"  1.25 1.06 1.47 5
    end
    eplot es lci uci, labels(sg) type(type) logscale values ///
        xlabel(0.5 0.7 1 1.4 2 3) name(v150_t18, replace)
    assert regexm(`"`r(cmd)'"', "xscale\(log range\(([^ ]+) ([^)]+)\)\)")
    assert !missing(real(regexs(1)))
    assert reldif(real(regexs(1)), 0.5) < 1e-9
    eplot es lci uci, labels(sg) type(type) xlabel(0.5 0.7 1 1.4 2 3) ///
        name(v150_t18b, replace)
    assert regexm(`"`r(cmd)'"', "xscale\(range\(([^ ]+) ([^)]+)\)\)")
    assert !missing(real(regexs(1)))
    assert reldif(real(regexs(1)), 0.5) < 1e-9
    assert !missing(real(regexs(2)))
    assert reldif(real(regexs(2)), 3) < 1e-9
    * Quoted tick labels are not positions: 100 must not widen the axis.
    eplot es lci uci, labels(sg) type(type) xlabel(1 "100" 1.5 "one and a half") ///
        name(v150_t18c, replace)
    assert regexm(`"`r(cmd)'"', "xscale\(range\(([^ ]+) ([^)]+)\)\)")
    assert real(regexs(2)) < 2
    * eplot's own decade lattice brackets the data; its end ticks are drawn.
    clear
    input str4 g double(es lci uci)
    "A" 0.5 0.32 0.9
    "B" 2.0 1.2  3.7
    end
    eplot es lci uci, labels(g) logscale name(v150_t18d, replace)
    assert strpos(`"`r(cmd)'"', "xscale(log range(.2 5))") > 0
    * Estimates and matrix modes, and the vertical effect axis.
    matrix R = (1.2, 1.1 \ 1.4, 1.2)
    matrix colnames R = b se
    matrix rownames R = a b
    eplot, matrix(R) xlabel(-2 0 2 4) name(v150_t18e, replace)
    assert regexm(`"`r(cmd)'"', "xscale\(range\(-2 4\)\)")
    sysuse auto, clear
    quietly logit foreign mpg weight
    eplot ., drop(_cons) eform logscale xlabel(0.25 1 4) vertical ///
        name(v150_t18f, replace)
    assert regexm(`"`r(cmd)'"', "yscale\(log range\(\.25 4\)\)")
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 18"
}

**## The values column starts right of the last labelled tick
* The appended ", nogrid" made the anchor's tick parse fail, so the column
* started at 2.26, between ticks 2 and 3, with the axis running under it.
local ++test_count
capture noisily {
    clear
    input str16 sg double(es lci uci) byte type
    "Age < 60" 1.18 0.88 1.58 1
    "Age 60+"  1.31 1.05 1.63 1
    "Overall"  1.25 1.06 1.47 5
    end
    foreach ax in "logscale" "" {
        eplot es lci uci, labels(sg) type(type) `ax' values ///
            xlabel(0.5 0.7 1 1.4 2 3) name(v150_t19, replace)
        assert regexm(`"`r(cmd)'"', "text\(\.3 ([^ ]+) ")
        assert real(regexs(1)) > 3
        * The default grid case anchors past its last tick as well.
        eplot es lci uci, labels(sg) type(type) `ax' values xlabel(0.5 1 3, grid) ///
            name(v150_t19b, replace)
        assert regexm(`"`r(cmd)'"', "text\(\.3 ([^ ]+) ")
        assert real(regexs(1)) > 3
    }
    matrix R = (0.5, 0.1 \ -0.3, 0.2)
    matrix rownames R = a b
    eplot, matrix(R) values xlabel(-1 0 1 2) name(v150_t19c, replace)
    assert regexm(`"`r(cmd)'"', "text\(\.3 ([^ ]+) ")
    assert real(regexs(1)) > 2
    sysuse auto, clear
    quietly regress price mpg weight
    eplot ., drop(_cons) values xlabel(-500 0 500) name(v150_t19d, replace)
    assert regexm(`"`r(cmd)'"', "text\(\.3 ([^ ]+) ")
    assert real(regexs(1)) > 500
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 19"
}

**## A bare-number vsize()/labsize() prints no error text
* regexs() of the unmatched unit group printed "invalid number, outside of
* allowed range" in red while the call went on to rc=0.
local ++test_count
capture noisily {
    use `v150_base', clear
    tempfile szlog
    quietly log using "`szlog'", text replace name(v150_sz)
    eplot es lo hi, labels(lab) type(t) values null(1) vsize(3) labsize(2.5) ///
        name(v150_t20, replace)
    local c `"`r(cmd)'"'
    quietly log close v150_sz
    assert strpos(`"`c'"', "mlabsize(3)") > 0
    assert strpos(`"`c'"', "labsize(2.5) nogrid") > 0
    tempname lfh
    local hits 0
    file open `lfh' using "`szlog'", read text
    file read `lfh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "invalid number") local ++hits
        file read `lfh' line
    }
    file close `lfh'
    assert `hits' == 0
}
local rc20 = _rc
capture log close v150_sz
if `rc20' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 20"
}

**## With values, an xline() label sits above the values header, not on it
* Both were drawn at y = 0.3, so a line near the right edge ran its label
* into the header text.
local ++test_count
capture noisily {
    use `v150_base', clear
    eplot es lo hi, labels(lab) type(t) values null(1) ///
        xline(1.45, label("LateLine")) name(v150_t21, replace)
    _v150_svgtext, graph(v150_t21) text("LateLine")
    assert r(n) == 1
    local y_lab = r(y)
    _v150_svgtext, graph(v150_t21) text("Estimate (95% CI)")
    assert r(n) == 1
    * The header's baseline is lower on the page than the label's.
    assert !missing(r(y), `y_lab')
    assert !missing(`y_lab', r(y))
    assert `y_lab' < r(y)
    * Without values the label keeps the top row.
    eplot es lo hi, labels(lab) type(t) null(1) ///
        xline(1.45, label("LateLine")) name(v150_t21b, replace)
    assert strpos(`"`r(cmd)'"', "text(.3 1.45 ") > 0
    matrix R = (0.5, 0.1 \ -0.3, 0.2)
    matrix rownames R = a b
    eplot, matrix(R) values xline(0.6, label("MLine")) name(v150_t21c, replace)
    _v150_svgtext, graph(v150_t21c) text("MLine")
    local y_lab = r(y)
    _v150_svgtext, graph(v150_t21c) text("Estimate (95% CI)")
    assert !missing(`y_lab', r(y))
    assert `y_lab' < r(y)
    sysuse auto, clear
    quietly regress price mpg weight
    eplot ., drop(_cons) values xline(5, label("ELine")) name(v150_t21d, replace)
    _v150_svgtext, graph(v150_t21d) text("ELine")
    local y_lab = r(y)
    _v150_svgtext, graph(v150_t21d) text("Coefficient (95% CI)")
    assert !missing(`y_lab', r(y))
    assert `y_lab' < r(y)
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 21"
}

**## RGB vcolor() is drawn as specified in estimates and matrix modes
local ++test_count
capture noisily {
    matrix R = (0.5, 0.1 \ -0.3, 0.2)
    matrix rownames R = a b
    eplot, matrix(R) values vcolor("0 128 0") name(v150_t22, replace)
    _v150_svgtext, graph(v150_t22) text("0.50 (0.30, 0.70)")
    assert r(n) == 1
    assert "`r(fill)'" == "#008000"
    sysuse auto, clear
    quietly regress price mpg weight
    eplot ., drop(_cons) values vcolor(0 0 255) vformat(%9.1f) ///
        name(v150_t22b, replace)
    _v150_svgtext, graph(v150_t22b) text("Coefficient (95% CI)")
    assert !missing(r(n))
    assert r(n) >= 1
    tempfile svg22
    quietly graph export "`svg22'", name(v150_t22b) as(svg) replace
    tempname sfh22
    local blue 0
    file open `sfh22' using "`svg22'", read text
    file read `sfh22' line
    while r(eof) == 0 {
        if regexm(lower(`"`macval(line)'"'), `"fill:#0000ff"[^>]*>-?[0-9]"') local ++blue
        file read `sfh22' line
    }
    file close `sfh22'
    assert `blue' == 2
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 22"
}

**## xlabel(, suboptions) keeps its grid request and the nogrid conflict
* The leading comma came back as the tick token, so xlabel(, grid) became
* xlabel(, grid nogrid) and nogrid with xlabel(, grid) was not refused.
local ++test_count
capture noisily {
    use `v150_base', clear
    eplot es lo hi, labels(lab) type(t) null(1) xlabel(, grid) ///
        scheme(eplotvgrid) name(v150_t23, replace)
    assert strpos(`"`r(cmd)'"', "xlabel(, grid)") > 0
    assert "`.v150_t23.xaxis1.style.draw_major_grid.setting'" == "yes"
    eplot es lo hi, labels(lab) type(t) null(1) xlabel(, labsize(small)) ///
        scheme(eplotvgrid) name(v150_t23b, replace)
    assert strpos(`"`r(cmd)'"', "xlabel(, labsize(small) nogrid)") > 0
    assert "`.v150_t23b.xaxis1.style.draw_major_grid.setting'" == "no"
    capture noisily eplot es lo hi, labels(lab) nogrid xlabel(, grid)
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 23"
}

capture adopath - "`scheme_dir'"
capture erase "`scheme_dir'/scheme-eplotvgrid.scheme"
capture rmdir "`scheme_dir'"
capture graph drop _all
capture estimates drop _all
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
_eplot_qa_result test_eplot_v150, tests(`test_count') pass(`pass_count') fail(`fail_count') skip(0)

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    capture log close
    exit 1
}
capture log close
