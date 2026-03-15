*! _mlearn_validate_method Version 1.0.0  2026/03/15
*! Validate method() option and return canonical name
*! Author: Timothy P Copeland

program define _mlearn_validate_method
    version 16.0
    set varabbrev off
    set more off

    args method

    local method = lower("`method'")

    * Map aliases to canonical names
    if "`method'" == "rf" local method "forest"
    if "`method'" == "randomforest" local method "forest"
    if "`method'" == "random_forest" local method "forest"
    if "`method'" == "gbm" local method "boost"
    if "`method'" == "gradient_boost" local method "boost"
    if "`method'" == "gradientboosting" local method "boost"
    if "`method'" == "xgb" local method "xgboost"
    if "`method'" == "lgbm" local method "lightgbm"
    if "`method'" == "lgb" local method "lightgbm"
    if "`method'" == "nn" local method "nnet"
    if "`method'" == "mlp" local method "nnet"
    if "`method'" == "neuralnet" local method "nnet"
    if "`method'" == "enet" local method "elasticnet"
    if "`method'" == "elastic_net" local method "elasticnet"
    if "`method'" == "lasso" local method "elasticnet"

    * Validate canonical name
    local valid_methods "forest boost xgboost lightgbm svm nnet elasticnet"
    local found = 0
    foreach m of local valid_methods {
        if "`method'" == "`m'" local found = 1
    }

    if `found' == 0 {
        display as error "method(`method') not recognized"
        display as error ""
        display as error "Available methods:"
        display as error "  {bf:forest}      - Random Forest (scikit-learn)"
        display as error "  {bf:boost}       - Gradient Boosting (scikit-learn)"
        display as error "  {bf:xgboost}     - XGBoost"
        display as error "  {bf:lightgbm}    - LightGBM"
        display as error "  {bf:svm}         - Support Vector Machine"
        display as error "  {bf:nnet}        - Neural Network (MLP)"
        display as error "  {bf:elasticnet}  - ElasticNet / Lasso"
        exit 198
    }

    * Return canonical name via c_local
    c_local _mlearn_canonical_method "`method'"

    * Return sklearn module mapping
    local sklearn_methods "forest boost svm nnet elasticnet"
    local is_sklearn = 0
    foreach m of local sklearn_methods {
        if "`method'" == "`m'" local is_sklearn = 1
    }

    c_local _mlearn_engine_module "sklearn"
    if "`method'" == "xgboost" c_local _mlearn_engine_module "xgboost"
    if "`method'" == "lightgbm" c_local _mlearn_engine_module "lightgbm"
end
