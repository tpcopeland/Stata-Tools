* crossval_episensr_dta.do -- exact fixed-parameter parity with episensr
clear all
set more off
set varabbrev off
version 16.0

* episensr::misclass() and qba_misclass implement the same deterministic 2x2
* exposure-misclassification correction.  Neither simple-mode API supplies a
* method-equivalent sampling SE; episensr bootstrap intervals and qba's
* probabilistic intervals use different simulation constructions, so this gate
* deliberately compares only the shared deterministic estimand.

do "`c(pwd)'/_qba_qa_common.do"
_qba_qa_bootstrap, isolated
local orig_plus `"`r(orig_plus)'"'
local orig_personal `"`r(orig_personal)'"'
local plusdir `"`r(plusdir)'"'
local personaldir `"`r(personaldir)'"'

local tests = 0
local pass = 0
local fail = 0
local qa_dir "`c(pwd)'"
local r_script "`qa_dir'/tools/oracle_episensr_dta.R"

* This fixed scenario intentionally has differential parameters and noninteger
* corrected cells.  It detects a swapped stratum, matrix-orientation error, or
* a CSV float round-trip that a rounded printed example could hide.
clear
set obs 1
gen double a = 215
gen double b = 1449
gen double c = 668
gen double d = 4296
gen double seca = .78
gen double secb = .73
gen double spca = .99
gen double spcb = .96
tempfile r_input r_output
save "`r_input'", replace

shell Rscript "`r_script'" "`r_input'" "`r_output'"
capture confirm file "`r_output'"
if _rc {
    _qba_qa_restore_isolation, origplus("`orig_plus'") ///
        origpersonal("`orig_personal'") plusdir("`plusdir'") ///
        personaldir("`personaldir'") uninstall
    display as error "episensr .dta oracle did not produce output"
    display "RESULT: crossval_episensr_dta tests=0 pass=0 fail=0 skip=0"
    exit 601
}

qba_misclass, a(215) b(1449) c(668) d(4296) ///
    seca(.78) secb(.73) spca(.99) spcb(.96) type(exposure)
local stata_a = r(corrected_a)
local stata_b = r(corrected_b)
local stata_c = r(corrected_c)
local stata_d = r(corrected_d)
local stata_or = r(corrected)
qba_misclass, a(215) b(1449) c(668) d(4296) ///
    seca(.78) secb(.73) spca(.99) spcb(.96) type(exposure) measure(RR)
local stata_rr = r(corrected)

use "`r_output'", clear
quietly count
assert r(N) == 6
quietly count if missing(value)
assert r(N) == 0
foreach item in a b c d rr or {
    quietly count if name == "`item'"
    assert r(N) == 1
    quietly summarize value if name == "`item'", meanonly
    local r_`item' = r(mean)
}

foreach item in a b c d rr or {
    local ++tests
    local stata = `stata_`item''
    capture noisily assert !missing(`stata', `r_`item'') & ///
        abs(`stata' - `r_`item'') < 1e-10
    if _rc == 0 local ++pass
    else local ++fail
}

_qba_qa_restore_isolation, origplus("`orig_plus'") ///
    origpersonal("`orig_personal'") plusdir("`plusdir'") ///
    personaldir("`personaldir'") uninstall
display "RESULT: crossval_episensr_dta tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' > 0 exit 1
