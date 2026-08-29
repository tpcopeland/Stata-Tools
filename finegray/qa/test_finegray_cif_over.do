* test_finegray_cif_over.do
* finegray_cif, over(varname): one curve per level in one call.
*
* The contract under test is IDENTITY: every overlaid curve must equal the
* standalone at()/bstratum() call bit for bit (mreldif == 0, not a tolerance),
* because over() is nothing but the one-profile path run once per level.  A
* tolerance here would let a level-to-profile mispairing (the level-2 curve
* drawn from the level-3 indicator) hide inside "close enough".
*
*   OV-01  direct 0/1 covariate (hiv_si ccr5): table blocks, r(at) rows,
*          r(over)/r(levels), the sixth r(table) column
*   OV-02  curve mode on the default grid, and saving(): one dataset, an
*          `over' variable carrying the source value label
*   OV-03  factor variable in an interaction with at() on the other part
*   OV-04  over(bstrata variable): each stratum its own grid; refusal with
*          bstratum()
*   OV-05  bootstrap(): one replication loop serves every curve, and with the
*          same seed each curve equals its standalone bootstrap
*   OV-06  tvc() fit: the piecewise branch goes through the same loop
*   OV-07  refusals: over()+at() on the same variable, a non-model variable,
*          a continuous covariate (> 20 levels), a nonexistent variable
*   OV-08  no over(): r(table) keeps five columns and r(at) one row
*   OV-09  a failed saving() still posts the full r() surface (side rc)

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_cif_over.log", replace name(_ov)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* Compare rows r0..r0+n-1, columns 1-5, of a stacked over() table with a
* standalone table.  Exact equality: mreldif must be 0.
capture program drop _ov_block
program define _ov_block, rclass
    version 16.0
    args stacked r0 n standalone
    tempname blk
    matrix `blk' = `stacked'[`r0'..`=`r0'+`n'-1', 1..5]
    return scalar d = mreldif(`blk', `standalone')
    return scalar rows_ok = (rowsof(`standalone') == `n')
end

capture program drop _ov_hypoxia
program define _ov_hypoxia
    webuse hypoxia, clear
    gen byte status = failtype
    quietly stset dftime, failure(dfcens==1) id(stnum)
end

**# OV-01: direct covariate, table mode
local ++test_count
capture noisily {
    webuse hiv_si, clear
    gen byte any_event = status > 0
    quietly stset time, failure(any_event==1) id(patnr)
    quietly finegray ccr5, compete(status) cause(2)
    quietly finegray_cif, over(ccr5) attime(2 5 10) ci
    matrix T = r(table)
    matrix A = r(at)
    assert colsof(T) == 6
    assert rowsof(T) == 6
    assert "`r(over)'" == "ccr5"
    assert "`r(levels)'" == "0 1"
    assert "`r(se_method)'" == "analytic"
    assert rowsof(A) == 2 & colsof(A) == 1
    assert A[1,1] == 0 & A[2,1] == 1
    local rn : rownames A
    assert "`rn'" == "0 1"
    local cn : colnames T
    assert "`cn'" == "time cif se lci uci over"
    forvalues r = 1/3 {
        assert T[`r', 6] == 0
        assert T[`=`r'+3', 6] == 1
    }
    quietly finegray_cif, at(ccr5=0) attime(2 5 10) ci nograph
    matrix S0 = r(table)
    _ov_block T 1 3 S0
    assert r(d) == 0 & r(rows_ok)
    quietly finegray_cif, at(ccr5=1) attime(2 5 10) ci nograph
    matrix S1 = r(table)
    _ov_block T 4 3 S1
    assert r(d) == 0 & r(rows_ok)
    * The two curves differ (positive control: the identity is not vacuous)
    assert mreldif(S0, S1) > 1e-6
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: OV-01 direct covariate table identity"
}
else {
    local ++fail_count
    display as error "  FAIL: OV-01 direct covariate table identity (rc=`=_rc')"
}

**# OV-02: curve mode on the default grid, graph drawn, saving()
local ++test_count
capture noisily {
    label define _ovlbl 0 "WW" 1 "WM"
    label values ccr5 _ovlbl
    tempfile ovsave
    finegray_cif, over(ccr5) ci saving("`ovsave'", replace)
    matrix TC = r(table)
    quietly finegray_cif, at(ccr5=0) ci nograph
    matrix C0 = r(table)
    local n0 = rowsof(C0)
    quietly finegray_cif, at(ccr5=1) ci nograph
    matrix C1 = r(table)
    local n1 = rowsof(C1)
    assert rowsof(TC) == `n0' + `n1'
    _ov_block TC 1 `n0' C0
    assert r(d) == 0
    _ov_block TC `=`n0'+1' `n1' C1
    assert r(d) == 0
    preserve
    use "`ovsave'", clear
    unab vars : _all
    assert "`vars'" == "time cif se lci uci over"
    assert _N == `n0' + `n1'
    quietly count if over == 0
    assert r(N) == `n0'
    quietly count if over == 1
    assert r(N) == `n1'
    local vl : value label over
    assert "`vl'" == "_ovlbl"
    local l1 : label (over) 1
    assert "`l1'" == "WM"
    * The saved rows are the r(table) rows: no display-only origin/terminal
    * rows leaked into the export.
    quietly count if time == 0
    assert r(N) == 0
    restore
    * Read-only: no design or scratch column left behind
    unab after : _all
    assert "`after'" == "patnr time status ccr5 any_event _st _d _t _t0"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: OV-02 curve mode identity and saving()"
}
else {
    local ++fail_count
    display as error "  FAIL: OV-02 curve mode identity and saving() (rc=`=_rc')"
}

**# OV-03: factor variable in an interaction, at() on the other part
local ++test_count
capture noisily {
    _ov_hypoxia
    quietly finegray i.pelnode c.ifp i.pelnode#c.ifp tumsize, compete(status) cause(1)
    quietly finegray_cif, over(pelnode) at(ifp=20) attime(1 5) ci nograph
    matrix T = r(table)
    matrix A = r(at)
    assert "`r(profile_vars)'" == "1.pelnode ifp 1.pelnode#c.ifp tumsize"
    * Row 2 of r(at) is the pelnode = 1 profile: indicator 1, interaction 20
    assert A[2,1] == 1 & A[2,2] == 20 & A[2,3] == 20
    assert A[1,1] == 0 & A[1,2] == 20 & A[1,3] == 0
    quietly finegray_cif, at(pelnode=0 ifp=20) attime(1 5) ci nograph
    matrix S0 = r(table)
    _ov_block T 1 2 S0
    assert r(d) == 0
    quietly finegray_cif, at(pelnode=1 ifp=20) attime(1 5) ci nograph
    matrix S1 = r(table)
    _ov_block T 3 2 S1
    assert r(d) == 0
    * Curve mode draws, with graph, and stacks the default grid
    finegray_cif, over(pelnode) at(ifp=20)
    assert colsof(r(table)) == 6
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: OV-03 factor/interaction identity"
}
else {
    local ++fail_count
    display as error "  FAIL: OV-03 factor/interaction identity (rc=`=_rc')"
}

**# OV-04: over(bstrata variable)
local ++test_count
capture noisily {
    _ov_hypoxia
    quietly finegray ifp tumsize, compete(status) cause(1) bstrata(pelnode)
    quietly finegray_cif, over(pelnode) attime(1 5) ci
    matrix T = r(table)
    assert "`r(over)'" == "pelnode"
    assert "`r(bstrata)'" == "pelnode"
    assert "`r(levels)'" == "0 1"
    quietly finegray_cif, bstratum(0) attime(1 5) ci nograph
    matrix S0 = r(table)
    _ov_block T 1 2 S0
    assert r(d) == 0
    quietly finegray_cif, bstratum(1) attime(1 5) ci nograph
    matrix S1 = r(table)
    _ov_block T 3 2 S1
    assert r(d) == 0
    * Default grid: each stratum on its OWN event times, so the blocks have
    * different lengths and each equals its standalone curve.
    quietly finegray_cif, over(pelnode) ci nograph
    matrix TC = r(table)
    quietly finegray_cif, bstratum(0) ci nograph
    matrix C0 = r(table)
    local n0 = rowsof(C0)
    quietly finegray_cif, bstratum(1) ci nograph
    matrix C1 = r(table)
    local n1 = rowsof(C1)
    assert `n0' != `n1'
    assert rowsof(TC) == `n0' + `n1'
    _ov_block TC 1 `n0' C0
    assert r(d) == 0
    _ov_block TC `=`n0'+1' `n1' C1
    assert r(d) == 0
    * over() on the bstrata variable stands in for bstratum(); both is refused
    capture finegray_cif, over(pelnode) bstratum(0) attime(1) nograph
    assert _rc == 198
    * ...and bstratum() alone is still required without over()
    capture finegray_cif, attime(1) nograph
    assert _rc == 198
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: OV-04 over(bstrata) identity and fences"
}
else {
    local ++fail_count
    display as error "  FAIL: OV-04 over(bstrata) identity and fences (rc=`=_rc')"
}

**# OV-05: bootstrap(): shared replications, per-curve identity with seed()
local ++test_count
capture noisily {
    _ov_hypoxia
    quietly finegray i.pelnode ifp tumsize, compete(status) cause(1)
    quietly finegray_cif, over(pelnode) attime(1 5) ci bootstrap(30) seed(42) nograph
    matrix T = r(table)
    assert "`r(se_method)'" == "bootstrap"
    assert r(bootstrap_requested) == 30
    assert !missing(r(bootstrap_success)) & !missing(r(bootstrap_failed))
    assert r(bootstrap_success) + r(bootstrap_failed) == 30
    assert r(bootstrap_success) >= 25
    quietly finegray_cif, at(pelnode=0) attime(1 5) ci bootstrap(30) seed(42) nograph
    matrix S0 = r(table)
    _ov_block T 1 2 S0
    assert r(d) == 0
    quietly finegray_cif, at(pelnode=1) attime(1 5) ci bootstrap(30) seed(42) nograph
    matrix S1 = r(table)
    _ov_block T 3 2 S1
    assert r(d) == 0
    * The user's fit survives the refits
    assert "`e(cmd)'" == "finegray"
    assert e(converged) == 1
    quietly count if e(sample)
    assert !missing(r(N)) & r(N) > 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: OV-05 bootstrap identity"
}
else {
    local ++fail_count
    display as error "  FAIL: OV-05 bootstrap identity (rc=`=_rc')"
}

**# OV-06: tvc() fit goes through the same loop
local ++test_count
capture noisily {
    _ov_hypoxia
    quietly finegray i.pelnode ifp tumsize, compete(status) cause(1) tvc(ifp) tsplit(2)
    quietly finegray_cif, over(pelnode) attime(1 5) ci nograph
    matrix T = r(table)
    quietly finegray_cif, at(pelnode=0) attime(1 5) ci nograph
    matrix S0 = r(table)
    _ov_block T 1 2 S0
    assert r(d) == 0
    quietly finegray_cif, at(pelnode=1) attime(1 5) ci nograph
    matrix S1 = r(table)
    _ov_block T 3 2 S1
    assert r(d) == 0
    assert T[1,3] < . & T[3,3] < .
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: OV-06 tvc() identity"
}
else {
    local ++fail_count
    display as error "  FAIL: OV-06 tvc() identity (rc=`=_rc')"
}

**# OV-07: refusals
local ++test_count
capture noisily {
    _ov_hypoxia
    quietly finegray i.pelnode ifp tumsize, compete(status) cause(1)
    capture finegray_cif, over(pelnode) at(pelnode=1) attime(1) nograph
    assert _rc == 198
    capture finegray_cif, over(dftime) attime(1) nograph
    assert _rc == 198
    capture finegray_cif, over(ifp) attime(1) nograph
    assert _rc == 198
    capture finegray_cif, over(nosuchvar) attime(1) nograph
    assert _rc == 111
    * A refusal leaves r() empty: nothing from an earlier call survives
    quietly finegray_cif, attime(1) nograph
    capture finegray_cif, over(ifp) attime(1) nograph
    assert _rc == 198
    assert "`r(over)'" == ""
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: OV-07 refusals"
}
else {
    local ++fail_count
    display as error "  FAIL: OV-07 refusals (rc=`=_rc')"
}

**# OV-08: without over(), the documented five-column surface is unchanged
local ++test_count
capture noisily {
    _ov_hypoxia
    quietly finegray i.pelnode ifp tumsize, compete(status) cause(1)
    quietly finegray_cif, attime(1 5) ci nograph
    assert colsof(r(table)) == 5
    local cn : colnames r(table)
    assert "`cn'" == "time cif se lci uci"
    assert rowsof(r(at)) == 1
    assert "`r(over)'" == "" & "`r(levels)'" == ""
    tempfile plain
    quietly finegray_cif, ci nograph saving("`plain'", replace)
    preserve
    use "`plain'", clear
    unab vars : _all
    assert "`vars'" == "time cif se lci uci"
    restore
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: OV-08 no-over() surface unchanged"
}
else {
    local ++fail_count
    display as error "  FAIL: OV-08 no-over() surface unchanged (rc=`=_rc')"
}

**# OV-09: a failed saving() with over() still posts the analytical payload
local ++test_count
capture noisily {
    _ov_hypoxia
    quietly finegray i.pelnode ifp tumsize, compete(status) cause(1)
    capture finegray_cif, over(pelnode) ci nograph ///
        saving("`c(tmpdir)'/no_such_dir_ov/x.dta", replace)
    assert _rc != 0
    assert colsof(r(table)) == 6
    assert "`r(over)'" == "pelnode"
    assert "`r(levels)'" == "0 1"
    assert rowsof(r(at)) == 2
    * and the caller's data are intact
    assert "`e(cmd)'" == "finegray"
    quietly count if e(sample)
    assert !missing(r(N)) & r(N) > 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: OV-09 side-effect failure keeps r()"
}
else {
    local ++fail_count
    display as error "  FAIL: OV-09 side-effect failure keeps r() (rc=`=_rc')"
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_cif_over tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _ov
    exit 1
}
display as result "ALL TESTS PASSED"
log close _ov
