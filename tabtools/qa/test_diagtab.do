* test_diagtab.do - Dedicated QA for diagtab

clear all
set more off
set varabbrev off

capture log close _diagtab
log using "test_diagtab.log", replace text name(_diagtab)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Known Answers
**## 2x2 measures match hand calculations
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = 0
    replace test = 1 in 1/40
    replace test = 1 in 51/70

    diagtab test gold

    assert abs(r(sensitivity) - 0.8) < 1e-10
    assert abs(r(specificity) - 0.6) < 1e-10
    assert abs(r(ppv) - (2/3)) < 1e-10
    assert abs(r(npv) - 0.75) < 1e-10
    assert abs(r(accuracy) - 0.7) < 1e-10
    assert abs(r(lr_pos) - 2) < 1e-10
    assert abs(r(lr_neg) - (1/3)) < 1e-10
    assert abs(r(dor) - 6) < 1e-10
    assert abs(r(youden) - 0.4) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: diagtab known-answer 2x2 measures"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab known-answer 2x2 measures (rc=`=_rc')"
    local ++fail_count
}

**# Cutoffs and AUC
**## auc/optimal work for a cleanly separated score
local ++test_count
capture noisily {
    clear
    set seed 12345
    set obs 200
    gen byte gold = (_n <= 100)
    gen double score = cond(gold, 0.80 + runiform() * 0.19, 0.01 + runiform() * 0.19)

    diagtab score gold, auc optimal

    assert r(auc) > 0.95
    assert r(optimal_cutoff) > 0.1
    assert r(optimal_cutoff) < 0.9
}
if _rc == 0 {
    display as result "  PASS: diagtab auc/optimal on separated scores"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab auc/optimal on separated scores (rc=`=_rc')"
    local ++fail_count
}

**## cutoffs() returns a cutoff table with one row per threshold
local ++test_count
capture noisily {
    clear
    set seed 12345
    set obs 200
    gen byte gold = (_n <= 100)
    gen double score = cond(gold, 0.80 + runiform() * 0.19, 0.01 + runiform() * 0.19)

    diagtab score gold, cutoffs(0.2 0.5 0.8)

    assert rowsof(r(cutoff_table)) == 3
    assert colsof(r(cutoff_table)) == 15
    assert real(word("`r(cutoffs)'", 1)) == 0.2
    assert real(word("`r(cutoffs)'", 2)) == 0.5
    assert real(word("`r(cutoffs)'", 3)) == 0.8
}
if _rc == 0 {
    display as result "  PASS: diagtab cutoffs() return matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab cutoffs() return matrix (rc=`=_rc')"
    local ++fail_count
}

**# Display, Frame, and Errors
**## frame() and display work together
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = 0
    replace test = 1 in 1/40
    replace test = 1 in 51/70

    capture frame drop diag_frame
    diagtab test gold, frame(diag_frame, replace) display subtitle("Validation sample")
    assert "`r(frame)'" == "diag_frame"
    frame diag_frame: assert _N >= 10
}
if _rc == 0 {
    display as result "  PASS: diagtab frame() + display"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab frame() + display (rc=`=_rc')"
    local ++fail_count
}
capture frame drop diag_frame

**## cutoff() and cutoffs() conflict cleanly
local ++test_count
capture noisily {
    clear
    set obs 50
    gen byte gold = (_n <= 25)
    gen double score = cond(gold, 0.9, 0.1)

    capture diagtab score gold, cutoff(0.5) cutoffs(0.2 0.5 0.8)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: diagtab cutoff()/cutoffs() conflict"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab cutoff()/cutoffs() conflict (rc=`=_rc')"
    local ++fail_count
}

display as result "diagtab QA summary: `pass_count' passed, `fail_count' failed"
if `fail_count' > 0 exit 1

log close _diagtab
