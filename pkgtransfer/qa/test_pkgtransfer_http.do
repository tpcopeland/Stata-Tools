/*
    File:    test_pkgtransfer_http.do
    Purpose: download(online) and download(local) against a descriptor served
             over HTTP: g/G records for every platform family (including the
             OSX.* console names), a parent-relative source, tab-separated
             fields, and a piped description
    Author:  Timothy P Copeland, Karolinska Institutet
    Date:    2026-10-12

    Starts python3 -m http.server on 127.0.0.1 through the Unix shell, so it
    runs on Linux and macOS only. Opt-in network lane; a server that does not
    start is a failure, never a skip.
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
local tplus "`qa_root'/tplus"
mkdir "`tplus'"
erase "`qa_plus'/stata.trk"

capture program drop pkgtransfer
run "`pkg_dir'/pkgtransfer.ado"

capture program drop _http_count_lines
program define _http_count_lines, rclass
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

**# Served fixture: <srv>/repo/sub/gplug.pkg with a ../assets plugin source

local srv "`qa_root'/srv"
local tab = char(9)
tempname fh
foreach dir in "`srv'" "`srv'/repo" "`srv'/repo/sub" "`srv'/repo/assets" {
    mkdir "`dir'"
}
file open `fh' using "`srv'/repo/sub/stata.toc", write text replace
file write `fh' "v 3" _n "p gplug" _n
file close `fh'
file open `fh' using "`srv'/repo/sub/gplug.pkg", write text replace
file write `fh' "v 3" _n `"d gplug: fixture | with a pipe and "quotes""' _n
file write `fh' "f gplug.ado" _n
file write `fh' "g WIN64`tab'gplug_w.plugin gplug.plugin" _n
file write `fh' "G LINUX64 ../assets/gplug_l.plugin gplug.plugin" _n
file write `fh' "g MACARM64 gplug_m.plugin gplug.plugin" _n
file write `fh' "g OSX.ARM64 gplug_m.plugin gplug.plugin" _n
file write `fh' "e" _n
file close `fh'
file open `fh' using "`srv'/repo/sub/gplug.ado", write text replace
file write `fh' "program define gplug" _n `"    display "gplug ok""' _n "end" _n
file close `fh'
foreach f in sub/gplug_w sub/gplug_m assets/gplug_l {
    file open `fh' using "`srv'/repo/`f'.plugin", write text replace
    file write `fh' "`f'" _n
    file close `fh'
}

* Pick a port from the clock so concurrent lanes rarely collide
local port = 20000 + mod(floor(clock("`c(current_time)'", "hms") / 1000), 20000)
local url "http://127.0.0.1:`port'/repo/sub"
local pidfile "`qa_root'/http.pid"
shell cd "`srv'" && (python3 -m http.server `port' --bind 127.0.0.1 > /dev/null 2>&1 & echo $! > "`pidfile'")
local server_up 0
forvalues attempt = 1/20 {
    capture copy "`url'/stata.toc" "`qa_root'/probe.toc", replace
    if _rc == 0 {
        local server_up 1
        continue, break
    }
    sleep 500
}

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# 1. Install from the served descriptor

local ++test_count
capture noisily {
    assert `server_up'
    net install gplug, from("`url'") replace
    _http_count_lines using "`qa_plus'/stata.trk", text("S `url'")
    assert r(n) == 1
}
local install_rc = _rc
if `install_rc' == 0 {
    local ++pass_count
    display as result "  PASS: HTTP server up; package installed from it"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' http_install"
    display as error "  FAIL: HTTP fixture install (rc `install_rc'; server_up=`server_up')"
}

**# 2. Bundles from the served descriptor keep each platform family

local ++test_count
local t "`work'/t02"
capture noisily {
    assert `install_rc' == 0
    mkdir "`t'"
    local g_all "WIN64 LINUX64 MACARM64 OSX.ARM64"
    local g_MacOSX "MACARM64 OSX.ARM64"
    local g_Unix "LINUX64"
    local rec_WIN64 "g WIN64 gplug_w.plugin gplug.plugin"
    local rec_LINUX64 "G LINUX64 assets/gplug_l.plugin gplug.plugin"
    local rec_MACARM64 "g MACARM64 gplug_m.plugin gplug.plugin"
    local rec_OSX_ARM64 "g OSX.ARM64 gplug_m.plugin gplug.plugin"
    local file_WIN64 "gplug_w.plugin"
    local file_LINUX64 "assets/gplug_l.plugin"
    local file_MACARM64 "gplug_m.plugin"
    local file_OSX_ARM64 "gplug_m.plugin"
    foreach run in online_all online_MacOSX local_Unix {
        gettoken mode os : run, parse("_")
        local os = substr("`os'", 2, .)
        local osopt = cond("`os'" == "all", "", "os(`os')")
        quietly cd "`t'"
        mkdir "`run'"
        quietly cd "`run'"
        pkgtransfer, download(`mode') `osopt'
        mkdir "x"
        quietly cd "x"
        unzipfile "../pkgtransfer_files.zip", replace
        local n_g : word count `g_`os''
        _http_count_lines using "pkgtransfer_files/gplug.pkg", ///
            text("g ") prefix
        local n_lower = r(n)
        _http_count_lines using "pkgtransfer_files/gplug.pkg", ///
            text("G ") prefix
        assert `n_lower' + r(n) == `n_g'
        foreach platform of local g_`os' {
            local key = subinstr("`platform'", ".", "_", .)
            _http_count_lines using "pkgtransfer_files/gplug.pkg", ///
                text("`rec_`key''")
            assert r(n) == 1
            confirm file "pkgtransfer_files/`file_`key''"
        }
        _http_count_lines using "pkgtransfer_files/gplug.pkg", ///
            text(`"d gplug: fixture | with a pipe and "quotes""')
        assert r(n) == 1
        _http_count_lines using "pkgtransfer_files/gplug.pkg", ///
            text("d pkgtransfer-source `url'")
        assert r(n) == 1
    }
}
local test_rc = _rc
quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: HTTP bundles keep OSX.*, G case, ../ sources, pipes"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' http_bundles"
    display as error "  FAIL: HTTP bundle content (rc `test_rc')"
}

**# 3. The all-platform bundle installs this platform's plugin; restore is exact

local ++test_count
local t3 "`work'/t03"
capture noisily {
    assert `test_rc' == 0
    mkdir "`t3'"
    copy "`t'/online_all/pkgtransfer.do" "`t3'/pkgtransfer.do"
    copy "`t'/online_all/pkgtransfer_files.zip" "`t3'/pkgtransfer_files.zip"
    sysdir set PLUS "`tplus'"
    quietly cd "`t3'"
    do pkgtransfer.do
    local plat = cond("`c(os)'" == "MacOSX", "sub/gplug_m", "assets/gplug_l")
    _http_count_lines using "`tplus'/g/gplug.plugin", text("`plat'")
    assert r(n) == 1
    _http_count_lines using "`tplus'/stata.trk", text("S `url'")
    assert r(n) == 0
    pkgtransfer, restore
    _http_count_lines using "`tplus'/stata.trk", text("S `url'")
    assert r(n) == 1
}
local test_rc = _rc
sysdir set PLUS "`qa_plus'"
quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: target gets this platform's plugin; restore is exact"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' http_target"
    display as error "  FAIL: HTTP bundle on target (rc `test_rc')"
}

**# Cleanup and result

capture confirm file "`pidfile'"
if _rc == 0 shell kill $(cat "`pidfile'")
quietly cd "`orig_dir'"
foreach dir in "`work'" "`qa_plus'" "`srv'" {
    capture quietly _pkgtransfer_cleanup_staging, directory("`dir'")
}
capture mkdir "`work'"
capture mkdir "`qa_plus'"
capture quietly _pkgtransfer_cleanup_staging, directory("`tplus'")
capture erase "`pidfile'"
capture erase "`qa_root'/probe.toc"
_pkgtransfer_qa_cleanup, root("`qa_root'") ///
    originalplus("`qa_original_plus'") ///
    originalpersonal("`qa_original_personal'")

if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    display as error ///
        "RESULT: test_pkgtransfer_http tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
    exit 1
}
display as result ///
    "RESULT: test_pkgtransfer_http tests=`test_count' pass=`pass_count' fail=0 skip=0"
