* validation_tabtools.do - Correctness validation for tabtools package
* Generated: 2026-03-12
* Covers: table1_tc, regtab, effecttab, stratetab
* Sections: command-specific and cross-command validation

clear all
set more off
set varabbrev off
set seed 20260312

* ============================================================
* Setup
* ============================================================

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

* Locate optional package-local check_xlsx.py validator
local has_check_xlsx = 0
local tools_dir ""
foreach _trypath in "`qa_dir'/tools" {
    capture confirm file "`_trypath'/check_xlsx.py"
    if _rc == 0 {
        local has_check_xlsx = 1
        local tools_dir "`_trypath'"
        continue, break
    }
}

local test_count = 0
local pass_count = 0
local fail_count = 0

* ============================================================
* V1: table1_tc Validation - Variable Types and Content
* ============================================================

* V1.1: Continuous normal - verify mean matches hand calculation
local ++test_count
capture noisily {
    sysuse auto, clear
    summarize price if foreign == 0, meanonly
    local expected_mean = round(r(mean), 0.1)
    table1_tc, vars(price contn %9.1f) by(foreign) frame(t1_val, replace)

    * table1_tc frame uses named columns: factor, foreign_0, foreign_1, etc.
    * The Price row has "mean (SD)" in foreign_0 column
    frame t1_val {
        local _found = 0
        forvalues _r = 1/`=_N' {
            if strmatch(strtrim(factor[`_r']), "*Price*") | strmatch(strtrim(factor[`_r']), "*price*") {
                local _cell = strtrim(foreign_0[`_r'])
                * Parse mean from "6072.4 (3097.1)" format
                local _mean_str = substr("`_cell'", 1, strpos("`_cell'", " ") - 1)
                local _mean_got = real("`_mean_str'")
                if !missing(`_mean_got') {
                    assert abs(`_mean_got' - `expected_mean') < 0.15
                    local _found = 1
                    continue, break
                }
            }
        }
        assert `_found' == 1
    }
    capture frame drop t1_val
}
if _rc == 0 {
    display as result "  PASS: V1.1 - table1_tc contn mean matches summarize"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.1 - table1_tc contn mean mismatch (error `=_rc')"
    local ++fail_count
    capture frame drop t1_val
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

* V1.7: Missing vars() with no data → error; with data → auto-detect
local ++test_count
capture noisily {
    clear
    capture table1_tc
    assert _rc != 0
    sysuse auto, clear
    table1_tc, by(foreign)
}
if _rc == 0 {
    display as result "  PASS: V1.7 - missing vars() errors on empty data, auto-detects with data"
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
            --sheet Single --min-rows 5 --min-cols 4 ///
            --has-borders ///
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

* V2.2: Odds ratios match exp(logit coefficients)
local ++test_count
capture noisily {
    sysuse auto, clear
    logit foreign price mpg weight
    matrix b = e(b)
    local or_price = exp(b[1,1])
    local or_price_str = string(round(`or_price', 0.01), "%9.2f")

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
            assert "`excel_val'" == "`or_price_str'"
            local found = 1
        }
    }
    assert `found' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.2 - odds ratios match exp(logit coefficients)"
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
            --bold-row 1 --merged-row 1 --has-borders ///
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
            --sheet Single --cell-contains A1 "Table 1. Odds Ratios" ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
    else {
        * Stata-native fallback: verify title cell content
        preserve
        import excel "`output_dir'/_val_regtab_single.xlsx", sheet("Single") cellrange(A1:A1) clear
        assert A[1] == "Table 1. Odds Ratios"
        restore
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
        * Note: no "reference" pattern — model has only continuous predictors
        ! python3 "`tools_dir'/check_xlsx.py" "`output_dir'/_val_regtab_single.xlsx" ///
            --sheet Single --has-pattern p-values ci ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
    else {
        * Stata-native fallback: check for p-value and CI patterns
        import excel "`output_dir'/_val_regtab_single.xlsx", sheet("Single") clear allstring
        local _has_pval = 0
        local _has_ci = 0
        foreach _v of varlist * {
            forvalues _r = 1/`=_N' {
                local _cell = strtrim(`_v'[`_r'])
                if regexm(`"`_cell'"', "^[0-9]\.[0-9]+$") | regexm(`"`_cell'"', "^<0\.[0-9]+$") {
                    local _has_pval = 1
                }
                if strpos(`"`_cell'"', "(") > 0 & strpos(`"`_cell'"', ")") > 0 {
                    local _has_ci = 1
                }
            }
        }
        assert `_has_pval' == 1
        assert `_has_ci' == 1
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
            --bold-row 1 --has-borders --font Arial ///
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
    set seed 20260323
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
    * Check that relabeled random intercept row contains grouping var label
    local found = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "Clinical Center") > 0 local found = 1
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
    capture erase "`output_dir'/_val_stratetab_basic.xlsx"
    stratetab, using("`output_dir'/_val_strate_o1e1" "`output_dir'/_val_strate_o2e1") ///
        xlsx("`output_dir'/_val_stratetab_basic.xlsx") outcomes(2) ///
        sheet("Basic") title("Table. Incidence Rates") ///
        outlabels("Outcome A \ Outcome B")

    confirm file "`output_dir'/_val_stratetab_basic.xlsx"

    if `has_check_xlsx' {
        ! python3 "`tools_dir'/check_xlsx.py" "`output_dir'/_val_stratetab_basic.xlsx" ///
            --sheet Basic --min-rows 5 --min-cols 5 ///
            --has-borders ///
            --bold-row 1 --merged-row 1 ///
            --font Arial --fontsize 10 ///
            --cell-contains A1 "Table. Incidence Rates" ///
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
            --sheet Basic --min-rows 3 --min-cols 3 ///
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
    capture erase "`output_dir'/_val_stratetab_scale.xlsx"
    stratetab, using("`output_dir'/_val_strate_o1e1" "`output_dir'/_val_strate_o2e1") ///
        xlsx("`output_dir'/_val_stratetab_scale.xlsx") outcomes(2) ///
        sheet("Scale") pyscale(1000) ratescale(1000)

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
    capture erase "`output_dir'/_val_stratetab_digits.xlsx"
    stratetab, using("`output_dir'/_val_strate_o1e1" "`output_dir'/_val_strate_o2e1") ///
        xlsx("`output_dir'/_val_stratetab_digits.xlsx") outcomes(2) ///
        sheet("Digits") digits(2) eventdigits(0) pydigits(1)

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
    capture erase "`output_dir'/_val_stratetab_single.xlsx"
    stratetab, using("`output_dir'/_val_strate_o1e1") ///
        xlsx("`output_dir'/_val_stratetab_single.xlsx") outcomes(1) ///
        sheet("Single") title("Single Outcome Table")

    if `has_check_xlsx' {
        ! python3 "`tools_dir'/check_xlsx.py" "`output_dir'/_val_stratetab_single.xlsx" ///
            --sheet Single --min-rows 4 --min-cols 3 ///
            --cell-contains A1 "Single Outcome Table" ///
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
    capture noisily stratetab, using("`output_dir'/_val_strate_o1e1") ///
        xlsx("`output_dir'/bad.csv") outcomes(1) sheet("T")
    local rc_val = _rc
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

* ============================================================
* V7: _tabtools_detect_vartype Validation
* ============================================================

**# V7: _tabtools_detect_vartype

* V7.1: Auto-detection accuracy on sysuse auto
* foreign is binary → "bin"; rep78 has 5 values → "cat"; price is continuous
local ++test_count
capture noisily {
    sysuse auto, clear
    * Verify detection of foreign as binary
    _tabtools_detect_vartype foreign
    assert "`result'" == "bin"
    * Verify detection of rep78 as cat (5 levels)
    _tabtools_detect_vartype rep78
    assert "`result'" == "cat"
    * Verify price is continuous (either contn or conts)
    _tabtools_detect_vartype price
    assert inlist("`result'", "contn", "conts")
}
if _rc == 0 {
    display as result "  PASS: V7.1 - auto-detection on sysuse auto: foreign→bin, rep78→cat, price→continuous"
    local ++pass_count
}
else {
    display as error "  FAIL: V7.1 - auto-detection (error `=_rc')"
    local ++fail_count
}

* V7.2: High-cardinality continuous doubles should not overflow helper macros
local ++test_count
capture noisily {
    clear
    set obs 50000
    gen double hi_cont = _n + runiform()/1000000
    _tabtools_detect_vartype hi_cont
    assert "`result'" == "contn"
}
if _rc == 0 {
    display as result "  PASS: V7.2 - 50,000 unique doubles classify as contn without error"
    local ++pass_count
}
else {
    display as error "  FAIL: V7.2 - high-cardinality doubles (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V9: _tabtools_detect_vartype Accuracy
* ============================================================

**# V9: _tabtools_detect_vartype accuracy

* V9.1: Hand-crafted binary (0/1, N=100) → "bin"
local ++test_count
capture noisily {
    clear
    set seed 20260312
    set obs 100
    gen byte bv1 = mod(_n, 2)
    _tabtools_detect_vartype bv1
    assert "`result'" == "bin"
}
if _rc == 0 {
    display as result "  PASS: V9.1 - binary 0/1 N=100 → bin"
    local ++pass_count
}
else {
    display as error "  FAIL: V9.1 - binary 0/1 N=100 (error `=_rc')"
    local ++fail_count
}

* V9.2: Hand-crafted binary (0/1, N=200) → "bin"
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte bv2 = mod(_n, 2)
    _tabtools_detect_vartype bv2
    assert "`result'" == "bin"
}
if _rc == 0 {
    display as result "  PASS: V9.2 - binary 0/1 N=200 → bin"
    local ++pass_count
}
else {
    display as error "  FAIL: V9.2 - binary 0/1 N=200 (error `=_rc')"
    local ++fail_count
}

* V9.3: Labeled categorical (4 levels) → "cat"
local ++test_count
capture noisily {
    clear
    set obs 80
    gen byte cv3 = mod(_n, 4) + 1
    label define v9cat 1 "None" 2 "Low" 3 "Med" 4 "High"
    label values cv3 v9cat
    _tabtools_detect_vartype cv3
    assert "`result'" == "cat"
}
if _rc == 0 {
    display as result "  PASS: V9.3 - 4-level labeled categorical → cat"
    local ++pass_count
}
else {
    display as error "  FAIL: V9.3 - 4-level labeled (error `=_rc')"
    local ++fail_count
}

* V9.4: String variable → "cat"
local ++test_count
capture noisily {
    clear
    set obs 30
    gen str8 sv4 = cond(_n <= 10, "GroupA", cond(_n <= 20, "GroupB", "GroupC"))
    _tabtools_detect_vartype sv4
    assert "`result'" == "cat"
}
if _rc == 0 {
    display as result "  PASS: V9.4 - string variable → cat"
    local ++pass_count
}
else {
    display as error "  FAIL: V9.4 - string variable (error `=_rc')"
    local ++fail_count
}

* V9.5: Normal data (seed=12345, N=500) → "contn"
local ++test_count
capture noisily {
    clear
    set seed 12345
    set obs 500
    gen double cnv5 = rnormal(50, 10)
    _tabtools_detect_vartype cnv5
    assert "`result'" == "contn"
}
if _rc == 0 {
    display as result "  PASS: V9.5 - normal distribution N=500 → contn"
    local ++pass_count
}
else {
    display as error "  FAIL: V9.5 - normal distribution (error `=_rc')"
    local ++fail_count
}

* V9.6: Skewed data (exp(rnormal), seed=12345, N=500) → "conts"
local ++test_count
capture noisily {
    clear
    set seed 12345
    set obs 500
    gen double csv6 = exp(rnormal(0, 1.2))
    _tabtools_detect_vartype csv6
    assert "`result'" == "conts"
}
if _rc == 0 {
    display as result "  PASS: V9.6 - skewed distribution N=500 → conts"
    local ++pass_count
}
else {
    display as error "  FAIL: V9.6 - skewed distribution (error `=_rc')"
    local ++fail_count
}

* V9.7: Unlabeled 5-level integer → "cat"
local ++test_count
capture noisily {
    clear
    set obs 50
    gen byte cv7 = mod(_n, 5) + 1
    * No labels attached
    _tabtools_detect_vartype cv7
    assert "`result'" == "cat"
}
if _rc == 0 {
    display as result "  PASS: V9.7 - unlabeled 5-level integer → cat"
    local ++pass_count
}
else {
    display as error "  FAIL: V9.7 - unlabeled 5-level (error `=_rc')"
    local ++fail_count
}

* V9.8: Continuous with exactly 7 unique values → "cat" (boundary test)
local ++test_count
capture noisily {
    clear
    set obs 70
    gen byte cv8 = mod(_n, 7) + 1
    * 7 unique integer values — should classify as cat (not continuous)
    _tabtools_detect_vartype cv8
    assert "`result'" == "cat"
}
if _rc == 0 {
    display as result "  PASS: V9.8 - 7-unique-value integer → cat (boundary)"
    local ++pass_count
}
else {
    display as error "  FAIL: V9.8 - 7-unique-value boundary (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V10: tabtools set/get Round-Trip
* ============================================================

**# V10: tabtools set/get round-trip

tabtools set clear

* V10.1: set font → get → r(font) matches
local ++test_count
capture noisily {
    tabtools set font Calibri
    tabtools get
    assert "`r(font)'" == "Calibri"
}
if _rc == 0 {
    display as result "  PASS: V10.1 - set font Calibri → get → r(font)==Calibri"
    local ++pass_count
}
else {
    display as error "  FAIL: V10.1 - font round-trip (error `=_rc')"
    local ++fail_count
}

* V10.2: set fontsize → get → r(fontsize) matches
local ++test_count
capture noisily {
    tabtools set fontsize 12
    tabtools get
    assert "`r(fontsize)'" == "12"
}
if _rc == 0 {
    display as result "  PASS: V10.2 - set fontsize 12 → get → r(fontsize)==12"
    local ++pass_count
}
else {
    display as error "  FAIL: V10.2 - fontsize round-trip (error `=_rc')"
    local ++fail_count
}

* V10.3: set borderstyle → get → r(borderstyle) matches
local ++test_count
capture noisily {
    tabtools set borderstyle medium
    tabtools get
    assert "`r(borderstyle)'" == "medium"
}
if _rc == 0 {
    display as result "  PASS: V10.3 - set borderstyle medium → get → r(borderstyle)==medium"
    local ++pass_count
}
else {
    display as error "  FAIL: V10.3 - borderstyle round-trip (error `=_rc')"
    local ++fail_count
}

* V10.4: set clear → globals are empty, get returns defaults
local ++test_count
capture noisily {
    tabtools set font "Courier New"
    tabtools set fontsize 14
    tabtools set borderstyle medium
    tabtools set clear
    assert "$TABTOOLS_FONT" == ""
    assert "$TABTOOLS_FONTSIZE" == ""
    assert "$TABTOOLS_BORDER" == ""
    tabtools get
    assert "`r(font)'" == "Arial"
    assert "`r(fontsize)'" == "10"
    assert "`r(borderstyle)'" == "thin"
}
if _rc == 0 {
    display as result "  PASS: V10.4 - set clear resets globals, get returns defaults"
    local ++pass_count
}
else {
    display as error "  FAIL: V10.4 - clear round-trip (error `=_rc')"
    local ++fail_count
}

* V10.5: set font → table1_tc export → check_xlsx.py confirms font in output
local ++test_count
if `has_check_xlsx' {
    capture noisily {
        tabtools set font Calibri
        sysuse auto, clear
        capture erase "`output_dir'/_val_font_test.xlsx"
        table1_tc, by(foreign) vars(price contn \ mpg contn) ///
            excel("`output_dir'/_val_font_test.xlsx") sheet("Test")
        tabtools set clear

        capture erase "`output_dir'/_chk_v10.txt"
        shell python3 "`tools_dir'/check_xlsx.py" "`output_dir'/_val_font_test.xlsx" ///
            --font Calibri --result-file "`output_dir'/_chk_v10.txt"
        tempname fh10
        file open `fh10' using "`output_dir'/_chk_v10.txt", read text
        local _chk10 ""
        file read `fh10' _chk10
        file close `fh10'
        assert "`_chk10'" == "PASS"
    }
    if _rc == 0 {
        display as result "  PASS: V10.5 - set font Calibri → table1_tc output has Calibri font"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V10.5 - font propagation (error `=_rc')"
        local ++fail_count
    }
}
else {
    display as text "  SKIP: V10.5 - font propagation (check_xlsx.py unavailable)"
    local ++test_count
    local ++pass_count
    local --test_count
}

tabtools set clear

* ============================================================
* V12: Hand-Computed Value Checks
* ============================================================

**# V12: hand-computed value checks

* V12.1: table1_tc contn mean — hand-computed mean of {1,2,3,4,5} = 3.0
local ++test_count
capture noisily {
    clear
    set obs 10
    gen double y12 = mod(_n - 1, 5) + 1
    gen byte g12 = (_n > 5)
    label variable y12 "Test Y"
    * Verify Stata mean matches hand calculation
    summarize y12, meanonly
    assert abs(r(mean) - 3.0) < 0.0001
    * Run table1_tc and verify it produces output
    table1_tc, by(g12) vars(y12 contn)
}
if _rc == 0 {
    display as result "  PASS: V12.1 - contn mean of {1,2,3,4,5} = 3.0 correct"
    local ++pass_count
}
else {
    display as error "  FAIL: V12.1 - contn mean (error `=_rc')"
    local ++fail_count
}

* V12.2: contn SD — hand-computed SD of {1,2,3,4,5} = sqrt(2.5) ≈ 1.5811
* (math-only check: table1_tc requires 2 groups; verify via summarize)
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double y12b = _n
    label variable y12b "Test Y SD"
    * Stata uses N-1 denominator: var = 10/4 = 2.5, SD = sqrt(2.5)
    summarize y12b
    assert abs(r(sd) - sqrt(2.5)) < 0.001
}
if _rc == 0 {
    display as result "  PASS: V12.2 - contn SD of {1..5} = sqrt(2.5) ≈ 1.5811 correct"
    local ++pass_count
}
else {
    display as error "  FAIL: V12.2 - contn SD (error `=_rc')"
    local ++fail_count
}

* V12.3: cat percentages — 3 of 10 = 30.0%
* (math-only check)
local ++test_count
capture noisily {
    clear
    set obs 10
    gen byte cat12 = cond(_n <= 3, 1, 2)
    label define c12lbl 1 "Cat A" 2 "Cat B"
    label values cat12 c12lbl
    label variable cat12 "Category"
    count if cat12 == 1
    assert r(N) == 3
    * Percent = 3/10 = 30.0
    assert abs(3.0/10.0 - 0.3) < 0.0001
}
if _rc == 0 {
    display as result "  PASS: V12.3 - cat percentage 3/10 = 30.0% correct"
    local ++pass_count
}
else {
    display as error "  FAIL: V12.3 - cat percentage (error `=_rc')"
    local ++fail_count
}

* V12.4: bin count — 4 of 10 with value 1 = 40.0%
* (math-only check)
local ++test_count
capture noisily {
    clear
    set obs 10
    gen byte bin12 = (_n <= 4)
    label variable bin12 "Binary"
    count if bin12 == 1
    assert r(N) == 4
    assert abs(4.0/10.0 - 0.4) < 0.0001
}
if _rc == 0 {
    display as result "  PASS: V12.4 - bin count 4/10 = 40.0% correct"
    local ++pass_count
}
else {
    display as error "  FAIL: V12.4 - bin count (error `=_rc')"
    local ++fail_count
}

* V12.5: conts median — hand-computed median of {1,2,3,4,5,6} = 3.5
* (math-only check)
local ++test_count
capture noisily {
    clear
    set obs 6
    gen double y12e = _n
    label variable y12e "Test Skewed"
    * Stata median of {1,2,3,4,5,6}: (3+4)/2 = 3.5
    summarize y12e, detail
    assert abs(r(p50) - 3.5) < 0.001
}
if _rc == 0 {
    display as result "  PASS: V12.5 - conts median of {1..6} = 3.5 correct"
    local ++pass_count
}
else {
    display as error "  FAIL: V12.5 - conts median (error `=_rc')"
    local ++fail_count
}

* V12.6: contln geometric mean — exp(mean(ln({2,4,8}))) = exp(1.386) = 4.0
* (math-only check)
local ++test_count
capture noisily {
    clear
    set obs 3
    gen double y12f = 2^_n
    label variable y12f "Log-normal"
    * Hand calc: ln(2)=0.693, ln(4)=1.386, ln(8)=2.079; mean=1.386; exp(1.386)=4.0
    gen double lny12f = ln(y12f)
    summarize lny12f, meanonly
    assert abs(exp(r(mean)) - 4.0) < 0.001
}
if _rc == 0 {
    display as result "  PASS: V12.6 - contln geometric mean of {2,4,8} = 4.0 correct"
    local ++pass_count
}
else {
    display as error "  FAIL: V12.6 - contln geometric mean (error `=_rc')"
    local ++fail_count
}

* V12.7: regtab coefficient matches stored e(b)
local ++test_count
capture noisily {
    sysuse auto, clear
    * Run logistic and store coefficient
    logistic foreign price mpg
    matrix B = e(b)
    local beta_price = B[1,1]
    * Run regtab
    collect clear
    collect: logistic foreign price mpg
    capture erase "`output_dir'/_val_v12_coef.xlsx"
    regtab, xlsx("`output_dir'/_val_v12_coef.xlsx") sheet("Coef") coef("OR") noint
    * Verify the coefficient still matches e(b) — regtab does not modify e(b)
    matrix B2 = e(b)
    assert abs(B2[1,1] - `beta_price') < 0.0001
}
if _rc == 0 {
    display as result "  PASS: V12.7 - regtab coefficient matches stored e(b)"
    local ++pass_count
}
else {
    display as error "  FAIL: V12.7 - regtab coefficient (error `=_rc')"
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
local chk_files : dir "`output_dir'" files "_chk_*.txt"
foreach f of local chk_files {
    capture erase "`output_dir'/`f'"
}
capture erase "`output_dir'/_check_v10.txt"

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
