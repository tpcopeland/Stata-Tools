"""
_mlearn_engine.py - Orchestrator for mlearn Python bridge
Version 1.0.0  2026/03/15
Author: Timothy P Copeland

Reads data from Stata via sfi, dispatches to method module,
writes results back to Stata.
"""

import sys
import os

# Expand ~ in sys.path entries (Stata adds ~/ado/plus/py but Python
# import doesn't expand tildes)
sys.path = [os.path.expanduser(p) for p in sys.path]

from sfi import Data, Macro
import numpy as np
import joblib
import tempfile


def _get_column(var_name):
    """Get all values for a variable as a flat list."""
    raw = Data.get(var_name)
    # Data.get returns [[v1], [v2], ...] — flatten to [v1, v2, ...]
    if raw and isinstance(raw[0], list):
        return [row[0] for row in raw]
    return raw


def _get_touse_indices(touse_var):
    """Get observation indices where touse == 1."""
    vals = _get_column(touse_var)
    return [i for i, v in enumerate(vals) if v == 1.0]


def _pull_data(features, outcome, mask):
    """Pull feature matrix X and outcome vector y from Stata."""
    feature_cols = []
    for f in features:
        col = _get_column(f)
        feature_cols.append(np.array([col[i] for i in mask]))
    X = np.column_stack(feature_cols)
    out_col = _get_column(outcome)
    y = np.array([out_col[i] for i in mask])
    return X, y


def _pull_features_only(features, mask):
    """Pull feature matrix X from Stata (no outcome)."""
    feature_cols = []
    for f in features:
        col = _get_column(f)
        feature_cols.append(np.array([col[i] for i in mask]))
    X = np.column_stack(feature_cols)
    return X


def _parse_hparams(hparams_str):
    """Parse key=value pairs from hparams string."""
    params = {}
    if not hparams_str:
        return params
    for token in hparams_str.split():
        if "=" in token:
            key, val = token.split("=", 1)
            # Try numeric conversion
            try:
                val = int(val)
            except ValueError:
                try:
                    val = float(val)
                except ValueError:
                    pass
            params[key] = val
    return params


def _train(X, y, method, task, params):
    """Dispatch training to appropriate method module."""
    if method == "xgboost":
        from _mlearn_xgboost import train_xgboost
        return train_xgboost(X, y, task, params)
    elif method == "lightgbm":
        from _mlearn_lightgbm import train_lightgbm
        return train_lightgbm(X, y, task, params)
    else:
        from _mlearn_sklearn import train_sklearn
        return train_sklearn(X, y, method, task, params)


def _compute_metrics_classification(y_true, y_pred, y_prob=None):
    """Compute classification metrics."""
    from sklearn.metrics import accuracy_score, f1_score, roc_auc_score
    metrics = {}
    metrics["accuracy"] = accuracy_score(y_true, y_pred)
    avg = "binary" if len(np.unique(y_true)) <= 2 else "weighted"
    metrics["f1"] = f1_score(y_true, y_pred, average=avg, zero_division=0)
    if y_prob is not None and len(np.unique(y_true)) == 2:
        try:
            metrics["auc"] = roc_auc_score(y_true, y_prob)
        except ValueError:
            metrics["auc"] = np.nan
    else:
        metrics["auc"] = np.nan
    return metrics


def _compute_metrics_regression(y_true, y_pred):
    """Compute regression metrics."""
    from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
    metrics = {}
    metrics["rmse"] = np.sqrt(mean_squared_error(y_true, y_pred))
    metrics["mae"] = mean_absolute_error(y_true, y_pred)
    metrics["r2"] = r2_score(y_true, y_pred)
    return metrics


def action_train():
    """Train a model and store results."""
    method = Macro.getGlobal("MLEARN_method")
    task = Macro.getGlobal("MLEARN_task")
    outcome = Macro.getGlobal("MLEARN_outcome")
    features = Macro.getGlobal("MLEARN_features").split()
    touse = Macro.getGlobal("MLEARN_touse")
    seed = int(Macro.getGlobal("MLEARN_seed_val"))
    trainpct = float(Macro.getGlobal("MLEARN_trainpct"))
    saving = Macro.getGlobal("MLEARN_saving")

    # Hyperparameters from options
    ntrees = int(Macro.getGlobal("MLEARN_ntrees"))
    maxdepth = int(Macro.getGlobal("MLEARN_maxdepth"))
    lrate = float(Macro.getGlobal("MLEARN_lrate"))
    hparams_str = Macro.getGlobal("MLEARN_hparams_raw")

    mask = _get_touse_indices(touse)
    X, y = _pull_data(features, outcome, mask)

    # Build params dict
    params = {
        "n_estimators": ntrees,
        "max_depth": maxdepth,
        "learning_rate": lrate,
    }
    params.update(_parse_hparams(hparams_str))

    if seed >= 0:
        params["random_state"] = seed
        np.random.seed(seed)

    # Train/test split
    n_test = 0
    if trainpct < 1.0:
        from sklearn.model_selection import train_test_split
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, train_size=trainpct,
            random_state=seed if seed >= 0 else None,
            stratify=y if task in ("classification", "multiclass") else None
        )
        n_test = len(y_test)
    else:
        X_train, y_train = X, y
        X_test, y_test = X, y

    # Train model
    model, _ = _train(X_train, y_train, method, task, params)

    # Apply scaler to test set if needed (for elasticnet/svm/nnet)
    scaler = getattr(model, "_mlearn_scaler", None)
    if scaler is not None:
        X_test = scaler.transform(X_test)

    # Compute metrics on test set
    y_pred = model.predict(X_test)
    if task in ("classification", "multiclass"):
        y_prob = None
        if hasattr(model, "predict_proba"):
            proba = model.predict_proba(X_test)
            if proba.shape[1] == 2:
                y_prob = proba[:, 1]
        metrics = _compute_metrics_classification(y_test, y_pred, y_prob)
    else:
        metrics = _compute_metrics_regression(y_test, y_pred)

    # Serialize model
    if saving:
        model_path = saving
    else:
        fd, model_path = tempfile.mkstemp(suffix=".mlearn", prefix="mlearn_")
        os.close(fd)

    bundle = {
        "model": model,
        "method": method,
        "task": task,
        "features": features,
        "outcome": outcome,
        "metrics": metrics,
        "params": params,
        "n_train": len(y_train),
        "n_test": n_test,
    }
    joblib.dump(bundle, model_path)

    # Write results back to Stata via globals (locals are scoped to bridge)
    Macro.setGlobal("MLEARN_model_path_out", model_path)
    Macro.setGlobal("MLEARN_n_train", str(len(y_train)))
    Macro.setGlobal("MLEARN_n_test", str(n_test))

    for k, v in metrics.items():
        val = float(v) if not np.isnan(v) else -999.0
        Macro.setGlobal("MLEARN_" + k, str(val))

    # Hyperparams string for storage
    hp_str = " ".join(f"{k}={v}" for k, v in params.items()
                      if k != "random_state")
    Macro.setGlobal("MLEARN_hparams_store", hp_str)


def action_predict():
    """Load serialized model and generate predictions."""
    model_path = Macro.getGlobal("MLEARN_model_path")
    touse = Macro.getGlobal("MLEARN_touse")
    pred_var = Macro.getGlobal("MLEARN_pred_var")
    want_prob = int(Macro.getGlobal("MLEARN_want_prob"))

    bundle = joblib.load(model_path)
    model = bundle["model"]
    features = bundle["features"]
    task = bundle["task"]

    mask = _get_touse_indices(touse)
    X = _pull_features_only(features, mask)

    # Apply scaler if one was used during training
    scaler = getattr(model, "_mlearn_scaler", None)
    if scaler is not None:
        X = scaler.transform(X)

    if want_prob and task in ("classification", "multiclass"):
        if hasattr(model, "predict_proba"):
            proba = model.predict_proba(X)
            if proba.shape[1] == 2:
                preds = proba[:, 1]
            else:
                preds = np.max(proba, axis=1)
        else:
            preds = model.predict(X).astype(float)
    else:
        preds = model.predict(X).astype(float)

    # Write predictions back to Stata
    for j, i in enumerate(mask):
        Data.store(pred_var, i, float(preds[j]))


def action_cv():
    """K-fold cross-validation."""
    from sklearn.model_selection import StratifiedKFold, KFold

    method = Macro.getGlobal("MLEARN_method")
    task = Macro.getGlobal("MLEARN_task")
    outcome = Macro.getGlobal("MLEARN_outcome")
    features = Macro.getGlobal("MLEARN_features").split()
    touse = Macro.getGlobal("MLEARN_touse")
    seed = int(Macro.getGlobal("MLEARN_seed_val"))
    n_folds = int(Macro.getGlobal("MLEARN_folds"))

    ntrees = int(Macro.getGlobal("MLEARN_ntrees"))
    maxdepth = int(Macro.getGlobal("MLEARN_maxdepth"))
    lrate = float(Macro.getGlobal("MLEARN_lrate"))
    hparams_str = Macro.getGlobal("MLEARN_hparams_raw")

    mask = _get_touse_indices(touse)
    X, y = _pull_data(features, outcome, mask)

    params = {
        "n_estimators": ntrees,
        "max_depth": maxdepth,
        "learning_rate": lrate,
    }
    params.update(_parse_hparams(hparams_str))

    if seed >= 0:
        params["random_state"] = seed
        np.random.seed(seed)

    # Set up K-fold splitter
    if task in ("classification", "multiclass"):
        kf = StratifiedKFold(n_splits=n_folds, shuffle=True,
                             random_state=seed if seed >= 0 else None)
        split_iter = kf.split(X, y)
    else:
        kf = KFold(n_splits=n_folds, shuffle=True,
                   random_state=seed if seed >= 0 else None)
        split_iter = kf.split(X)

    # Collect per-fold metrics
    fold_metrics = []
    for fold_idx, (train_idx, test_idx) in enumerate(split_iter):
        X_train, X_test = X[train_idx], X[test_idx]
        y_train, y_test = y[train_idx], y[test_idx]

        model, _ = _train(X_train, y_train, method, task, params)

        # Apply scaler for prediction if needed
        scaler = getattr(model, "_mlearn_scaler", None)
        X_pred = scaler.transform(X_test) if scaler is not None else X_test

        y_pred = model.predict(X_pred)

        if task in ("classification", "multiclass"):
            y_prob = None
            if hasattr(model, "predict_proba"):
                proba = model.predict_proba(X_pred)
                if proba.shape[1] == 2:
                    y_prob = proba[:, 1]
            metrics = _compute_metrics_classification(y_test, y_pred, y_prob)
        else:
            metrics = _compute_metrics_regression(y_test, y_pred)

        fold_metrics.append(metrics)

    # Compute mean and SD across folds
    all_keys = fold_metrics[0].keys()
    mean_metrics = {}
    sd_metrics = {}
    for k in all_keys:
        vals = [m[k] for m in fold_metrics if not np.isnan(m[k])]
        if vals:
            mean_metrics[k] = np.mean(vals)
            sd_metrics[k] = np.std(vals, ddof=1) if len(vals) > 1 else 0.0
        else:
            mean_metrics[k] = np.nan
            sd_metrics[k] = np.nan

    # Write results back to Stata
    for k, v in mean_metrics.items():
        val = float(v) if not np.isnan(v) else -999.0
        Macro.setGlobal("MLEARN_" + k, str(val))
    for k, v in sd_metrics.items():
        val = float(v) if not np.isnan(v) else -999.0
        Macro.setGlobal("MLEARN_sd_" + k, str(val))

    Macro.setGlobal("MLEARN_n_folds", str(n_folds))
    Macro.setGlobal("MLEARN_n_obs", str(len(y)))

    # Per-fold detail for display
    for fi, fm in enumerate(fold_metrics):
        for k, v in fm.items():
            val = float(v) if not np.isnan(v) else -999.0
            Macro.setGlobal(f"MLEARN_fold{fi+1}_{k}", str(val))


def action_importance():
    """Extract feature importance from trained model."""
    model_path = Macro.getGlobal("MLEARN_model_path")
    bundle = joblib.load(model_path)
    model = bundle["model"]
    features = bundle["features"]

    # Get importance values
    if hasattr(model, "feature_importances_"):
        importances = model.feature_importances_
    elif hasattr(model, "coef_"):
        importances = np.abs(model.coef_).flatten()
        if len(importances) != len(features):
            importances = np.abs(model.coef_[0])
    else:
        raise ValueError(f"Model type {type(model).__name__} does not support "
                         "feature importance")

    # Sort by importance (descending)
    order = np.argsort(importances)[::-1]

    Macro.setGlobal("MLEARN_n_imp_features", str(len(features)))

    for rank, idx in enumerate(order):
        i = rank + 1
        Macro.setGlobal(f"MLEARN_imp_name_{i}", features[idx])
        Macro.setGlobal(f"MLEARN_imp_val_{i}", str(float(importances[idx])))
        # Display copies (sorted)
        Macro.setGlobal(f"MLEARN_imp_disp_{i}", features[idx])
        Macro.setGlobal(f"MLEARN_imp_disp_val_{i}",
                        str(float(importances[idx])))
        # Plot copies (sorted)
        Macro.setGlobal(f"MLEARN_imp_plot_name_{i}", features[idx])
        Macro.setGlobal(f"MLEARN_imp_plot_val_{i}",
                        str(float(importances[idx])))


def _parse_grid(grid_str):
    """Parse grid string like 'ntrees: 100 500 1000 maxdepth: 3 6 9'."""
    import re
    param_grid = {}
    # Split on parameter names (word followed by colon)
    parts = re.split(r'(\w+)\s*:', grid_str)
    parts = [p.strip() for p in parts if p.strip()]

    i = 0
    while i < len(parts) - 1:
        param_name = parts[i]
        values_str = parts[i + 1]
        values = []
        for v in values_str.split():
            try:
                values.append(int(v))
            except ValueError:
                try:
                    values.append(float(v))
                except ValueError:
                    values.append(v)
        if values:
            # Map Stata option names to sklearn param names
            name_map = {
                "ntrees": "n_estimators",
                "maxdepth": "max_depth",
                "lrate": "learning_rate",
            }
            param_name = name_map.get(param_name, param_name)
            param_grid[param_name] = values
        i += 2

    return param_grid


def action_tune():
    """Grid or random hyperparameter search."""
    from sklearn.model_selection import StratifiedKFold, KFold
    import itertools

    method = Macro.getGlobal("MLEARN_method")
    task = Macro.getGlobal("MLEARN_task")
    outcome = Macro.getGlobal("MLEARN_outcome")
    features = Macro.getGlobal("MLEARN_features").split()
    touse = Macro.getGlobal("MLEARN_touse")
    seed = int(Macro.getGlobal("MLEARN_seed_val"))
    n_folds = int(Macro.getGlobal("MLEARN_folds"))
    grid_str = Macro.getGlobal("MLEARN_grid")
    search = Macro.getGlobal("MLEARN_search")
    niter = int(Macro.getGlobal("MLEARN_niter"))
    metric = Macro.getGlobal("MLEARN_tune_metric")

    mask = _get_touse_indices(touse)
    X, y = _pull_data(features, outcome, mask)

    if seed >= 0:
        np.random.seed(seed)

    param_grid = _parse_grid(grid_str)

    # Generate configurations
    if search == "grid":
        keys = list(param_grid.keys())
        values = list(param_grid.values())
        configs = [dict(zip(keys, combo))
                   for combo in itertools.product(*values)]
    else:
        # Random search
        configs = []
        keys = list(param_grid.keys())
        for _ in range(niter):
            config = {}
            for k in keys:
                config[k] = np.random.choice(param_grid[k])
            configs.append(config)

    # Evaluate each configuration via CV
    if task in ("classification", "multiclass"):
        kf = StratifiedKFold(n_splits=n_folds, shuffle=True,
                             random_state=seed if seed >= 0 else None)
    else:
        kf = KFold(n_splits=n_folds, shuffle=True,
                   random_state=seed if seed >= 0 else None)

    # Higher is better for these metrics
    higher_better = {"accuracy", "auc", "f1", "r2"}

    best_score = None
    best_params = None

    for config in configs:
        base_params = {
            "n_estimators": config.get("n_estimators", 100),
            "max_depth": config.get("max_depth", 6),
            "learning_rate": config.get("learning_rate", 0.1),
        }
        if seed >= 0:
            base_params["random_state"] = seed
        base_params.update(config)

        fold_scores = []
        splits = (kf.split(X, y) if task in ("classification", "multiclass")
                  else kf.split(X))

        for train_idx, test_idx in splits:
            X_train, X_test = X[train_idx], X[test_idx]
            y_train, y_test = y[train_idx], y[test_idx]

            model, _ = _train(X_train, y_train, method, task, base_params)
            scaler = getattr(model, "_mlearn_scaler", None)
            X_pred = scaler.transform(X_test) if scaler else X_test

            y_pred = model.predict(X_pred)

            if task in ("classification", "multiclass"):
                y_prob = None
                if hasattr(model, "predict_proba"):
                    proba = model.predict_proba(X_pred)
                    if proba.shape[1] == 2:
                        y_prob = proba[:, 1]
                m = _compute_metrics_classification(y_test, y_pred, y_prob)
            else:
                m = _compute_metrics_regression(y_test, y_pred)

            if metric in m and not np.isnan(m[metric]):
                fold_scores.append(m[metric])

        if fold_scores:
            mean_score = np.mean(fold_scores)
            if best_score is None:
                best_score = mean_score
                best_params = config
            elif metric in higher_better and mean_score > best_score:
                best_score = mean_score
                best_params = config
            elif metric not in higher_better and mean_score < best_score:
                best_score = mean_score
                best_params = config

    # Write results
    Macro.setGlobal("MLEARN_best_score", str(float(best_score)))
    bp_str = " ".join(f"{k}={v}" for k, v in best_params.items())
    Macro.setGlobal("MLEARN_best_params", bp_str)
    Macro.setGlobal("MLEARN_n_configs", str(len(configs)))


def action_shap():
    """Compute SHAP values."""
    import importlib
    import _mlearn_shap_engine
    importlib.reload(_mlearn_shap_engine)
    from _mlearn_shap_engine import compute_shap

    model_path = Macro.getGlobal("MLEARN_model_path")
    touse = Macro.getGlobal("MLEARN_touse")
    features_str = Macro.getGlobal("MLEARN_features")
    features = features_str.split()
    task = Macro.getGlobal("MLEARN_task")
    max_samples = int(Macro.getGlobal("MLEARN_max_samples"))
    want_plot = Macro.getGlobal("MLEARN_shap_plot") == "1"

    bundle = joblib.load(model_path)
    model = bundle["model"]

    mask = _get_touse_indices(touse)
    X = _pull_features_only(features, mask)

    # Apply scaler if present
    scaler = getattr(model, "_mlearn_scaler", None)
    if scaler is not None:
        X = scaler.transform(X)

    shap_values, mean_abs_shap, X_sub = compute_shap(
        model, X, features, task, max_samples)

    # Sort by mean absolute SHAP (descending)
    order = np.argsort(mean_abs_shap)[::-1]

    Macro.setGlobal("MLEARN_shap_n_features", str(len(features)))
    Macro.setGlobal("MLEARN_shap_n_samples", str(len(X_sub)))

    for rank, idx in enumerate(order):
        i = rank + 1
        Macro.setGlobal(f"MLEARN_shap_name_{i}", features[idx])
        # Ensure proper scalar extraction from numpy
        val = mean_abs_shap[idx]
        if hasattr(val, 'item'):
            val = val.item()
        Macro.setGlobal(f"MLEARN_shap_val_{i}", str(float(val)))

    # Optional SHAP summary plot
    if want_plot:
        import shap
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        fig, ax = plt.subplots(figsize=(10, 6))
        shap.summary_plot(shap_values, X_sub,
                         feature_names=features, show=False)
        plt.tight_layout()
        plt.savefig("/tmp/mlearn_shap_plot.png", dpi=150)
        plt.close()
        Macro.setGlobal("MLEARN_shap_plot_path", "/tmp/mlearn_shap_plot.png")


def main():
    try:
        action = Macro.getGlobal("MLEARN_action")
        if action == "train":
            action_train()
        elif action == "predict":
            action_predict()
        elif action == "cv":
            action_cv()
        elif action == "importance":
            action_importance()
        elif action == "tune":
            action_tune()
        elif action == "shap":
            action_shap()
        else:
            Macro.setGlobal("MLEARN_py_error",
                           f"unknown action: {action}")
    except Exception as e:
        Macro.setGlobal("MLEARN_py_error", str(e))
        raise


main()
