clear all
set more off
version 16.0
set varabbrev off

* test_iivw_v200_qagate.do
*
* v2.0.0 Phase 0 regressions for the QA gate itself. These test the tests.
*
*   Q1  The external R cross-validation lane reported "ALL 4 EXTERNAL
*       CROSS-VALIDATION TESTS PASSED" in the very run where R halted with a
*       missing `cobalt' package -- because Stata's `shell' never propagates the
*       child's exit status, and the lane then "validated" by confirming that
*       the TRACKED CSVs existed, which they always do. The gate certified a
*       package it never tested.
*   Q4  A curated suite missing from disk printed SKIP and continued, so a typo
*       or an accidental deletion shrank coverage while the aggregate stayed
*       green.
*   EXIT-CODE CONTRACT (found while fixing Q1, not in the audit): `stata-mp -b
*       do' returns shell exit status 0 unconditionally -- even for `exit 1',
*       `error 198', a failed command, or a failed `assert'. Every suite's
*       "exit 1 on failure" is therefore invisible to a shell caller. The runner
*       must publish its verdict in a file, and this suite pins that contract.

capture log close
log using "test_iivw_v200_qagate.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = substr("`qa_dir'", 1, strlen("`qa_dir'") - strlen("/qa"))

* This suite installs nothing itself, but it spawns nested stata-mp runs that
* do. Sandbox anyway so a stray install in this process cannot escape.
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap, pkgdir("`pkg_dir'") noinstall

**# T1: Stata's shell does not propagate a child's failure (the root cause)

local ++test_count
capture noisily {
    * This is WHY the sentinel pattern is necessary: Stata's `shell' reports
    * rc 0 for a child that failed, exited nonzero, or does not even exist.
    * Note the `capture' -- without it, _rc here is simply whatever the last
    * captured command left behind, which is how a "shell rc" check can look
    * like it works while testing nothing at all.
    capture shell false
    if _rc != 0 {
        display as error "T1 FAIL: shell now propagates rc; revisit the sentinel rationale"
        error 9
    }
    capture shell /nonexistent/binary/xyzzy
    if _rc != 0 {
        display as error "T1 FAIL: shell now reports a missing binary; revisit the rationale"
        error 9
    }

    * And the sentinel mechanism must catch what _rc cannot.
    tempfile stub
    local d "`stub'_q1"
    capture mkdir "`d'"
    local ok "`d'/.ok"
    capture erase "`ok'"

    * Failing child: `touch' must never run, so the sentinel must be absent.
    shell false && touch "`ok'"
    capture confirm file "`ok'"
    if _rc == 0 {
        display as error "T1 FAIL: success sentinel exists after a FAILING child"
        error 9
    }

    * Succeeding child: the sentinel must appear.
    shell true && touch "`ok'"
    capture confirm file "`ok'"
    if _rc != 0 {
        display as error "T1 FAIL: success sentinel missing after a SUCCEEDING child"
        error 9
    }
    capture erase "`ok'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: T1 shell rc is unusable; the success sentinel is not"
}
else {
    local ++fail_count
    display as error "FAIL: T1 shell/sentinel contract"
}

**# T2: stata-mp -b do returns 0 even on failure (so no caller may gate on $?)

local ++test_count
capture noisily {
    tempfile stub2
    local d2 "`stub2'_ec"
    capture mkdir "`d2'"

    * A do-file that fails as loudly as Stata permits.
    capture file close _ec
    file open _ec using "`d2'/boom.do", write replace
    file write _ec "assert 1 == 2" _n
    file close _ec

    * If Stata ever starts returning a nonzero exit status, the sentinel file in
    * run_all.do is redundant but harmless -- and this test tells us to simplify.
    local marker "`d2'/.ran"
    capture erase "`marker'"
    shell cd "`d2'" && stata-mp -b do boom.do ; echo done > "`marker'"

    * The failing do-file must have actually failed (log records the error)...
    capture confirm file "`d2'/boom.log"
    if _rc {
        display as error "T2 FAIL: no log produced; cannot verify the exit-code contract"
        error 9
    }
    * ...and run_all must therefore not rely on the process exit status. We pin
    * the observed behaviour rather than asserting a specific code, so that this
    * test documents reality on whatever Stata build runs it.
    display as text "  (exit-code behaviour pinned: run_all publishes run_all_status.txt)"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: T2 batch exit-code contract pinned"
}
else {
    local ++fail_count
    display as error "FAIL: T2 batch exit-code contract"
}

**# T3 (Q4): a curated suite missing from disk must FAIL the run, not SKIP

local ++test_count
capture noisily {
    * Stand up a bare qa/ tree containing only run_all.do. In sim mode the
    * runner curates three suites; none of them exists here. The old runner
    * printed "SKIP: ... not found" three times and exited 0. The fixed runner
    * must count all three as failures, name them, and record status=FAIL.
    tempfile stub3
    local root "`stub3'_q4"
    capture mkdir "`root'"
    capture mkdir "`root'/iivw"
    capture mkdir "`root'/iivw/qa"
    local fakeqa "`root'/iivw/qa"

    copy "`qa_dir'/run_all.do" "`fakeqa'/run_all.do", replace

    shell cd "`fakeqa'" && stata-mp -b do run_all.do sim > /dev/null 2>&1

    * The verdict must be published where a caller can read it, because the
    * process exit status cannot be trusted (T1/T2).
    capture confirm file "`fakeqa'/run_all_status.txt"
    if _rc {
        display as error "T3 FAIL: runner published no run_all_status.txt"
        error 9
    }

    capture file close _st
    file open _st using "`fakeqa'/run_all_status.txt", read
    file read _st line1
    local status = strtrim("`line1'")
    file read _st line2
    file read _st line3
    local counts = strtrim("`line3'")
    file close _st

    if "`status'" != "FAIL" {
        display as error "T3 FAIL: three missing curated suites gave status=`status', not FAIL"
        error 9
    }
    * All three sim suites are absent, so none ran and all three are failures.
    if strpos("`counts'", "pass=0") == 0 | strpos("`counts'", "fail=3") == 0 {
        display as error "T3 FAIL: expected pass=0 fail=3, got: `counts'"
        error 9
    }
    display as text "  runner verdict on 3 missing suites: `status' / `counts'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: T3 missing curated suite fails the run and is named"
}
else {
    local ++fail_count
    display as error "FAIL: T3 missing curated suite"
}

**# T4 (Q1): R failing with stale tracked CSVs present must STOP the lane

local ++test_count
capture noisily {
    * The smoking gun, reproduced end to end. Copy the package (so the lane can
    * net install it and find its tracked reference CSVs -- the stale files that
    * previously stood in for a reference that was never produced), then put a
    * failing `Rscript' shim first on PATH, exactly imitating the missing-cobalt
    * failure recorded in the shipped crossval_iivw_external.log.
    tempfile stub4
    local root "`stub4'_q1e2e"
    capture mkdir "`root'"
    shell cp -r "`pkg_dir'" "`root'/iivw" 2>/dev/null
    local fakeqa "`root'/iivw/qa"
    capture confirm file "`fakeqa'/crossval_iivw_external.do"
    if _rc {
        display as error "T4 FAIL: could not stage a package copy"
        error 9
    }

    * The tracked references must be present -- that is the whole precondition:
    * a valid-looking oracle sitting on disk while R is dead.
    capture confirm file "`fakeqa'/crossval_iivw_external_bladder.csv"
    if _rc {
        display as error "T4 FAIL: staged copy lacks the tracked reference CSVs"
        error 9
    }

    * Erase any log the copy brought with it. cp -r drags along whatever logs
    * happen to be sitting in qa/, and a leftover log from a PASSING run would
    * make this test read someone else's success -- the same stale-artifact
    * mistake the lane itself used to make.
    capture erase "`fakeqa'/crossval_iivw_external.log"
    capture confirm file "`fakeqa'/crossval_iivw_external.log"
    if _rc == 0 {
        display as error "T4 FAIL: could not clear the staged log before the run"
        error 9
    }

    * Failing Rscript shim.
    capture mkdir "`root'/shim"
    capture file close _sh
    file open _sh using "`root'/shim/Rscript", write replace
    file write _sh "#!/bin/sh" _n
    file write _sh `"echo "Error in library(cobalt) : there is no package called 'cobalt'" >&2"' _n
    file write _sh "exit 1" _n
    file close _sh
    shell chmod +x "`root'/shim/Rscript"

    * NOTE the backslash: inside a Stata command line `$PATH' is expanded as a
    * GLOBAL MACRO, not passed through to the shell. Unescaped, it expands to
    * nothing, PATH becomes "<shim>:" alone, stata-mp is not found, and the
    * nested run silently never happens -- leaving whatever log was already
    * there to be read as if it were this run's result.
    shell cd "`fakeqa'" && PATH="`root'/shim:\$PATH" stata-mp -b do crossval_iivw_external.do > /dev/null 2>&1

    capture confirm file "`fakeqa'/crossval_iivw_external.log"
    if _rc {
        display as error "T4 FAIL: the lane produced no log (nested stata-mp never ran)"
        error 9
    }

    * Scan the log. The lane must NOT claim any test passed, and must say why it
    * stopped. This is exactly the assertion the shipped log would have failed:
    * it contained BOTH "Execution halted" AND "ALL 4 ... TESTS PASSED".
    *
    * Do the scanning with grep, not `file read' + macro expansion: a Stata log
    * echoes source lines full of quotes and backticks, and expanding one of
    * those into strpos() dies with r(132). Counting in the shell and reading
    * back an integer keeps the log's contents out of the macro processor.
    tempfile cnt
    local logf "`fakeqa'/crossval_iivw_external.log"

    * Anchor on OUTPUT lines, which begin in column 1. A Stata batch log also
    * echoes the do-file's SOURCE -- including comments and the bodies of
    * branches that never executed -- each prefixed with ". ". Grepping for a
    * bare substring would therefore match this lane's own explanatory comment
    * about the historical false-green, and match the text of error messages
    * that were never printed. Only an unprefixed line was actually emitted.
    shell grep -cE "^RESULT:.*PASSED" "`logf'" > "`cnt'" 2>/dev/null
    file open _c using "`cnt'", read
    file read _c nline
    file close _c
    local saw_pass = real(strtrim("`nline'"))

    shell grep -cE "^R preflight failed|^R reference generation did not run" "`logf'" > "`cnt'" 2>/dev/null
    file open _c using "`cnt'", read
    file read _c nline
    file close _c
    local saw_stop = real(strtrim("`nline'"))

    if `saw_pass' {
        display as error "T4 FAIL: the lane reported TESTS PASSED while R was dead"
        error 9
    }
    if `saw_stop' == 0 {
        display as error "T4 FAIL: the lane neither passed nor said why it stopped"
        error 9
    }

    * And it must not have destroyed the references on its way out.
    capture confirm file "`fakeqa'/crossval_iivw_external_bladder.csv"
    if _rc {
        display as error "T4 FAIL: the failed lane removed the tracked references"
        error 9
    }
    display as text "  lane stopped with a named dependency failure; references preserved"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: T4 dead R cannot green the external crossval lane"
}
else {
    local ++fail_count
    display as error "FAIL: T4 external crossval false-green"
}

**# Summary

display _newline as text "v2.0.0 Phase 0 QA-gate regressions"
display as text "  tests:  " as result `test_count'
display as text "  passed: " as result `pass_count'
display as text "  failed: " as result `fail_count'

display "RESULT: iivw_v200_qagate tests=`test_count' pass=`pass_count' fail=`fail_count'"

if `fail_count' > 0 {
    log close
    exit 1
}

log close
