*! _nma_contrast_rate Version 1.0.1  2026/02/28
*! Compute contrasts for rate outcomes

program define _nma_contrast_rate
    version 16.0
    set varabbrev off
    set more off

    syntax , ref_code(integer)

    tempvar is_base study_has_ref min_trt
    gen byte `is_base' = (_nma_trt == `ref_code')
    bysort _nma_study : egen byte `study_has_ref' = max(`is_base')
    bysort _nma_study : egen double `min_trt' = min(_nma_trt)
    quietly replace `is_base' = (_nma_trt == `min_trt') if `study_has_ref' == 0

    tempvar base_events base_ptime base_trt_temp
    gen double `base_events' = _nma_events if `is_base'
    gen double `base_ptime' = _nma_ptime if `is_base'
    gen double `base_trt_temp' = _nma_trt if `is_base'
    bysort _nma_study : egen double _nma_base_events = max(`base_events')
    bysort _nma_study : egen double _nma_base_ptime = max(`base_ptime')
    bysort _nma_study : egen double _nma_base_trt = max(`base_trt_temp')

    gen double _nma_y = log(_nma_events / _nma_ptime) ///
        - log(_nma_base_events / _nma_base_ptime) if !`is_base'
    gen double _nma_se = sqrt(1/_nma_events + 1/_nma_base_events) if !`is_base'
    gen double _nma_var_base = 1 / _nma_base_events

    quietly drop if `is_base'
end
