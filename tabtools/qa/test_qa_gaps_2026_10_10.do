* test_qa_gaps_2026_10_10.do - QA gaps found by the 2026-10-10 final check
*
* Coverage that let a mutated package pass, plus degenerate-input (null-case)
* probes for commands that read external state.
*
* G1  crosstab picks Fisher's exact test below an expected count of 5 and
*     Pearson's chi-squared at 5: tables built with a minimum expected count
*     of exactly 4.9 and 5.0 (tab, exact / tab, chi2 oracles)
* G2  the p-value display rule, from a literal table: <0.001, three decimals
*     below 0.10, two from 0.10, >0.99 (both _tabtools_fmt_p and the scalar
*     _tabtools_format_p, and regtab's own cell)
* G3  desctab/table1_tc t-test and ANOVA p-values against the pooled-variance
*     and one-way F formulas computed from summarize, at moderate p
* G4  regtab eform: both interval limits are exp(b -/+ z se), from e(b), e(V)
* N1  survtab and ratetab null case: data not stset, stset characteristics
*     left without their variables, an empty sample
* N2  tabcell est null case: no estimation results, a coefficient absent
*     from e(b), lincom with no lincom results
* N3  stratetab null case: missing file, a saved file that is not strate
*     output, a strate-shaped file with no rows
* N4  stacktab, comptab, hrcomptab null case: a frame that does not exist and
*     an empty frame; comptab names the caller's frame in its error
* N5  corrtab and outtab null case: an all-missing variable
*
* Run from tabtools/qa.

clear all
version 17.0
set more off
set varabbrev off
set linesize 255

capture log close _g10
log using "test_qa_gaps_2026_10_10.log", replace text name(_g10)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear
* the shared helper file, for _tabtools_format_p
quietly findfile _tabtools_common.ado
quietly run "`r(fn)'"

* _gx_csv FILE: load a CSV, every cell a string, into frame _gx (v1, v2, ...)
capture program drop _gx_csv
program define _gx_csv
    version 17.0
    args file
    capture frame drop _gx
    frame create _gx
    frame _gx: quietly import delimited using `"`file'"', varnames(nonames) ///
        stringcols(_all) delimiter(",") bindquote(strict) clear
end

* _gx_2x2 A B C D: a 2x2 table (row, col) with cell counts A B / C D
capture program drop _gx_2x2
program define _gx_2x2
    version 17.0
    args a b c d
    clear
    quietly set obs 4
    generate byte row = cond(_n <= 2, 1, 2)
    generate byte col = cond(mod(_n, 2) == 1, 1, 2)
    generate long w = .
    quietly replace w = `a' in 1
    quietly replace w = `b' in 2
    quietly replace w = `c' in 3
    quietly replace w = `d' in 4
    quietly expand w
    drop w
end

**# G1: Fisher below an expected count of 5, chi-squared at 5
local ++test_count
capture noisily {
    * N = 100, row 1 total 10: column 1 total 49 gives a minimum expected
    * count of 10 * 49 / 100 = 4.9, column 1 total 50 gives exactly 5. The
    * tables are unbalanced so Fisher and chi-squared p-values differ.
    _gx_2x2 8 2 41 49
    quietly tab row col, exact
    local p_ex = r(p_exact)
    crosstab row col
    assert !missing(r(p), `p_ex') & reldif(r(p), `p_ex') < 1e-12
    assert missing(r(chi2))
    _gx_2x2 8 2 42 48
    quietly tab row col, chi2
    local p_ch = r(p)
    local chi = r(chi2)
    crosstab row col
    assert !missing(r(p), `p_ch') & reldif(r(p), `p_ch') < 1e-12
    assert !missing(r(chi2), `chi') & reldif(r(chi2), `chi') < 1e-12
    * the two tests disagree here, so the choice is visible in r(p)
    quietly tab row col, exact
    assert abs(r(p_exact) - `p_ch') > 1e-6
}
if _rc == 0 {
    display as result "  PASS: G1 crosstab Fisher/chi-squared switch at expected count 5"
    local ++pass_count
}
else {
    display as error "  FAIL: G1 crosstab test switch (rc=`=_rc')"
    local ++fail_count
}

**# G2: the p-value display rule, value by value
local ++test_count
capture noisily {
    * p and its text under the default pdp(3) highpdp(2)
    local grid "0 <0.001 0.0004 <0.001 0.001 0.001 0.0123 0.012 0.05 0.050"
    local grid "`grid' 0.0734 0.073 0.0949 0.095 0.1 0.10 0.25 0.25 0.5 0.50"
    local grid "`grid' 0.989 0.99 0.991 >0.99 1 1.00"
    local n : word count `grid'
    clear
    quietly set obs `=`n' / 2'
    generate double p = .
    generate str10 want = ""
    forvalues i = 1(2)`n' {
        local j = (`i' + 1) / 2
        quietly replace p = real(word("`grid'", `i')) in `j'
        quietly replace want = word("`grid'", `i' + 1) in `j'
    }
    _tabtools_fmt_p p, generate(got)
    assert got == want
    forvalues j = 1/`=_N' {
        _tabtools_format_p, pvalue(`=p[`j']')
        assert `"`r(value)'"' == want[`j']
    }
    * regtab's p cell for a coefficient whose p lies in 0.05-0.10
    sysuse auto, clear
    collect clear
    quietly collect: regress price weight length
    matrix T = r(table)
    local p = T["pvalue", "length"]
    assert `p' >= 0.001 & `p' < 0.10
    tempfile f
    regtab, csv("`f'.csv")
    _gx_csv "`f'.csv"
    local hl : variable label length
    frame _gx: quietly count if strtrim(v1) == "`hl'" & strtrim(v4) == strtrim(string(`p', "%5.3f"))
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: G2 p-value display rule pinned to literal text"
    local ++pass_count
}
else {
    display as error "  FAIL: G2 p-value rule (rc=`=_rc')"
    local ++fail_count
}

**# G3: desctab t-test and ANOVA p-values against the formulas
local ++test_count
capture noisily {
    sysuse auto, clear
    * pooled-variance t test of headroom by foreign, from summarize
    quietly summarize headroom if foreign == 0
    local n0 = r(N)
    local m0 = r(mean)
    local v0 = r(Var)
    quietly summarize headroom if foreign == 1
    local n1 = r(N)
    local m1 = r(mean)
    local v1 = r(Var)
    local df = `n0' + `n1' - 2
    local sp2 = ((`n0' - 1) * `v0' + (`n1' - 1) * `v1') / `df'
    local t = (`m1' - `m0') / sqrt(`sp2' * (1 / `n0' + 1 / `n1'))
    local p_t = 2 * ttail(`df', abs(`t'))
    * a moderate p, where df and df + 1 differ in the 4th significant digit
    assert `p_t' > 0.001 & `p_t' < 0.5
    table1_tc, vars(headroom contn) by(foreign)
    matrix R = r(table)
    assert !missing(R[1, 1], `p_t') & reldif(R[1, 1], `p_t') < 1e-9
    * one-way ANOVA of mpg by rep78 (missing rep78 left out)
    quietly summarize mpg if !missing(rep78)
    local N = r(N)
    local gm = r(mean)
    local ssw = 0
    local ssb = 0
    quietly levelsof rep78, local(levs)
    local k : word count `levs'
    foreach l of local levs {
        quietly summarize mpg if rep78 == `l'
        local ssb = `ssb' + r(N) * (r(mean) - `gm')^2
        local ssw = `ssw' + (r(N) - 1) * r(Var)
    }
    local F = (`ssb' / (`k' - 1)) / (`ssw' / (`N' - `k'))
    local p_f = Ftail(`k' - 1, `N' - `k', `F')
    table1_tc, vars(mpg contn) by(rep78)
    matrix R = r(table)
    assert !missing(R[1, 1], `p_f') & reldif(R[1, 1], `p_f') < 1e-9
}
if _rc == 0 {
    display as result "  PASS: G3 t-test and ANOVA p-values match the formulas"
    local ++pass_count
}
else {
    display as error "  FAIL: G3 desctab test p-values (rc=`=_rc')"
    local ++fail_count
}

**# G4: regtab eform interval limits are both exponentiated
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: logit foreign mpg weight, or
    local z = invnormal(0.975)
    local b = _b[mpg]
    local se = sqrt(el(e(V), rownumb(e(V), "mpg"), colnumb(e(V), "mpg")))
    local lo = exp(`b' - `z' * `se')
    local hi = exp(`b' + `z' * `se')
    tempfile f
    regtab, csv("`f'.csv") digits(4)
    _gx_csv "`f'.csv"
    local ml : variable label mpg
    frame _gx: quietly count if strtrim(v1) == "`ml'"
    assert r(N) == 1
    frame _gx: quietly levelsof v3 if strtrim(v1) == "`ml'", local(ci) clean
    local ci = subinstr(subinstr("`ci'", "(", "", .), ")", "", .)
    gettoken clo chi : ci, parse(",")
    local chi = subinstr("`chi'", ",", "", 1)
    assert abs(real("`clo'") - `lo') < 0.00005
    assert abs(real("`chi'") - `hi') < 0.00005
    frame _gx: quietly levelsof v2 if strtrim(v1) == "`ml'", local(est) clean
    assert abs(real("`est'") - exp(`b')) < 0.00005
}
if _rc == 0 {
    display as result "  PASS: G4 regtab eform estimate and both limits exponentiated"
    local ++pass_count
}
else {
    display as error "  FAIL: G4 regtab eform CI (rc=`=_rc')"
    local ++fail_count
}

**# N1: survtab and ratetab null case
local ++test_count
capture noisily {
    * null case: data that were never stset
    sysuse auto, clear
    capture survtab, times(1)
    assert _rc == 119
    capture ratetab foreign
    assert _rc == 119
    * degenerate stset state: the characteristics survive, _t does not
    webuse drugtr, clear
    drop _t
    capture survtab, times(10)
    assert _rc == 111
    capture ratetab drug
    assert _rc == 111
    * null case: an empty sample
    webuse drugtr, clear
    capture ratetab drug if drug == 99
    assert _rc == 2000
    capture survtab if drug == 99, times(10)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: N1 survtab/ratetab refuse unset, half-set and empty survival data"
    local ++pass_count
}
else {
    display as error "  FAIL: N1 survtab/ratetab null case (rc=`=_rc')"
    local ++fail_count
}

**# N2: tabcell est null case
local ++test_count
capture noisily {
    sysuse auto, clear
    * null case: no estimation results at all
    ereturn clear
    capture tabcell est weight
    assert _rc == 301
    * degenerate source: a coefficient the model does not have
    quietly regress price weight
    capture tabcell est mpg
    assert _rc == 111
    * null case: lincom asked for with no lincom results in r()
    quietly summarize price
    capture tabcell est, lincom
    assert _rc == 301
}
if _rc == 0 {
    display as result "  PASS: N2 tabcell est refuses absent estimation results"
    local ++pass_count
}
else {
    display as error "  FAIL: N2 tabcell null case (rc=`=_rc')"
    local ++fail_count
}

**# N3: stratetab null case
local ++test_count
capture noisily {
    tempfile notstrate emptystrate
    * null case: a file that does not exist
    capture stratetab, using(_g10_no_such_file) outcomes(1)
    assert _rc == 601
    * degenerate saved file: not strate output
    sysuse auto, clear
    quietly save "`notstrate'.dta", replace
    capture stratetab, using("`notstrate'") outcomes(1)
    assert _rc == 111
    * degenerate saved file: strate-shaped, zero rows
    clear
    foreach v in _Rate _Lower _Upper _D _Y {
        generate double `v' = .
    }
    quietly save "`emptystrate'.dta", replace emptyok
    capture stratetab, using("`emptystrate'") outcomes(1)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: N3 stratetab refuses missing, foreign and empty strate files"
    local ++pass_count
}
else {
    display as error "  FAIL: N3 stratetab null case (rc=`=_rc')"
    local ++fail_count
}

**# N4: stacktab, comptab, hrcomptab null case
local ++test_count
capture noisily {
    capture frame drop _g10_empty
    frame create _g10_empty
    tempfile f
    * null case: a frame that does not exist, and an empty one
    capture stacktab, frames(_g10_no_such_frame) sheet("S") csv("`f'.csv")
    assert _rc == 111
    capture stacktab, frames(_g10_empty) sheet("S") csv("`f'.csv")
    assert _rc == 111
    capture comptab _g10_no_such_frame, rows(1)
    assert _rc == 111
    capture noisily comptab _g10_empty, rows(1)
    assert _rc == 198
    capture hrcomptab _g10_no_such_frame, modelframes(_g10_empty) rows(1)
    assert _rc == 111
    capture hrcomptab _g10_empty, modelframes(_g10_empty) rows(1)
    assert _rc != 0
    * comptab's empty-frame error names the caller's frame
    tempfile lg
    log using "`lg'.log", text replace name(_g10b)
    capture noisily comptab _g10_empty, rows(1)
    log close _g10b
    mata: st_numscalar("_g10_n", sum(strpos(cat(st_local("lg") + ".log"), "Frame '_g10_empty' has no data rows") :> 0))
    assert scalar(_g10_n) == 1
    scalar drop _g10_n
    frame drop _g10_empty
}
if _rc == 0 {
    display as result "  PASS: N4 stacktab/comptab/hrcomptab refuse missing and empty frames"
    local ++pass_count
}
else {
    local n4rc = _rc
    capture log close _g10b
    capture frame drop _g10_empty
    display as error "  FAIL: N4 frame null case (rc=`n4rc')"
    local ++fail_count
}

**# N5: corrtab and outtab null case: all-missing input
local ++test_count
capture noisily {
    sysuse auto, clear
    generate double allmiss = .
    generate byte ev = price > 6000
    * null case: an all-missing variable leaves no usable observation
    capture corrtab price allmiss
    assert _rc == 2000
    capture outtab ev, exposure(allmiss)
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: N5 corrtab/outtab refuse all-missing input"
    local ++pass_count
}
else {
    display as error "  FAIL: N5 all-missing null case (rc=`=_rc')"
    local ++fail_count
}

capture frame drop _gx

**# Summary
display as result "RESULT: test_qa_gaps_2026_10_10 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _g10
if `fail_count' > 0 exit 1
