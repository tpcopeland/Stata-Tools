* test_cycle_20261120_sentinels.do - typed -1 values, xlsx()+excel(), and
* short models() headers (1.2.0 audit follow-up, 2026-11-20)
*
* Contracts:
*   S1  a typed -1 is a value, never "option not given": digits(-1),
*       boldp(-1), highlight(-1) (and in regtab/effecttab pdp(-1),
*       highpdp(-1), level(-1), regtab mincount(-1)) are r(198) in crosstab,
*       desctab, table1_tc, regtab, effecttab, puttab (both forms) and
*       stacktab frames(). These options were declared with -1 defaults, so
*       the typed value was read as absent at rc 0.
*   S2  the same options still accept valid values and still default when
*       omitted (session digits default applies; non-integer digits refused;
*       an integer typed as 2.0 or 1e0 is accepted, as the integer type did).
*   S3  xlsx() and excel() naming two different workbooks is r(198) in
*       desctab, table1_tc, outtab, survtab and effecttab, and neither file
*       is written; the same workbook in both is accepted.
*   S5  comptab refuses highlight(-1)/boldp(-1); comptab and stratetab refuse
*       xlsx() and excel() naming two workbooks.
*   S4  effecttab with fewer models() names than models labels the rest
*       "Model #" (regtab's rule), not blank.
*
* Oracles: the return codes, file existence, and the flat frame's variable
* labels (independent of the console renderer).

clear all
set more off
set varabbrev off
set linesize 255
version 17.0

capture log close _cys
log using "test_cycle_20261120_sentinels.log", replace text name(_cys)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear

local test_count = 0
local pass_count = 0
local fail_count = 0

* _cys_rc <expected rc> <command>: run quietly; fail (exit 9) on another rc
capture program drop _cys_rc
program define _cys_rc
    version 17.0
    gettoken want 0 : 0
    capture `0'
    local got = _rc
    if `got' != `want' {
        display as error `"  rc `got' (want `want'): `0'"'
        exit 9
    }
end

capture program drop _cys_te
program define _cys_te
    version 17.0
    clear
    set seed 123
    set obs 600
    gen age = rnormal(50, 10)
    gen treat = runiform() < invlogit((age - 50) / 10)
    gen y = 0.12 * treat + 0.05 * age + rnormal()
    collect clear
    quietly collect: teffects ipw (y) (treat age, logit), ate
end

**# S1 typed -1 is refused

**## crosstab, desctab, table1_tc
local ++test_count
capture noisily {
    sysuse auto, clear
    foreach o in "digits(-1)" "boldp(-1)" {
        _cys_rc 198 crosstab rep78 foreign, `o'
    }
    foreach o in "boldp(-1)" "highlight(-1)" {
        _cys_rc 198 desctab mpg, by(foreign) test `o'
        _cys_rc 198 table1_tc, by(foreign) vars(mpg contn) `o'
    }
}
if _rc == 0 {
    display as result "  PASS: S1a crosstab/desctab/table1_tc refuse a typed -1"
    local ++pass_count
}
else {
    display as error "  FAIL: S1a crosstab/desctab/table1_tc refuse a typed -1 (rc=`=_rc')"
    local ++fail_count
}

**## regtab
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    foreach o in "digits(-1)" "boldp(-1)" "highlight(-1)" "pdp(-1)" ///
        "highpdp(-1)" "level(-1)" "mincount(-1)" {
        _cys_rc 198 regtab, `o'
    }
}
if _rc == 0 {
    display as result "  PASS: S1b regtab refuses a typed -1"
    local ++pass_count
}
else {
    display as error "  FAIL: S1b regtab refuses a typed -1 (rc=`=_rc')"
    local ++fail_count
}

**## effecttab
local ++test_count
capture noisily {
    _cys_te
    foreach o in "digits(-1)" "boldp(-1)" "highlight(-1)" "pdp(-1)" ///
        "highpdp(-1)" "level(-1)" {
        _cys_rc 198 effecttab, effect(ATE) `o'
    }
    matrix E = (1, .5, 1.5, .04)
    _cys_rc 198 effecttab, from(E) digits(-1)
}
if _rc == 0 {
    display as result "  PASS: S1c effecttab refuses a typed -1"
    local ++pass_count
}
else {
    display as error "  FAIL: S1c effecttab refuses a typed -1 (rc=`=_rc')"
    local ++fail_count
}

**## puttab (data and matrix forms), stacktab frames()
local ++test_count
capture noisily {
    clear
    input str8 lab double v
    "a" 1.25
    "b" 2.5
    end
    local csv "`output_dir'/cys_put.csv"
    capture erase "`csv'"
    _cys_rc 198 puttab lab v, csv("`csv'") digits(-1)
    confirm new file "`csv'"
    matrix M = (1.25, 2.5 \ 3, 4)
    _cys_rc 198 puttab, matrix(M) csv("`csv'") digits(-1)
    confirm new file "`csv'"
    sysuse auto, clear
    table1_tc, by(foreign) vars(mpg contn) frame(cys_a, replace)
    local book "`output_dir'/cys_stack.xlsx"
    capture erase "`book'"
    _cys_rc 198 stacktab using "`book'", frames(cys_a "All") sheet("T") digits(-1)
    confirm new file "`book'"
    capture frame drop cys_a
}
if _rc == 0 {
    display as result "  PASS: S1d puttab and stacktab frames() refuse digits(-1)"
    local ++pass_count
}
else {
    display as error "  FAIL: S1d puttab and stacktab frames() refuse digits(-1) (rc=`=_rc')"
    local ++fail_count
}

**# S2 valid values and defaults still work
local ++test_count
capture noisily {
    sysuse auto, clear
    _cys_rc 0 crosstab rep78 foreign, digits(0) boldp(0.05)
    _cys_rc 198 crosstab rep78 foreign, digits(1.5)
    _cys_rc 198 crosstab rep78 foreign, digits(abc)
    _cys_rc 0 desctab mpg, by(foreign) test boldp(.05) highlight(.05)
    _cys_rc 198 desctab mpg, by(foreign) test boldp(0)
    collect clear
    quietly collect: regress price mpg weight
    * level(95) matches the collection (another level is refused by design)
    _cys_rc 0 regtab, digits(3) pdp(2) highpdp(3) level(95) boldp(.05) highlight(.05)
    * omitted digits takes the session default
    quietly tabtools set digits 4
    clear
    input str8 lab double v
    "a" 1.25
    end
    local csv "`output_dir'/cys_put2.csv"
    capture erase "`csv'"
    quietly puttab lab v, csv("`csv'")
    quietly tabtools set clear
    mata: st_local("hit", strofreal(sum(strpos(cat(st_local("csv")), "1.2500") :> 0)))
    assert `hit' == 1
    capture erase "`csv'"
    _cys_te
    _cys_rc 0 effecttab, effect(ATE) digits(3) pdp(2) highpdp(3) boldp(.05)
    * an integer typed with a decimal point is still an integer (the
    * integer syntax type accepted it); -1.0 is still the typed value -1
    _cys_rc 0 effecttab, effect(ATE) digits(2.0) highpdp(1e0)
    _cys_rc 198 effecttab, effect(ATE) digits(-1.0)
    _cys_rc 198 effecttab, effect(ATE) digits(2.5)
    sysuse auto, clear
    _cys_rc 0 crosstab rep78 foreign, digits(5.0)
    collect clear
    quietly collect: regress price mpg weight
    _cys_rc 0 regtab, digits(2.0) pdp(3.)
    _cys_rc 198 regtab, digits(2.5)
    table1_tc, by(foreign) vars(mpg contn) frame(cys_a2, replace)
    local book "`output_dir'/cys_stack2.xlsx"
    capture erase "`book'"
    _cys_rc 0 stacktab using "`book'", frames(cys_a2 "All") sheet("T") digits(3)
    _cys_rc 0 stacktab using "`book'", frames(cys_a2 "All") sheet("U") digits(2.0)
    capture erase "`book'"
    capture frame drop cys_a2
    clear
    input str8 lab double v
    "a" 1.25
    end
    local csv "`output_dir'/cys_put3.csv"
    capture erase "`csv'"
    quietly puttab lab v, csv("`csv'") digits(3.0)
    mata: st_local("hit", strofreal(sum(strpos(cat(st_local("csv")), "1.250") :> 0)))
    assert `hit' == 1
    capture erase "`csv'"
}
if _rc == 0 {
    display as result "  PASS: S2 valid values and the session default still apply"
    local ++pass_count
}
else {
    local _rc_s2 = _rc
    quietly tabtools set clear
    display as error "  FAIL: S2 valid values and the session default still apply (rc=`_rc_s2')"
    local ++fail_count
}

**# S3 xlsx() and excel() naming two workbooks
local ++test_count
capture noisily {
    local a "`output_dir'/cys_a.xlsx"
    local b "`output_dir'/cys_b.xlsx"
    capture erase "`a'"
    capture erase "`b'"
    sysuse auto, clear
    _cys_rc 198 desctab mpg, by(foreign) xlsx("`a'") excel("`b'") sheet(S)
    _cys_rc 198 table1_tc, by(foreign) vars(mpg contn) xlsx("`a'") excel("`b'") sheet(S)
    gen byte y = rep78 > 3 if !missing(rep78)
    _cys_rc 198 outtab y, exposure(foreign) xlsx("`a'") excel("`b'") sheet(S)
    clear
    set obs 60
    gen t = _n
    gen e = mod(_n, 3) == 0
    stset t, failure(e)
    _cys_rc 198 survtab, times(10 20) xlsx("`a'") excel("`b'") sheet(S)
    _cys_te
    _cys_rc 198 effecttab, effect(ATE) xlsx("`a'") excel("`b'") sheet(S)
    confirm new file "`a'"
    confirm new file "`b'"
    * one workbook named twice is one destination
    _cys_rc 0 effecttab, effect(ATE) xlsx("`a'") excel("`a'") sheet(S)
    confirm file "`a'"
    capture erase "`a'"
}
if _rc == 0 {
    display as result "  PASS: S3 xlsx() and excel() naming two workbooks is r(198)"
    local ++pass_count
}
else {
    display as error "  FAIL: S3 xlsx() and excel() naming two workbooks is r(198) (rc=`=_rc')"
    local ++fail_count
}

**# S5 comptab and stratetab: typed -1 and two workbooks
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price foreign mpg weight
    quietly regtab, frame(cys_c1, replace) noint
    collect clear
    quietly collect: regress price foreign mpg weight length
    quietly regtab, frame(cys_c2, replace) noint
    _cys_rc 0 comptab cys_c1 cys_c2, rows(1 \ 1) highlight(.05) boldp(.05)
    foreach o in "highlight(-1)" "boldp(-1)" {
        _cys_rc 198 comptab cys_c1 cys_c2, rows(1 \ 1) `o'
    }
    local a "`output_dir'/cys_ca.xlsx"
    local b "`output_dir'/cys_cb.xlsx"
    capture erase "`a'"
    capture erase "`b'"
    _cys_rc 198 comptab cys_c1 cys_c2, rows(1 \ 1) xlsx("`a'") excel("`b'")
    local w "`output_dir'"
    clear
    quietly set obs 2
    gen str80 cat = cond(_n == 1, "A", "B")
    gen double _D = cond(_n == 1, 5, 9)
    gen double _Y = cond(_n == 1, 100, 200)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.8
    gen double _Upper = _Rate * 1.3
    quietly save "`w'/_cys_st", replace
    _cys_rc 198 stratetab, using("`w'/_cys_st") outcomes(1) xlsx("`a'") excel("`b'")
    confirm new file "`a'"
    confirm new file "`b'"
    capture erase "`w'/_cys_st.dta"
    capture frame drop cys_c1
    capture frame drop cys_c2
}
if _rc == 0 {
    display as result "  PASS: S5 comptab and stratetab refuse -1 and two workbooks"
    local ++pass_count
}
else {
    display as error "  FAIL: S5 comptab and stratetab refuse -1 and two workbooks (rc=`=_rc')"
    local ++fail_count
}

**# S4 effecttab short models() labels the rest "Model #"
local ++test_count
capture noisily {
    _cys_te
    quietly collect: teffects ra (y age) (treat), ate
    effecttab, models("IPW") effect(ATE) frame(cys_m, replace, flat)
    frame cys_m {
        local l1 : variable label c1
        local l4 : variable label c4
    }
    assert `"`l1'"' == "IPW, ATE"
    assert `"`l4'"' == "Model 2, ATE"
    * no usable name at all: every model takes Model #
    effecttab, models("\ ") effect(ATE) frame(cys_m, replace, flat)
    frame cys_m {
        local l1 : variable label c1
        local l4 : variable label c4
    }
    assert `"`l1'"' == "Model 1, ATE"
    assert `"`l4'"' == "Model 2, ATE"
    capture frame drop cys_m
}
if _rc == 0 {
    display as result "  PASS: S4 effecttab short models() labels the rest Model #"
    local ++pass_count
}
else {
    display as error "  FAIL: S4 effecttab short models() labels the rest Model # (rc=`=_rc')"
    local ++fail_count
}

local _tc = `pass_count' + `fail_count'
display "RESULT: test_cycle_20261120_sentinels tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _cys
if `fail_count' > 0 exit 1
