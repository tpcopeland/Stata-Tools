* test_review_2026_09_29.do - reviewer findings of 2026-09-29 (tabtools 2.1.15)
* Regression suite, written against 2.1.15 (d7e252c1) before any fix. Each
* block failed on 2.1.15:
*   R1  loading any tabtools file with Mata code set matastrict on for the
*       session; a caller's undeclared Mata function then failed r(3000)
*   R2  crosstab, cochran: a decreasing trend gave chi2_trend = -z^2 and
*       p for trend 1 (the macro expanded to "-0.6^2", and ^ binds tighter
*       than unary minus)
*   R3  crosstab, trend missing tested fewer rows than the table displayed
*       (Muse I1); it is now refused like cochran missing
*   R4  crosstab or/rr/rd and cochran matched rows by levelsof text, so a
*       fractional float level (0.1 -> .1000000014901161) matched nothing:
*       a defined OR/RR/RD or trend was refused as undefined
*   R5  survtab by() with a fractional float variable stopped r(2000)
*       (every group selection matched nothing)
*   R6  desctab/table1_tc categorical SMD was blank at rc 0 for a fractional
*       float variable (its level shares were counted as 0)
*   R7  sheet() names were re-expanded as macro text in every command: a
*       $global expanded and a `name' pair vanished (rc 0, wrong sheet), an
*       unbalanced backtick exited r(132)
* Oracles: R's prop.trend.test value (R2), tabulate's Pearson chi2, cc/cs on
* a 0/1 recode, the same command on an integer-coded twin, and sheet names
* read back by import excel, describe (not the xl() writer under test).

clear all
set more off
set varabbrev off
version 17.0

capture log close _r929
log using "test_review_2026_09_29.log", replace text name(_r929)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
local od "`output_dir'/r929"
capture mkdir "`od'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

**# R1 matastrict is never changed by loading a tabtools file
**## R1a every shipped .ado, run directly, leaves matastrict as found
capture noisily {
    local ados : dir "`pkg_dir'" files "*.ado"
    local bad ""
    local n 0
    foreach f of local ados {
        foreach st in off on {
            * a file without cap program drop cannot be run twice
            program drop _all
            mata: mata set matastrict `st'
            quietly run "`pkg_dir'/`f'"
            if c(matastrict) != "`st'" local bad "`bad' `f'(`st')"
        }
        local ++n
    }
    mata: mata set matastrict off
    display as text "R1a files run: `n'; changed matastrict: [`bad']"
    assert `n' >= 30
    assert "`bad'" == ""
}
if _rc == 0 {
    display as result "  PASS: R1a matastrict preserved by every .ado load"
    local ++pass_count
}
else {
    display as error "  FAIL: R1a matastrict preserved by every .ado load (rc=`=_rc')"
    local ++fail_count
}

**## R1b autoloaded commands leave matastrict off; undeclared Mata compiles
capture noisily {
    discard
    mata: mata set matastrict off
    sysuse auto, clear
    quietly crosstab foreign rep78
    quietly corrtab price mpg weight
    quietly puttab make price in 1/3 using "`od'/r1.xlsx", sheet("A")
    quietly stacktab using "`od'/r1.xlsx", sheet("B") blocks(sheet(A)) sheetreplace
    quietly table1_tc, by(foreign) vars(price contn \ rep78 cat) excel("`od'/r1t.xlsx")
    assert c(matastrict) == "off"
    capture mata: mata drop _r929_undeclared()
    mata:
    function _r929_undeclared(x)
    {
        y = x * 2
        return(y)
    }
    end
    mata: st_numscalar("r929_u", _r929_undeclared(21))
    assert scalar(r929_u) == 42
    mata: mata drop _r929_undeclared()
    scalar drop r929_u
}
if _rc == 0 {
    display as result "  PASS: R1b autoload keeps matastrict off"
    local ++pass_count
}
else {
    display as error "  FAIL: R1b autoload keeps matastrict off (rc=`=_rc')"
    local ++fail_count
}

* 1 when the workbook `f' holds a worksheet whose name is byte-identical to
* the local `want' of the caller, read by import excel, describe.
capture program drop _r929_has_sheet
program define _r929_has_sheet, rclass
    version 17.0
    gettoken f 0 : 0
    gettoken want 0 : 0
    local ok 0
    preserve
    quietly import excel using `"`f'"', describe
    forvalues s = 1/`r(N_worksheet)' {
        mata: st_local("hit", strofreal(st_global("r(worksheet_`s')") == st_local("want")))
        if `hit' local ok 1
    }
    restore
    return scalar ok = `ok'
end

**# R2 Cochran-Armitage with a decreasing trend
**## R2a known answer: 30/40, 20/40, 10/40 at scores 1 2 3
* R 4.x: prop.trend.test(c(30,20,10), c(40,40,40)) gives X-squared = 20,
* p-value = 7.74421643104e-06; z is negative (the proportion falls).
capture noisily {
    clear
    input byte(y x) int w
    1 1 30
    0 1 10
    1 2 20
    0 2 20
    1 3 10
    0 3 30
    end
    crosstab y x [fw=w], cochran
    assert !missing(r(chi2_trend), r(p_trend), r(z_trend))
    assert reldif(r(chi2_trend), 20) < 1e-12
    assert reldif(r(z_trend), -sqrt(20)) < 1e-12
    assert reldif(r(p_trend), chi2tail(1, 20)) < 1e-10
    assert reldif(r(p_trend), 7.74421643104e-06) < 1e-9
    * mirror image: the increasing trend has the same chi2 and p
    local pdown = r(p_trend)
    replace y = 1 - y
    crosstab y x [fw=w], cochran
    assert reldif(r(chi2_trend), 20) < 1e-12
    assert reldif(r(p_trend), `pdown') < 1e-12
    assert reldif(r(z_trend), sqrt(20)) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: R2a Cochran-Armitage decreasing trend = prop.trend.test"
    local ++pass_count
}
else {
    display as error "  FAIL: R2a Cochran-Armitage decreasing trend = prop.trend.test (rc=`=_rc')"
    local ++fail_count
}

**## R2b 2x2: the trend chi2 equals Pearson's chi2 from tabulate
capture noisily {
    clear
    set seed 20260929
    set obs 300
    gen byte r = runiform() < 0.55
    gen byte c = runiform() < 0.5
    replace r = 0 if c == 1 & runiform() < 0.2
    quietly tabulate r c, chi2
    scalar r929_chi2 = r(chi2)
    scalar r929_p = r(p)
    crosstab r c, cochran
    assert !missing(r(chi2_trend), scalar(r929_chi2))
    assert r(z_trend) < 0
    assert reldif(r(chi2_trend), scalar(r929_chi2)) < 1e-10
    assert reldif(r(p_trend), scalar(r929_p)) < 1e-8
    scalar drop r929_chi2 r929_p
}
if _rc == 0 {
    display as result "  PASS: R2b 2x2 Cochran-Armitage = tabulate chi2"
    local ++pass_count
}
else {
    display as error "  FAIL: R2b 2x2 Cochran-Armitage = tabulate chi2 (rc=`=_rc')"
    local ++fail_count
}

**# R3 trend with missing is refused; without missing it runs
capture noisily {
    clear
    input byte(r c)
    1 1
    1 2
    2 1
    2 2
    2 .a
    1 1
    end
    capture crosstab r c, missing trend
    assert _rc == 198
    capture crosstab r c, missing cochran
    assert _rc == 198
    quietly spearman r c
    local pcc = r(p)
    crosstab r c, trend
    assert r(N) == 5
    assert reldif(r(p_trend), `pcc') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: R3 trend + missing refused"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 trend + missing refused (rc=`=_rc')"
    local ++fail_count
}

**# R4 crosstab association measures on fractional float levels
capture noisily {
    clear
    set seed 20260929
    set obs 240
    gen float r = cond(runiform() < 0.4, 0.1, 0.7)
    gen float c = cond(runiform() < 0.5, 0.3, 1.9)
    replace r = 0.1 if c > 1 & runiform() < 0.15
    gen byte r01 = r > 0.5
    gen byte c01 = c > 1
    quietly cc r01 c01
    local or = r(or)
    quietly cs r01 c01
    local rr = r(rr)
    local rd = r(rd)
    crosstab r c, or rr rd
    assert !missing(r(or), r(rr), r(rd))
    assert reldif(r(or), `or') < 1e-12
    assert reldif(r(rr), `rr') < 1e-12
    assert reldif(r(rd), `rd') < 1e-12
    * the integer twin gives the identical trend test
    crosstab r01 c01, cochran
    local ptw = r(p_trend)
    local ctw = r(chi2_trend)
    crosstab r c01, cochran
    assert reldif(r(p_trend), `ptw') < 1e-12
    assert reldif(r(chi2_trend), `ctw') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: R4 crosstab OR/RR/RD/cochran on fractional float levels"
    local ++pass_count
}
else {
    display as error "  FAIL: R4 crosstab OR/RR/RD/cochran on fractional float levels (rc=`=_rc')"
    local ++fail_count
}

**# R5 survtab by() on a fractional float variable = integer twin
capture noisily {
    webuse drugtr, clear
    gen float grp = cond(drug == 1, 0.1, 0.7)
    gen byte grpi = cond(drug == 1, 1, 7)
    survtab, times(10 20) by(grpi) median events riskset rmst(20)
    tempname Ti
    matrix `Ti' = r(table)
    local e1 = r(events_1)
    local e2 = r(events_2)
    local a1 = r(atrisk_1)
    local m1 = r(median_1)
    local m2 = r(median_2)
    local lr = r(logrank_chi2)
    survtab, times(10 20) by(grp) median events riskset rmst(20)
    assert mreldif(r(table), `Ti') < 1e-12
    assert r(events_1) == `e1' & r(events_2) == `e2' & r(atrisk_1) == `a1'
    assert r(median_1) == `m1' & r(median_2) == `m2'
    assert reldif(r(logrank_chi2), `lr') < 1e-12
    * group 1 is the drug == 1 arm: 12 failures among 28 subjects
    assert r(events_1) == 12 & r(atrisk_1) == 28
    mata: st_local("v1", st_global("r(group_1_value)"))
    assert "`v1'" == string(float(0.1), "%18.0g")
}
if _rc == 0 {
    display as result "  PASS: R5 survtab by(fractional float) = integer twin"
    local ++pass_count
}
else {
    display as error "  FAIL: R5 survtab by(fractional float) = integer twin (rc=`=_rc')"
    local ++fail_count
}

**# R6 categorical SMD for a fractional float variable = integer twin
capture noisily {
    clear
    set seed 20260929
    set obs 300
    gen byte g = runiform() < 0.5
    gen byte xi = cond(runiform() < 0.4, 1, cond(runiform() < 0.5, 2, 3))
    replace xi = 1 if g == 1 & runiform() < 0.15
    gen float y = cond(xi == 1, 0.1, cond(xi == 2, 2, 3))
    gen float z = cond(xi == 1, 0.1, cond(xi == 2, 0.7, 3))
    gen double w = 0.5 + runiform()
    foreach wopt in "" "wt(w)" {
        capture frame drop r929_t
        table1_tc, by(g) vars(xi cat \ y cat \ z cat) smd frame(r929_t) `wopt'
        frame r929_t {
            quietly levelsof smd_str if strtrim(factor) == "xi", local(sx) clean
            quietly levelsof smd_str if strtrim(factor) == "y", local(sy) clean
            quietly levelsof smd_str if strtrim(factor) == "z", local(sz) clean
        }
        display as text "SMD [`wopt'] xi=[`sx'] y=[`sy'] z=[`sz']"
        assert "`sx'" != ""
        assert "`sy'" == "`sx'"
        assert "`sz'" == "`sx'"
    }
    capture frame drop r929_t
}
if _rc == 0 {
    display as result "  PASS: R6 categorical SMD on fractional float levels"
    local ++pass_count
}
else {
    display as error "  FAIL: R6 categorical SMD on fractional float levels (rc=`=_rc')"
    local ++fail_count
}

**# R7 sheet() names reach the workbook and r(sheet) byte for byte
* Hostile names: a $global plus a `name' pair and a double quote, a bare
* $global, an unbalanced backtick, and an embedded double quote. The global
* is set so that a wrong expansion is visible.
global R929_G "EXPANDED"
mata: st_global("R929_S1", "V " + char(36) + "R929_G " + char(96) + "lit" + char(39) + " " + char(34) + "q")
mata: st_global("R929_S2", "P " + char(36) + "R929_G q")
mata: st_global("R929_S3", "U " + char(96) + "tick end")
mata: st_global("R929_S4", "A" + char(34) + "B")

* Build the inputs the commands need once.
capture noisily {
    capture program drop _r929_strate
    program define _r929_strate
        args base
        clear
        set obs 2
        gen exposure = _n - 1
        gen _D = cond(_n == 1, 10, 20)
        gen _Y = cond(_n == 1, 1000, 1100)
        gen _Rate = _D / _Y
        gen _Lower = _Rate * 0.8
        gen _Upper = _Rate * 1.2
        label variable _Lower "Lower 95% confidence limit"
        label variable _Upper "Upper 95% confidence limit"
        save "`base'.dta", replace
    end
    _r929_strate "`od'/rate1"
}

foreach cmd in corrtab crosstab table1_tc puttab stacktab regtab effecttab ///
    survtab stratetab comptab {
    capture noisily {
        local bad ""
        forvalues k = 1/4 {
            mata: st_local("s", st_global("R929_S`k'"))
            local x "`od'/sh_`cmd'_`k'.xlsx"
            capture erase "`x'"
            if "`cmd'" == "corrtab" {
                sysuse auto, clear
                quietly corrtab price mpg, xlsx("`x'") sheet(`"`macval(s)'"')
            }
            else if "`cmd'" == "crosstab" {
                sysuse auto, clear
                quietly crosstab foreign rep78, xlsx("`x'") sheet(`"`macval(s)'"')
            }
            else if "`cmd'" == "table1_tc" {
                sysuse auto, clear
                quietly table1_tc, by(foreign) vars(price contn) excel("`x'") sheet(`"`macval(s)'"')
            }
            else if "`cmd'" == "puttab" {
                sysuse auto, clear
                quietly puttab make price in 1/3 using "`x'", sheet(`"`macval(s)'"')
            }
            else if "`cmd'" == "stacktab" {
                sysuse auto, clear
                quietly puttab make price in 1/3 using "`x'", sheet("Src")
                quietly stacktab using "`x'", sheet(`"`macval(s)'"') blocks(sheet(Src))
                * the sheet now exists: append must find it by its exact name
                quietly stacktab using "`x'", sheet(`"`macval(s)'"') blocks(sheet(Src)) append
            }
            else if "`cmd'" == "regtab" {
                sysuse auto, clear
                collect clear
                quietly collect: regress price mpg
                quietly regtab, xlsx("`x'") sheet(`"`macval(s)'"')
            }
            else if "`cmd'" == "effecttab" {
                sysuse auto, clear
                quietly logit foreign mpg
                collect clear
                quietly collect: margins, dydx(mpg)
                quietly effecttab, xlsx("`x'") sheet(`"`macval(s)'"') type(margins)
            }
            else if "`cmd'" == "survtab" {
                webuse drugtr, clear
                quietly survtab, times(10) xlsx("`x'") sheet(`"`macval(s)'"')
            }
            else if "`cmd'" == "stratetab" {
                quietly stratetab, using("`od'/rate1") outcomes(1) xlsx("`x'") sheet(`"`macval(s)'"')
            }
            else if "`cmd'" == "comptab" {
                sysuse auto, clear
                collect clear
                quietly collect: regress price foreign mpg
                capture frame drop r929_f1
                quietly regtab, frame(r929_f1) noint
                quietly comptab r929_f1, rows(1) xlsx("`x'") sheet(`"`macval(s)'"')
                capture frame drop r929_f1
            }
            mata: st_local("rok", strofreal(st_global("r(sheet)") == st_local("s")))
            _r929_has_sheet "`x'" `"`macval(s)'"'
            if !`rok' | !r(ok) local bad "`bad' S`k'(r=`rok',wb=`r(ok)')"
        }
        display as text "`cmd' sheet() mismatches: [`bad']"
        assert "`bad'" == ""
    }
    if _rc == 0 {
        display as result "  PASS: R7 `cmd' sheet() written and returned exactly"
        local ++pass_count
    }
    else {
        display as error "  FAIL: R7 `cmd' sheet() written and returned exactly (rc=`=_rc')"
        local ++fail_count
    }
}

**# Summary
capture macro drop R929_G R929_S1 R929_S2 R929_S3 R929_S4
capture program drop _r929_strate
capture shell rm -rf "`od'"
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_review_2026_09_29 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _r929
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_review_2026_09_29 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _r929
