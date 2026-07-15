* test_iivw_v200_phase3b.do
* Phase 3 (second half): label serialization, docs, and QA-infrastructure gates.
*
*   Q1  H14  labels containing " and | round-trip through r() and through Excel
*   Q2  H14  the pipe-joined r(group_labels)/r(term_labels) macros are GONE
*   Q3  D3   the help files describe the borders the code actually draws
*   Q4  Q5   iivw_qa_selector rejects a non-integer / negative selector
*   Q5  Q5   iivw_qa_summary refuses to call a zero-execution run green
*   Q6  Q5   a real suite run with an out-of-range selector exits nonzero
*   Q7  Q9   every curated suite emits the documented RESULT: sentinel
*   Q8  Q8   no suite derives its package dir with first-occurrence subinstr()
*   Q9  Q6   no suite writes a named log or a fixed /tmp workbook into the tree
*   Q10 Q12  the demo stages its assets and only publishes after every assert
*
* The sharpest of these is Q5/Q6: `do test_iivw_exogtest.do 999' used to execute
* nothing, end with fail_count == 0, print an all-passed banner and exit 0. A typo
* in a selector was indistinguishable from a green suite.

clear all
set varabbrev off
version 16.0

capture log close
tempfile _suite_log
log using "`_suite_log'", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

local qa_dir "`c(pwd)'"
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir "`r(pkg_dir)'"
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

capture program drop _p3b_panel
program define _p3b_panel
    version 16.0
    syntax [, NIDS(integer 120) SEED(integer 4242)]

    clear
    set seed `seed'
    set obs `nids'
    gen long id = _n
    gen byte arm = mod(_n, 2)
    gen double z = rnormal()
    expand 6
    bysort id: gen int j = _n
    gen double gap = -ln(runiform()) / (0.5 * exp(0.3 * z))
    bysort id (j): gen double months = sum(gap)
    gen double y = 1 + 0.4 * z + rnormal()
    drop gap j
end

**# Q1. H14 -- hostile labels survive r() and the workbook

local ++test_count
capture noisily {
    _p3b_panel

    * Both characters the old code destroyed: it deleted every double quote from
    * the label and then joined the labels with an unescaped "|".
    label variable y `"Cohort "A" | high risk"'
    label define _p3b_arm 0 `"ctrl "x" | a"' 1 `"trt "y" | b"', replace
    label values arm _p3b_arm

    tempfile xstub
    local xb "`xstub'_exog.xlsx"

    iivw_exogtest y, endatlastvisit id(id) time(months) by(arm) nolog ///
        xlsx("`xb'") replace

    * Verbatim, not sanitized.
    assert `"`r(term_label_1)'"'  == `"Cohort "A" | high risk (lag 1)"'
    assert `"`r(group_label_1)'"' == `"ctrl "x" | a"'
    assert `"`r(group_label_2)'"' == `"trt "y" | b"'
    assert r(n_terms)  == 1
    assert r(n_groups) == 2

    * And into the workbook, not just into r(). The Excel path is separate code.
    confirm file "`xb'"
    preserve
    quietly import excel using "`xb'", sheet("Exogeneity") clear allstring
    local hit_term = 0
    local hit_grp  = 0
    quietly ds
    foreach v of varlist `r(varlist)' {
        quietly count if strpos(`v', `"Cohort "A" | high risk"') > 0
        if r(N) > 0 local hit_term = 1
        quietly count if strpos(`v', `"trt "y" | b"') > 0
        if r(N) > 0 local hit_grp = 1
    }
    assert `hit_term' == 1
    assert `hit_grp'  == 1
    restore
}
if _rc == 0 {
    display as result "  PASS: Q1 - H14 hostile labels round-trip r() and Excel"
    local ++pass_count
}
else {
    display as error "  FAIL: Q1 - H14 label round-trip (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Q1"
}

**# Q2. H14 -- the lossy pipe-joined macros are gone, not merely supplemented

local ++test_count
capture noisily {
    _p3b_panel
    iivw_exogtest y, endatlastvisit id(id) time(months) by(arm) nolog

    * If these came back, someone re-introduced the delimiter and the indexed
    * returns became decoration.
    assert "`r(group_labels)'"   == ""
    assert "`r(term_labels)'"    == ""
    assert "`r(skipped_labels)'" == ""
}
if _rc == 0 {
    display as result "  PASS: Q2 - H14 pipe-joined label macros removed"
    local ++pass_count
}
else {
    display as error "  FAIL: Q2 - pipe-joined macros still present (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Q2"
}

**# Q3. D3 -- the border docs match the borders the code draws

local ++test_count
capture noisily {
    * _iivw_export_table draws an outer frame, header rules, and vertical group
    * separators. It deliberately does NOT draw interior horizontal rules, and
    * test_iivw_reporting_exports.do enforces that. All three help files used to
    * promise "a full thin grid -- an outer box plus interior horizontal and
    * vertical rules", which is a contract the package never honoured.
    foreach h in iivw_balance iivw_diagnose iivw_exogtest {
        preserve
        quietly import delimited using "`pkg_dir'/`h'.sthlp", ///
            delimiter(tab) varnames(nonames) stringcols(_all) clear
        quietly count if strpos(v1, "interior horizontal") > 0 & ///
            strpos(v1, "and vertical rules") > 0
        assert r(N) == 0
        quietly count if strpos(v1, "not separated by interior horizontal rules") > 0
        assert r(N) == 1
        restore
    }
}
if _rc == 0 {
    display as result "  PASS: Q3 - D3 border docs match implementation"
    local ++pass_count
}
else {
    display as error "  FAIL: Q3 - D3 border docs (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Q3"
}

**# Q4. Q5 -- the selector validator rejects what it should

local ++test_count
capture noisily {
    capture iivw_qa_selector "abc"
    assert _rc == 198
    capture iivw_qa_selector "-1"
    assert _rc == 198
    capture iivw_qa_selector "2.5"
    assert _rc == 198

    * And accepts what it should, defaulting to 0.
    iivw_qa_selector ""
    assert `r(run_only)' == 0
    iivw_qa_selector "7"
    assert `r(run_only)' == 7
}
if _rc == 0 {
    display as result "  PASS: Q4 - Q5 selector validation"
    local ++pass_count
}
else {
    display as error "  FAIL: Q4 - selector validation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Q4"
}

**# Q5. Q5 -- a zero-execution run is an error, never "ALL TESTS PASSED"

local ++test_count
capture noisily {
    * 16 declared cases, none executed: exactly what run_only=999 produced.
    capture iivw_qa_summary, name(probe) tests(16) pass(0) fail(0) runonly(999)
    assert _rc == 198

    * A specific selector that somehow ran more than one case is also wrong.
    capture iivw_qa_summary, name(probe) tests(16) pass(4) fail(0) runonly(3)
    assert _rc == 198

    * Counter corruption (pass+fail > tests) is refused in either direction.
    capture iivw_qa_summary, name(probe) tests(2) pass(3) fail(0) runonly(0)
    assert _rc == 198

    * A genuine all-pass run still passes, and a genuine failure still exits 1.
    capture iivw_qa_summary, name(probe) tests(16) pass(16) fail(0) runonly(0)
    assert _rc == 0
    capture iivw_qa_summary, name(probe) tests(16) pass(15) fail(1) runonly(0)
    assert _rc == 1

    * One selected case out of many is the normal selector path.
    capture iivw_qa_summary, name(probe) tests(16) pass(1) fail(0) runonly(3)
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: Q5 - Q5 zero-execution run refused"
    local ++pass_count
}
else {
    display as error "  FAIL: Q5 - zero-execution guard (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Q5"
}

**# Q6. Q5 -- end to end: a real suite with a bogus selector exits nonzero

local ++test_count
capture noisily {
    * The unit tests above exercise the helpers. This one proves the helpers are
    * actually WIRED IN: it runs a real suite, in a child process, with the
    * selector that used to false-green. rc is not readable from `stata-mp -b'
    * (it is always 0), so read the sentinel out of the child's log instead.
    tempfile probelog
    quietly shell cd "`qa_dir'" && stata-mp -b do test_iivw_exogtest.do 999 ///
        > /dev/null 2>&1

    * The child writes test_iivw_exogtest.log in qa/. Read it, then remove it --
    * it is exactly the debris the hygiene gate now refuses.
    preserve
    quietly import delimited using "`qa_dir'/test_iivw_exogtest.log", ///
        delimiter(tab) varnames(nonames) stringcols(_all) clear

    * Anchor at column 1. A Stata log ECHOES the source of every command and
    * comment it reads, so a bare strpos() for "ALL TESTS PASSED" matches the
    * comment in this very file that explains the bug -- three hits, and the
    * false-green assertion fails on its own documentation. Only EXECUTED output
    * starts at column 1; echoed source is prefixed with ". " or " 15.".
    quietly count if strpos(v1, "test_iivw_exogtest: no test executed") == 1
    local saw_guard = r(N)
    quietly count if strpos(v1, "ALL EXECUTED TESTS PASSED") == 1
    local saw_falsegreen = r(N)
    quietly count if strpos(v1, "RESULT: test_iivw_exogtest tests=") == 1 & ///
        strpos(v1, "pass=0 fail=0") > 0
    local saw_sentinel = r(N)
    restore
    capture erase "`qa_dir'/test_iivw_exogtest.log"

    assert `saw_guard'      >= 1
    assert `saw_falsegreen' == 0
    assert `saw_sentinel'   >= 1
}
if _rc == 0 {
    display as result "  PASS: Q6 - Q5 bogus selector fails a real suite"
    local ++pass_count
}
else {
    display as error "  FAIL: Q6 - bogus selector end-to-end (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Q6"
}

**# Q7. Q9 -- every curated suite emits the documented RESULT: sentinel

local ++test_count
capture noisily {
    * qa/README.md promises "RESULT: name tests=N pass=N fail=N". Seven suites
    * printed prose ("RESULT: ALL 28 VALIDATIONS PASSED") on the success path, so
    * the parser could read a pass count off a suite it had never verified. The
    * shared summary emits one shape on both paths; a suite that neither calls it
    * nor hand-writes the sentinel is a suite the aggregate cannot check.
    local suites : dir "`qa_dir'" files "*.do"
    local bad ""
    foreach s of local suites {
        if substr("`s'", 1, 1) == "_"  continue
        if "`s'" == "run_all.do"        continue
        if substr("`s'", 1, 4) == "sim_" continue
        * benchmark_* are high-replication gates in their own lane, not curated
        * pass/fail suites the aggregate parses -- excluded like sim_*.
        if substr("`s'", 1, 10) == "benchmark_" continue

        preserve
        quietly import delimited using "`qa_dir'/`s'", delimiter(tab) ///
            varnames(nonames) stringcols(_all) clear
        quietly count if strpos(v1, "iivw_qa_summary,") > 0
        local uses_shared = r(N)
        * A hand-written sentinel counts ONLY if it is the machine-readable form.
        * Accepting any line starting `display "RESULT:' would keep blessing the
        * prose banners this test exists to eliminate -- "RESULT: ALL 28
        * VALIDATIONS PASSED" carries no counts, so the parser reports a pass it
        * never verified. The "tests=" is what makes it parseable.
        quietly count if strpos(v1, "display " + char(34) + "RESULT: ") > 0 & ///
            strpos(v1, "tests=") > 0
        local hand_written = r(N)
        restore

        if `uses_shared' == 0 & `hand_written' == 0 {
            local bad "`bad' `s'"
        }
    }
    if "`bad'" != "" {
        display as error "suites with no RESULT: sentinel:`bad'"
    }
    assert "`bad'" == ""
}
if _rc == 0 {
    display as result "  PASS: Q7 - Q9 every suite emits a RESULT: sentinel"
    local ++pass_count
}
else {
    display as error "  FAIL: Q7 - missing RESULT: sentinel (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Q7"
}

**# Q8. Q8 -- no suite strips its path suffix with first-occurrence subinstr()

local ++test_count
capture noisily {
    * A run from /tmp/qa-audit-42/iivw/qa derived a nonexistent
    * /tmp-audit-42/iivw, because subinstr(path, "/qa", "", 1) removes the FIRST
    * "/qa" in the string, not the suffix. 29 files carried the same line.
    local suites : dir "`qa_dir'" files "*.do"
    local bad ""
    foreach s of local suites {
        preserve
        quietly import delimited using "`qa_dir'/`s'", delimiter(tab) ///
            varnames(nonames) stringcols(_all) clear
        quietly count if strpos(v1, `"subinstr("`qa_dir'""') > 0 | ///
            strpos(v1, `"subinstr("`pkg_dir'""') > 0
        local hits = r(N)
        restore
        if `hits' > 0 local bad "`bad' `s'"
    }
    if "`bad'" != "" {
        display as error "suites still using first-occurrence subinstr():`bad'"
    }
    assert "`bad'" == ""

    * And the shared resolver gets the hostile path right. Build a real one.
    local hostile "`c(tmpdir)'/qa-audit-42"
    capture mkdir "`hostile'"
    capture mkdir "`hostile'/iivw"
    capture mkdir "`hostile'/iivw/qa"
    quietly copy "`pkg_dir'/iivw.pkg" "`hostile'/iivw/iivw.pkg", replace

    local saved "`c(pwd)'"
    cd "`hostile'/iivw/qa"
    iivw_qa_sandbox
    local got "`r(pkg_dir)'"
    cd "`saved'"

    * The correct answer is <tmpdir>/qa-audit-42/iivw. The old rule gave
    * <tmpdir>-audit-42/iivw/qa, which does not exist.
    assert "`got'" == "`hostile'/iivw"
    capture confirm file "`got'/iivw.pkg"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: Q8 - Q8 path derivation survives a qa ancestor"
    local ++pass_count
}
else {
    display as error "  FAIL: Q8 - path derivation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Q8"
}

**# Q9. Q6 -- no suite writes a named log or a fixed /tmp workbook into the tree

local ++test_count
capture noisily {
    * The tree held 17 gitignored .log files under qa, ~4 MB, and the crossval
    * ones carry the local Stata license header. They were written by the suites
    * themselves, and the release hygiene gate whitelisted every one of them.
    * (Do not write the glob as qa-slash-star-dot-log in a comment: the slash-star
    * opens a Stata block comment that never closes, and the suite dies with
    * "matching close brace not found" -- which reads as a hang, not a bug.)
    * char(34) is a double quote, char(96) a backtick. Both are built inline,
    * and NEITHER may be parked in a local first. A literal quote inside these
    * count-if expressions unbalances the enclosing capture-noisily block and
    * Stata aborts the whole suite with "matching close brace not found" -- a
    * parse error, so the suite looks like it stopped rather than like it failed.
    * And a local holding char(96) is worse: expanding it re-enters macro
    * expansion on the backtick it contains, which breaks the same way.
    local suites : dir "`qa_dir'" files "*.do"
    local bad_log ""
    local bad_tmp ""
    foreach s of local suites {
        preserve
        quietly import delimited using "`qa_dir'/`s'", delimiter(tab) ///
            varnames(nonames) stringcols(_all) clear
        * A log target that opens with a quote-then-letter is a literal name and
        * lands in the package tree; a quote-then-backtick is a `tempfile' macro
        * and lands in c(tmpdir), which is what every suite must now use.
        * "log using " is 10 characters, so the quote is character 11 and the
        * first character of the target is character 12.
        gen str32 _head = substr(strtrim(v1), 1, 12)
        quietly count if substr(_head, 1, 11) == "log using " + char(34) & ///
            substr(_head, 12, 1) != char(96)
        local n_log = r(N)
        * Assembled from three pieces so that this source line does not itself
        * contain the sequence it is hunting for -- otherwise the scanner is the
        * one file it always reports, and the only way to get a green is to
        * exempt it, which puts a hole in the very check it performs.
        quietly count if strpos(v1, char(34) + "/" + "tmp" + "/") > 0
        local n_tmp = r(N)
        restore
        if `n_log' > 0 local bad_log "`bad_log' `s'"
        if `n_tmp' > 0 local bad_tmp "`bad_tmp' `s'"
    }
    if "`bad_log'" != "" display as error "suites writing named logs:`bad_log'"
    if "`bad_tmp'" != "" display as error "suites using fixed /tmp paths:`bad_tmp'"
    assert "`bad_log'" == ""
    assert "`bad_tmp'" == ""
}
if _rc == 0 {
    display as result "  PASS: Q9 - Q6 no named logs, no fixed /tmp artifacts"
    local ++pass_count
}
else {
    display as error "  FAIL: Q9 - artifact hygiene (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Q9"
}

**# Q10. Q12 -- the demo stages and publishes only after every assert

local ++test_count
capture noisily {
    local demo "`pkg_dir'/demo/demo_iivw.do"
    capture confirm file "`demo'"
    assert _rc == 0

    preserve
    quietly import delimited using "`demo'", delimiter(tab) ///
        varnames(nonames) stringcols(_all) clear

    * It must NOT erase the tracked assets up front. That is what made a
    * mid-demo failure leave the repo with the documentation assets missing.
    quietly count if strpos(v1, "capture erase") > 0 & ///
        strpos(v1, "pkg_dir") > 0
    assert r(N) == 0

    * It must stage, and publish with copy ... replace only at the end.
    quietly count if strpos(v1, "local stage ") > 0
    assert r(N) == 1
    quietly count if strpos(v1, "copy ") > 0 & strpos(v1, "stage") > 0 & ///
        strpos(v1, "pkg_dir") > 0
    assert r(N) == 1

    * It must sandbox its four net installs and restore the scheme.
    quietly count if strpos(v1, "sysdir set PLUS") > 0
    assert r(N) == 2
    * char(96) rather than a typed backtick: a backtick in this search string is
    * macro-expanded by Stata BEFORE strpos() ever sees it, so "set scheme
    * <backtick>orig_scheme'" would silently become "set scheme " and match the
    * demo's own `set scheme plotplainblind' as well -- a passing test looking
    * for a restore line that need not exist.
    quietly count if strpos(v1, "set scheme " + char(96) + "orig_scheme'") > 0
    assert r(N) == 1
    restore
}
if _rc == 0 {
    display as result "  PASS: Q10 - Q12 demo is staged, sandboxed, and atomic"
    local ++pass_count
}
else {
    display as error "  FAIL: Q10 - demo atomicity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Q10"
}

**# Summary

local run_only = 0
iivw_qa_summary, name(test_iivw_v200_phase3b) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') runonly(`run_only') ///
    failedtests("`failed_tests'")
