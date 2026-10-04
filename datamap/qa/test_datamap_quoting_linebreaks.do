clear all
set more off
version 16.0
set linesize 255

* test_datamap_quoting_linebreaks.do - compound quotes and line breaks in
* user text, across datacheck, its call-error ledger row, dataqa, and the
* datamap text map.
* E  a failing datacheck call writes its call-error row whatever the quoting
*    (E5: a passing call keeps a compound-quoted run() label, once stored empty)
*    of ledger(), run(), name() and the rest of the line (the writer stopped
*    with r(132) on a compound quote, so dataqa assert passed over the call)
* P  rule()/review()/byrule() written in compound quotes parse exactly like
*    the plain form (r(132)/r(109) before), and malformed forms are refused
*    with a message, never r(132)
* D  dataqa assert prints a stored message as text: no SMCL, macro or quote
*    character in it is live
* L  a line break in a variable, value or dataset label or a string value
*    never breaks a line of the datamap text map
* Oracles: count if on the fixture, the command text as typed (built in Mata
* from char() codes), the plain-form result as the twin of each quoted form,
* and the map of the same data with every line break written as a space.

* === Bootstrap: targeted local reinstall ===
local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard
macro drop DATAMAP_DQ

local tests 0
local pass 0
local fail 0

local W "`c(tmpdir)'/qalb_`=c(pid)'"
capture mkdir "`W'"

* compound-quote characters, so the oracles never contain a literal one
local LQ = char(96) + char(34)
local RQ = char(34) + char(39)

* the rows of a ledger as one string per row: family label status observed
* expected n_scope, for comparing two runs of the same gates
capture program drop _lb_rows
program define _lb_rows, rclass
    args file
    preserve
    quietly use `"`file'"', clear
    quietly generate strL _r = family + "|" + label + "|" + variable + "|" + ///
        status + "|" + observed + "|" + expected + "|" + string(n_scope)
    mata: st_local("rows", invtokens(st_sdata(., "_r")', char(10)))
    return local rows `"`macval(rows)'"'
    return scalar N = _N
    restore
end

* the lines of a text file, skipping lines that start with a given prefix
capture program drop _lb_lines
program define _lb_lines, rclass
    args file
    mata: _lb_f = cat(st_local("file")); ///
        _lb_k = !(strpos(_lb_f, "Generated:") :== 1 :| strpos(_lb_f, "Data Signature:") :== 1); ///
        st_local("txt", invtokens(select(_lb_f, _lb_k)', char(10))); ///
        st_local("n", strofreal(rows(_lb_f)))
    return local txt `"`macval(txt)'"'
    return scalar n = `n'
end

**# E1 body failure, compound-quoted ledger, run and name
local ++tests
capture noisily {
    sysuse auto, clear
    local L "`W'/e1 ledger.dta"
    capture erase "`L'"
    quietly datasignature
    local sig0 "`r(datasignature)'"
    local va0 = c(varabbrev)
    capture noisily datacheck, gatesonly notmissing(nosuchvar) ledger(`"`L'"', run(`"r 1"')) name(`"my data"')
    assert _rc == 111
    quietly datasignature
    assert "`r(datasignature)'" == "`sig0'"
    assert c(varabbrev) == "`va0'"
    preserve
    quietly use "`L'", clear
    assert _N == 1
    assert family == "call" & status == "error" & kind == "invariant"
    assert observed_num == 111 & observed == "rc 111"
    assert run == "r 1"
    assert dataset == "my data"
    * the message is the command text exactly as typed
    mata: st_local("ok", strofreal(st_sdata(1, "message") == ///
        "datacheck call exited with rc 111: datacheck , gatesonly notmissing(nosuchvar) ledger(" + ///
        st_local("LQ") + st_local("L") + st_local("RQ") + ", run(" + st_local("LQ") + "r 1" + ///
        st_local("RQ") + ")) name(" + st_local("LQ") + "my data" + st_local("RQ") + ")"))
    assert `ok' == 1
    restore
}
local rc = _rc
capture restore
if `rc' {
    local ++fail
    display as error "FAIL: E1 body failure with compound-quoted ledger() rc=`rc'"
}
else {
    local ++pass
    display as result "PASS: E1 body failure with compound-quoted ledger()"
}

**# E2 syntax failure: ledger, run and name read back from the raw line
local ++tests
capture noisily {
    sysuse auto, clear
    local L "`W'/e2.dta"
    capture erase "`L'"
    capture noisily datacheck, gatesonly notanoption ledger(`"`L'"', run(`"z w"')) name(`"x y"')
    assert _rc == 198
    preserve
    quietly use "`L'", clear
    assert _N == 1
    assert status == "error" & observed_num == 198
    assert run == "z w"
    assert dataset == "x y"
    assert strpos(message, "notanoption") > 0
    restore
    * a plain-quoted twin gives the same row
    local L2 "`W'/e2b.dta"
    capture erase "`L2'"
    capture noisily datacheck, gatesonly notanoption ledger("`L2'", run("z w")) name("x y")
    assert _rc == 198
    preserve
    quietly use "`L2'", clear
    assert _N == 1 & run == "z w" & dataset == "x y" & observed_num == 198
    restore
}
local rc = _rc
capture restore
if `rc' {
    local ++fail
    display as error "FAIL: E2 syntax failure reads compound-quoted options back rc=`rc'"
}
else {
    local ++pass
    display as result "PASS: E2 syntax failure reads compound-quoted options back"
}

**# E3 a compound-quoted rule() naming a missing variable
local ++tests
capture noisily {
    sysuse auto, clear
    local L "`W'/e3.dta"
    capture erase "`L'"
    capture noisily datacheck, gatesonly rule(`"heavy: nosuch > 1"') ledger("`L'")
    assert _rc == 111
    preserve
    quietly use "`L'", clear
    assert _N == 1 & status == "error" & observed_num == 111
    mata: st_local("ok", strofreal(strpos(st_sdata(1, "message"), "rule(" + st_local("LQ") + ///
        "heavy: nosuch > 1" + st_local("RQ") + ")") > 0))
    assert `ok' == 1
    restore
}
local rc = _rc
capture restore
if `rc' {
    local ++fail
    display as error "FAIL: E3 compound-quoted rule() with a missing variable rc=`rc'"
}
else {
    local ++pass
    display as result "PASS: E3 compound-quoted rule() with a missing variable"
}

**# E4 the session ledger takes the row of a compound-quoted failing call
local ++tests
capture noisily {
    sysuse auto, clear
    local L "`W'/e4.dta"
    capture erase "`L'"
    dataqa set ledger("`L'") run(s4)
    capture noisily datacheck, gatesonly isid(nosuch) name(`"sess data"')
    local rc1 = _rc
    dataqa set clear
    assert `rc1' == 111
    preserve
    quietly use "`L'", clear
    assert _N == 1 & status == "error" & run == "s4" & dataset == "sess data"
    restore
}
local rc = _rc
capture restore
capture dataqa set clear
if `rc' {
    local ++fail
    display as error "FAIL: E4 session ledger row for a compound-quoted call rc=`rc'"
}
else {
    local ++pass
    display as result "PASS: E4 session ledger row for a compound-quoted call"
}

**# E5 a passing call keeps a compound-quoted run() label (it was stored empty)
local ++tests
capture noisily {
    sysuse auto, clear
    local L "`W'/e5.dta"
    capture erase "`L'"
    datacheck, gatesonly isid(make) ledger(`"`L'"', run(`"r 5"')) name(auto)
    datacheck, gatesonly isid(make) ledger(`"`L'"', run(r5plain)) name(auto)
    preserve
    quietly use "`L'", clear
    assert _N == 2
    assert run[1] == "r 5" & run[2] == "r5plain"
    restore
    dataqa assert using "`L'", run(r 5)
    assert r(N) == 1 & r(n_failed) == 0
}
local rc = _rc
capture restore
if `rc' {
    local ++fail
    display as error "FAIL: E5 compound-quoted run() kept on a passing call rc=`rc'"
}
else {
    local ++pass
    display as result "PASS: E5 compound-quoted run() kept on a passing call"
}

**# D1 dataqa assert prints SMCL, $ and quotes in messages as text
local ++tests
capture noisily {
    sysuse auto, clear
    local L "`W'/d1.dta"
    capture erase "`L'"
    * a failing gate whose label carries SMCL, then a failing call whose
    * command text carries braces, a dollar sign and a quoted literal
    capture noisily datacheck, gatesonly rule("{bf:heavy}": weight < 2000) ledger("`L'", run(d)) name(auto)
    assert _rc == 9
    * \$ keeps the do-file from expanding $y; datacheck receives a literal $
    capture noisily datacheck, gatesonly rule(`"lit: make != "{x}\$y""') notmissing(nosuch) ledger("`L'", run(d)) name(auto2)
    assert _rc == 111
    preserve
    quietly use "`L'", clear
    quietly count if status == "error"
    assert r(N) == 1
    quietly count if status == "fail"
    assert r(N) == 1
    * the stored text is literal
    quietly count if strpos(message, "rule({bf:heavy})") == 1
    assert r(N) == 1
    quietly count if strpos(message, "make != " + char(34) + "{x}" + char(36) + "y" + char(34)) > 0
    assert r(N) == 1
    restore
    tempfile lg
    log using "`lg'", text replace name(d1log)
    capture noisily dataqa assert using "`L'", run(d)
    local arc = _rc
    local nf = r(n_failed)
    local ne = r(n_errors)
    log close d1log
    assert `arc' == 9
    assert `nf' == 2 & `ne' == 1
    mata: _lb_t = cat(st_local("lg")); ///
        st_local("n1", strofreal(sum(strpos(_lb_t, "auto: rule({bf:heavy}): ") :> 0))); ///
        st_local("n2", strofreal(sum(strpos(_lb_t, "make != " + char(34) + "{x}" + char(36) + "y" + char(34)) :> 0)))
    * the log of the display, as printed: once each, with the braces intact
    assert `n1' == 1
    assert `n2' == 1
}
local rc = _rc
capture restore
capture log close d1log
if `rc' {
    local ++fail
    display as error "FAIL: D1 dataqa assert prints messages as text rc=`rc'"
}
else {
    local ++pass
    display as result "PASS: D1 dataqa assert prints messages as text"
}

**# P1 rule(): compound-quoted forms are the plain form's twins
local ++tests
capture noisily {
    sysuse auto, clear
    quietly count if !(price > 5000)
    local nb = r(N)
    assert `nb' >= 1 & `nb' < 74
    local k = 0
    foreach form in plain whole entry qlabel {
        local ++k
        local L`k' "`W'/p1_`form'.dta"
        capture erase "`L`k''"
        if "`form'" == "plain" capture noisily datacheck, gatesonly rule(a: make != "" \ b: price > 5000) ledger("`L`k''")
        if "`form'" == "whole" capture noisily datacheck, gatesonly rule(`"a: make != "" \ b: price > 5000"') ledger("`L`k''")
        if "`form'" == "entry" capture noisily datacheck, gatesonly rule(`"a: make != """' \ `"b: price > 5000"') ledger("`L`k''")
        if "`form'" == "qlabel" capture noisily datacheck, gatesonly rule(`""a": make != "" \ "b": price > 5000"') ledger("`L`k''")
        assert _rc == 9
        assert r(n_failed) == 1
        _lb_rows "`L`k''"
        assert r(N) == 2
        local rows`k' `"`r(rows)'"'
    }
    forvalues j = 2/4 {
        assert `"`rows`j''"' == `"`rows1'"'
    }
    preserve
    quietly use "`L1'", clear
    assert label[1] == "a" & status[1] == "pass"
    assert label[2] == "b" & status[2] == "fail"
    assert observed_num[2] == `nb'
    restore
}
local rc = _rc
capture restore
if `rc' {
    local ++fail
    display as error "FAIL: P1 compound-quoted rule() forms match the plain form rc=`rc'"
}
else {
    local ++pass
    display as result "PASS: P1 compound-quoted rule() forms match the plain form"
}

**# P2 review() and byrule(): compound-quoted twins
local ++tests
capture noisily {
    sysuse auto, clear
    quietly count if strpos(make, "AMC") == 1
    local namc = r(N)
    assert `namc' == 3
    local La "`W'/p2a.dta"
    local Lb "`W'/p2b.dta"
    capture erase "`La'"
    capture erase "`Lb'"
    datacheck, gatesonly review(amc: strpos(make, "AMC") == 1) ///
        byrule(foreign (price): "ord": make != "" & price >= price[_n-1] | _n == 1) ledger("`La'")
    datacheck, gatesonly review(`"amc: strpos(make, "AMC") == 1"') ///
        byrule(`"foreign (price): "ord": make != "" & price >= price[_n-1] | _n == 1"') ledger("`Lb'")
    _lb_rows "`La'"
    local ra `"`r(rows)'"'
    assert r(N) == 2
    _lb_rows "`Lb'"
    assert `"`r(rows)'"' == `"`ra'"'
    preserve
    quietly use "`Lb'", clear
    quietly count if family == "review" & observed_num == `namc'
    assert r(N) == 1
    quietly count if family == "byrule" & status == "pass" & label == "ord"
    assert r(N) == 1
    restore
}
local rc = _rc
capture restore
if `rc' {
    local ++fail
    display as error "FAIL: P2 compound-quoted review()/byrule() match the plain form rc=`rc'"
}
else {
    local ++pass
    display as result "PASS: P2 compound-quoted review()/byrule() match the plain form"
}

**# P3 malformed quoting is refused with a message, never r(132)
local ++tests
capture noisily {
    sysuse auto, clear
    tempfile lg
    log using "`lg'", text replace name(p3log)
    * a byrule spec quoted as a whole
    capture noisily datacheck, gatesonly byrule("foreign (price): ord: _n >= 1")
    local r1 = _rc
    * a wrapper that swallows the label's opening quote
    capture noisily datacheck, gatesonly rule(`"heavy": weight > 1"')
    local r2 = _rc
    capture noisily datacheck, gatesonly review(`"cheap": price < 4000"')
    local r3 = _rc
    log close p3log
    assert `r1' == 198 & `r2' == 198 & `r3' == 198
    mata: _lb_t = cat(st_local("lg")); ///
        st_local("n1", strofreal(sum(strpos(_lb_t, "with only the label in quotes") :> 0))); ///
        st_local("n2", strofreal(sum(strpos(_lb_t, "label must not contain quotes or backticks") :> 0))); ///
        st_local("n3", strofreal(sum(strpos(_lb_t, "too few quotes") :> 0 :| strpos(_lb_t, "could not be written") :> 0)))
    assert `n1' == 1
    assert `n2' == 2
    assert `n3' == 0
}
local rc = _rc
capture restore
capture log close p3log
if `rc' {
    local ++fail
    display as error "FAIL: P3 malformed quoting refused with a message rc=`rc'"
}
else {
    local ++pass
    display as result "PASS: P3 malformed quoting refused with a message"
}

**# L1 line breaks in labels and values never break a line of the text map
local ++tests
capture noisily {
    foreach v in nl sp {
        local br = cond("`v'" == "nl", char(10), " ")
        local crlf = cond("`v'" == "nl", char(13) + char(10), " ")
        clear
        quietly set obs 12
        quietly generate x = mod(_n, 2) + 1
        label variable x "first`br'second"
        label define xl 1 "one`crlf'uno" 2 "two`=cond("`v'" == "nl", char(13), " ")'dos"
        label values x xl
        quietly generate str5 s = "a`br'b" if _n <= 6
        quietly replace s = "c`br'd" if _n > 6
        label data "data`br'set"
        datamap, output("`W'/l1_`v'.txt") samples(3)
    }
    _lb_lines "`W'/l1_nl.txt"
    local tnl `"`r(txt)'"'
    local nnl = r(n)
    _lb_lines "`W'/l1_sp.txt"
    local tsp `"`r(txt)'"'
    assert `nnl' == r(n)
    * the map of the data with line breaks is the map with spaces, line for line
    assert `"`macval(tnl)'"' == `"`macval(tsp)'"'
    mata: _lb_t = cat(st_local("W") + "/l1_nl.txt"); ///
        st_local("k1", strofreal(sum(strpos(_lb_t, "Label: first second") :> 0))); ///
        st_local("k2", strofreal(sum(_lb_t :== "second" :| _lb_t :== "uno" :| _lb_t :== "dos"))); ///
        st_local("k3", strofreal(sum(strpos(_lb_t, "1 = one uno") :> 0)))
    assert `k1' >= 1 & `k2' == 0 & `k3' >= 1
    * JSON keeps its own escape, \n
    clear
    quietly set obs 3
    quietly generate x = _n
    label variable x "first`=char(10)'second"
    datamap, output("`W'/l1.json") format(json)
    mata: _lb_t = cat(st_local("W") + "/l1.json"); ///
        st_local("k4", strofreal(sum(strpos(_lb_t, "first" + char(92) + "nsecond") :> 0)))
    assert `k4' >= 1
}
local rc = _rc
capture restore
if `rc' {
    local ++fail
    display as error "FAIL: L1 line breaks in labels and values in the text map rc=`rc'"
}
else {
    local ++pass
    display as result "PASS: L1 line breaks in labels and values in the text map"
}

* tidy
capture mata: mata drop _lb_f _lb_k _lb_t
local files : dir "`W'" files "*"
foreach f of local files {
    capture erase "`W'/`f'"
}
capture rmdir "`W'"

display "RESULT: test_datamap_quoting_linebreaks tests=`tests' pass=`pass' fail=`fail'"
if `fail' exit 1
