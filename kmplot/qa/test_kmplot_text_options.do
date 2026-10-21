* test_kmplot_text_options.do
* Title-type options with sub-options and several lines, literal group labels,
* passthrough text, xlabel() positions for the risk table, and option
* validation (pvalueformat(), pvaluetext(""), compete(), name())
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-10-20
*
* Rendered text is read back from exported SVG files.  Literal strings with
* macro characters travel in globals set by Mata, so the test never expands
* them itself.

clear all
version 16.0
set varabbrev off
local qa_dir "`c(pwd)'"
quietly do "`qa_dir'/_kmplot_qa_common.do"
quietly do "`qa_dir'/_kmplot_qa_cifsupport.do"
_kmplot_qa_bootstrap
_kmqa_init
global TABTOOLS_set_smallcells ""

* Number of SVG <text> elements whose text is exactly the global's value
* (exact(1)) or contains it (exact(0)); r(n).  The value is read by Mata.
capture program drop _kmtx_svgcount
program define _kmtx_svgcount, rclass
    version 16.0
    syntax using/, GLOBAL(name) [EXACT(integer 1)]
    mata: _kmtx_count(st_local("using"), st_global(st_local("global")), strtoreal(st_local("exact")))
    return scalar n = scalar(_kmtx_n)
end
capture mata: mata drop _kmtx_count()
mata:
void _kmtx_count(string scalar fn, string scalar want, real scalar exact)
{
    string colvector L
    string scalar s, t
    real scalar i, n, p, q
    L = cat(fn)
    n = 0
    want = subinstr(subinstr(subinstr(want, "&", "&amp;"), "<", "&lt;"), ">", "&gt;")
    for (i = 1; i <= rows(L); i++) {
        s = L[i]
        if (!strpos(s, "<text ")) continue
        p = strpos(s, ">")
        q = strpos(s, "</text>")
        if (p == 0 | q <= p) continue
        t = substr(s, p + 1, q - p - 1)
        if (exact) n = n + (t == want)
        else n = n + (strpos(t, want) > 0)
    }
    st_numscalar("_kmtx_n", n)
}
end

* font size of the first <text> element whose text equals the global
capture program drop _kmtx_svgsize
program define _kmtx_svgsize, rclass
    version 16.0
    syntax using/, GLOBAL(name)
    mata: _kmtx_size(st_local("using"), st_global(st_local("global")))
    return scalar fs = scalar(_kmtx_fs)
end
capture mata: mata drop _kmtx_size()
mata:
void _kmtx_size(string scalar fn, string scalar want)
{
    string colvector L
    real scalar i
    L = cat(fn)
    st_numscalar("_kmtx_fs", .)
    for (i = 1; i <= rows(L); i++) {
        if (strpos(L[i], ">" + want + "</text>") & regexm(L[i], "font-size:([0-9.]+)px")) {
            st_numscalar("_kmtx_fs", strtoreal(regexs(1)))
            return
        }
    }
}
end

**## X1 title(), subtitle() and note() sub-options are applied, not printed
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    tempfile a b
    kmplot, by(drug) title("Hello") export("`a'.svg", replace)
    kmplot, by(drug) title("Hello", size(huge)) subtitle("Sub", color(red)) ///
        note("N=48", size(small)) export("`b'.svg", replace)
    global KMTX_S "Hello"
    _kmtx_svgcount using "`b'.svg", global(KMTX_S)
    assert r(n) == 1
    global KMTX_S "size("
    _kmtx_svgcount using "`b'.svg", global(KMTX_S) exact(0)
    assert r(n) == 0
    global KMTX_S "color("
    _kmtx_svgcount using "`b'.svg", global(KMTX_S) exact(0)
    assert r(n) == 0
    foreach s in Sub N=48 {
        global KMTX_S "`s'"
        _kmtx_svgcount using "`b'.svg", global(KMTX_S)
        assert r(n) == 1
    }
    * the user's size() replaces the default size
    global KMTX_S "Hello"
    _kmtx_svgsize using "`a'.svg", global(KMTX_S)
    local fs_default = r(fs)
    _kmtx_svgsize using "`b'.svg", global(KMTX_S)
    assert r(fs) > `fs_default' & r(fs) < .
}
_kmqa_record, name("X1 title()/subtitle()/note() sub-options honoured") rc(`=_rc')

**## X2 xtitle() and ytitle() sub-options; r(xtitle) and r(ytitle) hold the text only
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    tempfile a b
    kmplot, by(drug) xtitle("Time (d)", color(red)) ytitle("S(t)", size(small)) ///
        export("`a'.svg", replace)
    assert `"`r(xtitle)'"' == "Time (d)"
    assert `"`r(ytitle)'"' == "S(t)"
    global KMTX_S "Time (d)"
    _kmtx_svgcount using "`a'.svg", global(KMTX_S)
    assert r(n) == 1
    global KMTX_S "color(red)"
    _kmtx_svgcount using "`a'.svg", global(KMTX_S) exact(0)
    assert r(n) == 0
    * with a risk table the x title is drawn by the table panel
    kmplot, by(drug) risktable xtitle("Days", color(red)) export("`b'.svg", replace)
    assert `"`r(xtitle)'"' == "Days"
    global KMTX_S "Days"
    _kmtx_svgcount using "`b'.svg", global(KMTX_S)
    assert r(n) == 1
    global KMTX_S "color(red)"
    _kmtx_svgcount using "`b'.svg", global(KMTX_S) exact(0)
    assert r(n) == 0
}
_kmqa_record, name("X2 xtitle()/ytitle() sub-options; returns hold the text") rc(`=_rc')

**## X3 several quoted strings are several lines
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    tempfile a
    kmplot, by(drug) title("Line one" "Line two") export("`a'.svg", replace)
    foreach s in "Line one" "Line two" {
        global KMTX_S "`s'"
        _kmtx_svgcount using "`a'.svg", global(KMTX_S)
        assert r(n) == 1
    }
    global KMTX_S `"" ""'
    _kmtx_svgcount using "`a'.svg", global(KMTX_S) exact(0)
    assert r(n) == 0
    * a comma inside a quoted title is text
    kmplot, by(drug) title("Plot, with comma", size(small)) export("`a'.svg", replace)
    global KMTX_S "Plot, with comma"
    _kmtx_svgcount using "`a'.svg", global(KMTX_S)
    assert r(n) == 1
}
_kmqa_record, name("X3 multi-line titles and quoted commas") rc(`=_rc')

**## X4 xtitle("") and ytitle("") suppress the titles with a risk table too
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    tempfile a b
    kmplot, by(drug) ytitle("") xtitle("") export("`a'.svg", replace)
    kmplot, by(drug) risktable ytitle("") xtitle("") export("`b'.svg", replace)
    foreach f in a b {
        foreach s in "Analysis time" "Survival probability" {
            global KMTX_S "`s'"
            _kmtx_svgcount using "``f''.svg", global(KMTX_S)
            assert r(n) == 0
        }
    }
    assert `"`r(xtitle)'"' == ""
    * without the empty title the default is drawn once
    kmplot, by(drug) risktable export("`b'.svg", replace)
    global KMTX_S "Analysis time"
    _kmtx_svgcount using "`b'.svg", global(KMTX_S)
    assert r(n) == 1
}
_kmqa_record, name("X4 empty xtitle() and ytitle() suppress the titles, risk table included") rc(`=_rc')

**## X5 the word nodraw inside passthrough text is text
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    tempfile a
    kmplot, by(drug) text(0.5 5 "see nodraw here") export("`a'.svg", replace)
    global KMTX_S "see nodraw here"
    _kmtx_svgcount using "`a'.svg", global(KMTX_S)
    assert r(n) == 1
    * a real nodraw is still honoured, and refused with export()
    kmplot, by(drug) nodraw text(0.5 5 "see nodraw here")
    _kmqa_expect, rc(198) cmd(kmplot, by(drug) nodraw export(x.svg, replace)) text("nodraw")
}
_kmqa_record, name("X5 nodraw inside text() is not the nodraw option") rc(`=_rc')

**## X6 group labels with a backtick or a dollar sign stay literal
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    global myg "EXPANDED"
    label define kmtx_dl 1 "x" 2 "B" 3 "C"
    mata: st_vlmodify("kmtx_dl", 1, "Back" + char(96) + "tick")
    mata: st_vlmodify("kmtx_dl", 2, "Arm " + char(36) + "myg")
    label values drug kmtx_dl
    tempfile a b
    foreach rt in "" risktable {
        kmplot, by(drug) `rt' median medianannotate export("`a'.svg", replace)
        mata: st_global("KMTX_S", "Back" + char(96) + "tick | Arm " + char(36) + "myg | C")
        mata: st_numscalar("kmtx_ok", st_global("r(group_labels)") == st_global("KMTX_S"))
        assert scalar(kmtx_ok) == 1
        mata: st_global("KMTX_S", "Back" + char(96) + "tick")
        _kmtx_svgcount using "`a'.svg", global(KMTX_S)
        assert r(n) >= 1 & r(n) < .
        mata: st_global("KMTX_S", "Arm " + char(36) + "myg")
        _kmtx_svgcount using "`a'.svg", global(KMTX_S)
        assert r(n) >= 1 & r(n) < .
        global KMTX_S "EXPANDED"
        _kmtx_svgcount using "`a'.svg", global(KMTX_S) exact(0)
        assert r(n) == 0
    }
    * risk table rows carry the labels too (main panel reserve + table row)
    mata: st_global("KMTX_S", "Back" + char(96) + "tick")
    _kmtx_svgcount using "`a'.svg", global(KMTX_S)
    assert r(n) >= 2 & r(n) < .
    * saved datasets keep the bytes
    kmplot, by(drug) saving("`b'", replace) risksaving("`a'", replace) nodraw
    foreach f in a b {
        use "``f''", clear
        mata: st_numscalar("kmtx_ok", any(st_sdata(., "group_label") :== "Back" + char(96) + "tick") & any(st_sdata(., "group_label") :== "Arm " + char(36) + "myg"))
        assert scalar(kmtx_ok) == 1
    }
    * a string by() value with a dollar sign
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    gen str12 arm = ""
    mata: st_sstore(., "arm", J(st_nobs(), 1, "Arm " + char(36) + "myg"))
    replace arm = "Other" if drug == 1
    kmplot, by(arm) nodraw
    mata: st_numscalar("kmtx_ok", st_global("r(group_labels)") == "Arm " + char(36) + "myg | Other")
    assert scalar(kmtx_ok) == 1
    * and one with a backtick, through the risk table
    mata: st_sstore(selectindex(st_data(., "drug") :== 2), "arm", J(sum(st_data(., "drug") :== 2), 1, "Back" + char(96) + "tick"))
    kmplot, by(arm) risktable nodraw
    mata: st_numscalar("kmtx_ok", st_global("r(group_labels)") == "Arm " + char(36) + "myg | Back" + char(96) + "tick | Other")
    assert scalar(kmtx_ok) == 1
    macro drop myg
}
_kmqa_record, name("X6 backtick and dollar group labels are literal everywhere") rc(`=_rc')

**## X7 xlabel() with text labels sets the risk-table columns; unparseable xlabel() is refused
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    kmplot, by(drug) risktable xlabel(0 "start" 10 20) nodraw
    assert "`r(timepoints)'" == "0 10 20"
    kmplot, by(drug) risktable xlabel(0(10)30, labsize(small)) nodraw
    assert "`r(timepoints)'" == "0 10 20 30"
    foreach spec in "#5" "minmax" "none" {
        _kmqa_expect, rc(198) cmd(kmplot, by(drug) risktable xlabel(`spec') nodraw) ///
            text("timepoints()")
    }
    * with timepoints() the labels are the user's choice
    kmplot, by(drug) risktable xlabel(#5) timepoints(0 10 20) nodraw
    assert "`r(timepoints)'" == "0 10 20"
    * no table drawn: risksaving() keeps its default columns
    tempfile rs
    kmplot, by(drug) risksaving("`rs'", replace) xlabel(#5) nodraw
    assert r(n_timepoints) > 0 & r(n_timepoints) < .
}
_kmqa_record, name("X7 risk-table columns follow labelled xlabel(); #, minmax, none refused") rc(`=_rc')

**## X8 pvalueformat() must be numeric; pvaluetext("") leaves no leading blank
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    gen byte rnd = mod(_n, 2)
    foreach f in %tc %td %9s {
        _kmqa_expect, rc(198) cmd(kmplot, by(rnd) pvalue pvalueformat(`f') nodraw) ///
            text("pvalueformat()")
    }
    quietly sts test rnd, logrank
    local p = chi2tail(r(df), r(chi2))
    local ptxt = strtrim(string(`p', "%5.3f"))
    kmplot, by(rnd) pvalue pvaluetext("") nodraw
    assert `"`r(pvalue_text)'"' == "= `ptxt'"
    kmplot, by(rnd) pvalue nodraw
    assert `"`r(pvalue_text)'"' == "Log-rank p = `ptxt'"
}
_kmqa_record, name("X8 pvalueformat() date formats refused; empty pvaluetext()") rc(`=_rc')

**## X9 compete(): a comma is refused; no competing records gives a note
capture noisily {
    sysuse cancer, clear
    set seed 11
    gen byte ev = cond(died == 1, 1, cond(runiform() < .5, 2, 0))
    quietly stset studytime, failure(ev == 1)
    foreach c in `"ev == 2, "' `"ev == 2, byte"' {
        _kmqa_expect, rc(198) cmd(kmplot, compete(`c') nodraw) text("compete()")
    }
    _kmqa_run, cmd(kmplot, compete(ev == 9) nodraw)
    assert r(rc) == 0
    assert strpos(`"`r(text)'"', "compete() is true on no records")
    _kmqa_run, cmd(kmplot, compete(ev == 2) nodraw)
    assert r(rc) == 0
    assert strpos(`"`r(text)'"', "compete() is true on no records") == 0
}
_kmqa_record, name("X9 compete() with a comma refused; zero competing records noted") rc(`=_rc')

**## X10 name() must be one graph name
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    foreach n in ",replace" "a b, replace" "a b" "1abc" {
        _kmqa_expect, rc(198) cmd(kmplot, name(`n') nodraw) text("name()")
    }
    kmplot, name(kmtx_ok, replace) nodraw
    assert "`r(graph_name)'" == "kmtx_ok"
    kmplot, name(kmtx_ok) nodraw
    assert "`r(graph_name)'" == "kmtx_ok"
}
_kmqa_record, name("X10 name() validated as a single graph name") rc(`=_rc')

_kmqa_finish, suite("test_kmplot_text_options")
