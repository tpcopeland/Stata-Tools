* test_crosstab.do - Dedicated QA for crosstab

clear all
set more off
set varabbrev off
version 17.0

capture log close _crosstab
log using "test_crosstab.log", replace text name(_crosstab)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Known Answers
**## OR/RR/RD agree with hand calculations
local ++test_count
capture noisily {
    clear
    input byte outcome byte exposure int freq
    0 0 40
    0 1 20
    1 0 10
    1 1 30
    end
    expand freq

    crosstab outcome exposure, or rr rd

    assert abs(r(or) - 6) < 1e-10
    assert abs(r(rr) - 3) < 1e-10
    assert abs(r(rd) - 0.4) < 1e-10
    assert r(N) == 100
}
if _rc == 0 {
    display as result "  PASS: crosstab OR/RR/RD known answers"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab OR/RR/RD known answers (rc=`=_rc')"
    local ++fail_count
}

**## Regression: 1/2-coded labeled 2x2 tables still post OR/RR/RD rows
local ++test_count
capture noisily {
    clear
    input byte outcome byte exposure int freq
    1 1 40
    1 2 20
    2 1 10
    2 2 30
    end
    label define crosstab_outcome_lbl 1 "No event" 2 "Event", replace
    label define crosstab_exposure_lbl 1 "Unexposed" 2 "Exposed", replace
    label values outcome crosstab_outcome_lbl
    label values exposure crosstab_exposure_lbl
    expand freq

    capture frame drop cross_assoc_lbl
    crosstab outcome exposure, or rr rd label frame(cross_assoc_lbl, replace)

    assert abs(r(or) - 6) < 1e-10
    assert abs(r(rr) - 3) < 1e-10
    assert abs(r(rd) - 0.4) < 1e-10
    frame cross_assoc_lbl {
        assert _N == 9
        assert strpos(c1[7], "OR = ") == 1
        assert strpos(c1[8], "RR = ") == 1
        assert strpos(c1[9], "RD = ") == 1
    }
}
if _rc == 0 {
    display as result "  PASS: crosstab 1/2-coded labeled association measures"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab 1/2-coded labeled association measures (rc=`=_rc')"
    local ++fail_count
}
capture frame drop cross_assoc_lbl

**# Percent Displays
**## default colpct uses column denominators
local ++test_count
capture noisily {
    clear
    input byte outcome byte exposure int freq
    0 0 40
    0 1 20
    1 0 10
    1 1 30
    end
    expand freq

    capture frame drop cross_col
    crosstab outcome exposure, frame(cross_col, replace)

    frame cross_col {
        assert c3[4] == "30 (60.0%)"
        assert c4[5] == "100"
    }
}
if _rc == 0 {
    display as result "  PASS: crosstab default colpct text"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab default colpct text (rc=`=_rc')"
    local ++fail_count
}
capture frame drop cross_col

**## missing changes level discovery and table totals
local ++test_count
capture noisily {
    clear
    input double outcome double exposure
    0 0
    0 1
    1 0
    1 1
    . 0
    1 .
    end

    capture frame drop cross_nomiss
    crosstab outcome exposure, frame(cross_nomiss, replace)
    assert r(N) == 4
    frame cross_nomiss: assert c4[5] == "4"
    capture frame drop cross_nomiss

    capture frame drop cross_miss
    crosstab outcome exposure, missing frame(cross_miss, replace)
    assert r(N) == 6
    frame cross_miss {
        assert c1[5] == "Missing"
        assert c4[4] == "1 (100.0%)"
        assert c5[6] == "6"
    }
}
if _rc == 0 {
    display as result "  PASS: crosstab missing propagates into counts and levels"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab missing propagates into counts and levels (rc=`=_rc')"
    local ++fail_count
}
capture frame drop cross_nomiss
capture frame drop cross_miss

**## rowpct and totalpct use the right denominators
local ++test_count
capture noisily {
    clear
    input byte outcome byte exposure int freq
    0 0 40
    0 1 20
    1 0 10
    1 1 30
    end
    expand freq

    capture frame drop cross_row
    crosstab outcome exposure, rowpct frame(cross_row, replace)
    frame cross_row: assert c3[4] == "30 (75.0%)"
    capture frame drop cross_row

    capture frame drop cross_total
    crosstab outcome exposure, totalpct frame(cross_total, replace)
    frame cross_total: assert c3[4] == "30 (30.0%)"
}
if _rc == 0 {
    display as result "  PASS: crosstab rowpct/totalpct text"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab rowpct/totalpct text (rc=`=_rc')"
    local ++fail_count
}
capture frame drop cross_row
capture frame drop cross_total

**## col/row/total abbreviations map to colpct/rowpct/totalpct
local ++test_count
capture noisily {
    clear
    input byte outcome byte exposure int freq
    0 0 40
    0 1 20
    1 0 10
    1 1 30
    end
    expand freq

    capture frame drop cross_col_abbrev
    crosstab outcome exposure, col frame(cross_col_abbrev, replace)
    frame cross_col_abbrev: assert c3[4] == "30 (60.0%)"
    capture frame drop cross_col_abbrev

    capture frame drop cross_row_abbrev
    crosstab outcome exposure, row frame(cross_row_abbrev, replace)
    frame cross_row_abbrev: assert c3[4] == "30 (75.0%)"
    capture frame drop cross_row_abbrev

    capture frame drop cross_total_abbrev
    crosstab outcome exposure, total frame(cross_total_abbrev, replace)
    frame cross_total_abbrev: assert c3[4] == "30 (30.0%)"
}
if _rc == 0 {
    display as result "  PASS: crosstab col/row/total abbreviations"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab col/row/total abbreviations (rc=`=_rc')"
    local ++fail_count
}
capture frame drop cross_col_abbrev
capture frame drop cross_row_abbrev
capture frame drop cross_total_abbrev

**# Tests and Weights
**## exact and trend return finite p-values
local ++test_count
capture noisily {
    clear
    input byte outcome byte exposure int freq
    0 0 9
    0 1 1
    1 0 1
    1 1 9
    end
    expand freq
    crosstab outcome exposure, exact
    assert !missing(r(p))
    assert r(p) < 0.01

    clear
    input byte outcome byte dose int freq
    0 0 25
    1 0 5
    0 1 20
    1 1 10
    0 2 10
    1 2 20
    end
    expand freq
    crosstab outcome dose, trend
    assert !missing(r(p_trend))
    assert r(p_trend) < 0.05
}
if _rc == 0 {
    display as result "  PASS: crosstab exact/trend p-values"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab exact/trend p-values (rc=`=_rc')"
    local ++fail_count
}

**## methods text reflects RR/RD and trend paths
local ++test_count
capture noisily {
    clear
    input byte outcome byte exposure int freq
    0 0 40
    0 1 20
    1 0 10
    1 1 30
    end
    expand freq

    crosstab outcome exposure, rr rd
    assert strpos("`r(methods)'", "risk ratio") > 0
    assert strpos("`r(methods)'", "risk difference") > 0

    clear
    input byte outcome byte dose int freq
    0 0 25
    1 0 5
    0 1 20
    1 1 10
    0 2 10
    1 2 20
    end
    expand freq

    crosstab outcome dose, trend
    assert strpos("`r(methods)'", "trend") > 0
}
if _rc == 0 {
    display as result "  PASS: crosstab methods text matches reported analyses"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab methods text matches reported analyses (rc=`=_rc')"
    local ++fail_count
}

	**## fweights preserve weighted totals
	local ++test_count
	capture noisily {
	    clear
    input byte outcome byte exposure int w
    0 0 40
    0 1 20
    1 0 10
    1 1 30
    end

    capture frame drop cross_w
    crosstab outcome exposure [fw=w], frame(cross_w, replace)

    assert r(N) == 100
    frame cross_w {
        assert c3[4] == "30 (60.0%)"
        assert c4[5] == "100"
    }
}
if _rc == 0 {
    display as result "  PASS: crosstab fweights"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab fweights (rc=`=_rc')"
    local ++fail_count
	}
	capture frame drop cross_w

	**## weighted trend matches explicit fweight expansion
	local ++test_count
	capture noisily {
	    clear
	    input byte outcome byte dose int wt
	    0 0 25
	    1 0 5
	    0 1 20
	    1 1 10
	    0 2 10
	    1 2 20
	    end

	    crosstab outcome dose [fw=wt], trend
	    local weighted_p = r(p_trend)

	    preserve
	    expand wt
	    crosstab outcome dose, trend
	    local expanded_p = r(p_trend)
	    restore

	    assert !missing(`weighted_p')
	    assert !missing(`expanded_p')
	    assert abs(`weighted_p' - `expanded_p') < 1e-12
	}
	if _rc == 0 {
	    display as result "  PASS: crosstab weighted trend matches expanded fweights"
	    local ++pass_count
	}
	else {
	    display as error "  FAIL: crosstab weighted trend matches expanded fweights (rc=`=_rc')"
	    local ++fail_count
	}

	**## zero-weight fweight rows are excluded from trend tests
	* Regression: expand keeps n<=0 rows, so a wt==0 row used to enter the
	* trend/cochran computations as a weight-1 observation.
	local ++test_count
	capture noisily {
	    clear
	    input byte outcome byte dose int wt
	    0 0 25
	    1 0 5
	    0 1 20
	    1 1 10
	    0 2 10
	    1 2 20
	    1 0 0
	    end

	    crosstab outcome dose [fw=wt], trend
	    local weighted_p = r(p_trend)

	    crosstab outcome dose [fw=wt], cochran
	    local weighted_ca = r(chi2_trend)

	    preserve
	    drop if wt == 0
	    expand wt
	    crosstab outcome dose, trend
	    local expanded_p = r(p_trend)
	    crosstab outcome dose, cochran
	    local expanded_ca = r(chi2_trend)
	    restore

	    assert !missing(`weighted_p')
	    assert abs(`weighted_p' - `expanded_p') < 1e-12
	    assert !missing(`weighted_ca')
	    assert abs(`weighted_ca' - `expanded_ca') < 1e-10
	}
	if _rc == 0 {
	    display as result "  PASS: crosstab zero-weight rows excluded from trend tests"
	    local ++pass_count
	}
	else {
	    display as error "  FAIL: crosstab zero-weight rows excluded from trend tests (rc=`=_rc')"
	    local ++fail_count
	}

	**## cochran matches the N*r^2 identity and return contract
	* For a binary outcome the Cochran-Armitage chi2 equals N times the
	* squared Pearson correlation between outcome and score.
	local ++test_count
	capture noisily {
	    clear
	    input byte outcome byte dose int freq
	    0 0 25
	    1 0 5
	    0 1 20
	    1 1 10
	    0 2 10
	    1 2 20
	    end
	    expand freq

	    crosstab outcome dose, cochran
	    local ca_chi2 = r(chi2_trend)
	    local ca_z = r(z_trend)
	    local ca_p = r(p_trend)
	    local ca_method "`r(trend_method)'"

	    assert "`ca_method'" == "Cochran-Armitage"
	    assert `ca_z' > 0
	    assert abs(`ca_z'^2 - `ca_chi2') < 1e-10
	    assert abs(`ca_p' - chi2tail(1, `ca_chi2')) < 1e-12

	    qui corr outcome dose
	    assert abs(`ca_chi2' - r(N) * r(rho)^2) < 1e-8
	}
	if _rc == 0 {
	    display as result "  PASS: crosstab cochran known-answer identity"
	    local ++pass_count
	}
	else {
	    display as error "  FAIL: crosstab cochran known-answer identity (rc=`=_rc')"
	    local ++fail_count
	}

	**## cochran option contracts reject cleanly
	local ++test_count
	capture noisily {
	    clear
	    input byte outcome byte dose int freq
	    0 0 25
	    1 0 5
	    0 1 20
	    1 1 10
	    0 2 10
	    1 2 20
	    end
	    expand freq

	    capture crosstab outcome dose, cochran trend
	    assert _rc == 198
	    capture crosstab outcome dose, cochran missing
	    assert _rc == 198
	    * dose has 3 levels, so it cannot be the cochran outcome
	    capture crosstab dose outcome, cochran
	    assert _rc == 198
	}
	if _rc == 0 {
	    display as result "  PASS: crosstab cochran option contracts"
	    local ++pass_count
	}
	else {
	    display as error "  FAIL: crosstab cochran option contracts (rc=`=_rc')"
	    local ++fail_count
	}

	**## quoted title survives to the output frame
	* Regression: titles containing embedded double quotes were silently
	* truncated at the first quote by a bare-quoted replace.
	local ++test_count
	capture noisily {
	    sysuse auto, clear
	    gen byte highmpg = mpg > 22
	    capture frame drop _qt_frame
	    crosstab highmpg foreign, title(`"Effect of "high" mpg"') ///
	        frame(_qt_frame, replace)
	    frame _qt_frame: assert title[1] == `"Effect of "high" mpg"'
	    capture frame drop _qt_frame
	}
	if _rc == 0 {
	    display as result "  PASS: crosstab quoted title survives to frame"
	    local ++pass_count
	}
	else {
	    display as error "  FAIL: crosstab quoted title survives to frame (rc=`=_rc')"
	    local ++fail_count
	}

	**## invalid input contracts reject cleanly
	local ++test_count
capture noisily {
    clear
    input byte outcome byte exposure int freq
    0 0 40
    0 1 20
    1 0 10
    1 1 30
    end
    expand freq

    capture crosstab outcome exposure, rowpct totalpct
    assert _rc == 198

    capture crosstab outcome exposure, open
    assert _rc == 198

    capture crosstab outcome exposure, xlsx("bad_ext.txt")
    assert _rc == 198

    clear
    input byte outcome byte exposure
    0 0
    0 1
    0 2
    1 0
    1 1
    1 2
    end

    capture crosstab outcome exposure, or
    assert _rc == 198
    capture crosstab outcome exposure, rr
    assert _rc == 198
    capture crosstab outcome exposure, rd
    assert _rc == 198

    clear
    input str3 outcome str1 exposure
    "Yes" "A"
    "No"  "A"
    "Yes" "B"
    "No"  "B"
    end

    capture crosstab outcome exposure
    assert _rc == 109

    clear
    input byte outcome byte exposure int freq
    0 0 40
    0 1 20
    1 0 10
    1 1 30
    end

    capture crosstab outcome exposure [iw=freq]
    assert _rc == 101
}
if _rc == 0 {
    display as result "  PASS: crosstab rejects conflicting or unsupported inputs"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab rejects conflicting or unsupported inputs (rc=`=_rc')"
    local ++fail_count
}

**## CSV export matches the displayed variable order
local ++test_count
capture noisily {
    clear
    input byte outcome byte exposure int freq
    0 0 40
    0 1 20
    1 0 10
    1 1 30
    end
    expand freq

    local csvfile "`output_dir'/crosstab_layout.csv"
    capture erase "`csvfile'"
    capture frame drop _ct_layout
    crosstab outcome exposure, csv("`csvfile'") frame(_ct_layout, replace)

    * The CSV is written without Stata variable-name headers (v1.8.6 contract)
    * and carries the same visible columns, in the same order, as the frame and
    * the console/XLSX table. Verify column ORDER by aligning the CSV's display
    * header row against the frame's visible columns (c1..c4).
    *
    * The frame reserves row 1 for the title; the CSV no longer does (1.12.0).
    * With no title() the CSV opens on the header row, so frame row 2 aligns
    * with CSV row 1. This test used to read CSV row 2 and so pinned the
    * reserved all-empty first row as expected output.
    frame _ct_layout {
        local _r2_c1 = c1[2]
        local _r2_c2 = c2[2]
        local _r2_c3 = c3[2]
        local _r2_c4 = c4[2]
    }
    preserve
    import delimited "`csvfile'", clear varnames(nonames)
    assert c(k) == 4
    assert strtrim(v1[1]) != ""
    assert strtrim(v1[1]) == strtrim("`_r2_c1'")
    assert strtrim(v2[1]) == strtrim("`_r2_c2'")
    assert strtrim(v3[1]) == strtrim("`_r2_c3'")
    assert strtrim(v4[1]) == strtrim("`_r2_c4'")
    restore

    * With title(), row 1 carries the title and the header row moves to row 2,
    * still with the same column count as the body.
    local csvtitled "`output_dir'/crosstab_layout_titled.csv"
    capture erase "`csvtitled'"
    crosstab outcome exposure, csv("`csvtitled'") title("Layout title")
    preserve
    import delimited "`csvtitled'", clear varnames(nonames)
    assert c(k) == 4
    assert strtrim(v1[1]) == "Layout title"
    assert strtrim(v1[2]) == strtrim("`_r2_c1'")
    assert strtrim(v4[2]) == strtrim("`_r2_c4'")
    restore
    capture frame drop _ct_layout
}
if _rc == 0 {
    display as result "  PASS: crosstab CSV layout matches console/XLSX order"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab CSV layout matches console/XLSX order (rc=`=_rc')"
    local ++fail_count
}

**# Display and Frame
**## display and frame() work together
local ++test_count
capture noisily {
    clear
    input byte outcome byte exposure int freq
    0 0 40
    0 1 20
    1 0 10
    1 1 30
    end
    expand freq

    capture frame drop cross_disp
 crosstab outcome exposure, frame(cross_disp, replace)
    assert "`r(frame)'" == "cross_disp"
    frame cross_disp: assert _N >= 6
}
if _rc == 0 {
    display as result "  PASS: crosstab display + frame()"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab display + frame() (rc=`=_rc')"
    local ++fail_count
}
capture frame drop cross_disp
**# Migrated: core crosstab suite

**# SECTION 5: crosstab
* ============================================================

* Create cross-tabulation dataset
clear
set obs 500
set seed 123
gen exposure = cond(runiform() < 0.5, 1, 0)
gen outcome = cond(runiform() < (0.3 + 0.2 * exposure), 1, 0)
label define explbl 0 "Unexposed" 1 "Exposed"
label define outlbl 0 "Outcome-" 1 "Outcome+"
label values exposure explbl
label values outcome outlbl
gen strata = cond(runiform() < 0.5, 0, 1)
label define stratlbl 0 "Young" 1 "Old"
label values strata stratlbl
gen ordinal_exp = cond(runiform() < 0.33, 0, cond(runiform() < 0.66, 1, 2))
label define ordlbl 0 "Never" 1 "Former" 2 "Current"
label values ordinal_exp ordlbl
tempfile crossdata
save `crossdata'

* Test: crosstab basic 2x2
capture noisily {
    use `crossdata', clear
 crosstab exposure outcome
}
if _rc == 0 {
    display as result "  PASS: crosstab basic 2x2"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab basic 2x2 (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab returns chi2 and p
capture noisily {
    use `crossdata', clear
 crosstab exposure outcome
    assert !missing(r(chi2))
    assert !missing(r(p))
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: crosstab r(chi2) and r(p)"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab r(chi2)/r(p) (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab OR option
capture noisily {
    use `crossdata', clear
 crosstab exposure outcome, or
    assert !missing(r(or))
}
if _rc == 0 {
    display as result "  PASS: crosstab or option"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab or option (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab RR option
capture noisily {
    use `crossdata', clear
 crosstab exposure outcome, rr
    assert !missing(r(rr))
}
if _rc == 0 {
    display as result "  PASS: crosstab rr option"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab rr option (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab RD option
capture noisily {
    use `crossdata', clear
 crosstab exposure outcome, rd
    assert !missing(r(rd))
}
if _rc == 0 {
    display as result "  PASS: crosstab rd option"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab rd option (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab column percentages (default)
capture noisily {
    use `crossdata', clear
 crosstab exposure outcome, colpct
}
if _rc == 0 {
    display as result "  PASS: crosstab colpct"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab colpct (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab row percentages
capture noisily {
    use `crossdata', clear
 crosstab exposure outcome, rowpct
}
if _rc == 0 {
    display as result "  PASS: crosstab rowpct"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab rowpct (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab total percentages
capture noisily {
    use `crossdata', clear
 crosstab exposure outcome, totalpct
}
if _rc == 0 {
    display as result "  PASS: crosstab totalpct"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab totalpct (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab fisher option
capture noisily {
    use `crossdata', clear
 crosstab exposure outcome, fisher
}
if _rc == 0 {
    display as result "  PASS: crosstab fisher"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab fisher (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab exact option
capture noisily {
    use `crossdata', clear
 crosstab exposure outcome, exact or
}
if _rc == 0 {
    display as result "  PASS: crosstab exact + or"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab exact + or (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab trend option with ordered exposure
capture noisily {
    use `crossdata', clear
 crosstab ordinal_exp outcome, trend
}
if _rc == 0 {
    display as result "  PASS: crosstab trend option"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab trend option (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab label option
capture noisily {
    use `crossdata', clear
 crosstab exposure outcome, label
}
if _rc == 0 {
    display as result "  PASS: crosstab label option"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab label option (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab missing option
capture noisily {
    use `crossdata', clear
    replace exposure = . in 1/10
 crosstab exposure outcome, missing
}
if _rc == 0 {
    display as result "  PASS: crosstab missing option"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab missing option (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab exact forces Fisher's exact test
capture noisily {
    use `crossdata', clear
 crosstab exposure outcome, exact or
    assert r(p) < .
}
if _rc == 0 {
    display as result "  PASS: crosstab exact forces Fisher's"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab exact forces Fisher's (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab xlsx export
capture noisily {
    use `crossdata', clear
    capture erase "`output_dir'/test_crosstab.xlsx"
    crosstab exposure outcome, or xlsx("`output_dir'/test_crosstab.xlsx") sheet("Cross")
    confirm file "`output_dir'/test_crosstab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: crosstab xlsx export"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab xlsx export (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab r(table) matrix
capture noisily {
    use `crossdata', clear
 crosstab exposure outcome
    matrix list r(table)
    assert rowsof(r(table)) > 0
}
if _rc == 0 {
    display as result "  PASS: crosstab r(table) matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab r(table) (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab r(methods)
capture noisily {
    use `crossdata', clear
 crosstab exposure outcome
    assert "`r(methods)'" != ""
}
if _rc == 0 {
    display as result "  PASS: crosstab r(methods)"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab r(methods) (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab csv export
capture noisily {
    use `crossdata', clear
 crosstab exposure outcome, csv("`output_dir'/test_crosstab.csv")
    confirm file "`output_dir'/test_crosstab.csv"
}
if _rc == 0 {
    display as result "  PASS: crosstab csv export"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab csv export (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab frame output
capture noisily {
    use `crossdata', clear
    capture frame drop crossframe
 crosstab exposure outcome, frame(crossframe)
    assert r(frame) == "crossframe"
    frame crossframe: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: crosstab frame output"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab frame output (rc=`=_rc')"
    local ++fail_count
}
capture frame drop crossframe

* Test: crosstab with if condition
capture noisily {
    use `crossdata', clear
 crosstab exposure outcome if strata == 1
}
if _rc == 0 {
    display as result "  PASS: crosstab with if condition"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab with if condition (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab data preservation
capture noisily {
    use `crossdata', clear
    local orig_n = _N
 crosstab exposure outcome
    assert _N == `orig_n'
}
if _rc == 0 {
    display as result "  PASS: crosstab data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab data preservation (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab with fweight
capture noisily {
    use `crossdata', clear
    gen wt = ceil(runiform() * 5)
 crosstab exposure outcome [fw=wt]
}
if _rc == 0 {
    display as result "  PASS: crosstab with fweight"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab with fweight (rc=`=_rc')"
    local ++fail_count
}

* ============================================================

**# Migrated: zero-denominator crash regression

**# 9. crosstab zero-denominator does not crash (I7 regression)

**## 9a. crosstab with colpct on valid data completes without error
capture noisily {
    sysuse auto, clear
 crosstab foreign rep78, colpct
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS [9a]: crosstab colpct on valid data completes"
    local ++pass_count
}
else {
    display as error "  FAIL [9a]: crosstab colpct crashed (rc=`=_rc')"
    local ++fail_count
}



**# Migrated: auto-Fisher

**# crosstab auto-Fisher
* =========================================================================

**## Auto-Fisher when expected cells < 5
capture noisily {
    clear
    input byte outcome byte exposure int freq
    0 0 50
    0 1 2
    1 0 3
    1 1 1
    end
    expand freq

    capture frame drop _cross_fisher
    crosstab outcome exposure, or label frame(_cross_fisher, replace)

    assert r(N) == 56
    // expected count for cell (1,1) = 4*3/56 = 0.21 < 5 => Fisher auto-selected
    frame _cross_fisher {
        local found_fisher = 0
        forvalues i = 1/`=_N' {
            if strpos(c1[`i'], "Fisher") > 0 local found_fisher = 1
        }
        assert `found_fisher' == 1
    }
    capture frame drop _cross_fisher
}
if _rc == 0 {
    display as result "  PASS: crosstab auto-selects Fisher for sparse expected cells"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab auto-Fisher selection (rc=`=_rc')"
    local ++fail_count
}

**## Large expected cells use chi-squared, not Fisher
capture noisily {
    clear
    input byte outcome byte exposure int freq
    0 0 40
    0 1 20
    1 0 10
    1 1 30
    end
    expand freq

    capture frame drop _cross_chi2
    crosstab outcome exposure, or frame(_cross_chi2, replace)

    frame _cross_chi2 {
        local found_chi2 = 0
        forvalues i = 1/`=_N' {
            if strpos(c1[`i'], "Chi") > 0 | strpos(c1[`i'], "chi") > 0 {
                local found_chi2 = 1
            }
        }
        assert `found_chi2' == 1
    }
    capture frame drop _cross_chi2
}
if _rc == 0 {
    display as result "  PASS: crosstab uses chi-squared for large expected cells"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab chi-squared selection (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: trend inside preserve

**# Regression: I2 — crosstab trend inside preserve is safe

**## R3. crosstab trend does not corrupt user data
capture noisily {
    sysuse auto, clear
    local _orig_N = _N
    local _orig_k = c(k)
    gen byte outcome = price > 6000
    gen byte exposure = rep78 > 3 if rep78 < .
 crosstab outcome exposure, trend label
    assert _N == `_orig_N'  // data unchanged
    * Variables should be intact
    confirm variable make price mpg
}
if _rc == 0 {
    display as result "  PASS [R3]: crosstab trend preserves user data"
    local ++pass_count
}
else {
    display as error "  FAIL [R3]: crosstab trend data preservation (rc=`=_rc')"
    local ++fail_count
}



**# Migrated: zebra formatting

**# 4. Zebra formatting in crosstab

**## 4a. crosstab zebra produces fills in xlsx
local t4a_pass = 1
capture noisily {
    sysuse auto, clear
    crosstab foreign rep78, xlsx("`output_dir'/_regfix_crosstab_zebra.xlsx") sheet("cross") zebra
}
if _rc != 0 {
    display as error "  FAIL [4a.run]: crosstab zebra error `=_rc'"
    local t4a_pass = 0
}
else {
    capture noisily {
        ! cd "`output_dir'" && unzip -o _regfix_crosstab_zebra.xlsx xl/styles.xml -d _regfix_cross_inspect > /dev/null 2>&1
        ! grep -c 'EDF2F9\|edf2f9' "`output_dir'/_regfix_cross_inspect/xl/styles.xml" > "`output_dir'/_regfix_cross_fill_count.txt" 2>&1

        file open _fh using "`output_dir'/_regfix_cross_fill_count.txt", read text
        file read _fh _line
        file close _fh

        local fill_count = real(strtrim("`_line'"))
        assert `fill_count' > 0
    }
    if _rc == 0 {
        display as result "  PASS [4a.fill]: crosstab zebra fill present in xlsx"
    }
    else {
        display as error "  FAIL [4a.fill]: crosstab zebra fill NOT found in xlsx"
        local t4a_pass = 0
    }
}
if `t4a_pass' == 1 {
    display as result "  PASS: crosstab zebra produces fills"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab zebra produces fills"
    local ++fail_count
}



**# Migrated: boldp() bounds validation

* Test 5: crosstab validates boldp() bounds
capture noisily {
    clear
    input exposure outcome
    0 0
    0 1
    1 0
    1 1
    end
    capture crosstab exposure outcome, boldp(1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: crosstab rejects invalid boldp()"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab rejects invalid boldp() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}


**# Migrated: border/tr abbreviations

* T1: crosstab `border`, `tr`
sysuse auto, clear
capture noisily crosstab foreign rep78, ///
    border(thin) tr
if _rc == 0 {
    display as result "  PASS T1: crosstab border/tr abbreviations"
    local ++pass_count
}
else {
    display as error "  FAIL T1: crosstab abbreviations (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

**# Small-cell disclosure control

**## smallcells() redacts counts, derived results, and frame metadata
capture noisily {
    clear
    input byte outcome byte exposure int freq
    0 0 2
    0 1 8
    1 0 6
    1 1 4
    end
    expand freq

    capture frame drop cross_sc
    crosstab outcome exposure, or rr rd trend smallcells(5) ///
        frame(cross_sc, replace)

    assert r(smallcells) == 5
    assert r(N_primary_suppressed) >= 2
    assert r(N_secondary_suppressed) >= 1
    assert r(N_derived_suppressed) >= 5
    assert r(p) == .d
    assert r(or) == .d
    assert r(rr) == .d
    assert r(rd) == .d
    assert r(p_trend) == .d
    matrix _cross_sc_t = r(table)
    matrix _cross_sc_s = r(suppression)
    assert _cross_sc_t[1,1] == .p
    assert _cross_sc_t[2,2] == .p
    mata: assert(any(st_matrix("_cross_sc_t") :== .s))
    mata: assert(all(st_matrix("_cross_sc_s") :== ///
        (st_matrix("_cross_sc_t") :== .p) + ///
        2 * (st_matrix("_cross_sc_t") :== .s)))

    frame cross_sc: assert c2[3] == "<5"
    frame cross_sc: assert c3[4] == "<5"
    frame cross_sc: assert strpos(c1[6], "Suppressed") > 0
    frame cross_sc: assert c1[7] == "OR = Suppressed"
    frame cross_sc: assert c1[8] == "RR = Suppressed"
    frame cross_sc: assert c1[9] == "RD = Suppressed"
    frame cross_sc: assert strpos(c1[10], "Suppressed") > 0
    frame cross_sc: local _sc_k : char _dta[tabtools_smallcells]
    frame cross_sc: local _sc_codes : char _dta[tabtools_suppression_codes]
    frame cross_sc: local _sc_scope : char _dta[tabtools_suppression_scope]
    assert "`_sc_k'" == "5"
    assert strpos("`_sc_codes'", "1 primary") > 0
    assert strpos("`_sc_scope'", "all sinks") > 0
}
if _rc == 0 {
    display as result "  PASS: crosstab smallcells strict return/frame contract"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab smallcells strict return/frame contract (rc=`=_rc')"
    local ++fail_count
}
capture frame drop cross_sc

**## redundant complementary margins are pruned
capture noisily {
    clear
    input byte outcome byte exposure int freq
    0 1 1
    1 0 1
    1 1 4
    end
    expand freq

    capture frame drop cross_sc_irredundant
    crosstab outcome exposure, smallcells(5) ///
        frame(cross_sc_irredundant, replace)
    assert r(N_primary_suppressed) == 5
    assert r(N_secondary_suppressed) == 1
    frame cross_sc_irredundant {
        local sc_ns = 0
        ds
        foreach sc_v of varlist `r(varlist)' {
            capture confirm string variable `sc_v'
            if !_rc {
                quietly count if strpos(`sc_v', "≥5") > 0
                local sc_ns = `sc_ns' + r(N)
            }
        }
    }
    assert `sc_ns' == 1
}
if _rc == 0 {
    display as result "  PASS: crosstab prunes redundant complementary margins"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab complementary-margin pruning (rc=`=_rc')"
    local ++fail_count
}
capture frame drop cross_sc_irredundant

**## one redacted payload is reused by CSV, Markdown, frame, and XLSX sinks
capture noisily {
    clear
    input byte outcome byte exposure int freq
    0 0 2
    0 1 8
    1 0 6
    1 1 4
    end
    expand freq

    local sc_csv "`output_dir'/crosstab_smallcells.csv"
    local sc_md "`output_dir'/crosstab_smallcells.md"
    local sc_xlsx "`output_dir'/crosstab_smallcells.xlsx"
    capture erase "`sc_csv'"
    capture erase "`sc_md'"
    capture erase "`sc_xlsx'"
    capture frame drop cross_sc_sinks
    crosstab outcome exposure, smallcells(5) ///
        csv("`sc_csv'") markdown("`sc_md'") ///
        frame(cross_sc_sinks, replace) ///
        xlsx("`sc_xlsx'") sheet("CrossSC")

    matrix _cross_sc_sink_t = r(table)
    assert _cross_sc_sink_t[1,1] == .p
    frame cross_sc_sinks: assert c2[3] == "<5"
    frame cross_sc_sinks: assert c3[4] == "<5"

    preserve
    import delimited "`sc_csv'", clear varnames(nonames) stringcols(_all)
    assert strtrim(v2[2]) == "<5"
    assert strtrim(v3[3]) == "<5"
    restore

    tempname sc_fh
    local sc_md_text ""
    file open `sc_fh' using "`sc_md'", read text
    file read `sc_fh' sc_line
    while r(eof) == 0 {
        local sc_md_text `"`sc_md_text' `macval(sc_line)'"'
        file read `sc_fh' sc_line
    }
    file close `sc_fh'
    assert strpos(`"`sc_md_text'"', "<5") > 0
    assert strpos(`"`sc_md_text'"', "≥5") > 0

    preserve
    import excel using "`sc_xlsx'", sheet("CrossSC") clear allstring
    local sc_np = 0
    local sc_ns = 0
    foreach sc_v of varlist _all {
        quietly count if strtrim(`sc_v') == "<5"
        local sc_np = `sc_np' + r(N)
        quietly count if strtrim(`sc_v') == "≥5"
        local sc_ns = `sc_ns' + r(N)
    }
    assert `sc_np' >= 2
    assert `sc_ns' >= 1
    restore
}
if _rc == 0 {
    display as result "  PASS: crosstab smallcells is identical across all sinks"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab smallcells all-sink contract (rc=`=_rc')"
    local ++fail_count
}
capture frame drop cross_sc_sinks

**## safe returns survive a later workbook export failure
capture noisily {
    clear
    input byte outcome byte exposure int freq
    0 0 2
    0 1 8
    1 0 6
    1 1 4
    end
    expand freq

    return clear
    capture noisily crosstab outcome exposure, smallcells(5) ///
        xlsx("`output_dir'/missing/crosstab_smallcells.xlsx")
    assert _rc != 0
    assert r(smallcells) == 5
    assert r(p) == .d
    matrix _cross_sc_failed_t = r(table)
    matrix _cross_sc_failed_s = r(suppression)
    assert _cross_sc_failed_t[1,1] == .p
    mata: assert(any(st_matrix("_cross_sc_failed_t") :== .s))
    mata: assert(any(st_matrix("_cross_sc_failed_s") :== 1))
    assert `"`r(xlsx)'"' == ""
}
if _rc == 0 {
    display as result "  PASS: crosstab failed export preserves only safe returns"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab safe failed-export contract (rc=`=_rc')"
    local ++fail_count
}

**## percentages, fweights, and threshold boundaries stay non-disclosing
capture noisily {
    clear
    input byte outcome byte exposure int freq
    0 0 2
    0 1 8
    1 0 8
    1 1 8
    end

    capture frame drop cross_sc_pct
    crosstab outcome exposure [fw=freq], colpct smallcells(5) ///
        frame(cross_sc_pct, replace)
    assert r(smallcells) == 5
    frame cross_sc_pct: assert c2[3] == "<5"
    frame cross_sc_pct: assert strpos(c2[3], "%") == 0
    frame cross_sc_pct: assert strpos(c2[4], "%") == 0 ///
        if strpos(c2[4], "≥5") > 0

    capture frame drop cross_sc_all
    crosstab outcome exposure [fw=freq], totalpct smallcells(30) ///
        frame(cross_sc_all, replace)
    assert r(smallcells) == 30
    assert r(N_primary_suppressed) > 0
    frame cross_sc_all {
        assert strpos(c2[3], "%") == 0
        assert strpos(c3[3], "%") == 0
        assert strpos(c2[4], "%") == 0
        assert strpos(c3[4], "%") == 0
    }
}
if _rc == 0 {
    display as result "  PASS: crosstab smallcells percent/fweight/boundary contract"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab smallcells percent/fweight/boundary contract (rc=`=_rc')"
    local ++fail_count
}
capture frame drop cross_sc_pct
capture frame drop cross_sc_all

**## invalid thresholds fail before output and restore caller state
capture noisily {
    clear
    input byte outcome byte exposure
    0 0
    1 1
    end
    set varabbrev on
    foreach bad in 0 1 2 {
        capture noisily crosstab outcome exposure, smallcells(`bad')
        assert _rc == 198
        assert "`c(varabbrev)'" == "on"
    }
    capture noisily crosstab outcome exposure, smallcells(3.5)
    assert _rc == 198
    capture noisily crosstab outcome exposure, smallcells(nonnumeric)
    assert _rc == 198
    assert _N == 2
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: crosstab smallcells validation is failure-atomic"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab smallcells validation contract (rc=`=_rc')"
    local ++fail_count
}
set varabbrev off




display as result "crosstab QA summary: `pass_count' passed, `fail_count' failed"
local _tc = `pass_count' + `fail_count'
display "RESULT: test_crosstab tests=`_tc' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1

log close _crosstab
