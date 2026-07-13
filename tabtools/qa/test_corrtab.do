* test_corrtab.do - Dedicated QA for corrtab

clear all
set more off
set varabbrev off

capture log close _corrtab
log using "test_corrtab.log", replace text name(_corrtab)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
local tools_dir "`qa_dir'/tools"
local checker "`tools_dir'/check_xlsx.py"
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

**## pairwise N matrix matches manual nonmissing overlaps
local ++test_count
capture noisily {
    clear
    input double x y z w
    1  2  .  4
    2  .  5  3
    .  4  6  2
    4  5  7  .
    5  6  .  0
    .  7  9  1
    end

    corrtab x y z w, full
    matrix N = r(N)

    local vars x y z w
    forvalues i = 1/4 {
        local vi : word `i' of `vars'
        forvalues j = 1/4 {
            local vj : word `j' of `vars'
            quietly count if !missing(`vi') & !missing(`vj')
            assert N[`i', `j'] == r(N)
        }
    }
}
if _rc == 0 {
    display as result "  PASS: corrtab pairwise N matches manual overlaps"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab pairwise N manual-overlap equivalence (rc=`=_rc')"
    local ++fail_count
}
capture matrix drop N

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

**## undefined correlations stay missing without false stars or p-values
local ++test_count
capture noisily {
    clear
    set obs 10
    gen double x = _n
    gen double y = 1

    capture frame drop _corr_const
    corrtab x y, full frame(_corr_const, replace)

    assert missing(r(C)[2, 1])
    assert missing(r(P)[2, 1])
    frame _corr_const {
        assert strtrim(c2[4]) == "."
        assert strpos(c2[4], "*") == 0
    }

    capture frame drop _corr_const_p
    corrtab x y, full pvalues frame(_corr_const_p, replace)

    assert missing(r(P)[2, 1])
    frame _corr_const_p {
        assert strtrim(c2[4]) == "."
        assert strpos(c2[4], "(") == 0
        assert strpos(c2[4], "<0.001") == 0
    }
}
if _rc == 0 {
    display as result "  PASS: corrtab leaves undefined correlations missing"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab leaves undefined correlations missing (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _corr_const
capture frame drop _corr_const_p

**## sparse Spearman overlaps return missing cells instead of aborting
local ++test_count
capture noisily {
    clear
    set obs 6
    gen double x = .
    gen double y = .
    gen double z = .
    replace x = _n in 1/3
    replace y = _n in 1/3
    replace z = _n - 3 in 4/6

    capture frame drop _corr_sparse
    corrtab x y z, spearman full frame(_corr_sparse, replace)

    assert r(N)[1, 2] == 3
    assert r(N)[1, 3] == 0
    assert r(N)[2, 3] == 0
    assert missing(r(C)[1, 3])
    assert missing(r(P)[1, 3])
    local p_rows : rownames r(P)
    local p_cols : colnames r(P)
    assert "`p_rows'" == "x y z"
    assert "`p_cols'" == "x y z"
}
if _rc == 0 {
    display as result "  PASS: corrtab sparse Spearman overlap stays pairwise"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab sparse Spearman overlap stays pairwise (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _corr_sparse

**## Spearman pairwise correlations and p-values keep Stata pairwise behavior
local ++test_count
capture noisily {
    clear
    input double x y z
    1  1  .
    2  4  .
    3  9  3
    4 16  2
    . 25  1
    . 36  0
    end

    quietly spearman x y if !missing(x, y)
    local rho_xy = r(rho)
    local p_xy = r(p)
    quietly spearman y z if !missing(y, z)
    local rho_yz = r(rho)
    local p_yz = r(p)

    corrtab x y z, spearman full

    assert r(N)[1, 2] == 4
    assert r(N)[2, 3] == 4
    assert abs(r(C)[1, 2] - `rho_xy') < 1e-12
    assert abs(r(P)[1, 2] - `p_xy') < 1e-12
    assert abs(r(C)[2, 3] - `rho_yz') < 1e-12
    assert missing(r(P)[2, 3]) & missing(`p_yz')
}
if _rc == 0 {
    display as result "  PASS: corrtab Spearman preserves pairwise Stata behavior"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab Spearman pairwise equivalence (rc=`=_rc')"
    local ++fail_count
}

**## invalid star thresholds and pvalues+star() reject cleanly
local ++test_count
capture noisily {
    clear
    set obs 10
    gen double x = _n
    gen double y = _n

    capture corrtab x y, star(0.05 0.05)
    assert _rc == 198

    capture corrtab x y, star(0 0.05)
    assert _rc == 198

	    capture corrtab x y, pvalues star(0.10 0.05)
	    assert _rc == 198

	    capture corrtab x y, lower upper
	    assert _rc == 198

	    capture corrtab x y, lower full
	    assert _rc == 198

	    capture corrtab x y, upper full
	    assert _rc == 198
	}
	if _rc == 0 {
	    display as result "  PASS: corrtab rejects invalid star() and shape contracts"
	    local ++pass_count
	}
	else {
	    display as error "  FAIL: corrtab rejects invalid star() and shape contracts (rc=`=_rc')"
	    local ++fail_count
	}

**## open and xlsx() validation fail early without a real workbook target
local ++test_count
capture noisily {
    clear
    set obs 10
    gen double x = _n
    gen double y = _n

    capture corrtab x y, open
    assert _rc == 198

    capture corrtab x y, xlsx("bad_ext.txt")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: corrtab validates open/xlsx() contracts"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab validates open/xlsx() contracts (rc=`=_rc')"
    local ++fail_count
}

**# Console and Export
**## xlsx export preserves rendered correlation strings
local ++test_count
capture noisily {
    clear
    set obs 8
    gen double x = _n
    gen double y = _n
    gen double z = 9 - _n

    capture erase "`output_dir'/_corrtab_perf_full.xlsx"
    corrtab x y z, full pvalues ///
        xlsx("`output_dir'/_corrtab_perf_full.xlsx") sheet("CorrPerf") ///
        title("Correlation Performance")
    confirm file "`output_dir'/_corrtab_perf_full.xlsx"

    import excel using "`output_dir'/_corrtab_perf_full.xlsx", ///
        sheet("CorrPerf") clear allstring
    assert A[1] == "Correlation Performance"
    assert C[2] == "x"
    assert D[2] == "y"
    assert E[2] == "z"
    assert C[3] == "1.00"
    assert strpos(C[4], "1.00") > 0
    assert strpos(C[4], "<0.001") > 0
    assert strpos(E[3], "-1.00") > 0
    assert strpos(E[3], "<0.001") > 0
}
if _rc == 0 {
    display as result "  PASS: corrtab xlsx preserves rendered strings"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab xlsx rendered-string fidelity (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_corrtab_perf_full.xlsx"

**## console output writes a visible table
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

 corrtab x y z, title("Console Correlation Table")

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
**# Migrated: core corrtab suite

**# SECTION 2: corrtab
* ============================================================

* Test: corrtab basic Pearson with display
capture noisily {
    sysuse auto, clear
 corrtab price mpg weight length
}
if _rc == 0 {
    display as result "  PASS: corrtab basic Pearson display"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab basic Pearson display (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab Spearman with xlsx export
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/test_corrtab_spearman.xlsx"
    corrtab price mpg weight length, spearman ///
        xlsx("`output_dir'/test_corrtab_spearman.xlsx") sheet("Spearman")
    confirm file "`output_dir'/test_corrtab_spearman.xlsx"
}
if _rc == 0 {
    display as result "  PASS: corrtab Spearman xlsx export"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab Spearman xlsx export (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab returns r(C) matrix
capture noisily {
    sysuse auto, clear
 corrtab price mpg weight length
    matrix list r(C)
    assert rowsof(r(C)) == 4
    assert colsof(r(C)) == 4
}
if _rc == 0 {
    display as result "  PASS: corrtab r(C) matrix 4x4"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab r(C) matrix (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab upper triangle
capture noisily {
    sysuse auto, clear
 corrtab price mpg weight, upper
}
if _rc == 0 {
    display as result "  PASS: corrtab upper triangle"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab upper triangle (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab full matrix
capture noisily {
    sysuse auto, clear
 corrtab price mpg weight, full
}
if _rc == 0 {
    display as result "  PASS: corrtab full matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab full matrix (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab pvalues option
capture noisily {
    sysuse auto, clear
 corrtab price mpg weight, pvalues
}
if _rc == 0 {
    display as result "  PASS: corrtab pvalues option"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab pvalues option (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab custom star thresholds
capture noisily {
    sysuse auto, clear
 corrtab price mpg weight, star(0.1 0.05 0.01)
}
if _rc == 0 {
    display as result "  PASS: corrtab custom star thresholds"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab custom star thresholds (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab digits option
capture noisily {
    sysuse auto, clear
 corrtab price mpg weight, digits(3)
}
if _rc == 0 {
    display as result "  PASS: corrtab digits(3)"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab digits(3) (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab with if condition
capture noisily {
    sysuse auto, clear
 corrtab price mpg weight if foreign == 0
}
if _rc == 0 {
    display as result "  PASS: corrtab with if condition"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab with if condition (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab csv export
capture noisily {
    sysuse auto, clear
 corrtab price mpg weight, csv("`output_dir'/test_corrtab.csv")
    confirm file "`output_dir'/test_corrtab.csv"
}
if _rc == 0 {
    display as result "  PASS: corrtab csv export"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab csv export (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab frame output
capture noisily {
    sysuse auto, clear
    capture frame drop corrframe
 corrtab price mpg weight, frame(corrframe)
    assert r(frame) == "corrframe"
    frame corrframe: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: corrtab frame output"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab frame output (rc=`=_rc')"
    local ++fail_count
}
capture frame drop corrframe

* Test: corrtab r(methods) returned
capture noisily {
    sysuse auto, clear
 corrtab price mpg weight
    assert "`r(methods)'" != ""
}
if _rc == 0 {
    display as result "  PASS: corrtab r(methods) returned"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab r(methods) (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab theme option
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/test_corrtab_lancet.xlsx"
    corrtab price mpg weight, xlsx("`output_dir'/test_corrtab_lancet.xlsx") theme(lancet)
    confirm file "`output_dir'/test_corrtab_lancet.xlsx"
}
if _rc == 0 {
    display as result "  PASS: corrtab theme(lancet)"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab theme(lancet) (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab data preservation
capture noisily {
    sysuse auto, clear
    local orig_n = _N
 corrtab price mpg weight
    assert _N == `orig_n'
}
if _rc == 0 {
    display as result "  PASS: corrtab data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab data preservation (rc=`=_rc')"
    local ++fail_count
}

* ============================================================

**# Migrated: Spearman pairwise missing

**# corrtab Spearman pairwise missing
* =========================================================================

**## Spearman with pairwise missing: N matrix reflects pairwise counts
capture noisily {
    clear
    set obs 20
    gen double x = _n
    gen double y = _n * 2 + rnormal()
    gen double z = _n * 3 + rnormal()
    replace x = . in 1/5
    replace z = . in 10/15

    corrtab x y z, spearman

    // x has 15 non-missing, y has 20, z has 14
    // N(x,y) = 15, N(y,z) = 14, N(x,z) = min of overlap
    assert r(N)[1,2] == 15 // x-y pair: 15 non-missing x, 20 non-missing y => 15
    assert r(N)[2,3] == 14 // y-z pair: 20 non-missing y, 14 non-missing z => 14

    // x-z pair: both non-missing when _n in {6..9, 16..20} = 9
    assert r(N)[1,3] == 9

    // Correlations should be non-missing
    assert !missing(r(C)[1,2])
    assert !missing(r(C)[2,3])
    assert !missing(r(C)[1,3])
}
if _rc == 0 {
    display as result "  PASS: corrtab Spearman pairwise missing N counts correct"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab Spearman pairwise missing (rc=`=_rc')"
    local ++fail_count
}

**## Spearman pairwise p-values are non-missing
capture noisily {
    clear
    set obs 30
    gen double x = rnormal()
    gen double y = rnormal()
    gen double z = rnormal()
    replace x = . in 1/10
    replace z = . in 15/25

    corrtab x y z, spearman pvalues

    assert !missing(r(P)[1,2])
    assert !missing(r(P)[2,3])
    assert !missing(r(P)[1,3])
}
if _rc == 0 {
    display as result "  PASS: corrtab Spearman pairwise p-values non-missing"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab Spearman pairwise p-values (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: pairwise N p-values

**# 1. corrtab pairwise N — p-values must use pairwise N, not listwise

**## 1a. Pearson: pairwise N matches direct computation
local t1a_pass = 1
capture noisily {
    clear
    set seed 12345
    set obs 100
    gen x = rnormal()
    gen y = rnormal() + 0.3*x
    gen z = rnormal() + 0.2*x
    replace y = . if _n > 80
    replace z = . if _n > 40

    corrtab x y z, pvalues xlsx("`output_dir'/_regfix_corrtab_pw.xlsx") sheet("pw")

    * Check pairwise N matrix
    assert r(N)[1,1] == 100
    assert r(N)[1,2] == 80
    assert r(N)[1,3] == 40
}
if _rc != 0 {
    display as error "  FAIL [1a.run]: corrtab pairwise N returned error `=_rc'"
    local t1a_pass = 0
}
else {
    * Verify p-values match direct pairwise computation
    tempname pmat nmat
    matrix `pmat' = r(P)
    matrix `nmat' = r(N)

    * x-y pair: N should be 80
    if `nmat'[1,2] == 80 {
        display as result "  PASS [1a.N_xy]: pairwise N(x,y) = 80"
    }
    else {
        display as error "  FAIL [1a.N_xy]: expected N(x,y) = 80, got `=`nmat'[1,2]'"
        local t1a_pass = 0
    }

    * x-z pair: N should be 40
    if `nmat'[1,3] == 40 {
        display as result "  PASS [1a.N_xz]: pairwise N(x,z) = 40"
    }
    else {
        display as error "  FAIL [1a.N_xz]: expected N(x,z) = 40, got `=`nmat'[1,3]'"
        local t1a_pass = 0
    }

    * Verify p-value for x-y against direct calculation
    clear
    set seed 12345
    set obs 100
    gen x = rnormal()
    gen y = rnormal() + 0.3*x
    replace y = . if _n > 80

    qui correlate x y
    local direct_r = r(rho)
    local direct_n = r(N)
    local direct_t = `direct_r' * sqrt((`direct_n' - 2) / (1 - `direct_r'^2))
    local direct_p = 2 * ttail(`direct_n' - 2, abs(`direct_t'))

    local corrtab_p = `pmat'[1,2]
    local p_diff = abs(`corrtab_p' - `direct_p')
    if `p_diff' < 0.0001 {
        display as result "  PASS [1a.p_xy]: p(x,y) matches direct (diff=`p_diff')"
    }
    else {
        display as error "  FAIL [1a.p_xy]: p(x,y) mismatch: corrtab=`corrtab_p' direct=`direct_p' diff=`p_diff'"
        local t1a_pass = 0
    }
}
if `t1a_pass' == 1 {
    display as result "  PASS: corrtab Pearson pairwise N"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab Pearson pairwise N"
    local ++fail_count
}

**## 1b. Spearman: pairwise N matches direct computation
local t1b_pass = 1
capture noisily {
    clear
    set seed 54321
    set obs 100
    gen x = rnormal()
    gen y = rnormal() + 0.4*x
    gen z = rnormal() + 0.3*x
    replace y = . if _n > 60
    replace z = . if _n > 30

    corrtab x y z, spearman pvalues xlsx("`output_dir'/_regfix_corrtab_sp.xlsx") sheet("sp")

    * Pairwise N
    assert r(N)[1,2] == 60
    assert r(N)[1,3] == 30
}
if _rc != 0 {
    display as error "  FAIL [1b.run]: corrtab Spearman pairwise N error `=_rc'"
    local t1b_pass = 0
}
else {
    tempname nmat_sp
    matrix `nmat_sp' = r(N)
    if `nmat_sp'[1,2] == 60 & `nmat_sp'[1,3] == 30 {
        display as result "  PASS [1b.N]: Spearman pairwise N correct (60, 30)"
    }
    else {
        display as error "  FAIL [1b.N]: Spearman pairwise N wrong"
        local t1b_pass = 0
    }
}
if `t1b_pass' == 1 {
    display as result "  PASS: corrtab Spearman pairwise N"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab Spearman pairwise N"
    local ++fail_count
}

**## 1c. No missingness: pairwise N equals total N for all pairs
capture noisily {
    clear
    set seed 99999
    set obs 50
    gen x = rnormal()
    gen y = rnormal()
    gen z = rnormal()

    corrtab x y z, pvalues xlsx("`output_dir'/_regfix_corrtab_complete.xlsx") sheet("complete")

    assert r(N)[1,1] == 50
    assert r(N)[1,2] == 50
    assert r(N)[1,3] == 50
    assert r(N)[2,3] == 50
}
if _rc == 0 {
    display as result "  PASS: corrtab complete data — all pairwise N = 50"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab complete data pairwise N (error `=_rc')"
    local ++fail_count
}



**# Migrated: border abbreviation

* T2: corrtab `border`
sysuse auto, clear
capture noisily corrtab price mpg weight length, ///
    border(thin)
if _rc == 0 {
    display as result "  PASS T2: corrtab border abbreviation"
    local ++pass_count
}
else {
    display as error "  FAIL T2: corrtab abbreviations (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}




**# Summary
display as result "corrtab QA summary: `pass_count' passed, `fail_count' failed"
local _tc = `pass_count' + `fail_count'
display "RESULT: test_corrtab tests=`_tc' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1

log close _corrtab
