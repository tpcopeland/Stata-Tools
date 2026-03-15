*! mlearn_shap Version 1.0.0  2026/03/15
*! SHAP values from trained model
*! Author: Timothy P Copeland
*! Program class: rclass

program define mlearn_shap, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    syntax , [PLOT noLOG Using(string) MAXSamples(integer 500)]

    * =========================================================================
    * CHECK MODEL EXISTS
    * =========================================================================
    if "`using'" != "" {
        local model_path "`using'"
        capture confirm file "`model_path'"
        if _rc {
            display as error "model file not found: `model_path'"
            set varabbrev `_vaset'
            exit 601
        }
    }
    else {
        capture program list _mlearn_check_trained
        if _rc {
            capture findfile _mlearn_check_trained.ado
            if _rc == 0 {
                run "`r(fn)'"
            }
            else {
                display as error "_mlearn_check_trained.ado not found; reinstall mlearn"
                set varabbrev `_vaset'
                exit 111
            }
        }
        capture noisily _mlearn_check_trained
        if _rc {
            set varabbrev `_vaset'
            exit _rc
        }
        local model_path : char _dta[_mlearn_model_path]
    }

    local features : char _dta[_mlearn_features]
    local task     : char _dta[_mlearn_task]

    * Need touse for data pull
    marksample touse, novarlist
    foreach v of local features {
        capture confirm variable `v'
        if _rc {
            display as error "feature variable `v' not found"
            set varabbrev `_vaset'
            exit 111
        }
        markout `touse' `v'
    }
    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        set varabbrev `_vaset'
        exit 2000
    }

    * =========================================================================
    * AUTO-LOAD BRIDGE AND RUN
    * =========================================================================
    capture program list _mlearn_python_bridge
    if _rc {
        capture findfile _mlearn_python_bridge.ado
        if _rc == 0 {
            run "`r(fn)'"
        }
        else {
            display as error "_mlearn_python_bridge.ado not found; reinstall mlearn"
            set varabbrev `_vaset'
            exit 111
        }
    }

    global MLEARN_action "shap"
    global MLEARN_model_path "`model_path'"
    global MLEARN_touse "`touse'"
    global MLEARN_features "`features'"
    global MLEARN_task "`task'"
    global MLEARN_max_samples "`maxsamples'"
    global MLEARN_shap_plot = cond("`plot'" != "", "1", "0")

    if "`log'" == "" {
        display as text "Computing SHAP values..."
    }

    capture noisily _mlearn_python_bridge _mlearn_engine.py
    local py_rc = _rc

    global MLEARN_action
    global MLEARN_model_path
    global MLEARN_touse
    global MLEARN_features
    global MLEARN_task
    global MLEARN_max_samples
    global MLEARN_shap_plot

    if `py_rc' {
        set varabbrev `_vaset'
        exit `py_rc'
    }

    * =========================================================================
    * RETRIEVE RESULTS
    * =========================================================================
    local n_features "$MLEARN_shap_n_features"
    local n_samples  "$MLEARN_shap_n_samples"
    global MLEARN_shap_n_features
    global MLEARN_shap_n_samples

    return scalar n_features = `n_features'
    return scalar n_samples = `n_samples'

    if "`log'" == "" {
        display as text ""
        display as text "{hline 50}"
        display as result "SHAP Values" as text " (mean |SHAP|)"
        display as text "{hline 50}"
        display as text %22s "Feature" as text " {c |}" as text %12s "Mean |SHAP|"
        display as text "{hline 22}{c +}{hline 14}"
    }

    forvalues i = 1/`n_features' {
        local fname "${MLEARN_shap_name_`i'}"
        local fval  "${MLEARN_shap_val_`i'}"
        return scalar shap_`fname' = `fval'
        global MLEARN_shap_name_`i'
        global MLEARN_shap_val_`i'

        if "`log'" == "" {
            display as text %22s "`fname'" as text " {c |}" ///
                as result %12.4f `fval'
        }
    }

    if "`log'" == "" {
        display as text "{hline 50}"
        display as text "Computed on `n_samples' observations"
    }

    return local method : char _dta[_mlearn_method]

    set varabbrev `_vaset'
end
