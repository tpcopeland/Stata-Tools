* test_bugfix_2026_10_06_m.do - smallcells() under slashN: a printed
* denominator never releases a protected count
*
* Report 2026-10-06-tabtools-smallcells-slashN-denominator-leak (P0): the
* count block certified each printed n/denominator as N minus the hidden
* rows, but the denominator stayed printed beside a withheld (>=k) group N,
* where it is a released sum of the level cells (x: <3 + 0 + <3 = 4 pins
* both cells at 2), and the Total column's denominator stayed printed when
* one group's was withheld (24 - 6 - 13 = 5 gives z's). Fixed in 2.5.2: a
* column whose N header is withheld withholds its denominator, and the Total
* withholds its own when its N or any group denominator is withheld.
*
* M1, M2: the report's two tables, cell for cell.
* M3: 200 random three-group slashN tables (categorical and binary, one and
*     two variables, total(after), catrowperc on binary-only tables, k 3/4)
*     checked by an independent exact integer program (tools/smallcells_ilp.py,
*     scipy milp) that reads only the published table: no count of 1..k-1,
*     printed or hidden (missing, a binary's negative row), may be pinned to
*     one value. A refused table (rc 498) passes; any other rc fails.
*
* Run from tabtools/qa.

clear all
version 17.0
set more off
set varabbrev off

capture log close _bfm
log using "test_bugfix_2026_10_06_m.log", replace text name(_bfm)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local pass_count = 0
local fail_count = 0
local test_count = 0

* _m_cell FRAME ROW VAR: r(s) = trimmed string value of VAR in row ROW
capture program drop _m_cell
program define _m_cell, rclass
    args fr row var
    frame `fr': local s = strtrim(`var'[`row'])
    return local s `"`s'"'
end

capture program drop _m_repro1
program define _m_repro1
    * the report's 22 rows, in order (g, v); "." is missing
    clear
    local gs "1 1 1 1 2 2 2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3"
    local vs "3 3 1 1 . 1 1 1 3 1 1 3 1 2 . 2 1 . . 1 . 1"
    quietly set obs 22
    gen g = .
    gen v = .
    forvalues i = 1/22 {
        quietly replace g = real(word("`gs'", `i')) in `i'
        quietly replace v = real(word("`vs'", `i')) in `i'
    }
    label define gl 1 "x" 2 "y" 3 "z", replace
    label values g gl
end

**# M1: categorical, slashN, k = 3 (report repro 1)
local ++test_count
capture noisily {
    _m_repro1
    table1_tc, by(g) vars(v cat) slashN smallcells(3) frame(_m1, replace)
    * group x (N withheld): 2.5.1 printed 0/4, which pins both <3 cells at 2
    _m_cell _m1 5 g_1
    assert "`r(s)'" == "0/Suppressed"
    * group z (N withheld): 2.5.1 printed 3/5 and 0/5, which pins its <3 at 2
    _m_cell _m1 4 g_3
    assert "`r(s)'" == "3/Suppressed"
    _m_cell _m1 6 g_3
    assert "`r(s)'" == "0/Suppressed"
    * group y keeps its 2.5.1 cells (its N is printed; its missing row withheld)
    _m_cell _m1 2 g_2
    assert "`r(s)'" == "N=9"
    _m_cell _m1 4 g_2
    assert "`r(s)'" == "6/Suppressed"
    * the same table with a Total column: its denominator goes too
    _m_repro1
    table1_tc, by(g) vars(v cat) slashN smallcells(3) total(after) frame(_m1t, replace)
    frame _m1t: count if strpos(g_T, "/") & !strpos(g_T, "/Suppressed")
    assert r(N) == 0
    _m_cell _m1t 5 g_1
    assert "`r(s)'" == "0/Suppressed"
}
if _rc == 0 {
    display as result "  PASS: M1 categorical denominators beside a withheld N are withheld"
    local ++pass_count
}
else {
    display as error "  FAIL: M1 categorical slashN repro (rc=`=_rc')"
    local ++fail_count
}

**# M2: binary, slashN catrowperc total(after), k = 3 (report repro 2)
local ++test_count
capture noisily {
    clear
    quietly set obs 24
    gen g = cond(_n <= 6, 1, cond(_n <= 19, 2, 3))
    gen b = 1
    quietly replace b = 0 in 17/19
    quietly replace b = 0 in 24
    label define gl 1 "x" 2 "y" 3 "z", replace
    label values g gl
    table1_tc, by(g) vars(b bin) slashN catrowperc total(after) smallcells(3) frame(_m2, replace)
    _m_cell _m2 2 g_1
    assert "`r(s)'" == "N=6"
    _m_cell _m2 3 g_1
    assert "`r(s)'" == "6/6"
    _m_cell _m2 3 g_2
    assert "`r(s)'" == "10/13"
    _m_cell _m2 3 g_3
    assert "`r(s)'" == "4/Suppressed"
    * 2.5.1 printed 20/24, so z's denominator was 24 - 6 - 13 = 5 and its
    * negative count 5 - 4 = 1
    _m_cell _m2 3 g_T
    assert "`r(s)'" == "20/Suppressed"
}
if _rc == 0 {
    display as result "  PASS: M2 a withheld group denominator withholds the Total's"
    local ++pass_count
}
else {
    display as error "  FAIL: M2 binary slashN Total repro (rc=`=_rc')"
    local ++fail_count
}

**# M3: random tables against an exact integer program
local ++test_count
capture noisily {
    tempfile tok
    local cdir "`tok'_m3"
    capture mkdir "`cdir'"
    local ilp "`qa_dir'/tools/smallcells_ilp.py"
    shell python3 "`ilp'" gen --dir "`cdir'" --n 200 --seed 20261006
    confirm file "`cdir'/cases.csv"
    import delimited using "`cdir'/cases.csv", clear varnames(1) stringcols(_all)
    local ncase = _N
    assert `ncase' == 200
    forvalues c = 1/`ncase' {
        local id_`c' = id[`c']
        local vars_`c' = vars[`c']
        local opts_`c' = opts[`c']
        local k_`c' = k[`c']
    }
    local nref 0
    forvalues c = 1/`ncase' {
        import delimited using "`cdir'/case_`id_`c''.csv", clear varnames(1)
        capture table1_tc, by(g) vars(`vars_`c'') `opts_`c'' smallcells(`k_`c'') frame(_m3, replace)
        if _rc == 498 {
            local ++nref
            tempname fh
            file open `fh' using "`cdir'/case_`id_`c''_refused", write text replace
            file close `fh'
            continue
        }
        if _rc {
            display as error "case `id_`c'': table1_tc rc=`=_rc' (vars(`vars_`c'') `opts_`c'' k=`k_`c'')"
            exit 9
        }
        frame _m3: quietly export delimited using "`cdir'/case_`id_`c''_table.csv", replace
    }
    local status "`cdir'/status.txt"
    shell python3 "`ilp'" check --dir "`cdir'" --status "`status'"
    tempname sh
    file open `sh' using "`status'", read text
    file read `sh' line
    local nl 0
    while r(eof) == 0 & `nl' < 15 {
        display as text "    `line'"
        local ++nl
        file read `sh' line
    }
    file close `sh'
    file open `sh' using "`status'", read text
    file read `sh' head
    file close `sh'
    assert substr(`"`head'"', 1, 5) == "PASS "
    * the grid must mostly publish tables, not be refused wholesale
    assert `nref' < 100
    display as text "    refused (rc 498): `nref' of `ncase'"
}
if _rc == 0 {
    display as result "  PASS: M3 no protected count is pinned in 200 random slashN tables"
    local ++pass_count
}
else {
    display as error "  FAIL: M3 random slashN tables (rc=`=_rc')"
    local ++fail_count
}

capture frame drop _m1
capture frame drop _m1t
capture frame drop _m2
capture frame drop _m3

display "RESULT: test_bugfix_2026_10_06_m tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _bfm
if `fail_count' > 0 exit 9
