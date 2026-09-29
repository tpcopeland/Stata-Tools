/*
    File: test_pkgtransfer_isolation.do
    Purpose: Verify that error suites preserve a real caller installation
    Author: Timothy P Copeland, Karolinska Institutet
    Date: 2026-09-29
*/
version 16.0
capture log close _all
local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local original_plus "`c(sysdir_plus)'"
local original_personal "`c(sysdir_personal)'"
tempfile marker
local root "`marker'_outer"
mkdir "`root'"
mkdir "`root'/plus"
mkdir "`root'/personal"
sysdir set PLUS "`root'/plus"
sysdir set PERSONAL "`root'/personal"
local tests 0
local pass 0
local fail 0
foreach suite in errors hostile {
    local ++tests
    capture noisily {
        clear
        ado dir
        net install pkgtransfer, from("`pkg_dir'") replace
        copy "`root'/plus/stata.trk" "`root'/before.trk", replace
        quietly do "`qa_dir'/test_pkgtransfer_`suite'.do"
        confirm file "`root'/plus/p/pkgtransfer.ado"
        * Compare every byte of the installed descriptor and tracking file.
        mata: assert(cat("`root'/before.trk") == cat("`root'/plus/stata.trk"))
        mata: assert(cat("`pkg_dir'/pkgtransfer.ado") == cat("`root'/plus/p/pkgtransfer.ado"))
    }
    local rc = _rc
    if `rc' == 0 local ++pass
    else {
        local ++fail
        display as error "FAIL: caller installation after `suite' rc=`rc'"
    }
}
sysdir set PLUS "`original_plus'"
sysdir set PERSONAL "`original_personal'"
capture program drop pkgtransfer
run "`pkg_dir'/pkgtransfer.ado"
_pkgtransfer_cleanup_staging, directory("`root'")
capture log close _all
display "RESULT: test_pkgtransfer_isolation tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' exit 1
