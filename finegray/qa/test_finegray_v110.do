* test_finegray_v110.do
* Regression tests for finegray 1.1.0:
*   - multiple-record-per-subject reduction (parity, TVC error, gap error)
*   - finegray_cif (curve / attime table / saving / guards)
*   - finegray_predict, cif ci
*   - finegray_cif graph polish: single-row legend default, twoway/legend()
*     passthrough, title()/xtitle() override, single-curve and nograph paths
clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_v110.log", replace name(_t110)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Helpers
program define _mk_hypoxia
    local cache "`c(tmpdir)'/finegray_hypoxia_cache.dta"
    capture confirm file "`cache'"
    if _rc {
        webuse hypoxia, clear
        quietly save "`cache'", replace
    }
    else {
        use "`cache'", clear
    }
    gen byte status = failtype
end

* Count occurrences of a literal token in a text file. Everything after the
* first (quoted) token on the command line is the search string, so spaces and
* "%" are handled (e.g. _svg_count "file" % CI).
program define _svg_count, rclass
    gettoken fn rest : 0
    local token = strtrim(`"`rest'"')
    tempname fh
    local n = 0
    file open `fh' using `fn', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`token'"') local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end

**# ---------------------------------------------------------------
**# 1. Multi-record reduction: stsplit parity with single-record fit
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    matrix b1 = e(b)
    matrix V1 = e(V)
    scalar ll1 = e(ll)
    scalar N1 = e(N)
    matrix bh1 = e(basehaz)

    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    stsplit iv, at(2 4 6 8)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    assert e(N) == N1
    assert mreldif(e(b), b1) < 1e-9
    assert mreldif(e(V), V1) < 1e-9
    assert reldif(e(ll), ll1) < 1e-9
    assert rowsof(e(basehaz)) == rowsof(bh1)
    assert mreldif(e(basehaz), bh1) < 1e-9
}
if _rc == 0 {
    display as result "  PASS: multi-record stsplit parity"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-record stsplit parity (rc=`=_rc')"
    local ++fail_count
}

**# 2. Time-varying covariate -> error 198
local ++test_count
capture {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    stsplit iv, at(2 4 6 8)
    replace ifp = ifp + iv
    capture finegray ifp tumsize pelnode, compete(status) cause(1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: TVC rejected (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: TVC rejected"
    local ++fail_count
}

**# 3. Gap in intervals -> error 198
local ++test_count
capture {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    stsplit iv, at(2 4 6 8)
    drop if iv==4 & stnum==stnum[1]
    capture finegray ifp tumsize pelnode, compete(status) cause(1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: interval gap rejected (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: interval gap rejected"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 4. finegray_cif: fixed-horizon table
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    finegray_cif, attime(2 5 8) ci
    matrix T = r(table)
    assert rowsof(T) == 3
    assert colsof(T) == 5
    * cif in (0,1), lci <= cif <= uci, increasing time
    forvalues r = 1/3 {
        assert T[`r',2] > 0 & T[`r',2] < 1
        assert T[`r',4] <= T[`r',2] + 1e-9
        assert T[`r',2] <= T[`r',5] + 1e-9
        assert T[`r',3] > 0
    }
    assert r(cause) == 1
    assert r(level) == 95
}
if _rc == 0 {
    display as result "  PASS: finegray_cif attime table"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_cif attime table (rc=`=_rc')"
    local ++fail_count
}

**# 5. finegray_cif: curve + saving() produces a dataset
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    tempfile cc
    finegray_cif, ci nograph saving("`cc'", replace)
    preserve
    use "`cc'", clear
    assert _N > 5
    foreach v in time cif se lci uci {
        capture confirm variable `v'
        assert _rc == 0
    }
    assert cif[1] >= 0 & cif[_N] <= 1
    restore
}
if _rc == 0 {
    display as result "  PASS: finegray_cif saving()"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_cif saving() (rc=`=_rc')"
    local ++fail_count
}

**# 6. finegray_cif: e(cmd) guard after a foreign estimator
local ++test_count
capture {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    regress ifp tumsize
    capture finegray_cif, attime(5)
    assert _rc == 301
}
if _rc == 0 {
    display as result "  PASS: finegray_cif e(cmd) guard (301)"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_cif e(cmd) guard"
    local ++fail_count
}

**# 7. finegray_cif at() profile differs from means, point matches predict
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    finegray_cif, at(ifp=20 tumsize=5 pelnode=1) attime(5)
    matrix T = r(table)
    scalar cif_cmd = T[1,2]
    * replicate via predict at the same profile and t=5
    drop _all
    set obs 1
    gen ifp = 20
    gen tumsize = 5
    gen pelnode = 1
    gen double t5 = 5
    finegray_predict cif_p, cif timevar(t5)
    assert reldif(cif_p[1], cif_cmd) < 1e-7
}
if _rc == 0 {
    display as result "  PASS: finegray_cif at() matches predict"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_cif at() matches predict (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 8. finegray_predict, cif ci: bounds and monotonicity
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    gen double t5 = 5
    finegray_predict cif5, cif timevar(t5) ci
    confirm variable cif5_lci
    confirm variable cif5_uci
    assert cif5_lci <= cif5 + 1e-9 if !missing(cif5)
    assert cif5 <= cif5_uci + 1e-9 if !missing(cif5)
    assert cif5_lci >= 0 & cif5_uci <= 1 if !missing(cif5)
    quietly count if !missing(cif5)
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: predict cif ci bounds"
    local ++pass_count
}
else {
    display as error "  FAIL: predict cif ci bounds (rc=`=_rc')"
    local ++fail_count
}

**# 9. ci requires cif
local ++test_count
capture {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    capture finegray_predict xbhat, ci
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: ci requires cif (198)"
    local ++pass_count
}
else {
    display as error "  FAIL: ci requires cif"
    local ++fail_count
}

**# 10. predict cif ci name-collision pre-check
local ++test_count
capture {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    gen myc_lci = 1
    capture finegray_predict myc, cif ci
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: predict ci name-collision guard"
    local ++pass_count
}
else {
    display as error "  FAIL: predict ci name-collision guard"
    local ++fail_count
}

**# 11. finegray_cif bootstrap: e() preserved, points unchanged, SE positive
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    matrix b0 = e(b)
    finegray_cif, attime(2 5 8) ci
    matrix A = r(table)
    finegray_cif, attime(2 5 8) ci bootstrap(150) seed(99)
    matrix B = r(table)
    assert "`e(cmd)'" == "finegray"
    assert mreldif(e(b), b0) < 1e-12
    forvalues r = 1/3 {
        assert reldif(A[`r',2], B[`r',2]) < 1e-10
        assert B[`r',3] > 0
        assert B[`r',4] <= B[`r',2] + 1e-9
        assert B[`r',2] <= B[`r',5] + 1e-9
    }
}
if _rc == 0 {
    display as result "  PASS: finegray_cif bootstrap (e() preserved)"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_cif bootstrap (rc=`=_rc')"
    local ++fail_count
}

**# 12. predict cif ci bootstrap: e() preserved, bounds valid
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    matrix b0 = e(b)
    gen double t5 = 5
    finegray_predict cb, cif timevar(t5) ci bootstrap(150) seed(5)
    assert "`e(cmd)'" == "finegray"
    assert mreldif(e(b), b0) < 1e-12
    assert cb_lci <= cb + 1e-9 if !missing(cb)
    assert cb <= cb_uci + 1e-9 if !missing(cb)
    assert cb_lci >= 0 & cb_uci <= 1 if !missing(cb)
}
if _rc == 0 {
    display as result "  PASS: predict cif ci bootstrap"
    local ++pass_count
}
else {
    display as error "  FAIL: predict cif ci bootstrap (rc=`=_rc')"
    local ++fail_count
}

**# 13. bootstrap() requires ci on predict
local ++test_count
capture {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    gen double t5 = 5
    capture finegray_predict cz, cif timevar(t5) bootstrap(50)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: predict bootstrap requires ci"
    local ++pass_count
}
else {
    display as error "  FAIL: predict bootstrap requires ci"
    local ++fail_count
}

**# 14. finegray_cif timepoints(): curve on a supplied grid + r(profile_vars)
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    finegray_cif, timepoints(1 2 4 6 8) nograph
    matrix T = r(table)
    assert rowsof(T) == 5
    assert T[1,1] == 1 & T[5,1] == 8
    * CIF is nondecreasing over the time grid
    forvalues r = 2/5 {
        assert T[`r',2] >= T[`=`r'-1',2] - 1e-9
    }
    * r(profile_vars) lists model covariates in r(at) column order
    assert "`r(profile_vars)'" == "ifp tumsize pelnode"
    assert colsof(r(at)) == 3
}
if _rc == 0 {
    display as result "  PASS: finegray_cif timepoints() + r(profile_vars)"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_cif timepoints() (rc=`=_rc')"
    local ++fail_count
}

**# 15. finegray e(marginsok): xb for plain model, empty for FV model
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    assert "`e(marginsok)'" == "xb"
    finegray i.pelnode c.ifp, compete(status) cause(1)
    assert "`e(marginsok)'" == ""
}
if _rc == 0 {
    display as result "  PASS: finegray e(marginsok)"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray e(marginsok) (rc=`=_rc')"
    local ++fail_count
}

**# 16. predict cif ci honors if/in: SE built from full estimation sample
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    gen double t5 = 5
    finegray_predict cifF, cif timevar(t5) ci
    finegray_predict cifS if ifp > 15, cif timevar(t5) ci
    * For observations in both samples the CI must be identical: the
    * influence-function SE uses e(sample), not the if-restricted subset.
    gen double dl = abs(cifF_lci - cifS_lci) if !missing(cifS)
    gen double du = abs(cifF_uci - cifS_uci) if !missing(cifS)
    quietly summarize dl
    assert r(max) < 1e-8
    quietly summarize du
    assert r(max) < 1e-8
    * the restriction actually dropped observations from the prediction set
    quietly count if missing(cifS) & !missing(cifF)
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: predict cif ci if/in estimation-sample fix"
    local ++pass_count
}
else {
    display as error "  FAIL: predict cif ci if/in fix (rc=`=_rc')"
    local ++fail_count
}

**# 17. finegray_cif level() controls returned level and CI width
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    finegray_cif, attime(5) ci
    matrix C95 = r(table)
    finegray_cif, attime(5) ci level(90)
    matrix C90 = r(table)
    assert r(level) == 90
    assert reldif(C90[1,2], C95[1,2]) < 1e-12
    assert reldif(C90[1,3], C95[1,3]) < 1e-12
    assert C90[1,4] >= C95[1,4] - 1e-9
    assert C90[1,5] <= C95[1,5] + 1e-9
}
if _rc == 0 {
    display as result "  PASS: finegray_cif level() controls CI width"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_cif level() controls CI width (rc=`=_rc')"
    local ++fail_count
}

**# 18. finegray_predict level() controls CIF CI width and labels
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    gen double t5 = 5
    finegray_predict cif95, cif timevar(t5) ci
    finegray_predict cif90, cif timevar(t5) ci level(90)
    local llabel : variable label cif90_lci
    local ulabel : variable label cif90_uci
    assert "`llabel'" == "CIF lower 90% limit"
    assert "`ulabel'" == "CIF upper 90% limit"
    assert reldif(cif90[1], cif95[1]) < 1e-12 if !missing(cif90[1])
    assert cif90_lci >= cif95_lci - 1e-9 if !missing(cif90)
    assert cif90_uci <= cif95_uci + 1e-9 if !missing(cif90)
    quietly count if !missing(cif90)
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: finegray_predict level() controls CI width and labels"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_predict level() controls CI width and labels (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# finegray_cif graph polish (single-row legend default, twoway/legend()
**# passthrough). Graph content is asserted by exporting SVG (a plain-text
**# format that works headless) to c(tmpdir) and scanning for legend/title
**# tokens.
**# ---------------------------------------------------------------

**# 19. Default CI plot: legend shown as a single row, both series labelled
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    local g1 "`c(tmpdir)'/_fg111_default.svg"
    capture erase "`g1'"
    finegray_cif, ci
    assert _rc == 0
    graph export "`g1'", replace
    * Both legend labels present -> legend is ON by default (not off)
    _svg_count "`g1'" >CIF<
    assert r(n) == 1
    _svg_count "`g1'" % CI<
    assert r(n) == 1
    capture erase "`g1'"
}
if _rc == 0 {
    display as result "  PASS: default CI legend shown with both labels"
    local ++pass_count
}
else {
    display as error "  FAIL: default CI legend shown with both labels (rc=`=_rc')"
    local ++fail_count
}

**# 20. legend(off) passthrough suppresses the legend
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    local g2 "`c(tmpdir)'/_fg111_legoff.svg"
    capture erase "`g2'"
    finegray_cif, ci legend(off)
    assert _rc == 0
    graph export "`g2'", replace
    * No legend labels -> the passthrough legend(off) reached the plot
    _svg_count "`g2'" >CIF<
    assert r(n) == 0
    _svg_count "`g2'" % CI<
    assert r(n) == 0
    capture erase "`g2'"
}
if _rc == 0 {
    display as result "  PASS: legend(off) passthrough suppresses legend"
    local ++pass_count
}
else {
    display as error "  FAIL: legend(off) passthrough suppresses legend (rc=`=_rc')"
    local ++fail_count
}

**# 21. title()/xtitle() passthrough override the hardcoded defaults
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    local g3 "`c(tmpdir)'/_fg111_titles.svg"
    capture erase "`g3'"
    finegray_cif, ci title("ZZTITLE") xtitle("ZZXAXIS")
    assert _rc == 0
    graph export "`g3'", replace
    _svg_count "`g3'" ZZTITLE
    assert r(n) >= 1
    _svg_count "`g3'" ZZXAXIS
    assert r(n) >= 1
    * the default xtitle is gone (overridden)
    _svg_count "`g3'" Analysis time
    assert r(n) == 0
    capture erase "`g3'"
}
if _rc == 0 {
    display as result "  PASS: title()/xtitle() passthrough override defaults"
    local ++pass_count
}
else {
    display as error "  FAIL: title()/xtitle() passthrough override defaults (rc=`=_rc')"
    local ++fail_count
}

**# 22. legend(rows(2)) passthrough is accepted (override of default rows(1))
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    local g4 "`c(tmpdir)'/_fg111_rows2.svg"
    capture erase "`g4'"
    finegray_cif, ci legend(rows(2))
    assert _rc == 0
    graph export "`g4'", replace
    * legend still shown (both labels) under the rows() override
    _svg_count "`g4'" >CIF<
    assert r(n) == 1
    capture erase "`g4'"
}
if _rc == 0 {
    display as result "  PASS: legend(rows(2)) passthrough accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: legend(rows(2)) passthrough accepted (rc=`=_rc')"
    local ++fail_count
}

**# 23. Single-curve (no ci) default builds without error
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    local g5 "`c(tmpdir)'/_fg111_single.svg"
    capture erase "`g5'"
    finegray_cif
    assert _rc == 0
    graph export "`g5'", replace
    * a curve was drawn (default xtitle present), single series -> no legend
    _svg_count "`g5'" Analysis time
    assert r(n) >= 1
    capture erase "`g5'"
}
if _rc == 0 {
    display as result "  PASS: single-curve default builds"
    local ++pass_count
}
else {
    display as error "  FAIL: single-curve default builds (rc=`=_rc')"
    local ++fail_count
}

**# 24. Passthrough does not disturb the returned payload (r(table)) or nograph
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    * graph options present alongside nograph: must be a no-op, payload intact
    finegray_cif, ci nograph legend(off) title("ignored")
    assert _rc == 0
    matrix T = r(table)
    assert colsof(T) == 5
    assert r(cause) == 1
}
if _rc == 0 {
    display as result "  PASS: nograph + passthrough leaves payload intact"
    local ++pass_count
}
else {
    display as error "  FAIL: nograph + passthrough leaves payload intact (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline "RESULT: test_finegray_v110 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _t110
    exit 1
}
display as result "ALL TESTS PASSED"
log close _t110
