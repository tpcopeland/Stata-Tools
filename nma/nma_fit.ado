*! nma_fit Version 1.0.2  2026/03/01
*! Consistency model fitting for network meta-analysis
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: eclass (returns results in e())

/*
Basic syntax:
  nma_fit [, method(reml|ml) common level(cilevel)
      iterate(integer 200) tolerance(real 1e-8) nolog]

Description:
  Fits the consistency model for network meta-analysis using
  multivariate random-effects meta-analysis (REML by default).
  Requires data prepared by nma_setup or nma_import.

See help nma_fit for complete documentation
*/

program define nma_fit, eclass
    version 16.0
    local _varabbrev = c(varabbrev)
    set varabbrev off

    * =======================================================================
    * SYNTAX PARSING
    * =======================================================================

    syntax [, METHod(string) COMMON Level(cilevel) ///
        ITERate(integer 200) TOLerance(real 1e-8) ///
        noLOG EFORM DIGits(integer 4)]

    if "`method'" == "" local method "reml"
    if !inlist("`method'", "reml", "ml") {
        display as error "method() must be reml or ml"
        exit 198
    }
    if "`level'" == "" local level 95

    * =======================================================================
    * CHECK PREREQUISITES
    * =======================================================================

    _nma_check_setup
    _nma_get_settings

    local measure     "`_nma_measure'"
    local ref         "`_nma_ref'"
    local treatments  "`_nma_treatments'"
    local n_treatments = `_nma_n_treatments'
    local n_studies   = `_nma_n_studies'
    local n_comparisons = `_nma_n_comparisons'
    local outcome_type "`_nma_outcome_type'"
    local ref_code    : char _dta[_nma_ref_code]

    _nma_display_header, command("nma_fit") ///
        description("Fitting consistency model")

    * =======================================================================
    * BUILD DESIGN MATRIX
    * =======================================================================

    * The design matrix maps study-level contrasts to basic parameters
    * Basic parameters: d_1R, d_2R, ..., d_{k-1,R} (all vs reference)
    * p = k - 1 parameters

    local p = `n_treatments' - 1

    * Build mapping: which parameter columns correspond to which treatments
    * Treatment codes 1..k, ref_code is excluded
    local param_trts ""
    local col = 0
    forvalues t = 1/`n_treatments' {
        if `t' != `ref_code' {
            local ++col
            local param_trts "`param_trts' `t'"
            local param_col_`t' = `col'
        }
    }

    * Stack y vector and build X matrix
    * Each row: study contrast d_{ab} = d_{aR} - d_{bR}
    * where a = treatment arm, b = study baseline
    * So X row has +1 at column for a, -1 at column for b (if b != ref)

    quietly count
    local N = r(N)

    * Create Stata matrices
    tempname y_mat x_mat
    matrix `y_mat' = J(`N', 1, 0)
    matrix `x_mat' = J(`N', `p', 0)

    forvalues obs = 1/`N' {
        matrix `y_mat'[`obs', 1] = _nma_y[`obs']

        local trt_code = _nma_trt[`obs']
        local base_code = .

        * Determine base treatment for this study
        * base_code stored in _nma_base_trt (from contrast computation)
        capture confirm variable _nma_base_trt
        if _rc == 0 {
            local base_code = _nma_base_trt[`obs']
        }
        else {
            * For arm-level setup, base is in _nma_base_events context
            * The base treatment code was stored during contrast computation
            * Get it from the study's reference
            local ref_code_val : char _dta[_nma_ref_code]
            local base_code = `ref_code_val'
        }

        * X row: +1 for trt_code (if not ref), -1 for base_code (if not ref)
        if `trt_code' != `ref_code' {
            local col = `param_col_`trt_code''
            matrix `x_mat'[`obs', `col'] = 1
        }
        if `base_code' != `ref_code' {
            local col = `param_col_`base_code''
            matrix `x_mat'[`obs', `col'] = -1
        }
    }

    * Study dimensions (contrasts per study) already in _nma_study_dims

    * =======================================================================
    * FIT MODEL VIA REML ENGINE
    * =======================================================================

    * Pass matrices to Mata engine
    matrix _nma_y_vec = `y_mat'
    matrix _nma_X_mat = `x_mat'

    local log_opt ""
    if "`log'" == "nolog" local log_opt "nolog"

    _nma_reml, y_matrix("_nma_y_vec") x_matrix("_nma_X_mat") ///
        v_prefix("_nma_V_") n_studies(`n_studies') dim(`p') ///
        method(`method') `common' iterate(`iterate') ///
        tolerance(`tolerance') `log_opt'

    * =======================================================================
    * LABEL AND POST RESULTS
    * =======================================================================

    * _nma_reml stored results in regular Stata matrices
    * Read them, label, and post to e()

    * Get coefficient vector and V matrix from _nma_reml output
    tempname b V
    matrix `b' = _nma_reml_b
    matrix `V' = _nma_reml_V

    * Label columns with treatment names
    local colnames ""
    foreach t of local param_trts {
        local lbl : char _dta[_nma_trt_`t']
        local lbl = subinstr("`lbl'", " ", "_", .)
        local colnames "`colnames' effect:`lbl'"
    }
    matrix colnames `b' = `colnames'
    matrix colnames `V' = `colnames'
    matrix rownames `V' = `colnames'

    * Retrieve scalars from _nma_reml output
    local tau2 = _nma_reml_tau2[1,1]
    local ll_val = _nma_reml_ll[1,1]
    local conv_val = _nma_reml_conv[1,1]
    local iter_val = _nma_reml_iter[1,1]

    tempname Sigma_mat
    capture matrix `Sigma_mat' = _nma_reml_Sigma

    * Compute I-squared
    tempvar se2_var
    gen double `se2_var' = _nma_se^2
    quietly summarize `se2_var', detail
    local typical_v = r(p50)
    if `tau2' + `typical_v' > 0 {
        local I2 = 100 * `tau2' / (`tau2' + `typical_v')
    }
    else {
        local I2 = 0
    }

    * Post labeled matrices to e() (consumes b and V tempnames)
    ereturn post `b' `V', obs(`N')

    * Retrieve back from e() for display later
    matrix `b' = e(b)
    matrix `V' = e(V)

    ereturn scalar tau2 = `tau2'
    ereturn scalar I2 = `I2'
    ereturn scalar ll = `ll_val'
    ereturn scalar converged = `conv_val'
    ereturn scalar iterations = `iter_val'
    ereturn scalar k = `n_treatments'
    ereturn scalar n_studies = `n_studies'
    ereturn scalar n_comparisons = `n_comparisons'

    ereturn local cmd "nma_fit"
    ereturn local method "`method'"
    ereturn local measure "`measure'"
    ereturn local ref "`ref'"
    ereturn local treatments "`treatments'"
    ereturn local outcome_type "`outcome_type'"

    capture ereturn matrix Sigma = `Sigma_mat'

    * Clean up _nma_reml temp matrices
    capture matrix drop _nma_reml_b
    capture matrix drop _nma_reml_V
    capture matrix drop _nma_reml_Sigma
    capture matrix drop _nma_reml_tau2
    capture matrix drop _nma_reml_ll
    capture matrix drop _nma_reml_conv
    capture matrix drop _nma_reml_iter

    * Store fitted state
    char _dta[_nma_fitted] "1"
    char _dta[_nma_tau2] "`tau2'"
    char _dta[_nma_method] "`method'"

    * =======================================================================
    * DISPLAY RESULTS
    * =======================================================================

    local uc_method = strupper("`method'")
    display as text "Method: " as result "`uc_method'" ///
        as text " | Studies: " as result "`n_studies'" ///
        as text " | Treatments: " as result "`n_treatments'" ///
        as text " | Comparisons: " as result "`n_comparisons'"
    display as text ""

    * Determine display transformation
    local transform ""
    local null_val = 0
    if "`eform'" != "" {
        if inlist("`measure'", "or", "rr", "irr", "hr") {
            local transform "eform"
            local null_val = 1
        }
    }

    * Display coefficient table
    display as text "{hline 78}"
    if "`transform'" == "eform" {
        display as text %~20s "Treatment" _col(22) %~10s "Exp(Coef)" ///
            _col(33) %~8s "SE" _col(42) %~18s "[`level'% CI]" ///
            _col(62) %~8s "P-value" _col(72) %~8s "Evidence"
    }
    else {
        display as text %~20s "Treatment" _col(22) %~10s "Coef" ///
            _col(33) %~8s "SE" _col(42) %~18s "[`level'% CI]" ///
            _col(62) %~8s "P-value" _col(72) %~8s "Evidence"
    }
    display as text "{hline 78}"

    local z_crit = invnormal(1 - (1 - `level'/100) / 2)

    local col = 0
    foreach t of local param_trts {
        local ++col
        local lbl : char _dta[_nma_trt_`t']
        local coef = `b'[1, `col']
        local se = sqrt(`V'[`col', `col'])
        local ci_lo = `coef' - `z_crit' * `se'
        local ci_hi = `coef' + `z_crit' * `se'
        local z = `coef' / `se'
        local pval = 2 * (1 - normal(abs(`z')))

        * Evidence type for this comparison (vs reference)
        local ev_code = _nma_evidence[`t', `ref_code']
        if `ev_code' == 1 local ev_label "Direct"
        else if `ev_code' == 2 local ev_label "Indirect"
        else if `ev_code' == 3 local ev_label "Mixed"
        else local ev_label "N/A"

        * Format p-value
        if `pval' < 0.001 {
            local pval_str "<0.001"
        }
        else {
            local pval_str : display %6.3f `pval'
        }

        * Apply eform transformation
        if "`transform'" == "eform" {
            local disp_coef = exp(`coef')
            local disp_lo = exp(`ci_lo')
            local disp_hi = exp(`ci_hi')
        }
        else {
            local disp_coef = `coef'
            local disp_lo = `ci_lo'
            local disp_hi = `ci_hi'
        }

        display as result %-20s "`lbl' vs `ref'" ///
            _col(22) %9.`digits'f `disp_coef' ///
            _col(33) %7.`digits'f `se' ///
            _col(42) "[" %7.`digits'f `disp_lo' ", " %7.`digits'f `disp_hi' "]" ///
            _col(62) %8s "`pval_str'" ///
            _col(72) as text "`ev_label'"
    }
    display as text "{hline 78}"

    * Heterogeneity
    display as text ""
    if "`common'" != "" {
        display as text "Model: Common (fixed) effect"
    }
    else {
        display as text "Heterogeneity: tau2 = " as result %7.`digits'f `tau2' ///
            as text ", I2 = " as result %5.1f `I2' as text "%"
    }

    if "`measure'" == "or" | "`measure'" == "rr" | "`measure'" == "irr" {
        display as text "Note: Coefficients are on log scale." ///
            " Use {bf:eform} option for exponentiated estimates."
    }
    if "`eform'" != "" & inlist("`measure'", "or", "rr", "irr", "hr") {
        display as text "Note: Results displayed on exponentiated scale."
    }

    set varabbrev `_varabbrev'
end
