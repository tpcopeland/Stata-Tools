* test_iivw_v100_regressions.do
* Regressions found in the 1.0.0 release review.
* budget: 9
*
*   T1  iivw_fit saving() with a base-name suffix longer than 10 characters
*       (x.000002_quiet_sh1): Stata writes the name as-is, and the shard stamp
*       must find and stamp that file. Red before the fix: Mata pathsuffix()
*       returns "" for such a suffix, the stamp looked for the name + .dta and
*       exited r(601) after the bootstrap had already written the file.
*   T2  iivw_bspool reads those shards by the same rule and its saving()
*       writes the pooled file under the typed long-suffix name, not + .dta.
*   T3  guard: a plain name still gets .dta, and a dotted DIRECTORY with an
*       undotted base name still gets .dta (expected green before the fix).
*   T4  guard: saving(x.) writes x, and iivw_fit and iivw_bspool stamp it.
*   T5  the removed bootstrap(#) and refitweights options exit r(198).
*   T6  the removed model(), mixedopts() and experimentalmixed exit r(198).
*   T7  iivw_exogtest term, omnibus and Holm p-values at full double precision.
*   T8  experimentalnotreatvisit exits r(198); a pre-release treat-free contract
*       is refused (459) and a fresh weighting clears the marker.
*   T9  iivw_bspool against a pre-release treat-free contract names that cause,
*       not "the weighted data in memory has changed". Red before the fix:
*       the capture around the contract check swallowed the real reason.
* guard: T3 and T4 are expected green at HEAD (behaviour-preservation)
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_v100_regressions.do [case#]

clear all
set varabbrev off
version 16.0

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed ""

local qa_dir "`c(pwd)'"
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap

iivw_qa_selector `1'
local run_only = r(run_only)

tempfile _stub
local work "`_stub'_v100"
capture mkdir "`work'_dir"
capture mkdir "`work'_dir/run.v2"

capture program drop _v100_panel
program define _v100_panel
    version 16.0
    clear
    set seed 20260417
    quietly set obs 240
    quietly gen long id = ceil(_n/4)
    quietly bysort id: gen byte visit = _n
    quietly gen double time = 3 * (visit - 1) + runiform() * .05
    quietly replace time = 0 if visit == 1
    quietly gen double x = rnormal()
    quietly bysort id: replace x = x[1]
    quietly gen double y = 1 + .1 * time + x + rnormal()
    quietly iivw_weight, id(id) time(time) visit_cov(x) maxfu(12) nolog
end

* Stamp marker of a written file, read without disturbing the data.
capture program drop _v100_marker
program define _v100_marker, rclass
    version 16.0
    syntax , FILE(string)
    preserve
    quietly use `"`file'"', clear
    local m : char _dta[_iivw_shard]
    restore
    return local marker "`m'"
end

local d "`work'_dir"

local ++test_count
if `run_only' == 0 | `run_only' == 1 {
capture noisily {
    _v100_panel
    capture erase "`d'/x.000002_quiet_sh1"
    capture erase "`d'/x.000002_quiet_sh1.dta"
    capture noisily quietly iivw_fit y x, citype(percentile) ///
        vce(bootstrap, reps(10) seed(7)) rngstream(1) ///
        saving("`d'/x.000002_quiet_sh1", replace) nolog allowfailedreps
    assert _rc == 0
    confirm file "`d'/x.000002_quiet_sh1"
    capture confirm file "`d'/x.000002_quiet_sh1.dta"
    assert _rc != 0
    _v100_marker, file("`d'/x.000002_quiet_sh1")
    assert "`r(marker)'" == "1"
    display as result "T1 PASS: long-suffix shard written and stamped as typed"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T1"
    display as error "T1 FAIL"
}
}

local ++test_count
if `run_only' == 0 | `run_only' == 2 {
capture noisily {
    _v100_panel
    foreach k in 1 2 {
        capture noisily quietly iivw_fit y x, citype(percentile) ///
            vce(bootstrap, reps(10) seed(7)) rngstream(`k') ///
            saving("`d'/x.000002_quiet_sh`k'", replace) nolog allowfailedreps
        assert _rc == 0
    }
    capture erase "`d'/pool.000002_pooled_out"
    capture erase "`d'/pool.000002_pooled_out.dta"
    quietly iivw_bspool using "`d'/x.000002_quiet_sh1 `d'/x.000002_quiet_sh2", ///
        reps(20) saving("`d'/pool.000002_pooled_out", replace)
    assert e(N_reps) == 20
    confirm file "`d'/pool.000002_pooled_out"
    capture confirm file "`d'/pool.000002_pooled_out.dta"
    assert _rc != 0
    _v100_marker, file("`d'/pool.000002_pooled_out")
    assert "`r(marker)'" == "1"
    display as result "T2 PASS: bspool reads and writes long-suffix names as typed"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T2"
    display as error "T2 FAIL"
}
}

local ++test_count
if `run_only' == 0 | `run_only' == 3 {
capture noisily {
    _v100_panel
    capture erase "`d'/plain.dta"
    capture erase "`d'/run.v2/sh.dta"
    capture noisily quietly iivw_fit y x, citype(percentile) ///
        vce(bootstrap, reps(10) seed(7)) rngstream(1) ///
        saving("`d'/plain", replace) nolog allowfailedreps
    assert _rc == 0
    confirm file "`d'/plain.dta"
    capture noisily quietly iivw_fit y x, citype(percentile) ///
        vce(bootstrap, reps(10) seed(7)) rngstream(2) ///
        saving("`d'/run.v2/sh", replace) nolog allowfailedreps
    assert _rc == 0
    confirm file "`d'/run.v2/sh.dta"
    _v100_marker, file("`d'/run.v2/sh.dta")
    assert "`r(marker)'" == "1"
    display as result "T3 PASS: undotted base names still take .dta"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T3"
    display as error "T3 FAIL"
}
}

local ++test_count
if `run_only' == 0 | `run_only' == 4 {
capture noisily {
    * Guard. Stata writes saving(x.) as the file x, and resolves "x." to that
    * same file on later reads, so the stamp finds and marks what was written.
    * Pinned so a future suffix rule cannot break the round trip.
    _v100_panel
    capture erase "`d'/trail"
    capture noisily quietly iivw_fit y x, citype(percentile) ///
        vce(bootstrap, reps(10) seed(7)) rngstream(1) ///
        saving("`d'/trail.", replace) nolog allowfailedreps
    assert _rc == 0
    confirm file "`d'/trail"
    _v100_marker, file("`d'/trail.")
    assert "`r(marker)'" == "1"
    quietly iivw_fit y x, citype(percentile) ///
        vce(bootstrap, reps(10) seed(7)) rngstream(2) ///
        saving("`d'/trail2.", replace) nolog allowfailedreps
    capture erase "`d'/pooltrail"
    quietly iivw_bspool using "`d'/trail. `d'/trail2.", reps(20) ///
        saving("`d'/pooltrail.", replace)
    assert e(N_reps) == 20
    confirm file "`d'/pooltrail"
    _v100_marker, file("`d'/pooltrail.")
    assert "`r(marker)'" == "1"
    display as result "T4 PASS: saving(x.) round-trips through fit, stamp and pool"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T4"
    display as error "T4 FAIL"
}
}

local ++test_count
if `run_only' == 0 | `run_only' == 5 {
capture noisily {
    * bootstrap(#) and refitweights were removed in 1.0.0: vce() is the only
    * variance interface. Each now fails as an unknown option (native
    * r(198)), and nothing is estimated or posted.
    _v100_panel
    ereturn clear
    capture noisily iivw_fit y x, bootstrap(5) nolog
    assert _rc == 198
    assert "`e(cmd)'" == ""
    capture noisily iivw_fit y x, refitweights nolog
    assert _rc == 198
    capture noisily iivw_fit y x, vce(bootstrap, reps(5)) refitweights nolog
    assert _rc == 198
    assert "`e(cmd)'" == ""
    * The supported spelling of the same request still runs.
    capture noisily quietly iivw_fit y x, vce(bootstrap, reps(5) fixedweights) ///
        nolog allowfailedreps
    assert _rc == 0
    assert "`e(iivw_refitweights)'" == "0"
    display as result "T5 PASS: bootstrap() and refitweights are gone (r(198))"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T5"
    display as error "T5 FAIL"
}
}

local ++test_count
if `run_only' == 0 | `run_only' == 6 {
capture noisily {
    * The weighted mixed-model route was removed in 1.0.0: GEE is the only
    * outcome model. model(), mixedopts() and experimentalmixed are no longer
    * options, so each fails as an unknown option (native r(198)) and nothing
    * is posted; the GEE fit itself still runs and records e(iivw_model)=gee.
    _v100_panel
    foreach opt in "model(gee)" "model(mixed)" "mixedopts(iterate(5))" ///
        "experimentalmixed" "model(mixed) experimentalmixed" {
        ereturn clear
        capture noisily iivw_fit y x, vce(fixed) `opt' nolog
        assert _rc == 198
        assert "`e(cmd)'" == ""
    }
    quietly iivw_fit y x, vce(fixed) nolog
    assert "`e(iivw_model)'" == "gee"
    assert "`e(iivw_underlying_cmd)'" == "glm"
    display as result "T6 PASS: model(), mixedopts() and experimentalmixed are gone (r(198))"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T6"
    display as error "T6 FAIL"
}
}

local ++test_count
if `run_only' == 0 | `run_only' == 7 {
capture noisily {
    * iivw_exogtest carried each term's b/se/z/p, the omnibus p-values, the
    * Holm steps and the posted minima through `local x = expr', which keeps
    * about 15 significant digits (measured relative error 4.6e-14 on this
    * fixture). They are now exact doubles. Oracles, from r(results) b and se:
    *   term p   = 2*normal(-|b/se|)                     exact equality
    *   joint p  = chi2tail(1, (b/se)^2)  (one lag per group, so the omnibus
    *              test is that term's Wald test; -test- forms b^2/V, which
    *              differs from (b/se)^2 by a few ulp, hence 1e-14 not 0)
    *   Holm min = min(1, m * joint_min_p) exactly: the smallest Holm-adjusted
    *              p is always the smallest raw p times m, whatever the tie
    *              ranking among the others, so a rounding-induced tie cannot
    *              change r() beyond its last digits; this pins that identity.
    clear
    set seed 4401
    quietly set obs 400
    gen long id = ceil(_n/4)
    bysort id: gen byte visit = _n
    gen byte g = mod(id, 4)
    gen double y = rnormal()
    gen double time = 0
    quietly bysort id (visit): replace time = time[_n-1] + ///
        exp(rnormal() - 0.4*y[_n-1]) if _n > 1
    quietly iivw_exogtest y, id(id) time(time) maxfu(40) by(g) replace nolog
    tempname R JM HM
    matrix `R' = r(results)
    scalar `JM' = r(joint_min_p)
    scalar `HM' = r(holm_min_p)
    assert r(n_tests) == 4
    mata: _v100_R = st_matrix("`R'")
    mata: _v100_z = _v100_R[., 3] :/ _v100_R[., 4]
    mata: st_numscalar("v100_perr", max(abs(_v100_R[., 6] - 2*normal(-abs(_v100_z)))))
    mata: st_numscalar("v100_jp", min(chi2tail(1, _v100_z:^2)))
    mata: mata drop _v100_R _v100_z
    display as text "  term p max abs err = " v100_perr
    assert v100_perr == 0
    display as text "  joint_min rel err  = " abs(`JM' - v100_jp) / v100_jp
    assert !missing(`JM') & abs(`JM' - v100_jp) / v100_jp < 1e-14
    assert `HM' == min(1, 4 * `JM')
    display as result "T7 PASS: exogtest p-values and Holm minimum carried at full precision"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T7"
    display as error "T7 FAIL"
}
capture scalar drop v100_perr v100_jp
}

local ++test_count
if `run_only' == 0 | `run_only' == 8 {
capture noisily {
    * experimentalnotreatvisit was removed in 1.0.0: FIPTIW always puts treat()
    * in the visit-intensity model. The option fails as unknown (native r(198))
    * and leaves no weights; a contract a pre-release build marked as
    * treat-free (_iivw_treat_in_visit = 0) is refused (459) by every
    * consumer, and a fresh iivw_weight run clears the field.
    clear
    set seed 20260417
    quietly set obs 240
    quietly gen long id = ceil(_n/4)
    quietly bysort id: gen byte visit = _n
    quietly gen double time = 3 * (visit - 1) + runiform() * .05
    quietly replace time = 0 if visit == 1
    quietly gen double x = rnormal()
    quietly bysort id: replace x = x[1]
    quietly gen byte treated = runiform() < invlogit(.4 + .5 * x)
    quietly bysort id: replace treated = treated[1]
    quietly gen double y = 1 + .1 * time + x + rnormal()
    capture noisily iivw_weight, id(id) time(time) visit_cov(x) maxfu(12) ///
        treat(treated) treat_cov(x) wtype(fiptiw) experimentalnotreatvisit nolog
    assert _rc == 198
    capture confirm variable _iivw_weight
    assert _rc != 0
    quietly iivw_weight, id(id) time(time) visit_cov(x) maxfu(12) ///
        treat(treated) treat_cov(x) wtype(fiptiw) nolog
    assert "`r(visit_covars)'" == "x treated"
    local tiv : char _dta[_iivw_treat_in_visit]
    assert "`tiv'" == ""
    char _dta[_iivw_treat_in_visit] "0"
    capture noisily iivw_fit y treated x, vce(fixed) nolog
    assert _rc == 459
    capture noisily iivw_balance, nolog
    assert _rc == 459
    quietly iivw_weight, id(id) time(time) visit_cov(x) maxfu(12) ///
        treat(treated) treat_cov(x) wtype(fiptiw) replace nolog
    local tiv : char _dta[_iivw_treat_in_visit]
    assert "`tiv'" == ""
    quietly iivw_fit y treated x, vce(fixed) nolog
    assert "`e(iivw_weighttype)'" == "fiptiw"
    display as result "T8 PASS: experimentalnotreatvisit is gone (r(198)); old marked contracts refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T8"
    display as error "T8 FAIL"
}
}

local ++test_count
if `run_only' == 0 | `run_only' == 9 {
capture noisily {
    _v100_panel
    foreach k in 1 2 {
        capture noisily quietly iivw_fit y x, citype(percentile) ///
            vce(bootstrap, reps(10) seed(7)) rngstream(`k') ///
            saving("`d'/t9_sh`k'", replace) nolog allowfailedreps
        assert _rc == 0
    }
    char _dta[_iivw_treat_in_visit] "0"
    tempfile t9log
    local t9ls = c(linesize)
    set linesize 255
    quietly log using "`t9log'", text replace name(_t9)
    capture noisily iivw_bspool using "`d'/t9_sh1 `d'/t9_sh2", reps(20)
    local t9rc = _rc
    quietly log close _t9
    set linesize `t9ls'
    assert `t9rc' == 459
    local saw_cause 0
    local saw_changed 0
    tempname fh
    file open `fh' using "`t9log'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "weighted without treat() in the FIPTIW visit model") local saw_cause 1
        if strpos(`"`macval(line)'"', "has changed since the anchor was fit") local saw_changed 1
        file read `fh' line
    }
    file close `fh'
    assert `saw_cause' == 1
    assert `saw_changed' == 0
    char _dta[_iivw_treat_in_visit]
    quietly iivw_bspool using "`d'/t9_sh1 `d'/t9_sh2", reps(20)
    assert e(N_reps) == 20
    display as result "T9 PASS: bspool names the pre-release treat-free cause"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T9"
    display as error "T9 FAIL"
}
}

**# Summary

iivw_qa_summary, name(test_iivw_v100_regressions) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') runonly(`run_only') ///
    failedtests("`failed'")
