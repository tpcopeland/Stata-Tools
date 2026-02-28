*! _nma_contrast_continuous Version 1.0.1  2026/02/28
*! Compute contrasts for continuous outcomes

program define _nma_contrast_continuous
    version 16.0
    set varabbrev off
    set more off

    syntax , measure(string) ref_code(integer)

    tempvar is_base study_has_ref min_trt
    gen byte `is_base' = (_nma_trt == `ref_code')
    bysort _nma_study : egen byte `study_has_ref' = max(`is_base')
    bysort _nma_study : egen double `min_trt' = min(_nma_trt)
    quietly replace `is_base' = (_nma_trt == `min_trt') if `study_has_ref' == 0

    tempvar base_mean base_sd base_n base_trt_temp
    gen double `base_mean' = _nma_mean if `is_base'
    gen double `base_sd' = _nma_sd if `is_base'
    gen double `base_n' = _nma_n if `is_base'
    gen double `base_trt_temp' = _nma_trt if `is_base'
    bysort _nma_study : egen double _nma_base_mean = max(`base_mean')
    bysort _nma_study : egen double _nma_base_sd = max(`base_sd')
    bysort _nma_study : egen double _nma_base_n = max(`base_n')
    bysort _nma_study : egen double _nma_base_trt = max(`base_trt_temp')

    if "`measure'" == "md" {
        gen double _nma_y = _nma_mean - _nma_base_mean if !`is_base'
        gen double _nma_se = sqrt(_nma_sd^2 / _nma_n + _nma_base_sd^2 / _nma_base_n) ///
            if !`is_base'
        gen double _nma_var_base = _nma_base_sd^2 / _nma_base_n
    }
    else if "`measure'" == "smd" {
        tempvar sp
        gen double `sp' = sqrt( ///
            ((_nma_n - 1) * _nma_sd^2 + (_nma_base_n - 1) * _nma_base_sd^2) / ///
            (_nma_n + _nma_base_n - 2) ///
        ) if !`is_base'
        gen double _nma_y = (_nma_mean - _nma_base_mean) / `sp' if !`is_base'
        gen double _nma_se = sqrt(1/_nma_n + 1/_nma_base_n + ///
            _nma_y^2 / (2 * (_nma_n + _nma_base_n))) if !`is_base'
        gen double _nma_var_base = 1/_nma_base_n
    }

    quietly drop if `is_base'
end
