* test_cycle_20261119_desctab.do - Regression QA for the 2026-11-19 desctab review cycle
*
* F1  long by() names: group columns are <by>_<level> / <by>_T; a name that
*     fits must succeed (total() too, headerperc too), one that cannot must
*     fail r(198) before any internal rename
* F2  by() names that prefix internal columns (f, c, p, smd) give the same
*     table as any other by() name, and keep boldp() formatting in Excel
* F3  total() with an unlabeled numeric by() keeps "by = level" headers
* F4  total(after) sits after the last group, ahead of Test/Statistic/p-value
* F5  no varlist and no vars(): every variable but by() (documented); r(100)
*     when none is left
* F6  an SMD withheld by smallcells() is .d in r(table), as documented

clear all
set more off
set varabbrev off
version 17.0

capture log close _cyc_dt
log using "test_cycle_20261119_desctab.log", replace text name(_cyc_dt)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local checker "`qa_dir'/tools/check_xlsx.py"
tempfile outtoken
local status "`outtoken'_cyc_dt_status.txt"

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _cyc_dt_verdict
program define _cyc_dt_verdict, rclass
    * Reads the PASS/FAIL line check_xlsx.py wrote; Stata's shell does not
    * propagate the child exit code into _rc.
    syntax , STATUS(string)
    tempname fh
    file open `fh' using "`status'", read text
    file read `fh' line
    file close `fh'
    return local verdict = strtrim(substr("`line'", 1, 4))
end

capture program drop _cyc_dt_data
program define _cyc_dt_data
    clear
    set obs 120
    set seed 1
    generate double age = rnormal(50, 10)
    generate byte sex = rbinomial(1, .5)
    generate int grp = 1 + mod(_n, 2)
end

**# F1 Long by() names
**## A 24-char by() name with total(after) builds <by>_1 <by>_2 <by>_T
local ++test_count
capture noisily {
    _cyc_dt_data
    generate byte treatment_assignment_grp = grp
    desctab age sex, by(treatment_assignment_grp) total(after) frame(_cyc_f1a, replace)
    frame _cyc_f1a {
        confirm variable treatment_assignment_grp_1 treatment_assignment_grp_2 ///
            treatment_assignment_grp_T, exact
        assert treatment_assignment_grp_1[1] == "treatment_assignment_grp = 1"
        assert treatment_assignment_grp_T[1] == "Total"
        assert treatment_assignment_grp_T[2] == "N=120"
    }
    frame drop _cyc_f1a
}
if _rc == 0 {
    display as result "  PASS: F1 24-char by() with total(after)"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 24-char by() with total(after) (rc=`=_rc')"
    local ++fail_count
}

**## A 29-char by() name with total(before): <by>_T is 31 characters and fits
local ++test_count
capture noisily {
    _cyc_dt_data
    generate byte abcdefghijklmnopqrstuvwxyz123 = grp
    desctab age, by(abcdefghijklmnopqrstuvwxyz123) total(before) frame(_cyc_f1b, replace)
    frame _cyc_f1b {
        confirm variable abcdefghijklmnopqrstuvwxyz123_T ///
            abcdefghijklmnopqrstuvwxyz123_1 abcdefghijklmnopqrstuvwxyz123_2, exact
        ds
        assert "`r(varlist)'" == "factor abcdefghijklmnopqrstuvwxyz123_T abcdefghijklmnopqrstuvwxyz123_1 abcdefghijklmnopqrstuvwxyz123_2 pvalue"
    }
    frame drop _cyc_f1b
}
if _rc == 0 {
    display as result "  PASS: F1 29-char by() with total(before)"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 29-char by() with total(before) (rc=`=_rc')"
    local ++fail_count
}

**## headerperc with a long by() name and total(after) prints the shares
* The scratch macro was hperc_scratch_for_<column>, over 31 characters here.
local ++test_count
capture noisily {
    _cyc_dt_data
    generate byte treatment_assignment_grp = grp
    desctab age sex, by(treatment_assignment_grp) total(after) headerperc frame(_cyc_f1c, replace)
    frame _cyc_f1c {
        assert treatment_assignment_grp_1[2] == "60 (50.0)"
        assert treatment_assignment_grp_2[2] == "60 (50.0)"
        assert treatment_assignment_grp_T[2] == "120 (100.0)"
    }
    frame drop _cyc_f1c
}
if _rc == 0 {
    display as result "  PASS: F1 headerperc with a long by() name"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 headerperc with a long by() name (rc=`=_rc')"
    local ++fail_count
}

**## headerperc with a 14-char by() name and no total()
* hperc_scratch_for_treatment_arms_1 is 34 characters; the old rename path
* handled this name, so this isolates the headerperc macro-name defect.
local ++test_count
capture noisily {
    _cyc_dt_data
    generate byte treatment_arms = grp
    desctab age sex, by(treatment_arms) headerperc frame(_cyc_f1e, replace)
    frame _cyc_f1e {
        assert treatment_arms_1[2] == "60 (50.0)"
        assert treatment_arms_2[2] == "60 (50.0)"
    }
    frame drop _cyc_f1e
}
if _rc == 0 {
    display as result "  PASS: F1 headerperc with a 14-char by() name"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 headerperc with a 14-char by() name (rc=`=_rc')"
    local ++fail_count
}

**## A by() name that cannot carry its columns fails r(198) and writes nothing
local ++test_count
capture noisily {
    _cyc_dt_data
    generate byte abcdefghijklmnopqrstuvwxyz_12345 = grp
    generate byte abcdefghijklmnopqrstuvwxyz_1234 = grp
    capture frame drop _cyc_f1d
    * 32 chars: <by>_1 is 34
    capture noisily desctab age, by(abcdefghijklmnopqrstuvwxyz_12345) frame(_cyc_f1d)
    assert _rc == 198
    * 31 chars with total(): <by>_T is 33
    capture noisily desctab age, by(abcdefghijklmnopqrstuvwxyz_1234) total(after) frame(_cyc_f1d)
    assert _rc == 198
    capture frame _cyc_f1d: describe
    assert _rc != 0
    * the same 31-char name without total(): <by>_1 is 33, also refused
    capture noisily desctab age, by(abcdefghijklmnopqrstuvwxyz_1234) frame(_cyc_f1d)
    assert _rc == 198
    * the caller's data is untouched
    assert _N == 120
    confirm variable age sex grp, exact
}
if _rc == 0 {
    display as result "  PASS: F1 over-long by() name refused r(198)"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 over-long by() name refused r(198) (rc=`=_rc')"
    local ++fail_count
}

**# F2 by() names that prefix internal columns
**## by(f), by(c), by(p), by(smd) give the by(grp) table, column for column
local ++test_count
capture noisily {
    _cyc_dt_data
    desctab age sex, by(grp) test smd frame(_cyc_ref, replace)
    frame _cyc_ref {
        ds
        local _refvars "`r(varlist)'"
        local _nref = _N
    }
    assert "`_refvars'" == "factor grp_1 grp_2 test pvalue smd_str"
    foreach b in f c p smd {
        _cyc_dt_data
        generate int `b' = grp
        desctab age sex, by(`b') test smd frame(_cyc_f2, replace)
        frame _cyc_f2 {
            ds
            assert "`r(varlist)'" == "factor `b'_1 `b'_2 test pvalue smd_str"
            assert _N == `_nref'
            rename (`b'_1 `b'_2) (grp_1 grp_2)
        }
        * every cell of the table matches the by(grp) table, header rows
        * aside (they carry the by name)
        frame _cyc_f2 {
            forvalues i = 1/`=_N' {
                foreach v in factor test pvalue smd_str {
                    assert `v'[`i'] == _frval(_cyc_ref, `v', `i')
                }
                if `i' > 1 {
                    assert grp_1[`i'] == _frval(_cyc_ref, grp_1, `i')
                    assert grp_2[`i'] == _frval(_cyc_ref, grp_2, `i')
                }
            }
            assert grp_1[1] == "`b' = 1"
        }
        frame drop _cyc_f2
    }
    frame drop _cyc_ref
}
if _rc == 0 {
    display as result "  PASS: F2 by(f c p smd) match by(grp)"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 by(f c p smd) match by(grp) (rc=`=_rc')"
    local ++fail_count
}

**## by(p) keeps boldp() on the p-value cell in Excel
local ++test_count
capture noisily {
    _cyc_dt_data
    generate int p = grp
    local book "`output_dir'/_cyc_dt_boldp.xlsx"
    capture erase "`book'"
    desctab age, by(p) boldp(0.99) xlsx("`book'") sheet("BP")
    capture erase "`status'"
    shell python3 "`checker'" "`book'" --sheet "BP" --cell E2 "p-value" ///
        --row-bold-contains "age" --result-file "`status'"
    _cyc_dt_verdict, status("`status'")
    assert "`r(verdict)'" == "PASS"
    * the bold is the p-value cell, not some other cell of the row: the same
    * call without boldp() has no bold in that row
    capture erase "`book'"
    desctab age, by(p) xlsx("`book'") sheet("BP")
    capture erase "`status'"
    shell python3 "`checker'" "`book'" --sheet "BP" --row-bold-contains "age" --result-file "`status'"
    _cyc_dt_verdict, status("`status'")
    assert "`r(verdict)'" == "FAIL"
    capture erase "`book'"
}
if _rc == 0 {
    display as result "  PASS: F2 by(p) boldp() bolds the p-value cell"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 by(p) boldp() bolds the p-value cell (rc=`=_rc')"
    local ++fail_count
}

**# F3 Unlabeled numeric by() headers with total()
**## total(after) keeps "g = 1" headers in frame and Excel
local ++test_count
capture noisily {
    _cyc_dt_data
    generate int g = grp
    desctab age, by(g) total(after) frame(_cyc_f3, replace)
    frame _cyc_f3 {
        assert g_1[1] == "g = 1"
        assert g_2[1] == "g = 2"
        assert g_T[1] == "Total"
    }
    frame drop _cyc_f3
    desctab age, by(g) total(before) frame(_cyc_f3, replace)
    frame _cyc_f3 {
        assert g_1[1] == "g = 1"
        assert g_T[1] == "Total"
    }
    frame drop _cyc_f3
    local book "`output_dir'/_cyc_dt_hdr.xlsx"
    capture erase "`book'"
    desctab age, by(g) total(after) xlsx("`book'") sheet("H")
    capture erase "`status'"
    shell python3 "`checker'" "`book'" --sheet "H" --cell C2 "g = 1" --cell D2 "g = 2" ///
        --cell E2 "Total" --result-file "`status'"
    _cyc_dt_verdict, status("`status'")
    assert "`r(verdict)'" == "PASS"
    capture erase "`book'"
    * a value-labeled by() still prints its labels
    label define _cyc_gl 1 "Control" 2 "Treated"
    label values g _cyc_gl
    desctab age, by(g) total(after) frame(_cyc_f3, replace)
    frame _cyc_f3 {
        assert g_1[1] == "Control"
        assert g_2[1] == "Treated"
        assert g_T[1] == "Total"
    }
    frame drop _cyc_f3
}
if _rc == 0 {
    display as result "  PASS: F3 unlabeled by() headers with total()"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 unlabeled by() headers with total() (rc=`=_rc')"
    local ++fail_count
}

**## wtcompare with total() keeps "Crude g = 1" / "Weighted g = 1"
local ++test_count
capture noisily {
    _cyc_dt_data
    generate int g = grp
    generate double w = 0.5 + runiform()
    desctab age, by(g) wt(w) wtcompare total(after) frame(_cyc_f3w, replace)
    frame _cyc_f3w {
        assert Cr_1[1] == "Crude g = 1"
        assert Wt_1[1] == "Weighted g = 1"
        assert Wt_2[1] == "Weighted g = 2"
    }
    frame drop _cyc_f3w
}
if _rc == 0 {
    display as result "  PASS: F3 wtcompare headers with total()"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 wtcompare headers with total() (rc=`=_rc')"
    local ++fail_count
}

**# F4 total(after) column position
**## Total follows the last group, ahead of Test, Statistic and p-value
local ++test_count
capture noisily {
    _cyc_dt_data
    generate int g = grp
    desctab age sex, by(g) total(after) test statistic frame(_cyc_f4, replace)
    frame _cyc_f4 {
        ds
        assert "`r(varlist)'" == "factor g_1 g_2 g_T test statistic pvalue"
    }
    frame drop _cyc_f4
    local book "`output_dir'/_cyc_dt_order.xlsx"
    capture erase "`book'"
    desctab age sex, by(g) total(after) test xlsx("`book'") sheet("O")
    capture erase "`status'"
    shell python3 "`checker'" "`book'" --sheet "O" --cell C2 "g = 1" --cell D2 "g = 2" ///
        --cell E2 "Total" --cell F2 "Test" --cell G2 "p-value" --result-file "`status'"
    _cyc_dt_verdict, status("`status'")
    assert "`r(verdict)'" == "PASS"
    capture erase "`book'"
    * nopvalue: the total is still the last data column
    desctab age sex, by(g) total(after) nopvalue frame(_cyc_f4, replace)
    frame _cyc_f4 {
        ds
        assert "`r(varlist)'" == "factor g_1 g_2 g_T"
    }
    frame drop _cyc_f4
}
if _rc == 0 {
    display as result "  PASS: F4 total(after) column order"
    local ++pass_count
}
else {
    display as error "  FAIL: F4 total(after) column order (rc=`=_rc')"
    local ++fail_count
}

**# F5 No varlist and no vars()
**## desctab, by() describes every variable but the by() variable
* The all-variables default is pinned by test_synthesis_review.do A2 and
* test_package_adversarial.do; the by() variable used to be tabulated
* against itself (0 (0) / 60 (100)).
local ++test_count
capture noisily {
    _cyc_dt_data
    desctab, by(grp) frame(_cyc_f5, replace)
    assert "`r(varlist)'" == "age sex"
    frame _cyc_f5 {
        assert _N == 4
        assert strtrim(factor[3]) == "age"
        assert strtrim(factor[4]) == "sex"
        quietly count if strtrim(factor) == "grp"
        assert r(N) == 0
    }
    frame drop _cyc_f5
    * no by(): every variable, as before
    desctab, frame(_cyc_f5, replace)
    assert "`r(varlist)'" == "age sex grp"
    frame drop _cyc_f5
    * nothing left to describe: r(100)
    keep grp
    capture noisily desctab, by(grp)
    assert _rc == 100
    clear
    capture noisily desctab
    assert _rc == 100
}
if _rc == 0 {
    display as result "  PASS: F5 default varlist excludes the by() variable"
    local ++pass_count
}
else {
    display as error "  FAIL: F5 default varlist excludes the by() variable (rc=`=_rc')"
    local ++fail_count
}

**# F6 Suppressed SMD in r(table)
**## an SMD withheld by smallcells() is .d, beside the .d p-value
local ++test_count
capture noisily {
    clear
    set seed 5
    set obs 112
    generate byte g = 1 + (_n > 100) + (_n > 106)
    generate double age = rnormal(50, 10)
    generate byte sex = rbinomial(1, .5)
    replace sex = 1 in 101/103
    replace sex = 0 in 104/106
    desctab age sex, by(g) smd test total(after) smallcells(5) frame(_cyc_f6, replace)
    tempname T
    matrix `T' = r(table)
    local rsex = rownumb(`T', "sex")
    local rage = rownumb(`T', "age")
    local csmd = colnumb(`T', "smd")
    local cp = colnumb(`T', "p_value")
    assert `rsex' < . & `rage' < . & `csmd' < . & `cp' < .
    assert `T'[`rsex', `cp'] == .d
    assert `T'[`rsex', `csmd'] == .d
    * an unsuppressed SMD stays a non-negative number
    assert `T'[`rage', `csmd'] < . & `T'[`rage', `csmd'] >= 0
    frame _cyc_f6 {
        quietly count if strtrim(factor) == "sex" & smd_str == "Suppressed"
        assert r(N) == 1
    }
    frame drop _cyc_f6
}
if _rc == 0 {
    display as result "  PASS: F6 suppressed SMD is .d in r(table)"
    local ++pass_count
}
else {
    display as error "  FAIL: F6 suppressed SMD is .d in r(table) (rc=`=_rc')"
    local ++fail_count
}

set varabbrev off
capture erase "`status'"

display as result "desctab cycle QA summary: `pass_count' passed, `fail_count' failed"
local _tc = `pass_count' + `fail_count'
display "RESULT: test_cycle_20261119_desctab tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _cyc_dt
if `fail_count' > 0 exit 1
