* test_clarity_final_2026_10_12.do - regressions for the final 2026-10-12
* clarity pass (tabtools 2.6.4)
*
* F1  desctab, missingsummary: the Missing row follows the level rows' cell
*     format (default n (%), percent_n % (n), percent %, slashN n/N (%),
*     percsign(), weighted percent-only and wtcompare columns) (I1)
* F2  effecttab r(methods) names the collected teffects estimand: ate, atet,
*     pomeans (also abbreviated), never the active e(); a collection
*     without e(stat) names none (I2)
* F3  regtab, addrow() with more values than models is refused (r(198))
*     and names the row; as many values as models still runs (I3)
* F4  ratetab notes a defaulted person-years label; no note with
*     pyscale(), ptunit(), stset scale(365.25), or the date-unit note (M1)
* F5  stratetab/ratetab note nonzero rates or limits that round to 0, with
*     the count of such numbers; none at enough decimals (M2)
* F6  regtab, addcol() error names its column label (M4)
* F7  stacktab sheet-exists error shows the sheet name without compound
*     quotes (M5)
* F8  effecttab, from(): an estimate outside its interval runs (rc 0) and
*     the row is named in a note; inside, no note (M7)
*
* Oracles: counts and percentages from count/tabulate, teffects' own
* e(stat), exact Poisson limits from invpoissontail()/invpoisson() over
* collapse sums, and the literal message texts. Run from tabtools/qa.

clear all
version 17.0
set more off
set varabbrev off
set linesize 255

capture log close _cf
log using "test_clarity_final_2026_10_12.log", replace text name(_cf)

local test_count = 0
local pass_count = 0
local failed ""

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

tempfile scratch
global CF_DIR "`scratch'_d"
capture mkdir "$CF_DIR"

capture program drop _cf_result
program define _cf_result, rclass
    args rc label
    if `rc' == 0 display as result "  PASS: `label'"
    else display as error "  FAIL: `label' (rc=`rc')"
    return scalar pass = (`rc' == 0)
end

* _cf_count FILE NEEDLE: r(n) = lines of FILE containing NEEDLE
capture program drop _cf_count
program define _cf_count, rclass
    version 17.0
    args file needle
    mata: st_numscalar("_cf_n", sum(strpos(cat(st_local("file")), st_local("needle")) :> 0))
    return scalar n = scalar(_cf_n)
    scalar drop _cf_n
end

* _cf_miss FRAME COLUMN: r(cell) = that column's Missing-row cell
capture program drop _cf_miss
program define _cf_miss, rclass
    version 17.0
    args fr col
    frame `fr' {
        quietly count if strtrim(factor) == "Missing"
        if r(N) != 1 exit 498
        quietly levelsof `col' if strtrim(factor) == "Missing", local(c) clean
    }
    return local cell `"`c'"'
end

capture program drop _cf_auto
program define _cf_auto
    version 17.0
    sysuse auto, clear
    quietly replace rep78 = . in 1/10
    gen w = 1 + mod(_n, 3)
end

**# F1: Missing row follows the level rows' format
local ++test_count
capture noisily {
    _cf_auto
    * oracle: 12 of the 52 domestic and 1 of the 22 foreign cars are missing
    quietly count if foreign == 0 & missing(rep78)
    local m0 = r(N)
    quietly count if foreign == 0
    local n0 = r(N)
    quietly count if foreign == 1 & missing(rep78)
    local m1 = r(N)
    quietly count if foreign == 1
    local n1 = r(N)
    local p0 = string(round(100 * `m0' / `n0', 1), "%5.0f")
    local p1 = string(round(100 * `m1' / `n1', 1), "%5.0f")
    assert `m0' == 12 & `n0' == 52 & "`p0'" == "23"

    desctab, vars(rep78 cat) by(foreign) missingsummary frame(f1, replace)
    _cf_miss f1 foreign_0
    assert `"`r(cell)'"' == "`m0' (`p0')"

    _cf_auto
    desctab, vars(rep78 cat) by(foreign) missingsummary percent_n frame(f1, replace)
    _cf_miss f1 foreign_0
    assert `"`r(cell)'"' == "`p0' (`m0')"
    _cf_miss f1 foreign_1
    assert `"`r(cell)'"' == "`p1' (`m1')"
    * the level rows of the same table are % (n) too
    frame f1: quietly count if strtrim(factor) == "3" & foreign_0 == "50 (20)"
    assert r(N) == 1

    _cf_auto
    desctab, vars(rep78 cat) by(foreign) missingsummary percent frame(f1, replace)
    _cf_miss f1 foreign_0
    assert `"`r(cell)'"' == "`p0'"

    _cf_auto
    desctab, vars(rep78 cat) by(foreign) missingsummary slashN frame(f1, replace)
    _cf_miss f1 foreign_0
    assert `"`r(cell)'"' == "`m0'/`n0' (`p0')"

    _cf_auto
    desctab, vars(rep78 cat) by(foreign) missingsummary percent_n slashN frame(f1, replace)
    _cf_miss f1 foreign_0
    assert `"`r(cell)'"' == "`p0' (`m0'/`n0')"

    _cf_auto
    desctab, vars(rep78 cat) by(foreign) missingsummary percent_n percsign(%) frame(f1, replace)
    _cf_miss f1 foreign_0
    assert `"`r(cell)'"' == "`p0'% (`m0')"

    * weighted: percent-only by default, so the Missing row prints no count
    _cf_auto
    desctab, vars(rep78 cat) by(foreign) missingsummary wt(w) frame(f1, replace)
    _cf_miss f1 foreign_0
    assert `"`r(cell)'"' == "`p0'"
}
_cf_result `=_rc' "F1 Missing row: default, percent_n, percent, slashN, percsign, weighted"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' F1"

**# F2: effecttab names the collected teffects estimand
local ++test_count
capture noisily {
    webuse cattaneo2, clear
    quietly keep in 1/1500
    foreach spec in "|ate|Average treatment effects estimated" ///
        ", atet|atet|Average treatment effects on the treated estimated" ///
        ", pomeans|pomeans|Potential-outcome means estimated" ///
        ", pom|pomeans|Potential-outcome means estimated" {
        gettoken opt rest : spec, parse("|")
        if "`opt'" == "|" local opt ""
        else gettoken bar rest : rest, parse("|")
        gettoken stat rest : rest, parse("|")
        gettoken bar want : rest, parse("|")
        collect clear
        quietly collect: teffects ipw (bweight) (mbsmoke mage) `opt'
        assert "`e(stat)'" == "`stat'"
        quietly effecttab, clean
        assert strpos(`"`r(methods)'"', "`want' using inverse probability weighting") == 1
    }
    * the collected fit, not the active e(): ATET collected, ATE active
    collect clear
    quietly collect: teffects ipw (bweight) (mbsmoke mage), atet
    quietly teffects ipw (bweight) (mbsmoke mage)
    assert "`e(stat)'" == "ate"
    quietly effecttab, clean
    assert strpos(`"`r(methods)'"', "Average treatment effects on the treated") == 1
    * nnmatch, ATET
    collect clear
    quietly collect: teffects nnmatch (bweight mage) (mbsmoke), atet
    quietly effecttab, clean
    assert strpos(`"`r(methods)'"', "Average treatment effects on the treated estimated using nearest-neighbor matching") == 1
}
_cf_result `=_rc' "F2 effecttab r(methods) names ate/atet/pomeans from the collected e(stat)"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' F2"

**# F2b: a collection without e(stat) names no estimand
capture program drop _cf_nostat
program define _cf_nostat, eclass
    version 17.0
    ereturn local stat ""
end
local ++test_count
capture noisily {
    webuse cattaneo2, clear
    quietly keep in 1/1500
    collect clear
    quietly teffects ipw (bweight) (mbsmoke mage), atet
    _cf_nostat
    assert "`e(stat)'" == ""
    quietly collect get e()
    collect label levels result cmd "Command" cmdline "Command line as typed", modify
    quietly effecttab, clean
    assert strpos(`"`r(methods)'"', "Treatment effects estimated using") == 1
    assert strpos(`"`r(methods)'"', "Average") == 0
}
_cf_result `=_rc' "F2b no collected e(stat): 'Treatment effects', no estimand guessed"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' F2b"

**# F3: regtab, addrow() refuses more values than models
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    quietly collect: regress price mpg weight
    local lf "$CF_DIR/f3.log"
    capture log close _f3
    log using "`lf'", replace text name(_f3)
    capture noisily regtab, frame(f3, replace) addrow("X" 1 2 3) keep(mpg)
    local rc = _rc
    log close _f3
    assert `rc' == 198
    _cf_count "`lf'" `"addrow(): "X" has more values than the 2 models"'
    assert r(n) == 1
    * as many values as models: both placed
    quietly regtab, frame(f3, replace) addrow("X" 1 2) keep(mpg)
    frame f3 {
        quietly count if strtrim(A) == "X" & c1 == "1"
        assert r(N) == 1
        quietly count if strtrim(A) == "X" & c4 == "2"
        assert r(N) == 1
    }
}
_cf_result `=_rc' "F3 addrow() with 3 values for 2 models is refused (198) and named"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' F3"

**# F4: ratetab default person-years note
local ++test_count
capture noisily {
    local note "labelled in person-years by default"
    local lf "$CF_DIR/f4.log"
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    foreach o in "" "pyscale(12)" "ptunit(months)" {
        capture log close _f4
        log using "`lf'", replace text name(_f4)
        ratetab drug, `o'
        log close _f4
        _cf_count "`lf'" "`note'"
        if "`o'" == "" assert r(n) == 1
        else assert r(n) == 0
    }
    * stset scale(365.25): the unit is years, no note
    sysuse cancer, clear
    gen days = studytime * 30.4375
    quietly stset days, failure(died) scale(365.25)
    capture log close _f4
    log using "`lf'", replace text name(_f4)
    ratetab drug
    log close _f4
    _cf_count "`lf'" "`note'"
    assert r(n) == 0
    * events()/exposure(): the unit is not inferred either
    sysuse cancer, clear
    capture log close _f4
    log using "`lf'", replace text name(_f4)
    ratetab drug, events(died) exposure(studytime)
    log close _f4
    _cf_count "`lf'" "`note'"
    assert r(n) == 1
    * a date-formatted time variable: only the person-days note
    webuse diet, clear
    quietly stset dox, failure(fail) origin(time doe) id(id)
    capture log close _f4
    log using "`lf'", replace text name(_f4)
    ratetab hienergy
    log close _f4
    _cf_count "`lf'" "`note'"
    assert r(n) == 0
    _cf_count "`lf'" "labelled in person-days"
    assert r(n) == 1
}
_cf_result `=_rc' "F4 ratetab notes a defaulted person-years label only when nothing names the unit"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' F4"

**# F5: nonzero rates or limits that round to 0 are noted
local ++test_count
capture noisily {
    webuse diet, clear
    quietly stset dox, failure(fail) origin(time doe) id(id)
    * oracle: exact Poisson rate and limits per 1,000 person-days, counted
    * when positive but 0 at 1 decimal
    preserve
    gen double pt = _t - _t0
    collapse (sum) D = _d Y = pt, by(hienergy)
    local want 0
    forvalues i = 1/`=_N' {
        local d = D[`i']
        local y = Y[`i']
        foreach v in `=1000 * `d' / `y'' `=1000 * invpoissontail(`d', .025) / `y'' `=1000 * invpoisson(`d', .025) / `y'' {
            if `v' > 0 & round(`v', 0.1) == 0 local ++want
        }
    }
    restore
    assert `want' > 0
    local lf "$CF_DIR/f5.log"
    capture log close _f5
    log using "`lf'", replace text name(_f5)
    ratetab hienergy
    log close _f5
    _cf_count "`lf'" "Note: `want' nonzero rate(s) or confidence limit(s) round to 0"
    assert r(n) == 1
    capture log close _f5
    log using "`lf'", replace text name(_f5)
    ratetab hienergy, digits(3)
    log close _f5
    _cf_count "`lf'" "round to 0 at the decimals shown"
    assert r(n) == 0
    * years: rates far from 0, no note
    quietly stset dox, failure(fail) origin(time doe) id(id) scale(365.25)
    capture log close _f5
    log using "`lf'", replace text name(_f5)
    ratetab hienergy
    log close _f5
    _cf_count "`lf'" "round to 0 at the decimals shown"
    assert r(n) == 0
}
_cf_result `=_rc' "F5 rates/limits rounding to 0 are counted in a note"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' F5"

**# F6: addcol() error names the column label
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    quietly collect: regress price mpg weight
    local lf "$CF_DIR/f6.log"
    capture log close _f6
    log using "`lf'", replace text name(_f6)
    capture noisily regtab, transpose addcol("Extra" a b c) keep(mpg)
    local rc = _rc
    log close _f6
    assert `rc' == 198
    _cf_count "`lf'" `"addcol(): "Extra" has more values than the 2 models"'
    assert r(n) == 1
}
_cf_result `=_rc' "F6 addcol() over-long error names its label"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' F6"

**# F7: stacktab sheet-exists error without compound quotes
local ++test_count
capture noisily {
    local wb "$CF_DIR/f7.xlsx"
    sysuse auto, clear
    keep make price mpg
    keep in 1/5
    export excel "`wb'", sheet("Src") sheetreplace firstrow(variables)
    export excel "`wb'", sheet("Out3") sheetreplace firstrow(variables)
    local lf "$CF_DIR/f7.log"
    capture log close _f7
    log using "`lf'", replace text name(_f7)
    capture noisily stacktab using "`wb'", blocks(sheet(Src) rows(2/3) cols(A-C)) sheet("Out3")
    local rc = _rc
    log close _f7
    assert `rc' == 602
    _cf_count "`lf'" `"stacktab: sheet "Out3" already exists"'
    assert r(n) == 1
    _cf_count "`lf'" `"`"Out3"'"'
    assert r(n) == 0
}
_cf_result `=_rc' "F7 stacktab sheet-exists error shows the plain sheet name"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' F7"

**# F8: effecttab from(): an estimate outside its interval is named, not refused
local ++test_count
capture noisily {
    local lf "$CF_DIR/f8.log"
    matrix R = (-0.5, 0.2, 0.8, 0.03 \ 0.5, 0.2, 0.8, 0.03)
    matrix rownames R = outside inside
    capture log close _f8
    log using "`lf'", replace text name(_f8)
    effecttab, from(R)
    local rc = _rc
    log close _f8
    assert `rc' == 0
    _cf_count "`lf'" "Note: from() row 1 (outside): estimate -.5 lies outside its interval [.2, .8]"
    assert r(n) == 1
    _cf_count "`lf'" "from() row 2 (inside)"
    assert r(n) == 0
}
_cf_result `=_rc' "F8 effecttab from(): estimate outside its interval is noted (rc 0)"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' F8"

**# Summary
foreach f in f1 f3 {
    capture frame drop `f'
}
capture matrix drop R
capture shell rm -rf "$CF_DIR"
capture macro drop CF_DIR
collect clear
local fail_count = `test_count' - `pass_count'
if `fail_count' display as error "failed:`failed'"
display as text "RESULT: test_clarity_final_2026_10_12 tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _cf
if `fail_count' > 0 exit 1
exit 0
