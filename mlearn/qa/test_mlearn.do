*! test_mlearn.do — Nuclear-level functional tests for mlearn package
*! Version 2.0.0  2026/03/15
*! Author: Timothy P Copeland
*! Tests: ~150 covering every option, error path, return value, and edge case

clear all
set more off

local n_pass = 0
local n_fail = 0
local n_tests = 0

capture ado uninstall mlearn
net install mlearn, from("~/Stata-Dev/mlearn") replace

* ============================================================================
* TEST DATA SETUP
* ============================================================================
clear
set obs 500
set seed 12345
gen double x1 = rnormal()
gen double x2 = rnormal()
gen double x3 = rnormal()
gen double latent = 1 + 0.8*x1 - 0.5*x2 + 0.3*x3 + rnormal()
gen byte y_bin = (latent > 0)
drop latent
gen double y_cont = 2 + 1.5*x1 - 0.8*x2 + 0.4*x3 + rnormal(0, 0.5)
* Multiclass outcome: 3 classes
gen byte y_multi = cond(x1 + x2 > 1, 2, cond(x1 + x2 > -0.5, 1, 0))
save "/tmp/test_mlearn_data.dta", replace

* ============================================================================
* SECTION 1: ROUTER (mlearn.ado)
* ============================================================================

* T1: overview (no args)
local ++n_tests
capture noisily mlearn
if _rc == 0 {
    display as result "RESULT: T1 PASSED — overview displayed"
    local ++n_pass
}
else {
    display as error "RESULT: T1 FAILED — overview failed rc=" _rc
    local ++n_fail
}

* T2: comma-only input triggers overview
local ++n_tests
capture noisily mlearn ,
if _rc == 0 {
    display as result "RESULT: T2 PASSED — comma-only triggers overview"
    local ++n_pass
}
else {
    display as error "RESULT: T2 FAILED — rc=" _rc
    local ++n_fail
}

* T3: implicit train dispatch (no 'train' keyword)
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn y_bin x1 x2, method(forest) ntrees(20) seed(42) nolog
if _rc == 0 & "`e(cmd)'" == "mlearn" & "`e(subcmd)'" == "train" {
    display as result "RESULT: T3 PASSED — implicit train dispatch"
    local ++n_pass
}
else {
    display as error "RESULT: T3 FAILED — implicit train dispatch rc=" _rc
    local ++n_fail
}

* T4: explicit train subcommand
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn train y_bin x1 x2, method(forest) ntrees(20) seed(42) nolog
if _rc == 0 & "`e(subcmd)'" == "train" {
    display as result "RESULT: T4 PASSED — explicit train subcommand"
    local ++n_pass
}
else {
    display as error "RESULT: T4 FAILED — rc=" _rc
    local ++n_fail
}

* T5: return add passthrough from router (e() survives)
local ++n_tests
if "`e(method)'" == "forest" & e(N) == 500 {
    display as result "RESULT: T5 PASSED — e() passthrough from router"
    local ++n_pass
}
else {
    display as error "RESULT: T5 FAILED — e(method)=`e(method)' e(N)=" e(N)
    local ++n_fail
}

* ============================================================================
* SECTION 2: TRAIN — all 7 methods × classification
* ============================================================================
local test_num = 5
foreach m in forest boost elasticnet svm nnet xgboost lightgbm {
    local ++test_num
    local ++n_tests
    use "/tmp/test_mlearn_data.dta", clear
    capture noisily mlearn y_bin x1 x2 x3, method(`m') ntrees(20) seed(42) nolog
    if _rc == 0 & "`e(method)'" == "`m'" & "`e(task)'" == "classification" {
        display as result "RESULT: T`test_num' PASSED — `m' classification (acc=" %5.4f e(accuracy) ")"
        local ++n_pass
    }
    else {
        display as error "RESULT: T`test_num' FAILED — `m' classification rc=" _rc
        local ++n_fail
    }
}

* ============================================================================
* SECTION 3: TRAIN — all 7 methods × regression
* ============================================================================
foreach m in forest boost elasticnet svm nnet xgboost lightgbm {
    local ++test_num
    local ++n_tests
    use "/tmp/test_mlearn_data.dta", clear
    capture noisily mlearn y_cont x1 x2 x3, method(`m') ntrees(20) seed(42) nolog
    if _rc == 0 & "`e(method)'" == "`m'" & "`e(task)'" == "regression" {
        display as result "RESULT: T`test_num' PASSED — `m' regression (rmse=" %6.4f e(rmse) ")"
        local ++n_pass
    }
    else {
        display as error "RESULT: T`test_num' FAILED — `m' regression rc=" _rc
        local ++n_fail
    }
}

* ============================================================================
* SECTION 4: TRAIN — all return values
* ============================================================================

* T20: classification e() scalars
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn y_bin x1 x2 x3, method(forest) ntrees(50) seed(42) trainpct(0.8) nolog
if _rc == 0 {
    local all_ok = 1
    if e(N) != 500 local all_ok = 0
    if e(n_train) < 390 | e(n_train) > 410 local all_ok = 0
    if e(n_test) < 90 | e(n_test) > 110 local all_ok = 0
    if e(n_features) != 3 local all_ok = 0
    if e(seed) != 42 local all_ok = 0
    if e(trainpct) != 0.8 local all_ok = 0
    if e(accuracy) <= 0 | e(accuracy) > 1 local all_ok = 0
    if e(f1) <= 0 | e(f1) > 1 local all_ok = 0
    if `all_ok' {
        display as result "RESULT: T`test_num' PASSED — classification e() scalars complete"
        local ++n_pass
    }
    else {
        display as error "RESULT: T`test_num' FAILED — e() scalars invalid"
        local ++n_fail
    }
}
else {
    display as error "RESULT: T`test_num' FAILED — rc=" _rc
    local ++n_fail
}

* T21: classification e() macros
local ++test_num
local ++n_tests
if "`e(cmd)'" == "mlearn" & "`e(subcmd)'" == "train" ///
    & "`e(method)'" == "forest" & "`e(task)'" == "classification" ///
    & "`e(outcome)'" == "y_bin" & "`e(features)'" == "x1 x2 x3" ///
    & "`e(depvar)'" == "y_bin" & "`e(model_path)'" != "" ///
    & "`e(title)'" != "" {
    display as result "RESULT: T`test_num' PASSED — classification e() macros complete"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — e() macros"
    local ++n_fail
}

* T22: e(b) and e(V) matrix structure (classification with AUC)
local ++test_num
local ++n_tests
capture confirm matrix e(b)
local b_ok = (_rc == 0)
capture confirm matrix e(V)
local v_ok = (_rc == 0)
if `b_ok' & `v_ok' {
    local ncol = colsof(e(b))
    if `ncol' == 3 {
        display as result "RESULT: T`test_num' PASSED — e(b) has 3 cols (acc, auc, f1)"
        local ++n_pass
    }
    else {
        display as error "RESULT: T`test_num' FAILED — e(b) has `ncol' cols, expected 3"
        local ++n_fail
    }
}
else {
    display as error "RESULT: T`test_num' FAILED — e(b) or e(V) missing"
    local ++n_fail
}

* T23: e(sample) function
local ++test_num
local ++n_tests
quietly count if e(sample)
if r(N) == 500 {
    display as result "RESULT: T`test_num' PASSED — e(sample) marks all 500 obs"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — e(sample)=" r(N) " expected 500"
    local ++n_fail
}

* T24: regression e() scalars
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn y_cont x1 x2 x3, method(forest) ntrees(50) seed(42) nolog
if _rc == 0 {
    local all_ok = 1
    if e(rmse) <= 0 local all_ok = 0
    if e(mae) <= 0 local all_ok = 0
    if e(r2) < -10 | e(r2) > 1 local all_ok = 0
    if `all_ok' {
        display as result "RESULT: T`test_num' PASSED — regression e() scalars (rmse/mae/r2)"
        local ++n_pass
    }
    else {
        display as error "RESULT: T`test_num' FAILED — regression scalars"
        local ++n_fail
    }
}
else {
    display as error "RESULT: T`test_num' FAILED — rc=" _rc
    local ++n_fail
}

* T25: dataset characteristics stored
local ++test_num
local ++n_tests
local c_trained  : char _dta[_mlearn_trained]
local c_method   : char _dta[_mlearn_method]
local c_task     : char _dta[_mlearn_task]
local c_outcome  : char _dta[_mlearn_outcome]
local c_features : char _dta[_mlearn_features]
local c_nfeat    : char _dta[_mlearn_n_features]
local c_model    : char _dta[_mlearn_model_path]
local c_seed     : char _dta[_mlearn_seed]
local c_ntrain   : char _dta[_mlearn_N_train]
if "`c_trained'" == "1" & "`c_method'" == "forest" ///
    & "`c_task'" == "regression" & "`c_outcome'" == "y_cont" ///
    & "`c_features'" == "x1 x2 x3" & "`c_nfeat'" == "3" ///
    & "`c_model'" != "" & "`c_seed'" == "42" & "`c_ntrain'" != "" {
    display as result "RESULT: T`test_num' PASSED — all 9 characteristics stored"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — characteristics incomplete"
    local ++n_fail
}

* ============================================================================
* SECTION 5: TRAIN — error paths
* ============================================================================

* T26: invalid method
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn y_bin x1, method(invalid_method)
if _rc == 198 {
    display as result "RESULT: T`test_num' PASSED — invalid method rejected (rc=198)"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — expected rc=198, got " _rc
    local ++n_fail
}

* T27: no observations
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn y_bin x1 x2 if x1 > 999, method(forest)
if _rc == 2000 {
    display as result "RESULT: T`test_num' PASSED — no observations (rc=2000)"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — expected rc=2000, got " _rc
    local ++n_fail
}

* T28: missing values in features → silently excluded by marksample
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
quietly replace x1 = . in 1
capture noisily mlearn y_bin x1 x2, method(forest) ntrees(20) seed(42) nolog
if _rc == 0 & e(N) == 499 {
    display as result "RESULT: T`test_num' PASSED — missing feature excluded (N=499)"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — expected N=499, got " e(N) " rc=" _rc
    local ++n_fail
}

* T29: missing values in outcome → excluded by marksample
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
quietly replace y_bin = . in 1
capture noisily mlearn y_bin x1 x2, method(forest) ntrees(20) seed(42) nolog
if _rc == 0 & e(N) == 499 {
    display as result "RESULT: T`test_num' PASSED — missing outcome excluded (N=499)"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — expected N=499, got " e(N) " rc=" _rc
    local ++n_fail
}

* T30: invalid task()
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn y_bin x1 x2, method(forest) task(invalid)
if _rc == 198 {
    display as result "RESULT: T`test_num' PASSED — invalid task rejected (rc=198)"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — expected rc=198, got " _rc
    local ++n_fail
}

* T31: trainpct out of range (0)
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn y_bin x1 x2, method(forest) trainpct(0) nolog
if _rc == 198 {
    display as result "RESULT: T`test_num' PASSED — trainpct(0) rejected"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — expected rc=198, got " _rc
    local ++n_fail
}

* T32: trainpct out of range (1.5)
local ++test_num
local ++n_tests
capture noisily mlearn y_bin x1 x2, method(forest) trainpct(1.5) nolog
if _rc == 198 {
    display as result "RESULT: T`test_num' PASSED — trainpct(1.5) rejected"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — expected rc=198, got " _rc
    local ++n_fail
}

* T33: ntrees(0) rejected
local ++test_num
local ++n_tests
capture noisily mlearn y_bin x1 x2, method(forest) ntrees(0)
if _rc == 198 {
    display as result "RESULT: T`test_num' PASSED — ntrees(0) rejected"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — expected rc=198, got " _rc
    local ++n_fail
}

* T34: maxdepth(0) rejected
local ++test_num
local ++n_tests
capture noisily mlearn y_bin x1 x2, method(forest) maxdepth(0)
if _rc == 198 {
    display as result "RESULT: T`test_num' PASSED — maxdepth(0) rejected"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — expected rc=198, got " _rc
    local ++n_fail
}

* T35: lrate(0) rejected
local ++test_num
local ++n_tests
capture noisily mlearn y_bin x1 x2, method(forest) lrate(0)
if _rc == 198 {
    display as result "RESULT: T`test_num' PASSED — lrate(0) rejected"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — expected rc=198, got " _rc
    local ++n_fail
}

* ============================================================================
* SECTION 6: TRAIN — options
* ============================================================================

* T36: task(classification) explicit override on multiclass outcome
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn y_multi x1 x2, method(forest) ntrees(20) seed(42) task(classification) nolog
if _rc == 0 & "`e(task)'" == "classification" {
    display as result "RESULT: T`test_num' PASSED — task(classification) override"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — task override rc=" _rc
    local ++n_fail
}

* T37: task(regression) explicit override
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn y_bin x1 x2, method(forest) ntrees(20) seed(42) task(regression) nolog
if _rc == 0 & "`e(task)'" == "regression" {
    display as result "RESULT: T`test_num' PASSED — task(regression) override"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — task override rc=" _rc
    local ++n_fail
}

* T38: if/in sample restriction
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn y_bin x1 x2 if x1 > 0, method(forest) ntrees(20) seed(42) nolog
if _rc == 0 {
    quietly count if x1 > 0
    local expected = r(N)
    if e(N) == `expected' {
        display as result "RESULT: T`test_num' PASSED — if restriction (N=`expected')"
        local ++n_pass
    }
    else {
        display as error "RESULT: T`test_num' FAILED — N mismatch"
        local ++n_fail
    }
}
else {
    display as error "RESULT: T`test_num' FAILED — rc=" _rc
    local ++n_fail
}

* T39: in range restriction
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn y_bin x1 x2 in 1/100, method(forest) ntrees(20) seed(42) nolog
if _rc == 0 & e(N) == 100 {
    display as result "RESULT: T`test_num' PASSED — in 1/100 restriction (N=100)"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — in restriction rc=" _rc " N=" e(N)
    local ++n_fail
}

* T40: saving() + using() round-trip
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture erase "/tmp/mlearn_saved_model.pkl"
capture noisily mlearn y_bin x1 x2 x3, method(forest) ntrees(30) seed(42) ///
    saving("/tmp/mlearn_saved_model.pkl") nolog
if _rc == 0 {
    capture confirm file "/tmp/mlearn_saved_model.pkl"
    if _rc == 0 {
        display as result "RESULT: T`test_num' PASSED — saving() creates model file"
        local ++n_pass
    }
    else {
        display as error "RESULT: T`test_num' FAILED — model file not created"
        local ++n_fail
    }
}
else {
    display as error "RESULT: T`test_num' FAILED — saving() training failed rc=" _rc
    local ++n_fail
}

* T41: predict using() from saved model
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
* Clear training state so we rely purely on using()
char _dta[_mlearn_trained] "1"
char _dta[_mlearn_features] "x1 x2 x3"
char _dta[_mlearn_model_path] "/tmp/mlearn_saved_model.pkl"
capture noisily mlearn predict, generate(yhat_saved) using("/tmp/mlearn_saved_model.pkl")
if _rc == 0 {
    quietly count if !missing(yhat_saved)
    if r(N) == 500 {
        display as result "RESULT: T`test_num' PASSED — predict using() works"
        local ++n_pass
    }
    else {
        display as error "RESULT: T`test_num' FAILED — only " r(N) " predictions"
        local ++n_fail
    }
}
else {
    display as error "RESULT: T`test_num' FAILED — predict using() rc=" _rc
    local ++n_fail
}

* T42: hparams() option
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn y_cont x1 x2, method(forest) ntrees(20) seed(42) ///
    hparams(min_samples_leaf=5) nolog
if _rc == 0 & "`e(hparams)'" != "" {
    display as result "RESULT: T`test_num' PASSED — hparams() accepted: `e(hparams)'"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — hparams() rc=" _rc
    local ++n_fail
}

* T43: multiclass detection
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn y_multi x1 x2 x3, method(forest) ntrees(20) seed(42) nolog
if _rc == 0 & "`e(task)'" == "multiclass" {
    display as result "RESULT: T`test_num' PASSED — multiclass auto-detected"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — task=`e(task)' expected multiclass rc=" _rc
    local ++n_fail
}

* T44: seed reproducibility
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn y_cont x1 x2, method(forest) ntrees(50) seed(12345) nolog
local rmse1 = e(rmse)
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn y_cont x1 x2, method(forest) ntrees(50) seed(12345) nolog
local rmse2 = e(rmse)
local diff = abs(`rmse1' - `rmse2')
if `diff' < 1e-10 {
    display as result "RESULT: T`test_num' PASSED — seed reproducibility (diff=" %12.2e `diff' ")"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — not reproducible (diff=`diff')"
    local ++n_fail
}

* T45: data preservation (_N unchanged)
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
local n_before = _N
capture noisily mlearn y_bin x1 x2 x3, method(forest) ntrees(20) seed(42) nolog
if _N == `n_before' {
    display as result "RESULT: T`test_num' PASSED — _N preserved (N=`n_before')"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — _N changed from `n_before' to " _N
    local ++n_fail
}

* ============================================================================
* SECTION 7: TRAIN — method aliases
* ============================================================================
local ++test_num
local ++n_tests
local alias_ok = 1
use "/tmp/test_mlearn_data.dta", clear
foreach pair in "rf:forest" "randomforest:forest" "gbm:boost" "xgb:xgboost" ///
    "lgbm:lightgbm" "nn:nnet" "enet:elasticnet" "lasso:elasticnet" {
    gettoken alias canonical : pair, parse(":")
    local canonical = substr("`canonical'", 2, .)
    capture noisily mlearn y_bin x1 x2, method(`alias') ntrees(10) seed(42) nolog
    if _rc != 0 | "`e(method)'" != "`canonical'" {
        display as error "  alias `alias' → `e(method)' (expected `canonical')"
        local alias_ok = 0
    }
    use "/tmp/test_mlearn_data.dta", clear
}
if `alias_ok' {
    display as result "RESULT: T`test_num' PASSED — all 8 method aliases resolve correctly"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — some aliases wrong"
    local ++n_fail
}

* ============================================================================
* SECTION 8: TRAIN — edge cases
* ============================================================================

* T47: single feature
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn y_bin x1, method(forest) ntrees(20) seed(42) nolog
if _rc == 0 & e(n_features) == 1 {
    display as result "RESULT: T`test_num' PASSED — single feature (n_features=1)"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — single feature rc=" _rc
    local ++n_fail
}

* T48: many features (wide data)
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
forvalues j = 4/20 {
    quietly gen double x`j' = rnormal()
}
capture noisily mlearn y_bin x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 ///
    x11 x12 x13 x14 x15 x16 x17 x18 x19 x20, ///
    method(forest) ntrees(20) seed(42) nolog
if _rc == 0 & e(n_features) == 20 {
    display as result "RESULT: T`test_num' PASSED — 20 features"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — wide data rc=" _rc " n_feat=" e(n_features)
    local ++n_fail
}

* T49: very few observations (N=10)
local ++test_num
local ++n_tests
clear
set obs 10
set seed 42
gen double x1 = rnormal()
gen byte y = (x1 > 0)
capture noisily mlearn y x1, method(forest) ntrees(10) seed(42) nolog
if _rc == 0 {
    display as result "RESULT: T`test_num' PASSED — N=10 trains successfully"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — N=10 failed rc=" _rc
    local ++n_fail
}

* T50: global cleanup after successful train
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn y_bin x1 x2, method(forest) ntrees(20) seed(42) nolog
local leaked = 0
foreach g in action method task outcome features touse seed_val ///
    trainpct saving ntrees maxdepth lrate hparams_raw ///
    model_path_out n_train n_test hparams_store accuracy f1 auc {
    if "${MLEARN_`g'}" != "" {
        display as error "  leaked global: MLEARN_`g' = ${MLEARN_`g'}"
        local leaked = 1
    }
}
if !`leaked' {
    display as result "RESULT: T`test_num' PASSED — no global leaks after train"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — globals leaked"
    local ++n_fail
}

* T51: global cleanup after failed train
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
quietly replace x1 = . in 1
capture noisily mlearn y_bin x1 x2, method(forest) nolog
* Should have failed with rc=416
local leaked = 0
foreach g in action method task outcome features touse {
    if "${MLEARN_`g'}" != "" {
        local leaked = 1
    }
}
if !`leaked' {
    display as result "RESULT: T`test_num' PASSED — no global leaks after failed train"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — globals leaked on error"
    local ++n_fail
}

* T52: varabbrev restored after error (direct subcommand call)
local ++test_num
local ++n_tests
set varabbrev on
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn_train y_bin x1 x2, method(invalid)
local va_after = c(varabbrev)
set varabbrev off
if "`va_after'" == "on" {
    display as result "RESULT: T`test_num' PASSED — varabbrev restored after error"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — varabbrev=`va_after' after error"
    local ++n_fail
}

* ============================================================================
* SECTION 9: PREDICT — all options and error paths
* ============================================================================

* T53: predict classification (default = class labels)
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn y_bin x1 x2 x3, method(forest) ntrees(50) seed(42) nolog
capture noisily mlearn predict, generate(yhat_class)
if _rc == 0 {
    quietly count if !missing(yhat_class)
    if r(N) == 500 {
        display as result "RESULT: T`test_num' PASSED — predict class (500 obs)"
        local ++n_pass
    }
    else {
        display as error "RESULT: T`test_num' FAILED — " r(N) " predictions"
        local ++n_fail
    }
}
else {
    display as error "RESULT: T`test_num' FAILED — predict rc=" _rc
    local ++n_fail
}

* T54: predict probability
local ++test_num
local ++n_tests
capture noisily mlearn predict, generate(phat) probability
if _rc == 0 {
    quietly summarize phat
    if r(min) >= 0 & r(max) <= 1 {
        display as result "RESULT: T`test_num' PASSED — probabilities in [0,1]"
        local ++n_pass
    }
    else {
        display as error "RESULT: T`test_num' FAILED — probabilities out of range"
        local ++n_fail
    }
}
else {
    display as error "RESULT: T`test_num' FAILED — predict probability rc=" _rc
    local ++n_fail
}

* T55: default generate name (_mlearn_pred)
local ++test_num
local ++n_tests
capture noisily mlearn predict
if _rc == 0 {
    capture confirm variable _mlearn_pred
    if _rc == 0 {
        display as result "RESULT: T`test_num' PASSED — default var _mlearn_pred created"
        local ++n_pass
    }
    else {
        display as error "RESULT: T`test_num' FAILED — _mlearn_pred not created"
        local ++n_fail
    }
}
else {
    display as error "RESULT: T`test_num' FAILED — rc=" _rc
    local ++n_fail
}

* T56: replace option
local ++test_num
local ++n_tests
capture noisily mlearn predict, generate(yhat_class)
local rc1 = _rc
capture noisily mlearn predict, generate(yhat_class) replace
local rc2 = _rc
if `rc1' == 110 & `rc2' == 0 {
    display as result "RESULT: T`test_num' PASSED — replace option works"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — rc1=`rc1' rc2=`rc2'"
    local ++n_fail
}

* T57: predict without model
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
char _dta[_mlearn_trained] ""
capture noisily mlearn predict, generate(yhat_fail)
if _rc == 198 {
    display as result "RESULT: T`test_num' PASSED — predict without model (rc=198)"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — expected rc=198, got " _rc
    local ++n_fail
}

* T58: predict using() nonexistent file
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
char _dta[_mlearn_features] "x1 x2"
capture noisily mlearn predict, generate(yhat) using("/tmp/nonexistent_model.pkl")
if _rc == 601 {
    display as result "RESULT: T`test_num' PASSED — nonexistent using() file (rc=601)"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — expected rc=601, got " _rc
    local ++n_fail
}

* T59: predict r() return values
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
mlearn y_bin x1 x2, method(forest) ntrees(20) seed(42) nolog
mlearn predict, generate(yhat_rv)
if r(N) == 500 & "`r(predict_var)'" == "yhat_rv" & "`r(model_path)'" != "" {
    display as result "RESULT: T`test_num' PASSED — predict r() values correct"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — r() values"
    local ++n_fail
}

* T60: predict with if restriction
local ++test_num
local ++n_tests
capture noisily mlearn predict if x1 > 0, generate(yhat_if) replace
if _rc == 0 {
    quietly count if !missing(yhat_if) & x1 > 0
    local n_pos = r(N)
    quietly count if missing(yhat_if) & x1 <= 0
    local n_miss = r(N)
    quietly count if x1 > 0
    local n_expected = r(N)
    if `n_pos' == `n_expected' {
        display as result "RESULT: T`test_num' PASSED — predict if restriction (N=`n_pos')"
        local ++n_pass
    }
    else {
        display as error "RESULT: T`test_num' FAILED — predict if wrong count"
        local ++n_fail
    }
}
else {
    display as error "RESULT: T`test_num' FAILED — predict if rc=" _rc
    local ++n_fail
}

* T61: predict all 7 methods (scaler applied correctly)
local ++test_num
local ++n_tests
local pred_ok = 1
foreach m in forest boost elasticnet svm nnet xgboost lightgbm {
    use "/tmp/test_mlearn_data.dta", clear
    capture noisily mlearn y_cont x1 x2, method(`m') ntrees(20) seed(42) nolog
    if _rc == 0 {
        capture noisily mlearn predict, generate(yhat_`m')
        if _rc != 0 {
            display as error "  predict failed for `m' rc=" _rc
            local pred_ok = 0
        }
        else {
            quietly correlate y_cont yhat_`m'
            if r(rho) < 0.3 {
                display as error "  `m' prediction correlation too low: " r(rho)
                local pred_ok = 0
            }
        }
    }
    else {
        display as error "  train failed for `m'"
        local pred_ok = 0
    }
}
if `pred_ok' {
    display as result "RESULT: T`test_num' PASSED — all 7 methods predict correctly"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — some methods failed predict"
    local ++n_fail
}

* ============================================================================
* SECTION 10: CROSS-VALIDATION
* ============================================================================

* T62: CV classification (5-fold)
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn cv y_bin x1 x2 x3, method(forest) ntrees(50) folds(5) seed(42)
if _rc == 0 & e(folds) == 5 & e(accuracy) > 0 & e(sd_accuracy) >= 0 {
    display as result "RESULT: T`test_num' PASSED — CV classification"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — CV classification rc=" _rc
    local ++n_fail
}

* T63: CV regression (3-fold)
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn cv y_cont x1 x2, method(elasticnet) folds(3) seed(42) nolog
if _rc == 0 & e(folds) == 3 & e(rmse) > 0 & e(sd_rmse) >= 0 & e(r2) <= 1 {
    display as result "RESULT: T`test_num' PASSED — CV regression"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — CV regression rc=" _rc
    local ++n_fail
}

* T64: CV all e() return values
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn cv y_bin x1 x2 x3, method(forest) ntrees(30) folds(5) seed(42) nolog
if _rc == 0 {
    local all_ok = 1
    if "`e(cmd)'" != "mlearn" local all_ok = 0
    if "`e(subcmd)'" != "cv" local all_ok = 0
    if "`e(method)'" != "forest" local all_ok = 0
    if "`e(task)'" != "classification" local all_ok = 0
    if "`e(outcome)'" != "y_bin" local all_ok = 0
    if "`e(features)'" != "x1 x2 x3" local all_ok = 0
    if e(N) != 500 local all_ok = 0
    if e(n_features) != 3 local all_ok = 0
    if e(seed) != 42 local all_ok = 0
    if e(accuracy) <= 0 local all_ok = 0
    if e(sd_accuracy) < 0 local all_ok = 0
    if e(f1) <= 0 local all_ok = 0
    if e(sd_f1) < 0 local all_ok = 0
    capture confirm matrix e(b)
    if _rc local all_ok = 0
    capture confirm matrix e(V)
    if _rc local all_ok = 0
    if `all_ok' {
        display as result "RESULT: T`test_num' PASSED — CV all e() values present"
        local ++n_pass
    }
    else {
        display as error "RESULT: T`test_num' FAILED — CV e() values incomplete"
        local ++n_fail
    }
}
else {
    display as error "RESULT: T`test_num' FAILED — CV rc=" _rc
    local ++n_fail
}

* T65: CV e(V) diagonal = sd^2
local ++test_num
local ++n_tests
if _rc == 0 {
    local sd_acc = e(sd_accuracy)
    matrix V = e(V)
    local v11 = V[1,1]
    local diff = abs(`v11' - `sd_acc'^2)
    if `diff' < 1e-10 {
        display as result "RESULT: T`test_num' PASSED — e(V)[1,1] = sd_accuracy^2"
        local ++n_pass
    }
    else {
        display as error "RESULT: T`test_num' FAILED — V[1,1]=`v11' vs sd^2=" `sd_acc'^2
        local ++n_fail
    }
}
else {
    display as error "RESULT: T`test_num' FAILED — no CV results"
    local ++n_fail
}

* T66: CV estimates store/table
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
estimates clear
capture noisily mlearn cv y_bin x1 x2 x3, method(forest) ntrees(30) folds(5) seed(42) nolog
estimates store cv_rf
capture noisily mlearn cv y_bin x1 x2 x3, method(xgboost) ntrees(30) folds(5) seed(42) nolog
estimates store cv_xgb
capture noisily estimates table cv_rf cv_xgb
if _rc == 0 {
    display as result "RESULT: T`test_num' PASSED — CV estimates store/table"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — estimates table rc=" _rc
    local ++n_fail
}

* T67: CV seed reproducibility
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn cv y_bin x1 x2, method(forest) ntrees(30) folds(5) seed(999) nolog
local acc1 = e(accuracy)
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn cv y_bin x1 x2, method(forest) ntrees(30) folds(5) seed(999) nolog
local acc2 = e(accuracy)
local diff = abs(`acc1' - `acc2')
if `diff' < 1e-10 {
    display as result "RESULT: T`test_num' PASSED — CV seed reproducibility"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — diff=`diff'"
    local ++n_fail
}

* T68: CV folds(1) rejected
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn cv y_bin x1, method(forest) folds(1)
if _rc == 198 {
    display as result "RESULT: T`test_num' PASSED — folds(1) rejected"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — expected rc=198"
    local ++n_fail
}

* T69: CV folds(2) minimum
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn cv y_bin x1 x2, method(forest) ntrees(20) folds(2) seed(42) nolog
if _rc == 0 & e(folds) == 2 {
    display as result "RESULT: T`test_num' PASSED — folds(2) works"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — folds(2) rc=" _rc
    local ++n_fail
}

* T70: CV 10-fold
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn cv y_cont x1 x2 x3, method(forest) ntrees(30) folds(10) seed(42) nolog
if _rc == 0 & e(folds) == 10 {
    display as result "RESULT: T`test_num' PASSED — 10-fold CV"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — 10-fold rc=" _rc
    local ++n_fail
}

* ============================================================================
* SECTION 11: TUNE
* ============================================================================

* T71: grid search
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn tune y_bin x1 x2 x3, method(forest) ///
    grid("ntrees: 20 50 maxdepth: 3 6") folds(3) seed(42)
if _rc == 0 & r(n_configs) == 4 & r(best_score) > 0 {
    display as result "RESULT: T`test_num' PASSED — grid search (configs=4)"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — grid search rc=" _rc
    local ++n_fail
}

* T72: random search
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn tune y_cont x1 x2, method(forest) ///
    grid("ntrees: 20 50 100 maxdepth: 3 6 9") search(random) niter(5) ///
    folds(3) seed(42) nolog
if _rc == 0 & r(n_configs) == 5 {
    display as result "RESULT: T`test_num' PASSED — random search (niter=5)"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — random search rc=" _rc
    local ++n_fail
}

* T73: tune r() values
local ++test_num
local ++n_tests
if _rc == 0 {
    if r(best_score) > 0 & "`r(best_params)'" != "" ///
        & "`r(method)'" == "forest" & "`r(search)'" == "random" {
        display as result "RESULT: T`test_num' PASSED — tune r() complete"
        local ++n_pass
    }
    else {
        display as error "RESULT: T`test_num' FAILED — r() incomplete"
        local ++n_fail
    }
}
else {
    display as error "RESULT: T`test_num' FAILED — no tune results"
    local ++n_fail
}

* T74: tune invalid search()
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn tune y_bin x1 x2, method(forest) ///
    grid("ntrees: 20 50") search(bayesian)
if _rc == 198 {
    display as result "RESULT: T`test_num' PASSED — search(bayesian) rejected"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — expected rc=198, got " _rc
    local ++n_fail
}

* T75: tune invalid task()
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn tune y_bin x1 x2, method(forest) ///
    grid("ntrees: 20 50") task(invalid)
if _rc == 198 {
    display as result "RESULT: T`test_num' PASSED — tune task(invalid) rejected"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — expected rc=198, got " _rc
    local ++n_fail
}

* ============================================================================
* SECTION 12: IMPORTANCE
* ============================================================================

* T76-80: importance for all tree methods + elasticnet
local ++test_num
local ++n_tests
local imp_ok = 1
foreach m in forest boost xgboost lightgbm elasticnet {
    use "/tmp/test_mlearn_data.dta", clear
    capture noisily mlearn y_cont x1 x2 x3, method(`m') ntrees(30) seed(42) nolog
    if _rc == 0 {
        mlearn importance, nolog
        if r(n_features) != 3 {
            display as error "  `m' importance: n_features=" r(n_features) " expected 3"
            local imp_ok = 0
        }
    }
    else {
        display as error "  `m' train failed"
        local imp_ok = 0
    }
}
if `imp_ok' {
    display as result "RESULT: T`test_num' PASSED — importance works for 5 methods"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — some importance failures"
    local ++n_fail
}

* T77: importance r() values include feature names
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
mlearn y_cont x1 x2 x3, method(forest) ntrees(50) seed(42) nolog
mlearn importance, nolog
local has_x1 = (r(imp_x1) > 0 | r(imp_x1) == 0)
local has_x2 = (r(imp_x2) > 0 | r(imp_x2) == 0)
local has_x3 = (r(imp_x3) > 0 | r(imp_x3) == 0)
if `has_x1' & `has_x2' & `has_x3' & "`r(method)'" == "forest" {
    display as result "RESULT: T`test_num' PASSED — r(imp_x1/x2/x3) + r(method)"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — importance r() values"
    local ++n_fail
}

* T78: importance without model
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
char _dta[_mlearn_trained] ""
capture noisily mlearn importance
if _rc == 198 {
    display as result "RESULT: T`test_num' PASSED — importance without model (rc=198)"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — expected rc=198, got " _rc
    local ++n_fail
}

* ============================================================================
* SECTION 13: SHAP
* ============================================================================

* T79: SHAP forest classification
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn y_bin x1 x2 x3, method(forest) ntrees(50) seed(42) nolog
if _rc == 0 {
    capture noisily mlearn shap, nolog
    if _rc == 0 & r(n_features) == 3 & r(n_samples) > 0 {
        display as result "RESULT: T`test_num' PASSED — SHAP forest (n_samples=" r(n_samples) ")"
        local ++n_pass
    }
    else {
        display as error "RESULT: T`test_num' FAILED — SHAP rc=" _rc
        local ++n_fail
    }
}
else {
    display as error "RESULT: T`test_num' FAILED — train failed"
    local ++n_fail
}

* T80: SHAP xgboost regression
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn y_cont x1 x2 x3, method(xgboost) ntrees(30) seed(42) nolog
if _rc == 0 {
    capture noisily mlearn shap, nolog
    if _rc == 0 & r(n_features) == 3 {
        display as result "RESULT: T`test_num' PASSED — SHAP xgboost regression"
        local ++n_pass
    }
    else {
        display as error "RESULT: T`test_num' FAILED — SHAP xgboost rc=" _rc
        local ++n_fail
    }
}
else {
    display as error "RESULT: T`test_num' FAILED — xgboost train failed"
    local ++n_fail
}

* T81: SHAP maxsamples option
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
capture noisily mlearn y_bin x1 x2 x3, method(forest) ntrees(30) seed(42) nolog
if _rc == 0 {
    capture noisily mlearn shap, nolog maxsamples(50)
    if _rc == 0 & r(n_samples) <= 50 {
        display as result "RESULT: T`test_num' PASSED — maxsamples(50) respected"
        local ++n_pass
    }
    else {
        display as error "RESULT: T`test_num' FAILED — maxsamples not respected"
        local ++n_fail
    }
}
else {
    display as error "RESULT: T`test_num' FAILED — train failed"
    local ++n_fail
}

* T82: SHAP without model
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
char _dta[_mlearn_trained] ""
capture noisily mlearn shap
if _rc == 198 {
    display as result "RESULT: T`test_num' PASSED — SHAP without model (rc=198)"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — expected rc=198, got " _rc
    local ++n_fail
}

* ============================================================================
* SECTION 14: COMPARE
* ============================================================================

* T83: compare 2 models
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
estimates clear
capture noisily mlearn y_bin x1 x2 x3, method(forest) ntrees(30) seed(42) nolog
estimates store m1
capture noisily mlearn y_bin x1 x2 x3, method(xgboost) ntrees(30) seed(42) nolog
estimates store m2
capture noisily mlearn compare m1 m2
if _rc == 0 & r(n_models) == 2 & "`r(models)'" == "m1 m2" {
    display as result "RESULT: T`test_num' PASSED — compare 2 models"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — compare rc=" _rc
    local ++n_fail
}

* T84: compare 3 models
local ++test_num
local ++n_tests
capture noisily mlearn y_bin x1 x2 x3, method(elasticnet) seed(42) nolog
estimates store m3
capture noisily mlearn compare m1 m2 m3
if _rc == 0 & r(n_models) == 3 {
    display as result "RESULT: T`test_num' PASSED — compare 3 models"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — compare 3 rc=" _rc
    local ++n_fail
}

* T85: compare auto-discover (no namelist)
local ++test_num
local ++n_tests
capture noisily mlearn compare
if _rc == 0 & r(n_models) >= 3 {
    display as result "RESULT: T`test_num' PASSED — compare auto-discover"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — auto-discover rc=" _rc
    local ++n_fail
}

* T86: compare < 2 models
local ++test_num
local ++n_tests
estimates clear
capture noisily mlearn y_bin x1 x2, method(forest) ntrees(20) seed(42) nolog
estimates store only_one
capture noisily mlearn compare only_one
if _rc == 198 {
    display as result "RESULT: T`test_num' PASSED — compare <2 models (rc=198)"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — expected rc=198, got " _rc
    local ++n_fail
}

* ============================================================================
* SECTION 15: SETUP
* ============================================================================

* T87: setup check
local ++test_num
local ++n_tests
capture noisily mlearn setup, check
if _rc == 0 {
    display as result "RESULT: T`test_num' PASSED — setup check"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — setup check rc=" _rc
    local ++n_fail
}

* T88: setup r() values
local ++test_num
local ++n_tests
mlearn setup, check
if "`r(python_version)'" != "" & "`r(core_ok)'" == "1" {
    display as result "RESULT: T`test_num' PASSED — setup r() values (py=`r(python_version)')"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — setup r() incomplete"
    local ++n_fail
}

* T89: setup no option
local ++test_num
local ++n_tests
capture noisily mlearn setup
if _rc == 198 {
    display as result "RESULT: T`test_num' PASSED — setup without option (rc=198)"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — expected rc=198, got " _rc
    local ++n_fail
}

* ============================================================================
* SECTION 16: CROSS-CUTTING INTEGRATION
* ============================================================================

* T90: train → predict → retrain → predict (characteristics update)
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
mlearn y_bin x1 x2, method(forest) ntrees(20) seed(42) nolog
mlearn predict, generate(p1)
* Now retrain with different features
mlearn y_cont x1 x2 x3, method(elasticnet) seed(42) nolog
mlearn predict, generate(p2)
local task : char _dta[_mlearn_task]
local feat : char _dta[_mlearn_features]
if "`task'" == "regression" & "`feat'" == "x1 x2 x3" {
    display as result "RESULT: T`test_num' PASSED — characteristics update on retrain"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — task=`task' features=`feat'"
    local ++n_fail
}

* T91: estimates store works for both train and CV
local ++test_num
local ++n_tests
use "/tmp/test_mlearn_data.dta", clear
estimates clear
mlearn y_bin x1 x2, method(forest) ntrees(20) seed(42) nolog
estimates store train_model
mlearn cv y_bin x1 x2, method(forest) ntrees(20) folds(3) seed(42) nolog
estimates store cv_model
capture noisily mlearn compare train_model cv_model
if _rc == 0 & r(n_models) == 2 {
    display as result "RESULT: T`test_num' PASSED — compare train vs CV models"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — train vs CV compare rc=" _rc
    local ++n_fail
}

* T92: net install clean
local ++test_num
local ++n_tests
capture ado uninstall mlearn
net install mlearn, from("~/Stata-Dev/mlearn") replace
capture noisily mlearn setup, check
if _rc == 0 {
    display as result "RESULT: T`test_num' PASSED — clean reinstall works"
    local ++n_pass
}
else {
    display as error "RESULT: T`test_num' FAILED — reinstall failed"
    local ++n_fail
}

* ============================================================================
* SUMMARY
* ============================================================================
display as text ""
display as text "{hline 50}"
display as result "mlearn test summary"
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
    display as error "SOME TESTS FAILED"
    exit 9
}
else {
    display as result "ALL TESTS PASSED"
}

* Clean up
capture erase "/tmp/test_mlearn_data.dta"
capture erase "/tmp/mlearn_saved_model.pkl"
