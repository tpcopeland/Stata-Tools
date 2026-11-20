* test_cycle_20261119_m_disclosure.do - regressions for the 2026-11-19
* disclosure-methods review (unit m_disclosure):
*   F1 comptab rate mode: a total row that is itself small stays the
*      section's total, so a block whose bounds pin every count is refused
*   F2 puttab: a fraction() denominator or rowtotal() total that adds up
*      from other counts() columns is an undeclared total (r(459))
*   F3 stratetab/outtab refuse smallcells(1|2); comptab re-renders a frame's
*      <framek as <k and refuses a frame masked below 3
*   F4 puttab: a lone totalrow() row equal to the sum over the other panels
*      with a masked term is refused (r(459))
* Printed cells are asserted from the exported CSV lines.

clear all
set more off
set varabbrev off
set linesize 255
version 17.0

capture log close _mdisc
log using "test_cycle_20261119_m_disclosure.log", replace text name(_mdisc)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
local w "`output_dir'"
global MD_OUT "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Helpers

* r(line): the CSV line whose first field (trimmed) is <label>, trimmed;
* r(n): how many lines matched
capture program drop _md_line
program define _md_line, rclass
    version 17.0
    args file label
    tempname h
    local n 0
    local hit ""
    file open `h' using `"`file'"', read text
    file read `h' line
    while r(eof) == 0 {
        local t = strtrim(`"`macval(line)'"')
        local p = strpos(`"`macval(t)'"', ",")
        if `p' {
            if strtrim(substr(`"`macval(t)'"', 1, `p' - 1)) == `"`label'"' {
                local ++n
                local hit `"`macval(t)'"'
            }
        }
        file read `h' line
    }
    file close `h'
    return local line `"`macval(hit)'"'
    return scalar n = `n'
end

* assert the line for <label> in <file> is exactly <expected>
capture program drop _md_is
program define _md_is
    version 17.0
    args file label expected
    _md_line `"`file'"' `"`label'"'
    if r(n) != 1 | `"`r(line)'"' != `"`expected'"' {
        display as error `"  `label': got "`r(line)'" (n=`r(n)'), expected "`expected'""'
        exit 9
    }
end

* stratetab-style input dataset: exposure 0.., events and person-years
capture program drop _md_st
program define _md_st
    version 17.0
    args name lab dvals yvals out
    clear
    local n : word count `dvals'
    quietly set obs `n'
    gen exposure = _n - 1
    gen double _D = .
    gen double _Y = .
    forvalues i = 1/`n' {
        quietly replace _D = `: word `i' of `dvals'' in `i'
        quietly replace _Y = `: word `i' of `yvals'' in `i'
    }
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.8
    gen double _Upper = _Rate * 1.2 + 0.0001
    label variable _Lower "Lower 95% confidence limit"
    label variable _Upper "Upper 95% confidence limit"
    if "`lab'" == "d" label define _mdd 0 "None" 1 "Low" 2 "High", replace
    if "`lab'" == "o" {
        quietly replace exposure = 1
        label define _mdo 1 "All", replace
    }
    label values exposure _md`lab'
    quietly save "`out'/_md_`name'.dta", replace
end

* one-model regtab frame _md1 (stcox i.dose) for comptab rate mode
clear
quietly set obs 300
set seed 20261119
gen byte dose = mod(_n, 3)
label define _mdd 0 "None" 1 "Low" 2 "High", replace
label values dose _mdd
gen double t1 = 1 + 12 * runiform()
gen byte d1 = mod(_n, 4) != 0
collect clear
quietly stset t1, failure(d1)
quietly collect: stcox i.dose, nolog
quietly regtab, models("Outcome 1") frame(_md1, replace) noint
global MD_CMP `"modelframes(_md1) rows(3/4) outcomemap("Outcome 1") keyed"'

* rate frame _rt from an Overall section (one value) and a Dose section
capture program drop _md_rt
program define _md_rt
    version 17.0
    args oval dvals extra
    local w "$MD_OUT"
    if "`oval'" != "" {
        _md_st o o "`oval'" "1700" "`w'"
        _md_st d d "`dvals'" "1000 300 400" "`w'"
        quietly stratetab, using(`w'/_md_o `w'/_md_d) outcomes(1) frame(_rt, replace) ///
            outlabels("Outcome 1") outcomeids("t1") explabels("Overall" \ "Dose") `extra'
    }
    else {
        _md_st d d "`dvals'" "1000 300 400" "`w'"
        quietly stratetab, using(`w'/_md_d) outcomes(1) frame(_rt, replace) ///
            outlabels("Outcome 1") outcomeids("t1") explabels("Dose") `extra'
    }
end

**# F1 comptab: a small total row stays the section's total

**## k=3, Overall 2 = 1 + 1 + 0: bounds force None = Low = 1, refused
local ++test_count
capture noisily {
    _md_rt "2" "1 1 0"
    capture erase "`w'/_md_f1a.csv"
    capture noisily comptab _rt, $MD_CMP smallcells(3) csv("`w'/_md_f1a.csv")
    assert _rc == 498
    capture confirm file "`w'/_md_f1a.csv"
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS: F1 comptab small total 2 = 1+1+0 under smallcells(3) is r(498)"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 comptab small total 2 = 1+1+0 under smallcells(3) (rc=`=_rc')"
    local ++fail_count
}

**## k=4, Overall 3 = 1 + 1 + 1: every count pinned, refused
local ++test_count
capture noisily {
    _md_rt "3" "1 1 1"
    capture erase "`w'/_md_f1b.csv"
    capture noisily comptab _rt, $MD_CMP smallcells(4) csv("`w'/_md_f1b.csv")
    assert _rc == 498
    capture confirm file "`w'/_md_f1b.csv"
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS: F1 comptab small total 3 = 1+1+1 under smallcells(4) is r(498)"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 comptab small total 3 = 1+1+1 under smallcells(4) (rc=`=_rc')"
    local ++fail_count
}

**## control: k=5, Overall 4 = 1 + 3 + 0 keeps two feasible values, printed
local ++test_count
capture noisily {
    _md_rt "4" "1 3 0"
    capture erase "`w'/_md_f1c.csv"
    comptab _rt, $MD_CMP smallcells(5) csv("`w'/_md_f1c.csv")
    assert r(smallcells) == 5
    local d = uchar(8211)
    _md_is "`w'/_md_f1c.csv" "All" "All,<5,`d',`d',,"
    _md_is "`w'/_md_f1c.csv" "None" "None,<5,`d',`d',Reference,"
    _md_is "`w'/_md_f1c.csv" "Low" "Low,<5,`d',`d',`d',`d'"
    _md_line "`w'/_md_f1c.csv" "High"
    assert strpos(`"`r(line)'"', "High,0,400,") == 1
}
if _rc == 0 {
    display as result "  PASS: F1 control: small total 4 = 1+3+0 under smallcells(5) prints masked"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 control: small total 4 = 1+3+0 under smallcells(5) (rc=`=_rc')"
    local ++fail_count
}

**## primary mode is unaffected (no complementary check by request)
local ++test_count
capture noisily {
    _md_rt "3" "1 1 1"
    capture erase "`w'/_md_f1d.csv"
    comptab _rt, $MD_CMP smallcells(4, primary) csv("`w'/_md_f1d.csv")
    local d = uchar(8211)
    _md_is "`w'/_md_f1d.csv" "All" "All,<4,`d',`d',,"
    _md_is "`w'/_md_f1d.csv" "High" "High,<4,`d',`d',`d',`d'"
}
if _rc == 0 {
    display as result "  PASS: F1 primary mode prints the small total masked, no refusal"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 primary mode (rc=`=_rc')"
    local ++fail_count
}

**# F3 thresholds below 3

**## stratetab and outtab refuse smallcells(1) and smallcells(2); 0 is none
local ++test_count
capture noisily {
    foreach t in 1 2 {
        capture noisily _md_rt "" "1 7 9" "smallcells(`t')"
        assert _rc == 198
    }
    _md_rt "" "1 7 9" "smallcells(0) csv(`w'/_md_f3z.csv)"
    _md_line "`w'/_md_f3z.csv" "None"
    assert strpos(`"`r(line)'"', "None,1,") == 1
    clear
    quietly set obs 40
    gen byte ex = _n <= 20
    gen byte y = inlist(_n, 1, 21, 22, 23)
    foreach t in 1 2 {
        capture erase "`w'/_md_f3o.csv"
        capture noisily outtab y, exposure(ex) smallcells(`t') csv("`w'/_md_f3o.csv")
        assert _rc == 198
        capture confirm file "`w'/_md_f3o.csv"
        assert _rc == 601
    }
    outtab y, exposure(ex) smallcells(3) csv("`w'/_md_f3o.csv")
    _md_line "`w'/_md_f3o.csv" "y"
    assert strpos(`"`r(line)'"', "y,<3/20,3/20 (15.0),") == 1
}
if _rc == 0 {
    display as result "  PASS: F3 stratetab/outtab refuse smallcells(1|2); 0 and 3 run"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 stratetab/outtab threshold floor (rc=`=_rc')"
    local ++fail_count
}

**## control: a frame masked at 3 keeps its <3 under comptab smallcells(5)
* (documented: a stratetab-masked cell keeps its text; 1..2 still holds two
* feasible values, so the finer marker discloses nothing)
local ++test_count
capture noisily {
    _md_rt "" "1 7 9" "smallcells(3)"
    capture erase "`w'/_md_f3c.csv"
    comptab _rt, $MD_CMP smallcells(5) csv("`w'/_md_f3c.csv")
    assert r(smallcells) == 5
    local d = uchar(8211)
    _md_is "`w'/_md_f3c.csv" "None" "None,<3,`d',`d',Reference,"
    _md_line "`w'/_md_f3c.csv" "Low"
    assert strpos(`"`r(line)'"', "Low,7,300,") == 1
}
if _rc == 0 {
    display as result "  PASS: F3 control: a frame's <3 stays masked under comptab smallcells(5)"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 control: a frame's <3 under comptab smallcells(5) (rc=`=_rc')"
    local ++fail_count
}

**## comptab refuses a rate frame recorded as masked below 3
local ++test_count
capture noisily {
    _md_rt "" "1 7 9"
    frame _rt: char _dta[tabtools_smallcells] "2"
    capture noisily comptab _rt, $MD_CMP smallcells(5)
    assert _rc == 459
    capture noisily comptab _rt, $MD_CMP
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: F3 comptab refuses a rate frame masked at smallcells(2)"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 comptab rate frame masked at 2 (rc=`=_rc')"
    local ++fail_count
}

**# F2 puttab undeclared totals beyond single counts

**## fraction() denominator n = a + b, a masked: r(459)
local ++test_count
capture noisily {
    clear
    input str3 lab e n a b
    "r1" 10 40 2 38
    "r2" 12 50 20 30
    end
    capture erase "`w'/_md_f2a.csv"
    capture noisily puttab lab e n a b, csv("`w'/_md_f2a.csv") counts(e n a b) ///
        fraction(e/n) smallcells(5)
    assert _rc == 459
    capture confirm file "`w'/_md_f2a.csv"
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS: F2 puttab fraction denominator = a + b is r(459)"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 puttab fraction denominator = a + b (rc=`=_rc')"
    local ++fail_count
}

**## rowtotal() total ntot = a + b, a masked: r(459)
local ++test_count
capture noisily {
    clear
    input str3 lab n1 n0 ntot a b
    "r1" 15 25 40 2 38
    "r2" 20 30 50 20 30
    end
    capture erase "`w'/_md_f2b.csv"
    capture noisily puttab lab n1 n0 ntot a b, csv("`w'/_md_f2b.csv") ///
        counts(n1 n0 ntot a b) rowtotal(ntot: n1 n0) smallcells(5)
    assert _rc == 459
    capture confirm file "`w'/_md_f2b.csv"
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS: F2 puttab rowtotal total = a + b is r(459)"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 puttab rowtotal total = a + b (rc=`=_rc')"
    local ++fail_count
}

**## controls: the declared identity alone, and equal denominators, print
local ++test_count
capture noisily {
    local ge = uchar(8805)
    clear
    input str3 lab n1 n0 ntot a b
    "r1" 2 38 40 15 25
    "r2" 20 30 50 20 30
    end
    capture erase "`w'/_md_f2c.csv"
    puttab lab n1 n0 ntot a b, csv("`w'/_md_f2c.csv") counts(n1 n0 ntot a b) ///
        rowtotal(ntot: n1 n0) smallcells(5)
    _md_is "`w'/_md_f2c.csv" "r1" "r1,<5,`ge'5,40,15,25"
    _md_is "`w'/_md_f2c.csv" "r2" "r2,20,30,50,20,30"
    * n2 = e1 + (n1 - e1) in every row, but n1 is printed: no new information
    clear
    input str3 lab e1 n1 e2 n2
    "r1" 2 40 10 40
    "r2" 12 50 20 50
    end
    capture erase "`w'/_md_f2d.csv"
    puttab lab e1 n1 e2 n2, csv("`w'/_md_f2d.csv") counts(e1 n1 e2 n2) ///
        fraction(e1/n1 e2/n2) smallcells(5)
    _md_is "`w'/_md_f2d.csv" "r1" "r1,<5/40,10/40"
}
if _rc == 0 {
    display as result "  PASS: F2 controls: declared rowtotal and equal printed denominators run"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 controls (rc=`=_rc')"
    local ++fail_count
}

**# F4 puttab lone total row across panels

**## overall row = A total + B total, A total masked: r(459)
local ++test_count
capture noisily {
    clear
    input str8 blk str8 lab a
    "A" "a1" 2
    "A" "a2" 0
    "A" "Total" 2
    "B" "b1" 10
    "B" "b2" 10
    "B" "Total" 20
    "All" "Total" 22
    end
    capture erase "`w'/_md_f4a.csv"
    capture noisily puttab lab a, csv("`w'/_md_f4a.csv") panel(blk) counts(a) ///
        totalrow(lab == "Total") smallcells(5)
    assert _rc == 459
    capture confirm file "`w'/_md_f4a.csv"
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS: F4 puttab lone overall total over a masked panel total is r(459)"
    local ++pass_count
}
else {
    display as error "  FAIL: F4 puttab lone overall total (rc=`=_rc')"
    local ++fail_count
}

**## overall row over panels without total rows, a cell masked: r(459)
local ++test_count
capture noisily {
    clear
    input str8 blk str8 lab a
    "A" "a1" 2
    "A" "a2" 10
    "B" "b1" 10
    "All" "Total" 22
    end
    capture noisily puttab lab a, csv("`w'/_md_f4b.csv") panel(blk) counts(a) ///
        totalrow(lab == "Total") smallcells(5)
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: F4 puttab lone overall total over untotalled panels is r(459)"
    local ++pass_count
}
else {
    display as error "  FAIL: F4 puttab lone overall total over untotalled panels (rc=`=_rc')"
    local ++fail_count
}

**## control: panel totals printed, the overall row adds nothing: prints
local ++test_count
capture noisily {
    local ge = uchar(8805)
    clear
    input str8 blk str8 lab a
    "A" "a1" 2
    "A" "a2" 10
    "A" "Total" 12
    "B" "b1" 10
    "B" "b2" 10
    "B" "Total" 20
    "All" "Total" 32
    end
    capture erase "`w'/_md_f4c.csv"
    puttab lab a, csv("`w'/_md_f4c.csv") panel(blk) counts(a) ///
        totalrow(lab == "Total") smallcells(5)
    _md_is "`w'/_md_f4c.csv" "a1" "a1,<5"
    _md_is "`w'/_md_f4c.csv" "a2" "a2,`ge'5"
    _md_line "`w'/_md_f4c.csv" "Total"
    assert r(n) == 3
    assert r(line) == "Total,32"
}
if _rc == 0 {
    display as result "  PASS: F4 control: overall total over printed panel totals runs"
    local ++pass_count
}
else {
    display as error "  FAIL: F4 control (rc=`=_rc')"
    local ++fail_count
}

quietly tabtools set clear
display as result "m_disclosure QA summary: `pass_count' passed, `fail_count' failed"
local _tc = `pass_count' + `fail_count'
display "RESULT: test_cycle_20261119_m_disclosure tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _mdisc
if `fail_count' > 0 exit 1
