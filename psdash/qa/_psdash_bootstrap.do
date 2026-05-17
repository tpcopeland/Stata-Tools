* _psdash_bootstrap.do -- shared local-install bootstrap for psdash QA
* Usage: run from psdash/qa before executing package tests.

version 16.0

local _psdash_qa_dir "`c(pwd)'"
local _psdash_pkg_dir "`_psdash_qa_dir'"
if length("`_psdash_pkg_dir'") >= 3 {
    if substr("`_psdash_pkg_dir'", length("`_psdash_pkg_dir'") - 2, 3) == "/qa" {
        local _psdash_pkg_dir = substr("`_psdash_pkg_dir'", 1, length("`_psdash_pkg_dir'") - 3)
    }
}
if !strpos("`_psdash_pkg_dir'", "psdash") {
    local _psdash_pkg_dir "`_psdash_pkg_dir'/psdash"
}

local _psdash_plus_orig "`c(sysdir_plus)'"
local _psdash_personal_orig "`c(sysdir_personal)'"
tempfile _psdash_marker
local _psdash_sysroot "`_psdash_marker'_sysdir"
local _psdash_plus "`_psdash_sysroot'/plus"
local _psdash_personal "`_psdash_sysroot'/personal"
capture mkdir "`_psdash_sysroot'"
capture mkdir "`_psdash_plus'"
capture mkdir "`_psdash_personal'"

sysdir set PLUS "`_psdash_plus'"
sysdir set PERSONAL "`_psdash_personal'"

capture program drop _psdash_qa_cleanup
program define _psdash_qa_cleanup
    version 16.0
    capture ado uninstall psdash
    if `"$PSDASH_QA_PLUS_ORIG"' != "" {
        sysdir set PLUS `"$PSDASH_QA_PLUS_ORIG"'
    }
    if `"$PSDASH_QA_PERSONAL_ORIG"' != "" {
        sysdir set PERSONAL `"$PSDASH_QA_PERSONAL_ORIG"'
    }
    if `"$PSDASH_QA_SYSROOT"' != "" {
        capture shell rm -rf `"$PSDASH_QA_SYSROOT"'
    }
    global PSDASH_QA_PLUS_ORIG
    global PSDASH_QA_PERSONAL_ORIG
    global PSDASH_QA_SYSROOT
end

global PSDASH_QA_PLUS_ORIG `"`_psdash_plus_orig'"'
global PSDASH_QA_PERSONAL_ORIG `"`_psdash_personal_orig'"'
global PSDASH_QA_SYSROOT `"`_psdash_sysroot'"'

capture ado uninstall psdash
capture noisily net install psdash, from("`_psdash_pkg_dir'") replace
local _psdash_install_rc = _rc
if `_psdash_install_rc' {
    _psdash_qa_cleanup
    exit `_psdash_install_rc'
}

c_local qa_dir "`_psdash_qa_dir'"
c_local pkg_dir "`_psdash_pkg_dir'"
c_local _qa_plus_orig "`_psdash_plus_orig'"
c_local _qa_personal_orig "`_psdash_personal_orig'"
c_local _qa_sysroot "`_psdash_sysroot'"
c_local _qa_plus "`_psdash_plus'"
c_local _qa_personal "`_psdash_personal'"
c_local _psdash_qa_bootstrap_loaded "1"
