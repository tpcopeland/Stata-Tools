*! _nma_contrast_binary Version 1.0.1  2026/02/28
*! Compute contrasts for binary outcomes

program define _nma_contrast_binary
    version 16.0
    set varabbrev off

    syntax , measure(string) ref_code(integer) zcorrection(real)

    * Identify studies needing zero-cell correction
    tempvar has_zero any_zero
    gen byte `has_zero' = (_nma_events == 0 | _nma_events == _nma_total)
    bysort _nma_study : egen byte `any_zero' = max(`has_zero')

    * Report corrections
    quietly count if `any_zero' & `has_zero'
    if r(N) > 0 {
        local n_corrected = r(N)
        display as text "  Zero-cell correction (`zcorrection') applied to " ///
            as result "`n_corrected'" as text " arms"

        * Apply correction to ALL arms of affected studies
        quietly replace _nma_events = _nma_events + `zcorrection' if `any_zero'
        quietly replace _nma_total = _nma_total + 2 * `zcorrection' if `any_zero'
    }

    * Identify study baseline arm
    tempvar is_base study_has_ref min_trt
    gen byte `is_base' = (_nma_trt == `ref_code')
    bysort _nma_study : egen byte `study_has_ref' = max(`is_base')
    bysort _nma_study : egen double `min_trt' = min(_nma_trt)
    quietly replace `is_base' = (_nma_trt == `min_trt') if `study_has_ref' == 0

    * Merge baseline arm values
    tempvar base_events base_total
    gen double `base_events' = _nma_events if `is_base'
    gen double `base_total' = _nma_total if `is_base'
    bysort _nma_study : egen double _nma_base_events = max(`base_events')
    bysort _nma_study : egen double _nma_base_total = max(`base_total')

    * Store baseline treatment code
    tempvar base_trt_temp
    gen double `base_trt_temp' = _nma_trt if `is_base'
    bysort _nma_study : egen double _nma_base_trt = max(`base_trt_temp')

    * Compute contrasts (non-baseline arms only)
    if "`measure'" == "or" {
        gen double _nma_y = log(_nma_events / (_nma_total - _nma_events)) ///
            - log(_nma_base_events / (_nma_base_total - _nma_base_events)) ///
            if !`is_base'
        gen double _nma_se = sqrt(1/_nma_events + 1/(_nma_total - _nma_events) ///
            + 1/_nma_base_events + 1/(_nma_base_total - _nma_base_events)) ///
            if !`is_base'
    }
    else if "`measure'" == "rr" {
        gen double _nma_y = log(_nma_events / _nma_total) ///
            - log(_nma_base_events / _nma_base_total) ///
            if !`is_base'
        gen double _nma_se = sqrt(1/_nma_events - 1/_nma_total ///
            + 1/_nma_base_events - 1/_nma_base_total) ///
            if !`is_base'
    }
    else if "`measure'" == "rd" {
        gen double _nma_y = (_nma_events / _nma_total) ///
            - (_nma_base_events / _nma_base_total) ///
            if !`is_base'
        gen double _nma_se = sqrt( ///
            (_nma_events / _nma_total) * (1 - _nma_events / _nma_total) / _nma_total ///
            + (_nma_base_events / _nma_base_total) * (1 - _nma_base_events / _nma_base_total) / _nma_base_total ///
            ) if !`is_base'
    }

    * Variance of baseline arm (for multi-arm covariance)
    if "`measure'" == "or" {
        gen double _nma_var_base = 1/_nma_base_events ///
            + 1/(_nma_base_total - _nma_base_events)
    }
    else if "`measure'" == "rr" {
        gen double _nma_var_base = 1/_nma_base_events - 1/_nma_base_total
    }
    else if "`measure'" == "rd" {
        gen double _nma_var_base = (_nma_base_events / _nma_base_total) ///
            * (1 - _nma_base_events / _nma_base_total) / _nma_base_total
    }

    * Drop baseline arm rows
    quietly drop if `is_base'
end
