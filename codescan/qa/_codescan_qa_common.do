version 16.0

* Shared QA scaffold for codescan.
*
* This package tracks no .dta input fixtures: every suite builds its own
* synthetic data inline (input blocks or seeded generators) and writes any
* transient artifact to the qa/ root, where .gitignore keeps it untracked.
*
* _codescan_qa_bootstrap sandboxes the install so the suite never touches the
* developer's real PLUS/PERSONAL adopath, then installs the local package copy
* (not a shadowing SSC/GitHub build higher in the adopath). run_all.do calls it
* once; the per-suite `net install codescan, replace` calls inside each test file
* then refresh into the same sandboxed PLUS, so running a file standalone still
* works against the local source.

capture program drop _codescan_qa_bootstrap
program define _codescan_qa_bootstrap, rclass
    version 16.0

    local qa_dir "`c(pwd)'"
    local _qa_len = strlen("`qa_dir'")
    local pkg_dir = substr("`qa_dir'", 1, `_qa_len' - 3)
    local _pkg_len = strlen("`pkg_dir'")
    local repo_dir = substr("`pkg_dir'", 1, `_pkg_len' - 9)

    if "$CODESCAN_QA_ISOLATED" == "" {
        tempfile _codescan_qa_base
        local plus_dir "`_codescan_qa_base'_plus"
        local personal_dir "`_codescan_qa_base'_personal"
        capture mkdir "`plus_dir'"
        capture mkdir "`personal_dir'"
        global CODESCAN_QA_PLUS "`plus_dir'"
        global CODESCAN_QA_PERSONAL "`personal_dir'"
        global CODESCAN_QA_ISOLATED "1"
    }

    sysdir set PLUS "$CODESCAN_QA_PLUS"
    sysdir set PERSONAL "$CODESCAN_QA_PERSONAL"

    capture ado uninstall codescan
    quietly net install codescan, from("`pkg_dir'") replace
    discard

    return local qa_dir "`qa_dir'"
    return local pkg_dir "`pkg_dir'"
    return local repo_dir "`repo_dir'"
end
