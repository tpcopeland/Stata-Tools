/*******************************************************************************
* test_colors_routing.do
*
* Purpose: Regression tests for the v1.2.1 bug fixes
*   - insigncolor() now parses and is honored in all modes (was a silent no-op;
*     the documented spelling previously aborted with r(198))
*   - a mistyped estimate name routes to estimates mode and reports
*     "estimation results 'X' not found" (was a misleading "variable not found")
*   - the .ado is safe to re-run in a session (cap program drop guards)
*
* Author: Timothy Copeland
* Date: 2026-06-14
*******************************************************************************/

clear all
set more off
version 16.0

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

* Targeted reinstall of the package under test so no installed copy shadows it
cap ado uninstall eplot
net install eplot, from("`pkg_dir'") replace

local nfail 0

*------------------------------------------------------------------------------
* C1: insigncolor() is honored (estimates mode)
*------------------------------------------------------------------------------
sysuse auto, clear
logit foreign mpg weight headroom turn

* documented spelling must parse (previously aborted r198)
cap noisily eplot ., noconstant sigcolors sigcolor(navy) insigncolor(gs12) cicap
if _rc {
    di as error "FAIL C1a: insigncolor(gs12) did not parse (rc=" _rc ")"
    local ++nfail
}
* the user-supplied color must appear in the executed command, not the gs10 default
if !strpos(`"`r(cmd)'"', "gs12") {
    di as error "FAIL C1b: insigncolor(gs12) not honored; r(cmd) lacks gs12"
    local ++nfail
}
if strpos(`"`r(cmd)'"', "gs10") {
    di as error "FAIL C1c: gs10 default leaked despite insigncolor(gs12)"
    local ++nfail
}

*------------------------------------------------------------------------------
* C1 (matrix mode): insigncolor() honored
*------------------------------------------------------------------------------
matrix b = (0.5 \ -0.3 \ 1.2)
matrix rownames b = a b c
* attach an se column so we have a 2-col matrix and CIs
matrix M = (0.5, 0.2 \ -0.3, 0.4 \ 1.2, 0.3)
matrix rownames M = a b c
cap noisily eplot, matrix(M) sigcolors insigncolor(gs14)
if _rc {
    di as error "FAIL C1d: matrix-mode insigncolor did not parse (rc=" _rc ")"
    local ++nfail
}
if !strpos(`"`r(cmd)'"', "gs14") {
    di as error "FAIL C1e: matrix-mode insigncolor(gs14) not honored"
    local ++nfail
}

*------------------------------------------------------------------------------
* I1: mistyped estimate names report the proper error
*------------------------------------------------------------------------------
sysuse auto, clear
logit foreign mpg weight
estimates store mFull

* one valid estimate + one typo -> estimates mode, proper r(111)
cap noisily eplot mFull nonesuch
if _rc != 111 {
    di as error "FAIL I1a: expected r(111) for mistyped name, got " _rc
    local ++nfail
}

* single typo -> estimates mode, proper r(111)
cap noisily eplot nonesuch2
if _rc != 111 {
    di as error "FAIL I1b: expected r(111) for single mistyped name, got " _rc
    local ++nfail
}

* genuine data mode (3 numeric vars) still routes to data mode
sysuse auto, clear
gen lo = mpg - 2
gen hi = mpg + 2
cap noisily eplot mpg lo hi
if _rc {
    di as error "FAIL I1c: data-mode call (3 numeric vars) failed (rc=" _rc ")"
    local ++nfail
}

*------------------------------------------------------------------------------
* M1: re-running the .ado in a session must not crash with "already defined"
*------------------------------------------------------------------------------
cap run "`pkg_dir'/eplot.ado"
cap run "`pkg_dir'/eplot.ado"
if _rc {
    di as error "FAIL M1: re-running eplot.ado crashed (rc=" _rc ")"
    local ++nfail
}

*------------------------------------------------------------------------------
* varabbrev must be restored after every path
*------------------------------------------------------------------------------
set varabbrev on
sysuse auto, clear
logit foreign mpg weight
qui eplot .
if "`c(varabbrev)'" != "on" {
    di as error "FAIL: varabbrev not restored after success path"
    local ++nfail
}
cap eplot nonesuch3
if "`c(varabbrev)'" != "on" {
    di as error "FAIL: varabbrev not restored after error path"
    local ++nfail
}
set varabbrev off

*------------------------------------------------------------------------------
if `nfail' == 0 {
    di as result "ALL test_colors_routing CHECKS PASSED"
}
else {
    di as error "`nfail' test_colors_routing CHECK(S) FAILED"
    exit 9
}
