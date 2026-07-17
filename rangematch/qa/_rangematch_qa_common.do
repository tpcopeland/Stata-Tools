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

    if "$RM_QA_ISOLATED" == "" {
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
        capture mkdir "`plus_dir'"
        capture mkdir "`personal_dir'"

        global RM_QA_PLUS "`plus_dir'"
        global RM_QA_PERSONAL "`personal_dir'"
        global RM_QA_ISOLATED "1"
    }

    * PERSONAL precedes PLUS on the adopath, so a stale PERSONAL copy would
    * shadow the package under test. Redirect both.
    sysdir set PLUS "$RM_QA_PLUS"
    sysdir set PERSONAL "$RM_QA_PERSONAL"

    * Install into the sandbox. This is now a no-op against the user's real
    * tree, so `ado uninstall' here is safe.
    capture ado uninstall rangematch
    quietly net install rangematch, from("`pkg_dir'") replace
    discard

    * Prove the command resolves, and resolves to the SANDBOX rather than to a
    * source directory left on the adopath by a sibling suite. Without this the
    * lane can report green for code it never loaded.
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

    return local qa_dir "`qa_dir'"
    return local pkg_dir "`pkg_dir'"
    return local plus_dir "$RM_QA_PLUS"
    return local personal_dir "$RM_QA_PERSONAL"
end

capture program drop _rm_qa_teardown
program define _rm_qa_teardown
    version 16.1

    if "$RM_QA_ISOLATED" == "" exit 0

    * Unconditional restore: every step capture'd so one failure cannot strand
    * the caller in the sandbox.
    capture sysdir set PLUS "$RM_QA_OLD_PLUS"
    capture sysdir set PERSONAL "$RM_QA_OLD_PERSONAL"
    global RM_QA_ISOLATED ""
end
