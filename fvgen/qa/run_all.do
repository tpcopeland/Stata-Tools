* run_all.do — curated QA lane runner for fvgen.
*
* Usage (from fvgen/qa/):
*   stata-mp -b do run_all.do          // full release gate (default)
*   stata-mp -b do run_all.do quick    // fastest functional smoke
*   stata-mp -b do run_all.do core     // functional + errors + validation
*
* Lanes are explicit suite lists (never a glob). quick subset of core subset
* of full. Each suite is self-contained (sandboxes its own install) and emits a
* RESULT: sentinel; this runner reports suite-level pass/fail and exits 1 on any
* failure.

version 16.0

args mode
if "`mode'" == "" local mode "full"

local valid "quick core full"
if !`: list mode in valid' {
    display as error "unknown lane '`mode'' (choose: `valid')"
    exit 198
}

local quick "test_fvgen"
local core  "`quick' test_ref test_simple test_errors test_provenance validation_fvgen"
local full  "`core' test_package_release"

local suites "``mode''"

display as text "fvgen QA — lane: `mode'"

do _fvgen_qa_common.do
_fvgen_qa_bootstrap

local n_suite = 0
local n_fail  = 0
local failed  ""
foreach s of local suites {
    local ++n_suite
    capture log close
    capture noisily do "`s'.do"
    if _rc == 0 {
        display as result "  [OK]   `s'"
    }
    else {
        display as error  "  [FAIL] `s' (rc=`=_rc')"
        local ++n_fail
        local failed "`failed' `s'"
    }
}
capture log close

display as text "Suites: `=`n_suite'-`n_fail''/`n_suite' passed"
if `n_fail' > 0 {
    display as error "FAILED LANES:`failed'"
    exit 1
}
display as result "ALL SUITES PASSED (lane: `mode')"
