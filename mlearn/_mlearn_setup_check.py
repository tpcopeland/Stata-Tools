"""
_mlearn_setup_check.py - Check and install Python dependencies for mlearn
Version 1.0.0  2026/03/15
Author: Timothy P Copeland
"""

from sfi import Macro
import importlib
import sys


def check_package(name, import_name=None):
    """Check if a Python package is available and return version."""
    if import_name is None:
        import_name = name
    try:
        mod = importlib.import_module(import_name)
        version = getattr(mod, "__version__", "unknown")
        return True, version
    except ImportError:
        return False, None


def main():
    try:
        action = Macro.getGlobal("MLEARN_setup_action")

        # Core dependencies
        deps = [
            ("numpy", "numpy"),
            ("scikit-learn", "sklearn"),
            ("joblib", "joblib"),
        ]

        # Optional dependencies
        optional_deps = [
            ("xgboost", "xgboost"),
            ("lightgbm", "lightgbm"),
            ("shap", "shap"),
        ]

        if action == "check":
            results = []
            all_ok = True

            Macro.setGlobal("MLEARN_python_version", sys.version.split()[0])

            for name, imp in deps:
                ok, ver = check_package(name, imp)
                status = f"  {name}: {ver}" if ok else f"  {name}: NOT FOUND"
                results.append(status)
                if not ok:
                    all_ok = False

            Macro.setGlobal("MLEARN_core_status",
                           "\n".join(results))
            Macro.setGlobal("MLEARN_core_ok", "1" if all_ok else "0")

            opt_results = []
            for name, imp in optional_deps:
                ok, ver = check_package(name, imp)
                status = f"  {name}: {ver}" if ok else f"  {name}: not installed"
                opt_results.append(status)

            Macro.setGlobal("MLEARN_optional_status",
                           "\n".join(opt_results))

        elif action == "install":
            import subprocess
            packages = Macro.getGlobal("MLEARN_install_pkgs").split()
            for pkg in packages:
                subprocess.check_call(
                    [sys.executable, "-m", "pip", "install", pkg],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.PIPE
                )
            Macro.setGlobal("MLEARN_install_ok", "1")

    except Exception as e:
        Macro.setGlobal("MLEARN_py_error", str(e))
        raise


main()
