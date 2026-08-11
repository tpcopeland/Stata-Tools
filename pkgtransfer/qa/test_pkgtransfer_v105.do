/*
    File:    test_pkgtransfer_v105.do
    Purpose: Regression coverage for defects found in the 1.0.5 deep review
    Author:  Timothy P Copeland, Karolinska Institutet
    Date:    2026-08-11
*/

version 16.0
capture log close _all

**# Setup

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

**# Generated distribution metadata

local ++test_count
tempname meta_source meta_tracker meta_pkg meta_toc
capture noisily {
    clear
    set obs 1
    mkdir "`qa_plus'/m"
    file open `meta_source' using "`qa_plus'/m/metafixture.ado", ///
        write text replace
    file write `meta_source' "program define metafixture" _n
    file write `meta_source' "end" _n
    file close `meta_source'

    file open `meta_tracker' using "`qa_plus'/stata.trk", ///
        write text replace
    file write `meta_tracker' "S https://example.org/metafixture" _n
    file write `meta_tracker' "N metafixture.pkg" _n
    file write `meta_tracker' "d A descriptive title" _n
    file write `meta_tracker' "f m/metafixture.ado" _n
    file write `meta_tracker' "e" _n
    file close `meta_tracker'

    quietly cd "`work'"
    pkgtransfer, download(local) limited(metafixture) ///
        dofile(meta.do) zipfile(meta.zip)
    mkdir "meta_extract"
    quietly cd "meta_extract"
    unzipfile "../meta.zip", replace

    file open `meta_pkg' using ///
        "pkgtransfer_files/metafixture.pkg", read text
    file read `meta_pkg' pkg_first
    assert `"`macval(pkg_first)'"' == "v 3"
    local first_description ""
    local marker_seen 0
    local marker_before_end 0
    file read `meta_pkg' line
    while r(eof) == 0 {
        if substr(`"`macval(line)'"', 1, 2) == "d " & ///
            `"`first_description'"' == "" ///
            local first_description `"`macval(line)'"'
        if substr(`"`macval(line)'"', 1, 21) == ///
            "d pkgtransfer-source " local marker_seen 1
        if strtrim(`"`macval(line)'"') == "e" & `marker_seen' ///
            local marker_before_end 1
        file read `meta_pkg' line
    }
    file close `meta_pkg'
    assert `"`first_description'"' == "d A descriptive title"
    assert `marker_seen' == 1
    assert `marker_before_end' == 1

    file open `meta_toc' using ///
        "pkgtransfer_files/stata.toc", read text
    file read `meta_toc' toc_first
    local found_package 0
    while r(eof) == 0 {
        if `"`macval(toc_first)'"' == ///
            "p metafixture A descriptive title" local found_package 1
        file read `meta_toc' toc_first
    }
    file close `meta_toc'
    assert `found_package' == 1

    file open `meta_toc' using ///
        "pkgtransfer_files/stata.toc", read text
    file read `meta_toc' toc_first
    file close `meta_toc'
    assert `"`macval(toc_first)'"' == "v 3"
}
local test_rc = _rc
foreach handle in meta_source meta_tracker meta_pkg meta_toc {
    capture file close ``handle''
}
capture quietly cd "`work'"
capture quietly _pkgtransfer_cleanup_staging, ///
    directory("`work'/meta_extract")
foreach artifact in meta.do meta.zip {
    capture erase "`work'/`artifact'"
}
capture quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: generated .pkg and stata.toc are canonical"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' generated_metadata"
    display as error "  FAIL: generated distribution metadata (rc `test_rc')"
}

**# Local SSC plugin descriptor lookup

local ++test_count
local ssc_source "`work'/ssc_source/fake.bc.edu/repec/bocode/s"
local ssc_root "`work'/ssc_source"
tempname ssc_pkg ssc_plugin ssc_installed ssc_ado ssc_tracker
capture noisily {
    clear
    set obs 1
    foreach dir in ///
        "`ssc_root'" ///
        "`ssc_root'/fake.bc.edu" ///
        "`ssc_root'/fake.bc.edu/repec" ///
        "`ssc_root'/fake.bc.edu/repec/bocode" ///
        "`ssc_source'" {
        mkdir `"`dir'"'
    }
    file open `ssc_plugin' using ///
        "`ssc_source'/sscfixture.plugin", write text replace
    file write `ssc_plugin' "ssc plugin payload" _n
    file close `ssc_plugin'
    file open `ssc_pkg' using "`ssc_source'/sscfixture.pkg", ///
        write text replace
    file write `ssc_pkg' "v 3" _n
    file write `ssc_pkg' "d SSC plugin fixture" _n
    file write `ssc_pkg' "g LINUX64 sscfixture.plugin" _n
    file write `ssc_pkg' "h sscfixture.plugin" _n
    file write `ssc_pkg' "f sscfixture.ado" _n
    file close `ssc_pkg'
    file open `ssc_installed' using ///
        "`qa_plus'/p/sscfixture.plugin", write text replace
    file write `ssc_installed' "installed plugin payload" _n
    file close `ssc_installed'
    file open `ssc_ado' using "`qa_plus'/p/sscfixture.ado", ///
        write text replace
    file write `ssc_ado' "program define sscfixture" _n
    file write `ssc_ado' "end" _n
    file close `ssc_ado'
    file open `ssc_tracker' using "`qa_plus'/stata.trk", ///
        write text replace
    file write `ssc_tracker' "S `ssc_source'" _n
    file write `ssc_tracker' "N sscfixture.pkg" _n
    file write `ssc_tracker' "d SSC plugin fixture" _n
    file write `ssc_tracker' "f p/sscfixture.plugin" _n
    file write `ssc_tracker' "f p/sscfixture.ado" _n
    file write `ssc_tracker' "e" _n
    file close `ssc_tracker'

    quietly cd "`work'"
    pkgtransfer, download(local) limited(sscfixture) ///
        dofile(ssc.do) zipfile(ssc.zip)
    mkdir "ssc_extract"
    quietly cd "ssc_extract"
    unzipfile "../ssc.zip", replace
    confirm file "pkgtransfer_files/sscfixture.pkg"
    confirm file "pkgtransfer_files/sscfixture.plugin"
}
local test_rc = _rc
foreach handle in ssc_pkg ssc_plugin ssc_installed ssc_ado ssc_tracker {
    capture file close ``handle''
}
capture quietly cd "`work'"
capture quietly _pkgtransfer_cleanup_staging, ///
    directory("`work'/ssc_extract")
capture quietly _pkgtransfer_cleanup_staging, directory("`ssc_root'")
foreach artifact in ssc.do ssc.zip {
    capture erase "`work'/`artifact'"
}
capture quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: local SSC plugin descriptor uses its .pkg path"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' ssc_plugin_descriptor"
    display as error "  FAIL: local SSC plugin descriptor (rc `test_rc')"
}

**# Parent-relative plugin source paths

local ++test_count
local relative_root "`work'/relative_source"
local relative_pkgdir "`relative_root'/pkg"
local relative_assets "`relative_root'/assets"
local relative_extract "`work'/relative_extract"
local relative_install "`work'/relative_install"
tempname relative_pkg relative_source relative_installed relative_ado ///
    relative_tracker relative_bundled relative_verify
capture noisily {
    clear
    set obs 1
    mkdir "`relative_root'"
    mkdir "`relative_pkgdir'"
    mkdir "`relative_assets'"
    file open `relative_source' using ///
        "`relative_assets'/relfixture.plugin", write text replace
    file write `relative_source' "downloaded relative plugin" _n
    file close `relative_source'
    file open `relative_pkg' using "`relative_pkgdir'/relfixture.pkg", ///
        write text replace
    file write `relative_pkg' "v 3" _n
    file write `relative_pkg' "d Relative plugin fixture" _n
    file write `relative_pkg' ///
        "G LINUX64 ../assets/relfixture.plugin relfixture.plugin" _n
    file write `relative_pkg' "h relfixture.plugin" _n
    file write `relative_pkg' "f relfixture.ado" _n
    file close `relative_pkg'
    file open `relative_installed' using ///
        "`qa_plus'/p/relfixture.plugin", write text replace
    file write `relative_installed' "stale installed plugin" _n
    file close `relative_installed'
    file open `relative_ado' using "`qa_plus'/p/relfixture.ado", ///
        write text replace
    file write `relative_ado' "program define relfixture" _n
    file write `relative_ado' "end" _n
    file close `relative_ado'
    file open `relative_tracker' using "`qa_plus'/stata.trk", ///
        write text replace
    file write `relative_tracker' "S `relative_pkgdir'" _n
    file write `relative_tracker' "N relfixture.pkg" _n
    file write `relative_tracker' "d Relative plugin fixture" _n
    file write `relative_tracker' "f p/relfixture.plugin" _n
    file write `relative_tracker' "f p/relfixture.ado" _n
    file write `relative_tracker' "e" _n
    file close `relative_tracker'

    quietly cd "`work'"
    pkgtransfer, download(local) limited(relfixture) ///
        dofile(relative.do) zipfile(relative.zip)
    mkdir "`relative_extract'"
    quietly cd "`relative_extract'"
    unzipfile "../relative.zip", replace
    confirm file ///
        "pkgtransfer_files/assets/relfixture.plugin"

    file open `relative_bundled' using ///
        "pkgtransfer_files/relfixture.pkg", read text
    local found_normalized 0
    local found_traversal 0
    file read `relative_bundled' line
    while r(eof) == 0 {
        if `"`macval(line)'"' == ///
            "G LINUX64 assets/relfixture.plugin relfixture.plugin" ///
            local found_normalized 1
        if strpos(`"`macval(line)'"', "../") local found_traversal 1
        file read `relative_bundled' line
    }
    file close `relative_bundled'
    assert `found_normalized' == 1
    assert `found_traversal' == 0

    mkdir "`relative_install'"
    sysdir set PLUS "`relative_install'"
    net install relfixture, ///
        from("`relative_extract'/pkgtransfer_files") replace
    file open `relative_verify' using ///
        "`relative_install'/r/relfixture.plugin", read text
    file read `relative_verify' installed_line
    file close `relative_verify'
    assert `"`macval(installed_line)'"' == "downloaded relative plugin"
}
local test_rc = _rc
foreach handle in relative_pkg relative_source relative_installed relative_ado ///
    relative_tracker relative_bundled relative_verify {
    capture file close ``handle''
}
capture sysdir set PLUS "`qa_plus'"
capture quietly cd "`work'"
capture quietly _pkgtransfer_cleanup_staging, directory("`relative_extract'")
capture quietly _pkgtransfer_cleanup_staging, directory("`relative_install'")
capture quietly _pkgtransfer_cleanup_staging, directory("`relative_root'")
foreach artifact in relative.do relative.zip {
    capture erase "`work'/`artifact'"
}
capture quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: parent-relative plugin sources remain installable"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' relative_plugin"
    display as error "  FAIL: parent-relative plugin source (rc `test_rc')"
}

**# Multiple plugin files in one package

local ++test_count
local multi_source "`work'/multi_source"
local multi_extract "`work'/multi_extract"
tempname multi_pkg multi_a multi_b multi_installed_a multi_installed_b ///
    multi_ado multi_tracker
capture noisily {
    clear
    set obs 1
    mkdir "`multi_source'"
    file open `multi_a' using "`multi_source'/multi_a.plugin", ///
        write text replace
    file write `multi_a' "downloaded plugin a" _n
    file close `multi_a'
    file open `multi_b' using "`multi_source'/multi_b.plugin", ///
        write text replace
    file write `multi_b' "downloaded plugin b" _n
    file close `multi_b'
    file open `multi_pkg' using "`multi_source'/multifixture.pkg", ///
        write text replace
    file write `multi_pkg' "v 3" _n
    file write `multi_pkg' "d Multiple plugin fixture" _n
    file write `multi_pkg' "g LINUX64 multi_a.plugin" _n
    file write `multi_pkg' "h multi_a.plugin" _n
    file write `multi_pkg' "g LINUX64 multi_b.plugin" _n
    file write `multi_pkg' "h multi_b.plugin" _n
    file write `multi_pkg' "f multifixture.ado" _n
    file close `multi_pkg'
    file open `multi_installed_a' using ///
        "`qa_plus'/p/multi_a.plugin", write text replace
    file write `multi_installed_a' "installed plugin a" _n
    file close `multi_installed_a'
    file open `multi_installed_b' using ///
        "`qa_plus'/p/multi_b.plugin", write text replace
    file write `multi_installed_b' "installed plugin b" _n
    file close `multi_installed_b'
    file open `multi_ado' using "`qa_plus'/p/multifixture.ado", ///
        write text replace
    file write `multi_ado' "program define multifixture" _n
    file write `multi_ado' "end" _n
    file close `multi_ado'
    file open `multi_tracker' using "`qa_plus'/stata.trk", ///
        write text replace
    file write `multi_tracker' "S `multi_source'" _n
    file write `multi_tracker' "N multifixture.pkg" _n
    file write `multi_tracker' "d Multiple plugin fixture" _n
    file write `multi_tracker' "f p/multi_a.plugin" _n
    file write `multi_tracker' "f p/multi_b.plugin" _n
    file write `multi_tracker' "f p/multifixture.ado" _n
    file write `multi_tracker' "e" _n
    file close `multi_tracker'

    quietly cd "`work'"
    pkgtransfer, download(local) limited(multifixture) ///
        dofile(multi.do) zipfile(multi.zip)
    mkdir "`multi_extract'"
    quietly cd "`multi_extract'"
    unzipfile "../multi.zip", replace
    confirm file "pkgtransfer_files/multi_a.plugin"
    confirm file "pkgtransfer_files/multi_b.plugin"
}
local test_rc = _rc
foreach handle in multi_pkg multi_a multi_b multi_installed_a ///
    multi_installed_b multi_ado multi_tracker {
    capture file close ``handle''
}
capture quietly cd "`work'"
capture quietly _pkgtransfer_cleanup_staging, directory("`multi_extract'")
capture quietly _pkgtransfer_cleanup_staging, directory("`multi_source'")
foreach artifact in multi.do multi.zip {
    capture erase "`work'/`artifact'"
}
capture quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: packages may carry multiple plugin files"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' multiple_plugins"
    display as error "  FAIL: multiple plugin files (rc `test_rc')"
}

**# Online restore marker precedes descriptor terminator

local ++test_count
local online_source "`work'/online_marker_source"
local online_extract "`work'/online_marker_extract"
tempname online_pkg online_ado online_plugin online_tracker online_verify
capture noisily {
    clear
    set obs 1
    mkdir "`online_source'"
    file open `online_ado' using ///
        "`online_source'/onlinefixture.ado", write text replace
    file write `online_ado' "program define onlinefixture" _n
    file write `online_ado' "end" _n
    file close `online_ado'
    file open `online_plugin' using ///
        "`online_source'/onlinefixture.plugin", write text replace
    file write `online_plugin' "online plugin payload" _n
    file close `online_plugin'
    file open `online_pkg' using ///
        "`online_source'/onlinefixture.pkg", write text replace
    file write `online_pkg' "v 3" _n
    file write `online_pkg' "d Online marker fixture" _n
    file write `online_pkg' "f onlinefixture.ado" _n
    file write `online_pkg' "G LINUX64 onlinefixture.plugin" _n
    file write `online_pkg' "h onlinefixture.plugin" _n
    file write `online_pkg' "e" _n
    file close `online_pkg'
    file open `online_tracker' using "`qa_plus'/stata.trk", ///
        write text replace
    file write `online_tracker' "S `online_source'" _n
    file write `online_tracker' "N onlinefixture.pkg" _n
    file write `online_tracker' "d Online marker fixture" _n
    file write `online_tracker' "e" _n
    file close `online_tracker'

    quietly cd "`work'"
    pkgtransfer, download(online) limited(onlinefixture) ///
        dofile(online_marker.do) zipfile(online_marker.zip)
    mkdir "`online_extract'"
    quietly cd "`online_extract'"
    unzipfile "../online_marker.zip", replace

    local saw_marker 0
    local marker_after_end 0
    local saw_end 0
    local saw_upper_plugin 0
    file open `online_verify' using ///
        "pkgtransfer_files/onlinefixture.pkg", read text
    file read `online_verify' line
    while r(eof) == 0 {
        if strtrim(`"`macval(line)'"') == "e" local saw_end 1
        if substr(`"`macval(line)'"', 1, 21) == ///
            "d pkgtransfer-source " {
            local saw_marker 1
            if `saw_end' local marker_after_end 1
        }
        if `"`macval(line)'"' == ///
            "G LINUX64 onlinefixture.plugin" local saw_upper_plugin 1
        file read `online_verify' line
    }
    file close `online_verify'
    assert `saw_marker' == 1
    assert `marker_after_end' == 0
    assert `saw_upper_plugin' == 1
    confirm file "pkgtransfer_files/onlinefixture.plugin"
}
local test_rc = _rc
foreach handle in online_pkg online_ado online_plugin online_tracker ///
    online_verify {
    capture file close ``handle''
}
capture quietly cd "`work'"
capture quietly _pkgtransfer_cleanup_staging, directory("`online_extract'")
capture quietly _pkgtransfer_cleanup_staging, directory("`online_source'")
foreach artifact in online_marker.do online_marker.zip {
    capture erase "`work'/`artifact'"
}
capture quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: online restore marker precedes e"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' online_marker_order"
    display as error "  FAIL: online restore marker order (rc `test_rc')"
}

**# Restore marker namespace

local ++test_count
tempname restore_tracker restore_verify
capture noisily {
    clear
    set obs 1
    file open `restore_tracker' using "`qa_plus'/stata.trk", ///
        write text replace
    file write `restore_tracker' "S https://example.org/original" _n
    file write `restore_tracker' "N legitimate.pkg" _n
    file write `restore_tracker' "d S ordinary description text" _n
    file write `restore_tracker' "f p/legitimate.ado" _n
    file write `restore_tracker' "e" _n
    file write `restore_tracker' "S `qa_plus'" _n
    file write `restore_tracker' "N privatefixture.pkg" _n
    file write `restore_tracker' "d Private marker fixture" _n
    file write `restore_tracker' "f p/privatefixture.ado" _n
    file write `restore_tracker' ///
        "d pkgtransfer-source https://example.org/restored/privatefixture" _n
    file write `restore_tracker' "e" _n
    file close `restore_tracker'

    quietly cd "`work'"
    pkgtransfer, restore
    assert "`r(download_mode)'" == "restore"

    local source_unchanged 0
    local description_retained 0
    local private_restored 0
    local private_marker_retained 0
    file open `restore_verify' using "`qa_plus'/stata.trk", read text
    file read `restore_verify' line
    while r(eof) == 0 {
        if `"`macval(line)'"' == ///
            "S https://example.org/original" local source_unchanged 1
        if `"`macval(line)'"' == ///
            "d S ordinary description text" local description_retained 1
        if `"`macval(line)'"' == ///
            "S https://example.org/restored/privatefixture" ///
            local private_restored 1
        if substr(`"`macval(line)'"', 1, 21) == ///
            "d pkgtransfer-source " local private_marker_retained 1
        file read `restore_verify' line
    }
    file close `restore_verify'
    assert `source_unchanged' == 1
    assert `description_retained' == 1
    assert `private_restored' == 1
    assert `private_marker_retained' == 0
}
local test_rc = _rc
foreach handle in restore_tracker restore_verify {
    capture file close ``handle''
}
capture quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: restore ignores ordinary d S descriptions"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' restore_marker"
    display as error "  FAIL: restore marker namespace (rc `test_rc')"
}

**# Runner isolation contract

local ++test_count
tempname runner_fh
capture noisily {
    clear
    set obs 1
    local unsafe_uninstall 0
    file open `runner_fh' using "`qa_dir'/run_all.do", read text
    file read `runner_fh' line
    while r(eof) == 0 {
        if trim(`"`macval(line)'"') == ///
            "capture ado uninstall pkgtransfer" local unsafe_uninstall 1
        file read `runner_fh' line
    }
    file close `runner_fh'
    assert `unsafe_uninstall' == 0
}
local test_rc = _rc
capture file close `runner_fh'
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: runner does not uninstall from the real ado tree"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' runner_uninstall"
    display as error "  FAIL: runner isolation contract (rc `test_rc')"
}

**# Cleanup and summary

capture noisily _pkgtransfer_qa_cleanup, root("`qa_root'") ///
    originalplus("`qa_original_plus'") ///
    originalpersonal("`qa_original_personal'")
if _rc != 0 {
    local ++test_count
    local ++fail_count
    local failed_tests "`failed_tests' fixture_cleanup"
}

display ///
    "RESULT: test_pkgtransfer_v105 tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 1
}
