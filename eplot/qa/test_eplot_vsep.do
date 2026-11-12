*! test_eplot_vsep.do - Regression tests for eplot 1.1.0 vsep()
*! vsep() sets the text between the two limits in the values annotation
*! (default ", ").  Covers the drawn text in data, estimates, matrix, and
*! frame modes read back from export(); quoted, compound-quoted, unquoted
*! (spaces kept), and multibyte separators; stars appended after the
*! interval; the multi-model refusal; and refusal with r(198) of empty text
*! or text holding a double quote, which before the fix returned rc 0 with
*! the drawn text truncated after the lower limit (vsep(`"x"')) or the
*! limits run together (vsep("")), with the caller's data and varabbrev
*! left unchanged.

clear all
set varabbrev off
set graphics off
version 16.0

capture log close _all
log using "test_eplot_vsep.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

capture program drop _vsep_data
program define _vsep_data
    clear
    quietly set obs 2
    gen str10 lab = cond(_n == 1, "A", "B")
    gen double b = cond(_n == 1, 1.13, -0.80)
    gen double lo = cond(_n == 1, 1.05, -1.60)
    gen double hi = cond(_n == 1, 1.21, -0.07)
end

**## 1. data mode: default separator unchanged
local ++test_count
capture noisily {
    _vsep_data
    eplot b lo hi, labels(lab) values export(vs_f, replace) nodraw
    frame vs_f {
        assert values[1] == "1.13 (1.05, 1.21)"
        assert values[2] == "-0.80 (-1.60, -0.07)"
    }
    frame drop vs_f
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**## 2. data mode: unquoted, quoted, compound, spaced, and multibyte text
local ++test_count
capture noisily {
    _vsep_data
    eplot b lo hi, labels(lab) values vsep(-) export(vs_f, replace) nodraw
    frame vs_f: assert values[1] == "1.13 (1.05-1.21)"
    eplot b lo hi, labels(lab) values vsep("-") export(vs_f, replace) nodraw
    frame vs_f: assert values[1] == "1.13 (1.05-1.21)"
    eplot b lo hi, labels(lab) values vsep(`" to "') export(vs_f, replace) nodraw
    frame vs_f {
        assert values[1] == "1.13 (1.05 to 1.21)"
        assert values[2] == "-0.80 (-1.60 to -0.07)"
    }
    eplot b lo hi, labels(lab) values vsep(" to ") export(vs_f, replace) nodraw
    frame vs_f: assert values[1] == "1.13 (1.05 to 1.21)"
    eplot b lo hi, labels(lab) values vsep( - ) export(vs_f, replace) nodraw
    frame vs_f: assert values[1] == "1.13 (1.05 - 1.21)"
    eplot b lo hi, labels(lab) values vsep(–) export(vs_f, replace) nodraw
    frame vs_f: assert values[1] == "1.13 (1.05–1.21)"
    eplot b lo hi, labels(lab) values vsep(;) export(vs_f, replace) nodraw
    frame vs_f: assert values[1] == "1.13 (1.05;1.21)"
    frame drop vs_f
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**## 3. estimates mode, against r(table), with and without stars
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store vs_m1
    tempname T
    matrix `T' = r(table)
    local w = string(`T'[1, 2], "%9.2f")
    local wl = string(`T'[5, 2], "%9.2f")
    local wu = string(`T'[6, 2], "%9.2f")
    eplot vs_m1, keep(weight) values vsep(-) export(vs_f, replace) nodraw
    frame vs_f: assert values[1] == strtrim("`w'") + " (" + strtrim("`wl'") + "-" + strtrim("`wu'") + ")"
    eplot vs_m1, keep(weight) values stars vsep(-) export(vs_f, replace) nodraw
    frame vs_f: assert values[1] == strtrim("`w'") + " (" + strtrim("`wl'") + "-" + strtrim("`wu'") + ")**"
    frame drop vs_f
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**## 4. matrix mode, plain and eform
local ++test_count
capture noisily {
    matrix M = (1.1, 0.9, 1.3 \ 0.7, 0.5, 0.95)
    matrix rownames M = x y
    eplot, matrix(M) values vsep(-) export(vs_f, replace) nodraw
    frame vs_f {
        assert values[1] == "1.10 (0.90-1.30)"
        assert values[2] == "0.70 (0.50-0.95)"
    }
    eplot, matrix(M) values eform vsep(" to ") export(vs_f, replace) nodraw
    frame vs_f: assert values[1] == "3.00 (2.46 to 3.67)"
    frame drop vs_f
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**## 5. frame mode
local ++test_count
capture noisily {
    clear
    input str10 label estimate ll ul
    "A" 1.13 1.05 1.21
    end
    frame copy default vs_src, replace
    eplot, frame(vs_src) values vsep(-) export(vs_f, replace) nodraw
    frame vs_f: assert values[1] == "1.13 (1.05-1.21)"
    frame drop vs_f
    frame drop vs_src
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

**## 6. several models refuse vsep() with r(198)
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store vs_m1
    quietly regress price mpg
    estimates store vs_m2
    capture eplot vs_m1 vs_m2, values vsep(-) nodraw
    assert _rc == 198
    capture eplot vs_m1 vs_m2, vsep(-) nodraw
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

**## 7. empty text or a double quote exits r(198) in every mode, state kept
local ++test_count
capture noisily {
    _vsep_data
    quietly datasignature
    local sig "`r(datasignature)'"
    set varabbrev on
    capture eplot b lo hi, labels(lab) values vsep("") nodraw
    assert _rc == 198
    capture eplot b lo hi, labels(lab) values vsep(`""') nodraw
    assert _rc == 198
    capture eplot b lo hi, labels(lab) values vsep(`"`"x"'"') nodraw
    assert _rc == 198
    capture eplot b lo hi, labels(lab) values vsep(`"a"b"') nodraw
    assert _rc == 198
    capture eplot b lo hi, labels(lab) values vsep("a" "b") nodraw
    assert _rc == 198
    assert c(varabbrev) == "on"
    quietly datasignature
    assert "`r(datasignature)'" == "`sig'"
    capture frame drop vs_f
    capture eplot b lo hi, labels(lab) values vsep(`"`"x"'"') export(vs_f) nodraw
    assert _rc == 198
    matrix M = (1.1, 0.9, 1.3)
    capture eplot, matrix(M) values vsep(`"`"x"'"') nodraw
    assert _rc == 198
    sysuse auto, clear
    quietly regress price mpg
    capture eplot, values vsep("") nodraw
    assert _rc == 198
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 local ++pass_count
else {
    set varabbrev off
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}

**## 8. vsep() without values is accepted and draws no values column
local ++test_count
capture noisily {
    _vsep_data
    eplot b lo hi, labels(lab) vsep(-) export(vs_f, replace) nodraw
    frame vs_f {
        capture confirm variable values
        assert _rc == 111
    }
    frame drop vs_f
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}

capture graph drop _all
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
_eplot_qa_result test_eplot_vsep, tests(`test_count') pass(`pass_count') fail(`fail_count') skip(0)

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    capture log close
    exit 1
}
capture log close
