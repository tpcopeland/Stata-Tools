/*
    File:    test_pkgtransfer_installed.do
    Purpose: Exercise pkgtransfer through Stata's installed-user autoloader
    Author:  Timothy P Copeland, Karolinska Institutet
    Date:    2026-08-11
*/

version 16.0
capture log close _all

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local orig_dir "`c(pwd)'"
local original_plus "`c(sysdir_plus)'"
local original_personal "`c(sysdir_personal)'"

run "`qa_dir'/_pkgtransfer_qa_common.do"
tempfile qa_marker
local qa_root "`qa_marker'_root"
local qa_plus "`qa_root'/plus"
local qa_personal "`qa_root'/personal"
local work "`qa_root'/work"

foreach dir in ///
    `"`qa_root'"' ///
    `"`qa_plus'"' ///
    `"`qa_personal'"' ///
    `"`work'"' {
    mkdir `"`dir'"'
}

local test_count 1
local pass_count 0
local fail_count 0
local failed_tests ""

capture noisily {
    sysdir set PLUS `"`qa_plus'"'
    sysdir set PERSONAL `"`qa_personal'"'
    quietly ado dir
    capture ado uninstall pkgtransfer
    net install pkgtransfer, from(`"`pkg_dir'"') replace
    discard
    which pkgtransfer
    findfile pkgtransfer.ado
    local installed_ado `"`r(fn)'"'
    assert strpos(`"`installed_ado'"', `"`qa_plus'/"') == 1

    quietly cd `"`work'"'
    pkgtransfer, download(local) limited(pkgtransfer) ///
        dofile(installed_local.do) zipfile(installed_local.zip)
    assert r(N_packages) == 1
    assert "`r(package_list)'" == "pkgtransfer"
    confirm file "installed_local.do"
    confirm file "installed_local.zip"

    mkdir "installed_extract"
    quietly cd "installed_extract"
    unzipfile "../installed_local.zip", replace
    confirm file "pkgtransfer_files/pkgtransfer.ado"
    confirm file "pkgtransfer_files/pkgtransfer.sthlp"

    tempname bundled_ado
    local found_prepare 0
    local found_cleanup 0
    file open `bundled_ado' using ///
        "pkgtransfer_files/pkgtransfer.ado", read text
    file read `bundled_ado' line
    while r(eof) == 0 {
        if `"`macval(line)'"' == ///
            "program define _pkgtransfer_prepare_destination, nclass" ///
            local found_prepare 1
        if `"`macval(line)'"' == ///
            "program define _pkgtransfer_cleanup_staging, nclass" ///
            local found_cleanup 1
        file read `bundled_ado' line
    }
    file close `bundled_ado'
    assert `found_prepare' == 1
    assert `found_cleanup' == 1
}
local test_rc = _rc

capture file close `bundled_ado'
capture quietly cd `"`orig_dir'"'
capture program drop pkgtransfer
capture program drop _pkgtransfer_prepare_destination
capture program drop _pkgtransfer_cleanup_staging
capture noisily _pkgtransfer_qa_cleanup, root(`"`qa_root'"') ///
    originalplus(`"`original_plus'"') ///
    originalpersonal(`"`original_personal'"')
local cleanup_rc = _rc
if `test_rc' == 0 & `cleanup_rc' != 0 local test_rc = `cleanup_rc'

if `test_rc' == 0 {
    local pass_count 1
}
else {
    local fail_count 1
    local failed_tests "installed_local_bundle"
}

display ///
    "RESULT: test_pkgtransfer_installed tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    display as error "Failed tests: `failed_tests' (rc `test_rc')"
    exit 1
}
