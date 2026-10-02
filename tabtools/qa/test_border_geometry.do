* test_border_geometry.do - boxed border layout and puttab hlines()/vlines()/boldrows()
*
* 2.2.0: puttab, corrtab, crosstab and survtab draw the suite's boxed layout
* under the default, thin and medium border styles -- a box around the table
* body (header row + data rows), the header row closed by its rules, and a
* rule right of the row-label column -- as regtab/desctab/stratetab already
* did. borderstyle(academic) keeps horizontal rules only. puttab adds
* hlines() (rule above data row #), vlines() (rule right of column #) and
* boldrows() (bold data row #); a row or column outside the table errors.
*
* Expected geometry is written out cell by cell from that specification, and
* the workbook is read back with openpyxl (tools/xlsx_facts.py), never through
* the Mata xl() writer under test.

clear all
set more off
set varabbrev off
version 17.0

capture log close _bg
log using "test_border_geometry.log", replace text name(_bg)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global BG_TOOL "`qa_dir'/tools/xlsx_facts.py"
global BG_RES "`output_dir'/bg_facts.txt"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

**# Helpers
* Read the layout facts of sheet `sheet' of `book' into $BG_RES.
capture program drop _bg_facts
program define _bg_facts
    version 17.0
    args book sheet
    capture erase "$BG_RES"
    shell python3 "$BG_TOOL" "`book'" "`sheet'" "$BG_RES"
    confirm file "$BG_RES"
end

* Every cell in `cells' carries fact "`kind' <cell> `style'" (style may be
* empty for bold). Exits 9 naming the first cell that does not.
capture program drop _bg_has
program define _bg_has
    version 17.0
    args kind style cells
    foreach c of local cells {
        local want = strtrim("`kind' `c' `style'")
        mata: st_local("_n", strofreal(sum(cat("$BG_RES") :== st_local("want"))))
        if `_n' != 1 {
            display as error "missing fact: `want'"
            exit 9
        }
    }
end

* No cell in `cells' carries any `kind' fact (any style).
capture program drop _bg_none
program define _bg_none
    version 17.0
    args kind cells
    foreach c of local cells {
        local pre "`kind' `c'"
        mata: _f = cat("$BG_RES"); st_local("_n", strofreal(sum((_f :== st_local("pre")) :| ///
            (substr(_f, 1, strlen(st_local("pre")) + 1) :== st_local("pre") + " "))))
        if `_n' != 0 {
            display as error "unexpected fact: `pre'"
            exit 9
        }
    }
end

* Number of `kind' facts on the sheet.
capture program drop _bg_count
program define _bg_count, rclass
    version 17.0
    args kind
    mata: _f = cat("$BG_RES"); st_local("_n", strofreal(sum(substr(_f, 1, ///
        strlen("`kind'") + 1) :== "`kind' ")))
    return scalar n = `_n'
end

**# puttab default (thin): box, header box, row-label column
* Layout: title row 1, header row 2 (B..D), data rows 3..5, footnote row 6.
local ++test_count
capture noisily {
    local book "`output_dir'/bg_puttab.xlsx"
    capture erase "`book'"
    sysuse auto, clear
    puttab make price mpg in 1/3 using "`book'", sheet("thin") ///
        title("T") footnote("note")
    _bg_facts "`book'" "thin"
    _bg_has left thin "B2 B3 B4 B5"
    _bg_has right thin "D2 D3 D4 D5"
    _bg_has right thin "B2 B3 B4 B5"
    _bg_has top thin "B2 C2 D2"
    _bg_has bottom thin "B2 C2 D2 B5 C5 D5"
    * interior data cells carry no vertical rules
    _bg_none left "C3 D3 C4"
    _bg_none right "C2 C3 C4 C5"
    * title row and footnote row sit outside the box
    _bg_none left "A1 B1 B6"
    _bg_none right "D1 D6"
    * the header row only (title cell A1 is bold too)
    _bg_has bold "" "A1 B2 C2 D2"
    _bg_none bold "B3 C3 D3 B5"
}
if _rc == 0 {
    display as result "  PASS: puttab thin box, header box and row-label rule"
    local ++pass_count
}
else {
    display as error "  FAIL: puttab thin box geometry (rc=`=_rc')"
    local ++fail_count
}

**# puttab medium: same geometry, medium weight
local ++test_count
capture noisily {
    local book "`output_dir'/bg_puttab.xlsx"
    sysuse auto, clear
    puttab make price mpg in 1/3 using "`book'", sheet("medium") borderstyle(medium)
    _bg_facts "`book'" "medium"
    _bg_has left medium "B2 B3 B4 B5"
    _bg_has right medium "D2 D3 D4 D5 B2 B3 B4 B5"
    _bg_has bottom medium "B2 D2 B5 D5"
    _bg_none right "C3"
    _bg_none left "C3"
}
if _rc == 0 {
    display as result "  PASS: puttab medium box"
    local ++pass_count
}
else {
    display as error "  FAIL: puttab medium box (rc=`=_rc')"
    local ++fail_count
}

**# puttab academic: horizontal rules only, explicit and via tabtools set
local ++test_count
capture noisily {
    local book "`output_dir'/bg_puttab.xlsx"
    sysuse auto, clear
    puttab make price mpg in 1/3 using "`book'", sheet("acad") borderstyle(academic)
    _bg_facts "`book'" "acad"
    _bg_count left
    assert r(n) == 0
    _bg_count right
    assert r(n) == 0
    _bg_has top medium "B2 C2 D2"
    _bg_has bottom medium "B2 D2 B5 D5"

    tabtools set borderstyle academic
    puttab make price mpg in 1/3 using "`book'", sheet("acadset")
    tabtools set clear
    _bg_facts "`book'" "acadset"
    _bg_count left
    assert r(n) == 0
    _bg_count right
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: puttab academic draws no vertical rules"
    local ++pass_count
}
else {
    display as error "  FAIL: puttab academic verticals (rc=`=_rc')"
    local ++fail_count
}
capture tabtools set clear

**# puttab noheader and matrix(): box starts at the first data row
local ++test_count
capture noisily {
    local book "`output_dir'/bg_puttab.xlsx"
    sysuse auto, clear
    puttab make price mpg in 1/3 using "`book'", sheet("nohdr") noheader
    _bg_facts "`book'" "nohdr"
    * no title -> blank row 1; data rows 2..4
    _bg_has left thin "B2 B3 B4"
    _bg_has right thin "B2 B3 B4 D2 D3 D4"
    _bg_has top thin "B2 C2 D2"
    _bg_none left "B1 B5"

    matrix bg_M = (1.5, 0.2 \ 2.25, 0.3)
    matrix rownames bg_M = x1 x2
    matrix colnames bg_M = b se
    puttab using "`book'", sheet("mat") matrix(bg_M)
    _bg_facts "`book'" "mat"
    _bg_has left thin "B2 B3 B4"
    _bg_has right thin "B2 B3 B4 D2 D3 D4"
    _bg_none right "C2 C3 C4"
}
if _rc == 0 {
    display as result "  PASS: puttab box under noheader and matrix()"
    local ++pass_count
}
else {
    display as error "  FAIL: puttab noheader/matrix box (rc=`=_rc')"
    local ++fail_count
}

**# puttab hlines()/vlines()/boldrows(): a second table stacked in one source
* Data rows 1..5 -> Excel rows 3..7; data row 3 is the second table's header.
local ++test_count
capture noisily {
    local book "`output_dir'/bg_puttab.xlsx"
    clear
    input str12 group str6 n str8 price
    "Domestic" "52" "6,072"
    "Foreign" "22" "6,385"
    "Repair" "N" "Price"
    "Good (4-5)" "29" "6,013"
    "Poor (1-3)" "40" "6,118"
    end
    puttab group n price using "`book'", sheet("stack") title("T") ///
        hlines(3 4) vlines(2) boldrows(3)
    assert r(n_datarows) == 5
    _bg_facts "`book'" "stack"
    * hlines(3 4): rules above Excel rows 5 and 6, across the table
    _bg_has top thin "B5 C5 D5 B6 C6 D6"
    _bg_none top "B4 B7"
    * vlines(2): rule right of column 2 (C) from the header to the last row
    _bg_has right thin "C2 C3 C4 C5 C6 C7"
    _bg_none right "C1 C8"
    * boldrows(3): Excel row 5 only, among data rows
    _bg_has bold "" "B5 C5 D5"
    _bg_none bold "B3 B4 B6 B7 C4 D6"

    * the user rules still apply under academic, with no box; with no
    * title the body still starts at row 2, so data row 3 is Excel row 5
    puttab group n price using "`book'", sheet("stackac") ///
        hlines(3) vlines(1) boldrows(3) borderstyle(academic)
    _bg_facts "`book'" "stackac"
    _bg_has top thin "B5 C5 D5"
    _bg_has right thin "B2 B3 B4 B5 B6 B7"
    _bg_none left "B2 B3"
    _bg_none right "D2 D3 C3 B8"
    _bg_has bold "" "B5 C5 D5"
    _bg_none bold "B4 B6"
}
if _rc == 0 {
    display as result "  PASS: puttab hlines/vlines/boldrows place exactly"
    local ++pass_count
}
else {
    display as error "  FAIL: puttab hlines/vlines/boldrows (rc=`=_rc')"
    local ++fail_count
}

**# puttab hlines()/vlines()/boldrows() refuse cells outside the table
local ++test_count
capture noisily {
    local book "`output_dir'/bg_puttab_err.xlsx"
    sysuse auto, clear
    foreach o in "hlines(4)" "boldrows(4)" "vlines(4)" "hlines(0)" "vlines(0)" "boldrows(1.5)" {
        capture erase "`book'"
        capture puttab make price mpg in 1/3 using "`book'", `o'
        local _orc = _rc
        if !inlist(`_orc', 125, 126) {
            display as error "`o' returned rc=`_orc'"
            exit 9
        }
        * refused before any sink is written
        capture confirm file "`book'"
        assert _rc == 601
    }
    * the boundary itself is inside the table
    capture erase "`book'"
    puttab make price mpg in 1/3 using "`book'", hlines(3) boldrows(3) vlines(3)
    confirm file "`book'"
    * Markdown-only output validates the same way
    capture puttab make price mpg in 1/3, markdown("`output_dir'/bg_err.md") hlines(9)
    assert _rc == 125
}
if _rc == 0 {
    display as result "  PASS: out-of-range hlines/vlines/boldrows error before export"
    local ++pass_count
}
else {
    display as error "  FAIL: out-of-range user rules (rc=`=_rc')"
    local ++fail_count
}

**# corrtab: box under thin/medium, none under academic
* Layout: title row 1, header row 2 (B..E), data rows 3..5, star note row 6.
local ++test_count
capture noisily {
    local book "`output_dir'/bg_corrtab.xlsx"
    capture erase "`book'"
    sysuse auto, clear
    corrtab price mpg weight, xlsx("`book'") sheet("thin") title("T")
    _bg_facts "`book'" "thin"
    _bg_has left thin "B2 B3 B4 B5"
    _bg_has right thin "B2 B3 B4 B5 E2 E3 E4 E5"
    _bg_none right "C3 D4"
    _bg_none left "B6 B1"

    corrtab price mpg weight, xlsx("`book'") sheet("med") borderstyle(medium)
    _bg_facts "`book'" "med"
    _bg_has left medium "B2 B5"
    _bg_has right medium "B2 B5 E2 E5"

    corrtab price mpg weight, xlsx("`book'") sheet("acad") borderstyle(academic)
    _bg_facts "`book'" "acad"
    _bg_count left
    assert r(n) == 0
    _bg_count right
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: corrtab boxed layout by border style"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab boxed layout (rc=`=_rc')"
    local ++fail_count
}

**# crosstab: box through the measure row, row-label rule stops at Total
* Layout: header row 2, rep78 rows 3..7, Total row 8, Fisher's exact row 9
* (merged across the table, so no row-label rule there).
local ++test_count
capture noisily {
    local book "`output_dir'/bg_crosstab.xlsx"
    capture erase "`book'"
    sysuse auto, clear
    crosstab rep78 foreign, xlsx("`book'") sheet("thin") title("T") label
    _bg_facts "`book'" "thin"
    mata: st_local("_tot", strofreal(sum(cat("$BG_RES") :== "value B8 Total")))
    assert `_tot' == 1
    mata: st_local("_fx", strofreal(sum(strpos(cat("$BG_RES"), "value B9 Fisher") :== 1)))
    assert `_fx' == 1
    _bg_has left thin "B2 B3 B8 B9"
    _bg_has right thin "E2 E3 E8 E9"
    _bg_has right thin "B2 B3 B4 B5 B6 B7 B8"
    _bg_none right "B9 C5"

    crosstab rep78 foreign, xlsx("`book'") sheet("acad") borderstyle(academic)
    _bg_facts "`book'" "acad"
    _bg_count left
    assert r(n) == 0
    _bg_count right
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: crosstab boxed layout, measure row unsplit"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab boxed layout (rc=`=_rc')"
    local ++fail_count
}

**# survtab: box under thin, none under academic
* Layout: header row 2 (B..E), rows 3..7 (section, 3 times, log-rank).
local ++test_count
capture noisily {
    local book "`output_dir'/bg_survtab.xlsx"
    capture erase "`book'"
    webuse drugtr, clear
    quietly stset studytime, failure(died)
    survtab, times(10 20 30) by(drug) xlsx("`book'") sheet("thin") title("T")
    _bg_facts "`book'" "thin"
    mata: st_local("_lr", strofreal(sum(strpos(cat("$BG_RES"), "value B7 Log-rank") :== 1)))
    assert `_lr' == 1
    _bg_has left thin "B2 B3 B4 B5 B6 B7"
    _bg_has right thin "B2 B7 E2 E3 E7"
    _bg_none right "C4 D4"
    _bg_none left "B1 B8"

    survtab, times(10 20 30) by(drug) xlsx("`book'") sheet("acad") borderstyle(academic)
    _bg_facts "`book'" "acad"
    _bg_count left
    assert r(n) == 0
    _bg_count right
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: survtab boxed layout by border style"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab boxed layout (rc=`=_rc')"
    local ++fail_count
}

capture erase "$BG_RES"
macro drop BG_TOOL BG_RES
display "RESULT: test_border_geometry tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _bg
if `fail_count' > 0 exit 1
