/*
    File:    test_pkgtransfer_network.do
    Purpose: Live-internet round trip: real SSC, university, and GitHub sources
             through download(online), download(local), a clean target, and restore
    Author:  Timothy P Copeland, Karolinska Institutet
    Date:    2026-10-12

    Requires internet access. Runs only in the opt-in network lane; an
    unreachable source is a failure, never a skip. Sources:
      fre      SSC, ordinary files
      gtools   SSC, plugins declared as plain f records
      traj     andrew.cmu.edu, tab-separated two-field g records, one plugin
               name in eight platform subdirectories
      datefix  raw.githubusercontent.com (Stata-Tools)
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

* Start from an empty tracker so only the live packages are tracked
erase "`qa_plus'/stata.trk"

local traj_url "https://www.andrew.cmu.edu/user/bjones/traj"
local gh_url "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/datefix"

* Count lines equal to (or, with prefix, starting with) a string; trailing
* blanks are ignored because outfile pads script-only lines
capture program drop _net_count_lines
program define _net_count_lines, rclass
    version 16.0
    syntax using/, TEXT(string asis) [PREFIX]
    gettoken text : text
    tempname fh
    local n 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        local line = strrtrim(`"`macval(line)'"')
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

* Source line (S record) recorded for one package in a tracker
capture program drop _net_source_of
program define _net_source_of, rclass
    version 16.0
    syntax using/, PKG(string)
    tempname fh
    local prev ""
    local src ""
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if `"`macval(line)'"' == "N `pkg'.pkg" local src `"`macval(prev)'"'
        local prev `"`macval(line)'"'
        file read `fh' line
    }
    file close `fh'
    return local source `"`macval(src)'"'
end

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# 1. Live installs into the sandboxed source PLUS

local ++test_count
capture noisily {
    ssc install fre, replace
    ssc install gtools, replace
    net install traj, from("`traj_url'") replace
    net install datefix, from("`gh_url'") replace
    foreach pkg in fre gtools traj datefix {
        _net_count_lines using "`qa_plus'/stata.trk", text("N `pkg'.pkg")
        assert r(n) == 1
    }
    confirm file "`qa_plus'/t/traj.plugin"
}
local live_rc = _rc
if `live_rc' == 0 {
    local ++pass_count
    display as result "  PASS: live installs from SSC, cmu.edu, and GitHub"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' live_install"
    display as error "  FAIL: live install (rc `live_rc'); network unavailable or a source moved"
}

* The installs above may define programs; test the working-tree command
capture program drop pkgtransfer
run "`pkg_dir'/pkgtransfer.ado"

**# 2. Script-only output names each live source exactly

local ++test_count
local t "`work'/t02"
capture noisily {
    assert `live_rc' == 0
    mkdir "`t'"
    quietly cd "`t'"
    pkgtransfer, dofile(script.do)
    assert r(N_packages) == 4
    _net_count_lines using "script.do", text("ssc install fre, replace")
    assert r(n) == 1
    _net_count_lines using "script.do", text("ssc install gtools, replace")
    assert r(n) == 1
    _net_count_lines using "script.do", ///
        text(`"net install traj, replace from("`traj_url'/")"')
    assert r(n) == 1
    _net_count_lines using "script.do", ///
        text(`"net install datefix, replace from("`gh_url'/")"')
    assert r(n) == 1
}
local test_rc = _rc
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: script-only commands match live sources"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' script_only"
    display as error "  FAIL: script-only live sources (rc `test_rc')"
}

**# 3. download(online) bundles every live file and plugin variant

local ++test_count
local t "`work'/t03"
local bundle_rc 1
capture noisily {
    assert `live_rc' == 0
    mkdir "`t'"
    quietly cd "`t'"
    pkgtransfer, download(online) dofile(all.do) zipfile(all.zip)
    assert r(N_packages) == 4
    local got "`r(package_list)'"
    local want "datefix fre gtools traj"
    local got : list sort got
    assert "`got'" == "`want'"
    mkdir "x"
    quietly cd "x"
    unzipfile "../all.zip", replace

    * traj: eight single-spaced g records, five distinct plugin files
    _net_count_lines using "pkgtransfer_files/traj.pkg", text("g ") prefix
    assert r(n) == 8
    foreach rec in "WIN plug-ins/win" "WIN64A plug-ins/win64a" ///
        "MAC plug-ins/mac" "MACINTEL plug-ins/mac" ///
        "MACINTEL64 plug-ins/mac" "MACARM64 plug-ins/mac" ///
        "LINUX plug-ins/linux" "LINUX64 plug-ins/linux64" {
        _net_count_lines using "pkgtransfer_files/traj.pkg", ///
            text("g `rec'/traj.plugin")
        assert r(n) == 1
    }
    foreach dir in win win64a mac linux linux64 {
        confirm file "pkgtransfer_files/plug-ins/`dir'/traj.plugin"
    }
    * The bundled Linux build is the one the source machine installed
    checksum "pkgtransfer_files/plug-ins/linux64/traj.plugin"
    local bundled_sum = r(checksum)
    checksum "`qa_plus'/t/traj.plugin"
    assert r(checksum) == `bundled_sum'

    * gtools: every f-record plugin travels
    foreach os in windows unix macosx {
        foreach v in v2 v3 {
            confirm file "pkgtransfer_files/gtools_`os'_`v'.plugin"
        }
    }
    confirm file "pkgtransfer_files/datefix.ado"
    confirm file "pkgtransfer_files/fre.ado"

    * Every descriptor carries its private restore marker; toc lists all four
    foreach pkg in fre gtools traj datefix {
        _net_count_lines using "pkgtransfer_files/`pkg'.pkg", ///
            text("d pkgtransfer-source ") prefix
        assert r(n) == 1
    }
    _net_count_lines using "pkgtransfer_files/stata.toc", text("p ") prefix
    assert r(n) == 4
}
local bundle_rc = _rc
quietly cd "`orig_dir'"
if `bundle_rc' == 0 {
    local ++pass_count
    display as result "  PASS: online bundle holds every live file and plugin"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' online_bundle"
    display as error "  FAIL: live online bundle (rc `bundle_rc')"
}

**# 4. os() keeps each platform family of the live traj descriptor

local ++test_count
local t4 "`work'/t04"
capture noisily {
    assert `live_rc' == 0
    mkdir "`t4'"
    local g_Unix "LINUX LINUX64"
    local d_Unix "linux linux64"
    local g_MacOSX "MAC MACINTEL MACINTEL64 MACARM64"
    local d_MacOSX "mac"
    local g_Windows "WIN WIN64A"
    local d_Windows "win win64a"
    foreach mode in online local {
        foreach os in Unix MacOSX Windows {
            quietly cd "`t4'"
            mkdir "`mode'_`os'"
            quietly cd "`mode'_`os'"
            pkgtransfer, download(`mode') limited(traj) os(`os')
            mkdir "x"
            quietly cd "x"
            unzipfile "../pkgtransfer_files.zip", replace
            local n_g : word count `g_`os''
            _net_count_lines using "pkgtransfer_files/traj.pkg", ///
                text("g ") prefix
            assert r(n) == `n_g'
            foreach platform of local g_`os' {
                _net_count_lines using "pkgtransfer_files/traj.pkg", ///
                    text("g `platform' ") prefix
                assert r(n) == 1
            }
            local present : dir "pkgtransfer_files/plug-ins" dirs "*"
            local n_dirs : word count `d_`os''
            assert `: word count `present'' == `n_dirs'
            foreach dir of local d_`os' {
                confirm file "pkgtransfer_files/plug-ins/`dir'/traj.plugin"
            }
        }
    }
}
local test_rc = _rc
quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t4'")
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: os() filters live traj records in both modes"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' live_os_filter"
    display as error "  FAIL: live os() filtering (rc `test_rc')"
}

**# 5. The relocated bundle installs and runs on a clean target

local ++test_count
local t5 "`work'/t05"
local target_rc 1
capture noisily {
    assert `bundle_rc' == 0
    mkdir "`t5'"
    copy "`t'/all.do" "`t5'/all.do"
    copy "`t'/all.zip" "`t5'/all.zip"
    sysdir set PLUS "`tplus'"
    quietly cd "`t5'"
    do all.do
    foreach pkg in fre gtools traj datefix {
        _net_count_lines using "`tplus'/stata.trk", text("N `pkg'.pkg")
        assert r(n) == 1
    }
    checksum "`tplus'/t/traj.plugin"
    assert r(checksum) == `bundled_sum'

    * Installed plugins load and compute
    sysuse auto, clear
    gcollapse (mean) gprice = price, by(foreign)
    sort foreign
    tempfile gc
    quietly save "`gc'"
    sysuse auto, clear
    collapse (mean) gprice = price, by(foreign)
    sort foreign
    unab collapse_vars : _all
    quietly describe using "`gc'", varlist
    assert "`collapse_vars'" == "`r(varlist)'"
    cf _all using "`gc'"

    clear
    set seed 20261012
    quietly set obs 200
    gen long id = _n
    gen byte grp = _n > 100
    forvalues j = 1/5 {
        gen t`j' = `j'
        gen y`j' = cond(grp, 2 + 1.5 * `j', 1) + rnormal()
    }
    traj, var(y1-y5) indep(t1-t5) model(cnorm) min(-10) max(20) order(1 1)
    confirm matrix e(b)
    capture which datefix
    assert _rc == 0
    capture which fre
    assert _rc == 0
}
local target_rc = _rc
sysdir set PLUS "`qa_plus'"
quietly cd "`orig_dir'"
clear
if `target_rc' == 0 {
    local ++pass_count
    display as result "  PASS: clean target installs the bundle; plugins compute"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' target_install"
    display as error "  FAIL: target install from live bundle (rc `target_rc')"
}

**# 6. restore points the target back at each live source

local ++test_count
capture noisily {
    assert `target_rc' == 0
    sysdir set PLUS "`tplus'"
    pkgtransfer, restore
    assert "`r(download_mode)'" == "restore"
    confirm file "`tplus'/stata.trk.backup"
    _net_count_lines using "`tplus'/stata.trk", ///
        text("d pkgtransfer-source ") prefix
    assert r(n) == 0
    foreach pkg in fre gtools traj datefix {
        _net_source_of using "`qa_plus'/stata.trk", pkg(`pkg')
        local src `"`r(source)'"'
        _net_source_of using "`tplus'/stata.trk", pkg(`pkg')
        assert `"`r(source)'"' == `"`src'"'
        assert `"`src'"' != ""
    }
    * The restored source answers a live update query
    ado update traj, update
}
local test_rc = _rc
sysdir set PLUS "`qa_plus'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: restore returns every package to its live source"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' live_restore"
    display as error "  FAIL: live restore (rc `test_rc')"
}

**# Cleanup and result

quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`work'")
capture mkdir "`work'"
capture quietly _pkgtransfer_cleanup_staging, directory("`qa_plus'")
capture mkdir "`qa_plus'"
capture quietly _pkgtransfer_cleanup_staging, directory("`tplus'")
_pkgtransfer_qa_cleanup, root("`qa_root'") ///
    originalplus("`qa_original_plus'") ///
    originalpersonal("`qa_original_personal'")

if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    display as error ///
        "RESULT: test_pkgtransfer_network tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
    exit 1
}
display as result ///
    "RESULT: test_pkgtransfer_network tests=`test_count' pass=`pass_count' fail=0 skip=0"
