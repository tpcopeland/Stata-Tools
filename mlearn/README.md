# mlearn — Machine Learning for Stata

Unified machine learning interface wrapping Python's scikit-learn, XGBoost, LightGBM, and SHAP via Stata 16+'s `python:` directive. Provides idiomatic Stata syntax with `ereturn`, `predict`, and `estimates store` integration.

## Version

v1.0.0 (2026-03-15)

## Requirements

- Stata 16+
- Python 3.8+ with: numpy, scikit-learn, joblib
- Optional: xgboost, lightgbm, shap

## Installation

```stata
net install mlearn, from("https://raw.githubusercontent.com/tcop/Stata-Dev/main/mlearn") replace
```

Check dependencies:
```stata
mlearn setup, check
```

## Quick Start

```stata
* Train a random forest
sysuse auto, clear
mlearn price mpg weight length, method(forest) ntrees(500) seed(42)

* Generate predictions
mlearn predict, generate(price_hat)

* Cross-validation
mlearn cv price mpg weight length, method(xgboost) folds(5) seed(42)

* Hyperparameter tuning
mlearn tune price mpg weight, method(forest) grid("ntrees: 100 500 maxdepth: 3 6 9") seed(42)

* Feature importance
mlearn importance

* SHAP values
mlearn shap

* Compare models
mlearn price mpg weight, method(forest) seed(42)
estimates store rf
mlearn price mpg weight, method(xgboost) seed(42)
estimates store xgb
mlearn compare rf xgb
```

## Commands

| Command | Purpose |
|---------|---------|
| `mlearn [train]` | Train a model (default action) |
| `mlearn predict` | Generate predictions from trained model |
| `mlearn cv` | K-fold cross-validation |
| `mlearn tune` | Hyperparameter tuning (grid/random) |
| `mlearn importance` | Feature importance |
| `mlearn shap` | SHAP values for interpretation |
| `mlearn compare` | Side-by-side model comparison |
| `mlearn setup` | Check/install Python dependencies |

## Methods

| Method | Engine | Type |
|--------|--------|------|
| `forest` | scikit-learn | Random Forest |
| `boost` | scikit-learn | Gradient Boosting |
| `xgboost` | XGBoost | XGBoost |
| `lightgbm` | LightGBM | LightGBM |
| `svm` | scikit-learn | Support Vector Machine |
| `nnet` | scikit-learn | Neural Network (MLP) |
| `elasticnet` | scikit-learn | ElasticNet / Lasso |

## Task Auto-Detection

The outcome variable determines the task type automatically:
- Binary 0/1 → classification
- Integer with ≤10 unique values → multiclass
- Otherwise → regression

Override with `task(classification|regression|multiclass)`.

## Stored Results

After `mlearn train`, results are posted to `e()`:

**Classification:** `e(b) = (accuracy, auc, f1)`, `e(accuracy)`, `e(auc)`, `e(f1)`

**Regression:** `e(b) = (rmse, mae, r2)`, `e(rmse)`, `e(mae)`, `e(r2)`

This enables `estimates store` / `estimates table` / `esttab` compatibility.

## Author

Timothy P Copeland
Department of Clinical Neuroscience, Karolinska Institutet
