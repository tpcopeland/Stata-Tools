* test_cycle_20261119_regtab_helpers.do - regtab helper review cycle 2026-11-19
*
* F1 _regtab_flatten: a multi-equation row is a dropped base-outcome row only
*    when its raw coefficient key starts with "o.", never because its display
*    label does ("o.d. of the sample" vanished from every mlogit/zip equation).
* F2 _regtab_relabel: relabel rewrites whole parameter tokens or
*    random-effects rows only (has_consent became hasInterceptent, lnsig_ex
*    became "Residual Log SDx", a label "Log sd(income)" became "Log SD (income)").
* F3 _regtab_statrows: stats() cells never fall back to e-notation or drop
*    the thousands separator (Root MSE 917662.140 printed as 9.18e+05).
* F4 _regtab_frameopts: frame()/eplotframe() cannot replace the default
*    frame from another frame (the user's data was swapped for the table).
* F8 _regtab_statrows: an e(r2_a) shown in the R² row is labelled as adjusted,
*    and is not repeated there when the Adjusted R² row is requested.
* Oracles: _b and e() of the fitted model, string() of the stored statistic,
*    and the display frame and console of regtab.

clear all
set more off
set varabbrev off
set linesize 255
version 17.0

capture log close _cyrh
log using "test_cycle_20261119_regtab_helpers.log", replace text name(_cyrh)

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

capture program drop _cyrh_cell
program define _cyrh_cell, rclass
    * _cyrh_cell <frame> <row label> <var>: r(n) rows whose trimmed A equals
    * the label, r(cell) the trimmed <var> of the first one
    args fr lab var
    local n = 0
    local cell ""
    frame `fr' {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == `"`lab'"' {
                local ++n
                if `n' == 1 local cell = strtrim(`var'[`i'])
            }
        }
    }
    return scalar n = `n'
    return local cell `"`cell'"'
end

capture program drop _cyrh_has
program define _cyrh_has, rclass
    * _cyrh_has <frame> <substring>: r(n) rows whose A contains it
    args fr sub
    local n = 0
    frame `fr' {
        forvalues i = 1/`=_N' {
            if strpos(A[`i'], `"`sub'"') local ++n
        }
    }
    return scalar n = `n'
end

capture program drop _cyrh_r2a
program define _cyrh_r2a, eclass
    * a user estimator that posts e(r2_a) but no e(r2), and an integer scalar
    quietly regress y x
    tempname b V
    matrix `b' = e(b)
    matrix `V' = e(V)
    local r2a = e(r2_a)
    local N = e(N)
    ereturn post `b' `V', depname(y) obs(`N')
    ereturn scalar r2_a = `r2a'
    ereturn scalar bigint = 1234567890
    ereturn scalar bigval = 123456789.125
    ereturn local cmd "_cyrh_r2a"
end

**# F1: a covariate labelled "o...." survives every mlogit equation
local ++test_count
capture noisily {
    clear
    set seed 7
    set obs 600
    generate double x = rnormal()
    generate double w = rnormal()
    label variable x "o.d. of the sample"
    label variable w "Weight"
    generate byte y = mod(_n, 3) + (x > 0.3)
    replace y = 2 if runiform() < .15
    collect clear
    quietly collect: mlogit y x w, baseoutcome(0)
    local b1 = exp([1]_b[x])
    local b3 = exp([3]_b[x])
    capture frame drop _cyh1
    quietly regtab, frame(_cyh1, replace) keepintercept
    foreach eq in 1 2 3 {
        _cyrh_cell _cyh1 "`eq': o.d. of the sample" c1
        assert r(n) == 1
        _cyrh_cell _cyh1 "`eq': Weight" c1
        assert r(n) == 1
    }
    _cyrh_cell _cyh1 "1: o.d. of the sample" c1
    assert abs(real("`r(cell)'") - `b1') < 0.005
    _cyrh_cell _cyh1 "3: o.d. of the sample" c1
    assert abs(real("`r(cell)'") - `b3') < 0.005
    * the base outcome equation stays out of the table
    frame _cyh1 {
        quietly count if strpos(strtrim(A), "0: ") == 1
        assert r(N) == 0
    }
}
if _rc == 0 {
    display as result "  PASS: F1 mlogit covariate labelled o.d. kept in every equation"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 mlogit covariate labelled o.d. (rc=`=_rc')"
    local ++fail_count
}

**# F1: zip keeps the covariate in both equations
local ++test_count
capture noisily {
    clear
    set obs 800
    set seed 11
    generate double x = rnormal()
    generate double z = rnormal()
    label variable x "o.r. score"
    generate cnt = rpoisson(exp(0.3 + 0.4*x)) * (runiform() > 0.3)
    collect clear
    quietly collect: zip cnt x, inflate(z x)
    local bc = [cnt]_b[x]
    local bi = [inflate]_b[x]
    capture frame drop _cyh2
    quietly regtab, frame(_cyh2, replace) keepintercept
    _cyrh_cell _cyh2 "cnt: o.r. score" c1
    assert r(n) == 1
    assert abs(real("`r(cell)'") - `bc') < 0.005
    _cyrh_cell _cyh2 "Inflation equation: o.r. score" c1
    assert r(n) == 1
    assert abs(real("`r(cell)'") - `bi') < 0.005
}
if _rc == 0 {
    display as result "  PASS: F1 zip covariate labelled o.r. kept in both equations"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 zip covariate labelled o.r. (rc=`=_rc')"
    local ++fail_count
}

**# F1: o.-keyed rows are still dropped (collinear term, base equation)
local ++test_count
capture noisily {
    clear
    set seed 7
    set obs 600
    generate double x = rnormal()
    generate double x2 = 2*x
    generate byte g = 1 + mod(_n, 4)
    generate byte flag = g == 4
    label define _cyhg 1 "One" 2 "Two" 3 "Three" 4 "Four"
    label values g _cyhg
    generate byte y = floor(3*runiform())
    collect clear
    quietly collect: mlogit y x x2 flag i.g, baseoutcome(0)
    capture frame drop _cyh3
    quietly regtab, frame(_cyh3, replace)
    _cyrh_has _cyh3 "x2"
    assert r(n) == 0
    _cyrh_cell _cyh3 "1: x" c1
    assert r(n) == 1
    _cyrh_cell _cyh3 "1:   Four" c1
    assert "`r(cell)'" == "Omitted"
    _cyrh_cell _cyh3 "2:   One" c1
    assert "`r(cell)'" == "Reference"
    frame _cyh3 {
        quietly count if strpos(strtrim(A), "0: ") == 1
        assert r(N) == 0
    }
}
if _rc == 0 {
    display as result "  PASS: F1 o.-keyed collinear and base-equation rows still dropped"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 o.-keyed rows (rc=`=_rc')"
    local ++fail_count
}

**# F2: relabel leaves covariate names that contain _cons / lnsig_e alone
local ++test_count
capture noisily {
    clear
    set seed 42
    set obs 400
    generate double x = rnormal()
    generate byte has_consent = runiform() < .4
    generate double lnsig_ex = rnormal()
    generate double yc = 1 + x + has_consent + rnormal()
    generate int g = ceil(_n/20)
    collect clear
    quietly collect: mixed yc x has_consent lnsig_ex || g:
    local bh = _b[has_consent]
    capture frame drop _cyh4
    quietly regtab, relabel frame(_cyh4, replace)
    _cyrh_cell _cyh4 "has_consent" c1
    assert r(n) == 1
    assert abs(real("`r(cell)'") - `bh') < 0.005
    _cyrh_cell _cyh4 "lnsig_ex" c1
    assert r(n) == 1
    _cyrh_has _cyh4 "hasIntercept"
    assert r(n) == 0
    _cyrh_has _cyh4 "Log SDx"
    assert r(n) == 0
    _cyrh_cell _cyh4 "Intercept" c1
    assert r(n) == 1
    _cyrh_cell _cyh4 "Variance: g (Intercept)" c1
    assert r(n) == 1
    _cyrh_cell _cyh4 "Residual Variance" c1
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: F2 relabel keeps has_consent and lnsig_ex intact"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 relabel covariate names (rc=`=_rc')"
    local ++fail_count
}

**# F2: relabel without random effects leaves fixed-effect labels alone
local ++test_count
capture noisily {
    clear
    set seed 42
    set obs 400
    generate double x = rnormal()
    generate byte has_consent = runiform() < .4
    generate double inc = rnormal()
    label variable inc "Log sd(income)"
    generate double yc = 1 + x + has_consent + rnormal()
    collect clear
    quietly collect: regress yc x has_consent inc
    capture frame drop _cyh5
    quietly regtab, relabel frame(_cyh5, replace)
    _cyrh_cell _cyh5 "Log sd(income)" c1
    assert r(n) == 1
    _cyrh_cell _cyh5 "has_consent" c1
    assert r(n) == 1
    _cyrh_has _cyh5 "SD ("
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: F2 fallback relabel leaves fixed-effect labels alone"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 fallback relabel (rc=`=_rc')"
    local ++fail_count
}

**# F2: random-slope relabel is unchanged
local ++test_count
capture noisily {
    clear
    set seed 42
    set obs 400
    generate double x = rnormal()
    generate byte has_consent = runiform() < .4
    generate double yc = 1 + x + has_consent + rnormal()
    generate int g = ceil(_n/20)
    collect clear
    quietly collect: mixed yc x has_consent || g: x, covariance(unstructured)
    capture frame drop _cyh6
    quietly regtab, relabel frame(_cyh6, replace) keepintercept
    foreach r in "has_consent" "Intercept" "Variance: g (x)" ///
        "Variance: g (Intercept)" "Covariance: g (x, Intercept)" "Residual Variance" {
        _cyrh_cell _cyh6 "`r'" c1
        assert r(n) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: F2 random-slope relabel unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 random-slope relabel (rc=`=_rc')"
    local ++fail_count
}

**# F3: large Root MSE and F print in fixed notation
local ++test_count
capture noisily {
    clear
    set obs 500
    set seed 3
    generate x = rnormal()
    generate y = 1.5e8 + 4e7*x + 9e5*rnormal()
    collect clear
    quietly collect: regress y x
    local rmse = string(e(rmse), "%20.3f")
    capture frame drop _cyh7
    quietly regtab, stats(rmse) frame(_cyh7, replace)
    _cyrh_cell _cyh7 "Root MSE" c1
    assert r(n) == 1
    assert "`r(cell)'" == "`rmse'"
    assert strpos("`r(cell)'", "e+") == 0

    clear
    set obs 500
    set seed 4
    generate x = rnormal()
    generate y = 1000*x + rnormal()
    collect clear
    quietly collect: regress y x
    assert e(F) >= 1e6
    local fstat = string(e(F), "%20.2f")
    capture frame drop _cyh7b
    quietly regtab, stats(F) frame(_cyh7b, replace)
    _cyrh_cell _cyh7b "F statistic" c1
    assert "`r(cell)'" == "`fstat'"
    assert strpos("`r(cell)'", "e+") == 0
}
if _rc == 0 {
    display as result "  PASS: F3 large stats print in fixed notation"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 large stats notation (rc=`=_rc')"
    local ++fail_count
}

**# F3: large e() statistics: separators kept, no e-notation
local ++test_count
capture noisily {
    clear
    set seed 5
    set obs 400
    generate x = rnormal()
    generate y = x + rnormal()
    collect clear
    quietly collect: _cyrh_r2a
    capture frame drop _cyh8
    quietly regtab, stats(e(bigint)="Big" e(bigval)="Bigval") frame(_cyh8, replace)
    _cyrh_cell _cyh8 "Big" c1
    assert r(n) == 1
    assert "`r(cell)'" == "1,234,567,890"
    _cyrh_cell _cyh8 "Bigval" c1
    assert r(n) == 1
    assert "`r(cell)'" == "123456789.125"
}
if _rc == 0 {
    display as result "  PASS: F3 large e() statistics printed in full"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 integer statistic separators (rc=`=_rc')"
    local ++fail_count
}

**# F4: frame(default, replace) from another frame is refused
local ++test_count
capture noisily {
    clear
    set seed 42
    set obs 400
    generate double x = rnormal()
    generate double yc = 1 + x + rnormal()
    collect clear
    quietly collect: regress yc x
    capture frame drop _cyh_other
    frame create _cyh_other
    frame change _cyh_other
    capture noisily regtab, frame(default, replace)
    local rc1 = _rc
    capture noisily regtab, eplotframe(default, replace)
    local rc2 = _rc
    * a frame of another name is still built from here
    capture frame drop _cyh9
    capture noisily regtab, frame(_cyh9, replace)
    local rc3 = _rc
    frame change default
    assert `rc1' == 198
    assert `rc2' == 198
    assert `rc3' == 0
    assert _N == 400
    confirm variable yc x
    _cyrh_cell _cyh9 "x" c1
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: F4 default frame protected from frame()/eplotframe()"
    local ++pass_count
}
else {
    display as error "  FAIL: F4 default frame protection (rc=`=_rc')"
    local ++fail_count
}
capture frame change default
capture frame drop _cyh_other

**# F8: an e(r2_a) in the R² row is labelled as adjusted
local ++test_count
capture noisily {
    clear
    set seed 5
    set obs 400
    generate x = rnormal()
    generate y = x + rnormal()
    collect clear
    quietly collect: regress y x
    local r2 = string(e(r2), "%5.3f")
    quietly collect: _cyrh_r2a
    local r2a = string(e(r2_a), "%5.3f")
    capture frame drop _cyh10
    quietly regtab, stats(r2) frame(_cyh10, replace) nopvalue
    _cyrh_cell _cyh10 "R²" c1
    assert r(n) == 0
    _cyrh_cell _cyh10 "R² / Adjusted R²" c1
    assert r(n) == 1
    assert "`r(cell)'" == "`r2'"
    _cyrh_cell _cyh10 "R² / Adjusted R²" c3
    assert "`r(cell)'" == "`r2a'"

    * with the Adjusted R² row requested, the R² row does not repeat it
    capture frame drop _cyh10b
    quietly regtab, stats(r2 r2_a) frame(_cyh10b, replace) nopvalue
    _cyrh_cell _cyh10b "R²" c1
    assert r(n) == 1
    assert "`r(cell)'" == "`r2'"
    _cyrh_cell _cyh10b "R²" c3
    assert "`r(cell)'" == ""
    _cyrh_cell _cyh10b "Adjusted R²" c3
    assert r(n) == 1
    assert "`r(cell)'" == "`r2a'"

    * a single adjusted-only model is labelled Adjusted R²
    collect clear
    quietly collect: _cyrh_r2a
    capture frame drop _cyh10c
    quietly regtab, stats(r2) frame(_cyh10c, replace) nopvalue
    _cyrh_cell _cyh10c "Adjusted R²" c1
    assert r(n) == 1
    assert "`r(cell)'" == "`r2a'"
    _cyrh_cell _cyh10c "R²" c1
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: F8 adjusted R² labelled, not repeated"
    local ++pass_count
}
else {
    display as error "  FAIL: F8 adjusted R² labelling (rc=`=_rc')"
    local ++fail_count
}

**# F8: R² and pseudo R² labels are unchanged
local ++test_count
capture noisily {
    clear
    set seed 5
    set obs 400
    generate x = rnormal()
    generate y = x + rnormal()
    generate byte yb = y > 0
    collect clear
    quietly collect: regress y x
    quietly collect: logit yb x
    local r2p = string(e(r2_p), "%5.3f")
    capture frame drop _cyh11
    quietly regtab, stats(r2) frame(_cyh11, replace) nopvalue
    _cyrh_cell _cyh11 "R² / Pseudo R²" c3
    assert r(n) == 1
    assert "`r(cell)'" == "`r2p'"
    collect clear
    quietly collect: regress y x
    capture frame drop _cyh11b
    quietly regtab, stats(r2) frame(_cyh11b, replace) nopvalue
    _cyrh_cell _cyh11b "R²" c1
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: F8 R² and pseudo R² labels unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: F8 R² and pseudo R² labels (rc=`=_rc')"
    local ++fail_count
}

display as result "regtab helpers cycle QA summary: `pass_count' passed, `fail_count' failed"
display "RESULT: test_cycle_20261119_regtab_helpers tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _cyrh
if `fail_count' > 0 exit 1
