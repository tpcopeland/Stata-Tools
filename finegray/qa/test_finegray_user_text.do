*! test_finegray_user_text.do - value/variable labels are copied, never re-expanded as macro text
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Through 1.3.7 finegray re-expanded user label text as macro text wherever
* it carried it: the factor design columns' variable labels, the fit table's
* "Reference:" line, and finegray_cif's over() curve headers, bstrata notes
* and the value label copied into the saving() dataset (label save + run).
* A value label "A $G" came out as "A <contents of $G>", a quoted `q' pair
* vanished, and an unbalanced backtick in a level label stopped a valid fit
* with r(132) (and a replay of an earlier fit with r(132) after the table).
*
* Graph text (UT-6 to UT-12): Stata's graph commands re-expand option text
* and draw SMCL, so even with macval() at every call site an over() label
* "A $G" was drawn "A EXPANDED" in the finegray_cif legend, a `q' pair and
* {bf:x} were eaten, and an unbalanced backtick stopped the graph with r(132).
* The drawn text is read from an SVG export (the renderer's own output), and
* the stored text from the graph object and from a saved .gph re-displayed.
* A labelled level's legend key is its value label alone; only an unlabelled
* level is keyed "grp = #" (UT-10).
*
* Every expected string is built in Mata from char() codes and compared
* byte for byte; console text is read back from a text log in Mata, so the
* test itself never expands the strings it checks.  The bait global $FGUT_G
* holds EXPANDED, so a wrong expansion is visible rather than empty.

clear all
set more off
set varabbrev off
version 16.0
set linesize 255

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
capture log close _all
log using "test_finegray_user_text.log", replace text name(_test_fgut)
do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"
local plus_dir "`r(plus_dir)'"

global FGUT_G "EXPANDED"

capture program drop _fgut_data
program define _fgut_data
    clear
    set seed 290927
    set obs 500
    generate long id = _n
    generate double x = rnormal()
    generate byte grp = 1 + (runiform() < .5)
    generate double t1 = -ln(runiform()) / exp(.4 * x + .3 * (grp == 2))
    generate double t2 = -ln(runiform()) / .6
    generate double tc = -ln(runiform()) / .3
    generate double t = min(t1, t2, tc)
    generate byte status = cond(t == t1, 1, cond(t == t2, 2, 0))
    quietly stset t, failure(status == 1 2) id(id)
    * level 1: a dollar-name; level 2: a balanced local-macro quote pair
    mata: st_vlmodify("fgut_l", (1 \ 2), ("A " + char(36) + "FGUT_G" \ ///
        "B " + char(96) + "q" + char(39) + " x"))
    label values grp fgut_l
    mata: st_varlabel("x", "X lab " + char(36) + "FGUT_G")
end

* Number of lines of text file f holding the text lit.  An empty needle is
* an error, never a match: strpos(s, "") is 1 on every line.
mata:
real scalar _fgut_has(string scalar f, string scalar lit)
{
    if (lit == "") _error(3498, "_fgut_has: empty search text")
    return(sum(strpos(cat(f), lit) :> 0))
}
end

**# UT-1 factor design-column labels carry the value and variable labels verbatim
local ++test_count
capture noisily {
    _fgut_data
    finegray i.grp i.grp#c.x, compete(status) cause(1) nolog
    assert "`e(designvars)'" == "_fg_grp_2 _fg_grp_1Xx _fg_grp_2Xx"
    mata: A = "A " + char(36) + "FGUT_G"; B = "B " + char(96) + "q" + char(39) + " x"; ///
        X = "X lab " + char(36) + "FGUT_G"; ///
        st_numscalar("ut1", (st_varlabel("_fg_grp_2") == B + " (vs. " + A + ")") + ///
        (st_varlabel("_fg_grp_1Xx") == A + " # " + X) + ///
        (st_varlabel("_fg_grp_2Xx") == B + " (vs. " + A + ") # " + X))
    assert scalar(ut1) == 3
}
if _rc == 0 {
    display as result "  PASS: UT-1 design-column labels are the labels, byte for byte"
    local ++pass_count
}
else {
    display as error "  FAIL: UT-1 design-column labels (rc=`=_rc')"
    local ++fail_count
}

**# UT-2 the Reference line prints the base level's label literally, fit and replay
local ++test_count
capture noisily {
    _fgut_data
    tempfile lg
    log using `"`lg'"', text replace name(_fgut2)
    finegray i.grp x, compete(status) cause(1) nolog
    finegray
    log close _fgut2
    mata: st_local("want", "Reference: i.grp: A " + char(36) + "FGUT_G (grp==1)")
    mata: st_local("bad", "A EXPANDED")
    mata: st_numscalar("fgut_n", _fgut_has(st_local("lg"), st_local("want")))
    assert !missing(scalar(fgut_n))
    assert scalar(fgut_n) >= 1
    mata: st_numscalar("fgut_n", _fgut_has(st_local("lg"), st_local("bad")))
    assert scalar(fgut_n) == 0
    mata: st_numscalar("fgut_n", _fgut_has(st_local("lg"), st_local("want")))
    assert scalar(fgut_n) == 2
}
if _rc == 0 {
    display as result "  PASS: UT-2 Reference line literal on the fit and its replay"
    local ++pass_count
}
else {
    local _urc = _rc
    capture log close _fgut2
    display as error "  FAIL: UT-2 Reference line (rc=`_urc')"
    local ++fail_count
}

**# UT-3 an unbalanced backtick in a level label does not stop a valid fit
local ++test_count
capture noisily {
    _fgut_data
    quietly finegray i.grp x, compete(status) cause(1) nolog
    tempname b0
    matrix `b0' = e(b)
    * the BASE level's label holds the backtick: it reaches the design label
    * of level 2 through "(vs. ...)" and the Reference line
    mata: st_vlmodify("fgut_l", 1, "U " + char(96) + "tick end")
    finegray i.grp x, compete(status) cause(1) nolog
    assert e(converged) == 1
    assert mreldif(e(b), `b0') == 0
    mata: st_numscalar("ut3", st_varlabel("_fg_grp_2") == ///
        "B " + char(96) + "q" + char(39) + " x (vs. U " + char(96) + "tick end)")
    assert scalar(ut3) == 1
    * replay of the same fit
    finegray
    * and the dropped-label case restores the plain level text
    label values grp
    finegray i.grp x, compete(status) cause(1) nolog
    mata: st_numscalar("ut3b", st_varlabel("_fg_grp_2") == "2 (vs. 1)")
    assert scalar(ut3b) == 1
}
if _rc == 0 {
    display as result "  PASS: UT-3 unbalanced backtick label: fit and replay rc 0, label verbatim"
    local ++pass_count
}
else {
    display as error "  FAIL: UT-3 unbalanced backtick label (rc=`=_rc')"
    local ++fail_count
}

**# UT-4 finegray_cif over(): curve headers and the saving() value label verbatim
local ++test_count
capture noisily {
    _fgut_data
    quietly finegray x grp, compete(status) cause(1) nolog
    tempfile lg sv
    log using `"`lg'"', text replace name(_fgut4)
    finegray_cif, over(grp) attime(1 2) nograph saving(`"`sv'"', replace)
    log close _fgut4
    mata: st_local("want1", "-> grp = A " + char(36) + "FGUT_G")
    mata: st_local("want2", "-> grp = B " + char(96) + "q" + char(39) + " x")
    mata: st_local("bad", "EXPANDED")
    mata: st_numscalar("fgut_n", _fgut_has(st_local("lg"), st_local("want1")))
    assert !missing(scalar(fgut_n))
    assert scalar(fgut_n) >= 1
    mata: st_numscalar("fgut_n", _fgut_has(st_local("lg"), st_local("want2")))
    assert !missing(scalar(fgut_n))
    assert scalar(fgut_n) >= 1
    mata: st_numscalar("fgut_n", _fgut_has(st_local("lg"), st_local("bad")))
    assert scalar(fgut_n) == 0
    preserve
    use `"`sv'"', clear
    local vl : value label over
    assert "`vl'" == "fgut_l"
    mata: st_vlload("fgut_l", v = ., tx = .); ///
        st_numscalar("ut4", rows(v) == 2 & v == (1 \ 2) & ///
        tx == ("A " + char(36) + "FGUT_G" \ "B " + char(96) + "q" + char(39) + " x"))
    assert scalar(ut4) == 1
    restore
}
if _rc == 0 {
    display as result "  PASS: UT-4 over() headers and saved value label verbatim"
    local ++pass_count
}
else {
    local _urc = _rc
    capture log close _fgut4
    display as error "  FAIL: UT-4 over() labels (rc=`_urc')"
    local ++fail_count
}

**# UT-5 finegray_cif over() of a bstrata() variable: the flat-tail note names the label verbatim
local ++test_count
capture noisily {
    _fgut_data
    quietly finegray x, compete(status) cause(1) nolog bstrata(grp)
    tempfile lg
    log using `"`lg'"', text replace name(_fgut5)
    finegray_cif, over(grp) attime(1 1000) nograph
    log close _fgut5
    mata: st_local("want", "(grp = A " + char(36) + "FGUT_G);")
    mata: st_local("bad", "EXPANDED")
    mata: st_numscalar("fgut_n", _fgut_has(st_local("lg"), st_local("want")))
    assert !missing(scalar(fgut_n))
    assert scalar(fgut_n) >= 1
    mata: st_numscalar("fgut_n", _fgut_has(st_local("lg"), st_local("bad")))
    assert scalar(fgut_n) == 0
}
if _rc == 0 {
    display as result "  PASS: UT-5 bstrata over() note names the stratum label verbatim"
    local ++pass_count
}
else {
    local _urc = _rc
    capture log close _fgut5
    display as error "  FAIL: UT-5 bstrata over() note (rc=`_urc')"
    local ++fail_count
}

* Three-level fixture with the hostile labels the graph tests draw: level 1
* is $name + SMCL markup + % + UTF-8, level 2 a quoted `q' pair and an
* embedded double-quoted word, level 3 an unbalanced backtick.
capture program drop _fgut_data3
program define _fgut_data3
    clear
    set seed 290929
    set obs 600
    generate long id = _n
    generate double x = rnormal()
    generate byte grp = 1 + (runiform() < .5) + (runiform() < .3)
    generate double t1 = -ln(runiform()) / exp(.4 * x + .3 * (grp == 2))
    generate double t2 = -ln(runiform()) / .6
    generate double tc = -ln(runiform()) / .3
    generate double t = min(t1, t2, tc)
    generate byte status = cond(t == t1, 1, cond(t == t2, 2, 0))
    quietly stset t, failure(status == 1 2) id(id)
    mata: st_vlmodify("fgut_h", (1 \ 2 \ 3), _fgut_hostile())
    label values grp fgut_h
end

mata:
// The three hostile labels, as raw bytes.
string colvector _fgut_hostile()
{
    return(("A " + char(36) + "FGUT_G {bf:x} }{ 50% " + char(195) + char(169) \
            "B " + char(96) + "q" + char(39) + " " + char(34) + "dq" + char(34) \
            "C " + char(96) + "tick"))
}

// The drawn text of every <text> element of an SVG file, in file order.  A
// run of mixed formatting (bold, italic) is one <text> holding several
// <tspan> lines; their contents are concatenated, so each element is the
// whole string as drawn.  The SVG writer spells spaces inside a <tspan> as
// U+00A0; they are read back as plain spaces.
string colvector _fgut_svgtext(string scalar f)
{
    string colvector L, R
    string scalar acc
    real scalar i, open
    L = cat(f)
    R = J(0, 1, "")
    open = 0
    acc = ""
    for (i = 1; i <= rows(L); i++) {
        if (ustrregexm(L[i], "<text [^>]*>(.*)</text>")) {
            R = R \ ustrregexs(1)
        }
        else if (ustrregexm(L[i], "<text [^>]*>")) {
            open = 1
            acc = ""
        }
        else if (open & ustrregexm(L[i], "<tspan[^>]*>(.*)</tspan>")) {
            acc = acc + subinstr(ustrregexs(1), char(194) + char(160), " ")
        }
        else if (open & strpos(L[i], "</text>")) {
            R = R \ acc
            open = 0
        }
    }
    return(R)
}

// Independent oracle for _finegray_graph_text: one character at a time.
string scalar _fgut_enc(string scalar raw)
{
    string scalar e, c
    real scalar k
    e = ""
    for (k = 1; k <= strlen(raw); k++) {
        c = substr(raw, k, 1)
        if (c == "{") e = e + "{c -(}"
        else if (c == "}") e = e + "{c )-}"
        else if (c == char(96)) e = e + "{c 96}"
        else if (c == char(36)) e = e + "{c 36}"
        else if (c == char(34)) e = e + "{c 34}"
        else e = e + c
    }
    return(e)
}

// 1 when every element of want occurs exactly once among the text elements
// of SVG f and no element holds the bait expansion.
real scalar _fgut_svg_has_all(string scalar f, string colvector want)
{
    string colvector T
    real scalar i
    T = _fgut_svgtext(f)
    if (rows(T) == 0) return(0)
    if (sum(strpos(T, "EXPANDED") :> 0)) return(0)
    for (i = 1; i <= rows(want); i++) {
        if (want[i] == "") _error(3498, "_fgut_svg_has_all: empty want")
        if (sum(T :== want[i]) != 1) return(0)
    }
    return(1)
}
end

**# UT-6 over() legend: $name, SMCL markup, quotes, %, UTF-8 drawn verbatim
local ++test_count
capture noisily {
    _fgut_data3
    * level 3 plain here, so an r(132) from UT-7's backtick cannot mask this
    mata: st_vlmodify("fgut_h", 3, "C plain")
    quietly finegray x i.grp, compete(status) cause(1) nolog
    tempfile sv
    graph drop _all
    finegray_cif, over(grp) ci name(fgut6)
    quietly graph export `"`sv'.svg"', name(fgut6) replace as(svg)
    mata: st_numscalar("fgut_n", _fgut_svg_has_all(st_local("sv") + ".svg", ///
        (_fgut_hostile()[1::2] \ "C plain")))
    assert scalar(fgut_n) == 1
    graph drop _all
}
if _rc == 0 {
    display as result "  PASS: UT-6 over() legend draws the labels verbatim"
    local ++pass_count
}
else {
    display as error "  FAIL: UT-6 over() legend text (rc=`=_rc')"
    local ++fail_count
}

**# UT-7 over() legend: an unbalanced backtick draws, verbatim, on both over() routes
local ++test_count
capture noisily {
    _fgut_data3
    quietly finegray x i.grp, compete(status) cause(1) nolog
    tempfile sv
    graph drop _all
    finegray_cif, over(grp) ci name(fgut7)
    quietly graph export `"`sv'.svg"', name(fgut7) replace as(svg)
    mata: st_numscalar("fgut_n", _fgut_svg_has_all(st_local("sv") + ".svg", ///
        _fgut_hostile()))
    assert scalar(fgut_n) == 1
    * the graph object holds the inert SMCL form, one entry per curve
    assert `.fgut7.legend.plotregion1.label.arrnels' == 3
    forvalues k = 1/3 {
        local _ot `"`.fgut7.legend.plotregion1.label[`k'].text[1]'"'
        mata: st_numscalar("fgut_n", st_local("_ot") == ///
            _fgut_enc(_fgut_hostile()[`k']))
        assert scalar(fgut_n) == 1
    }
    * the bstrata() over() route draws the same labels
    quietly finegray x, compete(status) cause(1) nolog bstrata(grp)
    finegray_cif, over(grp) name(fgut7b)
    quietly graph export `"`sv'.svg"', name(fgut7b) replace as(svg)
    mata: st_numscalar("fgut_n", _fgut_svg_has_all(st_local("sv") + ".svg", ///
        _fgut_hostile()))
    assert scalar(fgut_n) == 1
    graph drop _all
}
if _rc == 0 {
    display as result "  PASS: UT-7 unbalanced backtick label drawn verbatim (default and bstrata routes)"
    local ++pass_count
}
else {
    display as error "  FAIL: UT-7 unbalanced backtick legend (rc=`=_rc')"
    local ++fail_count
}

**# UT-8 the text survives graph display, graph save + graph use, and graph combine
local ++test_count
capture noisily {
    _fgut_data3
    quietly finegray x grp, compete(status) cause(1) nolog
    tempfile sv gph
    graph drop _all
    finegray_cif, over(grp) name(fgut8)
    graph display fgut8
    quietly graph export `"`sv'.svg"', replace as(svg)
    mata: st_numscalar("fgut_n", _fgut_svg_has_all(st_local("sv") + ".svg", ///
        _fgut_hostile()))
    assert scalar(fgut_n) == 1
    quietly graph save fgut8 `"`gph'.gph"', replace
    graph drop _all
    graph use `"`gph'.gph"', name(fgut8u)
    quietly graph export `"`sv'.svg"', name(fgut8u) replace as(svg)
    mata: st_numscalar("fgut_n", _fgut_svg_has_all(st_local("sv") + ".svg", ///
        _fgut_hostile()))
    assert scalar(fgut_n) == 1
    graph combine fgut8u, name(fgut8c)
    quietly graph export `"`sv'.svg"', name(fgut8c) replace as(svg)
    mata: st_numscalar("fgut_n", _fgut_svg_has_all(st_local("sv") + ".svg", ///
        _fgut_hostile()))
    assert scalar(fgut_n) == 1
    graph drop _all
}
if _rc == 0 {
    display as result "  PASS: UT-8 verbatim after graph display, save/use and combine"
    local ++pass_count
}
else {
    display as error "  FAIL: UT-8 re-displayed graph text (rc=`=_rc')"
    local ++fail_count
}

**# UT-9 console: SMCL markup in a label prints literally (over() header, Reference line)
local ++test_count
capture noisily {
    _fgut_data3
    tempfile lg
    log using `"`lg'"', text replace name(_fgut9)
    finegray x i.grp, compete(status) cause(1) nolog
    finegray_cif, over(grp) attime(1) nograph
    log close _fgut9
    mata: st_local("want1", "Reference: i.grp: " + _fgut_hostile()[1] + " (grp==1)")
    mata: st_local("want2", "-> grp = " + _fgut_hostile()[1])
    mata: st_local("want3", "-> grp = " + _fgut_hostile()[3])
    foreach w in want1 want2 want3 {
        mata: st_numscalar("fgut_n", _fgut_has(st_local("lg"), st_local("`w'")))
        assert !missing(scalar(fgut_n))
        assert scalar(fgut_n) == 1
    }
    mata: st_numscalar("fgut_n", _fgut_has(st_local("lg"), "EXPANDED"))
    assert scalar(fgut_n) == 0
}
if _rc == 0 {
    display as result "  PASS: UT-9 console prints SMCL markup and backticks in labels literally"
    local ++pass_count
}
else {
    local _urc = _rc
    capture log close _fgut9
    display as error "  FAIL: UT-9 console label text (rc=`_urc')"
    local ++fail_count
}

**# UT-10 legend keys: labelled levels drawn as the label alone, unlabelled as "grp = #"
local ++test_count
capture noisily {
    _fgut_data3
    mata: st_vlmodify("fgut_p", (1 \ 2 \ 3), ("Placebo" \ "Low dose (5 mg), 10%" \ ///
        "Hög: " + char(39) + "alt" + char(39) + " a\b"))
    label values grp fgut_p
    quietly finegray x grp, compete(status) cause(1) nolog
    tempfile sv
    graph drop _all
    finegray_cif, over(grp) ci name(fgut10)
    quietly graph export `"`sv'.svg"', name(fgut10) replace as(svg)
    mata: st_vlload("fgut_p", _fgut_v = ., _fgut_t = .); ///
        st_numscalar("fgut_n", _fgut_svg_has_all(st_local("sv") + ".svg", _fgut_t))
    assert scalar(fgut_n) == 1
    * the stored legend text is the label itself: nothing was encoded
    forvalues k = 1/3 {
        local _ot `"`.fgut10.legend.plotregion1.label[`k'].text[1]'"'
        mata: st_numscalar("fgut_n", st_local("_ot") == _fgut_t[`k'])
        assert scalar(fgut_n) == 1
    }
    * fixed text finegray_cif writes itself is unchanged
    mata: st_numscalar("fgut_n", _fgut_svg_has_all(st_local("sv") + ".svg", ///
        ("Cumulative incidence" \ "Analysis time" \ "Shaded: 95% CI")))
    assert scalar(fgut_n) == 1
    * a labelled level carries no "var = " prefix anywhere in the drawn text
    mata: st_numscalar("fgut_n", sum(strpos(_fgut_svgtext(st_local("sv") + ".svg"), "grp = ") :> 0))
    assert scalar(fgut_n) == 0
    * a partly labelled variable: the unlabelled level keeps its prefix
    label define fgut_q 1 "Placebo" 2 "Active"
    label values grp fgut_q
    quietly finegray x grp, compete(status) cause(1) nolog
    finegray_cif, over(grp) name(fgut10m)
    quietly graph export `"`sv'.svg"', name(fgut10m) replace as(svg)
    mata: st_numscalar("fgut_n", _fgut_svg_has_all(st_local("sv") + ".svg", ///
        ("Placebo" \ "Active" \ "grp = 3")))
    assert scalar(fgut_n) == 1
    label drop fgut_q
    * an unlabelled over() variable still shows its levels
    label values grp
    quietly finegray x grp, compete(status) cause(1) nolog
    finegray_cif, over(grp) name(fgut10b)
    quietly graph export `"`sv'.svg"', name(fgut10b) replace as(svg)
    mata: st_numscalar("fgut_n", _fgut_svg_has_all(st_local("sv") + ".svg", ///
        ("grp = 1" \ "grp = 2" \ "grp = 3")))
    assert scalar(fgut_n) == 1
    graph drop _all
    mata: mata drop _fgut_v _fgut_t
}
if _rc == 0 {
    display as result "  PASS: UT-10 labelled keys drawn as the label alone, unlabelled as "grp = #""
    local ++pass_count
}
else {
    display as error "  FAIL: UT-10 legend keys (rc=`=_rc')"
    local ++fail_count
    capture mata: mata drop _fgut_v _fgut_t
}

**# UT-11 _finegray_graph_text: exact encoding, contract errors, state, and it ships
local ++test_count
capture noisily {
    * the installed copy resolves, from this run's private PLUS tree
    quietly findfile _finegray_graph_text.ado
    assert strpos(`"`r(fn)'"', `"`plus_dir'"') == 1
    * every .ado in the package directory is an f line of finegray.pkg
    local _ados : dir `"`pkg_dir'"' files "*.ado"
    tempname fh
    local _flines ""
    file open `fh' using `"`pkg_dir'/finegray.pkg"', read text
    file read `fh' _ln
    while r(eof) == 0 {
        if regexm(`"`_ln'"', "^f ([^ ]+)$") local _flines `"`_flines' `=regexs(1)'"'
        file read `fh' _ln
    }
    file close `fh'
    assert `: word count `_ados'' >= 14
    foreach _a of local _ados {
        local _in : list _a in _flines
        if !`_in' display as error "  `_a' is not listed in finegray.pkg"
        assert `_in'
    }
    * byte-exact against the one-character-at-a-time oracle
    mata: _fgut_T = (_fgut_hostile() \ "" \ "{" \ "}" \ "{}{{" \ ///
        "lit {c 36} {c -(}" \ " pad  " \ "a: b" \ "a\b\" \ ///
        "\" + char(36) + "G \" + char(96) + "q'" \ ///
        "x" + char(34) + char(39) + "y" \ ///
        char(96) + char(34) + "cq" + char(34) + char(39) \ ///
        char(34) + "plain" + char(34) \ "ctl" + char(1) + char(2) + char(5) + "z")
    mata: st_local("_nt", strofreal(rows(_fgut_T)))
    forvalues k = 1/`_nt' {
        mata: st_local("_raw", _fgut_T[`k'])
        _finegray_graph_text _enc : `"`macval(_raw)'"'
        mata: st_numscalar("fgut_n", st_local("_enc") == _fgut_enc(_fgut_T[`k']))
        if scalar(fgut_n) != 1 display as error "  encoding mismatch, case `k'"
        assert scalar(fgut_n) == 1
    }
    mata: mata drop _fgut_T
    * contract errors, and varabbrev restored on both paths
    set varabbrev on
    capture _finegray_graph_text 1bad : `"x"'
    assert _rc == 198
    assert c(varabbrev) == "on"
    capture _finegray_graph_text nocolon
    assert _rc == 198
    _finegray_graph_text _enc : `"x"'
    assert c(varabbrev) == "on"
    set varabbrev off
    * nclass: r() of the caller is left alone
    quietly summarize x
    local _rn = r(N)
    _finegray_graph_text _enc : `"A"'
    assert r(N) == `_rn'
}
if _rc == 0 {
    display as result "  PASS: UT-11 helper encodes exactly, errors on bad syntax, and ships"
    local ++pass_count
}
else {
    display as error "  FAIL: UT-11 _finegray_graph_text (rc=`=_rc')"
    local ++fail_count
    capture mata: mata drop _fgut_T
    set varabbrev off
}

**# UT-12 user twoway text options pass through exactly as twoway draws them
* title(), note(), axis titles, text() and legend() typed by the user are
* graph syntax, forwarded unchanged: SMCL in them is honoured, as in twoway.
* finegray_cif must add no expansion layer of its own.
local ++test_count
capture noisily {
    _fgut_data3
    label values grp
    quietly finegray x, compete(status) cause(1) nolog
    mata: st_local("_h", "{bf:b} {c 36}lit " + char(34) + "dq" + char(34) + ///
        " 50% " + char(195) + char(169) + " end")
    local _o `"title(`"T `macval(_h)'"') subtitle(`"S `macval(_h)'"') note(`"N `macval(_h)'"') xtitle(`"X `macval(_h)'"') ytitle(`"Y `macval(_h)'"') text(.1 1 `"B `macval(_h)'"') legend(on order(1 `"L `macval(_h)'"'))"'
    tempfile s1 s2
    graph drop _all
    finegray_cif, `macval(_o)' name(fgut12f)
    quietly graph export `"`s1'.svg"', name(fgut12f) replace as(svg)
    generate double _fgut_y = .5
    twoway line _fgut_y _t, `macval(_o)' name(fgut12t)
    quietly graph export `"`s2'.svg"', name(fgut12t) replace as(svg)
    * each drawn element is prefix + " b $lit "dq" 50% <e-acute> end", with
    * b in bold; finegray_cif and twoway must draw the same seven elements
    mata: _fgut_w = " b " + char(36) + "lit " + char(34) + "dq" + char(34) + ///
        " 50% " + char(195) + char(169) + " end"; ///
        _fgut_a = _fgut_svgtext(st_local("s1") + ".svg"); ///
        _fgut_b = _fgut_svgtext(st_local("s2") + ".svg"); ///
        _fgut_a = sort(select(_fgut_a, strpos(_fgut_a, "lit") :> 0), 1); ///
        _fgut_b = sort(select(_fgut_b, strpos(_fgut_b, "lit") :> 0), 1); ///
        st_numscalar("fgut_n", rows(_fgut_a) == 7 & rows(_fgut_b) == 7 & ///
            _fgut_a == _fgut_b & ///
            _fgut_a == ("B" \ "L" \ "N" \ "S" \ "T" \ "X" \ "Y") :+ _fgut_w)
    mata: mata drop _fgut_a _fgut_b _fgut_w
    assert scalar(fgut_n) == 1
    graph drop _all
}
if _rc == 0 {
    display as result "  PASS: UT-12 user text options drawn exactly as twoway draws them"
    local ++pass_count
}
else {
    display as error "  FAIL: UT-12 user twoway text pass-through (rc=`=_rc')"
    local ++fail_count
    capture mata: mata drop _fgut_a _fgut_b _fgut_w
}

macro drop FGUT_G
capture scalar drop fgut_n ut1 ut3 ut3b ut4
capture mata: mata drop _fgut_has() _fgut_hostile() _fgut_svgtext() _fgut_enc() _fgut_svg_has_all()
display "RESULT: test_finegray_user_text tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _test_fgut
if `fail_count' > 0 exit 1
exit 0
