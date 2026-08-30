* test_diagtab.do - Dedicated QA for diagtab

clear all
set more off
set varabbrev off
version 17.0

capture log close _diagtab
log using "test_diagtab.log", replace text name(_diagtab) nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$DIAGTAB_QA_OUTPUT_DIR" != "" local output_dir "$DIAGTAB_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
local tools_dir "`qa_dir'/tools"
local checker "`tools_dir'/check_xlsx.py"

capture ado uninstall diagtab
quietly net install diagtab, from("`pkg_dir'") replace

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

    assert !missing(r(auc))

    assert r(auc) > 0.95
    assert !missing(r(optimal_cutoff))
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

**## close and scientific cutoffs retain distinct identifiers and labels
local ++test_count
capture noisily {
    clear
    input byte gold double score
    1 1.00000015
    1 2
    0 1.00000015
    0 0
    end

    capture frame drop diag_close_cutoffs
    diagtab score gold, cutoffs(1.0000001 1.0000002) ///
        frame(diag_close_cutoffs, replace)
    matrix C = r(cutoff_table)
    local cutoff_rows : rownames C
    assert word("`cutoff_rows'", 1) != word("`cutoff_rows'", 2)
    assert C[1, 1] == 1
    assert C[2, 1] == 0.5

    frame diag_close_cutoffs: generate byte _cutoff_row = ///
        strpos(c1, "Cutoff >=") == 1
    frame diag_close_cutoffs: bysort c1: generate byte _cutoff_dup = _N
    frame diag_close_cutoffs: assert _cutoff_dup == 1 if _cutoff_row

    capture frame drop diag_close_cutoffs
    clear
    input byte gold double score
    1 1e-10
    1 1.0000000001e-10
    0 0
    0 2e-10
    end
    diagtab score gold, cutoffs(1e-10 1.0000000001e-10) ///
        frame(diag_close_cutoffs, replace)
    matrix C = r(cutoff_table)
    local cutoff_rows : rownames C
    assert word("`cutoff_rows'", 1) != word("`cutoff_rows'", 2)
    assert C[1, 1] == 1
    assert C[2, 1] == 0.5
    frame diag_close_cutoffs: generate byte _cutoff_row = ///
        strpos(c1, "Cutoff >=") == 1
    frame diag_close_cutoffs: bysort c1: generate byte _cutoff_dup = _N
    frame diag_close_cutoffs: assert _cutoff_dup == 1 if _cutoff_row

    * A threshold that needs 17 significant digits must not shift upward when
    * normalized: a score exactly equal to it remains test-positive.
    capture frame drop diag_close_cutoffs
    clear
    input byte gold double score
    1 1.2345678901234567
    1 2
    0 0
    0 0.5
    end
    diagtab score gold, cutoffs(1.2345678901234567)
    matrix C = r(cutoff_table)
    assert C[1, 1] == 1
    assert abs(real(word("`r(cutoffs)'", 1)) - ///
        1.2345678901234567) < 1e-16

    diagtab score gold, cutoff(1.2345678901234567)
    assert r(sensitivity) == 1
    assert r(specificity) == 1

    diagtab score gold, optimal
    assert r(sensitivity) == 1
    assert r(specificity) == 1
    assert abs(r(optimal_cutoff) - 1.2345678901234567) < 1e-16
}
if _rc == 0 {
    display as result "  PASS: close/scientific cutoffs have unique names and labels"
    local ++pass_count
}
else {
    display as error "  FAIL: close/scientific cutoff mapping (rc=`=_rc')"
    local ++fail_count
}
capture frame drop diag_close_cutoffs
capture matrix drop C

**## cutoffs() preserves numeric sorting and numlist range expansion
local ++test_count
capture noisily {
    clear
    input byte gold double score
    1 0.9
    1 0.6
    0 0.4
    0 0.1
    end

    diagtab score gold, cutoffs(0.8 0.2 0.5)
    assert rowsof(r(cutoff_table)) == 3
    assert abs(real(word("`r(cutoffs)'", 1)) - 0.2) < 1e-15
    assert abs(real(word("`r(cutoffs)'", 2)) - 0.5) < 1e-15
    assert abs(real(word("`r(cutoffs)'", 3)) - 0.8) < 1e-15

    diagtab score gold, cutoffs(0.2(0.3)0.8)
    assert rowsof(r(cutoff_table)) == 3
    assert abs(real(word("`r(cutoffs)'", 1)) - 0.2) < 1e-15
    assert abs(real(word("`r(cutoffs)'", 2)) - 0.5) < 1e-15
    assert abs(real(word("`r(cutoffs)'", 3)) - 0.8) < 1e-15
}
if _rc == 0 {
    display as result "  PASS: cutoffs() sorts values and expands numlist ranges"
    local ++pass_count
}
else {
    display as error "  FAIL: cutoffs() sorting/range expansion (rc=`=_rc')"
    local ++fail_count
}

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
    * Section labels are rendered at one precision, with a leading zero: the
    * old per-cutoff %9.0g formatting produced ".2" / ".5".
    assert B[3] == "Cutoff >= 0.2"
    assert B[9] == "Cutoff >= 0.5"
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
 diagtab test gold, frame(diag_frame, replace)
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
**# Migrated: core diagtab suite

**# SECTION 4: diagtab
* ============================================================

* Create diagnostic test dataset
clear
set obs 500
set seed 42
gen gold = runiform() < 0.2
gen test_score = rnormal(0, 1) + 1.5 * gold
gen test_binary = test_score > 0.5
label define goldlbl 0 "Negative" 1 "Positive"
label values gold goldlbl
tempfile diagdata
save `diagdata'

* Test: diagtab basic with binary test
capture noisily {
    use `diagdata', clear
 diagtab test_binary gold
}
if _rc == 0 {
    display as result "  PASS: diagtab basic binary test"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab basic binary test (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab returns sensitivity and specificity
capture noisily {
    use `diagdata', clear
 diagtab test_binary gold
    assert !missing(r(sensitivity))
    assert !missing(r(specificity))
    assert !missing(r(ppv))
    assert !missing(r(npv))
    assert !missing(r(accuracy))
    assert !missing(r(sensitivity))
    assert r(sensitivity) > 0 & r(sensitivity) <= 1
    assert !missing(r(specificity))
    assert r(specificity) > 0 & r(specificity) <= 1
}
if _rc == 0 {
    display as result "  PASS: diagtab returns valid Se/Sp/PPV/NPV"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab r() values (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab with cutoff for continuous test
capture noisily {
    use `diagdata', clear
 diagtab test_score gold, cutoff(0.5)
    assert !missing(r(sensitivity))
}
if _rc == 0 {
    display as result "  PASS: diagtab cutoff() for continuous test"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab cutoff() (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab rejects continuous test without cutoff
capture {
    use `diagdata', clear
 diagtab test_score gold
}
if _rc == 198 {
    display as result "  PASS: diagtab rejects continuous test without cutoff"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab continuous-without-cutoff expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: diagtab exact CIs
capture noisily {
    use `diagdata', clear
 diagtab test_binary gold, exact
}
if _rc == 0 {
    display as result "  PASS: diagtab exact CIs"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab exact CIs (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab wilson CIs (default)
capture noisily {
    use `diagdata', clear
 diagtab test_binary gold, wilson
}
if _rc == 0 {
    display as result "  PASS: diagtab wilson CIs"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab wilson CIs (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab auc option
capture noisily {
    use `diagdata', clear
 diagtab test_score gold, cutoff(0.5) auc
    assert !missing(r(auc))
    assert !missing(r(auc))
    assert r(auc) > 0.5 & r(auc) <= 1
}
if _rc == 0 {
    display as result "  PASS: diagtab auc option"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab auc option (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab optimal cutoff via Youden
capture noisily {
    use `diagdata', clear
 diagtab test_score gold, cutoff(0.5) optimal
    assert !missing(r(optimal_cutoff))
    assert !missing(r(youden))
}
if _rc == 0 {
    display as result "  PASS: diagtab optimal cutoff"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab optimal cutoff (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab prevalence adjustment
capture noisily {
    use `diagdata', clear
 diagtab test_binary gold, prevalence(0.05)
}
if _rc == 0 {
    display as result "  PASS: diagtab prevalence(0.05)"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab prevalence() (rc=`=_rc')"
    local ++fail_count
}

* Regression: diagtab must reject invalid prevalence values
capture {
    use `diagdata', clear
 diagtab test_binary gold, prevalence(1.2)
}
if _rc == 198 {
    display as result "  PASS: diagtab rejects prevalence() outside (0,1)"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab invalid prevalence() expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: diagtab xlsx export
capture noisily {
    use `diagdata', clear
    capture erase "`output_dir'/test_diagtab.xlsx"
    diagtab test_binary gold, xlsx("`output_dir'/test_diagtab.xlsx") ///
        sheet("Dx") auc
    confirm file "`output_dir'/test_diagtab.xlsx"
    assert !missing(r(auc))
}
if _rc == 0 {
    display as result "  PASS: diagtab xlsx export"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab xlsx export (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab rejects auc with cutoffs()
capture {
    use `diagdata', clear
 diagtab test_score gold, cutoffs(0.25 0.5) auc
}
if _rc == 198 {
    display as result "  PASS: diagtab rejects auc with cutoffs()"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab auc+cutoffs() expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: diagtab r(methods) returned
capture noisily {
    use `diagdata', clear
 diagtab test_binary gold
    assert "`r(methods)'" != ""
}
if _rc == 0 {
    display as result "  PASS: diagtab r(methods)"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab r(methods) (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab LR+, LR-, DOR returned
capture noisily {
    use `diagdata', clear
 diagtab test_binary gold
    assert !missing(r(lr_pos))
    assert !missing(r(lr_neg))
    assert !missing(r(dor))
}
if _rc == 0 {
    display as result "  PASS: diagtab LR+/LR-/DOR returned"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab LR+/LR-/DOR (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab csv export
capture noisily {
    use `diagdata', clear
 diagtab test_binary gold, csv("`output_dir'/test_diagtab.csv")
    confirm file "`output_dir'/test_diagtab.csv"
}
if _rc == 0 {
    display as result "  PASS: diagtab csv export"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab csv export (rc=`=_rc')"
    local ++fail_count
}

* Test: Markdown export, append mode, and return metadata
capture noisily {
    use `diagdata', clear
    tempname md_tag md_fh
    local md_path "`output_dir'/`md_tag'.md"
    capture erase "`md_path'"

    diagtab test_binary gold, markdown("`md_path'") ///
        title("First diagnostic table") footnote("First footnote")
    assert `"`r(markdown)'"' == `"`md_path'"'
    assert !missing(r(markdown_rows))
    assert r(markdown_rows) > 0
    assert r(markdown_cols) == 3

    diagtab test_binary gold, markdown("`md_path'") mdappend ///
        title("Second diagnostic table") footnote("Second footnote")
    assert `"`r(markdown)'"' == `"`md_path'"'
    assert !missing(r(markdown_rows))
    assert r(markdown_rows) > 0
    assert r(markdown_cols) == 3

    file open `md_fh' using "`md_path'", read text
    file read `md_fh' md_line
    local saw_first = 0
    local saw_second = 0
    local saw_footnote = 0
    while r(eof) == 0 {
        if strpos(`"`md_line'"', "First diagnostic table") local saw_first = 1
        if strpos(`"`md_line'"', "Second diagnostic table") local saw_second = 1
        if strpos(`"`md_line'"', "Second footnote") local saw_footnote = 1
        file read `md_fh' md_line
    }
    file close `md_fh'
    assert `saw_first' == 1
    assert `saw_second' == 1
    assert `saw_footnote' == 1
    capture erase "`md_path'"
}
if _rc == 0 {
    display as result "  PASS: diagtab Markdown append and return metadata"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab Markdown append/returns (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab frame output
capture noisily {
    use `diagdata', clear
    capture frame drop diagframe
 diagtab test_binary gold, frame(diagframe)
    assert r(frame) == "diagframe"
    frame diagframe: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: diagtab frame output"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab frame output (rc=`=_rc')"
    local ++fail_count
}
capture frame drop diagframe

* Test: diagtab with if condition
capture noisily {
    use `diagdata', clear
    gen byte subset = _n <= 300
 diagtab test_binary gold if subset
    assert !missing(r(sensitivity))
}
if _rc == 0 {
    display as result "  PASS: diagtab with if condition"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab with if condition (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab data preservation
capture noisily {
    use `diagdata', clear
    local orig_n = _N
 diagtab test_binary gold
    assert _N == `orig_n'
}
if _rc == 0 {
    display as result "  PASS: diagtab data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab data preservation (rc=`=_rc')"
    local ++fail_count
}

* ============================================================

**# Migrated: degenerate 2x2 undefined marker

**# 8. diagtab degenerate 2x2 shows explicit undefined marker (I6 regression)

**## 8a. All test-positive (FN=0, TN=0): NPV shows "--"
capture noisily {
    clear
    set obs 50
    gen byte gold = cond(_n <= 30, 1, 0)
    gen byte test = 1
    local i6_xlsx "`output_dir'/_rev1013_i6_diagtab.xlsx"
    capture erase "`i6_xlsx'"
    diagtab test gold, xlsx("`i6_xlsx'") sheet("AllPos")

    * Read back after command returns (avoids nested preserve)
    clear
    import excel using "`i6_xlsx'", sheet("AllPos") allstring clear
    local found_dash = 0
    ds
    foreach v in `r(varlist)' {
        forvalues i = 1/`=_N' {
            if strtrim(`v'[`i']) == "NPV" {
                * Check the next column for em-dash
                local found_dash = 1
            }
        }
    }
    * Also check: find the NPV row and verify column B is "--"
    local found_dash = 0
    forvalues i = 1/`=_N' {
        if strtrim(A[`i']) == "NPV" | strtrim(B[`i']) == "NPV" {
            * The value column follows the label column
            if strtrim(A[`i']) == "NPV" & strtrim(B[`i']) == "--" local found_dash = 1
            if strtrim(B[`i']) == "NPV" & strtrim(C[`i']) == "--" local found_dash = 1
        }
    }
    assert `found_dash' == 1
}
if _rc == 0 {
    display as result "  PASS [8a]: diagtab all-test-positive: NPV shows --"
    local ++pass_count
}
else {
    display as error "  FAIL [8a]: diagtab all-test-positive: NPV does not show -- (rc=`=_rc')"
    local ++fail_count
}

**## 8b. All test-negative (TP=0, FP=0): PPV shows "--" (Se=0% is correct, not undefined)
capture noisily {
    clear
    set obs 50
    gen byte gold = cond(_n <= 30, 1, 0)
    gen byte test = 0
    local i6b_xlsx "`output_dir'/_rev1013_i6b_diagtab.xlsx"
    capture erase "`i6b_xlsx'"
    diagtab test gold, xlsx("`i6b_xlsx'") sheet("AllNeg")

    clear
    import excel using "`i6b_xlsx'", sheet("AllNeg") allstring clear
    local ppv_dash = 0
    forvalues i = 1/`=_N' {
        if strtrim(A[`i']) == "PPV" & strtrim(B[`i']) == "--" local ppv_dash = 1
        if strtrim(B[`i']) == "PPV" & strtrim(C[`i']) == "--" local ppv_dash = 1
    }
    assert `ppv_dash' == 1
}
if _rc == 0 {
    display as result "  PASS [8b]: diagtab all-test-negative: PPV shows --"
    local ++pass_count
}
else {
    display as error "  FAIL [8b]: diagtab all-test-negative: PPV not -- (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_rev1013_i6_diagtab.xlsx"
capture erase "`output_dir'/_rev1013_i6b_diagtab.xlsx"



**# Migrated: prevalence edge cases

**# diagtab prevalence edge cases
* =========================================================================

**## Se=0 Sp=1 with prevalence() does not crash
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = 0
    replace test = 1 in 51/100

    diagtab test gold, prevalence(0.3)

    assert abs(r(sensitivity) - 0) < 1e-10
    assert abs(r(specificity) - 0) < 1e-10
    // PPV denominator = Se*prev + (1-Sp)*(1-prev) = 0*0.3 + 1*0.7 = 0.7
    // NPV denominator = (1-Se)*prev + Sp*(1-prev) = 1*0.3 + 0*0.7 = 0.3
    assert !missing(r(ppv))
    assert !missing(r(npv))
}
if _rc == 0 {
    display as result "  PASS: diagtab Se=0 Sp=0 with prevalence does not crash"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab Se=0 Sp=0 with prevalence crashed (rc=`=_rc')"
    local ++fail_count
}

**## Perfect Se=1 Sp=0 with prevalence() does not crash
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = 1

    diagtab test gold, prevalence(0.3)

    assert abs(r(sensitivity) - 1) < 1e-10
    assert abs(r(specificity) - 0) < 1e-10
    assert !missing(r(ppv))
    // NPV denom = (1-Se)*prev + Sp*(1-prev) = 0*0.3 + 0*0.7 = 0 → missing
    assert missing(r(npv))
}
if _rc == 0 {
    display as result "  PASS: diagtab Se=1 Sp=0 with prevalence does not crash"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab Se=1 Sp=0 with prevalence crashed (rc=`=_rc')"
    local ++fail_count
}

**## Se=1 Sp=1 with prevalence: PPV and NPV both 1
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = gold

    diagtab test gold, prevalence(0.5)

    assert abs(r(sensitivity) - 1) < 1e-10
    assert abs(r(specificity) - 1) < 1e-10
    assert abs(r(ppv) - 1) < 1e-10
    assert abs(r(npv) - 1) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: diagtab perfect classifier with prevalence"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab perfect classifier with prevalence (rc=`=_rc')"
    local ++fail_count
}

**## Se=0 Sp=1 edge case: PPV denominator = 0, PPV should be missing
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = 0

    diagtab test gold, prevalence(0.3)

    assert abs(r(sensitivity) - 0) < 1e-10
    assert abs(r(specificity) - 1) < 1e-10
    // PPV denom = Se*prev + (1-Sp)*(1-prev) = 0*0.3 + 0*0.7 = 0
    // PPV should remain missing (division guarded)
    assert missing(r(ppv))
    // NPV denom = (1-Se)*prev + Sp*(1-prev) = 1*0.3 + 1*0.7 = 1
    assert abs(r(npv) - 0.7) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: diagtab Se=0 Sp=1 prevalence: PPV=. NPV=0.7"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab Se=0 Sp=1 prevalence edge case (rc=`=_rc')"
    local ++fail_count
}

**## Se=1 Sp=0: NPV denominator = 0, NPV should be missing
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = 1

    replace gold = 0 in 1/50
    replace gold = 1 in 51/100
    replace test = gold

    replace test = 1

    diagtab test gold, prevalence(0.3)

    assert abs(r(sensitivity) - 1) < 1e-10
    assert abs(r(specificity) - 0) < 1e-10
    // NPV denom = (1-Se)*prev + Sp*(1-prev) = 0*0.3 + 0*0.7 = 0
    assert missing(r(npv))
    // PPV denom = Se*prev + (1-Sp)*(1-prev) = 1*0.3 + 1*0.7 = 1
    assert abs(r(ppv) - 0.3) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: diagtab Se=1 Sp=0 prevalence: NPV=. PPV=0.3"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab Se=1 Sp=0 prevalence edge case (rc=`=_rc')"
    local ++fail_count
}

**## Cutoffs path: Se=0 Sp=1 with prevalence via cutoff()
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen double score = cond(gold, 0.7, 0.3)

    diagtab score gold, cutoff(0.5) prevalence(0.3)

    assert abs(r(sensitivity) - 1) < 1e-10
    assert abs(r(specificity) - 1) < 1e-10
    assert abs(r(ppv) - 1) < 1e-10
    assert abs(r(npv) - 1) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: diagtab cutoff path with prevalence adjustment"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab cutoff path prevalence adjustment (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: cutoff/cutoffs abbreviation

**# QA Gap 2: diagtab cutoff/cutoffs abbreviation

**## 2a. Full "cutoff" works
capture noisily {
    clear
    set obs 200
    set seed 42
    gen gold = runiform() > 0.5
    gen test_cont = rnormal(0, 1) + gold * 0.5
    diagtab test_cont gold, cutoff(0.5)
    assert r(sensitivity) < .
    assert r(specificity) < .
}
if _rc == 0 {
    display as result "  PASS [2a]: diagtab cutoff(0.5) works"
    local ++pass_count
}
else {
    display as error "  FAIL [2a]: diagtab cutoff (rc=`=_rc')"
    local ++fail_count
}

**## 2b. Full "cutoffs" works
capture noisily {
    clear
    set obs 200
    set seed 42
    gen gold = runiform() > 0.5
    gen test_cont = rnormal(0, 1) + gold * 0.5
    diagtab test_cont gold, cutoffs(0.3 0.5 0.7)
    * r(cutoffs) may use Stata's float display (e.g., ".3 .5 .7")
    assert "`r(cutoffs)'" != ""
    local ncuts = rowsof(r(cutoff_table))
    assert `ncuts' == 3
}
if _rc == 0 {
    display as result "  PASS [2b]: diagtab cutoffs(0.3 0.5 0.7) works"
    local ++pass_count
}
else {
    display as error "  FAIL [2b]: diagtab cutoffs (rc=`=_rc')"
    local ++fail_count
}

**## 2c. Abbreviated "cut" matches cutoff (single)
capture noisily {
    clear
    set obs 200
    set seed 42
    gen gold = runiform() > 0.5
    gen test_cont = rnormal(0, 1) + gold * 0.5
    diagtab test_cont gold, cut(0.5)
    assert r(sensitivity) < .  // single-cutoff returns scalars
}
if _rc == 0 {
    display as result "  PASS [2c]: diagtab cut(0.5) abbreviation resolves to cutoff"
    local ++pass_count
}
else {
    display as error "  FAIL [2c]: diagtab cut abbreviation (rc=`=_rc')"
    local ++fail_count
}

**## 2d. cutoff and cutoffs are mutually exclusive
capture {
    clear
    set obs 200
    set seed 42
    gen gold = runiform() > 0.5
    gen test_cont = rnormal(0, 1) + gold * 0.5
    diagtab test_cont gold, cutoff(0.5) cutoffs(0.3 0.7)
}
if _rc == 198 {
    display as result "  PASS [2d]: cutoff + cutoffs rejected as mutually exclusive (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL [2d]: cutoff + cutoffs should give rc=198, got rc=`=_rc'"
    local ++fail_count
}



**# Migrated: cutoff vs cutoffs independence

**# Regression: I1 — diagtab cutoff and cutoffs are independent options

**## R1. cutoff returns scalars (single-cutoff path)
capture noisily {
    clear
    set obs 300
    set seed 42
    gen gold = runiform() > 0.5
    gen test_val = rnormal() + gold * 0.5
    diagtab test_val gold, cutoff(0)
    assert r(TP) < .
    assert r(FP) < .
    assert r(sensitivity) < .
}
if _rc == 0 {
    display as result "  PASS [R1]: diagtab cutoff(0) returns scalars"
    local ++pass_count
}
else {
    display as error "  FAIL [R1]: diagtab cutoff scalars (rc=`=_rc')"
    local ++fail_count
}

**## R2. cutoffs returns matrix (multi-cutoff path)
capture noisily {
    clear
    set obs 300
    set seed 42
    gen gold = runiform() > 0.5
    gen test_val = rnormal() + gold * 0.5
    diagtab test_val gold, cutoffs(-0.5 0 0.5 1)
    matrix _ct = r(cutoff_table)
    assert rowsof(_ct) == 4
    assert colsof(_ct) == 15  // Se, Se_lo, Se_hi, Sp, ... (15 cols)
    matrix drop _ct
}
if _rc == 0 {
    display as result "  PASS [R2]: diagtab cutoffs(-0.5 0 0.5 1) returns 4-row matrix"
    local ++pass_count
}
else {
    display as error "  FAIL [R2]: diagtab cutoffs matrix (rc=`=_rc')"
    local ++fail_count
}



**# Migrated: border abbreviation and rich Excel alias contract

* T3: excel() aliases xlsx(), formatting options affect the artifact, and
*     r(xlsx) reports the actual destination.
sysuse auto, clear
gen byte _gold = foreign
gen byte _test = (mpg >= 25)
local _t3_xlsx "`output_dir'/_diagtab_excel_alias.xlsx"
local _t3_status "`output_dir'/_diagtab_excel_alias.status"
capture erase "`_t3_xlsx'"
capture erase "`_t3_status'"
capture noisily {
    confirm file "`checker'"
    diagtab _test _gold, excel("`_t3_xlsx'") sheet("Alias") ///
        title("QA title") footnote("QA footnote") digits(2) border(thin)
    assert `"`r(xlsx)'"' == `"`_t3_xlsx'"'
    shell python3 "`checker'" "`_t3_xlsx'" --sheet "Alias" ///
        --contains "QA title" --contains "QA footnote" ///
        --contains "50.00%" --has-borders --border-style thin ///
        --result-file "`_t3_status'" --quiet
    tempname _t3_fh
    file open `_t3_fh' using "`_t3_status'", read text
    file read `_t3_fh' _t3_result
    file close `_t3_fh'
    assert "`_t3_result'" == "PASS"
}
local _t3_rc = _rc
drop _gold _test
if `_t3_rc' == 0 {
    display as result "  PASS T3: excel alias, digits/title/footnote, border, and r(xlsx)"
    local ++pass_count
}
else {
    display as error "  FAIL T3: rich Excel alias contract (rc=`_t3_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}
capture erase "`_t3_xlsx'"
capture erase "`_t3_status'"


**# Migrated: single-cutoff zebra + headershade

* T11: inspect the workbook rather than accepting rc=0 as evidence that
*      headercolor(), zebracolor(), headershade, and zebra were applied.
sysuse auto, clear
gen byte _gold = foreign
gen byte _test = (mpg >= 25)
local _t11_xlsx "`output_dir'/_v103_diagtab.xlsx"
local _t11_status "`output_dir'/_v103_diagtab.status"
capture erase "`_t11_xlsx'"
capture erase "`_t11_status'"
capture noisily {
    confirm file "`checker'"
    diagtab _test _gold, xlsx("`_t11_xlsx'") sheet("Test") ///
        zebra zebracolor("217 234 247") ///
        headershade headercolor("31 78 121") border(thin)
    shell python3 "`checker'" "`_t11_xlsx'" --sheet "Test" ///
        --row-fill-contains "Gold +" "31 78 121" ///
        --row-fill-contains "Sensitivity" "217 234 247" ///
        --result-file "`_t11_status'" --quiet
    tempname _t11_fh
    file open `_t11_fh' using "`_t11_status'", read text
    file read `_t11_fh' _t11_result
    file close `_t11_fh'
    assert "`_t11_result'" == "PASS"
}
local _t11_rc = _rc
if `_t11_rc' == 0 {
    display as result "  PASS T11: header and zebra fills match requested colors"
    local ++pass_count
}
else {
    display as error "  FAIL T11: workbook fill assertions (rc=`_t11_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T11"
}
drop _gold _test
capture erase "`_t11_xlsx'"
capture erase "`_t11_status'"

* ============================================================



display as result "diagtab QA summary: `pass_count' passed, `fail_count' failed"
local _tc = `pass_count' + `fail_count'
display "RESULT: test_diagtab tests=`_tc' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1

log close _diagtab
