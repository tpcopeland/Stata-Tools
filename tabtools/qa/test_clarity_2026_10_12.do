* test_clarity_2026_10_12.do - regressions for the 2026-10-12 clarity audit
*
* C1  regtab, relabel: var(e.<dv>) after tobit and meglm reads
*     "Residual Variance (<dv>)"; no "Residual<dv>" glue; raw label kept
*     without relabel (I1)
* C2  ratetab on a date-formatted stset without scale(): headers, frame and
*     r(methods) say person-days; pyscale(365.25) gives person-years;
*     ptunit() names another unit; stratetab ptunit() and its default (I2)
* C3  desctab, missingsummary and comptab print no "real change" lines (M1)
* C4  survtab notes a defaulted years label unless stset scale() made the
*     time years; the date-format case prints only its own note (M2)
* C5  a failed xlsx export prints one hint that names a missing directory,
*     or the open-file/writable hint when the directory exists (M5)
* C6  adversarial cells (I5): fingerprint on error paths (ratetab, outtab),
*     surface parity (ratetab, outtab, tabcell), and lifecycle (ratetab,
*     outtab, tabcell, comptab) through the vendored qa-lib helpers; plus a
*     stale-file check of ratetab saving() and bit-identical ratetab reruns
*
* Oracles: collapse sums of _d and _t-_t0, poisson/logit e(b), the label
* strings themselves. No expected value is read back from the code under
* test. Run from tabtools/qa.

clear all
version 17.0
set more off
set varabbrev off
set linesize 255

capture log close _c12
log using "test_clarity_2026_10_12.log", replace text name(_c12)

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed ""

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear
do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_parity.do"
do "`qa_dir'/_qa_lifecycle.do"

tempfile scratch
global C12_DIR "`scratch'_d"
capture mkdir "$C12_DIR"

capture program drop _c12_result
program define _c12_result, rclass
    args rc label
    if `rc' == 0 display as result "  PASS: `label'"
    else display as error "  FAIL: `label' (rc=`rc')"
    return scalar pass = (`rc' == 0)
end

* _c12_log FILE NEEDLE: r(n) = lines of FILE containing NEEDLE
capture program drop _c12_log
program define _c12_log, rclass
    version 17.0
    args file needle
    mata: st_numscalar("_c12_n", sum(strpos(cat(st_local("file")), st_local("needle")) :> 0))
    return scalar n = scalar(_c12_n)
    scalar drop _c12_n
end

* _c12_dates: 200 subjects, entry and exit as %td dates, two groups
capture program drop _c12_dates
program define _c12_dates
    version 17.0
    clear
    set seed 20261012
    quietly set obs 200
    gen long id = _n
    gen entry = td(01jan2000) + floor(365 * runiform())
    gen exit = entry + 1 + floor(2000 * runiform())
    format entry exit %td
    gen byte fail = runiform() < 0.3
    gen byte g = mod(_n, 2)
    label define _c12_g 0 "Unexposed" 1 "Exposed", replace
    label values g _c12_g
    label variable g "Exposure group"
end

**# C1: regtab relabel of equation-qualified residual variance (I1)

**## C1a tobit: var(e.yc) -> "Residual Variance (yc)"
local ++test_count
capture noisily {
    sysuse auto, clear
    gen double yc = price - 5000
    collect clear
    quietly collect: tobit yc mpg weight, ll(0)
    regtab, frame(c12_t, replace) relabel
    frame c12_t {
        quietly count if A == "Residual Variance (yc)"
        assert r(N) == 1
        quietly count if strpos(A, "Residualyc") | strpos(A, "var(e.")
        assert r(N) == 0
    }
    * without relabel the raw Stata name is shown unchanged
    regtab, frame(c12_t, replace)
    frame c12_t: quietly count if A == "var(e.yc)"
    assert r(N) == 1
}
_c12_result `=_rc' "C1a tobit relabel: Residual Variance (yc); raw var(e.yc) without relabel"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' C1a"

**## C1b meglm gaussian: var(e.price) next to a random-intercept variance
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: meglm price mpg || rep78:, family(gaussian)
    regtab, frame(c12_t, replace) relabel
    frame c12_t {
        quietly count if A == "Residual Variance (price)"
        assert r(N) == 1
        quietly count if strpos(A, "Residualprice") | strpos(A, "var(e.")
        assert r(N) == 0
    }
}
_c12_result `=_rc' "C1b meglm relabel: Residual Variance (price)"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' C1b"

**# C2: ratetab names the person-time unit (I2)

**## C2a date-format stset, no scale(): person-days in headers and r(methods)
local ++test_count
capture noisily {
    _c12_dates
    quietly stset exit, failure(fail) origin(time entry) id(id)
    tempfile lg
    capture log close _c12l
    log using `"`lg'"', text replace name(_c12l)
    ratetab g, frame(c12_r, replace)
    local m `"`r(methods)'"'
    log close _c12l
    assert strpos(`"`m'"', "Incidence rates per 1,000 person-days with") == 1
    assert strpos(`"`m'"', "person-years") == 0
    frame c12_r {
        assert c3[3] == "Person-days"
        assert c4[3] == "Per 1,000 person-days (95% CI)"
    }
    _c12_log `"`lg'"' "pyscale(365.25) for person-years"
    assert r(n) == 1
    _c12_log `"`lg'"' "Person-Years (PY)"
    assert r(n) == 0
}
_c12_result `=_rc' "C2a ratetab day-scale data: person-days in header, frame and r(methods)"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' C2a"

**## C2b pyscale(365.25) converts to years and labels person-years
local ++test_count
capture noisily {
    _c12_dates
    quietly stset exit, failure(fail) origin(time entry) id(id)
    * oracle: events and person-years of group 0
    preserve
    gen double _py = (_t - _t0) / 365.25
    collapse (sum) _d _py, by(g)
    local want = _d[1] / _py[1] * 1000
    restore
    ratetab g, pyscale(365.25) frame(c12_r, replace)
    local m `"`r(methods)'"'
    matrix c12_E = r(estimates)
    assert strpos(`"`m'"', "Incidence rates per 1,000 person-years with") == 1
    assert !missing(el(c12_E, 1, 6), `want')
    assert reldif(el(c12_E, 1, 6), `want') < 1e-10
    frame c12_r {
        assert c3[3] == "Person-Years (PY)"
        assert c4[3] == "Per 1,000 PY (95% CI)"
    }
}
_c12_result `=_rc' "C2b ratetab pyscale(365.25): person-years and the oracle rate"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' C2b"

**## C2c ptunit() names a unit; no date note when ptunit() is given
local ++test_count
capture noisily {
    _c12_dates
    quietly stset exit, failure(fail) origin(time entry) id(id)
    tempfile lg
    capture log close _c12l
    log using `"`lg'"', text replace name(_c12l)
    ratetab g, ptunit(months) pyscale(30.4375) frame(c12_r, replace)
    local m `"`r(methods)'"'
    log close _c12l
    assert strpos(`"`m'"', "Incidence rates per 1,000 person-months with") == 1
    frame c12_r {
        assert c3[3] == "Person-months"
        assert c4[3] == "Per 1,000 person-months (95% CI)"
    }
    _c12_log `"`lg'"' "date format"
    assert r(n) == 0
    * stset scale() makes years: default header, no note
    quietly stset exit, failure(fail) origin(time entry) id(id) scale(365.25)
    ratetab g, frame(c12_r, replace)
    assert strpos(`"`r(methods)'"', "person-years") > 0
    frame c12_r: assert c3[3] == "Person-Years (PY)"
}
_c12_result `=_rc' "C2c ratetab ptunit(months); scale(365.25) keeps the PY header"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' C2c"

**## C2d stratetab ptunit(): header text; default unchanged
local ++test_count
capture noisily {
    clear
    quietly set obs 2
    gen exposure = _n - 1
    gen double _D = cond(_n == 1, 10, 20)
    gen double _Y = cond(_n == 1, 1000, 1100)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * .8
    gen double _Upper = _Rate * 1.2
    label variable _Lower "Lower 95% confidence limit"
    label variable _Upper "Upper 95% confidence limit"
    quietly save "$C12_DIR/st1.dta", replace
    stratetab, using("$C12_DIR/st1") outcomes(1) ptunit(weeks) frame(c12_s, replace)
    frame c12_s {
        assert c3[3] == "Person-weeks"
        assert c4[3] == "Per 1,000 person-weeks (95% CI)"
    }
    stratetab, using("$C12_DIR/st1") outcomes(1) frame(c12_s, replace)
    frame c12_s {
        assert c3[3] == "Person-Years (PY)"
        assert c4[3] == "Per 1,000 PY (95% CI)"
    }
}
_c12_result `=_rc' "C2d stratetab ptunit(weeks) header; default header unchanged"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' C2d"

**# C3: desctab, missingsummary is quiet (M1)
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly replace rep78 = .a in 1
    tempfile lg
    capture log close _c12l
    log using `"`lg'"', text replace name(_c12l)
    desctab, by(foreign) vars(rep78 cat \ mpg contn) missingsummary
    log close _c12l
    _c12_log `"`lg'"' "real change"
    assert r(n) == 0
}
_c12_result `=_rc' "C3 desctab missingsummary prints no replace counts"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' C3"

**## C3b comptab composing regtab frames prints no replace counts
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight foreign
    quietly regtab, frame(c12_f1, replace) noint
    collect clear
    quietly collect: regress price mpg weight
    quietly regtab, frame(c12_f2, replace) noint
    tempfile lg
    capture log close _c12l
    log using `"`lg'"', text replace name(_c12l)
    comptab c12_f1 c12_f2, rows(3 1 1 \ 1) frame(c12_cmp, replace)
    log close _c12l
    _c12_log `"`lg'"' "real change"
    assert r(n) == 0
    * rows(3 1 1): the repeated row is kept once
    frame c12_cmp: assert _N == 6
}
_c12_result `=_rc' "C3b comptab prints no replace counts; a repeated row is kept once"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' C3b"

**# C4: survtab default years label is announced (M2)
local ++test_count
capture noisily {
    local needle "times are labelled in years by default"
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    tempfile lg
    capture log close _c12l
    log using `"`lg'"', text replace name(_c12l)
    survtab, times(10)
    log close _c12l
    _c12_log `"`lg'"' "`needle'"
    assert r(n) == 1
    * an explicit timeunit() is not announced
    capture log close _c12l
    log using `"`lg'"', text replace name(_c12l)
    survtab, times(10) timeunit(months)
    log close _c12l
    _c12_log `"`lg'"' "`needle'"
    assert r(n) == 0
    * stset scale(365.25) made the time years: no note
    quietly stset studytime, failure(died) scale(365.25)
    capture log close _c12l
    log using `"`lg'"', text replace name(_c12l)
    survtab, times(0.01)
    log close _c12l
    _c12_log `"`lg'"' "`needle'"
    assert r(n) == 0
    * date-format time: the date note only
    _c12_dates
    quietly stset exit, failure(fail) origin(time entry) id(id)
    capture log close _c12l
    log using `"`lg'"', text replace name(_c12l)
    survtab, times(500)
    log close _c12l
    _c12_log `"`lg'"' "`needle'"
    assert r(n) == 0
    _c12_log `"`lg'"' "has a date format"
    assert r(n) == 1
}
_c12_result `=_rc' "C4 survtab announces a defaulted years label exactly when the unit is not known"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' C4"

**# C5: export-failure hint (M5)

**## C5a missing directory: one hint naming it, for each sink-writing command
local ++test_count
capture noisily {
    local bad "$C12_DIR/no_such_dir/out.xlsx"
    collect clear
    sysuse auto, clear
    quietly collect: regress price mpg
    foreach c in "desctab, vars(price contn \ mpg contn)" "crosstab foreign rep78," ///
        "table1_tc, vars(price contn) by(foreign)" "regtab," {
        sysuse auto, clear
        tempfile lg
        capture log close _c12l
        log using `"`lg'"', text replace name(_c12l)
        capture noisily `c' xlsx("`bad'")
        local rc = _rc
        log close _c12l
        display as text "`c': rc `rc'"
        assert `rc' != 0
        _c12_log `"`lg'"' "Hint: the directory $C12_DIR/no_such_dir/ does not exist"
        assert r(n) == 1
        _c12_log `"`lg'"' "Hint:"
        assert r(n) == 1
        _c12_log `"`lg'"' "Check file permissions"
        assert r(n) == 0
    }
}
_c12_result `=_rc' "C5a missing directory: exactly one hint, naming the directory"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' C5a"

**## C5b existing but unwritable directory: the open-file/writable hint
local ++test_count
capture noisily {
    local ro "$C12_DIR/readonly"
    capture mkdir "`ro'"
    shell chmod 555 "`ro'"
    sysuse auto, clear
    tempfile lg
    capture log close _c12l
    log using `"`lg'"', text replace name(_c12l)
    capture noisily crosstab foreign rep78, xlsx("`ro'/out.xlsx")
    local rc = _rc
    log close _c12l
    shell chmod 755 "`ro'"
    assert `rc' != 0
    _c12_log `"`lg'"' "not open in another application and the directory is writable"
    assert r(n) == 1
    _c12_log `"`lg'"' "does not exist"
    assert r(n) == 0
}
_c12_result `=_rc' "C5b unwritable directory: open-file/writable hint"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' C5b"

**# C6: adversarial cells (I5)

**## FE-ratetab error paths leave the caller's state unchanged
local ++test_count
capture noisily {
    _c12_dates
    quietly stset exit, failure(fail) origin(time entry) id(id) scale(365.25)
    qa_state_snapshot, tag(c12_rt_bad) rreturn
    capture ratetab g, ci(bogus)
    local rc = _rc
    qa_state_compare, tag(c12_rt_bad)
    assert `rc' == 198
    quietly ratetab g, saving("$C12_DIR/rt_save.dta", replace)
    qa_state_snapshot, tag(c12_rt_exists) rreturn
    capture ratetab g, saving("$C12_DIR/rt_save.dta")
    local rc = _rc
    qa_state_compare, tag(c12_rt_exists)
    assert `rc' == 602
    * refused inside the stratetab step: an unknown option passes through
    * to stratetab, and a markdown() file without .md is refused there
    quietly summarize _t
    qa_state_snapshot, tag(c12_rt_st) rreturn
    capture ratetab g, nosuchoption
    local rc = _rc
    qa_state_compare, tag(c12_rt_st)
    assert `rc' == 198
    qa_state_snapshot, tag(c12_rt_md) rreturn
    capture ratetab g, markdown("$C12_DIR/x.txt")
    local rc = _rc
    qa_state_compare, tag(c12_rt_md)
    assert `rc' != 0
}
_c12_result `=_rc' "FE-ratetab refusals before and inside the stratetab step change nothing"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' FE-ratetab"

**## FE-outtab error paths leave the caller's state unchanged
local ++test_count
capture noisily {
    webuse lbw, clear
    qa_state_snapshot, tag(c12_ot_bad) rreturn
    capture outtab low, exposure(smoke) estimator(poisson, irr) nosuchoption
    local rc = _rc
    qa_state_compare, tag(c12_ot_bad)
    assert `rc' == 198
    * a one-valued exposure in the sample is refused
    qa_state_snapshot, tag(c12_ot_one) rreturn
    capture outtab low if smoke == 1, exposure(smoke) estimator(poisson, irr)
    local rc = _rc
    qa_state_compare, tag(c12_ot_one)
    assert `rc' != 0
}
_c12_result `=_rc' "FE-outtab refused calls change nothing"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' FE-outtab"

**## SP-ratetab one rate in r(estimates), frame and workbook = collapse oracle
local ++test_count
capture noisily {
    _c12_dates
    quietly stset exit, failure(fail) origin(time entry) id(id) scale(365.25)
    preserve
    gen double _py = _t - _t0
    collapse (sum) _d _py, by(g)
    scalar c12_want = _d[1] / _py[1] * 1000
    restore
    capture erase "$C12_DIR/rt.xlsx"
    ratetab g, frame(c12_r, replace) xlsx("$C12_DIR/rt.xlsx")
    matrix c12_E = r(estimates)
    qa_surface_parity, expect(scalar(c12_want)) name(rate of group 0) ///
        result(el(c12_E,1,6)) frame(c12_r c4 5) xlsx("$C12_DIR/rt.xlsx" Results E5)
}
_c12_result `=_rc' "SP-ratetab rate in r(), frame and workbook"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-ratetab"

**## SP-outtab one risk ratio in r(table), frame and workbook = poisson e(b)
local ++test_count
capture noisily {
    webuse lbw, clear
    quietly poisson low i.smoke, irr vce(robust)
    scalar c12_want = exp(_b[1.smoke])
    capture erase "$C12_DIR/ot.xlsx"
    outtab low, exposure(smoke) estimator(poisson, irr vce(robust)) ///
        frame(c12_o, replace) xlsx("$C12_DIR/ot.xlsx")
    matrix c12_T = r(table)
    qa_surface_parity, expect(scalar(c12_want)) name(RR smoke) ///
        result(el(c12_T,1,5)) frame(c12_o c3 1) xlsx("$C12_DIR/ot.xlsx" Table E3)
}
_c12_result `=_rc' "SP-outtab risk ratio in r(), frame and workbook"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-outtab"

**## SP-tabcell one estimate in r(), the console, and a generate() variable
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly logit foreign mpg weight
    scalar c12_want = exp(_b[mpg])
    tempfile lg
    capture log close _c12l
    log using `"`lg'"', text replace name(_c12l)
    tabcell est mpg, eform format(%6.4f)
    scalar c12_got = r(estimate)
    log close _c12l
    qa_surface_parity, expect(scalar(c12_want)) name(OR mpg) ///
        result(scalar(c12_got)) log(`"`lg'"') logregex("^([0-9][0-9.]*) \(")
    * generate(): the same value through the variable sink
    gen double bv = scalar(c12_want)
    gen double lv = bv / 2
    gen double uv = bv * 2
    tabcell est, b(bv) ll(lv) ul(uv) format(%6.4f) generate(c12_cell)
    qa_surface_parity, expect(scalar(c12_want)) name(OR mpg generate) ///
        frame(default c12_cell 1)
}
_c12_result `=_rc' "SP-tabcell estimate in r(), console and generate()"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-tabcell"

**## LC-tabcell reads the restored fit A, not fit B
local ++test_count
capture noisily {
    sysuse auto, clear
    qa_lifecycle, fita(logit foreign mpg weight) fitb(logit foreign mpg if rep78 > 2) ///
        post(tabcell est mpg, eform; tabcell est weight)
}
_c12_result `=_rc' "LC-tabcell output after fit B and restore A is unchanged"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' LC-tabcell"

**## LC-ratetab output and saving() do not depend on the active fit
local ++test_count
capture noisily {
    _c12_dates
    quietly stset exit, failure(fail) origin(time entry) id(id) scale(365.25)
    qa_lifecycle, fita(poisson _d g, exposure(_t)) fitb(poisson _d, exposure(_t)) ///
        post(ratetab g, saving("$C12_DIR/rt_lc.dta", replace); ratetab g, ci(poisson))
}
_c12_result `=_rc' "LC-ratetab output after fit B and restore A is unchanged"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' LC-ratetab"

**## RP-ratetab reruns on the same data are bit-identical
local ++test_count
capture noisily {
    * many rows per level and non-integer person-time: the sum order moves
    * the last bit unless ratetab fixes it
    clear
    set seed 4242
    quietly set obs 3000
    gen byte g = mod(_n, 3)
    gen double py = 0.1 + runiform() * 7.3
    gen long ev = rpoisson(0.05 * py)
    gen long cl = mod(_n, 50)
    foreach ci in exact poisson "cluster(cl)" {
        set sortseed 1
        quietly ratetab g, events(ev) exposure(py) per(1) ci(`ci')
        matrix c12_A = r(estimates)
        forvalues k = 2/6 {
            set sortseed `k'
            quietly ratetab g, events(ev) exposure(py) per(1) ci(`ci')
            matrix c12_B = r(estimates)
            mata: st_numscalar("c12_d", any(st_matrix("c12_A") :!= st_matrix("c12_B")))
            assert scalar(c12_d) == 0
        }
    }
    set sortseed 0
}
_c12_result `=_rc' "RP-ratetab exact, poisson and cluster reruns are bit-identical"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' RP-ratetab"

**## LC-ratetab saving(): a refused rewrite keeps the file, replace rewrites it
local ++test_count
capture noisily {
    _c12_dates
    quietly stset exit, failure(fail) origin(time entry) id(id) scale(365.25)
    quietly count if _d & g == 0
    local d_all = r(N)
    quietly ratetab g, saving("$C12_DIR/rt_stale.dta", replace)
    capture ratetab g if id <= 100, saving("$C12_DIR/rt_stale.dta")
    assert _rc == 602
    preserve
    use "$C12_DIR/rt_stale.dta", clear
    assert events[1] == `d_all'
    restore
    quietly count if _d & g == 0 & id <= 100
    local d_half = r(N)
    assert `d_half' != `d_all'
    quietly ratetab g if id <= 100, saving("$C12_DIR/rt_stale.dta", replace)
    use "$C12_DIR/rt_stale.dta", clear
    assert events[1] == `d_half'
}
_c12_result `=_rc' "LC-ratetab saving() is never stale"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' LC-ratetab-file"

**## LC-outtab fits its own models: output after fit B and restore A is unchanged
local ++test_count
capture noisily {
    webuse lbw, clear
    qa_lifecycle, fita(logit low smoke age) fitb(logit low lwt) ///
        post(outtab low, exposure(smoke) estimator(poisson, irr vce(robust)) frame(c12_olc, replace))
}
_c12_result `=_rc' "LC-outtab output after fit B and restore A is unchanged"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' LC-outtab"

**## LC-comptab composes the same frames identically around a refit
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price foreign mpg weight
    quietly regtab, frame(c12_f1, replace) noint
    collect clear
    quietly collect: regress price i.foreign##c.mpg weight
    quietly regtab, frame(c12_f2, replace) noint
    qa_lifecycle, fita(regress price mpg) fitb(regress price weight if foreign) ///
        post(comptab c12_f1 c12_f2, rows(1 \ 1 2) frame(c12_cmp, replace))
}
_c12_result `=_rc' "LC-comptab output after fit B and restore A is unchanged"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' LC-comptab"

**# Summary
capture shell chmod -R 755 "$C12_DIR"
capture shell rm -rf "$C12_DIR"
foreach f in c12_t c12_r c12_s c12_o c12_olc c12_f1 c12_f2 c12_cmp {
    capture frame drop `f'
}
capture scalar drop c12_want c12_got c12_d
capture matrix drop c12_E c12_T c12_A c12_B
capture macro drop C12_DIR
local fail_count = `test_count' - `pass_count'
if `fail_count' display as error "failed:`failed'"
display as text "RESULT: test_clarity_2026_10_12 tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _c12
if `fail_count' > 0 exit 1
exit 0
