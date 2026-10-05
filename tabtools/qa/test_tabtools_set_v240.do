* test_tabtools_set_v240.do - tabtools set borderstyle as a session key:
* set / query / clear / r(), validation identical to the borderstyle()
* option, and precedence (explicit option > session value > thin) read back
* from the workbook XML with openpyxl (tools/xlsx_facts.py), never through
* the Mata xl() writer under test.
*
* Border geometry (test_border_geometry.do): thin and medium draw a box with
* left/right rules on the body; academic draws no vertical rules.

clear all
set more off
set varabbrev off
version 17.0

capture log close _ts240
log using "test_tabtools_set_v240.log", replace text name(_ts240)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global TS240_TOOL "`qa_dir'/tools/xlsx_facts.py"
global TS240_RES "`output_dir'/ts240_facts.txt"
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear

local test_count = 0
local pass_count = 0
local fail_count = 0

* number of `kind' border facts with style `style' on sheet `sheet' of
* `book' (style "" = any style) -> r(n)
capture program drop _ts240_count
program define _ts240_count, rclass
    version 17.0
    args book sheet kind style
    capture erase "$TS240_RES"
    shell python3 "$TS240_TOOL" "`book'" "`sheet'" "$TS240_RES"
    confirm file "$TS240_RES"
    local pre = strtrim("`kind' ")
    mata: _f = cat("$TS240_RES")
    mata: _f = select(_f, substr(_f, 1, strlen(st_local("kind")) + 1) :== st_local("kind") + " ")
    if "`style'" != "" {
        mata: _f = select(_f, substr(_f, -strlen(st_local("style")) - 1, .) :== " " + st_local("style"))
    }
    mata: st_local("_n", strofreal(rows(_f)))
    return scalar n = `_n'
end

**# B1: set, query, get and r() report the session border style
local ++test_count
capture noisily {
    quietly tabtools set clear
    tabtools query
    assert `"`r(borderstyle)'"' == ""
    tabtools set borderstyle medium
    assert `"`r(borderstyle)'"' == "medium"
    assert `"$TABTOOLS_BORDER"' == "medium"
    tabtools query
    assert `"`r(borderstyle)'"' == "medium"
    * the other query returns are still there
    assert `"`r(workbook)'"' == "" & `"`r(smallcells)'"' == ""
    tabtools get
    assert `"`r(borderstyle)'"' == "medium"
    * query prints the line
    local con "`output_dir'/ts240_query.txt"
    log using "`con'", text replace name(_ts240q)
    tabtools query
    log close _ts240q
    mata: st_local("_n", strofreal(sum(strtrim(cat(st_local("con"))) :== "Borderstyle: medium")))
    assert `_n' == 1
    tabtools set borderstyle clear
    log using "`con'", text replace name(_ts240q)
    tabtools query
    log close _ts240q
    mata: st_local("_n", strofreal(sum(strtrim(cat(st_local("con"))) :== "Borderstyle: (not set)")))
    assert `_n' == 1
}
if _rc == 0 {
    display as result "  PASS: B1 set/query/get report borderstyle"
    local ++pass_count
}
else {
    display as error "  FAIL: B1 set/query/get borderstyle (rc=`=_rc')"
    local ++fail_count
}
capture log close _ts240q

**# B2: clear one key, clear all, and validation as the option validates
local ++test_count
capture noisily {
    tabtools set borderstyle academic
    tabtools set borderstyle clear
    assert "`r(action)'" == "cleared" & "`r(key)'" == "borderstyle"
    assert `"$TABTOOLS_BORDER"' == ""
    tabtools query
    assert `"`r(borderstyle)'"' == ""
    * clearing one key leaves the others
    tabtools set smallcells 5
    tabtools set borderstyle thin
    tabtools set borderstyle clear
    tabtools query
    assert `"`r(smallcells)'"' == "5" & `"`r(borderstyle)'"' == ""
    * tabtools set clear removes it with the rest
    tabtools set borderstyle medium
    tabtools set clear
    tabtools query
    assert `"`r(borderstyle)'"' == "" & `"`r(smallcells)'"' == ""
    * clear cannot go to a profile
    capture tabtools set borderstyle clear, permanent
    assert _rc == 198
    * the values borderstyle() refuses are refused here, and leave the
    * session value as it was
    tabtools set borderstyle medium
    sysuse auto, clear
    foreach bad in Medium THIN thick none bogus {
        capture tabtools set borderstyle `bad'
        local rc_set = _rc
        capture crosstab rep78 foreign, xlsx("`output_dir'/ts240_bad.xlsx") sheet("x") borderstyle(`bad')
        local rc_opt = _rc
        assert `rc_set' == 198 & `rc_opt' == 198
        assert `"$TABTOOLS_BORDER"' == "medium"
    }
    capture tabtools set borderstyle
    assert _rc == 198
    assert `"$TABTOOLS_BORDER"' == "medium"
    * and every value the option takes is taken
    foreach ok in default thin medium academic {
        tabtools set borderstyle `ok'
        assert `"`r(borderstyle)'"' == "`ok'"
    }
    tabtools set clear
}
if _rc == 0 {
    display as result "  PASS: B2 clear/one key/all keys; values validated as the option"
    local ++pass_count
}
else {
    display as error "  FAIL: B2 clear and validation (rc=`=_rc')"
    local ++fail_count
}
capture tabtools set clear

**# B3: precedence in crosstab: option > session > thin
local ++test_count
capture noisily {
    local book "`output_dir'/ts240_cross.xlsx"
    capture erase "`book'"
    sysuse auto, clear
    tabtools set clear
    crosstab rep78 foreign, xlsx("`book'") sheet("none")
    _ts240_count "`book'" "none" left thin
    local thin0 = r(n)
    assert `thin0' > 0
    _ts240_count "`book'" "none" left medium
    assert r(n) == 0
    * session medium: medium rules, no thin left rules
    tabtools set borderstyle medium
    crosstab rep78 foreign, xlsx("`book'") sheet("sess")
    _ts240_count "`book'" "sess" left medium
    assert r(n) == `thin0'
    _ts240_count "`book'" "sess" left thin
    assert r(n) == 0
    * explicit thin beats the session medium
    crosstab rep78 foreign, xlsx("`book'") sheet("opt") borderstyle(thin)
    _ts240_count "`book'" "opt" left thin
    assert r(n) == `thin0'
    _ts240_count "`book'" "opt" left medium
    assert r(n) == 0
    * session academic: no vertical rules; explicit medium restores them
    tabtools set borderstyle academic
    crosstab rep78 foreign, xlsx("`book'") sheet("acad")
    _ts240_count "`book'" "acad" left ""
    assert r(n) == 0
    _ts240_count "`book'" "acad" right ""
    assert r(n) == 0
    crosstab rep78 foreign, xlsx("`book'") sheet("acadopt") borderstyle(medium)
    _ts240_count "`book'" "acadopt" left medium
    assert r(n) == `thin0'
    * cleared: back to thin
    tabtools set borderstyle clear
    crosstab rep78 foreign, xlsx("`book'") sheet("back")
    _ts240_count "`book'" "back" left thin
    assert r(n) == `thin0'
}
if _rc == 0 {
    display as result "  PASS: B3 crosstab: borderstyle() > session borderstyle > thin"
    local ++pass_count
}
else {
    display as error "  FAIL: B3 crosstab precedence (rc=`=_rc')"
    local ++fail_count
}
capture tabtools set clear

**# B4: precedence in ratetab (stratetab writer) and puttab
local ++test_count
capture noisily {
    local book "`output_dir'/ts240_rate.xlsx"
    capture erase "`book'"
    clear
    quietly set obs 8
    gen byte g = 1 + (_n > 4)
    gen long ev = mod(_n, 3)
    gen double pt = 1 + _n
    tabtools set clear
    ratetab g, events(ev) exposure(pt) xlsx("`book'") sheet("none")
    _ts240_count "`book'" "none" left thin
    local thin0 = r(n)
    assert `thin0' > 0
    tabtools set borderstyle medium
    ratetab g, events(ev) exposure(pt) xlsx("`book'") sheet("sess")
    _ts240_count "`book'" "sess" left medium
    assert r(n) == `thin0'
    _ts240_count "`book'" "sess" left thin
    assert r(n) == 0
    ratetab g, events(ev) exposure(pt) xlsx("`book'") sheet("opt") borderstyle(thin)
    _ts240_count "`book'" "opt" left thin
    assert r(n) == `thin0'
    _ts240_count "`book'" "opt" left medium
    assert r(n) == 0
    * puttab
    sysuse auto, clear
    local pbook "`output_dir'/ts240_put.xlsx"
    capture erase "`pbook'"
    puttab make price mpg in 1/3 using "`pbook'", sheet("sess")
    _ts240_count "`pbook'" "sess" left medium
    assert r(n) > 0
    _ts240_count "`pbook'" "sess" left thin
    assert r(n) == 0
    puttab make price mpg in 1/3 using "`pbook'", sheet("opt") borderstyle(thin)
    _ts240_count "`pbook'" "opt" left medium
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: B4 ratetab and puttab: borderstyle() > session borderstyle"
    local ++pass_count
}
else {
    display as error "  FAIL: B4 ratetab/puttab precedence (rc=`=_rc')"
    local ++fail_count
}
capture tabtools set clear

**# B5: an invalid session value is reported as the session's; the option still wins
local ++test_count
capture noisily {
    sysuse auto, clear
    local book "`output_dir'/ts240_inv.xlsx"
    capture erase "`book'"
    global TABTOOLS_BORDER "bogus"
    local con "`output_dir'/ts240_inv.txt"
    log using "`con'", text replace name(_ts240i)
    capture noisily crosstab rep78 foreign, xlsx("`book'") sheet("x")
    local rc1 = _rc
    log close _ts240i
    assert `rc1' == 198
    mata: st_local("_n", strofreal(sum(strpos(cat(st_local("con")), `"session borderstyle "bogus" is not valid"') :> 0)))
    assert `_n' == 1
    crosstab rep78 foreign, xlsx("`book'") sheet("y") borderstyle(medium)
    _ts240_count "`book'" "y" left medium
    assert r(n) > 0
    global TABTOOLS_BORDER
}
if _rc == 0 {
    display as result "  PASS: B5 invalid session borderstyle named; explicit option wins"
    local ++pass_count
}
else {
    display as error "  FAIL: B5 invalid session value (rc=`=_rc')"
    local ++fail_count
}
capture log close _ts240i
global TABTOOLS_BORDER

**# B6: permanent saves it to a profile; use loads it back
local ++test_count
capture noisily {
    local prof "`output_dir'/ts240_profile.do"
    capture erase "`prof'"
    tabtools set borderstyle academic, permanent profile("`prof'")
    assert "`r(permanent)'" == "permanent"
    mata: st_local("_n", strofreal(sum(cat(st_local("prof")) :== "tabtools set borderstyle academic")))
    assert `_n' == 1
    tabtools set clear
    assert `"$TABTOOLS_BORDER"' == ""
    tabtools use using "`prof'"
    tabtools query
    assert `"`r(borderstyle)'"' == "academic"
    tabtools set clear
}
if _rc == 0 {
    display as result "  PASS: B6 borderstyle saved by permanent and reloaded by use"
    local ++pass_count
}
else {
    display as error "  FAIL: B6 permanent profile (rc=`=_rc')"
    local ++fail_count
}
capture tabtools set clear

**# B7: the help-file example runs as written
local ++test_count
capture noisily {
    local here "`c(pwd)'"
    cd "`output_dir'"
    capture erase "tables.xlsx"
    tabtools set borderstyle academic
    tabtools query
    sysuse auto, clear
    crosstab rep78 foreign, xlsx(tables.xlsx) sheet("Academic")
    crosstab rep78 foreign, xlsx(tables.xlsx) sheet("Boxed") borderstyle(thin)
    tabtools set borderstyle clear
    cd "`here'"
    _ts240_count "`output_dir'/tables.xlsx" "Academic" left ""
    assert r(n) == 0
    _ts240_count "`output_dir'/tables.xlsx" "Boxed" left thin
    assert r(n) > 0
}
if _rc == 0 {
    display as result "  PASS: B7 help example"
    local ++pass_count
}
else {
    display as error "  FAIL: B7 help example (rc=`=_rc')"
    local ++fail_count
}
capture cd "`qa_dir'"
capture tabtools set clear

display "RESULT: test_tabtools_set_v240 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _ts240
if `fail_count' > 0 exit 1
