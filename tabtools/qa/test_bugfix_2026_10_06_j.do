* test_bugfix_2026_10_06_j.do - independent review of the 2.5.2 change set:
*   J1 regtab: a CI bound prints with the estimate's rounding (exact binary
*      tie, and a decimal that is a tie only in decimal arithmetic)
*   J2 effecttab (collect route): the same rule for its CI bounds
*   J3 effecttab: a value label that matrix stripes refuse ("#1" followed
*      by "[", read as factor-variable notation) no longer aborts the table
*   J4 ratetab: default unitlabel for an exponent-form per()
* Expected strings are worked by hand (round half up at the stated decimals),
* not read from the commands.

clear all
set more off
set varabbrev off
set linesize 255
version 17.0

capture log close _bfj
log using "test_bugfix_2026_10_06_j.log", replace text name(_bfj)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

* an estimation result with b = bval and a variance so small that every 95% bound
* is the same double as b (b +/- 2e-17 rounds back to b for |b| >= 0.05)
capture program drop _bfj_post
program define _bfj_post, eclass
    version 17.0
    args bval
    tempname b V
    matrix `b' = (`bval', 1)
    matrix colnames `b' = x _cons
    matrix `V' = (1e-34, 0 \ 0, 1e-34)
    matrix rownames `V' = x _cons
    matrix colnames `V' = x _cons
    ereturn post `b' `V', obs(100) dof(100000)
    ereturn local cmd "regress"
    ereturn local depvar "y"
end

**# J1: regtab, estimate and bounds round alike
local ++test_count
capture noisily {
    * b, digits, estimate cell, CI cell (bounds equal b except where b - 2e-17
    * is a different double: 0.125 and 0.0625 sit on a power of two, so their
    * lower bound is one ulp below the tie and correctly rounds down)
    local i 0
    foreach spec in "2.25|1|2.3|(2.3, 2.3)" "-2.25|1|-2.2|(-2.2, -2.2)" "0.85|1|0.9|(0.9, 0.9)" ///
        "0.375|2|0.38|(0.38, 0.38)" "1.5|0|2|(2, 2)" "0.125|2|0.13|(0.12, 0.13)" "-0.125|2|-0.12|(-0.13, -0.12)" {
        gettoken bv rest : spec, parse("|")
        local rest = substr("`rest'", 2, .)
        gettoken dg rest : rest, parse("|")
        local rest = substr("`rest'", 2, .)
        gettoken want_c1 rest : rest, parse("|")
        local want_c2 = substr("`rest'", 2, .)
        collect clear
        quietly collect: _bfj_post `bv'
        quietly regtab, digits(`dg') frame(_bfj_f, replace)
        frame _bfj_f: assert strtrim(c1[4]) == "`want_c1'"
        frame _bfj_f: assert strtrim(c2[4]) == "`want_c2'"
    }
}
if _rc == 0 {
    display as result "  PASS: J1 regtab bounds follow the estimate's rounding on ties"
    local ++pass_count
}
else {
    display as error "  FAIL: J1 regtab tie rounding (rc=`=_rc')"
    local ++fail_count
}

**# J2: effecttab collect route, estimate and bounds round alike
local ++test_count
capture noisily {
    clear
    quietly set obs 100
    * y = 2.25 +/- one ulp, balanced: the mean and both 95% bounds are 2.25
    quietly gen double y = 2.25 + (mod(_n, 2) * 2 - 1) * 2^-51
    quietly gen byte x = mod(_n, 4) < 2
    quietly regress y i.x
    collect clear
    quietly collect: margins x
    quietly effecttab, digits(1) frame(_bfj_e, replace)
    frame _bfj_e: quietly count if strtrim(c1) == "2.3" & strtrim(c2) == "(2.3, 2.3)"
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: J2 effecttab margins 2.25 at 1 decimal prints 2.3 (2.3, 2.3)"
    local ++pass_count
}
else {
    display as error "  FAIL: J2 effecttab tie rounding (rc=`=_rc')"
    local ++fail_count
}

**# J3: effecttab keeps a label matrix stripes refuse
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly generate byte g = mod(_n, 3) + 1
    label define _bfj_gl 1 "first" 2 "#1 [a]" 3 "Age [18-30]"
    label values g _bfj_gl
    quietly regress price i.g
    collect clear
    quietly collect: margins g
    effecttab, frame(_bfj_g, replace)
    matrix T = r(table)
    assert rowsof(T) == 3
    * the refused name falls back to row#, every other label keeps its own name
    local rn : rowfullnames T
    assert strpos(" `rn' ", " row2 ") > 0
    assert strpos(" `rn' ", "first") > 0 & strpos(" `rn' ", "Age_[18-30]") > 0
    * all three labels are in the rendered table
    frame _bfj_g: quietly count if strpos(A, "#1 [a]") > 0
    assert r(N) == 1
    frame _bfj_g: quietly count if strpos(A, "Age [18-30]") > 0
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: J3 effecttab label '#1 [a]' renders, row named row2"
    local ++pass_count
}
else {
    display as error "  FAIL: J3 effecttab bracket label (rc=`=_rc')"
    local ++fail_count
}

**# J4: ratetab default unit label for per() in exponent form
local ++test_count
capture noisily {
    clear
    set seed 3
    quietly set obs 200
    gen byte g = 1 + mod(_n, 2)
    gen byte ev = runiform() < .2
    gen double pt = 1 + runiform() * 3
    foreach spec in "1e-6|Per 1e-06 PY (95% CI)" "1.5e-7|Per 1.5e-07 PY (95% CI)" "0.5|Per 0.5 PY (95% CI)" ///
        "1000|Per 1,000 PY (95% CI)" "100000|Per 100,000 PY (95% CI)" "1e10|Per 10,000,000,000 PY (95% CI)" ///
        "1500.5|Per 1,500.5 PY (95% CI)" "0.001|Per 0.001 PY (95% CI)" {
        gettoken p want : spec, parse("|")
        local want = substr("`want'", 2, .)
        quietly ratetab g, events(ev) exposure(pt) per(`p') frame(_bfj_r, replace)
        frame _bfj_r: assert c4[3] == "`want'"
    }
}
if _rc == 0 {
    display as result "  PASS: J4 ratetab unitlabel: exponent form is compact, plain forms unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: J4 ratetab unitlabel (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as result "RESULT: test_bugfix_2026_10_06_j tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _bfj
if `fail_count' > 0 exit 1
