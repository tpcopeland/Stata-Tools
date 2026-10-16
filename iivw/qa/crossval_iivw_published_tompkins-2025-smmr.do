clear all
set more off
version 16.0
set varabbrev off

* crossval_iivw_published_tompkins-2025-smmr.do
*
* PUBLISHED REPRODUCTION, via the authors' own public code: Tompkins G, Dubin JA,
* Wallace M. On flexible inverse probability of treatment and intensity weighting:
* informative censoring, variable selection, and weight trimming. Stat Methods
* Med Res 2025;34(5):915-937 (arXiv:2405.15740v1; PDF p.8 for the DGP, p.11 for
* Table 1). Index row: _literature/iivw/index.md, key tompkins-2025-smmr.
*
* Routes covered
*   iivw_weight, wtype(iivw)    stabilized inverse-intensity weights (Cox AG)
*   iivw_fit, unweighted        the paper's "Naive" column
*   iivw_fit weighted GEE point estimate under IIW weights (offset 2 - t)
*
* Oracle: the authors' public R code (github.com/grcetmpk/FIPTIW, commit
* f46e493, file FIPTIW_timevarW_functions.R, SHA-256 asserted in the R script).
* The R script runs the authors' own Simulation II data generator
* (gendata_FIPTIW_continuous) and the authors' own estimator (simulateOneVarSel:
* stabilized IIW from a Cox model fitted on the full 0.01 time grid, independent
* GEE with offset 2 - t) for the intensity models {none (Naive), D, Z, D+Z}. This
* suite then runs iivw on the SAME simulated data, one row per visit plus a
* subject row, and compares replicate by replicate. Not a re-derivation in Stata.
* Configuration: n = 100, beta1 = 0.5, beta2 = 0, beta3 = 1, gamma = (0.5, 0, 0.6),
* randomized treatment (alpha = 0), tau = 7, C ~ U(tau/2, tau): Table 1 row
* (gamma2 = 0, beta2 = 0). Only subject-constant covariates (D, Z) enter the
* intensity model, for which a visit-row risk set is exact.
*
* Tolerance: 1e-6 absolute on beta1-hat per replicate (same estimator, same
* data; floating-point only). Measured over 300 replicates when this suite was
* built: max |iivw - authors| = 6e-8 for D+Z. R = 40 replicates, seed 20261015
* inside the R script.
*
* NOTE* (declared convention difference, not a widened tolerance). The PRINTED
* Table 1 / S1 / S2 are NOT asserted, because they do not reproduce from the
* authors' public code or from the text of the paper. Evidence, all run before
* this suite was written:
*   - authors' code, n = 100, 300 data sets, row (0,0): bias(D+Z) = -0.006
*     (MCSE 0.014) against published 0.026; the file's phi is drawn with SD 1.25
*     (var_phi = 1.25 used as an SD) and the intensity frailty has variance 0.01,
*     where the paper's text says phi ~ N(0, 0.25) and sigma_eta^2 = 0.1.
*   - a DGP written from the paper's text, iivw, 300-1000 data sets per cell: the
*     Naive and D columns match the published bias within 3 MCSE in all 24 cells
*     of Table 1, S1 and S2, while the Z and D+Z columns are outside that band
*     in 10 of their 24 cells (3 at n = 100, 0 at n = 50, 7 at n = 500), 0.01 to
*     0.03 below the published bias, and the published D+Z bias does not shrink
*     with n at row (0,0) (0.024, 0.026, 0.027 at n = 50, 100, 500) while ours does.
*   - rounding visit and censoring times to 0.01 as the authors' code does moves
*     the D+Z bias from 0.014 to -0.007 (MCSE 0.006), not toward 0.027.
* The cause is unresolved. It is not attributed to iivw: iivw equals the
* authors' estimator on the authors' data to 6e-8. The columns that include G(t)
* are out of scope because G(t) = W log t varies between visits and cannot be
* supplied to a visit-row risk set.
*
* Requires: Rscript with dplyr, survival, geepack; network access to
* raw.githubusercontent.com (REFERENCE: line prints the URL and fetch date).
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do crossval_iivw_published_tompkins-2025-smmr.do [n]

args run_only
do "`c(pwd)'/_iivw_qa_common.do"
iivw_qa_selector "`run_only'"
local run_only = `r(run_only)'

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "crossval_iivw_published_tompkins-2025-smmr.do must be run from iivw/qa"
    exit 198
}
iivw_qa_bootstrap

local R = 40
local N = 100
local TOL = 1e-6

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# Generate the authors' simulated data and estimates (fresh, sentinel-gated)
local rscript "`qa_dir'/crossval_iivw_published_tompkins-2025-smmr.R"
capture confirm file "`rscript'"
if _rc {
    display as error "missing R generator: `rscript'"
    exit 601
}
tempfile refstub
local ref_dir "`refstub'_auth"
capture mkdir "`ref_dir'"
local rok "`ref_dir'/auth.ok"
capture erase "`rok'"
shell Rscript "`rscript'" --outdir="`ref_dir'" --reps=`R' --n=`N'
capture confirm file "`rok'"
if _rc {
    display as error "authors' R reference did not run to completion"
    display as error "  required: Rscript with dplyr, survival, geepack; network access"
    display as error "  refusing to compare against absent or stale references"
    exit 198
}
display as text "REFERENCE: github.com/grcetmpk/FIPTIW commit f46e493 FIPTIW_timevarW_functions.R (see R output above for fetch date)"

* iivw on each replicate: Naive, D, Z, D+Z
tempfile ours
capture postclose _pf
postfile _pf int rep double(i_naive i_D i_Z i_DZ) using "`ours'", replace
forvalues r = 1/`R' {
    import delimited "`ref_dir'/auth_s_`r'.csv", clear case(preserve)
    gen double t = 0
    gen byte entry = 1
    gen double y = .
    tempfile s
    quietly save `s'
    import delimited "`ref_dir'/auth_v_`r'.csv", clear case(preserve)
    gen byte entry = 0
    keep id t D Z y C entry
    append using `s'
    sort id t
    gen double off = 2 - t
    capture quietly iivw_fit y D, unweighted id(id) time(t) timespec(none) ///
        geeopts(offset(off) noconstant) nolog
    local i_naive = cond(_rc == 0, _b[D], .)
    local k = 0
    foreach vc in "D" "Z" "D Z" {
        local ++k
        capture quietly {
            iivw_weight, id(id) time(t) visit_cov(`vc') stabcov(D) wtype(iivw) ///
                censor(C) baseline(entry) nolog replace
            iivw_fit y D, timespec(none) vce(fixed) ///
                geeopts(offset(off) noconstant) nolog replace
        }
        local i_`k' = cond(_rc == 0, _b[D], .)
    }
    post _pf (`r') (`i_naive') (`i_1') (`i_2') (`i_3')
}
postclose _pf

import delimited "`ref_dir'/auth_res.csv", clear case(preserve)
tempfile auth
quietly save "`auth'"
use "`ours'", clear
merge 1:1 rep using "`auth'", nogenerate
tempfile both
quietly save "`both'"

**# T1: completeness
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    capture noisily {
        use "`both'", clear
        assert _N == `R'
        assert !missing(i_naive, i_D, i_Z, i_DZ, b_naive, b_D, b_Z, b_DZ)
        capture confirm file "`ref_dir'/auth_versions.csv"
        assert _rc == 0
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T1 `R' replicates, every iivw and reference fit present"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' T1"
        display as error "FAIL: T1 completeness (error `=_rc')"
    }
}

**# T2-T5: replicate-level parity per column
local tno = 1
foreach col in naive D Z DZ {
    local ++tno
    local ++test_count
    if `run_only' == 0 | `run_only' == `tno' {
        capture noisily {
            use "`both'", clear
            gen double gap = abs(i_`col' - b_`col')
            quietly summarize gap
            display as text "    `col': max |iivw - authors| = " %12.3e r(max) "  (tolerance `TOL')"
            assert r(max) < . & r(max) < `TOL'
        }
        if _rc == 0 {
            local ++pass_count
            display as result "PASS: T`tno' `col' column equals the authors' estimator on their data"
        }
        else {
            local ++fail_count
            local failed_tests "`failed_tests' T`tno'"
            display as error "FAIL: T`tno' `col' column parity (error `=_rc')"
        }
    }
}

**# T6: negative control, the bands separate columns that differ
*  iivw's Z-only fit against the authors' D+Z estimate: different intensity
*  models, so the gap must exceed the tolerance somewhere.
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    capture noisily {
        use "`both'", clear
        gen double gap = abs(i_Z - b_DZ)
        quietly summarize gap
        display as text "    max |iivw Z-only - authors D+Z| = " %9.4f r(max) "  (must exceed `TOL')"
        assert r(max) < . & r(max) > `TOL'
        gen double gap2 = abs(i_naive - b_DZ)
        quietly summarize gap2
        assert r(max) < . & r(max) > `TOL'
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T6 the tolerance separates different intensity models"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' T6"
        display as error "FAIL: T6 negative control did not separate (error `=_rc')"
    }
}

**# Printed for the record, NOT asserted (see NOTE* in the header)
use "`both'", clear
foreach col in naive D Z DZ {
    quietly summarize b_`col'
    local ab = r(mean) - 0.5
    local am = r(sd) / sqrt(r(N))
    display as text "    NOTE* authors' `col' bias at n=100 over `R' sets: " %7.4f `ab' " (MCSE " %6.4f `am' ")  published Table 1 row (0,0): naive 0.286, D 0.286, Z 0.082, D+Z 0.026"
}

iivw_qa_summary, name(crossval_iivw_published_tompkins-2025-smmr) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') runonly(`run_only') failedtests("`failed_tests'")

clear
