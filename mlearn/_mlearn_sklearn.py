"""
_mlearn_sklearn.py - scikit-learn model wrappers for mlearn
Version 1.0.0  2026/03/15
Author: Timothy P Copeland

Provides RandomForest and ElasticNet (Phase 1).
Additional methods (boost, svm, nnet) added in Phase 2.
"""


def _get_forest_model(task, params):
    """Build RandomForest classifier or regressor."""
    from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor

    model_params = {
        "n_estimators": params.get("n_estimators", 100),
        "max_depth": params.get("max_depth", 6),
        "n_jobs": -1,
    }
    if "random_state" in params:
        model_params["random_state"] = params["random_state"]
    if "min_samples_leaf" in params:
        model_params["min_samples_leaf"] = params["min_samples_leaf"]
    if "min_samples_split" in params:
        model_params["min_samples_split"] = params["min_samples_split"]
    if "max_features" in params:
        model_params["max_features"] = params["max_features"]

    if task in ("classification", "multiclass"):
        return RandomForestClassifier(**model_params)
    else:
        return RandomForestRegressor(**model_params)


def _get_elasticnet_model(task, params):
    """Build ElasticNet (regression) or LogisticRegression (classification)."""
    if task in ("classification", "multiclass"):
        from sklearn.linear_model import LogisticRegression
        model_params = {
            "penalty": "elasticnet",
            "solver": "saga",
            "max_iter": params.get("max_iter", 10000),
            "l1_ratio": params.get("l1_ratio", 0.5),
            "C": params.get("C", 1.0),
        }
        if "random_state" in params:
            model_params["random_state"] = params["random_state"]
        if task == "multiclass":
            model_params["multi_class"] = "multinomial"
        return LogisticRegression(**model_params)
    else:
        from sklearn.linear_model import ElasticNet
        model_params = {
            "alpha": params.get("alpha", 1.0),
            "l1_ratio": params.get("l1_ratio", 0.5),
            "max_iter": params.get("max_iter", 10000),
        }
        if "random_state" in params:
            model_params["random_state"] = params["random_state"]
        return ElasticNet(**model_params)


def _get_boost_model(task, params):
    """Build GradientBoosting classifier or regressor."""
    from sklearn.ensemble import (GradientBoostingClassifier,
                                  GradientBoostingRegressor)

    model_params = {
        "n_estimators": params.get("n_estimators", 100),
        "max_depth": params.get("max_depth", 6),
        "learning_rate": params.get("learning_rate", 0.1),
    }
    if "random_state" in params:
        model_params["random_state"] = params["random_state"]
    if "min_samples_leaf" in params:
        model_params["min_samples_leaf"] = params["min_samples_leaf"]
    if "subsample" in params:
        model_params["subsample"] = params["subsample"]

    if task in ("classification", "multiclass"):
        return GradientBoostingClassifier(**model_params)
    else:
        return GradientBoostingRegressor(**model_params)


def _get_svm_model(task, params):
    """Build SVM classifier or regressor."""
    from sklearn.svm import SVC, SVR

    model_params = {
        "kernel": params.get("kernel", "rbf"),
        "C": params.get("C", 1.0),
    }
    if "gamma" in params:
        model_params["gamma"] = params["gamma"]

    if task in ("classification", "multiclass"):
        model_params["probability"] = True
        if "random_state" in params:
            model_params["random_state"] = params["random_state"]
        return SVC(**model_params)
    else:
        return SVR(**model_params)


def _get_nnet_model(task, params):
    """Build MLP classifier or regressor."""
    from sklearn.neural_network import MLPClassifier, MLPRegressor

    # Parse hidden layer sizes
    hidden = params.get("hidden_layer_sizes", (100,))
    if isinstance(hidden, str):
        hidden = tuple(int(x) for x in hidden.split(","))
    elif isinstance(hidden, (int, float)):
        hidden = (int(hidden),)

    model_params = {
        "hidden_layer_sizes": hidden,
        "max_iter": params.get("max_iter", 1000),
        "learning_rate_init": params.get("learning_rate", 0.001),
        "early_stopping": True,
    }
    if "random_state" in params:
        model_params["random_state"] = params["random_state"]
    if "alpha" in params:
        model_params["alpha"] = params["alpha"]

    if task in ("classification", "multiclass"):
        return MLPClassifier(**model_params)
    else:
        return MLPRegressor(**model_params)


def train_sklearn(X, y, method, task, params):
    """Train a scikit-learn model. Returns (model, metrics_dict)."""
    from sklearn.preprocessing import StandardScaler

    builders = {
        "forest": _get_forest_model,
        "elasticnet": _get_elasticnet_model,
        "boost": _get_boost_model,
        "svm": _get_svm_model,
        "nnet": _get_nnet_model,
    }

    if method not in builders:
        raise ValueError(f"Unknown sklearn method: {method}")

    # Scale features for methods that benefit from it
    scale_methods = {"elasticnet", "svm", "nnet"}
    if method in scale_methods:
        scaler = StandardScaler()
        X = scaler.fit_transform(X)
    else:
        scaler = None

    model = builders[method](task, params)
    model.fit(X, y)

    # Attach scaler to model for prediction
    model._mlearn_scaler = scaler

    return model, {}
