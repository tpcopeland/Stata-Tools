*! _nma_contrast_multiarm Version 1.0.1  2026/02/28
*! Build within-study V matrices for multi-arm studies

program define _nma_contrast_multiarm
    version 16.0
    set varabbrev off

    * Get study list and dimensions
    tempvar study_id
    egen `study_id' = group(_nma_study)
    quietly summarize `study_id'
    local n_studies = r(max)

    * Build V matrix for each study
    tempname dims
    matrix `dims' = J(`n_studies', 1, 0)

    forvalues s = 1/`n_studies' {
        quietly count if `study_id' == `s'
        local d = r(N)
        matrix `dims'[`s', 1] = `d'

        if `d' == 1 {
            * 2-arm study: V is scalar variance
            quietly summarize _nma_se if `study_id' == `s'
            local se_val = r(mean)
            tempname V`s'
            matrix `V`s'' = `se_val'^2
            matrix _nma_V_`s' = `V`s''
        }
        else {
            * Multi-arm study: V has covariance structure
            tempname V`s'
            matrix `V`s'' = J(`d', `d', 0)

            * Get var_base for this study
            quietly summarize _nma_var_base if `study_id' == `s'
            local vb = r(mean)

            * Get individual SEs
            local row = 0
            forvalues obs = 1/`=_N' {
                if `study_id'[`obs'] == `s' {
                    local ++row
                    local se_`row' = _nma_se[`obs']
                }
            }

            * Fill V matrix
            forvalues i = 1/`d' {
                matrix `V`s''[`i', `i'] = `se_`i''^2
                forvalues j = 1/`d' {
                    if `i' != `j' {
                        matrix `V`s''[`i', `j'] = `vb'
                    }
                }
            }
            matrix _nma_V_`s' = `V`s''
        }
    }

    matrix _nma_study_dims = `dims'
end
