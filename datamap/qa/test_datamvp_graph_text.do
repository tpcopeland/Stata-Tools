* test_datamvp_graph_text.do: datamvp graph text as rendered
* title() and subtitle() in every graph type (plain, compound, embedded
* quotes, macro-built hostile text, several lines, unquoted, empty),
* varlabels on bar/matrix/correlation axes and keys, and gby() value
* labels kept literally, bar order, and title()/subtitle() suboptions
* (size, colour, position, ring, span) checked against the native option
* passed through graphoptions().  Every check reads the <text> elements of
* an exported SVG, so a title drawn with its own quote characters or with
* its suboptions as text fails.
* Self-contained: generates its own data.

clear all
set more off
version 16.0

**# Bootstrap
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall datamap
net install datamap, from("`pkg_dir'/") replace force

local test_count = 0
local pass_count = 0
local fail_count = 0

capture mata: mata drop _gt_svg_texts()
capture mata: mata drop _gt_svg_tags()
capture mata: mata drop _gt_tag_of()
capture mata: mata drop _gt_ys()
capture mata: mata drop _gt_nearest()
capture mata: mata drop _gt_nsubopt()
capture mata: mata drop _gt_count()
capture mata: mata drop _gt_nquoted()
mata:
// Decoded contents of every <text> element of an SVG file
string colvector _gt_svg_texts(string scalar path)
{
    return(_gt_svg_tags(path)[., 2])
}

// Opening tag (column 1) and decoded contents (column 2) of every <text>
string matrix _gt_svg_tags(string scalar path)
{
    real scalar fh, p, q
    string scalar all, line, piece, tag
    string matrix out

    fh = fopen(path, "r")
    all = ""
    while ((line = fget(fh)) != J(0, 0, "")) all = all + line + " "
    fclose(fh)
    out = J(0, 2, "")
    while ((p = strpos(all, "<text")) > 0) {
        all = substr(all, p, .)
        q = strpos(all, ">")
        tag = substr(all, 1, q)
        all = substr(all, q + 1, .)
        q = strpos(all, "</text>")
        if (q == 0) break
        piece = substr(all, 1, q - 1)
        all = substr(all, q + 7, .)
        piece = subinstr(piece, "&quot;", char(34))
        piece = subinstr(piece, "&apos;", char(39))
        piece = subinstr(piece, "&#39;", char(39))
        piece = subinstr(piece, "&#36;", char(36))
        piece = subinstr(piece, "&#96;", char(96))
        piece = subinstr(piece, "&lt;", "<")
        piece = subinstr(piece, "&gt;", ">")
        piece = subinstr(piece, "&amp;", "&")
        out = out \ (tag, piece)
    }
    return(out)
}

// Opening tags of the elements whose text equals want, joined
string scalar _gt_tag_of(string scalar path, string scalar want)
{
    string matrix t
    string scalar out
    real scalar i

    t = _gt_svg_tags(path)
    out = ""
    for (i = 1; i <= rows(t); i++) {
        if (t[i, 2] == want) out = out + t[i, 1]
    }
    return(out)
}

// y coordinates of the elements whose text equals want
real colvector _gt_ys(string scalar path, string scalar want)
{
    string matrix t
    real colvector out
    real scalar i, p

    t = _gt_svg_tags(path)
    out = J(0, 1, .)
    for (i = 1; i <= rows(t); i++) {
        if (t[i, 2] != want) continue
        p = strpos(t[i, 1], " y=" + char(34))
        out = out \ strtoreal(substr(t[i, 1], p + 4,
            strpos(substr(t[i, 1], p + 4, .), char(34)) - 1))
    }
    return(out)
}

// Text of the bar label (a number with a decimal point) nearest to y
string scalar _gt_nearest(string scalar path, real scalar y)
{
    string matrix t
    string scalar best
    real scalar i, p, yy, d

    t = _gt_svg_tags(path)
    best = ""
    d = .
    for (i = 1; i <= rows(t); i++) {
        if (!regexm(t[i, 2], "^[0-9]+[.][0-9]$")) continue
        p = strpos(t[i, 1], " y=" + char(34))
        yy = strtoreal(substr(t[i, 1], p + 4,
            strpos(substr(t[i, 1], p + 4, .), char(34)) - 1))
        if (abs(yy - y) < d) {
            d = abs(yy - y)
            best = t[i, 2]
        }
    }
    return(best)
}

// Number of elements whose text shows a title suboption as literal text
real scalar _gt_nsubopt(string scalar path)
{
    string colvector t
    real scalar i, k

    t = _gt_svg_texts(path)
    k = 0
    for (i = 1; i <= rows(t); i++) {
        k = k + regexm(t[i], "(size|color|position|ring)[(]|, *span|span size")
    }
    return(k)
}

// Number of text elements exactly equal to want
real scalar _gt_count(string scalar path, string scalar want)
{
    return(sum(_gt_svg_texts(path) :== want))
}

// Number of text elements wrapped in a literal pair of double quotes
real scalar _gt_nquoted(string scalar path)
{
    string colvector t
    real scalar i, n, k

    t = _gt_svg_texts(path)
    k = 0
    for (i = 1; i <= rows(t); i++) {
        n = strlen(t[i])
        if (n >= 2 & substr(t[i], 1, 1) == char(34) &
            substr(t[i], n, 1) == char(34)) k++
    }
    return(k)
}
end

* Export a named graph as SVG to the path in local svg
capture program drop _gt_export
program define _gt_export
    args gname path
    quietly graph export "`path'", name(`gname') as(svg) replace
end

**# Test data
quietly {
    clear
    set obs 60
    gen double x1 = _n
    gen double x2 = _n
    gen double x3 = _n
    gen double x4 = _n
    replace x1 = . if mod(_n, 4) == 0
    replace x2 = . if mod(_n, 5) == 0
    replace x3 = . if mod(_n, 3) == 0
    replace x4 = . if mod(_n, 6) == 0 | mod(_n, 4) == 0
    label var x1 "Biomarker A"
    label var x2 "Biomarker B"
    label var x3 "Biomarker C"
    gen byte arm = mod(_n, 2)
    label define gt_arm 0 "Control" 1 "Treated"
    label values arm gt_arm
    tempfile gtdata
    save `gtdata', replace
}
tempfile svgbase svgbase2
local svg "`svgbase'.svg"
local svg2 "`svgbase2'.svg"

**# T1: a plain quoted title() and subtitle() are drawn without quote marks
local ++test_count
capture noisily {
    use `gtdata', clear
    datamvp x1 x2 x3 x4, graph(bar) title("Missingness by variable") ///
        subtitle("Plain subtitle") gname(gt1)
    _gt_export gt1 "`svg'"
    mata: st_numscalar("__gt_a", _gt_count(st_local("svg"), "Missingness by variable"))
    mata: st_numscalar("__gt_b", _gt_count(st_local("svg"), "Plain subtitle"))
    mata: st_numscalar("__gt_q", _gt_nquoted(st_local("svg")))
    assert scalar(__gt_a) == 1
    assert scalar(__gt_b) == 1
    assert scalar(__gt_q) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS T1: plain quoted title() and subtitle() drawn without quote marks"
}
else {
    local ++fail_count
    display as error "  FAIL T1: plain quoted title() and subtitle() drawn without quote marks"
}

**# T2: compound quotes with embedded quotes keep only the inner quotes
* guard: expected green at pre-fix ref (1.9.3 stripped compound quotes)
local ++test_count
capture noisily {
    use `gtdata', clear
    datamvp x1 x2 x3 x4, graph(bar) title(`"Say "hi" now"') ///
        subtitle(`"plain compound"') gname(gt2)
    _gt_export gt2 "`svg'"
    local want = "Say " + char(34) + "hi" + char(34) + " now"
    mata: st_numscalar("__gt_a", _gt_count(st_local("svg"), st_local("want")))
    mata: st_numscalar("__gt_b", _gt_count(st_local("svg"), "plain compound"))
    mata: st_numscalar("__gt_q", _gt_nquoted(st_local("svg")))
    assert scalar(__gt_a) == 1
    assert scalar(__gt_b) == 1
    assert scalar(__gt_q) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS T2: compound-quoted title with embedded quotes"
}
else {
    local ++fail_count
    display as error "  FAIL T2: compound-quoted title with embedded quotes"
}

**# T3: macro-built text with $, `, and quotes prints literally
local ++test_count
capture noisily {
    use `gtdata', clear
    local t1 = "Cost " + char(34) + "q" + char(34) + " " + char(36) + ///
        "UNSET " + char(96) + "tick"
    local t2 = "Dollar " + char(36) + "X and " + char(96) + "y"
    datamvp x1 x2 x3 x4, graph(bar) title(`"`macval(t1)'"') ///
        subtitle("`macval(t2)'") gname(gt3)
    _gt_export gt3 "`svg'"
    mata: st_numscalar("__gt_a", _gt_count(st_local("svg"), st_local("t1")))
    mata: st_numscalar("__gt_b", _gt_count(st_local("svg"), st_local("t2")))
    assert scalar(__gt_a) == 1
    assert scalar(__gt_b) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS T3: macro-built hostile title text"
}
else {
    local ++fail_count
    display as error "  FAIL T3: macro-built hostile title text"
}

**# T4: several quoted strings are several lines; unquoted text is one line
local ++test_count
capture noisily {
    use `gtdata', clear
    datamvp x1 x2 x3 x4, graph(bar) title("Line one" `"Line "two""') ///
        subtitle(Unquoted words here) gname(gt4)
    _gt_export gt4 "`svg'"
    local want = "Line " + char(34) + "two" + char(34)
    mata: st_numscalar("__gt_a", _gt_count(st_local("svg"), "Line one"))
    mata: st_numscalar("__gt_b", _gt_count(st_local("svg"), st_local("want")))
    mata: st_numscalar("__gt_c", _gt_count(st_local("svg"), "Unquoted words here"))
    mata: st_numscalar("__gt_q", _gt_nquoted(st_local("svg")))
    assert scalar(__gt_a) == 1
    assert scalar(__gt_b) == 1
    assert scalar(__gt_c) == 1
    assert scalar(__gt_q) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS T4: multi-line and unquoted titles"
}
else {
    local ++fail_count
    display as error "  FAIL T4: multi-line and unquoted titles"
}

**# T5: title("") suppresses the default title and draws no quote marks
local ++test_count
capture noisily {
    use `gtdata', clear
    datamvp x1 x2 x3 x4, graph(bar) title("") gname(gt5)
    _gt_export gt5 "`svg'"
    mata: st_numscalar("__gt_a", _gt_count(st_local("svg"), "Missing Values by Variable"))
    mata: st_numscalar("__gt_e", _gt_count(st_local("svg"), char(34) + char(34)))
    assert scalar(__gt_a) == 0
    assert scalar(__gt_e) == 0
    datamvp x1 x2 x3 x4, graph(bar) gname(gt5b)
    _gt_export gt5b "`svg'"
    mata: st_numscalar("__gt_a", _gt_count(st_local("svg"), "Missing Values by Variable"))
    assert scalar(__gt_a) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS T5: empty title and default title"
}
else {
    local ++fail_count
    display as error "  FAIL T5: empty title and default title"
}

**# T6: every graph type draws title() and subtitle() without quote marks
local ++test_count
capture noisily {
    local specs `" "bar" "bar gby(arm)" "bar over(arm)" "bar stacked" "patterns" "patterns gby(arm)" "matrix" "correlation" "'
    local k = 0
    foreach spec of local specs {
        local ++k
        gettoken gtype gopts : spec
        display as text "  graph(`spec')"
        use `gtdata', clear
        local t = "Title " + char(34) + "`k'" + char(34)
        datamvp x1 x2 x3 x4, graph(`gtype') `gopts' ///
            title(`"`macval(t)'"') subtitle("Subtitle `k'") gname(gt6_`k')
        _gt_export gt6_`k' "`svg'"
        mata: st_numscalar("__gt_a", _gt_count(st_local("svg"), st_local("t")))
        mata: st_numscalar("__gt_b", _gt_count(st_local("svg"), "Subtitle `k'"))
        mata: st_numscalar("__gt_q", _gt_nquoted(st_local("svg")))
        * under gby() the title belongs to by() and is drawn once
        assert scalar(__gt_a) == 1
        assert scalar(__gt_b) == 1
        assert scalar(__gt_q) == 0
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS T6: title()/subtitle() in all eight graph forms"
}
else {
    local ++fail_count
    display as error "  FAIL T6: title()/subtitle() in one of the eight graph forms"
}

**# T7: varlabels puts variable labels on bar axes; names are the default
local ++test_count
capture noisily {
    use `gtdata', clear
    datamvp x1 x2 x3 x4, graph(bar) gname(gt7a)
    _gt_export gt7a "`svg'"
    mata: st_numscalar("__gt_a", _gt_count(st_local("svg"), "x1"))
    mata: st_numscalar("__gt_b", _gt_count(st_local("svg"), "Biomarker A"))
    assert scalar(__gt_a) == 1
    assert scalar(__gt_b) == 0

    datamvp x1 x2 x3 x4, graph(bar) varlabels gname(gt7b)
    _gt_export gt7b "`svg'"
    foreach w in "Biomarker A" "Biomarker B" "Biomarker C" "x4" {
        mata: st_numscalar("__gt_a", _gt_count(st_local("svg"), "`w'"))
        assert scalar(__gt_a) == 1
    }
    mata: st_numscalar("__gt_a", _gt_count(st_local("svg"), "x1"))
    assert scalar(__gt_a) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS T7: varlabels on the bar axis"
}
else {
    local ++fail_count
    display as error "  FAIL T7: varlabels on the bar axis"
}

**# T8: varlabels keeps hostile and duplicate labels as separate literal bars
local ++test_count
capture noisily {
    use `gtdata', clear
    local hl = "Cost " + char(34) + "q" + char(34) + " " + char(36) + ///
        "UNSET " + char(96) + "tick"
    mata: st_varlabel("x1", st_local("hl"))
    label var x2 "Same"
    label var x3 "Same"
    datamvp x1 x2 x3 x4, graph(bar) varlabels gname(gt8)
    _gt_export gt8 "`svg'"
    mata: st_numscalar("__gt_a", _gt_count(st_local("svg"), st_local("hl")))
    mata: st_numscalar("__gt_b", _gt_count(st_local("svg"), "Same"))
    assert scalar(__gt_a) == 1
    assert scalar(__gt_b) == 2
    * four bars, value labels in the bar order x1..x4 (top to bottom), each
    * beside its own bar: x1 25.0, x2 20.0, x3 33.3, x4 33.3 percent missing
    mata: st_numscalar("__gt_c", _gt_count(st_local("svg"), "x4"))
    assert scalar(__gt_c) == 1
    mata: __gt_y1 = _gt_ys(st_local("svg"), st_local("hl"))
    mata: __gt_y23 = sort(_gt_ys(st_local("svg"), "Same"), 1)
    mata: __gt_y4 = _gt_ys(st_local("svg"), "x4")
    mata: st_numscalar("__gt_a", __gt_y1 < __gt_y23[1] & ///
        __gt_y23[1] < __gt_y23[2] & __gt_y23[2] < __gt_y4)
    assert scalar(__gt_a) == 1
    mata: st_local("near1", _gt_nearest(st_local("svg"), __gt_y1))
    mata: st_local("near2", _gt_nearest(st_local("svg"), __gt_y23[1]))
    mata: st_local("near3", _gt_nearest(st_local("svg"), __gt_y23[2]))
    mata: st_local("near4", _gt_nearest(st_local("svg"), __gt_y4))
    assert "`near1'" == "25.0" & "`near2'" == "20.0"
    assert "`near3'" == "33.3" & "`near4'" == "33.3"
    mata: mata drop __gt_y1 __gt_y23 __gt_y4
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS T8: hostile and duplicate variable labels, in bar order"
}
else {
    local ++fail_count
    display as error "  FAIL T8: hostile and duplicate variable labels, in bar order"
}

**# T9: varlabels in gby(), over(), stacked, matrix, and correlation, untruncated
local ++test_count
capture noisily {
    local vspecs `" "bar gby(arm)" "bar over(arm)" "bar stacked" "matrix" "correlation" "'
    foreach spec of local vspecs {
        gettoken gtype gopts : spec
        display as text "  graph(`spec')"
        use `gtdata', clear
        * a hostile label that escapes to more than 32 characters
        local hl = "Cost " + char(34) + "q" + char(34) + " " + char(36) + ///
            "UNSET " + char(96) + "tick, long label"
        mata: st_varlabel("x1", st_local("hl"))
        datamvp x1 x2 x3 x4, graph(`gtype') `gopts' varlabels gname(gt9)
        _gt_export gt9 "`svg'"
        mata: st_numscalar("__gt_a", _gt_count(st_local("svg"), st_local("hl")))
        mata: st_numscalar("__gt_b", _gt_count(st_local("svg"), "x1"))
        mata: st_numscalar("__gt_c", _gt_count(st_local("svg"), "x4"))
        assert scalar(__gt_a) >= 1
        assert scalar(__gt_b) == 0
        assert scalar(__gt_c) >= 1
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS T9: varlabels in gby(), over(), stacked, matrix, correlation"
}
else {
    local ++fail_count
    display as error "  FAIL T9: varlabels in one of the five graph forms"
}

**# T10: a gby() value label written with compound quotes is kept literally
local ++test_count
capture noisily {
    use `gtdata', clear
    local lab = char(96) + char(34) + "wrapped" + char(34) + char(39)
    mata: st_vlmodify("gt_arm", 1, st_local("lab"))
    datamvp x1 x2 x3 x4, graph(bar) gby(arm) gname(gt10)
    _gt_export gt10 "`svg'"
    mata: st_numscalar("__gt_a", _gt_count(st_local("svg"), st_local("lab")))
    mata: st_numscalar("__gt_b", _gt_count(st_local("svg"), "wrapped"))
    assert scalar(__gt_a) == 1
    assert scalar(__gt_b) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS T10: compound-quoted gby() value label"
}
else {
    local ++fail_count
    display as error "  FAIL T10: compound-quoted gby() value label"
}

**# T11: varlabels is refused without a graph and with graph(patterns)
local ++test_count
capture noisily {
    use `gtdata', clear
    capture datamvp x1 x2 x3 x4, varlabels
    assert _rc == 198
    capture datamvp x1 x2 x3 x4, graph(patterns) varlabels nodraw
    assert _rc == 198
    capture datamvp x1 x2 x3 x4, graph(bar) varl nodraw
    assert _rc == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS T11: varlabels refusals and abbreviation"
}
else {
    local ++fail_count
    display as error "  FAIL T11: varlabels refusals and abbreviation"
}

**# T12: title()/subtitle() suboptions match the native option (bar)
* Oracle: the same text with the suboptions handed to the native graph
* title()/subtitle() through graphoptions(); the drawn element (font size,
* colour, anchor, position) must be identical and no suboption printed.
local ++test_count
capture noisily {
    local cases `" `"title("a", size(large))"' `"title("a", color(red) position(7))"' `"title("a" , span)"' `"title(hello, size(huge))"' `"title("Line one" "Line two", size(large))"' `"title("a b c") subtitle("sub", span size(small))"' "'
    local natives `" `"title("a") graphoptions(title(, size(large)))"' `"title("a") graphoptions(title(, color(red) position(7)))"' `"title("a") graphoptions(title(, span))"' `"title(hello) graphoptions(title(, size(huge)))"' `"title("Line one" "Line two") graphoptions(title(, size(large)))"' `"title("a b c") subtitle("sub") graphoptions(subtitle(, span size(small)))"' "'
    local wants `" "a" "a" "a" "hello" "Line two" "sub" "'
    local k = 0
    foreach c of local cases {
        local ++k
        local nat : word `k' of `natives'
        local want : word `k' of `wants'
        display as text `"  case `k': `c'"'
        use `gtdata', clear
        datamvp x1 x2 x3 x4, graph(bar) `c' gname(gt12d)
        _gt_export gt12d "`svg'"
        datamvp x1 x2 x3 x4, graph(bar) `nat' gname(gt12n)
        _gt_export gt12n "`svg2'"
        mata: st_local("tagd", _gt_tag_of(st_local("svg"), st_local("want")))
        mata: st_local("tagn", _gt_tag_of(st_local("svg2"), st_local("want")))
        mata: st_numscalar("__gt_s", _gt_nsubopt(st_local("svg")))
        assert `"`tagd'"' != ""
        assert `"`tagd'"' == `"`tagn'"'
        assert scalar(__gt_s) == 0
        graph drop gt12d gt12n
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS T12: title()/subtitle() suboptions match native on graph(bar)"
}
else {
    local ++fail_count
    display as error "  FAIL T12: title()/subtitle() suboptions match native on graph(bar)"
}

**# T13: suboptions with no text restyle the default title, never print
local ++test_count
capture noisily {
    use `gtdata', clear
    datamvp x1 x2 x3 x4, graph(bar) title(, ring(0) color(red)) ///
        subtitle(, size(vlarge)) gname(gt13d)
    _gt_export gt13d "`svg'"
    datamvp x1 x2 x3 x4, graph(bar) gname(gt13n) ///
        graphoptions(title(, ring(0) color(red)) subtitle(, size(vlarge)))
    _gt_export gt13n "`svg2'"
    local want "Missing Values by Variable"
    mata: st_local("tagd", _gt_tag_of(st_local("svg"), st_local("want")))
    mata: st_local("tagn", _gt_tag_of(st_local("svg2"), st_local("want")))
    mata: st_numscalar("__gt_s", _gt_nsubopt(st_local("svg")))
    mata: st_numscalar("__gt_c", _gt_count(st_local("svg"), ","))
    assert `"`tagd'"' != ""
    assert `"`tagd'"' == `"`tagn'"'
    assert scalar(__gt_s) == 0 & scalar(__gt_c) == 0
    assert strpos(`"`tagd'"', "#FF0000")

    * faceted graphs: the default title is drawn once, restyled
    foreach spec in "bar gby(arm)" "patterns gby(arm)" {
        gettoken gtype gopts : spec
        display as text "  graph(`spec')"
        datamvp x1 x2 x3 x4, graph(`gtype') `gopts' ///
            title(, color(red)) gname(gt13g)
        _gt_export gt13g "`svg'"
        local want = cond("`gtype'" == "bar", ///
            "Missing Values by Variable and arm", "Missing Value Patterns by arm")
        mata: st_numscalar("__gt_a", _gt_count(st_local("svg"), st_local("want")))
        mata: st_local("tagd", _gt_tag_of(st_local("svg"), st_local("want")))
        mata: st_numscalar("__gt_s", _gt_nsubopt(st_local("svg")))
        assert scalar(__gt_a) == 1
        assert strpos(`"`tagd'"', "#FF0000")
        assert scalar(__gt_s) == 0
        graph drop gt13g
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS T13: suboptions without text restyle the default title"
}
else {
    local ++fail_count
    display as error "  FAIL T13: suboptions without text restyle the default title"
}

**# T14: suboptions match native on matrix, correlation, stacked, and over()
local ++test_count
capture noisily {
    foreach spec in "matrix" "correlation" "bar stacked" "bar over(arm)" "patterns" {
        gettoken gtype gopts : spec
        display as text "  graph(`spec')"
        use `gtdata', clear
        datamvp x1 x2 x3 x4, graph(`gtype') `gopts' ///
            title("T14", size(vlarge) color(red)) gname(gt14d)
        _gt_export gt14d "`svg'"
        datamvp x1 x2 x3 x4, graph(`gtype') `gopts' title("T14") ///
            graphoptions(title(, size(vlarge) color(red))) gname(gt14n)
        _gt_export gt14n "`svg2'"
        mata: st_local("tagd", _gt_tag_of(st_local("svg"), "T14"))
        mata: st_local("tagn", _gt_tag_of(st_local("svg2"), "T14"))
        mata: st_numscalar("__gt_s", _gt_nsubopt(st_local("svg")))
        assert `"`tagd'"' != ""
        assert `"`tagd'"' == `"`tagn'"'
        assert scalar(__gt_s) == 0
        graph drop gt14d gt14n
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS T14: suboptions match native on five more graph forms"
}
else {
    local ++fail_count
    display as error "  FAIL T14: suboptions match native on five more graph forms"
}

**# T15: suboptions without graph() are refused like the text
* guard: expected green at pre-fix ref (the suboptions were text then)
local ++test_count
capture noisily {
    use `gtdata', clear
    capture datamvp x1 x2 x3 x4, title(, size(large))
    assert _rc == 198
    capture datamvp x1 x2 x3 x4, subtitle(, size(large))
    assert _rc == 198
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS T15: suboption-only title() refused without graph()"
}
else {
    local ++fail_count
    display as error "  FAIL T15: suboption-only title() refused without graph()"
}

capture graph drop _all
capture scalar drop __gt_a __gt_b __gt_c __gt_e __gt_q __gt_s

**# Summary
display "RESULT: test_datamvp_graph_text tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
