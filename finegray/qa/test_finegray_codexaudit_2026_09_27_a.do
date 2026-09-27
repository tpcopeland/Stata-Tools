* test_finegray_codexaudit_2026_09_27_a.do
* Postestimation regressions from the 2026-09-27 Codex audit (F01, F02, F04,
* F05, F06).  Every check is a known answer or an invariance, read from the
* numbers the user sees: r(table), the live graph serset, or predict.
*
*   F01  The default finegray_cif grid carried each baseline event time
*        through a decimal macro.  A time that rounds DOWN (.12345678901234564
*        -> ...559) was evaluated before its own jump: CIF 0 at rc 0, table
*        and graph alike.
*   F04  The graph's terminal plateau was looked up by equality against a
*        rounded max-time macro; an exact timepoints() grid selected no row
*        and drew a missing tail.
*   F05  The plateau cutoff accepted a grid ending 1e-12 BEFORE the last
*        cause event as having reached it, drawing the pre-jump value out to
*        the end of follow-up.
*   F02  tvc() x bstrata() row prediction inferred the boundary matrix layout
*        from its ROW count; with several fitted strata and cause events in
*        only one, the stratum value was read as a cumulative hazard.
*   F06  A single-level bstrata() fit answered rows in a level it never saw
*        from the sole fitted baseline.
*   F07/F08 residue in the postestimation files: the Schoenfeld routes wrote
*        and dropped a fixed _finegray_schoenfeld matrix, and a failed engine
*        load in finegray_cif/finegray_predict left matastrict on.
*
* CA-1..CA-5, CA-8..CA-11, CA-13 and CA-14 fail on the 1.3.7 build; CA-6, CA-7 and CA-12 pin
* behaviour that must survive the fixes.
clear all
set varabbrev off
version 16.0

local qa_dir "`c(pwd)'"
capture log close _all
log using "test_finegray_codexaudit_2026_09_27_a.log", replace text name(_fgca)
do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _fgca_result
program define _fgca_result, rclass
    args rc label
    if `rc' == 0 {
        display as result "  PASS: `label'"
        return scalar pass = 1
        return scalar fail = 0
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        return scalar pass = 0
        return scalar fail = 1
    }
end

* The one-curve serset twoway was handed: number of rows, last plotted time,
* the CIF there, whether any variable is missing on that terminal row, and the
* CIF at an exact probe time (missing if no row has that time).
capture program drop _fgca_serset
program define _fgca_serset, rclass
    version 16.0
    args probe
    local found = 0
    forvalues k = 0/19 {
        capture serset set `k'
        if _rc continue
        preserve
        serset use, clear
        capture confirm numeric variable time cif
        if _rc {
            restore
            continue
        }
        local ++found
        sort time
        return scalar n = _N
        return scalar maxt = time[_N]
        return scalar lastcif = cif[_N]
        local miss = 0
        foreach v of varlist _all {
            if missing(`v'[_N]) local miss = 1
        }
        return scalar lastmiss = `miss'
        return scalar nvar = c(k)
        local pc = .
        if "`probe'" != "" {
            forvalues i = 1/`=_N' {
                if time[`i'] == `probe' local pc = cif[`i']
            }
        }
        return scalar probecif = `pc'
        restore
    }
    return scalar nsets = `found'
end

* F01 fixture: 200 balanced subjects, 100 cause events at a time whose
* decimal rendering rounds DOWN, 100 competing events at 1.  Coefficient 0,
* one Breslow jump of 100/200: CIF(t >= tev) = 1 - exp(-.5).
capture program drop _fgca_mk01
program define _fgca_mk01
    version 16.0
    args tev tcomp bstr
    clear
    quietly set obs 200
    gen long id = _n
    gen byte x = mod(_n, 2)
    gen double t = cond(_n <= 100, `tev', `tcomp')
    gen byte status = cond(_n <= 100, 1, 2)
    if "`bstr'" != "" {
        * two baseline strata, each with 50 cause and 50 competing events,
        * each balanced in x
        gen byte bs = cond(mod(_n, 4) < 2, 1, 2)
    }
    quietly stset t, failure(status==1 2) id(id)
end

* %21x: `local tev = ...' would itself round the oracle through decimal text
local tev : display %21x .12345678901234564
local known = 1 - exp(-.5)

**# CA-1 (F01): default grid contains the exact event time and its jump
local ++test_count
capture noisily {
    _fgca_mk01 .12345678901234564 1
    quietly finegray x, compete(status) cause(1) nolog
    quietly finegray_cif, at(x=0) nograph
    tempname T
    matrix `T' = r(table)
    local hit = 0
    forvalues r = 1/`=rowsof(`T')' {
        if `T'[`r', 1] == `tev' {
            local ++hit
            assert !missing(`T'[`r', 2], `known')
            assert reldif(`T'[`r', 2], `known') < 1e-12
            assert `T'[`r', 3] > 0 & `T'[`r', 3] < .
        }
        * no grid time may sit strictly between two representable neighbours
        * of an event: every grid time is an event time of the fit
        assert `T'[`r', 1] == `tev'
    }
    assert `hit' == 1
}
local _rc = _rc
_fgca_result `_rc' "CA-1 F01 default grid keeps the exact event time and CIF 1-exp(-.5)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# CA-2 (F01): the default GRAPH shows the jump
local ++test_count
capture noisily {
    capture graph drop _all
    capture serset drop _all
    _fgca_mk01 .12345678901234564 1
    quietly finegray x, compete(status) cause(1) nolog
    quietly finegray_cif, at(x=0) name(_fgca2, replace)
    _fgca_serset `tev'
    assert r(nsets) == 1
    assert !missing(r(probecif), `known')
    assert reldif(r(probecif), `known') < 1e-12
    assert r(maxt) == 1
    assert !missing(r(lastcif), `known')
    assert reldif(r(lastcif), `known') < 1e-12
    graph drop _all
}
local _rc = _rc
capture restore
_fgca_result `_rc' "CA-2 F01 default graph jumps at the exact event and plateaus at 1-exp(-.5)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# CA-3 (F01): stratified default grids and the over() overlay keep exact times
local ++test_count
capture noisily {
    _fgca_mk01 .12345678901234564 1 bs
    quietly finegray x, compete(status) cause(1) bstrata(bs) nolog
    forvalues s = 1/2 {
        quietly finegray_cif, at(x=0) bstratum(`s') nograph
        tempname T
        matrix `T' = r(table)
        assert rowsof(`T') == 1
        assert `T'[1, 1] == `tev'
        assert !missing(`T'[1, 2], `known')
        assert reldif(`T'[1, 2], `known') < 1e-12
    }
    quietly finegray_cif, at(x=0) over(bs) nograph
    matrix `T' = r(table)
    assert rowsof(`T') == 2
    forvalues r = 1/2 {
        assert `T'[`r', 1] == `tev'
        assert !missing(`T'[`r', 2], `known')
        assert reldif(`T'[`r', 2], `known') < 1e-12
    }
}
local _rc = _rc
_fgca_result `_rc' "CA-3 F01 bstratum() and over() default grids keep the exact event time"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# CA-4 (F04): an exact timepoints() grid keeps its terminal plateau
local ++test_count
capture noisily {
    capture graph drop _all
    capture serset drop _all
    _fgca_mk01 .12345678901234564 1
    quietly finegray x, compete(status) cause(1) nolog
    quietly finegray_cif, at(x=0) timepoints(.12345678901234564) name(_fgca4, replace)
    _fgca_serset `tev'
    assert r(nsets) == 1
    assert !missing(r(probecif), `known')
    assert reldif(r(probecif), `known') < 1e-12
    assert r(maxt) == 1
    assert r(lastmiss) == 0
    assert !missing(r(lastcif), `known')
    assert reldif(r(lastcif), `known') < 1e-12
    graph drop _all
    capture serset drop _all
    quietly finegray_cif, at(x=0) timepoints(.12345678901234564) ci name(_fgca4b, replace)
    _fgca_serset `tev'
    assert r(nvar) == 4
    assert r(maxt) == 1
    assert r(lastmiss) == 0
    assert !missing(r(lastcif), `known')
    assert reldif(r(lastcif), `known') < 1e-12
    graph drop _all
}
local _rc = _rc
capture restore
_fgca_result `_rc' "CA-4 F04 exact timepoints() graph extends CIF and bands to the end of follow-up"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# CA-5 (F05): a grid ending just BEFORE the final jump is not extended
local ++test_count
capture noisily {
    capture graph drop _all
    capture serset drop _all
    _fgca_mk01 1.0000000000005 2
    quietly finegray x, compete(status) cause(1) nolog
    quietly finegray_cif, at(x=0) timepoints(1) name(_fgca5, replace)
    _fgca_serset
    assert r(maxt) == 1
    assert r(lastcif) == 0
    graph drop _all
}
local _rc = _rc
capture restore
_fgca_result `_rc' "CA-5 F05 timepoints(1) before a jump at 1+5e-13 ends at 1, no false zero plateau"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# CA-6 (F05 control): a grid AT the final jump is extended, with the jump
local ++test_count
capture noisily {
    capture graph drop _all
    capture serset drop _all
    _fgca_mk01 1.0000000000005 2
    quietly finegray x, compete(status) cause(1) nolog
    quietly finegray_cif, at(x=0) timepoints(1.0000000000005) name(_fgca6, replace)
    _fgca_serset 1.0000000000005
    assert !missing(r(probecif), `known')
    assert reldif(r(probecif), `known') < 1e-12
    assert r(maxt) == 2
    assert !missing(r(lastcif), `known')
    assert reldif(r(lastcif), `known') < 1e-12
    graph drop _all
    capture serset drop _all
    quietly finegray_cif, at(x=0) name(_fgca6b, replace)
    _fgca_serset 1.0000000000005
    assert !missing(r(probecif), `known')
    assert reldif(r(probecif), `known') < 1e-12
    assert r(maxt) == 2
    assert !missing(r(lastcif), `known')
    assert reldif(r(lastcif), `known') < 1e-12
    graph drop _all
}
local _rc = _rc
capture restore
_fgca_result `_rc' "CA-6 F05/F01 grid at the exact final jump is extended with the jump value"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# CA-7 (F04 no-regression): exactly representable timepoints keep their tail
local ++test_count
capture noisily {
    capture graph drop _all
    capture serset drop _all
    _fgca_mk01 .5 1
    quietly finegray x, compete(status) cause(1) nolog
    quietly finegray_cif, at(x=0) timepoints(.25 .5) ci name(_fgca7, replace)
    _fgca_serset .5
    assert !missing(r(probecif), `known')
    assert reldif(r(probecif), `known') < 1e-12
    assert r(maxt) == 1
    assert r(lastmiss) == 0
    graph drop _all
}
local _rc = _rc
capture restore
_fgca_result `_rc' "CA-7 representable timepoints() grid keeps its plateau (control)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* F02 fixture: two fitted baseline strata (7 and 9), cause events only in 7.
capture program drop _fgca_mk02
program define _fgca_mk02
    version 16.0
    args lab7
    clear
    set seed 928371
    quietly set obs 600
    gen long id = _n
    gen double x = rnormal()
    gen double t = .1 + 5*runiform()
    gen byte status = cond(runiform()<.5,1,cond(runiform()<.5,2,0))
    gen byte bs = cond(_n<=400,7,9)
    quietly replace status = 2 if bs==9 & status==1
    if "`lab7'" != "" quietly replace bs = `lab7' if bs == 7
    quietly stset t, failure(status==1 2) id(id)
end

**# CA-8 (F02): row CIF equals direct integration of the posted baseline
local ++test_count
capture noisily {
    _fgca_mk02
    quietly finegray x, compete(status) cause(1) bstrata(bs) tvc(x) tsplit(2) basehaz nolog
    tempname B H
    matrix `B' = e(b)
    matrix `H' = e(basehaz)
    scalar _fgca_hcut = 0
    scalar _fgca_ht = 0
    forvalues j = 1/`=rowsof(`H')' {
        if `H'[`j',1] == 7 & `H'[`j',2] <= 2 scalar _fgca_hcut = `H'[`j',3]
        if `H'[`j',1] == 7 & `H'[`j',2] <= 4 scalar _fgca_ht = `H'[`j',3]
    }
    scalar _fgca_exp = 1 - exp(-(_fgca_hcut*exp(x[1]*`B'[1,1]) + ///
        (_fgca_ht - _fgca_hcut)*exp(x[1]*`B'[1,2])))
    gen double horizon = 4
    * posted baseline
    quietly finegray_predict double p1 if bs==7, cif timevar(horizon)
    assert !missing(p1[1], scalar(_fgca_exp))
    assert reldif(p1[1], scalar(_fgca_exp)) < 1e-10
    * rebuilt baseline after the Mata cache is gone
    mata: mata clear
    quietly finegray_predict double p2 if bs==7, cif timevar(horizon)
    assert !missing(p2[1], scalar(_fgca_exp))
    assert reldif(p2[1], scalar(_fgca_exp)) < 1e-10
    * the profile route at the same exact x
    local xp : display %21x x[1]
    quietly finegray_cif, at(x=`xp') attime(4) bstratum(7) ci nograph
    tempname T
    matrix `T' = r(table)
    assert !missing(`T'[1,2], scalar(_fgca_exp))
    assert reldif(`T'[1,2], scalar(_fgca_exp)) < 1e-10
    local plci = `T'[1,4]
    local puci = `T'[1,5]
    * the ci route's point and limits agree with the profile route
    quietly finegray_predict double p3 if _n == 1, cif timevar(horizon) ci
    assert !missing(p3[1], scalar(_fgca_exp))
    assert reldif(p3[1], scalar(_fgca_exp)) < 1e-10
    assert !missing(p3_lci[1], `plci')
    assert reldif(p3_lci[1], `plci') < 1e-8
    assert !missing(p3_uci[1], `puci')
    assert reldif(p3_uci[1], `puci') < 1e-8
}
local _rc = _rc
_fgca_result `_rc' "CA-8 F02 one event-bearing stratum: row CIF = direct integration, all baseline sources, ci"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# CA-9 (F02): relabelling a baseline stratum does not change its CIF
local ++test_count
capture noisily {
    _fgca_mk02
    quietly finegray x, compete(status) cause(1) bstrata(bs) tvc(x) tsplit(2) nolog
    gen double horizon = 4
    quietly finegray_predict double pa if bs==7, cif timevar(horizon)
    tempfile a
    keep id pa
    quietly save `a'
    foreach lab in 0 8 3.5 {
        _fgca_mk02 `lab'
        quietly finegray x, compete(status) cause(1) bstrata(bs) tvc(x) tsplit(2) nolog
        gen double horizon = 4
        quietly finegray_predict double pb if bs==`lab', cif timevar(horizon)
        quietly merge 1:1 id using `a', assert(match) nogen
        assert missing(pa) == missing(pb)
        assert reldif(pa, pb) < 1e-12 if !missing(pa, pb)
        quietly count if !missing(pb)
        assert r(N) == 400
    }
}
local _rc = _rc
_fgca_result `_rc' "CA-9 F02 stratum labels 7/0/8/3.5 give identical row CIFs"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* F06 fixture: the F02 data with every row in one stratum (or two, control).
capture program drop _fgca_mk06
program define _fgca_mk06
    version 16.0
    args multi
    clear
    set seed 928371
    quietly set obs 600
    gen long id = _n
    gen double x = rnormal()
    gen double t = .1 + 5*runiform()
    gen byte status = cond(runiform()<.5,1,cond(runiform()<.5,2,0))
    gen byte bs = 7
    if "`multi'" != "" quietly replace bs = 9 if _n > 300
    quietly stset t, failure(status==1 2) id(id)
end

**# CA-10 (F06): a single-level fit refuses an unseen level, cif and basecshazard
local ++test_count
capture noisily {
    foreach m in "" multi {
        _fgca_mk06 `m'
        quietly finegray x, compete(status) cause(1) bstrata(bs) nolog
        quietly replace bs = 99 in 1/10
        capture finegray_predict double c1, cif
        assert _rc == 459
        capture finegray_predict double h1, basecshazard
        assert _rc == 459
        * the fitted level alone still predicts
        capture drop c2
        quietly finegray_predict double c2 if bs != 99, cif
        quietly count if !missing(c2)
        assert r(N) == 590
    }
}
local _rc = _rc
_fgca_result `_rc' "CA-10 F06 unseen bstrata() level refused (459) after singleton and multi-level fits"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# CA-11 (F06): the same after estimates save/use on compatible new data
local ++test_count
capture noisily {
    _fgca_mk06
    quietly finegray x, compete(status) cause(1) bstrata(bs) basehaz nolog
    tempfile est
    quietly estimates save `est'
    clear
    quietly set obs 5
    gen double x = 0
    gen double _t = 2
    gen byte bs = cond(_n <= 2, 7, 99)
    quietly estimates use `est'
    capture finegray_predict double c1, cif timevar(_t)
    assert _rc == 459
    capture finegray_predict double c2 if bs == 7, cif timevar(_t)
    assert _rc == 0
    quietly count if !missing(c2)
    assert r(N) == 2
}
local _rc = _rc
_fgca_result `_rc' "CA-11 F06 saved singleton fit refuses unseen level on new data"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# CA-12 (control): singleton bstrata() predictions equal the unstratified fit
local ++test_count
capture noisily {
    _fgca_mk06
    quietly finegray x, compete(status) cause(1) bstrata(bs) nolog
    quietly finegray_predict double cs, cif
    quietly finegray_predict double hs, basecshazard
    quietly finegray x, compete(status) cause(1) nolog
    quietly finegray_predict double cu, cif
    quietly finegray_predict double hu, basecshazard
    assert !missing(cs, cu)
    assert reldif(cs, cu) < 1e-12
    assert !missing(hs, hu)
    assert reldif(hs, hu) < 1e-12
}
local _rc = _rc
_fgca_result `_rc' "CA-12 singleton-stratum predictions equal the unstratified fit (control)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# CA-13 (F07 pattern): Schoenfeld routes leave a caller's matrix alone
local ++test_count
capture noisily {
    _fgca_mk06 multi
    quietly finegray x, compete(status) cause(1) nolog
    matrix _finegray_schoenfeld = (11, 22, 33)
    matrix colnames _finegray_schoenfeld = a b c
    quietly finegray_phtest
    confirm matrix _finegray_schoenfeld
    assert _finegray_schoenfeld[1,1] == 11 & _finegray_schoenfeld[1,3] == 33
    assert "`: colnames _finegray_schoenfeld'" == "a b c"
    quietly finegray_predict double sc, schoenfeld
    quietly count if !missing(sc)
    assert r(N) > 0
    confirm matrix _finegray_schoenfeld
    assert _finegray_schoenfeld[1,2] == 22
    assert colsof(_finegray_schoenfeld) == 3 & rowsof(_finegray_schoenfeld) == 1
    matrix drop _finegray_schoenfeld
}
local _rc = _rc
capture matrix drop _finegray_schoenfeld
_fgca_result `_rc' "CA-13 F07 phtest and predict, schoenfeld keep a caller's _finegray_schoenfeld"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# CA-14 (F08): a failed engine load in cif/predict restores matastrict
local ++test_count
local brokendir ""
capture noisily {
    _fgca_mk06 multi
    quietly finegray x, compete(status) cause(1) nolog
    findfile _finegray_mata.ado
    local src `"`r(fn)'"'
    tempfile anchor
    local brokendir "`anchor'_brokenmata"
    mkdir "`brokendir'"
    filefilter `"`src'"' "`brokendir'/_finegray_mata.ado", ///
        from("void _finegray_mata_ok() {}") to("void _finegray_mata_ok() {}\Ureal scalar _fgca_broken( {")
    assert r(occurrences) == 1
    adopath ++ "`brokendir'"
    foreach s in off on {
        mata: mata clear
        mata: mata set matastrict `s'
        capture finegray_cif, at(x=0) attime(1) nograph
        assert _rc != 0
        assert "`c(matastrict)'" == "`s'"
        mata: mata clear
        mata: mata set matastrict `s'
        capture finegray_predict double c1, cif
        assert _rc != 0
        assert "`c(matastrict)'" == "`s'"
        mata: mata clear
        mata: mata set matastrict `s'
        capture finegray_predict double s1, schoenfeld
        assert _rc != 0
        assert "`c(matastrict)'" == "`s'"
    }
}
local _rc = _rc
capture adopath - "`brokendir'"
mata: mata clear
mata: mata set matastrict off
_fgca_result `_rc' "CA-14 F08 engine load failure in finegray_cif/predict restores matastrict on/off"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# Summary
display as text _newline ///
    "RESULT: test_finegray_codexaudit_2026_09_27_a tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _fgca
if `fail_count' > 0 exit 1
exit 0
