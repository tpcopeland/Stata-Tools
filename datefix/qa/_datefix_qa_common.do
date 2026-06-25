version 16.0

* Shared QA scaffold for datefix.
*
* datefix tracks no .dta input fixtures: every suite builds its own tiny
* data inline via `input`. This file provides only the sandboxed install
* bootstrap so run_all.do never touches the real ado tree. Single-file runs
* keep their own self-contained `ado uninstall` + `net install` bootstrap.

capture program drop _datefix_qa_bootstrap
program define _datefix_qa_bootstrap, rclass
    version 16.0

    local qa_dir "`c(pwd)'"
    local _qa_len = strlen("`qa_dir'")
    local pkg_dir = substr("`qa_dir'", 1, `_qa_len' - 3)

    if "$DATEFIX_QA_ISOLATED" == "" {
        tempfile _datefix_qa_base
        local plus_dir "`_datefix_qa_base'_plus"
        local personal_dir "`_datefix_qa_base'_personal"
        capture mkdir "`plus_dir'"
        capture mkdir "`personal_dir'"
        global DATEFIX_QA_PLUS "`plus_dir'"
        global DATEFIX_QA_PERSONAL "`personal_dir'"
        global DATEFIX_QA_ISOLATED "1"
    }

    sysdir set PLUS "$DATEFIX_QA_PLUS"
    sysdir set PERSONAL "$DATEFIX_QA_PERSONAL"

    capture ado uninstall datefix
    quietly net install datefix, from("`pkg_dir'") replace

    return local qa_dir "`qa_dir'"
    return local pkg_dir "`pkg_dir'"
end
