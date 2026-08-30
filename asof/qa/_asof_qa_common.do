*! _asof_qa_common.do - Sandboxed installation bootstrap for asof QA
*! Author: Timothy P Copeland, Karolinska Institutet
*! Requires: Stata 16.0+

version 16.0

capture program drop _asof_qa_bootstrap
program define _asof_qa_bootstrap, rclass
    version 16.0

    local qa_dir "`c(pwd)'"
    local qa_len = strlen("`qa_dir'")
    local pkg_dir = substr("`qa_dir'", 1, `qa_len' - 3)

    if "$ASOF_QA_ISOLATED" == "" {
        tempfile qa_base
        local plus_dir "`qa_base'_plus"
        local personal_dir "`qa_base'_personal"
        capture mkdir "`plus_dir'"
        capture mkdir "`personal_dir'"
        global ASOF_QA_PLUS "`plus_dir'"
        global ASOF_QA_PERSONAL "`personal_dir'"
        global ASOF_QA_ISOLATED "1"
    }

    sysdir set PLUS "$ASOF_QA_PLUS"
    sysdir set PERSONAL "$ASOF_QA_PERSONAL"
    capture ado uninstall asof
    quietly net install asof, from("`pkg_dir'") replace
    discard

    return local qa_dir "`qa_dir'"
    return local pkg_dir "`pkg_dir'"
end
