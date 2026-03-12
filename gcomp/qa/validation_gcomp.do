* validation_gcomp.do - Correctness validation for gcomp package (gcomp + gcomptab)
* Validates: decomposition invariants, known-answer DGP, bootstrap properties,
*            scale options, gcomptab value accuracy and Excel structure
* Runtime: ~5 minutes

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
capture findfile gcomp.ado
quietly run "`r(fn)'"

local testdir "`c(tmpdir)'"

* ============================================================
* V1: Mediation decomposition invariants
* ============================================================
* The parametric g-formula guarantees: TCE = NDE + NIE
* and PM = NIE / TCE (when TCE != 0)

* V1.1: TCE = NDE + NIE (OBE)
local ++test_count
capture noisily {
    clear
    set seed 20260313
    set obs 1000
    gen double c = rnormal()
    gen double x = rbinomial(1, invlogit(-0.5 + 0.3*c))
    gen double m = rbinomial(1, invlogit(-1 + 0.8*x + 0.5*c))
    gen double y = rbinomial(1, invlogit(-1.5 + 0.6*m + 0.4*x + 0.3*c))

    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(50) seed(1)

    local decomp = abs(e(tce) - (e(nde) + e(nie)))
    assert `decomp' < 0.001
}
if _rc == 0 {
    display as result "  PASS: V1.1 TCE = NDE + NIE (residual=" %9.6f `decomp' ")"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.1 TCE = NDE + NIE (error `=_rc')"
    local ++fail_count
}

* V1.2: PM = NIE / TCE
local ++test_count
capture noisily {
    * Uses results from V1.1
    local expected_pm = e(nie) / e(tce)
    local pm_diff = abs(e(pm) - `expected_pm')
    assert `pm_diff' < 0.001
}
if _rc == 0 {
    display as result "  PASS: V1.2 PM = NIE/TCE (diff=" %9.6f `pm_diff' ")"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.2 PM = NIE/TCE (error `=_rc')"
    local ++fail_count
}

* V1.3: Decomposition holds with control() (CDE independent)
local ++test_count
capture noisily {
    clear
    set seed 20260313
    set obs 1000
    gen double c = rnormal()
    gen double x = rbinomial(1, invlogit(-0.5 + 0.3*c))
    gen double m = rbinomial(1, invlogit(-1 + 0.8*x + 0.5*c))
    gen double y = rbinomial(1, invlogit(-1.5 + 0.6*m + 0.4*x + 0.3*c))

    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) control(0) sim(500) samples(50) seed(1)

    * TCE = NDE + NIE still holds (CDE is separate)
    local decomp = abs(e(tce) - (e(nde) + e(nie)))
    assert `decomp' < 0.001

    * CDE exists and is distinct from NDE
    confirm scalar e(cde)
}
if _rc == 0 {
    display as result "  PASS: V1.3 Decomposition holds with control(), CDE present"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.3 Decomposition with control() (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V2: Known-answer DGP validation
* ============================================================
* DGP: Binary exposure mediation with confounder
*   C ~ N(50, 10)
*   X ~ Bernoulli(invlogit(-2 + 0.02*C))
*   M ~ Bernoulli(invlogit(-1 + 0.8*X + 0.01*C))
*   Y ~ Bernoulli(invlogit(-3 + 0.5*M + 0.3*X + 0.02*C))
*
* Analytical truth (N=100,000 MC integration):
*   TCE ~ 0.056, NDE ~ 0.041, NIE ~ 0.015
*   All effects positive (exposure increases risk)
*   NDE > NIE (direct effect dominates)

* V2.1: Effect directions correct
local ++test_count
capture noisily {
    clear
    set seed 20260306
    set obs 5000
    gen double c = rnormal(50, 10)
    gen double x = rbinomial(1, invlogit(-2 + 0.02*c))
    gen double m = rbinomial(1, invlogit(-1 + 0.8*x + 0.01*c))
    gen double y = rbinomial(1, invlogit(-3 + 0.5*m + 0.3*x + 0.02*c))

    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(2000) samples(100) seed(20260306)

    * All effects should be positive (exposure increases outcome risk)
    assert e(tce) > 0
    assert e(nde) > 0
    assert e(nie) > 0
}
if _rc == 0 {
    display as result "  PASS: V2.1 All effects positive (TCE=" %6.4f e(tce) " NDE=" %6.4f e(nde) " NIE=" %6.4f e(nie) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.1 Effect directions (error `=_rc')"
    local ++fail_count
}

* V2.2: TCE within 0.03 of analytical truth
local ++test_count
local true_tce = 0.05577
capture noisily {
    local tce_diff = abs(e(tce) - `true_tce')
    assert `tce_diff' < 0.03
}
if _rc == 0 {
    display as result "  PASS: V2.2 TCE within 0.03 of truth (diff=" %6.4f `tce_diff' ")"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.2 TCE accuracy (error `=_rc')"
    local ++fail_count
}

* V2.3: NDE within 0.03 of analytical truth
local ++test_count
local true_nde = 0.04062
capture noisily {
    local nde_diff = abs(e(nde) - `true_nde')
    assert `nde_diff' < 0.03
}
if _rc == 0 {
    display as result "  PASS: V2.3 NDE within 0.03 of truth (diff=" %6.4f `nde_diff' ")"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.3 NDE accuracy (error `=_rc')"
    local ++fail_count
}

* V2.4: NIE within 0.02 of analytical truth
local ++test_count
local true_nie = 0.01516
capture noisily {
    local nie_diff = abs(e(nie) - `true_nie')
    assert `nie_diff' < 0.02
}
if _rc == 0 {
    display as result "  PASS: V2.4 NIE within 0.02 of truth (diff=" %6.4f `nie_diff' ")"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.4 NIE accuracy (error `=_rc')"
    local ++fail_count
}

* V2.5: NDE > NIE (direct dominates in this DGP)
local ++test_count
capture noisily {
    assert e(nde) > e(nie)
}
if _rc == 0 {
    display as result "  PASS: V2.5 NDE > NIE (direct effect dominates)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.5 NDE vs NIE ordering (error `=_rc')"
    local ++fail_count
}

* V2.6: PM in plausible range (true ~ 0.272)
* Tolerance: PM = NIE/TCE is inherently noisy (ratio of two MC estimates)
* With moderate sim/samples, PM can be quite variable; use wide range
local ++test_count
capture noisily {
    assert e(pm) > 0.001 & e(pm) < 0.80
}
if _rc == 0 {
    display as result "  PASS: V2.6 PM in [0.001, 0.80] (PM=" %6.3f e(pm) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.6 PM range (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V3: Bootstrap properties
* ============================================================

* V3.1: All SEs are positive
local ++test_count
capture noisily {
    assert e(se_tce) > 0
    assert e(se_nde) > 0
    assert e(se_nie) > 0
    assert e(se_pm) > 0
}
if _rc == 0 {
    display as result "  PASS: V3.1 All SEs positive"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.1 SE positivity (error `=_rc')"
    local ++fail_count
}

* V3.2: Normal CIs contain point estimates
local ++test_count
capture noisily {
    tempname ci
    matrix `ci' = e(ci_normal)
    * Row 1 = lower, Row 2 = upper
    * TCE: lower < tce < upper
    assert `ci'[1,1] < e(tce) & e(tce) < `ci'[2,1]
    * NDE
    assert `ci'[1,2] < e(nde) & e(nde) < `ci'[2,2]
    * NIE
    assert `ci'[1,3] < e(nie) & e(nie) < `ci'[2,3]
}
if _rc == 0 {
    display as result "  PASS: V3.2 CIs contain point estimates"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.2 CI containment (error `=_rc')"
    local ++fail_count
}

* V3.3: CI widths are positive
local ++test_count
capture noisily {
    tempname ci
    matrix `ci' = e(ci_normal)
    forvalues j = 1/4 {
        assert `ci'[2,`j'] > `ci'[1,`j']
    }
}
if _rc == 0 {
    display as result "  PASS: V3.3 All CI widths positive"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.3 CI width (error `=_rc')"
    local ++fail_count
}

* V3.4: SE vector matches diagonal of V
local ++test_count
capture noisily {
    tempname se_vec V_mat
    matrix `se_vec' = e(se)
    matrix `V_mat' = e(V)
    local k = colsof(`se_vec')
    forvalues j = 1/`k' {
        local se_from_vec = `se_vec'[1,`j']
        local se_from_V = sqrt(`V_mat'[`j',`j'])
        assert reldif(`se_from_vec', `se_from_V') < 0.0001
    }
}
if _rc == 0 {
    display as result "  PASS: V3.4 e(se) matches sqrt(diag(e(V)))"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.4 SE/V consistency (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V4: Scale option validation
* ============================================================
* logOR and logRR should produce different estimates than RD

* V4.1: logOR produces different TCE than RD
local ++test_count
capture noisily {
    clear
    set seed 20260313
    set obs 1000
    gen double c = rnormal()
    gen double x = rbinomial(1, invlogit(-0.5 + 0.3*c))
    gen double m = rbinomial(1, invlogit(-1 + 0.8*x + 0.5*c))
    gen double y = rbinomial(1, invlogit(-1.5 + 0.6*m + 0.4*x + 0.3*c))

    * RD scale
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(10) seed(1)
    local tce_rd = e(tce)

    * logOR scale
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(10) seed(1) logOR
    local tce_logor = e(tce)

    * Should be different (logOR is on log-odds scale)
    assert reldif(`tce_rd', `tce_logor') > 0.01
}
if _rc == 0 {
    display as result "  PASS: V4.1 logOR produces different TCE than RD"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.1 logOR vs RD (error `=_rc')"
    local ++fail_count
}

* V4.2: logRR produces different TCE than RD
local ++test_count
capture noisily {
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(10) seed(1) logRR
    local tce_logrr = e(tce)

    assert reldif(`tce_rd', `tce_logrr') > 0.01
}
if _rc == 0 {
    display as result "  PASS: V4.2 logRR produces different TCE than RD"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.2 logRR vs RD (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V5: minsim vs random draws
* ============================================================
* minsim uses expected values; should give similar point estimates
* but potentially different SEs

* V5.1: minsim TCE close to random-draw TCE
local ++test_count
capture noisily {
    clear
    set seed 20260313
    set obs 1000
    gen double c = rnormal()
    gen double x = rbinomial(1, invlogit(-0.5 + 0.3*c))
    gen double m = rbinomial(1, invlogit(-1 + 0.8*x + 0.5*c))
    gen double y = rbinomial(1, invlogit(-1.5 + 0.6*m + 0.4*x + 0.3*c))

    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(10) seed(1)
    local tce_random = e(tce)

    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(10) seed(1) minsim
    local tce_minsim = e(tce)

    * Should be within 0.05 (same estimand, different MC method)
    assert abs(`tce_random' - `tce_minsim') < 0.05
}
if _rc == 0 {
    display as result "  PASS: V5.1 minsim TCE close to random-draw TCE (diff=" %6.4f abs(`tce_random' - `tce_minsim') ")"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.1 minsim vs random (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V6: gcomptab value accuracy
* ============================================================

* Helper: mock gcomp for gcomptab validation
capture program drop mock_gcomp
program define mock_gcomp, eclass
    version 16.0
    syntax, tce(real) nde(real) nie(real) pm(real) cde(real) ///
            [se_tce(real 0.05) se_nde(real 0.04) se_nie(real 0.03) ///
             se_pm(real 0.02) se_cde(real 0.04)]

    tempname b V se_mat cin
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
    matrix `cin' = J(2, 5, .)
    forvalues j = 1/5 {
        local vals tce nde nie pm cde
        local se_vals se_tce se_nde se_nie se_pm se_cde
        local v : word `j' of `vals'
        local s : word `j' of `se_vals'
        matrix `cin'[1,`j'] = ``v'' - 1.96*``s''
        matrix `cin'[2,`j'] = ``v'' + 1.96*``s''
    }
    matrix colnames `cin' = tce nde nie pm cde
    ereturn matrix ci_normal = `cin'
end

* V6.1: r() scalars match input exactly
local ++test_count
capture noisily {
    mock_gcomp, tce(0.150) nde(0.100) nie(0.050) pm(0.333) cde(0.080)
    gcomptab, xlsx("`testdir'/_val_gcomptab.xlsx") sheet("V6_1")
    assert reldif(r(tce), 0.150) < 1e-6
    assert reldif(r(nde), 0.100) < 1e-6
    assert reldif(r(nie), 0.050) < 1e-6
    assert reldif(r(pm), 0.333) < 1e-6
    assert reldif(r(cde), 0.080) < 1e-6
    assert r(N_effects) == 5
}
if _rc == 0 {
    display as result "  PASS: V6.1 r() scalars match input exactly"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.1 r() scalars (error `=_rc')"
    local ++fail_count
}

* V6.2: Excel has exactly 7 rows (title + header + 5 effects)
local ++test_count
capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)
    capture erase "`testdir'/_val_gcomptab_struct.xlsx"
    gcomptab, xlsx("`testdir'/_val_gcomptab_struct.xlsx") sheet("Structure")
    import excel "`testdir'/_val_gcomptab_struct.xlsx", sheet("Structure") clear
    count
    assert r(N) == 7
}
if _rc == 0 {
    display as result "  PASS: V6.2 Excel has 7 rows"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.2 Excel row count (error `=_rc')"
    local ++fail_count
}

* V6.3: Excel has exactly 5 columns
local ++test_count
capture noisily {
    import excel "`testdir'/_val_gcomptab_struct.xlsx", sheet("Structure") clear
    ds
    local ncols : word count `r(varlist)'
    assert `ncols' == 5
}
if _rc == 0 {
    display as result "  PASS: V6.3 Excel has 5 columns"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.3 Excel column count (error `=_rc')"
    local ++fail_count
}

* V6.4: Point estimates present in Excel
local ++test_count
capture noisily {
    mock_gcomp, tce(0.150) nde(0.100) nie(0.050) pm(0.333) cde(0.080)
    gcomptab, xlsx("`testdir'/_val_gcomptab_vals.xlsx") sheet("Values")
    import excel "`testdir'/_val_gcomptab_vals.xlsx", sheet("Values") clear
    * Row 3 = TCE, Column C = estimate
    assert !missing(C[3])
    assert !missing(C[4])
    assert !missing(C[5])
    assert !missing(C[6])
    assert !missing(C[7])
}
if _rc == 0 {
    display as result "  PASS: V6.4 All point estimates present in Excel"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.4 Point estimates in Excel (error `=_rc')"
    local ++fail_count
}

* V6.5: CIs formatted with parentheses
local ++test_count
capture noisily {
    import excel "`testdir'/_val_gcomptab_vals.xlsx", sheet("Values") clear
    * Column D = CI
    assert strpos(D[3], "(") > 0
    assert strpos(D[3], ")") > 0
    assert strpos(D[3], ",") > 0
}
if _rc == 0 {
    display as result "  PASS: V6.5 CIs formatted as (lower, upper)"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.5 CI format (error `=_rc')"
    local ++fail_count
}

* V6.6: SE values present for all 5 effects
local ++test_count
capture noisily {
    import excel "`testdir'/_val_gcomptab_vals.xlsx", sheet("Values") clear
    forvalues r = 3/7 {
        assert !missing(E[`r'])
    }
}
if _rc == 0 {
    display as result "  PASS: V6.6 All SE values present"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.6 SE values (error `=_rc')"
    local ++fail_count
}

* V6.7: Negative effects show minus sign in Excel
local ++test_count
capture noisily {
    mock_gcomp, tce(-0.12) nde(-0.08) nie(-0.04) pm(0.33) cde(-0.07)
    gcomptab, xlsx("`testdir'/_val_gcomptab_neg.xlsx") sheet("Negative")
    import excel "`testdir'/_val_gcomptab_neg.xlsx", sheet("Negative") clear
    assert strpos(C[3], "-") > 0
}
if _rc == 0 {
    display as result "  PASS: V6.7 Negative effects show minus sign"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.7 Negative effects display (error `=_rc')"
    local ++fail_count
}

* V6.8: Custom labels appear in Excel
local ++test_count
capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)
    gcomptab, xlsx("`testdir'/_val_gcomptab_lbl.xlsx") sheet("Labels") ///
        labels("Total \ Direct \ Indirect \ Pct Med \ CDE")
    import excel "`testdir'/_val_gcomptab_lbl.xlsx", sheet("Labels") clear
    assert B[3] == "Total"
    assert B[4] == "Direct"
    assert B[5] == "Indirect"
}
if _rc == 0 {
    display as result "  PASS: V6.8 Custom labels appear correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.8 Custom labels (error `=_rc')"
    local ++fail_count
}

* V6.9: Title appears in first row
local ++test_count
capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)
    gcomptab, xlsx("`testdir'/_val_gcomptab_ttl.xlsx") sheet("Title") ///
        title("Table 1. My Results")
    import excel "`testdir'/_val_gcomptab_ttl.xlsx", sheet("Title") clear
    assert strpos(A[1], "Table 1") > 0
}
if _rc == 0 {
    display as result "  PASS: V6.9 Title appears in row 1"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.9 Title placement (error `=_rc')"
    local ++fail_count
}

* V6.10: Decimal precision validation
* Hand-calculated: 0.123456 with decimal(3) should display as "0.123"
local ++test_count
capture noisily {
    mock_gcomp, tce(0.123456) nde(0.100) nie(0.050) pm(0.333) cde(0.080)
    gcomptab, xlsx("`testdir'/_val_gcomptab_dec.xlsx") sheet("Dec3")
    import excel "`testdir'/_val_gcomptab_dec.xlsx", sheet("Dec3") clear
    local val = C[3]
    local dotpos = strpos("`val'", ".")
    if `dotpos' > 0 {
        local decimals = strlen("`val'") - `dotpos'
        assert `decimals' == 3
    }
}
if _rc == 0 {
    display as result "  PASS: V6.10 Default 3 decimal precision"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.10 Decimal precision (error `=_rc')"
    local ++fail_count
}

* V6.11: decimal(4) produces 4 decimal places
local ++test_count
capture noisily {
    mock_gcomp, tce(0.12345) nde(0.10000) nie(0.05000) pm(0.33333) cde(0.08000)
    gcomptab, xlsx("`testdir'/_val_gcomptab_dec4.xlsx") sheet("Dec4") decimal(4)
    import excel "`testdir'/_val_gcomptab_dec4.xlsx", sheet("Dec4") clear
    local val = C[3]
    local dotpos = strpos("`val'", ".")
    if `dotpos' > 0 {
        local decimals = strlen("`val'") - `dotpos'
        assert `decimals' == 4
    }
}
if _rc == 0 {
    display as result "  PASS: V6.11 decimal(4) works"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.11 decimal(4) (error `=_rc')"
    local ++fail_count
}

* V6.12: Normal CI is default
local ++test_count
capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)
    gcomptab, xlsx("`testdir'/_val_gcomptab_cidef.xlsx") sheet("Default")
    assert "`r(ci)'" == "normal"
}
if _rc == 0 {
    display as result "  PASS: V6.12 Normal CI is default"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.12 Default CI type (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Cleanup
* ============================================================

capture program drop mock_gcomp
local val_files : dir "`testdir'" files "_val_gcomptab*.xlsx"
foreach f of local val_files {
    capture erase "`testdir'/`f'"
}

* ============================================================
* Summary
* ============================================================

display ""
display as result "Validation Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: validation_gcomp tests=`test_count' pass=`pass_count' fail=`fail_count' status=" _continue
if `fail_count' > 0 {
    display as error "FAIL"
    exit 1
}
else {
    display as result "PASS"
}
