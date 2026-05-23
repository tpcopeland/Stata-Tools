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
    local cutoff_rows : rownames r(cutoff_table)
    assert "`cutoff_rows'" == "cut_p2 cut_p5 cut_p8"
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

**## cutoffs() matrix matches manual threshold counts with missings
local ++test_count
capture noisily {
    clear
    input byte gold double score
    1 0.95
    1 0.70
    1 0.30
    1 .
    0 0.85
    0 0.45
    0 0.15
    0 .
    end

    diagtab score gold, cutoffs(0.2 0.5 0.8)
    matrix C = r(cutoff_table)

    local _row 0
    foreach _cut in 0.2 0.5 0.8 {
        local ++_row
        quietly count if score >= `_cut' & gold == 1 & !missing(score, gold)
        local TP = r(N)
        quietly count if score >= `_cut' & gold == 0 & !missing(score, gold)
        local FP = r(N)
        quietly count if score < `_cut' & gold == 1 & !missing(score, gold)
        local FN = r(N)
        quietly count if score < `_cut' & gold == 0 & !missing(score, gold)
        local TN = r(N)

        assert abs(C[`_row', 1] - (`TP' / (`TP' + `FN'))) < 1e-12
        assert abs(C[`_row', 4] - (`TN' / (`TN' + `FP'))) < 1e-12
        assert abs(C[`_row', 7] - (`TP' / (`TP' + `FP'))) < 1e-12
        assert abs(C[`_row', 10] - (`TN' / (`TN' + `FN'))) < 1e-12
        assert abs(C[`_row', 13] - ((`TP' + `TN') / (`TP' + `FP' + `FN' + `TN'))) < 1e-12
    }
}
if _rc == 0 {
    display as result "  PASS: diagtab cutoffs() matches manual threshold counts"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab cutoffs() manual-count equivalence (rc=`=_rc')"
    local ++fail_count
}
capture matrix drop C

**## cutoffs() renders undefined predictive values explicitly
local ++test_count
capture noisily {
    clear
    input byte gold double score
    1 .25
    1 .35
    0 .25
    0 .35
    end

    capture frame drop diag_undef
    diagtab score gold, cutoffs(0.2 0.3 0.4) frame(diag_undef, replace)
    matrix C = r(cutoff_table)

    assert missing(C[1, 10])
    assert missing(C[3, 7])

    frame diag_undef {
        ds, has(type string)
        local string_vars `r(varlist)'
        local saw_explicit 0
        foreach v of varlist `string_vars' {
            quietly count if strtrim(`v') == "--"
            if r(N) > 0 local saw_explicit 1
        }
        assert `saw_explicit' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: diagtab cutoffs() renders undefined values explicitly"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab cutoffs() undefined-value rendering (rc=`=_rc')"
    local ++fail_count
}
capture frame drop diag_undef
capture matrix drop C

**## cutoffs() xlsx export preserves rendered table text
local ++test_count
capture noisily {
    clear
    input byte gold double score
    1 0.95
    1 0.70
    1 0.30
    0 0.85
    0 0.45
    0 0.15
    end

    capture erase "`output_dir'/_diagtab_perf_cutoffs.xlsx"
    diagtab score gold, cutoffs(0.2 0.5) ///
        xlsx("`output_dir'/_diagtab_perf_cutoffs.xlsx") sheet("DiagPerf") ///
        title("Diagnostic Performance")
    confirm file "`output_dir'/_diagtab_perf_cutoffs.xlsx"

    import excel using "`output_dir'/_diagtab_perf_cutoffs.xlsx", ///
        sheet("DiagPerf") clear allstring
    assert A[1] == "Diagnostic Performance"
    assert B[2] == "Cutoff"
    assert C[2] == "Estimate"
    assert D[2] == "(95% CI)"
    assert B[3] == "Cutoff >= .2"
    assert B[9] == "Cutoff >= .5"
    assert C[4] == "100.0%"
    assert C[10] == "66.7%"
}
if _rc == 0 {
    display as result "  PASS: diagtab cutoffs() xlsx preserves rendered text"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab cutoffs() xlsx rendered-text fidelity (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_diagtab_perf_cutoffs.xlsx"

	**## optimal rejects binary test variables
	local ++test_count
	capture noisily {
	    clear
	    set obs 80
	    gen byte gold = (_n <= 40)
	    gen byte test = 0
	    replace test = 1 in 1/30
	    replace test = 1 in 41/50

	    capture diagtab test gold, optimal
	    assert _rc == 198
	}
	if _rc == 0 {
	    display as result "  PASS: diagtab optimal rejects binary test variables"
	    local ++pass_count
	}
	else {
	    display as error "  FAIL: diagtab optimal rejects binary test variables (rc=`=_rc')"
	    local ++fail_count
	}

	**## auc requires both gold classes
	local ++test_count
capture noisily {
    clear
    set obs 40
    gen byte gold = 1
    gen double score = runiform()

    capture diagtab score gold, auc
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: diagtab auc rejects one-class gold variables"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab auc rejects one-class gold variables (rc=`=_rc')"
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
    diagtab test gold, frame(diag_frame, replace) display
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

**## open/xlsx and CI-method conflicts fail early
local ++test_count
capture noisily {
    clear
    set obs 50
    gen byte gold = (_n <= 25)
    gen double score = cond(gold, 0.9, 0.1)
    gen byte test = score >= 0.5

    capture diagtab test gold, open
    assert _rc == 198

    capture diagtab test gold, xlsx("bad_ext.txt")
    assert _rc == 198

    capture diagtab test gold, exact wilson
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: diagtab validates open/xlsx()/CI contracts"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab validates open/xlsx()/CI contracts (rc=`=_rc')"
    local ++fail_count
}

display as result "diagtab QA summary: `pass_count' passed, `fail_count' failed"
if `fail_count' > 0 exit 1

log close _diagtab
