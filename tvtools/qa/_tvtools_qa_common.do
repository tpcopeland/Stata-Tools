*! _tvtools_qa_common.do
*! Shared QA scaffold for the tvtools suite.
*!
*! Every test_*/validation_*/crossval_* suite sources this file, then calls
*! _tvtools_qa_bootstrap. The first call sandboxes PLUS/PERSONAL under c(tmpdir),
*! installs tvtools from the package root, and copies tracked fixtures into a
*! private run workspace. Later calls are no-ops, so a runner process installs
*! and copies fixtures exactly once. This file also defines the result-contract
*! parser and shared assertion helpers.
*!
*! Run any suite standalone from qa/:  stata-mp -b do test_tvexpose.do
*! Run the whole suite:                stata-mp -b do run_all.do [lane]

version 16.0

**# Test-harness globals
if "$RUN_TEST_NUMBER" == "" global RUN_TEST_NUMBER 0
if "$RUN_TEST_QUIET"  == "" global RUN_TEST_QUIET 0
if "$TVTOOLS_QA_DATA" == "" global DATA_DIR "`c(pwd)'/data"
else global DATA_DIR "$TVTOOLS_QA_DATA"

**# Sandboxed install bootstrap
capture program drop _tvtools_qa_bootstrap
program define _tvtools_qa_bootstrap, rclass
    version 16.0

    local qa_dir "`c(pwd)'"
    local _qa_len = strlen("`qa_dir'")
    local pkg_dir = substr("`qa_dir'", 1, `_qa_len' - 3)

    if "$TVTOOLS_QA_BOOTSTRAPPED" == "1" {
        sysdir set PLUS "$TVTOOLS_QA_PLUS"
        sysdir set PERSONAL "$TVTOOLS_QA_PERSONAL"
        global DATA_DIR "$TVTOOLS_QA_DATA"
        return local qa_dir  "$TVTOOLS_QA_DIR"
        return local pkg_dir "$TVTOOLS_QA_PKG_DIR"
        exit
    }

    if "$TVTOOLS_QA_ISOLATED" == "" {
        tempfile _tvtools_qa_base
        local run_dir "`_tvtools_qa_base'_run"
        local plus_dir "`run_dir'/plus"
        local personal_dir "`run_dir'/personal"
        capture mkdir "`run_dir'"
        capture mkdir "`plus_dir'"
        capture mkdir "`personal_dir'"
        global TVTOOLS_QA_PLUS "`plus_dir'"
        global TVTOOLS_QA_PERSONAL "`personal_dir'"
        global TVTOOLS_QA_RUN_DIR "`run_dir'"
        global TVTOOLS_QA_ISOLATED "1"
    }

    sysdir set PLUS "$TVTOOLS_QA_PLUS"
    sysdir set PERSONAL "$TVTOOLS_QA_PERSONAL"

    capture ado uninstall tvtools
    quietly net install tvtools, from("`pkg_dir'") replace

    * Tracked fixtures are inputs, not build products. Missing source fixtures
    * are a hard failure; disposable outputs are written only to the run space.
    capture confirm file "`qa_dir'/data/cohort.dta"
    if _rc {
        display as error "required tracked fixture data/cohort.dta is missing"
        exit 601
    }

    global TVTOOLS_QA_DATA "$TVTOOLS_QA_RUN_DIR/data"
    capture mkdir "$TVTOOLS_QA_DATA"
    local fixture_files : dir "`qa_dir'/data" files "*"
    foreach fixture of local fixture_files {
        quietly copy "`qa_dir'/data/`fixture'" ///
            "$TVTOOLS_QA_DATA/`fixture'", replace
    }

    global TVTOOLS_QA_DIR "`qa_dir'"
    global TVTOOLS_QA_PKG_DIR "`pkg_dir'"
    global TVTOOLS_QA_BOOTSTRAPPED "1"
    global DATA_DIR "$TVTOOLS_QA_DATA"
    local bootstrap_count = cond("$TVTOOLS_QA_BOOTSTRAP_COUNT" == "", ///
        0, real("$TVTOOLS_QA_BOOTSTRAP_COUNT")) + 1
    global TVTOOLS_QA_BOOTSTRAP_COUNT "`bootstrap_count'"

    return local qa_dir  "`qa_dir'"
    return local pkg_dir "`pkg_dir'"
end

**# Result-contract and dependency helpers

capture mata: mata drop _tvtools_qa_scan_result()
mata:
void _tvtools_qa_scan_result(string scalar logfile)
{
    real scalar fh, result_lines, valid_lines, with_skip
    string scalar line, trimmed, parsed_suite, tests, pass, fail, skip

    fh = fopen(logfile, "r")
    result_lines = 0
    valid_lines = 0
    parsed_suite = ""
    tests = "."
    pass = "."
    fail = "."
    skip = "0"

    while ((line = fget(fh)) != J(0, 0, "")) {
        trimmed = strtrim(line)
        if (substr(trimmed, 1, 7) == "RESULT:") {
            result_lines++
            with_skip = regexm(trimmed,
                "^RESULT: ([A-Za-z0-9_]+) tests=([0-9]+) pass=([0-9]+) fail=([0-9]+) skip=([0-9]+)$")
            if (with_skip) {
                valid_lines++
                parsed_suite = regexs(1)
                tests = regexs(2)
                pass = regexs(3)
                fail = regexs(4)
                skip = regexs(5)
            }
            else if (regexm(trimmed,
                "^RESULT: ([A-Za-z0-9_]+) tests=([0-9]+) pass=([0-9]+) fail=([0-9]+)$")) {
                valid_lines++
                parsed_suite = regexs(1)
                tests = regexs(2)
                pass = regexs(3)
                fail = regexs(4)
                skip = "0"
            }
        }
    }
    fclose(fh)

    st_local("result_lines", strofreal(result_lines))
    st_local("valid_lines", strofreal(valid_lines))
    st_local("parsed_suite", parsed_suite)
    st_local("tests", tests)
    st_local("pass", pass)
    st_local("fail", fail)
    st_local("skip", skip)
}
end

capture program drop _tvtools_qa_validate_result
program define _tvtools_qa_validate_result, rclass
    version 16.0
    syntax, LOGFile(string) SUITE(string) EXPECTED(integer) [ALLOWSKIP REQUIREZEROSKIP]

    return scalar valid = 0
    return scalar tests = .
    return scalar pass = .
    return scalar fail = .
    return scalar skip = .
    return local reason "result log not found"

    capture confirm file `"`logfile'"'
    if _rc exit

    local result_lines = 0
    local valid_lines = 0
    local parsed_suite ""
    local tests = .
    local pass = .
    local fail = .
    local skip = 0

    mata: _tvtools_qa_scan_result(st_local("logfile"))

    return scalar tests = `tests'
    return scalar pass = `pass'
    return scalar fail = `fail'
    return scalar skip = `skip'
    return local parsed_suite "`parsed_suite'"

    if `result_lines' != 1 {
        return local reason "expected one RESULT line; found `result_lines'"
        exit
    }
    if `valid_lines' != 1 {
        return local reason "RESULT line is malformed"
        exit
    }
    if "`parsed_suite'" != "`suite'" {
        return local reason "suite name mismatch: `parsed_suite'"
        exit
    }
    if `tests' != `expected' {
        return local reason "test-count mismatch: got `tests', expected `expected'"
        exit
    }
    if `tests' != `pass' + `fail' + `skip' {
        return local reason "tests != pass + fail + skip"
        exit
    }
    if `fail' > 0 {
        return local reason "suite reported `fail' failed checks"
        exit
    }
    if `skip' > 0 & "`allowskip'" == "" {
        return local reason "suite reported disallowed skips"
        exit
    }
    if `skip' > 0 & "`requirezeroskip'" != "" {
        return local reason "full/release lane requires zero skips"
        exit
    }

    return scalar valid = 1
    return local reason "ok"
end

capture program drop _tvtools_qa_probe_rscript
program define _tvtools_qa_probe_rscript, rclass
    version 16.0
    local probe "$TVTOOLS_QA_RUN_DIR/_rscript_version.txt"
    capture erase "`probe'"
    quietly shell Rscript --version > "`probe'" 2>&1
    capture confirm file "`probe'"
    if _rc {
        return scalar available = 0
        exit
    }
    local content = lower(fileread("`probe'"))
    local available = strpos(`"`content'"', "rscript") > 0 & ///
        strpos(`"`content'"', "version") > 0 & ///
        strpos(`"`content'"', "not found") == 0 & ///
        strpos(`"`content'"', "not recognized") == 0
    return scalar available = `available'
end

capture program drop _tvtools_qa_rmtree
program define _tvtools_qa_rmtree
    version 16.0
    args path
    if `"`path'"' == "" exit
    capture local child_dirs : dir `"`path'"' dirs "*"
    foreach child of local child_dirs {
        _tvtools_qa_rmtree `"`path'/`child'"'
    }
    capture local files : dir `"`path'"' files "*"
    foreach file of local files {
        capture erase `"`path'/`file'"'
    }
    capture rmdir `"`path'"'
end

capture program drop _tvtools_qa_cleanup
program define _tvtools_qa_cleanup
    version 16.0
    if "$TVTOOLS_QA_RUN_DIR" == "" exit
    _tvtools_qa_rmtree "$TVTOOLS_QA_RUN_DIR"
end

**# Shared assertion and verification helpers
*
* These are also defined inline inside several suites. Defining them here is a
* safety net: every helper drops itself first, so the last definition wins.

* _run_test: print a test banner, honouring the RUN_TEST_* globals.
capture program drop _run_test
program define _run_test
    args test_num test_desc
    if $RUN_TEST_NUMBER > 0 & $RUN_TEST_NUMBER != `test_num' {
        exit 0
    }
    if $RUN_TEST_QUIET == 0 {
        display as text _n "TEST `test_num': `test_desc'"
        display as text "{hline 50}"
    }
end

* assert_exact: integer/exact equality assertion (aborts with rc 9 on failure).
capture program drop assert_exact
program define assert_exact
    args actual expected label
    if `actual' == `expected' {
        display as result "  PASS [`label']: value=`actual'"
    }
    else {
        display as error "  FAIL [`label']: actual=`actual', expected=`expected'"
        exit 9
    }
end

* assert_approx: tolerance-bounded equality assertion (aborts with rc 9).
capture program drop assert_approx
program define assert_approx
    args actual expected tolerance label
    local diff = abs(`actual' - `expected')
    if `diff' <= `tolerance' {
        display as result "  PASS [`label']: actual=`actual', expected=`expected', diff=`diff'"
    }
    else {
        display as error "  FAIL [`label']: actual=`actual', expected=`expected', diff=`diff' > tol=`tolerance'"
        exit 9
    }
end

* _validate_tvexpose_output: structural sanity checks on tvexpose output.
capture program drop _validate_tvexpose_output
program define _validate_tvexpose_output, rclass
    syntax, cohort_ids(integer) [tolerance(real 0.01) startvar(string) stopvar(string)]

    if "`startvar'" == "" local startvar "start"
    if "`stopvar'" == "" local stopvar "stop"

    quietly count
    if r(N) == 0 {
        display as error "    Validation FAIL: Output has 0 observations"
        return scalar valid = 0
        exit
    }

    quietly levelsof id
    local output_ids = r(r)
    if `output_ids' < `cohort_ids' * 0.95 {
        display as error "    Validation WARN: Only `output_ids'/`cohort_ids' IDs in output"
    }

    quietly count if `stopvar' < `startvar'
    if r(N) > 0 {
        display as error "    Validation FAIL: " r(N) " rows with stop < start"
        return scalar valid = 0
        exit
    }

    sort id `startvar' `stopvar'
    quietly by id: gen byte _overlap = (`startvar' < `stopvar'[_n-1]) if _n > 1
    quietly count if _overlap == 1
    local n_overlaps = r(N)
    if `n_overlaps' > 0 {
        display as error "    Validation WARN: `n_overlaps' overlapping periods detected"
    }
    quietly drop _overlap

    return scalar valid = 1
    return scalar n_obs = _N
    return scalar n_ids = `output_ids'
end

* _verify_ptime_conserved: person-time conservation check.
capture program drop _verify_ptime_conserved
program define _verify_ptime_conserved, rclass
    syntax, start(varname) stop(varname) expected_ptime(real) [tolerance(real 0.001)]
    tempvar dur
    gen double `dur' = `stop' - `start'
    quietly sum `dur'
    local actual = r(sum)
    local pct_diff = abs(`actual' - `expected_ptime') / `expected_ptime'
    return scalar actual_ptime = `actual'
    return scalar pct_diff = `pct_diff'
    return scalar passed = (`pct_diff' < `tolerance')
end

* _verify_no_overlap: count overlapping intervals within id.
capture program drop _verify_no_overlap
program define _verify_no_overlap, rclass
    syntax, id(varname) start(varname) stop(varname)
    sort `id' `start' `stop'
    tempvar prev_stop overlap
    by `id': gen double `prev_stop' = `stop'[_n-1] if _n > 1
    by `id': gen byte `overlap' = (`start' < `prev_stop') if _n > 1
    quietly count if `overlap' == 1
    return scalar n_overlaps = r(N)
end

* ---------------------------------------------------------------------------
* run_test / test_pass / test_fail harness.
*
* The consolidated option-coverage and edge/stress suites call these primitives.
* In the original monolith they were never defined, so the enclosing
* `capture noisily {}` swallowed the resulting r(199) and silently skipped the
* whole block (88 option tests + the edge/stress tallies never gated). Defining
* them here as global-counter primitives revives those tests: each suite resets
* $TVQA_PASS/$TVQA_FAIL in its preamble and folds them into the shared
* pass_count/fail_count in its summary.
* ---------------------------------------------------------------------------
capture program drop run_test
program define run_test
    args _tvqa_name
    global TVQA_CURRENT "`_tvqa_name'"
    if $RUN_TEST_QUIET == 0 {
        display as text _n "TEST: `_tvqa_name'"
    }
end

capture program drop test_pass
program define test_pass
    global TVQA_PASS = $TVQA_PASS + 1
    if $RUN_TEST_QUIET == 0 {
        display as result "  PASS [$TVQA_CURRENT]"
    }
end

capture program drop test_fail
program define test_fail
    args _tvqa_msg
    global TVQA_FAIL = $TVQA_FAIL + 1
    global TVQA_FAILED "$TVQA_FAILED $TVQA_CURRENT"
    display as error "  FAIL [$TVQA_CURRENT]: `_tvqa_msg'"
end

* _check_log: report whether a needle string appears in a log file.
capture program drop _check_log
program define _check_log, rclass
    syntax , logfile(string) needle(string)
    local content = fileread("`logfile'")
    local found = strpos(`"`content'"', `"`needle'"') > 0
    return scalar found = `found'
end
