clear all
set more off
version 16.0

* test_datamap_v200_removed.do - what datamap 2.0.0 removed stops, with a pointer
*
* 2.0.0 (2026-11-10): datadict is gone (no stub, no wrapper), Markdown is the
* only file format, and the options that existed only for the text/JSON
* layouts or for datadict are removed:
*   datadict                 unrecognized, rc 199, after a clean install
*   format(anything)         rc 198, "format() was removed in 2.0.0: ..."
*   datevars()               rc 198, "datevars() was removed in 2.0.0: ..."
*   date(<document date>)    rc 198 (date() is datamap's varlist; the document
*                            date is docdate()), with a docdate() pointer
*   noguidance, bare missing, stats, detail, datasignature
*                            rc 198 from -syntax- ("option X not allowed"); no
*                            replacement exists (README migration table)
*   config(): a format key   rc 198, "config(): the format key was removed ..."
* Every rejection happens before any file is written and leaves the caller's
* data, settings and frames untouched.  The replacement meanings are pinned at
* the end: date(varlist) classifies, docdate() is the document date,
* missing(detail|pattern) is the missingness section, det abbreviates detect.
*
* Not covered here (open, reported to the supervisor): format() and datevars()
* with EMPTY parentheses are accepted at rc 0.

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace

do "`qa_dir'/_qa_md.do"
do "`qa_dir'/_qa_state.do"

local orig_plus     : sysdir PLUS
local orig_personal : sysdir PERSONAL
local orig_linesize = c(linesize)

tempfile base
local msg_log "`base'_msg.log"
local out     "`base'_out.md"
local meta    "`base'_meta.dta"
local srcdta  "`base'_src.dta"
local bt = char(96)

* run one datamap call with its error text captured in a log; the text is
* in `msg_log' (linesize 255 so the message is not wrapped)
capture program drop _rm_call
program define _rm_call, rclass
    version 16.0
    syntax , Log(string) Call(string asis) [QUIet]
    capture log close _rm_msg
    quietly log using `"`log'"', text replace name(_rm_msg)
    * quiet: only the return code is wanted, so Stata's own error text (e.g.
    * "option stats not allowed") is not echoed into the suite log, where a
    * log reader would count it as a failure
    if "`quiet'" != "" capture `call'
    else capture noisily `call'
    local rc = _rc
    quietly log close _rm_msg
    return scalar rc = `rc'
end

sysuse auto, clear
quietly save "`srcdta'", replace
set linesize 255

**# R1: datadict is unrecognized after a clean install (rc 199)

local ++test_count
capture noisily {
    * nothing in the package tree
    capture confirm file "`pkg_dir'/datadict.ado"
    assert _rc != 0
    capture confirm file "`pkg_dir'/datadict.sthlp"
    assert _rc != 0
    qa_md_contains using "`pkg_dir'/datamap.pkg", needle("datadict")
    assert r(found) == 0
    * a clean install in an empty PLUS and PERSONAL
    local plus "`base'_r1_plus"
    local personal "`base'_r1_personal"
    capture mkdir "`plus'"
    capture mkdir "`personal'"
    sysdir set PLUS "`plus'/"
    sysdir set PERSONAL "`personal'/"
    discard
    quietly net install datamap, from("`pkg_dir'") replace
    capture quietly findfile datadict.ado
    assert _rc != 0
    capture quietly findfile datadict.sthlp
    assert _rc != 0
    capture datadict
    assert _rc == 199
    capture datadict, output("`out'") missing stats
    assert _rc == 199
    capture confirm file "`out'"
    assert _rc != 0
    * the install itself is complete: datamap and its renderer resolve
    quietly findfile datamap.ado
    assert strpos(`"`r(fn)'"', "`plus'") == 1
    quietly findfile _datamap_md_document.ado
    assert strpos(`"`r(fn)'"', "`plus'") == 1
    * help for the removed command finds nothing in the install
    capture quietly findfile datadict.sthlp
    assert _rc != 0
}
local rc_case = _rc
sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
if `rc_case' == 0 {
    display as result "  PASS: datadict is unrecognized (rc 199) after a clean install; no package file names it"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict after a clean install (error `rc_case')"
    local ++fail_count
}

**# R2: format(json) and format(text): rc 198, the exact message, nothing written

local fmt_msg "format() was removed in 2.0.0: datamap writes Markdown; use saving() for a machine-readable table"
local fmt_n 0
foreach f in json text {
    local ++test_count
    capture noisily {
        capture erase "`out'"
        capture erase "`meta'"
        qa_state_snapshot, tag(rm_fmt)
        _rm_call, log("`msg_log'") call(datamap price mpg, output("`out'") saving("`meta'", replace) format(`f'))
        assert r(rc) == 198
        qa_md_contains using "`msg_log'", needle("`fmt_msg'") exact
        assert r(found) == 1
        capture confirm file "`out'"
        assert _rc != 0
        capture confirm file "`meta'"
        assert _rc != 0
        qa_state_compare, tag(rm_fmt)
    }
    if _rc == 0 {
        display as result "  PASS: format(`f') stops with rc 198 and the exact message; no file written"
        local ++pass_count
    }
    else {
        display as error "  FAIL: format(`f') (error `=_rc')"
        local ++fail_count
    }
}

**# R3: any other format() value is refused too (format() is parsed only to stop)

local ++test_count
capture noisily {
    foreach f in markdown md txt JSON {
        capture erase "`out'"
        _rm_call, log("`msg_log'") call(datamap price mpg, output("`out'") format(`f'))
        assert r(rc) == 198
        qa_md_contains using "`msg_log'", needle("`fmt_msg'") exact
        assert r(found) == 1
        capture confirm file "`out'"
        assert _rc != 0
    }
    * format() also refused beside a varlist, an input option and config()
    capture erase "`out'"
    _rm_call, log("`msg_log'") call(datamap, single("`srcdta'") output("`out'") format(json))
    assert r(rc) == 198
    capture confirm file "`out'"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: format(markdown|md|txt|JSON) and format() with single() all stop rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: other format() values (error `=_rc')"
    local ++fail_count
}

**# R4: the removed options that fall out of -syntax- each fail rc 198

foreach opt in noguidance missing stats detail datasignature {
    local ++test_count
    capture noisily {
        capture erase "`out'"
        capture erase "`meta'"
        qa_state_snapshot, tag(rm_opt)
        _rm_call, log("`msg_log'") call(datamap price mpg, output("`out'") saving("`meta'", replace) `opt') quiet
        assert r(rc) == 198
        capture confirm file "`out'"
        assert _rc != 0
        capture confirm file "`meta'"
        assert _rc != 0
        qa_state_compare, tag(rm_opt)
        * the same option beside valid options and an input option
        _rm_call, log("`msg_log'") call(datamap, single("`srcdta'") output("`out'") quality `opt') quiet
        assert r(rc) == 198
        capture confirm file "`out'"
        assert _rc != 0
    }
    if _rc == 0 {
        display as result "  PASS: `opt' stops with rc 198; no file written; state unchanged"
        local ++pass_count
    }
    else {
        display as error "  FAIL: `opt' (error `=_rc')"
        local ++fail_count
    }
}

**# R5: datevars() names its replacement; date(<document date>) points at docdate()

local ++test_count
capture noisily {
    capture erase "`out'"
    qa_state_snapshot, tag(rm_dv)
    _rm_call, log("`msg_log'") call(datamap price, output("`out'") datevars(price))
    assert r(rc) == 198
    qa_md_contains using "`msg_log'", needle("datevars() was removed in 2.0.0: use date() to classify variables as dates") exact
    assert r(found) == 1
    capture confirm file "`out'"
    assert _rc != 0
    qa_state_compare, tag(rm_dv)
    * datadict's date(): a document date reaches date(), which takes variables
    foreach d in 2026-11-10 "10 Nov 2026" November nosuchvar {
        capture erase "`out'"
        _rm_call, log("`msg_log'") call(datamap price, output("`out'") date(`d'))
        assert r(rc) == 198
        qa_md_contains using "`msg_log'", needle("date() names variables to classify as dates; the document date is docdate() since 2.0.0")
        assert r(found) == 1
        capture confirm file "`out'"
        assert _rc != 0
    }
    * a typo in continuous() is still a missing-variable error, not 198
    _rm_call, log("`msg_log'") call(datamap price, output("`out'") continuous(nosuchvar))
    assert r(rc) == 111
}
if _rc == 0 {
    display as result "  PASS: datevars() and a document date in date() stop rc 198 with their pointers"
    local ++pass_count
}
else {
    display as error "  FAIL: datevars()/date() pointers (error `=_rc')"
    local ++fail_count
}

**# R6: a format key in config() is refused with its own message

local ++test_count
capture noisily {
    local cfg "`base'_cfg.txt"
    quietly file open cf using "`cfg'", write text replace
    file write cf "title = Should not be written" _n
    file write cf "format = json" _n
    file close cf
    capture erase "`out'"
    _rm_call, log("`msg_log'") call(datamap price mpg, output("`out'") config("`cfg'"))
    assert r(rc) == 198
    qa_md_contains using "`msg_log'", needle("config(): the format key was removed in 2.0.0: datamap writes Markdown; use saving() for a machine-readable table") exact
    assert r(found) == 1
    capture confirm file "`out'"
    assert _rc != 0
    * datadict's other config keys are ignored, not errors (2026-11-10,
    * Phase 6 repair: still rc 0, but no longer silent -- one note names them)
    quietly file open cf using "`cfg'", write text replace
    file write cf "detail = yes" _n
    file write cf "stats = yes" _n
    file write cf "datasignature = yes" _n
    file write cf "noguidance = yes" _n
    file close cf
    _rm_call, log("`msg_log'") call(datamap price mpg, output("`out'") config("`cfg'"))
    assert r(rc) == 0
    confirm file "`out'"
    qa_md_contains using "`msg_log'", needle("note: config(): key removed in 2.0.0, ignored: detail stats datasignature noguidance") exact
    assert r(found) == 1
    capture erase "`cfg'"
}
if _rc == 0 {
    display as result "  PASS: config(format = json) is rc 198; datadict's other keys are ignored with a note"
    local ++pass_count
}
else {
    display as error "  FAIL: config() format key (error `=_rc')"
    local ++fail_count
}

**# R7: the replacement meanings that won the option clashes

local ++test_count
capture noisily {
    sysuse auto, clear
    gen long when = mdy(3, 1, 2020) + _n
    capture erase "`out'"
    capture erase "`meta'"
    * date(varlist) classifies a numeric variable as a date; docdate() is the
    * document date; both together with the other document options
    datamap price when, output("`out'") saving("`meta'", replace) ///
        date(when) title(T) docdate(2026-11-10)
    assert "`r(date_vars)'" == "when"
    qa_md_contains using "`out'", needle("**Last Updated:** 2026-11-10") exact
    assert r(found) == 1
    preserve
    use "`meta'", clear
    assert class == "date" if variable == "when"
    assert class != "date" if variable == "price"
    restore
    * missing(detail) and missing(pattern) are the missingness section
    capture erase "`out'"
    datamap price rep78, output("`out'") missing(pattern)
    qa_md_contains using "`out'", needle("### Missingness") exact
    assert r(found) == 1
    * det abbreviates detect()
    capture erase "`out'"
    datamap foreign, output("`out'") det(binary)
    qa_md_contains using "`out'", needle("- Binary (two distinct values): `bt'foreign`bt'") exact
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: date(varlist), docdate(), missing(pattern) and det() carry datamap's meanings"
    local ++pass_count
}
else {
    display as error "  FAIL: replacement option meanings (error `=_rc')"
    local ++fail_count
}

**# R8: config() names what it ignores (2026-11-10, Phase 6 repair; red on
* the pre-repair build, where every line below was dropped at rc 0 silently)

local ++test_count
capture noisily {
    sysuse auto, clear
    local cfg "`base'_cfg8.txt"
    quietly file open cf using "`cfg'", write text replace
    * a misspelt privacy key, a bare flag line, an unreadable switch value, a
    * key only dataprobe reads, a known key, and a comment
    file write cf "# project defaults" _n
    file write cf "exlcude = make" _n
    file write cf "datesafe" _n
    file write cf "nolabels = yse" _n
    file write cf "rare = 3" _n
    file write cf "title = Configured" _n
    file close cf
    capture erase "`out'"
    _rm_call, log("`msg_log'") call(datamap make price, output("`out'") config("`cfg'"))
    assert r(rc) == 0
    qa_md_contains using "`msg_log'", needle("note: config(): key not recognised, ignored: exlcude") exact
    assert r(found) == 1
    qa_md_contains using "`msg_log'", needle("note: config(): line without = or :, ignored (write key = yes): datesafe") exact
    assert r(found) == 1
    qa_md_contains using "`msg_log'", needle("note: config(): value is not 1/yes/true/on or 0/no/false/off, so the switch stays off: nolabels") exact
    assert r(found) == 1
    * rare is dataprobe's key: no note, so one file serves both commands
    qa_md_contains using "`msg_log'", needle("rare")
    assert r(found) == 0
    qa_md_contains using "`msg_log'", needle("note: config():")
    assert r(n) == 3
    * the ignored lines left the defaults in force; the known key applied
    qa_md_contains using "`out'", needle("# Configured")
    assert r(found) == 1
    quietly datamap make price, output("`out'") config("`cfg'")
    assert "`r(excluded_vars)'" == ""
    * a clean file prints no note
    quietly file open cf using "`cfg'", write text replace
    file write cf "title = Configured" _n
    file write cf "nolabels = no" _n
    file close cf
    _rm_call, log("`msg_log'") call(datamap price, output("`out'") config("`cfg'"))
    assert r(rc) == 0
    qa_md_contains using "`msg_log'", needle("note: config():")
    assert r(found) == 0
    * dataprobe reads the same file: an unknown key is named, a key only
    * datamap reads (title) is not
    quietly file open cf using "`cfg'", write text replace
    file write cf "title = Configured" _n
    file write cf "maskrar = yes" _n
    file write cf "stats = yes" _n
    file close cf
    _rm_call, log("`msg_log'") call(dataprobe price, config("`cfg'"))
    assert r(rc) == 0
    qa_md_contains using "`msg_log'", needle("note: config(): key not recognised, ignored: maskrar") exact
    assert r(found) == 1
    qa_md_contains using "`msg_log'", needle("note: config(): key removed in 2.0.0, ignored: stats") exact
    assert r(found) == 1
    qa_md_contains using "`msg_log'", needle("note: config():")
    assert r(n) == 2
    capture erase "`cfg'"
}
if _rc == 0 {
    display as result "  PASS: config() notes unknown keys, bare lines, and unreadable switch values in datamap and dataprobe"
    local ++pass_count
}
else {
    display as error "  FAIL: config() ignored-key notes (error `=_rc')"
    local ++fail_count
}

set linesize `orig_linesize'
capture erase "`out'"
capture erase "`meta'"
capture erase "`msg_log'"
capture erase "`srcdta'"

display as text "datamap v200 removed-option tests: `pass_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_datamap_v200_removed tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 9
}
display as result "ALL TESTS PASSED"
display "RESULT: test_datamap_v200_removed tests=`test_count' pass=`pass_count' fail=`fail_count'"
exit 0
