*! test_datamap_v171.do Version 1.0.0  2026/09/29
*! Known-answer regressions for review F01-F08 and M01
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
capture log close _all
log using "test_datamap_v171.log", replace text
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
tempfile base
local work "`base'_work"
quietly mkdir "`work'"
quietly mkdir "`work'/plus"
quietly mkdir "`work'/personal"
local oldplus : sysdir PLUS
local oldpersonal : sysdir PERSONAL
sysdir set PLUS "`work'/plus"
sysdir set PERSONAL "`work'/personal"
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace
discard
do "`c(pwd)'/_qa_state.do"
do "`c(pwd)'/_qa_hostile.do"
do "`c(pwd)'/_qa_parity.do"
local tests = 0
local pass = 0
local fail = 0

**## F01 memory %td metadata privacy
local ++tests
capture noisily {
clear
set obs 6
gen double dob = 20000 + _n
format dob %td
gen double age = 40 + _n
save "`work'/source.dta", replace

datamap,  datesafe output("`work'/private.txt") saving("`work'/meta.dta", replace)
use "`work'/meta.dta", clear
assert class == "date" if variable == "dob"
assert missing(mean, sd, p50, p25, p75, min, max) if variable == "dob"
assert min == 41 & max == 46 if variable == "age"
quietly count if variable == "dob"
assert r(N) == 1
quietly summarize min if variable == "dob"
qa_surface_parity, expect(withheld) result(r(min)) ///
    log("`work'/private.txt") logregex("Earliest:")
qa_surface_parity, expect(withheld) log("`work'/private.txt") logregex("Latest:")
}
local rc = _rc
capture file close _all
capture log close cfglog
capture log close directlog
capture log close fallback
if `rc' {
    local ++fail
    display as error "FAIL: F01 memory %td metadata privacy (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F01 memory %td metadata privacy"
}

**## F01 memory %tc metadata privacy
local ++tests
capture noisily {
clear
set obs 6
gen double dob = 1700000000000 + 1000*_n
format dob %tc
gen double age = 40 + _n
save "`work'/source.dta", replace

datamap,  datesafe output("`work'/private.txt") saving("`work'/meta.dta", replace)
use "`work'/meta.dta", clear
assert class == "date" if variable == "dob"
assert missing(mean, sd, p50, p25, p75, min, max) if variable == "dob"
assert min == 41 & max == 46 if variable == "age"
quietly count if variable == "dob"
assert r(N) == 1
quietly summarize min if variable == "dob"
qa_surface_parity, expect(withheld) result(r(min)) ///
    log("`work'/private.txt") logregex("Earliest:")
qa_surface_parity, expect(withheld) log("`work'/private.txt") logregex("Latest:")
}
local rc = _rc
capture file close _all
capture log close cfglog
capture log close directlog
capture log close fallback
if `rc' {
    local ++fail
    display as error "FAIL: F01 memory %tc metadata privacy (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F01 memory %tc metadata privacy"
}

**## F01 single %td metadata privacy
local ++tests
capture noisily {
clear
set obs 6
gen double dob = 20000 + _n
format dob %td
gen double age = 40 + _n
save "`work'/source.dta", replace
clear
datamap, single("`work'/source.dta") datesafe output("`work'/private.txt") saving("`work'/meta.dta", replace)
use "`work'/meta.dta", clear
assert class == "date" if variable == "dob"
assert missing(mean, sd, p50, p25, p75, min, max) if variable == "dob"
assert min == 41 & max == 46 if variable == "age"
quietly count if variable == "dob"
assert r(N) == 1
quietly summarize min if variable == "dob"
qa_surface_parity, expect(withheld) result(r(min)) ///
    log("`work'/private.txt") logregex("Earliest:")
qa_surface_parity, expect(withheld) log("`work'/private.txt") logregex("Latest:")
}
local rc = _rc
capture file close _all
capture log close cfglog
capture log close directlog
capture log close fallback
if `rc' {
    local ++fail
    display as error "FAIL: F01 single %td metadata privacy (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F01 single %td metadata privacy"
}

**## F01 single %tc metadata privacy
local ++tests
capture noisily {
clear
set obs 6
gen double dob = 1700000000000 + 1000*_n
format dob %tc
gen double age = 40 + _n
save "`work'/source.dta", replace
clear
datamap, single("`work'/source.dta") datesafe output("`work'/private.txt") saving("`work'/meta.dta", replace)
use "`work'/meta.dta", clear
assert class == "date" if variable == "dob"
assert missing(mean, sd, p50, p25, p75, min, max) if variable == "dob"
assert min == 41 & max == 46 if variable == "age"
quietly count if variable == "dob"
assert r(N) == 1
quietly summarize min if variable == "dob"
qa_surface_parity, expect(withheld) result(r(min)) ///
    log("`work'/private.txt") logregex("Earliest:")
qa_surface_parity, expect(withheld) log("`work'/private.txt") logregex("Latest:")
}
local rc = _rc
capture file close _all
capture log close cfglog
capture log close directlog
capture log close fallback
if `rc' {
    local ++fail
    display as error "FAIL: F01 single %tc metadata privacy (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F01 single %tc metadata privacy"
}

**## F02 exact double categories labeled=False
local ++tests
capture noisily {
clear
set obs 12
qa_hostile_times
local down "`r(down)'"
gen double x = cond(_n <= 6, `down', .54321098765432109)
format x %21.17g

datadict, categorical(x) mincell(0) stats output("`work'/double.md")
file open rd using "`work'/double.md", read text
local matches = 0
file read rd line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "Unique=2") {
        local matches = 1
        assert strpos(`"`macval(line)'"', "(0;") == 0
        local both = subinstr(`"`macval(line)'"', "(6; 50.0%)", "", .)
        assert strlen(`"`macval(line)'"') - strlen(`"`macval(both)'"') == 20
    }
    file read rd line
}
file close rd
assert `matches' == 1
}
local rc = _rc
capture file close _all
capture log close cfglog
capture log close directlog
capture log close fallback
if `rc' {
    local ++fail
    display as error "FAIL: F02 exact double categories labeled=False (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F02 exact double categories labeled=False"
}

**## F02 exact double categories labeled=True
local ++tests
capture noisily {
clear
set obs 12
qa_hostile_times
local down "`r(down)'"
gen double x = cond(_n <= 6, `down', .54321098765432109)
format x %21.17g
label define cats 1 "unused"
label values x cats
datadict, categorical(x) mincell(0) stats output("`work'/double.md")
file open rd using "`work'/double.md", read text
local matches = 0
file read rd line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "Unique=2") {
        local matches = 1
        assert strpos(`"`macval(line)'"', "(0;") == 0
        local both = subinstr(`"`macval(line)'"', "(6; 50.0%)", "", .)
        assert strlen(`"`macval(line)'"') - strlen(`"`macval(both)'"') == 20
    }
    file read rd line
}
file close rd
assert `matches' == 1
}
local rc = _rc
capture file close _all
capture log close cfglog
capture log close directlog
capture log close fallback
if `rc' {
    local ++fail
    display as error "FAIL: F02 exact double categories labeled=True (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F02 exact double categories labeled=True"
}

**## F03 filelist same-basename preflight
local ++tests
capture noisily {
clear
set obs 2
gen x = _n
capture mkdir "`work'/a"
capture mkdir "`work'/b"
capture mkdir "`work'/out"
save "`work'/a/cohort.dta", replace
rename x other
save "`work'/b/cohort.dta", replace
file open sentinel using "`work'/out/cohort_dictionary.md", write text replace
file write sentinel "existing sentinel" _n
file close sentinel
capture noisily datadict, filelist("`work'/a/cohort.dta `work'/b/cohort.dta") separate outdir("`work'/out")
local rc = _rc
assert `rc' == 198
file open rd using "`work'/out/cohort_dictionary.md", read text
file read rd line
file close rd
assert `"`macval(line)'"' == "existing sentinel"
assert other == _n
}
local rc = _rc
capture file close _all
capture log close cfglog
capture log close directlog
capture log close fallback
if `rc' {
    local ++fail
    display as error "FAIL: F03 filelist same-basename preflight (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F03 filelist same-basename preflight"
}

**## F03 directory same-basename preflight
local ++tests
capture noisily {
clear
set obs 2
gen x = _n
capture mkdir "`work'/a"
capture mkdir "`work'/b"
capture mkdir "`work'/out"
save "`work'/a/cohort.dta", replace
rename x other
save "`work'/b/cohort.dta", replace
file open sentinel using "`work'/out/cohort_dictionary.md", write text replace
file write sentinel "existing sentinel" _n
file close sentinel
capture noisily datadict, directory("`work'") recursive separate outdir("`work'/out")
local rc = _rc
assert `rc' == 198
file open rd using "`work'/out/cohort_dictionary.md", read text
file read rd line
file close rd
assert `"`macval(line)'"' == "existing sentinel"
assert other == _n
}
local rc = _rc
capture file close _all
capture log close cfglog
capture log close directlog
capture log close fallback
if `rc' {
    local ++fail
    display as error "FAIL: F03 directory same-basename preflight (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F03 directory same-basename preflight"
}

**## F04 single by deferred input binding
local ++tests
capture noisily {
clear
set obs 4
gen site = cond(_n <= 2, 1, 2)
gen x = _n
save "`work'/groups.dta", replace
clear
set obs 3
gen caller = 42
set varabbrev on
datacheck, single("`work'/groups.dta") by(site) expectn(2) warn
assert r(n_groups) == 2 & r(n_failed) == 0
assert c(varabbrev) == "on"
assert _N == 3 & caller == 42
}
local rc = _rc
capture file close _all
capture log close cfglog
capture log close directlog
capture log close fallback
if `rc' {
    local ++fail
    display as error "FAIL: F04 single by deferred input binding (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F04 single by deferred input binding"
}

**## F04 single over deferred input binding
local ++tests
capture noisily {
clear
set obs 4
gen site = cond(_n <= 2, 1, 2)
gen x = _n
save "`work'/groups.dta", replace
clear
set obs 3
gen caller = 42
set varabbrev on
datacheck, single("`work'/groups.dta") over(site) expectn(2) warn
assert r(n_groups) == 2 & r(n_failed) == 0
assert c(varabbrev) == "on"
assert _N == 3 & caller == 42
}
local rc = _rc
capture file close _all
capture log close cfglog
capture log close directlog
capture log close fallback
if `rc' {
    local ++fail
    display as error "FAIL: F04 single over deferred input binding (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F04 single over deferred input binding"
}

**## F05 complete-data sort returns
local ++tests
capture noisily {
clear
set obs 4
gen x = _n
datamvp x, sort
assert r(N) == 4 & r(N_complete) == 4 & r(N_incomplete) == 0
assert r(N_patterns) == 1 & r(N_vars) == 0 & r(N_mv_total) == 0
assert "`r(varlist_nomiss)'" == "x"
assert x == _n
}
local rc = _rc
capture file close _all
capture log close cfglog
capture log close directlog
capture log close fallback
if `rc' {
    local ++fail
    display as error "FAIL: F05 complete-data sort returns (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F05 complete-data sort returns"
}

**## F06 all pattern scratch collisions
local ++tests
capture noisily {
clear
set obs 4
gen x = cond(_n == 1, ., _n)
foreach v in _pattern _miss _freq _pct _cumpct {
    gen `v' = 123 + _n
}
datamvp x, percent cumulative
assert r(N) == 4 & r(N_patterns) == 2 & r(N_mv_total) == 1
foreach v in _pattern _miss _freq _pct _cumpct {
    assert `v' == 123 + _n
}
assert missing(x) if _n == 1
assert x == _n if _n > 1
}
local rc = _rc
capture file close _all
capture log close cfglog
capture log close directlog
capture log close fallback
if `rc' {
    local ++fail
    display as error "FAIL: F06 all pattern scratch collisions (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F06 all pattern scratch collisions"
}

**## F07 caller __f
local ++tests
capture noisily {
clear
set obs 6
gen __f = mod(_n, 2)
datacheck __f,
assert r(N) == 6 & r(n_categorical) == 1

assert __f == mod(_n, 2)
}
local rc = _rc
capture file close _all
capture log close cfglog
capture log close directlog
capture log close fallback
if `rc' {
    local ++fail
    display as error "FAIL: F07 caller __f  (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F07 caller __f "
}

**## F07 caller __f rare(4)
local ++tests
capture noisily {
clear
set obs 6
gen __f = mod(_n, 2)
datacheck __f, rare(4)
assert r(N) == 6 & r(n_categorical) == 1
assert r(n_rare_vars) == 1
assert __f == mod(_n, 2)
}
local rc = _rc
capture file close _all
capture log close cfglog
capture log close directlog
capture log close fallback
if `rc' {
    local ++fail
    display as error "FAIL: F07 caller __f rare(4) (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F07 caller __f rare(4)"
}

**## F08 config gatesonly matches command line
local ++tests
capture noisily {
clear
set obs 10
gen x = _n
file open cfg using "`work'/flags.cfg", write text replace
file write cfg "gatesonly = yes" _n
file close cfg
log using "`work'/cfg.txt", name(cfglog) replace text
noisily datacheck, config("`work'/flags.cfg")
assert r(gatesonly) == 1
log close cfglog
log using "`work'/direct.txt", name(directlog) replace text
noisily datacheck, gatesonly
assert r(gatesonly) == 1
log close directlog
* Compare only profile/gate display, excluding command and log headers.
file open cr using "`work'/cfg.txt", read text
file open dr using "`work'/direct.txt", read text
local cfgbody ""
local dirbody ""
local copying = 0
file read cr line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "datacheck:") == 1 local copying = 1
    if substr(`"`macval(line)'"', 1, 2) == ". " local copying = 0
    if `copying' local cfgbody `"`macval(cfgbody)'`macval(line)'"'
    file read cr line
}
local copying = 0
file read dr line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "datacheck:") == 1 local copying = 1
    if substr(`"`macval(line)'"', 1, 2) == ". " local copying = 0
    if `copying' local dirbody `"`macval(dirbody)'`macval(line)'"'
    file read dr line
}
file close cr
file close dr
assert `"`macval(cfgbody)'"' != ""
assert `"`macval(cfgbody)'"' == `"`macval(dirbody)'"'
}
local rc = _rc
capture file close _all
capture log close cfglog
capture log close directlog
capture log close fallback
if `rc' {
    local ++fail
    display as error "FAIL: F08 config gatesonly matches command line (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F08 config gatesonly matches command line"
}

**## F08 config onlyflagged matches command line
local ++tests
capture noisily {
clear
set obs 10
gen x = _n
file open cfg using "`work'/flags.cfg", write text replace
file write cfg "onlyflagged = yes" _n
file close cfg
log using "`work'/cfg.txt", name(cfglog) replace text
noisily datacheck, config("`work'/flags.cfg")
assert r(onlyflagged) == 1
log close cfglog
log using "`work'/direct.txt", name(directlog) replace text
noisily datacheck, onlyflagged
assert r(onlyflagged) == 1
log close directlog
* Compare only profile/gate display, excluding command and log headers.
file open cr using "`work'/cfg.txt", read text
file open dr using "`work'/direct.txt", read text
local cfgbody ""
local dirbody ""
local copying = 0
file read cr line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "datacheck:") == 1 local copying = 1
    if substr(`"`macval(line)'"', 1, 2) == ". " local copying = 0
    if `copying' local cfgbody `"`macval(cfgbody)'`macval(line)'"'
    file read cr line
}
local copying = 0
file read dr line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "datacheck:") == 1 local copying = 1
    if substr(`"`macval(line)'"', 1, 2) == ". " local copying = 0
    if `copying' local dirbody `"`macval(dirbody)'`macval(line)'"'
    file read dr line
}
file close cr
file close dr
assert `"`macval(cfgbody)'"' != ""
assert `"`macval(cfgbody)'"' == `"`macval(dirbody)'"'
}
local rc = _rc
capture file close _all
capture log close cfglog
capture log close directlog
capture log close fallback
if `rc' {
    local ++fail
    display as error "FAIL: F08 config onlyflagged matches command line (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F08 config onlyflagged matches command line"
}

**## M01 tetrachoric failure diagnostic
local ++tests
capture noisily {
clear
set obs 8
gen x = .
gen y = cond(_n <= 4, ., _n)
log using "`work'/fallback.txt", name(fallback) replace text
datamvp x y, correlate
matrix C = r(corr_miss)
assert rowsof(C) == 2 & colsof(C) == 2
log close fallback
file open rd using "`work'/fallback.txt", read text
local found = 0
file read rd line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "tetrachoric failed (rc=") local found = 1
    assert strpos(`"`macval(line)'"', "tetrachoric not available") == 0
    file read rd line
}
file close rd
assert `found' == 1
}
local rc = _rc
capture file close _all
capture log close cfglog
capture log close directlog
capture log close fallback
if `rc' {
    local ++fail
    display as error "FAIL: M01 tetrachoric failure diagnostic (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: M01 tetrachoric failure diagnostic"
}

**## Caller fingerprint datamap success
local ++tests
capture noisily {
    clear
    set obs 12
    gen double x = cond(_n <= 3, ., _n)
    gen double y = _n + mod(_n, 2)
    quietly regress y x
    matrix corrmat = (7, 8)
    scalar __f = 99
    char _dta[user] "untouched"
    set varabbrev on
    qa_state_snapshot, tag(state) rreturn
    datamap , output("`work'/state.txt") saving("`work'/state.dta", replace)
    qa_state_compare, tag(state) allow(r)
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: datamap fingerprint success (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: datamap fingerprint success"
}

**## Caller fingerprint datamap error
local ++tests
capture noisily {
    clear
    set obs 12
    gen double x = cond(_n <= 3, ., _n)
    gen double y = _n + mod(_n, 2)
    quietly regress y x
    matrix corrmat = (7, 8)
    scalar __f = 99
    char _dta[user] "untouched"
    set varabbrev on
    qa_state_snapshot, tag(state) rreturn
    capture datamap, unknownoption
    assert _rc == 198
    qa_state_compare, tag(state) allow(r)
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: datamap fingerprint error (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: datamap fingerprint error"
}

**## Caller fingerprint datadict success
local ++tests
capture noisily {
    clear
    set obs 12
    gen double x = cond(_n <= 3, ., _n)
    gen double y = _n + mod(_n, 2)
    quietly regress y x
    matrix corrmat = (7, 8)
    scalar __f = 99
    char _dta[user] "untouched"
    set varabbrev on
    qa_state_snapshot, tag(state) rreturn
    datadict , output("`work'/state.md")
    qa_state_compare, tag(state) allow(r)
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: datadict fingerprint success (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: datadict fingerprint success"
}

**## Caller fingerprint datadict error
local ++tests
capture noisily {
    clear
    set obs 12
    gen double x = cond(_n <= 3, ., _n)
    gen double y = _n + mod(_n, 2)
    quietly regress y x
    matrix corrmat = (7, 8)
    scalar __f = 99
    char _dta[user] "untouched"
    set varabbrev on
    qa_state_snapshot, tag(state) rreturn
    capture datadict, unknownoption
    assert _rc == 198
    qa_state_compare, tag(state) allow(r)
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: datadict fingerprint error (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: datadict fingerprint error"
}

**## Caller fingerprint datacheck success
local ++tests
capture noisily {
    clear
    set obs 12
    gen double x = cond(_n <= 3, ., _n)
    gen double y = _n + mod(_n, 2)
    quietly regress y x
    matrix corrmat = (7, 8)
    scalar __f = 99
    char _dta[user] "untouched"
    set varabbrev on
    qa_state_snapshot, tag(state) rreturn
    datacheck x
    qa_state_compare, tag(state) allow(r)
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: datacheck fingerprint success (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: datacheck fingerprint success"
}

**## Caller fingerprint datacheck error
local ++tests
capture noisily {
    clear
    set obs 12
    gen double x = cond(_n <= 3, ., _n)
    gen double y = _n + mod(_n, 2)
    quietly regress y x
    matrix corrmat = (7, 8)
    scalar __f = 99
    char _dta[user] "untouched"
    set varabbrev on
    qa_state_snapshot, tag(state) rreturn
    capture datacheck, unknownoption
    assert _rc == 198
    qa_state_compare, tag(state) allow(r)
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: datacheck fingerprint error (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: datacheck fingerprint error"
}

**## Caller fingerprint datamvp success
local ++tests
capture noisily {
    clear
    set obs 12
    gen double x = cond(_n <= 3, ., _n)
    gen double y = _n + mod(_n, 2)
    quietly regress y x
    matrix corrmat = (7, 8)
    scalar __f = 99
    char _dta[user] "untouched"
    set varabbrev on
    qa_state_snapshot, tag(state) rreturn
    datamvp x
    qa_state_compare, tag(state) allow(r)
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: datamvp fingerprint success (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: datamvp fingerprint success"
}

**## Caller fingerprint datamvp error
local ++tests
capture noisily {
    clear
    set obs 12
    gen double x = cond(_n <= 3, ., _n)
    gen double y = _n + mod(_n, 2)
    quietly regress y x
    matrix corrmat = (7, 8)
    scalar __f = 99
    char _dta[user] "untouched"
    set varabbrev on
    qa_state_snapshot, tag(state) rreturn
    capture datamvp, unknownoption
    assert _rc == 198
    qa_state_compare, tag(state) allow(r)
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: datamvp fingerprint error (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: datamvp fingerprint error"
}

**## Caller fingerprint datamap JSON
local ++tests
capture noisily {
    clear
    set obs 12
    gen double x = cond(_n <= 3, ., _n)
    gen double y = _n + mod(_n, 2)
    quietly regress y x
    matrix corrmat = (7, 8)
    scalar __f = 99
    char _dta[user] "untouched"
    set varabbrev on
    save "`work'/state-input.dta", replace
    qa_state_snapshot, tag(state) rreturn
    datamap, format(json) output("`work'/state.json")
    qa_state_compare, tag(state) allow(r)
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: datamap fingerprint JSON (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: datamap fingerprint JSON"
}

**## Caller fingerprint datamap separate
local ++tests
capture noisily {
    clear
    set obs 12
    gen double x = cond(_n <= 3, ., _n)
    gen double y = _n + mod(_n, 2)
    quietly regress y x
    matrix corrmat = (7, 8)
    scalar __f = 99
    char _dta[user] "untouched"
    set varabbrev on
    local caller_cwd "`c(pwd)'"
    cd "`work'"
    capture erase "memory_map.txt"
    file open seed using "memory_map.txt", write text replace
    file close seed
    save "`work'/state-input.dta", replace
    qa_state_snapshot, tag(state) rreturn
    datamap, separate
    qa_state_compare, tag(state) allow(r)
    cd "`caller_cwd'"
}
local rc = _rc
cd "`pkg_dir'/qa"
if `rc' {
    local ++fail
    display as error "FAIL: datamap fingerprint separate (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: datamap fingerprint separate"
}

**## Caller fingerprint datamap single
local ++tests
capture noisily {
    clear
    set obs 12
    gen double x = cond(_n <= 3, ., _n)
    gen double y = _n + mod(_n, 2)
    quietly regress y x
    matrix corrmat = (7, 8)
    scalar __f = 99
    char _dta[user] "untouched"
    set varabbrev on
    save "`work'/state-input.dta", replace
    qa_state_snapshot, tag(state) rreturn
    datamap, single("`work'/state-input.dta") output("`work'/single.txt")
    qa_state_compare, tag(state) allow(r)
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: datamap fingerprint single (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: datamap fingerprint single"
}

**## Caller fingerprint datamap dict_single
local ++tests
capture noisily {
    clear
    set obs 12
    gen double x = cond(_n <= 3, ., _n)
    gen double y = _n + mod(_n, 2)
    quietly regress y x
    matrix corrmat = (7, 8)
    scalar __f = 99
    char _dta[user] "untouched"
    set varabbrev on
    save "`work'/state-input.dta", replace
    qa_state_snapshot, tag(state) rreturn
    datadict, single("`work'/state-input.dta") output("`work'/single.md")
    qa_state_compare, tag(state) allow(r)
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: datamap fingerprint dict_single (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: datamap fingerprint dict_single"
}


sysdir set PLUS "`oldplus'"
sysdir set PERSONAL "`oldpersonal'"
display "RESULT: test_datamap_v171 tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
