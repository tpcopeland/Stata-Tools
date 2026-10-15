*! test_eplot_margins.do - Factor labels for margins, post results
*! margins, post names each factor level "#bn.var" (or "#.var"): the "bn"
*! level had kept its raw name ("0bn.foreign") while the other levels took
*! their value labels.  Every level now takes its value label, and the
*! plotted margins equal Stata's own table.

clear all
set varabbrev off
set graphics off
version 16.0

capture log close _all
log using "test_eplot_margins.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

**# 1. every margins level is labelled from its value label
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg i.foreign i.rep78
    quietly margins foreign rep78, post
    local cn : colnames e(b)
    assert strpos("`cn'", "0bn.foreign") & strpos("`cn'", "1bn.rep78")
    capture frame drop mg_f
    eplot ., nodraw export(mg_f)
    frame mg_f {
        assert _N == 7
        assert label[1] == "Domestic"
        assert label[2] == "Foreign"
        * rep78 carries no value label: "Variable label = level" for all.
        assert label[3] == "Repair record 1978 = 1"
        assert label[4] == "Repair record 1978 = 2"
        forvalues i = 1/7 {
            assert strpos(label[`i'], "bn.") == 0
        }
    }
    frame drop mg_f
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# 2. the plotted margins and limits equal Stata's own table
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly logit foreign mpg i.rep78
    quietly margins rep78, post
    quietly ereturn display, level(90)
    matrix O = r(table)'
    eplot ., level(90) nodraw
    matrix E = r(table)
    local k = rowsof(E)
    assert `k' == rowsof(O)
    forvalues i = 1/`k' {
        assert !missing(E[`i', 1]) & !missing(O[`i', 1])
        assert reldif(E[`i', 1], O[`i', 1]) < 1e-12
        assert !missing(E[`i', 2]) & !missing(O[`i', 5])
        assert reldif(E[`i', 2], O[`i', 5]) < 1e-12
        assert !missing(E[`i', 3]) & !missing(O[`i', 6])
        assert reldif(E[`i', 3], O[`i', 6]) < 1e-12
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# 3. ordinary base-level and level names are unchanged
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg ib1.foreign
    capture frame drop mg_g
    eplot ., baselevels drop(_cons) nodraw export(mg_g)
    frame mg_g {
        assert _N == 3
        assert label[2] == "Domestic"
        assert label[3] == "Foreign"
        assert missing(estimate[3])
    }
    frame drop mg_g
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

capture graph drop _all
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
_eplot_qa_result test_eplot_margins, tests(`test_count') pass(`pass_count') fail(`fail_count') skip(0)

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    capture log close
    exit 1
}
capture log close
