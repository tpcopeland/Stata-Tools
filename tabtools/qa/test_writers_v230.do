* test_writers_v230.do - multi-paragraph footnote() in the shared writers (O4)
*
* The literal token " \ " separates paragraphs. The shared writers emit one
* row per paragraph in Excel (the footnote row's styling copied to each),
* one row per paragraph in CSV, and one italic paragraph each in Markdown.
* A footnote without the token is written exactly as before. Checked for
* commands whose Excel footnote goes through _tabtools_xlsx_apply_styles
* (desctab, crosstab, corrtab, regtab, survtab); puttab and stacktab are
* covered in their own v230 suites. Read back with openpyxl.

clear all
set more off
set varabbrev off
version 17.0

capture log close _wr230
log using "test_writers_v230.log", replace text name(_wr230)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global V230_TOOL "`qa_dir'/tools/xlsx_facts.py"
global V230_RES "`output_dir'/wr230_facts.txt"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear
run "`qa_dir'/_qa_v230_helpers.do"

* Paragraphs t1, t2 sit in column B of consecutive rows, both italic, each
* merged from B, and nothing follows them; r(row) is t1's row.
capture program drop _wr_pair
program define _wr_pair, rclass
    version 17.0
    args book sheet t1 t2
    _v_facts "`book'" "`sheet'"
    mata: _f = cat("$V230_RES"); _t = " " + st_local("t1"); ///
        _k = selectindex((substr(_f, 1, 7) :== "value B") :& ///
        (substr(_f, -strlen(_t), .) :== _t)); ///
        st_local("r", rows(_k) == 1 ? substr(_f[_k], 8, strpos(substr(_f[_k], 8, .), " ") - 1) : "")
    if "`r'" == "" {
        display as error "paragraph not found once in column B: `t1'"
        exit 9
    }
    local r2 = `r' + 1
    _v_value B`r2' "`t2'"
    _v_empty B`=`r2' + 1'
    local ok "$V230_RES.it"
    capture erase "`ok'"
    shell python3 -c "import openpyxl,sys; ws=openpyxl.load_workbook(sys.argv[1])[sys.argv[2]]; r=int(sys.argv[3]); m=[str(x) for x in ws.merged_cells.ranges]; ok=ws.cell(r,2).font.i and ws.cell(r+1,2).font.i and any(x.startswith('B%d:'%r) for x in m) and any(x.startswith('B%d:'%(r+1)) for x in m); open(sys.argv[4],'w').write('OK') if ok else None" "`book'" "`sheet'" "`r'" "`ok'"
    confirm file "`ok'"
    erase "`ok'"
    return scalar row = `r'
end

**# desctab / table1_tc
local ++test_count
capture noisily {
    local book "`output_dir'/wr230.xlsx"
    local csv "`output_dir'/wr230_d.csv"
    local md "`output_dir'/wr230_d.md"
    capture erase "`book'"
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat) excel("`book'") sheet("D") ///
        footnote("D one. \ D two.") csv("`csv'") markdown("`md'")
    _wr_pair "`book'" "D" "D one." "D two."
    _v_line "`csv'" "D one.,,," 1
    _v_line "`csv'" "D two.,,," 1
    _v_line "`md'" "*D one.*" 1
    _v_line "`md'" "*D two.*" 1
    * one paragraph: one row, as typed
    table1_tc, by(foreign) vars(rep78 cat) excel("`book'") sheet("D1") ///
        footnote("Only one, with a\backslash.") csv("`csv'") markdown("`md'")
    _v_facts "`book'" "D1"
    _v_grep "$V230_RES" "^value B[0-9]+ Only one, with a\\backslash\.$"
    assert r(n) == 1
    _v_line "`md'" "*Only one, with a\\backslash.*" 1
}
if _rc == 0 {
    display as result "  PASS: table1_tc footnote paragraphs in xlsx/csv/md"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc footnote paragraphs (rc=`=_rc')"
    local ++fail_count
}

**# crosstab and corrtab
local ++test_count
* stata-dev-ignore: rc-only-test — the content oracle is the _wr_pair/_v_line call(s) in this block: each compares the produced cell/line/fact with the expected text and exits 9 on mismatch (helpers in this file and _qa_v230_helpers.do); the rule cannot see a helper whose name has no "assert" substring
capture noisily {
    local book "`output_dir'/wr230.xlsx"
    local md "`output_dir'/wr230_c.md"
    sysuse auto, clear
    crosstab rep78 foreign, xlsx("`book'") sheet("C") footnote("C one. \ C two.") ///
        markdown("`md'")
    _wr_pair "`book'" "C" "C one." "C two."
    _v_line "`md'" "*C one.*" 1
    corrtab mpg price weight, xlsx("`book'") sheet("R") footnote("R one. \ R two.")
    _wr_pair "`book'" "R" "R one." "R two."
}
if _rc == 0 {
    display as result "  PASS: crosstab/corrtab footnote paragraphs"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab/corrtab footnote paragraphs (rc=`=_rc')"
    local ++fail_count
}

**# regtab and survtab use the same shared Excel path
local ++test_count
capture noisily {
    local book "`output_dir'/wr230.xlsx"
    local csv "`output_dir'/wr230_g.csv"
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`book'") sheet("G") coef("Coef.") footnote("G one. \ G two.") ///
        csv("`csv'")
    _wr_pair "`book'" "G" "G one." "G two."
    _v_grep "`csv'" "^G one\.,"
    assert r(n) == 1
    _v_grep "`csv'" "^G two\.,"
    assert r(n) == 1
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    survtab, times(10 20) by(drug) xlsx("`book'") sheet("S") ///
        footnote("S one. \ S two.")
    _wr_pair "`book'" "S" "S one." "S two."
}
if _rc == 0 {
    display as result "  PASS: regtab/survtab footnote paragraphs through the shared writer"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab/survtab footnote paragraphs (rc=`=_rc')"
    local ++fail_count
}

capture erase "$V230_RES"
macro drop V230_TOOL V230_RES
display "RESULT: test_writers_v230 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _wr230
if `fail_count' > 0 exit 1
