* Regression suite: python precedence, replay format swap, run version,
* .logdocrc grammar, quiet/verbose merge, start-time overwrite check,
* tempfile hygiene, renderer lookup order, r() forwarding.
* Self-locating; every input lives under c(tmpdir).

version 16.0
clear all
set varabbrev off

local qa_dir = regexr("`c(pwd)'", "/+$", "")
local pkg_dir = regexr("`qa_dir'", "/qa/?$", "")
capture ado uninstall logdoc
quietly net install logdoc, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _cr_has
program define _cr_has, rclass
    syntax using/ , Pattern(string)
    local _crpos = strpos(fileread(`"`using'"'), `"`pattern'"')
    return scalar found = (`_crpos' > 0)
    return scalar pos = `_crpos'
end

capture program drop _cr_session_cleanup
program define _cr_session_cleanup
    capture log close _logdoc
    capture macro drop LOGDOC_ACTIVE LOGDOC_OUTPUT LOGDOC_FORMAT ///
        LOGDOC_THEME LOGDOC_TITLE LOGDOC_DATE LOGDOC_PREFORMATTED ///
        LOGDOC_NOFOLD LOGDOC_NODOTS LOGDOC_SESSION_PYTHON LOGDOC_CSS ///
        LOGDOC_OPEN LOGDOC_ACCENT LOGDOC_REPLACE LOGDOC_APPEND ///
        LOGDOC_QUIET LOGDOC_VERBOSE LOGDOC_FOOTER LOGDOC_STAMP ///
        LOGDOC_NOGRAPH LOGDOC_GRAPHWIDTH LOGDOC_GRAPHHEIGHT ///
        LOGDOC_LINENUMBERS LOGDOC_TOC LOGDOC_FOLD LOGDOC_HIGHLIGHT ///
        LOGDOC_TABLES LOGDOC_COPY LOGDOC_DOWNLOAD LOGDOC_KEEP LOGDOC_DROP ///
        LOGDOC_NOTEBOOK LOGDOC_EMAIL LOGDOC_ANNOTATE LOGDOC_LEGACY ///
        LOGDOC_GENERATED LOGDOC_ORIG_LINESIZE LOGDOC_TMPLOG LOGDOC_GRAPHBASE
end

local orig_pwd "`c(pwd)'"
tempfile _sbx_base
local sbx "`_sbx_base'_logdoc_cfgrun"
capture mkdir "`sbx'"
quietly cd "`sbx'"
capture macro drop LOGDOC_PYTHON
capture erase .logdocrc

* Shared inputs
quietly log using "`sbx'/a.smcl", smcl replace nomsg name(_cr)
display "hello alpha"
quietly log close _cr
quietly log using "`sbx'/b.smcl", smcl replace nomsg name(_cr)
display "hello beta"
quietly log close _cr
capture mkdir bd
quietly copy a.smcl bd/a.smcl, replace
quietly copy b.smcl bd/b.smcl, replace

* Marker wrapper: records each use, then delegates to a real python
* The wrapper is a /bin/sh script, so the marker tests need a POSIX shell:
* on Windows they fail loudly below instead of skipping.
local wrap "`sbx'/fakepy.sh"
file open fh using "`wrap'", write replace text
file write fh "#!/bin/sh" _n
file write fh `"echo used >> "`sbx'/marker.txt""' _n
file write fh `"exec python3 "\$@""' _n
file close fh
quietly shell chmod +x "`wrap'"
if "`c(os)'" == "Windows" {
    display as error "test_logdoc_config_run: the marker-wrapper tests need /bin/sh and are not supported on Windows; failing instead of skipping"
    local ++test_count
    local ++fail_count
}

**# I2: logdoc_py set makes logdoc use that python, not Stata python
local ++test_count
capture noisily {
    capture erase marker.txt
    capture erase .logdocrc
    quietly logdoc_py, python("`wrap'") set quiet
    assert `"`r(python_source)'"' == "option"
    assert `"$LOGDOC_PYTHON"' == "`wrap'"
    capture erase marker.txt
    quietly logdoc_py, quiet
    assert `"`r(python)'"' == "`wrap'"
    assert "`r(python_source)'" == "global"
    capture erase marker.txt
    quietly logdoc using a.smcl, output(i2a.html) replace quiet
    capture confirm file marker.txt
    assert _rc == 0
    _cr_has using i2a.html, pattern("hello alpha")
    assert r(found) == 1
    capture erase marker.txt
    quietly logdoc combine using a.smcl b.smcl, output(i2c.html) replace quiet
    capture confirm file marker.txt
    assert _rc == 0
    capture erase marker.txt
    quietly logdoc diff using a.smcl, compare(b.smcl) output(i2d.html) replace quiet
    capture confirm file marker.txt
    assert _rc == 0
    capture erase marker.txt
    local pat "bd/*.smcl"
    quietly logdoc batch, input(`pat') outdir(i2b) replace quiet
    capture confirm file marker.txt
    assert _rc == 0
    quietly logdoc using a.smcl, output(i2r.html) replace quiet
    capture erase marker.txt
    quietly logdoc replay
    capture confirm file marker.txt
    assert _rc == 0
    capture erase marker.txt
    quietly logdoc start, output(i2s.html) replace quiet
    display "session text"
    quietly logdoc stop
    capture confirm file marker.txt
    assert _rc == 0
    _cr_has using i2s.html, pattern("session text")
    assert r(found) == 1
}
local trc = _rc
if `trc' == 0 local ++pass_count
else {
    display as error "FAILED: test `test_count' (rc `trc')"
    local ++fail_count
}
_cr_session_cleanup
capture macro drop LOGDOC_PYTHON
capture erase marker.txt

**# I2: .logdocrc python= (incl. spaced grammar) outranks Stata python; global outranks config
local ++test_count
capture noisily {
    capture macro drop LOGDOC_PYTHON
    capture erase marker.txt
    file open fh using .logdocrc, write replace text
    file write fh "# comment line" _n
    file write fh "#python=/no/such/python" _n
    file write fh "" _n
    file write fh "python = `wrap'" _n
    file close fh
    quietly logdoc_py, quiet
    assert `"`r(python)'"' == "`wrap'"
    assert "`r(python_source)'" == "config"
    capture erase marker.txt
    quietly logdoc using a.smcl, output(i2e.html) replace quiet
    capture confirm file marker.txt
    assert _rc == 0
    capture erase marker.txt
    quietly logdoc diff using a.smcl, compare(b.smcl) output(i2f.html) replace quiet
    capture confirm file marker.txt
    assert _rc == 0
    * save writes a config that the next call then honors
    capture erase .logdocrc
    quietly logdoc_py, python("`wrap'") save quiet
    capture erase marker.txt
    quietly logdoc using a.smcl, output(i2g.html) replace quiet
    capture confirm file marker.txt
    assert _rc == 0
}
local trc = _rc
if `trc' == 0 local ++pass_count
else {
    display as error "FAILED: test `test_count' (rc `trc')"
    local ++fail_count
}
capture erase .logdocrc
capture erase marker.txt

**# I3: replay format() swaps the extension and never overwrites another format
local ++test_count
capture noisily {
    quietly logdoc using a.smcl, output(r.html) replace quiet
    quietly checksum r.html
    local sum_before = r(checksum)
    quietly logdoc replay, format(md)
    assert "`r(output)'" == "r.md"
    assert "`r(format)'" == "md"
    confirm file r.md
    quietly checksum r.html
    assert r(checksum) == `sum_before'
    _cr_has using r.html, pattern("<html")
    assert r(found) == 1
    _cr_has using r.md, pattern("<html")
    assert r(found) == 0
    _cr_has using r.md, pattern("hello alpha")
    assert r(found) == 1
    quietly logdoc replay, format(tex)
    assert "`r(output)'" == "r.tex"
    confirm file r.tex
    quietly logdoc replay, format(qmd)
    assert "`r(output)'" == "r.qmd"
    confirm file r.qmd
    quietly logdoc replay, format(both)
    assert "`r(output)'" == "r.html"
    assert "`r(secondary)'" == "r.md"
    quietly logdoc replay, format(docx)
    assert "`r(output)'" == "r.docx"
    confirm file r.docx
    _cr_has using r.html, pattern("<html")
    assert r(found) == 1
}
local trc = _rc
if `trc' == 0 local ++pass_count
else {
    display as error "FAILED: test `test_count' (rc `trc')"
    local ++fail_count
}

**# I4: run executes the do-file under the caller's version (Stata 17 syntax)
local ++test_count
capture noisily {
    file open fh using run17.do, write replace text
    file write fh "sysuse auto, clear" _n
    file write fh "table foreign, statistic(mean price)" _n
    file close fh
    capture noisily logdoc using run17.do, output(run17.html) run replace quiet
    assert _rc == 0
    local run_input "`r(input)'"
    _cr_has using run17.html, pattern("Domestic")
    assert r(found) == 1
    _cr_has using run17.html, pattern("r(198)")
    assert r(found) == 0
    * M1: r(input) is the user's do-file, not the erased wrapper log
    assert "`run_input'" == "run17.do"
    confirm file `"`run_input'"'
}
local trc = _rc
if `trc' == 0 local ++pass_count
else {
    display as error "FAILED: test `test_count' (rc `trc')"
    local ++fail_count
}

**# M2: .logdocrc grammar is the same with and without spaces; comments tolerated
local ++test_count
capture noisily {
    file open fh using .logdocrc, write replace text
    file write fh "# comment" _n
    file write fh "" _n
    file write fh "theme = dark" _n
    file close fh
    quietly logdoc using a.smcl, output(m2a.html) replace quiet
    assert "`r(theme)'" == "dark"
    file open fh using .logdocrc, write replace text
    file write fh "theme=dark" _n
    file close fh
    quietly logdoc using a.smcl, output(m2b.html) replace quiet
    assert "`r(theme)'" == "dark"
    quietly logdoc combine using a.smcl b.smcl, output(m2c.html) replace quiet
    assert "`r(theme)'" == "dark"
}
local trc = _rc
if `trc' == 0 local ++pass_count
else {
    display as error "FAILED: test `test_count' (rc `trc')"
    local ++fail_count
}
capture erase .logdocrc

**# M3: command-line quiet/verbose beats the config opposite; conflicts are errors
local ++test_count
capture noisily {
    file open fh using .logdocrc, write replace text
    file write fh "quiet=1" _n
    file close fh
    capture erase m3.log
    quietly log using m3.log, text replace name(_cr3)
    capture noisily logdoc using a.smcl, output(m3a.html) verbose replace
    local rc_verbose = _rc
    quietly log close _cr3
    assert `rc_verbose' == 0
    _cr_has using m3.log, pattern("Generating document")
    assert r(found) == 1
    file open fh using .logdocrc, write replace text
    file write fh "verbose=1" _n
    file close fh
    quietly log using m3.log, text replace name(_cr3)
    capture noisily logdoc using a.smcl, output(m3b.html) quiet replace
    local rc_quiet = _rc
    quietly log close _cr3
    assert `rc_quiet' == 0
    _cr_has using m3.log, pattern("Generating document")
    assert r(found) == 0
    * both on the command line stays an error
    capture quietly logdoc using a.smcl, output(m3c.html) quiet verbose replace
    assert _rc == 198
    * both only in config is an error too
    file open fh using .logdocrc, write replace text
    file write fh "verbose=1" _n
    file write fh "quiet=1" _n
    file close fh
    capture quietly logdoc using a.smcl, output(m3d.html) replace
    assert _rc == 198
    * combine follows the same rule
    file open fh using .logdocrc, write replace text
    file write fh "quiet=1" _n
    file close fh
    quietly log using m3.log, text replace name(_cr3)
    capture noisily logdoc combine using a.smcl b.smcl, output(m3e.html) verbose replace
    local rc_comb = _rc
    quietly log close _cr3
    assert `rc_comb' == 0
    _cr_has using m3.log, pattern("Combining")
    assert r(found) == 1
}
local trc = _rc
capture log close _cr3
if `trc' == 0 local ++pass_count
else {
    display as error "FAILED: test `test_count' (rc `trc')"
    local ++fail_count
}
capture erase .logdocrc

**# M4: start rejects an existing output without replace/append, at start
local ++test_count
capture noisily {
    _cr_session_cleanup
    quietly copy a.smcl m4.html, replace
    capture noisily logdoc start, output(m4.html) quiet
    local rc_start = _rc
    local active_after "$LOGDOC_ACTIVE"
    _cr_session_cleanup
    assert `rc_start' == 602
    assert "`active_after'" == ""
    * format(both): a pre-existing secondary file is enough
    quietly copy a.smcl m4b.md, replace
    capture erase m4b.html
    capture noisily logdoc start, output(m4b) format(both) quiet
    local rc_both = _rc
    _cr_session_cleanup
    assert `rc_both' == 602
    * replace, append and config replace all allow the session to start
    capture noisily logdoc start, output(m4.html) replace quiet
    assert _rc == 0
    assert "$LOGDOC_ACTIVE" == "1"
    _cr_session_cleanup
    capture noisily logdoc start, output(m4.html) append quiet
    assert _rc == 0
    _cr_session_cleanup
    file open fh using .logdocrc, write replace text
    file write fh "replace = 1" _n
    file close fh
    capture noisily logdoc start, output(m4.html) quiet
    assert _rc == 0
    _cr_session_cleanup
}
local trc = _rc
_cr_session_cleanup
if `trc' == 0 local ++pass_count
else {
    display as error "FAILED: test `test_count' (rc `trc')"
    local ++fail_count
}
capture erase .logdocrc

**# M5: format(pdf) leaves no tempfile .pdf candidate and prints no copy note
local ++test_count
capture noisily {
    local before : dir "`c(tmpdir)'" files "St*.pdf"
    capture erase m5.log
    quietly log using m5.log, text replace name(_cr5)
    capture noisily logdoc using a.smcl, output(m5.pdf) format(pdf) replace quiet
    local rc_pdf = _rc
    quietly log close _cr5
    assert `rc_pdf' == 0
    confirm file m5.pdf
    local after : dir "`c(tmpdir)'" files "St*.pdf"
    local new_pdf : list after - before
    assert `"`new_pdf'"' == ""
    _cr_has using m5.log, pattern("not found")
    assert r(found) == 0
}
local trc = _rc
capture log close _cr5
if `trc' == 0 local ++pass_count
else {
    display as error "FAILED: test `test_count' (rc `trc')"
    local ++fail_count
}

**# M6: a stray renderer or CSS in the cwd never beats the installed ones
local ++test_count
capture noisily {
    capture mkdir stray
    quietly copy a.smcl stray/a.smcl, replace
    file open fh using stray/logdoc_render.py, write replace text
    file write fh "import sys" _n
    file write fh "open('stray_ran.txt', 'w').write('x')" _n
    file write fh "sys.exit(1)" _n
    file close fh
    file open fh using stray/logdoc_light.css, write replace text
    file write fh "body { background: #ff00fe; }" _n
    file close fh
    quietly cd stray
    capture erase stray_ran.txt
    * fold and copy select the enhanced route, which embeds theme CSS
    capture noisily logdoc using a.smcl, output(m6.html) fold copy replace quiet
    local rc_stray = _rc
    quietly logdoc_py, quiet
    local py_renderer `"`r(renderer)'"'
    quietly cd "`sbx'"
    assert `rc_stray' == 0
    capture confirm file stray/stray_ran.txt
    assert _rc != 0
    _cr_has using stray/m6.html, pattern("ff00fe")
    assert r(found) == 0
    _cr_has using stray/m6.html, pattern("hello alpha")
    assert r(found) == 1
    * built-in theme CSS is present
    _cr_has using stray/m6.html, pattern("<style")
    assert r(found) == 1
    assert substr(`"`py_renderer'"', 1, 2) != "./"
    assert `"`py_renderer'"' != "logdoc_render.py"
    assert strpos(`"`py_renderer'"', "stray") == 0
}
local trc = _rc
quietly cd "`sbx'"
if `trc' == 0 local ++pass_count
else {
    display as error "FAILED: test `test_count' (rc `trc')"
    local ++fail_count
}

**# I6: docx/pdf output substitution precedes Windows path normalization
local ++test_count
capture noisily {
    quietly findfile logdoc.ado
    local ado_file "`r(fn)'"
    _cr_has using `"`ado_file'"', pattern(`""--format docx", "--format html""')
    local sub_pos = r(pos)
    _cr_has using `"`ado_file'"', pattern(`""\", "/", .)"')
    local win_pos = r(pos)
    assert `sub_pos' > 0
    assert `win_pos' > 0
    assert `sub_pos' < `win_pos'
    * and the docx artifact is a real zip container, not HTML bytes
    quietly logdoc using a.smcl, output(i6.docx) replace quiet
    tempname bh
    file open `bh' using i6.docx, read binary
    file read `bh' %2s magic
    file close `bh'
    assert "`magic'" == "PK"
}
local trc = _rc
if `trc' == 0 local ++pass_count
else {
    display as error "FAILED: test `test_count' (rc `trc')"
    local ++fail_count
}

**# O1: dispatcher forwards every child return unchanged
local ++test_count
capture noisily {
    quietly logdoc using a.smcl, output(o1a.html) replace quiet
    local sc : r(scalars)
    local mc : r(macros)
    local sc : list sort sc
    local mc : list sort mc
    assert "`sc'" == "filesize nblocks ngraphs ntables nwarnings"
    assert "`mc'" == "format input output theme"
    assert r(nblocks) == 3
    assert "`r(output)'" == "o1a.html"
    quietly logdoc using a.smcl, output(o1b) format(both) replace quiet
    local mc : r(macros)
    local mc : list sort mc
    assert "`mc'" == "format input output secondary theme"
    assert "`r(secondary)'" == "o1b.md"
    quietly logdoc combine using a.smcl b.smcl, output(o1c.html) replace quiet
    local sc : r(scalars)
    local sc : list sort sc
    assert "`sc'" == "filesize n_sources nblocks ngraphs ntables nwarnings"
    assert r(n_sources) == 2
    assert r(nblocks) == 6
    local pat "bd/*.smcl"
    quietly logdoc batch, input(`pat') outdir(o1d) replace quiet
    local sc : r(scalars)
    local mc : r(macros)
    local sc : list sort sc
    assert "`sc'" == "n_failed n_files"
    assert "`mc'" == ""
    assert r(n_files) == 2 & r(n_failed) == 0
    quietly logdoc diff using a.smcl, compare(b.smcl) output(o1e.html) replace quiet
    local mc : r(macros)
    local mc : list sort mc
    assert "`mc'" == "compare input output"
    assert "`r(compare)'" == "b.smcl"
    * failure path keeps its exact rc and posts nothing
    capture quietly logdoc using nosuch.smcl, output(o1f.html) replace quiet
    assert _rc == 601
    local sc : r(scalars)
    local mc : r(macros)
    assert "`sc'`mc'" == ""
}
local trc = _rc
if `trc' == 0 local ++pass_count
else {
    display as error "FAILED: test `test_count' (rc `trc')"
    local ++fail_count
}

**# P1: an invalid explicit python ($LOGDOC_PYTHON, .logdocrc) fails naming its source; no fall-through
local ++test_count
capture noisily {
    local bad "/definitely/not/logdoc/bad-python"
    capture erase .logdocrc
    capture macro drop LOGDOC_PYTHON

    * --- invalid global, valid config: fail in every entry point ---
    global LOGDOC_PYTHON "`bad'"
    quietly file open fh using .logdocrc, write text replace
    file write fh "python=`wrap'" _n
    file close fh
    capture erase marker.txt
    local cmds `""logdoc using a.smcl, output(p1a.html) replace quiet""'
    local cmds `"`cmds' "logdoc combine using a.smcl b.smcl, output(p1c.html) replace quiet""'
    local cmds `"`cmds' "logdoc diff using a.smcl, compare(b.smcl) output(p1d.html) replace quiet""'
    local pat "bd/*.smcl"
    local cmds `"`cmds' "logdoc batch, input(`pat') outdir(p1b) replace quiet""'
    local k = 0
    foreach c of local cmds {
        local ++k
        capture log close _p1
        quietly log using "p1_`k'.log", text replace nomsg name(_p1)
        capture noisily `c'
        local p1rc = _rc
        quietly log close _p1
        assert `p1rc' == 601
        _cr_has using "p1_`k'.log", pattern("LOGDOC_PYTHON not usable: `bad'")
        assert r(found) == 1
        _cr_has using "p1_`k'.log", pattern("global LOGDOC_PYTHON")
        assert r(found) == 1
        * the valid config python was never used
        capture confirm file marker.txt
        assert _rc != 0
        _cr_session_cleanup
        global LOGDOC_PYTHON "`bad'"
    }
    * logdoc_py check: same failure, same message, rc 601
    capture log close _p1
    quietly log using "p1_py.log", text replace nomsg name(_p1)
    capture noisily logdoc_py, quiet
    local p1rc = _rc
    quietly log close _p1
    assert `p1rc' == 601
    _cr_has using "p1_py.log", pattern("LOGDOC_PYTHON not usable: `bad'")
    assert r(found) == 1
    capture confirm file marker.txt
    assert _rc != 0

    * session path: the python is resolved at stop
    quietly logdoc start, output(p1s.html) replace quiet
    display "session text"
    capture log close _p1
    quietly log using "p1_stop.log", text replace nomsg name(_p1)
    capture noisily logdoc stop
    local p1rc = _rc
    quietly log close _p1
    assert `p1rc' == 601
    _cr_has using "p1_stop.log", pattern("LOGDOC_PYTHON not usable: `bad'")
    assert r(found) == 1
    _cr_session_cleanup
    global LOGDOC_PYTHON "`bad'"

    * --- repair: set with a valid python() works despite the stale global ---
    quietly logdoc_py, python("`wrap'") set quiet
    assert `"$LOGDOC_PYTHON"' == "`wrap'"
    quietly logdoc_py, quiet
    assert "`r(python_source)'" == "global"
    quietly logdoc using a.smcl, output(p1r.html) replace quiet
    capture confirm file marker.txt
    assert _rc == 0

    * --- invalid config (no global): fail naming .logdocrc ---
    capture macro drop LOGDOC_PYTHON
    capture erase marker.txt
    quietly file open fh using .logdocrc, write text replace
    file write fh "python=`bad'" _n
    file close fh
    capture log close _p1
    quietly log using "p1_cfg.log", text replace nomsg name(_p1)
    capture noisily logdoc using a.smcl, output(p1f.html) replace quiet
    local p1rc = _rc
    quietly log close _p1
    assert `p1rc' == 601
    _cr_has using "p1_cfg.log", pattern("python= in the project ./.logdocrc not usable: `bad'")
    assert r(found) == 1
    _cr_has using "p1_cfg.log", pattern("python= in")
    assert r(found) == 1
    capture log close _p1
    quietly log using "p1_cfgpy.log", text replace nomsg name(_p1)
    capture noisily logdoc_py, quiet
    local p1rc = _rc
    quietly log close _p1
    assert `p1rc' == 601
    _cr_has using "p1_cfgpy.log", pattern("python= in the project ./.logdocrc not usable: `bad'")
    assert r(found) == 1

    * --- repair: save replace with a valid python() works despite stale config ---
    quietly logdoc_py, python("`wrap'") save replace quiet
    quietly logdoc_py, quiet
    assert "`r(python_source)'" == "config"
    assert `"`r(python)'"' == "`wrap'"
    capture erase marker.txt
    quietly logdoc using a.smcl, output(p1g.html) replace quiet
    capture confirm file marker.txt
    assert _rc == 0
}
local trc = _rc
if `trc' == 0 local ++pass_count
else {
    display as error "FAILED: test `test_count' (rc `trc')"
    local ++fail_count
}
**# R1: run leaves no batch-mode child log in the working directory
local ++test_count
capture noisily {
    capture mkdir runcwd
    quietly cd runcwd
    file open _r1fh using "r1.do", write text replace
    file write _r1fh "display 7100+3" _n
    file close _r1fh
    quietly logdoc using "r1.do", output("r1.html") run replace quiet
    local r1_logs : dir . files "*.log"
    assert `"`r1_logs'"' == ""
    _cr_has using r1.html, pattern("7103")
    assert r(found) == 1
}
local trc = _rc
capture file close _r1fh
quietly cd "`sbx'"
if `trc' == 0 local ++pass_count
else {
    display as error "FAILED: test `test_count' (rc `trc')"
    local ++fail_count
}

**# F1: .logdocrc flag values: 0/false/no/off are off, 1/true/yes/on are on, junk is rc 198
local ++test_count
capture noisily {
    foreach off in "0" "false" "no" "off" "" {
        file open fh using .logdocrc, write replace text
        file write fh "quiet = `off'" _n
        file close fh
        quietly log using f1.log, text replace name(_cr_f1)
        capture noisily logdoc using a.smcl, output(f1.html) replace
        local f1rc = _rc
        quietly log close _cr_f1
        assert `f1rc' == 0
        _cr_has using f1.log, pattern("Generating document")
        assert r(found) == 1
    }
    foreach on in "1" "true" "yes" "on" "TRUE" {
        file open fh using .logdocrc, write replace text
        file write fh "quiet=`on'" _n
        file close fh
        quietly log using f1.log, text replace name(_cr_f1)
        capture noisily logdoc using a.smcl, output(f1.html) replace
        local f1rc = _rc
        quietly log close _cr_f1
        assert `f1rc' == 0
        _cr_has using f1.log, pattern("Generating document")
        assert r(found) == 0
    }
    file open fh using .logdocrc, write replace text
    file write fh "quiet=maybe" _n
    file close fh
    quietly log using f1.log, text replace name(_cr_f1)
    capture noisily logdoc using a.smcl, output(f1.html) replace
    local f1rc = _rc
    quietly log close _cr_f1
    assert `f1rc' == 198
    _cr_has using f1.log, pattern("quiet")
    assert r(found) == 1
    _cr_has using f1.log, pattern(".logdocrc")
    assert r(found) == 1
    * replace=0 does not allow overwriting at start
    file open fh using .logdocrc, write replace text
    file write fh "replace = 0" _n
    file close fh
    quietly copy a.smcl f1s.html, replace
    capture noisily logdoc start, output(f1s.html) quiet
    local f1rc = _rc
    _cr_session_cleanup
    assert `f1rc' == 602
}
local trc = _rc
capture log close _cr_f1
if `trc' == 0 local ++pass_count
else {
    display as error "FAILED: test `test_count' (rc `trc')"
    local ++fail_count
}
capture erase .logdocrc

**# RP1: replay after combine, batch or diff says so and does not replay an older conversion
local ++test_count
capture noisily {
    quietly logdoc using a.smcl, output(rp1.html) replace quiet
    quietly logdoc replay
    local pat "bd/*.smcl"
    foreach c in "combine using a.smcl b.smcl, output(rp1c.html) replace quiet" ///
        "batch, input(`pat') outdir(rp1b) replace quiet" ///
        "diff using a.smcl, compare(b.smcl) output(rp1d.html) replace quiet" {
        quietly logdoc `c'
        quietly log using rp1.log, text replace name(_cr_rp1)
        capture noisily logdoc replay
        local rp1rc = _rc
        quietly log close _cr_rp1
        assert `rp1rc' == 198
        _cr_has using rp1.log, pattern("cannot be replayed")
        assert r(found) == 1
    }
    * a later single conversion makes replay work again
    quietly logdoc using a.smcl, output(rp1e.html) replace quiet
    quietly logdoc replay
    assert "`r(output)'" == "rp1e.html"
}
local trc = _rc
capture log close _cr_rp1
if `trc' == 0 local ++pass_count
else {
    display as error "FAILED: test `test_count' (rc `trc')"
    local ++fail_count
}

**# PF1: an invalid .logdocrc python names the file it came from
local ++test_count
capture noisily {
    capture macro drop LOGDOC_PYTHON
    file open fh using .logdocrc, write replace text
    file write fh "python = /definitely/not/logdoc/bad-config-python" _n
    file close fh
    quietly log using pf1.log, text replace name(_cr_pf1)
    capture noisily logdoc using a.smcl, output(pf1.html) replace quiet
    local pf1rc = _rc
    quietly log close _cr_pf1
    assert `pf1rc' == 601
    _cr_has using pf1.log, pattern("project ./.logdocrc")
    assert r(found) == 1
    _cr_has using pf1.log, pattern("bad-config-python")
    assert r(found) == 1
}
local trc = _rc
capture log close _cr_pf1
if `trc' == 0 local ++pass_count
else {
    display as error "FAILED: test `test_count' (rc `trc')"
    local ++fail_count
}
capture erase .logdocrc

**# L1: run prints no path to its (erased) wrapper log
local ++test_count
capture noisily {
    file open fh using l1.do, write text replace
    file write fh "display 7200+4" _n
    file close fh
    quietly log using l1.log, text replace name(_cr_l1)
    capture noisily logdoc using l1.do, output(l1.html) run replace
    local l1rc = _rc
    quietly log close _cr_l1
    assert `l1rc' == 0
    _cr_has using l1.log, pattern("Log captured")
    assert r(found) == 0
}
local trc = _rc
capture log close _cr_l1
if `trc' == 0 local ++pass_count
else {
    display as error "FAILED: test `test_count' (rc `trc')"
    local ++fail_count
}

**# V1: start validates the whole .logdocrc, so a bad flag fails at start
local ++test_count
capture noisily {
    _cr_session_cleanup
    local ls_before = c(linesize)
    file open fh using .logdocrc, write replace text
    file write fh "copy = maybe" _n
    file close fh
    capture erase v1.html
    quietly log using v1.log, text replace name(_cr_v1)
    capture noisily logdoc start, output(v1.html) replace quiet
    local v1rc = _rc
    quietly log close _cr_v1
    local active_after "$LOGDOC_ACTIVE"
    local ls_after = c(linesize)
    _cr_session_cleanup
    assert `v1rc' == 198
    assert "`active_after'" == ""
    assert `ls_after' == `ls_before'
    _cr_has using v1.log, pattern("copy")
    assert r(found) == 1
}
local trc = _rc
capture log close _cr_v1
if `trc' == 0 local ++pass_count
else {
    display as error "FAILED: test `test_count' (rc `trc')"
    local ++fail_count
}
capture erase .logdocrc

capture log close _p1
_cr_session_cleanup
capture macro drop LOGDOC_PYTHON
capture erase .logdocrc
capture erase marker.txt

quietly cd "`orig_pwd'"
capture shell rm -rf "`sbx'"

display "RESULT: test_logdoc_config_run tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 9
