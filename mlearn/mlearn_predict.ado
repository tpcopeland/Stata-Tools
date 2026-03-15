*! mlearn_predict Version 1.0.0  2026/03/15
*! Load serialized model and generate predictions
*! Author: Timothy P Copeland
*! Program class: rclass

/*
Syntax:
  mlearn_predict [if] [in], [generate(name) probability class replace using(string)]

Options:
  generate(name)  - Name for new prediction variable (default: _mlearn_pred)
  probability     - Predict probabilities instead of classes (classification only)
  class           - Predict class labels (default for classification)
  replace         - Replace existing prediction variable
  using(string)   - Path to saved model file (overrides dataset characteristic)
*/

program define mlearn_predict, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    syntax [if] [in] , [GENerate(name) PRobability CLass replace Using(string)]

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
        * Auto-load check helper
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
    * SET PREDICTION VARIABLE
    * =========================================================================
    if "`generate'" == "" local generate "_mlearn_pred"

    if "`replace'" != "" {
        capture drop `generate'
    }
    else {
        capture confirm variable `generate'
        if _rc == 0 {
            display as error "variable `generate' already exists"
            display as error "use {bf:replace} to overwrite"
            set varabbrev `_vaset'
            exit 110
        }
    }

    * =========================================================================
    * MARK SAMPLE
    * =========================================================================
    * Get features from stored characteristics
    local features : char _dta[_mlearn_features]
    if "`features'" == "" {
        display as error "feature variables not found in dataset characteristics"
        display as error "train a model on this dataset first"
        set varabbrev `_vaset'
        exit 198
    }

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
    local N = r(N)

    * =========================================================================
    * CREATE PREDICTION VARIABLE
    * =========================================================================
    quietly gen double `generate' = .

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

    global MLEARN_action "predict"
    global MLEARN_model_path "`model_path'"
    global MLEARN_touse "`touse'"
    global MLEARN_pred_var "`generate'"
    global MLEARN_want_prob = cond("`probability'" != "", "1", "0")

    capture noisily _mlearn_python_bridge _mlearn_engine.py
    local py_rc = _rc

    * Clean up globals
    global MLEARN_action
    global MLEARN_model_path
    global MLEARN_touse
    global MLEARN_pred_var
    global MLEARN_want_prob

    if `py_rc' {
        capture drop `generate'
        set varabbrev `_vaset'
        exit `py_rc'
    }

    * Label the prediction variable
    local task : char _dta[_mlearn_task]
    local method : char _dta[_mlearn_method]
    if "`probability'" != "" {
        label variable `generate' "Predicted probability (`method')"
    }
    else {
        label variable `generate' "Predicted `task' (`method')"
    }

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================
    quietly count if !missing(`generate') & `touse'
    local n_pred = r(N)

    display as text "Predictions stored in " as result "`generate'" ///
        as text " (`n_pred' observations)"

    return scalar N = `n_pred'
    return local predict_var "`generate'"
    return local model_path "`model_path'"

    set varabbrev `_vaset'
end
