*! _tvtools_qa_common.do
*! Shared QA scaffold for the tvtools suite.
*!
*! Every test_*/validation_*/crossval_* suite sources this file, then calls
*! _tvtools_qa_bootstrap once. The bootstrap sandboxes PLUS/PERSONAL under
*! c(tmpdir) (so the real ado tree is never touched), installs tvtools from the
*! package root, and ensures the data/ fixtures exist. This file also defines the
*! shared assertion/verification helpers and the test globals used across suites.
*!
*! Run any suite standalone from qa/:  stata-mp -b do test_tvexpose.do
*! Run the whole suite:                stata-mp -b do run_all.do [lane]

version 16.0

* ---------------------------------------------------------------------------
* Test-harness globals (referenced by the shared _run_test helper and bodies)
* ---------------------------------------------------------------------------
if "$RUN_TEST_NUMBER" == "" global RUN_TEST_NUMBER 0
if "$RUN_TEST_QUIET"  == "" global RUN_TEST_QUIET 0
global DATA_DIR "`c(pwd)'/data"

* ---------------------------------------------------------------------------
* Sandboxed install bootstrap
*   - Sandboxes PLUS/PERSONAL into c(tmpdir) once per Stata session.
*   - (Re)installs tvtools from the package root (qa/.. ).
*   - Generates the data/ fixtures if they are missing.
* ---------------------------------------------------------------------------
capture program drop _tvtools_qa_bootstrap
program define _tvtools_qa_bootstrap, rclass
    version 16.0

    local qa_dir "`c(pwd)'"
    local _qa_len = strlen("`qa_dir'")
    local pkg_dir = substr("`qa_dir'", 1, `_qa_len' - 3)

    if "$TVTOOLS_QA_ISOLATED" == "" {
        tempfile _tvtools_qa_base
        local plus_dir "`_tvtools_qa_base'_plus"
        local personal_dir "`_tvtools_qa_base'_personal"
        capture mkdir "`plus_dir'"
        capture mkdir "`personal_dir'"
        global TVTOOLS_QA_PLUS "`plus_dir'"
        global TVTOOLS_QA_PERSONAL "`personal_dir'"
        global TVTOOLS_QA_ISOLATED "1"
    }

    sysdir set PLUS "$TVTOOLS_QA_PLUS"
    sysdir set PERSONAL "$TVTOOLS_QA_PERSONAL"

    capture ado uninstall tvtools
    quietly net install tvtools, from("`pkg_dir'") replace

    * Ensure the tracked data/ fixtures exist (regenerate if absent).
    capture confirm file "`qa_dir'/data/cohort.dta"
    if _rc {
        cd "`qa_dir'/data"
        run generate_test_data.do
        cd "`qa_dir'"
    }

    global DATA_DIR "`qa_dir'/data"

    return local qa_dir  "`qa_dir'"
    return local pkg_dir "`pkg_dir'"
end

* ---------------------------------------------------------------------------
* Shared assertion / verification helpers
*
* These are also defined inline inside several suites (the consolidated suites
* preserve their origin bodies verbatim). Defining them here as well is a
* harmless safety net: every helper drops itself first, so the last definition
* wins and any suite that references a helper before its inline definition still
* resolves it.
* ---------------------------------------------------------------------------

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
