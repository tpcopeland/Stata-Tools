*! Literal path examples from massdesas.sthlp; intentionally red if paths fail
*! Date: 2026-08-23

clear all
set varabbrev off
version 14.0

do "_massdesas_qa_common.do"
quietly _massdesas_qa_bootstrap
local test_count = 0
local pass_count = 0
local fail_count = 0

* These are the help-file command lines, not repaired test paths.
local ++test_count
capture noisily {
    massdesas, directory("C:/Data/SAS_Files")
    assert r(n_converted) > 0 & r(n_failed) == 0
}
if _rc == 0 local ++pass_count
else local ++fail_count

local ++test_count
capture noisily {
    massdesas, directory("C:/Data/SAS_Files") lower
    assert r(n_converted) > 0 & r(n_failed) == 0
}
if _rc == 0 local ++pass_count
else local ++fail_count

local ++test_count
capture noisily {
    massdesas, directory("C:/Data/SAS_Files_Backup") lower
    assert r(n_converted) > 0 & r(n_failed) == 0
    use "C:/Data/SAS_Files_Backup/dataset1.dta", clear
    describe
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_massdesas_documentation_exact tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 exit 1
