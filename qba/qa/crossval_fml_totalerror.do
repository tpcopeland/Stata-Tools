* crossval_fml_totalerror.do -- qba_misclass, totalerror against the author
* reference R code for Fox, MacLehose & Lash (2023)
* Package: qba (Quantitative Bias Analysis)
* Usage: cd qba/qa && stata-mp -b do crossval_fml_totalerror.do
*
* The oracle in tools/oracle_fml_totalerror.R transcribes the authors' own
* published summary-level algorithms. It shares no code and no nuisance
* parameter with qba, so agreement is parity against an independent
* implementation of the method, not a mirror of the package.
*
* Two worked examples from the reference code:
*   1. exposure misclassification, nondifferential, RR
*      (a=215 b=1449 c=668 d=4296; Se~Beta(50.6,14.3), Sp~Beta(70,1))
*   2. outcome misclassification in a case-control study, OR
*      (a=387 b=1642 c=685 d=3365; Se~Beta(35,3), Sp~U(.96,1), fctrl=0.1)
*
* Tolerances are relative and calibrated from Monte Carlo noise: at 10^6 draws
* per side the largest observed relative discrepancy across all 16 compared
* quantities was 6e-4. At the SIMS used here the expected noise is ~2e-3, so
* the tolerances below sit several standard errors out -- loose enough not to
* flake, tight enough that any formula error (which moves results by percent
* or more) fails.

clear all
version 16.0

local SIMS 200000
local SEED 20260726

capture program drop _qba_fml_expect
program define _qba_fml_expect, rclass
    syntax , Name(string) USing(string)
    preserve
    quietly use "`using'", clear
    quietly keep if name == "`name'"
    if _N != 1 {
        display as error "oracle row `name' not found"
        exit 9
    }
    return scalar value = value[1]
    restore
end

capture program drop _qba_fml_compare
program define _qba_fml_compare
    syntax , Actual(real) Name(string) USing(string) [RELtol(real 0.015)]
    _qba_fml_expect, name("`name'") using("`using'")
    local expected = r(value)
    if missing(`actual') | missing(`expected') {
        display as error "`name': missing value (actual=`actual' expected=`expected')"
        exit 9
    }
    local denom = abs(`expected')
    if `denom' < 1e-12 local denom = 1
    local rel = abs(`actual' - `expected') / `denom'
    if `rel' > `reltol' {
        display as error "`name': expected " %12.8f `expected' ///
            ", got " %12.8f `actual' ///
            " (rel " %9.6f `rel' " > tol " %9.6f `reltol' ")"
        exit 9
    }
    display as text "    `name': " %12.8f `actual' " vs oracle " ///
        %12.8f `expected' "  (rel " %9.6f `rel' ")"
end

capture program drop _qba_crossval_fml_main
program define _qba_crossval_fml_main
    version 16.0
    args sims seed

    local test_count = 0
    local pass_count = 0
    local fail_count = 0
    local failed_tests ""

    local qa_dir "`c(pwd)'"
    local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
    capture confirm file "`pkg_dir'/qba.pkg"
    if _rc {
        display as error "could not locate qba package root from `c(pwd)'"
        exit 601
    }

    local oracle_script "`qa_dir'/tools/oracle_fml_totalerror.R"
    capture confirm file "`oracle_script'"
    if _rc {
        display as error "author-reference oracle script not found: `oracle_script'"
        exit 601
    }

    * The oracle needs base R only -- no contributed packages -- so an
    * available Rscript is sufficient. A missing Rscript is a real gap, not a
    * skip: install R rather than weakening this suite.
    * Have R create the sentinel itself so the guard is independent of the
    * user's interactive shell syntax.
    tempfile r_ok
    capture erase "`r_ok'"
    local r_ok_path = subinstr("`r_ok'", "\", "/", .)
    shell Rscript -e "writeLines('ok', '`r_ok_path'')"
    capture confirm file "`r_ok'"
    if _rc {
        display as error "Rscript is not available; install R to run this cross-validation"
        exit 1
    }

    capture ado uninstall qba
    quietly net install qba, from("`pkg_dir'") replace

    tempfile oracle_csv oracle_dta
    * The oracle writes the sentinel only after the CSV is complete.
    tempfile oracle_ok
    capture erase "`oracle_ok'"
    shell Rscript "`oracle_script'" "`oracle_csv'" `seed' `sims' "`oracle_ok'"
    capture confirm file "`oracle_ok'"
    if _rc {
        display as error "author-reference oracle failed (error `=_rc')"
        exit 1
    }

    preserve
    import delimited using "`oracle_csv'", varnames(1) clear stringcols(_all)
    quietly gen double value_d = real(value)
    assert !missing(value_d)
    drop value
    rename value_d value
    quietly save "`oracle_dta'", replace
    restore

    **# X1: exposure misclassification, systematic-error arm

    local ++test_count
    capture noisily {
        qba_misclass, a(215) b(1449) c(668) d(4296) seca(.78) spca(.99) ///
            measure(RR) reps(`sims') seed(`seed') ///
            dist_se("beta 50.6 14.3") dist_sp("beta 70 1") totalerror
        local x_syst_lo = r(ci_lower)
        local x_syst_md = r(corrected)
        local x_syst_hi = r(ci_upper)
        local x_tot_lo = r(te_lower)
        local x_tot_md = r(te_median)
        local x_tot_hi = r(te_upper)
        local x_re_lo = r(re_lower)
        local x_re_md = r(re_median)
        local x_re_hi = r(re_upper)
        local x_imposs = (r(reps) - r(n_valid_te)) / r(reps)

        _qba_fml_compare, actual(`x_syst_lo') name("exp_syst_p025") ///
            using("`oracle_dta'")
        _qba_fml_compare, actual(`x_syst_md') name("exp_syst_p50") ///
            using("`oracle_dta'") reltol(0.008)
        _qba_fml_compare, actual(`x_syst_hi') name("exp_syst_p975") ///
            using("`oracle_dta'")
    }
    if _rc {
        local ++fail_count
        local failed_tests "`failed_tests' X1"
        display as error "  FAIL: X1 exposure systematic-error arm (error `=_rc')"
    }
    else {
        local ++pass_count
        display as result "  PASS: X1 exposure systematic-error arm"
    }

    **# X2: exposure misclassification, total-error arm

    local ++test_count
    capture noisily {
        _qba_fml_compare, actual(`x_tot_lo') name("exp_total_p025") ///
            using("`oracle_dta'")
        _qba_fml_compare, actual(`x_tot_md') name("exp_total_p50") ///
            using("`oracle_dta'") reltol(0.008)
        _qba_fml_compare, actual(`x_tot_hi') name("exp_total_p975") ///
            using("`oracle_dta'")
    }
    if _rc {
        local ++fail_count
        local failed_tests "`failed_tests' X2"
        display as error "  FAIL: X2 exposure total-error arm (error `=_rc')"
    }
    else {
        local ++pass_count
        display as result "  PASS: X2 exposure total-error arm"
    }

    **# X3: exposure misclassification, random-error-only arm and the
    * impossible-replicate rate

    local ++test_count
    capture noisily {
        _qba_fml_compare, actual(`x_re_lo') name("exp_re_p025") ///
            using("`oracle_dta'")
        _qba_fml_compare, actual(`x_re_md') name("exp_re_p50") ///
            using("`oracle_dta'") reltol(0.008)
        _qba_fml_compare, actual(`x_re_hi') name("exp_re_p975") ///
            using("`oracle_dta'")
        * The nonpositive-cell exclusion rate is a property of the algorithm,
        * not of the summary: it must agree in absolute terms.
        _qba_fml_expect, name("exp_impossible_frac") using("`oracle_dta'")
        local orc_imposs = r(value)
        if abs(`x_imposs' - `orc_imposs') > 0.002 {
            display as error "impossible fraction `x_imposs' vs oracle `orc_imposs'"
            exit 9
        }
        display as text "    exp_impossible_frac: " %9.6f `x_imposs' ///
            " vs oracle " %9.6f `orc_imposs'
    }
    if _rc {
        local ++fail_count
        local failed_tests "`failed_tests' X3"
        display as error "  FAIL: X3 exposure random-error arm (error `=_rc')"
    }
    else {
        local ++pass_count
        display as result "  PASS: X3 exposure random-error arm"
    }

    **# X4: case-control outcome misclassification, source-population table

    local ++test_count
    capture noisily {
        qba_misclass, a(387) b(1642) c(685) d(3365) type(outcome) ///
            measure(OR) seca(.9) spca(.98) fctrl(.1) reps(`sims') seed(`seed') ///
            dist_se("beta 35 3") dist_sp("uniform .96 1") totalerror
        local c_syst_lo = r(ci_lower)
        local c_syst_md = r(corrected)
        local c_syst_hi = r(ci_upper)
        local c_tot_lo = r(te_lower)
        local c_tot_md = r(te_median)
        local c_tot_hi = r(te_upper)
        * _qba_fml_compare is rclass, so it replaces r() on its first call.
        * Every r() value this test needs is captured before any comparison.
        local c_adj_a = r(adj_a)
        local c_adj_b = r(adj_b)
        local c_adj_c = r(adj_c)
        local c_adj_d = r(adj_d)

        * The sampling-fraction inflation must reproduce the oracle's table
        * exactly -- this is arithmetic, not simulation.
        _qba_fml_compare, actual(`c_adj_a') name("cc_adj_a") ///
            using("`oracle_dta'") reltol(1e-9)
        _qba_fml_compare, actual(`c_adj_b') name("cc_adj_b") ///
            using("`oracle_dta'") reltol(1e-9)
        _qba_fml_compare, actual(`c_adj_c') name("cc_adj_c") ///
            using("`oracle_dta'") reltol(1e-9)
        _qba_fml_compare, actual(`c_adj_d') name("cc_adj_d") ///
            using("`oracle_dta'") reltol(1e-9)
    }
    if _rc {
        local ++fail_count
        local failed_tests "`failed_tests' X4"
        display as error "  FAIL: X4 case-control source-population table (error `=_rc')"
    }
    else {
        local ++pass_count
        display as result "  PASS: X4 case-control source-population table"
    }

    **# X5: case-control outcome misclassification, systematic-error arm

    local ++test_count
    capture noisily {
        _qba_fml_compare, actual(`c_syst_lo') name("cc_syst_p025") ///
            using("`oracle_dta'")
        _qba_fml_compare, actual(`c_syst_md') name("cc_syst_p50") ///
            using("`oracle_dta'") reltol(0.008)
        _qba_fml_compare, actual(`c_syst_hi') name("cc_syst_p975") ///
            using("`oracle_dta'")
    }
    if _rc {
        local ++fail_count
        local failed_tests "`failed_tests' X5"
        display as error "  FAIL: X5 case-control systematic-error arm (error `=_rc')"
    }
    else {
        local ++pass_count
        display as result "  PASS: X5 case-control systematic-error arm"
    }

    **# X6: case-control outcome misclassification, total-error arm

    local ++test_count
    capture noisily {
        _qba_fml_compare, actual(`c_tot_lo') name("cc_total_p025") ///
            using("`oracle_dta'")
        _qba_fml_compare, actual(`c_tot_md') name("cc_total_p50") ///
            using("`oracle_dta'") reltol(0.008)
        _qba_fml_compare, actual(`c_tot_hi') name("cc_total_p975") ///
            using("`oracle_dta'")
    }
    if _rc {
        local ++fail_count
        local failed_tests "`failed_tests' X6"
        display as error "  FAIL: X6 case-control total-error arm (error `=_rc')"
    }
    else {
        local ++pass_count
        display as result "  PASS: X6 case-control total-error arm"
    }

    **# X7: the arms are genuinely distinct
    * Guards against a regression that quietly wires two arms to the same
    * numbers -- which would keep every comparison above green.

    local ++test_count
    capture noisily {
        local w_syst = `c_syst_hi' / `c_syst_lo'
        local w_tot = `c_tot_hi' / `c_tot_lo'
        if abs(`w_tot' - `w_syst') < 0.05 {
            display as error ///
                "total and systematic interval widths are indistinguishable: `w_tot' vs `w_syst'"
            exit 9
        }
        if abs(`x_re_md' - `x_syst_md') < 0.001 {
            display as error ///
                "random-error and systematic medians are indistinguishable: `x_re_md' vs `x_syst_md'"
            exit 9
        }
    }
    if _rc {
        local ++fail_count
        local failed_tests "`failed_tests' X7"
        display as error "  FAIL: X7 arms are distinct (error `=_rc')"
    }
    else {
        local ++pass_count
        display as result "  PASS: X7 arms are distinct"
    }

    **# Summary

    display as text ""
    display as result "Author-reference cross-validation: `pass_count'/`test_count' passed, `fail_count' failed"
    display "RESULT: crossval_fml_totalerror tests=`test_count' pass=`pass_count' fail=`fail_count'"

    if `fail_count' > 0 {
        display as error "FAILED TESTS: `failed_tests'"
        exit 1
    }
    display as result "ALL TESTS PASSED"
end

local _orig_plus "`c(sysdir_plus)'"
local _orig_personal "`c(sysdir_personal)'"
tempfile _qba_plus_stub _qba_personal_stub
local _qba_plus "`_qba_plus_stub'_dir"
local _qba_personal "`_qba_personal_stub'_dir"
* A Stata process that aborted before its cleanup leaves this exact
* tempfile-derived name behind, and tempfile names are keyed to the PID, which
* the OS recycles. A bare mkdir onto an existing directory is r(693) -- a
* spurious failure in a later, unrelated run. Clear the stale leftover: the
* name is this process's own tempfile, so nothing else can own it.
capture mkdir "`_qba_plus'"
if _rc {
    capture shell rm -rf "`_qba_plus'"
    mkdir "`_qba_plus'"
}
capture mkdir "`_qba_personal'"
if _rc {
    capture shell rm -rf "`_qba_personal'"
    mkdir "`_qba_personal'"
}
sysdir set PLUS "`_qba_plus'"
sysdir set PERSONAL "`_qba_personal'"

capture noisily _qba_crossval_fml_main `SIMS' `SEED'
local rc = _rc

capture ado uninstall qba
sysdir set PLUS "`_orig_plus'"
sysdir set PERSONAL "`_orig_personal'"

if `rc' exit `rc'
