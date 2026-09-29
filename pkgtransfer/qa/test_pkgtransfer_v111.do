/*
    File: test_pkgtransfer_v111.do
    Purpose: Pin the September 2026 review findings to payload and lifecycle oracles
    Author: Timothy P Copeland, Karolinska Institutet
    Date: 2026-09-29
*/
version 16.0
capture log close _all
local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
run "`qa_dir'/_pkgtransfer_qa_common.do"
_pkgtransfer_qa_setup, pkgdir("`pkg_dir'")
local root "`r(root)'"
local work "`r(work)'"
local plus "`r(plus)'"
local original_plus "`r(original_plus)'"
local original_personal "`r(original_personal)'"
capture program drop pkgtransfer
run "`pkg_dir'/pkgtransfer.ado"
local tests 0
local pass 0
local fail 0

capture program drop _pkgtransfer_v111_fixture
program define _pkgtransfer_v111_fixture, rclass
    version 16.0
    syntax, WORK(string) PLUS(string) [ORDinary METAdata TOKEN]
    capture ado uninstall alpha
    capture ado uninstall beta
    foreach folder in a b s m {
        capture local oldfiles : dir "`plus'/`folder'" files "*"
        foreach oldfile of local oldfiles {
            capture erase "`plus'/`folder'/`oldfile'"
        }
    }
    capture erase "`plus'/stata.trk"
    tempname fh
    foreach pkg in alpha beta {
        capture mkdir "`work'/`pkg'"
        file open `fh' using "`work'/`pkg'/stata.toc", write text replace
        file write `fh' "v 3" _n "p `pkg'" _n
        file close `fh'
        file open `fh' using "`work'/`pkg'/`pkg'.pkg", write text replace
        file write `fh' "v 3" _n "d `pkg' fixture" _n
        if "`ordinary'" != "" {
            file write `fh' "f shared.ado" _n
        }
        else if "`metadata'" != "" {
            file write `fh' "g LINUX64 stata.toc alpha.plugin" _n
        }
        else if "`token'" != "" {
            file write `fh' "g LINUX64 unix.bin mygtools.plugin" _n
            file write `fh' "g WIN64 win.bin mygtools.plugin" _n
        }
        else {
            file write `fh' "g LINUX64 shared.bin `pkg'.plugin" _n
        }
        file write `fh' "e" _n
        file close `fh'
        foreach payload in shared.bin shared.ado unix.bin win.bin beta.pkg {
            if "`payload'" == "beta.pkg" & "`pkg'" == "beta" continue
            file open `fh' using "`work'/`pkg'/`payload'", write text replace
            file write `fh' "`pkg' `payload' BYTES" _n
            file close `fh'
        }
    }
    net install alpha, from("`work'/alpha") replace
    if "`token'" == "" & "`metadata'" == "" ///
        net install beta, from("`work'/beta") replace
end

capture program drop _pkgtransfer_v111_line
program define _pkgtransfer_v111_line, rclass
    version 16.0
    syntax using/
    tempname fh
    file open `fh' using "`using'", read text
    file read `fh' line
    file close `fh'
    return local line `"`macval(line)'"'
end

capture program drop _qa_sthlp_render
program define _qa_sthlp_render, rclass
    version 16.0
    syntax anything(name=files id="help files")

    * Tolerate a quoted list. `anything' keeps the surrounding quotes, so a
    * quoted call collapses the whole space-separated list into one filename;
    * the program then reports "file not found" and fails closed. Failing
    * closed is right, but it means the render never ran.
    local files = subinstr(`"`files'"', char(34), "", .)

    local nbad 0
    local badfiles ""

    foreach f of local files {
        capture confirm file "`f'"
        if _rc {
            display as error "  render: file not found: `f'"
            local ++nbad
            local badfiles "`badfiles' `f'"
            continue
        }

        tempfile rlog
        * Pause the enclosing QA log, render into a private named log, resume.
        capture log off
        log using "`rlog'", replace text name(_qarender)
        type "`f'", smcl
        log close _qarender
        capture log on

        local hits 0
        local nlines 0
        tempname fh
        file open `fh' using "`rlog'", read text
        file read `fh' line
        while r(eof) == 0 {
            local ++nlines
            if regexm(`"`line'"', "\{(pstd|phang|pmore|pin|p_end|psee|synopt|p2col|cmd:|it:|bf:|opt |opth |helpb |hline|title:|marker |dlgtab:|break)") {
                * Park the braces on control chars first: the SMCL escapes
                * {c -(} and {c )-} themselves contain braces, so substituting
                * them in place corrupts each other. Without this, `display`
                * renders the markup away and the log shows a line that looks
                * perfectly fine -- hiding the very defect being reported.
                local shown = subinstr(`"`line'"',  "{",     char(1), .)
                local shown = subinstr(`"`shown'"', "}",     char(2), .)
                local shown = subinstr(`"`shown'"', char(1), "{c -(}", .)
                local shown = subinstr(`"`shown'"', char(2), "{c )-}", .)
                display as error "  literal SMCL: `shown'"
                local ++hits
            }
            file read `fh' line
        }
        file close `fh'

        * An oracle that did not run must never read as clean.
        if `nlines' == 0 {
            display as error "  render produced no output for `f' -- FAILING"
            local ++nbad
            local badfiles "`badfiles' `f'"
            continue
        }
        if `hits' > 0 {
            local ++nbad
            local badfiles "`badfiles' `f'"
        }
    }

    return scalar nbad = `nbad'
    return local badfiles "`badfiles'"
end

**## online plugin collision
local ++tests
capture noisily {
    clear
    set obs 2

    _pkgtransfer_v111_fixture, work("`work'") plus("`plus'")
    _pkgtransfer_v111_line using "`plus'/a/alpha.plugin"
    assert r(line) == "alpha shared.bin BYTES"
    _pkgtransfer_v111_line using "`plus'/b/beta.plugin"
    assert r(line) == "beta shared.bin BYTES"
    cd "`work'"
    capture noisily pkgtransfer, download(online) limited(alpha beta)
    local rc = _rc
    assert `rc' == 459
    capture confirm file pkgtransfer_files.zip
    assert _rc == 601
    capture mkdir pkgtransfer_files
    assert _rc == 0
    rmdir pkgtransfer_files
}
local rc = _rc
if `rc' == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: online plugin collision rc=`rc'"
}
capture cd "`work'"
capture _pkgtransfer_cleanup_staging, directory("pkgtransfer_files")
foreach f in pkgtransfer.do pkgtransfer_files.zip outside.do outside.zip state.do {
    capture erase "`f'"
}

**## local plugin collision
local ++tests
capture noisily {
    clear
    set obs 2

    _pkgtransfer_v111_fixture, work("`work'") plus("`plus'")
    _pkgtransfer_v111_line using "`plus'/a/alpha.plugin"
    assert r(line) == "alpha shared.bin BYTES"
    _pkgtransfer_v111_line using "`plus'/b/beta.plugin"
    assert r(line) == "beta shared.bin BYTES"
    cd "`work'"
    capture noisily pkgtransfer, download(local) limited(alpha beta)
    local rc = _rc
    assert `rc' == 459
    capture confirm file pkgtransfer_files.zip
    assert _rc == 601
    capture mkdir pkgtransfer_files
    assert _rc == 0
    rmdir pkgtransfer_files
}
local rc = _rc
if `rc' == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: local plugin collision rc=`rc'"
}
capture cd "`work'"
capture _pkgtransfer_cleanup_staging, directory("pkgtransfer_files")
foreach f in pkgtransfer.do pkgtransfer_files.zip outside.do outside.zip state.do {
    capture erase "`f'"
}

**## ordinary collision
local ++tests
capture noisily {
    clear
    set obs 2

    _pkgtransfer_v111_fixture, work("`work'") plus("`plus'") ordinary
    cd "`work'"
    foreach mode in local online {
        capture noisily pkgtransfer, download(`mode') limited(alpha beta)
        local rc = _rc
        assert `rc' == 459
        capture confirm file pkgtransfer_files.zip
        assert _rc == 601
    }
}
local rc = _rc
if `rc' == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: ordinary collision rc=`rc'"
}
capture cd "`work'"
capture _pkgtransfer_cleanup_staging, directory("pkgtransfer_files")
foreach f in pkgtransfer.do pkgtransfer_files.zip outside.do outside.zip state.do {
    capture erase "`f'"
}

**## metadata collision
local ++tests
capture noisily {
    clear
    set obs 2

    _pkgtransfer_v111_fixture, work("`work'") plus("`plus'") metadata
    cd "`work'"
    foreach mode in local online {
        capture noisily pkgtransfer, download(`mode') limited(alpha)
        local rc = _rc
        assert `rc' == 459
        capture confirm file pkgtransfer_files.zip
        assert _rc == 601
    }
}
local rc = _rc
if `rc' == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: metadata collision rc=`rc'"
}
capture cd "`work'"
capture _pkgtransfer_cleanup_staging, directory("pkgtransfer_files")
foreach f in pkgtransfer.do pkgtransfer_files.zip outside.do outside.zip state.do {
    capture erase "`f'"
}

**## gtools substring Windows
local ++tests
capture noisily {
    clear
    set obs 2

    _pkgtransfer_v111_fixture, work("`work'") plus("`plus'") token
    cd "`work'"
    pkgtransfer, download(local) limited(alpha) os(Windows)
    assert r(N_packages) == 1
    assert r(package_list) == "alpha"
    confirm file "`r(dofile)'"
    confirm file "`r(zipfile)'"
    unzipfile pkgtransfer_files.zip, replace
    _pkgtransfer_v111_line using "pkgtransfer_files/win.bin"
    assert r(line) == "alpha win.bin BYTES"
    capture confirm file "pkgtransfer_files/unix.bin"
    assert _rc == 601
    tempname fh
    file open `fh' using "pkgtransfer_files/alpha.pkg", read text
    file read `fh' line
    local g 0
    local stale 0
    while r(eof) == 0 {
        if substr(`"`line'"',1,2) == "g " local ++g
        if `"`line'"' == "f mygtools.plugin" local ++stale
        file read `fh' line
    }
    file close `fh'
    assert `g' == 1
    assert `stale' == 0
}
local rc = _rc
if `rc' == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: gtools substring Windows rc=`rc'"
}
capture cd "`work'"
capture _pkgtransfer_cleanup_staging, directory("pkgtransfer_files")
foreach f in pkgtransfer.do pkgtransfer_files.zip outside.do outside.zip state.do {
    capture erase "`f'"
}

**## gtools substring all
local ++tests
capture noisily {
    clear
    set obs 2

    _pkgtransfer_v111_fixture, work("`work'") plus("`plus'") token
    cd "`work'"
    pkgtransfer, download(local) limited(alpha) 
    assert r(N_packages) == 1
    assert r(package_list) == "alpha"
    confirm file "`r(dofile)'"
    confirm file "`r(zipfile)'"
    unzipfile pkgtransfer_files.zip, replace
    _pkgtransfer_v111_line using "pkgtransfer_files/win.bin"
    assert r(line) == "alpha win.bin BYTES"
    _pkgtransfer_v111_line using "pkgtransfer_files/unix.bin"
    assert r(line) == "alpha unix.bin BYTES"
    tempname fh
    file open `fh' using "pkgtransfer_files/alpha.pkg", read text
    file read `fh' line
    local g 0
    local stale 0
    while r(eof) == 0 {
        if substr(`"`line'"',1,2) == "g " local ++g
        if `"`line'"' == "f mygtools.plugin" local ++stale
        file read `fh' line
    }
    file close `fh'
    assert `g' == 2
    assert `stale' == 0
}
local rc = _rc
if `rc' == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: gtools substring all rc=`rc'"
}
capture cd "`work'"
capture _pkgtransfer_cleanup_staging, directory("pkgtransfer_files")
foreach f in pkgtransfer.do pkgtransfer_files.zip outside.do outside.zip state.do {
    capture erase "`f'"
}

**## output paths
local ++tests
capture noisily {
    clear
    set obs 2

    _pkgtransfer_v111_fixture, work("`work'") plus("`plus'")
    cd "`work'"
    foreach mode in local online {
        foreach path in "pkgtransfer_files/install.do" "./pkgtransfer_files/install.do" "`work'/pkgtransfer_files/install.do" "dummy/../pkgtransfer_files/install.do" {
            capture noisily pkgtransfer, download(`mode') limited(alpha) dofile("`path'")
            local rc = _rc
            assert `rc' == 198
            capture mkdir pkgtransfer_files
            assert _rc == 0
            rmdir pkgtransfer_files
        }
        capture noisily pkgtransfer, download(`mode') limited(alpha) zipfile("./pkgtransfer_files/out.zip")
        local rc = _rc
        assert `rc' == 198
    }
    pkgtransfer, download(online) limited(alpha) dofile("outside.do") zipfile("outside.zip")
    assert r(dofile) == "outside.do"
    assert r(zipfile) == "outside.zip"
    confirm file "`r(dofile)'"
    confirm file "`r(zipfile)'"
}
local rc = _rc
if `rc' == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: output paths rc=`rc'"
}
capture cd "`work'"
capture _pkgtransfer_cleanup_staging, directory("pkgtransfer_files")
foreach f in pkgtransfer.do pkgtransfer_files.zip outside.do outside.zip state.do {
    capture erase "`f'"
}

**## github bootstrap
local ++tests
capture noisily {
    clear
    set obs 2

    tempname fh
    file open `fh' using "`plus'/stata.trk", write text replace
    file write `fh' "S https://haghish.github.io/github/" _n "N github.pkg" _n "e" _n
    file close `fh'
    cd "`work'"
    pkgtransfer, limited(github)
    _pkgtransfer_v111_line using pkgtransfer.do
    assert strtrim(r(line)) == `"net install github, replace from("https://raw.githubusercontent.com/haghish/github/master/")"'
}
local rc = _rc
if `rc' == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: github bootstrap rc=`rc'"
}
capture cd "`work'"
capture _pkgtransfer_cleanup_staging, directory("pkgtransfer_files")
foreach f in pkgtransfer.do pkgtransfer_files.zip outside.do outside.zip state.do {
    capture erase "`f'"
}

**## caller state
local ++tests
capture noisily {
    clear
    set obs 2

    _pkgtransfer_v111_fixture, work("`work'") plus("`plus'")
    cd "`work'"
    do "`qa_dir'/_qa_state.do"
    sysuse auto, clear
    regress price mpg
    matrix pkgtransfer_user = (1,2)
    qa_state_snapshot, tag(success)
    pkgtransfer, limited(alpha) dofile(state.do)
    qa_state_compare, tag(success) allow(r file)
    qa_state_snapshot, tag(error)
    capture pkgtransfer, download(invalid)
    assert _rc == 198
    qa_state_compare, tag(error) allow(r)
}
local rc = _rc
if `rc' == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: caller state rc=`rc'"
}
capture cd "`work'"
capture _pkgtransfer_cleanup_staging, directory("pkgtransfer_files")
foreach f in pkgtransfer.do pkgtransfer_files.zip outside.do outside.zip state.do {
    capture erase "`f'"
}

**## lifecycle
local ++tests
capture noisily {
    clear
    set obs 2

    _pkgtransfer_v111_fixture, work("`work'") plus("`plus'") token
    cd "`work'"
    do "`qa_dir'/_qa_lifecycle.do"
    sysuse auto, clear
    qa_lifecycle, fita(regress price mpg) fitb(regress price mpg length) ///
        post(pkgtransfer, limited(alpha) dofile(lifecycle.do))
    _pkgtransfer_v111_line using lifecycle.do
    assert strtrim(r(line)) == `"net install alpha, replace from("`work'/alpha/")"'
}
local rc = _rc
capture log close parity
capture _pkgtransfer_cleanup_staging, directory("pkgtransfer_files")
foreach artifact in pkgtransfer.do pkgtransfer_files.zip lifecycle.do {
    capture erase "`artifact'"
}
if `rc' == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: lifecycle rc=`rc'"
}

**## surface parity
local ++tests
capture noisily {
    clear
    set obs 2

    _pkgtransfer_v111_fixture, work("`work'") plus("`plus'") token
    cd "`work'"
    do "`qa_dir'/_qa_parity.do"
    tempfile console
    log using "`console'", name(parity) text replace
    pkgtransfer, download(online) limited(alpha)
    tempname n
    scalar `n' = r(N_packages)
    assert r(package_list) == "alpha"
    log close parity
    qa_surface_parity, expect(1) result(scalar(`n')) ///
        log("`console'") logregex("Starting download of ([0-9]+) packages")
}
local rc = _rc
capture log close parity
capture _pkgtransfer_cleanup_staging, directory("pkgtransfer_files")
foreach artifact in pkgtransfer.do pkgtransfer_files.zip lifecycle.do {
    capture erase "`artifact'"
}
if `rc' == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: surface parity rc=`rc'"
}

**## hostile string options
local ++tests
capture noisily {
    clear
    set obs 2

    _pkgtransfer_v111_fixture, work("`work'") plus("`plus'") token
    cd "`work'"
    do "`qa_dir'/_qa_hostile.do"
    qa_hostile_strings
    local corpus "`r(names)'"
    local cells 0
    foreach option in download os dofile zipfile limited skip {
        foreach g of local corpus {
            clear
            set obs 2
            gen double caller = _n
            local text : copy global `g'
            local vao = c(varabbrev)
            local selector ""
            if "`option'" == "skip" local selector "limited(alpha)"
            capture pkgtransfer, `option'(`"`macval(text)'"') `selector' 
            local command_rc = _rc
            display as text "Hostile cell: `option' `g' rc=`command_rc'"
            if "`option'" == "limited" assert inlist(`command_rc',111,132,198)
            else if "`option'" == "skip" {
                assert inlist(`command_rc',0,132,198)
                if `command_rc' == 0 {
                    assert r(N_packages) == 1
                    assert r(package_list) == "alpha"
                    confirm file "`r(dofile)'"
                }
            }
            else assert inlist(`command_rc',132,198)
            assert c(varabbrev) == "`vao'"
            assert _N == 2
            assert caller == _n
            local ++cells
        }
    }
    assert `cells' == 54
    display as text "Hostile string receipt: 6 options x 9 strings = `cells' cells"
    macro drop QA_HS_GLB QA_HS_TICKPAIR QA_HS_TICK QA_HS_DOLLAR QA_HS_APOS QA_HS_DQ QA_HS_BSLASH QA_HS_COMMA QA_HS_LEAD QA_HS_UNICODE
}
local rc = _rc
capture log close parity
capture _pkgtransfer_cleanup_staging, directory("pkgtransfer_files")
foreach artifact in pkgtransfer.do pkgtransfer_files.zip lifecycle.do {
    capture erase "`artifact'"
}
if `rc' == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: hostile string options rc=`rc'"
}

**## Rendered help with a broken-markup positive control
local ++tests
capture noisily {
    clear
    set obs 1
    _qa_sthlp_render "`pkg_dir'/pkgtransfer.sthlp"
    assert r(nbad) == 0
    tempname fh
    file open `fh' using "`work'/broken.sthlp", write text replace
    file write `fh' "{pstd}A {it:broken" _n "directive} remains visible.{p_end}" _n
    file close `fh'
    _qa_sthlp_render "`work'/broken.sthlp"
    assert r(nbad) == 1
}
local rc = _rc
capture erase "`work'/broken.sthlp"
if `rc' == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: rendered help rc=`rc'"
}

cd "`qa_dir'"
local ++tests
capture noisily _pkgtransfer_qa_cleanup, root("`root'") originalplus("`original_plus'") originalpersonal("`original_personal'")
local cleanup_rc = _rc
if `cleanup_rc' == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: fixture cleanup rc=`cleanup_rc'"
}
capture log close _all
display "RESULT: test_pkgtransfer_v111 tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' exit 1
