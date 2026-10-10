*! test_eplot_v151.do - Regression tests for eplot 1.5.1
*! Covers eform on ordinal, count, survival and multilevel models (cutpoints,
*! ln_p, var() and alpha rows excluded), mlogit rrr, ereturn-post results
*! surviving an eplot call, rename() collisions within and across models,
*! coeflabels() cascade, vformat() validation in every mode, the spurious
*! constant-suppressed note, logscale and xlabel() on nonpositive values,
*! frame() sources read with in, and xline() outside the data range.  Oracles
*! are Stata's own r(table), r(pvalues) and _b[] values, or hand-known numbers.

clear all
set varabbrev off
set graphics off
version 16.0

capture log close _all
log using "test_eplot_v151.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

**# Ordinal, count, survival and multilevel eform

**## ologit eform keeps the two covariates, drops cutpoints, matches Stata
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly ologit rep78 mpg weight, or
    matrix S = r(table)
    local rl = rownumb(S, "ll")
    local ru = rownumb(S, "ul")
    quietly ologit rep78 mpg weight
    local b_mpg = exp(_b[mpg])
    local b_wt = exp(_b[weight])
    eplot ., eform name(v151_t1, replace)
    matrix T = r(table)
    assert rowsof(T) == 2
    local nms : rownames T
    assert !strpos("`nms'", "cut")
    assert !missing(T[1,1]) & !missing(T[2,1])
    assert !missing(T[1,1]) & !missing(`b_mpg')
    assert reldif(T[1,1], `b_mpg') < 1e-12
    assert !missing(T[2,1]) & !missing(`b_wt')
    assert reldif(T[2,1], `b_wt') < 1e-12
    forvalues j = 1/2 {
        assert !missing(T[`j',2]) & !missing(T[`j',3])
        assert !missing(S[`rl',`j']) & !missing(S[`ru',`j'])
        assert reldif(T[`j',2], S[`rl',`j']) < 1e-10
        assert reldif(T[`j',3], S[`ru',`j']) < 1e-10
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**## ologit without eform drops cutpoints and reports Stata's p-values
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly ologit rep78 mpg weight
    matrix S = r(table)
    local rp = rownumb(S, "pvalue")
    eplot ., name(v151_t2, replace)
    matrix T = r(table)
    assert rowsof(T) == 2
    local nms : rownames T
    assert !strpos("`nms'", "cut")
    matrix P = r(pvalues)
    assert rowsof(P) == 2
    forvalues j = 1/2 {
        assert !missing(P[`j',1]) & !missing(S[`rp',`j'])
        assert reldif(P[`j',1], S[`rp',`j']) < 1e-10
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**## nbreg eform keeps only the mean-equation covariate
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly nbreg price mpg
    local b_mpg = exp(_b[mpg])
    eplot ., eform name(v151_t3, replace)
    matrix T = r(table)
    assert rowsof(T) == 1
    local nms : rownames T
    assert !strpos("`nms'", "_cons")
    assert !strpos("`nms'", "alpha")
    assert !missing(T[1,1])
    assert !missing(T[1,1]) & !missing(`b_mpg')
    assert reldif(T[1,1], `b_mpg') < 1e-12
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**## streg weibull eform drops ln_p and returns the time ratio of age
local ++test_count
capture noisily {
    webuse cancer, clear
    stset studytime, failure(died)
    quietly streg age, dist(weibull)
    local b_age = exp(_b[_t:age])
    eplot ., eform name(v151_t4, replace)
    matrix T = r(table)
    assert rowsof(T) == 1
    local nms : rownames T
    assert !strpos("`nms'", "ln_p")
    assert !missing(T[1,1])
    assert !missing(T[1,1]) & !missing(`b_age')
    assert reldif(T[1,1], `b_age') < 1e-12
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**## melogit eform drops the variance components
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly melogit foreign mpg || rep78:
    local b_mpg = exp(_b[mpg])
    eplot ., eform name(v151_t5, replace)
    matrix T = r(table)
    assert rowsof(T) == 1
    local nms : rownames T
    assert !strpos("`nms'", "var(")
    assert !missing(T[1,1])
    assert !missing(T[1,1]) & !missing(`b_mpg')
    assert reldif(T[1,1], `b_mpg') < 1e-12
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

**## mlogit rrr with eform plots the mpg row of both non-base equations
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly mlogit rep78 mpg if rep78 >= 3 & !missing(rep78)
    local e4 = exp(_b[4:mpg])
    local e5 = exp(_b[5:mpg])
    eplot ., eform name(v151_t6, replace)
    matrix T = r(table)
    assert rowsof(T) == 2
    assert !missing(T[1,1]) & !missing(T[2,1])
    local ok 0
    if reldif(T[1,1], `e4') < 1e-12 & reldif(T[2,1], `e5') < 1e-12 local ok 1
    if reldif(T[1,1], `e5') < 1e-12 & reldif(T[2,1], `e4') < 1e-12 local ok 1
    assert `ok' == 1
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

**# ereturn-post results and estimates

**## Results posted before eplot survive the call
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store m1
    matrix b = (1, 2)
    matrix V = I(2)
    matrix colnames b = x1 x2
    matrix colnames V = x1 x2
    matrix rownames V = x1 x2
    ereturn post b V
    matrix saved = e(b)
    eplot m1, name(v151_t7, replace)
    confirm matrix e(b)
    assert colsof(e(b)) == 2
    assert mreldif(e(b), saved) == 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}

**## eplot . accepts ereturn-post results that carry no e(cmd)
local ++test_count
capture noisily {
    sysuse auto, clear
    matrix b = (1, 2)
    matrix V = I(2)
    matrix colnames b = x1 x2
    matrix colnames V = x1 x2
    matrix rownames V = x1 x2
    ereturn post b V
    eplot ., name(v151_t8, replace)
    matrix T = r(table)
    assert rowsof(T) == 2
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}

**# rename() and coeflabels()

**## rename() that maps two coefficients onto one name within a model errors
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store m1
    capture noisily eplot m1, rename(mpg = weight)
    assert _rc == 198
    capture noisily eplot m1, rename(mpg = weight weight = mpg)
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}

**## rename() across models merges the shared coefficient into one row
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store a
    quietly regress price weight
    estimates store b
    eplot a b, rename(weight = mpg) drop(_cons) name(v151_t10, replace)
    assert r(k) == 1
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 10"
}

**## coeflabels() renames the row whose b matches the original coefficient
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    local b_mpg = _b[mpg]
    local b_wt = _b[weight]
    estimates store m1
    eplot m1, coeflabels(mpg = "weight") drop(_cons) name(v151_t11a, replace)
    matrix T = r(table)
    local nms : rownames T
    local row 0
    forvalues i = 1/`=rowsof(T)' {
        if reldif(T[`i',1], `b_mpg') < 1e-12 local row `i'
    }
    assert `row' > 0
    local nm : word `row' of `nms'
    assert "`nm'" == "weight"
    local nm1 : word 1 of `nms'
    assert "`nm1'" == "weight"

    eplot m1, coeflabels(mpg = "weight" weight = "mpg") drop(_cons) ///
        name(v151_t11b, replace)
    matrix T = r(table)
    local nms : rownames T
    local row_mpg 0
    local row_wt 0
    forvalues i = 1/`=rowsof(T)' {
        if reldif(T[`i',1], `b_mpg') < 1e-12 local row_mpg `i'
        if reldif(T[`i',1], `b_wt') < 1e-12 local row_wt `i'
    }
    assert `row_mpg' > 0 & `row_wt' > 0
    local nm_mpg : word `row_mpg' of `nms'
    local nm_wt : word `row_wt' of `nms'
    assert "`nm_mpg'" == "weight"
    assert "`nm_wt'" == "mpg"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 11"
}

**# Input validation

**## vformat() that is not a numeric display format is refused in every mode
local ++test_count
capture noisily {
    clear
    input es lci uci
0.5 0.3 0.8
1.2 1.0 1.5
end
    capture noisily eplot es lci uci, values vformat(abc)
    assert _rc == 198
    capture noisily eplot es lci uci, values vformat(%s)
    assert _rc == 198
    sysuse auto, clear
    quietly regress price mpg
    estimates store m1
    capture noisily eplot m1, values vformat(abc)
    assert _rc == 198
    matrix R = (0.5, 0.3, 0.8 \ 1.2, 1.0, 1.5)
    matrix rownames R = a b
    capture noisily eplot, matrix(R) values vformat(abc)
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 12"
}

**## eform on a matrix without a constant does not print the constant note
* The note belongs to models that carry _cons; a matrix input has no constant
* row, so the log must not mention one.
local ++test_count
capture noisily {
    matrix M = (0.5, 0.2, 0.9 \ 1.3, 0.8, 1.9)
    matrix rownames M = a b
    tempfile eflog
    quietly log using "`eflog'", text replace name(v151_eform)
    capture noisily eplot, matrix(M) eform name(v151_t13, replace)
    local rc_eform = _rc
    quietly log close v151_eform
    assert `rc_eform' == 0
    tempname lfh
    local hits 0
    file open `lfh' using "`eflog'", read text
    file read `lfh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "constant suppressed") local ++hits
        file read `lfh' line
    }
    file close `lfh'
    assert `hits' == 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 13"
}

**# Logscale and xlabel on nonpositive values

**## logscale refuses a row whose estimate is zero
local ++test_count
capture noisily {
    clear
    input es lci uci
0 0.5 2
1 0.8 1.3
end
    capture noisily eplot es lci uci, logscale name(v151_t14, replace)
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 14"
}

**# Frame sources and reference lines

**## frame() with in reads the selected rows of the named frame
local ++test_count
capture noisily {
    frame change default
    capture frame drop fr
    frame create fr
    frame change fr
    input str10 lab double(estimate ll ul)
"a" 1.1 0.9 1.3
"b" 1.4 1.1 1.8
"c" 0.8 0.6 1.0
"d" 1.9 1.5 2.4
end
    frame change default
    * Default frame empty
    clear
    eplot in 2/3, frame(fr) name(v151_t15, replace)
    matrix T = r(table)
    assert rowsof(T) == 2
    assert !missing(T[1,1]) & !missing(T[2,1])
    assert reldif(T[1,1], 1.4) < 1e-12
    assert reldif(T[2,1], 0.8) < 1e-12
    assert !missing(T[1,2]) & !missing(1.1)
    assert reldif(T[1,2], 1.1) < 1e-12
    assert !missing(T[1,3]) & !missing(1.8)
    assert reldif(T[1,3], 1.8) < 1e-12
    * Default frame holding one observation
    clear
    set obs 1
    eplot in 2/3, frame(fr) name(v151_t15b, replace)
    matrix T = r(table)
    assert rowsof(T) == 2
    assert !missing(T[1,1]) & !missing(T[2,1])
    assert reldif(T[1,1], 1.4) < 1e-12
    assert reldif(T[2,1], 0.8) < 1e-12
    frame change default
    capture frame drop fr
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 15"
}

**## xline() outside the data range widens the drawn x axis to include it
local ++test_count
capture noisily {
    clear
    input es lci uci
0.8 0.5 1.2
1.1 0.9 1.6
1.9 1.4 2.0
end
    eplot es lci uci, xline(5) nonull name(v151_t16, replace)
    local cmd `"`r(cmd)'"'
    local hi .
    if regexm(`"`cmd'"', "xscale\([^)]*range\(([-0-9.e+]+) ([-0-9.e+]+)\)") ///
        local hi = real(regexs(2))
    assert !missing(`hi')
    assert `hi' >= 5
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 16"
}

**## xlabel() with a nonpositive tick on a log axis is refused
local ++test_count
capture noisily {
    clear
    input es lci uci
0.8 0.5 1.2
1.1 0.9 1.6
1.9 1.4 2.0
end
    capture noisily eplot es lci uci, logscale xlabel(0 1 2) name(v151_t17, replace)
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 17"
}

**## A null line outside the data range is reported, and nonull silences it
* The axis keeps the data range when every interval excludes the null, so the
* line cannot be drawn; the log must say so exactly once per call.
local ++test_count
capture noisily {
    clear
    input es lci uci
1.5 1.2 1.9
2.1 1.6 2.8
end
    tempfile nulllog
    quietly log using "`nulllog'", text replace name(v151_null)
    capture noisily eplot es lci uci, name(v151_t18, replace)
    local rc_a = _rc
    capture noisily eplot es lci uci, nonull name(v151_t18, replace)
    local rc_b = _rc
    capture noisily eplot es lci uci, xline(0) name(v151_t18, replace)
    local rc_c = _rc
    quietly log close v151_null
    assert `rc_a' == 0 & `rc_b' == 0 & `rc_c' == 0
    tempname nfh
    local hits 0
    file open `nfh' using "`nulllog'", read text
    file read `nfh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "null line at 0 lies outside") local ++hits
        file read `nfh' line
    }
    file close `nfh'
    * Only the first call: nonull suppresses the line, xline(0) brings the
    * null into the range.
    assert `hits' == 1
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 18"
}

**## eform on a transposed nbreg r(table) omits /lnalpha and _diparm alpha
* The matrix carries eform-eligible mpg plus the ancillary rows Stata itself
* displays untransformed; only mpg may be exponentiated.
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly nbreg price mpg
    local b_mpg = exp(_b[mpg])
    quietly nbreg
    matrix RT = r(table)'
    matrix RT = RT[1..., "b"], RT[1..., "ll"], RT[1..., "ul"]
    local rn : roweq RT
    assert strpos("`rn'", "_diparm") > 0
    eplot, matrix(RT) eform name(v151_t19, replace)
    matrix T = r(table)
    local tn : rownames T
    assert rowsof(T) == 1
    assert "`tn'" == "mpg"
    assert !missing(T[1,1]) & !missing(`b_mpg')
    assert reldif(T[1,1], `b_mpg') < 1e-12
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 19"
}

capture frame drop fr
capture graph drop _all
capture estimates drop _all
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
_eplot_qa_result test_eplot_v151, tests(`test_count') pass(`pass_count') fail(`fail_count') skip(0)

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    capture log close
    exit 1
}
capture log close
