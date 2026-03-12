* test_gcomp.do - Functional tests for gcomp package (gcomp + gcomptab)
* Tests: all options, error handling, edge cases, return values, data preservation
* Runtime: ~10 minutes (bootstrap-based)

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

* ============================================================
* Setup
* ============================================================

capture ado uninstall gcomp
quietly net install gcomp, from("/home/tpcopeland/Stata-Tools/gcomp/") replace
discard

* Force-load to clear program cache
capture findfile gcomp.ado
quietly run "`r(fn)'"

local testdir "`c(tmpdir)'"

* ============================================================
* Helper: Mock gcomp output for gcomptab tests
* ============================================================

capture program drop mock_gcomp
program define mock_gcomp, eclass
    version 16.0
    syntax, tce(real) nde(real) nie(real) pm(real) cde(real) ///
            [se_tce(real 0.05) se_nde(real 0.04) se_nie(real 0.03) ///
             se_pm(real 0.02) se_cde(real 0.04)]

    tempname b V se_mat cin cip cibc cibca
    matrix `b' = (`tce', `nde', `nie', `pm', `cde')
    matrix colnames `b' = tce nde nie pm cde
    matrix `V' = J(5, 5, 0)
    matrix `V'[1,1] = `se_tce'^2
    matrix `V'[2,2] = `se_nde'^2
    matrix `V'[3,3] = `se_nie'^2
    matrix `V'[4,4] = `se_pm'^2
    matrix `V'[5,5] = `se_cde'^2
    matrix colnames `V' = tce nde nie pm cde
    matrix rownames `V' = tce nde nie pm cde
    ereturn post `b' `V'
    ereturn local cmd "gcomp"
    ereturn local analysis_type "mediation"
    ereturn scalar tce = `tce'
    ereturn scalar nde = `nde'
    ereturn scalar nie = `nie'
    ereturn scalar pm = `pm'
    ereturn scalar cde = `cde'
    ereturn scalar se_tce = `se_tce'
    ereturn scalar se_nde = `se_nde'
    ereturn scalar se_nie = `se_nie'
    ereturn scalar se_pm = `se_pm'
    ereturn scalar se_cde = `se_cde'
    matrix `se_mat' = (`se_tce', `se_nde', `se_nie', `se_pm', `se_cde')
    matrix colnames `se_mat' = tce nde nie pm cde
    ereturn matrix se = `se_mat'

    * CI matrices (2 rows x 5 cols: row1=lower, row2=upper)
    foreach ci in cin cip cibc cibca {
        matrix ``ci'' = J(2, 5, .)
    }
    forvalues j = 1/5 {
        local vals tce nde nie pm cde
        local se_vals se_tce se_nde se_nie se_pm se_cde
        local v : word `j' of `vals'
        local s : word `j' of `se_vals'
        matrix `cin'[1,`j'] = ``v'' - 1.96*``s''
        matrix `cin'[2,`j'] = ``v'' + 1.96*``s''
        matrix `cip'[1,`j'] = ``v'' - 2.0*``s''
        matrix `cip'[2,`j'] = ``v'' + 1.9*``s''
        matrix `cibc'[1,`j'] = ``v'' - 2.05*``s''
        matrix `cibc'[2,`j'] = ``v'' + 1.85*``s''
        matrix `cibca'[1,`j'] = ``v'' - 2.1*``s''
        matrix `cibca'[2,`j'] = ``v'' + 1.8*``s''
    }
    foreach ci in cin cip cibc cibca {
        matrix colnames ``ci'' = tce nde nie pm cde
    }
    ereturn matrix ci_normal = `cin'
    ereturn matrix ci_percentile = `cip'
    ereturn matrix ci_bc = `cibc'
    ereturn matrix ci_bca = `cibca'
end

* ============================================================
* Generate shared synthetic data
* ============================================================

clear
set seed 12345
set obs 500
gen double c = rnormal()
gen double x = rbinomial(1, invlogit(-0.5 + 0.3*c))
gen double m = rbinomial(1, invlogit(-1 + 0.8*x + 0.5*c))
gen double y = rbinomial(1, invlogit(-1.5 + 0.6*m + 0.4*x + 0.3*c))
tempfile syndata
save `syndata'

* ============================================================
* gcomp: Basic functionality
* ============================================================

* 1. File loads and all programs defined
local ++test_count
capture noisily {
    capture program list gcomp
    assert _rc == 0
    capture program list _gcomp_bootstrap
    assert _rc == 0
    capture program list _gcomp_detangle
    assert _rc == 0
    capture program list _gcomp_formatline
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: All programs defined (gcomp, _gcomp_bootstrap, _gcomp_detangle, _gcomp_formatline)"
    local ++pass_count
}
else {
    display as error "  FAIL: Not all programs defined (error `=_rc')"
    local ++fail_count
}

* 2. Basic OBE mediation
local ++test_count
capture noisily {
    use `syndata', clear
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(5) seed(1)
}
if _rc == 0 {
    display as result "  PASS: Basic OBE mediation runs"
    local ++pass_count
}
else {
    display as error "  FAIL: Basic OBE mediation (error `=_rc')"
    local ++fail_count
}

* 3. e(cmd) and e(analysis_type)
local ++test_count
capture noisily {
    assert "`e(cmd)'" == "gcomp"
    assert "`e(analysis_type)'" == "mediation"
}
if _rc == 0 {
    display as result "  PASS: e(cmd)=gcomp, e(analysis_type)=mediation"
    local ++pass_count
}
else {
    display as error "  FAIL: e(cmd) or e(analysis_type) incorrect (error `=_rc')"
    local ++fail_count
}

* 4. e() convenience scalars exist
local ++test_count
capture noisily {
    confirm scalar e(tce)
    confirm scalar e(nde)
    confirm scalar e(nie)
    confirm scalar e(pm)
    confirm scalar e(se_tce)
    confirm scalar e(se_nde)
    confirm scalar e(se_nie)
    confirm scalar e(se_pm)
}
if _rc == 0 {
    display as result "  PASS: All e() convenience scalars present"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing e() convenience scalars (error `=_rc')"
    local ++fail_count
}

* 5. e(b) and e(V) structure
local ++test_count
capture noisily {
    confirm matrix e(b)
    confirm matrix e(V)
    tempname _eb _eV
    matrix `_eb' = e(b)
    matrix `_eV' = e(V)
    local _colnames : colnames `_eb'
    local _first : word 1 of `_colnames'
    assert "`_first'" == "tce"
    local _k = colsof(`_eb')
    assert rowsof(`_eV') == `_k'
    assert colsof(`_eV') == `_k'
}
if _rc == 0 {
    display as result "  PASS: e(b) named columns, e(V) is k x k"
    local ++pass_count
}
else {
    display as error "  FAIL: e(b)/e(V) structure (error `=_rc')"
    local ++fail_count
}

* 6. e(se) and e(ci_normal) matrices
local ++test_count
capture noisily {
    confirm matrix e(se)
    confirm matrix e(ci_normal)
    tempname _se _ci
    matrix `_se' = e(se)
    matrix `_ci' = e(ci_normal)
    assert colsof(`_se') == colsof(e(b))
    assert rowsof(`_ci') == 2
    assert colsof(`_ci') == colsof(e(b))
}
if _rc == 0 {
    display as result "  PASS: e(se) and e(ci_normal) matrices correct dimensions"
    local ++pass_count
}
else {
    display as error "  FAIL: e(se)/e(ci_normal) structure (error `=_rc')"
    local ++fail_count
}

* 7. e() macro metadata
local ++test_count
capture noisily {
    assert "`e(outcome)'" == "y"
    assert "`e(exposure)'" == "x"
    assert "`e(mediator)'" == "m"
    assert "`e(mediation_type)'" == "obe"
    assert "`e(scale)'" == "RD"
}
if _rc == 0 {
    display as result "  PASS: e() macros (outcome, exposure, mediator, mediation_type, scale)"
    local ++pass_count
}
else {
    display as error "  FAIL: e() macros incorrect (error `=_rc')"
    local ++fail_count
}

* ============================================================
* gcomp: Option tests
* ============================================================

* 8. OBE with control() for CDE
local ++test_count
capture noisily {
    use `syndata', clear
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) control(0) sim(100) samples(5) seed(1)
    confirm scalar e(cde)
    confirm scalar e(se_cde)
    tempname _b
    matrix `_b' = e(b)
    assert colsof(`_b') == 5
    local _last : word 5 of `: colnames `_b''
    assert "`_last'" == "cde"
}
if _rc == 0 {
    display as result "  PASS: control() option produces CDE in e(b)"
    local ++pass_count
}
else {
    display as error "  FAIL: control() option (error `=_rc')"
    local ++fail_count
}

* 9. OCE mediation (categorical exposure)
local ++test_count
capture noisily {
    clear
    set seed 54321
    set obs 500
    gen double y = rbinomial(1, 0.3)
    gen double m = rbinomial(1, 0.5)
    gen double x = floor(runiform() * 3)
    gen double c = rnormal()
    gcomp y m x c, outcome(y) mediation oce ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(5) seed(1)
    assert "`e(mediation_type)'" == "oce"
}
if _rc == 0 {
    display as result "  PASS: OCE mediation (categorical exposure)"
    local ++pass_count
}
else {
    display as error "  FAIL: OCE mediation (error `=_rc')"
    local ++fail_count
}

* 10. OCE without baseline() auto-detects (Bug #2 regression)
local ++test_count
capture noisily {
    clear
    set seed 54321
    set obs 500
    gen double y = rbinomial(1, 0.3)
    gen double m = rbinomial(1, 0.5)
    gen double x = floor(runiform() * 3)
    gen double c = rnormal()
    gcomp y m x c, outcome(y) mediation oce ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(10) seed(1)
}
if _rc == 0 {
    display as result "  PASS: OCE without baseline() auto-detects baseline"
    local ++pass_count
}
else {
    display as error "  FAIL: OCE without baseline() (error `=_rc')"
    local ++fail_count
}

* 11. all option (all CI types)
local ++test_count
capture noisily {
    use `syndata', clear
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(5) seed(1) all
    confirm matrix e(ci_normal)
    confirm matrix e(ci_percentile)
    confirm matrix e(ci_bc)
    confirm matrix e(ci_bca)
}
if _rc == 0 {
    display as result "  PASS: all option produces 4 CI matrices"
    local ++pass_count
}
else {
    display as error "  FAIL: all option (error `=_rc')"
    local ++fail_count
}

* 12. minsim option (expected values instead of random draws)
local ++test_count
capture noisily {
    use `syndata', clear
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(5) seed(1) minsim
    confirm scalar e(tce)
}
if _rc == 0 {
    display as result "  PASS: minsim option runs"
    local ++pass_count
}
else {
    display as error "  FAIL: minsim option (error `=_rc')"
    local ++fail_count
}

* 13. logOR option
local ++test_count
capture noisily {
    use `syndata', clear
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(5) seed(1) logOR
    assert "`e(scale)'" == "logOR"
}
if _rc == 0 {
    display as result "  PASS: logOR option sets scale=logOR"
    local ++pass_count
}
else {
    display as error "  FAIL: logOR option (error `=_rc')"
    local ++fail_count
}

* 14. logRR option
local ++test_count
capture noisily {
    use `syndata', clear
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(5) seed(1) logRR
    assert "`e(scale)'" == "logRR"
}
if _rc == 0 {
    display as result "  PASS: logRR option sets scale=logRR"
    local ++pass_count
}
else {
    display as error "  FAIL: logRR option (error `=_rc')"
    local ++fail_count
}

* 15. seed option (reproducibility)
local ++test_count
capture noisily {
    use `syndata', clear
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(5) seed(999)
    local tce1 = e(tce)

    use `syndata', clear
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(5) seed(999)
    local tce2 = e(tce)

    assert reldif(`tce1', `tce2') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: Same seed produces identical results"
    local ++pass_count
}
else {
    display as error "  FAIL: Seed reproducibility (error `=_rc')"
    local ++fail_count
}

* ============================================================
* gcomp: Internal subprograms
* ============================================================

* 16. _gcomp_detangle parses model specs
local ++test_count
capture noisily {
    use `syndata', clear
    _gcomp_detangle "m: logit, y: logit" command "m y"
    assert "${S_1}" == "logit"
    assert "${S_2}" == "logit"
}
if _rc == 0 {
    display as result "  PASS: _gcomp_detangle parses model specifications"
    local ++pass_count
}
else {
    display as error "  FAIL: _gcomp_detangle (error `=_rc')"
    local ++fail_count
}

* 17. _gcomp_formatline wraps long variable lists
local ++test_count
capture noisily {
    _gcomp_formatline, n("x c m y some_long_variable another") maxlen(20)
    assert r(lines) >= 1
}
if _rc == 0 {
    display as result "  PASS: _gcomp_formatline wraps long lists (r(lines)=`=r(lines)')"
    local ++pass_count
}
else {
    display as error "  FAIL: _gcomp_formatline (error `=_rc')"
    local ++fail_count
}

* ============================================================
* gcomp: No global pollution
* ============================================================

* 18. No leaked global macros (Bug #3 regression)
local ++test_count
capture noisily {
    use `syndata', clear

    * Record globals before
    local globals_before : all globals

    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(5) seed(1)

    * Check known leaked globals from SSC version
    local leaked = 0
    foreach g in maxid check_delete check_print check_save almost_varlist {
        capture confirm existence ${`g'}
        if _rc == 0 {
            local ++leaked
        }
    }
    assert `leaked' == 0
}
if _rc == 0 {
    display as result "  PASS: No leaked global macros"
    local ++pass_count
}
else {
    display as error "  FAIL: Global macro pollution (error `=_rc')"
    local ++fail_count
}

* 19. No leaked global matrices
local ++test_count
capture noisily {
    local leaked = 0
    foreach mat in _po _se_po _b_msm _se_msm ci_normal ci_percentile ci_bc ci_bca {
        capture confirm matrix `mat'
        if _rc == 0 {
            local ++leaked
        }
    }
    assert `leaked' == 0
}
if _rc == 0 {
    display as result "  PASS: No leaked global matrices"
    local ++pass_count
}
else {
    display as error "  FAIL: Global matrix pollution (error `=_rc')"
    local ++fail_count
}

* 20. No deprecated uniform() in source
local ++test_count
capture noisily {
    tempfile temp1 temp2
    capture findfile gcomp.ado
    copy "`r(fn)'" `temp1', replace
    filefilter `temp1' `temp2', from("runiform()") to("SAFE_FUNC")
    filefilter `temp2' `temp1', from("uniform()") to("FOUND_IT") replace
    assert r(occurrences) == 0
}
if _rc == 0 {
    display as result "  PASS: No deprecated uniform() in source"
    local ++pass_count
}
else {
    display as error "  FAIL: Found deprecated uniform() in source (error `=_rc')"
    local ++fail_count
}

* ============================================================
* gcomp: Data preservation
* ============================================================

* 21. _N unchanged after gcomp
local ++test_count
capture noisily {
    use `syndata', clear
    local N_before = _N
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(5) seed(1)
    assert _N == `N_before'
}
if _rc == 0 {
    display as result "  PASS: _N preserved after gcomp (`=_N' obs)"
    local ++pass_count
}
else {
    display as error "  FAIL: _N changed after gcomp (error `=_rc')"
    local ++fail_count
}

* 22. estimates store/restore works (eclass proof)
local ++test_count
capture noisily {
    estimates store gcomp_test
    estimates restore gcomp_test
    assert "`e(cmd)'" == "gcomp"
    confirm scalar e(tce)
    confirm matrix e(b)
    estimates drop gcomp_test
}
if _rc == 0 {
    display as result "  PASS: estimates store/restore works"
    local ++pass_count
}
else {
    display as error "  FAIL: estimates store/restore (error `=_rc')"
    local ++fail_count
}

* ============================================================
* gcomptab: Basic functionality
* ============================================================

* 23. Basic gcomptab output
local ++test_count
capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08) ///
        se_tce(0.03) se_nde(0.025) se_nie(0.015) se_pm(0.08) se_cde(0.025)
    gcomptab, xlsx("`testdir'/_test_gcomptab.xlsx") sheet("Basic")
    confirm file "`testdir'/_test_gcomptab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: Basic gcomptab creates Excel file"
    local ++pass_count
}
else {
    display as error "  FAIL: Basic gcomptab (error `=_rc')"
    local ++fail_count
}

* 24. With title option
local ++test_count
capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)
    gcomptab, xlsx("`testdir'/_test_gcomptab_title.xlsx") sheet("Table 2") ///
        title("Table 2. Causal Mediation Analysis Results")
    confirm file "`testdir'/_test_gcomptab_title.xlsx"
}
if _rc == 0 {
    display as result "  PASS: title() option"
    local ++pass_count
}
else {
    display as error "  FAIL: title() option (error `=_rc')"
    local ++fail_count
}

* 25-28. CI type options
foreach citype in normal percentile bc bca {
    local ++test_count
    capture noisily {
        mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)
        gcomptab, xlsx("`testdir'/_test_gcomptab_`citype'.xlsx") ///
            sheet("`citype'") ci(`citype')
        confirm file "`testdir'/_test_gcomptab_`citype'.xlsx"
        assert "`r(ci)'" == "`citype'"
    }
    if _rc == 0 {
        display as result "  PASS: ci(`citype') option"
        local ++pass_count
    }
    else {
        display as error "  FAIL: ci(`citype') option (error `=_rc')"
        local ++fail_count
    }
}

* 29. Custom effect label
local ++test_count
capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)
    gcomptab, xlsx("`testdir'/_test_gcomptab_effect.xlsx") sheet("RD") ///
        effect("Risk Diff")
    confirm file "`testdir'/_test_gcomptab_effect.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effect() option"
    local ++pass_count
}
else {
    display as error "  FAIL: effect() option (error `=_rc')"
    local ++fail_count
}

* 30. Custom labels
local ++test_count
capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)
    gcomptab, xlsx("`testdir'/_test_gcomptab_labels.xlsx") sheet("Custom") ///
        labels("Total \ Direct \ Indirect \ % Med \ CDE")
    confirm file "`testdir'/_test_gcomptab_labels.xlsx"
}
if _rc == 0 {
    display as result "  PASS: labels() option"
    local ++pass_count
}
else {
    display as error "  FAIL: labels() option (error `=_rc')"
    local ++fail_count
}

* 31-33. Decimal precision options
foreach dec in 2 3 4 {
    local ++test_count
    capture noisily {
        mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)
        gcomptab, xlsx("`testdir'/_test_gcomptab_dec`dec'.xlsx") ///
            sheet("Dec`dec'") decimal(`dec')
        confirm file "`testdir'/_test_gcomptab_dec`dec'.xlsx"
    }
    if _rc == 0 {
        display as result "  PASS: decimal(`dec') option"
        local ++pass_count
    }
    else {
        display as error "  FAIL: decimal(`dec') option (error `=_rc')"
        local ++fail_count
    }
}

* 34. All options combined
local ++test_count
capture noisily {
    mock_gcomp, tce(0.18) nde(0.11) nie(0.07) pm(0.39) cde(0.09) ///
        se_tce(0.035) se_nde(0.028) se_nie(0.018) se_pm(0.09) se_cde(0.028)
    gcomptab, xlsx("`testdir'/_test_gcomptab_full.xlsx") sheet("Complete") ///
        ci(percentile) effect("RD") decimal(4) ///
        labels("TCE \ NDE \ NIE \ PM \ CDE") ///
        title("Table 3. Full Options Test")
    confirm file "`testdir'/_test_gcomptab_full.xlsx"
}
if _rc == 0 {
    display as result "  PASS: All gcomptab options combined"
    local ++pass_count
}
else {
    display as error "  FAIL: All options combined (error `=_rc')"
    local ++fail_count
}

* 35. Multiple sheets in same file
local ++test_count
capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)
    gcomptab, xlsx("`testdir'/_test_gcomptab_multi.xlsx") sheet("Model 1") ///
        title("Model 1: Unadjusted")
    mock_gcomp, tce(0.12) nde(0.08) nie(0.04) pm(0.33) cde(0.07)
    gcomptab, xlsx("`testdir'/_test_gcomptab_multi.xlsx") sheet("Model 2") ///
        title("Model 2: Adjusted")
    confirm file "`testdir'/_test_gcomptab_multi.xlsx"
}
if _rc == 0 {
    display as result "  PASS: Multiple sheets in same file"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple sheets (error `=_rc')"
    local ++fail_count
}

* ============================================================
* gcomptab: r() stored results
* ============================================================

* 36. r() scalars match input
local ++test_count
capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)
    gcomptab, xlsx("`testdir'/_test_gcomptab_r.xlsx") sheet("R")
    assert reldif(r(tce), 0.15) < 0.0001
    assert reldif(r(nde), 0.10) < 0.0001
    assert reldif(r(nie), 0.05) < 0.0001
    assert reldif(r(pm), 0.33) < 0.0001
    assert reldif(r(cde), 0.08) < 0.0001
    assert r(N_effects) == 5
}
if _rc == 0 {
    display as result "  PASS: r() scalars match input values"
    local ++pass_count
}
else {
    display as error "  FAIL: r() scalars (error `=_rc')"
    local ++fail_count
}

* 37. r() macros stored
local ++test_count
capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)
    gcomptab, xlsx("`testdir'/_test_gcomptab_rmac.xlsx") sheet("RMac") ci(bc)
    assert "`r(xlsx)'" == "`testdir'/_test_gcomptab_rmac.xlsx"
    assert "`r(sheet)'" == "RMac"
    assert "`r(ci)'" == "bc"
}
if _rc == 0 {
    display as result "  PASS: r() macros (xlsx, sheet, ci)"
    local ++pass_count
}
else {
    display as error "  FAIL: r() macros (error `=_rc')"
    local ++fail_count
}

* ============================================================
* gcomptab: Edge cases
* ============================================================

* 38. Negative (protective) effects
local ++test_count
capture noisily {
    mock_gcomp, tce(-0.12) nde(-0.08) nie(-0.04) pm(0.33) cde(-0.07) ///
        se_tce(0.04) se_nde(0.03) se_nie(0.02) se_pm(0.10) se_cde(0.03)
    gcomptab, xlsx("`testdir'/_test_gcomptab_neg.xlsx") sheet("Negative")
    confirm file "`testdir'/_test_gcomptab_neg.xlsx"
}
if _rc == 0 {
    display as result "  PASS: Negative effects handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Negative effects (error `=_rc')"
    local ++fail_count
}

* 39. Very small effects
local ++test_count
capture noisily {
    mock_gcomp, tce(0.001) nde(0.0008) nie(0.0002) pm(0.20) cde(0.0007)
    gcomptab, xlsx("`testdir'/_test_gcomptab_small.xlsx") sheet("Small") decimal(4)
    confirm file "`testdir'/_test_gcomptab_small.xlsx"
}
if _rc == 0 {
    display as result "  PASS: Very small effects handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Very small effects (error `=_rc')"
    local ++fail_count
}

* 40. Large effects
local ++test_count
capture noisily {
    mock_gcomp, tce(0.85) nde(0.60) nie(0.25) pm(0.29) cde(0.55) ///
        se_tce(0.08) se_nde(0.06) se_nie(0.05) se_pm(0.10) se_cde(0.06)
    gcomptab, xlsx("`testdir'/_test_gcomptab_large.xlsx") sheet("Large")
    confirm file "`testdir'/_test_gcomptab_large.xlsx"
}
if _rc == 0 {
    display as result "  PASS: Large effects handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Large effects (error `=_rc')"
    local ++fail_count
}

* ============================================================
* gcomptab: Error handling
* ============================================================

* 41. Error when no gcomp results
local ++test_count
capture noisily {
    clear
    set obs 10
    gen double _y = rnormal()
    gen double _x = rnormal()
    quietly regress _y _x
    capture gcomptab, xlsx("`testdir'/_test_error.xlsx") sheet("Error")
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Error when e(cmd) != gcomp"
    local ++pass_count
}
else {
    display as error "  FAIL: Should error without gcomp results (error `=_rc')"
    local ++fail_count
}

* 42. Error for invalid CI type
local ++test_count
capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)
    capture gcomptab, xlsx("`testdir'/_test_error.xlsx") sheet("Error") ci(invalid)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Error for invalid CI type"
    local ++pass_count
}
else {
    display as error "  FAIL: Should error for invalid CI type (error `=_rc')"
    local ++fail_count
}

* 43. Error for invalid decimal
local ++test_count
capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)
    capture gcomptab, xlsx("`testdir'/_test_error.xlsx") sheet("Error") decimal(10)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Error for decimal out of range"
    local ++pass_count
}
else {
    display as error "  FAIL: Should error for decimal=10 (error `=_rc')"
    local ++fail_count
}

* 44. Error for invalid file extension
local ++test_count
capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)
    capture gcomptab, xlsx("`testdir'/_test_error.xls") sheet("Error")
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Error for non-.xlsx extension"
    local ++pass_count
}
else {
    display as error "  FAIL: Should error for .xls extension (error `=_rc')"
    local ++fail_count
}

* ============================================================
* gcomp + gcomptab: Integration
* ============================================================

* 45. Full pipeline: gcomp → gcomptab
local ++test_count
capture noisily {
    use `syndata', clear
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(5) seed(1)
    gcomptab, xlsx("`testdir'/_test_integration.xlsx") ///
        sheet("Integration") ///
        title("Integration Test")
    confirm file "`testdir'/_test_integration.xlsx"
}
if _rc == 0 {
    display as result "  PASS: Full gcomp -> gcomptab pipeline"
    local ++pass_count
}
else {
    display as error "  FAIL: gcomp -> gcomptab pipeline (error `=_rc')"
    local ++fail_count
}

* 46. e() persists after gcomptab (rclass doesn't clear eclass)
local ++test_count
capture noisily {
    assert "`e(cmd)'" == "gcomp"
    assert "`e(analysis_type)'" == "mediation"
    confirm scalar e(tce)
    confirm matrix e(b)
}
if _rc == 0 {
    display as result "  PASS: e() persists after gcomptab call"
    local ++pass_count
}
else {
    display as error "  FAIL: e() cleared by gcomptab (error `=_rc')"
    local ++fail_count
}

* 47. gcomp with all + gcomptab with each CI type
local ++test_count
capture noisily {
    use `syndata', clear
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(5) seed(1) all

    foreach citype in normal percentile bc bca {
        gcomptab, xlsx("`testdir'/_test_integ_ci.xlsx") ///
            sheet("`citype'") ci(`citype')
    }
    confirm file "`testdir'/_test_integ_ci.xlsx"
}
if _rc == 0 {
    display as result "  PASS: gcomp all + gcomptab each CI type"
    local ++pass_count
}
else {
    display as error "  FAIL: gcomp all + gcomptab CI types (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Cleanup
* ============================================================

capture program drop mock_gcomp
local xlsx_files : dir "`testdir'" files "_test_gcomptab*.xlsx"
foreach f of local xlsx_files {
    capture erase "`testdir'/`f'"
}
foreach f in _test_integration _test_integ_ci _test_error {
    capture erase "`testdir'/`f'.xlsx"
}

* ============================================================
* Summary
* ============================================================

display ""
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_gcomp tests=`test_count' pass=`pass_count' fail=`fail_count' status=" _continue
if `fail_count' > 0 {
    display as error "FAIL"
    exit 1
}
else {
    display as result "PASS"
}
