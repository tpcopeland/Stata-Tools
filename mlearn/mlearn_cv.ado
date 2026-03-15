*! mlearn_cv Version 1.0.0  2026/03/15
*! K-fold cross-validation for mlearn models
*! Author: Timothy P Copeland
*! Program class: eclass

/*
Syntax:
  mlearn_cv varlist [if] [in], method(string) [options]

  First variable in varlist = outcome, remaining = features.

Required:
  method(string) - ML method: forest, boost, xgboost, lightgbm, svm, nnet, elasticnet

Optional:
  folds(integer 5)        - Number of CV folds (default 5)
  ntrees(integer 100)     - Number of trees
  maxdepth(integer 6)     - Maximum tree depth
  lrate(real 0.1)         - Learning rate
  task(string)            - Override auto-detection
  seed(integer -1)        - Random seed
  hparams(string)         - Additional key=value hyperparameters
  nolog                   - Suppress display
*/

program define mlearn_cv, eclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax varlist(numeric min=2) [if] [in] , Method(string) ///
        [FOLDs(integer 5) NTRees(integer 100) MAXDepth(integer 6) ///
         LRate(real 0.1) TASK(string) SEED(integer -1) ///
         hparams(string) noLOG]

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

    * Check for missing values
    foreach v of local varlist {
        quietly count if missing(`v') & `touse'
        if r(N) > 0 {
            display as error "`v' has " r(N) " missing values in estimation sample"
            display as error "mlearn does not handle missing values; drop or impute first"
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

    if `folds' < 2 | `folds' > `N' {
        display as error "folds() must be between 2 and N (=`N')"
        set varabbrev `_vaset'
        exit 198
    }

    local n_features : word count `features'

    * =========================================================================
    * AUTO-LOAD BRIDGE
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

    * =========================================================================
    * SET UP PYTHON GLOBALS
    * =========================================================================
    global MLEARN_action "cv"
    global MLEARN_method "`method'"
    global MLEARN_task "`task'"
    global MLEARN_outcome "`outcome'"
    global MLEARN_features "`features'"
    global MLEARN_touse "`touse'"
    global MLEARN_seed_val "`seed'"
    global MLEARN_folds "`folds'"
    global MLEARN_ntrees "`ntrees'"
    global MLEARN_maxdepth "`maxdepth'"
    global MLEARN_lrate "`lrate'"
    global MLEARN_hparams_raw "`hparams'"

    * =========================================================================
    * RUN PYTHON ENGINE
    * =========================================================================
    if "`log'" == "" {
        display as text "Cross-validating `method' (`task', `folds' folds)..."
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
    global MLEARN_ntrees
    global MLEARN_maxdepth
    global MLEARN_lrate
    global MLEARN_hparams_raw

    if `py_rc' {
        foreach g in accuracy f1 auc rmse mae r2 ///
            sd_accuracy sd_f1 sd_auc sd_rmse sd_mae sd_r2 ///
            n_folds n_obs {
            global MLEARN_`g'
        }
        set varabbrev `_vaset'
        exit `py_rc'
    }

    * =========================================================================
    * RETRIEVE RESULTS
    * =========================================================================
    tempname b V

    if "`task'" == "classification" | "`task'" == "multiclass" {
        local acc "$MLEARN_accuracy"
        local f1  "$MLEARN_f1"
        local auc "$MLEARN_auc"
        local sd_acc "$MLEARN_sd_accuracy"
        local sd_f1  "$MLEARN_sd_f1"
        local sd_auc "$MLEARN_sd_auc"
        global MLEARN_accuracy
        global MLEARN_f1
        global MLEARN_auc
        global MLEARN_sd_accuracy
        global MLEARN_sd_f1
        global MLEARN_sd_auc
        if `auc' == -999 local auc = .
        if `sd_auc' == -999 local sd_auc = .

        if `auc' != . {
            matrix `b' = (`acc', `auc', `f1')
            matrix colnames `b' = accuracy auc f1
            matrix `V' = J(3, 3, 0)
            matrix `V'[1,1] = `sd_acc'^2
            matrix `V'[2,2] = `sd_auc'^2
            matrix `V'[3,3] = `sd_f1'^2
            matrix colnames `V' = accuracy auc f1
            matrix rownames `V' = accuracy auc f1
        }
        else {
            matrix `b' = (`acc', `f1')
            matrix colnames `b' = accuracy f1
            matrix `V' = J(2, 2, 0)
            matrix `V'[1,1] = `sd_acc'^2
            matrix `V'[2,2] = `sd_f1'^2
            matrix colnames `V' = accuracy f1
            matrix rownames `V' = accuracy f1
        }
    }
    else {
        local rmse "$MLEARN_rmse"
        local mae  "$MLEARN_mae"
        local r2   "$MLEARN_r2"
        local sd_rmse "$MLEARN_sd_rmse"
        local sd_mae  "$MLEARN_sd_mae"
        local sd_r2   "$MLEARN_sd_r2"
        global MLEARN_rmse
        global MLEARN_mae
        global MLEARN_r2
        global MLEARN_sd_rmse
        global MLEARN_sd_mae
        global MLEARN_sd_r2

        matrix `b' = (`rmse', `mae', `r2')
        matrix colnames `b' = rmse mae r2
        matrix `V' = J(3, 3, 0)
        matrix `V'[1,1] = `sd_rmse'^2
        matrix `V'[2,2] = `sd_mae'^2
        matrix `V'[3,3] = `sd_r2'^2
        matrix colnames `V' = rmse mae r2
        matrix rownames `V' = rmse mae r2
    }

    * Clean up per-fold globals
    forvalues fi = 1/`folds' {
        foreach k in accuracy f1 auc rmse mae r2 {
            capture global MLEARN_fold`fi'_`k'
        }
    }
    global MLEARN_n_folds
    global MLEARN_n_obs

    ereturn post `b' `V', obs(`N') esample(`touse') properties(b V)

    * Scalars
    ereturn scalar N = `N'
    ereturn scalar folds = `folds'
    ereturn scalar n_features = `n_features'
    ereturn scalar seed = `seed'

    if "`task'" == "classification" | "`task'" == "multiclass" {
        ereturn scalar accuracy = `acc'
        ereturn scalar sd_accuracy = `sd_acc'
        ereturn scalar f1 = `f1'
        ereturn scalar sd_f1 = `sd_f1'
        if `auc' != . {
            ereturn scalar auc = `auc'
            ereturn scalar sd_auc = `sd_auc'
        }
    }
    else {
        ereturn scalar rmse = `rmse'
        ereturn scalar sd_rmse = `sd_rmse'
        ereturn scalar mae = `mae'
        ereturn scalar sd_mae = `sd_mae'
        ereturn scalar r2 = `r2'
        ereturn scalar sd_r2 = `sd_r2'
    }

    * Macros
    ereturn local cmd "mlearn"
    ereturn local subcmd "cv"
    ereturn local method "`method'"
    ereturn local task "`task'"
    ereturn local outcome "`outcome'"
    ereturn local features "`features'"
    ereturn local depvar "`outcome'"
    ereturn local title "mlearn CV: `method' (`task', `folds'-fold)"

    * =========================================================================
    * DISPLAY RESULTS
    * =========================================================================
    if "`log'" == "" {
        display as text ""
        display as text "{hline 60}"
        display as result "mlearn" as text " - `folds'-Fold Cross-Validation"
        display as text "{hline 60}"
        display as text ""
        display as text "Method:        " as result "`method'"
        display as text "Task:          " as result "`task'"
        display as text "Outcome:       " as result "`outcome'"
        display as text "Features:      " as result "`n_features'"
        display as text "Observations:  " as result %10.0fc `N'
        display as text "Folds:         " as result %10.0fc `folds'
        display as text ""
        display as text "{hline 50}"
        display as text %22s "Metric" as text " {c |}" ///
            as text %12s "Mean" as text %12s "Std. Dev."
        display as text "{hline 22}{c +}{hline 26}"

        if "`task'" == "classification" | "`task'" == "multiclass" {
            display as text %22s "Accuracy" as text " {c |}" ///
                as result %12.4f `acc' as result %12.4f `sd_acc'
            if `auc' != . {
                display as text %22s "AUC" as text " {c |}" ///
                    as result %12.4f `auc' as result %12.4f `sd_auc'
            }
            display as text %22s "F1 Score" as text " {c |}" ///
                as result %12.4f `f1' as result %12.4f `sd_f1'
        }
        else {
            display as text %22s "RMSE" as text " {c |}" ///
                as result %12.4f `rmse' as result %12.4f `sd_rmse'
            display as text %22s "MAE" as text " {c |}" ///
                as result %12.4f `mae' as result %12.4f `sd_mae'
            display as text %22s "R-squared" as text " {c |}" ///
                as result %12.4f `r2' as result %12.4f `sd_r2'
        }
        display as text "{hline 50}"
    }

    set varabbrev `_vaset'
end
