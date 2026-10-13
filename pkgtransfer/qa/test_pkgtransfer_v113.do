/*
    File:    test_pkgtransfer_v113.do
    Purpose: Regression coverage for the 1.1.3 tracker, installer, and filter fixes
    Author:  Timothy P Copeland, Karolinska Institutet
    Date:    2026-10-12
*/

version 16.0
capture log close _all
set linesize 255

**# Setup

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa/?$", "")
local orig_dir "`c(pwd)'"

run "`qa_dir'/_pkgtransfer_qa_common.do"
_pkgtransfer_qa_setup, pkgdir("`pkg_dir'")
local qa_root "`r(root)'"
local qa_original_plus "`r(original_plus)'"
local qa_original_personal "`r(original_personal)'"
local qa_plus "`r(plus)'"
local work "`r(work)'"
_pkgtransfer_qa_stage_list
local stage_list0 `"`r(list)'"'

capture program drop pkgtransfer
run "`pkg_dir'/pkgtransfer.ado"

* Count descriptor lines that equal (exact) or start with (prefix) a string
capture program drop _v113_count_lines
program define _v113_count_lines, rclass
    version 16.0
    syntax using/, TEXT(string asis) [PREFIX]
    gettoken text : text
    tempname fh
    local n 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if "`prefix'" != "" {
            if substr(`"`macval(line)'"', 1, strlen(`"`macval(text)'"')) == ///
                `"`macval(text)'"' local ++n
        }
        else if `"`macval(line)'"' == `"`macval(text)'"' local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end

* Plugin package fixture: tracker, installed files, and a source descriptor
capture program drop _v113_plugin_fixture
program define _v113_plugin_fixture
    version 16.0
    syntax, DIR(string) PLUS(string) PKG(string) PLUGINS(string) ///
        PLATFORMS(string) [NOGLINES]
    mkdir "`dir'/src"
    tempname fh
    file open `fh' using "`dir'/src/`pkg'.ado", write text replace
    file write `fh' "program define `pkg'" _n "end" _n
    file close `fh'
    file open `fh' using "`dir'/src/`pkg'.pkg", write text replace
    file write `fh' "v 3" _n "d `pkg' | plugin fixture" _n
    foreach plugin of local plugins {
        if "`noglines'" == "" {
            foreach platform of local platforms {
                local bin = lower(subinstr("`platform'", ".", "_", .))
                file write `fh' "g `platform' `plugin'_`bin'.bin `plugin'.plugin" _n
                tempname bh
                file open `bh' using "`dir'/src/`plugin'_`bin'.bin", ///
                    write text replace
                file write `bh' "`plugin' `platform'" _n
                file close `bh'
            }
        }
        file write `fh' "h `plugin'.plugin" _n
    }
    file write `fh' "f `pkg'.ado" _n
    file close `fh'
    copy "`dir'/src/`pkg'.ado" "`plus'/p/`pkg'.ado", replace
    file open `fh' using "`plus'/stata.trk", write text replace
    file write `fh' "* 00000001" _n "*! version 1.0.0" _n _n
    file write `fh' "S `dir'/src" _n "N `pkg'.pkg" _n "D 12 Oct 2026" _n
    file write `fh' "U 1" _n "d `pkg' | plugin fixture" _n
    foreach plugin of local plugins {
        file write `fh' "f p/`plugin'.plugin" _n
        tempname ih
        file open `ih' using "`plus'/p/`plugin'.plugin", write text replace
        file write `ih' "installed" _n
        file close `ih'
    }
    file write `fh' "f p/`pkg'.ado" _n "e" _n
    file close `fh'
end

* Single-file package installed in PLUS with a caller-supplied tracker header
capture program drop _v113_alpha_fixture
program define _v113_alpha_fixture
    version 16.0
    syntax, PLUS(string) [BODY(string)]
    if "`body'" == "" local body "new"
    tempname fh
    file open `fh' using "`plus'/a/alpha.ado", write text replace
    file write `fh' "program define alpha" _n
    file write `fh' `"    display "alpha `body'""' _n "end" _n
    file close `fh'
    file open `fh' using "`plus'/stata.trk", write text replace
    file write `fh' "* 00000001" _n "*! version 1.0.0" _n _n
    file write `fh' "S https://example.org/alpha" _n "N alpha.pkg" _n
    file write `fh' "D 12 Oct 2026" _n "U 1" _n
    file write `fh' "d alpha: a | piped description" _n
    file write `fh' "f a/alpha.ado" _n "e" _n
    file close `fh'
end

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# 1. restore preserves every non-marker tracker line byte for byte

local ++test_count
local t "`work'/t01"
tempname fh
capture noisily {
    mkdir "`t'"
    file open `fh' using "`qa_plus'/stata.trk", write text replace
    file write `fh' "* 00000002" _n "*! version 1.0.0" _n
    file write `fh' "* Do not erase or edit this file" _n _n
    file write `fh' "S https://example.org/alpha" _n "N alpha.pkg" _n
    file write `fh' "D 12 Oct 2026" _n "U 1" _n
    file write `fh' "d alpha: a | piped description" _n
    file write `fh' `"d quoted "text" and 'single' with"' _char(9) "tab" _n
    file write `fh' "d " _dup(3000) "x" _n
    file write `fh' "f a/alpha.ado" _n "e" _n _n
    file write `fh' "S `t'/pkgtransfer_files" _n "N beta.pkg" _n
    file write `fh' "D 12 Oct 2026" _n "U 2" _n
    file write `fh' "d beta || double pipe" _n "f b/beta.ado" _n
    file write `fh' "d pkgtransfer-source https://example.org/beta" _n
    file write `fh' "e" _n
    file close `fh'
    copy "`qa_plus'/stata.trk" "`t'/original.trk"

    file open `fh' using "`t'/expected.trk", write text replace
    file write `fh' "* 00000002" _n "*! version 1.0.0" _n
    file write `fh' "* Do not erase or edit this file" _n _n
    file write `fh' "S https://example.org/alpha" _n "N alpha.pkg" _n
    file write `fh' "D 12 Oct 2026" _n "U 1" _n
    file write `fh' "d alpha: a | piped description" _n
    file write `fh' `"d quoted "text" and 'single' with"' _char(9) "tab" _n
    file write `fh' "d " _dup(3000) "x" _n
    file write `fh' "f a/alpha.ado" _n "e" _n _n
    file write `fh' "S https://example.org/beta" _n "N beta.pkg" _n
    file write `fh' "D 12 Oct 2026" _n "U 2" _n
    file write `fh' "d beta || double pipe" _n "f b/beta.ado" _n
    file write `fh' "e" _n
    file close `fh'

    pkgtransfer, restore
    assert fileread("`qa_plus'/stata.trk") == fileread("`t'/expected.trk")
    assert fileread("`qa_plus'/stata.trk.backup") == ///
        fileread("`t'/original.trk")
}
local test_rc = _rc
capture file close `fh'
capture erase "`qa_plus'/stata.trk.backup"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: restore keeps blank, piped, quoted, tab, and long lines"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' restore_bytes"
    display as error "  FAIL: restore tracker fidelity (rc `test_rc')"
}

**# 2. Local bundles keep piped and long descriptions

local ++test_count
local t "`work'/t02"
capture noisily {
    mkdir "`t'"
    _v113_alpha_fixture, plus("`qa_plus'")
    local long_d = "d " + 2100 * "y"
    tempname fh
    file open `fh' using "`qa_plus'/stata.trk", write text replace
    file write `fh' "* 00000001" _n "*! version 1.0.0" _n _n
    file write `fh' "S https://example.org/alpha" _n "N alpha.pkg" _n
    file write `fh' "D 12 Oct 2026" _n "U 1" _n
    file write `fh' "d alpha: a | piped description" _n
    file write `fh' "`long_d'" _n "f a/alpha.ado" _n "e" _n
    file close `fh'

    quietly cd "`t'"
    pkgtransfer, download(local) limited(alpha) dofile(b.do) zipfile(b.zip)
    mkdir "x"
    quietly cd "x"
    unzipfile "../b.zip", replace
    confirm file "pkgtransfer_files/alpha.ado"
    _v113_count_lines using "pkgtransfer_files/alpha.pkg", ///
        text("d alpha: a | piped description")
    assert r(n) == 1
    _v113_count_lines using "pkgtransfer_files/alpha.pkg", text("`long_d'")
    assert r(n) == 1
    _v113_count_lines using "pkgtransfer_files/alpha.pkg", text("F alpha.ado")
    assert r(n) == 1
    _v113_count_lines using "pkgtransfer_files/stata.toc", ///
        text("p alpha alpha: a | piped description")
    assert r(n) == 1
}
local test_rc = _rc
capture file close `fh'
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: local bundle keeps piped and long d lines"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' local_pipes"
    display as error "  FAIL: local bundle description fidelity (rc `test_rc')"
}

**# 3. Local bundle package names come only from N records

local ++test_count
local t "`work'/t03"
tempname fh
capture noisily {
    mkdir "`t'"
    _v113_alpha_fixture, plus("`qa_plus'")
    file open `fh' using "`qa_plus'/stata.trk", write text replace
    file write `fh' "* 00000001" _n _n
    file write `fh' "S https://example.org/alpha" _n "N alpha.pkg" _n
    file write `fh' "D 12 Oct 2026" _n "U 1" _n
    file write `fh' "d alpha | companion" _n
    file write `fh' "d see N beta.pkg for the companion package" _n
    file write `fh' "f a/alpha.ado" _n "e" _n
    file close `fh'

    quietly cd "`t'"
    pkgtransfer, download(local) limited(alpha) dofile(b.do) zipfile(b.zip)
    assert "`r(package_list)'" == "alpha"
    mkdir "x"
    quietly cd "x"
    unzipfile "../b.zip", replace
    confirm file "pkgtransfer_files/alpha.ado"
    _v113_count_lines using "pkgtransfer_files/alpha.pkg", text("F alpha.ado")
    assert r(n) == 1
    _v113_count_lines using "pkgtransfer_files/alpha.pkg", ///
        text("d see N beta.pkg for the companion package")
    assert r(n) == 1
}
local test_rc = _rc
capture file close `fh'
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: d text naming N x.pkg does not reassign lines"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' n_record_split"
    display as error "  FAIL: local package-name detection (rc `test_rc')"
}

**# 4. Online bundles keep piped descriptions

local ++test_count
local t "`work'/t04"
tempname fh
capture noisily {
    mkdir "`t'"
    mkdir "`t'/src"
    file open `fh' using "`t'/src/gamma.pkg", write text replace
    file write `fh' "v 3" _n "d gamma | piped description" _n _n
    file write `fh' "f gamma.ado" _n
    file close `fh'
    file open `fh' using "`t'/src/gamma.ado", write text replace
    file write `fh' "program define gamma" _n "end" _n
    file close `fh'
    file open `fh' using "`qa_plus'/stata.trk", write text replace
    file write `fh' "* 00000001" _n _n
    file write `fh' "S `t'/src" _n "N gamma.pkg" _n "D 12 Oct 2026" _n
    file write `fh' "U 1" _n "d gamma | piped description" _n
    file write `fh' "f g/gamma.ado" _n "e" _n
    file close `fh'

    quietly cd "`t'"
    pkgtransfer, download(online) limited(gamma) dofile(b.do) zipfile(b.zip)
    mkdir "x"
    quietly cd "x"
    unzipfile "../b.zip", replace
    confirm file "pkgtransfer_files/gamma.ado"
    _v113_count_lines using "pkgtransfer_files/gamma.pkg", ///
        text("d gamma | piped description")
    assert r(n) == 1
    _v113_count_lines using "pkgtransfer_files/stata.toc", ///
        text("p gamma gamma | piped description")
    assert r(n) == 1
    * The restore marker records the S value exactly (no added separator)
    _v113_count_lines using "pkgtransfer_files/gamma.pkg", ///
        text("d pkgtransfer-source `t'/src")
    assert r(n) == 1
}
local test_rc = _rc
capture file close `fh'
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: online bundle keeps piped d lines"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' online_pipes"
    display as error "  FAIL: online bundle description fidelity (rc `test_rc')"
}

**# 5. Installer works after moving the .do and .zip together

local ++test_count
local t "`work'/t05"
capture noisily {
    mkdir "`t'"
    _v113_alpha_fixture, plus("`qa_plus'")
    quietly cd "`t'"
    mkdir "out dir"
    pkgtransfer, download(local) limited(alpha) ///
        zipfile("out dir/my.zip") dofile("out dir/inst.do")
    mkdir "moved dir"
    copy "out dir/my.zip" "moved dir/my.zip"
    copy "out dir/inst.do" "moved dir/inst.do"
    mkdir "target plus"
    sysdir set PLUS "`t'/target plus"
    quietly cd "`t'/moved dir"
    do "inst.do"
    confirm file "`t'/target plus/a/alpha.ado"
    _v113_count_lines using "`t'/target plus/stata.trk", text("N alpha.pkg")
    assert r(n) == 1
    _v113_count_lines using "`t'/out dir/inst.do", ///
        text(`"    unzipfile "my.zip", replace"')
    assert r(n) == 1
}
local test_rc = _rc
sysdir set PLUS "`qa_plus'"
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: relocated installer finds its archive"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' relocated_installer"
    display as error "  FAIL: relocated installer (rc `test_rc')"
}

**# 6. Installer upgrades an existing copy; restore then runs on the duplicate tracker

local ++test_count
local t "`work'/t06"
tempname fh
capture noisily {
    mkdir "`t'"
    * Older alpha published from another source and installed in the target
    mkdir "`t'/old_src"
    file open `fh' using "`t'/old_src/stata.toc", write text replace
    file write `fh' "v 3" _n "p alpha" _n
    file close `fh'
    file open `fh' using "`t'/old_src/alpha.pkg", write text replace
    file write `fh' "v 3" _n "d alpha old" _n "f alpha.ado" _n
    file close `fh'
    file open `fh' using "`t'/old_src/alpha.ado", write text replace
    file write `fh' "program define alpha" _n `"    display "alpha old""' _n "end" _n
    file close `fh'
    mkdir "`t'/target plus"
    sysdir set PLUS "`t'/target plus"
    net install alpha, from("`t'/old_src")
    sysdir set PLUS "`qa_plus'"

    _v113_alpha_fixture, plus("`qa_plus'") body("new")
    quietly cd "`t'"
    pkgtransfer, download(local) limited(alpha) zipfile(up.zip) dofile(up.do)
    sysdir set PLUS "`t'/target plus"
    do "up.do"
    assert strpos(fileread("`t'/target plus/a/alpha.ado"), "alpha new") > 0

    * net install from a new source leaves two alpha entries in stata.trk
    _v113_count_lines using "`t'/target plus/stata.trk", text("N alpha.pkg")
    assert r(n) == 2
    capture noisily pkgtransfer, dofile(blocked.do)
    assert _rc == 459
    pkgtransfer, restore
    assert "`r(download_mode)'" == "restore"
    _v113_count_lines using "`t'/target plus/stata.trk", ///
        text("S https://example.org/alpha")
    assert r(n) == 1
    _v113_count_lines using "`t'/target plus/stata.trk", ///
        text("d pkgtransfer-source ") prefix
    assert r(n) == 0
}
local test_rc = _rc
capture file close `fh'
sysdir set PLUS "`qa_plus'"
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: installer replaces older copy; restore runs on duplicates"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' installer_replace"
    display as error "  FAIL: installer upgrade / duplicate restore (rc `test_rc')"
}

**# 7. os() keeps every [R] net platform name of its family

local ++test_count
local t "`work'/t07"
capture noisily {
    mkdir "`t'"
    _v113_plugin_fixture, dir("`t'") plus("`qa_plus'") pkg(osall) ///
        plugins(osall) platforms(WIN64 LINUX64 LINUX64P MACINTEL64 ///
        MACARM64 OSX.ARM64 OSX.X8664)
    quietly cd "`t'"
    foreach os in MacOSX Unix Windows {
        pkgtransfer, download(local) limited(osall) os(`os') ///
            dofile(`os'.do) zipfile(`os'.zip)
        mkdir "`os'"
        quietly cd "`os'"
        unzipfile "../`os'.zip", replace
        local expect_MacOSX "MACINTEL64 MACARM64 OSX.ARM64 OSX.X8664"
        local expect_Unix "LINUX64 LINUX64P"
        local expect_Windows "WIN64"
        _v113_count_lines using "pkgtransfer_files/osall.pkg", ///
            text("g ") prefix
        assert r(n) == `: word count `expect_`os'''
        foreach platform of local expect_`os' {
            local bin = lower(subinstr("`platform'", ".", "_", .))
            _v113_count_lines using "pkgtransfer_files/osall.pkg", ///
                text("g `platform' osall_`bin'.bin osall.plugin")
            assert r(n) == 1
            confirm file "pkgtransfer_files/osall_`bin'.bin"
        }
        quietly cd "`t'"
    }
}
local test_rc = _rc
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: os(MacOSX) keeps OSX.ARM64 and OSX.X8664"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' os_families"
    display as error "  FAIL: os() platform families (rc `test_rc')"
}

**# 8. Default mode names omitted local-path packages; URL rule is a scheme test

local ++test_count
local t "`work'/t08"
tempname fh
capture noisily {
    mkdir "`t'"
    file open `fh' using "`qa_plus'/stata.trk", write text replace
    file write `fh' "* 00000001" _n _n
    file write `fh' "S https://example.org/alpha" _n "N alpha.pkg" _n
    file write `fh' "d alpha | online" _n "f a/alpha.ado" _n "e" _n
    file write `fh' "S `t'/x.com/pkgs" _n "N epsilon.pkg" _n
    file write `fh' "d epsilon | local path that contains .com/" _n
    file write `fh' "f e/epsilon.ado" _n "e" _n
    file close `fh'
    quietly cd "`t'"
    log using "`t'/note.log", text replace name(v113note)
    pkgtransfer, dofile(all.do)
    local returned "`r(package_list)'"
    log close v113note
    assert "`returned'" == "alpha"
    assert strpos(fileread("`t'/note.log"), ///
        "Note: omitted packages installed from a local path: epsilon") > 0
    assert strpos(fileread("all.do"), "epsilon") == 0
    pkgtransfer, limited(epsilon) dofile(one.do)
    assert "`r(package_list)'" == "epsilon"
    assert strpos(fileread("one.do"), "net install epsilon") > 0
}
local test_rc = _rc
capture file close `fh'
capture log close v113note
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: local-path packages are named, not silently dropped"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' local_path_note"
    display as error "  FAIL: local-path omission rule (rc `test_rc')"
}

**# 9. Repeated restore never overwrites an earlier backup

local ++test_count
local t "`work'/t09"
tempname fh
capture noisily {
    mkdir "`t'"
    foreach round in 1 2 {
        file open `fh' using "`qa_plus'/stata.trk", write text replace
        file write `fh' "* 0000000`round'" _n _n
        file write `fh' "S `t'/bundle" _n "N alpha.pkg" _n
        file write `fh' "d alpha | round `round'" _n "f a/alpha.ado" _n
        file write `fh' "d pkgtransfer-source https://example.org/alpha" _n
        file write `fh' "e" _n
        file close `fh'
        copy "`qa_plus'/stata.trk" "`t'/round`round'.trk"
        pkgtransfer, restore
        if `round' == 1 {
            copy "`qa_plus'/stata.trk" "`t'/restored1.trk"
            * No markers left: a second restore must not touch the backup
            pkgtransfer, restore
            assert fileread("`qa_plus'/stata.trk") == ///
                fileread("`t'/restored1.trk")
            capture confirm file "`qa_plus'/stata.trk.backup1"
            assert _rc == 601
        }
    }
    assert fileread("`qa_plus'/stata.trk.backup") == ///
        fileread("`t'/round1.trk")
    assert fileread("`qa_plus'/stata.trk.backup1") == ///
        fileread("`t'/round2.trk")
}
local test_rc = _rc
capture file close `fh'
capture erase "`qa_plus'/stata.trk.backup"
capture erase "`qa_plus'/stata.trk.backup1"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: restore backups are numbered, never overwritten"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' backup_clobber"
    display as error "  FAIL: restore backup preservation (rc `test_rc')"
}

**# 10. Standalone restore refuses options it cannot honor

local ++test_count
local t "`work'/t10"
capture noisily {
    mkdir "`t'"
    _v113_alpha_fixture, plus("`qa_plus'")
    copy "`qa_plus'/stata.trk" "`t'/before.trk"
    quietly cd "`t'"
    foreach call in "limited(alpha)" "skip(alpha)" "os(Unix)" ///
        "dofile(x.do)" "zipfile(x.zip)" {
        local opt = substr("`call'", 1, strpos("`call'", "(") - 1)
        log using "`t'/refuse.log", text replace name(v113refuse)
        capture noisily pkgtransfer, restore `call'
        local call_rc = _rc
        log close v113refuse
        assert `call_rc' == 198
        assert strpos(fileread("`t'/refuse.log"), ///
            "restore without download() cannot be combined with: `opt'()") > 0
    }
    assert fileread("`qa_plus'/stata.trk") == fileread("`t'/before.trk")
    capture confirm file "x.do"
    assert _rc == 601
}
local test_rc = _rc
capture log close v113refuse
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: restore rejects limited/skip/os/dofile/zipfile"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' restore_options"
    display as error "  FAIL: standalone restore option contract (rc `test_rc')"
}

**# 11. Plugin names match whole file names

local ++test_count
local t "`work'/t11"
capture noisily {
    mkdir "`t'"
    _v113_plugin_fixture, dir("`t'") plus("`qa_plus'") pkg(plgpkg) ///
        plugins(plg xplg) platforms(WIN64 LINUX64)
    quietly cd "`t'"
    pkgtransfer, download(local) limited(plgpkg) dofile(b.do) zipfile(b.zip)
    mkdir "x"
    quietly cd "x"
    unzipfile "../b.zip", replace
    local pkgfile "pkgtransfer_files/plgpkg.pkg"
    _v113_count_lines using "`pkgfile'", text("g ") prefix
    assert r(n) == 4
    _v113_count_lines using "`pkgfile'", text("h ") prefix
    assert r(n) == 2
    foreach plugin in plg xplg {
        foreach platform in WIN64 LINUX64 {
            local bin = lower("`platform'")
            _v113_count_lines using "`pkgfile'", ///
                text("g `platform' `plugin'_`bin'.bin `plugin'.plugin")
            assert r(n) == 1
        }
        _v113_count_lines using "`pkgfile'", text("f `plugin'.plugin")
        assert r(n) == 0
    }
}
local test_rc = _rc
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: plg.plugin does not capture xplg.plugin records"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' plugin_substring"
    display as error "  FAIL: plugin whole-name matching (rc `test_rc')"
}

**# 12. rc 498: installed plugin without a platform record

local ++test_count
local t "`work'/t12"
capture noisily {
    mkdir "`t'"
    _v113_plugin_fixture, dir("`t'") plus("`qa_plus'") pkg(noplat) ///
        plugins(noplat) platforms(WIN64) noglines
    quietly cd "`t'"
    log using "`t'/p.log", text replace name(v113plat)
    capture noisily pkgtransfer, download(local) limited(noplat) ///
        dofile(b.do) zipfile(b.zip)
    local call_rc = _rc
    log close v113plat
    assert `call_rc' == 498
    assert strpos(fileread("`t'/p.log"), ///
        "Plugin noplat.plugin has no platform record") > 0
    local staged : dir "." dirs "pkgtransfer_files"
    assert `"`staged'"' == ""
    _pkgtransfer_qa_stage_list
    assert `"`r(list)'"' == `"`stage_list0'"'
    capture confirm file "b.zip"
    assert _rc == 601
}
local test_rc = _rc
capture log close v113plat
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: plugin without platform record exits 498"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' rc498"
    display as error "  FAIL: rc 498 route (rc `test_rc')"
}

**# 13. rc 693: a bundled file occupies a needed directory name

local ++test_count
local t "`work'/t13"
tempname fh
capture noisily {
    mkdir "`t'"
    mkdir "`qa_plus'/s"
    file open `fh' using "`qa_plus'/s/sub", write text replace
    file write `fh' "plain file named sub" _n
    file close `fh'
    file open `fh' using "`qa_plus'/stata.trk", write text replace
    file write `fh' "* 00000001" _n _n
    file write `fh' "S https://example.org/aaa" _n "N aaa.pkg" _n
    file write `fh' "d aaa | file" _n "f s/sub" _n "e" _n
    file write `fh' "S https://example.org/bbb" _n "N bbb.pkg" _n
    file write `fh' "d bbb | nested" _n "f s/sub/x.ado" _n "e" _n
    file close `fh'
    quietly cd "`t'"
    log using "`t'/d.log", text replace name(v113dir)
    capture noisily pkgtransfer, download(local) dofile(b.do) zipfile(b.zip)
    local call_rc = _rc
    log close v113dir
    assert `call_rc' == 693
    assert strpos(fileread("`t'/d.log"), ///
        "Could not create bundle directory sub/") > 0
    local staged : dir "." dirs "pkgtransfer_files"
    assert `"`staged'"' == ""
    _pkgtransfer_qa_stage_list
    assert `"`r(list)'"' == `"`stage_list0'"'
}
local test_rc = _rc
capture file close `fh'
capture log close v113dir
capture erase "`qa_plus'/s/sub"
capture rmdir "`qa_plus'/s"
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: blocked bundle directory exits 693"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' rc693"
    display as error "  FAIL: rc 693 route (rc `test_rc')"
}

**# 14. Online and local bundles parse tab-separated two-field g records (traj shape)

* traj.pkg separates directive fields with tabs, omits the target name, and
* ships every platform variant as plug-ins/<dir>/traj.plugin.
local ++test_count
local t "`work'/t14"
tempname fh
capture noisily {
    mkdir "`t'"
    mkdir "`t'/src"
    mkdir "`t'/src/plug-ins"
    local tab = char(9)
    local tj_platforms "WIN WIN64A MAC MACARM64 LINUX LINUX64"
    local tj_dirs "win win64a mac mac linux linux64"
    file open `fh' using "`t'/src/tabg.pkg", write text replace
    file write `fh' "v 3" _n "d tabg`tab'| tab fixture" _n
    forvalues i = 1/6 {
        local platform : word `i' of `tj_platforms'
        local dir : word `i' of `tj_dirs'
        * One record puts the tab directly after the directive letter
        local sep = cond(`i' == 6, "`tab'", " ")
        file write `fh' "g`sep'`platform'`tab'`tab'plug-ins/`dir'/tabg.plugin" _n
        capture mkdir "`t'/src/plug-ins/`dir'"
        tempname bh
        file open `bh' using "`t'/src/plug-ins/`dir'/tabg.plugin", ///
            write text replace
        file write `bh' "tabg `dir'" _n
        file close `bh'
    }
    file write `fh' "h tabg.plugin" _n "f`tab'tabg.ado" _n
    file close `fh'
    file open `fh' using "`t'/src/tabg.ado", write text replace
    file write `fh' "program define tabg" _n "end" _n
    file close `fh'
    file open `fh' using "`qa_plus'/stata.trk", write text replace
    file write `fh' "* 00000001" _n _n
    file write `fh' "S `t'/src" _n "N tabg.pkg" _n "D 12 Oct 2026" _n
    file write `fh' "U 1" _n "d tabg`tab'| tab fixture" _n
    file write `fh' "f t/tabg.plugin" _n "f t/tabg.ado" _n "e" _n
    file close `fh'
    capture mkdir "`qa_plus'/t"
    copy "`t'/src/tabg.ado" "`qa_plus'/t/tabg.ado", replace
    copy "`t'/src/plug-ins/linux64/tabg.plugin" "`qa_plus'/t/tabg.plugin", replace

    local keep_all "WIN WIN64A MAC MACARM64 LINUX LINUX64"
    local keep_Unix "LINUX LINUX64"
    quietly cd "`t'"
    foreach run in online_all online_Unix local_all local_Unix {
        gettoken mode os : run, parse("_")
        local os = substr("`os'", 2, .)
        local osopt = cond("`os'" == "all", "", "os(`os')")
        pkgtransfer, download(`mode') limited(tabg) `osopt' ///
            dofile(`run'.do) zipfile(`run'.zip)
        mkdir "`run'"
        quietly cd "`run'"
        unzipfile "../`run'.zip", replace
        local n_keep : word count `keep_`os''
        _v113_count_lines using "pkgtransfer_files/tabg.pkg", ///
            text("g ") prefix
        assert r(n) == `n_keep'
        forvalues i = 1/6 {
            local platform : word `i' of `tj_platforms'
            local dir : word `i' of `tj_dirs'
            local kept : list platform in keep_`os'
            _v113_count_lines using "pkgtransfer_files/tabg.pkg", ///
                text("g `platform' plug-ins/`dir'/tabg.plugin")
            assert r(n) == `kept'
            if `kept' confirm file "pkgtransfer_files/plug-ins/`dir'/tabg.plugin"
        }
        confirm file "pkgtransfer_files/tabg.ado"
        * The description keeps its tab byte for byte
        _v113_count_lines using "pkgtransfer_files/tabg.pkg", ///
            text("d tabg`tab'| tab fixture")
        assert r(n) == 1
        quietly cd "`t'"
    }
}
local test_rc = _rc
capture file close `fh'
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: online and local bundles parse tab-separated g records"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' online_tab_glines"
    display as error "  FAIL: tab-separated g records (rc `test_rc')"
}

**# Cleanup and result

quietly cd "`orig_dir'"
_pkgtransfer_qa_cleanup, root("`qa_root'") ///
    originalplus("`qa_original_plus'") ///
    originalpersonal("`qa_original_personal'")

if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    display as error ///
        "RESULT: test_pkgtransfer_v113 tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
    exit 1
}
display as result ///
    "RESULT: test_pkgtransfer_v113 tests=`test_count' pass=`pass_count' fail=0 skip=0"
