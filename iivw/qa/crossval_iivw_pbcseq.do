clear all
version 16.0
set varabbrev off

* crossval_iivw_pbcseq.do
*
* Public-study cross-validation using survival::pbcseq, the sequential Mayo
* Clinic primary biliary cholangitis trial data. The R companion independently
* constructs the counting-process risk set and checks:
*   XV1 stabilized visit-intensity Cox coefficients and risk-set counts
*   XV2 row-level normalized IIW, including baseline(entry) rows
*   XV3 quadratic-time weighted Gaussian GEE coefficients and robust SEs
*   XV4 iivw_exogtest lagged-bilirubin coefficient and clustered robust SE

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "crossval_iivw_pbcseq.do must be run from iivw/qa"
    exit 198
}

do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir "`r(pkg_dir)'"

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

**# Generate fresh R references

local rscript "`qa_dir'/crossval_iivw_pbcseq.R"
capture confirm file "`rscript'"
if _rc {
    display as error "missing R generator: `rscript'"
    exit 601
}

tempfile refstub
local ref_dir "`refstub'_pbcseq"
capture mkdir "`ref_dir'"

local rok "`ref_dir'/pbcseq.ok"
capture erase "`rok'"
shell Rscript "`rscript'" --outdir="`ref_dir'"
capture confirm file "`rok'"
if _rc {
    display as error "PBCseq R reference generation did not run to completion"
    display as error "  required: Rscript with survival and geepack"
    display as error "  refusing to compare against absent or stale references"
    exit 198
}

local ref_files pbcseq_data pbcseq_cox pbcseq_weights pbcseq_exog ///
    pbcseq_geeglm pbcseq_versions
foreach f of local ref_files {
    capture confirm file "`ref_dir'/`f'.csv"
    if _rc {
        display as error "R generator omitted `f'.csv"
        exit 601
    }
    preserve
    capture import delimited "`ref_dir'/`f'.csv", clear varnames(1) asdouble
    local import_rc = _rc
    local import_N = _N
    restore
    if `import_rc' != 0 | `import_N' == 0 {
        display as error "R reference `f'.csv is unreadable or empty"
        exit 601
    }
}

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# XV1 - Cox coefficients and risk-set counts match survival::coxph

local ++test_count
capture noisily {
    import delimited "`ref_dir'/pbcseq_data.csv", clear varnames(1) asdouble

    iivw_weight, id(id) time(time) censor(censor_time) baseline(entry) ///
        visit_cov(trt age sex_f) lagvars(logbili) ///
        stabcov(trt age sex_f) efron nolog

    matrix B = r(visit_b)
    local visit_N = r(visit_N)
    local visit_events = r(n_modeled_events)
    local censor_rows = r(n_censor_rows)
    local weighted_N = r(N_weighted)

    preserve
    import delimited "`ref_dir'/pbcseq_cox.csv", clear varnames(1) asdouble
    assert _N == 4
    local r_n = n[1]
    local r_events = nevent[1]
    local r_censor = ncensor[1]
    local r_trt = estimate[1]
    local r_age = estimate[2]
    local r_sex = estimate[3]
    local r_lagbili = estimate[4]
    restore

    local j_trt = colnumb(B, "trt")
    local j_age = colnumb(B, "age")
    local j_sex = colnumb(B, "sex_f")
    local j_lag = colnumb(B, "logbili_lag1")
    assert !missing(`j_trt', `j_age', `j_sex', `j_lag')
    assert abs(B[1, `j_trt'] - `r_trt') < 1e-7
    assert abs(B[1, `j_age'] - `r_age') < 1e-7
    assert abs(B[1, `j_sex'] - `r_sex') < 1e-7
    assert abs(B[1, `j_lag'] - `r_lagbili') < 1e-7
    assert `visit_N' == `r_n'
    assert `visit_events' == `r_events'
    assert `censor_rows' == `r_censor'
    assert `weighted_N' == 1866
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: XV1 - PBCseq Cox coefficients and risk set match R"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' XV1"
    display as error "FAIL: XV1 - PBCseq Cox/risk-set parity (error `=_rc')"
}

**# XV2 - Modeled-visit weights and entry rows match the R oracle

local ++test_count
capture noisily {
    import delimited "`ref_dir'/pbcseq_data.csv", clear varnames(1) asdouble
    iivw_weight, id(id) time(time) censor(censor_time) baseline(entry) ///
        visit_cov(trt age sex_f) lagvars(logbili) ///
        stabcov(trt age sex_f) efron nolog

    preserve
    import delimited "`ref_dir'/pbcseq_weights.csv", clear varnames(1) asdouble
    tempfile rweights
    save "`rweights'"
    local r_rows = _N
    restore

    merge 1:1 id time using "`rweights'", keep(master match) generate(_mrg)
    quietly count if _mrg == 3
    assert r(N) == `r_rows'
    assert `r_rows' == 1607

    gen double weight_diff = abs(_iivw_iw - norm_weight) if _mrg == 3
    quietly summarize weight_diff, meanonly
    assert r(N) == `r_rows'
    assert r(max) < 1e-8

    bysort id (time): gen byte is_entry = (_n == 1)
    quietly count if _mrg == 1 & is_entry
    assert r(N) == 259
    quietly count if _mrg == 1 & !is_entry
    assert r(N) == 0
    quietly summarize _iivw_iw if is_entry, meanonly
    assert r(N) == 259
    assert abs(r(min) - 1) < 1e-12
    assert abs(r(max) - 1) < 1e-12
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: XV2 - PBCseq row-level stabilized IIW match R"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' XV2"
    display as error "FAIL: XV2 - PBCseq row-level weight parity (error `=_rc')"
}

**# XV3 - Quadratic-time weighted GEE matches geepack::geeglm

local ++test_count
capture noisily {
    import delimited "`ref_dir'/pbcseq_data.csv", clear varnames(1) asdouble
    iivw_weight, id(id) time(time) censor(censor_time) baseline(entry) ///
        visit_cov(trt age sex_f) lagvars(logbili) ///
        stabcov(trt age sex_f) efron nolog
    iivw_fit logbili trt age sex_f albumin, timespec(quadratic) ///
        vce(fixed) nolog

    local s_b1 = _b[_cons]
    local s_b2 = _b[trt]
    local s_b3 = _b[age]
    local s_b4 = _b[sex_f]
    local s_b5 = _b[albumin]
    local s_b6 = _b[time]
    local s_b7 = _b[_iivw_time_sq]
    local s_se1 = _se[_cons]
    local s_se2 = _se[trt]
    local s_se3 = _se[age]
    local s_se4 = _se[sex_f]
    local s_se5 = _se[albumin]
    local s_se6 = _se[time]
    local s_se7 = _se[_iivw_time_sq]
    assert e(N) == 1866

    preserve
    import delimited "`ref_dir'/pbcseq_geeglm.csv", clear varnames(1) asdouble
    assert _N == 7
    forvalues j = 1/7 {
        local r_b`j' = estimate[`j']
        local r_se`j' = se[`j']
    }
    restore

    forvalues j = 1/7 {
        assert abs(`s_b`j'' - `r_b`j'') < 1e-6
        assert abs(`s_se`j'' - `r_se`j'') / `r_se`j'' < 0.05
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: XV3 - PBCseq quadratic GEE coefficients/SEs match R"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' XV3"
    display as error "FAIL: XV3 - PBCseq quadratic GEE parity (error `=_rc')"
}

**# XV4 - Exogeneity diagnostic matches clustered survival::coxph

local ++test_count
capture noisily {
    import delimited "`ref_dir'/pbcseq_data.csv", clear varnames(1) asdouble
    iivw_exogtest logbili, id(id) time(time) censor(censor_time) ///
        adjust(trt age sex_f) efron nolog
    matrix X = r(results)
    assert rowsof(X) == 1
    assert r(n_models) == 1
    local s_b = X[1, 3]
    local s_se = X[1, 4]
    local s_N = X[1, 10]
    local s_ids = X[1, 11]

    preserve
    import delimited "`ref_dir'/pbcseq_exog.csv", clear varnames(1) asdouble
    local r_b = estimate[1]
    local r_se_raw = se_r[1]
    local r_se = se_stata_fsc[1]
    local r_N = n[1]
    restore

    assert abs(`s_b' - `r_b') < 1e-7
    display as text "  exog SE Stata=" %12.9f `s_se' ///
        " R+Stata FSC=" %12.9f `r_se' ///
        " relative diff=" %12.9f (abs(`s_se' - `r_se') / `r_se')
    * survival reports the uncorrected clustered sandwich. Stata multiplies its
    * covariance by M/(M-1), M=259 clusters; the R oracle applies that explicit
    * correction before this same-estimand comparison.
    assert reldif(`r_se', `r_se_raw' * sqrt(259 / 258)) < 1e-12
    assert abs(`s_se' - `r_se') / `r_se' < 1e-4
    assert `s_N' == `r_N'
    assert `s_ids' == 259
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: XV4 - PBCseq exogeneity diagnostic matches R"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' XV4"
    display as error "FAIL: XV4 - PBCseq exogeneity parity (error `=_rc')"
}

**# Summary

local run_only = 0
iivw_qa_summary, name(crossval_iivw_pbcseq) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') runonly(`run_only') ///
    failedtests("`failed_tests'")

clear
