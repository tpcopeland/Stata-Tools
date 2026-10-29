/*
    File:    test_documentation_examples.do
    Purpose: Every Example in pkgtransfer.sthlp, run as written by an
             installed user, with its result checked by executing what it
             produced: each generated installer is run into a fresh PLUS and
             the packages that land there are compared with the source
             machine; bundle contents are checked for the os() filter; restore
             must give back the source machine's own tracker sources.
    Fixture: estout, outreg2, gtools (one .plugin with LINUX64, WIN64 and
             MACARM64 variants) and pkgtransfer itself are served by
             python3 -m http.server on 127.0.0.1 and installed with net install,
             so stata.trk is a real tracker with URL sources. Loopback only:
             no internet access. Unix shell (Linux/macOS). A server that does
             not start is a failure, never a skip. The README examples run in
             test_pkgtransfer_readme_sequence.do.
    Author:  Timothy P Copeland, Karolinska Institutet
    Date:    2026-10-28
*/

version 16.0
capture log close _all
set linesize 255
set varabbrev off

**# Setup

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa/?$", "")
local orig_dir "`c(pwd)'"
local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"

* Earlier suites in the lane put the source directory first on the adopath
* (adopath ++ pkg_dir). The examples must run the copy net install puts in
* PLUS, so take the source directory off for this suite and put it back at
* the end exactly as found.
local had_pkg_path 0
local drop_rc 0
while `drop_rc' == 0 {
    capture adopath - "`pkg_dir'"
    local drop_rc = _rc
    if `drop_rc' == 0 local had_pkg_path 1
}

tempfile marker
local root "`marker'_ptdoc"
local src "`root'/src"
local plusA "`root'/plusA"
local work "`root'/work"
* Setup runs captured: a failure here is reported by test 0 and the sysdirs
* and cwd are still restored at the end, rather than aborting the suite with
* PERSONAL repointed for every later suite in the lane.
local setup_rc 0
capture noisily {
    foreach d in "`root'" "`src'" "`plusA'" "`root'/personal" "`work'" {
        mkdir "`d'"
    }
    sysdir set PERSONAL "`root'/personal"
}
if _rc local setup_rc = _rc

* Reads one tracker: the ordered list of package names and each one's source.
capture program drop _ptd_trk
program define _ptd_trk, rclass
    version 16.0
    syntax, PLUS(string)
    tempname fh
    local names ""
    local cur_s ""
    file open `fh' using "`plus'/stata.trk", read text
    file read `fh' line
    while r(eof) == 0 {
        if substr(`"`line'"', 1, 2) == "S " local cur_s = substr(`"`line'"', 3, .)
        if substr(`"`line'"', 1, 2) == "N " {
            local n = subinstr(substr(`"`line'"', 3, .), ".pkg", "", 1)
            local names "`names' `n'"
            return local S_`n' `"`cur_s'"'
        }
        file read `fh' line
    }
    file close `fh'
    local names : list sort names
    return local names "`names'"
end

* First line of a text file.
capture program drop _ptd_first
program define _ptd_first, rclass
    version 16.0
    syntax, FILE(string)
    tempname fh
    file open `fh' using `"`file'"', read text
    file read `fh' line
    file close `fh'
    return local line `"`line'"'
end

* Runs a generated installer from its own directory into a fresh PLUS.
capture program drop _ptd_install
program define _ptd_install
    version 16.0
    syntax, DOfile(string) TARGET(string) DIR(string)
    mkdir "`target'"
    sysdir set PLUS "`target'"
    discard
    quietly cd "`dir'"
    do "`dofile'"
    quietly cd "`dir'"
end

* The files an offline bundle carries.
capture program drop _ptd_zipfiles
program define _ptd_zipfiles, rclass
    version 16.0
    syntax, ZIP(string) DIR(string)
    mkdir "`dir'"
    quietly cd "`dir'"
    unzipfile `"`zip'"'
    local files : dir "pkgtransfer_files" files "*", respectcase
    return local files `"`files'"'
end

**# Fixture: package sources served on loopback, installed into plusA

tempname fh
local port 0
local server_up 0
local pidfile "`root'/http.pid"
capture noisily {
    if `setup_rc' exit `setup_rc'
    foreach p in estout outreg2 gtools {
        mkdir "`src'/`p'"
        file open `fh' using "`src'/`p'/`p'.ado", write text replace
        file write `fh' "program define `p'" _n `"    display "`p' ok""' _n "end" _n
        file close `fh'
        file open `fh' using "`src'/`p'/`p'.pkg", write text replace
        file write `fh' "v 3" _n "d `p' fixture" _n "f `p'.ado" _n
        if "`p'" == "gtools" {
            foreach pl in LINUX64 WIN64 MACARM64 {
                local l = lower("`pl'")
                file write `fh' "g `pl' gtools_`l'.plugin gtools.plugin" _n
            }
        }
        file write `fh' "e" _n
        file close `fh'
        file open `fh' using "`src'/`p'/stata.toc", write text replace
        file write `fh' "v 3" _n "p `p'" _n
        file close `fh'
    }
    foreach pl in LINUX64 WIN64 MACARM64 {
        local l = lower("`pl'")
        file open `fh' using "`src'/gtools/gtools_`l'.plugin", write text replace
        file write `fh' "plugin bytes `pl'" _n
        file close `fh'
    }
    mkdir "`src'/pkgtransfer"
    foreach f in pkgtransfer.ado pkgtransfer.sthlp pkgtransfer.pkg stata.toc {
        copy "`pkg_dir'/`f'" "`src'/pkgtransfer/`f'"
    }

    file open `fh' using "`src'/ptdoc_nonce.txt", write text replace
    file write `fh' "`marker'" _n
    file close `fh'

    local base = 20000 + mod(floor(clock("`c(current_time)'", "hms") / 1000), 20000)
    forvalues try = 0/4 {
        local port = `base' + 97 * `try'
        shell cd "`src'" && (python3 -m http.server `port' --bind 127.0.0.1 > /dev/null 2>&1 & echo $! > "`pidfile'")
        forvalues attempt = 1/20 {
            * The nonce is this run's own tempfile path: a server some other run
            * left on the port serves its own nonce (or a 404), never ours.
            capture copy "http://127.0.0.1:`port'/ptdoc_nonce.txt" "`root'/probe.txt", replace
            if _rc == 0 {
                _ptd_first, file("`root'/probe.txt")
                if `"`r(line)'"' == "`marker'" {
                    local server_up 1
                    continue, break
                }
            }
            sleep 250
        }
        if `server_up' continue, break
        capture shell kill $(cat "`pidfile'")
    }
}
if _rc & !`setup_rc' local setup_rc = _rc
local url "http://127.0.0.1:`port'"

* The g-record variant net install picks on this host (the suite needs a Unix
* shell, so Linux or Apple-silicon macOS).
* An Intel Mac (MACINTEL64) is not in the fixture and fails test 0.
local this_plat = cond("`c(os)'" == "MacOSX", "MACARM64", "LINUX64")

* The help file's Examples, verbatim. Each block below runs its example from
* these locals, and test 11 requires the list to equal the {cmd:. ...} lines of
* the shipped pkgtransfer.sthlp -- so what runs is what the help shows.
local ex1 "pkgtransfer"
local ex2 "pkgtransfer, download(online)"
local ex3 "pkgtransfer, download(local)"
local ex4 "pkgtransfer, download(local) os(Unix)"
local ex5 "pkgtransfer, limited(estout outreg2)"
local ex6 "pkgtransfer, download(online) limited(estout outreg2)"
local ex7 "pkgtransfer, skip(gtools)"
local ex8 "pkgtransfer, download(online) dofile(my_install.do) zipfile(my_packages.zip)"
local ex9 "pkgtransfer, dofile(my_install.do) replace"
local ex10 "pkgtransfer, restore"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# 0. Fixture: a real tracker with URL sources, and the installed command
local ++test_count
capture noisily {
    assert `setup_rc' == 0
    assert `server_up' == 1
    sysdir set PLUS "`plusA'"
    foreach p in estout outreg2 gtools pkgtransfer {
        net install `p', from("`url'/`p'")
    }
    _ptd_trk, plus("`plusA'")
    assert "`r(names)'" == "estout gtools outreg2 pkgtransfer"
    assert inlist(`"`r(S_estout)'"', "`url'/estout", "`url'/estout/")
    discard
    quietly findfile pkgtransfer.ado
    assert strpos(`"`r(fn)'"', "`plusA'") == 1
    _ptd_first, file("`plusA'/g/gtools.plugin")
    assert `"`r(line)'"' == "plugin bytes `this_plat'"
}
local fixture_rc = _rc
if `fixture_rc' == 0 {
    display as result "  PASS: 0 loopback sources installed; pkgtransfer resolves from PLUS"
    local ++pass_count
}
else {
    display as error "  FAIL: 0 fixture (setup_rc=`setup_rc', server_up=`server_up', rc=`fixture_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 0"
}

**# 1. pkgtransfer: online reinstall do-file for every tracked package
local ++test_count
capture noisily {
    assert `fixture_rc' == 0
    sysdir set PLUS "`plusA'"
    discard
    mkdir "`work'/e1"
    quietly cd "`work'/e1"
    `ex1'
    assert r(N_packages) == 4
    assert "`r(download_mode)'" == "script_only"
    assert "`r(dofile)'" == "pkgtransfer.do"
    assert "`r(package_list)'" == "estout gtools outreg2 pkgtransfer"
    local made : dir . files "*", respectcase
    assert `"`made'"' == `""pkgtransfer.do""'
    _ptd_install, dofile("pkgtransfer.do") target("`root'/t1") dir("`work'/e1")
    _ptd_trk, plus("`root'/t1")
    assert "`r(names)'" == "estout gtools outreg2 pkgtransfer"
    foreach p in estout gtools outreg2 pkgtransfer {
        assert inlist(`"`r(S_`p')'"', "`url'/`p'", "`url'/`p'/")
    }
    _ptd_first, file("`root'/t1/g/gtools.plugin")
    assert `"`r(line)'"' == "plugin bytes `this_plat'"
}
if _rc == 0 {
    display as result "  PASS: 1 the reinstall do-file rebuilds all four packages on a clean PLUS"
    local ++pass_count
}
else {
    display as error "  FAIL: 1 pkgtransfer (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**# 2. download(online): offline bundle downloaded from the sources
local ++test_count
capture noisily {
    assert `fixture_rc' == 0
    sysdir set PLUS "`plusA'"
    discard
    mkdir "`work'/e2"
    quietly cd "`work'/e2"
    `ex2'
    assert r(N_packages) == 4
    assert "`r(download_mode)'" == "online"
    assert "`r(zipfile)'" == "pkgtransfer_files.zip"
    confirm file "pkgtransfer.do"
    confirm file "pkgtransfer_files.zip"
    _ptd_install, dofile("pkgtransfer.do") target("`root'/t2") dir("`work'/e2")
    _ptd_trk, plus("`root'/t2")
    assert "`r(names)'" == "estout gtools outreg2 pkgtransfer"
    * Installed from the unpacked bundle, not from the server.
    assert strpos(`"`r(S_estout)'"', "http") == 0
    _ptd_first, file("`root'/t2/e/estout.ado")
    assert `"`r(line)'"' == "program define estout"
    _ptd_first, file("`root'/t2/g/gtools.plugin")
    assert `"`r(line)'"' == "plugin bytes `this_plat'"
}
local e2_rc = _rc
if `e2_rc' == 0 {
    display as result "  PASS: 2 download(online) bundle installs all four packages offline"
    local ++pass_count
}
else {
    display as error "  FAIL: 2 download(online) (rc=`e2_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**# 3. download(local): bundle from PLUS with every OS plugin variant
local ++test_count
capture noisily {
    assert `fixture_rc' == 0
    sysdir set PLUS "`plusA'"
    discard
    mkdir "`work'/e3"
    quietly cd "`work'/e3"
    `ex3'
    assert r(N_packages) == 4
    assert "`r(download_mode)'" == "local"
    _ptd_zipfiles, zip("`work'/e3/pkgtransfer_files.zip") dir("`work'/e3/chk")
    local files `"`r(files)'"'
    foreach f in estout.ado outreg2.ado gtools.ado pkgtransfer.ado pkgtransfer.sthlp ///
            gtools_linux64.plugin gtools_win64.plugin gtools_macarm64.plugin {
        assert `: list f in files'
    }
    _ptd_install, dofile("pkgtransfer.do") target("`root'/t3") dir("`work'/e3")
    _ptd_trk, plus("`root'/t3")
    assert "`r(names)'" == "estout gtools outreg2 pkgtransfer"
    _ptd_first, file("`root'/t3/g/gtools.plugin")
    assert `"`r(line)'"' == "plugin bytes `this_plat'"
}
if _rc == 0 {
    display as result "  PASS: 3 download(local) bundle carries all three plugin variants and installs"
    local ++pass_count
}
else {
    display as error "  FAIL: 3 download(local) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**# 4. download(local) os(Unix): Unix plugin variant only
local ++test_count
capture noisily {
    assert `fixture_rc' == 0
    sysdir set PLUS "`plusA'"
    discard
    mkdir "`work'/e4"
    quietly cd "`work'/e4"
    `ex4'
    assert "`r(os)'" == "Unix"
    assert r(N_packages) == 4
    _ptd_zipfiles, zip("`work'/e4/pkgtransfer_files.zip") dir("`work'/e4/chk")
    local files `"`r(files)'"'
    local want "gtools_linux64.plugin"
    assert `: list want in files'
    foreach f in gtools_win64.plugin gtools_macarm64.plugin {
        assert !`: list f in files'
    }
    foreach f in estout.ado outreg2.ado gtools.ado pkgtransfer.ado pkgtransfer.sthlp {
        assert `: list f in files'
    }
    * On a Linux host the Unix-only bundle installs and its plugin computes here.
    if "`c(os)'" == "Unix" {
        _ptd_install, dofile("pkgtransfer.do") target("`root'/t4") dir("`work'/e4")
        _ptd_trk, plus("`root'/t4")
        assert "`r(names)'" == "estout gtools outreg2 pkgtransfer"
        _ptd_first, file("`root'/t4/g/gtools.plugin")
        assert `"`r(line)'"' == "plugin bytes LINUX64"
    }
}
if _rc == 0 {
    display as result "  PASS: 4 os(Unix) keeps the Linux plugin and drops Windows and macOS"
    local ++pass_count
}
else {
    display as error "  FAIL: 4 os(Unix) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**# 5. limited(estout outreg2): do-file for the named packages only
local ++test_count
capture noisily {
    assert `fixture_rc' == 0
    sysdir set PLUS "`plusA'"
    discard
    mkdir "`work'/e5"
    quietly cd "`work'/e5"
    `ex5'
    assert r(N_packages) == 2
    assert "`r(package_list)'" == "estout outreg2"
    _ptd_install, dofile("pkgtransfer.do") target("`root'/t5") dir("`work'/e5")
    _ptd_trk, plus("`root'/t5")
    assert "`r(names)'" == "estout outreg2"
}
if _rc == 0 {
    display as result "  PASS: 5 limited() installs exactly estout and outreg2"
    local ++pass_count
}
else {
    display as error "  FAIL: 5 limited() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

**# 6. download(online) limited(estout outreg2): bundle of the named packages
local ++test_count
capture noisily {
    assert `fixture_rc' == 0
    sysdir set PLUS "`plusA'"
    discard
    mkdir "`work'/e6"
    quietly cd "`work'/e6"
    `ex6'
    assert r(N_packages) == 2
    assert "`r(download_mode)'" == "online"
    _ptd_zipfiles, zip("`work'/e6/pkgtransfer_files.zip") dir("`work'/e6/chk")
    local files `"`r(files)'"'
    foreach f in gtools.ado pkgtransfer.ado {
        assert !`: list f in files'
    }
    _ptd_install, dofile("pkgtransfer.do") target("`root'/t6") dir("`work'/e6")
    _ptd_trk, plus("`root'/t6")
    assert "`r(names)'" == "estout outreg2"
}
if _rc == 0 {
    display as result "  PASS: 6 limited() bundle carries and installs only estout and outreg2"
    local ++pass_count
}
else {
    display as error "  FAIL: 6 download(online) limited() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

**# 7. skip(gtools): every package except gtools
local ++test_count
capture noisily {
    assert `fixture_rc' == 0
    sysdir set PLUS "`plusA'"
    discard
    mkdir "`work'/e7"
    quietly cd "`work'/e7"
    `ex7'
    assert r(N_packages) == 3
    assert "`r(package_list)'" == "estout outreg2 pkgtransfer"
    _ptd_install, dofile("pkgtransfer.do") target("`root'/t7") dir("`work'/e7")
    _ptd_trk, plus("`root'/t7")
    assert "`r(names)'" == "estout outreg2 pkgtransfer"
}
if _rc == 0 {
    display as result "  PASS: 7 skip(gtools) installs the other three packages"
    local ++pass_count
}
else {
    display as error "  FAIL: 7 skip() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}

**# 8. download(online) with custom do-file and ZIP names
local ++test_count
capture noisily {
    assert `fixture_rc' == 0
    sysdir set PLUS "`plusA'"
    discard
    mkdir "`work'/e8"
    quietly cd "`work'/e8"
    `ex8'
    assert "`r(dofile)'" == "my_install.do"
    assert "`r(zipfile)'" == "my_packages.zip"
    local made : dir . files "*", respectcase
    local made : list sort made
    assert `"`made'"' == `""my_install.do" "my_packages.zip""'
    _ptd_install, dofile("my_install.do") target("`root'/t8") dir("`work'/e8")
    _ptd_trk, plus("`root'/t8")
    assert "`r(names)'" == "estout gtools outreg2 pkgtransfer"
}
if _rc == 0 {
    display as result "  PASS: 8 custom names are written and the renamed installer works"
    local ++pass_count
}
else {
    display as error "  FAIL: 8 custom dofile()/zipfile() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}

**# 9. dofile(my_install.do) replace: rewrites an existing file
local ++test_count
capture noisily {
    assert `fixture_rc' == 0
    sysdir set PLUS "`plusA'"
    discard
    mkdir "`work'/e9"
    quietly cd "`work'/e9"
    file open `fh' using "my_install.do", write text replace
    file write `fh' "* stale script" _n
    file close `fh'
    capture noisily pkgtransfer, dofile(my_install.do)
    assert _rc == 602
    _ptd_first, file("my_install.do")
    assert `"`r(line)'"' == "* stale script"
    `ex9'
    assert "`r(dofile)'" == "my_install.do"
    assert r(N_packages) == 4
    _ptd_install, dofile("my_install.do") target("`root'/t9") dir("`work'/e9")
    _ptd_trk, plus("`root'/t9")
    assert "`r(names)'" == "estout gtools outreg2 pkgtransfer"
}
if _rc == 0 {
    display as result "  PASS: 9 replace rewrites the existing do-file (602 without it)"
    local ++pass_count
}
else {
    display as error "  FAIL: 9 replace (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}

**# 10. restore: online sources back in a bundle-installed tracker
local ++test_count
capture noisily {
    assert `e2_rc' == 0
    * t2 was set up from the Example 2 bundle; restore with its own copy.
    sysdir set PLUS "`root'/t2"
    discard
    quietly findfile pkgtransfer.ado
    assert strpos(`"`r(fn)'"', "`root'/t2") == 1
    _ptd_trk, plus("`root'/t2")
    assert strpos(`"`r(S_gtools)'"', "http") == 0
    quietly cd "`work'"
    `ex10'
    assert "`r(download_mode)'" == "restore"
    _ptd_trk, plus("`root'/t2")
    local after "`r(names)'"
    foreach p in estout gtools outreg2 pkgtransfer {
        local S_`p' `"`r(S_`p')'"'
    }
    _ptd_trk, plus("`plusA'")
    assert "`after'" == "`r(names)'"
    foreach p in estout gtools outreg2 pkgtransfer {
        assert `"`S_`p''"' == `"`r(S_`p')'"'
    }
}
if _rc == 0 {
    display as result "  PASS: 10 restore returns the source machine's own tracker sources"
    local ++pass_count
}
else {
    display as error "  FAIL: 10 restore (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10"
}

**# 11. The examples above are exactly the Examples in the shipped help file
* Every "{cmd:. ...}" line in pkgtransfer.sthlp is an example a user can type.
* A help-file example added, removed or edited without a matching block here
* fails this test, so "every Example" stays true as the help file changes.
local ++test_count
capture noisily {
    local run_examples ""
    forvalues k = 1/10 {
        local run_examples `"`run_examples' "`ex`k''""'
    }
    local help_examples ""
    local n_help 0
    file open `fh' using "`pkg_dir'/pkgtransfer.sthlp", read text
    file read `fh' line
    while r(eof) == 0 {
        if regexm(`"`line'"', "^\{cmd:\. (.*)\}$") {
            local ex = regexs(1)
            local help_examples `"`help_examples' "`ex'""'
            local ++n_help
        }
        file read `fh' line
    }
    file close `fh'
    display as text `"help examples (`n_help'):`help_examples'"'
    assert `n_help' == 10
    assert `: list run_examples === help_examples'
}
if _rc == 0 {
    display as result "  PASS: 11 the ten blocks above are exactly the help file's Examples"
    local ++pass_count
}
else {
    display as error "  FAIL: 11 help-file Examples differ from the commands this suite runs"
    local ++fail_count
    local failed_tests "`failed_tests' 11"
}

**# Cleanup and result

capture confirm file "`pidfile'"
if _rc == 0 & `server_up' shell kill $(cat "`pidfile'")
quietly cd "`orig_dir'"
sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
if `had_pkg_path' adopath ++ "`pkg_dir'"
discard
* The root is this run's own tempfile-derived directory.
if strpos("`root'", "`c(tmpdir)'") == 1 & strpos("`root'", "_ptdoc") > 0 {
    shell rm -rf "`root'"
}

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED:`failed_tests'"
    display "RESULT: test_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count'"
