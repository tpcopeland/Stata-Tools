* test_corrtab.do - Dedicated QA for corrtab

clear all
set more off
set varabbrev off

capture log close _corrtab
log using "test_corrtab.log", replace text name(_corrtab)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
local checker "`qa_dir'/tools/check_xlsx.py"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Pearson and Spearman
**## Pearson returns match pwcorr with pairwise N
local ++test_count
capture noisily {
    clear
    set obs 10
    gen double x = _n
    gen double y = _n
    gen double z = _n
    replace z = . in 1/2

    quietly pwcorr x y z, sig
    matrix _refC = r(C)

    capture frame drop _corr_pearson
    corrtab x y z, frame(_corr_pearson, replace)

    assert abs(r(C)[2, 1] - _refC[2, 1]) < 1e-12
    assert abs(r(C)[3, 1] - _refC[3, 1]) < 1e-12
    assert r(N)[1, 2] == 10
    assert r(N)[1, 3] == 8
    assert r(N)[2, 3] == 8
    assert "`r(frame)'" == "_corr_pearson"
}
if _rc == 0 {
    display as result "  PASS: corrtab Pearson matches pwcorr with pairwise N"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab Pearson matches pwcorr with pairwise N (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _corr_pearson

**## Spearman returns match spearman
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly spearman price mpg weight, pw matrix
    local rho_pm = r(Rho)[2, 1]
    local rho_pw = r(Rho)[3, 1]

    corrtab price mpg weight, spearman

    assert abs(r(C)[2, 1] - `rho_pm') < 1e-12
    assert abs(r(C)[3, 1] - `rho_pw') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: corrtab Spearman matches spearman"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab Spearman matches spearman (rc=`=_rc')"
    local ++fail_count
}

**# Triangle Display
**## lower triangle stores only lower-half values
local ++test_count
capture noisily {
    clear
    set obs 10
    gen double x = _n
    gen double y = _n
    gen double z = 11 - _n

    capture frame drop _corr_lower
    corrtab x y z, lower frame(_corr_lower, replace)

    frame _corr_lower {
        assert c3[3] == ""
        assert c4[3] == ""
        assert c4[4] == ""
        assert c2[4] != ""
        assert c2[5] != ""
        assert c3[5] != ""
    }
}
if _rc == 0 {
    display as result "  PASS: corrtab lower triangle blanks upper cells"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab lower triangle blanks upper cells (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _corr_lower

**## upper triangle stores only upper-half values
local ++test_count
capture noisily {
    clear
    set obs 10
    gen double x = _n
    gen double y = _n
    gen double z = 11 - _n

    capture frame drop _corr_upper
    corrtab x y z, upper frame(_corr_upper, replace)

    frame _corr_upper {
        assert c2[4] == ""
        assert c2[5] == ""
        assert c3[5] == ""
        assert c3[3] != ""
        assert c4[3] != ""
        assert c4[4] != ""
    }
}
if _rc == 0 {
    display as result "  PASS: corrtab upper triangle blanks lower cells"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab upper triangle blanks lower cells (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _corr_upper

**## full matrix populates both off-diagonals
local ++test_count
capture noisily {
    clear
    set obs 10
    gen double x = _n
    gen double y = _n
    gen double z = 11 - _n

    capture frame drop _corr_full
    corrtab x y z, full frame(_corr_full, replace)

    frame _corr_full {
        assert c3[3] != ""
        assert c4[3] != ""
        assert c2[4] != ""
        assert c4[4] != ""
        assert c2[5] != ""
        assert c3[5] != ""
    }
}
if _rc == 0 {
    display as result "  PASS: corrtab full matrix fills both triangles"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab full matrix fills both triangles (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _corr_full

**# Significance Presentation
**## custom star thresholds change displayed strings
local ++test_count
capture noisily {
    clear
    set obs 10
    gen double x = _n
    gen double y = _n

    capture frame drop _corr_star
    corrtab x y, star(0.10 0.05) frame(_corr_star, replace)

    frame _corr_star {
        assert c2[4] == "1.00**"
    }
}
if _rc == 0 {
    display as result "  PASS: corrtab custom star thresholds affect output text"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab custom star thresholds affect output text (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _corr_star

**## pvalues() prints coefficient and p-value together
local ++test_count
capture noisily {
    clear
    set obs 10
    gen double x = _n
    gen double y = _n

    capture frame drop _corr_p
    corrtab x y, pvalues frame(_corr_p, replace)

    frame _corr_p {
        assert strpos(c2[4], "1.00") > 0
        assert strpos(c2[4], "<0.001") > 0
        assert strpos(c2[4], "(") > 0
    }
}
if _rc == 0 {
    display as result "  PASS: corrtab pvalues() prints p-values in-cell"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab pvalues() prints p-values in-cell (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _corr_p

**# Console and Export
**## display writes a visible console table
local ++test_count
capture noisily {
    tempfile corr_console
    capture log close _corr_console
    log using "`corr_console'", replace text name(_corr_console)

    clear
    set obs 8
    gen double x = _n
    gen double y = _n
    gen double z = 9 - _n

    corrtab x y z, display title("Console Correlation Table")

    log close _corr_console

    tempname fh
    local found_title = 0
    local found_header = 0
    local found_value = 0
    local line ""
    file open `fh' using "`corr_console'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "Console Correlation Table") > 0 local found_title = 1
        if strpos(`"`line'"', "x") > 0 & strpos(`"`line'"', "y") > 0 local found_header = 1
        if strpos(`"`line'"', "1.00") > 0 local found_value = 1
        file read `fh' line
    }
    file close `fh'

    assert `found_title' == 1
    assert `found_header' == 1
    assert `found_value' == 1
}
if _rc == 0 {
    display as result "  PASS: corrtab display emits title, headers, and values"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab display emits title, headers, and values (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as result "corrtab QA summary: `pass_count' passed, `fail_count' failed"
if `fail_count' > 0 exit 1

log close _corrtab
