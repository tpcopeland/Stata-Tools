* Hostile public-input contracts for pkgtransfer.
version 16.0
clear all
set varabbrev off
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa/?$", "")
run "`qa_dir'/_pkgtransfer_qa_common.do"
_pkgtransfer_qa_setup, pkgdir("`pkg_dir'")
local root `"`r(root)'"'
local original_plus `"`r(original_plus)'"'
local original_personal `"`r(original_personal)'"'
local tests = 0
local pass = 0
local fail = 0
set linesize 255
tempfile msglog
local expected_1 = 198
local expected_2 = 198
local expected_3 = 111
local msg_1 "Error: dofile() contains invalid characters"
local msg_2 "Error: zipfile() contains invalid characters"
local msg_3 "Error: package 'zzz_nonexistent_pkg_12345' not found"
foreach call in `"dofile(bad;name.do)"' `"zipfile(bad|name.zip)"' `"limited(zzz_nonexistent_pkg_12345)"' {
    local ++tests
    log using "`msglog'", text replace name(hostmsg)
    capture noisily pkgtransfer, `call'
    local call_rc = _rc
    log close hostmsg
    local seen = strpos(fileread("`msglog'"), "`msg_`tests''") > 0
    if `call_rc' == `expected_`tests'' & `seen' local ++pass
    else {
        local ++fail
        display as error "FAIL: `call' rc=`call_rc' message_seen=`seen'"
    }
}
_pkgtransfer_qa_cleanup, root("`root'") originalplus("`original_plus'") originalpersonal("`original_personal'")
display "RESULT: test_pkgtransfer_hostile tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' > 0 exit 1
