* crossval_timevarying_se.do - Python statsmodels SE cross-validation for gcomp
* Manual run from this qa/ directory: stata-mp -b do crossval_timevarying_se.do

clear all
set more off
set varabbrev off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local data_dir "`qa_dir'/data"

capture ado uninstall gcomp
quietly net install gcomp, from("`pkg_dir'") replace
discard

capture noisily shell python3 "`data_dir'/generate_timevarying_se_reference.py"
if _rc {
    display as error "Python statsmodels reference generation failed"
    display "RESULT: crossval_timevarying_se tests=0 pass=0 fail=1 status=FAIL"
    exit 1
}

preserve
import delimited using "`data_dir'/timevarying_se_reference.csv", clear varnames(1) asdouble
forvalues i = 1/`=_N' {
    local analysis = analysis[`i']
    local metric = metric[`i']
    local ref_`analysis'_`metric' = estimate[`i']
    local refse_`analysis'_`metric' = se[`i']
    local tol_`analysis'_`metric' = tolerance_estimate[`i']
    local tolse_`analysis'_`metric' = tolerance_se[`i']
}
restore

preserve
import delimited using "`data_dir'/timevarying_se_covariance.csv", clear varnames(1) asdouble
forvalues i = 1/`=_N' {
    local analysis = analysis[`i']
    local metric1 = metric1[`i']
    local metric2 = metric2[`i']
    local refcov_`analysis'_`metric1'_`metric2' = covariance[`i']
    local tolcov_`analysis'_`metric1'_`metric2' = cov_abs_tol[`i']
}
restore

capture program drop _tvse_compare
program define _tvse_compare
    version 16.0
    syntax, ACTual(real) EXpected(real) TOLerance(real) LABEL(string)

    local diff = abs(`actual' - `expected')
    noisily display as text "    `label': Stata=" %12.8f `actual' ///
        " Python=" %12.8f `expected' " diff=" %10.8f `diff' ///
        " tol=" %10.8f `tolerance'
    assert `diff' <= `tolerance'
end

capture program drop _tvse_extract
program define _tvse_extract, rclass
    version 16.0

    tempname b se
    matrix `b' = e(b)
    matrix `se' = e(se)
    tempname V
    matrix `V' = e(V)

    local c1 = colnumb(`b', "PO1")
    local c2 = colnumb(`b', "PO2")
    if `c1' == . | `c2' == . {
        display as error "Required PO1/PO2 columns not found in e(b)"
        exit 498
    }

    return scalar po_a1 = `b'[1, `c1']
    return scalar po_a0 = `b'[1, `c2']
    return scalar rd_a1_a0 = `b'[1, `c1'] - `b'[1, `c2']
    return scalar se_po_a1 = `se'[1, `c1']
    return scalar se_po_a0 = `se'[1, `c2']
    return scalar se_rd_a1_a0 = sqrt(`V'[`c1', `c1'] + `V'[`c2', `c2'] - 2 * `V'[`c1', `c2'])
    return scalar vdiag_po_a1 = sqrt(`V'[`c1', `c1'])
    return scalar vdiag_po_a0 = sqrt(`V'[`c2', `c2'])

    local cov_abs_sum = abs(`V'[`c1', `c2'])
    local c3 = colnumb(`b', "PO3")
    if `c3' < . {
        local cov_abs_sum = `cov_abs_sum' + abs(`V'[`c1', `c3']) + abs(`V'[`c2', `c3'])
    }
    return scalar po_cov_abs_sum = `cov_abs_sum'
    return scalar po12_cov = `V'[`c1', `c2']
end

capture program drop _tvse_run_gcomp
program define _tvse_run_gcomp, eclass
    version 16.0
    syntax, OUTcome(varname) COMMAND(string) SEED(integer) SAMPLES(integer)

    quietly count if time == 1
    local ns = r(N)

    gcomp `outcome' l0 a l alag llag id time, outcome(`outcome') ///
        idvar(id) tvar(time) ///
        varyingcovariates(l) ///
        fixedcovariates(l0) ///
        laggedvars(alag llag) ///
        lagrules(alag: a 1, llag: l 1) ///
        intvars(a) ///
        eofu minsim ///
        commands(a: logit, `outcome': `command', l: regress) ///
        equations(a: l0 l, `outcome': a l l0, l: alag llag l0) ///
        interventions(a=1, a=0) ///
        sim(`ns') samples(`samples') seed(`seed')
end

local stata_boot_reps = 80

**# Binary EOFU outcome
import delimited using "`data_dir'/timevarying_se_data.csv", clear varnames(1) asdouble
_tvse_run_gcomp, outcome(y) command(logit) seed(20260515) samples(`stata_boot_reps')
_tvse_extract

local actual_binary_po_a1 = r(po_a1)
local actual_binary_po_a0 = r(po_a0)
local actual_binary_rd_a1_a0 = r(rd_a1_a0)
local actual_binary_se_po_a1 = r(se_po_a1)
local actual_binary_se_po_a0 = r(se_po_a0)
local actual_binary_se_rd_a1_a0 = r(se_rd_a1_a0)
local actual_binary_vdiag_po_a1 = r(vdiag_po_a1)
local actual_binary_vdiag_po_a0 = r(vdiag_po_a0)
local actual_binary_po_cov_abs_sum = r(po_cov_abs_sum)
local actual_binary_po12_cov = r(po12_cov)

foreach metric in po_a1 po_a0 rd_a1_a0 {
    local ++test_count
    capture noisily _tvse_compare, actual(`actual_binary_`metric'') ///
        expected(`ref_binary_`metric'') tolerance(`tol_binary_`metric'') ///
        label("binary `metric' point estimate")
    if _rc == 0 {
        display as result "  PASS: binary `metric' point estimate"
        local ++pass_count
    }
    else {
        display as error "  FAIL: binary `metric' point estimate (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' binary_`metric'"
    }
}

foreach metric in po_a1 po_a0 rd_a1_a0 {
    local ++test_count
    capture noisily _tvse_compare, actual(`actual_binary_se_`metric'') ///
        expected(`refse_binary_`metric'') tolerance(`tolse_binary_`metric'') ///
        label("binary `metric' bootstrap SE")
    if _rc == 0 {
        display as result "  PASS: binary `metric' bootstrap SE"
        local ++pass_count
    }
    else {
        display as error "  FAIL: binary `metric' bootstrap SE (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' binary_se_`metric'"
    }
}

foreach metric in po_a1 po_a0 {
    local ++test_count
    capture noisily _tvse_compare, actual(`actual_binary_vdiag_`metric'') ///
        expected(`actual_binary_se_`metric'') tolerance(1e-10) ///
        label("binary `metric' sqrt(diag(e(V))) vs e(se)")
    if _rc == 0 {
        display as result "  PASS: binary `metric' e(V) diagonal matches e(se)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: binary `metric' e(V) diagonal mismatch (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' binary_vdiag_`metric'"
    }
}

local ++test_count
capture noisily {
    _tvse_compare, actual(`actual_binary_po12_cov') ///
        expected(`refcov_binary_po_a1_po_a0') ///
        tolerance(`tolcov_binary_po_a1_po_a0') ///
        label("binary cov(PO1,PO2)")
    assert `actual_binary_po_cov_abs_sum' > 1e-12
}
if _rc == 0 {
    display as result "  PASS: binary PO covariance matches Python bootstrap"
    local ++pass_count
}
else {
    display as error "  FAIL: binary PO covariance mismatch (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' binary_po_covariance"
}

**# Continuous EOFU outcome
import delimited using "`data_dir'/timevarying_se_data.csv", clear varnames(1) asdouble
_tvse_run_gcomp, outcome(yc) command(regress) seed(20260516) samples(`stata_boot_reps')
_tvse_extract

local actual_continuous_po_a1 = r(po_a1)
local actual_continuous_po_a0 = r(po_a0)
local actual_continuous_rd_a1_a0 = r(rd_a1_a0)
local actual_continuous_se_po_a1 = r(se_po_a1)
local actual_continuous_se_po_a0 = r(se_po_a0)
local actual_continuous_se_rd_a1_a0 = r(se_rd_a1_a0)
local actual_continuous_vdiag_po_a1 = r(vdiag_po_a1)
local actual_continuous_vdiag_po_a0 = r(vdiag_po_a0)
local actual_cont_pocovsum = r(po_cov_abs_sum)
local actual_cont_po12cov = r(po12_cov)

foreach metric in po_a1 po_a0 rd_a1_a0 {
    local ++test_count
    capture noisily _tvse_compare, actual(`actual_continuous_`metric'') ///
        expected(`ref_continuous_`metric'') tolerance(`tol_continuous_`metric'') ///
        label("continuous `metric' point estimate")
    if _rc == 0 {
        display as result "  PASS: continuous `metric' point estimate"
        local ++pass_count
    }
    else {
        display as error "  FAIL: continuous `metric' point estimate (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' continuous_`metric'"
    }
}

foreach metric in po_a1 po_a0 rd_a1_a0 {
    local ++test_count
    capture noisily _tvse_compare, actual(`actual_continuous_se_`metric'') ///
        expected(`refse_continuous_`metric'') tolerance(`tolse_continuous_`metric'') ///
        label("continuous `metric' bootstrap SE")
    if _rc == 0 {
        display as result "  PASS: continuous `metric' bootstrap SE"
        local ++pass_count
    }
    else {
        display as error "  FAIL: continuous `metric' bootstrap SE (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' continuous_se_`metric'"
    }
}

foreach metric in po_a1 po_a0 {
    local ++test_count
    capture noisily _tvse_compare, actual(`actual_continuous_vdiag_`metric'') ///
        expected(`actual_continuous_se_`metric'') tolerance(1e-10) ///
        label("continuous `metric' sqrt(diag(e(V))) vs e(se)")
    if _rc == 0 {
        display as result "  PASS: continuous `metric' e(V) diagonal matches e(se)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: continuous `metric' e(V) diagonal mismatch (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' continuous_vdiag_`metric'"
    }
}

local ++test_count
capture noisily {
    _tvse_compare, actual(`actual_cont_po12cov') ///
        expected(`refcov_continuous_po_a1_po_a0') ///
        tolerance(`tolcov_continuous_po_a1_po_a0') ///
        label("continuous cov(PO1,PO2)")
    assert `actual_cont_pocovsum' > 1e-12
}
if _rc == 0 {
    display as result "  PASS: continuous PO covariance matches Python bootstrap"
    local ++pass_count
}
else {
    display as error "  FAIL: continuous PO covariance mismatch (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' continuous_po_covariance"
}

capture program drop _tvse_compare
capture program drop _tvse_extract
capture program drop _tvse_run_gcomp

display as text ""
display as result "Time-varying SE cross-validation: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display "RESULT: crossval_timevarying_se tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    display as error "FAIL"
    display as error "Failed comparisons:`failed_tests'"
    exit 1
}

display "RESULT: crossval_timevarying_se tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"
display as result "PASS"
