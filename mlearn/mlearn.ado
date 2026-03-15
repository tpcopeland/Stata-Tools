*! mlearn Version 1.0.0  2026/03/15
*! Unified machine learning interface for Stata
*! Author: Timothy P Copeland
*! Program class: rclass

/*
Router for mlearn package.

Syntax:
  mlearn y x1 x2, method(forest) [options]        - Train (default)
  mlearn train y x1 x2, method(forest) [options]   - Train (explicit)
  mlearn predict, generate(yhat)                    - Predict
  mlearn cv y x1 x2, method(forest) folds(5)       - Cross-validation
  mlearn tune y x1 x2, method(xgboost) grid(...)   - Hyperparameter tuning
  mlearn importance, plot                           - Feature importance
  mlearn shap, plot                                 - SHAP values
  mlearn compare                                   - Compare stored models
  mlearn setup, check                               - Check dependencies
*/

program define mlearn, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * Parse subcommand
    gettoken subcmd 0 : 0, parse(" ,")

    * No subcommand — show overview
    if "`subcmd'" == "" | "`subcmd'" == "," {
        _mlearn_overview
        set varabbrev `_vaset'
        exit
    }

    * Known subcommands dispatch to mlearn_<subcmd>
    local known_subcmds "train predict cv tune importance shap compare setup"

    local is_subcmd = 0
    foreach s of local known_subcmds {
        if "`subcmd'" == "`s'" local is_subcmd = 1
    }

    if `is_subcmd' {
        mlearn_`subcmd' `0'
    }
    else {
        * Unknown first token — treat as outcome variable, dispatch to train
        * Re-attach subcmd to the front of the argument list
        mlearn_train `subcmd' `0'
    }

    * Pass through return values
    return add

    set varabbrev `_vaset'
end


capture program drop _mlearn_overview
program define _mlearn_overview
    version 16.0

    local version "1.0.0"

    display as text ""
    display as text "{hline 70}"
    display as result "mlearn" as text " - Machine Learning for Stata"
    display as text "Version `version'"
    display as text "{hline 70}"
    display as text ""
    display as text "Training (default):"
    display as text "  {cmd:mlearn} {it:y x1 x2 x3}{cmd:, method(forest)} [{it:options}]"
    display as text ""
    display as text "Subcommands:"
    display as text "  {cmd:mlearn train}       Train a model (explicit)"
    display as text "  {cmd:mlearn predict}     Generate predictions"
    display as text "  {cmd:mlearn cv}          K-fold cross-validation"
    display as text "  {cmd:mlearn tune}        Hyperparameter tuning"
    display as text "  {cmd:mlearn importance}  Feature importance"
    display as text "  {cmd:mlearn shap}        SHAP values"
    display as text "  {cmd:mlearn compare}     Compare stored models"
    display as text "  {cmd:mlearn setup}       Check/install dependencies"
    display as text ""
    display as text "Methods:"
    display as text "  {bf:forest}      Random Forest          {bf:boost}       Gradient Boosting"
    display as text "  {bf:xgboost}     XGBoost                {bf:lightgbm}    LightGBM"
    display as text "  {bf:svm}         Support Vector Machine  {bf:nnet}        Neural Network"
    display as text "  {bf:elasticnet}  ElasticNet / Lasso"
    display as text ""
    display as text "Type {cmd:help mlearn} for full documentation."
    display as text "{hline 70}"
end
