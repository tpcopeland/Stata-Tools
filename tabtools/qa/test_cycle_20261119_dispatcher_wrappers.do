* test_cycle_20261119_dispatcher_wrappers.do - 2026-11-19 review cycle,
* tabtools dispatcher and session helpers
*
*   D1  tabtools set workbook|markdown ~/path stores $HOME/path (was "/path")
*       and session writes reach that file
*   D2  tabtools use keeps the session settings (workbook, smallcells, ...),
*       and accepts a compound-quoted using path
*   D3  fontsize, digits and smallcells are stored as the number, so masked
*       cells and footnotes read <5, not <+5 or <05
*   D4  tabtools fitcount leaves no collect-save .stjson in c(tmpdir)
*
* Printed output is checked by logging a command to a text file and reading
* it back (_dw_capture), and exported cells by import excel / file read.

clear all
set more off
set varabbrev off
version 17.0

capture log close _dw
log using "test_cycle_20261119_dispatcher_wrappers.log", replace text name(_dw)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

local test_count = 0
local pass_count = 0
local fail_count = 0

* Run a command with its output logged to a text file; the file's text is
* returned in the caller's local _dw_text (newlines as spaces).
capture program drop _dw_capture
program define _dw_capture
    gettoken _file 0 : 0
    capture log close _dwcap
    quietly log using `"`_file'"', replace text name(_dwcap)
    capture noisily `0'
    local _rc = _rc
    quietly log close _dwcap
    tempname fh
    local _t ""
    file open `fh' using `"`_file'"', read text
    file read `fh' _line
    while r(eof) == 0 {
        local _t `"`macval(_t)' `macval(_line)'"'
        file read `fh' _line
    }
    file close `fh'
    c_local _dw_text `"`macval(_t)'"'
    c_local _dw_rc `_rc'
end

* Small-cell fixture: c == 1 has 2 rows in each group, so it is masked.
capture program drop _dw_data
program define _dw_data
    clear
    set obs 60
    generate byte g = mod(_n, 2)
    generate byte c = cond(_n <= 4, 1, cond(_n <= 30, 2, 3))
end

local home : environment HOME

**# D1 tilde paths are $HOME
**## D1.1 the stored session targets are $HOME/...
local ++test_count
capture noisily {
    tabtools set clear
    assert `"`home'"' != ""
    tabtools set workbook ~/zz_dw_probe.xlsx
    assert `"`r(workbook)'"' == `"`home'/zz_dw_probe.xlsx"'
    tabtools set markdown "~/zz_dw_probe.md"
    assert `"`r(markdown)'"' == `"`home'/zz_dw_probe.md"'
    tabtools set latex ~/sub/../zz_dw_probe.tex
    assert `"`r(latex)'"' == `"`home'/zz_dw_probe.tex"'
    _dw_capture `"`output_dir'/_dw_q1.txt"' tabtools query
    assert strpos(`"`_dw_text'"', `""`home'/zz_dw_probe.xlsx""') > 0
    assert `"$TABTOOLS_set_workbook"' == `"`home'/zz_dw_probe.xlsx"'
    tabtools set clear
}
if _rc == 0 {
    display as result "  PASS: D1.1 ~/ session targets stored under HOME"
    local ++pass_count
}
else {
    display as error "  FAIL: D1.1 ~/ session targets stored under HOME (rc=`=_rc')"
    local ++fail_count
}
tabtools set clear

**## D1.2 session writes through a ~/ target land in $HOME/...
* The output directory is reached as ~/<rel> when it lies under HOME (it does
* when the package tree is under the home directory); the stored-path test
* above runs anyway.
local ++test_count
capture noisily {
    tabtools set clear
    local _od `"`output_dir'"'
    assert substr(`"`_od'"', 1, strlen(`"`home'"') + 1) == `"`home'/"'
    local rel = substr(`"`_od'"', strlen(`"`home'"') + 2, .)
    local wb `"`_od'/_dw_tilde.xlsx"'
    local md `"`_od'/_dw_tilde.md"'
    capture erase `"`wb'"'
    capture erase `"`md'"'
    tabtools set workbook ~/`rel'/_dw_tilde.xlsx
    assert `"`r(workbook)'"' == `"`wb'"'
    tabtools set markdown ~/`rel'/_dw_tilde.md
    assert `"`r(markdown)'"' == `"`md'"'
    clear
    input str8 make int price
    "AMC"   4099
    "Buick" 4816
    "Chev"  3299
    end
    puttab make price, sheet(s1)
    confirm file `"`wb'"'
    confirm file `"`md'"'
    import excel using `"`wb'"', sheet("s1") clear allstring
    local hit 0
    foreach v of varlist _all {
        quietly count if strtrim(`v') == "4816"
        if r(N) local hit 1
    }
    assert `hit'
    _dw_capture `"`output_dir'/_dw_q2.txt"' type `"`md'"'
    assert strpos(`"`_dw_text'"', "4816") > 0
    * The same file named by its absolute spelling is the same target.
    tabtools set workbook `"`wb'"'
    tabtools query
    assert `"`r(workbook_fresh)'"' == "0"
    tabtools set clear
    capture erase `"`wb'"'
    capture erase `"`md'"'
}
if _rc == 0 {
    display as result "  PASS: D1.2 session writes through ~/ targets reach HOME"
    local ++pass_count
}
else {
    display as error "  FAIL: D1.2 session writes through ~/ targets (rc=`=_rc')"
    local ++fail_count
}
tabtools set clear

**# D2 tabtools use keeps session settings
**## D2.1 a generated profile does not wipe session keys
local ++test_count
capture noisily {
    tabtools set clear
    local prof `"`output_dir'/_dw_prof1.do"'
    local wb `"`output_dir'/_dw_use.xlsx"'
    tabtools set workbook `"`wb'"'
    tabtools set smallcells 5 primary
    tabtools set texopts size(small)
    tabtools set headershade off
    tabtools set font Calibri, permanent profile(`"`prof'"')
    * The profile clears first, as every generated profile does.
    _dw_capture `"`output_dir'/_dw_p1.txt"' type `"`prof'"'
    assert strpos(`"`_dw_text'"', "tabtools set clear") > 0
    global TABTOOLS_FONT
    * Compound-quoted using path (a program passing a macro): was rc 198.
    tabtools use using `"`prof'"'
    assert "`r(action)'" == "loaded"
    assert `"`r(profile)'"' == `"`prof'"'
    assert "$TABTOOLS_FONT" == "Calibri"
    tabtools query
    assert `"`r(workbook)'"' == `"`wb'"'
    assert `"`r(workbook_fresh)'"' == "1"
    assert `"`r(smallcells)'"' == "5"
    assert `"`r(smallcells_mode)'"' == "primary"
    assert `"`r(texopts)'"' == "size(small)"
    assert `"`r(headershade)'"' == "off"
    * The kept smallcells still masks: printed cells and the echo.
    tabtools set workbook clear
    _dw_data
    _dw_capture `"`output_dir'/_dw_t1.txt"' table1_tc, by(g) vars(c cat)
    assert `_dw_rc' == 0
    assert strpos(`"`_dw_text'"', "using session smallcells(5, primary)") > 0
    assert strpos(`"`_dw_text'"', "<5") > 0
    tabtools set clear
}
if _rc == 0 {
    display as result "  PASS: D2.1 tabtools use keeps workbook, smallcells, texopts, headershade"
    local ++pass_count
}
else {
    display as error "  FAIL: D2.1 tabtools use keeps session keys (rc=`=_rc')"
    local ++fail_count
}
tabtools set clear

**## D2.2 a profile that sets a session key itself wins; a failing one still keeps them
local ++test_count
capture noisily {
    tabtools set clear
    local prof2 `"`output_dir'/_dw_prof2.do"'
    tempname fh
    file open `fh' using `"`prof2'"', write text replace
    file write `fh' "tabtools set clear" _n "tabtools set smallcells 7" _n
    file close `fh'
    tabtools set smallcells 5
    tabtools set headershade on
    tabtools use using "`prof2'"
    assert `"`r(profile)'"' == `"`prof2'"'
    tabtools query
    assert `"`r(smallcells)'"' == "7"
    assert `"`r(smallcells_mode)'"' == "full"
    assert `"`r(headershade)'"' == "on"
    * A profile that errors after its clear line: rc kept, session restored.
    local prof3 `"`output_dir'/_dw_prof3.do"'
    file open `fh' using `"`prof3'"', write text replace
    file write `fh' "tabtools set clear" _n "tabtools set fontsize 999" _n
    file close `fh'
    tabtools set smallcells 4 primary
    capture tabtools use using `"`prof3'"'
    assert _rc == 198
    tabtools query
    assert `"`r(smallcells)'"' == "4"
    assert `"`r(smallcells_mode)'"' == "primary"
    assert `"`r(headershade)'"' == "on"
    tabtools set clear
}
if _rc == 0 {
    display as result "  PASS: D2.2 profile-set session key wins; failing profile keeps session"
    local ++pass_count
}
else {
    display as error "  FAIL: D2.2 profile-set key / failing profile (rc=`=_rc')"
    local ++fail_count
}
tabtools set clear

**# D3 numeric settings stored as the number
**## D3.1 smallcells +5 and 05: masks and footnote read 5
local ++test_count
capture noisily {
    tabtools set clear
    foreach typed in +5 05 {
        tabtools set smallcells `typed'
        assert r(smallcells) == 5
        assert `"$TABTOOLS_set_smallcells"' == "5"
        _dw_data
        _dw_capture `"`output_dir'/_dw_t3.txt"' table1_tc, by(g) vars(c cat)
        assert `_dw_rc' == 0
        assert strpos(`"`_dw_text'"', "using session smallcells(5)") > 0
        assert strpos(`"`_dw_text'"', "Counts below 5 are shown as <5") > 0
        assert strpos(`"`_dw_text'"', "<+5") == 0
        assert strpos(`"`_dw_text'"', "<05") == 0
    }
    tabtools set clear
}
if _rc == 0 {
    display as result "  PASS: D3.1 smallcells +5/05 stored as 5; printed <5"
    local ++pass_count
}
else {
    display as error "  FAIL: D3.1 smallcells spelling in masks (rc=`=_rc')"
    local ++fail_count
}
tabtools set clear

**## D3.2 fontsize +9 and digits 03: get, the global, and the profile
local ++test_count
capture noisily {
    tabtools set clear
    tabtools set fontsize +9
    assert r(fontsize) == 9
    assert "$TABTOOLS_FONTSIZE" == "9"
    local prof4 `"`output_dir'/_dw_prof4.do"'
    tabtools set digits 03, permanent profile(`"`prof4'"')
    assert r(digits) == 3
    assert "$TABTOOLS_DIGITS" == "3"
    _dw_capture `"`output_dir'/_dw_g.txt"' tabtools get
    assert ustrregexm(`"`_dw_text'"', "Font size: +9 ")
    assert ustrregexm(`"`_dw_text'"', "Digits: +3 ")
    assert !ustrregexm(`"`_dw_text'"', "Font size: +[+]9")
    assert !ustrregexm(`"`_dw_text'"', "Digits: +03")
    _dw_capture `"`output_dir'/_dw_p4.txt"' type `"`prof4'"'
    assert strpos(`"`_dw_text'"', "tabtools set fontsize 9") > 0
    assert strpos(`"`_dw_text'"', "tabtools set digits 3") > 0
    assert strpos(`"`_dw_text'"', "fontsize +9") == 0
    assert strpos(`"`_dw_text'"', "digits 03") == 0
    tabtools set clear
}
if _rc == 0 {
    display as result "  PASS: D3.2 fontsize/digits stored as the number"
    local ++pass_count
}
else {
    display as error "  FAIL: D3.2 fontsize/digits spelling (rc=`=_rc')"
    local ++fail_count
}
tabtools set clear

**# D4 fitcount leaves nothing in c(tmpdir)
local ++test_count
capture noisily {
    clear
    set seed 20261119
    set obs 200
    generate double x = rnormal()
    generate byte y = rpoisson(exp(0.2 * x)) > 0
    collect clear
    collect: poisson y x
    local t = c(tmpdir)
    local before : dir "`t'" files "*.stjson"
    tabtools fitcount, events(y)
    assert r(events) > 0
    local after : dir "`t'" files "*.stjson"
    local new : list after - before
    display `"new .stjson files: [`new']"'
    assert `"`new'"' == ""
    collect clear
}
if _rc == 0 {
    display as result "  PASS: D4 fitcount leaves no .stjson in c(tmpdir)"
    local ++pass_count
}
else {
    display as error "  FAIL: D4 fitcount .stjson left in c(tmpdir) (rc=`=_rc')"
    local ++fail_count
}

tabtools set clear
foreach f in _dw_q1.txt _dw_q2.txt _dw_p1.txt _dw_t1.txt _dw_t3.txt _dw_g.txt _dw_p4.txt ///
    _dw_prof1.do _dw_prof2.do _dw_prof3.do _dw_prof4.do {
    capture erase `"`output_dir'/`f'"'
}

display as result "dispatcher_wrappers QA summary: `pass_count' passed, `fail_count' failed"
local _tc = `pass_count' + `fail_count'
display "RESULT: test_cycle_20261119_dispatcher_wrappers tests=`_tc' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1

log close _dw
