* _iivw_qa_common.do — shared QA scaffold for iivw
*
* Source this from a suite, then call the bootstrap:
*
*     do "`c(pwd)'/_iivw_qa_common.do"
*     iivw_qa_bootstrap
*
* WHY THIS EXISTS
* ---------------
* 36 of the 40 iivw suites `net install' the package, and several
* uninstall/replace tabtools. Run against the default sysdirs, that mutates the
* USER's real ado tree: a 2026-07 audit run left the tracker pointing iivw at
* /tmp and removed tabtools outright, and both had to be restored by hand.
*
* run_all.do sandboxes PLUS/PERSONAL for the whole run, but that protects only
* suites it launches in-process. A suite run standalone -- or a suite that
* spawns a nested `stata-mp' -- starts from the user's real sysdirs again,
* because a child process does not inherit Stata's `sysdir set'. So the sandbox
* has to be available at suite level too. That is what this file provides.
*
* The sandbox lives under c(tmpdir) and is unique per process, so two suites can
* run concurrently without colliding on a shared PLUS (which is what produces
* the r(603) "file ... could not be opened" failures during parallel installs).

* iivw_qa_sandbox -- sysdir sandbox + path resolution, no install.
*
* This is the piece EVERY suite needs, including the many that already have
* their own bespoke `net install' lines. It is rclass so a suite can take the
* resolved directories from r() instead of re-deriving them:
*
*     do "`c(pwd)'/_iivw_qa_common.do"
*     iivw_qa_sandbox
*     local pkg_dir  "`r(pkg_dir)'"
*     local repo_dir "`r(repo_dir)'"
capture program drop iivw_qa_sandbox
program define iivw_qa_sandbox, rclass
    version 16.0
    syntax [, PKGdir(string)]

    * Resolve the package directory from the caller's cwd unless told otherwise.
    * Strip the known "/qa" suffix by LENGTH -- never with first-occurrence
    * subinstr(), which mangles any path whose ancestors contain "qa" (a run from
    * /tmp/qa-audit-42/iivw/qa derived a nonexistent /tmp-audit-42/iivw).
    if "`pkgdir'" == "" {
        local here "`c(pwd)'"
        if substr("`here'", -3, 3) == "/qa" {
            local pkgdir = substr("`here'", 1, strlen("`here'") - 3)
        }
        else {
            display as error "iivw_qa_sandbox: run from the package's qa/ directory,"
            display as error "  or pass pkgdir()"
            exit 601
        }
    }
    capture confirm file "`pkgdir'/iivw.pkg"
    if _rc {
        display as error "iivw_qa_sandbox: no iivw.pkg under `pkgdir'"
        exit 601
    }
    * Same length-based rule one level up: a checkout under ~/iivw-work/iivw
    * would lose the wrong component to subinstr(...,"/iivw","",1).
    local repodir = substr("`pkgdir'", 1, strlen("`pkgdir'") - strlen("/iivw"))

    * Sandbox the ado tree for this process.  Idempotent: a suite launched by
    * run_all (which already sandboxed) simply gets a nested sandbox, and a
    * standalone suite gets the protection it would otherwise not have.
    tempfile _stub
    local sandbox "`_stub'_sysdir"
    capture mkdir "`sandbox'"
    capture mkdir "`sandbox'/plus"
    capture mkdir "`sandbox'/personal"
    capture confirm file "`sandbox'/plus"
    if _rc {
        display as error "iivw_qa_sandbox: could not create sysdir sandbox `sandbox'"
        exit 603
    }
    sysdir set PLUS     "`sandbox'/plus"
    sysdir set PERSONAL "`sandbox'/personal"

    display as text "iivw QA sandbox: `sandbox'  (user's PLUS/PERSONAL untouched)"

    return local pkg_dir  "`pkgdir'"
    return local repo_dir "`repodir'"
    return local sandbox  "`sandbox'"
end

capture program drop iivw_qa_bootstrap
program define iivw_qa_bootstrap, rclass
    version 16.0
    syntax [, PKGdir(string) NOInstall]

    if "`pkgdir'" == "" iivw_qa_sandbox
    else                iivw_qa_sandbox, pkgdir("`pkgdir'")
    local pkgdir  "`r(pkg_dir)'"
    local repodir "`r(repo_dir)'"
    local sandbox "`r(sandbox)'"

    if "`noinstall'" == "" {
        capture ado uninstall iivw
        quietly net install iivw, from("`pkgdir'") replace
        * Prove the install actually resolves before any test trusts it.
        capture which iivw_weight
        if _rc {
            display as error "iivw_qa_bootstrap: iivw_weight not found after net install"
            exit 111
        }
    }

    return local pkg_dir  "`pkgdir'"
    return local repo_dir "`repodir'"
    return local sandbox  "`sandbox'"
end

* -----------------------------------------------------------------------------
* SELECTOR AND SUMMARY CONTRACTS (Q5, Q9)
* -----------------------------------------------------------------------------
* Every selectable suite took `args run_only' and then guarded each case with
*   if `run_only' == 0 | `run_only' == 7 { ... }
* so `do test_iivw_exogtest.do 999' executed NOTHING, ended with fail_count==0,
* printed "ALL TESTS PASSED" and exited 0. A typo in a selector was therefore
* indistinguishable from a green suite. And seven suites printed a prose success
* line instead of the RESULT: sentinel qa/README.md documents, so the parser
* could read "4/4 passed" off a suite it had not actually verified.
*
* iivw_qa_selector validates the selector up front; iivw_qa_summary emits ONE
* sentinel shape on both the pass and the fail path, and refuses to call a run
* green when no case ran.

capture program drop iivw_qa_selector
program define iivw_qa_selector, rclass
    version 16.0
    args sel
    if `"`sel'"' == "" {
        return local run_only = 0
        exit
    }
    capture confirm integer number `sel'
    if _rc {
        display as error "run_only must be a non-negative integer (got: `sel')"
        exit 198
    }
    if `sel' < 0 {
        display as error "run_only must be a non-negative integer (got: `sel')"
        exit 198
    }
    return local run_only = `sel'
end

capture program drop iivw_qa_summary
program define iivw_qa_summary
    version 16.0
    syntax , NAme(string) Tests(integer) Pass(integer) Fail(integer) ///
        [RUNonly(string) FAILEDtests(string)]

    if `"`runonly'"' == "" local runonly = 0
    local executed = `pass' + `fail'
    local skip     = `tests' - `executed'

    display as text ""
    display as result "`name': `pass'/`tests' passed, `fail' failed, `skip' skipped"

    * Reconciliation. A suite whose counters do not add up is not a suite whose
    * result can be trusted, whichever way the arithmetic fell.
    if `skip' < 0 {
        display as error "`name': counter corruption -- pass+fail (`executed') exceeds tests (`tests')"
        display "RESULT: `name' tests=`tests' pass=`pass' fail=`fail' skip=`skip'"
        capture log close _all
        exit 198
    }

    * Zero executed cases is a selector error, never a pass.
    if `executed' == 0 {
        display as error "`name': no test executed (run_only = `runonly')"
        display as error "  valid selectors are 0 (all) or 1-`tests'"
        display "RESULT: `name' tests=`tests' pass=0 fail=0 skip=`skip'"
        capture log close _all
        exit 198
    }

    * A specific selector must select exactly one case.
    if `runonly' != 0 & `executed' != 1 {
        display as error "`name': selector `runonly' executed `executed' cases, expected 1"
        display "RESULT: `name' tests=`tests' pass=`pass' fail=`fail' skip=`skip'"
        capture log close _all
        exit 198
    }

    if `fail' > 0 {
        if `"`failedtests'"' != "" {
            display as error "FAILED TESTS: `failedtests'"
        }
        display "RESULT: `name' tests=`tests' pass=`pass' fail=`fail' skip=`skip'"
        capture log close _all
        exit 1
    }

    display as result "ALL EXECUTED TESTS PASSED"
    display "RESULT: `name' tests=`tests' pass=`pass' fail=`fail' skip=`skip'"
    * The sentinel is emitted BEFORE this, so it lands in the suite's own log as
    * well as the batch log. `log close _all' does not touch Stata's -b log.
    capture log close _all
end
