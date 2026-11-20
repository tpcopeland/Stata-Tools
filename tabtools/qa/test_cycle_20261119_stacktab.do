* test_cycle_20261119_stacktab.do - regressions for the 2026-11-19 stacktab review cycle
*   F1 blocks(... skip(N)) past the end of the block
*   F2 columnmerge() with a blank first column
*   F3 numeric source cells rendered as Excel shows them (whole numbers of more
*      than 15 digits: 15 significant digits, then zeros)
*   F4 columnmerge() letters outside the composed table

clear all
set more off
set varabbrev off
version 17.0

capture log close _cyc_stk
log using "test_cycle_20261119_stacktab.log", replace text name(_cyc_stk)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* Three-column text sheet used by F1 and F4: h1 h2 h3 / x 1 z / w y k
capture program drop _cyc_stk_text
program define _cyc_stk_text
    args file
    clear
    quietly set obs 3
    quietly gen str5 a = word("h1 x w", _n)
    quietly gen str5 b = word("h2 1 y", _n)
    quietly gen str5 c = word("h3 z k", _n)
    export excel using "`file'", sheet("S") replace
end

* Sheet names of a workbook, in r(sheets)
capture program drop _cyc_stk_sheets
program define _cyc_stk_sheets, rclass
    args file
    quietly import excel using "`file'", describe
    local s ""
    forvalues i = 1/`r(N_worksheet)' {
        local s `"`s' `r(worksheet_`i')'"'
    }
    return local sheets `"`s'"'
end

**# F1 skip() past the end of the block
**## skip(99) on a 3-row block is r(198) and writes nothing
local ++test_count
capture noisily {
    local f "`output_dir'/cyc_stk_f1.xlsx"
    _cyc_stk_text "`f'"
    capture frame drop cyc_f1
    capture noisily stacktab using "`f'", sheet("O1") blocks(sheet(S) skip(99)) frame(cyc_f1)
    assert _rc == 198
    capture confirm frame cyc_f1
    assert _rc != 0
    _cyc_stk_sheets "`f'"
    assert !strpos(`"`r(sheets)'"', "O1")
}
if _rc == 0 {
    display as result "  PASS: F1 skip(99) beyond a 3-row block errors, nothing written"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 skip(99) beyond a 3-row block errors, nothing written (rc=`=_rc')"
    local ++fail_count
}

**## skip() boundary: skip(3) drops the last row, skip(4) errors
local ++test_count
capture noisily {
    local f "`output_dir'/cyc_stk_f1b.xlsx"
    _cyc_stk_text "`f'"
    capture frame drop cyc_f1b
    stacktab using "`f'", sheet("O2") blocks(sheet(S) skip(3)) frame(cyc_f1b)
    assert r(rows_written) == 2
    frame cyc_f1b {
        assert _N == 2
        assert _xcol1[1] == "h1" & _xcol1[2] == "x"
    }
    capture noisily stacktab using "`f'", sheet("O3") blocks(sheet(S) rows(2/3) skip(3))
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: F1 skip(N) at and past the block boundary"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 skip(N) at and past the block boundary (rc=`=_rc')"
    local ++fail_count
}

**# F2 columnmerge() with a blank first column
**## puttab sheet: merged label column carries no leading space (frame and workbook)
local ++test_count
capture noisily {
    local f "`output_dir'/cyc_stk_f2.xlsx"
    capture erase "`f'"
    matrix MA = (1.23, 1.05, 1.44)
    matrix colnames MA = HR LL UL
    puttab using "`f'", sheet("A") matrix(MA) title("Model A")
    capture frame drop cyc_f2
    stacktab using "`f'", sheet("CM") blocks(sheet(A)) columnmerge(A+C as "AC") frame(cyc_f2)
    frame cyc_f2 {
        assert _N == 3
        assert _xcol1[1] == "AC"
        assert _xcol1[2] == "HR"
        assert _xcol1[3] == "1.23"
        quietly count if substr(_xcol1, 1, 1) == " "
        assert r(N) == 0
    }
    import excel using "`f'", sheet("CM") clear allstring
    quietly ds
    local v1 : word 1 of `r(varlist)'
    quietly count if `v1' == "1.23"
    assert r(N) == 1
    quietly count if `v1' == "HR"
    assert r(N) == 1
    quietly count if substr(`v1', 1, 1) == " "
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: F2 blank first column takes the second column's text alone"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 blank first column takes the second column's text alone (rc=`=_rc')"
    local ++fail_count
}

**## text sheet: ("", "y") merges to "y"; ("a", "b") still to "a b"; ("q", "") stays "q"
local ++test_count
capture noisily {
    local f "`output_dir'/cyc_stk_f2b.xlsx"
    clear
    input str5 a str5 b str5 c
    "H1" "H2" "H3"
    "" "y" "k"
    "a" "b" "m"
    "q" "" "n"
    end
    export excel using "`f'", sheet("T") replace
    capture frame drop cyc_f2b
    stacktab using "`f'", sheet("Out") blocks(sheet(T)) columnmerge(A+B as "AB") frame(cyc_f2b)
    frame cyc_f2b {
        assert _xcol1[1] == "AB"
        assert _xcol1[2] == "y"
        assert _xcol1[3] == "a b"
        assert _xcol1[4] == "q"
        assert _xcol3[2] == "k"
    }
}
if _rc == 0 {
    display as result "  PASS: F2 merge of blank/populated pairs"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 merge of blank/populated pairs (rc=`=_rc')"
    local ++fail_count
}

**# F3 numeric source cells
**## export excel numeric sheet: 0.1/0.2/0.3 copied as Excel shows them
local ++test_count
capture noisily {
    local f "`output_dir'/cyc_stk_f3.xlsx"
    clear
    set obs 3
    gen str10 lab = "r" + string(_n)
    gen double v = 0.1 * _n
    gen double w = 1234.5678
    export excel using "`f'", sheet("N") replace
    capture frame drop cyc_f3
    stacktab using "`f'", sheet("Out") blocks(sheet(N)) frame(cyc_f3)
    frame cyc_f3 {
        assert _xcol2[1] == "0.1" & _xcol2[2] == "0.2" & _xcol2[3] == "0.3"
        assert _xcol3[1] == "1234.5678"
    }
    import excel using "`f'", sheet("Out") clear allstring
    assert C[1] == "0.1" & C[2] == "0.2" & C[3] == "0.3"
    assert D[3] == "1234.5678"
    assert B[1] == "r1"
}
if _rc == 0 {
    display as result "  PASS: F3 numeric cells copied at Excel precision"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 numeric cells copied at Excel precision (rc=`=_rc')"
    local ++fail_count
}

**## magnitudes Stata's %24.17g misprints, signs, exponents and 15-digit rounding
local ++test_count
capture noisily {
    local f "`output_dir'/cyc_stk_f3b.xlsx"
    clear
    input double x
    1e20
    1.5e20
    -0.25
    -1.2345678912345e-12
    100
    end
    replace x = 1/3 in 5
    export excel using "`f'", sheet("Big") replace
    capture frame drop cyc_f3b
    stacktab using "`f'", sheet("Out") blocks(sheet(Big)) frame(cyc_f3b)
    frame cyc_f3b {
        assert _xcol1[1] == "1e+20"
        assert _xcol1[2] == "1.5e+20"
        assert _xcol1[3] == "-0.25"
        assert _xcol1[4] == "-1.2345678912345e-12"
        assert _xcol1[5] == "0.333333333333333"
        assert real(_xcol1[1]) == 1e20
        assert reldif(real(_xcol1[2]), 1.5e20) < 1e-15
    }
}
if _rc == 0 {
    display as result "  PASS: F3 large/small/negative numeric cells"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 large/small/negative numeric cells (rc=`=_rc')"
    local ++fail_count
}

**## whole numbers of more than 15 digits: 15 significant digits and zeros, magnitude kept
local ++test_count
capture noisily {
    local f "`output_dir'/cyc_stk_f3i.xlsx"
    clear
    quietly set obs 5
    gen double x = .
    replace x = 12345678901234567 in 1
    replace x = 2^53 + 2 in 2
    replace x = -98765432109876543 in 3
    replace x = 123456789012345 in 4
    replace x = 99999999999999999 in 5
    export excel using "`f'", sheet("Int") replace
    capture frame drop cyc_f3i
    stacktab using "`f'", sheet("Out") blocks(sheet(Int)) frame(cyc_f3i)
    frame cyc_f3i {
        assert _xcol1[1] == "12345678901234600"
        assert _xcol1[2] == "9007199254740990"
        assert _xcol1[3] == "-98765432109876500"
        assert _xcol1[4] == "123456789012345"
        assert _xcol1[5] == "100000000000000000"
        forvalues i = 1/5 {
            local t = _xcol1[`i']
            assert regexm("`t'", "^-?[0-9]+$")
            local sig = regexr(regexr("`t'", "^-", ""), "0+$", "")
            assert strlen("`sig'") <= 15
        }
    }
    import excel using "`f'", sheet("Out") clear allstring
    assert B[1] == "12345678901234600"
}
if _rc == 0 {
    display as result "  PASS: F3 long whole numbers capped at 15 significant digits"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 long whole numbers capped at 15 significant digits (rc=`=_rc')"
    local ++fail_count
}

**## text cells that look numeric are copied exactly; numeric cells in a text column re-rendered
local ++test_count
capture noisily {
    local f "`output_dir'/cyc_stk_f3c.xlsx"
    clear
    input str8 t double n
    ".5"     0.5
    "0042"   0.3
    "1.230"  -0.1
    end
    * row 1 a text header over the numeric column: n is a mixed column
    set obs 4
    replace t = "label" in 4
    gsort -t
    export excel using "`f'", sheet("Mix") cell(C4) replace
    putexcel set "`f'", sheet("Mix") modify
    putexcel D4 = "Header"
    putexcel clear
    capture frame drop cyc_f3c
    stacktab using "`f'", sheet("Out") blocks(sheet(Mix)) frame(cyc_f3c)
    frame cyc_f3c {
        list, noobs
        assert _N == 4
        assert _xcol1[1] == "label" & _xcol2[1] == "Header"
        quietly count if _xcol1 == ".5"
        assert r(N) == 1
        quietly count if _xcol1 == "0042"
        assert r(N) == 1
        quietly count if _xcol1 == "1.230"
        assert r(N) == 1
        quietly count if _xcol1 == ".5" & _xcol2 == "0.5"
        assert r(N) == 1
        quietly count if _xcol2 == "0.3"
        assert r(N) == 1
        quietly count if _xcol2 == "-0.1"
        assert r(N) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: F3 text cells untouched, numeric cells re-rendered (offset sheet)"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 text cells untouched, numeric cells re-rendered (offset sheet) (rc=`=_rc')"
    local ++fail_count
}

**## rows()/cols() selections on an offset sheet keep the cell mapping
local ++test_count
capture noisily {
    local f "`output_dir'/cyc_stk_f3d.xlsx"
    clear
    set obs 4
    gen str4 lab = "k" + string(_n)
    gen double v = 0.1 * _n
    gen double w = 0.7 * _n
    export excel using "`f'", sheet("Off") cell(B3) replace
    capture frame drop cyc_f3d
    stacktab using "`f'", sheet("O1") blocks(sheet(Off) rows(4/5) cols(B-D)) frame(cyc_f3d)
    frame cyc_f3d {
        assert _N == 2
        assert _xcol1[1] == "k2" & _xcol2[1] == "0.2" & _xcol3[1] == "1.4"
        assert _xcol1[2] == "k3" & _xcol2[2] == "0.3" & _xcol3[2] == "2.1"
    }
    capture frame drop cyc_f3e
    stacktab using "`f'", sheet("O2") blocks(sheet(Off) rows(6/6)) frame(cyc_f3e)
    frame cyc_f3e {
        assert _N == 1
        assert _xcol1[1] == "k4" & _xcol2[1] == "0.4" & _xcol3[1] == "2.8"
    }
    capture frame drop cyc_f3f
    stacktab using "`f'", sheet("O3") blocks(sheet(Off) cols(C-D)) frame(cyc_f3f)
    frame cyc_f3f {
        assert _N == 4
        assert _xcol1[3] == "0.3" & _xcol2[3] == "2.1"
    }
}
if _rc == 0 {
    display as result "  PASS: F3 rows()/cols() selections keep the cell mapping"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 rows()/cols() selections keep the cell mapping (rc=`=_rc')"
    local ++fail_count
}

**## puttab text sheets are unchanged byte for byte
local ++test_count
capture noisily {
    local f "`output_dir'/cyc_stk_f3g.xlsx"
    capture erase "`f'"
    matrix MB = (0.5, 0.123, 12.30)
    matrix colnames MB = a b c
    puttab using "`f'", sheet("P") matrix(MB) title("T")
    * oracle: the multiset of nonblank source texts, read by import excel
    import excel using "`f'", sheet("P") clear allstring
    gen long _r = _n
    quietly ds _r, not
    foreach v in `r(varlist)' {
        rename `v' c_`v'
    }
    quietly reshape long c_, i(_r) j(_c) string
    quietly keep if c_ != ""
    keep c_
    sort c_
    quietly count
    assert r(N) >= 4
    quietly count if c_ == "0.500" | c_ == "0.50" | c_ == "0.5" | c_ == "0.123" | c_ == "0.12"
    assert r(N) >= 1
    tempfile src
    quietly save `src'
    capture frame drop cyc_f3g
    stacktab using "`f'", sheet("Out") blocks(sheet(P)) frame(cyc_f3g)
    frame cyc_f3g {
        gen long _r = _n
        quietly ds _r, not
        foreach v in `r(varlist)' {
            rename `v' c_`v'
        }
        quietly reshape long c_, i(_r) j(_c) string
        quietly keep if c_ != ""
        keep c_
        sort c_
        cf _all using `src'
    }
}
if _rc == 0 {
    display as result "  PASS: F3 puttab text sheet copied unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 puttab text sheet copied unchanged (rc=`=_rc')"
    local ++fail_count
}

**## a refused call on a numeric sheet leaves the source workbook byte-identical
local ++test_count
capture noisily {
    local f "`output_dir'/cyc_stk_f3h.xlsx"
    clear
    set obs 3
    gen str4 lab = "z" + string(_n)
    gen double v = 0.1 * _n
    export excel using "`f'", sheet("N") replace
    quietly stacktab using "`f'", sheet("Ok") blocks(sheet(N))
    quietly checksum "`f'"
    local before "`r(checksum)':`r(filelen)'"
    capture noisily stacktab using "`f'", sheet("Bad") blocks(sheet(N)) borders(bottom(row 9))
    assert _rc == 198
    quietly checksum "`f'"
    assert "`r(checksum)':`r(filelen)'" == "`before'"
}
if _rc == 0 {
    display as result "  PASS: F3 numeric-cell pass never rewrites the source workbook"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 numeric-cell pass never rewrites the source workbook (rc=`=_rc')"
    local ++fail_count
}

**## rows()-only block on a source sheet whose name holds a backtick and $
local ++test_count
capture noisily {
    local f "`output_dir'/cyc_stk_f3i.xlsx"
    capture erase "`f'"
    mata: st_local("hs", "U " + char(96) + "t " + char(36) + "G")
    clear
    set obs 3
    gen str4 lab = "m" + string(_n)
    gen double v = 0.1 * _n
    export excel using "`f'", sheet(`"`macval(hs)'"') cell(B3) replace
    capture frame drop cyc_f3i
    stacktab using "`f'", sheet("Out") blocks(sheet("`macval(hs)'") rows(4/5)) frame(cyc_f3i)
    frame cyc_f3i {
        assert _N == 2
        assert _xcol1[1] == "m2" & _xcol2[1] == "0.2"
        assert _xcol1[2] == "m3" & _xcol2[2] == "0.3"
    }
    capture frame drop cyc_f3i
}
if _rc == 0 {
    display as result "  PASS: F3 rows()-only block on a hostile source sheet name"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 rows()-only block on a hostile source sheet name (rc=`=_rc')"
    local ++fail_count
}

**# F4 columnmerge() letters count columns of the composed table
**## a letter past the composed width is a stacktab r(198), not a bare r(111)
local ++test_count
capture noisily {
    local f "`output_dir'/cyc_stk_f4.xlsx"
    _cyc_stk_text "`f'"
    capture noisily stacktab using "`f'", sheet("O3") blocks(sheet(S) cols(B-C)) columnmerge(B+C as "BC")
    assert _rc == 198
    _cyc_stk_sheets "`f'"
    assert !strpos(`"`r(sheets)'"', "O3")
    capture noisily stacktab using "`f'", sheet("O5") blocks(sheet(S)) columnmerge(A+B as "x" \ B+C as "y")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: F4 out-of-range and already-merged columnmerge() columns error 198"
    local ++pass_count
}
else {
    display as error "  FAIL: F4 out-of-range and already-merged columnmerge() columns error 198 (rc=`=_rc')"
    local ++fail_count
}

**## with cols(B-C), A+B merges sheet columns B and C (documented positional meaning)
local ++test_count
capture noisily {
    local f "`output_dir'/cyc_stk_f4b.xlsx"
    _cyc_stk_text "`f'"
    capture frame drop cyc_f4b
    stacktab using "`f'", sheet("O4") blocks(sheet(S) cols(B-C)) columnmerge(A+B as "BC") frame(cyc_f4b)
    frame cyc_f4b {
        assert _xcol1[1] == "BC"
        assert _xcol1[2] == "1 z"
        assert _xcol1[3] == "y k"
    }
}
if _rc == 0 {
    display as result "  PASS: F4 columnmerge() letters are composed-table positions"
    local ++pass_count
}
else {
    display as error "  FAIL: F4 columnmerge() letters are composed-table positions (rc=`=_rc')"
    local ++fail_count
}

**## help file states the composed-table rule, the skip() error and numeric rendering
local ++test_count
capture noisily {
    tempname fh
    local hit_cm = 0
    local hit_skip = 0
    local hit_num = 0
    file open `fh' using "`pkg_dir'/stacktab.sthlp", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "letters count columns of the composed") local hit_cm = 1
        if strpos(`"`macval(line)'"', "larger than the block's row count is an error") local hit_skip = 1
        if strpos(`"`macval(line)'"', "at most 15 significant digits") local hit_num = 1
        file read `fh' line
    }
    file close `fh'
    assert `hit_cm' & `hit_skip' & `hit_num'
}
if _rc == 0 {
    display as result "  PASS: help documents F1/F3/F4 behaviour"
    local ++pass_count
}
else {
    display as error "  FAIL: help documents F1/F3/F4 behaviour (rc=`=_rc')"
    local ++fail_count
}

capture frame drop cyc_f1b
capture frame drop cyc_f2
capture frame drop cyc_f2b
capture frame drop cyc_f3
capture frame drop cyc_f3b
capture frame drop cyc_f3c
capture frame drop cyc_f3d
capture frame drop cyc_f3e
capture frame drop cyc_f3f
capture frame drop cyc_f3g
capture frame drop cyc_f4b

display as result "stacktab cycle 2026-11-19 QA summary: `pass_count' passed, `fail_count' failed"
local _tc = `pass_count' + `fail_count'
display "RESULT: test_cycle_20261119_stacktab tests=`_tc' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1

log close _cyc_stk
