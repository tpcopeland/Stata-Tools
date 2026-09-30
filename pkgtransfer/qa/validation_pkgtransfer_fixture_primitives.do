*! validation_pkgtransfer_fixture_primitives.do -- exact installer content and hostile caller data
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using validation_pkgtransfer_fixture_primitives.log,text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_hostile.do
do _qa_state.do
do _pkgtransfer_qa_common.do
_pkgtransfer_qa_setup, pkgdir("`pkg_dir'")
local transferroot `"`r(root)'"'
local originalplus `"`r(original_plus)'"'
local originalpersonal `"`r(original_personal)'"'
local tests 0
local pass 0
local fail 0

**# Installer content and caller names
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local output `"`macval(root)'/transfer.do"'
    * The installed-package tracker is the command input. This independently
    * hostile caller dataset must survive the read-only installer writer.
    * expect: INVARIANT
    qa_hostile_names, clear
    qa_state_snapshot, tag(pkg_primitive)
    quietly pkgtransfer, limited(alpha fre) dofile(`"`macval(output)'"')
    assert r(N_packages)==2 & "`r(package_list)'"=="alpha fre"
    assert `"`r(dofile)'"'==`"`macval(output)'"'
    qa_state_compare, tag(pkg_primitive)
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text(); assert _t.count("ssc install fre")==1 and _t.count("net install alpha")==1 and "https://example.org/alpha" in _t and "install pkgtransfer" not in _t and "EXPANDED" not in _t
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

**# Installer content and caller codes
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local output `"`macval(root)'/transfer.do"'
    * The installed-package tracker is the command input. This independently
    * hostile caller dataset must survive the read-only installer writer.
    * expect: INVARIANT
    qa_hostile_codes, clear
    qa_state_snapshot, tag(pkg_primitive)
    quietly pkgtransfer, limited(alpha fre) dofile(`"`macval(output)'"')
    assert r(N_packages)==2 & "`r(package_list)'"=="alpha fre"
    assert `"`r(dofile)'"'==`"`macval(output)'"'
    qa_state_compare, tag(pkg_primitive)
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text(); assert _t.count("ssc install fre")==1 and _t.count("net install alpha")==1 and "https://example.org/alpha" in _t and "install pkgtransfer" not in _t and "EXPANDED" not in _t
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

**# Installer content and caller label_gaps
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local output `"`macval(root)'/transfer.do"'
    * The installed-package tracker is the command input. This independently
    * hostile caller dataset must survive the read-only installer writer.
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    qa_state_snapshot, tag(pkg_primitive)
    quietly pkgtransfer, limited(alpha fre) dofile(`"`macval(output)'"')
    assert r(N_packages)==2 & "`r(package_list)'"=="alpha fre"
    assert `"`r(dofile)'"'==`"`macval(output)'"'
    qa_state_compare, tag(pkg_primitive)
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text(); assert _t.count("ssc install fre")==1 and _t.count("net install alpha")==1 and "https://example.org/alpha" in _t and "install pkgtransfer" not in _t and "EXPANDED" not in _t
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

**# Installer content and caller miss_all_column
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local output `"`macval(root)'/transfer.do"'
    * The installed-package tracker is the command input. This independently
    * hostile caller dataset must survive the read-only installer writer.
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    qa_state_snapshot, tag(pkg_primitive)
    quietly pkgtransfer, limited(alpha fre) dofile(`"`macval(output)'"')
    assert r(N_packages)==2 & "`r(package_list)'"=="alpha fre"
    assert `"`r(dofile)'"'==`"`macval(output)'"'
    qa_state_compare, tag(pkg_primitive)
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text(); assert _t.count("ssc install fre")==1 and _t.count("net install alpha")==1 and "https://example.org/alpha" in _t and "install pkgtransfer" not in _t and "EXPANDED" not in _t
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

**# Installer content and caller single_row
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local output `"`macval(root)'/transfer.do"'
    * The installed-package tracker is the command input. This independently
    * hostile caller dataset must survive the read-only installer writer.
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    qa_state_snapshot, tag(pkg_primitive)
    quietly pkgtransfer, limited(alpha fre) dofile(`"`macval(output)'"')
    assert r(N_packages)==2 & "`r(package_list)'"=="alpha fre"
    assert `"`r(dofile)'"'==`"`macval(output)'"'
    qa_state_compare, tag(pkg_primitive)
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text(); assert _t.count("ssc install fre")==1 and _t.count("net install alpha")==1 and "https://example.org/alpha" in _t and "install pkgtransfer" not in _t and "EXPANDED" not in _t
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

**# Installer content and caller strings
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local output `"`macval(root)'/transfer.do"'
    * The installed-package tracker is the command input. This independently
    * hostile caller dataset must survive the read-only installer writer.
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    local corpus `r(names)'
    generate strL caption=""
    local row=0
    foreach g of local corpus {
        local ++row
        mata: st_sstore(strtoreal(st_local("row")),"caption",st_global(st_local("g")))
    }
    qa_state_snapshot, tag(pkg_primitive)
    quietly pkgtransfer, limited(alpha fre) dofile(`"`macval(output)'"')
    assert r(N_packages)==2 & "`r(package_list)'"=="alpha fre"
    assert `"`r(dofile)'"'==`"`macval(output)'"'
    qa_state_compare, tag(pkg_primitive)
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text(); assert _t.count("ssc install fre")==1 and _t.count("net install alpha")==1 and "https://example.org/alpha" in _t and "install pkgtransfer" not in _t and "EXPANDED" not in _t
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

capture noisily _pkgtransfer_qa_cleanup, root(`"`transferroot'"') originalplus(`"`originalplus'"') originalpersonal(`"`originalpersonal'"')
if _rc {
    local ++tests
    local ++fail
}
display "RESULT: validation_pkgtransfer_fixture_primitives tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
