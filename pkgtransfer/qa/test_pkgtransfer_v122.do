/*
    File:    test_pkgtransfer_v122.do
    Purpose: Regression coverage for the 1.2.2 progress message: the
             "Copying OS-specific plugins from online..." line is shown only
             when a bundle really has platform-specific files to fetch
    Author:  Timothy P Copeland, Karolinska Institutet
    Date:    2026-10-13
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
capture program drop _v122_write
program define _v122_write
    version 16.0
    syntax using/, TEXT(string)
    tempname fh
    file open `fh' using `"`using'"', write text replace
    file write `fh' `"`text'"' _n
    file close `fh'
end

* Source repository with platform-specific g/G files that are not .plugin
capture program drop _v122_grepo
program define _v122_grepo
    version 16.0
    syntax, DIR(string)
    mkdir "`dir'"
    _v122_write using "`dir'/hcmd.ado", text("program define hcmd")
    tempname fh
    file open `fh' using "`dir'/hpkg.pkg", write text replace
    file write `fh' "v 3" _n "d hpkg native libraries" _n "f hcmd.ado" _n
    foreach platform in LINUX64 WIN64 MACARM64 {
        local p = lower("`platform'")
        file write `fh' "g `platform' jar_`p'.bin native.jar" _n
        file write `fh' "G `platform' rt_`p'.bin hrt.dta" _n
        _v122_write using "`dir'/jar_`p'.bin", text("jar bytes `platform'")
        _v122_write using "`dir'/rt_`p'.bin", text("runtime bytes `platform'")
    }
    file write `fh' "e" _n
    file close `fh'
    file open `fh' using "`dir'/stata.toc", write text replace
    file write `fh' "v 3" _n "p hpkg" _n
    file close `fh'
end


local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# 1. A local bundle with no platform-specific files never says it is going online

local ++test_count
local t "`work'/t01"
capture noisily {
    mkdir "`t'"
    _v122_write using "`qa_plus'/a/alpha.ado", text("program define alpha")
    tempname fh
    file open `fh' using "`qa_plus'/stata.trk", write text replace
    file write `fh' "* 00000001" _n _n
    file write `fh' "S https://example.org/alpha" _n "N alpha.pkg" _n
    file write `fh' "d alpha" _n "f a/alpha.ado" _n "e" _n
    file close `fh'
    quietly cd "`t'"
    log using "`t'/plain.log", text replace name(v122a)
    pkgtransfer, download(local) dofile(b.do) zipfile(b.zip)
    log close v122a
    confirm file "`t'/b.zip"
    assert strpos(fileread("`t'/plain.log"), "OS-specific plugins") == 0
}
local test_rc = _rc
capture log close v122a
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: no plugin message without platform-specific files"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' no_plugin_msg"
    display as error "  FAIL: plugin message on a plain bundle (rc `test_rc')"
}

**# 2. A bundle with platform-specific files still shows the message once
* guard: expected green at HEAD (behaviour-preservation: the message stays for platform bundles)

local ++test_count
local t "`work'/t02"
capture noisily {
    mkdir "`t'"
    foreach d in src_plus run {
        mkdir "`t'/`d'"
    }
    _v122_grepo, dir("`t'/repo")
    sysdir set PLUS "`t'/src_plus"
    quietly cd "`t'/run"
    net install hpkg, from("`t'/repo")
    log using "`t'/plat.log", text replace name(v122b)
    pkgtransfer, download(local) os(Windows) dofile(w.do) zipfile(w.zip)
    log close v122b
    mata: st_local("hits", strofreal(sum(strpos(cat(st_local("t") + "/plat.log"), "Copying OS-specific plugins") :> 0)))
    assert `hits' == 1
}
local test_rc = _rc
capture log close v122b
sysdir set PLUS "`qa_plus'"
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: plugin message kept for a bundle with platform-specific files"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' plugin_msg_kept"
    display as error "  FAIL: plugin message on a platform bundle (rc `test_rc')"
}

**# Cleanup and result

quietly cd "`orig_dir'"
_pkgtransfer_qa_cleanup, root("`qa_root'") ///
    originalplus("`qa_original_plus'") ///
    originalpersonal("`qa_original_personal'")

if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    display as error ///
        "RESULT: test_pkgtransfer_v122 tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
    exit 1
}
display as result ///
    "RESULT: test_pkgtransfer_v122 tests=`test_count' pass=`pass_count' fail=0 skip=0"
