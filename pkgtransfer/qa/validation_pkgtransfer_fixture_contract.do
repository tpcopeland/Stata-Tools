*! validation_pkgtransfer_fixture_contract.do -- canonical labelled designs and independent contents
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using "validation_pkgtransfer_fixture_contract.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
* The source directory goes first on the adopath for this suite only. $S_ADO
* (the adopath itself) is restored exactly on every exit path below, so later
* suites in the lane do not resolve pkgtransfer from this source tree. The body
* runs captured so an abort still reaches that restore and the sysdir cleanup.
local saved_s_ado `"$S_ADO"'
local transferroot ""
local tests 0
local pass 0
local fail 0
adopath ++ "`pkg_dir'"
capture noisily {
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0
do _pkgtransfer_qa_common.do
_pkgtransfer_qa_setup, pkgdir("`pkg_dir'")
local transferroot `"`r(root)'"'
local originalplus `"`r(original_plus)'"'
local originalpersonal `"`r(original_personal)'"'

**# Exact installer or refused path friendly
local ++tests
capture noisily {
    local root ""
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    local output `"`macval(root)'/transfer.do"'
    quietly pkgtransfer, limited(alpha fre) dofile(`"`macval(output)'"')
    assert r(N_packages)==2 & "`r(package_list)'"=="alpha fre"
    local actual `"`r(dofile)'"'
    python: _p=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("actual")); _t=_p.read_text(); assert "ssc install fre" in _t and "net install alpha" in _t and "https://example.org/alpha" in _t and "install pkgtransfer" not in _t

}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Exact installer or refused path friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Exact installer or refused path friendly"
}

**# Exact installer or refused path path_hostile
local ++tests
capture noisily {
    local root ""
    * expect: REFUSED
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    qa_state_snapshot, tag(pt_path)
    capture noisily pkgtransfer, limited(alpha fre) dofile(`"`macval(output)'"')
    assert _rc==198
    qa_state_compare, tag(pt_path)

}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Exact installer or refused path path_hostile; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Exact installer or refused path path_hostile"
}

**# Exact installer or refused path path_noext
local ++tests
capture noisily {
    local root ""
    * expect: REFUSED
    qa_fx_a7_files, clear seed(37) perturb(path_noext)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    qa_state_snapshot, tag(pt_noext)
    capture noisily pkgtransfer, limited(alpha fre) dofile(`"`macval(output)'"')
    assert _rc==198
    qa_state_compare, tag(pt_noext)
    python: assert __import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text()=="EXTENSIONLESS_KEEP\n"

}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Exact installer or refused path path_noext; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Exact installer or refused path path_noext"
}
_pkgtransfer_qa_cleanup, root(`"`macval(transferroot)'"') originalplus(`"`macval(originalplus)'"') originalpersonal(`"`macval(originalpersonal)'"')

}
local body_rc = _rc
global S_ADO `"`saved_s_ado'"'
if `body_rc' {
    display as error "suite body aborted (rc=`body_rc')"
    local ++tests
    local ++fail
    if `"`transferroot'"' != "" {
        capture noisily _pkgtransfer_qa_cleanup, root(`"`transferroot'"') originalplus(`"`originalplus'"') originalpersonal(`"`originalpersonal'"')
    }
}
display "RESULT: validation_pkgtransfer_fixture_contract tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
