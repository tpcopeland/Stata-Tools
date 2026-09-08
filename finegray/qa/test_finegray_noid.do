*! test_finegray_noid.do - stset without id(): each record is one subject
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Before 1.3.2 finegray refused any stset declaration that carried no id()
* ("finegray requires stset with id() variable", r(198)), including on data
* with one record per subject, where id() carries no information: stset
* itself treats an id()-less record as its own subject, and stsplit and
* (start,stop] data require id(), so an id()-less declaration IS the
* single-record case.  The fit now keys its subject-level machinery by row
* and posts an empty e(idvar).
*
* Every block fits the SAME data twice -- once stset with id(), once without
* -- and asserts the two fits are bit-identical, so the row key can only pass
* by being an id.  Post-estimation, delayed entry, cluster(), pweights (whose
* weight digest is keyed by e(idvar) and degrades to value-only without it)
* and the bootstrap refit (which stamps its own st_id on the resample) are
* each exercised on the id()-less fit.

clear all
set more off
set varabbrev off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
capture log close _all
log using "test_finegray_noid.log", replace text name(_test_finegray_noid)
do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap

capture program drop _fgni_data
program define _fgni_data
    clear
    set seed 20260908
    set obs 300
    generate long id = 1000 + _n
    generate double x1 = rnormal()
    generate byte grp = 1 + mod(_n, 3)
    generate byte ctr = 1 + mod(_n, 6)
    generate double u = runiform()
    generate byte status = cond(u < 0.35, 1, cond(u < 0.6, 2, 0))
    generate double time = 0.5 + 6 * runiform()
    generate double entry = 0.3 * runiform()
    generate double pw = 0.5 + runiform()
    generate byte marker = 41
    drop u
end

capture program drop _fgni_record
program define _fgni_record
    args rc label
    if `rc' == 0 display as result "  PASS: `label'"
    else display as error "  FAIL: `label' (error `rc')"
end

* Run a command with its output logged to a tempfile and return the log text
* in r(blob), so a test can assert on what was (not) printed.
capture program drop _fgni_capture
program define _fgni_capture, rclass
    gettoken cmd 0 : 0
    tempfile lg
    tempname fh
    capture log close _fgni_lg
    log using "`lg'", text replace name(_fgni_lg)
    capture noisily `cmd'
    local rc = _rc
    log close _fgni_lg
    local blob ""
    file open `fh' using "`lg'", read text
    file read `fh' line
    while r(eof) == 0 {
        local blob `"`blob' `line'"'
        file read `fh' line
    }
    file close `fh'
    return local blob `"`blob'"'
    return scalar rc = `rc'
end

* -----------------------------------------------------------------------------
**# NI-01  Fit identity: stset with id() == stset without id(), no residue
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgni_data
    quietly stset time, failure(status) id(id)
    finegray x1 i.grp, compete(status) cause(1) nolog
    assert "`e(idvar)'" == "id"
    tempname b_id V_id
    matrix `b_id' = e(b)
    matrix `V_id' = e(V)
    local ll_id = e(ll)
    local N_id = e(N)
    local Nf_id = e(N_fail)
    local Nc_id = e(N_compete)

    quietly stset time, failure(status)
    assert `"`_dta[st_id]'"' == ""
    quietly describe, varlist
    local vars_before "`r(varlist)'"
    _fgni_capture `"finegray x1 i.grp, compete(status) cause(1) nolog"'
    display as text "  NI-01 rc = `r(rc)'"
    assert r(rc) == 0
    assert strpos(`"`r(blob)'"', "requires stset with id()") == 0
    assert "`e(idvar)'" == ""
    assert "`e(entryvar)'" == ""
    assert e(N) == `N_id'
    assert e(N_fail) == `Nf_id'
    assert e(N_compete) == `Nc_id'
    assert e(ll) == `ll_id'
    assert mreldif(e(b), `b_id') == 0
    assert mreldif(e(V), `V_id') == 0
    * the row key is a tempvar: nothing is left in the data, and stset's own
    * characteristic is not repointed at it.  Set equality, not string
    * equality: the fit re-creates its _fg_* design columns at the end of the
    * dataset, so the order changes while the membership must not.
    quietly describe, varlist
    local vars_after "`r(varlist)'"
    assert `: list vars_after === vars_before'
    assert `"`_dta[st_id]'"' == ""
    assert marker[1] == 41
    * replay still works
    finegray
    assert mreldif(e(b), `b_id') == 0
}
local block_rc = _rc
_fgni_record `block_rc' "NI-01 fit without id() is bit-identical to the id() fit and leaves no residue"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

* -----------------------------------------------------------------------------
**# NI-02  Post-estimation on the id()-less fit reproduces the id() fit
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgni_data
    quietly stset time, failure(status) id(id)
    quietly finegray x1 i.grp, compete(status) cause(1) nolog
    quietly finegray_cif, at(x1=0.3 grp=2) attime(1 2.5 4) ci nograph
    tempname tab_id
    matrix `tab_id' = r(table)
    quietly finegray_predict double cif_id, cif ci
    quietly finegray_predict double sch_id, schoenfeld
    quietly finegray_predict double xb_id, xb
    quietly finegray_phtest
    tempname ph_id
    matrix `ph_id' = r(phtest)

    quietly stset time, failure(status)
    quietly finegray x1 i.grp, compete(status) cause(1) nolog
    assert "`e(idvar)'" == ""
    finegray_cif, at(x1=0.3 grp=2) attime(1 2.5 4) ci nograph
    assert "`r(se_method)'" == "analytic"
    assert mreldif(r(table), `tab_id') == 0
    finegray_predict double cif_ni, cif ci
    assert cif_ni == cif_id
    assert cif_ni_lci == cif_id_lci
    assert cif_ni_uci == cif_id_uci
    finegray_predict double sch_ni, schoenfeld
    assert sch_ni == sch_id if !missing(sch_id)
    assert missing(sch_ni) if missing(sch_id)
    finegray_predict double xb_ni, xb
    assert xb_ni == xb_id
    finegray_phtest
    assert mreldif(r(phtest), `ph_id') == 0
}
local block_rc = _rc
_fgni_record `block_rc' "NI-02 cif, predict (cif ci, schoenfeld, xb) and phtest agree without id()"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

* -----------------------------------------------------------------------------
**# NI-03  Delayed entry and cluster() on single-record data without id()
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgni_data
    quietly stset time, failure(status) id(id) enter(time entry)
    quietly finegray x1 i.grp, compete(status) cause(1) cluster(ctr) nolog
    assert !missing(e(N_delayed))
    assert e(N_delayed) > 0
    tempname b_id V_id
    matrix `b_id' = e(b)
    matrix `V_id' = e(V)
    local ll_id = e(ll)
    local Nd_id = e(N_delayed)
    local Ncl_id = e(N_clust)

    quietly stset time, failure(status) enter(time entry)
    finegray x1 i.grp, compete(status) cause(1) cluster(ctr) nolog
    assert "`e(idvar)'" == ""
    assert "`e(clustvar)'" == "ctr"
    assert e(N_delayed) == `Nd_id'
    assert e(N_clust) == `Ncl_id'
    assert e(ll) == `ll_id'
    assert mreldif(e(b), `b_id') == 0
    assert mreldif(e(V), `V_id') == 0
}
local block_rc = _rc
_fgni_record `block_rc' "NI-03 delayed entry + cluster() without id() match the id() fit"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

* -----------------------------------------------------------------------------
**# NI-04  pweight without id(): identical fit, value-only digest still guards
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgni_data
    quietly stset time, failure(status) id(id)
    quietly finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog
    tempname b_id V_id tab_id
    matrix `b_id' = e(b)
    matrix `V_id' = e(V)
    local ll_id = e(ll)
    local sumw_id = e(sum_w)
    quietly finegray_cif, at(x1=0.3 grp=2) attime(1 2.5) ci nograph
    matrix `tab_id' = r(table)

    quietly stset time, failure(status)
    finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog
    assert "`e(idvar)'" == ""
    assert "`e(wtype)'" == "pweight"
    assert e(sum_w) == `sumw_id'
    assert e(ll) == `ll_id'
    assert mreldif(e(b), `b_id') == 0
    assert mreldif(e(V), `V_id') == 0
    * a digest is still posted (value-only) and post-estimation reconciles
    * against it without the legacy "no weight digest" warning
    assert "`e(wsig)'" != ""
    assert e(wsig_n) == e(N)
    _fgni_capture `"finegray_cif, at(x1=0.3 grp=2) attime(1 2.5) ci nograph"'
    assert r(rc) == 0
    assert strpos(`"`r(blob)'"', "carries no weight digest") == 0
    assert strpos(`"`r(blob)'"', "id variable") == 0
    * the capture helper is rclass, so take the table from a fresh call
    quietly finegray_cif, at(x1=0.3 grp=2) attime(1 2.5) ci nograph
    assert mreldif(r(table), `tab_id') == 0
    * a changed weight is still refused: the digest sees the values
    quietly replace pw = pw * 2 in 1
    capture finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph
    assert _rc == 459
    quietly replace pw = pw / 2 in 1
    * a value-preserving exchange of two subjects' weights escapes a value-only
    * digest by construction; the datasignature over pw catches it instead
    local w1 = pw[1]
    local w2 = pw[2]
    quietly replace pw = `w2' in 1
    quietly replace pw = `w1' in 2
    capture finegray_cif, at(x1=0.3 grp=2) attime(1) ci nograph
    assert _rc == 459
}
local block_rc = _rc
_fgni_record `block_rc' "NI-04 pweight fit without id() matches; digest and datasignature still refuse changed weights"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

* -----------------------------------------------------------------------------
**# NI-05  Bootstrap refits on the id()-less fit (resample stamps its own id)
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgni_data
    quietly stset time, failure(status)
    quietly finegray x1 i.grp, compete(status) cause(1) nolog
    finegray_cif, at(x1=0.3 grp=2) attime(1 2.5) ci bootstrap(30) seed(20260908) nograph
    assert "`r(se_method)'" == "bootstrap"
    assert r(bootstrap_requested) == 30
    assert r(bootstrap_success) == 30
    assert r(bootstrap_failed) == 0
    assert r(table)[1, 2] < .
    * the caller's data are untouched: no id was written into stset's state
    assert `"`_dta[st_id]'"' == ""
    assert marker[1] == 41
    assert _N == 300
    finegray_predict double cifb, cif ci bootstrap(30) seed(20260908)
    assert cifb < . & cifb_lci < . & cifb_uci < .
}
local block_rc = _rc
_fgni_record `block_rc' "NI-05 finegray_cif and finegray_predict bootstrap run on the id()-less fit"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

* -----------------------------------------------------------------------------
**# NI-06  The multiple-record contract is unchanged when id() IS declared
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgni_data
    quietly stset time, failure(status) id(id)
    quietly finegray x1 i.grp, compete(status) cause(1) nolog
    tempname b_id
    matrix `b_id' = e(b)
    quietly stsplit sp, at(1 2 3)
    quietly bysort id (_t): replace status = status[_N]
    quietly finegray x1 i.grp, compete(status) cause(1) nolog
    assert "`e(idvar)'" == "id"
    assert "`e(entryvar)'" != ""
    assert mreldif(e(b), `b_id') == 0
    * a time-varying covariate under id() is still refused by name
    quietly bysort id (_t): replace x1 = x1 + 0.1 if _n > 1
    capture finegray x1 i.grp, compete(status) cause(1) nolog
    assert _rc == 198
}
local block_rc = _rc
_fgni_record `block_rc' "NI-06 with id() the multiple-record reduction and constancy refusal are unchanged"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_finegray_noid tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _test_finegray_noid
if `fail_count' > 0 exit 1
exit 0
