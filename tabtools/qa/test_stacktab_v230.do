* test_stacktab_v230.do - stacktab, frames(): in-memory frames stacked as
* labelled panels through puttab's panel() rendering (I3), and multi-
* paragraph notes on the workbook-block route (O4)
*
* Expected rows are built from the frames' own contents; the workbook is read
* back with openpyxl (tools/xlsx_facts.py).

clear all
set more off
set varabbrev off
version 17.0

capture log close _st230
log using "test_stacktab_v230.log", replace text name(_st230)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global V230_TOOL "`qa_dir'/tools/xlsx_facts.py"
global V230_RES "`output_dir'/st230_facts.txt"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear
run "`qa_dir'/_qa_v230_helpers.do"

**# two table1_tc frames: panels, embedded headers dropped, all sinks
local ++test_count
capture noisily {
    local book "`output_dir'/st230_frames.xlsx"
    local csv "`output_dir'/st230_frames.csv"
    local md "`output_dir'/st230_frames.md"
    capture erase "`book'"
    sysuse auto, clear
    table1_tc, by(foreign) vars(mpg contn \ rep78 cat) frame(st230_a, replace)
    table1_tc if price > 5000, by(foreign) vars(mpg contn \ rep78 cat) ///
        frame(st230_b, replace)
    frame st230_a: local na = _N - 1
    frame st230_b: local nb = _N - 1
    * oracle rows, taken from the frames themselves (row 1 is the embedded header)
    frame st230_a: local a_last = strtrim(foreign_1[_N])
    frame st230_b: local b_n = strtrim(foreign_0[2])
    stacktab using "`book'", frames(st230_a "All cars" \ st230_b "Expensive cars") ///
        sheet("T1") title("Stacked") footnote("One. \ Two.") csv("`csv'") markdown("`md'")
    assert r(n_frames) == 2
    assert r(n_panels) == 2
    assert r(n_datarows) == `na' + `nb' + 2
    assert r(n_cols) == 4
    * title 1, header 2, heading 3, frame A rows 4..(3+na), heading, frame B rows
    local hb = 4 + `na'
    _v_facts "`book'" "T1"
    _v_value C2 "Domestic"
    _v_value B3 "All cars"
    _v_value B`hb' "Expensive cars"
    * 2.5.6: panel headings are not merged
    _v_none merge "B3:E3 B`hb':E`hb'"
    _v_has bold "" "B3 B`hb'"
    _v_has top thin "B3 B`hb'"
    _v_value D`=3 + `na'' "`a_last'"
    _v_value C`=`hb' + 1' "`b_n'"
    * the embedded header rows are gone: "Domestic" appears once
    _v_grep "$V230_RES" "^value [A-Z]+[0-9]+ Domestic$"
    assert r(n) == 1
    _v_value B`=`hb' + `nb' + 1' "One."
    _v_value B`=`hb' + `nb' + 2' "Two."
    _v_line "`md'" "| **All cars** |  |  |  |" 1
    _v_line "`md'" "| **Expensive cars** |  |  |  |" 1
    _v_line "`md'" "*One.*" 1
    _v_line "`md'" "*Two.*" 1
    _v_line "`csv'" "All cars,,," 1
    _v_line "`csv'" "Expensive cars,,," 1
    * the frames in memory are unchanged
    frame st230_a: assert _N == `na' + 1
}
if _rc == 0 {
    display as result "  PASS: stacktab frames() stacks labelled panels in xlsx/csv/md"
    local ++pass_count
}
else {
    display as error "  FAIL: stacktab frames() (rc=`=_rc')"
    local ++fail_count
}

**# numeric columns, an unlabelled panel, and the session workbook
local ++test_count
capture noisily {
    local book "`output_dir'/st230_num.xlsx"
    capture erase "`book'"
    frame create st230_n1
    frame st230_n1 {
        set obs 2
        gen str6 lab = "r" + string(_n)
        gen double v = _n * 1.5
        format v %4.2f
        gen byte yn = _n - 1
        label define st230_yn 0 "No" 1 "Yes"
        label values yn st230_yn
        label variable lab "Label"
        label variable v "Value"
        label variable yn "Flag"
    }
    frame create st230_n2
    frame st230_n2 {
        set obs 1
        gen str6 lab = "z"
        gen double v = 10
        gen byte yn = 1
    }
    tabtools set workbook "`book'"
    stacktab, frames(st230_n1 \ st230_n2 "Second") sheet("N")
    assert r(n_panels) == 1
    tabtools set clear
    _v_facts "`book'" "N"
    _v_value B2 "Label"
    _v_value C2 "Value"
    * first frame has no label: no heading, no indent
    _v_value B3 "r1"
    _v_value C3 "1.50"
    _v_value D3 "No"
    _v_value D4 "Yes"
    _v_value B5 "Second"
    _v_value B6 "   z"
    _v_value C6 "10"
}
local _rc_save = _rc
tabtools set clear
if `_rc_save' == 0 {
    display as result "  PASS: frames() formats numeric columns; unlabelled panel; session workbook"
    local ++pass_count
}
else {
    display as error "  FAIL: frames() numeric/unlabelled (rc=`_rc_save')"
    local ++fail_count
}

**# frames() refusals
local ++test_count
capture noisily {
    local book "`output_dir'/st230_ref.xlsx"
    sysuse auto, clear
    table1_tc, by(foreign) vars(mpg contn) frame(st230_r, replace)
    frame create st230_wide
    frame st230_wide: sysuse auto
    capture stacktab using "`book'", frames(st230_r "x" \ nosuch "y") sheet("S")
    assert _rc == 111
    capture stacktab using "`book'", frames(st230_r "x" \ ) sheet("S")
    assert _rc == 198
    capture stacktab using "`book'", frames(st230_r "x" \ st230_wide "y") sheet("S")
    assert _rc == 198
    capture stacktab using "`book'", frames(st230_r "x" \ st230_r "y") sheet("S")
    assert _rc == 198
    capture stacktab using "`book'", frames(st230_r "x" st230_r) sheet("S")
    assert _rc == 198
    capture stacktab using "`book'", frames(st230_r) sheet("S") layout(hstack)
    assert _rc == 198
    capture stacktab using "`book'", frames(st230_r) sheet("S") sheetreplace
    assert _rc == 198
    capture stacktab using "`book'", frames(st230_r) blocks(sheet(A)) sheet("S")
    assert _rc == 198
    capture stacktab using "`book'", frames(st230_r)
    assert _rc == 198
    * no using and no session workbook: puttab's target rule
    tabtools set clear
    capture stacktab, frames(st230_r) sheet("S")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: frames() refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: frames() refusals (rc=`=_rc')"
    local ++fail_count
}

**# workbook-block route: note() paragraphs become rows; single note unchanged
local ++test_count
* stata-dev-ignore: rc-only-test — the content oracle is the _v_value/_v_empty/_v_line call(s) in this block: each compares the produced cell/line/fact with the expected text and exits 9 on mismatch (helpers in _qa_v230_helpers.do); the rule cannot see a helper whose name has no "assert" substring
capture noisily {
    local src "`output_dir'/st230_src.xlsx"
    local csv "`output_dir'/st230_blk.csv"
    capture erase "`src'"
    sysuse auto, clear
    puttab make mpg in 1/3 using "`src'", sheet("A") title("A")
    stacktab using "`src'", blocks(sheet(A) rows(2/5)) sheet("Out") ///
        note("Para one. \ Para two.") csv("`csv'")
    local nr = r(note_row)
    _v_facts "`src'" "Out"
    _v_value B`nr' "Para one."
    _v_value B`=`nr' + 1' "Para two."
    _v_line "`csv'" "Para one.,," 1
    _v_line "`csv'" "Para two.,," 1
    stacktab using "`src'", blocks(sheet(A) rows(2/5)) sheet("Out1") ///
        note("Just one\note") sheetreplace
    local nr = r(note_row)
    _v_facts "`src'" "Out1"
    _v_value B`nr' "Just one\note"
    _v_empty B`=`nr' + 1'
}
if _rc == 0 {
    display as result "  PASS: stacktab note() paragraphs on the blocks route"
    local ++pass_count
}
else {
    display as error "  FAIL: stacktab note() paragraphs (rc=`=_rc')"
    local ++fail_count
}

foreach f in st230_a st230_b st230_n1 st230_n2 st230_r st230_wide {
    capture frame drop `f'
}
capture erase "$V230_RES"
macro drop V230_TOOL V230_RES
display "RESULT: test_stacktab_v230 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _st230
if `fail_count' > 0 exit 1
