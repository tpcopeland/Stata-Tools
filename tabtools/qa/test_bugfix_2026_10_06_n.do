* test_bugfix_2026_10_06_n.do - review of the slashN / overflow / SMD-width
* fixes (reviewer N)
*
* N1: a denominator of 1..k-1 printed as <k is a released upper bound on the
*     sum of the level cells (k = 3: <3 over cells 1 and 1 pins both). Full
*     mode withholds it as Suppressed.
* N2: a Missing row's percentage beside a withheld N header releases that N.
* N3: wide exact-ILP grid (2-5 groups, cat/bin/contn, missing, missingsummary,
*     catrowperc on any variable set, total before/after, percent_n, and the
*     primary mode checked literally), continuous variables with
*     missingsummary included.
* N4: SMD with probability weights near the double range stays finite.
* N5: the xlsx SMD column fits the 10-character Suppressed marker.
* N6: a printed continuous summary says n >= k. Beside N = 4 (k = 3) and a
*     Missing <3 that pinned the missing count at 1 (2.5.3); the N header is
*     now withheld, and the Total N with it.
*
* Run from tabtools/qa.

clear all
version 17.0
set more off
set varabbrev off

capture log close _bfn
log using "test_bugfix_2026_10_06_n.log", replace text name(_bfn)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global BFN_OUT "`output_dir'"
global BFN_TOOLS "`qa_dir'/tools"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear
global TABTOOLS_set_smallcells

local pass_count = 0
local fail_count = 0
local test_count = 0

* _n_cell FRAME ROW VAR: r(s) = trimmed string value of VAR in row ROW
capture program drop _n_cell
program define _n_cell, rclass
    args fr row var
    frame `fr': local s = strtrim(`var'[`row'])
    return local s `"`s'"'
end

* _n_width BOOK SHEET NEEDLE: r(width) of the column holding the cell text
capture program drop _n_width
program define _n_width, rclass
    version 17.0
    args book sheet needle
    tempfile out
    capture erase `"`out'"'
    quietly shell python3 "$BFN_TOOLS/xlsx_facts.py" "`book'" "`sheet'" "`out'"
    confirm file `"`out'"'
    tempname h
    local col ""
    local w .
    file open `h' using `"`out'"', read text
    file read `h' line
    while r(eof) == 0 {
        if substr(`"`macval(line)'"', 1, 6) == "value " {
            local rest = substr(`"`macval(line)'"', 7, .)
            gettoken cell txt : rest
            if strtrim(`"`macval(txt)'"') == `"`needle'"' {
                local col = regexr("`cell'", "[0-9]+$", "")
            }
        }
        file read `h' line
    }
    file close `h'
    file open `h' using `"`out'"', read text
    file read `h' line
    while r(eof) == 0 {
        if substr(`"`macval(line)'"', 1, 6) == "width " {
            tokenize `"`macval(line)'"'
            if "`2'" == "`col'" local w = round(real("`3'") - 0.71, 0.01)
        }
        file read `h' line
    }
    file close `h'
    return scalar width = `w'
end

**# N1: a denominator below k is withheld, never printed as <k
local ++test_count
capture noisily {
    * four groups, k = 3, a continuous and a categorical variable (so the
    * group N headers are shared). Non-missing (level 1, 2, 3) counts of the
    * categorical: g1 (2, 0, 6), g2 (2, 1, 1), g3 (1, 0, 1), g4 (1, 3, 4);
    * missing 6, 2, 4, 1. Group 3 has denominator 2 with two level cells of 1.
    clear
    local gn "14 6 6 9"
    local c1 "2 2 1 1"
    local c2 "0 1 0 3"
    local c3 "6 1 1 4"
    gen g = .
    gen v = .
    local at 0
    forvalues j = 1/4 {
        local n : word `j' of `gn'
        local a : word `j' of `c1'
        local b : word `j' of `c2'
        local c : word `j' of `c3'
        quietly set obs `=`at' + `n''
        quietly replace g = `j' in `=`at' + 1'/`=`at' + `n''
        if `a' > 0 quietly replace v = 1 in `=`at' + 1'/`=`at' + `a''
        if `b' > 0 quietly replace v = 2 in `=`at' + `a' + 1'/`=`at' + `a' + `b''
        if `c' > 0 quietly replace v = 3 in `=`at' + `a' + `b' + 1'/`=`at' + `a' + `b' + `c''
        local at = `at' + `n'
    }
    set seed 1400
    gen double x = rnormal()
    table1_tc, by(g) vars(x contn \ v cat) slashN total(after) smallcells(3) frame(_n1, replace)
    frame _n1: list, noobs
    frame _n1: quietly count if strpos(g_1, "/<") | strpos(g_2, "/<") | strpos(g_3, "/<") | strpos(g_4, "/<") | strpos(g_T, "/<")
    assert r(N) == 0
    * group 3: the level cells are <3 and the denominator is Suppressed, as is
    * the Total's (it would give group 3's back by subtraction)
    frame _n1: quietly count if strpos(g_3, "/Suppressed")
    assert r(N) == 1
    frame _n1: quietly count if strpos(g_T, "/Suppressed")
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: N1 no denominator is printed as </k"
    local ++pass_count
}
else {
    display as error "  FAIL: N1 denominator below k (rc=`=_rc')"
    local ++fail_count
}

**# N2: a Missing percentage never accompanies a withheld N header
local ++test_count
capture noisily {
    * five groups: (missing, zero, one) = (1,1,3) (4,2,6) (1,0,4) (4,2,8) (0,0,12);
    * the first four N headers print as >=3
    clear
    local mm "1 4 1 4 0"
    local zz "1 2 0 2 0"
    local oo "3 6 4 8 12"
    gen g = .
    gen b = .
    local at 0
    forvalues j = 1/5 {
        local m : word `j' of `mm'
        local z : word `j' of `zz'
        local o : word `j' of `oo'
        local n = `m' + `z' + `o'
        quietly set obs `=`at' + `n''
        quietly replace g = `j' in `=`at' + 1'/`=`at' + `n''
        if `z' > 0 quietly replace b = 0 in `=`at' + 1'/`=`at' + `z''
        quietly replace b = 1 in `=`at' + `z' + 1'/`=`at' + `z' + `o''
        local at = `at' + `n'
    }
    table1_tc, by(g) vars(b bin) slashN total(before) missingsummary smallcells(3) frame(_n2, replace)
    frame _n2: list, noobs
    * every column whose N header is withheld prints its Missing count bare
    local ncols 0
    foreach c in g_1 g_2 g_3 g_4 g_5 g_T {
        _n_cell _n2 2 `c'
        local hdr `"`r(s)'"'
        _n_cell _n2 4 `c'
        local miss `"`r(s)'"'
        if substr(`"`hdr'"', 1, 1) != "N" {
            local ++ncols
            assert strpos(`"`miss'"', "(") == 0
        }
    }
    assert `ncols' >= 1
}
if _rc == 0 {
    display as result "  PASS: N2 Missing percentage withheld beside a withheld N"
    local ++pass_count
}
else {
    display as error "  FAIL: N2 Missing percentage (rc=`=_rc')"
    local ++fail_count
}

**# N3: wide grid against the exact integer program
local ++test_count
capture noisily {
    tempfile tok
    local cdir "`tok'_n3"
    capture mkdir "`cdir'"
    local ilp "`qa_dir'/tools/smallcells_ilp.py"
    shell python3 "`ilp'" gen --grid wide --dir "`cdir'" --n 500 --seed 20261008
    confirm file "`cdir'/cases.csv"
    import delimited using "`cdir'/cases.csv", clear varnames(1) stringcols(_all)
    local ncase = _N
    assert `ncase' == 500
    forvalues c = 1/`ncase' {
        local id_`c' = id[`c']
        local vars_`c' = vars[`c']
        local opts_`c' = opts[`c']
        local k_`c' = k[`c']
        local mode_`c' = mode[`c']
    }
    local nref 0
    forvalues c = 1/`ncase' {
        import delimited using "`cdir'/case_`id_`c''.csv", clear varnames(1)
        local sc "`k_`c''"
        if "`mode_`c''" == "primary" local sc "`k_`c'', primary"
        capture table1_tc, by(g) vars(`vars_`c'') `opts_`c'' smallcells(`sc') frame(_n3, replace)
        if _rc == 498 {
            local ++nref
            tempname fh
            file open `fh' using "`cdir'/case_`id_`c''_refused", write text replace
            file close `fh'
            continue
        }
        if _rc {
            display as error "case `id_`c'': table1_tc rc=`=_rc' (vars(`vars_`c'') `opts_`c'' smallcells(`sc'))"
            exit 9
        }
        frame _n3: quietly export delimited using "`cdir'/case_`id_`c''_table.csv", replace
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
    assert `nref' < 250
    display as text "    refused (rc 498): `nref' of `ncase'"
}
if _rc == 0 {
    display as result "  PASS: N3 no protected count is pinned in 500 wide-grid tables"
    local ++pass_count
}
else {
    display as error "  FAIL: N3 wide grid (rc=`=_rc')"
    local ++fail_count
}

**# N4: SMD with weights near the double range equals the SMD with unit-scale weights
local ++test_count
capture noisily {
    clear
    set seed 20261007
    set obs 90
    gen g = ceil(_n / 30)
    gen double x = rnormal() + (g == 2) * 0.5
    gen double w = 0.5 + runiform()
    gen double wk = w * 1e306
    gen double wh = w * 1e307
    foreach spec in "smd" "smd smdtype(maxpair)" "smd smdtype(population)" {
        table1_tc, by(g) vars(x contn) wt(w) `spec' frame(_n4a, replace)
        _n_cell _n4a 4 smd_str
        local ref `"`r(s)'"'
        assert real("`ref'") < .
        foreach wv in wk wh {
            table1_tc, by(g) vars(x contn) wt(`wv') `spec' frame(_n4b, replace)
            _n_cell _n4b 4 smd_str
            assert `"`r(s)'"' == "`ref'"
        }
    }
    * two groups: the default pair path
    keep if g <= 2
    table1_tc, by(g) vars(x contn) wt(w) smd frame(_n4a, replace)
    _n_cell _n4a 4 smd_str
    local ref `"`r(s)'"'
    assert real("`ref'") < .
    foreach wv in wk wh {
        table1_tc, by(g) vars(x contn) wt(`wv') smd frame(_n4b, replace)
        _n_cell _n4b 4 smd_str
        assert `"`r(s)'"' == "`ref'"
    }
}
if _rc == 0 {
    display as result "  PASS: N4 SMD is finite and scale-invariant for weights up to 1e307"
    local ++pass_count
}
else {
    display as error "  FAIL: N4 SMD with huge weights (rc=`=_rc')"
    local ++fail_count
}

**# N5: the SMD column fits the Suppressed marker
local ++test_count
capture noisily {
    clear
    set seed 20261007
    set obs 50
    gen g = 1 + (_n > 25)
    gen double x = rnormal()
    gen b = 1
    replace b = 0 in 1/24
    replace b = 1 in 26/50
    replace b = 0 in 26/30
    local book "$BFN_OUT/bfn_smd_supp.xlsx"
    table1_tc, by(g) vars(x contn \ b bin) smd smallcells(3) excel("`book'") sheet(t1) frame(_n5, replace)
    frame _n5: quietly count if smd_str == "Suppressed"
    assert r(N) == 1
    _n_width "`book'" t1 "SMD"
    assert r(width) == 10
    * without a suppressed SMD the bare header keeps width 8
    local book2 "$BFN_OUT/bfn_smd_plain.xlsx"
    table1_tc, by(g) vars(x contn) smd excel("`book2'") sheet(t1)
    _n_width "`book2'" t1 "SMD"
    assert r(width) == 8
}
if _rc == 0 {
    display as result "  PASS: N5 SMD column is 10 wide only when it holds Suppressed"
    local ++pass_count
}
else {
    display as error "  FAIL: N5 SMD width (rc=`=_rc')"
    local ++fail_count
}

capture frame drop _n1
capture frame drop _n2
capture frame drop _n3
capture frame drop _n4a
capture frame drop _n4b
capture frame drop _n5

**# N6: a printed mean says n >= k (continuous + missingsummary)
local ++test_count
capture noisily {
    clear
    quietly set obs 16
    gen g = cond(_n <= 4, 1, cond(_n <= 10, 2, 3))
    gen double x = _n
    quietly replace x = . in 4
    quietly replace x = . in 11/12
    * group 1: N = 4, n = 3 (mean printed), missing 1 (<3): N - n <= 1 and
    * missing >= 1 pinned it at 1 when N = 4 was printed
    table1_tc, by(g) vars(x contn) missingsummary smallcells(3) frame(_n6, replace)
    frame _n6: assert strtrim(g_1[2]) == "≥3"
    frame _n6: assert strtrim(g_1[4]) == "<3"
    frame _n6: assert strtrim(g_2[2]) == "N=6"
    frame _n6: assert strtrim(g_3[2]) == "N=6"
    * the mean is still printed: the bound protects without hiding it
    frame _n6: assert strtrim(g_1[3]) == "2±1"
    table1_tc, by(g) vars(x contn) missingsummary smallcells(3) total(after) frame(_n6t, replace)
    frame _n6t: assert strtrim(g_1[2]) == "≥3"
    frame _n6t: assert strtrim(g_T[2]) == "≥3"
    frame _n6t: assert strtrim(g_T[4]) == "3"
    * a group whose N leaves room (N = 6, missing <3) keeps its N
    frame _n6t: assert strtrim(g_3[2]) == "N=6"
    capture frame drop _n6
    capture frame drop _n6t
}
if _rc == 0 {
    display as result "  PASS: N6 a printed continuous summary is counted as n >= k"
    local ++pass_count
}
else {
    display as error "  FAIL: N6 continuous + missingsummary lower bound (rc=`=_rc')"
    local ++fail_count
}

display "RESULT: test_bugfix_2026_10_06_n tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _bfn
if `fail_count' > 0 exit 9
