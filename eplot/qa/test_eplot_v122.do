/*******************************************************************************
* test_eplot_v122.do
*
* Purpose: Regression tests for the v1.2.2 fixes
*   - The category (y) axis line and ticks are suppressed by default in
*     data/forest mode and matrix mode, matching estimates mode (was only
*     suppressed in estimates mode; forest/matrix plots drew a left axis line).
*   - In estimates mode, coeflabels() is honored even when the model variables
*     carry variable labels (the auto variable-label pass previously overwrote
*     coef_name before coeflabels() could match, silently ignoring user labels).
*   - Grouped estimates plots keep coefficients in their group/model order
*     (regression guard against the scrambled-row ordering shown in the old demo).
*
* Assertions read r(cmd), the executed graph command returned by eplot.
*
* Author: Timothy Copeland
* Date: 2026-06-14
*******************************************************************************/

clear all
set more off
version 16.0

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

* Targeted reinstall so no installed copy shadows the package under test
cap ado uninstall eplot
net install eplot, from("`pkg_dir'") replace

local nfail 0

*------------------------------------------------------------------------------
* C1: estimates mode honors coeflabels() over variable labels
*------------------------------------------------------------------------------
* auto.dta variables carry variable labels ("Mileage (mpg)", "Weight (lbs.)").
* The user label must win; the variable label must not leak through.
sysuse auto, clear
quietly logit foreign mpg weight
cap noisily eplot ., drop(_cons) eform ///
    coeflabels(mpg = "Miles/Gallon" weight = "Curb Weight")
if _rc {
    di as error "FAIL C1a: estimates+coeflabels aborted (rc=" _rc ")"
    local ++nfail
}
if !strpos(`"`r(cmd)'"', "Miles/Gallon") {
    di as error "FAIL C1b: coeflabels() user label absent from r(cmd)"
    local ++nfail
}
if strpos(`"`r(cmd)'"', "Mileage (mpg)") {
    di as error "FAIL C1c: variable label leaked despite coeflabels()"
    local ++nfail
}

*------------------------------------------------------------------------------
* C2: estimates mode suppresses the y-axis line and ticks by default
*------------------------------------------------------------------------------
quietly logit foreign mpg weight
cap noisily eplot ., drop(_cons) eform
if !strpos(`"`r(cmd)'"', "yscale(reverse noline") {
    di as error "FAIL C2a: estimates mode y-axis line not suppressed"
    local ++nfail
}
if !strpos(`"`r(cmd)'"', "noticks") {
    di as error "FAIL C2b: estimates mode y-axis ticks not suppressed"
    local ++nfail
}

*------------------------------------------------------------------------------
* C3: data/forest mode suppresses the y-axis line and ticks by default
*------------------------------------------------------------------------------
clear
input str16 study double(es lci uci)
"Study A" 0.72 0.55 0.94
"Study B" 0.85 0.71 1.02
"Overall" 0.80 0.72 0.88
end
cap noisily eplot es lci uci, labels(study) nonull
if _rc {
    di as error "FAIL C3a: data mode aborted (rc=" _rc ")"
    local ++nfail
}
if !strpos(`"`r(cmd)'"', "yscale(reverse noline") {
    di as error "FAIL C3b: data/forest mode y-axis line not suppressed"
    local ++nfail
}
if !strpos(`"`r(cmd)'"', "noticks") {
    di as error "FAIL C3c: data/forest mode y-axis ticks not suppressed"
    local ++nfail
}

*------------------------------------------------------------------------------
* C4: matrix mode suppresses the y-axis line and ticks by default
*------------------------------------------------------------------------------
matrix R = (1.82, 1.21, 2.74 \ 0.73, 0.54, 0.99)
matrix rownames R = Drug_A Drug_B
cap noisily eplot, matrix(R) eform
if _rc {
    di as error "FAIL C4a: matrix mode aborted (rc=" _rc ")"
    local ++nfail
}
if !strpos(`"`r(cmd)'"', "yscale(reverse noline") {
    di as error "FAIL C4b: matrix mode y-axis line not suppressed"
    local ++nfail
}
if !strpos(`"`r(cmd)'"', "noticks") {
    di as error "FAIL C4c: matrix mode y-axis ticks not suppressed"
    local ++nfail
}

*------------------------------------------------------------------------------
* C5: grouped estimates keep coefficients in group order (no scrambling)
*------------------------------------------------------------------------------
* The "Dimensions" group is length headroom trunk; they must appear in that
* order, after the group header, not scattered as in the pre-fix demo.
* Explicit coeflabels make the row labels deterministic in r(cmd).
sysuse auto, clear
quietly logit foreign mpg weight length headroom trunk turn
cap noisily eplot ., drop(_cons) eform ///
    coeflabels(length = "ZLEN" headroom = "ZHEAD" trunk = "ZTRK") ///
    groups(mpg weight = "Efficiency" ///
           length headroom trunk = "Dimensions" ///
           turn = "Handling")
if _rc {
    di as error "FAIL C5a: grouped estimates aborted (rc=" _rc ")"
    local ++nfail
}
local _p_dim   = strpos(`"`r(cmd)'"', "Dimensions")
local _p_len   = strpos(`"`r(cmd)'"', "ZLEN")
local _p_head  = strpos(`"`r(cmd)'"', "ZHEAD")
local _p_trunk = strpos(`"`r(cmd)'"', "ZTRK")
if !(`_p_dim' > 0 & `_p_dim' < `_p_len' & `_p_len' < `_p_head' & `_p_head' < `_p_trunk') {
    di as error "FAIL C5b: Dimensions group rows out of order " ///
        "(dim=`_p_dim' length=`_p_len' headroom=`_p_head' trunk=`_p_trunk')"
    local ++nfail
}

*------------------------------------------------------------------------------
* Summary
*------------------------------------------------------------------------------
if `nfail' == 0 {
    di as result "ALL test_eplot_v122 CHECKS PASSED"
}
else {
    di as error "`nfail' test_eplot_v122 CHECK(S) FAILED"
}
