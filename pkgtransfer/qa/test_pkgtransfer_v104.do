/*
    File:    test_pkgtransfer_v104.do
    Purpose: Regression coverage for the pkgtransfer 1.0.4 review fixes
    Author:  Timothy P Copeland, Karolinska Institutet
    Date:    2026-08-11
*/

version 16.0

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local orig_dir "`c(pwd)'"

run "`qa_dir'/_pkgtransfer_qa_common.do"
_pkgtransfer_qa_setup, pkgdir("`pkg_dir'")
local qa_root "`r(root)'"
local qa_original_plus "`r(original_plus)'"
local qa_original_personal "`r(original_personal)'"
local qa_plus "`r(plus)'"
local work "`r(work)'"

capture program drop pkgtransfer
run "`pkg_dir'/pkgtransfer.ado"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# Duplicate limited() entries are a set, not duplicate work items

local ++test_count
capture noisily {
    clear
    set obs 1
    quietly cd "`work'"
    pkgtransfer, limited(alpha alpha) dofile(duplicate.do)
    local returned_n = r(N_packages)
    local returned_list "`r(package_list)'"
    tempname duplicate_fh
    local install_lines 0
    file open `duplicate_fh' using "duplicate.do", read text
    file read `duplicate_fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', " install ") local ++install_lines
        file read `duplicate_fh' line
    }
    file close `duplicate_fh'
    assert `returned_n' == 1
    assert "`returned_list'" == "alpha"
    assert `install_lines' == 1
}
local test_rc = _rc
capture erase "`work'/duplicate.do"
capture quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: duplicate limited() entries are normalized"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' duplicate_limited"
    display as error "  FAIL: duplicate limited() entries (rc `test_rc')"
}

**# Output filenames containing quotes are rejected before file creation

local ++test_count
capture noisily {
    clear
    set obs 1
    quietly cd "`work'"
    capture noisily pkgtransfer, dofile("bad'name.do")
    assert _rc == 198
    capture confirm file "bad'name.do"
    assert _rc == 601
}
local test_rc = _rc
capture erase "`work'/bad'name.do"
capture quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: quoted dofile() names are rejected"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' quoted_dofile"
    display as error "  FAIL: quoted dofile() guard (rc `test_rc')"
}

local ++test_count
capture noisily {
    clear
    set obs 1
    quietly cd "`work'"
    capture noisily pkgtransfer, download(local) limited(pkgtransfer) ///
        dofile(quote_guard.do) zipfile("bad'name.zip")
    assert _rc == 198
    capture confirm file "quote_guard.do"
    assert _rc == 601
    capture confirm file "bad'name.zip"
    assert _rc == 601
}
local test_rc = _rc
capture quietly cd "`work'"
capture quietly _pkgtransfer_cleanup_staging, ///
    directory("`work'/pkgtransfer_files")
capture erase "`work'/quote_guard.do"
capture erase "`work'/bad'name.zip"
capture quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: quoted zipfile() names are rejected"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' quoted_zipfile"
    display as error "  FAIL: quoted zipfile() guard (rc `test_rc')"
}

**# The default installer and return payload describe the same packages

local ++test_count
capture noisily {
    clear
    set obs 1
    quietly cd "`work'"
    pkgtransfer, dofile(default_contract.do)
    local returned_n = r(N_packages)
    local returned_list "`r(package_list)'"
    tempname default_fh
    local install_lines 0
    local matched_lines 0
    file open `default_fh' using "default_contract.do", read text
    file read `default_fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', " install ") {
            local ++install_lines
            foreach pkg of local returned_list {
                if strpos(`"`macval(line)'"', " install `pkg'") ///
                    local ++matched_lines
            }
        }
        file read `default_fh' line
    }
    file close `default_fh'
    assert `returned_n' == `install_lines'
    assert `matched_lines' == `install_lines'
}
local test_rc = _rc
capture file close `default_fh'
capture erase "`work'/default_contract.do"
capture quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: default script and r() package sets match"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' default_return_contract"
    display as error "  FAIL: default script/return contract (rc `test_rc')"
}

**# Local bundles preserve ordinary nested files

local ++test_count
tempname nested_source nested_tracker nested_pkg
capture noisily {
    clear
    set obs 1
    mkdir "`qa_plus'/n"
    mkdir "`qa_plus'/n/nested"
    file open `nested_source' using ///
        "`qa_plus'/n/nested/nestedfixture.ado", write text replace
    file write `nested_source' "program define nestedfixture" _n
    file write `nested_source' "end" _n
    file close `nested_source'
    file open `nested_tracker' using "`qa_plus'/stata.trk", ///
        write text append
    file write `nested_tracker' "S https://example.org/nestedfixture" _n
    file write `nested_tracker' "N nestedfixture.pkg" _n
    file write `nested_tracker' "d nested fixture" _n
    file write `nested_tracker' "f n/nested/nestedfixture.ado" _n
    file write `nested_tracker' "e" _n
    file close `nested_tracker'

    quietly cd "`work'"
    pkgtransfer, download(local) limited(nestedfixture) ///
        dofile(nested_local.do) zipfile(nested_local.zip)
    mkdir "nested_local_extract"
    quietly cd "nested_local_extract"
    unzipfile "../nested_local.zip", replace
    confirm file "pkgtransfer_files/nested/nestedfixture.ado"
    file open `nested_pkg' using ///
        "pkgtransfer_files/nestedfixture.pkg", read text
    local found_nested 0
    file read `nested_pkg' line
    while r(eof) == 0 {
        if `"`macval(line)'"' == ///
            "f nested/nestedfixture.ado" local found_nested 1
        file read `nested_pkg' line
    }
    file close `nested_pkg'
    assert `found_nested' == 1
}
local test_rc = _rc
foreach handle in nested_source nested_tracker nested_pkg {
    capture file close ``handle''
}
capture quietly cd "`work'"
capture quietly _pkgtransfer_cleanup_staging, ///
    directory("`work'/nested_local_extract")
foreach artifact in nested_local.do nested_local.zip {
    capture erase "`work'/`artifact'"
}
capture quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: local nested files retain their paths"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' local_nested"
    display as error "  FAIL: local nested file bundle (rc `test_rc')"
}

**# Online bundles preserve ordinary nested files

local ++test_count
local online_source "`work'/online_source"
tempname online_asset online_pkg online_tracker online_bundled_pkg
capture noisily {
    clear
    set obs 1
    mkdir "`online_source'"
    mkdir "`online_source'/nested"
    file open `online_asset' using ///
        "`online_source'/nested/onlineasset.txt", write text replace
    file write `online_asset' "nested online asset" _n
    file close `online_asset'
    file open `online_pkg' using ///
        "`online_source'/nestedonline.pkg", write text replace
    file write `online_pkg' "v 3" _n
    file write `online_pkg' "d nested online fixture" _n
    file write `online_pkg' "f nested/onlineasset.txt" _n
    file close `online_pkg'
    file open `online_tracker' using "`qa_plus'/stata.trk", ///
        write text append
    file write `online_tracker' "S `online_source'" _n
    file write `online_tracker' "N nestedonline.pkg" _n
    file write `online_tracker' "d nested online fixture" _n
    file write `online_tracker' "e" _n
    file close `online_tracker'

    quietly cd "`work'"
    pkgtransfer, download(online) limited(nestedonline) ///
        dofile(nested_online.do) zipfile(nested_online.zip)
    mkdir "nested_online_extract"
    quietly cd "nested_online_extract"
    unzipfile "../nested_online.zip", replace
    confirm file "pkgtransfer_files/nested/onlineasset.txt"
    file open `online_bundled_pkg' using ///
        "pkgtransfer_files/nestedonline.pkg", read text
    local found_nested 0
    file read `online_bundled_pkg' line
    while r(eof) == 0 {
        if `"`macval(line)'"' == ///
            "f nested/onlineasset.txt" local found_nested 1
        file read `online_bundled_pkg' line
    }
    file close `online_bundled_pkg'
    assert `found_nested' == 1
}
local test_rc = _rc
foreach handle in online_asset online_pkg online_tracker online_bundled_pkg {
    capture file close ``handle''
}
capture quietly cd "`work'"
capture quietly _pkgtransfer_cleanup_staging, ///
    directory("`work'/nested_online_extract")
capture quietly _pkgtransfer_cleanup_staging, directory("`online_source'")
foreach artifact in nested_online.do nested_online.zip {
    capture erase "`work'/`artifact'"
}
capture quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: online nested files retain their paths"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' online_nested"
    display as error "  FAIL: online nested file bundle (rc `test_rc')"
}

**# Online bundles preserve platform and nested plugin source paths

local ++test_count
local online_plugin_source "`work'/online_plugin_source"
tempname online_plugin_file online_plugin_pkg online_plugin_tracker ///
    online_plugin_bundled_pkg
capture noisily {
    clear
    set obs 1
    mkdir "`online_plugin_source'"
    mkdir "`online_plugin_source'/nested"
    file open `online_plugin_file' using ///
        "`online_plugin_source'/nested/onlineplugin.plugin", ///
        write text replace
    file write `online_plugin_file' "nested online plugin" _n
    file close `online_plugin_file'
    file open `online_plugin_pkg' using ///
        "`online_plugin_source'/nestedplugin.pkg", write text replace
    file write `online_plugin_pkg' "v 3" _n
    file write `online_plugin_pkg' "d nested plugin fixture" _n
    file write `online_plugin_pkg' ///
        "g LINUX64 nested/onlineplugin.plugin" _n
    file close `online_plugin_pkg'
    file open `online_plugin_tracker' using "`qa_plus'/stata.trk", ///
        write text append
    file write `online_plugin_tracker' "S `online_plugin_source'" _n
    file write `online_plugin_tracker' "N nestedplugin.pkg" _n
    file write `online_plugin_tracker' "d nested plugin fixture" _n
    file write `online_plugin_tracker' "e" _n
    file close `online_plugin_tracker'

    quietly cd "`work'"
    pkgtransfer, download(online) limited(nestedplugin) ///
        dofile(nested_plugin.do) zipfile(nested_plugin.zip)
    mkdir "nested_plugin_extract"
    quietly cd "nested_plugin_extract"
    unzipfile "../nested_plugin.zip", replace
    confirm file ///
        "pkgtransfer_files/nested/onlineplugin.plugin"
    file open `online_plugin_bundled_pkg' using ///
        "pkgtransfer_files/nestedplugin.pkg", read text
    local found_nested_plugin 0
    file read `online_plugin_bundled_pkg' line
    while r(eof) == 0 {
        if `"`macval(line)'"' == ///
            "g LINUX64 nested/onlineplugin.plugin" ///
            local found_nested_plugin 1
        file read `online_plugin_bundled_pkg' line
    }
    file close `online_plugin_bundled_pkg'
    assert `found_nested_plugin' == 1
}
local test_rc = _rc
foreach handle in online_plugin_file online_plugin_pkg ///
    online_plugin_tracker online_plugin_bundled_pkg {
    capture file close ``handle''
}
capture quietly cd "`work'"
capture quietly _pkgtransfer_cleanup_staging, ///
    directory("`work'/nested_plugin_extract")
capture quietly _pkgtransfer_cleanup_staging, ///
    directory("`online_plugin_source'")
foreach artifact in nested_plugin.do nested_plugin.zip {
    capture erase "`work'/`artifact'"
}
capture quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: online plugin records retain nested paths"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' online_plugin_nested"
    display as error "  FAIL: online nested plugin bundle (rc `test_rc')"
}

**# Tracked paths may not escape the invocation-owned staging root

local ++test_count
local traversal_root "`work'/traversal"
tempname traversal_source traversal_sentinel traversal_tracker traversal_verify
capture noisily {
    clear
    set obs 1
    foreach dir in ///
        "`traversal_root'" ///
        "`traversal_root'/a" ///
        "`traversal_root'/a/b" ///
        "`traversal_root'/a/b/c" ///
        "`traversal_root'/a/b/c/plus" ///
        "`traversal_root'/work" {
        mkdir `"`dir'"'
    }
    file open `traversal_source' using ///
        "`traversal_root'/a/escape.txt", write text replace
    file write `traversal_source' "source-content" _n
    file close `traversal_source'
    file open `traversal_sentinel' using ///
        "`traversal_root'/work/escape.txt", write text replace
    file write `traversal_sentinel' "caller-owned" _n
    file close `traversal_sentinel'
    file open `traversal_tracker' using ///
        "`traversal_root'/a/b/c/plus/stata.trk", write text replace
    file write `traversal_tracker' "S https://example.org/traversal" _n
    file write `traversal_tracker' "N traversal.pkg" _n
    file write `traversal_tracker' "d traversal fixture" _n
    file write `traversal_tracker' "f ../../../escape.txt" _n
    file write `traversal_tracker' "e" _n
    file close `traversal_tracker'
    sysdir set PLUS "`traversal_root'/a/b/c/plus"
    quietly cd "`traversal_root'/work"
    capture noisily pkgtransfer, download(local) limited(traversal) ///
        dofile(traversal.do) zipfile(traversal.zip)
    local command_rc = _rc
    file open `traversal_verify' using ///
        "`traversal_root'/work/escape.txt", read text
    file read `traversal_verify' sentinel_line
    file close `traversal_verify'
    assert `command_rc' == 198
    assert `"`macval(sentinel_line)'"' == "caller-owned"
}
local test_rc = _rc
foreach handle in traversal_source traversal_sentinel traversal_tracker traversal_verify {
    capture file close ``handle''
}
capture sysdir set PLUS "`qa_plus'"
capture quietly cd "`work'"
capture quietly _pkgtransfer_cleanup_staging, directory("`traversal_root'")
capture quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: traversal records are rejected before writes"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' traversal"
    display as error "  FAIL: staging traversal guard (rc `test_rc')"
}

**# Side-effect failures retain the analytical return payload

local ++test_count
capture noisily {
    clear
    set obs 1
    quietly cd "`work'"
    capture noisily pkgtransfer, download(local) limited(pkgtransfer) ///
        dofile(missing_parent/fail.do) zipfile(fail.zip)
    local command_rc = _rc
    assert `command_rc' == 603
    assert "`r(download_mode)'" == "local"
    assert "`r(os)'" == "`c(os)'"
    assert r(N_packages) == 1
    assert "`r(package_list)'" == "pkgtransfer"
    assert "`r(dofile)'" == "missing_parent/fail.do"
    assert "`r(zipfile)'" == "fail.zip"
}
local test_rc = _rc
capture erase "`work'/fail.zip"
capture quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: failed side effects preserve r()"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' return_gate"
    display as error "  FAIL: failed-side-effect return gate (rc `test_rc')"
}

**# Generated installers do not overwrite caller globals

local ++test_count
local install_plus "`work'/installer_plus"
local original_package_dir "$package_dir"
capture noisily {
    clear
    set obs 1
    quietly cd "`work'"
    pkgtransfer, download(local) limited(pkgtransfer) ///
        dofile(installer_state.do) zipfile(installer_state.zip)
    mkdir "`install_plus'"
    mkdir "`install_plus'/p"
    sysdir set PLUS "`install_plus'"
    global package_dir "caller-owned"
    do installer_state.do
    assert "$package_dir" == "caller-owned"
}
local test_rc = _rc
capture sysdir set PLUS "`qa_plus'"
if `"`original_package_dir'"' == "" {
    capture macro drop package_dir
}
else {
    global package_dir `"`original_package_dir'"'
}
capture quietly cd "`work'"
capture quietly _pkgtransfer_cleanup_staging, directory("`install_plus'")
capture quietly _pkgtransfer_cleanup_staging, ///
    directory("`work'/pkgtransfer_files")
foreach artifact in installer_state.do installer_state.zip {
    capture erase "`work'/`artifact'"
}
capture quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: installer preserves caller globals"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' installer_global"
    display as error "  FAIL: installer global-state contract (rc `test_rc')"
}

**# Duplicate tracked package definitions fail in every transfer mode

local ++test_count
tempname duplicate_source duplicate_tracker
capture noisily {
    clear
    set obs 1
    file open `duplicate_source' using ///
        "`qa_plus'/a/alpha_duplicate.ado", write text replace
    file write `duplicate_source' "program define alpha_duplicate" _n
    file write `duplicate_source' "end" _n
    file close `duplicate_source'
    file open `duplicate_tracker' using "`qa_plus'/stata.trk", ///
        write text append
    file write `duplicate_tracker' "S https://mirror.example.org/alpha" _n
    file write `duplicate_tracker' "N alpha.pkg" _n
    file write `duplicate_tracker' "d duplicate alpha fixture" _n
    file write `duplicate_tracker' "f a/alpha_duplicate.ado" _n
    file write `duplicate_tracker' "e" _n
    file close `duplicate_tracker'
    quietly cd "`work'"
    capture noisily pkgtransfer, download(local) limited(alpha) ///
        dofile(duplicate_source.do) zipfile(duplicate_source.zip)
    assert _rc == 459
    capture confirm file "duplicate_source.do"
    assert _rc == 601
    capture confirm file "duplicate_source.zip"
    assert _rc == 601
}
local test_rc = _rc
foreach handle in duplicate_source duplicate_tracker {
    capture file close ``handle''
}
capture quietly cd "`work'"
capture quietly _pkgtransfer_cleanup_staging, ///
    directory("`work'/pkgtransfer_files")
foreach artifact in duplicate_source.do duplicate_source.zip {
    capture erase "`work'/`artifact'"
}
capture quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: duplicate tracked definitions are rejected"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' duplicate_source"
    display as error "  FAIL: duplicate tracked definitions (rc `test_rc')"
}

capture noisily _pkgtransfer_qa_cleanup, root("`qa_root'") ///
    originalplus("`qa_original_plus'") ///
    originalpersonal("`qa_original_personal'")
if _rc != 0 {
    local ++test_count
    local ++fail_count
    local failed_tests "`failed_tests' fixture_cleanup"
}

display "RESULT: test_pkgtransfer_v104 tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 1
}
