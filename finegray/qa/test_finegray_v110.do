* test_finegray_v110.do
* Regression tests for finegray 1.1.0.
*
* Merged suite: this file locks every fix the collapsed version history
* attributes to 1.1.0.  It was produced mechanically from the four
* version-pinned suites that predated the history collapse
* (v110 + v111 + v112 + v114); their section banners are preserved below.
*
*   - multiple-record-per-subject reduction (parity, TVC error, gap error)
*   - finegray_cif (curve / attime table / saving / guards) and its graph
*     polish: single-row legend default, twoway/legend() passthrough,
*     title()/xtitle() override, single-curve and nograph paths
*   - finegray_predict, cif ci
*   - post-estimation parity between a single-record fit and the
*     equivalent multi-record (stsplit) fit
*   - bootstrap paths after a multi-record fit (refits see true entry
*     times); e(sample) survives finegray_cif, bootstrap()
*   - _fg_entry lifecycle; string id() bootstrap; cluster bootstrap
*     resamples whole clusters; finegray_cif at() factor natural names
*   - estimation-data signatures, stale-state invalidation, return gates,
*     strict saving()/at() validation, bootstrap nonconvergence accounting
*   - bootstrap refits that lose a factor level are skipped; unspaced
*     saving(filename,replace); finegray_predict error-path var cleanup
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


**# ==================================================================
**# Section from test_finegray_v110.do
**# ==================================================================


**# Helpers
capture program drop _mk_hypoxia
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
capture program drop _svg_count
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
    * basehaz: this test compares e(basehaz) across the stsplit, so it must be
    * posted.  It is opt-in because a K-row Stata matrix is O(K^2) to create.
    finegray ifp tumsize pelnode, compete(status) cause(1) basehaz
    matrix b1 = e(b)
    matrix V1 = e(V)
    scalar ll1 = e(ll)
    scalar N1 = e(N)
    matrix bh1 = e(basehaz)

    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    stsplit iv, at(2 4 6 8)
    finegray ifp tumsize pelnode, compete(status) cause(1) basehaz
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


**# ==================================================================
**# Section from test_finegray_v111.do
**# ==================================================================


**# Helpers
capture program drop _mk_hypoxia
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

**# ---------------------------------------------------------------
**# 1. finegray_cif parity: single-record fit vs stsplit fit
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    quietly finegray_cif, attime(2 5 8) ci
    matrix C1 = r(table)

    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    stsplit iv, at(2 4 6 8)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    quietly finegray_cif, attime(2 5 8) ci
    matrix C2 = r(table)

    assert mreldif(C1, C2) < 1e-9
}
if _rc == 0 {
    display as result "  PASS: finegray_cif parity after stsplit reduction"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_cif parity after stsplit reduction (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 2. finegray_phtest parity: single-record fit vs stsplit fit
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    quietly finegray_phtest
    matrix P1 = r(phtest)

    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    stsplit iv, at(2 4 6 8)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    quietly finegray_phtest
    matrix P2 = r(phtest)

    * 1.2.0: the r(chi2) comparison that stood here was dropped with the
    * omnibus statistic.  It was redundant anyway -- it was a function of the
    * per-covariate chi2 column, which mreldif(P1, P2) compares directly and
    * more strictly (every cell, not their sum).
    assert mreldif(P1, P2) < 1e-9
}
if _rc == 0 {
    display as result "  PASS: finegray_phtest parity after stsplit reduction"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_phtest parity after stsplit reduction (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 3. predict cif ci parity per subject: single-record vs stsplit fit
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    gen double t5 = 5
    quietly finegray_predict cifA, cif timevar(t5) ci
    preserve
    quietly keep if !missing(cifA)
    keep stnum cifA cifA_lci cifA_uci
    tempfile single
    quietly save `single'
    restore

    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    stsplit iv, at(2 4 6 8)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    gen double t5 = 5
    quietly finegray_predict cifB, cif timevar(t5) ci
    quietly keep if !missing(cifB)
    quietly merge 1:1 stnum using `single', assert(match) nogenerate
    assert reldif(cifA, cifB) < 1e-9
    assert reldif(cifA_lci, cifB_lci) < 1e-9
    assert reldif(cifA_uci, cifB_uci) < 1e-9
}
if _rc == 0 {
    display as result "  PASS: predict cif ci per-subject parity after stsplit"
    local ++pass_count
}
else {
    display as error "  FAIL: predict cif ci per-subject parity after stsplit (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 4. e(sample) survives finegray_cif bootstrap; post-estimation still works
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    scalar Nfit = e(N)
    quietly finegray_cif, attime(5) ci bootstrap(30) seed(11)
    assert "`e(cmd)'" == "finegray"
    quietly count if e(sample)
    assert r(N) == Nfit
    * a recomputation-path command must still run after the bootstrap
    quietly finegray_phtest
    matrix _P111 = r(phtest)
    assert rowsof(_P111) == 3
}
if _rc == 0 {
    display as result "  PASS: e(sample) intact after finegray_cif bootstrap"
    local ++pass_count
}
else {
    display as error "  FAIL: e(sample) intact after finegray_cif bootstrap (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 5. bootstrap after stsplit fit: both commands, refits on true entry times
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    stsplit iv, at(2 4 6 8)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    scalar Nfit = e(N)
    quietly finegray_cif, attime(5) ci
    matrix A = r(table)
    quietly finegray_cif, attime(5) ci bootstrap(100) seed(42)
    matrix B = r(table)
    * point CIF unchanged; bootstrap SE close to the analytic SE (the refits
    * would roughly triple it if they treated kept records as late entries)
    assert reldif(A[1,2], B[1,2]) < 1e-10
    assert B[1,3] > 0
    assert abs(B[1,3]/A[1,3] - 1) < 0.35
    quietly count if e(sample)
    assert r(N) == Nfit

    gen double t5 = 5
    quietly finegray_predict cbb, cif timevar(t5) ci bootstrap(60) seed(7)
    assert "`e(cmd)'" == "finegray"
    assert cbb_lci <= cbb + 1e-9 if !missing(cbb)
    assert cbb <= cbb_uci + 1e-9 if !missing(cbb)
    quietly count if !missing(cbb)
    assert r(N) == Nfit
}
if _rc == 0 {
    display as result "  PASS: bootstrap paths after stsplit reduction"
    local ++pass_count
}
else {
    display as error "  FAIL: bootstrap paths after stsplit reduction (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 6. _fg_entry lifecycle: created on reduced fit, cleared on refit/error
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    stsplit iv, at(2 4 6 8)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    confirm variable _fg_entry
    assert `"`_dta[_finegray_entryvar]'"' == "_fg_entry"

    * single-record refit drops the stale entry variable and clears the char
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    stsplit iv, at(2 4 6 8)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    drop iv
    quietly stjoin
    assert _N == e(N)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    capture confirm variable _fg_entry
    assert _rc != 0
    assert `"`_dta[_finegray_entryvar]'"' == ""

    * error after reduction must not leave _fg_entry behind
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    stsplit iv, at(2 4 6 8)
    capture finegray ifp tumsize pelnode, compete(status) cause(9)
    assert _rc == 198
    capture confirm variable _fg_entry
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: _fg_entry lifecycle (create/clear/error)"
    local ++pass_count
}
else {
    display as error "  FAIL: _fg_entry lifecycle (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 7. user-owned _fg_entry rejected without touching the variable
**# ---------------------------------------------------------------
local ++test_count
capture {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    stsplit iv, at(2 4 6 8)
    gen double _fg_entry = 99
    capture finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert _rc == 198
    confirm variable _fg_entry
    assert _fg_entry == 99
}
if _rc == 0 {
    display as result "  PASS: user-owned _fg_entry collision rejected (198)"
    local ++pass_count
}
else {
    display as error "  FAIL: user-owned _fg_entry collision rejected"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 8. multi-variable strata() through the CIF SE paths: must equal a
**#    single pre-combined group variable (and not error)
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    gen byte grp = mod(stnum, 2)
    stset dftime, failure(dfcens==1) id(stnum)
    quietly finegray ifp tumsize, compete(status) cause(1) strata(pelnode grp) nolog
    quietly finegray_cif, attime(5) ci
    matrix S2 = r(table)
    gen double t5 = 5
    quietly finegray_predict cs2, cif timevar(t5) ci

    egen long sgrp = group(pelnode grp)
    quietly finegray ifp tumsize, compete(status) cause(1) strata(sgrp) nolog
    quietly finegray_cif, attime(5) ci
    matrix S1 = r(table)
    quietly finegray_predict cs1, cif timevar(t5) ci

    assert mreldif(S1, S2) < 1e-9
    assert reldif(cs1, cs2) < 1e-9 if !missing(cs1)
    assert reldif(cs1_lci, cs2_lci) < 1e-9 if !missing(cs1)
    assert reldif(cs1_uci, cs2_uci) < 1e-9 if !missing(cs1)
}
if _rc == 0 {
    display as result "  PASS: multi-variable strata() CIF SE paths"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-variable strata() CIF SE paths (rc=`=_rc')"
    local ++fail_count
}

* Multi-variable strata() under bootstrap() SEs.  The analytical path above
* exercises the ng>1 censoring-KM prefix sums; the bootstrap path re-fits inside
* a frame and must agree with it to within Monte Carlo error.
local ++test_count
capture noisily {
    _mk_hypoxia
    gen byte grp = mod(stnum, 2)
    stset dftime, failure(dfcens==1) id(stnum)
    quietly finegray ifp tumsize, compete(status) cause(1) strata(pelnode grp) nolog
    quietly finegray_cif, attime(5) ci
    matrix A = r(table)
    scalar _an_cif = A[1, 2]
    scalar _an_se  = A[1, 3]
    quietly finegray_cif, attime(5) ci bootstrap(60) seed(20260710)
    matrix B = r(table)
    assert r(bootstrap_success) > 1
    * The point estimate is the full-sample fit either way.
    assert reldif(B[1, 2], _an_cif) < 1e-8
    * Bootstrap SE is independent of the ng>1 prefix-sum path but must land in
    * the same ballpark as the analytical SE.
    assert B[1, 3] > 0 & B[1, 3] < .
    assert reldif(B[1, 3], _an_se) < 0.5
    assert B[1, 4] < B[1, 2] & B[1, 2] < B[1, 5]

    gen double t5 = 5
    quietly finegray_predict cbs, cif timevar(t5) ci bootstrap(60) seed(20260710)
    quietly count if !missing(cbs) & cbs_lci < cbs & cbs < cbs_uci
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: multi-variable strata() bootstrap CIF SE paths"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-variable strata() bootstrap CIF SE (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 9. string id() bootstrap: no r(109) crash, positive SE, no leak
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    gen str8 sid = "S" + string(stnum)
    stset dftime, failure(dfcens==1) id(sid)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    * finegray_cif bootstrap used to die with r(109) (replace strvar = _n)
    quietly finegray_cif, attime(2 5) ci bootstrap(30) seed(1)
    matrix Bstr = r(table)
    assert Bstr[1,3] > 0 & Bstr[2,3] > 0
    * finegray_predict bootstrap likewise
    quietly finegray_predict cstr, cif ci bootstrap(30) seed(1)
    quietly count if !missing(cstr)
    assert r(N) > 0
    assert cstr_lci <= cstr + 1e-9 if !missing(cstr)
    assert cstr <= cstr_uci + 1e-9 if !missing(cstr)
    * the caller's string id survives untouched (no char repoint / type leak)
    assert `"`_dta[st_id]'"' == "sid"
    capture confirm string variable sid
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: string id() bootstrap (no r(109), no leak)"
    local ++pass_count
}
else {
    display as error "  FAIL: string id() bootstrap (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 10. string-id bootstrap equals numeric-id path under the same seed
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    quietly finegray_cif, attime(2 5) ci bootstrap(40) seed(99)
    matrix Bnum = r(table)

    _mk_hypoxia
    gen str8 sid = "S" + string(stnum)
    stset dftime, failure(dfcens==1) id(sid)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    quietly finegray_cif, attime(2 5) ci bootstrap(40) seed(99)
    matrix Bstr2 = r(table)
    * same rows, same seed, unique ids either way -> identical refits
    assert mreldif(Bnum, Bstr2) < 1e-7
}
if _rc == 0 {
    display as result "  PASS: string-id bootstrap matches numeric-id path"
    local ++pass_count
}
else {
    display as error "  FAIL: string-id bootstrap matches numeric-id path (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 11. cluster bootstrap resamples clusters (SE inflated vs subjects)
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    * Strong shared cluster frailty, few clusters: cluster resampling must
    * produce a substantially larger bootstrap SE than subject resampling.
    clear
    set seed 20260707
    set obs 240
    gen long cl = ceil(_n/40)
    by cl, sort: gen double u = rnormal()*1.4 if _n==1
    by cl: replace u = u[1]
    gen double x = rnormal()
    gen double lp = 0.5*x + u
    gen double tt = -ln(runiform())/exp(lp)
    gen double cc = runiform()*3
    gen double time = min(tt, cc)
    gen byte status = cond(tt<=cc, cond(runiform()<0.7,1,2), 0)
    gen long id = _n
    stset time, failure(status) id(id)

    * cluster fit -> cluster resampling (the fix)
    quietly finegray x, compete(status) cause(1) cluster(cl) nolog
    quietly finegray_cif, attime(1) ci bootstrap(200) seed(123)
    matrix Tc = r(table)
    scalar se_c = Tc[1,3]

    * same data, no-cluster fit -> subject resampling (pre-fix behavior)
    quietly finegray x, compete(status) cause(1) nolog
    quietly finegray_cif, attime(1) ci bootstrap(200) seed(123)
    matrix Ts = r(table)
    scalar se_s = Ts[1,3]

    assert se_c > 0 & se_s > 0
    * observed ratio ~2.3; old subject-resampling code would give ~1.0
    assert se_c / se_s > 1.5

    * finegray_predict has its own bsample site: cluster CIs must be wider too
    quietly finegray x, compete(status) cause(1) cluster(cl) nolog
    quietly finegray_predict pc, cif ci bootstrap(150) seed(5)
    gen double wc = pc_uci - pc_lci
    quietly summarize wc, meanonly
    scalar wcm = r(mean)
    drop pc pc_lci pc_uci wc
    quietly finegray x, compete(status) cause(1) nolog
    quietly finegray_predict ps, cif ci bootstrap(150) seed(5)
    gen double ws = ps_uci - ps_lci
    quietly summarize ws, meanonly
    assert wcm / r(mean) > 1.3
}
if _rc == 0 {
    display as result "  PASS: cluster bootstrap resamples clusters (SE inflated)"
    local ++pass_count
}
else {
    display as error "  FAIL: cluster bootstrap resamples clusters (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 12. finegray_cif at() by factor natural name (binary factor)
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    quietly finegray i.pelnode c.ifp, compete(status) cause(1) nolog

    * natural name == internal dummy name
    quietly finegray_cif, at(pelnode=1 ifp=20) attime(5)
    matrix Fn = r(table)
    matrix an = r(at)
    quietly finegray_cif, at(_fg_pelnode_1=1 ifp=20) attime(5)
    matrix Fi = r(table)
    assert mreldif(Fn, Fi) < 1e-9
    assert an[1,1] == 1

    * reference level sets the dummy to 0
    quietly finegray_cif, at(pelnode=0 ifp=20) attime(5)
    matrix ar = r(at)
    assert ar[1,1] == 0

    * invalid level and unknown var both rejected
    capture finegray_cif, at(pelnode=9 ifp=20) attime(5)
    assert _rc == 198
    capture finegray_cif, at(nosuchvar=1) attime(5)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: finegray_cif at() factor natural name"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_cif at() factor natural name (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 13. at() multi-level factor coherence + interaction rejection
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    gen byte grp3 = mod(stnum, 3)
    stset dftime, failure(dfcens==1) id(stnum)
    quietly finegray i.grp3 ifp, compete(status) cause(1) nolog
    * covariates: _fg_grp3_1 _fg_grp3_2 ifp

    * natural at(grp3=2) drives a coherent single-level profile (0,1)
    quietly finegray_cif, at(grp3=2 ifp=20) attime(5)
    matrix g2 = r(at)
    assert g2[1,1] == 0 & g2[1,2] == 1

    * equals the explicit coherent internal profile
    quietly finegray_cif, at(_fg_grp3_1=0 _fg_grp3_2=1 ifp=20) attime(5)
    matrix gi = r(table)
    quietly finegray_cif, at(grp3=2 ifp=20) attime(5)
    matrix gn = r(table)
    assert mreldif(gi, gn) < 1e-9

    * reference level zeros every dummy
    quietly finegray_cif, at(grp3=0 ifp=20) attime(5)
    matrix g0 = r(at)
    assert g0[1,1] == 0 & g0[1,2] == 0

    * a factor entering an interaction is rejected by natural name
    quietly finegray i.grp3##c.ifp, compete(status) cause(1) nolog
    capture finegray_cif, at(grp3=2) attime(5)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: at() multi-level coherence + interaction guard"
    local ++pass_count
}
else {
    display as error "  FAIL: at() multi-level coherence + interaction guard (rc=`=_rc')"
    local ++fail_count
}


**# ==================================================================
**# Section from test_finegray_v112.do
**# ==================================================================


capture program drop _mk_hypoxia_112
program define _mk_hypoxia_112
    local cache "`c(tmpdir)'/finegray_hypoxia_cache.dta"
    capture confirm file "`cache'"
    if _rc {
        webuse hypoxia, clear
        quietly save "`cache'", replace
    }
    else use "`cache'", clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)
end

**# 1. Installed state-check helper and estimation signature
local ++test_count
capture noisily {
    which _finegray_check_data
    _mk_hypoxia_112
    quietly finegray ifp tumsize, compete(status) cause(1) nolog
    assert `"`e(datasignature)'"' != ""
    assert `"`e(datasignaturevars)'"' != ""
    _finegray_check_data
}
if _rc == 0 {
    display as result "  PASS: installed data-signature guard"
    local ++pass_count
}
else {
    display as error "  FAIL: installed data-signature guard (rc=`=_rc')"
    local ++fail_count
}

**# 2. Data-dependent post-estimation rejects stale estimation data
local ++test_count
capture noisily {
    _mk_hypoxia_112
    quietly finegray ifp tumsize, compete(status) cause(1) nolog
    quietly replace status = cond(status == 0, 1, 0) in 1

    capture finegray_cif, attime(5)
    assert _rc == 459
    capture finegray_phtest
    assert _rc == 459
    capture finegray_predict stale_ci, cif ci
    assert _rc == 459

    * Pure coefficient scoring remains valid on compatible prediction data.
    finegray_predict xb_ok, xb
    confirm variable xb_ok
}
if _rc == 0 {
    display as result "  PASS: stale estimation data blocked where required"
    local ++pass_count
}
else {
    display as error "  FAIL: stale estimation data guard (rc=`=_rc')"
    local ++fail_count
}

**# 3. Validation failure preserves the preceding successful fit
local ++test_count
capture noisily {
    _mk_hypoxia_112
    quietly finegray ifp tumsize, compete(status) cause(1) nolog
    matrix b_before = e(b)
    capture finegray ifp tumsize, compete(status) cause(0) nolog
    assert _rc == 198
    assert `"`_dta[_finegray_estimated]'"' == "1"
    assert mreldif(e(b), b_before) == 0
    quietly finegray_cif, attime(5)
    confirm matrix r(table)
}
if _rc == 0 {
    display as result "  PASS: failed validation preserves prior fit"
    local ++pass_count
}
else {
    display as error "  FAIL: failed validation state contract (rc=`=_rc')"
    local ++fail_count
}

**# 4. Failure after mutation starts invalidates the preceding fit
local ++test_count
capture noisily {
    _mk_hypoxia_112
    quietly finegray ifp tumsize, compete(status) cause(1) nolog
    gen byte grp = mod(_n, 2)
    gen byte _fg_grp_1 = 0
    capture finegray i.grp ifp, compete(status) cause(1) nolog
    assert _rc == 198
    assert `"`_dta[_finegray_estimated]'"' == ""
    capture finegray_cif, attime(5)
    assert _rc == 301
}
if _rc == 0 {
    display as result "  PASS: failed re-fit cannot expose stale prior state"
    local ++pass_count
}
else {
    display as error "  FAIL: failed re-fit state invalidation (rc=`=_rc')"
    local ++fail_count
}

**# 5. Saving failure preserves the complete r() analytical payload
local ++test_count
capture noisily {
    _mk_hypoxia_112
    quietly finegray ifp tumsize, compete(status) cause(1) nolog
    capture finegray_cif, attime(2 5) ///
        saving("`c(tmpdir)'/__finegray_no_such_dir__/curve.dta")
    local save_rc = _rc
    matrix saved_table = r(table)
    matrix saved_at = r(at)
    local saved_level = r(level)
    local saved_cause = r(cause)
    local saved_profile `"`r(profile_vars)'"'
    assert `save_rc' != 0
    assert rowsof(saved_table) == 2 & colsof(saved_table) == 5
    assert rowsof(saved_at) == 1 & colsof(saved_at) == 2
    assert `saved_level' == 95
    assert `saved_cause' == 1
    assert `"`saved_profile'"' == "ifp tumsize"
}
if _rc == 0 {
    display as result "  PASS: failed saving() preserves full r() payload"
    local ++pass_count
}
else {
    display as error "  FAIL: saving() return gate (rc=`=_rc')"
    local ++fail_count
}

**# 6. Graph failure preserves the complete r() analytical payload
local ++test_count
capture noisily {
    _mk_hypoxia_112
    quietly finegray ifp tumsize, compete(status) cause(1) nolog
    capture finegray_cif, __finegray_no_such_twoway_option
    local graph_rc = _rc
    matrix graph_table = r(table)
    matrix graph_at = r(at)
    local graph_level = r(level)
    local graph_cause = r(cause)
    local graph_profile `"`r(profile_vars)'"'
    assert `graph_rc' != 0
    assert rowsof(graph_table) > 1 & colsof(graph_table) == 5
    assert rowsof(graph_at) == 1 & colsof(graph_at) == 2
    assert `graph_level' == 95
    assert `graph_cause' == 1
    assert `"`graph_profile'"' == "ifp tumsize"
}
if _rc == 0 {
    display as result "  PASS: failed graph preserves full r() payload"
    local ++pass_count
}
else {
    display as error "  FAIL: graph return gate (rc=`=_rc')"
    local ++fail_count
}

**# 7. saving() rejects malformed options and unsafe path characters
local ++test_count
capture noisily {
    _mk_hypoxia_112
    quietly finegray ifp tumsize, compete(status) cause(1) nolog
    capture finegray_cif, attime(5) saving("bad;name.dta", replace)
    assert _rc == 198
    capture finegray_cif, attime(5) saving("safe.dta", append)
    assert _rc == 198
    capture finegray_cif, at(ifp=.) attime(5)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: saving()/at() validation rejects unsafe input"
    local ++pass_count
}
else {
    display as error "  FAIL: saving()/at() validation (rc=`=_rc')"
    local ++fail_count
}

**# 8. A nonconverged fit can never reach the bootstrap at all
* Contract (FG-H07). This test used to manufacture a nonconverged fit
* (iterate(1) tolerance(1e-20)), confirm e(converged)==0, and then check that
* finegray_cif's bootstrap skipped every refit and errored 498.
*
* The fit still posts (rc 0, e(converged)=0 -- stcrreg's contract), but it can no
* longer REACH the bootstrap: finegray_cif refuses a nonconverged fit outright.
* So the old scenario is unreachable one step earlier than it used to be.
*
* Note the refit loop was never the exposure: finegray_cif.ado already skips a
* nonconverged refit (`if e(converged) != 1 continue') and finegray_predict.ado
* already turns one into rc 498. The hole was the MAIN fit feeding
* post-estimation unchecked, which is what the gate below asserts.
*
* We also keep the two invariants this test used to carry: the below-floor
* replication count is rejected, and no replication goes unaccounted for.
local ++test_count
capture noisily {
    _mk_hypoxia_112

    * (a) a nonconverged fit posts, but no post-estimation command will take it
    capture noisily finegray ifp tumsize pelnode, compete(status) cause(1) nolog ///
        iterate(1) tolerance(1e-20)
    assert _rc == 0
    assert e(converged) == 0
    capture finegray_cif, attime(5) ci bootstrap(25) seed(112)
    assert _rc == 430

    * (b) a below-floor replication count is rejected up front (min 25)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert e(converged) == 1
    capture finegray_cif, attime(5) ci bootstrap(1) seed(112)
    assert _rc == 198

    * (c) every requested replication is accounted for as success or failure
    quietly finegray_cif, attime(5) ci bootstrap(25) seed(112)
    assert r(bootstrap_requested) == 25
    assert r(bootstrap_success) + r(bootstrap_failed) == r(bootstrap_requested)
}
if _rc == 0 {
    display as result "  PASS: nonconverged fits cannot be bootstrapped; replications all accounted"
    local ++pass_count
}
else {
    display as error "  FAIL: bootstrap convergence gate (rc=`=_rc')"
    local ++fail_count
}

**# 9. Bootstrap skips only nonconverged refits and restores estimates
local ++test_count
capture noisily {
    _mk_hypoxia_112
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog ///
        iterate(4) tolerance(1e-6)
    assert e(converged) == 1
    matrix partial_b = e(b)
    tempvar partial_sample
    quietly gen byte `partial_sample' = e(sample)
    quietly count if `partial_sample'
    local partial_N = r(N)

    * Request comfortably ABOVE the replication floor (25). The point of this
    * test is that some refits fail and are skipped while the band is still built
    * from the survivors -- so the request must leave enough headroom for those
    * failures to occur without dropping the success count under the floor.
    * Requesting exactly 25 made any single failure a hard 498.
    quietly finegray_cif, attime(5) ci bootstrap(60) seed(911)
    local partial_requested = r(bootstrap_requested)
    local partial_success = r(bootstrap_success)
    local partial_failed = r(bootstrap_failed)
    matrix partial_table = r(table)

    display as text "  bootstrap: `partial_success' succeeded, `partial_failed' skipped of `partial_requested'"
    assert `partial_requested' == 60
    assert `partial_success' >= 25                       // floor honoured
    assert `partial_success' < `partial_requested'       // some genuinely failed
    assert `partial_failed' == `partial_requested' - `partial_success'
    assert partial_table[1,3] < . & partial_table[1,4] < . & partial_table[1,5] < .
    assert "`e(cmd)'" == "finegray"
    assert mreldif(e(b), partial_b) < 1e-12
    quietly count if e(sample) != `partial_sample'
    assert r(N) == 0
    quietly count if e(sample)
    assert r(N) == `partial_N'
}
if _rc == 0 {
    display as result "  PASS: partial bootstrap failures are skipped and state restored"
    local ++pass_count
}
else {
    display as error "  FAIL: partial bootstrap skip/restore (rc=`=_rc')"
    local ++fail_count
}

**# 10. finegray_predict does not leak helper r() results
local ++test_count
capture noisily {
    _mk_hypoxia_112
    quietly finegray ifp tumsize, compete(status) cause(1) nolog
    quietly summarize ifp, meanonly
    quietly finegray_predict xb_clean, xb
    capture confirm scalar r(N)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: finegray_predict does not leak helper r()"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_predict r() leak (rc=`=_rc')"
    local ++fail_count
}


**# ==================================================================
**# Section from test_finegray_v114.do
**# ==================================================================


* Competing-risks data with a rare factor level (level 3: two subjects), so
* that bootstrap resamples can lose the level and the refit posts a shorter
* coefficient vector.
capture program drop _mk_rarelvl_114
program define _mk_rarelvl_114
    clear
    set seed 42
    quietly set obs 120
    gen long id = _n
    gen byte grp = 1 + (_n > 60) + (_n >= 119)
    gen double x = rnormal()
    gen double t = -ln(runiform()) * 2
    gen byte ev = 0
    quietly replace ev = 1 if mod(_n, 3) == 0
    quietly replace ev = 2 if mod(_n, 5) == 0 & ev == 0
    quietly stset t, failure(ev) id(id)
end

**# 1. finegray_cif bootstrap skips level-dropping refits
* Pre-1.1.4 these replications "succeeded" while silently pairing the shorter
* refit e(b) against the full covariate profile; the skip is the regression
* signal: at least one replication must now be counted as failed.
*
* 40 replications, not 20: level 3 holds two subjects, so roughly a fifth of
* the resamples lose it and are skipped.  Since 1.2.0 the bootstrap requires 25
* SUCCESSFUL replications (FG-M07), so the request has to leave headroom for the
* skips this test exists to produce.  That makes this the "some fail, enough
* survive" path -- the one a real user with a rare level actually lands on.
local ++test_count
capture noisily {
    _mk_rarelvl_114
    quietly finegray i.grp x, compete(ev) cause(1) nolog
    finegray_cif, attime(1) ci bootstrap(40) seed(7) nograph
    assert r(bootstrap_requested) == 40
    assert r(bootstrap_failed) > 0
    assert r(bootstrap_success) >= 25
    assert r(bootstrap_success) + r(bootstrap_failed) == 40
    matrix _T114 = r(table)
    assert _T114[1, 3] > 0 & _T114[1, 3] < .
    matrix drop _T114
}
if _rc == 0 {
    display as result "  PASS: finegray_cif bootstrap skips level-dropping refits"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_cif bootstrap level-drop guard (rc=`=_rc')"
    local ++fail_count
}

**# 2. finegray_predict bootstrap survives level-dropping refits
* Pre-1.1.4 this aborted with a Mata conformability error r(3200).
local ++test_count
capture noisily {
    _mk_rarelvl_114
    quietly finegray i.grp x, compete(ev) cause(1) nolog
    gen double t1 = 1
    finegray_predict cb, cif timevar(t1) ci bootstrap(40) seed(7)
    confirm variable cb
    confirm variable cb_lci
    confirm variable cb_uci
    quietly count if cb < . & cb_lci < . & cb_uci < . & e(sample)
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: finegray_predict bootstrap skips level-dropping refits"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_predict bootstrap level-drop guard (rc=`=_rc')"
    local ++fail_count
}

**# 3. saving(filename,replace) without a space after the comma
local ++test_count
capture noisily {
    _mk_rarelvl_114
    quietly finegray i.grp x, compete(ev) cause(1) nolog
    local _sv "`c(tmpdir)'/fg114_save.dta"
    capture erase "`_sv'"
    finegray_cif, nograph saving("`_sv'",replace)
    confirm file "`_sv'"
    * spaced form still works, replace honored
    finegray_cif, nograph saving("`_sv'", replace)
    confirm file "`_sv'"
    erase "`_sv'"
    * junk suboptions are still rejected
    capture finegray_cif, nograph saving("`_sv'", junk)
    assert _rc == 198
    capture confirm file "`_sv'"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: saving(filename,replace) comma parsing"
    local ++pass_count
}
else {
    display as error "  FAIL: saving(filename,replace) comma parsing (rc=`=_rc')"
    local ++fail_count
}

**# 4. finegray_predict drops created variables on error
* A pre-existing <newvar>_lci makes the ci path fail after the point CIF has
* been generated; the failed call must not leave the point CIF behind.
local ++test_count
capture noisily {
    _mk_rarelvl_114
    quietly finegray i.grp x, compete(ev) cause(1) nolog
    gen double pc_lci = .
    capture finegray_predict pc, cif ci
    assert _rc == 110
    capture confirm variable pc
    assert _rc != 0
    capture confirm variable pc_uci
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: finegray_predict all-or-nothing output on error"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_predict error-path variable cleanup (rc=`=_rc')"
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

