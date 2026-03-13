*! nma_import Version 1.0.3  2026/02/28
*! Pre-computed effect size import for network meta-analysis
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  nma_import effect se [if] [in], studyvar(varname) treat1(varname) treat2(varname)
      [ref(string) measure(string) covariance(varname)]

Description:
  Imports pre-computed effect sizes (e.g., log ORs, HRs, MDs) with their
  standard errors for network meta-analysis. Each row should represent one
  pairwise comparison within a study.

See help nma_import for complete documentation
*/

program define nma_import, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    set varabbrev off

    * Clean up global matrices from any previous nma run
    foreach mat in _nma_adj _nma_evidence _nma_sucra _nma_meanrank ///
        _nma_rankprob _nma_node_x _nma_node_y _nma_node_sizes ///
        _nma_edge_weights _nma_study_dims _nma_y_vec _nma_X_mat {
        capture matrix drop `mat'
    }
    forvalues i = 1/500 {
        capture matrix drop _nma_V_`i'
        if _rc != 0 continue, break
    }
    capture frame drop _nma_original

    * =======================================================================
    * SYNTAX PARSING
    * =======================================================================

    syntax varlist(numeric min=2 max=2) [if] [in] , ///
        STUDYvar(varname) TREAT1(varname) TREAT2(varname) ///
        [REF(string) MEAsure(string) COVariance(varname) FORCE]

    local var_effect : word 1 of `varlist'
    local var_se : word 2 of `varlist'

    if "`measure'" == "" local measure "or"

    _nma_display_header, command("nma_import") ///
        description("Importing pre-computed effect sizes for network meta-analysis")

    * =======================================================================
    * MARK SAMPLE
    * =======================================================================

    marksample touse
    markout `touse' `var_effect' `var_se'
    if "`covariance'" != "" markout `touse' `covariance'

    * Handle string variables manually (markout drops all obs for strings)
    foreach v in `studyvar' `treat1' `treat2' {
        capture confirm string variable `v'
        if _rc == 0 {
            quietly replace `touse' = 0 if missing(`v') | `v' == ""
        }
        else {
            markout `touse' `v'
        }
    }

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }

    * =======================================================================
    * VALIDATE
    * =======================================================================

    * SE must be positive
    quietly count if `var_se' <= 0 & `touse'
    if r(N) > 0 {
        display as error "standard errors must be > 0"
        exit 198
    }

    * treat1 != treat2
    capture confirm string variable `treat1'
    if _rc == 0 {
        quietly count if `treat1' == `treat2' & `touse'
    }
    else {
        quietly count if `treat1' == `treat2' & `touse'
    }
    if r(N) > 0 {
        display as error "treat1 and treat2 must differ within each row"
        exit 198
    }

    * =======================================================================
    * PRESERVE AND PREPARE
    * =======================================================================

    quietly keep if `touse'

    capture frame drop _nma_original
    frame put *, into(_nma_original)

    * Build treatment list from both treat1 and treat2
    capture confirm string variable `treat1'
    local trt_is_string = (_rc == 0)

    if `trt_is_string' {
        * String treatments: collect unique values
        tempvar trt_all
        gen `trt_all' = `treat1'
        local N_orig = _N
        quietly set obs `=_N * 2'
        forvalues i = 1/`N_orig' {
            quietly replace `trt_all' = `treat2'[`i'] in `=`N_orig' + `i''
        }
        quietly levelsof `trt_all' in 1/`=2*`N_orig'', local(all_trts)
        quietly drop in `=`N_orig'+1'/l
    }
    else {
        * Numeric treatments
        quietly levelsof `treat1', local(trts1)
        quietly levelsof `treat2', local(trts2)
        local all_trts : list trts1 | trts2
        local all_trts : list sort all_trts
    }

    local k : word count `all_trts'
    local treatments ""
    local _i = 0
    foreach t of local all_trts {
        local ++_i
        if `trt_is_string' {
            local treatments "`treatments' `t'"
            char _dta[_nma_trt_`_i'] "`t'"
        }
        else {
            * Check for value labels
            local lbl : label (`treat1') `t', strict
            if "`lbl'" == "" local lbl "`t'"
            local treatments "`treatments' `lbl'"
            char _dta[_nma_trt_`_i'] "`lbl'"
        }
    }
    local treatments = strtrim("`treatments'")

    * Create numeric treatment codes
    tempvar trt1_num trt2_num
    if `trt_is_string' {
        quietly gen long `trt1_num' = .
        quietly gen long `trt2_num' = .
        local i = 0
        foreach t of local all_trts {
            local ++i
            quietly replace `trt1_num' = `i' if `treat1' == "`t'"
            quietly replace `trt2_num' = `i' if `treat2' == "`t'"
        }
    }
    else {
        quietly gen long `trt1_num' = .
        quietly gen long `trt2_num' = .
        local i = 0
        foreach t of local all_trts {
            local ++i
            quietly replace `trt1_num' = `i' if `treat1' == `t'
            quietly replace `trt2_num' = `i' if `treat2' == `t'
        }
    }

    * =======================================================================
    * SELECT REFERENCE
    * =======================================================================

    if "`ref'" == "" {
        * Auto-select most common treatment
        local max_count = 0
        local ref_code = 1
        forvalues i = 1/`k' {
            quietly count if `trt1_num' == `i' | `trt2_num' == `i'
            if r(N) > `max_count' {
                local max_count = r(N)
                local ref_code = `i'
            }
        }
        local ref : char _dta[_nma_trt_`ref_code']
        local ref_auto "auto-selected: most connected"
    }
    else {
        local ref_code = 0
        local i = 0
        foreach t of local all_trts {
            local ++i
            local lbl : char _dta[_nma_trt_`i']
            if "`lbl'" == "`ref'" local ref_code = `i'
        }
        if `ref_code' == 0 {
            display as error "reference treatment `ref' not found"
            display as error "available treatments: `treatments'"
            exit 198
        }
        local ref_auto "user-specified"
    }

    * =======================================================================
    * ORIENT CONTRASTS (treat2 vs treat1 where treat1 is closer to ref)
    * =======================================================================

    * Ensure consistent direction: higher-coded - lower-coded
    * Then the design matrix maps correctly
    * _nma_y = treat1 - treat2, so _nma_trt = treat1, _nma_base_trt = treat2
    * This ensures _nma_y = d_{trt,R} - d_{base,R} for the design matrix
    gen double _nma_y = `var_effect'
    gen double _nma_se = `var_se'
    quietly gen double _nma_study = .
    gen double _nma_trt = `trt1_num'
    gen double _nma_base_trt = `trt2_num'

    * Orient: if trt < base (trt1 < trt2), flip to make _nma_trt the higher code
    quietly replace _nma_y = -_nma_y if `trt1_num' < `trt2_num'
    quietly replace _nma_trt = `trt2_num' if `trt1_num' < `trt2_num'
    quietly replace _nma_base_trt = `trt1_num' if `trt1_num' < `trt2_num'

    * Create study numeric ID
    tempvar study_num
    egen `study_num' = group(`studyvar'), label
    quietly replace _nma_study = `study_num'

    * =======================================================================
    * BUILD ADJACENCY AND CHECK CONNECTIVITY
    * =======================================================================

    quietly levelsof `study_num', local(study_levels)
    local n_studies : word count `study_levels'

    tempname adj
    matrix `adj' = J(`k', `k', 0)
    forvalues obs = 1/`=_N' {
        local t1 = _nma_base_trt[`obs']
        local t2 = _nma_trt[`obs']
        matrix `adj'[`t1', `t2'] = `adj'[`t1', `t2'] + 1
        matrix `adj'[`t2', `t1'] = `adj'[`t2', `t1'] + 1
    }

    tempname adj_bin
    matrix `adj_bin' = J(`k', `k', 0)
    forvalues i = 1/`k' {
        forvalues j = 1/`k' {
            if `adj'[`i', `j'] > 0 matrix `adj_bin'[`i', `j'] = 1
        }
    }
    matrix _nma_adj = `adj_bin'

    _nma_validate_network, k(`k') adj_matrix("_nma_adj")

    local connected = `_nma_connected'
    if !`connected' & "`force'" == "" {
        display as error "network is disconnected"
        display as error "specify {bf:force} to proceed"
        matrix drop _nma_adj
        exit 198
    }

    * Count direct comparisons
    local n_comparisons = 0
    forvalues i = 1/`k' {
        forvalues j = `=`i'+1'/`k' {
            if `adj'[`i', `j'] > 0 local ++n_comparisons
        }
    }
    local n_possible = `k' * (`k' - 1) / 2

    * Classify evidence
    _nma_classify_evidence, k(`k') adj_matrix("_nma_adj")

    local n_direct = 0
    local n_indirect = 0
    local n_mixed = 0
    forvalues i = 1/`k' {
        forvalues j = `=`i'+1'/`k' {
            local ev = _nma_evidence[`i', `j']
            if `ev' == 1 local ++n_direct
            else if `ev' == 2 local ++n_indirect
            else if `ev' == 3 local ++n_mixed
        }
    }

    * =======================================================================
    * BUILD V MATRICES
    * =======================================================================

    * For imported data, V = diag(se^2) unless covariance provided
    gen double _nma_var_base = 0
    if "`covariance'" != "" {
        quietly replace _nma_var_base = `covariance'
    }

    _nma_contrast_multiarm

    * =======================================================================
    * STORE METADATA
    * =======================================================================

    char _dta[_nma_setup] "1"
    char _dta[_nma_format] "contrast"
    char _dta[_nma_measure] "`measure'"
    char _dta[_nma_studyvar] "`studyvar'"
    char _dta[_nma_trtvar] "`treat1'"
    char _dta[_nma_ref] "`ref'"
    char _dta[_nma_treatments] "`treatments'"
    char _dta[_nma_n_treatments] "`k'"
    char _dta[_nma_n_studies] "`n_studies'"
    char _dta[_nma_n_comparisons] "`n_comparisons'"
    char _dta[_nma_outcome_type] "precomputed"
    char _dta[_nma_n_direct] "`n_direct'"
    char _dta[_nma_n_indirect] "`n_indirect'"
    char _dta[_nma_n_mixed] "`n_mixed'"

    * Treatment labels already stored in _dta[_nma_trt_*] during encoding
    char _dta[_nma_ref_code] "`ref_code'"

    * Measure description
    if "`measure'" == "or" local measure_desc "log odds ratio"
    else if "`measure'" == "rr" local measure_desc "log risk ratio"
    else if "`measure'" == "hr" local measure_desc "log hazard ratio"
    else if "`measure'" == "md" local measure_desc "mean difference"
    else if "`measure'" == "smd" local measure_desc "standardized mean difference"
    else if "`measure'" == "irr" local measure_desc "log incidence rate ratio"
    else local measure_desc "`measure'"

    * =======================================================================
    * DISPLAY
    * =======================================================================

    display as text "Outcome type: " as result "Pre-computed (`measure_desc')"
    display as text "Reference treatment: " as result "`ref'" ///
        as text " (`ref_auto')"
    display as text ""
    display as text "Network summary:"
    display as text "  Studies: " as result "`n_studies'" ///
        as text " | Treatments: " as result "`k'" ///
        as text " | Direct comparisons: " as result "`n_comparisons'"
    display as text "  Total possible comparisons: " as result "`n_possible'"
    display as text "  Evidence: " as result "`n_direct'" as text " direct, " ///
        as result "`n_indirect'" as text " indirect-only, " ///
        as result "`n_mixed'" as text " mixed"

    * =======================================================================
    * RETURNS
    * =======================================================================

    return scalar n_studies = `n_studies'
    return scalar n_treatments = `k'
    return scalar n_comparisons = `n_comparisons'
    return scalar n_direct = `n_direct'
    return scalar n_indirect = `n_indirect'
    return scalar n_mixed = `n_mixed'
    return scalar connected = `connected'
    return local treatments "`treatments'"
    return local ref "`ref'"
    return local measure "`measure'"
    * Copy before returning (return matrix moves, not copies)
    tempname ev_copy adj_copy
    matrix `ev_copy' = _nma_evidence
    matrix `adj_copy' = _nma_adj
    return matrix evidence = `ev_copy'
    return matrix adjacency = `adj_copy'

    set varabbrev `_varabbrev'
end
