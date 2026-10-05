* test_stratetab_v231.do - stratetab (and ratetab through it), tabtools 2.3.1
* Contracts:
*   - the console header prints "Exposure" once (row 3 repeated it); the
*     frame and the workbook keep their layout
*   - sheet() without xlsx() writes the session workbook (tabtools set
*     workbook); the first write starts the workbook over, later writes add
*     sheets; with no session workbook the log says
*     "(tabtools: sheet() ignored; no xlsx() and no session workbook)"
*   - zerocells(dash|blank) and masktext()
* Oracles: the logged console text, read back line by line with Mata cat();
* workbook sheet names from import excel, describe and cell text from
* openpyxl (tools/xlsx_facts.py); hand-built strate-format files whose cell
* text is written out by hand.

clear all
set more off
set varabbrev off
version 17.0

capture log close _st231
log using "test_stratetab_v231.log", replace text name(_st231)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global V230_TOOL "`qa_dir'/tools/xlsx_facts.py"
global V230_RES "`output_dir'/st231_facts.txt"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear
run "`qa_dir'/_qa_v230_helpers.do"

local pass_count = 0
local fail_count = 0

* A strate-format file: levels 1..3 with events d1 d2 d3 over 100, 200, 400
* person-years, exact 95% limits, labelled as strate labels them.
capture program drop _st231_file
program define _st231_file
    version 17.0
    args file d1 d2 d3
    clear
    quietly set obs 3
    gen byte arm = _n
    label define _st231_arm 1 "Low" 2 "Mid" 3 "High", replace
    label values arm _st231_arm
    gen double _D = cond(_n == 1, `d1', cond(_n == 2, `d2', `d3'))
    gen double _Y = 100 * 2^(_n - 1)
    gen double _Rate = _D / _Y
    gen double _Lower = cond(_D > 0, invpoissontail(_D, 0.025) / _Y, .)
    gen double _Upper = cond(_D > 0, invpoisson(_D, 0.025) / _Y, .)
    label variable _Lower "Lower 95% bound"
    label variable _Upper "Upper 95% bound"
    quietly save "`file'", replace
end

* Sheet names of a workbook, in order, into r(sheets).
capture program drop _st231_sheets
program define _st231_sheets, rclass
    args book
    quietly import excel using "`book'", describe
    local s ""
    forvalues i = 1/`r(N_worksheet)' {
        local s `"`s' `r(worksheet_`i')'"'
    }
    return local sheets = strtrim(`"`s'"')
end

local f1 "`output_dir'/st231_a"
local f2 "`output_dir'/st231_b"
_st231_file "`f1'" 19 12 30
_st231_file "`f2'" 0 3 8

**# S1: the console header prints "Exposure" once; frame and workbook keep it
capture noisily {
    local lg "`output_dir'/st231_s1.log"
    local book "`output_dir'/st231_s1.xlsx"
    capture erase "`book'"
    local ls0 = c(linesize)
    set linesize 255
    capture log close _st231c
    log using "`lg'", replace text name(_st231c)
    stratetab, using("`f1'") outcomes(1) outlabels("Death") explabels("Arm") ///
        frame(_s1, replace) xlsx("`book'") sheet("T")
    log close _st231c
    set linesize `ls0'
    * the boxed console table: one header line names the label column
    _v_grep "`lg'" "^ *\| +Exposure +Death +\|$"
    assert r(n) == 1
    _v_grep "`lg'" "^ *\| +Events +Person-Years \(PY\) +Per 1,000 PY \(95% CI\) +\|$"
    assert r(n) == 1
    _v_grep "`lg'" "Exposure"
    assert r(n) == 1
    * frame layout unchanged (comptab, rateframe() reads it): rows 2 and 3
    frame _s1: assert c1[2] == "Exposure" & c1[3] == "Exposure"
    frame _s1: assert c2[2] == "Death" & c2[3] == "Events"
    frame drop _s1
    * workbook: B2 (merged over B3) still says Exposure
    _v_facts "`book'" "T"
    _v_value B2 "Exposure"
    _v_value C3 "Events"
}
if _rc == 0 {
    display as result "  PASS: S1 stratetab console shows Exposure once; frame/workbook unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: S1 stratetab Exposure printed twice (rc=`=_rc')"
    local ++fail_count
}
capture log close _st231c
set linesize 80

**# S2: ratetab (rendered by stratetab) prints "Exposure" once
capture noisily {
    clear
    quietly set obs 6
    gen byte g = 1 + (_n > 3)
    gen long ev = _n
    gen double pt = 10 * _n
    local lg "`output_dir'/st231_s2.log"
    set linesize 255
    capture log close _st231c
    log using "`lg'", replace text name(_st231c)
    ratetab g, events(ev) exposure(pt) outlabels("Death") explabels("Group")
    log close _st231c
    set linesize 80
    _v_grep "`lg'" "Exposure"
    assert r(n) == 1
    _v_grep "`lg'" "^ *\| +Exposure +Death +\|$"
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: S2 ratetab console shows Exposure once"
    local ++pass_count
}
else {
    display as error "  FAIL: S2 ratetab Exposure printed twice (rc=`=_rc')"
    local ++fail_count
}
capture log close _st231c
set linesize 80

**# S3: sheet() alone writes the session workbook; first write starts it over
capture noisily {
    local book "`output_dir'/st231_sess.xlsx"
    capture erase "`book'"
    * a workbook left over from an earlier run, with a stale sheet
    clear
    quietly set obs 1
    gen x = 1
    quietly export excel using "`book'", sheet("Stale") replace
    _st231_sheets "`book'"
    assert `"`r(sheets)'"' == "Stale"

    tabtools set workbook "`book'"
    stratetab, using("`f1'") outcomes(1) sheet("One")
    assert `"`r(xlsx)'"' == "`book'"
    assert `"`r(sheet)'"' == "One"
    _st231_sheets "`book'"
    assert `"`r(sheets)'"' == "One"
    stratetab, using("`f2'") outcomes(1) sheet("Two")
    _st231_sheets "`book'"
    assert `"`r(sheets)'"' == "One Two"
    * content of the session sheet: the first level of file 1
    _v_facts "`book'" "One"
    _v_value B5 "   Low"
    _v_value C5 "19"
    _v_value D5 "100"
    local r1 = strtrim(string(round(190, 0.1), "%24.1f")) + " (" + ///
        strtrim(string(round(1000 * invpoissontail(19, 0.025) / 100, 0.1), "%24.1f")) + ", " + ///
        strtrim(string(round(1000 * invpoisson(19, 0.025) / 100, 0.1), "%24.1f")) + ")"
    _v_value E5 "`r1'"
    * an explicit xlsx() wins over the session workbook
    local other "`output_dir'/st231_other.xlsx"
    capture erase "`other'"
    stratetab, using("`f1'") outcomes(1) xlsx("`other'") sheet("Mine")
    assert `"`r(xlsx)'"' == "`other'"
    _st231_sheets "`book'"
    assert `"`r(sheets)'"' == "One Two"
    _st231_sheets "`other'"
    assert `"`r(sheets)'"' == "Mine"
    * no sheet(): the session workbook is not touched (as corrtab)
    stratetab, using("`f1'") outcomes(1)
    assert `"`r(xlsx)'"' == ""
    _st231_sheets "`book'"
    assert `"`r(sheets)'"' == "One Two"
}
if _rc == 0 {
    display as result "  PASS: S3 stratetab sheet() writes the session workbook (first write replaces)"
    local ++pass_count
}
else {
    display as error "  FAIL: S3 stratetab session workbook (rc=`=_rc')"
    local ++fail_count
}
quietly tabtools set clear

**# S4: ratetab with sheet() alone writes the session workbook too
capture noisily {
    local book "`output_dir'/st231_sess_rt.xlsx"
    capture erase "`book'"
    tabtools set workbook "`book'"
    clear
    quietly set obs 6
    gen byte g = 1 + (_n > 3)
    gen long ev = _n
    gen double pt = 10 * _n
    ratetab g, events(ev) exposure(pt) sheet("Rates")
    assert `"`r(xlsx)'"' == "`book'"
    _st231_sheets "`book'"
    assert `"`r(sheets)'"' == "Rates"
    _v_facts "`book'" "Rates"
    _v_value C5 "6"
    _v_value D5 "60"
}
if _rc == 0 {
    display as result "  PASS: S4 ratetab sheet() writes the session workbook"
    local ++pass_count
}
else {
    display as error "  FAIL: S4 ratetab session workbook (rc=`=_rc')"
    local ++fail_count
}
quietly tabtools set clear

**# S5: sheet() with no xlsx() and no session workbook says so, writes nothing
capture noisily {
    local lg "`output_dir'/st231_s5.log"
    local cwdfile "`c(pwd)'/Ignored.xlsx"
    capture erase "`cwdfile'"
    set linesize 255
    capture log close _st231c
    log using "`lg'", replace text name(_st231c)
    stratetab, using("`f1'") outcomes(1) sheet("Ignored")
    local rx `"`r(xlsx)'"'
    log close _st231c
    set linesize 80
    _v_line "`lg'" "(tabtools: sheet() ignored; no xlsx() and no session workbook)" 1
    assert `"`rx'"' == ""
    capture confirm file "`cwdfile'"
    assert _rc == 601
    * with xlsx() given the note is not printed
    local book "`output_dir'/st231_s5.xlsx"
    capture erase "`book'"
    set linesize 255
    log using "`lg'", replace text name(_st231c)
    stratetab, using("`f1'") outcomes(1) xlsx("`book'") sheet("Given")
    log close _st231c
    set linesize 80
    _v_line "`lg'" "(tabtools: sheet() ignored; no xlsx() and no session workbook)" 0
}
if _rc == 0 {
    display as result "  PASS: S5 sheet() with no workbook prints the exact note"
    local ++pass_count
}
else {
    display as error "  FAIL: S5 sheet() ignored note (rc=`=_rc')"
    local ++fail_count
}
capture log close _st231c
set linesize 80

**# S6: zerocells(dash|blank) and masktext(); refusals
capture noisily {
    * file 2: Low has 0 events, Mid 3, High 8
    stratetab, using("`f2'") outcomes(1) frame(_s6, replace) smallcells(5)
    * defaults: zero printed with rate 0.0 (–) as strate saved it; <5 masked
    frame _s6: assert c2[5] == "0" & c3[5] == "100" & c4[5] == "0.0 (–)"
    frame _s6: assert c2[6] == "<5" & c3[6] == "–" & c4[6] == "–"
    frame _s6: assert c2[7] == "8" & c3[7] == "400"
    stratetab, using("`f2'") outcomes(1) frame(_s6, replace) smallcells(5) ///
        zerocells(dash) masktext("–")
    frame _s6: assert c2[5] == "–" & c3[5] == "100" & c4[5] == "–"
    frame _s6: assert c2[6] == "–" & c3[6] == "–" & c4[6] == "–"
    frame _s6: assert c2[7] == "8" & c3[7] == "400"
    stratetab, using("`f2'") outcomes(1) frame(_s6, replace) zerocells(blank)
    frame _s6: assert c2[5] == "" & c3[5] == "100" & c4[5] == ""
    frame _s6: assert c2[6] == "3" & c3[6] == "200"
    * r(rates) keeps the numbers
    assert el(r(rates), 1, 1) == 0 & reldif(el(r(rates), 2, 1), 15) < 1e-12
    * zeroexact limits are replaced too
    stratetab, using("`f2'") outcomes(1) frame(_s6, replace) zeroexact zerocells(dash)
    frame _s6: assert c2[5] == "–" & c4[5] == "–"
    * abbreviation zero still means zeroexact
    stratetab, using("`f2'") outcomes(1) frame(_s6, replace) zero
    local want = "0.0 (0.0, " + strtrim(string(round(1000 * -ln(0.025) / 100, 0.1), "%24.1f")) + ")"
    frame _s6: assert c4[5] == "`want'"
    frame drop _s6
    capture stratetab, using("`f2'") outcomes(1) zerocells(none)
    assert _rc == 198
    capture stratetab, using("`f2'") outcomes(1) masktext("x")
    assert _rc == 198
    capture stratetab, using("`f2'") outcomes(1) masktext("x") nosmallcells
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: S6 zerocells() and masktext() cells; refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: S6 zerocells/masktext (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _s6

**# S8: sheet() also reaches the session Markdown file (first write replaces)
capture noisily {
    local md "`output_dir'/st231_sess.md"
    file open fh using "`md'", write replace text
    file write fh "STALE LINE" _n
    file close fh
    tabtools set markdown "`md'"
    stratetab, using("`f1'") outcomes(1) sheet("M1") title("First rates")
    assert `"`r(markdown)'"' == "`md'"
    stratetab, using("`f2'") outcomes(1) sheet("M2") title("Second rates")
    _v_line "`md'" "STALE LINE" 0
    _v_line "`md'" "### First rates" 1
    _v_line "`md'" "### Second rates" 1
    * an explicit markdown() wins
    local md2 "`output_dir'/st231_own.md"
    capture erase "`md2'"
    stratetab, using("`f1'") outcomes(1) sheet("M3") markdown("`md2'") title("Own")
    assert `"`r(markdown)'"' == "`md2'"
    _v_line "`md'" "### Own" 0
}
if _rc == 0 {
    display as result "  PASS: S8 sheet() writes the session Markdown file"
    local ++pass_count
}
else {
    display as error "  FAIL: S8 session Markdown (rc=`=_rc')"
    local ++fail_count
}
quietly tabtools set clear

**# S7: session hygiene: varabbrev and data restored on success and error
capture noisily {
    sysuse auto, clear
    set varabbrev on
    capture stratetab, using("`f2'") outcomes(1) zerocells(none)
    assert c(varabbrev) == "on"
    stratetab, using("`f2'") outcomes(1) zerocells(dash) sheet("X")
    assert c(varabbrev) == "on"
    assert _N == 74 & c(filename) != ""
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: S7 varabbrev and data restored"
    local ++pass_count
}
else {
    display as error "  FAIL: S7 session hygiene (rc=`=_rc')"
    local ++fail_count
}
set varabbrev off
capture erase "`c(pwd)'/X.xlsx"
quietly tabtools set clear
capture erase "$V230_RES"
macro drop V230_TOOL V230_RES

local _tc = `pass_count' + `fail_count'
display "RESULT: test_stratetab_v231 tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _st231
if `fail_count' > 0 exit 1
