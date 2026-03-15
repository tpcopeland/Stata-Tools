*! mlearn_importance Version 1.0.0  2026/03/15
*! Feature importance from trained model
*! Author: Timothy P Copeland
*! Program class: rclass

program define mlearn_importance, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    syntax , [PLOT noLOG Using(string)]

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

    global MLEARN_action "importance"
    global MLEARN_model_path "`model_path'"

    capture noisily _mlearn_python_bridge _mlearn_engine.py
    local py_rc = _rc

    global MLEARN_action
    global MLEARN_model_path

    if `py_rc' {
        set varabbrev `_vaset'
        exit `py_rc'
    }

    * =========================================================================
    * RETRIEVE RESULTS
    * =========================================================================
    local n_features "$MLEARN_n_imp_features"
    local method : char _dta[_mlearn_method]
    global MLEARN_n_imp_features

    * Build results
    forvalues i = 1/`n_features' {
        local fname "`=strrtrim("${MLEARN_imp_name_`i'}")'"
        local fval  "${MLEARN_imp_val_`i'}"
        return scalar imp_`fname' = `fval'
        global MLEARN_imp_name_`i'
        global MLEARN_imp_val_`i'
    }

    return scalar n_features = `n_features'
    return local method "`method'"

    * =========================================================================
    * DISPLAY
    * =========================================================================
    if "`log'" == "" {
        display as text ""
        display as text "{hline 50}"
        display as result "Feature Importance" as text " (`method')"
        display as text "{hline 50}"
        display as text %22s "Feature" as text " {c |}" as text %12s "Importance"
        display as text "{hline 22}{c +}{hline 14}"

        forvalues i = 1/`n_features' {
            local fname "`=strrtrim("${MLEARN_imp_disp_`i'}")'"
            local fval  "${MLEARN_imp_disp_val_`i'}"
            display as text %22s "`fname'" as text " {c |}" ///
                as result %12.4f `fval'
            global MLEARN_imp_disp_`i'
            global MLEARN_imp_disp_val_`i'
        }
        display as text "{hline 50}"
    }

    * =========================================================================
    * PLOT
    * =========================================================================
    if "`plot'" != "" {
        * Build bar chart data from stored results
        local features : char _dta[_mlearn_features]
        local n : word count `features'
        preserve
        clear
        quietly set obs `n'
        quietly gen str32 feature = ""
        quietly gen double importance = .
        quietly gen int rank = .

        forvalues i = 1/`n' {
            local fname "${MLEARN_imp_plot_name_`i'}"
            local fval  "${MLEARN_imp_plot_val_`i'}"
            quietly replace feature = "`fname'" in `i'
            quietly replace importance = `fval' in `i'
            quietly replace rank = `i' in `i'
            global MLEARN_imp_plot_name_`i'
            global MLEARN_imp_plot_val_`i'
        }

        graph hbar importance, over(feature, sort(rank)) ///
            title("Feature Importance") ///
            ytitle("Importance") ///
            scheme(plotplainblind) ///
            bar(1, color(navy))
        restore
    }

    set varabbrev `_vaset'
end
