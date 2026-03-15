"""
_mlearn_shap_engine.py - SHAP value computation for mlearn
Version 1.0.0  2026/03/15
Author: Timothy P Copeland
"""
import numpy as np


def compute_shap(model, X, features, task, max_samples=500):
    """Compute SHAP values. Returns (shap_values, mean_abs_shap, X_sub)."""
    import shap

    # Subsample if needed
    if len(X) > max_samples:
        idx = np.random.choice(len(X), max_samples, replace=False)
        X_sub = X[idx]
    else:
        X_sub = X

    # Pick explainer based on model type
    model_type = type(model).__name__

    tree_models = {
        "RandomForestClassifier", "RandomForestRegressor",
        "GradientBoostingClassifier", "GradientBoostingRegressor",
        "XGBClassifier", "XGBRegressor",
        "LGBMClassifier", "LGBMRegressor",
    }

    if model_type in tree_models:
        try:
            explainer = shap.TreeExplainer(model)
            shap_values = explainer.shap_values(X_sub)
            # Some versions return Explanation objects — extract .values
            if hasattr(shap_values, 'values'):
                shap_values = shap_values.values
        except (ValueError, TypeError):
            # Fallback for XGBoost 3.x / shap compatibility issues
            # Use KernelExplainer instead
            bg = shap.sample(X_sub, min(50, len(X_sub)))
            if task in ("classification", "multiclass"):
                explainer = shap.KernelExplainer(model.predict_proba, bg)
            else:
                explainer = shap.KernelExplainer(model.predict, bg)
            shap_values = explainer.shap_values(X_sub, nsamples=100)
    else:
        # KernelExplainer for non-tree models
        bg = shap.sample(X_sub, min(50, len(X_sub)))
        if task in ("classification", "multiclass"):
            explainer = shap.KernelExplainer(model.predict_proba, bg)
        else:
            explainer = shap.KernelExplainer(model.predict, bg)
        shap_values = explainer.shap_values(X_sub, nsamples=100)

    # Normalize to 2D array (n_samples, n_features)
    if isinstance(shap_values, list):
        # Classification returns list of arrays per class
        if len(shap_values) == 2:
            shap_values = np.array(shap_values[1])
        else:
            shap_values = np.array(shap_values[0])
    shap_values = np.array(shap_values)

    # Handle 3D arrays (some explainers return (n_samples, n_features, n_classes))
    if shap_values.ndim == 3:
        if shap_values.shape[2] == 2:
            shap_values = shap_values[:, :, 1]
        else:
            shap_values = shap_values[:, :, 0]

    # Ensure 2D
    if shap_values.ndim == 1:
        shap_values = shap_values.reshape(1, -1)

    # Compute mean absolute SHAP per feature
    mean_abs_shap = np.mean(np.abs(shap_values), axis=0).flatten()
    # Convert to plain Python floats
    mean_abs_shap = np.array([float(v) for v in mean_abs_shap])

    return shap_values, mean_abs_shap, X_sub
