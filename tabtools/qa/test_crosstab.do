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
    crosstab outcome exposure, display frame(cross_disp, replace) subtitle("ITT Population")
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
