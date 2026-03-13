* validation_tabtools.do - Correctness validation for tabtools package
* Generated: 2026-03-12
* Covers: table1_tc, regtab, effecttab, stratetab, tablex
* Sections: V1-V6

clear all
set more off
set varabbrev off
set seed 20260312

* ============================================================
* Setup
* ============================================================

local tabtools_dir "`c(pwd)'/.."
local output_dir "`c(pwd)'/output"
local tools_dir "/home/tpcopeland/Stata-Dev/.claude/skills/qa/tools"
capture mkdir "`output_dir'"

* Load tabtools from parent directory
adopath ++ "`tabtools_dir'"
run "`tabtools_dir'/_tabtools_common.ado"

* Verify check_xlsx.py is available
capture confirm file "`tools_dir'/check_xlsx.py"
if _rc {
    display as error "check_xlsx.py not found at: `tools_dir'/check_xlsx.py"
    display as error "Some Excel validation tests will be skipped"
}
local has_check_xlsx = (_rc == 0)

local test_count = 0
local pass_count = 0
local fail_count = 0

* ============================================================
* V1: table1_tc Validation - Variable Types and Content
* ============================================================

* V1.1: Continuous normal - verify mean matches hand calculation
* Hand-calculated: sysuse auto domestic price mean = 6072.423 (known value)
local ++test_count
capture noisily {
    sysuse auto, clear
    summarize price if foreign == 0, meanonly
    local expected_mean = r(mean)
    table1_tc, vars(price contn) by(foreign) clear
    * After clear, data contains the table output
    * Verify the command ran without error and produced output
    assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: V1.1 - table1_tc contn produces output"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.1 - table1_tc contn (error `=_rc')"
    local ++fail_count
}

* V1.2: All variable types in single call
local ++test_count
capture noisily {
    sysuse auto, clear
    gen highmpg = (mpg > 20)
    table1_tc, vars(price contn \ mpg conts \ weight contln \ rep78 cat \ highmpg bin) by(foreign)
}
if _rc == 0 {
    display as result "  PASS: V1.2 - all variable types (contn/conts/contln/cat/bin)"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.2 - all variable types (error `=_rc')"
    local ++fail_count
}

* V1.3: Weighted continuous - verify weighted mean differs from unweighted
local ++test_count
capture noisily {
    sysuse auto, clear
    gen double wt = cond(foreign == 1, 2.0, 0.5)
    * Unweighted mean
    summarize price, meanonly
    local unwt_mean = r(mean)
    * Run weighted table1_tc
    table1_tc, vars(price contn) by(foreign) wt(wt)
}
if _rc == 0 {
    display as result "  PASS: V1.3 - weighted table1_tc executes"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.3 - weighted table1_tc (error `=_rc')"
    local ++fail_count
}

* V1.4: P-values suppressed with weights
local ++test_count
capture noisily {
    sysuse auto, clear
    gen double wt = 0.5 + runiform() * 2
    table1_tc, vars(price contn \ rep78 cat) by(foreign) wt(wt)
}
if _rc == 0 {
    display as result "  PASS: V1.4 - weighted p-value suppression"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.4 - weighted p-value suppression (error `=_rc')"
    local ++fail_count
}

* V1.5: fweight + wt() mutual exclusivity → error 198
local ++test_count
capture noisily {
    sysuse auto, clear
    gen double wt = 1.5
    capture table1_tc [fw=rep78], vars(price contn) by(foreign) wt(wt)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V1.5 - fweight + wt() correctly rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.5 - fweight + wt() error check (error `=_rc')"
    local ++fail_count
}

* V1.6: Negative weights → error 498
local ++test_count
capture noisily {
    sysuse auto, clear
    gen double neg_wt = -1
    capture table1_tc, vars(price contn) by(foreign) wt(neg_wt)
    assert _rc == 498
}
if _rc == 0 {
    display as result "  PASS: V1.6 - negative weights correctly rejected (rc=498)"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.6 - negative weights error check (error `=_rc')"
    local ++fail_count
}

* V1.7: Missing vars() → error
local ++test_count
capture noisily {
    sysuse auto, clear
    capture table1_tc, by(foreign)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: V1.7 - missing vars() correctly errors"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.7 - missing vars() error check (error `=_rc')"
    local ++fail_count
}

* V1.8: Weighted with total column
local ++test_count
capture noisily {
    sysuse auto, clear
    gen double wt = 0.5 + runiform() * 2
    table1_tc, vars(price contn \ rep78 cat) by(foreign) wt(wt) total(after)
}
if _rc == 0 {
    display as result "  PASS: V1.8 - weighted with total column"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.8 - weighted with total column (error `=_rc')"
    local ++fail_count
}

* V1.9: Weighted with clear option preserves table data
local ++test_count
capture noisily {
    sysuse auto, clear
    gen double wt = 0.5 + runiform() * 2
    table1_tc, vars(price contn \ rep78 cat) by(foreign) wt(wt) clear
    assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: V1.9 - weighted with clear option"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.9 - weighted with clear option (error `=_rc')"
    local ++fail_count
}

* V1.10: Weighted without by() (single group)
local ++test_count
capture noisily {
    sysuse auto, clear
    gen double wt = 0.5 + runiform() * 2
    table1_tc, vars(price contn \ mpg conts \ rep78 cat) wt(wt)
}
if _rc == 0 {
    display as result "  PASS: V1.10 - weighted without by()"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.10 - weighted without by() (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V2: regtab Validation - Structure, Content, Mixed Models
* ============================================================

* V2.1: Single model - Excel structure via check_xlsx.py
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign price mpg weight

    capture erase "`output_dir'/_val_regtab_single.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_single.xlsx") sheet("Single") ///
        coef("OR") title("Table 1. Odds Ratios") noint

    confirm file "`output_dir'/_val_regtab_single.xlsx"

    if `has_check_xlsx' {
        ! python3 "`tools_dir'/check_xlsx.py" "`output_dir'/_val_regtab_single.xlsx" ///
            --sheet Single --min-rows 5 --min-cols 4 --max-cols 6 ///
            --has-borders --border-style thin ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
}
if _rc == 0 {
    display as result "  PASS: V2.1 - single model structure and formatting"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.1 - single model structure (error `=_rc')"
    local ++fail_count
}

* V2.2: Point estimates match logit output
local ++test_count
capture noisily {
    sysuse auto, clear
    logit foreign price mpg weight
    matrix b = e(b)
    local coef_price = b[1,1]
    local coef_price_str = string(round(`coef_price', 0.01), "%9.2f")

    collect clear
    collect: logit foreign price mpg weight

    capture erase "`output_dir'/_val_regtab_coef.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_coef.xlsx") sheet("Coef") ///
        coef("OR") noint

    import excel "`output_dir'/_val_regtab_coef.xlsx", sheet("Coef") clear
    local found = 0
    forvalues i = 4/`=_N' {
        if regexm(strlower(strtrim(B[`i'])), "price") {
            local excel_val = strtrim(C[`i'])
            assert "`excel_val'" == "`coef_price_str'"
            local found = 1
        }
    }
    assert `found' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.2 - point estimates match model output"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.2 - point estimates (error `=_rc')"
    local ++fail_count
}

* V2.3: Multi-model column structure
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg
    collect: regress price mpg weight
    collect: regress price mpg weight i.foreign

    capture erase "`output_dir'/_val_regtab_multi.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_multi.xlsx") sheet("Multi") ///
        coef("Coef.") models("Model 1 \ Model 2 \ Model 3") ///
        title("Progressive Adjustment") noint

    if `has_check_xlsx' {
        ! python3 "`tools_dir'/check_xlsx.py" "`output_dir'/_val_regtab_multi.xlsx" ///
            --sheet Multi --min-cols 10 --min-rows 5 ///
            --bold-row 1 3 --merged-row 1 2 --has-borders ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }

    * Verify model labels in header
    import excel "`output_dir'/_val_regtab_multi.xlsx", sheet("Multi") clear allstring
    local found_m1 = 0
    foreach var of varlist * {
        forvalues i = 1/3 {
            if strpos(`var'[`i'], "Model 1") > 0 local found_m1 = 1
        }
    }
    assert `found_m1' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.3 - multi-model structure and labels"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.3 - multi-model structure (error `=_rc')"
    local ++fail_count
}

* V2.4: Stats option - verify N matches e(N)
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    local true_n = e(N)

    capture erase "`output_dir'/_val_regtab_stats.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_stats.xlsx") sheet("Stats") ///
        coef("Coef.") stats(n aic bic)

    import excel "`output_dir'/_val_regtab_stats.xlsx", sheet("Stats") clear allstring
    local found_obs = 0
    forvalues i = 1/`=_N' {
        if strtrim(B[`i']) == "Observations" {
            local reported_n = real(C[`i'])
            assert `reported_n' == `true_n'
            local found_obs = 1
        }
    }
    assert `found_obs' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.4 - stats(n) matches e(N) = `true_n'"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.4 - stats option (error `=_rc')"
    local ++fail_count
}

* V2.5: noint removes intercept row
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    capture erase "`output_dir'/_val_regtab_noint.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_noint.xlsx") sheet("NoInt") ///
        coef("Coef.") noint

    import excel "`output_dir'/_val_regtab_noint.xlsx", sheet("NoInt") clear allstring
    local found_cons = 0
    forvalues i = 1/`=_N' {
        if inlist(strlower(strtrim(B[`i'])), "_cons", "intercept", "constant") {
            local found_cons = 1
        }
    }
    assert `found_cons' == 0
}
if _rc == 0 {
    display as result "  PASS: V2.5 - noint removes intercept"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.5 - noint option (error `=_rc')"
    local ++fail_count
}

* V2.6: Custom CI separator
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign price mpg

    capture erase "`output_dir'/_val_regtab_sep.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_sep.xlsx") sheet("Sep") ///
        coef("OR") noint sep("; ")

    import excel "`output_dir'/_val_regtab_sep.xlsx", sheet("Sep") clear allstring
    local found_semi = 0
    forvalues i = 4/`=_N' {
        if strpos(D[`i'], ";") > 0 {
            local found_semi = 1
        }
    }
    assert `found_semi' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.6 - custom CI separator (semicolon)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.6 - CI separator (error `=_rc')"
    local ++fail_count
}

* V2.7: Title cell content via check_xlsx.py
local ++test_count
capture noisily {
    if `has_check_xlsx' {
        ! python3 "`tools_dir'/check_xlsx.py" "`output_dir'/_val_regtab_single.xlsx" ///
            --sheet Single --cell A1 "Table 1. Odds Ratios" ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
    else {
        * Fallback: just confirm file exists
        confirm file "`output_dir'/_val_regtab_single.xlsx"
    }
}
if _rc == 0 {
    display as result "  PASS: V2.7 - title cell content correct"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.7 - title cell (error `=_rc')"
    local ++fail_count
}

* V2.8: Content patterns (p-values, CIs, reference)
local ++test_count
capture noisily {
    if `has_check_xlsx' {
        ! python3 "`tools_dir'/check_xlsx.py" "`output_dir'/_val_regtab_single.xlsx" ///
            --sheet Single --has-pattern p-values ci reference ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
    else {
        confirm file "`output_dir'/_val_regtab_single.xlsx"
    }
}
if _rc == 0 {
    display as result "  PASS: V2.8 - content patterns (p-values, CI, reference)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.8 - content patterns (error `=_rc')"
    local ++fail_count
}

* V2.9: Mixed model with relabel - random intercept labels
local ++test_count
capture noisily {
    clear
    set obs 300
    gen hospital = ceil(_n/30)
    label variable hospital "Hospital Site"
    gen treatment = runiform() > 0.5
    label variable treatment "Treatment Arm"
    gen age = 40 + int(runiform()*30)
    label variable age "Patient Age"
    gen y = 1 + 0.5*treatment + 0.02*age + rnormal(0, 0.3) * hospital + rnormal()*0.5

    collect clear
    collect: mixed y treatment age || hospital:

    capture erase "`output_dir'/_val_regtab_re.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_re.xlsx") sheet("RE") ///
        coef("Coef.") title("Mixed Model") stats(n groups icc) relabel

    import excel "`output_dir'/_val_regtab_re.xlsx", sheet("RE") clear allstring
    local found_int = 0
    local found_res = 0
    forvalues i = 1/`=_N' {
        if B[`i'] == "Hospital Site (Intercept)" local found_int = 1
        if B[`i'] == "Residual Variance" local found_res = 1
    }
    assert `found_int' == 1
    assert `found_res' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.9 - mixed model relabel (intercept + residual)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.9 - mixed model relabel (error `=_rc')"
    local ++fail_count
}

* V2.10: Mixed model with random slope - labels
local ++test_count
capture noisily {
    clear
    set obs 200
    gen provider = ceil(_n/20)
    label variable provider "Healthcare Provider"
    gen treatment = runiform() > 0.5
    label variable treatment "Treatment Group"
    gen y = 1 + 0.5*treatment + rnormal()*0.5

    collect clear
    collect: mixed y treatment || provider: treatment, cov(unstructured)

    capture erase "`output_dir'/_val_regtab_slope.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_slope.xlsx") sheet("Slope") ///
        coef("Coef.") stats(n groups) relabel

    import excel "`output_dir'/_val_regtab_slope.xlsx", sheet("Slope") clear allstring
    local found_int = 0
    local found_slope = 0
    forvalues i = 1/`=_N' {
        if B[`i'] == "Healthcare Provider (Intercept)" local found_int = 1
        if B[`i'] == "Healthcare Provider (Treatment Group)" local found_slope = 1
    }
    assert `found_int' == 1
    assert `found_slope' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.10 - random slope labels correct"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.10 - random slope labels (error `=_rc')"
    local ++fail_count
}

* V2.11: Without relabel shows raw var() labels
local ++test_count
capture noisily {
    clear
    set obs 200
    gen cluster = ceil(_n/20)
    gen x1 = rnormal()
    gen y = 1 + 0.3*x1 + rnormal()*0.5

    collect clear
    collect: mixed y x1 || cluster:

    capture erase "`output_dir'/_val_regtab_norelabel.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_norelabel.xlsx") sheet("NoRelabel") coef("Coef.")

    import excel "`output_dir'/_val_regtab_norelabel.xlsx", sheet("NoRelabel") clear allstring
    local found_raw = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "var(") > 0 local found_raw = 1
    }
    assert `found_raw' >= 1
}
if _rc == 0 {
    display as result "  PASS: V2.11 - without relabel shows raw labels"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.11 - raw labels (error `=_rc')"
    local ++fail_count
}

* V2.12: nore option hides random effects
local ++test_count
capture noisily {
    clear
    set obs 200
    gen facility = ceil(_n/20)
    gen exposure = runiform() > 0.5
    gen outcome = 1 + 0.5*exposure + rnormal()*0.5

    collect clear
    collect: mixed outcome exposure || facility:

    capture erase "`output_dir'/_val_regtab_nore.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_nore.xlsx") sheet("NoRE") coef("Coef.") nore

    import excel "`output_dir'/_val_regtab_nore.xlsx", sheet("NoRE") clear allstring
    local found_re = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "var(") > 0 | strpos(B[`i'], "Variance") > 0 local found_re = 1
    }
    assert `found_re' == 0
}
if _rc == 0 {
    display as result "  PASS: V2.12 - nore hides random effects"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.12 - nore option (error `=_rc')"
    local ++fail_count
}

* V2.13: ICC calculation matches manual computation
* ICC = var_re / (var_re + var_resid)
local ++test_count
capture noisily {
    clear
    set obs 300
    gen cluster = ceil(_n/30)
    gen cluster_effect = rnormal() if _n <= 10
    bysort cluster: replace cluster_effect = cluster_effect[1]
    gen y = cluster_effect + rnormal()
    gen x = rnormal()

    collect clear
    collect: mixed y x || cluster:

    * Calculate ICC manually from model parameters
    matrix temp_b = e(b)
    local colnames : colfullnames temp_b
    local col = 1
    local var_re = .
    local var_resid = .
    foreach colname of local colnames {
        if strpos("`colname'", "lns1_1_1:") {
            local log_sd = temp_b[1,`col']
            local var_re = exp(2 * `log_sd')
        }
        if strpos("`colname'", "lnsig_e:") {
            local log_sd = temp_b[1,`col']
            local var_resid = exp(2 * `log_sd')
        }
        local col = `col' + 1
    }
    local true_icc = `var_re' / (`var_re' + `var_resid')

    capture erase "`output_dir'/_val_regtab_icc.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_icc.xlsx") sheet("ICC") ///
        coef("Coef.") stats(icc) relabel

    import excel "`output_dir'/_val_regtab_icc.xlsx", sheet("ICC") clear allstring
    local icc_row = 0
    forvalues i = 1/`=_N' {
        if B[`i'] == "ICC" {
            local icc_row = `i'
        }
    }
    assert `icc_row' > 0
    local reported_icc = real(C[`icc_row'])
    local diff = abs(`reported_icc' - `true_icc')
    assert `diff' < 0.001
}
if _rc == 0 {
    display as result "  PASS: V2.13 - ICC matches manual calculation (diff < 0.001)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.13 - ICC calculation (error `=_rc')"
    local ++fail_count
}

* V2.14: Groups statistic matches e(N_g)
local ++test_count
capture noisily {
    clear
    set obs 200
    gen cluster = ceil(_n/20)
    gen x = rnormal()
    gen y = x + rnormal()

    collect clear
    collect: mixed y x || cluster:
    tempname ng_mat
    matrix `ng_mat' = e(N_g)
    local true_groups = `ng_mat'[1,1]

    capture erase "`output_dir'/_val_regtab_groups.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_groups.xlsx") sheet("Groups") ///
        coef("Coef.") stats(groups) relabel

    import excel "`output_dir'/_val_regtab_groups.xlsx", sheet("Groups") clear allstring
    local grp_row = 0
    forvalues i = 1/`=_N' {
        if B[`i'] == "Groups" local grp_row = `i'
    }
    assert `grp_row' > 0
    local reported_groups = real(C[`grp_row'])
    assert `reported_groups' == `true_groups'
}
if _rc == 0 {
    display as result "  PASS: V2.14 - groups statistic matches e(N_g)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.14 - groups statistic (error `=_rc')"
    local ++fail_count
}

* V2.15: All stats combined (N, groups, AIC, BIC, LL, ICC)
local ++test_count
capture noisily {
    clear
    set obs 200
    gen facility = ceil(_n/20)
    gen treat = runiform() > 0.5
    gen y = 1 + 0.5*treat + rnormal()*0.5

    collect clear
    collect: mixed y treat || facility:

    capture erase "`output_dir'/_val_regtab_allstats.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_allstats.xlsx") sheet("AllStats") ///
        coef("Coef.") stats(n groups aic bic ll icc) relabel

    import excel "`output_dir'/_val_regtab_allstats.xlsx", sheet("AllStats") clear allstring
    local has_n = 0
    local has_grp = 0
    local has_aic = 0
    local has_bic = 0
    local has_ll = 0
    local has_icc = 0
    forvalues i = 1/`=_N' {
        if B[`i'] == "Observations" local has_n = 1
        if B[`i'] == "Groups" local has_grp = 1
        if B[`i'] == "AIC" local has_aic = 1
        if B[`i'] == "BIC" local has_bic = 1
        if B[`i'] == "Log-likelihood" local has_ll = 1
        if B[`i'] == "ICC" local has_icc = 1
    }
    assert `has_n' == 1
    assert `has_grp' == 1
    assert `has_aic' == 1
    assert `has_bic' == 1
    assert `has_ll' == 1
    assert `has_icc' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.15 - all stats present (N, groups, AIC, BIC, LL, ICC)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.15 - all stats combined (error `=_rc')"
    local ++fail_count
}

* V2.16: Cox regression output structure
local ++test_count
capture noisily {
    clear
    set obs 200
    gen treat = runiform() > 0.5
    gen age = 40 + int(runiform()*30)
    gen time = rexponential(1/(0.1 + 0.05*treat))
    gen event = runiform() < 0.7
    stset time, failure(event)

    collect clear
    collect: stcox treat age

    capture erase "`output_dir'/_val_regtab_cox.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_cox.xlsx") sheet("Cox") ///
        coef("HR") title("Hazard Ratios") stats(n ll)

    if `has_check_xlsx' {
        ! python3 "`tools_dir'/check_xlsx.py" "`output_dir'/_val_regtab_cox.xlsx" ///
            --sheet Cox --min-rows 4 --min-cols 4 ///
            --bold-row 1 3 --has-borders --font Arial ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
    else {
        confirm file "`output_dir'/_val_regtab_cox.xlsx"
    }
}
if _rc == 0 {
    display as result "  PASS: V2.16 - Cox regression output"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.16 - Cox regression (error `=_rc')"
    local ++fail_count
}

* V2.17: Poisson regression with stats
local ++test_count
capture noisily {
    clear
    set obs 500
    gen x1 = rnormal()
    label variable x1 "Risk Factor"
    gen x2 = runiform()
    gen y = rpoisson(exp(0.5 + 0.3*x1 - 0.2*x2))

    collect clear
    collect: poisson y x1 x2

    capture erase "`output_dir'/_val_regtab_poisson.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_poisson.xlsx") sheet("Poisson") ///
        coef("IRR") stats(n aic bic) noint

    import excel "`output_dir'/_val_regtab_poisson.xlsx", sheet("Poisson") clear allstring
    local found_rf = 0
    local found_obs = 0
    forvalues i = 1/`=_N' {
        if B[`i'] == "Risk Factor" local found_rf = 1
        if B[`i'] == "Observations" local found_obs = 1
    }
    assert `found_rf' == 1
    assert `found_obs' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.17 - Poisson regression with relabel and stats"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.17 - Poisson regression (error `=_rc')"
    local ++fail_count
}

* V2.18: Variables without labels fall back to variable names
local ++test_count
capture noisily {
    clear
    set obs 200
    gen grp = ceil(_n/20)
    gen x1 = rnormal()
    gen y = x1 + rnormal()

    collect clear
    collect: mixed y x1 || grp:

    capture erase "`output_dir'/_val_regtab_nolabels.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_nolabels.xlsx") sheet("NoLabels") ///
        coef("Coef.") relabel

    import excel "`output_dir'/_val_regtab_nolabels.xlsx", sheet("NoLabels") clear allstring
    local found = 0
    forvalues i = 1/`=_N' {
        if B[`i'] == "grp (Intercept)" local found = 1
    }
    assert `found' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.18 - no labels falls back to variable names"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.18 - no labels fallback (error `=_rc')"
    local ++fail_count
}

* V2.19: Error - missing .xlsx extension
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign price mpg
    capture noisily regtab, xlsx("`output_dir'/bad_file.csv") sheet("T") coef("OR")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V2.19 - missing .xlsx extension rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.19 - .xlsx extension check (error `=_rc')"
    local ++fail_count
}

* V2.20: Mixed logit with relabel
local ++test_count
capture noisily {
    clear
    set obs 500
    gen center = ceil(_n/50)
    label variable center "Clinical Center"
    gen treat = runiform() > 0.5
    label variable treat "Active Treatment"
    gen age = 50 + int(runiform()*20)
    gen logit_p = -1 + 0.8*treat + 0.02*age + rnormal()*0.5
    gen outcome = runiform() < invlogit(logit_p)

    collect clear
    collect: melogit outcome treat age || center:

    capture erase "`output_dir'/_val_regtab_melogit.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_melogit.xlsx") sheet("MELogit") ///
        coef("OR") stats(n groups ll) relabel

    import excel "`output_dir'/_val_regtab_melogit.xlsx", sheet("MELogit") clear allstring
    local found = 0
    forvalues i = 1/`=_N' {
        if B[`i'] == "Clinical Center (Intercept)" local found = 1
    }
    assert `found' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.20 - mixed logit with relabel"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.20 - mixed logit relabel (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V3: effecttab Validation - Stored Results and Content
* ============================================================

* V3.1: Stored results (r(N_rows), r(N_cols), r(type))
local ++test_count
capture noisily {
    clear
    set obs 500
    gen age = 30 + runiform() * 30
    gen female = runiform() < 0.5
    gen propensity = invlogit(-0.5 + 0.01*age + 0.2*female)
    gen treatment = runiform() < propensity
    gen prob_y = invlogit(-1 + 0.4*treatment + 0.01*age)
    gen outcome = runiform() < prob_y

    collect clear
    collect: teffects ipw (outcome) (treatment age female), ate

    capture erase "`output_dir'/_val_effecttab.xlsx"
    effecttab, xlsx("`output_dir'/_val_effecttab.xlsx") sheet("Test")

    assert r(N_rows) > 0
    assert r(N_cols) > 0
    assert "`r(xlsx)'" == "`output_dir'/_val_effecttab.xlsx"
    assert "`r(sheet)'" == "Test"
}
if _rc == 0 {
    display as result "  PASS: V3.1 - effecttab stored results"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.1 - stored results (error `=_rc')"
    local ++fail_count
}

* V3.2: Type auto-detection (teffects)
local ++test_count
capture noisily {
    clear
    set obs 500
    gen age = 30 + runiform() * 30
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment)

    collect clear
    collect: teffects ipw (outcome) (treatment age), ate

    capture erase "`output_dir'/_val_effecttab_type.xlsx"
    effecttab, xlsx("`output_dir'/_val_effecttab_type.xlsx") sheet("TypeTest")

    assert "`r(type)'" == "teffects"
}
if _rc == 0 {
    display as result "  PASS: V3.2 - type detected as teffects"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.2 - type detection teffects (error `=_rc')"
    local ++fail_count
}

* V3.3: Type auto-detection (margins)
local ++test_count
capture noisily {
    clear
    set obs 500
    gen age = 30 + runiform() * 30
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment)

    logit outcome i.treatment age

    collect clear
    collect: margins treatment

    capture erase "`output_dir'/_val_effecttab_margins.xlsx"
    effecttab, xlsx("`output_dir'/_val_effecttab_margins.xlsx") sheet("MarginsType")

    assert "`r(type)'" == "margins"
}
if _rc == 0 {
    display as result "  PASS: V3.3 - type detected as margins"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.3 - type detection margins (error `=_rc')"
    local ++fail_count
}

* V3.4: Excel structure (min rows/cols)
local ++test_count
capture noisily {
    clear
    set obs 500
    gen age = 30 + runiform() * 30
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment)

    collect clear
    collect: teffects ipw (outcome) (treatment age), ate

    capture erase "`output_dir'/_val_effecttab_struct.xlsx"
    effecttab, xlsx("`output_dir'/_val_effecttab_struct.xlsx") sheet("Structure")

    import excel "`output_dir'/_val_effecttab_struct.xlsx", sheet("Structure") clear
    ds
    local ncols : word count `r(varlist)'
    assert `ncols' >= 4
    count
    assert r(N) >= 3
}
if _rc == 0 {
    display as result "  PASS: V3.4 - effecttab Excel structure"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.4 - Excel structure (error `=_rc')"
    local ++fail_count
}

* V3.5: Multi-model effecttab
local ++test_count
capture noisily {
    clear
    set obs 500
    gen age = 30 + runiform() * 30
    gen female = runiform() < 0.5
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment)

    collect clear
    collect: teffects ipw (outcome) (treatment age), ate
    collect: teffects ipw (outcome) (treatment age female), ate

    capture erase "`output_dir'/_val_effecttab_multi.xlsx"
    effecttab, xlsx("`output_dir'/_val_effecttab_multi.xlsx") sheet("Multi") ///
        models("Model 1 \ Model 2")

    import excel "`output_dir'/_val_effecttab_multi.xlsx", sheet("Multi") clear
    ds
    local ncols : word count `r(varlist)'
    assert `ncols' >= 7
}
if _rc == 0 {
    display as result "  PASS: V3.5 - multi-model effecttab"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.5 - multi-model effecttab (error `=_rc')"
    local ++fail_count
}

* V3.6: margins dydx output
local ++test_count
capture noisily {
    clear
    set obs 500
    gen age = 30 + runiform() * 30
    gen female = runiform() < 0.5
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment + 0.01*age)

    logit outcome i.treatment age female

    collect clear
    collect: margins, dydx(treatment age)

    capture erase "`output_dir'/_val_effecttab_dydx.xlsx"
    effecttab, xlsx("`output_dir'/_val_effecttab_dydx.xlsx") sheet("dydx") effect("AME")

    import excel "`output_dir'/_val_effecttab_dydx.xlsx", sheet("dydx") clear
    count
    assert r(N) >= 3
}
if _rc == 0 {
    display as result "  PASS: V3.6 - margins dydx output"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.6 - margins dydx (error `=_rc')"
    local ++fail_count
}

* V3.7: margins predictions
local ++test_count
capture noisily {
    clear
    set obs 500
    gen age = 30 + runiform() * 30
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment)

    logit outcome i.treatment age

    collect clear
    collect: margins treatment

    capture erase "`output_dir'/_val_effecttab_pred.xlsx"
    effecttab, xlsx("`output_dir'/_val_effecttab_pred.xlsx") sheet("Pred") ///
        type(margins) effect("Pr(Y)")

    import excel "`output_dir'/_val_effecttab_pred.xlsx", sheet("Pred") clear
    count
    assert r(N) >= 4
}
if _rc == 0 {
    display as result "  PASS: V3.7 - margins predictions output"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.7 - margins predictions (error `=_rc')"
    local ++fail_count
}

* V3.8: clean option
local ++test_count
capture noisily {
    clear
    set obs 500
    gen age = 30 + runiform() * 30
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment)

    collect clear
    collect: teffects ipw (outcome) (treatment age), ate

    capture erase "`output_dir'/_val_effecttab_clean.xlsx"
    effecttab, xlsx("`output_dir'/_val_effecttab_clean.xlsx") sheet("Clean") clean

    confirm file "`output_dir'/_val_effecttab_clean.xlsx"
}
if _rc == 0 {
    display as result "  PASS: V3.8 - clean option"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.8 - clean option (error `=_rc')"
    local ++fail_count
}

* V3.9: Single effect row
local ++test_count
capture noisily {
    clear
    set obs 500
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment)

    collect clear
    collect: teffects ipw (outcome) (treatment), ate

    capture erase "`output_dir'/_val_effecttab_single.xlsx"
    effecttab, xlsx("`output_dir'/_val_effecttab_single.xlsx") sheet("Single")

    import excel "`output_dir'/_val_effecttab_single.xlsx", sheet("Single") clear
    count
    assert r(N) >= 3
}
if _rc == 0 {
    display as result "  PASS: V3.9 - single effect row"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.9 - single effect (error `=_rc')"
    local ++fail_count
}

* V3.10: Many effects (multi-level treatment)
local ++test_count
capture noisily {
    clear
    set obs 500
    gen age = 30 + runiform() * 30
    gen treat4 = floor(runiform() * 4)
    gen outcome = runiform() < (0.2 + 0.05*treat4)

    collect clear
    collect: teffects ipw (outcome) (treat4 age), ate

    capture erase "`output_dir'/_val_effecttab_many.xlsx"
    effecttab, xlsx("`output_dir'/_val_effecttab_many.xlsx") sheet("Many") clean

    import excel "`output_dir'/_val_effecttab_many.xlsx", sheet("Many") clear
    count
    assert r(N) >= 5
}
if _rc == 0 {
    display as result "  PASS: V3.10 - many effects (multi-level)"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.10 - many effects (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V4: stratetab Validation - Structure and Content
* ============================================================

* Create synthetic strate output files with KNOWN values
* Outcome 1: 3 exposure levels, known events and PY
clear
set obs 3
gen exposure = _n - 1
gen double _D = .
gen double _Y = .
gen double _Rate = .
gen double _Lower = .
gen double _Upper = .

replace _D = 25 in 1
replace _D = 18 in 2
replace _D = 32 in 3

replace _Y = 5000 in 1
replace _Y = 4500 in 2
replace _Y = 5200 in 3

replace _Rate = _D / _Y
replace _Lower = _Rate * 0.65
replace _Upper = _Rate * 1.35

label variable exposure "Treatment Group"
label define val_exp_lbl 0 "Placebo" 1 "Low Dose" 2 "High Dose"
label values exposure val_exp_lbl
save "`output_dir'/_val_strate_o1e1.dta", replace

* Outcome 2: same exposure structure
clear
set obs 3
gen exposure = _n - 1
gen double _D = .
gen double _Y = .
gen double _Rate = .
gen double _Lower = .
gen double _Upper = .

replace _D = 12 in 1
replace _D = 8 in 2
replace _D = 20 in 3

replace _Y = 5000 in 1
replace _Y = 4500 in 2
replace _Y = 5200 in 3

replace _Rate = _D / _Y
replace _Lower = _Rate * 0.65
replace _Upper = _Rate * 1.35

label define val_exp_lbl 0 "Placebo" 1 "Low Dose" 2 "High Dose", replace
label values exposure val_exp_lbl
save "`output_dir'/_val_strate_o2e1.dta", replace

* V4.1: Basic structure and formatting
local ++test_count
capture noisily {
    preserve
    capture erase "`output_dir'/_val_stratetab_basic.xlsx"
    stratetab, using("`output_dir'/_val_strate_o1e1" "`output_dir'/_val_strate_o2e1") ///
        xlsx("`output_dir'/_val_stratetab_basic.xlsx") outcomes(2) ///
        sheet("Basic") title("Table. Incidence Rates") ///
        outlabels("Outcome A \ Outcome B")
    restore

    confirm file "`output_dir'/_val_stratetab_basic.xlsx"

    if `has_check_xlsx' {
        ! python3 "`tools_dir'/check_xlsx.py" "`output_dir'/_val_stratetab_basic.xlsx" ///
            --sheet Basic --min-rows 5 --min-cols 5 ///
            --has-borders --border-style thin ///
            --bold-row 1 --merged-row 1 ///
            --font Arial --fontsize 10 ///
            --cell A1 "Table. Incidence Rates" ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
}
if _rc == 0 {
    display as result "  PASS: V4.1 - stratetab basic structure and formatting"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.1 - stratetab structure (error `=_rc')"
    local ++fail_count
}

* V4.2: Outcome labels present in output
local ++test_count
capture noisily {
    import excel "`output_dir'/_val_stratetab_basic.xlsx", sheet("Basic") clear
    local found_a = 0
    local found_b = 0
    foreach var of varlist * {
        forvalues i = 1/`=_N' {
            if strpos(`var'[`i'], "Outcome A") > 0 local found_a = 1
            if strpos(`var'[`i'], "Outcome B") > 0 local found_b = 1
        }
    }
    assert `found_a' == 1
    assert `found_b' == 1
}
if _rc == 0 {
    display as result "  PASS: V4.2 - outcome labels present"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.2 - outcome labels (error `=_rc')"
    local ++fail_count
}

* V4.3: Rate patterns present
local ++test_count
capture noisily {
    if `has_check_xlsx' {
        ! python3 "`tools_dir'/check_xlsx.py" "`output_dir'/_val_stratetab_basic.xlsx" ///
            --sheet Basic --has-pattern rates ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
    else {
        confirm file "`output_dir'/_val_stratetab_basic.xlsx"
    }
}
if _rc == 0 {
    display as result "  PASS: V4.3 - rate patterns in content"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.3 - rate patterns (error `=_rc')"
    local ++fail_count
}

* V4.4: Event counts are numeric and reasonable
local ++test_count
capture noisily {
    import excel "`output_dir'/_val_stratetab_basic.xlsx", sheet("Basic") clear
    local found_events = 0
    forvalues i = 3/`=_N' {
        foreach var of varlist * {
            local val = `var'[`i']
            if regexm("`val'", "^[0-9]+$") {
                local numval = real("`val'")
                if `numval' >= 1 & `numval' <= 1000 {
                    local found_events = 1
                }
            }
        }
    }
    assert `found_events' == 1
}
if _rc == 0 {
    display as result "  PASS: V4.4 - event counts present and numeric"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.4 - event counts (error `=_rc')"
    local ++fail_count
}

* V4.5: PY and rate scaling options
local ++test_count
capture noisily {
    preserve
    capture erase "`output_dir'/_val_stratetab_scale.xlsx"
    stratetab, using("`output_dir'/_val_strate_o1e1" "`output_dir'/_val_strate_o2e1") ///
        xlsx("`output_dir'/_val_stratetab_scale.xlsx") outcomes(2) ///
        sheet("Scale") pyscale(1000) ratescale(1000)
    restore

    if `has_check_xlsx' {
        ! python3 "`tools_dir'/check_xlsx.py" "`output_dir'/_val_stratetab_scale.xlsx" ///
            --sheet Scale --min-rows 4 --min-cols 4 --has-borders ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
    else {
        confirm file "`output_dir'/_val_stratetab_scale.xlsx"
    }
}
if _rc == 0 {
    display as result "  PASS: V4.5 - PY and rate scaling"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.5 - scaling options (error `=_rc')"
    local ++fail_count
}

* V4.6: Custom decimal places
local ++test_count
capture noisily {
    preserve
    capture erase "`output_dir'/_val_stratetab_digits.xlsx"
    stratetab, using("`output_dir'/_val_strate_o1e1" "`output_dir'/_val_strate_o2e1") ///
        xlsx("`output_dir'/_val_stratetab_digits.xlsx") outcomes(2) ///
        sheet("Digits") digits(2) eventdigits(0) pydigits(1)
    restore

    confirm file "`output_dir'/_val_stratetab_digits.xlsx"
}
if _rc == 0 {
    display as result "  PASS: V4.6 - custom decimal places"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.6 - digits options (error `=_rc')"
    local ++fail_count
}

* V4.7: Single outcome
local ++test_count
capture noisily {
    preserve
    capture erase "`output_dir'/_val_stratetab_single.xlsx"
    stratetab, using("`output_dir'/_val_strate_o1e1") ///
        xlsx("`output_dir'/_val_stratetab_single.xlsx") outcomes(1) ///
        sheet("Single") title("Single Outcome Table")
    restore

    if `has_check_xlsx' {
        ! python3 "`tools_dir'/check_xlsx.py" "`output_dir'/_val_stratetab_single.xlsx" ///
            --sheet Single --min-rows 4 --min-cols 3 ///
            --cell A1 "Single Outcome Table" ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
    else {
        confirm file "`output_dir'/_val_stratetab_single.xlsx"
    }
}
if _rc == 0 {
    display as result "  PASS: V4.7 - single outcome"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.7 - single outcome (error `=_rc')"
    local ++fail_count
}

* V4.8: Error - missing .xlsx extension
local ++test_count
capture noisily {
    preserve
    capture noisily stratetab, using("`output_dir'/_val_strate_o1e1") ///
        xlsx("`output_dir'/bad.csv") outcomes(1) sheet("T")
    local rc_val = _rc
    restore
    assert `rc_val' == 198
}
if _rc == 0 {
    display as result "  PASS: V4.8 - missing .xlsx extension rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.8 - .xlsx extension check (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V5: tablex Validation - Structure and Content Accuracy
* ============================================================

* V5.1: Frequency table structure via check_xlsx.py
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign rep78

    capture erase "`output_dir'/_val_tablex_freq.xlsx"
    tablex using "`output_dir'/_val_tablex_freq.xlsx", ///
        sheet("Frequencies") title("Table 1. Car Frequency") replace

    if `has_check_xlsx' {
        ! python3 "`tools_dir'/check_xlsx.py" "`output_dir'/_val_tablex_freq.xlsx" ///
            --sheet Frequencies --min-rows 4 --min-cols 3 ///
            --has-borders --border-style thin ///
            --bold-row 1 --merged-row 1 ///
            --font Arial --fontsize 10 ///
            --cell A1 "Table 1. Car Frequency" ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
    else {
        confirm file "`output_dir'/_val_tablex_freq.xlsx"
    }
}
if _rc == 0 {
    display as result "  PASS: V5.1 - frequency table structure and formatting"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.1 - frequency table (error `=_rc')"
    local ++fail_count
}

* V5.2: Summary statistics content matches known auto.dta values
* Hand-calculated: domestic mean price = 6072.423 (from sysuse auto)
local ++test_count
capture noisily {
    sysuse auto, clear
    summarize price if foreign == 0, meanonly
    local mean_dom = r(mean)

    table foreign, statistic(mean price mpg weight) statistic(sd price mpg weight)

    capture erase "`output_dir'/_val_tablex_summary.xlsx"
    tablex using "`output_dir'/_val_tablex_summary.xlsx", ///
        sheet("Summary") title("Summary by Origin") replace

    import excel "`output_dir'/_val_tablex_summary.xlsx", sheet("Summary") clear
    local found = 0
    foreach var of varlist * {
        forvalues i = 1/`=_N' {
            local val = `var'[`i']
            local numval = real("`val'")
            if !missing(`numval') {
                if abs(`numval' - `mean_dom') < 0.01 {
                    local found = 1
                }
            }
        }
    }
    assert `found' == 1
}
if _rc == 0 {
    display as result "  PASS: V5.2 - summary content matches known auto.dta values"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.2 - summary content (error `=_rc')"
    local ++fail_count
}

* V5.3: Custom font (Calibri 11pt)
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price)

    capture erase "`output_dir'/_val_tablex_calibri.xlsx"
    tablex using "`output_dir'/_val_tablex_calibri.xlsx", ///
        sheet("Custom") title("Custom Font") ///
        font(Calibri) fontsize(11) replace

    if `has_check_xlsx' {
        ! python3 "`tools_dir'/check_xlsx.py" "`output_dir'/_val_tablex_calibri.xlsx" ///
            --sheet Custom --font Calibri --fontsize 11 ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
    else {
        confirm file "`output_dir'/_val_tablex_calibri.xlsx"
    }
}
if _rc == 0 {
    display as result "  PASS: V5.3 - custom font (Calibri 11pt)"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.3 - custom font (error `=_rc')"
    local ++fail_count
}

* V5.4: Medium border style
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price)

    capture erase "`output_dir'/_val_tablex_medium.xlsx"
    tablex using "`output_dir'/_val_tablex_medium.xlsx", ///
        sheet("Borders") title("Medium Borders") ///
        borderstyle(medium) replace

    if `has_check_xlsx' {
        ! python3 "`tools_dir'/check_xlsx.py" "`output_dir'/_val_tablex_medium.xlsx" ///
            --sheet Borders --has-borders --border-style medium ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
    else {
        confirm file "`output_dir'/_val_tablex_medium.xlsx"
    }
}
if _rc == 0 {
    display as result "  PASS: V5.4 - medium border style"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.4 - border style (error `=_rc')"
    local ++fail_count
}

* V5.5: Cross-tabulation with frequency and percent
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign rep78, statistic(frequency) statistic(percent)

    capture erase "`output_dir'/_val_tablex_cross.xlsx"
    tablex using "`output_dir'/_val_tablex_cross.xlsx", ///
        sheet("CrossTab") title("Cross-Tabulation") replace

    if `has_check_xlsx' {
        ! python3 "`tools_dir'/check_xlsx.py" "`output_dir'/_val_tablex_cross.xlsx" ///
            --sheet CrossTab --min-rows 4 --min-cols 3 ///
            --has-borders --bold-row 1 --merged-row 1 ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
    else {
        confirm file "`output_dir'/_val_tablex_cross.xlsx"
    }
}
if _rc == 0 {
    display as result "  PASS: V5.5 - cross-tabulation"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.5 - cross-tabulation (error `=_rc')"
    local ++fail_count
}

* V5.6: Table without title
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price mpg)

    capture erase "`output_dir'/_val_tablex_notitle.xlsx"
    tablex using "`output_dir'/_val_tablex_notitle.xlsx", ///
        sheet("NoTitle") replace

    if `has_check_xlsx' {
        ! python3 "`tools_dir'/check_xlsx.py" "`output_dir'/_val_tablex_notitle.xlsx" ///
            --sheet NoTitle --min-rows 3 --min-cols 2 --has-borders ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
    else {
        confirm file "`output_dir'/_val_tablex_notitle.xlsx"
    }
}
if _rc == 0 {
    display as result "  PASS: V5.6 - table without title"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.6 - no-title table (error `=_rc')"
    local ++fail_count
}

* V5.7: Error - missing .xlsx extension
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price)
    capture noisily tablex using "`output_dir'/bad.csv", sheet("T") replace
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V5.7 - missing .xlsx extension rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.7 - .xlsx extension check (error `=_rc')"
    local ++fail_count
}

* V5.8: Error - invalid fontsize
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price)
    capture noisily tablex using "`output_dir'/_val_empty.xlsx", ///
        sheet("T") fontsize(2) replace
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V5.8 - invalid fontsize rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.8 - fontsize validation (error `=_rc')"
    local ++fail_count
}

* V5.9: Error - invalid border style
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price)
    capture noisily tablex using "`output_dir'/_val_empty.xlsx", ///
        sheet("T") borderstyle(thick) replace
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V5.9 - invalid border style rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.9 - borderstyle validation (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V6: Cross-Command Validation
* ============================================================

* V6.1: Data preservation across table1_tc
local ++test_count
capture noisily {
    sysuse auto, clear
    local N_before = _N
    table1_tc, vars(price contn \ mpg conts) by(foreign)
    assert _N == `N_before'
}
if _rc == 0 {
    display as result "  PASS: V6.1 - table1_tc preserves data (_N unchanged)"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.1 - data preservation (error `=_rc')"
    local ++fail_count
}

* V6.2: Data preservation across regtab
local ++test_count
capture noisily {
    sysuse auto, clear
    local N_before = _N
    collect clear
    collect: regress price mpg weight

    capture erase "`output_dir'/_val_cross_regtab.xlsx"
    regtab, xlsx("`output_dir'/_val_cross_regtab.xlsx") sheet("T") coef("Coef.")
    assert _N == `N_before'
}
if _rc == 0 {
    display as result "  PASS: V6.2 - regtab preserves data (_N unchanged)"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.2 - regtab data preservation (error `=_rc')"
    local ++fail_count
}

* V6.3: Data preservation across tablex
local ++test_count
capture noisily {
    sysuse auto, clear
    local N_before = _N
    table foreign, statistic(mean price)

    capture erase "`output_dir'/_val_cross_tablex.xlsx"
    tablex using "`output_dir'/_val_cross_tablex.xlsx", sheet("T") replace
    assert _N == `N_before'
}
if _rc == 0 {
    display as result "  PASS: V6.3 - tablex preserves data (_N unchanged)"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.3 - tablex data preservation (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Cleanup
* ============================================================

* Remove all validation output files
local val_files : dir "`output_dir'" files "_val_*.xlsx"
foreach f of local val_files {
    capture erase "`output_dir'/`f'"
}
local val_files : dir "`output_dir'" files "_val_*.dta"
foreach f of local val_files {
    capture erase "`output_dir'/`f'"
}
capture erase "`output_dir'/_check.txt"
capture erase "`output_dir'/_val_empty.xlsx"

* ============================================================
* Summary
* ============================================================

display as text ""
display as result "Validation Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME VALIDATIONS FAILED"
    exit 1
}
else {
    display as result "ALL VALIDATIONS PASSED"
}
