"""
_mlearn_xgboost.py - XGBoost model wrappers for mlearn
Version 1.0.0  2026/03/15
Author: Timothy P Copeland
"""


def train_xgboost(X, y, task, params):
    """Train an XGBoost model. Returns (model, metrics_dict)."""
    import xgboost as xgb

    model_params = {
        "n_estimators": params.get("n_estimators", 100),
        "max_depth": params.get("max_depth", 6),
        "learning_rate": params.get("learning_rate", 0.1),
        "n_jobs": -1,
        "verbosity": 0,
    }
    if "random_state" in params:
        model_params["random_state"] = params["random_state"]
    if "subsample" in params:
        model_params["subsample"] = params["subsample"]
    if "colsample_bytree" in params:
        model_params["colsample_bytree"] = params["colsample_bytree"]
    if "reg_alpha" in params:
        model_params["reg_alpha"] = params["reg_alpha"]
    if "reg_lambda" in params:
        model_params["reg_lambda"] = params["reg_lambda"]
    if "min_child_weight" in params:
        model_params["min_child_weight"] = params["min_child_weight"]
    if "gamma" in params:
        model_params["gamma"] = params["gamma"]

    if task in ("classification", "multiclass"):
        model = xgb.XGBClassifier(**model_params, use_label_encoder=False,
                                   eval_metric="logloss")
    else:
        model = xgb.XGBRegressor(**model_params)

    model.fit(X, y)
    model._mlearn_scaler = None
    return model, {}
