* Hostile public-input contracts for pkgtransfer.
version 16.0
clear all
set varabbrev off
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall pkgtransfer
run "`qa_dir'/_pkgtransfer_qa_common.do"
_pkgtransfer_qa_setup, pkgdir("`pkg_dir'")
local root `"`r(root)'"'
local original_plus `"`r(original_plus)'"'
local original_personal `"`r(original_personal)'"'
local tests = 0
local pass = 0
local fail = 0
local expected_1 = 198
local expected_2 = 198
local expected_3 = 111
foreach call in `"dofile(bad;name.do)"' `"zipfile(bad|name.zip)"' `"limited(zzz_nonexistent_pkg_12345)"' {
    local ++tests
    capture noisily pkgtransfer, `call'
    local call_rc = _rc
    if `call_rc' == `expected_`tests'' local ++pass
    else local ++fail
}
_pkgtransfer_qa_cleanup, root("`root'") originalplus("`original_plus'") originalpersonal("`original_personal'")
display "RESULT: test_pkgtransfer_hostile tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' > 0 exit 1
