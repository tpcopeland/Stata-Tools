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

capture program drop iivw_qa_bootstrap
program define iivw_qa_bootstrap
    version 16.0
    syntax [, PKGdir(string) NOInstall]

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
            display as error "iivw_qa_bootstrap: run from the package's qa/ directory,"
            display as error "  or pass pkgdir()"
            exit 601
        }
    }
    capture confirm file "`pkgdir'/iivw.pkg"
    if _rc {
        display as error "iivw_qa_bootstrap: no iivw.pkg under `pkgdir'"
        exit 601
    }

    * Sandbox the ado tree for this process.
    tempfile _stub
    local sandbox "`_stub'_sysdir"
    capture mkdir "`sandbox'"
    capture mkdir "`sandbox'/plus"
    capture mkdir "`sandbox'/personal"
    capture confirm file "`sandbox'/plus"
    if _rc {
        display as error "iivw_qa_bootstrap: could not create sysdir sandbox `sandbox'"
        exit 603
    }
    sysdir set PLUS     "`sandbox'/plus"
    sysdir set PERSONAL "`sandbox'/personal"

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

    display as text "iivw QA sandbox: `sandbox'  (user's PLUS/PERSONAL untouched)"
end
