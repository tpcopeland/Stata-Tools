* test_logdoc_v119.do - artifact and lifecycle regressions for F1-F9
* Author: Timothy P Copeland, Karolinska Institutet
* Run from logdoc/qa: stata-mp -b do test_logdoc_v119.do
version 16.0
clear all
set processors 1
capture log close _all
local qadir = regexr("`c(pwd)'", "/+$", "")
local pkgdir = regexr("`qadir'", "/qa/?$", "")
local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
tempfile token
local sandbox "`token'_qa"
mkdir "`sandbox'"
mkdir "`sandbox'/plus"
mkdir "`sandbox'/personal"
sysdir set PLUS "`sandbox'/plus"
sysdir set PERSONAL "`sandbox'/personal"
ado dir
quietly net install logdoc, from("`pkgdir'") replace
discard
which logdoc
quietly logdoc_py
local python "`r(python)'"
local tool "`qadir'/tools/check_review_regressions.py"
local pass = 0
local fail = 0
local test_count = 0
tempname fh

**# F1: artifact regression
local ++test_count
local d "`sandbox'/F1"
local receipt "`sandbox'/receipt.txt"
local size = 0
capture noisily {
    clear
    shell "`python'" "`tool'" setup F1 "`d'" "`receipt'"
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
    capture noisily logdoc using "`d'/a.log", output("`d'/out.html") replace quiet
    local child_rc = _rc
    assert `child_rc' != 0
    shell "`python'" "`tool'" verify F1 "`d'" "`receipt'" --size `size'
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
}
local case_rc = _rc
capture file close `fh'
capture cd "`qadir'"
if `case_rc' == 0 {
    local ++pass
    display as result "PASS: F1"
}
else {
    local ++fail
    display as error "FAIL: F1 rc=`case_rc'"
}

**# F1-docx: artifact regression
local ++test_count
local d "`sandbox'/F1-docx"
local receipt "`sandbox'/receipt.txt"
local size = 0
capture noisily {
    clear
    shell "`python'" "`tool'" setup F1-docx "`d'" "`receipt'"
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
    capture noisily logdoc using "`d'/a.log", output("`d'/out.docx") format(docx) replace quiet
    local child_rc = _rc
    assert `child_rc' != 0
    shell "`python'" "`tool'" verify F1-docx "`d'" "`receipt'" --size `size'
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
}
local case_rc = _rc
capture file close `fh'
capture cd "`qadir'"
if `case_rc' == 0 {
    local ++pass
    display as result "PASS: F1-docx"
}
else {
    local ++fail
    display as error "FAIL: F1-docx rc=`case_rc'"
}

**# F1-pdf: artifact regression
local ++test_count
local d "`sandbox'/F1-pdf"
local receipt "`sandbox'/receipt.txt"
local size = 0
capture noisily {
    clear
    shell "`python'" "`tool'" setup F1-pdf "`d'" "`receipt'"
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
    capture noisily logdoc using "`d'/a.log", output("`d'/out.pdf") format(pdf) replace quiet
    local child_rc = _rc
    assert `child_rc' != 0
    shell "`python'" "`tool'" verify F1-pdf "`d'" "`receipt'" --size `size'
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
}
local case_rc = _rc
capture file close `fh'
capture cd "`qadir'"
if `case_rc' == 0 {
    local ++pass
    display as result "PASS: F1-pdf"
}
else {
    local ++fail
    display as error "FAIL: F1-pdf rc=`case_rc'"
}

**# F2-convert: artifact regression
local ++test_count
local d "`sandbox'/F2-convert"
local receipt "`sandbox'/receipt.txt"
local size = 0
capture noisily {
    clear
    shell "`python'" "`tool'" setup F2-convert "`d'" "`receipt'"
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
    capture noisily logdoc using "`d'/a.log", output("`d'/out") format(both) replace quiet
    local child_rc = _rc
    assert `child_rc' == 601
    shell "`python'" "`tool'" verify F2-convert "`d'" "`receipt'" --size `size'
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
}
local case_rc = _rc
capture file close `fh'
capture cd "`qadir'"
if `case_rc' == 0 {
    local ++pass
    display as result "PASS: F2-convert"
}
else {
    local ++fail
    display as error "FAIL: F2-convert rc=`case_rc'"
}

**# F2-combine: artifact regression
local ++test_count
local d "`sandbox'/F2-combine"
local receipt "`sandbox'/receipt.txt"
local size = 0
capture noisily {
    clear
    shell "`python'" "`tool'" setup F2-combine "`d'" "`receipt'"
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
    capture noisily logdoc combine using "`d'/a.log" "`d'/b.log", output("`d'/out") format(both) replace quiet
    local child_rc = _rc
    assert `child_rc' == 601
    shell "`python'" "`tool'" verify F2-combine "`d'" "`receipt'" --size `size'
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
}
local case_rc = _rc
capture file close `fh'
capture cd "`qadir'"
if `case_rc' == 0 {
    local ++pass
    display as result "PASS: F2-combine"
}
else {
    local ++fail
    display as error "FAIL: F2-combine rc=`case_rc'"
}

**# F3-html: artifact regression
local ++test_count
local d "`sandbox'/F3-html"
local receipt "`sandbox'/receipt.txt"
local size = 0
capture noisily {
    clear
    shell "`python'" "`tool'" setup F3-html "`d'" "`receipt'"
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
    cd "`d'"
    logdoc using "`d'/source/a.log", output("`d'/out.html") replace quiet
    assert r(ngraphs) == 1
    shell "`python'" "`tool'" verify F3-html "`d'" "`receipt'" --size `size'
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
}
local case_rc = _rc
capture file close `fh'
capture cd "`qadir'"
if `case_rc' == 0 {
    local ++pass
    display as result "PASS: F3-html"
}
else {
    local ++fail
    display as error "FAIL: F3-html rc=`case_rc'"
}

**# F3-md: artifact regression
local ++test_count
local d "`sandbox'/F3-md"
local receipt "`sandbox'/receipt.txt"
local size = 0
capture noisily {
    clear
    shell "`python'" "`tool'" setup F3-md "`d'" "`receipt'"
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
    cd "`d'"
    logdoc using "`d'/source/a.log", output("`d'/out.md") format(md) replace quiet
    shell "`python'" "`tool'" verify F3-md "`d'" "`receipt'" --size `size'
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
}
local case_rc = _rc
capture file close `fh'
capture cd "`qadir'"
if `case_rc' == 0 {
    local ++pass
    display as result "PASS: F3-md"
}
else {
    local ++fail
    display as error "FAIL: F3-md rc=`case_rc'"
}

**# F3-tex: artifact regression
local ++test_count
local d "`sandbox'/F3-tex"
local receipt "`sandbox'/receipt.txt"
local size = 0
capture noisily {
    clear
    shell "`python'" "`tool'" setup F3-tex "`d'" "`receipt'"
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
    cd "`d'"
    logdoc using "`d'/source/a.log", output("`d'/out.tex") format(tex) replace quiet
    shell "`python'" "`tool'" verify F3-tex "`d'" "`receipt'" --size `size'
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
}
local case_rc = _rc
capture file close `fh'
capture cd "`qadir'"
if `case_rc' == 0 {
    local ++pass
    display as result "PASS: F3-tex"
}
else {
    local ++fail
    display as error "FAIL: F3-tex rc=`case_rc'"
}

**# F3-combine: artifact regression
local ++test_count
local d "`sandbox'/F3-combine"
local receipt "`sandbox'/receipt.txt"
local size = 0
capture noisily {
    clear
    shell "`python'" "`tool'" setup F3-combine "`d'" "`receipt'"
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
    cd "`d'"
    logdoc combine using "`d'/source/a.log" "`d'/b.log", output("`d'/out.html") replace quiet
    assert r(ngraphs) == 1
    shell "`python'" "`tool'" verify F3-combine "`d'" "`receipt'" --size `size'
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
}
local case_rc = _rc
capture file close `fh'
capture cd "`qadir'"
if `case_rc' == 0 {
    local ++pass
    display as result "PASS: F3-combine"
}
else {
    local ++fail
    display as error "FAIL: F3-combine rc=`case_rc'"
}

**# F4: artifact regression
local ++test_count
local d "`sandbox'/F4"
local receipt "`sandbox'/receipt.txt"
local size = 0
capture noisily {
    clear
    shell "`python'" "`tool'" setup F4 "`d'" "`receipt'"
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
    capture noisily logdoc batch, input("`d'/batch/*") outdir("`d'/out") replace quiet
    local child_rc = _rc
    assert `child_rc' == 198
    shell "`python'" "`tool'" verify F4 "`d'" "`receipt'" --size `size'
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
}
local case_rc = _rc
capture file close `fh'
capture cd "`qadir'"
if `case_rc' == 0 {
    local ++pass
    display as result "PASS: F4"
}
else {
    local ++fail
    display as error "FAIL: F4 rc=`case_rc'"
}

**# F5-filter: artifact regression
local ++test_count
local d "`sandbox'/F5-filter"
local receipt "`sandbox'/receipt.txt"
local size = 0
capture noisily {
    clear
    shell "`python'" "`tool'" setup F5-filter "`d'" "`receipt'"
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
    logdoc combine using "`d'/a.log" "`d'/b.log", output("`d'/out.html") keep("BETA") replace quiet
    local nblocks = r(nblocks)
    assert `nblocks' > 0
    logdoc combine using "`d'/b.log" "`d'/a.log", output("`d'/reverse.html") keep("BETA") replace quiet
    assert r(nblocks) == `nblocks' 
    shell "`python'" "`tool'" verify F5-filter "`d'" "`receipt'" --size `size'
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
}
local case_rc = _rc
capture file close `fh'
capture cd "`qadir'"
if `case_rc' == 0 {
    local ++pass
    display as result "PASS: F5-filter"
}
else {
    local ++fail
    display as error "FAIL: F5-filter rc=`case_rc'"
}

**# F5-empty: artifact regression
local ++test_count
local d "`sandbox'/F5-empty"
local receipt "`sandbox'/receipt.txt"
local size = 0
capture noisily {
    clear
    shell "`python'" "`tool'" setup F5-empty "`d'" "`receipt'"
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
    logdoc combine using "`d'/empty.log" "`d'/b.log", output("`d'/out.html") replace quiet
    local nblocks = r(nblocks)
    assert `nblocks' > 0
    logdoc combine using "`d'/b.log" "`d'/empty.log", output("`d'/reverse.html") replace quiet
    assert r(nblocks) == `nblocks' 
    shell "`python'" "`tool'" verify F5-empty "`d'" "`receipt'" --size `size'
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
}
local case_rc = _rc
capture file close `fh'
capture cd "`qadir'"
if `case_rc' == 0 {
    local ++pass
    display as result "PASS: F5-empty"
}
else {
    local ++fail
    display as error "FAIL: F5-empty rc=`case_rc'"
}

**# F6: artifact regression
local ++test_count
local d "`sandbox'/F6"
local receipt "`sandbox'/receipt.txt"
local size = 0
capture noisily {
    clear
    shell "`python'" "`tool'" setup F6 "`d'" "`receipt'"
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
    logdoc start, output("`d'/out.html") replace quiet
    display "SESSION_TEXT_119"
    logdoc stop
    local transcript `"$LOGDOC_LAST_INPUT"'
    confirm file "`transcript'"
    logdoc replay, theme(dark)
    assert "`r(theme)'" == "dark"
    confirm file "`transcript'"
    shell "`python'" "`tool'" verify F6 "`d'" "`receipt'" --size `size'
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
    capture noisily logdoc using "`d'/missing.log", output("`d'/failed.html") replace quiet
    local child_rc = _rc
    assert `child_rc' == 601
    confirm file "`transcript'"
    assert `"$LOGDOC_LAST_INPUT"' == `"`transcript'"'
    logdoc using "`d'/a.log", output("`d'/next.html") replace quiet
    capture confirm file "`transcript'"
    local exists_rc = _rc
    assert `exists_rc' == 601
    assert `"$LOGDOC_SESSION_INPUT"' == ""
}
local case_rc = _rc
capture file close `fh'
capture cd "`qadir'"
if `case_rc' == 0 {
    local ++pass
    display as result "PASS: F6"
}
else {
    local ++fail
    display as error "FAIL: F6 rc=`case_rc'"
}

**# F7: artifact regression
local ++test_count
local d "`sandbox'/F7"
local receipt "`sandbox'/receipt.txt"
local size = 0
capture noisily {
    clear
    shell "`python'" "`tool'" setup F7 "`d'" "`receipt'"
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
    logdoc_py, set python("`python'")
    local selected `"$LOGDOC_PYTHON"'
    assert `"`selected'"' == `"`python'"'
    logdoc start, output("`d'/out.html") replace quiet
    assert `"$LOGDOC_PYTHON"' == `"`selected'"'
    display "PYTHON_SELECTION"
    logdoc stop
    assert `"$LOGDOC_PYTHON"' == `"`selected'"'
    logdoc_py
    assert `"`r(python)'"' == `"`selected'"' 
}
local case_rc = _rc
capture file close `fh'
capture cd "`qadir'"
if `case_rc' == 0 {
    local ++pass
    display as result "PASS: F7"
}
else {
    local ++fail
    display as error "FAIL: F7 rc=`case_rc'"
}

**# F8: artifact regression
local ++test_count
local d "`sandbox'/F8"
local receipt "`sandbox'/receipt.txt"
local size = 0
capture noisily {
    clear
    shell "`python'" "`tool'" setup F8 "`d'" "`receipt'"
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
    logdoc combine using "`d'/a.log" "`d'/b.log", output("`d'/out") format(both) replace quiet
    assert `"`r(output)'"' == `"`d'/out.html"'
    assert `"`r(secondary)'"' == `"`d'/out.md"'
    confirm file `"`r(output)'"' 
    shell "`python'" "`tool'" verify F8 "`d'" "`receipt'" --size `size'
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
}
local case_rc = _rc
capture file close `fh'
capture cd "`qadir'"
if `case_rc' == 0 {
    local ++pass
    display as result "PASS: F8"
}
else {
    local ++fail
    display as error "FAIL: F8 rc=`case_rc'"
}

**# F9-docx: artifact regression
local ++test_count
local d "`sandbox'/F9-docx"
local receipt "`sandbox'/receipt.txt"
local size = 0
capture noisily {
    clear
    shell "`python'" "`tool'" setup F9-docx "`d'" "`receipt'"
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
    logdoc using "`d'/a.log", output("`d'/out.docx") format(docx) replace quiet
    local size = r(filesize)
    shell "`python'" "`tool'" verify F9-docx "`d'" "`receipt'" --size `size'
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
}
local case_rc = _rc
capture file close `fh'
capture cd "`qadir'"
if `case_rc' == 0 {
    local ++pass
    display as result "PASS: F9-docx"
}
else {
    local ++fail
    display as error "FAIL: F9-docx rc=`case_rc'"
}

**# F9-pdf: artifact regression
local ++test_count
local d "`sandbox'/F9-pdf"
local receipt "`sandbox'/receipt.txt"
local size = 0
capture noisily {
    clear
    shell "`python'" "`tool'" setup F9-pdf "`d'" "`receipt'"
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
    logdoc using "`d'/a.log", output("`d'/out.pdf") format(pdf) replace quiet
    local size = r(filesize)
    shell "`python'" "`tool'" verify F9-pdf "`d'" "`receipt'" --size `size'
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
}
local case_rc = _rc
capture file close `fh'
capture cd "`qadir'"
if `case_rc' == 0 {
    local ++pass
    display as result "PASS: F9-pdf"
}
else {
    local ++fail
    display as error "FAIL: F9-pdf rc=`case_rc'"
}

**# session_graph: artifact regression
local ++test_count
local d "`sandbox'/session_graph"
local receipt "`sandbox'/receipt.txt"
local size = 0
capture noisily {
    clear
    shell "`python'" "`tool'" setup session_graph "`d'" "`receipt'"
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
    cd "`d'"
    logdoc start, output("`d'/out.html") replace quiet
    sysuse auto, clear
    scatter price mpg
    graph export graph.svg, replace
    cd "`qadir'"
    logdoc stop
    assert r(ngraphs) == 1
    logdoc replay, theme(dark)
    assert r(ngraphs) == 1
    shell "`python'" "`tool'" verify session_graph "`d'" "`receipt'" --size `size'
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
}
local case_rc = _rc
capture file close `fh'
capture cd "`qadir'"
if `case_rc' == 0 {
    local ++pass
    display as result "PASS: session_graph"
}
else {
    local ++fail
    display as error "FAIL: session_graph rc=`case_rc'"
}

**# run_graph: execution-directory guard
* guard: run_graph is expected green at pre-fix ref
local ++test_count
local d "`sandbox'/run_graph"
local receipt "`sandbox'/receipt.txt"
local size = 0
capture noisily {
    clear
    shell "`python'" "`tool'" setup run_graph "`d'" "`receipt'"
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
    cd "`d'"
    logdoc using "`d'/run.do", output("`d'/out.html") run replace quiet
    assert r(ngraphs) == 1
    shell "`python'" "`tool'" verify run_graph "`d'" "`receipt'" --size `size'
    file open `fh' using "`receipt'", read text
    file read `fh' result
    file close `fh'
    assert "`result'" == "PASS"
}
local case_rc = _rc
capture file close `fh'
capture cd "`qadir'"
if `case_rc' == 0 {
    local ++pass
    display as result "PASS: run_graph"
}
else {
    local ++fail
    display as error "FAIL: run_graph rc=`case_rc'"
}

sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
capture log close _all
display as text "RESULT: test_logdoc_v119 tests=`test_count' pass=`pass' fail=`fail'"
if `fail' exit 1
