* test_bugfix_2026_10_06_i.do - regtab: one tie rule for the estimate and its CI bounds
* Bug: the estimate was rounded with round() and the CI bounds were printed by
* string() alone, which rounds an exact binary tie to even (string(2.25, "%9.1f")
* is 2.2; round(2.25, 0.1) is 2.3), so one value printed two ways in one row.
* Covers:
*   I1  a tie on the estimate and on both bounds in one row (digits 2, 1, 0)
*   I2  a negative tie (Stata's round() takes it toward +infinity, as the estimate does)
*   I3  cformat() is applied as given: no rounding extended to it
*   I4  non-tie guard: bounds that are not exact binary ties print exactly as
*       string() prints them, on a decimal "tie" that is not one in binary and
*       on random fits
* Every expected string is built from the fixture's own values (the eplotframe
* numbers asserted to be the exact ties first), never from the table's cells.

clear all
set more off
set varabbrev off
version 17.0

capture log close _rbi
log using "test_bugfix_2026_10_06_i.log", replace text name(_rbi)

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

* One-variable fit posted straight into collect: coefficient b, standard error
* se, no degrees of freedom (so the interval is b -/+ invnormal(.975) * se).
* cmdline "logit y x" (no or) makes regtab exponentiate.
capture program drop _bfi_fit
program define _bfi_fit, eclass
    version 17.0
    args cmd b se
    tempname B V
    matrix `B' = (`b', 0.5)
    matrix `V' = (`se'^2, 0 \ 0, 0.01)
    matrix colnames `B' = x _cons
    matrix colnames `V' = x _cons
    matrix rownames `V' = x _cons
    ereturn post `B' `V', obs(100) depname(y)
    ereturn local cmd "`cmd'"
    ereturn local depvar "y"
    ereturn local cmdline "`cmd' y x"
end

* Fit, regtab, read back. Returns r(est), r(ci) (the printed cells of row x)
* and r(e_est), r(e_ll), r(e_ul) (the exact numbers regtab holds).
capture program drop _bfi_run
program define _bfi_run, rclass
    version 17.0
    syntax , Cmd(string) B(string) Se(string) [Digits(string) CFormat(string) OUTdir(string)]
    local opt ""
    if "`digits'" != "" local opt "digits(`digits')"
    if `"`cformat'"' != "" local opt `"cformat(`cformat')"'
    collect clear
    quietly collect: _bfi_fit `cmd' `b' `se'
    quietly regtab, xlsx("`outdir'/bfi.xlsx") sheet(a) `opt' noint ///
        csv("`outdir'/bfi.csv") eplotframe(_bfi_ef, replace)
    frame _bfi_ef {
        return scalar e_est = estimate[1]
        return scalar e_ll = ll[1]
        return scalar e_ul = ul[1]
    }
    frame create _bfi_c
    frame _bfi_c {
        quietly import delimited using "`outdir'/bfi.csv", varnames(nonames) stringcols(_all) clear
        quietly count if v1 == "x"
        assert r(N) == 1
        quietly generate long _r = _n
        quietly summarize _r if v1 == "x", meanonly
        local row = r(min)
        local est = strtrim(v2[`row'])
        local ci = strtrim(v3[`row'])
    }
    frame drop _bfi_c
    return local est `"`est'"'
    return local ci `"`ci'"'
end

local z = invnormal(0.975)

**# I1 tie on the estimate and both bounds in one row
* b = 2.125, bounds 0.125 and 4.125: three exact ties at 2 decimals
local ++test_count
capture noisily {
    local se = 2 / `z'
    _bfi_run, cmd(regress) b(2.125) se(`se') digits(2) outdir("`output_dir'")
    assert r(e_est) == 2.125 & r(e_ll) == 0.125 & r(e_ul) == 4.125
    assert `"`r(est)'"' == "2.13"
    assert `"`r(ci)'"' == "(0.13, 4.13)"
    * digits(1): b = 2.25, bounds 0.25 and 4.25
    _bfi_run, cmd(regress) b(2.25) se(`se') digits(1) outdir("`output_dir'")
    assert r(e_est) == 2.25 & r(e_ll) == 0.25 & r(e_ul) == 4.25
    assert `"`r(est)'"' == "2.3"
    assert `"`r(ci)'"' == "(0.3, 4.3)"
    * digits(0): b = 2.5, bounds 0.5 and 4.5
    _bfi_run, cmd(regress) b(2.5) se(`se') digits(0) outdir("`output_dir'")
    assert r(e_est) == 2.5 & r(e_ll) == 0.5 & r(e_ul) == 4.5
    assert `"`r(est)'"' == "3"
    assert `"`r(ci)'"' == "(1, 5)"
}
if _rc == 0 {
    display as result "  PASS: I1 estimate and CI bounds on a tie print by one rule"
    local ++pass_count
}
else {
    display as error "  FAIL: I1 estimate and CI bounds on a tie (rc=`=_rc')"
    local ++fail_count
}

**# I2 a negative tie: round() takes it toward +infinity for the estimate and the bounds alike
* b = -2.375: string() gives -2.38 and (-4.38, -0.38); round() gives -2.37
local ++test_count
capture noisily {
    local se = 2 / `z'
    _bfi_run, cmd(regress) b(-2.375) se(`se') digits(2) outdir("`output_dir'")
    assert r(e_est) == -2.375 & r(e_ll) == -4.375 & r(e_ul) == -0.375
    assert `"`r(est)'"' == "-2.37"
    assert `"`r(ci)'"' == "(-4.37, -0.37)"
}
if _rc == 0 {
    display as result "  PASS: I2 negative ties follow the estimate's rule"
    local ++pass_count
}
else {
    display as error "  FAIL: I2 negative ties (rc=`=_rc')"
    local ++fail_count
}

**# I3 cformat() is applied as given: string() on the estimate and both bounds
local ++test_count
capture noisily {
    local se = 2 / `z'
    _bfi_run, cmd(regress) b(2.125) se(`se') cformat(%9.2f) outdir("`output_dir'")
    assert r(e_est) == 2.125 & r(e_ll) == 0.125 & r(e_ul) == 4.125
    assert `"`r(est)'"' == strtrim(string(2.125, "%9.2f"))
    assert `"`r(ci)'"' == "(" + strtrim(string(0.125, "%9.2f")) + ", " + strtrim(string(4.125, "%9.2f")) + ")"
    assert `"`r(est)'"' == "2.12"
}
if _rc == 0 {
    display as result "  PASS: I3 cformat() output is untouched"
    local ++pass_count
}
else {
    display as error "  FAIL: I3 cformat() (rc=`=_rc')"
    local ++fail_count
}

**# I4 non-tie guard
* A bound prints as an estimate of the same value prints: round() at the displayed
* digits, then the format (2.675 is 2.67499999999999982..., so the text is what
* round(x, 0.01) gives, not what string() alone gives)
local ++test_count
capture noisily {
    local se = (4.5 - 2.675) / `z'
    _bfi_run, cmd(regress) b(4.5) se(`se') digits(2) outdir("`output_dir'")
    local lo : display %9.2f round(r(e_ll), 0.01)
    local hi : display %9.2f round(r(e_ul), 0.01)
    * the fixture's lower bound is b - z*se by construction, 2.675 to rounding noise
    assert !missing(r(e_ll))
    assert abs(r(e_ll) - (4.5 - `se' * `z')) < 1e-12
    assert `"`r(ci)'"' == "(" + strtrim("`lo'") + ", " + strtrim("`hi'") + ")"
    * a bound 1e-7 either side of a tie is not a tie
    foreach off in -1e-7 1e-7 {
        local se = (2.125 - (0.125 + `off')) / `z'
        _bfi_run, cmd(regress) b(2.125) se(`se') digits(2) outdir("`output_dir'")
        assert !missing(r(e_ll))
        assert r(e_ll) != 0.125
        local lo : display %9.2f r(e_ll)
        local want = cond(`off' < 0, "0.12", "0.13")
        assert strtrim("`lo'") == "`want'"
        assert substr(`"`r(ci)'"', 1, 5) == "(`want'"
    }
}
if _rc == 0 {
    display as result "  PASS: I4a decimal and near-tie bounds print as the estimate would"
    local ++pass_count
}
else {
    display as error "  FAIL: I4a near-ties (rc=`=_rc')"
    local ++fail_count
}

* Random fits, linear and exponentiated (logit: regtab exponentiates): every printed bound is string() of the bound regtab holds
local ++test_count
capture noisily {
    set seed 20261006
    local nbad = 0
    forvalues s = 1/25 {
        local d = 1 + mod(`s', 4)
        local b = round(rnormal() * 3, 0.001)
        local se = 0.05 + runiform()
        foreach cmd in regress logit {
            _bfi_run, cmd(`cmd') b(`b') se(`se') digits(`d') outdir("`output_dir'")
            local lo : display %32.`d'f r(e_ll)
            local hi : display %32.`d'f r(e_ul)
            local want = "(" + strtrim("`lo'") + ", " + strtrim("`hi'") + ")"
            if `"`r(ci)'"' != `"`want'"' local ++nbad
        }
    }
    assert `nbad' == 0
}
if _rc == 0 {
    display as result "  PASS: I4b 50 random fits print their bounds exactly as string() does"
    local ++pass_count
}
else {
    display as error "  FAIL: I4b random fits (rc=`=_rc', nbad=`nbad')"
    local ++fail_count
}

**# Summary
display "RESULT: test_bugfix_2026_10_06_i tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture frame drop _bfi_ef
capture frame drop _bfi_c
capture tabtools set clear
log close _rbi
if `fail_count' > 0 exit 1
