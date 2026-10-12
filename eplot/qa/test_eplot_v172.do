*! test_eplot_v172.do - Regression tests for eplot 1.7.2
*! With a values column the x range runs on under the column, so twoway
*! centred the effect-axis title and the graph title on a plot region that
*! includes the invisible column, off to the right of the drawn axis.  Since
*! 1.7.2 the effect-axis title is centred on the drawn effect axis and the
*! title and subtitle span the whole graph.  Positions are read back from SVG
*! exports: SVG text is drawn with text-anchor="middle", so a text's x is
*! its horizontal centre, and the drawn axis is the lowest horizontal line.

clear all
set varabbrev off
set graphics off
version 16.0

capture log close _all
log using "test_eplot_v172.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

* Reads the geometry of a graph back from its SVG export: the width of the
* graph, the drawn effect axis (the lowest horizontal line), the lowest text
* reading xtitle() (the values header may carry the same text higher up),
* the highest text reading title(), and the text reading subtitle().
capture program drop _v172_geom
program define _v172_geom, rclass
    version 16.0
    syntax , Graph(name) [XTitle(string asis) Title(string asis) ///
        SUBtitle(string asis)]
    foreach o in xtitle title subtitle {
        gettoken `o' : `o'
    }
    tempfile svg
    quietly graph display `graph'
    quietly graph export "`svg'", name(`graph') as(svg) replace
    tempname fh
    local width .
    local height .
    local xt_rot 0
    local axy -1
    local ax1 .
    local ax2 .
    local xt_y -1
    local xt_x .
    local xt_n 0
    local xt_size .
    local xt_fill ""
    local ti_y .
    local ti_x .
    local ti_size .
    local st_x .
    file open `fh' using "`svg'", read text
    file read `fh' line
    while r(eof) == 0 {
        if regexm(`"`macval(line)'"', `"viewBox="0 0 ([0-9.]+) "') {
            local width = real(regexs(1))
            if regexm(`"`macval(line)'"', `"viewBox="0 0 [0-9.]+ ([0-9.]+)""') {
                local height = real(regexs(1))
            }
        }
        if regexm(`"`macval(line)'"', `"<line x1="(-?[0-9.]+)" y1="(-?[0-9.]+)" x2="(-?[0-9.]+)" y2="(-?[0-9.]+)""') {
            local _x1 = real(regexs(1))
            local _y1 = real(regexs(2))
            local _x2 = real(regexs(3))
            local _y2 = real(regexs(4))
            if abs(`_y1' - `_y2') < 0.01 & abs(`_x2' - `_x1') > 1 & `_y1' > `axy' {
                local axy = `_y1'
                local ax1 = min(`_x1', `_x2')
                local ax2 = max(`_x1', `_x2')
            }
        }
        if regexm(`"`macval(line)'"', `"<text x="(-?[0-9.]+)" y="(-?[0-9.]+)""') {
            local _tx = real(regexs(1))
            local _ty = real(regexs(2))
            local _sz .
            if regexm(`"`macval(line)'"', "font-size:([0-9.]+)px") local _sz = real(regexs(1))
            local _fill ""
            if regexm(`"`macval(line)'"', "fill:(#[0-9A-Fa-f]+)") local _fill = regexs(1)
            if `"`xtitle'"' != "" & strpos(`"`macval(line)'"', `">`xtitle'</text>"') {
                local ++xt_n
                if `_ty' > `xt_y' {
                    local xt_y = `_ty'
                    local xt_x = `_tx'
                    local xt_size = `_sz'
                    local xt_fill "`_fill'"
                    local xt_rot = strpos(`"`macval(line)'"', "rotate(") > 0
                }
            }
            if `"`title'"' != "" & strpos(`"`macval(line)'"', `">`title'</text>"') {
                if missing(`ti_y') | `_ty' < `ti_y' {
                    local ti_y = `_ty'
                    local ti_x = `_tx'
                    local ti_size = `_sz'
                }
            }
            if `"`subtitle'"' != "" & strpos(`"`macval(line)'"', `">`subtitle'</text>"') {
                local st_x = `_tx'
            }
        }
        file read `fh' line
    }
    file close `fh'
    return scalar width = `width'
    return scalar height = `height'
    return scalar xt_rot = `xt_rot'
    return scalar axis_lo = `ax1'
    return scalar axis_hi = `ax2'
    return scalar axis_mid = (`ax1' + `ax2') / 2
    return scalar axis_y = `axy'
    return scalar xt_x = `xt_x'
    return scalar xt_y = `xt_y'
    return scalar xt_n = `xt_n'
    return scalar xt_size = `xt_size'
    return local xt_fill "`xt_fill'"
    return scalar ti_x = `ti_x'
    return scalar ti_size = `ti_size'
    return scalar st_x = `st_x'
end

* The x title centred on the drawn axis and the title (and subtitle) on the
* whole graph, to 1% of the graph width; the axis line itself must stop
* short of the right edge (the values column), or the check proves nothing.
capture program drop _v172_assert_centred
program define _v172_assert_centred
    version 16.0
    syntax [, SUBtitle]
    local w = r(width)
    assert !missing(`w', r(axis_lo), r(axis_hi), r(xt_x), r(ti_x))
    assert r(axis_hi) < 0.85 * `w'
    local d_xt = r(xt_x) - r(axis_mid)
    local d_ti = r(ti_x) - `w' / 2
    local d_st = r(st_x) - `w' / 2
    display as text "geometry (share of graph width): x title - axis midpoint = " ///
        %6.3f `d_xt' / `w' ", title - graph centre = " %6.3f `d_ti' / `w'
    if abs(`d_xt') >= 0.01 * `w' {
        display as error "x title is not centred on the drawn effect axis"
        exit 9
    }
    if abs(`d_ti') >= 0.01 * `w' {
        display as error "title is not centred on the graph"
        exit 9
    }
    if "`subtitle'" != "" {
        if missing(`d_st') | abs(`d_st') >= 0.01 * `w' {
            display as error "subtitle is not centred on the graph"
            exit 9
        }
    }
end

local dims "xsize(6) ysize(4) scheme(s2color)"

* Fixtures: long labels push the axis right, short labels let it sit left.
clear
input str40 lab es lci uci
"Cardiovascular event, adjusted model" 1.04 .99 1.10
"Self-harm" .98 .92 1.06
"Fracture" 1.03 .95 1.11
"Gastrointestinal bleeding (any)" .96 .89 1.03
end
generate str4 shortlab = "R" + string(_n)
tempfile v172_base
quietly save `v172_base'

**# Geometry with a values column, every mode
**## 1. Data mode, long labels, log scale: x title on the axis, titles spanning
local ++test_count
capture noisily {
    use `v172_base', clear
    eplot es lci uci, labels(lab) values logscale effect("Hazard ratio") ///
        vtitle("HR (95% CI)") title("Adjusted hazard ratios") ///
        subtitle("Four outcomes") `dims' name(v172_g1, replace)
    _v172_geom, graph(v172_g1) xtitle("Hazard ratio") ///
        title("Adjusted hazard ratios") subtitle("Four outcomes")
    assert r(xt_n) == 1
    _v172_assert_centred, subtitle
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: V172_1"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    display as error "FAIL: V172_1 (rc=" _rc ")"
}

**## 2. Data mode, short labels, linear scale, header shares the title text
local ++test_count
capture noisily {
    use `v172_base', clear
    eplot es lci uci, labels(shortlab) values effect("Estimate") ///
        title("Short labels") `dims' name(v172_g2, replace)
    _v172_geom, graph(v172_g2) xtitle("Estimate") title("Short labels")
    * The values header reads "Estimate" too; the axis title is the lower.
    assert r(xt_n) == 2
    _v172_assert_centred
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: V172_2"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    display as error "FAIL: V172_2 (rc=" _rc ")"
}

**## 3. Matrix mode
local ++test_count
capture noisily {
    matrix V172 = (1.5, 1.1, 2.0 \ 0.8, 0.6, 1.2 \ 1.2, 0.9, 1.6)
    matrix rownames V172 = "Treatment_A" "Treatment_B" "Treatment_C"
    eplot, matrix(V172) values effect("Odds ratio") vtitle("OR (95% CI)") ///
        title("Matrix mode") subtitle("values") `dims' name(v172_g3, replace)
    _v172_geom, graph(v172_g3) xtitle("Odds ratio") title("Matrix mode") ///
        subtitle("values")
    _v172_assert_centred, subtitle
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: V172_3"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    display as error "FAIL: V172_3 (rc=" _rc ")"
}

**## 4. Estimates mode, eform
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly logit foreign mpg weight headroom
    eplot ., drop(_cons) eform values effect("Odds ratio") ///
        vtitle("OR (95% CI)") title("Estimates mode") `dims' ///
        name(v172_g4, replace)
    _v172_geom, graph(v172_g4) xtitle("Odds ratio") title("Estimates mode")
    _v172_assert_centred
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: V172_4"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    display as error "FAIL: V172_4 (rc=" _rc ")"
}

**## 5. Frame mode
local ++test_count
capture noisily {
    clear
    input str24 label estimate ll ul
    "Alpha" 0.5 0.2 0.8
    "Beta, a longer label" -0.2 -0.6 0.2
    "Gamma" 0.1 -0.1 0.3
    end
    capture frame drop v172_fr
    frame put *, into(v172_fr)
    eplot, frame(v172_fr) values effect("Difference") vtitle("Diff (95% CI)") ///
        title("Frame mode") `dims' name(v172_g5, replace)
    _v172_geom, graph(v172_g5) xtitle("Difference") title("Frame mode")
    _v172_assert_centred
    frame drop v172_fr
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: V172_5"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    display as error "FAIL: V172_5 (rc=" _rc ")"
}

**## 6. favors(, below): the hung title is centred on the axis too
local ++test_count
capture noisily {
    use `v172_base', clear
    eplot es lci uci, labels(lab) values logscale effect("Hazard ratio") ///
        vtitle("HR (95% CI)") favors("Favors A" "Favors B", below) ///
        title("Favors below") `dims' name(v172_g6, replace)
    _v172_geom, graph(v172_g6) xtitle("Hazard ratio") title("Favors below")
    assert r(xt_n) == 1
    _v172_assert_centred
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: V172_6"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    display as error "FAIL: V172_6 (rc=" _rc ")"
}

**# User overrides
**## 7. A passed-through xtitle() text is centred, once, with its size and color
local ++test_count
capture noisily {
    use `v172_base', clear
    eplot es lci uci, labels(lab) values logscale vtitle("HR (95% CI)") ///
        xtitle("User axis title", size(large) color(red)) ///
        title("User xtitle") `dims' name(v172_g7, replace)
    _v172_geom, graph(v172_g7) xtitle("User axis title") title("User xtitle")
    assert r(xt_n) == 1
    _v172_assert_centred
    local big = r(xt_size)
    assert upper("`r(xt_fill)'") == "#FF0000"
    * The same title at the default size is smaller.
    eplot es lci uci, labels(lab) values logscale vtitle("HR (95% CI)") ///
        xtitle("User axis title") `dims' name(v172_g7b, replace)
    _v172_geom, graph(v172_g7b) xtitle("User axis title")
    assert r(xt_n) == 1
    assert !missing(`big', r(xt_size))
    assert `big' > r(xt_size) * 1.1
    assert abs(r(xt_x) - r(axis_mid)) < 0.01 * r(width)
    * Unquoted and multi-line xtitle() text.
    eplot es lci uci, labels(lab) values logscale vtitle("HR (95% CI)") ///
        xtitle(Plain words) `dims' name(v172_g7c, replace)
    _v172_geom, graph(v172_g7c) xtitle("Plain words")
    assert r(xt_n) == 1
    assert abs(r(xt_x) - r(axis_mid)) < 0.01 * r(width)
    eplot es lci uci, labels(lab) values logscale vtitle("HR (95% CI)") ///
        xtitle("Line one" "Line two") `dims' name(v172_g7d, replace)
    _v172_geom, graph(v172_g7d) xtitle("Line two")
    assert r(xt_n) == 1
    assert abs(r(xt_x) - r(axis_mid)) < 0.01 * r(width)
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: V172_7"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    display as error "FAIL: V172_7 (rc=" _rc ")"
}

**## 8. title() suboptions still apply under span
local ++test_count
capture noisily {
    use `v172_base', clear
    eplot es lci uci, labels(lab) values effect("Hazard ratio") ///
        title("Sized title", size(small)) `dims' name(v172_g8, replace)
    local cmd `"`r(cmd)'"'
    _v172_geom, graph(v172_g8) xtitle("Hazard ratio") title("Sized title")
    _v172_assert_centred
    * span comes before the user's title(), which merges onto it.
    local p_span = strpos(`"`cmd'"', "title(, span)")
    local p_user = strpos(`"`cmd'"', `"title("Sized title", size(small))"')
    assert `p_span' > 0 & `p_user' > `p_span'
    local small = r(ti_size)
    eplot es lci uci, labels(lab) values effect("Hazard ratio") ///
        title("Sized title") `dims' name(v172_g8b, replace)
    _v172_geom, graph(v172_g8b) title("Sized title")
    assert !missing(`small', r(ti_size))
    assert `small' < r(ti_size) * 0.9
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: V172_8"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    display as error "FAIL: V172_8 (rc=" _rc ")"
}

**# Layout left alone
**## 9. No values column: x title and title stay centred on the plot region
local ++test_count
* guard: expected green at HEAD too; this layout is left alone by the fix
capture noisily {
    use `v172_base', clear
    eplot es lci uci, labels(lab) logscale effect("Hazard ratio") ///
        title("No values") `dims' name(v172_g9, replace)
    local cmd `"`r(cmd)'"'
    _v172_geom, graph(v172_g9) xtitle("Hazard ratio") title("No values")
    * Both on the plot region, so on one another, and not on the graph.
    assert abs(r(ti_x) - r(xt_x)) < 1
    assert abs(r(ti_x) - r(width) / 2) > 0.02 * r(width)
    assert strpos(`"`cmd'"', "span") == 0
    assert strpos(`"`cmd'"', "axis(2)") == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: V172_9"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    display as error "FAIL: V172_9 (rc=" _rc ")"
}

**## 10. Vertical layout (values ignored) and an empty effect() title
local ++test_count
* guard: expected green at HEAD too; this layout is left alone by the fix
capture noisily {
    use `v172_base', clear
    eplot es lci uci, labels(shortlab) vertical values effect("Hazard ratio") ///
        title("Vertical") nonull `dims' name(v172_g10, replace)
    assert strpos(`"`r(cmd)'"', "span") == 0
    assert strpos(`"`r(cmd)'"', "axis(2)") == 0
    * Nothing to centre: no second axis, so no stray number for a label.
    eplot es lci uci, labels(lab) values effect(" ") vtitle("HR (95% CI)") ///
        `dims' name(v172_g10b, replace)
    assert strpos(`"`r(cmd)'"', "axis(2)") == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: V172_10"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    display as error "FAIL: V172_10 (rc=" _rc ")"
}

**## 11. effect(, atnull) with values still puts the title on the null
local ++test_count
* guard: expected green at HEAD too; this layout is left alone by the fix
capture noisily {
    use `v172_base', clear
    eplot es lci uci, labels(lab) values logscale xlabel(.8 1 1.5) ///
        effect("Hazard ratio", atnull) vtitle("HR (95% CI)") ///
        `dims' name(v172_g11, replace)
    _v172_geom, graph(v172_g11) xtitle("Hazard ratio")
    local xt = r(xt_x)
    local mid = r(axis_mid)
    _v172_geom, graph(v172_g11) xtitle("1")
    * The tick label "1" is the null; the title sits on it, off the midpoint.
    assert abs(`xt' - r(xt_x)) < 1
    assert abs(`xt' - `mid') > 0.02 * r(width)
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: V172_11"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    display as error "FAIL: V172_11 (rc=" _rc ")"
}

**# Passed-through axis options the centred title cannot honour
**## 12. xtitle("") suppresses the axis title, as at 1.7.1
local ++test_count
* guard: expected green at HEAD too; 1.7.1 behaviour the centred title must keep
capture noisily {
    use `v172_base', clear
    eplot es lci uci, labels(lab) values logscale effect("Hazard ratio") ///
        vtitle("HR (95% CI)") title("Main title") xtitle("") `dims' ///
        name(v172_g12, replace)
    _v172_geom, graph(v172_g12) xtitle("Hazard ratio") title("Main title")
    assert r(xt_n) == 0
    * The default title too.
    eplot es lci uci, labels(lab) values logscale vtitle("HR (95% CI)") ///
        xtitle("") `dims' name(v172_g12b, replace)
    _v172_geom, graph(v172_g12b) xtitle("Estimate (95% CI)")
    assert r(xt_n) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: V172_12"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    display as error "FAIL: V172_12 (rc=" _rc ")"
}

**## 13. xtitle() placement(), justification(), orientation() are honoured
local ++test_count
* guard: expected green at HEAD too; 1.7.1 behaviour the centred title must keep
capture noisily {
    use `v172_base', clear
    * placement(left) left-aligns the title on the plot region: well left
    * of the axis midpoint, where the centred title would be.
    eplot es lci uci, labels(lab) values logscale vtitle("HR (95% CI)") ///
        xtitle("Mine", placement(left)) `dims' name(v172_g13, replace)
    _v172_geom, graph(v172_g13) xtitle("Mine")
    assert r(xt_n) == 1
    assert !missing(r(xt_x), r(axis_mid), r(width))
    assert r(xt_x) < r(axis_mid) - 0.1 * r(width)
    * justification(right) right-aligns it: well right of the midpoint.
    eplot es lci uci, labels(lab) values logscale vtitle("HR (95% CI)") ///
        xtitle("Mine", justification(right)) `dims' name(v172_g13b, replace)
    _v172_geom, graph(v172_g13b) xtitle("Mine")
    assert r(xt_n) == 1
    assert !missing(r(xt_x), r(axis_mid), r(width))
    assert r(xt_x) > r(axis_mid) + 0.1 * r(width)
    * orientation(vertical) rotates it.
    eplot es lci uci, labels(lab) values logscale vtitle("HR (95% CI)") ///
        effect("Hazard ratio") xtitle(, orientation(vertical)) `dims' ///
        name(v172_g13c, replace)
    _v172_geom, graph(v172_g13c) xtitle("Hazard ratio")
    assert r(xt_n) == 1
    assert r(xt_rot) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: V172_13"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    display as error "FAIL: V172_13 (rc=" _rc ")"
}

**## 14. A user axis(2) exits r(198) as at 1.7.1, never replacing the title
local ++test_count
* guard: expected green at HEAD too; 1.7.1 behaviour the centred title must keep
capture noisily {
    use `v172_base', clear
    capture eplot es lci uci, labels(lab) values logscale ///
        vtitle("HR (95% CI)") xlabel(.9 1 1.1, axis(2)) `dims' ///
        name(v172_g14, replace)
    assert _rc == 198
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: V172_14"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    display as error "FAIL: V172_14 (rc=" _rc ")"
}

**## 15. xscale(alt) keeps the title with the axis, at the top
local ++test_count
* guard: expected green at HEAD too; 1.7.1 behaviour the centred title must keep
capture noisily {
    use `v172_base', clear
    eplot es lci uci, labels(lab) values logscale effect("Hazard ratio") ///
        vtitle("HR (95% CI)") xscale(alt) `dims' name(v172_g15, replace)
    _v172_geom, graph(v172_g15) xtitle("Hazard ratio")
    assert r(xt_n) == 1
    assert !missing(r(xt_y), r(height))
    assert r(xt_y) < 0.3 * r(height)
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: V172_15"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    display as error "FAIL: V172_15 (rc=" _rc ")"
}

**## 16. Two passed-through xtitle() options: one title, suboptions honoured
local ++test_count
* guard: expected green at HEAD too; 1.7.1 behaviour the centred title must keep
capture noisily {
    use `v172_base', clear
    eplot es lci uci, labels(lab) values logscale vtitle("HR (95% CI)") ///
        xtitle("Twice") xtitle(, size(small)) `dims' name(v172_g16, replace)
    _v172_geom, graph(v172_g16) xtitle("Twice")
    assert r(xt_n) == 1
    * A placement() in the second xtitle() is honoured, not dropped.
    eplot es lci uci, labels(lab) values logscale vtitle("HR (95% CI)") ///
        xtitle("Twice") xtitle(, placement(left)) `dims' ///
        name(v172_g16b, replace)
    _v172_geom, graph(v172_g16b) xtitle("Twice")
    assert r(xt_n) == 1
    assert !missing(r(xt_x), r(axis_mid), r(width))
    assert r(xt_x) < r(axis_mid) - 0.1 * r(width)
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: V172_16"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    display as error "FAIL: V172_16 (rc=" _rc ")"
}

**## 17. title(, nospan) restores plot-region centring
local ++test_count
* guard: expected green at HEAD too; 1.7.1 behaviour the centred title must keep
capture noisily {
    use `v172_base', clear
    eplot es lci uci, labels(lab) values logscale effect("Hazard ratio") ///
        vtitle("HR (95% CI)") title("Unspanned", nospan) `dims' ///
        name(v172_g17, replace)
    _v172_geom, graph(v172_g17) title("Unspanned")
    assert !missing(r(ti_x), r(width))
    assert abs(r(ti_x) - r(width) / 2) > 0.02 * r(width)
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: V172_17"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    display as error "FAIL: V172_17 (rc=" _rc ")"
}

**## 18. xscale(off) draws no axis title, as at 1.7.1
local ++test_count
* guard: expected green at HEAD too; 1.7.1 behaviour the centred title must keep
capture noisily {
    use `v172_base', clear
    eplot es lci uci, labels(lab) values logscale vtitle("HR (95% CI)") ///
        xscale(off) `dims' name(v172_g18, replace)
    _v172_geom, graph(v172_g18) xtitle("Estimate (95% CI)")
    assert r(xt_n) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: V172_18"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    display as error "FAIL: V172_18 (rc=" _rc ")"
}

capture graph drop _all
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
_eplot_qa_result test_eplot_v172, tests(`test_count') pass(`pass_count') fail(`fail_count') skip(0)

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    capture log close
    exit 1
}
capture log close
