* test_bugfix_2026_10_06_c.do - tabtools 2.5.1 bug report 2026-10-06, slice C
* Covers the outtab surfaces that had no QA (excel(), mdappend, borderstyle(),
* headershade, font(), fontsize(), frame(), grouplabels(), title(),
* footnote(), sheet(), csv(), markdown(), r(frame), r(xlsx), r(estimator),
* r(minevents), r(N_outcomes)), the claims written into the new Options
* entries of outtab, ratetab (level(), pydigits()) and tabcell (p(), median(),
* q1(), q3(), r(N), r(N_missing), r(varname)), and that each of those options
* has a prose entry in its help file.
* Oracles: hand counts, workbook styles read back with openpyxl
* (tools/xlsx_style_facts.py), the written Markdown/CSV text, the exact
* Garwood Poisson limits from invchi2(), and the help files read as text.

clear all
set more off
set varabbrev off
version 17.0

capture log close _bfc
log using "test_bugfix_2026_10_06_c.log", replace text name(_bfc)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global BFC_OUT "`output_dir'"
* a workbook that exists gets sheets added to it, so start from none
local _old : dir "`output_dir'" files "bfc_*"
foreach _f of local _old {
    capture erase "`output_dir'/`_f'"
}
global BFC_TOOLS "`qa_dir'/tools"
global BFC_PKG "`pkg_dir'"
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear
global TABTOOLS_set_smallcells

local pass_count = 0
local fail_count = 0

* one fact line of a facts file is exactly the needle
capture program drop _bfc_hasline
program define _bfc_hasline, rclass
    version 17.0
    args file needle
    tempname h
    local found 0
    file open `h' using `"`file'"', read text
    file read `h' line
    while r(eof) == 0 {
        if `"`macval(line)'"' == `"`needle'"' local found 1
        file read `h' line
    }
    file close `h'
    return scalar found = `found'
end

* number of lines of a facts file that begin with the prefix
capture program drop _bfc_countprefix
program define _bfc_countprefix, rclass
    version 17.0
    args file prefix
    tempname h
    local n 0
    file open `h' using `"`file'"', read text
    file read `h' line
    while r(eof) == 0 {
        if substr(`"`macval(line)'"', 1, strlen(`"`prefix'"')) == `"`prefix'"' local ++n
        file read `h' line
    }
    file close `h'
    return scalar n = `n'
end

* all lines of a text file: r(n) and r(l1) ... r(ln)
capture program drop _bfc_lines
program define _bfc_lines, rclass
    version 17.0
    args file
    tempname h
    local n 0
    file open `h' using `"`file'"', read text
    file read `h' line
    while r(eof) == 0 {
        local ++n
        return local l`n' `"`macval(line)'"'
        file read `h' line
    }
    file close `h'
    return scalar n = `n'
end

* read one worksheet's styles into a facts file
capture program drop _bfc_facts
program define _bfc_facts
    version 17.0
    args book sheet out
    capture erase `"`out'"'
    quietly shell python3 "$BFC_TOOLS/xlsx_style_facts.py" "`book'" "`sheet'" "`out'"
    confirm file `"`out'"'
end

* Help-file option check: the needle (as typed in the file) occurs in the
* Options section, between {marker options} and the next {marker
capture program drop _bfc_optsection
program define _bfc_optsection, rclass
    version 17.0
    args file needle
    tempname h
    local inopt 0
    local found 0
    file open `h' using `"`file'"', read text
    file read `h' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "{marker options}") local inopt 1
        else if `inopt' & strpos(`"`macval(line)'"', "{marker ") local inopt 0
        if `inopt' & strpos(`"`macval(line)'"', `"`needle'"') & ///
            strpos(`"`macval(line)'"', "{synopt") == 0 local found 1
        file read `h' line
    }
    file close `h'
    return scalar found = `found'
end

capture program drop _bfc_data
program define _bfc_data
    version 17.0
    clear
    set seed 20261006
    set obs 800
    gen long id = _n
    gen byte expo = runiform() < 0.4
    label define _bfx 1 "Exposed" 0 "Unexposed", replace
    label values expo _bfx
    gen byte expo_nl = expo
    gen double age = rnormal(40, 8)
    gen byte y1 = runiform() < 0.15 + 0.10 * expo
    gen byte y2 = runiform() < 0.30 + 0.10 * expo
    label variable y1 "Outcome one"
    label variable y2 "Outcome two"
end

**# C1: excel() is a synonym for xlsx(): the two workbooks are the same cell for cell
capture noisily {
    _bfc_data
    outtab y1 y2, exposure(expo) estimator(logit, or) xlsx("$BFC_OUT/bfc_x.xlsx") ///
        sheet("S") title("Title") footnote("Foot")
    matrix Rx = r(table)
    local rx `"`r(xlsx)'"'
    outtab y1 y2, exposure(expo) estimator(logit, or) excel("$BFC_OUT/bfc_e.xlsx") ///
        sheet("S") title("Title") footnote("Foot")
    matrix Re = r(table)
    assert `"`r(xlsx)'"' == "$BFC_OUT/bfc_e.xlsx"
    assert `"`rx'"' == "$BFC_OUT/bfc_x.xlsx"
    assert mreldif(Rx, Re) == 0
    quietly import excel using "$BFC_OUT/bfc_x.xlsx", sheet("S") allstring clear
    quietly describe
    assert !missing(r(N), r(k)) & r(N) >= 5 & r(k) >= 4
    tempfile fx
    quietly save `fx'
    quietly import excel using "$BFC_OUT/bfc_e.xlsx", sheet("S") allstring clear
    unab vars_e : _all
    preserve
    quietly use `fx', clear
    unab vars_x : _all
    restore
    assert "`vars_e'" == "`vars_x'"
    cf _all using `fx'
    * the cells are real: the first outcome's crude odds ratio is in column E
    _bfc_data
    quietly logit y1 expo, or
    matrix T = r(table)
    local want = strtrim(string(T[1,1], "%4.2f")) + " (" + strtrim(string(T[5,1], "%4.2f")) + ", " + strtrim(string(T[6,1], "%4.2f")) + ")"
    quietly import excel using "$BFC_OUT/bfc_e.xlsx", sheet("S") allstring clear
    quietly count if E == "`want'"
    assert r(N) == 1
    * both given: xlsx() wins and the excel() file is not written
    _bfc_data
    capture erase "$BFC_OUT/bfc_unused.xlsx"
    outtab y1, exposure(expo) estimator(logit, or) excel("$BFC_OUT/bfc_unused.xlsx") xlsx("$BFC_OUT/bfc_used.xlsx")
    assert `"`r(xlsx)'"' == "$BFC_OUT/bfc_used.xlsx"
    confirm file "$BFC_OUT/bfc_used.xlsx"
    capture confirm file "$BFC_OUT/bfc_unused.xlsx"
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS: C1 excel() writes the same workbook as xlsx(); xlsx() wins when both are given"
    local ++pass_count
}
else {
    display as error "  FAIL: C1 excel() alias (rc=`=_rc')"
    local ++fail_count
}

**# C2: mdappend adds the new table after the earlier Markdown; without it the file is replaced
capture noisily {
    _bfc_data
    capture erase "$BFC_OUT/bfc_md.md"
    outtab y1 y2, exposure(expo) estimator(logit, or) markdown("$BFC_OUT/bfc_md.md") title("First")
    _bfc_lines "$BFC_OUT/bfc_md.md"
    local n1 = r(n)
    forvalues i = 1/`n1' {
        local f`i' `"`r(l`i')'"'
    }
    assert `n1' >= 6
    assert `"`f1'"' == "### First"
    quietly count if y2 == 1 & expo == 1
    local e1 = r(N)
    quietly count if expo == 1
    local n1c = r(N)
    outtab y2, exposure(expo) estimator(logit, or) markdown("$BFC_OUT/bfc_md.md") mdappend title("Second")
    _bfc_lines "$BFC_OUT/bfc_md.md"
    local n2 = r(n)
    forvalues i = 1/`n2' {
        local s`i' `"`r(l`i')'"'
    }
    * the first table is intact, line for line, at the top of the file
    forvalues i = 1/`n1' {
        assert `"`s`i''"' == `"`f`i''"'
    }
    * and the second table follows it: its title, then its header and its one outcome row
    assert `n2' > `n1'
    local at2 0
    forvalues i = `=`n1' + 1'/`n2' {
        if `"`s`i''"' == "### Second" local at2 `i'
    }
    assert `at2' > `n1'
    assert `n2' == `at2' + 4
    assert `"`s`=`at2' - 1''"' == ""
    assert regexm(`"`s`=`at2' + 2''"', "^\|  \| Exposed, events/N \(%\) \| Unexposed, events/N \(%\) \| Crude, RR \(95% CI\) \|$")
    assert regexm(`"`s`=`at2' + 4''"', "^\| Outcome two \| ")
    * the appended row is the one-row table's own counts, not a copy of the first table's
    assert strpos(`"`s`=`at2' + 4''"', "`e1'/`n1c' (") > 0
    * a call without mdappend replaces the file
    outtab y2, exposure(expo) estimator(logit, or) markdown("$BFC_OUT/bfc_md.md") title("Third")
    _bfc_lines "$BFC_OUT/bfc_md.md"
    assert r(n) == 5
    assert `"`r(l1)'"' == "### Third"
    * mdappend without markdown() writes nothing and is not an error
    capture erase "$BFC_OUT/bfc_none.md"
    outtab y1, exposure(expo) estimator(logit, or) mdappend
    capture confirm file "$BFC_OUT/bfc_none.md"
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS: C2 mdappend keeps the earlier Markdown intact and adds the new table; no mdappend replaces"
    local ++pass_count
}
else {
    display as error "  FAIL: C2 mdappend (rc=`=_rc')"
    local ++fail_count
}

**# C3: borderstyle() is applied to the workbook: thin box, academic rules only, medium box
capture noisily {
    _bfc_data
    foreach bs in default thin medium academic {
        outtab y1 y2, exposure(expo) estimator(logit, or) xlsx("$BFC_OUT/bfc_b_`bs'.xlsx") sheet("T") borderstyle(`bs')
        _bfc_facts "$BFC_OUT/bfc_b_`bs'.xlsx" T "$BFC_OUT/bfc_b_`bs'.facts"
    }
    * the default and thin are one style: a thin box and a rule right of the row labels
    _bfc_hasline "$BFC_OUT/bfc_b_default.facts" "border B2 left thin"
    assert r(found)
    _bfc_hasline "$BFC_OUT/bfc_b_default.facts" "border E4 right thin"
    assert r(found)
    _bfc_countprefix "$BFC_OUT/bfc_b_default.facts" "border"
    local nd = r(n)
    _bfc_countprefix "$BFC_OUT/bfc_b_thin.facts" "border"
    assert r(n) == `nd'
    _bfc_hasline "$BFC_OUT/bfc_b_thin.facts" "border B2 left thin"
    assert r(found)
    _bfc_hasline "$BFC_OUT/bfc_b_thin.facts" "border B2 left medium"
    assert !r(found)
    * medium: the same box in the medium weight
    _bfc_hasline "$BFC_OUT/bfc_b_medium.facts" "border B2 left medium"
    assert r(found)
    _bfc_hasline "$BFC_OUT/bfc_b_medium.facts" "border E4 right medium"
    assert r(found)
    _bfc_hasline "$BFC_OUT/bfc_b_medium.facts" "border B2 left thin"
    assert !r(found)
    * academic: horizontal rules only, no vertical border anywhere
    _bfc_countprefix "$BFC_OUT/bfc_b_academic.facts" "border"
    assert !missing(r(n)) & r(n) > 0
    _bfc_hasline "$BFC_OUT/bfc_b_academic.facts" "border B2 top medium"
    assert r(found)
    _bfc_hasline "$BFC_OUT/bfc_b_academic.facts" "border E4 bottom medium"
    assert r(found)
    tempname h
    local nvert 0
    file open `h' using "$BFC_OUT/bfc_b_academic.facts", read text
    file read `h' line
    while r(eof) == 0 {
        if regexm(`"`macval(line)'"', "^border [A-Z]+[0-9]+ (left|right) ") local ++nvert
        file read `h' line
    }
    file close `h'
    assert `nvert' == 0
    * a bad style is refused, and nothing is written
    capture erase "$BFC_OUT/bfc_b_bad.xlsx"
    capture outtab y1, exposure(expo) estimator(logit, or) xlsx("$BFC_OUT/bfc_b_bad.xlsx") borderstyle(dotted)
    assert _rc == 198
    capture confirm file "$BFC_OUT/bfc_b_bad.xlsx"
    assert _rc == 601
    * the session style applies when the option is absent, and an explicit option wins
    tabtools set borderstyle medium
    outtab y1 y2, exposure(expo) estimator(logit, or) xlsx("$BFC_OUT/bfc_b_sess.xlsx") sheet("T")
    _bfc_facts "$BFC_OUT/bfc_b_sess.xlsx" T "$BFC_OUT/bfc_b_sess.facts"
    _bfc_hasline "$BFC_OUT/bfc_b_sess.facts" "border B2 left medium"
    assert r(found)
    outtab y1 y2, exposure(expo) estimator(logit, or) xlsx("$BFC_OUT/bfc_b_sess2.xlsx") sheet("T") borderstyle(thin)
    _bfc_facts "$BFC_OUT/bfc_b_sess2.xlsx" T "$BFC_OUT/bfc_b_sess2.facts"
    _bfc_hasline "$BFC_OUT/bfc_b_sess2.facts" "border B2 left thin"
    assert r(found)
    quietly tabtools set clear
}
if _rc == 0 {
    display as result "  PASS: C3 borderstyle() sets thin, medium, and academic borders in the workbook"
    local ++pass_count
}
else {
    quietly tabtools set clear
    display as error "  FAIL: C3 borderstyle() (rc=`=_rc')"
    local ++fail_count
}

**# C4: headershade fills the header row only; the session default fills it too
capture noisily {
    _bfc_data
    outtab y1 y2, exposure(expo) estimator(logit, or) xlsx("$BFC_OUT/bfc_h0.xlsx") sheet("T")
    _bfc_facts "$BFC_OUT/bfc_h0.xlsx" T "$BFC_OUT/bfc_h0.facts"
    _bfc_countprefix "$BFC_OUT/bfc_h0.facts" "fill "
    assert r(n) == 0
    outtab y1 y2, exposure(expo) estimator(logit, or) xlsx("$BFC_OUT/bfc_h1.xlsx") sheet("T") headershade
    _bfc_facts "$BFC_OUT/bfc_h1.xlsx" T "$BFC_OUT/bfc_h1.facts"
    * the four header cells, and nothing else
    _bfc_countprefix "$BFC_OUT/bfc_h1.facts" "fill "
    assert r(n) == 4
    foreach c in B2 C2 D2 E2 {
        _bfc_hasline "$BFC_OUT/bfc_h1.facts" "fill `c' FFDBE5F1"
        assert r(found)
    }
    * the header text sits in those cells
    _bfc_hasline "$BFC_OUT/bfc_h1.facts" "value C2 Exposed, events/N (%)"
    assert r(found)
    tabtools set headershade on
    outtab y1 y2, exposure(expo) estimator(logit, or) xlsx("$BFC_OUT/bfc_h2.xlsx") sheet("T")
    _bfc_facts "$BFC_OUT/bfc_h2.xlsx" T "$BFC_OUT/bfc_h2.facts"
    _bfc_countprefix "$BFC_OUT/bfc_h2.facts" "fill "
    assert r(n) == 4
    quietly tabtools set clear
}
if _rc == 0 {
    display as result "  PASS: C4 headershade fills B2:E2 and only those; the session default does too"
    local ++pass_count
}
else {
    quietly tabtools set clear
    display as error "  FAIL: C4 headershade (rc=`=_rc')"
    local ++fail_count
}

**# C5: font() and fontsize(): defaults, explicit values, range, session values
capture noisily {
    _bfc_data
    outtab y1 y2, exposure(expo) estimator(logit, or) xlsx("$BFC_OUT/bfc_f0.xlsx") sheet("T")
    _bfc_facts "$BFC_OUT/bfc_f0.xlsx" T "$BFC_OUT/bfc_f0.facts"
    _bfc_hasline "$BFC_OUT/bfc_f0.facts" "font C3 Arial 10"
    assert r(found)
    outtab y1 y2, exposure(expo) estimator(logit, or) xlsx("$BFC_OUT/bfc_f1.xlsx") sheet("T") ///
        font("Times New Roman") fontsize(12)
    _bfc_facts "$BFC_OUT/bfc_f1.xlsx" T "$BFC_OUT/bfc_f1.facts"
    foreach c in B2 C2 E2 B3 E3 B4 E4 {
        _bfc_hasline "$BFC_OUT/bfc_f1.facts" "font `c' Times New Roman 12"
        assert r(found)
    }
    _bfc_countprefix "$BFC_OUT/bfc_f1.facts" "font "
    local nf = r(n)
    _bfc_countprefix "$BFC_OUT/bfc_f1.facts" "font A"
    assert r(n) == 0
    foreach sz in 0 73 {
        capture outtab y1, exposure(expo) estimator(logit, or) xlsx("$BFC_OUT/bfc_f2.xlsx") fontsize(`sz')
        assert _rc == 198
    }
    foreach sz in 1 72 {
        outtab y1, exposure(expo) estimator(logit, or) xlsx("$BFC_OUT/bfc_f3.xlsx") sheet("T") fontsize(`sz')
        _bfc_facts "$BFC_OUT/bfc_f3.xlsx" T "$BFC_OUT/bfc_f3.facts"
        _bfc_hasline "$BFC_OUT/bfc_f3.facts" "font C3 Arial `sz'"
        assert r(found)
    }
    * session defaults apply without the options, and the options override them
    tabtools set font Calibri
    tabtools set fontsize 9
    outtab y1 y2, exposure(expo) estimator(logit, or) xlsx("$BFC_OUT/bfc_f4.xlsx") sheet("T")
    _bfc_facts "$BFC_OUT/bfc_f4.xlsx" T "$BFC_OUT/bfc_f4.facts"
    _bfc_hasline "$BFC_OUT/bfc_f4.facts" "font C3 Calibri 9"
    assert r(found)
    outtab y1 y2, exposure(expo) estimator(logit, or) xlsx("$BFC_OUT/bfc_f5.xlsx") sheet("T") font(Verdana) fontsize(11)
    _bfc_facts "$BFC_OUT/bfc_f5.xlsx" T "$BFC_OUT/bfc_f5.facts"
    _bfc_hasline "$BFC_OUT/bfc_f5.facts" "font C3 Verdana 11"
    assert r(found)
    quietly tabtools set clear
}
if _rc == 0 {
    display as result "  PASS: C5 font() and fontsize() reach every cell; defaults Arial 10; 1 through 72"
    local ++pass_count
}
else {
    quietly tabtools set clear
    display as error "  FAIL: C5 font() and fontsize() (rc=`=_rc')"
    local ++fail_count
}

**# C6: grouplabels(): the column headers, the default labels, and the refusals
capture noisily {
    _bfc_data
    outtab y1 y2, exposure(expo) estimator(logit, or) grouplabels("Smokers" \ "Non-smokers") frame(_bfc6a, replace)
    frame _bfc6a {
        assert "`: variable label c1'" == "Smokers, events/N (%)"
        assert "`: variable label c2'" == "Non-smokers, events/N (%)"
    }
    * the exposed group is the first label: its counts are in c1
    quietly count if expo == 1 & y1 == 1
    local e1 = r(N)
    quietly count if expo == 1
    local n1 = r(N)
    frame _bfc6a: assert strpos(c1[1], "`e1'/`n1' (") == 1
    * default: the value labels of 1 and 0
    outtab y1, exposure(expo) estimator(logit, or) frame(_bfc6b, replace)
    frame _bfc6b {
        assert "`: variable label c1'" == "Exposed, events/N (%)"
        assert "`: variable label c2'" == "Unexposed, events/N (%)"
    }
    * default without value labels: the variable name and the code
    outtab y1, exposure(expo_nl) estimator(logit, or) frame(_bfc6c, replace)
    frame _bfc6c {
        assert "`: variable label c1'" == "expo_nl = 1, events/N (%)"
        assert "`: variable label c2'" == "expo_nl = 0, events/N (%)"
    }
    * exactly two labels
    capture outtab y1, exposure(expo) estimator(logit, or) grouplabels("Only one")
    assert _rc == 198
    capture outtab y1, exposure(expo) estimator(logit, or) grouplabels("A" \ "B" \ "C")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: C6 grouplabels() names the exposed group first; defaults from value labels; needs two labels"
    local ++pass_count
}
else {
    display as error "  FAIL: C6 grouplabels() (rc=`=_rc')"
    local ++fail_count
}

**# C7: sheet(), title(), footnote(), csv(), markdown() write what the Options entries say
capture noisily {
    _bfc_data
    capture erase "$BFC_OUT/bfc_s.csv"
    capture erase "$BFC_OUT/bfc_s.md"
    outtab y1 y2, exposure(expo) estimator(logit, or) xlsx("$BFC_OUT/bfc_s.xlsx") sheet("MySheet") ///
        title("My title") footnote("Note one. \ Note two.") csv("$BFC_OUT/bfc_s.csv") markdown("$BFC_OUT/bfc_s.md")
    _bfc_facts "$BFC_OUT/bfc_s.xlsx" MySheet "$BFC_OUT/bfc_s.facts"
    _bfc_hasline "$BFC_OUT/bfc_s.facts" "sheets MySheet"
    assert r(found)
    _bfc_hasline "$BFC_OUT/bfc_s.facts" "value A1 My title"
    assert r(found)
    _bfc_hasline "$BFC_OUT/bfc_s.facts" "value B5 Note one."
    assert r(found)
    _bfc_hasline "$BFC_OUT/bfc_s.facts" "value B6 Note two."
    assert r(found)
    * the default sheet name is Table
    outtab y1, exposure(expo) estimator(logit, or) xlsx("$BFC_OUT/bfc_s2.xlsx")
    _bfc_facts "$BFC_OUT/bfc_s2.xlsx" Table "$BFC_OUT/bfc_s2.facts"
    _bfc_hasline "$BFC_OUT/bfc_s2.facts" "sheets Table"
    assert r(found)
    * a second call to the same workbook with another sheet adds it; the same sheet name replaces it
    outtab y1, exposure(expo) estimator(logit, or) xlsx("$BFC_OUT/bfc_s.xlsx") sheet("Other")
    _bfc_facts "$BFC_OUT/bfc_s.xlsx" Other "$BFC_OUT/bfc_s3.facts"
    _bfc_hasline "$BFC_OUT/bfc_s3.facts" "sheets MySheet Other"
    assert r(found)
    outtab y1, exposure(expo) estimator(logit, or) xlsx("$BFC_OUT/bfc_s.xlsx") sheet("Other") title("Replaced")
    _bfc_facts "$BFC_OUT/bfc_s.xlsx" Other "$BFC_OUT/bfc_s3.facts"
    _bfc_hasline "$BFC_OUT/bfc_s3.facts" "sheets MySheet Other"
    assert r(found)
    _bfc_hasline "$BFC_OUT/bfc_s3.facts" "value A1 Replaced"
    assert r(found)
    * CSV: title first row, footnote paragraphs last, the table between
    _bfc_lines "$BFC_OUT/bfc_s.csv"
    local nc = r(n)
    assert `"`r(l1)'"' == "My title,,,"
    assert `"`r(l`nc')'"' == "Note two.,,,"
    assert `"`r(l`=`nc' - 1')'"' == "Note one.,,,"
    assert `nc' == 1 + 1 + 2 + 2
    assert strpos(`"`r(l2)'"', "Exposed, events/N (%)") > 0
    * Markdown: a heading, the table, the footnote in italics
    _bfc_lines "$BFC_OUT/bfc_s.md"
    assert `"`r(l1)'"' == "### My title"
    local nm = r(n)
    forvalues i = 1/`nm' {
        if `"`r(l`i')'"' == "*Note one.*" local seen1 1
        if `"`r(l`i')'"' == "*Note two.*" local seen2 1
    }
    assert "`seen1'" == "1" & "`seen2'" == "1"
    * extensions are enforced, and nothing is written on the refusal
    capture erase "$BFC_OUT/bfc_wrong.txt"
    capture outtab y1, exposure(expo) estimator(logit, or) csv("$BFC_OUT/bfc_wrong.txt")
    assert _rc != 0
    capture outtab y1, exposure(expo) estimator(logit, or) xlsx("$BFC_OUT/bfc_wrong.csv")
    assert _rc == 198
    * file options alone write nothing: no sink, no file, no error
    outtab y1, exposure(expo) estimator(logit, or) sheet("Nowhere") title("T") footnote("F") headershade font(Arial) fontsize(8) borderstyle(academic)
    assert "`r(xlsx)'" == ""
}
if _rc == 0 {
    display as result "  PASS: C7 sheet, title, footnote, csv, markdown write the documented cells, rows and lines"
    local ++pass_count
}
else {
    display as error "  FAIL: C7 sheet/title/footnote/csv/markdown (rc=`=_rc')"
    local ++fail_count
}

**# C8: frame(), and the returned r() surface that had no assertion
capture noisily {
    _bfc_data
    capture frame drop _bfc8
    outtab y1 y2, exposure(expo) estimator(logit, or) models("" \ "age") minevents(5) frame(_bfc8)
    assert "`r(frame)'" == "_bfc8"
    assert "`r(estimator)'" == "logit, or"
    assert r(minevents) == 5
    assert r(N_outcomes) == 2 & r(N_models) == 2 & r(N_rows) == 2 & r(N_panels) == 1
    assert "`r(xlsx)'" == ""
    frame _bfc8 {
        assert _N == 2
        confirm string variable rowlabel c1 c2 c3 c4
        assert rowlabel[1] == "Outcome one" & rowlabel[2] == "Outcome two"
    }
    * the same name is an error unless replace is given; the existing frame is left alone
    capture outtab y1, exposure(expo) estimator(logit, or) frame(_bfc8)
    assert _rc == 110
    frame _bfc8: assert _N == 2
    outtab y1, exposure(expo) estimator(logit, or) frame(_bfc8, replace)
    frame _bfc8: assert _N == 1
    capture outtab y1, exposure(expo) estimator(logit, or) frame(_bfc8x, keep)
    assert _rc == 198
    capture frame _bfc8x: describe
    assert _rc != 0
    * no frame(): none returned
    outtab y1, exposure(expo) estimator(logit, or)
    assert "`r(frame)'" == ""
    * an outcome count, an exposed-event count and a ratio equal hand values
    quietly count if y1 == 1 & expo == 1
    local e1 = r(N)
    matrix R = r(table)
    outtab y1, exposure(expo) estimator(logit, or) frame(_bfc8, replace)
    matrix R = r(table)
    assert R[1, 2] == `e1'
    quietly logit y1 expo, or
    matrix T = r(table)
    assert !missing(R[1, 5], T[1, 1]) & reldif(R[1, 5], T[1, 1]) < 1e-12
    capture frame drop _bfc8
}
if _rc == 0 {
    display as result "  PASS: C8 frame() and r(frame), r(estimator), r(minevents), r(N_outcomes), r(xlsx)"
    local ++pass_count
}
else {
    display as error "  FAIL: C8 frame() and r() surface (rc=`=_rc')"
    local ++fail_count
}

**# C9: ratetab level() and pydigits() as documented
capture noisily {
    clear
    input byte grp double(d py)
    0 4 10.25
    0 2 20.5
    0 0 31.125
    1 9 100.5
    1 3 200.25
    1 0 300.125
    end
    label define _bfg 0 "Control" 1 "Treated", replace
    label values grp _bfg
    label variable grp "Arm"
    label variable d "Events"
    * hand totals per arm
    quietly summarize d if grp == 0
    local D0 = r(sum)
    quietly summarize py if grp == 0
    local Y0 = r(sum)
    quietly summarize d if grp == 1
    local D1 = r(sum)
    quietly summarize py if grp == 1
    local Y1 = r(sum)
    assert `D0' == 6 & `D1' == 12
    assert !missing(`Y0', `Y1')
    * default: c(level), 0 decimals of person-time
    ratetab grp, events(d) exposure(py) frame(_bfc9a, replace)
    assert r(level) == 95 & r(ci_level) == 95
    matrix E = r(estimates)
    assert !missing(E[1, 5], E[2, 5], `Y0', `Y1') & reldif(E[1, 5], `Y0') < 1e-12 & reldif(E[2, 5], `Y1') < 1e-12
    frame _bfc9a {
        quietly count if c3 == string(round(`Y0'), "%12.0fc") & c2 == "6"
        assert r(N) == 1
        quietly count if strpos(c4, "Per 1,000 PY (95% CI)") > 0
        assert r(N) == 1
    }
    * level(90): the exact Garwood limits at 90%, in the header, in r(level)
    ratetab grp, events(d) exposure(py) level(90) pydigits(2) frame(_bfc9b, replace)
    assert r(level) == 90 & r(ci_level) == 90
    matrix F = r(estimates)
    local a = (1 - 0.90) / 2
    forvalues g = 0/1 {
        local i = `g' + 1
        local D = `D`g''
        local Y = `Y`g''
        local lo = 1000 * invchi2(2 * `D', `a') / 2 / `Y'
        local hi = 1000 * invchi2(2 * (`D' + 1), 1 - `a') / 2 / `Y'
        assert !missing(`lo', `hi', `Y', `D')
        assert !missing(F[`i', 7], F[`i', 8], F[`i', 6]) & reldif(F[`i', 7], `lo') < 1e-8
        assert !missing(F[`i', 8], `hi') & reldif(F[`i', 8], `hi') < 1e-8
        assert !missing(F[`i', 6], 1000 * `D' / `Y') & reldif(F[`i', 6], 1000 * `D' / `Y') < 1e-12
    }
    * the 90% limits are narrower than the 95% ones
    assert F[1, 7] > E[1, 7] & F[1, 8] < E[1, 8]
    * pydigits(2): the printed person-time has two decimals; the numbers are unchanged
    assert F[1, 5] == E[1, 5] & F[2, 5] == E[2, 5]
    frame _bfc9b {
        quietly count if c3 == string(`Y0', "%12.2fc")
        assert r(N) == 1
        quietly count if c3 == string(`Y1', "%12.2fc")
        assert r(N) == 1
        quietly count if strpos(c4, "Per 1,000 PY (90% CI)") > 0
        assert r(N) == 1
    }
    * level() under another CI method, and the c(level) default follows set level
    ratetab grp, events(d) exposure(py) ci(poisson) level(80)
    assert r(level) == 80
    set level 90
    ratetab grp, events(d) exposure(py)
    assert r(level) == 90
    set level 95
    * the ranges
    foreach l in 9 9.99 100 {
        capture ratetab grp, events(d) exposure(py) level(`l')
        assert _rc == 198
    }
    foreach l in 10 99.99 {
        ratetab grp, events(d) exposure(py) level(`l')
        assert r(level) == `l'
    }
    foreach p in -1 11 {
        capture ratetab grp, events(d) exposure(py) pydigits(`p')
        assert _rc == 198
    }
    foreach p in 0 10 {
        ratetab grp, events(d) exposure(py) pydigits(`p')
    }
    capture frame drop _bfc9a
    capture frame drop _bfc9b
}
if _rc == 0 {
    display as result "  PASS: C9 ratetab level() gives the Garwood limits at that level; pydigits() prints, never rounds the numbers"
    local ++pass_count
}
else {
    set level 95
    display as error "  FAIL: C9 ratetab level() and pydigits() (rc=`=_rc')"
    local ++fail_count
}

**# C10: tabcell p(), median(), q1(), q3() and the generate() results
capture noisily {
    tabcell p, p(0.0499)
    assert "`r(cell)'" == "0.050" & "`r(form)'" == "p"
    tabcell p, p(0.0004)
    assert "`r(cell)'" == "<0.001"
    tabcell p, p(0.5)
    assert "`r(cell)'" == "0.50"
    tabcell p, p(0) pdp(2)
    assert "`r(cell)'" == "<0.01"
    tabcell p, p(0.995)
    assert "`r(cell)'" == ">0.99"
    foreach bad in 1.2 -0.1 {
        capture tabcell p, p(`bad')
        assert _rc == 198
    }
    capture tabcell p, p(.)
    assert _rc == 459
    tabcell p, p(.) missing("n/a")
    assert "`r(cell)'" == "n/a" & r(missing) == 1
    capture tabcell p
    assert _rc == 198
    * p() is an expression in the data with generate()
    clear
    set obs 3
    gen double pv = cond(_n == 1, 0.0499, cond(_n == 2, 0.0004, 0.5))
    tabcell p, p(pv) generate(pc)
    assert pc[1] == "0.050" & pc[2] == "<0.001" & pc[3] == "0.50"
    assert r(N) == 3 & r(N_missing) == 0 & "`r(varname)'" == "pc" & "`r(form)'" == "p"
    * iqr: median (Q1, Q3)
    tabcell iqr, median(20) q1(18) q3(25) format(%4.0f)
    assert "`r(cell)'" == "20 (18, 25)" & "`r(form)'" == "iqr"
    assert r(missing) == 0
    tabcell iqr, median(20) q1(18) q3(25) digits(1) sep(" to ")
    assert "`r(cell)'" == "20.0 (18.0 to 25.0)"
    * the median may equal either quartile, not lie outside them; Q1 may not exceed Q3
    tabcell iqr, median(18) q1(18) q3(25) format(%4.0f)
    assert "`r(cell)'" == "18 (18, 25)"
    tabcell iqr, median(25) q1(18) q3(25) format(%4.0f)
    assert "`r(cell)'" == "25 (18, 25)"
    capture tabcell iqr, median(17) q1(18) q3(25)
    assert _rc == 198
    capture tabcell iqr, median(26) q1(18) q3(25)
    assert _rc == 198
    capture tabcell iqr, median(20) q1(26) q3(25)
    assert _rc == 198
    * all three are required
    capture tabcell iqr, median(20) q1(18)
    assert _rc == 198
    capture tabcell iqr, median(20) q3(25)
    assert _rc == 198
    capture tabcell iqr, q1(18) q3(25)
    assert _rc == 198
    * a missing number is refused unless missing() gives the text
    capture tabcell iqr, median(.) q1(18) q3(25)
    assert _rc == 459
    tabcell iqr, median(.) q1(18) q3(25) missing("n/a")
    assert "`r(cell)'" == "n/a" & r(missing) == 1
    * expressions in the data with generate(): r(N), r(N_missing), r(varname)
    clear
    set obs 4
    gen double m = cond(_n == 4, ., 10 * _n)
    gen double lo = m - 2
    gen double hi = m + 3
    tabcell iqr, median(m) q1(lo) q3(hi) format(%4.0f) missing("-") generate(cell)
    assert cell[1] == "10 (8, 13)" & cell[2] == "20 (18, 23)" & cell[3] == "30 (28, 33)" & cell[4] == "-"
    * r(N) counts the rows printed with a number, r(N_missing) those given the text
    assert r(N) == 3 & r(N_missing) == 1 & "`r(varname)'" == "cell" & "`r(form)'" == "iqr"
    * p() and median() are refused with the wrong form
    capture tabcell iqr, median(20) q1(18) q3(25) p(0.5)
    assert _rc == 198
    capture tabcell p, p(0.5) median(20)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: C10 tabcell p(), median(), q1(), q3(): values, ranges, requirements, generate() results"
    local ++pass_count
}
else {
    display as error "  FAIL: C10 tabcell p() and iqr (rc=`=_rc')"
    local ++fail_count
}

**# C11: every option of the three synopsis tables has a prose entry in its Options section
capture noisily {
    foreach n in "{opt groupl:abels(" "{opt xlsx(" "{opt excel(" "{opt sheet(" "{opt title(" "{opt footnote(" ///
        "{opt csv(" "{opt mark:down(" "{opt mdapp:end}" "{opt fra:me(" "{opt border:style(" "{opt headers:hade}" ///
        "{opt font(" "{opt fontsize(" {
        _bfc_optsection "$BFC_PKG/outtab.sthlp" `"`n'"'
        if !r(found) display as error `"outtab.sthlp: no Options entry with `n'"'
        assert r(found)
    }
    foreach n in "{opt level(#)}" "{opt pydigits(#)}" {
        _bfc_optsection "$BFC_PKG/ratetab.sthlp" `"`n'"'
        if !r(found) display as error `"ratetab.sthlp: no Options entry with `n'"'
        assert r(found)
    }
    foreach n in "{opt p(#)}" "{opt median(#)}" "{opt q1(#)}" "{opt q3(#)}" {
        _bfc_optsection "$BFC_PKG/tabcell.sthlp" `"`n'"'
        if !r(found) display as error `"tabcell.sthlp: no Options entry with `n'"'
        assert r(found)
    }
    * the stored results the generate() path posts are in the Stored results table
    foreach n in "{synopt:{cmd:r(N)}}" "{synopt:{cmd:r(N_missing)}}" "{synopt:{cmd:r(varname)}}" "{synopt:{cmd:r(lincom_}" {
        tempname h
        local found 0
        file open `h' using "$BFC_PKG/tabcell.sthlp", read text
        file read `h' line
        while r(eof) == 0 {
            if strpos(`"`macval(line)'"', `"`n'"') == 1 local found 1
            file read `h' line
        }
        file close `h'
        assert `found'
    }
}
if _rc == 0 {
    display as result "  PASS: C11 each option and result named in the bug report has a prose entry in its help file"
    local ++pass_count
}
else {
    display as error "  FAIL: C11 help-file entries (rc=`=_rc')"
    local ++fail_count
}

**# C12: puttab key-column note with an unresolvable varlist still errors on the bad name
capture noisily {
    clear
    set obs 3
    gen str5 a = "x"
    gen str5 b = "y"
    char b[tabtools_key] 1
    capture puttab a nosuchvar using "$BFC_OUT/bfc_pt.xlsx", sheet("T")
    assert _rc == 111
    capture confirm file "$BFC_OUT/bfc_pt.xlsx"
    assert _rc == 601
    * a valid varlist that names the key column literally exports it
    puttab a b using "$BFC_OUT/bfc_pt.xlsx", sheet("T")
    _bfc_facts "$BFC_OUT/bfc_pt.xlsx" T "$BFC_OUT/bfc_pt.facts"
    _bfc_countprefix "$BFC_OUT/bfc_pt.facts" "value C"
    assert !missing(r(n)) & r(n) > 0
    * a key column the varlist does not name is left out, with a note
    puttab a using "$BFC_OUT/bfc_pt2.xlsx", sheet("T")
    _bfc_facts "$BFC_OUT/bfc_pt2.xlsx" T "$BFC_OUT/bfc_pt2.facts"
    _bfc_countprefix "$BFC_OUT/bfc_pt2.facts" "value C"
    assert r(n) == 0
    _bfc_countprefix "$BFC_OUT/bfc_pt2.facts" "value B"
    assert !missing(r(n)) & r(n) > 0
}
if _rc == 0 {
    display as result "  PASS: C12 puttab: a bad name in the varlist still stops the export (unab capture in the key-column note)"
    local ++pass_count
}
else {
    display as error "  FAIL: C12 puttab varlist with key columns (rc=`=_rc')"
    local ++fail_count
}

**# C13: queued cell-style rules left by an interrupted export do not reach the next one, and a clean start needs no external
capture noisily {
    sysuse auto, clear
    * no externals: the clear at the start of an export is silent
    mata: (void) rmexternal("_tt_xp_rules")
    mata: (void) rmexternal("_tt_xp_meta")
    puttab make price mpg using "$BFC_OUT/bfc_ex0.xlsx" in 1/3, sheet("T")
    * stale externals from an earlier export that stopped before compaction
    mata: (void) crexternal("_tt_xp_rules")
    mata: (void) crexternal("_tt_xp_meta")
    mata: st_numscalar("_bfc_stale", findexternal("_tt_xp_rules") != NULL & findexternal("_tt_xp_meta") != NULL)
    assert scalar(_bfc_stale) == 1
    puttab make price mpg using "$BFC_OUT/bfc_ex1.xlsx" in 1/3, sheet("T")
    mata: st_numscalar("_bfc_stale", findexternal("_tt_xp_rules") != NULL | findexternal("_tt_xp_meta") != NULL)
    assert scalar(_bfc_stale) == 0
    * the two workbooks hold the same cells
    quietly import excel using "$BFC_OUT/bfc_ex0.xlsx", sheet("T") allstring clear
    tempfile f0
    quietly save `f0'
    quietly import excel using "$BFC_OUT/bfc_ex1.xlsx", sheet("T") allstring clear
    unab v1 : _all
    preserve
    quietly use `f0', clear
    unab v0 : _all
    restore
    assert "`v1'" == "`v0'"
    cf _all using `f0'
    quietly count
    * the margin row, the header row, and the three data rows
    assert r(N) == 5
}
if _rc == 0 {
    display as result "  PASS: C13 stale queued style rules are cleared before an export; the workbook is unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: C13 stale style rules (rc=`=_rc')"
    local ++fail_count
}

local _tc = `pass_count' + `fail_count'
display "RESULT: test_bugfix_2026_10_06_c tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _bfc
if `fail_count' > 0 exit 1
