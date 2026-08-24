* Focused public parser/error contracts for pkgtransfer.
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
foreach call in `"download(invalid)"' `"os(NoSuchOS)"' `"dofile(not_a_do.txt)"' `"zipfile(not_a_zip.tar)"' {
    local ++tests
    capture noisily pkgtransfer, `call'
    local call_rc = _rc
    if `call_rc' == 198 local ++pass
    else local ++fail
}
_pkgtransfer_qa_cleanup, root("`root'") originalplus("`original_plus'") originalpersonal("`original_personal'")
display "RESULT: test_pkgtransfer_errors tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' > 0 exit 1
