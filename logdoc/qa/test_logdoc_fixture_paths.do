*! test_logdoc_fixture_paths.do -- actual renderer/interpreter path contracts
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using test_logdoc_fixture_paths.log,text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# Renderer path_hostile
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local input `"`r(path_log)'"'
    local output `"`r(path_active)'"'
    * expect: REFUSED
    python: _ld_before={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_state_snapshot, tag(logdoc_path)
    capture noisily logdoc using `"`macval(input)'"', output(`"`macval(output)'"') format(md) quiet
    assert _rc==198
    qa_state_compare, tag(logdoc_path)
    python: assert _ld_before=={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}

}
local outcome=_rc
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Renderer path_hostile; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Renderer path_hostile"
}

**# Explicit interpreter path_hostile
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local input `"`r(path_log)'"'
    local output `"`r(path_active)'"'
    * expect: REFUSED
    python: _ld_before={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_state_snapshot, tag(logdoc_path)
    capture noisily logdoc_py, check quiet python(`"`macval(output)'"')
    assert _rc==198
    qa_state_compare, tag(logdoc_path)
    python: assert _ld_before=={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}

}
local outcome=_rc
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Explicit interpreter path_hostile; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Explicit interpreter path_hostile"
}

**# Renderer path_noext
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37) perturb(path_noext)
    local root `"`r(root)'"'
    local input `"`r(path_log)'"'
    local output `"`r(path_active)'"'
    * expect: REFUSED
    python: _ld_before={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_state_snapshot, tag(logdoc_path)
    capture noisily logdoc using `"`macval(input)'"', output(`"`macval(output)'"') format(md) quiet
    assert _rc==602
    qa_state_compare, tag(logdoc_path)
    python: assert _ld_before=={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}

}
local outcome=_rc
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Renderer path_noext; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Renderer path_noext"
}

**# Explicit interpreter path_noext
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37) perturb(path_noext)
    local root `"`r(root)'"'
    local input `"`r(path_log)'"'
    local output `"`r(path_active)'"'
    * expect: REFUSED
    python: _ld_before={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_state_snapshot, tag(logdoc_path)
    capture noisily logdoc_py, check quiet python(`"`macval(output)'"')
    assert _rc==601
    qa_state_compare, tag(logdoc_path)
    python: assert _ld_before=={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}

}
local outcome=_rc
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Explicit interpreter path_noext; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Explicit interpreter path_noext"
}

**# Accepted Unicode-spaces renderer output
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local input `"`r(path_log)'"'
    local output `"`r(path_active)'"'
    * expect: EXACT
    local accepted `"`macval(root)'/accepted Å space"'
    mkdir `"`accepted'"'
    local output `"`accepted'/faithful.md"'
    python: __import__("sfi").Macro.setLocal("pyexec",__import__("sys").executable)
    * Replay intentionally records resolved options; pin that exact state
    * while preserving every global outside the documented replay cache.
    mata: st_local("caller_globals",invtokens(select(st_dir("global","macro","*"),substr(st_dir("global","macro","*"),1,12):!="LOGDOC_LAST_")'))
    local caller_i=0
    foreach g of local caller_globals {
        local ++caller_i
        mata: st_local("caller_value_`caller_i'",st_global(st_local("g")))
    }
    qa_state_snapshot, tag(logdoc_path)
    quietly logdoc using `"`input'"', output(`"`output'"') format(md) python(`"`pyexec'"') quiet
    assert `"`r(output)'"'==`"`output'"'
    qa_state_compare, tag(logdoc_path) allow(global)
    mata: st_local("after_globals",invtokens(select(st_dir("global","macro","*"),substr(st_dir("global","macro","*"),1,12):!="LOGDOC_LAST_")'))
    assert "`caller_globals'"=="`after_globals'"
    local caller_i=0
    foreach g of local caller_globals {
        local ++caller_i
        mata: assert(st_global(st_local("g"))==st_local("caller_value_`caller_i'"))
    }
    mata: assert(st_global("LOGDOC_LAST_INPUT")==st_local("input"))
    mata: assert(st_global("LOGDOC_LAST_OUTPUT")==st_local("output"))
    assert "$LOGDOC_LAST_FORMAT"=="md" & "$LOGDOC_LAST_THEME"=="light"
    mata: assert(st_global("LOGDOC_LAST_PYTHON")==st_local("pyexec"))
    assert "$LOGDOC_LAST_QUIET"=="quiet"
    foreach opt in TITLE DATE PREFORMATTED NOFOLD NODOTS CSS ACCENT VERBOSE FOOTER STAMP NOGRAPH GRAPHWIDTH GRAPHHEIGHT LINENUMBERS TOC FOLD HIGHLIGHT TABLES COPY DOWNLOAD LEGACY KEEP DROP APPEND NOTEBOOK EMAIL ANNOTATE GENERATED RUN STATAEXE {
        mata: assert(st_global("LOGDOC_LAST_"+st_local("opt"))=="")
    }
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text(); assert ("line 1: "+"wrapped text "*20).rstrip() in _t and "line 2: END" in _t and "```" in _t

}
local outcome=_rc
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Accepted Unicode-spaces renderer output; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Accepted Unicode-spaces renderer output"
}

**# Explicit actual Python executable resolves renderer
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local input `"`r(path_log)'"'
    local output `"`r(path_active)'"'
    * expect: EXACT
    python: __import__("sfi").Macro.setLocal("pyexec",__import__("sys").executable)
    qa_state_snapshot, tag(logdoc_path)
    quietly logdoc_py, check quiet python(`"`pyexec'"')
    assert r(ok)==1 & r(python_ok)==1 & r(renderer_ok)==1
    assert `"`r(python)'"'==`"`pyexec'"' & "`r(python_source)'"=="option"
    local version `"`r(python_version)'"'
    python: assert __import__("subprocess").check_output([__import__("sfi").Macro.getLocal("pyexec"),"--version"],text=True).strip()==__import__("sfi").Macro.getLocal("version")
    qa_state_compare, tag(logdoc_path)

}
local outcome=_rc
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Explicit actual Python executable resolves renderer; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Explicit actual Python executable resolves renderer"
}

display "RESULT: test_logdoc_fixture_paths tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
