*! mlearn_tune Version 1.0.0  2026/03/15
*! Hyperparameter tuning via grid or random search
*! Author: Timothy P Copeland
*! Program class: rclass

/*
Syntax:
  mlearn_tune varlist [if] [in], method(string) grid(string) [options]

  grid() format: "ntrees: 100 500 1000 maxdepth: 3 6 9 lrate: 0.01 0.1"
*/

program define mlearn_tune, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    syntax varlist(numeric min=2) [if] [in] , Method(string) ///
        GRID(string) [TASK(string) SEED(integer -1) FOLDs(integer 5) ///
         SEARch(string) NITer(integer 20) METric(string) noLOG]

    * Split varlist
    gettoken outcome features : varlist
    local features = strtrim("`features'")
    if "`features'" == "" {
        display as error "at least one feature variable required after outcome"
        set varabbrev `_vaset'
        exit 198
    }

    * =========================================================================
    * MARK SAMPLE
    * =========================================================================
    marksample touse
    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        set varabbrev `_vaset'
        exit 2000
    }
    local N = r(N)

    foreach v of local varlist {
        quietly count if missing(`v') & `touse'
        if r(N) > 0 {
            display as error "`v' has " r(N) " missing values"
            set varabbrev `_vaset'
            exit 416
        }
    }

    * =========================================================================
    * VALIDATE
    * =========================================================================
    capture program list _mlearn_validate_method
    if _rc {
        capture findfile _mlearn_validate_method.ado
        if _rc == 0 {
            run "`r(fn)'"
        }
        else {
            display as error "_mlearn_validate_method.ado not found; reinstall mlearn"
            set varabbrev `_vaset'
            exit 111
        }
    }
    capture noisily _mlearn_validate_method "`method'"
    if _rc {
        set varabbrev `_vaset'
        exit _rc
    }
    local method "`_mlearn_canonical_method'"

    if "`task'" == "" {
        capture program list _mlearn_auto_detect
        if _rc {
            capture findfile _mlearn_auto_detect.ado
            if _rc == 0 {
                run "`r(fn)'"
            }
            else {
                display as error "_mlearn_auto_detect.ado not found; reinstall mlearn"
                set varabbrev `_vaset'
                exit 111
            }
        }
        _mlearn_auto_detect `outcome' `touse'
        local task "`_mlearn_detected_task'"
    }
    else {
        local task = lower("`task'")
        if !inlist("`task'", "classification", "regression", "multiclass") {
            display as error "task() must be classification, regression, or multiclass"
            set varabbrev `_vaset'
            exit 198
        }
    }

    if "`search'" == "" local search "grid"
    if !inlist("`search'", "grid", "random") {
        display as error "search() must be grid or random"
        set varabbrev `_vaset'
        exit 198
    }

    if "`metric'" == "" {
        if "`task'" == "classification" | "`task'" == "multiclass" {
            local metric "accuracy"
        }
        else {
            local metric "rmse"
        }
    }

    local n_features : word count `features'

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

    global MLEARN_action "tune"
    global MLEARN_method "`method'"
    global MLEARN_task "`task'"
    global MLEARN_outcome "`outcome'"
    global MLEARN_features "`features'"
    global MLEARN_touse "`touse'"
    global MLEARN_seed_val "`seed'"
    global MLEARN_folds "`folds'"
    global MLEARN_grid "`grid'"
    global MLEARN_search "`search'"
    global MLEARN_niter "`niter'"
    global MLEARN_tune_metric "`metric'"

    if "`log'" == "" {
        display as text "Tuning `method' (`search' search, `folds'-fold CV)..."
    }

    capture noisily _mlearn_python_bridge _mlearn_engine.py
    local py_rc = _rc

    * Clean up input globals
    global MLEARN_action
    global MLEARN_method
    global MLEARN_task
    global MLEARN_outcome
    global MLEARN_features
    global MLEARN_touse
    global MLEARN_seed_val
    global MLEARN_folds
    global MLEARN_grid
    global MLEARN_search
    global MLEARN_niter
    global MLEARN_tune_metric

    if `py_rc' {
        foreach g in best_score best_params n_configs {
            global MLEARN_`g'
        }
        set varabbrev `_vaset'
        exit `py_rc'
    }

    * =========================================================================
    * RETRIEVE RESULTS
    * =========================================================================
    local best_score "$MLEARN_best_score"
    local best_params "$MLEARN_best_params"
    local n_configs "$MLEARN_n_configs"
    global MLEARN_best_score
    global MLEARN_best_params
    global MLEARN_n_configs

    return scalar best_score = `best_score'
    return scalar n_configs = `n_configs'
    return local best_params "`best_params'"
    return local method "`method'"
    return local metric "`metric'"
    return local search "`search'"

    * =========================================================================
    * DISPLAY
    * =========================================================================
    if "`log'" == "" {
        display as text ""
        display as text "{hline 60}"
        display as result "mlearn" as text " - Hyperparameter Tuning"
        display as text "{hline 60}"
        display as text ""
        display as text "Method:        " as result "`method'"
        display as text "Search:        " as result "`search'"
        display as text "Folds:         " as result "`folds'"
        display as text "Configurations:" as result " `n_configs'"
        display as text "Metric:        " as result "`metric'"
        display as text ""
        display as text "Best `metric': " as result %12.4f `best_score'
        display as text "Best params:   " as result "`best_params'"
        display as text "{hline 60}"
    }

    set varabbrev `_vaset'
end
