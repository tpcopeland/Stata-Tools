* test_puttab_v230.do - puttab 2.3.0: panel(), panelheader(), spanheader(),
* multi-paragraph footnote(), and the embedded-header contract (D2)
*
* Expected cells, borders, merges and bold are written out from the option
* contracts and read back with openpyxl (tools/xlsx_facts.py); CSV and
* Markdown are read line by line. Nothing is checked through the xl() writer.

clear all
set more off
set varabbrev off
version 17.0

capture log close _pt230
log using "test_puttab_v230.log", replace text name(_pt230)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global V230_TOOL "`qa_dir'/tools/xlsx_facts.py"
global V230_RES "`output_dir'/pt230_facts.txt"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear
run "`qa_dir'/_qa_v230_helpers.do"

* Fixture: two panels (A: two rows, B: one row) with per-panel header text.
* Built at file level (input cannot sit inside a program) and reloaded.
clear
input str20 lab str8(a b c) byte blk str10(h1 h2 h3 h4)
"Age <55" "1" "2" "3" 1 "" "Events" "PY" "Rate"
"Age 55+" "4" "5" "6" 1 "" "Events" "PY" "Rate"
"Repleted" "7" "8" "9" 2 "" "Scans" "Pct" "RR"
end
label define blk 1 "A. Relapses" 2 "B. MRI", replace
label values blk blk
label variable lab "Row"
label variable a "Col A"
label variable b "Col B"
label variable c "Col C"
tempfile pt230_fixture
quietly save "`pt230_fixture'"
global PT230_FIX "`pt230_fixture'"
capture program drop _pt230_data
program define _pt230_data
    quietly use "$PT230_FIX", clear
end

**# panel(): heading rows, indent, rules, all three sinks
local ++test_count
capture noisily {
    local book "`output_dir'/pt230_panel.xlsx"
    local csv "`output_dir'/pt230_panel.csv"
    local md "`output_dir'/pt230_panel.md"
    capture erase "`book'"
    _pt230_data
    puttab lab a b c using "`book'", sheet("P") panel(blk) varlabels ///
        title("T") csv("`csv'") markdown("`md'")
    assert r(n_panels) == 2
    assert r(n_datarows) == 5
    assert r(n_cols) == 4
    * Layout: title 1, header 2, heading A 3, rows 4-5, heading B 6, row 7.
    _v_facts "`book'" "P"
    _v_value B2 "Row"
    _v_value B3 "A. Relapses"
    _v_empty C3
    _v_value B4 "   Age <55"
    _v_value C4 "1"
    _v_value B5 "   Age 55+"
    _v_value B6 "B. MRI"
    _v_value B7 "   Repleted"
    _v_value E7 "9"
    _v_has merge "" "B3:E3 B6:E6"
    _v_has bold "" "B3 B6"
    _v_none bold "B4 B5 B7"
    _v_has top thin "B3 C3 D3 E3 B6 C6 D6 E6"
    _v_none top "B4 B5 B7"
    * panel variable is not exported: four columns, nothing in F
    _v_none value "F2 F3 F4"
    _v_line "`csv'" "A. Relapses,,," 1
    _v_line "`csv'" "   Age <55,1,2,3" 1
    _v_line "`csv'" "B. MRI,,," 1
    _v_line "`csv'" "   Repleted,7,8,9" 1
    _v_line "`md'" "| **A. Relapses** |  |  |  |" 1
    _v_line "`md'" "| &nbsp;&nbsp;&nbsp;Age \<55 | 1 | 2 | 3 |" 1
    _v_line "`md'" "| **B. MRI** |  |  |  |" 1
    _v_line "`md'" "| Row | Col A | Col B | Col C |" 1
}
if _rc == 0 {
    display as result "  PASS: panel() heading rows, indent, rules in xlsx/csv/md"
    local ++pass_count
}
else {
    display as error "  FAIL: panel() heading rows (rc=`=_rc')"
    local ++fail_count
}

**# panelheader(): a header row under each heading
local ++test_count
capture noisily {
    local book "`output_dir'/pt230_phdr.xlsx"
    local md "`output_dir'/pt230_phdr.md"
    capture erase "`book'"
    _pt230_data
    puttab lab a b c using "`book'", sheet("H") panel(blk) ///
        panelheader(h1 h2 h3 h4) noheader headershade markdown("`md'")
    assert r(n_panels) == 2
    * noheader: heading A 2, its header 3, rows 4-5, heading B 6, header 7, row 8
    assert r(n_datarows) == 7
    _v_facts "`book'" "H"
    _v_value B2 "A. Relapses"
    _v_value C3 "Events"
    _v_value E3 "Rate"
    _v_empty B3
    _v_value B6 "B. MRI"
    _v_value C7 "Scans"
    _v_value D7 "Pct"
    _v_value B8 "   Repleted"
    _v_has bold "" "C3 D3 E3 C7 D7 E7"
    _v_has bottom thin "B3 C3 D3 E3 B7 C7 D7 E7"
    * panel header text variables are never exported
    _v_none value "F3 G3 H3 I3"
    _v_line "`md'" "|  | **Events** | **PY** | **Rate** |" 1
    _v_line "`md'" "|  | **Scans** | **Pct** | **RR** |" 1
}
if _rc == 0 {
    display as result "  PASS: panelheader() repeats each panel's own header"
    local ++pass_count
}
else {
    display as error "  FAIL: panelheader() (rc=`=_rc')"
    local ++fail_count
}

**# panel(): string and unlabelled numeric values; missing value gets no heading
local ++test_count
capture noisily {
    local csv "`output_dir'/pt230_pvals.csv"
    clear
    input str8 lab str4 v double g str6 s
    "r1" "1" . "x"
    "r2" "2" 3 "x"
    "r3" "3" 3 "y"
    "r4" "4" 7 "y"
    end
    format g %4.1f
    * numeric, no value label: heading text is the value as puttab writes
    * numbers (an integer-valued column without decimals); the leading
    * missing run has no heading and is not indented.
    puttab lab v, panel(g) markdown("`output_dir'/pt230_pvals.md") csv("`csv'") noheader
    assert r(n_panels) == 2
    _v_line "`csv'" "r1,1" 1
    _v_line "`csv'" "3," 1
    _v_line "`csv'" "   r2,2" 1
    _v_line "`csv'" "7," 1
    * string panel variable
    puttab lab v, panel(s) markdown("`output_dir'/pt230_pvals.md") csv("`csv'") noheader
    assert r(n_panels) == 2
    _v_line "`csv'" "x," 1
    _v_line "`csv'" "y," 1
    _v_line "`csv'" "   r3,3" 1
    * a panel variable listed in the varlist is still not exported
    puttab lab v s, panel(s) markdown("`output_dir'/pt230_pvals.md") csv("`csv'") noheader
    assert r(n_cols) == 2
}
if _rc == 0 {
    display as result "  PASS: panel() value text, missing run, varlist overlap"
    local ++pass_count
}
else {
    display as error "  FAIL: panel() value text (rc=`=_rc')"
    local ++fail_count
}

**# panel()/panelheader() refusals
local ++test_count
capture noisily {
    _pt230_data
    local md "`output_dir'/pt230_ref.md"
    capture puttab lab a b c, markdown("`md'") panelheader(h1 h2 h3 h4)
    assert _rc == 198
    capture puttab lab a b c, markdown("`md'") panel(blk) panelheader(h1 h2)
    assert _rc == 198
    capture puttab lab a b c, markdown("`md'") panel(blk) panelheader(h1 h2 h3 blk)
    assert _rc == 109
    capture puttab lab a b c, markdown("`md'") panel(nosuch)
    assert _rc == 111
    capture puttab lab a b c, markdown("`md'") panel(blk lab)
    assert _rc == 198
    gen str4 hb = ""
    capture puttab lab a b c, markdown("`md'") panel(hb) panelheader(h1 h2 hb h4)
    assert _rc == 198
    matrix M = (1, 2 \ 3, 4)
    capture puttab, matrix(M) markdown("`md'") panel(blk)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: panel()/panelheader() refuse bad specifications"
    local ++pass_count
}
else {
    display as error "  FAIL: panel() refusals (rc=`=_rc')"
    local ++fail_count
}

**# spanheader(): merged spanning labels, rules, CSV row, Markdown fold
local ++test_count
capture noisily {
    local book "`output_dir'/pt230_span.xlsx"
    local csv "`output_dir'/pt230_span.csv"
    local md "`output_dir'/pt230_span.md"
    capture erase "`book'"
    _pt230_data
    puttab lab a b c using "`book'", sheet("S") varlabels title("T") ///
        spanheader("Span AB" 2/3) csv("`csv'") markdown("`md'")
    assert r(n_spans) == 1
    assert r(n_datarows) == 3
    * title 1, span row 2, header 3, data 4-6
    _v_facts "`book'" "S"
    _v_value C2 "Span AB"
    _v_empty B2
    _v_empty E2
    _v_has merge "" "C2:D2"
    _v_has bottom thin "C2 D2"
    _v_none bottom "B2 E2"
    _v_has bold "" "C2"
    * the table's top rule is above the span row, not the header row
    _v_has top thin "B2 C2 D2 E2"
    _v_none top "B3 C3 D3 E3"
    _v_has bottom thin "B3 C3 D3 E3"
    _v_value C3 "Col A"
    _v_value B4 "Age <55"
    _v_line "`csv'" ",Span AB,," 1
    _v_line "`csv'" "Row,Col A,Col B,Col C" 1
    _v_line "`md'" "| Row | Span AB, Col A | Span AB, Col B | Col C |" 1

    * two spans; a one-column span is not merged
    puttab lab a b c using "`book'", sheet("S2") varlabels ///
        spanheader(`"x"' 2 \ "y z" 3/4)
    assert r(n_spans) == 2
    _v_facts "`book'" "S2"
    _v_value C2 "x"
    _v_value D2 "y z"
    _v_has merge "" "D2:E2"
    _v_none merge "C2:C2"
    _v_has bottom thin "C2 D2 E2"
}
if _rc == 0 {
    display as result "  PASS: spanheader() geometry and sink equivalents"
    local ++pass_count
}
else {
    display as error "  FAIL: spanheader() (rc=`=_rc')"
    local ++fail_count
}

**# spanheader() refusals
local ++test_count
capture noisily {
    _pt230_data
    local md "`output_dir'/pt230_ref.md"
    capture puttab lab a b c, markdown("`md'") spanheader("x" 2/3 \ "y" 3/4)
    assert _rc == 198
    capture puttab lab a b c, markdown("`md'") spanheader("x" 2/5)
    assert _rc == 125
    capture puttab lab a b c, markdown("`md'") spanheader("x" 0/1)
    assert _rc == 125
    capture puttab lab a b c, markdown("`md'") spanheader(x 2/3)
    assert _rc == 198
    capture puttab lab a b c, markdown("`md'") spanheader("x" 3/2)
    assert _rc == 198
    capture puttab lab a b c, markdown("`md'") spanheader("" 2/3)
    assert _rc == 198
    capture puttab lab a b c, markdown("`md'") spanheader("x" 2/3 "y" 4)
    assert _rc == 198
    capture puttab lab a b c, markdown("`md'") spanheader("x")
    assert _rc == 198
    capture puttab lab a b c, markdown("`md'") spanheader("x" 2/3) noheader
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: spanheader() refuses overlap, range, syntax, noheader"
    local ++pass_count
}
else {
    display as error "  FAIL: spanheader() refusals (rc=`=_rc')"
    local ++fail_count
}

**# footnote(): one row per paragraph; a single paragraph is unchanged
local ++test_count
capture noisily {
    local book "`output_dir'/pt230_fn.xlsx"
    local csv "`output_dir'/pt230_fn.csv"
    local md "`output_dir'/pt230_fn.md"
    capture erase "`book'"
    _pt230_data
    puttab lab a b c using "`book'", sheet("F") varlabels ///
        footnote("First paragraph. \ Second one. \ ") csv("`csv'") markdown("`md'")
    * header 2, data 3-5, footnotes 6-7 (the empty third paragraph is dropped)
    assert r(n_rows) == 6
    _v_facts "`book'" "F"
    _v_value B6 "First paragraph."
    _v_value B7 "Second one."
    _v_empty B8
    _v_has merge "" "B6:E6 B7:E7"
    _v_line "`csv'" "First paragraph.,,," 1
    _v_line "`csv'" "Second one.,,," 1
    _v_line "`md'" "*First paragraph.*" 1
    _v_line "`md'" "*Second one.*" 1
    * italic both rows (openpyxl, independent of xl())
    capture erase "`output_dir'/pt230_it.txt"
    shell python3 -c "import openpyxl,sys; ws=openpyxl.load_workbook(sys.argv[1])['F']; ok=ws['B6'].font.i and ws['B7'].font.i; open(sys.argv[2],'w').write('OK') if ok else None" "`book'" "`output_dir'/pt230_it.txt"
    confirm file "`output_dir'/pt230_it.txt"
    erase "`output_dir'/pt230_it.txt"

    * backslash without spaces is text; one paragraph is written as typed
    puttab lab a b c using "`book'", sheet("F1") varlabels ///
        footnote("a\b keeps its backslash") csv("`csv'") markdown("`md'")
    assert r(n_rows) == 5
    * no title: blank row 1, header 2, data 3-5, footnote 6
    _v_facts "`book'" "F1"
    _v_value B6 "a\b keeps its backslash"
    _v_line "`csv'" "a\b keeps its backslash,,," 1
}
if _rc == 0 {
    display as result "  PASS: footnote() paragraphs in xlsx/csv/md; single paragraph unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: footnote() paragraphs (rc=`=_rc')"
    local ++fail_count
}

**# D2: the embedded header row of a table1_tc table is consumed by varlabels
local ++test_count
capture noisily {
    local book "`output_dir'/pt230_d2.xlsx"
    local csv "`output_dir'/pt230_d2.csv"
    capture erase "`book'"
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat \ mpg contn) frame(pt230_t1, replace)
    frame pt230_t1 {
        local nobs = _N
        * observation 1 repeats the variable labels (the embedded header)
        assert strtrim(foreign_0[1]) == "Domestic"
        local lab0 : variable label foreign_0
        assert "`lab0'" == "Domestic"
    }
    puttab using "`book'", frame(pt230_t1) varlabels sheet("T1") csv("`csv'")
    * every observation but the embedded header is a data row
    assert r(n_datarows) == `nobs' - 1
    _v_facts "`book'" "T1"
    _v_value C2 "Domestic"
    _v_value D2 "Foreign"
    * header text appears once: row 3 is the descriptor/N row, not a repeat
    _v_value D3 "N=22"
    _v_grep "`csv'" ",Domestic,Foreign,p-value$"
    assert r(n) == 1
    _v_grep "`csv'" "^Factor *,Domestic,Foreign,p-value$"
    assert r(n) == 1

    * the same table through clear: identical rows
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat \ mpg contn) clear
    puttab _all using "`book'", varlabels sheet("T1b")
    assert r(n_datarows) == `nobs' - 1
}
if _rc == 0 {
    display as result "  PASS: puttab varlabels consumes table1_tc's embedded header (no drop in 1)"
    local ++pass_count
}
else {
    display as error "  FAIL: D2 embedded header (rc=`=_rc')"
    local ++fail_count
}

capture frame drop pt230_t1
capture erase "$V230_RES"
macro drop V230_TOOL V230_RES PT230_FIX
display "RESULT: test_puttab_v230 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _pt230
if `fail_count' > 0 exit 1
