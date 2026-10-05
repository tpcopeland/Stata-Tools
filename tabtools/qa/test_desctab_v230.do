* test_desctab_v230.do - desctab/table1_tc cellreplace() (O5): exact-or-error
* replacement of named body cells, seen identically by every sink
*
* The target cell is located independently of the command: by the level's
* row in the frame and the group's column, and in the workbook by reading
* the row back with import excel.

clear all
set more off
set varabbrev off
version 17.0

capture log close _dt230
log using "test_desctab_v230.log", replace text name(_dt230)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global V230_TOOL "`qa_dir'/tools/xlsx_facts.py"
global V230_RES "`output_dir'/dt230_facts.txt"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear
run "`qa_dir'/_qa_v230_helpers.do"

* Fixture: a DMT category with a level folded into "Other" in one period.
clear
set obs 120
gen byte period = 1 + (_n > 60)
label define period 1 "2004-2008" 2 "2009-2013"
label values period period
gen byte dmt = mod(_n, 4) + 1
replace dmt = 4 if period == 1 & dmt == 3
label define dmt 1 "None" 2 "Interferon" 3 "Natalizumab" 4 "Other"
label values dmt dmt
label variable dmt "DMT at conception"
gen double age = 25 + mod(_n, 15)
label variable age "Age"
tempfile dt230_fix
quietly save "`dt230_fix'"

**# cellreplace by header text and by position, every sink
local ++test_count
capture noisily {
    local book "`output_dir'/dt230_cr.xlsx"
    local csv "`output_dir'/dt230_cr.csv"
    local md "`output_dir'/dt230_cr.md"
    capture erase "`book'"
    use "`dt230_fix'", clear
    * without cellreplace the folded level prints a false zero
    table1_tc, by(period) vars(dmt cat \ age contn) frame(dt230_raw, replace)
    frame dt230_raw {
        quietly count if strtrim(factor) == "Natalizumab"
        assert r(N) == 1
        quietly levelsof period_1 if strtrim(factor) == "Natalizumab", local(z) clean
        assert "`z'" == "0 (0)"
    }
    use "`dt230_fix'", clear
    table1_tc, by(period) vars(dmt cat \ age contn) total(before) ///
        cellreplace("Natalizumab" "2004-2008" "In Other" \ "Age" 1 "n/a") ///
        excel("`book'") sheet("T1") csv("`csv'") markdown("`md'") ///
        frame(dt230_cr, replace)
    assert r(n_cellreplace) == 2
    frame dt230_cr {
        quietly levelsof period_1 if strtrim(factor) == "Natalizumab", local(v) clean
        assert "`v'" == "In Other"
        * position 1 is the first column after the label column: Total
        quietly levelsof period_T if strtrim(factor) == "Age", local(v) clean
        assert "`v'" == "n/a"
        * nothing else changed: the other period keeps its count
        quietly levelsof period_2 if strtrim(factor) == "Natalizumab", local(v) clean
        assert regexm("`v'", "^[0-9]+ \([0-9]+\)$")
    }
    import excel using "`book'", sheet("T1") allstring clear
    * B label, C Total, D 2004-2008, E 2009-2013
    quietly count if strtrim(B) == "Natalizumab" & D == "In Other"
    assert r(N) == 1
    quietly count if strtrim(B) == "Age" & C == "n/a"
    assert r(N) == 1
    _v_grep "`csv'" "^ *Natalizumab,[^,]*,In Other,"
    assert r(n) == 1
    _v_grep "`md'" "Natalizumab \| [^|]* \| In Other \|"
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: cellreplace() by header and position in every sink"
    local ++pass_count
}
else {
    display as error "  FAIL: cellreplace() happy path (rc=`=_rc')"
    local ++fail_count
}

**# cellreplace refusals: nothing guessed
local ++test_count
capture noisily {
    use "`dt230_fix'", clear
    local base "by(period) vars(dmt cat \ age contn)"
    capture table1_tc, `base' cellreplace("Nope" 1 "x")
    assert _rc == 198
    capture table1_tc, `base' cellreplace("Natalizumab" 9 "x")
    assert _rc == 125
    capture table1_tc, `base' cellreplace("Natalizumab" 0 "x")
    assert _rc == 125
    capture table1_tc, `base' cellreplace("Natalizumab" "1999" "x")
    assert _rc == 198
    capture table1_tc, `base' cellreplace("Natalizumab" 1)
    assert _rc == 198
    capture table1_tc, `base' cellreplace("Natalizumab" 1 "x" "y")
    assert _rc == 198
    capture table1_tc, `base' cellreplace("Natalizumab" 1 "x" \ )
    assert _rc == 198
    * a level label shared by two variables is ambiguous
    gen byte dmt2 = dmt
    label values dmt2 dmt
    capture table1_tc, by(period) vars(dmt cat \ dmt2 cat) cellreplace("Other" 1 "x")
    assert _rc == 198
    * the header row is never a target
    capture table1_tc, `base' cellreplace("" 1 "x")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: cellreplace() refuses unmatched, ambiguous and malformed entries"
    local ++pass_count
}
else {
    display as error "  FAIL: cellreplace() refusals (rc=`=_rc')"
    local ++fail_count
}

**# cellreplace after smallcells: replaces the masked cell, keeps the masks elsewhere
local ++test_count
capture noisily {
    sysuse auto, clear
    desctab, by(foreign) vars(rep78 cat) smallcells(5, primary) ///
        cellreplace("1" "Foreign" "--") clear
    quietly levelsof foreign_1 if strtrim(factor) == "1", local(v) clean
    assert "`v'" == "--"
    quietly levelsof foreign_0 if strtrim(factor) == "1", local(v) clean
    assert "`v'" == "<5"
}
if _rc == 0 {
    display as result "  PASS: cellreplace() composes with smallcells()"
    local ++pass_count
}
else {
    display as error "  FAIL: cellreplace() with smallcells (rc=`=_rc')"
    local ++fail_count
}

capture frame drop dt230_raw
capture frame drop dt230_cr
capture erase "$V230_RES"
macro drop V230_TOOL V230_RES
display "RESULT: test_desctab_v230 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _dt230
if `fail_count' > 0 exit 1
