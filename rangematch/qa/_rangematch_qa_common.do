*! _rangematch_qa_common.do
*! Shared QA bootstrap for the rangematch suite.
*!
*! Every suite in this directory is independently runnable, so every suite is
*! responsible for putting itself into a sandbox before it touches ado state.
*! That is what `_rm_qa_bootstrap' is for. Call it once, at the top of the
*! suite, after `clear all':
*!
*!     quietly do "`c(pwd)'/_rangematch_qa_common.do"
*!     _rm_qa_bootstrap
*!     local pkg_dir "`r(pkg_dir)'"
*!     local qa_dir  "`r(qa_dir)'"
*!
*! WHY THIS EXISTS (RM-I17). The previous headers each did their own
*! `capture ado uninstall rangematch' against the REAL PLUS directory and then
*! `adopath ++ "<pkg_dir>"'. Two consequences, both bad:
*!
*!   1. Running the documented gate uninstalled the user's own installed
*!      rangematch. The QA suite is not entitled to mutate the environment of
*!      the person running it.
*!   2. Several suites (test_rangematch_basic.do among them) uninstalled and
*!      then never installed anything -- they resolved the command off the
*!      adopath entry, i.e. they tested the SOURCE directory while reading as
*!      if they tested an installed package. An installed-user defect (a file
*!      missing from rangematch.pkg, say) is invisible to that arrangement.
*!
*! The sandbox is established once per Stata session and reused. `clear all'
*! drops programs but NOT global macros, and `sysdir set' is session state that
*! `clear all' does not touch -- both verified on stata-mp 17 -- so a suite that
*! re-sources this file after its own `clear all' rejoins the existing sandbox
*! instead of building a second one.

version 16.1

capture program drop _rm_qa_bootstrap
program define _rm_qa_bootstrap, rclass
    version 16.1

    * Resolve pkg_dir from c(pwd) only -- never a machine-local literal.
    local cwd "`c(pwd)'"
    local cwd_len = strlen("`cwd'")
    if substr("`cwd'", `cwd_len' - 2, 3) == "/qa" {
        local qa_dir "`cwd'"
        local pkg_dir = substr("`cwd'", 1, `cwd_len' - 3)
    }
    else {
        local pkg_dir "`cwd'"
        local qa_dir "`pkg_dir'/qa"
    }

    local fresh = ("$RM_QA_ISOLATED" == "")
    local plus_changed = 0
    local personal_changed = 0

    if `fresh' {
        * Remember the caller's real trees so teardown can put them back.
        global RM_QA_OLD_PLUS "`c(sysdir_plus)'"
        global RM_QA_OLD_PERSONAL "`c(sysdir_personal)'"

        * Process-unique sandbox names. An unseeded runiform() is NOT unique --
        * Stata's default RNG seed is fixed, so it returns the same draw in every
        * session and collides with the previous run's leftovers. A tempfile name
        * carries the pid, so derive the token from one.
        tempfile _rm_tok_probe
        mata: st_local("_rm_tok", subinstr(pathbasename(st_local("_rm_tok_probe")), ".", "_"))
        local plus_dir "`c(tmpdir)'/rm_qa_plus_`_rm_tok'"
        local personal_dir "`c(tmpdir)'/rm_qa_personal_`_rm_tok'"
        global RM_QA_PLUS "`plus_dir'"
        global RM_QA_PERSONAL "`personal_dir'"
    }

    * Every mutation is inside one captured body. A first-time failure after
    * PLUS moves but before PERSONAL moves used to strand the caller in a
    * half-created sandbox. The cleanup zone below now restores every setting
    * whose mutation succeeded and preserves the original error code.
    capture noisily {
        if `fresh' {
            mkdir "$RM_QA_PLUS"
            mkdir "$RM_QA_PERSONAL"
        }

        * PERSONAL precedes PLUS on the adopath, so a stale PERSONAL copy would
        * shadow the package under test. Redirect both.
        local plus_changed = 1
        sysdir set PLUS "$RM_QA_PLUS"
        local personal_changed = 1
        sysdir set PERSONAL "$RM_QA_PERSONAL"

        * Install exactly once per lane. Later suites rejoin the same sandbox;
        * reinstalling before every file both contradicted the contract above
        * and could hide a preceding suite that damaged the installed surface.
        if `fresh' {
            capture ado uninstall rangematch
            quietly net install rangematch, from("`pkg_dir'") replace
        }
        discard

        * Prove the command resolves, and resolves to the SANDBOX rather than
        * to a source directory left on the adopath by a sibling suite.
        capture findfile rangematch.ado
        if _rc {
            display as error "rangematch.ado does not resolve after the QA install"
            exit 601
        }
        if strpos("`r(fn)'", "$RM_QA_PLUS") != 1 {
            display as error "rangematch resolved to `r(fn)', not the QA sandbox at $RM_QA_PLUS"
            display as error "a sibling suite has left a source directory on the adopath"
            exit 459
        }
    }
    local rc = _rc

    if `rc' & `fresh' {
        local cleanup_rc = 0
        if `personal_changed' {
            capture sysdir set PERSONAL "$RM_QA_OLD_PERSONAL"
            if _rc & !`cleanup_rc' local cleanup_rc = _rc
        }
        if `plus_changed' {
            capture sysdir set PLUS "$RM_QA_OLD_PLUS"
            if _rc & !`cleanup_rc' local cleanup_rc = _rc
        }

        * Clear the cycle only after both restores succeeded. If a restore ever
        * fails, leave the state intact so _rm_qa_teardown can retry it.
        if !`cleanup_rc' {
            global RM_QA_ISOLATED ""
            global RM_QA_PLUS ""
            global RM_QA_PERSONAL ""
            global RM_QA_OLD_PLUS ""
            global RM_QA_OLD_PERSONAL ""
        }
        else {
            global RM_QA_ISOLATED "1"
            display as error "QA bootstrap cleanup failed with rc=`cleanup_rc'"
        }
        exit `rc'
    }

    if `rc' exit `rc'
    if `fresh' global RM_QA_ISOLATED "1"

    return local qa_dir "`qa_dir'"
    return local pkg_dir "`pkg_dir'"
    return local plus_dir "$RM_QA_PLUS"
    return local personal_dir "$RM_QA_PERSONAL"
end

capture program drop _rm_qa_teardown
program define _rm_qa_teardown
    version 16.1

    if "$RM_QA_ISOLATED" == "" exit 0

    * Unconditional restore: every step is attempted, and failed restoration is
    * itself a nonzero result. Never clear the retry state after a failed set.
    capture sysdir set PERSONAL "$RM_QA_OLD_PERSONAL"
    local personal_rc = _rc
    capture sysdir set PLUS "$RM_QA_OLD_PLUS"
    local plus_rc = _rc

    local rc = `personal_rc'
    if !`rc' local rc = `plus_rc'
    if `rc' {
        display as error "QA teardown could not restore both ado trees (PERSONAL rc=`personal_rc', PLUS rc=`plus_rc')"
        exit `rc'
    }

    global RM_QA_ISOLATED ""
    global RM_QA_PLUS ""
    global RM_QA_PERSONAL ""
    global RM_QA_OLD_PLUS ""
    global RM_QA_OLD_PERSONAL ""
end

* Strict runner-sentinel validator (RM-I20).
*
* A suite is green only when its section contains exactly one column-zero line
* of the form
*
*   RESULT: <file-stem> tests=N pass=N fail=0 [skip=N]
*
* with N>0 and pass+fail=N. Nested benchmark results use a different schema
* (`scenarios=') and are ignored; a wrong-name or duplicate test sentinel is a
* hard failure rather than a substitute for the suite's own terminal contract.
capture mata: mata drop _rm_qa_one_sentinel_issue()
capture mata: mata drop _rm_qa_sentinel_issues()
mata:
string scalar _rm_qa_one_sentinel_issue(
    string scalar suite, real scalar nfmt, real scalar nexact, real scalar nvalid)
{
    if (nfmt == 1 & nexact == 1 & nvalid == 1) return("")
    return(suite)
}

string scalar _rm_qa_sentinel_issues(string scalar logpath)
{
    real scalar fh, nfmt, nexact, nvalid, tests, pass, fail
    string scalar line, cur, stem, name, issues, issue

    fh = fopen(logpath, "r")
    cur = ""
    stem = ""
    issues = ""
    nfmt = nexact = nvalid = 0

    while ((line = fget(fh)) != J(0, 0, "")) {
        if (substr(line, 1, 8) == "Running ") {
            if (cur != "") {
                issue = _rm_qa_one_sentinel_issue(cur, nfmt, nexact, nvalid)
                if (issue != "") issues = issues + " " + issue
            }
            cur = strtrim(substr(line, 9, .))
            stem = pathbasename(cur)
            if (substr(stem, strlen(stem) - 2, 3) == ".do") {
                stem = substr(stem, 1, strlen(stem) - 3)
            }
            nfmt = nexact = nvalid = 0
        }
        else if (cur != "" & substr(line, 1, 8) == "RESULT: " &
            ustrregexm(line,
                "^RESULT: ([A-Za-z0-9_]+) tests=([0-9]+) pass=([0-9]+) fail=([0-9]+)( skip=([0-9]+))?$")) {
            nfmt++
            name = ustrregexs(1)
            tests = strtoreal(ustrregexs(2))
            pass = strtoreal(ustrregexs(3))
            fail = strtoreal(ustrregexs(4))
            if (name == stem) {
                nexact++
                if (tests > 0 & pass + fail == tests & fail == 0) nvalid++
            }
        }
    }
    if (cur != "") {
        issue = _rm_qa_one_sentinel_issue(cur, nfmt, nexact, nvalid)
        if (issue != "") issues = issues + " " + issue
    }
    fclose(fh)
    return(strtrim(issues))
}
end

capture program drop _rm_qa_scan_sentinels
program define _rm_qa_scan_sentinels, rclass
    version 16.1
    syntax using/
    mata: st_local("_rm_issues", _rm_qa_sentinel_issues(st_local("using")))
    return local issues "`_rm_issues'"
end
