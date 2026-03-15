*! _mlearn_python_bridge Version 1.0.0  2026/03/15
*! Locate Python scripts via findfile, run python: block, capture errors
*! Author: Timothy P Copeland

program define _mlearn_python_bridge
    version 16.0
    set varabbrev off
    set more off

    args script_name

    * Locate the Python script
    capture findfile `script_name'
    if _rc {
        display as error "`script_name' not found"
        display as error "Reinstall the mlearn package or run {bf:mlearn setup, check}"
        exit 601
    }
    local pypath "`r(fn)'"

    * Clear any previous error message
    global MLEARN_py_error ""

    * Execute Python script (use expanduser to resolve ~ in findfile paths)
    capture noisily python: exec(open(__import__('os').path.expanduser("`pypath'")).read())
    if _rc {
        local bridge_rc = _rc
        if "$MLEARN_py_error" != "" {
            display as error "mlearn error: $MLEARN_py_error"
        }
        else {
            display as error "Python execution failed (rc=`bridge_rc')"
            display as error "Run {bf:mlearn setup, check} to verify dependencies"
        }
        global MLEARN_py_error
        exit `bridge_rc'
    }
    global MLEARN_py_error
end
