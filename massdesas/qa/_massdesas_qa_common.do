* _massdesas_qa_common.do
*
* Isolated installation bootstrap for massdesas QA
*
* Author: Timothy P Copeland, Karolinska Institutet
* Date: 2026-08-05

version 14.0

capture program drop _massdesas_qa_cleanup
program define _massdesas_qa_cleanup
    version 14.0

    if "$MASSDESAS_QA_ORIG_PLUS" != "" {
        sysdir set PLUS "$MASSDESAS_QA_ORIG_PLUS"
        sysdir set PERSONAL "$MASSDESAS_QA_ORIG_PERSONAL"
        discard
    }
    if "$MASSDESAS_QA_PLUS" != "" {
        capture shell rm -rf "$MASSDESAS_QA_PLUS" "$MASSDESAS_QA_PERSONAL"
    }
    global MASSDESAS_QA_ORIG_PLUS
    global MASSDESAS_QA_ORIG_PERSONAL
    global MASSDESAS_QA_PLUS
    global MASSDESAS_QA_PERSONAL
end

capture program drop _massdesas_qa_bootstrap
program define _massdesas_qa_bootstrap, rclass
    version 14.0

    local qa_dir `"`c(pwd)'"'
    local pkg_dir "`qa_dir'/.."

    if "$MASSDESAS_QA_PLUS" == "" {
        tempfile qa_token
        local plus_dir "`qa_token'_massdesas_plus"
        local personal_dir "`qa_token'_massdesas_personal"
        capture mkdir "`plus_dir'"
        capture mkdir "`personal_dir'"
        global MASSDESAS_QA_ORIG_PLUS `"`c(sysdir_plus)'"'
        global MASSDESAS_QA_ORIG_PERSONAL `"`c(sysdir_personal)'"'
        global MASSDESAS_QA_PLUS "`plus_dir'"
        global MASSDESAS_QA_PERSONAL "`personal_dir'"
    }

    sysdir set PLUS "$MASSDESAS_QA_PLUS"
    sysdir set PERSONAL "$MASSDESAS_QA_PERSONAL"
    discard

    local dep_rc = 0
    foreach dep in filelist fs {
        capture noisily ssc install `dep', replace
        if _rc local dep_rc = _rc
        capture which `dep'
        if _rc local dep_rc = 111
    }
    if `dep_rc' {
        display as error "required QA dependencies filelist and fs could not be installed"
        _massdesas_qa_cleanup
        exit `dep_rc'
    }

    capture ado uninstall massdesas
    capture noisily net install massdesas, from("`pkg_dir'") replace
    local install_rc = _rc
    if `install_rc' {
        display as error "local massdesas installation failed (rc=`install_rc')"
        _massdesas_qa_cleanup
        exit `install_rc'
    }

    capture which massdesas
    if _rc {
        local which_rc = _rc
        _massdesas_qa_cleanup
        exit `which_rc'
    }

    return local qa_dir `"`qa_dir'"'
    return local pkg_dir `"`pkg_dir'"'
end
