* test_cycle_20261119_survtab.do - 2026-11-19 review cycle, unit survtab
*   F1/F5 fweighted median equals stci on the expanded data, printed and in
*         r(); a genuinely unreached median still prints NR
*   F2    an explicit value equal to the old -1 "unset" sentinel is
*         range-checked (rmst, digits, pdp, highpdp, boldp, highlight,
*         fontsize) and valid values keep working
*   F3    the RMST row label and r(methods) name the horizon as given
*   F4    r(table) column names from multibyte labels are valid UTF-8,
*         unique and at most 32 bytes

clear all
set more off
set varabbrev off
version 17.0

capture log close _cyc_sv
log using "test_cycle_20261119_survtab.log", replace text name(_cyc_sv)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* fixture: 120 rows, two groups, integer times, frequency weights 1..3
capture program drop _cyc_sv_data
program define _cyc_sv_data
    clear
    set seed 20261119
    set obs 120
    gen double t = ceil(runiform()*30)
    gen byte e = runiform() < .7
    gen byte g = 1 + mod(_n, 2)
    gen long w = 1 + mod(_n, 3)
end

* the c1 row of frame <fr> whose label starts with <prefix>; stored in c_local
capture program drop _cyc_sv_row
program define _cyc_sv_row
    args fr prefix
    frame `fr' {
        quietly count if strpos(strtrim(c1), `"`prefix'"') == 1
        assert r(N) == 1
        quietly gen long _cyc_n = _n
        quietly summarize _cyc_n if strpos(strtrim(c1), `"`prefix'"') == 1, meanonly
        local i = r(min)
        drop _cyc_n
        c_local _row `i'
    }
end

**# F1/F5 fweighted median
local ++test_count
capture noisily {
    _cyc_sv_data
    tempfile base
    quietly save `base'
    expand w
    stset t, failure(e)
    quietly stci if g == 1
    local ex1 = r(p50)
    local ex1lb = r(lb)
    local ex1ub = r(ub)
    quietly stci if g == 2
    local ex2 = r(p50)
    assert !missing(`ex1') & !missing(`ex2')
    use `base', clear
    stset t [fw=w], failure(e)
    survtab, times(5 10) by(g) median digits(1) frame(sv_f1, replace)
    assert r(median_1) == `ex1'
    assert r(median_2) == `ex2'
    _cyc_sv_row sv_f1 "Median survival"
    * the median cell, then its CI on the next row
    frame sv_f1: local cell = strtrim(c2[`_row'])
    frame sv_f1: local cicell = strtrim(c2[`_row' + 1])
    local want = strtrim(string(`ex1', "%9.1f"))
    local wantci = "(" + strtrim(string(`ex1lb', "%9.1f")) + ", " + strtrim(string(`ex1ub', "%9.1f")) + ")"
    display `"cell [`cell'] [`cicell'] want [`want'] [`wantci']"'
    assert `"`cell'"' == `"`want'"'
    assert `"`cicell'"' == `"`wantci'"'
}
if _rc == 0 {
    display as result "  PASS: F1 fweighted median = stci on expanded data (cell and r())"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 fweighted median = stci on expanded data (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    * heavy censoring: S(t) never reaches 0.5, so NR is the true answer
    clear
    set obs 40
    gen double t = _n
    gen byte e = mod(_n, 10) == 0 & _n < 40
    stset t, failure(e)
    quietly stci
    assert missing(r(p50))
    survtab, times(5 10) median frame(sv_f5, replace)
    assert missing(r(median_1))
    _cyc_sv_row sv_f5 "Median survival"
    frame sv_f5: local cell = c2[`_row']
    assert strpos(`"`cell'"', "NR") == 1
}
if _rc == 0 {
    display as result "  PASS: F5 genuinely unreached median prints NR"
    local ++pass_count
}
else {
    display as error "  FAIL: F5 genuinely unreached median prints NR (rc=`=_rc')"
    local ++fail_count
}

**# F2 sentinel values are range-checked
foreach o in "rmst(-1)" "digits(-1)" "pdp(-1)" "highpdp(-1)" "boldp(-1)" "highlight(-1)" "fontsize(-1)" "digits(1.5)" "digits(abc)" "rmst(.)" {
    local ++test_count
    capture noisily {
        _cyc_sv_data
        stset t, failure(e)
        capture survtab, times(5 10) by(g) `o'
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: F2 `o' refused with rc 198"
        local ++pass_count
    }
    else {
        display as error "  FAIL: F2 `o' refused with rc 198 (rc=`=_rc')"
        local ++fail_count
    }
}

local ++test_count
capture noisily {
    _cyc_sv_data
    stset t, failure(e)
    foreach o in "rmst(20)" "digits(0)" "digits(6)" "pdp(1)" "highpdp(10)" "boldp(0.05)" "highlight(.5)" "fontsize(12)" "rmst(1e-1)" {
        capture survtab, times(5 10) by(g) `o'
        if _rc {
            display as error "`o' rc=" _rc
            exit 9
        }
    }
    * defaults when unset: digits 1 in the printed cell, no RMST row
    survtab, times(5 10) by(g) frame(sv_f2d, replace)
    assert missing(r(rmst_1))
    frame sv_f2d: quietly count if strpos(c1, "RMST") > 0
    assert r(N) == 0
    _cyc_sv_row sv_f2d "5"
    frame sv_f2d: local cell = c2[`_row']
    assert ustrregexm(strtrim(`"`cell'"'), "^[0-9]+\.[0-9]%$")
    * digits(2) is honoured in the printed cell
    survtab, times(5 10) by(g) digits(2) frame(sv_f2e, replace)
    _cyc_sv_row sv_f2e "5"
    frame sv_f2e: local cell = c2[`_row']
    assert ustrregexm(strtrim(`"`cell'"'), "^[0-9]+\.[0-9][0-9]%$")
}
if _rc == 0 {
    display as result "  PASS: F2 valid values and defaults unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 valid values and defaults unchanged (rc=`=_rc')"
    local ++fail_count
}

**# F3 RMST horizon label
local ++test_count
capture noisily {
    _cyc_sv_data
    stset t, failure(e)
    survtab, times(5 10) rmst(0.05) frame(sv_f3a, replace)
    assert strpos(`"`r(methods)'"', "up to 0.05 years") > 0
    frame sv_f3a: quietly count if strtrim(c1) == "RMST (0.05-yr), yr (95% CI)"
    assert r(N) == 1
    survtab, times(5 10) rmst(12.25) csv("`c(tmpdir)'/sv_f3.csv") frame(sv_f3b, replace)
    assert strpos(`"`r(methods)'"', "up to 12.25 years") > 0
    frame sv_f3b: quietly count if strtrim(c1) == "RMST (12.25-yr), yr (95% CI)"
    assert r(N) == 1
    * the exported CSV carries the same label
    tempname fh
    local found 0
    file open `fh' using "`c(tmpdir)'/sv_f3.csv", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "RMST (12.25-yr)") local found 1
        file read `fh' line
    }
    file close `fh'
    assert `found' == 1
    * integer horizons keep their label
    survtab, times(5 10) rmst(20) frame(sv_f3c, replace)
    frame sv_f3c: quietly count if strtrim(c1) == "RMST (20-yr), yr (95% CI)"
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: F3 RMST label and methods name the horizon as given"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 RMST label and methods name the horizon as given (rc=`=_rc')"
    local ++fail_count
}

**# F4 multibyte r(table) column names
local ++test_count
capture noisily {
    _cyc_sv_data
    label define _cyc_L 1 "日本語日本語日本語日本語日本語日本語日本語日本語_甲" ///
        2 "日本語日本語日本語日本語日本語日本語日本語日本語_乙"
    label values g _cyc_L
    stset t, failure(e)
    survtab, times(5 10) by(g)
    local cn : colnames r(table)
    assert wordcount(`"`cn'"') == 2
    local c1 : word 1 of `cn'
    local c2 : word 2 of `cn'
    display `"names [`c1'] [`c2']"'
    assert ustrinvalidcnt(`"`c1'"') == 0 & ustrinvalidcnt(`"`c2'"') == 0
    assert strlen(`"`c1'"') <= 32 & strlen(`"`c2'"') <= 32
    assert `"`c1'"' != `"`c2'"'
    assert `"`c1'"' == "日本語日本語日本語日"
    assert `"`c2'"' == "日本語日本語日本語日_2"
}
if _rc == 0 {
    display as result "  PASS: F4 multibyte colnames valid, unique, <= 32 bytes"
    local ++pass_count
}
else {
    display as error "  FAIL: F4 multibyte colnames valid, unique, <= 32 bytes (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    * ASCII names are unchanged: 32-byte cut and _2 suffix as before
    _cyc_sv_data
    label define _cyc_A 1 "abcdefghijklmnopqrstuvwxyz0123456789_one" ///
        2 "abcdefghijklmnopqrstuvwxyz0123456789_two"
    label values g _cyc_A
    stset t, failure(e)
    survtab, times(5 10) by(g)
    local cn : colnames r(table)
    local c1 : word 1 of `cn'
    local c2 : word 2 of `cn'
    assert `"`c1'"' == "abcdefghijklmnopqrstuvwxyz012345"
    assert `"`c2'"' == "abcdefghijklmnopqrstuvwxyz0123_2"
}
if _rc == 0 {
    display as result "  PASS: F4 ASCII colnames unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: F4 ASCII colnames unchanged (rc=`=_rc')"
    local ++fail_count
}

display as result "test_cycle_20261119_survtab: `pass_count' passed, `fail_count' failed"
display "RESULT: test_cycle_20261119_survtab tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _cyc_sv
if `fail_count' > 0 exit 1
