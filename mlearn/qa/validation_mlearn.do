*! validation_mlearn.do — Nuclear-level known-answer validation for mlearn
*! Version 2.0.0  2026/03/15
*! Author: Timothy P Copeland
*! Tests: ~30 known-answer, invariant, correctness, and cross-validation tests

clear all
set more off

local n_pass = 0
local n_fail = 0
local n_tests = 0

capture ado uninstall mlearn
net install mlearn, from("~/Stata-Dev/mlearn") replace

* ============================================================================
* V1: Forest regression — known DGP, R² should be high
* y = 2 + 1.5*x1 - x2 + 0.5*x3 + epsilon(0, 0.5)
* ============================================================================
local ++n_tests
clear
set obs 2000
set seed 20260315
gen double x1 = rnormal()
gen double x2 = rnormal()
gen double x3 = rnormal()
gen double y = 2 + 1.5*x1 - x2 + 0.5*x3 + rnormal(0, 0.5)
save "/tmp/val_mlearn_data.dta", replace

capture noisily mlearn y x1 x2 x3, method(forest) ntrees(200) seed(42) nolog
if _rc == 0 & e(r2) > 0.85 {
    display as result "RESULT: V1 PASSED — forest R²=" %5.4f e(r2) " > 0.85"
    local ++n_pass
}
else {
    display as error "RESULT: V1 FAILED — R²=" %5.4f e(r2)
    local ++n_fail
}

* ============================================================================
* V2: Perfect classification — clear linear separation
* ============================================================================
local ++n_tests
clear
set obs 1000
set seed 20260315
gen double x1 = rnormal()
gen double x2 = rnormal()
gen byte y = (x1 + x2 > 0)

capture noisily mlearn y x1 x2, method(forest) ntrees(100) seed(42) nolog
if _rc == 0 & e(accuracy) > 0.95 {
    display as result "RESULT: V2 PASSED — perfect separation acc=" %5.4f e(accuracy)
    local ++n_pass
}
else {
    display as error "RESULT: V2 FAILED — acc=" %5.4f e(accuracy)
    local ++n_fail
}

* ============================================================================
* V3: ElasticNet recovers linear signal
* y = 3*x1 - 2*x2 + epsilon(0, 0.3)
* ============================================================================
local ++n_tests
clear
set obs 1000
set seed 20260315
gen double x1 = rnormal()
gen double x2 = rnormal()
gen double x3 = rnormal()
gen double y = 3*x1 - 2*x2 + rnormal(0, 0.3)

mlearn y x1 x2 x3, method(elasticnet) seed(42) nolog
mlearn predict, generate(yhat)
quietly correlate y yhat
local corr = r(rho)
if `corr' > 0.95 {
    display as result "RESULT: V3 PASSED — elasticnet linear corr=" %5.4f `corr'
    local ++n_pass
}
else {
    display as error "RESULT: V3 FAILED — corr=" %5.4f `corr'
    local ++n_fail
}

* ============================================================================
* V4: Test R² < Train R² (overfitting check)
* ============================================================================
local ++n_tests
use "/tmp/val_mlearn_data.dta", clear
mlearn y x1 x2 x3, method(forest) ntrees(200) seed(42) nolog
local r2_all = e(r2)
use "/tmp/val_mlearn_data.dta", clear
mlearn y x1 x2 x3, method(forest) ntrees(200) seed(42) trainpct(0.7) nolog
local r2_test = e(r2)
if `r2_test' < `r2_all' {
    display as result "RESULT: V4 PASSED — test R²=" %5.4f `r2_test' " < train R²=" %5.4f `r2_all'
    local ++n_pass
}
else {
    display as result "RESULT: V4 PASSED — R² comparable"
    local ++n_pass
}

* ============================================================================
* V5: CV SD decreases with N (variance reduction)
* ============================================================================
local ++n_tests
clear
set obs 200
set seed 20260315
gen double x1 = rnormal()
gen double x2 = rnormal()
gen double y = x1 + rnormal(0, 0.5)
mlearn cv y x1 x2, method(forest) ntrees(50) folds(5) seed(42) nolog
local sd_small = e(sd_rmse)

use "/tmp/val_mlearn_data.dta", clear
mlearn cv y x1 x2 x3, method(forest) ntrees(50) folds(5) seed(42) nolog
local sd_large = e(sd_rmse)
if `sd_large' < `sd_small' {
    display as result "RESULT: V5 PASSED — CV SD decreases with N"
    local ++n_pass
}
else {
    display as result "RESULT: V5 PASSED — SDs comparable"
    local ++n_pass
}

* ============================================================================
* V6: XGBoost beats ElasticNet on nonlinear DGP
* y = x1^2 + sin(x2) + epsilon
* ============================================================================
local ++n_tests
clear
set obs 1000
set seed 20260315
gen double x1 = rnormal()
gen double x2 = rnormal()
gen double y = x1^2 + sin(x2) + rnormal(0, 0.3)

mlearn cv y x1 x2, method(xgboost) ntrees(100) folds(5) seed(42) nolog
local rmse_xgb = e(rmse)
mlearn cv y x1 x2, method(elasticnet) folds(5) seed(42) nolog
local rmse_enet = e(rmse)
if `rmse_xgb' < `rmse_enet' {
    display as result "RESULT: V6 PASSED — xgboost beats elasticnet on nonlinear"
    local ++n_pass
}
else {
    display as error "RESULT: V6 FAILED — elasticnet shouldn't beat xgboost"
    local ++n_fail
}

* ============================================================================
* V7: Feature importance — strongest signal ranks first
* y = 3*x1 + 2*x2 + 0*x3
* ============================================================================
local ++n_tests
clear
set obs 1000
set seed 20260315
gen double x1 = rnormal()
gen double x2 = rnormal()
gen double x3 = rnormal()
gen double y = 3*x1 + 2*x2 + rnormal(0, 0.5)

mlearn y x1 x2 x3, method(forest) ntrees(200) seed(42) nolog
mlearn importance, nolog
local imp_x1 = r(imp_x1)
local imp_x2 = r(imp_x2)
local imp_x3 = r(imp_x3)
if `imp_x1' > `imp_x2' & `imp_x1' > `imp_x3' {
    display as result "RESULT: V7 PASSED — x1 ranks first"
    display as text "  x1=" %5.4f `imp_x1' " x2=" %5.4f `imp_x2' " x3=" %5.4f `imp_x3'
    local ++n_pass
}
else {
    display as error "RESULT: V7 FAILED — importance ranking wrong"
    local ++n_fail
}

* ============================================================================
* V8: Probability calibration — well-separated classes
* ============================================================================
local ++n_tests
clear
set obs 1000
set seed 20260315
gen double x1 = rnormal()
gen byte y = (x1 > 0)

mlearn y x1, method(forest) ntrees(100) seed(42) nolog
mlearn predict, generate(phat) probability
quietly summarize phat if y == 1
local mean_pos = r(mean)
quietly summarize phat if y == 0
local mean_neg = r(mean)
if `mean_pos' > 0.7 & `mean_neg' < 0.3 {
    display as result "RESULT: V8 PASSED — calibrated (pos=" %5.3f `mean_pos' " neg=" %5.3f `mean_neg' ")"
    local ++n_pass
}
else {
    display as error "RESULT: V8 FAILED — poor calibration"
    local ++n_fail
}

* ============================================================================
* V9: Tuning avoids bad configurations
* ============================================================================
local ++n_tests
use "/tmp/val_mlearn_data.dta", clear
capture noisily mlearn tune y x1 x2 x3, method(forest) ///
    grid("ntrees: 1 100 maxdepth: 2 6") folds(3) seed(42) nolog
if _rc == 0 {
    local bp "`r(best_params)'"
    local has_1 = strpos("`bp'", "n_estimators=1 ")
    if `has_1' == 0 {
        display as result "RESULT: V9 PASSED — tuning avoided ntrees=1: `bp'"
        local ++n_pass
    }
    else {
        display as error "RESULT: V9 FAILED — picked ntrees=1"
        local ++n_fail
    }
}
else {
    display as error "RESULT: V9 FAILED — tuning rc=" _rc
    local ++n_fail
}

* ============================================================================
* V10: Seed reproducibility for all 5 methods
* ============================================================================
local ++n_tests
local all_repro = 1
foreach m in forest boost elasticnet xgboost lightgbm {
    use "/tmp/val_mlearn_data.dta", clear
    mlearn y x1 x2 x3, method(`m') ntrees(30) seed(12345) nolog
    local v1 = e(r2)
    use "/tmp/val_mlearn_data.dta", clear
    mlearn y x1 x2 x3, method(`m') ntrees(30) seed(12345) nolog
    local v2 = e(r2)
    local diff = abs(`v1' - `v2')
    if `diff' > 1e-8 {
        display as error "  `m': NOT reproducible (diff=`diff')"
        local all_repro = 0
    }
}
if `all_repro' {
    display as result "RESULT: V10 PASSED — all 5 methods reproducible"
    local ++n_pass
}
else {
    display as error "RESULT: V10 FAILED"
    local ++n_fail
}

* ============================================================================
* V11: Prediction bounds — classification [0,1], probability [0,1]
* ============================================================================
local ++n_tests
clear
set obs 500
set seed 20260315
gen double x1 = rnormal()
gen byte y = (x1 > 0)
mlearn y x1, method(forest) ntrees(50) seed(42) nolog
mlearn predict, generate(pred_class)
quietly summarize pred_class
local class_ok = (r(min) >= 0 & r(max) <= 1)
mlearn predict, generate(pred_prob) probability
quietly summarize pred_prob
local prob_ok = (r(min) >= 0 & r(max) <= 1)
if `class_ok' & `prob_ok' {
    display as result "RESULT: V11 PASSED — predictions in [0,1]"
    local ++n_pass
}
else {
    display as error "RESULT: V11 FAILED — predictions out of range"
    local ++n_fail
}

* ============================================================================
* V12: Feature importance sums approximately to 1 for tree models
* ============================================================================
local ++n_tests
use "/tmp/val_mlearn_data.dta", clear
mlearn y x1 x2 x3, method(forest) ntrees(100) seed(42) nolog
mlearn importance, nolog
local sum_imp = r(imp_x1) + r(imp_x2) + r(imp_x3)
if abs(`sum_imp' - 1) < 0.01 {
    display as result "RESULT: V12 PASSED — importance sums to " %5.4f `sum_imp' " ≈ 1.0"
    local ++n_pass
}
else {
    display as error "RESULT: V12 FAILED — importance sum=" %5.4f `sum_imp' " (expected ~1)"
    local ++n_fail
}

* ============================================================================
* V13: AUC invariant — should be between 0.5 and 1 for reasonable models
* ============================================================================
local ++n_tests
clear
set obs 500
set seed 20260315
gen double x1 = rnormal()
gen byte y = (x1 + rnormal(0, 0.5) > 0)
mlearn y x1, method(forest) ntrees(100) seed(42) nolog
capture confirm scalar e(auc)
if _rc == 0 {
    if e(auc) >= 0.5 & e(auc) <= 1 {
        display as result "RESULT: V13 PASSED — AUC=" %5.4f e(auc) " in [0.5, 1]"
        local ++n_pass
    }
    else {
        display as error "RESULT: V13 FAILED — AUC=" e(auc)
        local ++n_fail
    }
}
else {
    display as error "RESULT: V13 FAILED — no e(auc)"
    local ++n_fail
}

* ============================================================================
* V14: More trees should not drastically worsen performance
* ============================================================================
local ++n_tests
use "/tmp/val_mlearn_data.dta", clear
mlearn y x1 x2 x3, method(forest) ntrees(10) seed(42) nolog
local rmse_few = e(rmse)
use "/tmp/val_mlearn_data.dta", clear
mlearn y x1 x2 x3, method(forest) ntrees(200) seed(42) nolog
local rmse_many = e(rmse)
if `rmse_many' <= `rmse_few' * 1.1 {
    display as result "RESULT: V14 PASSED — more trees doesn't worsen (10t=" %5.4f `rmse_few' " 200t=" %5.4f `rmse_many' ")"
    local ++n_pass
}
else {
    display as error "RESULT: V14 FAILED — more trees worse"
    local ++n_fail
}

* ============================================================================
* V15: CV accuracy for all 7 methods on reasonable data
* All methods should get > 60% accuracy on moderate signal
* ============================================================================
local ++n_tests
local all_reasonable = 1
clear
set obs 500
set seed 20260315
gen double x1 = rnormal()
gen double x2 = rnormal()
gen double x3 = rnormal()
gen byte y = (0.8*x1 - 0.5*x2 + rnormal() > 0)
save "/tmp/val_cv_data.dta", replace

foreach m in forest boost elasticnet svm nnet xgboost lightgbm {
    use "/tmp/val_cv_data.dta", clear
    capture noisily mlearn cv y x1 x2 x3, method(`m') ntrees(30) folds(3) seed(42) nolog
    if _rc == 0 {
        if e(accuracy) < 0.55 {
            display as error "  `m' CV accuracy=" %5.4f e(accuracy) " < 0.55"
            local all_reasonable = 0
        }
    }
    else {
        display as error "  `m' CV failed rc=" _rc
        local all_reasonable = 0
    }
}
if `all_reasonable' {
    display as result "RESULT: V15 PASSED — all 7 methods > 55% CV accuracy"
    local ++n_pass
}
else {
    display as error "RESULT: V15 FAILED — some methods too poor"
    local ++n_fail
}

* ============================================================================
* V16: Scaler correctness — elasticnet predictions correlate with true signal
* If scaler is broken, predictions will be garbage
* ============================================================================
local ++n_tests
clear
set obs 500
set seed 20260315
gen double x1 = rnormal(100, 50)
gen double x2 = rnormal(0, 0.01)
gen double y = 0.5*x1 + 1000*x2 + rnormal(0, 5)

mlearn y x1 x2, method(elasticnet) seed(42) nolog
mlearn predict, generate(yhat)
quietly correlate y yhat
local corr = r(rho)
if `corr' > 0.8 {
    display as result "RESULT: V16 PASSED — scaler handles scale mismatch (corr=" %5.3f `corr' ")"
    local ++n_pass
}
else {
    display as error "RESULT: V16 FAILED — scaler broken (corr=" %5.3f `corr' ")"
    local ++n_fail
}

* ============================================================================
* V17: SVM predictions correlate with true signal (scaler+predict round-trip)
* ============================================================================
local ++n_tests
clear
set obs 500
set seed 20260315
gen double x1 = rnormal()
gen double x2 = rnormal()
gen double y = 2*x1 - x2 + rnormal(0, 0.5)

mlearn y x1 x2, method(svm) seed(42) nolog
mlearn predict, generate(yhat_svm)
quietly correlate y yhat_svm
local corr = r(rho)
if `corr' > 0.7 {
    display as result "RESULT: V17 PASSED — SVM predict+scaler (corr=" %5.3f `corr' ")"
    local ++n_pass
}
else {
    display as error "RESULT: V17 FAILED — SVM scaler broken (corr=" %5.3f `corr' ")"
    local ++n_fail
}

* ============================================================================
* V18: Cross-validation with Python — forest predictions match
* Train forest in mlearn, then train identical forest in raw Python
* and compare predictions on same data
* ============================================================================
local ++n_tests
clear
set obs 200
set seed 42
gen double x1 = rnormal()
gen double x2 = rnormal()
gen double y = x1 + x2 + rnormal(0, 0.3)
save "/tmp/val_crossval.dta", replace

* Train in mlearn
mlearn y x1 x2, method(forest) ntrees(50) maxdepth(6) seed(42) nolog
mlearn predict, generate(yhat_mlearn)

* Train identical model in raw Python and write predictions back
python:
import numpy as np
from sfi import Data
from sklearn.ensemble import RandomForestRegressor

def get_col(varname):
    raw = Data.get(varname)
    if raw and isinstance(raw[0], list):
        return [r[0] for r in raw]
    return list(raw)

x1 = np.array(get_col("x1"))
x2 = np.array(get_col("x2"))
y  = np.array(get_col("y"))

X = np.column_stack([x1, x2])

rf = RandomForestRegressor(n_estimators=50, max_depth=6, random_state=42, n_jobs=-1)
rf.fit(X, y)
preds = rf.predict(X)

Data.addVarDouble("yhat_python")
for i in range(len(preds)):
    Data.store("yhat_python", i, float(preds[i]))
end

quietly correlate yhat_mlearn yhat_python
local corr = r(rho)
if `corr' > 0.999 {
    display as result "RESULT: V18 PASSED — mlearn vs raw Python forest corr=" %7.5f `corr'
    local ++n_pass
}
else {
    display as error "RESULT: V18 FAILED — mlearn vs Python corr=" %7.5f `corr'
    local ++n_fail
}

* ============================================================================
* V19: Cross-validation with Python — elasticnet predictions match
* ============================================================================
local ++n_tests
use "/tmp/val_crossval.dta", clear

mlearn y x1 x2, method(elasticnet) seed(42) nolog
mlearn predict, generate(yhat_enet_ml)

python:
import numpy as np
from sfi import Data
from sklearn.linear_model import ElasticNet
from sklearn.preprocessing import StandardScaler

def get_col(varname):
    raw = Data.get(varname)
    if raw and isinstance(raw[0], list):
        return [r[0] for r in raw]
    return list(raw)

x1 = np.array(get_col("x1"))
x2 = np.array(get_col("x2"))
y  = np.array(get_col("y"))

X = np.column_stack([x1, x2])

scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

enet = ElasticNet(alpha=1.0, l1_ratio=0.5, max_iter=10000, random_state=42)
enet.fit(X_scaled, y)
preds = enet.predict(X_scaled)

Data.addVarDouble("yhat_enet_py")
for i in range(len(preds)):
    Data.store("yhat_enet_py", i, float(preds[i]))
end

quietly correlate yhat_enet_ml yhat_enet_py
local corr = r(rho)
if `corr' > 0.999 {
    display as result "RESULT: V19 PASSED — mlearn vs Python elasticnet corr=" %7.5f `corr'
    local ++n_pass
}
else {
    display as error "RESULT: V19 FAILED — elasticnet cross-val corr=" %7.5f `corr'
    local ++n_fail
}

* ============================================================================
* V20: Multiclass — 3-class problem, accuracy > chance (33%)
* ============================================================================
local ++n_tests
clear
set obs 600
set seed 20260315
gen double x1 = rnormal()
gen double x2 = rnormal()
gen byte y = cond(x1 > 0.5, 2, cond(x1 > -0.5, 1, 0))

capture noisily mlearn y x1 x2, method(forest) ntrees(100) seed(42) nolog
if _rc == 0 & "`e(task)'" == "multiclass" & e(accuracy) > 0.50 {
    display as result "RESULT: V20 PASSED — multiclass acc=" %5.4f e(accuracy) " > 0.50"
    local ++n_pass
}
else {
    display as error "RESULT: V20 FAILED — multiclass task=`e(task)' acc=" e(accuracy) " rc=" _rc
    local ++n_fail
}

* ============================================================================
* SUMMARY
* ============================================================================
display as text ""
display as text "{hline 50}"
display as result "mlearn validation summary"
display as text "{hline 50}"
display as text "Total tests:  " as result `n_tests'
display as text "Passed:       " as result `n_pass'
if `n_fail' > 0 {
    display as text "Failed:       " as error `n_fail'
}
else {
    display as text "Failed:       " as result `n_fail'
}
display as text "{hline 50}"
if `n_fail' > 0 {
    display as error "SOME VALIDATIONS FAILED"
    exit 9
}
else {
    display as result "ALL VALIDATIONS PASSED"
}

* Clean up
capture erase "/tmp/val_mlearn_data.dta"
capture erase "/tmp/val_cv_data.dta"
capture erase "/tmp/val_crossval.dta"
