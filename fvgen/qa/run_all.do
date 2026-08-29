*! run_all.do — Curated QA lane runner for fvgen
*! Author: Timothy P Copeland, Karolinska Institutet
*! Requires: Stata 16.0+
*
* Usage (from fvgen/qa/):
*   stata-mp -b do run_all.do          // full release gate (default)
*   stata-mp -b do run_all.do quick    // fastest functional smoke
*   stata-mp -b do run_all.do core     // functional + errors + validation
*
* Lanes are explicit suite lists (never a glob). quick is a subset of core,
* which is a subset of full. Each suite emits a reconciled RESULT sentinel.

version 16.0

args mode extra
if "`mode'" == "" local mode "full"

if "`extra'" != "" {
    display as error "run_all.do accepts at most one lane argument"
    exit 198
}

local valid "quick core full"
if !`: list mode in valid' {
    display as error "unknown lane '`mode'' (choose: `valid')"
    exit 198
}

local quick "test_fvgen"
local core  "`quick' test_ref test_simple test_errors test_provenance test_margins test_regressions test_fvgen_hostile test_fvgen_oracle validation_fvgen"
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
    tempfile suite_log
    capture log close _fvgen_suite
    log using "`suite_log'", text replace name(_fvgen_suite) nomsg
    capture noisily do "`s'.do"
    local suite_rc = _rc
    capture log close _fvgen_suite

    local result_count = 0
    local result_name ""
    local result_tests = .
    local result_pass = .
    local result_fail = .
    local result_skip = 0
    capture quietly infix str244 result_line 1-244 using "`suite_log'", clear
    local read_rc = _rc
    if !`read_rc' {
        local result_pattern "^RESULT: ([A-Za-z0-9_]+) tests=([0-9]+) pass=([0-9]+) fail=([0-9]+)$"
        local skip_pattern "^RESULT: ([A-Za-z0-9_]+) tests=([0-9]+) pass=([0-9]+) fail=([0-9]+) skip=([0-9]+)$"
        quietly generate byte result_match = regexm(result_line, "`result_pattern'")
        quietly generate byte skip_match = regexm(result_line, "`skip_pattern'")
        quietly generate str32 parsed_name = ""
        quietly generate double parsed_tests = .
        quietly generate double parsed_pass = .
        quietly generate double parsed_fail = .
        quietly generate double parsed_skip = .
        quietly replace parsed_name = regexs(1) if regexm(result_line, "`result_pattern'")
        quietly replace parsed_tests = real(regexs(2)) if regexm(result_line, "`result_pattern'")
        quietly replace parsed_pass = real(regexs(3)) if regexm(result_line, "`result_pattern'")
        quietly replace parsed_fail = real(regexs(4)) if regexm(result_line, "`result_pattern'")
        quietly replace parsed_skip = 0 if result_match
        quietly replace parsed_name = regexs(1) if regexm(result_line, "`skip_pattern'")
        quietly replace parsed_tests = real(regexs(2)) if regexm(result_line, "`skip_pattern'")
        quietly replace parsed_pass = real(regexs(3)) if regexm(result_line, "`skip_pattern'")
        quietly replace parsed_fail = real(regexs(4)) if regexm(result_line, "`skip_pattern'")
        quietly replace parsed_skip = real(regexs(5)) if regexm(result_line, "`skip_pattern'")
        quietly count if result_match | skip_match
        local result_count = r(N)
        if `result_count' == 1 {
            quietly levelsof parsed_name if result_match | skip_match, local(result_name) clean
            quietly summarize parsed_tests if result_match | skip_match, meanonly
            local result_tests = r(min)
            quietly summarize parsed_pass if result_match | skip_match, meanonly
            local result_pass = r(min)
            quietly summarize parsed_fail if result_match | skip_match, meanonly
            local result_fail = r(min)
            quietly summarize parsed_skip if result_match | skip_match, meanonly
            local result_skip = r(min)
        }
    }

    local contract_bad = (`read_rc' != 0 | `result_count' != 1)
    if !`contract_bad' {
        if "`result_name'" != "`s'" local contract_bad = 1
        if missing(`result_tests', `result_pass', `result_fail', `result_skip') local contract_bad = 1
        if `result_tests' != `result_pass' + `result_fail' + `result_skip' local contract_bad = 1
        if (`result_fail' > 0) != (`suite_rc' != 0) local contract_bad = 1
        if "`mode'" == "full" & `result_skip' > 0 local contract_bad = 1
    }

    if `contract_bad' {
        display as error "  [FAIL] `s' (missing, duplicate, malformed, or inconsistent RESULT sentinel)"
        local ++n_fail
        local failed "`failed' `s'"
    }
    else if `suite_rc' == 0 {
        display as result "  [OK]   `s'"
    }
    else {
        display as error  "  [FAIL] `s' (rc=`suite_rc')"
        local ++n_fail
        local failed "`failed' `s'"
    }
}

display as text "Suites: `=`n_suite'-`n_fail''/`n_suite' passed"
if `n_fail' > 0 {
    display as error "FAILED LANES:`failed'"
    exit 1
}
display as result "ALL SUITES PASSED (lane: `mode')"
