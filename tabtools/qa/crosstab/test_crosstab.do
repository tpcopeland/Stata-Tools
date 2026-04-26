* test_crosstab.do - Dedicated QA for crosstab

clear all
set more off
set varabbrev off

capture log close _crosstab
log using "test_crosstab.log", replace text name(_crosstab)

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
    assert _rc != 0
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
    crosstab outcome exposure, csv("`csvfile'")

    tempname fh
    local header ""
    file open `fh' using "`csvfile'", read text
    file read `fh' header
    file close `fh'

    assert "`header'" == "title,c1,c2,c3,c4"
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
    crosstab outcome exposure, display frame(cross_disp, replace)
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

display as result "crosstab QA summary: `pass_count' passed, `fail_count' failed"
if `fail_count' > 0 exit 1

log close _crosstab
