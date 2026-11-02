/*
    File:    test_pkgtransfer_v101.do
    Purpose: Regression coverage for 1.0.1: download(local) bundles a .plugin
             that the source descriptor lists as a plain f record (gtools),
             and a file that two packages both install (reghdfe5.mata in
             reghdfe and ppmlhdfe); both bundles install offline
    Author:  Timothy P Copeland, Karolinska Institutet
    Date:    2026-11-02
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

* Write one text file
capture program drop _v101_write
program define _v101_write
    version 16.0
    syntax using/, TEXT(string)
    tempname fh
    file open `fh' using `"`using'"', write text replace
    file write `fh' `"`text'"' _n
    file close `fh'
end

* Source repository: one package whose lines are given as f records
capture program drop _v101_repo
program define _v101_repo
    version 16.0
    syntax, DIR(string) PKG(string) FILES(string)
    capture mkdir "`dir'"
    tempname fh
    file open `fh' using "`dir'/`pkg'.pkg", write text replace
    file write `fh' "v 3" _n "d `pkg' fixture" _n
    foreach f of local files {
        file write `fh' "f `f'" _n
        _v101_write using "`dir'/`f'", text("shared bytes `f'")
    }
    file write `fh' "e" _n
    file close `fh'
    file open `fh' using "`dir'/stata.toc", write text replace
    file write `fh' "v 3" _n "p `pkg'" _n
    file close `fh'
end

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# 1. A .plugin listed as a plain f record for every OS is bundled from PLUS

local ++test_count
local t "`work'/t01"
capture noisily {
    foreach d in "" /src_plus /dest_plus /run {
        mkdir "`t'`d'"
    }
    _v101_repo, dir("`t'/repo") pkg(gplug) ///
        files(gplug.ado gplug_unix.plugin gplug_windows.plugin gplug_macosx.plugin)
    sysdir set PLUS "`t'/src_plus/"
    net install gplug, from("`t'/repo")
    quietly cd "`t'/run"
    pkgtransfer, download(local) dofile(b.do) zipfile(b.zip)
    assert r(N_packages) == 1
    sysdir set PLUS "`t'/dest_plus/"
    do b.do
    foreach f in gplug.ado gplug_unix.plugin gplug_windows.plugin gplug_macosx.plugin {
        local sub = substr("`f'", 1, 1)
        confirm file "`t'/dest_plus/`sub'/`f'"
    }
}
local test_rc = _rc
sysdir set PLUS "`qa_plus'"
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: plain f .plugin files bundled and installed offline"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' plain_plugin"
    display as error "  FAIL: plain f .plugin bundle (rc `test_rc')"
}

**# 2. A file installed by two packages is bundled once and installs both

local ++test_count
local t "`work'/t02"
capture noisily {
    foreach d in "" /src_plus /dest_plus /run {
        mkdir "`t'`d'"
    }
    _v101_repo, dir("`t'/repo_a") pkg(apkg) files(apkg.ado shared5.mata)
    _v101_repo, dir("`t'/repo_b") pkg(bpkg) files(bpkg.ado shared5.mata)
    sysdir set PLUS "`t'/src_plus/"
    net install apkg, from("`t'/repo_a")
    net install bpkg, from("`t'/repo_b") replace
    quietly cd "`t'/run"
    pkgtransfer, download(local) limited(apkg bpkg) dofile(b.do) zipfile(b.zip)
    assert r(N_packages) == 2
    sysdir set PLUS "`t'/dest_plus/"
    do b.do
    foreach f in a/apkg.ado b/bpkg.ado s/shared5.mata {
        confirm file "`t'/dest_plus/`f'"
    }
    local trk = fileread("`t'/dest_plus/stata.trk")
    assert strpos(`"`trk'"', "N apkg.pkg") > 0
    assert strpos(`"`trk'"', "N bpkg.pkg") > 0
}
local test_rc = _rc
sysdir set PLUS "`qa_plus'"
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: shared file bundled once; both packages install offline"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' shared_file"
    display as error "  FAIL: shared file bundle (rc `test_rc')"
}

**# Cleanup and result

quietly cd "`orig_dir'"
_pkgtransfer_qa_cleanup, root("`qa_root'") ///
    originalplus("`qa_original_plus'") ///
    originalpersonal("`qa_original_personal'")

if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    display as error ///
        "RESULT: test_pkgtransfer_v101 tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
    exit 1
}
display as result ///
    "RESULT: test_pkgtransfer_v101 tests=`test_count' pass=`pass_count' fail=0 skip=0"
