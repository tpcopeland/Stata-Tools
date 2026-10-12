/*
    File:    test_pkgtransfer_v120.do
    Purpose: Regression coverage for the 1.2.0 descriptor-fidelity, second-hop,
             and replace fixes (F records, non-plugin g/G files, restore markers)
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

capture program drop pkgtransfer
run "`pkg_dir'/pkgtransfer.ado"

* Count file lines that equal (exact) or start with (prefix) a string
capture program drop _v120_count_lines
program define _v120_count_lines, rclass
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

* Write one text file
capture program drop _v120_write
program define _v120_write
    version 16.0
    syntax using/, TEXT(string)
    tempname fh
    file open `fh' using `"`using'"', write text replace
    file write `fh' `"`text'"' _n
    file close `fh'
end

* Source repository whose descriptor uses F for non-installation file types
capture program drop _v120_frepo
program define _v120_frepo
    version 16.0
    syntax, DIR(string)
    mkdir "`dir'"
    _v120_write using "`dir'/fcmd.ado", text("program define fcmd")
    _v120_write using "`dir'/fnote.txt", text("forced note")
    _v120_write using "`dir'/fasset", text("forced extensionless asset")
    preserve
    clear
    quietly set obs 3
    quietly generate double x = _n * 1.5
    quietly save "`dir'/fdata.dta"
    restore
    tempname fh
    file open `fh' using "`dir'/fpkg.pkg", write text replace
    file write `fh' "v 3" _n "d fpkg forced runtime assets" _n
    file write `fh' "f fcmd.ado" _n "F fdata.dta" _n "F fnote.txt" _n
    file write `fh' "F fasset" _n "e" _n
    file close `fh'
    file open `fh' using "`dir'/stata.toc", write text replace
    file write `fh' "v 3" _n "p fpkg" _n
    file close `fh'
end

* Source repository with platform-specific g/G files that are not .plugin
capture program drop _v120_grepo
program define _v120_grepo
    version 16.0
    syntax, DIR(string)
    mkdir "`dir'"
    _v120_write using "`dir'/hcmd.ado", text("program define hcmd")
    tempname fh
    file open `fh' using "`dir'/hpkg.pkg", write text replace
    file write `fh' "v 3" _n "d hpkg native libraries" _n "f hcmd.ado" _n
    foreach platform in LINUX64 WIN64 MACARM64 {
        local p = lower("`platform'")
        file write `fh' "g `platform' jar_`p'.bin native.jar" _n
        file write `fh' "G `platform' rt_`p'.bin hrt.dta" _n
        _v120_write using "`dir'/jar_`p'.bin", text("jar bytes `platform'")
        _v120_write using "`dir'/rt_`p'.bin", text("runtime bytes `platform'")
    }
    file write `fh' "e" _n
    file close `fh'
    file open `fh' using "`dir'/stata.toc", write text replace
    file write `fh' "v 3" _n "p hpkg" _n
    file close `fh'
end

* One-file package repository
capture program drop _v120_arepo
program define _v120_arepo
    version 16.0
    syntax, DIR(string)
    mkdir "`dir'"
    _v120_write using "`dir'/alpha.ado", text("program define alpha")
    tempname fh
    file open `fh' using "`dir'/alpha.pkg", write text replace
    file write `fh' "v 3" _n "d alpha two-hop fixture" _n "f alpha.ado" _n "e" _n
    file close `fh'
    file open `fh' using "`dir'/stata.toc", write text replace
    file write `fh' "v 3" _n "p alpha" _n
    file close `fh'
end

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# 1. F records survive a local bundle and install into PLUS byte for byte

local ++test_count
local t "`work'/t01"
capture noisily {
    mkdir "`t'"
    foreach d in src_plus dst_plus run x {
        mkdir "`t'/`d'"
    }
    _v120_frepo, dir("`t'/repo")
    sysdir set PLUS "`t'/src_plus"
    quietly cd "`t'/run"
    net install fpkg, from("`t'/repo")
    confirm file "`t'/src_plus/f/fdata.dta"

    pkgtransfer, download(local) dofile(b.do) zipfile(b.zip)
    quietly cd "`t'/x"
    unzipfile "`t'/run/b.zip", replace
    local desc "pkgtransfer_files/fpkg.pkg"
    foreach f in fcmd.ado fdata.dta fnote.txt fasset {
        _v120_count_lines using "`desc'", text("F `f'")
        assert r(n) == 1
    }
    _v120_count_lines using "`desc'", text("f ") prefix
    assert r(n) == 0

    sysdir set PLUS "`t'/dst_plus"
    quietly cd "`t'/run"
    do "b.do"
    foreach f in fdata.dta fnote.txt fasset fcmd.ado {
        local letter = substr("`f'", 1, 1)
        assert fileread("`t'/dst_plus/`letter'/`f'") == fileread("`t'/repo/`f'")
    }
}
local test_rc = _rc
sysdir set PLUS "`qa_plus'"
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: local bundle keeps F records; forced files reach PLUS"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' local_F"
    display as error "  FAIL: local bundle F records (rc `test_rc')"
}

**# 2. F records survive an online bundle and install into PLUS byte for byte

local ++test_count
local t "`work'/t02"
capture noisily {
    mkdir "`t'"
    foreach d in src_plus dst_plus run x {
        mkdir "`t'/`d'"
    }
    _v120_frepo, dir("`t'/repo")
    sysdir set PLUS "`t'/src_plus"
    quietly cd "`t'/run"
    net install fpkg, from("`t'/repo")

    pkgtransfer, download(online) limited(fpkg) dofile(b.do) zipfile(b.zip)
    quietly cd "`t'/x"
    unzipfile "`t'/run/b.zip", replace
    local desc "pkgtransfer_files/fpkg.pkg"
    foreach f in fdata.dta fnote.txt fasset {
        _v120_count_lines using "`desc'", text("F `f'")
        assert r(n) == 1
    }
    _v120_count_lines using "`desc'", text("f fcmd.ado")
    assert r(n) == 1

    sysdir set PLUS "`t'/dst_plus"
    quietly cd "`t'/run"
    do "b.do"
    foreach f in fdata.dta fnote.txt fasset fcmd.ado {
        local letter = substr("`f'", 1, 1)
        assert fileread("`t'/dst_plus/`letter'/`f'") == fileread("`t'/repo/`f'")
    }
}
local test_rc = _rc
sysdir set PLUS "`qa_plus'"
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: online bundle keeps F records; forced files reach PLUS"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' online_F"
    display as error "  FAIL: online bundle F records (rc `test_rc')"
}

**# 3. Local bundles route non-plugin g/G files through platform selection

local ++test_count
local t "`work'/t03"
capture noisily {
    mkdir "`t'"
    foreach d in src_plus dst_plus run {
        mkdir "`t'/`d'"
    }
    _v120_grepo, dir("`t'/repo")
    sysdir set PLUS "`t'/src_plus"
    quietly cd "`t'/run"
    net install hpkg, from("`t'/repo")

    * os(Windows): only the WIN64 records and bytes, no installed-platform copy
    pkgtransfer, download(local) os(Windows) dofile(w.do) zipfile(w.zip)
    mkdir "`t'/xw"
    quietly cd "`t'/xw"
    unzipfile "`t'/run/w.zip", replace
    local desc "pkgtransfer_files/hpkg.pkg"
    _v120_count_lines using "`desc'", text("g WIN64 jar_win64.bin native.jar")
    assert r(n) == 1
    _v120_count_lines using "`desc'", text("G WIN64 rt_win64.bin hrt.dta")
    assert r(n) == 1
    _v120_count_lines using "`desc'", text("g ") prefix
    assert r(n) == 1
    _v120_count_lines using "`desc'", text("G ") prefix
    assert r(n) == 1
    foreach dropped in "F native.jar" "F hrt.dta" "f native.jar" "f hrt.dta" {
        _v120_count_lines using "`desc'", text("`dropped'")
        assert r(n) == 0
    }
    _v120_count_lines using "`desc'", text("F hcmd.ado")
    assert r(n) == 1
    assert fileread("pkgtransfer_files/jar_win64.bin") == ///
        fileread("`t'/repo/jar_win64.bin")
    assert fileread("pkgtransfer_files/rt_win64.bin") == ///
        fileread("`t'/repo/rt_win64.bin")
    foreach absent in native.jar hrt.dta jar_linux64.bin rt_linux64.bin {
        capture confirm file "pkgtransfer_files/`absent'"
        assert _rc == 601
    }

    * No os(): every platform record; installing on this machine selects its build
    quietly cd "`t'/run"
    pkgtransfer, download(local) dofile(a.do) zipfile(a.zip)
    mkdir "`t'/xa"
    quietly cd "`t'/xa"
    unzipfile "`t'/run/a.zip", replace
    foreach platform in LINUX64 WIN64 MACARM64 {
        local p = lower("`platform'")
        _v120_count_lines using "`desc'", text("g `platform' jar_`p'.bin native.jar")
        assert r(n) == 1
        _v120_count_lines using "`desc'", text("G `platform' rt_`p'.bin hrt.dta")
        assert r(n) == 1
    }
    if "`c(os)'" == "Unix" {
        sysdir set PLUS "`t'/dst_plus"
        quietly cd "`t'/run"
        do "a.do"
        assert fileread("`t'/dst_plus/jar/native.jar") == ///
            fileread("`t'/repo/jar_linux64.bin")
        assert fileread("`t'/dst_plus/h/hrt.dta") == ///
            fileread("`t'/repo/rt_linux64.bin")
    }
}
local test_rc = _rc
sysdir set PLUS "`qa_plus'"
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: non-plugin g/G files follow os() in local bundles"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' local_nonplugin_g"
    display as error "  FAIL: non-plugin g/G platform selection (rc `test_rc')"
}

**# 4. Unreadable source descriptor: files bundled as installed, with a note

local ++test_count
local t "`work'/t04"
capture noisily {
    mkdir "`t'"
    _v120_write using "`qa_plus'/a/alpha.ado", text("program define alpha")
    tempname fh
    file open `fh' using "`qa_plus'/stata.trk", write text replace
    file write `fh' "* 00000001" _n _n
    file write `fh' "S `t'/gone" _n "N alpha.pkg" _n "d alpha | gone source" _n
    file write `fh' "f a/alpha.ado" _n "e" _n
    file close `fh'
    quietly cd "`t'"
    log using "`t'/note.log", text replace name(v120note)
    pkgtransfer, download(local) dofile(b.do) zipfile(b.zip)
    log close v120note
    assert strpos(fileread("`t'/note.log"), ///
        "Note: could not read the source descriptor of: alpha") > 0
    mkdir "x"
    quietly cd "x"
    unzipfile "../b.zip", replace
    _v120_count_lines using "pkgtransfer_files/alpha.pkg", text("F alpha.ado")
    assert r(n) == 1
    assert fileread("pkgtransfer_files/alpha.ado") == ///
        fileread("`qa_plus'/a/alpha.ado")
}
local test_rc = _rc
capture log close v120note
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: unreadable descriptor bundles installed files with a note"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' unread_descriptor"
    display as error "  FAIL: unreadable descriptor route (rc `test_rc')"
}

**# 5. Two local hops keep the original source; restore returns it

local ++test_count
local t "`work'/t05"
capture noisily {
    mkdir "`t'"
    foreach d in p1 p2 p3 h1 h2 x {
        mkdir "`t'/`d'"
    }
    _v120_arepo, dir("`t'/repo")
    sysdir set PLUS "`t'/p1"
    quietly cd "`t'/h1"
    net install alpha, from("`t'/repo")

    pkgtransfer, download(local) dofile(b.do) zipfile(b.zip)
    sysdir set PLUS "`t'/p2"
    do "b.do"
    _v120_count_lines using "`t'/p2/stata.trk", text("S `t'/h1/pkgtransfer_files")
    assert r(n) == 1
    _v120_count_lines using "`t'/p2/stata.trk", ///
        text("d pkgtransfer-source `t'/repo")
    assert r(n) == 1

    * Second hop from the bundle-installed machine
    quietly cd "`t'/h2"
    pkgtransfer, download(local) dofile(b.do) zipfile(b.zip)
    quietly cd "`t'/x"
    unzipfile "`t'/h2/b.zip", replace
    _v120_count_lines using "pkgtransfer_files/alpha.pkg", ///
        text("d pkgtransfer-source ") prefix
    assert r(n) == 1
    _v120_count_lines using "pkgtransfer_files/alpha.pkg", ///
        text("d pkgtransfer-source `t'/repo")
    assert r(n) == 1

    sysdir set PLUS "`t'/p3"
    quietly cd "`t'/h2"
    do "b.do"
    pkgtransfer, restore
    _v120_count_lines using "`t'/p3/stata.trk", text("S `t'/repo")
    assert r(n) == 1
    _v120_count_lines using "`t'/p3/stata.trk", text("S ") prefix
    assert r(n) == 1
    _v120_count_lines using "`t'/p3/stata.trk", ///
        text("d pkgtransfer-source ") prefix
    assert r(n) == 0
}
local test_rc = _rc
sysdir set PLUS "`qa_plus'"
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: second local hop restores the original source"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' two_hop_local"
    display as error "  FAIL: two-hop local restore (rc `test_rc')"
}

**# 6. An online hop from a bundle-installed machine adds no second marker

local ++test_count
local t "`work'/t06"
capture noisily {
    mkdir "`t'"
    foreach d in p1 p2 p3 h1 h2 x {
        mkdir "`t'/`d'"
    }
    _v120_arepo, dir("`t'/repo")
    sysdir set PLUS "`t'/p1"
    quietly cd "`t'/h1"
    net install alpha, from("`t'/repo")
    pkgtransfer, download(local) dofile(b.do) zipfile(b.zip)
    sysdir set PLUS "`t'/p2"
    do "b.do"

    * p2 records S h1/pkgtransfer_files, whose descriptor carries the marker
    quietly cd "`t'/h2"
    pkgtransfer, download(online) limited(alpha) dofile(b.do) zipfile(b.zip)
    quietly cd "`t'/x"
    unzipfile "`t'/h2/b.zip", replace
    _v120_count_lines using "pkgtransfer_files/alpha.pkg", ///
        text("d pkgtransfer-source ") prefix
    assert r(n) == 1
    _v120_count_lines using "pkgtransfer_files/alpha.pkg", ///
        text("d pkgtransfer-source `t'/repo")
    assert r(n) == 1

    sysdir set PLUS "`t'/p3"
    quietly cd "`t'/h2"
    do "b.do"
    pkgtransfer, restore
    _v120_count_lines using "`t'/p3/stata.trk", text("S `t'/repo")
    assert r(n) == 1
}
local test_rc = _rc
sysdir set PLUS "`qa_plus'"
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: online hop keeps one original marker"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' two_hop_online"
    display as error "  FAIL: two-hop online marker (rc `test_rc')"
}

**# 7. restore picks the original marker from a pre-1.2.0 stacked entry

local ++test_count
local t "`work'/t07"
tempname fh
capture noisily {
    mkdir "`t'"
    file open `fh' using "`qa_plus'/stata.trk", write text replace
    file write `fh' "* 00000001" _n _n
    file write `fh' "S /old/machine2/pkgtransfer_files" _n "N alpha.pkg" _n
    file write `fh' "D 12 Oct 2026" _n "U 1" _n "d alpha" _n
    file write `fh' "d pkgtransfer-source /old/machine1/pkgtransfer_files" _n
    file write `fh' "d pkgtransfer-source https://example.org/alpha" _n
    file write `fh' "f a/alpha.ado" _n "e" _n
    file write `fh' "S https://example.org/beta" _n "N beta.pkg" _n
    file write `fh' "d beta" _n "f b/beta.ado" _n "e" _n
    file close `fh'
    pkgtransfer, restore
    _v120_count_lines using "`qa_plus'/stata.trk", text("S https://example.org/alpha")
    assert r(n) == 1
    _v120_count_lines using "`qa_plus'/stata.trk", text("S https://example.org/beta")
    assert r(n) == 1
    _v120_count_lines using "`qa_plus'/stata.trk", text("S /old/") prefix
    assert r(n) == 0
    _v120_count_lines using "`qa_plus'/stata.trk", ///
        text("d pkgtransfer-source ") prefix
    assert r(n) == 0
}
local test_rc = _rc
capture file close `fh'
capture erase "`qa_plus'/stata.trk.backup"
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: restore uses the last (original) stacked marker"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' stacked_markers"
    display as error "  FAIL: stacked-marker restore (rc `test_rc')"
}

**# 8. Existing outputs are refused without replace (602), overwritten with it

local ++test_count
local t "`work'/t08"
capture noisily {
    mkdir "`t'"
    _v120_write using "`qa_plus'/a/alpha.ado", text("program define alpha")
    tempname fh
    file open `fh' using "`qa_plus'/stata.trk", write text replace
    file write `fh' "* 00000001" _n _n
    file write `fh' "S https://example.org/alpha" _n "N alpha.pkg" _n
    file write `fh' "d alpha" _n "f a/alpha.ado" _n "e" _n
    file close `fh'
    quietly cd "`t'"
    _v120_write using "mywork.do", text("* USER SENTINEL")
    _v120_write using "mine.zip", text("not a zip")
    local sentinel_do = fileread("mywork.do")
    local sentinel_zip = fileread("mine.zip")

    * Script mode
    log using "`t'/r1.log", text replace name(v120r1)
    capture noisily pkgtransfer, dofile(mywork.do)
    local call_rc = _rc
    log close v120r1
    assert `call_rc' == 602
    assert strpos(fileread("`t'/r1.log"), ///
        "file mywork.do already exists; specify replace to overwrite it") > 0
    assert fileread("mywork.do") == `"`sentinel_do'"'

    * Download mode: the existing archive is refused before staging
    capture noisily pkgtransfer, download(local) dofile(new.do) zipfile(mine.zip)
    assert _rc == 602
    assert fileread("mine.zip") == `"`sentinel_zip'"'
    capture confirm file "new.do"
    assert _rc == 601
    local staged : dir "." dirs "pkgtransfer_files"
    assert `"`staged'"' == ""

    * Download mode: the existing do-file is refused too
    capture noisily pkgtransfer, download(local) dofile(mywork.do) zipfile(new.zip)
    assert _rc == 602
    capture confirm file "new.zip"
    assert _rc == 601

    * replace overwrites both
    pkgtransfer, dofile(mywork.do) replace
    assert strpos(fileread("mywork.do"), "net install alpha") > 0
    pkgtransfer, download(local) dofile(mywork.do) zipfile(mine.zip) replace
    assert fileread("mine.zip") != `"`sentinel_zip'"'
    assert strpos(fileread("mywork.do"), "unzipfile") > 0

    * Standalone restore writes no outputs, so replace is refused there
    log using "`t'/r2.log", text replace name(v120r2)
    capture noisily pkgtransfer, restore replace
    local call_rc = _rc
    log close v120r2
    assert `call_rc' == 198
    assert strpos(fileread("`t'/r2.log"), ///
        "restore without download() cannot be combined with: replace") > 0
    assert strpos(fileread("`t'/r2.log"), "replace()") == 0
}
local test_rc = _rc
capture log close v120r1
capture log close v120r2
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: outputs need replace; restore refuses replace"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' replace_option"
    display as error "  FAIL: replace contract (rc `test_rc')"
}

**# 9. download() and os() accept any case and return canonical spellings

local ++test_count
local t "`work'/t09"
capture noisily {
    mkdir "`t'"
    _v120_write using "`qa_plus'/a/alpha.ado", text("program define alpha")
    tempname fh
    file open `fh' using "`qa_plus'/stata.trk", write text replace
    file write `fh' "* 00000001" _n _n
    file write `fh' "S https://example.org/alpha" _n "N alpha.pkg" _n
    file write `fh' "d alpha" _n "f a/alpha.ado" _n "e" _n
    file close `fh'
    quietly cd "`t'"
    pkgtransfer, download(LOCAL) os(windows) dofile(b.do) zipfile(b.zip)
    assert "`r(download_mode)'" == "local"
    assert "`r(os)'" == "Windows"
    assert strpos(fileread("b.do"), "rmdir /s /q") > 0
    foreach spelling in macosx MACOSX MacOSX {
        pkgtransfer, os(`spelling') dofile(s.do) replace
        assert "`r(os)'" == "MacOSX"
    }
    pkgtransfer, os(UNIX) dofile(s.do) replace
    assert "`r(os)'" == "Unix"
    capture noisily pkgtransfer, os(linux) dofile(s.do) replace
    assert _rc == 198
    capture noisily pkgtransfer, download(offline) dofile(s.do) replace
    assert _rc == 198
}
local test_rc = _rc
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: case-insensitive download() and os()"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' option_case"
    display as error "  FAIL: option case handling (rc `test_rc')"
}

**# 10. Duplicate-tracker error names the documented remedy

local ++test_count
local t "`work'/t10"
capture noisily {
    mkdir "`t'"
    tempname fh
    file open `fh' using "`qa_plus'/stata.trk", write text replace
    file write `fh' "* 00000001" _n _n
    foreach src in one two {
        file write `fh' "S https://example.org/`src'" _n "N alpha.pkg" _n
        file write `fh' "d alpha" _n "f a/alpha.ado" _n "e" _n
    }
    file close `fh'
    quietly cd "`t'"
    log using "`t'/dup.log", text replace name(v120dup)
    capture noisily pkgtransfer, dofile(b.do)
    local call_rc = _rc
    log close v120dup
    assert `call_rc' == 459
    assert strpos(fileread("`t'/dup.log"), ///
        "Use -ado dir- and -ado uninstall [#]- to remove the older copy.") > 0
    assert strpos(fileread("`t'/dup.log"), "ado update") == 0
}
local test_rc = _rc
capture log close v120dup
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: duplicate-tracker error gives ado dir / ado uninstall"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' duplicate_message"
    display as error "  FAIL: duplicate-tracker message (rc `test_rc')"
}

**# 11. A g file with no record for the requested os() stops the bundle (498)

local ++test_count
local t "`work'/t11"
tempname fh
capture noisily {
    mkdir "`t'"
    foreach d in src_plus run {
        mkdir "`t'/`d'"
    }
    mkdir "`t'/repo"
    _v120_write using "`t'/repo/jcmd.ado", text("program define jcmd")
    file open `fh' using "`t'/repo/jpkg.pkg", write text replace
    file write `fh' "v 3" _n "d jpkg linux and windows only" _n "f jcmd.ado" _n
    foreach platform in LINUX64 WIN64 {
        local p = lower("`platform'")
        file write `fh' "g `platform' j_`p'.bin only.jar" _n
        _v120_write using "`t'/repo/j_`p'.bin", text("jar `platform'")
    }
    file write `fh' "e" _n
    file close `fh'
    _v120_write using "`t'/repo/stata.toc", text("v 3")
    sysdir set PLUS "`t'/src_plus"
    quietly cd "`t'/run"
    net install jpkg, from("`t'/repo")
    log using "`t'/os.log", text replace name(v120os)
    capture noisily pkgtransfer, download(local) os(MacOSX) dofile(b.do) zipfile(b.zip)
    local call_rc = _rc
    log close v120os
    assert `call_rc' == 498
    assert strpos(fileread("`t'/os.log"), ///
        "Platform file only.jar has no platform record for os(MacOSX)") > 0
    local staged : dir "." dirs "pkgtransfer_files"
    assert `"`staged'"' == ""
    capture confirm file "b.zip"
    assert _rc == 601
    * A matching OS still bundles
    pkgtransfer, download(local) os(Windows) dofile(w.do) zipfile(w.zip)
    confirm file "w.zip"
}
local test_rc = _rc
capture file close `fh'
capture log close v120os
sysdir set PLUS "`qa_plus'"
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: g file without the requested OS exits 498"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' os_no_variant"
    display as error "  FAIL: os() without a matching g record (rc `test_rc')"
}

**# 12. A .plugin package whose source descriptor is unreadable fails

local ++test_count
local t "`work'/t12"
tempname fh
capture noisily {
    mkdir "`t'"
    _v120_write using "`qa_plus'/p/gonep.plugin", text("installed plugin")
    _v120_write using "`qa_plus'/p/gonep.ado", text("program define gonep")
    file open `fh' using "`qa_plus'/stata.trk", write text replace
    file write `fh' "* 00000001" _n _n
    file write `fh' "S `t'/gone" _n "N gonep.pkg" _n "d gonep | gone source" _n
    file write `fh' "f p/gonep.plugin" _n "f p/gonep.ado" _n "e" _n
    file close `fh'
    quietly cd "`t'"
    capture noisily pkgtransfer, download(local) dofile(b.do) zipfile(b.zip)
    local call_rc = _rc
    assert `call_rc' != 0
    capture confirm file "b.zip"
    assert _rc == 601
    local staged : dir "." dirs "pkgtransfer_files"
    assert `"`staged'"' == ""
}
local test_rc = _rc
capture file close `fh'
capture erase "`qa_plus'/p/gonep.plugin"
capture erase "`qa_plus'/p/gonep.ado"
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: unreadable descriptor for a plugin package fails (rc `call_rc')"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' plugin_unread"
    display as error "  FAIL: plugin package with unreadable descriptor (rc `test_rc')"
}

**# Cleanup and result

quietly cd "`orig_dir'"
_pkgtransfer_qa_cleanup, root("`qa_root'") ///
    originalplus("`qa_original_plus'") ///
    originalpersonal("`qa_original_personal'")

if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    display as error ///
        "RESULT: test_pkgtransfer_v120 tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
    exit 1
}
display as result ///
    "RESULT: test_pkgtransfer_v120 tests=`test_count' pass=`pass_count' fail=0 skip=0"
