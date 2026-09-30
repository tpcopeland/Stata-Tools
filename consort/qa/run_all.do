* consort QA runner, 2026-09-29
* Author: Timothy P Copeland, Karolinska Institutet
version 16.0
args mode
if "`mode'" == "" local mode "full"
if !inlist("`mode'", "quick", "core", "full") exit 198
capture log close _all
log using run_all.log, text replace
local oldplus "`c(sysdir_plus)'"
local oldpersonal "`c(sysdir_personal)'"
tempfile sandbox_base
local sandbox "`sandbox_base'_consort_sandbox"
capture mkdir "`sandbox'"
capture mkdir "`sandbox'/plus"
capture mkdir "`sandbox'/personal"
sysdir set PLUS "`sandbox'/plus"
sysdir set PERSONAL "`sandbox'/personal"
ado dir
capture ado uninstall consort
local suites "test_consort_v112 test_consort_help"
if inlist("`mode'", "core", "full") local suites "`suites' validation_consort_fixture_contract test_consort test_consort_v104 test_consort_v106 test_consort_v110 validation_consort"
if "`mode'" == "full" local suites "`suites' test_consort_expanded test_consort_edge_cases validation_consort_expanded"
local failed 0
local passed 0
local skipped 0
foreach suite of local suites {
    local skip_reason ""
    capture confirm file "_skip.txt"
    if !_rc {
        tempname skipfh
        file open `skipfh' using "_skip.txt", read text
        file read `skipfh' line
        while r(eof) == 0 {
            local bar = strpos(`"`macval(line)'"', "|")
            if `bar' > 0 {
                local skipfile = trim(substr(`"`macval(line)'"', 1, `bar' - 1))
                if "`skipfile'" == "`suite'.do" {
                    local skip_reason = trim(substr(`"`macval(line)'"', `bar' + 1, .))
                }
            }
            file read `skipfh' line
        }
        file close `skipfh'
    }
    if `"`macval(skip_reason)'"' != "" {
        local ++skipped
        display `"RESULT: `suite' tests=0 pass=0 fail=0 skip=0 skipped=`macval(skip_reason)'"'
        continue
    }
    capture noisily do `suite'.do
    local rc = _rc
    if `rc' local ++failed
    else local ++passed
    display "SUITE: `suite' rc=`rc'"
}
sysdir set PLUS "`oldplus'"
sysdir set PERSONAL "`oldpersonal'"
tempname fh
file open `fh' using run_all_status.txt, write replace text
file write `fh' "mode=`mode' pass=`passed' fail=`failed' skip=`skipped'" _n
file close `fh'
display "RESULT: run_all tests=`= `passed' + `failed' + `skipped'' pass=`passed' fail=`failed' skip=`skipped'"
log close
if `failed' exit 1
