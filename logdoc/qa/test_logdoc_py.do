* test_logdoc_py.do - Feature-format QA for logdoc_py
* Location: logdoc/qa/
* Run: stata-mp -b do test_logdoc_py.do

clear all
set more off
capture log close _all

**# Setup
local qa_dir = regexr("`c(pwd)'", "/+$", "")
capture confirm file "`qa_dir'/logdoc.pkg"
if _rc == 0 {
    local pkg_dir "`qa_dir'"
    local qa_dir "`pkg_dir'/qa"
}
else {
    local pkg_dir = regexr("`qa_dir'", "/qa/?$", "")
}
capture confirm file "`pkg_dir'/logdoc.pkg"
if _rc {
    display as error "Could not locate logdoc package root from c(pwd)=`c(pwd)'"
    exit 601
}

local start_pwd "`c(pwd)'"
local orig_varabbrev = c(varabbrev)
local orig_logdoc_python `"$LOGDOC_PYTHON"'

capture ado uninstall logdoc
quietly net install logdoc, from("`pkg_dir'") replace

tempfile scratch_marker
local scratch_dir "`scratch_marker'_dir"
capture mkdir "`scratch_dir'"

local test_pass = 0
local test_fail = 0
local test_total = 0
local detected_python ""
local stata_python ""
local has_stata_python 0
capture quietly python: from sfi import Macro; import sys; Macro.setLocal("stata_python", sys.executable)
if _rc == 0 & `"`stata_python'"' != "" local has_stata_python 1

**# Installed Surface And Default Check
**## PY-T1: package manifest installs command, help, and renderer
local ++test_total
capture noisily {
    which logdoc_py
    findfile logdoc_py.ado
    findfile logdoc_py.sthlp
    findfile logdoc_render.py
}
if _rc == 0 {
    display as result "PASS: PY-T1 - Installed command, help, and renderer are discoverable"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T1 - Installed package surface (rc = " _rc ")"
    local ++test_fail
}

**## PY-T2: default action is check with full return contract
local ++test_total
capture noisily {
    global LOGDOC_PYTHON
    logdoc_py, quiet
    assert r(ok) == 1
    assert r(python_ok) == 1
    assert r(renderer_ok) == 1
    capture assert r(pdf_ok) == 1
    assert _rc != 0
    capture assert r(installed) == 1
    assert _rc != 0
    assert r(python) != ""
    assert r(python_version) != ""
    assert strpos(r(python_version), "Python") == 1
    if `has_stata_python' {
        assert r(python_source) == "stata"
        assert r(python) == "`stata_python'"
    }
    else {
        assert r(python_source) == "path"
    }
    assert r(renderer) != ""
    local detected_python `"`r(python)'"'
}
if _rc == 0 {
    display as result "PASS: PY-T2 - Default check returns expected diagnostics"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T2 - Default check return contract (rc = " _rc ")"
    local ++test_fail
}

**## PY-T3: explicit check action matches default action
local ++test_total
capture noisily {
    logdoc_py, check quiet
    assert r(ok) == 1
    assert r(python_ok) == 1
    assert r(renderer_ok) == 1
    assert r(python) != ""
}
if _rc == 0 {
    display as result "PASS: PY-T3 - Explicit check action works"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T3 - Explicit check action (rc = " _rc ")"
    local ++test_fail
}

**# Option Coverage
**## PY-T4: documented abbreviations work
local ++test_total
capture noisily {
    logdoc_py, ch py("`detected_python'") q
    assert r(ok) == 1
    assert r(python_source) == "option"
    assert r(python) == "`detected_python'"
}
if _rc == 0 {
    display as result "PASS: PY-T4 - check/python/quiet abbreviations work"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T4 - Documented abbreviations (rc = " _rc ")"
    local ++test_fail
}

**## PY-T5: verbose check preserves the same r-class contract
local ++test_total
capture noisily {
    logdoc_py, python("`detected_python'") verbose
    assert r(ok) == 1
    assert r(python_ok) == 1
    assert r(renderer_ok) == 1
    assert r(python_source) == "option"
    assert r(python) == "`detected_python'"
}
if _rc == 0 {
    display as result "PASS: PY-T5 - verbose check works"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T5 - verbose option (rc = " _rc ")"
    local ++test_fail
}

**## PY-T6: python() path with spaces works
local ++test_total
capture noisily {
    if "`c(os)'" == "Windows" {
        display as result "SKIP: PY-T6 - spaced path symlink check is Unix-only"
    }
    else {
        local spaced_parent "`scratch_dir'/python space"
        local spaced_bin "`spaced_parent'/bin"
        capture mkdir "`spaced_parent'"
        capture mkdir "`spaced_bin'"
        tempfile pybinout
        quietly shell command -v python3 > "`pybinout'" 2>&1
        tempname pyfh
        file open `pyfh' using "`pybinout'", read text
        file read `pyfh' pybin
        file close `pyfh'
        local pybin = strtrim("`pybin'")
        if "`pybin'" == "" local pybin "`detected_python'"
        local spaced_py "`spaced_bin'/python3"
        capture erase "`spaced_py'"
        quietly shell ln -sf "`pybin'" "`spaced_py'"
        logdoc_py, python("`spaced_py'") quiet
        assert r(ok) == 1
        assert r(python_source) == "option"
        assert r(python) == "`spaced_py'"
    }
}
if _rc == 0 {
    display as result "PASS: PY-T6 - python() accepts executable paths with spaces"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T6 - python() path with spaces (rc = " _rc ")"
    local ++test_fail
}

**# Detection Order
**## PY-T7: option beats invalid global and invalid config
local ++test_total
capture noisily {
    local t7_dir "`scratch_dir'/t7_option_first"
    capture mkdir "`t7_dir'"
    cd "`t7_dir'"
    global LOGDOC_PYTHON "/definitely/not/logdoc/global-python"
    quietly file open cfg using ".logdocrc", write text replace
    file write cfg "python=/definitely/not/logdoc/config-python" _n
    file close cfg

    logdoc_py, python("`detected_python'") quiet
    assert r(python_source) == "option"
    assert r(python) == "`detected_python'"
    cd "`start_pwd'"
    global LOGDOC_PYTHON
}
if _rc == 0 {
    display as result "PASS: PY-T7 - option candidate has highest precedence"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T7 - option detection precedence (rc = " _rc ")"
    capture cd "`start_pwd'"
    global LOGDOC_PYTHON
    local ++test_fail
}

**## PY-T8: Stata configured Python beats session global and config
local ++test_total
capture noisily {
    local t8_dir "`scratch_dir'/t8_stata_first"
    capture mkdir "`t8_dir'"
    cd "`t8_dir'"

    local global_python "`detected_python'"
    if "`c(os)'" != "Windows" {
        local alt_dir "`scratch_dir'/t8_alt"
        capture mkdir "`alt_dir'"
        local global_python "`alt_dir'/python3"
        capture erase "`global_python'"
        quietly shell ln -sf "`detected_python'" "`global_python'"
    }
    global LOGDOC_PYTHON "`global_python'"
    quietly file open cfg using ".logdocrc", write text replace
    file write cfg "python=`global_python'" _n
    file close cfg

    logdoc_py, quiet
    if `has_stata_python' {
        assert r(python_source) == "stata"
        assert r(python) == "`stata_python'"
    }
    else {
        assert r(python_source) == "global"
        assert r(python) == "`global_python'"
    }
    assert r(config) == ".logdocrc"
    cd "`start_pwd'"
    global LOGDOC_PYTHON
}
if _rc == 0 {
    display as result "PASS: PY-T8 - Stata configured Python has default precedence"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T8 - Stata-first detection precedence (rc = " _rc ")"
    capture cd "`start_pwd'"
    global LOGDOC_PYTHON
    local ++test_fail
}

**## PY-T9: invalid global falls through to Stata/config fallback
local ++test_total
capture noisily {
    local t9_dir "`scratch_dir'/t9_after_bad_global"
    capture mkdir "`t9_dir'"
    cd "`t9_dir'"
    global LOGDOC_PYTHON "/definitely/not/logdoc/global-python"
    quietly file open cfg using ".logdocrc", write text replace
    file write cfg "theme=dark" _n
    file write cfg "python=`detected_python'" _n
    file close cfg

    logdoc_py, quiet
    if `has_stata_python' {
        assert r(python_source) == "stata"
        assert r(python) == "`stata_python'"
    }
    else {
        assert r(python_source) == "config"
        assert r(python) == "`detected_python'"
    }
    assert r(config) == ".logdocrc"
    cd "`start_pwd'"
    global LOGDOC_PYTHON
}
if _rc == 0 {
    display as result "PASS: PY-T9 - invalid global uses next valid fallback"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T9 - fallback after invalid global (rc = " _rc ")"
    capture cd "`start_pwd'"
    global LOGDOC_PYTHON
    local ++test_fail
}

**## PY-T10: invalid config falls through to Stata/path defaults
local ++test_total
capture noisily {
    local t10_dir "`scratch_dir'/t10_default_after_bad_config"
    capture mkdir "`t10_dir'"
    cd "`t10_dir'"
    global LOGDOC_PYTHON
    quietly file open cfg using ".logdocrc", write text replace
    file write cfg "python=/definitely/not/logdoc/config-python" _n
    file close cfg

    local expect_source "path"
    if `has_stata_python' local expect_source "stata"
    logdoc_py, quiet
    assert r(ok) == 1
    assert r(python_source) == "`expect_source'"
    if `has_stata_python' assert r(python) == "`stata_python'"
    assert r(config) == ".logdocrc"
    cd "`start_pwd'"
}
if _rc == 0 {
    display as result "PASS: PY-T10 - invalid config falls through to default candidates"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T10 - default fallback after invalid config (rc = " _rc ")"
    capture cd "`start_pwd'"
    local ++test_fail
}

**# set Action
**## PY-T11: set stores LOGDOC_PYTHON and returns diagnostics
local ++test_total
capture noisily {
    set varabbrev on
    logdoc_py, python("`detected_python'") set quiet
    assert "$LOGDOC_PYTHON" == "`detected_python'"
    assert r(ok) == 1
    assert r(python_source) == "option"
    assert c(varabbrev) == "on"
    global LOGDOC_PYTHON
    set varabbrev `orig_varabbrev'
}
if _rc == 0 {
    display as result "PASS: PY-T11 - set action stores session global"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T11 - set action (rc = " _rc ")"
    global LOGDOC_PYTHON
    set varabbrev `orig_varabbrev'
    local ++test_fail
}

**# save Action
**## PY-T12: save creates a new .logdocrc
local ++test_total
capture noisily {
    local t12_dir "`scratch_dir'/t12_save_new"
    capture mkdir "`t12_dir'"
    cd "`t12_dir'"
    logdoc_py, python("`detected_python'") save quiet
    assert r(config) == ".logdocrc"
    confirm file ".logdocrc"

    local saw_python 0
    quietly file open cfgread using ".logdocrc", read text
    file read cfgread line
    while r(eof) == 0 {
        if "`line'" == "python=`detected_python'" local saw_python 1
        file read cfgread line
    }
    file close cfgread
    assert `saw_python' == 1
    cd "`start_pwd'"
}
if _rc == 0 {
    display as result "PASS: PY-T12 - save creates project config"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T12 - save new config (rc = " _rc ")"
    capture cd "`start_pwd'"
    local ++test_fail
}

**## PY-T13: save without replace refuses existing python
local ++test_total
capture noisily {
    local t13_dir "`scratch_dir'/t13_save_no_replace"
    capture mkdir "`t13_dir'"
    cd "`t13_dir'"
    quietly file open cfg using ".logdocrc", write text replace
    file write cfg "python=/definitely/not/logdoc/config-python" _n
    file close cfg

    capture noisily logdoc_py, python("`detected_python'") save quiet
    assert _rc == 602
    cd "`start_pwd'"
}
if _rc == 0 {
    display as result "PASS: PY-T13 - save refuses overwrite without replace"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T13 - save no-replace guard (rc = " _rc ")"
    capture cd "`start_pwd'"
    local ++test_fail
}

**## PY-T14: save replace preserves other config lines and collapses python entries
local ++test_total
capture noisily {
    local t14_dir "`scratch_dir'/t14_save_replace"
    capture mkdir "`t14_dir'"
    cd "`t14_dir'"
    quietly file open cfg using ".logdocrc", write text replace
    file write cfg "theme=dark" _n
    file write cfg "python=/definitely/not/logdoc/first-python" _n
    file write cfg "format=html" _n
    file write cfg "python=/definitely/not/logdoc/second-python" _n
    file close cfg

    logdoc_py, python("`detected_python'") save replace quiet
    local saw_theme 0
    local saw_format 0
    local saw_python 0
    local python_lines 0
    quietly file open cfgread using ".logdocrc", read text
    file read cfgread line
    while r(eof) == 0 {
        if "`line'" == "theme=dark" local saw_theme 1
        if "`line'" == "format=html" local saw_format 1
        if substr("`line'", 1, 7) == "python=" local ++python_lines
        if "`line'" == "python=`detected_python'" local saw_python 1
        file read cfgread line
    }
    file close cfgread
    assert `saw_theme' == 1
    assert `saw_format' == 1
    assert `saw_python' == 1
    assert `python_lines' == 1
    cd "`start_pwd'"
}
if _rc == 0 {
    display as result "PASS: PY-T14 - save replace preserves config and replaces python once"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T14 - save replace config preservation (rc = " _rc ")"
    capture cd "`start_pwd'"
    local ++test_fail
}

**# install Action
**## PY-T15: required optional and all installs are no-op for logdoc
local ++test_total
capture noisily {
    foreach mode in required optional all {
        logdoc_py, install(`mode') quiet
        assert r(installed) == 0
        assert "`r(required)'" == ""
        assert "`r(optional)'" == ""
        assert "`r(missing)'" == ""
        assert "`r(install_cmd)'" == ""
    }
}
if _rc == 0 {
    display as result "PASS: PY-T15 - required/optional/all install modes are no-op"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T15 - built-in install modes (rc = " _rc ")"
    local ++test_fail
}

**## PY-T16: custom install dryrun returns pip command without installing
local ++test_total
capture noisily {
    logdoc_py, python("`detected_python'") install(jinja2) dryrun quiet
    assert r(installed) == .
    assert r(python_source) == "option"
    assert strpos(r(install_cmd), "-m pip install jinja2") > 0
}
if _rc == 0 {
    display as result "PASS: PY-T16 - custom install dryrun reports pip command"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T16 - custom install dryrun (rc = " _rc ")"
    local ++test_fail
}

**# PDF Option
**## PY-T17: pdf option reports available wkhtmltopdf or fails cleanly
local ++test_total
capture noisily {
    tempfile wkcheck
    if "`c(os)'" == "Windows" {
        quietly shell where wkhtmltopdf > "`wkcheck'" 2>&1
    }
    else {
        quietly shell command -v wkhtmltopdf > "`wkcheck'" 2>&1
    }
    local has_wkhtmltopdf 0
    capture {
        tempname wkfh
        file open `wkfh' using "`wkcheck'", read text
        file read `wkfh' wkline
        file close `wkfh'
        local wkline = strtrim("`wkline'")
        if "`wkline'" != "" & !regexm(lower("`wkline'"), "not found") {
            local has_wkhtmltopdf 1
        }
    }

    capture noisily logdoc_py, check pdf quiet
    if `has_wkhtmltopdf' {
        assert _rc == 0
        assert r(pdf_ok) == 1
        assert r(wkhtmltopdf) != ""
    }
    else {
        assert _rc == 601
    }
}
if _rc == 0 {
    display as result "PASS: PY-T17 - pdf option handles wkhtmltopdf presence/absence"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T17 - pdf option behavior (rc = " _rc ")"
    local ++test_fail
}

**# Error And Boundary Behavior
**## PY-T18: invalid option combinations return rc=198
local ++test_total
capture noisily {
    capture noisily logdoc_py, quiet verbose
    assert _rc == 198
    capture noisily logdoc_py, check set
    assert _rc == 198
    capture noisily logdoc_py, set save
    assert _rc == 198
    capture noisily logdoc_py, save install(required)
    assert _rc == 198
    capture noisily logdoc_py, dryrun
    assert _rc == 198
    capture noisily logdoc_py, replace
    assert _rc == 198
}
if _rc == 0 {
    display as result "PASS: PY-T18 - invalid option combinations return rc=198"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T18 - invalid option combinations (rc = " _rc ")"
    local ++test_fail
}

**## PY-T19: missing executable returns rc=601 and restores varabbrev
local ++test_total
capture noisily {
    set varabbrev on
    capture noisily logdoc_py, python("/definitely/not/logdoc/python3") quiet
    assert _rc == 601
    assert c(varabbrev) == "on"
    set varabbrev `orig_varabbrev'
}
if _rc == 0 {
    display as result "PASS: PY-T19 - missing Python errors cleanly and restores varabbrev"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T19 - missing Python error path (rc = " _rc ")"
    set varabbrev `orig_varabbrev'
    local ++test_fail
}

**## PY-T20: Python older than 3.6 is rejected
local ++test_total
capture noisily {
    if "`c(os)'" == "Windows" {
        display as result "SKIP: PY-T20 - fake executable check is Unix-only"
    }
    else {
        local fake_old "`scratch_dir'/fake_old_python"
        tempname oldfh
        quietly file open `oldfh' using "`fake_old'", write text replace
        file write `oldfh' "#!/usr/bin/env bash" _n
        file write `oldfh' "echo 'Python 2.7.18'" _n
        file close `oldfh'
        quietly shell chmod +x "`fake_old'"
        capture noisily logdoc_py, python("`fake_old'") quiet
        assert _rc == 601
    }
}
if _rc == 0 {
    display as result "PASS: PY-T20 - old Python version is rejected"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T20 - old Python version rejection (rc = " _rc ")"
    local ++test_fail
}

**## PY-T21: broken standard-library import path is rejected
local ++test_total
capture noisily {
    if "`c(os)'" == "Windows" {
        display as result "SKIP: PY-T21 - fake executable check is Unix-only"
    }
    else {
        local fake_broken "`scratch_dir'/fake_broken_python"
        tempname brokenfh
        quietly file open `brokenfh' using "`fake_broken'", write text replace
        file write `brokenfh' "#!/usr/bin/env bash" _n
        file write `brokenfh' "echo 'Python 3.11.0'" _n
        file write `brokenfh' "exit 1" _n
        file close `brokenfh'
        quietly shell chmod +x "`fake_broken'"
        capture noisily logdoc_py, python("`fake_broken'") quiet
        assert _rc == 601
    }
}
if _rc == 0 {
    display as result "PASS: PY-T21 - broken Python checks are rejected"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T21 - broken Python rejection (rc = " _rc ")"
    local ++test_fail
}

**# State Preservation
**## PY-T22: data in memory is unchanged
local ++test_total
capture noisily {
    clear
    input id value
    1 10
    2 20
    3 30
    end
    sort value
    logdoc_py, quiet
    assert _N == 3
    assert id[1] == 1
    assert id[2] == 2
    assert id[3] == 3
    assert value[1] == 10
    assert value[2] == 20
    assert value[3] == 30
}
if _rc == 0 {
    display as result "PASS: PY-T22 - data in memory is preserved"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T22 - data preservation (rc = " _rc ")"
    local ++test_fail
}

**## PY-T23: active estimation results are unchanged
local ++test_total
capture noisily {
    sysuse auto, clear
    regress price mpg
    local e_cmd "`e(cmd)'"
    local e_n = e(N)
    matrix b_before = e(b)
    logdoc_py, quiet
    assert "`e(cmd)'" == "`e_cmd'"
    assert e(N) == `e_n'
    matrix b_after = e(b)
    assert mreldif(b_before, b_after) == 0
}
if _rc == 0 {
    display as result "PASS: PY-T23 - active estimation state is preserved"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T23 - estimation state preservation (rc = " _rc ")"
    local ++test_fail
}

**## PY-T24: more setting is not changed
local ++test_total
capture noisily {
    local before_more = c(more)
    logdoc_py, quiet
    assert c(more) == "`before_more'"
}
if _rc == 0 {
    display as result "PASS: PY-T24 - more setting is preserved"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T24 - more setting preservation (rc = " _rc ")"
    local ++test_fail
}

**# Documentation Reality
**## PY-T25: runnable help examples execute after install
local ++test_total
capture noisily {
    logdoc_py
    assert r(ok) == 1
    logdoc_py, install(jinja2) dryrun
    assert strpos(r(install_cmd), "-m pip install jinja2") > 0
}
if _rc == 0 {
    display as result "PASS: PY-T25 - runnable help examples work after install"
    local ++test_pass
}
else {
    display as error "FAIL: PY-T25 - runnable help examples (rc = " _rc ")"
    local ++test_fail
}

**# Cleanup And Summary
capture cd "`start_pwd'"
if "`c(os)'" == "Windows" {
    capture shell rmdir /s /q "`scratch_dir'"
}
else {
    capture shell rm -rf "`scratch_dir'"
}
if `"`orig_logdoc_python'"' != "" {
    global LOGDOC_PYTHON `"`orig_logdoc_python'"'
}
else {
    global LOGDOC_PYTHON
}
set varabbrev `orig_varabbrev'

display as result "logdoc_py feature QA: `test_pass' passed, `test_fail' failed, `test_total' total"
if `test_fail' > 0 exit 9
