*! mlearn_train Version 1.0.0  2026/03/15
*! Train machine learning model, post metrics to e(), store model
*! Author: Timothy P Copeland
*! Program class: eclass

/*
Syntax:
  mlearn_train varlist [if] [in], method(string) [options]

  First variable in varlist = outcome, remaining = features.

Required:
  method(string) - ML method: forest, boost, xgboost, lightgbm, svm, nnet, elasticnet

Optional:
  ntrees(integer 100)   - Number of trees (tree methods)
  maxdepth(integer 6)   - Maximum tree depth
  lrate(real 0.1)       - Learning rate
  task(string)          - Override auto-detection: classification, regression, multiclass
  seed(integer -1)      - Random seed (-1 = no seed)
  saving(string)        - File path to persist model
  trainpct(real 1)      - Train/test split ratio (default 1 = no split)
  hparams(string)       - Additional key=value hyperparameters
  nolog                 - Suppress display
*/

program define mlearn_train, eclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax varlist(numeric min=2) [if] [in] , Method(string) ///
        [NTRees(integer 100) MAXDepth(integer 6) LRate(real 0.1) ///
         TASK(string) SEED(integer -1) SAVing(string) ///
         TRAINPct(real 1) hparams(string) noLOG]

    * Split varlist: first = outcome, rest = features
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
    * VALIDATE METHOD
    * =========================================================================
    * Auto-load helper
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

    * =========================================================================
    * DETECT TASK TYPE
    * =========================================================================
    if "`task'" == "" {
        * Auto-load helper
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

    * =========================================================================
    * VALIDATE OPTIONS
    * =========================================================================
    if `trainpct' <= 0 | `trainpct' > 1 {
        display as error "trainpct() must be in (0, 1]"
        set varabbrev `_vaset'
        exit 198
    }

    if `ntrees' < 1 {
        display as error "ntrees() must be >= 1"
        set varabbrev `_vaset'
        exit 198
    }

    if `maxdepth' < 1 {
        display as error "maxdepth() must be >= 1"
        set varabbrev `_vaset'
        exit 198
    }

    if `lrate' <= 0 {
        display as error "lrate() must be > 0"
        set varabbrev `_vaset'
        exit 198
    }

    * Count features
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
    * SET UP PYTHON GLOBALS (Python reads via Macro.getGlobal)
    * =========================================================================
    global MLEARN_action "train"
    global MLEARN_method "`method'"
    global MLEARN_task "`task'"
    global MLEARN_outcome "`outcome'"
    global MLEARN_features "`features'"
    global MLEARN_touse "`touse'"
    global MLEARN_seed_val "`seed'"
    global MLEARN_trainpct "`trainpct'"
    global MLEARN_saving "`saving'"
    global MLEARN_ntrees "`ntrees'"
    global MLEARN_maxdepth "`maxdepth'"
    global MLEARN_lrate "`lrate'"
    global MLEARN_hparams_raw "`hparams'"

    * =========================================================================
    * RUN PYTHON ENGINE
    * =========================================================================
    if "`log'" == "" {
        display as text "Training `method' (`task')..."
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
    global MLEARN_trainpct
    global MLEARN_saving
    global MLEARN_ntrees
    global MLEARN_maxdepth
    global MLEARN_lrate
    global MLEARN_hparams_raw

    if `py_rc' {
        * Clean up any output globals on error
        foreach g in model_path_out n_train n_test hparams_store ///
            accuracy f1 auc rmse mae r2 {
            global MLEARN_`g'
        }
        set varabbrev `_vaset'
        exit `py_rc'
    }

    * =========================================================================
    * RETRIEVE RESULTS
    * =========================================================================
    local model_path "$MLEARN_model_path_out"
    local n_train "$MLEARN_n_train"
    local n_test  "$MLEARN_n_test"
    local hparams_store "$MLEARN_hparams_store"

    * Clean up globals
    global MLEARN_model_path_out
    global MLEARN_n_train
    global MLEARN_n_test
    global MLEARN_hparams_store

    * =========================================================================
    * POST ECLASS RESULTS
    * =========================================================================
    tempname b V

    if "`task'" == "classification" | "`task'" == "multiclass" {
        local acc "$MLEARN_accuracy"
        local f1  "$MLEARN_f1"
        local auc "$MLEARN_auc"
        * Clean up globals
        global MLEARN_accuracy
        global MLEARN_f1
        global MLEARN_auc
        if `auc' == -999 local auc = .

        matrix `b' = (`acc', `f1')
        matrix colnames `b' = accuracy f1
        matrix `V' = J(2, 2, 0)
        matrix colnames `V' = accuracy f1
        matrix rownames `V' = accuracy f1

        if `auc' != . {
            matrix `b' = (`acc', `auc', `f1')
            matrix colnames `b' = accuracy auc f1
            matrix `V' = J(3, 3, 0)
            matrix colnames `V' = accuracy auc f1
            matrix rownames `V' = accuracy auc f1
        }
    }
    else {
        local rmse "$MLEARN_rmse"
        local mae  "$MLEARN_mae"
        local r2   "$MLEARN_r2"
        * Clean up globals
        global MLEARN_rmse
        global MLEARN_mae
        global MLEARN_r2

        matrix `b' = (`rmse', `mae', `r2')
        matrix colnames `b' = rmse mae r2
        matrix `V' = J(3, 3, 0)
        matrix colnames `V' = rmse mae r2
        matrix rownames `V' = rmse mae r2
    }

    ereturn post `b' `V', obs(`N') esample(`touse') properties(b V)

    * Scalars
    ereturn scalar N = `N'
    ereturn scalar n_train = `n_train'
    ereturn scalar n_test = `n_test'
    ereturn scalar n_features = `n_features'
    ereturn scalar seed = `seed'
    ereturn scalar trainpct = `trainpct'

    if "`task'" == "classification" | "`task'" == "multiclass" {
        ereturn scalar accuracy = `acc'
        ereturn scalar f1 = `f1'
        if `auc' != . {
            ereturn scalar auc = `auc'
        }
    }
    else {
        ereturn scalar rmse = `rmse'
        ereturn scalar mae = `mae'
        ereturn scalar r2 = `r2'
    }

    * Locals
    ereturn local cmd "mlearn"
    ereturn local subcmd "train"
    ereturn local method "`method'"
    ereturn local task "`task'"
    ereturn local outcome "`outcome'"
    ereturn local features "`features'"
    ereturn local model_path "`model_path'"
    ereturn local hparams "`hparams_store'"
    ereturn local depvar "`outcome'"
    ereturn local title "mlearn `method' (`task')"

    * =========================================================================
    * STORE DATASET CHARACTERISTICS
    * =========================================================================
    char _dta[_mlearn_trained]     "1"
    char _dta[_mlearn_method]      "`method'"
    char _dta[_mlearn_task]        "`task'"
    char _dta[_mlearn_outcome]     "`outcome'"
    char _dta[_mlearn_features]    "`features'"
    char _dta[_mlearn_n_features]  "`n_features'"
    char _dta[_mlearn_model_path]  "`model_path'"
    char _dta[_mlearn_seed]        "`seed'"
    char _dta[_mlearn_N_train]     "`n_train'"
    char _dta[_mlearn_hparams]     "`hparams_store'"

    * =========================================================================
    * DISPLAY RESULTS
    * =========================================================================
    if "`log'" == "" {
        * Auto-load display helper
        capture program list _mlearn_display
        if _rc {
            capture findfile _mlearn_display.ado
            if _rc == 0 {
                run "`r(fn)'"
            }
        }
        capture noisily _mlearn_display "`task'" "`method'" `N' `n_features' "`outcome'" `n_train' `n_test'
    }

    set varabbrev `_vaset'
end
