* Focused public parser/error contracts for pkgtransfer.
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
local call_1 `"download(invalid)"'
local msg_1 "Error: Invalid download() specification."
local call_2 `"os(NoSuchOS)"'
local msg_2 "Error: Invalid os() specification."
local call_3 `"dofile(not_a_do.txt)"'
local msg_3 "Do file name must end with '.do' extension"
local call_4 `"download(online) zipfile(not_a_zip.tar)"'
local msg_4 "ZIP file name must end with '.zip' extension"
local call_5 `"zipfile(valid_name.zip)"'
local msg_5 "Only ZIP file name if downloading data"
forvalues i = 1/5 {
    local ++tests
    log using "`msglog'", text replace name(errmsg)
    capture noisily pkgtransfer, `call_`i''
    local call_rc = _rc
    log close errmsg
    local seen = strpos(fileread("`msglog'"), "`msg_`i''") > 0
    if `call_rc' == 198 & `seen' local ++pass
    else {
        local ++fail
        display as error "FAIL: `call_`i'' rc=`call_rc' message_seen=`seen'"
    }
}
_pkgtransfer_qa_cleanup, root("`root'") originalplus("`original_plus'") originalpersonal("`original_personal'")
display "RESULT: test_pkgtransfer_errors tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' > 0 exit 1
