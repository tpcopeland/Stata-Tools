* test_v190_overlap_support_graphs.do -- overlap/support graph aesthetics
* Author: Timothy P Copeland, Karolinska Institutet
*
* Fail-on-old (psdash 1.8.1). Every assertion reads a saved .gph or an exported
* SVG, never the source text of the .ado files:
*   hist_bins_aligned     - treated and control histograms started at their own
*                           group minimum, so bars were offset by a fraction of
*                           a bin (serset bin midpoints differ by a non-integer
*                           number of widths)
*   support_bound_key_*   - overlap draws grey common-support xlines with no
*                           legend key
*   dash_key_dashboard    - the dashed legend key was clipped to a dash and a dot
*                           at the small key width of the 2x2 dashboard
*   mg_box_*_canonical    - multi-group box plots used the scheme's default
*                           series order (blue/orange/green) and the support box
*                           was all blue; density/weights use p1, p6, p2
*   mg_floor_*            - the red gpsfloor line had no legend key or note
*   mg_box_default_ticks  - forced %3.1f / %4.2f tick labels (0.0, 0.20, ...)
*   mg_density_one_legend - three identical per-panel legends
*   mg_density_text_size  - forced small/vsmall text on a 12-inch-wide combine
version 16.0
clear all
capture log close _all
log using test_v190_overlap_support_graphs.log, replace nomsg
do "`c(pwd)'/_psdash_bootstrap.do"
local tests = 0
local pass = 0
local fail = 0
local failed ""

* graph export needs a .svg suffix; tempfile names carry their own suffix.
tempfile svgbase gph
local svg_cut = strrpos("`svgbase'", "/")
local svg = substr("`svgbase'", 1, `svg_cut') + ///
    subinstr(substr("`svgbase'", `svg_cut' + 1, .), ".", "_", .) + ".svg"

* Series colours are read against the white_tableau scheme the package demos
* use; fall back to the built-in s2color when tc_schemes is not installed.
local sch "s2color"
capture findfile scheme-white_tableau.scheme
if _rc {
    local tc_dir = substr("`c(pwd)'", 1, strlen("`c(pwd)'") - 3) + "/../tc_schemes"
    capture quietly net install tc_schemes, from("`tc_dir'") replace
    capture findfile scheme-white_tableau.scheme
}
if _rc == 0 local sch "white_tableau"
display "test scheme: `sch'"

capture mata: mata drop _v190_count_text() _v190_min_fs_ratio() ///
    _v190_key_dashes() _v190_fills() _v190_ref_strokes() _v190_lab() ///
    _v190_nearest_set() _v190_hist_offset() _v190_hex2num()
mata:
// Number of <text> elements whose content matches the regular expression re.
real scalar _v190_count_text(string scalar f, string scalar re)
{
    string colvector L
    real scalar i, n
    L = cat(f)
    n = 0
    for (i = 1; i <= rows(L); i++) {
        if (regexm(L[i], ">([^<]*)</text>")) n = n + regexm(regexs(1), re)
    }
    return(n)
}
// Smallest <text> font size divided by the SVG viewBox width.
real scalar _v190_min_fs_ratio(string scalar f)
{
    string colvector L
    real scalar i, w, m, fs
    L = cat(f)
    w = .
    m = .
    for (i = 1; i <= rows(L); i++) {
        if (w >= . & regexm(L[i], "viewBox=.0 0 ([0-9.]+) ")) w = strtoreal(regexs(1))
        if (regexm(L[i], "<text .*font-size:([0-9.]+)px")) {
            fs = strtoreal(regexs(1))
            if (m >= . | fs < m) m = fs
        }
    }
    if (w >= . | m >= .) return(.)
    return(m / w)
}
// For each legend <text> whose content is txt: the number of horizontal grey
// (#808080) <line> segments of the key drawn just left of it. Returns the
// minimum over occurrences, or -1 when txt does not occur.
real scalar _v190_key_dashes(string scalar f, string scalar txt)
{
    string colvector L
    real scalar i, j, tx, ty, fs, n, best, x1, x2, y1, y2, found
    L = cat(f)
    best = .
    found = 0
    for (i = 1; i <= rows(L); i++) {
        if (!strpos(L[i], ">" + txt + "</text>")) continue
        if (!regexm(L[i], "<text x=.([0-9.]+). y=.([0-9.]+).")) continue
        tx = strtoreal(regexs(1))
        ty = strtoreal(regexs(2))
        if (!regexm(L[i], "font-size:([0-9.]+)px")) continue
        fs = strtoreal(regexs(1))
        found++
        n = 0
        for (j = 1; j <= rows(L); j++) {
            if (!strpos(L[j], "<line ")) continue
            if (!strpos(L[j], "stroke:#808080")) continue
            if (!regexm(L[j], "x1=.([0-9.]+). y1=.([0-9.]+). x2=.([0-9.]+). y2=.([0-9.]+).")) continue
            x1 = strtoreal(regexs(1)); y1 = strtoreal(regexs(2))
            x2 = strtoreal(regexs(3)); y2 = strtoreal(regexs(4))
            if (y1 != y2) continue
            if (y1 > ty | y1 < ty - fs) continue
            if (x2 > tx | x1 < tx - 10 * fs) continue
            n++
        }
        if (best >= . | n < best) best = n
    }
    if (!found) return(-1)
    return(best)
}
real scalar _v190_hex2num(string scalar h)
{
    return(16 * (strpos("0123456789ABCDEF", substr(h, 1, 1)) - 1) + ///
        (strpos("0123456789ABCDEF", substr(h, 2, 1)) - 1))
}
// CIELAB (D65) of a 6-digit hex colour.
real rowvector _v190_lab(string scalar hex)
{
    real rowvector c
    real scalar i, X, Y, Z
    c = J(1, 3, .)
    for (i = 1; i <= 3; i++) {
        c[i] = _v190_hex2num(substr(hex, 2*i - 1, 2)) / 255
        c[i] = (c[i] > .04045 ? ((c[i] + .055) / 1.055)^2.4 : c[i] / 12.92)
    }
    X = (c[1]*.4124 + c[2]*.3576 + c[3]*.1805) / .95047
    Y =  c[1]*.2126 + c[2]*.7152 + c[3]*.0722
    Z = (c[1]*.0193 + c[2]*.1192 + c[3]*.9505) / 1.08883
    X = (X > .008856 ? X^(1/3) : 7.787*X + 16/116)
    Y = (Y > .008856 ? Y^(1/3) : 7.787*Y + 16/116)
    Z = (Z > .008856 ? Z^(1/3) : 7.787*Z + 16/116)
    return((116*Y - 16, 500*(X - Y), 200*(Y - Z)))
}
// Distinct non-grey, non-red fill colours of an SVG (box fills, markers).
string colvector _v190_fills(string scalar f)
{
    string colvector L, cols
    string scalar s, hex
    real scalar i, p
    L = cat(f)
    cols = J(0, 1, "")
    for (i = 1; i <= rows(L); i++) {
        s = L[i]
        while ((p = strpos(s, "fill:#")) > 0) {
            hex = strupper(substr(s, p + 6, 6))
            s = substr(s, p + 12, .)
            if (strlen(hex) < 6 | hex == "FF0000") continue
            if (substr(hex, 1, 2) == substr(hex, 3, 2) & ///
                substr(hex, 3, 2) == substr(hex, 5, 2)) continue
            cols = cols \ hex
        }
    }
    if (rows(cols) == 0) return(cols)
    return(uniqrows(cols))
}
// Non-grey, non-red <path>/<line> stroke colours in order of first appearance.
string colvector _v190_ref_strokes(string scalar f)
{
    string colvector L, cols
    string scalar s, hex
    real scalar i, p, j, dup
    L = cat(f)
    cols = J(0, 1, "")
    for (i = 1; i <= rows(L); i++) {
        if (!strpos(L[i], "<path") & !strpos(L[i], "<line")) continue
        s = L[i]
        while ((p = strpos(s, "stroke:#")) > 0) {
            hex = strupper(substr(s, p + 8, 6))
            s = substr(s, p + 14, .)
            if (hex == "FF0000") continue
            if (substr(hex, 1, 2) == substr(hex, 3, 2) & ///
                substr(hex, 3, 2) == substr(hex, 5, 2)) continue
            dup = 0
            for (j = 1; j <= rows(cols); j++) dup = dup | (cols[j] == hex)
            if (!dup) cols = cols \ hex
        }
    }
    return(cols)
}
// For every fill in fills, the index of the nearest reference stroke colour.
// Returns the sorted set of those indices (a row vector); a fill whose nearest
// reference is not clearly nearer than the runner-up makes the result missing.
real rowvector _v190_nearest_set(string colvector fills, string colvector refs)
{
    real scalar i, j, k
    real colvector d, o
    real rowvector out
    out = J(1, 0, .)
    for (i = 1; i <= rows(fills); i++) {
        d = J(rows(refs), 1, .)
        for (j = 1; j <= rows(refs); j++) {
            d[j] = sqrt(sum((_v190_lab(fills[i]) - _v190_lab(refs[j])):^2))
        }
        o = order(d, 1)
        if (rows(refs) > 1) {
            if (d[o[2]] < 1.25 * d[o[1]]) return(J(1, 1, .))
        }
        k = o[1]
        out = out, k
    }
    return(sort(uniqrows(out')', 1))
}
// Offset of the control histogram bins from the treated histogram bins, in
// bin widths (fractional part): reads the two histogram sersets (bin midpoints,
// series "x") and the width() of the saved command line from a .gph.
real scalar _v190_hist_offset(string scalar f)
{
    string colvector L
    real scalar i, nx, w, m1, m2, off
    L = cat(f)
    nx = 0
    w = .
    m1 = .
    m2 = .
    for (i = 1; i <= rows(L); i++) {
        if (w >= . & substr(L[i], 1, 12) == "*! command: ") {
            if (regexm(L[i], "width\(([0-9.e+-]+)\)")) w = strtoreal(regexs(1))
        }
        if (regexm(L[i], "^\.name = ..x..$")) {
            nx++
            if (nx <= 2 & i + 4 <= rows(L)) {
                if (regexm(L[i+4], "^\.min = +([0-9.e+-]+)")) {
                    if (nx == 1) m1 = strtoreal(regexs(1))
                    else m2 = strtoreal(regexs(1))
                }
            }
        }
    }
    if (w >= . | m1 >= . | m2 >= .) return(.)
    off = abs(m1 - m2) / w
    return(abs(off - round(off)))
}
end

capture program drop _v190_binary
program define _v190_binary
    clear
    set seed 190
    set obs 800
    generate double age = rnormal(50, 10)
    label variable age "Age in years"
    generate byte female = runiform() < .5
    label variable female "Female sex"
    generate double bmi = rnormal(27, 4)
    generate double ps = invlogit(-3 + .05 * age + .3 * female)
    generate byte t = runiform() < ps
    generate double w = cond(t, 1 / ps, 1 / (1 - ps))
end

capture program drop _v190_multigroup
program define _v190_multigroup
    clear
    set seed 191
    set obs 900
    generate double age = rnormal(50, 10)
    generate byte female = runiform() < .5
    generate double u = runiform() + .002 * (age - 50)
    generate byte arm = 1 + (u > 1/3) + (u > 2/3)
    drop u
    label define v190arm 1 "Placebo" 2 "Low dose" 3 "High dose"
    label values arm v190arm
    quietly mlogit arm age female
    quietly predict double p1 p2 p3, pr
end

**# 1. Binary histogram bins are aligned across arms
capture noisily {
    _v190_binary
    graph drop _all
    quietly psdash overlap t ps, histogram bins(25) name(v190_h) scheme(`sch')
    graph save v190_h "`gph'", replace
    mata: st_numscalar("v190_off", _v190_hist_offset("`gph'"))
    display "histogram bin offset (fraction of a width) = " scalar(v190_off)
    assert !missing(scalar(v190_off))
    assert scalar(v190_off) < 1e-6
    scalar drop v190_off
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' hist_bins_aligned"
}
else local ++pass

**# 2. Overlap draws a legend key for its common-support bounds
capture noisily {
    _v190_binary
    graph drop _all
    quietly psdash overlap t ps, scheme(`sch')
    quietly graph export "`svg'", replace
    mata: st_numscalar("v190_n", _v190_count_text("`svg'", "^Common support bounds$"))
    assert scalar(v190_n) == 1
    mata: st_numscalar("v190_n", _v190_count_text("`svg'", "^(Treated|Control)$"))
    assert scalar(v190_n) == 2
    scalar drop v190_n
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' support_bound_key_density"
}
else local ++pass

capture noisily {
    _v190_binary
    graph drop _all
    quietly psdash overlap t ps, histogram scheme(`sch')
    quietly graph export "`svg'", replace
    mata: st_numscalar("v190_n", _v190_count_text("`svg'", "^Common support bounds$"))
    assert scalar(v190_n) == 1
    scalar drop v190_n
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' support_bound_key_histogram"
}
else local ++pass

**# 3. The dashed key stays a dashed line inside the 2x2 dashboard
capture noisily {
    _v190_binary
    graph drop _all
    quietly psdash combined t ps, covariates(age female bmi) wvar(w) scheme(`sch')
    quietly graph export "`svg'", name(psdash_combined) replace
    mata: st_numscalar("v190_k", _v190_key_dashes("`svg'", "Common support bounds"))
    display "dashes in the dashboard support key (min over panels) = " scalar(v190_k)
    assert scalar(v190_k) >= 3
    scalar drop v190_k
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' dash_key_dashboard"
}
else local ++pass

* standalone support graph keeps a readable key too
capture noisily {
    _v190_binary
    graph drop _all
    quietly psdash support t ps, scheme(`sch')
    quietly graph export "`svg'", replace
    mata: st_numscalar("v190_k", _v190_key_dashes("`svg'", "Common support bounds"))
    assert scalar(v190_k) >= 3
    scalar drop v190_k
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' dash_key_support_standalone"
}
else local ++pass

**# 4. Multi-group box plots use the canonical level -> pstyle colours
* Reference: a plain line graph with the first four styles _psdash_pstyles
* returns for the test scheme gives the colour of each style. Box fills are
* those colours at reduced intensity, so each fill is matched to its nearest
* reference colour; the canonical mapping is exactly reference indexes 1, 2, 3.
capture noisily {
    clear
    set obs 20
    generate double x = _n
    generate double y1 = _n
    generate double y2 = _n + 1
    generate double y3 = _n + 2
    generate double y4 = _n + 3
    graph drop _all
    _psdash_pstyles, scheme(`sch')
    tokenize "`s(order)'"
    quietly twoway (line y1 x, pstyle(p`1')) (line y2 x, pstyle(p`2')) ///
        (line y3 x, pstyle(p`3')) (line y4 x, pstyle(p`4')), ///
        scheme(`sch') name(v190_ref)
    quietly graph export "`svg'", name(v190_ref) replace
    mata: v190_refs = _v190_ref_strokes("`svg'")
    mata: st_numscalar("v190_nref", rows(v190_refs))
    assert scalar(v190_nref) == 4
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' mg_colour_reference"
}
else local ++pass

capture noisily {
    _v190_multigroup
    graph drop _all
    quietly psdash overlap arm, psvars(p1 p2 p3) compact scheme(`sch')
    quietly graph export "`svg'", replace
    mata: v190_fl = _v190_fills("`svg'")
    mata: st_matrix("v190_set", _v190_nearest_set(v190_fl, v190_refs))
    matrix list v190_set
    assert colsof(v190_set) == 3
    assert v190_set[1,1] == 1 & v190_set[1,2] == 2 & v190_set[1,3] == 3
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' mg_box_overlap_canonical"
}
else local ++pass

capture noisily {
    _v190_multigroup
    graph drop _all
    quietly psdash support arm, psvars(p1 p2 p3) compact scheme(`sch')
    quietly graph export "`svg'", replace
    mata: v190_fl = _v190_fills("`svg'")
    mata: st_matrix("v190_set", _v190_nearest_set(v190_fl, v190_refs))
    matrix list v190_set
    assert colsof(v190_set) == 3
    assert v190_set[1,1] == 1 & v190_set[1,2] == 2 & v190_set[1,3] == 3
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' mg_box_support_canonical"
}
else local ++pass

**# 5. The multi-group gpsfloor line is explained
* box plots: a note names the line and the actual floor value
capture noisily {
    _v190_multigroup
    graph drop _all
    quietly psdash overlap arm, psvars(p1 p2 p3) compact scheme(`sch')
    quietly graph export "`svg'", replace
    mata: st_numscalar("v190_n", _v190_count_text("`svg'", "positivity floor \(0\.01\)"))
    assert scalar(v190_n) == 1
    graph drop _all
    quietly psdash overlap arm, psvars(p1 p2 p3) compact gpsfloor(.05) scheme(`sch')
    quietly graph export "`svg'", replace
    mata: st_numscalar("v190_n", _v190_count_text("`svg'", "positivity floor \(0\.05\)"))
    assert scalar(v190_n) == 1
    scalar drop v190_n
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' mg_floor_note_overlap_box"
}
else local ++pass

capture noisily {
    _v190_multigroup
    graph drop _all
    quietly psdash support arm, psvars(p1 p2 p3) compact gpsfloor(.02) scheme(`sch')
    quietly graph export "`svg'", replace
    mata: st_numscalar("v190_n", _v190_count_text("`svg'", "positivity floor \(0\.02\)"))
    assert scalar(v190_n) == 1
    scalar drop v190_n
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' mg_floor_note_support_box"
}
else local ++pass

* density panels: a legend key appears exactly when a panel draws the line
capture noisily {
    _v190_multigroup
    graph drop _all
    quietly psdash overlap arm, psvars(p1 p2 p3) gpsfloor(.3) scheme(`sch')
    quietly graph export "`svg'", replace
    mata: st_numscalar("v190_n", _v190_count_text("`svg'", "^Practical positivity floor \(0\.3\)$"))
    assert scalar(v190_n) == 1
    * default floor 0.01 lies outside every component's range: no phantom key
    graph drop _all
    quietly psdash overlap arm, psvars(p1 p2 p3) scheme(`sch')
    quietly graph export "`svg'", replace
    mata: st_numscalar("v190_n", _v190_count_text("`svg'", "positivity floor"))
    assert scalar(v190_n) == 0
    scalar drop v190_n
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' mg_floor_key_density"
}
else local ++pass

**# 6. Multi-group box plots keep Stata's default tick-label format
capture noisily {
    _v190_multigroup
    graph drop _all
    quietly psdash overlap arm, psvars(p1 p2 p3) compact scheme(`sch')
    quietly graph export "`svg'", replace
    * forced %3.1f printed 0.0 0.2 ... 1.0; the default prints 0 .2 ... 1
    mata: st_numscalar("v190_n", _v190_count_text("`svg'", "^[01]\.[0-9]+$"))
    assert scalar(v190_n) == 0
    graph drop _all
    quietly psdash support arm, psvars(p1 p2 p3) compact scheme(`sch')
    quietly graph export "`svg'", replace
    mata: st_numscalar("v190_n", _v190_count_text("`svg'", "^[01]\.[0-9]+$"))
    assert scalar(v190_n) == 0
    scalar drop v190_n
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' mg_box_default_ticks"
}
else local ++pass

**# 7. Multi-group overlap: one shared legend, readable text
capture noisily {
    _v190_multigroup
    foreach h in "" "histogram" {
        graph drop _all
        quietly psdash overlap arm, psvars(p1 p2 p3) `h' scheme(`sch')
        quietly graph export "`svg'", replace
        * the group label is a legend key only (panel titles read Pr(A=. | X))
        mata: st_numscalar("v190_n", _v190_count_text("`svg'", "^Placebo$"))
        assert scalar(v190_n) == 1
        mata: st_numscalar("v190_n", _v190_count_text("`svg'", "^Pr\(A=(Placebo|Low dose|High dose) \| X\)$"))
        assert scalar(v190_n) == 3
    }
    scalar drop v190_n
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' mg_density_one_legend"
}
else local ++pass

capture noisily {
    _v190_multigroup
    foreach h in "" "histogram" {
        graph drop _all
        quietly psdash overlap arm, psvars(p1 p2 p3) `h' scheme(`sch')
        quietly graph export "`svg'", replace
        mata: st_numscalar("v190_r", _v190_min_fs_ratio("`svg'"))
        display "smallest text / canvas width (`h') = " scalar(v190_r)
        assert !missing(scalar(v190_r))
        * forced vsmall legend text on a 12-inch canvas gave about 0.007
        assert scalar(v190_r) >= .0095
    }
    scalar drop v190_r
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' mg_density_text_size"
}
else local ++pass

* two rows of panels (5 arms): text is rescaled so it stays as large as in the
* one-row layout, and the legend panel holds the floor key on a second row
capture noisily {
    clear
    set seed 195
    set obs 1500
    generate double x = rnormal()
    generate double u = runiform()
    generate byte arm = 1 + (u > .2) + (u > .4) + (u > .6) + (u > .8)
    quietly mlogit arm x
    quietly predict double q1 q2 q3 q4 q5, pr
    graph drop _all
    quietly psdash overlap arm, psvars(q1 q2 q3 q4 q5) gpsfloor(.2) name(v190_k5) scheme(`sch')
    graph dir
    assert trim("`r(list)'") == "v190_k5"
    quietly graph export "`svg'", name(v190_k5) replace
    mata: st_numscalar("v190_r", _v190_min_fs_ratio("`svg'"))
    display "smallest text / canvas width (5 arms) = " scalar(v190_r)
    assert scalar(v190_r) >= .0095
    mata: st_numscalar("v190_n", _v190_count_text("`svg'", "^Practical positivity floor \(0\.2\)$"))
    assert scalar(v190_n) == 1
    mata: st_numscalar("v190_n", _v190_count_text("`svg'", "^Pr\(A=[1-5] \| X\)$"))
    assert scalar(v190_n) == 5
    scalar drop v190_r v190_n
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' mg_density_five_arms_layout"
}
else local ++pass

**# 8. No helper graphs leak into the session
capture noisily {
    _v190_multigroup
    graph drop _all
    quietly psdash overlap arm, psvars(p1 p2 p3) name(v190_keep) scheme(`sch')
    graph dir
    assert trim("`r(list)'") == "v190_keep"
    graph drop _all
    quietly psdash overlap arm, psvars(p1 p2 p3) compact name(v190_keep2) scheme(`sch')
    graph dir
    assert trim("`r(list)'") == "v190_keep2"
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' no_leaked_graphs"
}
else local ++pass

**# 9. Arm colours follow the scheme's own order unless p2 sits next to p1
* Categorical schemes give p1, p2, p3 (white_tableau: blue, orange, green);
* sequential schemes, where p1 and p2 are within CIE76 30, keep p1, p6, p2.
capture noisily {
    _psdash_pstyles, scheme(s2color)
    assert substr("`s(order)'", 1, 5) == "1 2 3"
    _psdash_pstyles, scheme(s1mono)
    assert substr("`s(order)'", 1, 5) == "1 6 2"
    if "`sch'" == "white_tableau" {
        _psdash_pstyles, scheme(white_tableau)
        assert substr("`s(order)'", 1, 5) == "1 2 3"
        assert real("`s(de12)'") > 100 & !missing(real("`s(de12)'"))
        foreach q in white_viridis white_cividis ukraine white_piyg {
            _psdash_pstyles, scheme(`q')
            assert substr("`s(order)'", 1, 5) == "1 6 2"
            assert real("`s(de12)'") < 30
        }
        * a scheme given inside graphoptions() is the one that counts
        _psdash_pstyles, graphopts(xtitle("x") scheme(white_viridis))
        assert substr("`s(order)'", 1, 5) == "1 6 2"
    }
    * the helper leaves r() and the graph list untouched
    clear
    set obs 5
    generate double z = _n
    graph drop _all
    quietly summarize z
    _psdash_pstyles, scheme(s2color)
    assert r(N) == 5 & r(mean) == 3
    quietly graph dir
    assert strtrim(`"`r(list)'"') == ""

    * the binary graphs draw control in the second style of that order
    _v190_binary
    graph drop _all
    quietly psdash overlap t ps, scheme(s2color) name(v190_col_a)
    graph describe v190_col_a
    assert strpos(`"`r(command)'"', "pstyle(p2)") > 0
    assert strpos(`"`r(command)'"', "pstyle(p6)") == 0
    if "`sch'" == "white_tableau" {
        quietly psdash support t ps, scheme(white_viridis) name(v190_col_b)
        graph describe v190_col_b
        assert strpos(`"`r(command)'"', "pstyle(p6)") > 0
        assert strpos(`"`r(command)'"', "pstyle(p2)") == 0
        * the weights histogram, Love plot, and strategies overlay follow suit
        foreach q in s2color white_viridis {
            local want = cond("`q'" == "s2color", "p2", "p6")
            local avoid = cond("`q'" == "s2color", "p6", "p2")
            graph drop _all
            quietly psdash weights t ps, wvar(w) graph scheme(`q') name(v190_col_w)
            graph describe v190_col_w
            assert strpos(`"`r(command)'"', "pstyle(`want')") > 0
            assert strpos(`"`r(command)'"', "pstyle(`avoid')") == 0
            quietly psdash balance t ps, covariates(age female bmi) wvar(w) ///
                loveplot scheme(`q') name(v190_col_l)
            graph describe v190_col_l
            assert strpos(`"`r(command)'"', "pstyle(`want')") > 0
            assert strpos(`"`r(command)'"', "pstyle(`avoid')") == 0
            quietly psdash balance t ps, covariates(age female bmi) ///
                strategies(raw ate att) scheme(`q') name(v190_col_s)
            graph describe v190_col_s
            assert strpos(`"`r(command)'"', "pstyle(`want')") > 0
        }
    }
    graph drop _all
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' arm_colours_adaptive"
}
else local ++pass

**# fix 4: horizontal y tick labels (vertical ones collided with the y title
**#        under s2color/s1mono) on the binary overlap and support graphs
capture noisily {
    _v190_binary
    graph drop _all
    foreach h in "" "histogram" {
        quietly psdash overlap t ps, `h' name(v190_ya) scheme(s2color)
        graph describe v190_ya
        assert strpos(`"`r(command)'"', "angle(horizontal)") > 0
    }
    quietly psdash support t ps, name(v190_yb) scheme(s1mono)
    graph describe v190_yb
    assert strpos(`"`r(command)'"', "angle(horizontal)") > 0
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' binary_ylabels_horizontal"
}
else local ++pass

**# fix 4: clustered minimum-GPS boxes (many arms) get round labels from 0, and
**#        a long legend wraps (the automatic labels crowded the top of the axis)
capture noisily {
    clear
    set seed 5
    set obs 1500
    generate double x1 = rnormal()
    generate double x2 = rnormal()
    generate byte arm = 1 + floor(5 * runiform())
    label define v190a5 1 `"A "one""' 2 "B & two" 3 "C, three" 4 "D'four" 5 "E five"
    label values arm v190a5
    quietly mlogit arm x1 x2
    quietly predict double q1 q2 q3 q4 q5, pr
    egen double mg = rowmin(q1 q2 q3 q4 q5)
    quietly summarize mg
    local mgmax = r(max)
    local mgmin = r(min)
    assert `mgmin' > .1
    graph drop _all
    quietly psdash support arm, psvars(q1 q2 q3 q4 q5) compact name(v190_bx) scheme(`sch')
    graph describe v190_bx
    local cmd `"`r(command)'"'
    assert regexm(`"`cmd'"', "ylabel\(([0-9. ]+), angle\(horizontal\)")
    local labs = strtrim(regexs(1))
    local nl : word count `labs'
    local first : word 1 of `labs'
    local last : word `nl' of `labs'
    assert real("`first'") == 0
    assert `nl' >= 3 & `nl' <= 6
    assert real("`last'") >= `mgmax'
    assert strpos(`"`cmd'"', "rows(2)") > 0
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' mg_support_box_round_labels"
}
else local ++pass

graph drop _all
display "RESULT: test_v190_overlap_support_graphs tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' display as error "Failed:`failed'"
_psdash_qa_cleanup
log close
if `fail' exit 1
