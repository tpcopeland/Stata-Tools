*! validation_logdoc_fixture_contract.do -- canonical labelled designs and independent contents
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using "validation_logdoc_fixture_contract.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# Wrapped log to md
local ++tests
capture noisily {
    local root ""
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local input `"`r(path_log)'"'
    local output `"`macval(root)'/faithful.md"'
    quietly logdoc using `"`macval(input)'"', output(`"`macval(output)'"') format(md) replace quiet
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text(); assert ("line 1: "+"wrapped text "*20).rstrip() in _t and "line 2: END" in _t; assert "```" in _t

}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Wrapped log to md; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Wrapped log to md"
}

**# Wrapped log to html
local ++tests
capture noisily {
    local root ""
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local input `"`r(path_log)'"'
    local output `"`macval(root)'/faithful.html"'
    quietly logdoc using `"`macval(input)'"', output(`"`macval(output)'"') format(html) replace quiet
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text(); assert ("line 1: "+"wrapped text "*20).rstrip() in _t and "line 2: END" in _t; assert "<pre" in _t

}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Wrapped log to html; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Wrapped log to html"
}

**# Wrapped smcl to md
local ++tests
capture noisily {
    local root ""
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local input `"`r(path_smcl)'"'
    local output `"`macval(root)'/faithful.md"'
    quietly logdoc using `"`macval(input)'"', output(`"`macval(output)'"') format(md) replace quiet
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text(); assert ("line 1: "+"wrapped text "*20).rstrip() in _t and "line 2: END" in _t; assert "```" in _t

}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Wrapped smcl to md; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Wrapped smcl to md"
}

**# Wrapped smcl to html
local ++tests
capture noisily {
    local root ""
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local input `"`r(path_smcl)'"'
    local output `"`macval(root)'/faithful.html"'
    quietly logdoc using `"`macval(input)'"', output(`"`macval(output)'"') format(html) replace quiet
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text(); assert ("line 1: "+"wrapped text "*20).rstrip() in _t and "line 2: END" in _t; assert "<pre" in _t

}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Wrapped smcl to html; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Wrapped smcl to html"
}

**# Existing extensionless output refuses without replacement
local ++tests
capture noisily {
    local root ""
    * expect: REFUSED
    qa_fx_a7_files, clear seed(37) perturb(path_noext)
    local root `"`r(root)'"'
    local input `"`r(path_log)'"'
    local output `"`r(path_active)'"'
    qa_state_snapshot, tag(ld_exists)
    capture noisily logdoc using `"`macval(input)'"', output(`"`macval(output)'"') format(md) quiet
    assert _rc==602
    qa_state_compare, tag(ld_exists)
    python: assert __import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text()=="EXTENSIONLESS_KEEP\n"

}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Existing extensionless output refuses without replacement; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Existing extensionless output refuses without replacement"
}

**# Python capability resolves the actual shipped renderer
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(ld_py)
    quietly logdoc_py, check quiet
    local renderer `"`r(renderer)'"'
    assert `"`r(python)'"'!="" & `"`r(python_version)'"'!=""
    python: _p=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("renderer")); assert _p.name=="logdoc_render.py" and "def " in _p.read_text()
    qa_state_compare, tag(ld_py)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Python capability resolves the actual shipped renderer; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Python capability resolves the actual shipped renderer"
}

display "RESULT: validation_logdoc_fixture_contract tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
