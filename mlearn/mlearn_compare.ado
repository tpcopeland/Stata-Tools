*! mlearn_compare Version 1.0.0  2026/03/15
*! Compare stored mlearn models
*! Author: Timothy P Copeland
*! Program class: rclass

/*
Syntax:
  mlearn_compare [namelist]

  If namelist is empty, compares all stored estimates.
  Works with estimates stored via `estimates store` after mlearn train or cv.
*/

program define mlearn_compare, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    syntax [anything(name=models)]

    if "`models'" == "" {
        * List all stored estimates
        quietly estimates dir
        local models "`r(names)'"
        if "`models'" == "" {
            display as error "no stored estimates found"
            display as error "Train models and use {bf:estimates store} first"
            set varabbrev `_vaset'
            exit 198
        }
    }

    local n_models : word count `models'
    if `n_models' < 2 {
        display as error "at least 2 stored models required for comparison"
        set varabbrev `_vaset'
        exit 198
    }

    * =========================================================================
    * DISPLAY COMPARISON TABLE
    * =========================================================================
    display as text ""
    display as text "{hline 70}"
    display as result "mlearn" as text " - Model Comparison"
    display as text "{hline 70}"
    display as text ""

    * Use estimates table for the core comparison
    estimates table `models', stats(N n_train n_test folds accuracy auc f1 ///
        rmse mae r2 sd_accuracy sd_rmse) ///
        title("Performance Metrics")

    display as text ""

    * Display method info
    display as text "{hline 50}"
    display as text %16s "Model" as text " {c |}" ///
        as text %16s "Method" as text %16s "Task"
    display as text "{hline 16}{c +}{hline 32}"

    foreach m of local models {
        quietly estimates restore `m'
        local method "`e(method)'"
        local task   "`e(task)'"
        local subcmd "`e(subcmd)'"
        display as text %16s "`m'" as text " {c |}" ///
            as result %16s "`method'" as result %16s "`task'"
    }
    display as text "{hline 50}"

    return scalar n_models = `n_models'
    return local models "`models'"

    set varabbrev `_vaset'
end
