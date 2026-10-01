*! run_all.do -- curated compress_tc QA lanes
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
set processors 1
args mode extra
if "`mode'"=="" local mode full
if "`extra'"!="" | !inlist("`mode'","quick","core","full") exit 198
local oldplus `"`c(sysdir_plus)'"'
local oldpersonal `"`c(sysdir_personal)'"'
tempfile sandbox
capture mkdir "`sandbox'_plus"
capture mkdir "`sandbox'_personal"
sysdir set PLUS "`sandbox'_plus"
sysdir set PERSONAL "`sandbox'_personal"
local quick "test_compress_tc test_compress_tc_errors test_compress_tc_hostile test_compress_tc_documentation_examples"
local core "`quick' validation_compress_tc_precision validation_compress_tc validation_compress_tc_fixture_contract validation_compress_tc_fixture_primitives"
local full "`core' crossval_compress_tc test_compress_tc_oracle"
local tests 0
local pass 0
local fail 0
foreach suite in ``mode'' {
    local ++tests
    capture noisily do `suite'.do
    if _rc local ++fail
    else local ++pass
}
sysdir set PLUS `"`oldplus'"'
sysdir set PERSONAL `"`oldpersonal'"'
display "RESULT: run_all tests=`tests' pass=`pass' fail=`fail'"
if `fail' exit 1
