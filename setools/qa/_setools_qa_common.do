*! _setools_qa_common.do  1.0.0  2026/07/13
*! Isolated setools QA setup/teardown shared by runner and standalone suites

version 16.0
args action pkg_dir
local action = lower(strtrim("`action'"))

if !inlist("`action'", "setup", "setup_runner", "teardown", "teardown_runner") {
    display as error "_setools_qa_common.do action must be setup, setup_runner, teardown, or teardown_runner"
    exit 198
}

if inlist("`action'", "setup", "setup_runner") {
    if "$SETOOLS_QA_ACTIVE" != "1" {
        if `"`pkg_dir'"' == "" {
            local qa_dir "`c(pwd)'"
            local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
        }
        capture confirm file `"`pkg_dir'/setools.pkg"'
        if _rc {
            display as error "setools package directory not found: `pkg_dir'"
            exit 601
        }

        global SETOOLS_QA_ORIG_PLUS `"`c(sysdir_plus)'"'
        global SETOOLS_QA_ORIG_PERSONAL `"`c(sysdir_personal)'"'
        global SETOOLS_QA_ORIG_VARABBREV "`c(varabbrev)'"
        global SETOOLS_QA_ORIG_MORE "`c(more)'"
        tempfile _setools_qa_seed
        global SETOOLS_QA_ISO "`_setools_qa_seed'_dir"
        global SETOOLS_QA_OWNER = cond("`action'" == "setup_runner", ///
            "runner", "standalone")

        shell /bin/rm -rf -- "$SETOOLS_QA_ISO"
        capture mkdir "$SETOOLS_QA_ISO"
        capture mkdir "$SETOOLS_QA_ISO/plus"
        capture mkdir "$SETOOLS_QA_ISO/personal"
        sysdir set PLUS "$SETOOLS_QA_ISO/plus"
        sysdir set PERSONAL "$SETOOLS_QA_ISO/personal"
        set more off
        set varabbrev off

        * Required session-start inspection is package-targeted.
        capture noisily ado dir setools
        discard
        quietly net install setools, from(`"`pkg_dir'"') replace
        global SETOOLS_QA_ACTIVE 1
    }
    else {
        discard
        which setools
    }
    exit
}

local may_teardown = ("$SETOOLS_QA_ACTIVE" == "1") & ///
    ("`action'" == "teardown_runner" | "$SETOOLS_QA_OWNER" == "standalone")
if `may_teardown' {
    sysdir set PLUS `"$SETOOLS_QA_ORIG_PLUS"'
    sysdir set PERSONAL `"$SETOOLS_QA_ORIG_PERSONAL"'
    set varabbrev $SETOOLS_QA_ORIG_VARABBREV
    set more $SETOOLS_QA_ORIG_MORE
    shell /bin/rm -rf -- "$SETOOLS_QA_ISO"
    global SETOOLS_QA_ACTIVE
    global SETOOLS_QA_OWNER
    global SETOOLS_QA_ISO
    global SETOOLS_QA_ORIG_PLUS
    global SETOOLS_QA_ORIG_PERSONAL
    global SETOOLS_QA_ORIG_VARABBREV
    global SETOOLS_QA_ORIG_MORE
}
