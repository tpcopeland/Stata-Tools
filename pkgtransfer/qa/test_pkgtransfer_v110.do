/*
    File:    test_pkgtransfer_v110.do
    Purpose: Regression coverage for OS-specific plugin bundles in 1.1.0
    Author:  Timothy P Copeland, Karolinska Institutet
    Date:    2026-08-16
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

capture program drop _pkgtransfer_v110_fixture
program define _pkgtransfer_v110_fixture, rclass
    version 16.0
    syntax, TAG(string) WORK(string) PLUS(string)

    local source "`work'/source_`tag'"
    mkdir "`source'"

    tempname pkg_file ado_file plugin_file tracker_file
    file open `ado_file' using "`source'/osfixture.ado", ///
        write text replace
    file write `ado_file' "program define osfixture" _n
    file write `ado_file' "end" _n
    file close `ado_file'

    foreach platform in win unix macintel macarm {
        file open `plugin_file' using "`source'/`platform'.bin", ///
            write text replace
        file write `plugin_file' "`platform' payload" _n
        file close `plugin_file'
    }

    file open `pkg_file' using "`source'/osfixture.pkg", ///
        write text replace
    file write `pkg_file' "v 3" _n
    file write `pkg_file' "d OS plugin fixture" _n
    file write `pkg_file' "g WIN64 win.bin osfixture.plugin" _n
    file write `pkg_file' "g LINUX64 unix.bin osfixture.plugin" _n
    file write `pkg_file' ///
        "g MACINTEL64 macintel.bin osfixture.plugin" _n
    file write `pkg_file' ///
        "g MACARM64 macarm.bin osfixture.plugin" _n
    file write `pkg_file' "h osfixture.plugin" _n
    file write `pkg_file' "f osfixture.ado" _n
    file close `pkg_file'

    copy "`source'/osfixture.ado" "`plus'/p/osfixture.ado", replace
    file open `plugin_file' using "`plus'/p/osfixture.plugin", ///
        write text replace
    file write `plugin_file' "installed payload" _n
    file close `plugin_file'

    file open `tracker_file' using "`plus'/stata.trk", ///
        write text replace
    file write `tracker_file' "S `source'" _n
    file write `tracker_file' "N osfixture.pkg" _n
    file write `tracker_file' "d OS plugin fixture" _n
    file write `tracker_file' "f p/osfixture.plugin" _n
    file write `tracker_file' "f p/osfixture.ado" _n
    file write `tracker_file' "e" _n
    file close `tracker_file'

    return local source "`source'"
end

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# Default all-platform behavior

**## Local bundle retains every source variant without a target duplicate
local ++test_count
tempname default_local_pkg
capture noisily {
    clear
    set obs 1
    _pkgtransfer_v110_fixture, tag(default_local) ///
        work("`work'") plus("`qa_plus'")
    quietly cd "`work'"
    pkgtransfer, download(local) limited(osfixture) ///
        dofile(default_local.do) zipfile(default_local.zip)
    mkdir "default_local_extract"
    quietly cd "default_local_extract"
    unzipfile "../default_local.zip", replace

    foreach source in win.bin unix.bin macintel.bin macarm.bin {
        confirm file "pkgtransfer_files/`source'"
    }
    capture confirm file "pkgtransfer_files/osfixture.plugin"
    assert _rc == 601

    file open `default_local_pkg' using ///
        "pkgtransfer_files/osfixture.pkg", read text
    local g_count 0
    file read `default_local_pkg' line
    while r(eof) == 0 {
        if inlist(substr(lower(`"`macval(line)'"'), 1, 2), "g ") ///
            local ++g_count
        file read `default_local_pkg' line
    }
    file close `default_local_pkg'
    assert `g_count' == 4
}
local test_rc = _rc
capture file close `default_local_pkg'
capture quietly cd "`work'"
capture quietly _pkgtransfer_cleanup_staging, ///
    directory("`work'/default_local_extract")
foreach artifact in default_local.do default_local.zip {
    capture erase "`work'/`artifact'"
}
capture quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result ///
        "  PASS: omitted os() keeps all local plugin variants"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' default_local_plugins"
    display as error ///
        "  FAIL: default local plugin variants (rc `test_rc')"
}

**## Online bundle retains every source variant
local ++test_count
tempname default_online_pkg
capture noisily {
    clear
    set obs 1
    _pkgtransfer_v110_fixture, tag(default_online) ///
        work("`work'") plus("`qa_plus'")
    quietly cd "`work'"
    pkgtransfer, download(online) limited(osfixture) ///
        dofile(default_online.do) zipfile(default_online.zip)
    mkdir "default_online_extract"
    quietly cd "default_online_extract"
    unzipfile "../default_online.zip", replace

    foreach source in win.bin unix.bin macintel.bin macarm.bin {
        confirm file "pkgtransfer_files/`source'"
    }
    capture confirm file "pkgtransfer_files/osfixture.plugin"
    assert _rc == 601

    file open `default_online_pkg' using ///
        "pkgtransfer_files/osfixture.pkg", read text
    local g_count 0
    file read `default_online_pkg' line
    while r(eof) == 0 {
        if substr(lower(`"`macval(line)'"'), 1, 2) == "g " ///
            local ++g_count
        file read `default_online_pkg' line
    }
    file close `default_online_pkg'
    assert `g_count' == 4
}
local test_rc = _rc
capture file close `default_online_pkg'
capture quietly cd "`work'"
capture quietly _pkgtransfer_cleanup_staging, ///
    directory("`work'/default_online_extract")
foreach artifact in default_online.do default_online.zip {
    capture erase "`work'/`artifact'"
}
capture quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result ///
        "  PASS: omitted os() keeps all online plugin variants"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' default_online_plugins"
    display as error ///
        "  FAIL: default online plugin variants (rc `test_rc')"
}

**# Explicit OS filtering

**## Local bundles retain only matching platform records and files
local ++test_count
capture noisily {
    foreach os in Windows Unix MacOSX {
        local tag = lower("`os'")
        _pkgtransfer_v110_fixture, tag(local_`tag') ///
            work("`work'") plus("`qa_plus'")
        quietly cd "`work'"
        pkgtransfer, download(local) limited(osfixture) os(`os') ///
            dofile(local_`tag'.do) zipfile(local_`tag'.zip)
        mkdir "local_`tag'_extract"
        quietly cd "local_`tag'_extract"
        unzipfile "../local_`tag'.zip", replace

        local expected_files ""
        local rejected_files ""
        local expected_g 1
        if "`os'" == "Windows" {
            local expected_files "win.bin"
            local rejected_files "unix.bin macintel.bin macarm.bin"
        }
        else if "`os'" == "Unix" {
            local expected_files "unix.bin"
            local rejected_files "win.bin macintel.bin macarm.bin"
        }
        else {
            local expected_files "macintel.bin macarm.bin"
            local rejected_files "win.bin unix.bin"
            local expected_g 2
        }

        foreach source of local expected_files {
            confirm file "pkgtransfer_files/`source'"
        }
        foreach source of local rejected_files {
            capture confirm file "pkgtransfer_files/`source'"
            assert _rc == 601
        }
        capture confirm file "pkgtransfer_files/osfixture.plugin"
        assert _rc == 601

        tempname filtered_pkg
        file open `filtered_pkg' using ///
            "pkgtransfer_files/osfixture.pkg", read text
        local g_count 0
        file read `filtered_pkg' line
        while r(eof) == 0 {
            if substr(lower(`"`macval(line)'"'), 1, 2) == "g " ///
                local ++g_count
            file read `filtered_pkg' line
        }
        file close `filtered_pkg'
        assert `g_count' == `expected_g'

        quietly cd "`work'"
        _pkgtransfer_cleanup_staging, ///
            directory("`work'/local_`tag'_extract")
        erase "`work'/local_`tag'.do"
        erase "`work'/local_`tag'.zip"
    }
}
local test_rc = _rc
capture file close `filtered_pkg'
capture quietly cd "`work'"
foreach os in windows unix macosx {
    capture quietly _pkgtransfer_cleanup_staging, ///
        directory("`work'/local_`os'_extract")
    capture erase "`work'/local_`os'.do"
    capture erase "`work'/local_`os'.zip"
}
capture quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result ///
        "  PASS: explicit os() filters all local platform families"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' local_os_filter"
    display as error ///
        "  FAIL: local os() plugin filtering (rc `test_rc')"
}

**## Online Unix bundle remains installable from its selected source
local ++test_count
tempname online_unix_pkg installed_plugin
local install_plus "`work'/online_unix_plus"
capture noisily {
    clear
    set obs 1
    _pkgtransfer_v110_fixture, tag(online_unix) ///
        work("`work'") plus("`qa_plus'")
    quietly cd "`work'"
    pkgtransfer, download(online) limited(osfixture) os(Unix) ///
        dofile(online_unix.do) zipfile(online_unix.zip)
    mkdir "online_unix_extract"
    quietly cd "online_unix_extract"
    unzipfile "../online_unix.zip", replace

    confirm file "pkgtransfer_files/unix.bin"
    foreach rejected in win.bin macintel.bin macarm.bin osfixture.plugin {
        capture confirm file "pkgtransfer_files/`rejected'"
        assert _rc == 601
    }

    file open `online_unix_pkg' using ///
        "pkgtransfer_files/osfixture.pkg", read text
    local g_count 0
    local saw_linux 0
    file read `online_unix_pkg' line
    while r(eof) == 0 {
        if substr(lower(`"`macval(line)'"'), 1, 2) == "g " {
            local ++g_count
            if `"`macval(line)'"' == ///
                "g LINUX64 unix.bin osfixture.plugin" local saw_linux 1
        }
        file read `online_unix_pkg' line
    }
    file close `online_unix_pkg'
    assert `g_count' == 1
    assert `saw_linux' == 1

    mkdir "`install_plus'"
    sysdir set PLUS "`install_plus'"
    net install osfixture, ///
        from("`work'/online_unix_extract/pkgtransfer_files") replace
    file open `installed_plugin' using ///
        "`install_plus'/o/osfixture.plugin", read text
    file read `installed_plugin' installed_line
    file close `installed_plugin'
    assert `"`macval(installed_line)'"' == "unix payload"
}
local test_rc = _rc
foreach handle in online_unix_pkg installed_plugin {
    capture file close ``handle''
}
capture sysdir set PLUS "`qa_plus'"
capture quietly cd "`work'"
capture quietly _pkgtransfer_cleanup_staging, ///
    directory("`work'/online_unix_extract")
capture quietly _pkgtransfer_cleanup_staging, ///
    directory("`install_plus'")
foreach artifact in online_unix.do online_unix.zip {
    capture erase "`work'/`artifact'"
}
capture quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result ///
        "  PASS: filtered online plugin descriptor installs correctly"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' online_os_install"
    display as error ///
        "  FAIL: filtered online plugin installation (rc `test_rc')"
}

**# Summary and cleanup

capture program drop _pkgtransfer_v110_fixture
capture quietly cd "`orig_dir'"
capture noisily _pkgtransfer_qa_cleanup, root("`qa_root'") ///
    originalplus("`qa_original_plus'") ///
    originalpersonal("`qa_original_personal'")
local cleanup_rc = _rc
if `cleanup_rc' {
    local ++test_count
    local ++fail_count
    local failed_tests "`failed_tests' cleanup"
}

display as text ///
    "RESULT: test_pkgtransfer_v110 tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    exit 9
}
