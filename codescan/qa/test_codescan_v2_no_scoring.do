* test_codescan_v2_no_scoring.do — asserts comorbidity scoring is gone from codescan v2.0.
version 16.0

* Install the local package copy so an installed build cannot shadow it.
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall codescan
quietly net install codescan, from("`pkg_dir'") replace

clear
input long pid str6 dx1
1 "E119"
2 "I50"
end
local fail 0

* score() must no longer be a valid option
capture codescan dx1, define(dm "E11") id(pid) collapse score(charlson)
if _rc != 198 {
    display as error "FAIL: score() still accepted (rc=`=_rc', expected 198)"
    local fail 1
}
* hierarchy() must no longer be a valid option
capture codescan dx1, define(dm "E11" | dm2 "E10") id(pid) collapse hierarchy(dm > dm2)
if _rc != 198 {
    display as error "FAIL: hierarchy() still accepted (rc=`=_rc', expected 198)"
    local fail 1
}
* basename codefile resolution must be gone (file genuinely not found -> 601)
capture codescan dx1, codefile(charlson_icd10_example.csv) id(pid) collapse
if _rc != 601 {
    display as error "FAIL: basename codefile still resolved (rc=`=_rc', expected 601)"
    local fail 1
}
* core scanning still works
codescan dx1, define(dm "E11" | chf "I50") id(pid) collapse
assert r(n_conditions) == 2

if `fail' {
    display as error "RESULT: test_codescan_v2_no_scoring FAILED"
    exit 9
}
display as result "RESULT: test_codescan_v2_no_scoring PASSED"
