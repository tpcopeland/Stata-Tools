*! mlearn_setup Version 1.0.0  2026/03/15
*! Check and install Python dependencies for mlearn
*! Author: Timothy P Copeland
*! Program class: rclass

program define mlearn_setup, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    syntax , [CHEck INSTall(string)]

    if "`check'" == "" & "`install'" == "" {
        display as error "specify {bf:check} or {bf:install()}"
        display as error "Example: {cmd:mlearn setup, check}"
        set varabbrev `_vaset'
        exit 198
    }

    * Auto-load bridge
    capture program list _mlearn_python_bridge
    if _rc {
        capture findfile _mlearn_python_bridge.ado
        if _rc == 0 {
            run "`r(fn)'"
        }
        else {
            display as error "_mlearn_python_bridge.ado not found; reinstall mlearn"
            set varabbrev `_vaset'
            exit 111
        }
    }

    * Check Python availability
    capture python: print("ok")
    if _rc {
        display as error "Python integration not available"
        display as error "Stata's python: directive requires Stata 16+ with Python configured"
        set varabbrev `_vaset'
        exit 198
    }

    if "`check'" != "" {
        global MLEARN_setup_action "check"
        capture noisily _mlearn_python_bridge _mlearn_setup_check.py
        local py_rc = _rc
        global MLEARN_setup_action
        if `py_rc' {
            set varabbrev `_vaset'
            exit `py_rc'
        }

        * Retrieve from globals
        local py_version "$MLEARN_python_version"
        local core_status "$MLEARN_core_status"
        local opt_status "$MLEARN_optional_status"
        local core_ok "$MLEARN_core_ok"
        * Clean up globals
        global MLEARN_python_version
        global MLEARN_core_status
        global MLEARN_optional_status
        global MLEARN_core_ok

        display as text ""
        display as text "{hline 50}"
        display as result "mlearn" as text " - Python Dependency Check"
        display as text "{hline 50}"
        display as text ""
        display as text "Python: " as result "`py_version'"
        display as text ""
        display as text "Core dependencies (required):"
        display as text "`core_status'"
        display as text ""
        display as text "Optional dependencies:"
        display as text "`opt_status'"
        display as text ""

        if "`core_ok'" == "1" {
            display as result "All core dependencies are installed."
        }
        else {
            display as error "Missing core dependencies. Run:"
            display as error "  {cmd:mlearn setup, install(core)}"
        }
        display as text "{hline 50}"

        return local python_version "`py_version'"
        return local core_ok "`core_ok'"
    }

    if "`install'" != "" {
        global MLEARN_setup_action "install"
        if "`install'" == "core" {
            global MLEARN_install_pkgs "numpy scikit-learn joblib"
        }
        else if "`install'" == "xgboost" {
            global MLEARN_install_pkgs "xgboost"
        }
        else if "`install'" == "lightgbm" {
            global MLEARN_install_pkgs "lightgbm"
        }
        else if "`install'" == "shap" {
            global MLEARN_install_pkgs "shap"
        }
        else if "`install'" == "all" {
            global MLEARN_install_pkgs "numpy scikit-learn joblib xgboost lightgbm shap"
        }
        else {
            global MLEARN_install_pkgs "`install'"
        }

        display as text "Installing: $MLEARN_install_pkgs..."
        capture noisily _mlearn_python_bridge _mlearn_setup_check.py
        local py_rc = _rc
        * Clean up globals
        global MLEARN_setup_action
        global MLEARN_install_pkgs

        if `py_rc' {
            set varabbrev `_vaset'
            exit `py_rc'
        }

        local install_ok "$MLEARN_install_ok"
        global MLEARN_install_ok

        if "`install_ok'" == "1" {
            display as result "Installation complete."
        }
        else {
            display as error "Installation failed."
        }
    }

    set varabbrev `_vaset'
end
