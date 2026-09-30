*! validation_logdoc_fixture_primitives.do -- actual transcript bytes and hostile caller preservation
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using validation_logdoc_fixture_primitives.log,text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_hostile.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# Exact transcript and hostile caller names
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local input `"`r(path_log)'"'
    local output `"`macval(root)'/faithful.md"'
    * Both commands promise caller-data preservation; actual transcript
    * content and interpreter resolution remain separately asserted.
    * expect: INVARIANT
    qa_hostile_names, clear
    python: __import__("sfi").Macro.setLocal("pyexec",__import__("sys").executable)
    qa_state_snapshot, tag(logdoc_py_primitive)
    quietly logdoc_py, check quiet python(`"`pyexec'"')
    assert r(ok)==1 & r(python_ok)==1 & r(renderer_ok)==1
    assert `"`r(python)'"'==`"`pyexec'"'
    qa_state_compare, tag(logdoc_py_primitive)
    mata: st_local("caller_globals",invtokens(select(st_dir("global","macro","*"),substr(st_dir("global","macro","*"),1,12):!="LOGDOC_LAST_")'))
    local caller_i=0
    foreach g of local caller_globals {
        local ++caller_i
        mata: st_local("caller_value_`caller_i'",st_global(st_local("g")))
    }
    qa_state_snapshot, tag(logdoc_primitive)
    quietly logdoc using `"`macval(input)'"', output(`"`macval(output)'"') format(md) python(`"`pyexec'"') quiet
    assert `"`r(output)'"'==`"`macval(output)'"'
    assert "`r(format)'"=="md"
    qa_state_compare, tag(logdoc_primitive) allow(global)
    mata: st_local("after_globals",invtokens(select(st_dir("global","macro","*"),substr(st_dir("global","macro","*"),1,12):!="LOGDOC_LAST_")'))
    assert "`caller_globals'"=="`after_globals'"
    local caller_i=0
    foreach g of local caller_globals {
        local ++caller_i
        mata: assert(st_global(st_local("g"))==st_local("caller_value_`caller_i'"))
    }
    mata: assert(st_global("LOGDOC_LAST_INPUT")==st_local("input"))
    mata: assert(st_global("LOGDOC_LAST_OUTPUT")==st_local("output"))
    mata: assert(st_global("LOGDOC_LAST_PYTHON")==st_local("pyexec"))
    assert "$LOGDOC_LAST_FORMAT"=="md" & "$LOGDOC_LAST_QUIET"=="quiet"
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text(); assert ("line 1: "+"wrapped text "*20).rstrip() in _t and "line 2: END" in _t and "```" in _t
}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: names rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: names"
}

**# Exact transcript and hostile caller codes
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local input `"`r(path_log)'"'
    local output `"`macval(root)'/faithful.md"'
    * Both commands promise caller-data preservation; actual transcript
    * content and interpreter resolution remain separately asserted.
    * expect: INVARIANT
    qa_hostile_codes, clear
    python: __import__("sfi").Macro.setLocal("pyexec",__import__("sys").executable)
    qa_state_snapshot, tag(logdoc_py_primitive)
    quietly logdoc_py, check quiet python(`"`pyexec'"')
    assert r(ok)==1 & r(python_ok)==1 & r(renderer_ok)==1
    assert `"`r(python)'"'==`"`pyexec'"'
    qa_state_compare, tag(logdoc_py_primitive)
    mata: st_local("caller_globals",invtokens(select(st_dir("global","macro","*"),substr(st_dir("global","macro","*"),1,12):!="LOGDOC_LAST_")'))
    local caller_i=0
    foreach g of local caller_globals {
        local ++caller_i
        mata: st_local("caller_value_`caller_i'",st_global(st_local("g")))
    }
    qa_state_snapshot, tag(logdoc_primitive)
    quietly logdoc using `"`macval(input)'"', output(`"`macval(output)'"') format(md) python(`"`pyexec'"') quiet
    assert `"`r(output)'"'==`"`macval(output)'"'
    assert "`r(format)'"=="md"
    qa_state_compare, tag(logdoc_primitive) allow(global)
    mata: st_local("after_globals",invtokens(select(st_dir("global","macro","*"),substr(st_dir("global","macro","*"),1,12):!="LOGDOC_LAST_")'))
    assert "`caller_globals'"=="`after_globals'"
    local caller_i=0
    foreach g of local caller_globals {
        local ++caller_i
        mata: assert(st_global(st_local("g"))==st_local("caller_value_`caller_i'"))
    }
    mata: assert(st_global("LOGDOC_LAST_INPUT")==st_local("input"))
    mata: assert(st_global("LOGDOC_LAST_OUTPUT")==st_local("output"))
    mata: assert(st_global("LOGDOC_LAST_PYTHON")==st_local("pyexec"))
    assert "$LOGDOC_LAST_FORMAT"=="md" & "$LOGDOC_LAST_QUIET"=="quiet"
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text(); assert ("line 1: "+"wrapped text "*20).rstrip() in _t and "line 2: END" in _t and "```" in _t
}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: codes rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: codes"
}

**# Exact transcript and hostile caller label_gaps
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local input `"`r(path_log)'"'
    local output `"`macval(root)'/faithful.md"'
    * Both commands promise caller-data preservation; actual transcript
    * content and interpreter resolution remain separately asserted.
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    python: __import__("sfi").Macro.setLocal("pyexec",__import__("sys").executable)
    qa_state_snapshot, tag(logdoc_py_primitive)
    quietly logdoc_py, check quiet python(`"`pyexec'"')
    assert r(ok)==1 & r(python_ok)==1 & r(renderer_ok)==1
    assert `"`r(python)'"'==`"`pyexec'"'
    qa_state_compare, tag(logdoc_py_primitive)
    mata: st_local("caller_globals",invtokens(select(st_dir("global","macro","*"),substr(st_dir("global","macro","*"),1,12):!="LOGDOC_LAST_")'))
    local caller_i=0
    foreach g of local caller_globals {
        local ++caller_i
        mata: st_local("caller_value_`caller_i'",st_global(st_local("g")))
    }
    qa_state_snapshot, tag(logdoc_primitive)
    quietly logdoc using `"`macval(input)'"', output(`"`macval(output)'"') format(md) python(`"`pyexec'"') quiet
    assert `"`r(output)'"'==`"`macval(output)'"'
    assert "`r(format)'"=="md"
    qa_state_compare, tag(logdoc_primitive) allow(global)
    mata: st_local("after_globals",invtokens(select(st_dir("global","macro","*"),substr(st_dir("global","macro","*"),1,12):!="LOGDOC_LAST_")'))
    assert "`caller_globals'"=="`after_globals'"
    local caller_i=0
    foreach g of local caller_globals {
        local ++caller_i
        mata: assert(st_global(st_local("g"))==st_local("caller_value_`caller_i'"))
    }
    mata: assert(st_global("LOGDOC_LAST_INPUT")==st_local("input"))
    mata: assert(st_global("LOGDOC_LAST_OUTPUT")==st_local("output"))
    mata: assert(st_global("LOGDOC_LAST_PYTHON")==st_local("pyexec"))
    assert "$LOGDOC_LAST_FORMAT"=="md" & "$LOGDOC_LAST_QUIET"=="quiet"
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text(); assert ("line 1: "+"wrapped text "*20).rstrip() in _t and "line 2: END" in _t and "```" in _t
}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: label_gaps rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: label_gaps"
}

**# Exact transcript and hostile caller miss_all_column
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local input `"`r(path_log)'"'
    local output `"`macval(root)'/faithful.md"'
    * Both commands promise caller-data preservation; actual transcript
    * content and interpreter resolution remain separately asserted.
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    python: __import__("sfi").Macro.setLocal("pyexec",__import__("sys").executable)
    qa_state_snapshot, tag(logdoc_py_primitive)
    quietly logdoc_py, check quiet python(`"`pyexec'"')
    assert r(ok)==1 & r(python_ok)==1 & r(renderer_ok)==1
    assert `"`r(python)'"'==`"`pyexec'"'
    qa_state_compare, tag(logdoc_py_primitive)
    mata: st_local("caller_globals",invtokens(select(st_dir("global","macro","*"),substr(st_dir("global","macro","*"),1,12):!="LOGDOC_LAST_")'))
    local caller_i=0
    foreach g of local caller_globals {
        local ++caller_i
        mata: st_local("caller_value_`caller_i'",st_global(st_local("g")))
    }
    qa_state_snapshot, tag(logdoc_primitive)
    quietly logdoc using `"`macval(input)'"', output(`"`macval(output)'"') format(md) python(`"`pyexec'"') quiet
    assert `"`r(output)'"'==`"`macval(output)'"'
    assert "`r(format)'"=="md"
    qa_state_compare, tag(logdoc_primitive) allow(global)
    mata: st_local("after_globals",invtokens(select(st_dir("global","macro","*"),substr(st_dir("global","macro","*"),1,12):!="LOGDOC_LAST_")'))
    assert "`caller_globals'"=="`after_globals'"
    local caller_i=0
    foreach g of local caller_globals {
        local ++caller_i
        mata: assert(st_global(st_local("g"))==st_local("caller_value_`caller_i'"))
    }
    mata: assert(st_global("LOGDOC_LAST_INPUT")==st_local("input"))
    mata: assert(st_global("LOGDOC_LAST_OUTPUT")==st_local("output"))
    mata: assert(st_global("LOGDOC_LAST_PYTHON")==st_local("pyexec"))
    assert "$LOGDOC_LAST_FORMAT"=="md" & "$LOGDOC_LAST_QUIET"=="quiet"
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text(); assert ("line 1: "+"wrapped text "*20).rstrip() in _t and "line 2: END" in _t and "```" in _t
}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: miss_all_column rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: miss_all_column"
}

**# Exact transcript and hostile caller single_row
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local input `"`r(path_log)'"'
    local output `"`macval(root)'/faithful.md"'
    * Both commands promise caller-data preservation; actual transcript
    * content and interpreter resolution remain separately asserted.
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    python: __import__("sfi").Macro.setLocal("pyexec",__import__("sys").executable)
    qa_state_snapshot, tag(logdoc_py_primitive)
    quietly logdoc_py, check quiet python(`"`pyexec'"')
    assert r(ok)==1 & r(python_ok)==1 & r(renderer_ok)==1
    assert `"`r(python)'"'==`"`pyexec'"'
    qa_state_compare, tag(logdoc_py_primitive)
    mata: st_local("caller_globals",invtokens(select(st_dir("global","macro","*"),substr(st_dir("global","macro","*"),1,12):!="LOGDOC_LAST_")'))
    local caller_i=0
    foreach g of local caller_globals {
        local ++caller_i
        mata: st_local("caller_value_`caller_i'",st_global(st_local("g")))
    }
    qa_state_snapshot, tag(logdoc_primitive)
    quietly logdoc using `"`macval(input)'"', output(`"`macval(output)'"') format(md) python(`"`pyexec'"') quiet
    assert `"`r(output)'"'==`"`macval(output)'"'
    assert "`r(format)'"=="md"
    qa_state_compare, tag(logdoc_primitive) allow(global)
    mata: st_local("after_globals",invtokens(select(st_dir("global","macro","*"),substr(st_dir("global","macro","*"),1,12):!="LOGDOC_LAST_")'))
    assert "`caller_globals'"=="`after_globals'"
    local caller_i=0
    foreach g of local caller_globals {
        local ++caller_i
        mata: assert(st_global(st_local("g"))==st_local("caller_value_`caller_i'"))
    }
    mata: assert(st_global("LOGDOC_LAST_INPUT")==st_local("input"))
    mata: assert(st_global("LOGDOC_LAST_OUTPUT")==st_local("output"))
    mata: assert(st_global("LOGDOC_LAST_PYTHON")==st_local("pyexec"))
    assert "$LOGDOC_LAST_FORMAT"=="md" & "$LOGDOC_LAST_QUIET"=="quiet"
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text(); assert ("line 1: "+"wrapped text "*20).rstrip() in _t and "line 2: END" in _t and "```" in _t
}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: single_row rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: single_row"
}

**# Exact transcript and hostile caller strings
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local input `"`r(path_log)'"'
    local output `"`macval(root)'/faithful.md"'
    * Both commands promise caller-data preservation; actual transcript
    * content and interpreter resolution remain separately asserted.
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    local corpus `r(names)'
    python: _ld_corpus=[__import__("sfi").Macro.getGlobal(g) for g in __import__("sfi").Macro.getLocal("corpus").split()]; __import__("pathlib").Path(__import__("sfi").Macro.getLocal("input")).write_text("\n".join(_ld_corpus)+"\n",encoding="utf-8")
    python: __import__("sfi").Macro.setLocal("pyexec",__import__("sys").executable)
    qa_state_snapshot, tag(logdoc_py_primitive)
    quietly logdoc_py, check quiet python(`"`pyexec'"')
    assert r(ok)==1 & r(python_ok)==1 & r(renderer_ok)==1
    assert `"`r(python)'"'==`"`pyexec'"'
    qa_state_compare, tag(logdoc_py_primitive)
    mata: st_local("caller_globals",invtokens(select(st_dir("global","macro","*"),substr(st_dir("global","macro","*"),1,12):!="LOGDOC_LAST_")'))
    local caller_i=0
    foreach g of local caller_globals {
        local ++caller_i
        mata: st_local("caller_value_`caller_i'",st_global(st_local("g")))
    }
    qa_state_snapshot, tag(logdoc_primitive)
    quietly logdoc using `"`macval(input)'"', output(`"`macval(output)'"') format(md) python(`"`pyexec'"') quiet
    assert `"`r(output)'"'==`"`macval(output)'"'
    assert "`r(format)'"=="md"
    qa_state_compare, tag(logdoc_primitive) allow(global)
    mata: st_local("after_globals",invtokens(select(st_dir("global","macro","*"),substr(st_dir("global","macro","*"),1,12):!="LOGDOC_LAST_")'))
    assert "`caller_globals'"=="`after_globals'"
    local caller_i=0
    foreach g of local caller_globals {
        local ++caller_i
        mata: assert(st_global(st_local("g"))==st_local("caller_value_`caller_i'"))
    }
    mata: assert(st_global("LOGDOC_LAST_INPUT")==st_local("input"))
    mata: assert(st_global("LOGDOC_LAST_OUTPUT")==st_local("output"))
    mata: assert(st_global("LOGDOC_LAST_PYTHON")==st_local("pyexec"))
    assert "$LOGDOC_LAST_FORMAT"=="md" & "$LOGDOC_LAST_QUIET"=="quiet"
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text(); assert all(v in _t for v in _ld_corpus) and "EXPANDED" not in _t and "```" in _t
}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: strings rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: strings"
}

display "RESULT: validation_logdoc_fixture_primitives tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
