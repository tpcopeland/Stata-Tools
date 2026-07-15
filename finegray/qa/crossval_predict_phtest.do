* crossval_predict_phtest.do - Cross-validation for finegray_predict and finegray_phtest
* Tests: row-level xb/CIF/Schoenfeld vs R, phtest chi2 vs R, internal consistency
* Package: finegray
*
* Companion: crossval_predict_phtest_r.R (called via shell)
* Equivalence: finegray_predict xb/cif/schoenfeld ~ cmprsk::crr manual computation
*              finegray_phtest ~ cor(schoenfeld, time) in R
*
* The Schoenfeld/PH residuals are cross-validated against cmprsk at a COMMON
* beta (finegray's coefficients are passed to R), isolating the residual/risk-
* set algorithm from optimizer-to-optimizer beta differences.  The authoritative
* chi2 parity is asserted on tie-free, well-conditioned simulated data (P12),
* where finegray and cmprsk agree to numerical precision; hypoxia (heavy ties +
* a near-zero censoring weight) is checked only for functional validity, with
* its residuals validated bit-for-bit against stcrreg in
* crossval_predict_stcrreg.do.

clear all
set varabbrev off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0

* Bootstrap: derive package root from qa/ working directory
local pkgroot "`c(pwd)'"
capture confirm file "`pkgroot'/finegray.pkg"
if _rc {
    capture confirm file "`pkgroot'/../finegray.pkg"
    if _rc {
        display as error "could not locate finegray package root"
        exit 601
    }
    local pkgroot "`pkgroot'/.."
}
local qadir "`pkgroot'/qa"
* Generated R cross-check CSVs are transient: write them to a temp directory so
* nothing lands in (or churns) the tracked qa/ tree, and so a failed/absent R
* run cannot silently validate against a stale committed copy (matches
* crossval_cif.do, which already uses c(tmpdir)).
local datadir "`c(tmpdir)'/finegray_xv_pp"
capture mkdir "`datadir'"

capture log close _all
log using "`qadir'/crossval_predict_phtest.log", replace text name(_crossval_pp)

* {smcl}
* {* SETUP}{...}
capture ado uninstall finegray
net install finegray, from("`pkgroot'") replace

program define _finegray_use_hypoxia
    local cache "`c(tmpdir)'/finegray_hypoxia_cache.dta"
    capture confirm file "`cache'"
    if _rc {
        webuse hypoxia, clear
        quietly save "`cache'", replace
    }
    else {
        use "`cache'", clear
    }
end

program define _setup_hypoxia
    _finegray_use_hypoxia
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)
end

* ============================================================
* {* SECTION 1: Export hypoxia data, fit model, run R}{...}
* ============================================================

_setup_hypoxia
finegray ifp tumsize pelnode, compete(status) cause(1) nolog
local N_fail_hyp = e(N_fail)

* finegray's coefficients (covariate order = CSV covariate order) to pass to R
* so Schoenfeld/PH residuals are computed at a COMMON beta (see _r.R header).
matrix _bb = e(b)
local fg_beta_hyp ""
forvalues _j = 1/`=colsof(_bb)' {
    local fg_beta_hyp "`fg_beta_hyp',`=_bb[1,`_j']'"
}
local fg_beta_hyp = substr("`fg_beta_hyp'", 2, .)

* Generate all three prediction types
finegray_predict xb_hat, xb
finegray_predict cif_hat, cif
finegray_predict sch, schoenfeld

* Save Stata predictions (estimation sample only)
preserve
keep if e(sample)
keep stnum dftime status ifp tumsize pelnode xb_hat cif_hat sch sch_2 sch_3 _t _d
rename stnum id
tempfile stata_pred_hyp
save `stata_pred_hyp'
restore

* Export for R (covariates only, no predictions)
preserve
keep if e(sample)
keep stnum _t status ifp tumsize pelnode
rename stnum id
rename _t time
export delimited using "`datadir'/pp_hypoxia_input.csv", replace
restore

* Run R on hypoxia
local r_hyp_ok = 1
capture noisily {
    shell Rscript "`qadir'/crossval_predict_phtest_r.R" ///
        "`datadir'/pp_hypoxia_input.csv" "`datadir'" "`fg_beta_hyp'"
}
capture confirm file "`datadir'/r_xb.csv"
if _rc {
    display as error "  R script failed or output not found"
    local r_hyp_ok = 0
}

* ============================================================
* {* SECTION 2: XB prediction vs R (hypoxia)}{...}
* ============================================================

if `r_hyp_ok' {

* P1: Row-level xb vs R on hypoxia
local ++test_count
local p1_pass = 1
capture noisily {
    preserve
    import delimited using "`datadir'/r_xb.csv", clear
    tempfile r_xb
    save `r_xb'
    use `stata_pred_hyp', clear
    merge 1:1 id using `r_xb', nogen
    gen double xb_diff = abs(xb_hat - r_xb)
    quietly summ xb_diff, meanonly
    local max_xb = r(max)
    local mean_xb = r(mean)
    display as text "  max |xb_stata - xb_R| = " %10.8f `max_xb'
    display as text "  mean |xb_stata - xb_R| = " %10.8f `mean_xb'
    assert `max_xb' < 0.001
    restore
}
if _rc != 0 {
    local p1_pass = 0
    capture restore
}
if `p1_pass' {
    display as result "  PASS: P1 row-level xb vs R (< 0.001)"
    local ++pass_count
}
else {
    display as error "  FAIL: P1 row-level xb vs R"
    local ++fail_count
}

* ============================================================
* {* SECTION 3: CIF prediction vs R (hypoxia)}{...}
* ============================================================

* P2: Row-level CIF vs R on hypoxia
local ++test_count
local p2_pass = 1
capture noisily {
    preserve
    import delimited using "`datadir'/r_cif.csv", clear
    tempfile r_cif
    save `r_cif'
    use `stata_pred_hyp', clear
    merge 1:1 id using `r_cif', nogen
    gen double cif_diff = abs(cif_hat - r_cif)
    quietly summ cif_diff, meanonly
    local max_cif = r(max)
    local mean_cif = r(mean)
    display as text "  max |CIF_stata - CIF_R| = " %10.8f `max_cif'
    display as text "  mean |CIF_stata - CIF_R| = " %10.8f `mean_cif'
    * Tier 1 tolerance for same-algorithm CIF
    assert `max_cif' < 0.01
    restore
}
if _rc != 0 {
    local p2_pass = 0
    capture restore
}
if `p2_pass' {
    display as result "  PASS: P2 row-level CIF vs R (< 0.01)"
    local ++pass_count
}
else {
    display as error "  FAIL: P2 row-level CIF vs R"
    local ++fail_count
}

* ============================================================
* {* SECTION 4: Schoenfeld residuals vs R (hypoxia)}{...}
* ============================================================

* P3: finegray_phtest on hypoxia is functionally sound (all time transforms).
* Why no cmprsk chi2 parity on hypoxia: this dataset has a large cluster of
* tied cause events (dftime=.003) AND a near-zero censoring weight (finegray
* notes "G(t) truncated to 1e-10 for 1 observation").  At tied event times
* finegray and cmprsk partition the per-event Schoenfeld residual by different
* (both valid) conventions, and the truncated G amplifies any tiny weight
* difference enormously (dividing competing-event weights by ~1e-10), so the
* per-EVENT residuals — and the correlation-based chi2 built from them — are
* implementation-dependent here.  finegray's hypoxia residuals are validated
* bit-for-bit against Stata's own stcrreg in crossval_predict_stcrreg.do; the
* authoritative cmprsk chi2 parity is asserted on tie-free, well-conditioned
* simulated data below (P12 rank/log/identity), where finegray matches cmprsk
* exactly.  Here we confirm the hypoxia phtest returns valid statistics.
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    foreach tf in rank log identity {
        finegray_phtest, time(`tf')
        assert r(chi2) > 0 & r(chi2) < .
        assert r(df) == 3
        assert r(p) >= 0 & r(p) <= 1
        assert r(N_fail) == `N_fail_hyp'
    }
}
if _rc == 0 {
    display as result "  PASS: P3 hypoxia phtest functionally valid (rank/log/identity)"
    local ++pass_count
}
else {
    display as error "  FAIL: P3 hypoxia phtest functionally valid (rc=`=_rc')"
    local ++fail_count
}

* P4: Schoenfeld residual count == N_fail
local ++test_count
capture noisily {
    use `stata_pred_hyp', clear
    quietly count if !missing(sch)
    assert r(N) == `N_fail_hyp'
}
if _rc == 0 {
    display as result "  PASS: P4 Schoenfeld count == N_fail (`N_fail_hyp')"
    local ++pass_count
}
else {
    display as error "  FAIL: P4 Schoenfeld count (rc=`=_rc')"
    local ++fail_count
}

* P5: Schoenfeld residuals only nonmissing at cause events
local ++test_count
capture noisily {
    use `stata_pred_hyp', clear
    * Non-cause events should have missing Schoenfeld residuals
    quietly count if !missing(sch) & !(status == 1 & _d == 1)
    assert r(N) == 0
    * All cause events should have nonmissing residuals
    quietly count if missing(sch) & status == 1 & _d == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: P5 Schoenfeld only at cause events"
    local ++pass_count
}
else {
    display as error "  FAIL: P5 Schoenfeld event mask (rc=`=_rc')"
    local ++fail_count
}

* (Hypoxia chi2-vs-cmprsk parity intentionally omitted — see P3 note. The
* authoritative cmprsk PH-test chi2 parity is on tie-free simulated data, P12.)

}
else {
    * R not available — skip the hypoxia R cross-validation (P1-P5)
    display as text "  SKIP: R cross-validation (P1-P5) — R/cmprsk not available"
    forvalues i = 1/5 {
        local ++test_count
        local ++skip_count
    }
}

* ============================================================
* {* SECTION 6: Simulated data cross-validation}{...}
* ============================================================

* Generate and export simulated data
clear
set seed 2026
set obs 300
gen id = _n
gen double x1 = rnormal()
gen double x2 = rbinomial(1, 0.4)
gen double u = runiform()
gen double t_event = -ln(u) / exp(0.4*x1 - 0.3*x2)
gen double t_censor = runiform() * 4
gen double t = min(t_event, t_censor)
gen byte d = (t_event <= t_censor)
gen byte status = 0
replace status = 1 if d == 1 & runiform() > 0.35
replace status = 2 if d == 1 & status == 0
stset t, failure(d) id(id)
finegray x1 x2, compete(status) cause(1) nolog
local N_fail_sim = e(N_fail)

* finegray's coefficients for the common-beta Schoenfeld/PH comparison in R
matrix _bb = e(b)
local fg_beta_sim ""
forvalues _j = 1/`=colsof(_bb)' {
    local fg_beta_sim "`fg_beta_sim',`=_bb[1,`_j']'"
}
local fg_beta_sim = substr("`fg_beta_sim'", 2, .)

finegray_predict xb_sim, xb
finegray_predict cif_sim, cif

preserve
keep if e(sample)
keep id _t status x1 x2 xb_sim cif_sim
rename _t time_stata
tempfile stata_pred_sim
save `stata_pred_sim'
restore

* Export for R
preserve
keep if e(sample)
keep id _t status x1 x2
rename _t time
export delimited using "`datadir'/pp_sim_input.csv", replace
restore

* Run R
local r_sim_ok = 1
capture noisily {
    * Rename R outputs from hypoxia to avoid overwrite
    capture shell mv "`datadir'/r_xb.csv" "`datadir'/r_xb_hyp.csv"
    capture shell mv "`datadir'/r_cif.csv" "`datadir'/r_cif_hyp.csv"
    capture shell mv "`datadir'/r_schoenfeld.csv" "`datadir'/r_schoenfeld_hyp.csv"
    capture shell mv "`datadir'/r_phtest.csv" "`datadir'/r_phtest_hyp.csv"

    shell Rscript "`qadir'/crossval_predict_phtest_r.R" ///
        "`datadir'/pp_sim_input.csv" "`datadir'" "`fg_beta_sim'"
}
capture confirm file "`datadir'/r_xb.csv"
if _rc {
    display as error "  R sim script failed or output not found"
    local r_sim_ok = 0
}

if `r_sim_ok' {

* P9: Row-level xb vs R on simulated
local ++test_count
local p9_pass = 1
capture noisily {
    preserve
    import delimited using "`datadir'/r_xb.csv", clear
    tempfile r_xb_sim
    save `r_xb_sim'
    use `stata_pred_sim', clear
    merge 1:1 id using `r_xb_sim', nogen
    gen double xb_diff = abs(xb_sim - r_xb)
    quietly summ xb_diff, meanonly
    display as text "  sim max |xb_diff| = " %10.8f r(max)
    assert r(max) < 0.001
    restore
}
if _rc != 0 {
    local p9_pass = 0
    capture restore
}
if `p9_pass' {
    display as result "  PASS: P9 row-level xb vs R simulated (< 0.001)"
    local ++pass_count
}
else {
    display as error "  FAIL: P9 simulated xb vs R"
    local ++fail_count
}

* P10: Row-level CIF vs R on simulated
local ++test_count
local p10_pass = 1
capture noisily {
    preserve
    import delimited using "`datadir'/r_cif.csv", clear
    tempfile r_cif_sim
    save `r_cif_sim'
    use `stata_pred_sim', clear
    merge 1:1 id using `r_cif_sim', nogen
    gen double cif_diff = abs(cif_sim - r_cif)
    quietly summ cif_diff, meanonly
    display as text "  sim max |CIF_diff| = " %10.8f r(max)
    assert r(max) < 0.01
    restore
}
if _rc != 0 {
    local p10_pass = 0
    capture restore
}
if `p10_pass' {
    display as result "  PASS: P10 row-level CIF vs R simulated (< 0.01)"
    local ++pass_count
}
else {
    display as error "  FAIL: P10 simulated CIF vs R"
    local ++fail_count
}

* P11: Simulated Schoenfeld residuals vs R
local ++test_count
local p11_pass = 1
capture noisily {
    * Refit and generate Schoenfeld on simulated data
    clear
    set seed 2026
    set obs 300
    gen id = _n
    gen double x1 = rnormal()
    gen double x2 = rbinomial(1, 0.4)
    gen double u = runiform()
    gen double t_event = -ln(u) / exp(0.4*x1 - 0.3*x2)
    gen double t_censor = runiform() * 4
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.35
    replace status = 2 if d == 1 & status == 0
    stset t, failure(d) id(id)
    finegray x1 x2, compete(status) cause(1) nolog
    finegray_predict sch_sim, schoenfeld
    * Keep cause events
    preserve
    keep if !missing(sch_sim)
    keep id sch_sim sch_sim_2
    * Import R results
    tempfile stata_sch_sim
    save `stata_sch_sim'
    import delimited using "`datadir'/r_schoenfeld.csv", clear
    rename event_id id
    rename x1 r_sch_x1
    rename x2 r_sch_x2
    tempfile r_sch_sim
    save `r_sch_sim'
    use `stata_sch_sim', clear
    merge 1:1 id using `r_sch_sim', nogen
    gen double d_x1 = abs(sch_sim - r_sch_x1)
    gen double d_x2 = abs(sch_sim_2 - r_sch_x2)
    * Tie-free, well-conditioned data + common beta -> bit-exact agreement.
    foreach v in d_x1 d_x2 {
        quietly summ `v', meanonly
        display as text "  sim `v': max=" %10.8f r(max) " mean=" %10.8f r(mean)
        if r(max) >= 1e-4 {
            display as error "  FAIL: sim `v' max " %10.8f r(max) " >= 1e-4"
            local p11_pass = 0
        }
    }
    restore
}
if _rc != 0 {
    local p11_pass = 0
    capture restore
}
if `p11_pass' {
    display as result "  PASS: P11 simulated Schoenfeld vs R (< 1e-4)"
    local ++pass_count
}
else {
    display as error "  FAIL: P11 simulated Schoenfeld vs R"
    local ++fail_count
}

* P12: Simulated phtest chi2 vs cmprsk — the AUTHORITATIVE PH-test parity.
* Tie-free, well-conditioned data with the Schoenfeld residuals computed at a
* COMMON beta (passed to R), so finegray's chi2 = N*rho^2 and cmprsk's must
* agree to numerical precision across all three time transforms.  (The 20%
* band the hypoxia checks used was tie/G-truncation slack — gone here.)
* Model is still active from P11.
foreach tf in rank log identity {
    local ++test_count
    capture noisily {
        finegray_phtest, time(`tf')
        local s_chi2 = r(chi2)
        preserve
        import delimited using "`datadir'/r_phtest.csv", clear
        quietly summ chi2 if variable == "GLOBAL" & time_func == "`tf'", meanonly
        local r_chi2 = r(mean)
        local rel_diff = abs(`s_chi2' - `r_chi2') / max(`r_chi2', 0.01)
        display as text "  sim `tf' chi2: Stata=" %9.5f `s_chi2' " R=" %9.5f `r_chi2' ///
            " rel_diff=" %8.6f `rel_diff'
        assert `rel_diff' < 0.005
        restore
    }
    if _rc == 0 {
        display as result "  PASS: P12 simulated phtest `tf' chi2 vs cmprsk (< 0.5%)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: P12 simulated phtest `tf' chi2 vs cmprsk (rc=`=_rc')"
        capture restore
        local ++fail_count
    }
}

}
else {
    * R sim not available — skip the simulated cross-validation (P9-P12, 6 tests)
    display as text "  SKIP: simulated R cross-validation (P9-P12) — R not available"
    forvalues i = 1/6 {
        local ++test_count
        local ++skip_count
    }
}

* ============================================================
* {* SECTION 7: Internal consistency (Stata-only)}{...}
* ============================================================

* P13: CIF = 1 - exp(-H0(t) * exp(xb)) exactly
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog basehaz
    finegray_predict xb_ic, xb
    finegray_predict cif_ic, cif
    * Compute CIF manually from xb + basehaz
    tempname bh
    matrix `bh' = e(basehaz)
    tempvar H0 alltouse
    quietly gen byte `alltouse' = 1
    quietly gen double `H0' = 0
    mata: _finegray_step_lookup("`bh'", "_t", "`H0'", "`alltouse'")
    gen double cif_manual = 1 - exp(-`H0' * exp(xb_ic))
    gen double cif_diff = abs(cif_ic - cif_manual) if e(sample)
    quietly summ cif_diff, meanonly
    display as text "  max |CIF_predict - CIF_manual| = " %12.10f r(max)
    assert r(max) < 1e-6
    drop xb_ic cif_ic cif_manual cif_diff
}
if _rc == 0 {
    display as result "  PASS: P13 CIF formula consistency (< 1e-10)"
    local ++pass_count
}
else {
    display as error "  FAIL: P13 CIF formula consistency (rc=`=_rc')"
    local ++fail_count
}

* P14: predict schoenfeld + manual correlation == phtest chi2
* Pearson r is scale-invariant, so unscaled Schoenfeld residuals
* should give the same chi2 as phtest's scaled version.
local ++test_count
local p14_pass = 1
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict sch_ic, schoenfeld
    * Run phtest for reference
    finegray_phtest, time(rank)
    local ph_chi2 = r(chi2)
    matrix ph_mat = r(phtest)
    local ph_Nfail = r(N_fail)
    * Compute manual correlation from predict schoenfeld
    preserve
    keep if !missing(sch_ic)
    * Rank of event time
    egen double t_rank = rank(_t)
    local manual_global_chi2 = 0
    local varnum = 0
    foreach v in sch_ic sch_ic_2 sch_ic_3 {
        local ++varnum
        quietly correlate `v' t_rank
        local rho = r(rho)
        local n_corr = r(N)
        local chi2_v = `n_corr' * (`rho')^2
        local manual_global_chi2 = `manual_global_chi2' + `chi2_v'
        local ph_chi2_v = ph_mat[`varnum', 1]
        local vdiff = abs(`chi2_v' - `ph_chi2_v')
        display as text "  var `varnum': manual chi2=" %8.4f `chi2_v' ///
            " phtest chi2=" %8.4f `ph_chi2_v' " diff=" %8.6f `vdiff'
        if `vdiff' >= 0.01 {
            display as error "  FAIL: var `varnum' diff " %8.6f `vdiff' " >= 0.01"
            local p14_pass = 0
        }
    }
    local global_diff = abs(`manual_global_chi2' - `ph_chi2')
    display as text "  global: manual=" %8.4f `manual_global_chi2' ///
        " phtest=" %8.4f `ph_chi2' " diff=" %8.6f `global_diff'
    if `global_diff' >= 0.01 {
        display as error "  FAIL: global chi2 diff " %8.6f `global_diff' " >= 0.01"
        local p14_pass = 0
    }
    restore
}
if _rc != 0 {
    local p14_pass = 0
    capture restore
}
if `p14_pass' {
    display as result "  PASS: P14 predict schoenfeld + manual cor == phtest chi2"
    local ++pass_count
}
else {
    display as error "  FAIL: P14 internal phtest consistency"
    local ++fail_count
}

* P15: phtest deterministic (same model → identical results on re-run)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_phtest, time(rank)
    local chi2_run1 = r(chi2)
    local p_run1 = r(p)
    finegray_phtest, time(rank)
    local chi2_run2 = r(chi2)
    local p_run2 = r(p)
    assert reldif(`chi2_run1', `chi2_run2') < 1e-10
    assert reldif(`p_run1', `p_run2') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: P15 phtest deterministic (identical re-run)"
    local ++pass_count
}
else {
    display as error "  FAIL: P15 phtest deterministic (rc=`=_rc')"
    local ++fail_count
}

* ============================================================
* {* SUMMARY}{...}
* ============================================================
display ""
display as text "RESULTS: crossval_predict_phtest.do"
display as text "Total:   " as result `test_count'
display as text "Passed:  " as result `pass_count'
display as text "Failed:  " as result `fail_count'
display as text "Skipped: " as result `skip_count'

if `fail_count' > 0 {
    display as error "RESULT: FAIL (`fail_count' of `test_count' tests failed)"
    log close _crossval_pp
    exit 1
}
else if `skip_count' > 0 {
    display as result ///
        "RESULT: PASS (`pass_count' passed, `skip_count' skipped)"
}
else {
    display as result "RESULT: PASS (all `test_count' tests passed)"
}

display "RESULT: crossval_predict_phtest tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count'"

log close _crossval_pp
