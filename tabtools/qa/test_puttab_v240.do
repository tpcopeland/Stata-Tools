* test_puttab_v240.do - puttab panelinline: the panel heading and the panel's
* column headers share one row
*
* Expected cells, borders, merges, bold and fills are written out from the
* option contract and read back with openpyxl (tools/xlsx_facts.py and an
* inline openpyxl probe for fills); CSV and Markdown are read line by line.
* Nothing is checked through the xl() writer.

clear all
set more off
set varabbrev off
version 17.0

capture log close _pt240
log using "test_puttab_v240.log", replace text name(_pt240)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global V230_TOOL "`qa_dir'/tools/xlsx_facts.py"
global V230_RES "`output_dir'/pt240_facts.txt"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear
run "`qa_dir'/_qa_v230_helpers.do"

* Fixture (as in test_puttab_v230.do): two panels with per-panel headers.
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
tempfile pt240_fixture
quietly save "`pt240_fixture'"
global PT240_FIX "`pt240_fixture'"
capture program drop _pt240_data
program define _pt240_data
    quietly use "$PT240_FIX", clear
end

**# I1: panelinline, xlsx/csv/md: one row per panel start, styled as both
local ++test_count
capture noisily {
    local book "`output_dir'/pt240_inline.xlsx"
    local csv "`output_dir'/pt240_inline.csv"
    local md "`output_dir'/pt240_inline.md"
    capture erase "`book'"
    _pt240_data
    puttab lab a b c using "`book'", sheet("I") panel(blk) ///
        panelheader(h1 h2 h3 h4) panelinline noheader ///
        csv("`csv'") markdown("`md'")
    assert r(n_panels) == 2
    * shared row A 2, rows 3-4, shared row B 5, row 6 (without panelinline 7)
    assert r(n_datarows) == 5
    assert r(n_cols) == 4
    _v_facts "`book'" "I"
    _v_value B2 "A. Relapses"
    _v_value C2 "Events"
    _v_value D2 "PY"
    _v_value E2 "Rate"
    _v_value B3 "   Age <55"
    _v_value C3 "1"
    _v_value B4 "   Age 55+"
    _v_value B5 "B. MRI"
    _v_value C5 "Scans"
    _v_value D5 "Pct"
    _v_value E5 "RR"
    _v_value B6 "   Repleted"
    _v_value E6 "9"
    _v_none value "B7 C7"
    * the shared row holds text in every cell: never merged (the only
    * merge is the reserved title row)
    _v_count merge
    assert r(n) == 1
    _v_has merge "" "A1:E1"
    _v_has bold "" "B2 C2 D2 E2 B5 C5 D5 E5"
    _v_none bold "B3 C3 B4 B6 E6"
    * rule above (the heading's) and below (the header's)
    _v_has top thin "B2 C2 D2 E2 B5 C5 D5 E5"
    _v_has bottom thin "B2 C2 D2 E2 B5 C5 D5 E5"
    _v_none top "B3 B4 B6"
    * text sinks: the same single row
    _v_line "`csv'" "A. Relapses,Events,PY,Rate" 1
    _v_line "`csv'" "   Age <55,1,2,3" 1
    _v_line "`csv'" "B. MRI,Scans,Pct,RR" 1
    _v_line "`csv'" "   Repleted,7,8,9" 1
    _v_line "`csv'" ",Events,PY,Rate" 0
    _v_line "`csv'" "A. Relapses,,," 0
    * noheader: GFM needs a header row, so the first shared row takes the
    * header slot (no blank "|  |  |" header above it); later ones stay bold
    _v_line "`md'" "| A. Relapses | Events | PY | Rate |" 1
    _v_line "`md'" "| **A. Relapses** | **Events** | **PY** | **Rate** |" 0
    _v_line "`md'" "|  |  |  |  |" 0
    _v_line "`md'" "| **B. MRI** | **Scans** | **Pct** | **RR** |" 1
    _v_line "`md'" "| &nbsp;&nbsp;&nbsp;Repleted | 7 | 8 | 9 |" 1
    _v_line "`md'" "| **A. Relapses** |  |  |  |" 0
}
if _rc == 0 {
    display as result "  PASS: I1 panelinline shares one row in xlsx/csv/md"
    local ++pass_count
}
else {
    display as error "  FAIL: I1 panelinline (rc=`=_rc')"
    local ++fail_count
}

**# I2: the same table without panelinline is unchanged (two rows per panel)
local ++test_count
capture noisily {
    local csv "`output_dir'/pt240_two.csv"
    _pt240_data
    puttab lab a b c, panel(blk) panelheader(h1 h2 h3 h4) noheader csv("`csv'") markdown("`output_dir'/pt240_side.md")
    assert r(n_datarows) == 7 & r(n_panels) == 2
    _v_line "`csv'" "A. Relapses,,," 1
    _v_line "`csv'" ",Events,PY,Rate" 1
    * and the inline layout is the two-row layout with each pair joined
    local csv2 "`output_dir'/pt240_two_inline.csv"
    puttab lab a b c, panel(blk) panelheader(h1 h2 h3 h4) noheader csv("`csv2'") panelinline markdown("`output_dir'/pt240_side.md")
    * body rows identical; heading + header pairs (two-row lines 1-2, 5-6)
    * become one line whose first cell is the heading and rest the header
    mata: _two = cat("`csv'"); _one = cat("`csv2'")
    mata: st_local("_eq", strofreal(rows(_two) == 7 & rows(_one) == 5 & ///
        _two[3..4] == _one[2..3] & _two[7] == _one[5] & ///
        _one[1] == subinstr(_two[1], ",,,", "", 1) + _two[2] & ///
        _one[4] == subinstr(_two[5], ",,,", "", 1) + _two[6]))
    mata: mata drop _two _one
    assert `_eq' == 1
}
if _rc == 0 {
    display as result "  PASS: I2 default layout unchanged; inline = joined pairs"
    local ++pass_count
}
else {
    display as error "  FAIL: I2 default layout (rc=`=_rc')"
    local ++fail_count
}

**# I3: literal panelheader(), a column header row, title, headershade fill
local ++test_count
capture noisily {
    local book "`output_dir'/pt240_lit.xlsx"
    capture erase "`book'"
    _pt240_data
    puttab lab a b c using "`book'", sheet("L") panel(blk) varlabels ///
        panelheader("" "n" `"say "x""' "%") panelinline headershade title("T")
    assert r(n_panels) == 2 & r(n_datarows) == 5
    * title 1, column header 2, shared A 3, rows 4-5, shared B 6, row 7
    _v_facts "`book'" "L"
    _v_value B2 "Row"
    _v_value B3 "A. Relapses"
    _v_value C3 "n"
    _v_value D3 `"say "x""'
    _v_value E3 "%"
    _v_value B6 "B. MRI"
    _v_value D6 `"say "x""'
    _v_value B7 "   Repleted"
    _v_has bold "" "B3 C3 D3 E3 B6 C6 D6 E6"
    _v_has bottom thin "B3 E3 B6 E6"
    _v_count merge
    * only the title is merged
    assert r(n) == 1
    _v_has merge "" "A1:E1"
    * headershade fills the header and both shared rows, not the body
    local fills "`output_dir'/pt240_fill.txt"
    capture erase "`fills'"
    shell python3 -c "import openpyxl,sys; ws=openpyxl.load_workbook(sys.argv[1])['L']; f=lambda c: (ws[c].fill.fill_type or 'none'); open(sys.argv[2],'w').write(' '.join(c+'='+f(c) for c in ['C2','C3','E3','C6','C4','C7']))" "`book'" "`fills'"
    confirm file "`fills'"
    mata: st_local("_f", cat("`fills'")[1])
    display as text "  fills: `_f'"
    assert strpos("`_f'", "C2=solid") & strpos("`_f'", "C3=solid") & ///
        strpos("`_f'", "E3=solid") & strpos("`_f'", "C6=solid")
    assert strpos("`_f'", "C4=none") & strpos("`_f'", "C7=none")
}
if _rc == 0 {
    display as result "  PASS: I3 literal header, varlabels header row, title, headershade"
    local ++pass_count
}
else {
    display as error "  FAIL: I3 literal/headershade (rc=`=_rc')"
    local ++fail_count
}

**# I4: mixed panels: blank header keeps a heading row; no heading keeps a header row
local ++test_count
capture noisily {
    local book "`output_dir'/pt240_mix.xlsx"
    local csv "`output_dir'/pt240_mix.csv"
    capture erase "`book'"
    clear
    input str8 lab str4 v byte g str6(p1 p2)
    "r1" "1" . "" "N0"
    "r2" "2" 1 "" ""
    "r3" "3" 1 "" ""
    "r4" "4" 2 "" "N2"
    end
    label define g 1 "G1" 2 "G2"
    label values g g
    puttab lab v using "`book'", sheet("M") panel(g) panelheader(p1 p2) ///
        panelinline noheader csv("`csv'") markdown("`output_dir'/pt240_side.md")
    * panel "." (no heading): its own header row; G1 (blank header): its
    * own heading row; G2: shared
    assert r(n_panels) == 2
    _v_line "`csv'" ",N0" 1
    _v_line "`csv'" "r1,1" 1
    _v_line "`csv'" "G1," 1
    _v_line "`csv'" "   r2,2" 1
    _v_line "`csv'" "G2,N2" 1
    _v_line "`csv'" "   r4,4" 1
    mata: st_local("_nl", strofreal(rows(cat("`csv'"))))
    assert `_nl' == 7
    _v_facts "`book'" "M"
    * the G1 heading row is a heading (not merged since 2.5.6), G2 is shared
    _v_value B4 "G1"
    _v_none merge "B4:C4"
    _v_value B7 "G2"
    _v_value C7 "N2"
    _v_none merge "B7:C7"
    _v_has bold "" "B7 C7"
}
if _rc == 0 {
    display as result "  PASS: I4 blank-header and no-heading panels keep their own rows"
    local ++pass_count
}
else {
    display as error "  FAIL: I4 mixed panels (rc=`=_rc')"
    local ++fail_count
}

**# I5: refusals; nothing is written on a refusal
local ++test_count
capture noisily {
    local book "`output_dir'/pt240_ref.xlsx"
    local csv "`output_dir'/pt240_ref.csv"
    capture erase "`book'"
    capture erase "`csv'"
    _pt240_data
    * panelinline needs panelheader()
    capture puttab lab a b c using "`book'", panel(blk) panelinline csv("`csv'")
    assert _rc == 198
    capture puttab lab a b c using "`book'", panelinline csv("`csv'")
    assert _rc == 198
    * text in the first header cell would be overwritten: refused
    replace h1 = "Group" if blk == 2
    capture noisily puttab lab a b c using "`book'", panel(blk) ///
        panelheader(h1 h2 h3 h4) panelinline csv("`csv'")
    assert _rc == 198
    capture puttab lab a b c using "`book'", panel(blk) ///
        panelheader("Group" "n" "m" "o") panelinline csv("`csv'")
    assert _rc == 198
    capture confirm file "`book'"
    assert _rc == 601
    capture confirm file "`csv'"
    assert _rc == 601
    * without panelinline the same header is fine (written below the heading)
    puttab lab a b c, panel(blk) panelheader(h1 h2 h3 h4) csv("`csv'") markdown("`output_dir'/pt240_side.md")
    _v_line "`csv'" "Group,Scans,Pct,RR" 1
    * the abbreviation documented in the help file
    puttab lab a b c, panel(blk) panelheader("" "n" "m" "o") paneli csv("`csv'") markdown("`output_dir'/pt240_side.md")
    _v_line "`csv'" "B. MRI,n,m,o" 1
}
if _rc == 0 {
    display as result "  PASS: I5 panelinline refusals leave no files"
    local ++pass_count
}
else {
    display as error "  FAIL: I5 refusals (rc=`=_rc')"
    local ++fail_count
}

**# I6: noindent and session hygiene
local ++test_count
capture noisily {
    local csv "`output_dir'/pt240_noind.csv"
    _pt240_data
    set varabbrev on
    puttab lab a b c, panel(blk) panelheader(h1 h2 h3 h4) panelinline noindent csv("`csv'") markdown("`output_dir'/pt240_side.md")
    assert c(varabbrev) == "on"
    _v_line "`csv'" "Age <55,1,2,3" 1
    _v_line "`csv'" "A. Relapses,Events,PY,Rate" 1
    capture puttab lab a b c, panel(blk) panelinline
    assert c(varabbrev) == "on"
    set varabbrev off
    * the caller's data are untouched
    assert _N == 3 & lab[1] == "Age <55"
    confirm variable h1 blk
}
if _rc == 0 {
    display as result "  PASS: I6 noindent, varabbrev, data preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: I6 noindent/hygiene (rc=`=_rc')"
    local ++fail_count
}
set varabbrev off

display "RESULT: test_puttab_v240 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _pt240
if `fail_count' > 0 exit 1
