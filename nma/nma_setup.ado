*! nma_setup Version 1.0.1  2026/02/28
*! Arm-level data import for network meta-analysis
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  nma_setup events total [if] [in], studyvar(varname) trtvar(varname)
      [ref(string) measure(or|rr|rd) zcorrection(real 0.5)]

  nma_setup mean sd n [if] [in], studyvar(varname) trtvar(varname)
      [ref(string) measure(md|smd)]

  nma_setup events persontime [if] [in], studyvar(varname) trtvar(varname)
      [ref(string) measure(irr)]

Description:
  Imports arm-level summary data for network meta-analysis. Auto-detects
  outcome type (binary/continuous/rate) from the number of variables
  specified. Computes contrasts, builds variance matrices, validates
  network connectivity, and prepares data for nma_fit.

See help nma_setup for complete documentation
*/

program define nma_setup, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    set varabbrev off

    * Clean up global matrices from any previous nma run
    foreach mat in _nma_adj _nma_evidence _nma_sucra _nma_meanrank ///
        _nma_rankprob _nma_node_x _nma_node_y _nma_node_sizes ///
        _nma_edge_weights _nma_study_dims _nma_y_vec _nma_X_mat {
        capture matrix drop `mat'
    }
    * Clean up numbered V matrices
    forvalues i = 1/500 {
        capture matrix drop _nma_V_`i'
        if _rc != 0 continue, break
    }
    capture frame drop _nma_original

    * =======================================================================
    * SYNTAX PARSING
    * =======================================================================

    * Parse: 2 vars = binary or rate, 3 vars = continuous
    * We detect type from variable count and measure() option
    syntax varlist(numeric min=2 max=3) [if] [in] , ///
        STUDYvar(varname) TRTvar(varname) ///
        [REF(string) MEAsure(string) ZCorrection(real 0.5) FORCE]

    local nvars : word count `varlist'

    * =======================================================================
    * DETECT OUTCOME TYPE
    * =======================================================================

    if `nvars' == 3 {
        * Continuous: mean sd n
        local outcome_type "continuous"
        local var_mean : word 1 of `varlist'
        local var_sd : word 2 of `varlist'
        local var_n : word 3 of `varlist'
        if "`measure'" == "" local measure "md"
        if !inlist("`measure'", "md", "smd") {
            display as error "measure() must be md or smd for continuous outcomes"
            exit 198
        }
    }
    else if `nvars' == 2 {
        * Binary or rate: need to distinguish
        local var1 : word 1 of `varlist'
        local var2 : word 2 of `varlist'

        if "`measure'" == "irr" {
            * Rate: events person-time
            local outcome_type "rate"
            local var_events "`var1'"
            local var_ptime "`var2'"
        }
        else {
            * Binary: events total (default)
            local outcome_type "binary"
            local var_events "`var1'"
            local var_total "`var2'"
            if "`measure'" == "" local measure "or"
            if !inlist("`measure'", "or", "rr", "rd") {
                display as error "measure() must be or, rr, or rd for binary outcomes"
                exit 198
            }
        }
    }

    _nma_display_header, command("nma_setup") ///
        description("Preparing arm-level data for network meta-analysis")

    * =======================================================================
    * MARK SAMPLE
    * =======================================================================

    marksample touse

    * Handle string variables manually (markout doesn't work with strings)
    capture confirm string variable `studyvar'
    if _rc == 0 {
        quietly replace `touse' = 0 if missing(`studyvar') | `studyvar' == ""
    }
    else {
        markout `touse' `studyvar'
    }
    capture confirm string variable `trtvar'
    if _rc == 0 {
        quietly replace `touse' = 0 if missing(`trtvar') | `trtvar' == ""
    }
    else {
        markout `touse' `trtvar'
    }

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N_obs = r(N)

    * =======================================================================
    * VALIDATE INPUTS
    * =======================================================================

    * Check no missing values in key variables
    if "`outcome_type'" == "binary" {
        markout `touse' `var_events' `var_total'
        * Validate: events >= 0, total > 0, events <= total
        quietly count if (`var_events' < 0 | `var_total' <= 0 | `var_events' > `var_total') & `touse'
        if r(N) > 0 {
            display as error "invalid values: events must be 0-total, total must be > 0"
            exit 198
        }
    }
    else if "`outcome_type'" == "continuous" {
        markout `touse' `var_mean' `var_sd' `var_n'
        quietly count if (`var_sd' < 0 | `var_n' <= 0) & `touse'
        if r(N) > 0 {
            display as error "invalid values: sd must be >= 0, n must be > 0"
            exit 198
        }
    }
    else if "`outcome_type'" == "rate" {
        markout `touse' `var_events' `var_ptime'
        quietly count if (`var_events' < 0 | `var_ptime' <= 0) & `touse'
        if r(N) > 0 {
            display as error "invalid values: events must be >= 0, person-time must be > 0"
            exit 198
        }
    }

    * Check at least 2 arms per study
    tempvar n_arms
    bysort `studyvar' : egen `n_arms' = total(`touse') if `touse'
    quietly count if `n_arms' < 2 & `touse'
    if r(N) > 0 {
        display as error "some studies have fewer than 2 arms"
        exit 198
    }

    * Check no duplicate treatment within study
    tempvar dup_check
    bysort `studyvar' `trtvar' : gen `dup_check' = _N if `touse'
    quietly count if `dup_check' > 1 & `touse'
    if r(N) > 0 {
        display as error "duplicate treatment arms found within studies"
        exit 198
    }

    * =======================================================================
    * ENCODE TREATMENTS
    * =======================================================================

    * Keep only sample
    quietly keep if `touse'

    * Preserve original data in a frame
    capture frame drop _nma_original
    frame put *, into(_nma_original)

    * Build treatment list
    * Determine if trtvar is string or numeric
    local trt_is_string = 0
    capture confirm string variable `trtvar'
    if _rc == 0 {
        local trt_is_string = 1
    }

    * Create numeric study and treatment IDs
    tempvar study_num trt_num
    if `trt_is_string' {
        encode `trtvar', gen(`trt_num')
    }
    else {
        * Numeric treatment variable: create labeled version
        egen `trt_num' = group(`trtvar'), label
    }
    egen `study_num' = group(`studyvar'), label

    * Get treatment labels
    quietly levelsof `trt_num', local(trt_levels)
    local treatments ""
    local k = 0
    foreach lev of local trt_levels {
        local ++k
        local lbl : label (`trt_num') `lev'
        local treatments "`treatments' `lbl'"
        char _dta[_nma_trt_`k'] "`lbl'"
    }
    local treatments = strtrim("`treatments'")

    * =======================================================================
    * SELECT REFERENCE TREATMENT
    * =======================================================================

    if "`ref'" == "" {
        * Auto-select: most connected treatment (highest degree)
        tempvar trt_degree
        bysort `studyvar' : gen `trt_degree' = _N - 1
        tempvar total_degree
        bysort `trt_num' : egen `total_degree' = total(`trt_degree')

        * Find treatment with max total degree
        quietly summarize `total_degree'
        local max_deg = r(max)
        quietly levelsof `trt_num' if `total_degree' == `max_deg', local(max_trt)
        local ref_code : word 1 of `max_trt'
        local ref : label (`trt_num') `ref_code'
        local ref_auto "auto-selected: most connected"
    }
    else {
        * User-specified reference
        local ref_code = .
        foreach lev of local trt_levels {
            local lbl : label (`trt_num') `lev'
            if "`lbl'" == "`ref'" {
                local ref_code = `lev'
            }
        }
        if `ref_code' == . {
            display as error "reference treatment `ref' not found in data"
            display as error "available treatments: `treatments'"
            exit 198
        }
        local ref_auto "user-specified"
    }

    * =======================================================================
    * COUNT STUDIES AND COMPARISONS
    * =======================================================================

    quietly levelsof `study_num', local(study_levels)
    local n_studies : word count `study_levels'
    local n_treatments = `k'

    * Count direct comparisons (unique treatment pairs with at least one study)
    * Build adjacency matrix
    tempname adj
    matrix `adj' = J(`k', `k', 0)

    foreach s of local study_levels {
        quietly levelsof `trt_num' if `study_num' == `s', local(arms_in_s)
        local arm_list ""
        foreach a of local arms_in_s {
            local arm_list "`arm_list' `a'"
        }
        local n_a : word count `arm_list'
        forvalues i = 1/`n_a' {
            forvalues j = `=`i'+1'/`n_a' {
                local ai : word `i' of `arm_list'
                local aj : word `j' of `arm_list'
                matrix `adj'[`ai', `aj'] = `adj'[`ai', `aj'] + 1
                matrix `adj'[`aj', `ai'] = `adj'[`aj', `ai'] + 1
            }
        }
    }

    * Count direct comparisons
    local n_comparisons = 0
    forvalues i = 1/`k' {
        forvalues j = `=`i'+1'/`k' {
            if `adj'[`i', `j'] > 0 local ++n_comparisons
        }
    }
    local n_possible = `k' * (`k' - 1) / 2

    * =======================================================================
    * VALIDATE NETWORK CONNECTIVITY
    * =======================================================================

    * Store adjacency as binary for connectivity check
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
    local n_components = `_nma_n_components'

    if !`connected' & "`force'" == "" {
        display as error "network is disconnected (`n_components' components)"
        display as error "components: `_nma_components'"
        display as error "NMA requires a connected network"
        display as error "specify {bf:force} to proceed with disconnected components"
        matrix drop _nma_adj
        exit 198
    }
    else if !`connected' {
        display as text "  {bf:Warning:} Network is disconnected (`n_components' components)"
        display as text "  Cross-component estimates will be marked as not estimable"
    }

    * =======================================================================
    * CLASSIFY EVIDENCE
    * =======================================================================

    _nma_classify_evidence, k(`k') adj_matrix("_nma_adj")

    * Count evidence types
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
    * COMPUTE CONTRASTS
    * =======================================================================

    * Create internal working variables
    gen double _nma_study = `study_num'
    gen double _nma_trt = `trt_num'

    if "`outcome_type'" == "binary" {
        gen double _nma_events = `var_events'
        gen double _nma_total = `var_total'
        _nma_contrast_binary, measure("`measure'") ref_code(`ref_code') ///
            zcorrection(`zcorrection')
    }
    else if "`outcome_type'" == "continuous" {
        gen double _nma_mean = `var_mean'
        gen double _nma_sd = `var_sd'
        gen double _nma_n = `var_n'
        _nma_contrast_continuous, measure("`measure'") ref_code(`ref_code')
    }
    else if "`outcome_type'" == "rate" {
        gen double _nma_events = `var_events'
        gen double _nma_ptime = `var_ptime'
        _nma_contrast_rate, ref_code(`ref_code')
    }

    * =======================================================================
    * BUILD WITHIN-STUDY V MATRICES
    * =======================================================================

    _nma_contrast_multiarm

    * =======================================================================
    * STORE METADATA
    * =======================================================================

    char _dta[_nma_setup] "1"
    char _dta[_nma_format] "arm"
    char _dta[_nma_measure] "`measure'"
    char _dta[_nma_studyvar] "`studyvar'"
    char _dta[_nma_trtvar] "`trtvar'"
    char _dta[_nma_ref] "`ref'"
    char _dta[_nma_treatments] "`treatments'"
    char _dta[_nma_n_treatments] "`n_treatments'"
    char _dta[_nma_n_studies] "`n_studies'"
    char _dta[_nma_n_comparisons] "`n_comparisons'"
    char _dta[_nma_outcome_type] "`outcome_type'"
    char _dta[_nma_n_direct] "`n_direct'"
    char _dta[_nma_n_indirect] "`n_indirect'"
    char _dta[_nma_n_mixed] "`n_mixed'"

    * Treatment labels already stored in _dta[_nma_trt_*] during encoding
    char _dta[_nma_ref_code] "`ref_code'"

    * Measure description for display
    if "`measure'" == "or" local measure_desc "log odds ratio"
    else if "`measure'" == "rr" local measure_desc "log risk ratio"
    else if "`measure'" == "rd" local measure_desc "risk difference"
    else if "`measure'" == "md" local measure_desc "mean difference"
    else if "`measure'" == "smd" local measure_desc "standardized mean difference"
    else if "`measure'" == "irr" local measure_desc "log incidence rate ratio"

    * =======================================================================
    * DISPLAY SUMMARY
    * =======================================================================

    local uc_type = proper("`outcome_type'")
    display as text "Outcome type: " as result "`uc_type' (`measure_desc')"
    display as text "Reference treatment: " as result "`ref'" ///
        as text " (`ref_auto')"
    display as text ""
    display as text "Network summary:"
    display as text "  Studies: " as result "`n_studies'" ///
        as text " | Treatments: " as result "`n_treatments'" ///
        as text " | Direct comparisons: " as result "`n_comparisons'"
    display as text "  Total possible comparisons: " as result "`n_possible'"
    display as text "  Evidence: " as result "`n_direct'" as text " direct, " ///
        as result "`n_indirect'" as text " indirect-only, " ///
        as result "`n_mixed'" as text " mixed"
    display as text ""

    if `connected' {
        display as text "Connectivity: " as result "Network is fully connected"
    }
    else {
        display as text "Connectivity: " as error "Disconnected (`n_components' components)"
    }

    * =======================================================================
    * RETURNS
    * =======================================================================

    return scalar n_studies = `n_studies'
    return scalar n_treatments = `n_treatments'
    return scalar n_comparisons = `n_comparisons'
    return scalar n_direct = `n_direct'
    return scalar n_indirect = `n_indirect'
    return scalar n_mixed = `n_mixed'
    return scalar connected = `connected'
    return local treatments "`treatments'"
    return local ref "`ref'"
    return local measure "`measure'"
    return local outcome_type "`outcome_type'"
    * Copy matrices before returning (return matrix moves, not copies)
    tempname ev_copy adj_copy
    matrix `ev_copy' = _nma_evidence
    matrix `adj_copy' = _nma_adj
    return matrix evidence = `ev_copy'
    return matrix adjacency = `adj_copy'

    set varabbrev `_varabbrev'
end
