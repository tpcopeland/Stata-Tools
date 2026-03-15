*! _mlearn_display Version 1.0.0  2026/03/15
*! Format and display training results table
*! Author: Timothy P Copeland

program define _mlearn_display
    version 16.0
    set varabbrev off
    set more off

    args task method n_obs n_features outcome n_train n_test

    display as text ""
    display as text "{hline 70}"
    display as result "mlearn" as text " - Machine Learning for Stata"
    display as text "{hline 70}"
    display as text ""
    display as text "Method:        " as result "`method'"
    display as text "Task:          " as result "`task'"
    display as text "Outcome:       " as result "`outcome'"
    display as text "Features:      " as result "`n_features'"
    display as text "Observations:  " as result %10.0fc `n_obs'
    if `n_test' > 0 {
        display as text "  Training:    " as result %10.0fc `n_train'
        display as text "  Test:        " as result %10.0fc `n_test'
    }
    display as text ""

    * Display metrics based on task type
    display as text "{hline 40}"
    display as text "Performance Metrics"
    display as text "{hline 40}"

    if "`task'" == "classification" | "`task'" == "multiclass" {
        local acc     = e(accuracy)
        local f1      = e(f1)
        display as text "  Accuracy:    " as result %10.4f `acc'
        display as text "  F1 Score:    " as result %10.4f `f1'
        capture confirm scalar e(auc)
        if _rc == 0 {
            local auc = e(auc)
            display as text "  AUC:         " as result %10.4f `auc'
        }
    }
    else {
        local rmse = e(rmse)
        local mae  = e(mae)
        local r2   = e(r2)
        display as text "  RMSE:        " as result %10.4f `rmse'
        display as text "  MAE:         " as result %10.4f `mae'
        display as text "  R-squared:   " as result %10.4f `r2'
    }
    display as text "{hline 40}"
end
