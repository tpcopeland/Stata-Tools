"""
_mlearn_lightgbm.py - LightGBM model wrappers for mlearn
Version 1.0.0  2026/03/15
Author: Timothy P Copeland
"""


def train_lightgbm(X, y, task, params):
    """Train a LightGBM model. Returns (model, metrics_dict)."""
    import lightgbm as lgb

    model_params = {
        "n_estimators": params.get("n_estimators", 100),
        "max_depth": params.get("max_depth", -1),
        "learning_rate": params.get("learning_rate", 0.1),
        "n_jobs": -1,
        "verbose": -1,
    }
    if "random_state" in params:
        model_params["random_state"] = params["random_state"]
    if "num_leaves" in params:
        model_params["num_leaves"] = params["num_leaves"]
    if "subsample" in params:
        model_params["subsample"] = params["subsample"]
    if "colsample_bytree" in params:
        model_params["colsample_bytree"] = params["colsample_bytree"]
    if "reg_alpha" in params:
        model_params["reg_alpha"] = params["reg_alpha"]
    if "reg_lambda" in params:
        model_params["reg_lambda"] = params["reg_lambda"]
    if "min_child_samples" in params:
        model_params["min_child_samples"] = params["min_child_samples"]

    if task in ("classification", "multiclass"):
        model = lgb.LGBMClassifier(**model_params)
    else:
        model = lgb.LGBMRegressor(**model_params)

    model.fit(X, y)
    model._mlearn_scaler = None
    return model, {}
