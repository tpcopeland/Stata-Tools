*! test_documentation_examples.do — Runs every fvgen.sthlp and README example
*! Author: Timothy P Copeland, Karolinska Institutet
*! Requires: Stata 16.0+

* Each help-file Example (1-9) and each README example runs as written, against
* the package installed into a sandbox PLUS (net install from the package
* directory), and its result is checked against an independent oracle: the
* same model fitted with native factor-variable notation.

clear all
set varabbrev off
version 16.0

do _fvgen_qa_common.do
_fvgen_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Help-file Setup block.
capture program drop _fvdoc_setup
program define _fvdoc_setup
    sysuse auto, clear
    label define rl 1 "Poor" 2 "Fair" 3 "Avg" 4 "Good" 5 "Best", replace
    label values rep78 rl
end

* reldif() with both sides asserted non-missing first.
capture program drop _fvdoc_same
program define _fvdoc_same
    args a b tol
    if "`tol'" == "" local tol 1e-8
    assert !missing(`a', `b')
    assert reldif(`a', `b') < `tol'
end

**# 0. The examples resolve the installed copy, not the source tree
local ++test_count
capture noisily {
    quietly findfile fvgen.ado
    local fn "`r(fn)'"
    assert strpos(`"`fn'"', `"`c(sysdir_plus)'"') == 1
    quietly findfile fvgen.sthlp
    assert strpos(`"`r(fn)'"', `"`c(sysdir_plus)'"') == 1
}
if _rc == 0 {
    display as result "  PASS: 0 fvgen.ado and fvgen.sthlp resolve from the installed PLUS"
    local ++pass_count
}
else {
    display as error "  FAIL: 0 installed resolution (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 0"
}

**# 1. Example 1: categorical-by-continuous interaction
local ++test_count
capture noisily {
    _fvdoc_setup
    quietly regress price i.foreign##c.mpg
    scalar b_f = _b[1.foreign]
    scalar b_m = _b[mpg]
    scalar b_i = _b[1.foreign#c.mpg]
    scalar rss = e(rss)
    fvgen i.foreign##c.mpg
    assert "`r(allvars)'" == "_foreign_1 mpg _foreignXmpg_1"
    assert r(k_main) == 2 & r(k_int) == 1
    assert "`: variable label _foreign_1'" == "Foreign"
    assert ustrpos("`: variable label _foreignXmpg_1'", "Foreign × Mileage (mpg)") == 1
    regress price `r(allvars)'
    _fvdoc_same _b[_foreign_1] b_f
    _fvdoc_same _b[mpg] b_m
    _fvdoc_same _b[_foreignXmpg_1] b_i
    _fvdoc_same e(rss) rss 1e-10
    assert e(N) == 74
}
if _rc == 0 {
    display as result "  PASS: 1 Example 1 reproduces the native i.foreign##c.mpg fit"
    local ++pass_count
}
else {
    display as error "  FAIL: 1 Example 1 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**# 2. Example 2: categorical-by-categorical interaction (empty cells)
local ++test_count
capture noisily {
    _fvdoc_setup
    quietly regress price i.foreign##i.rep78
    scalar rss = e(rss)
    scalar dfm = e(df_m)
    quietly predict double _fvdoc_native, xb
    fvgen i.foreign##i.rep78, replace
    assert "`r(mainvars)'" == "_foreign_1 _rep78_2 _rep78_3 _rep78_4 _rep78_5"
    * foreign==1 never has rep78 1 or 2, so only three product terms exist.
    assert "`r(intvars)'" == "_foreignXrep78_1_3 _foreignXrep78_1_4 _foreignXrep78_1_5"
    assert "`: variable label _rep78_4'" == "Good"
    regress price `r(allvars)'
    _fvdoc_same e(rss) rss 1e-10
    assert e(df_m) == dfm
    * 1.foreign plus the three products are collinear (no foreign car has
    * rep78 1 or 2), so native and flattened fits omit different terms and
    * coefficients are not term-by-term comparable; the fitted values are.
    quietly predict double _fvdoc_flat if e(sample), xb
    quietly count if e(sample)
    assert r(N) == 69
    assert !missing(_fvdoc_native, _fvdoc_flat) if e(sample)
    assert reldif(_fvdoc_native, _fvdoc_flat) < 1e-8 if e(sample)
    drop _fvdoc_native _fvdoc_flat
}
if _rc == 0 {
    display as result "  PASS: 2 Example 2 reproduces the native i.foreign##i.rep78 fit"
    local ++pass_count
}
else {
    display as error "  FAIL: 2 Example 2 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**# 3. Example 3: continuous-by-continuous, centered
local ++test_count
capture noisily {
    _fvdoc_setup
    quietly regress price c.mpg##c.weight
    scalar rss = e(rss)
    scalar b_i = _b[c.mpg#c.weight]
    quietly summarize mpg
    scalar mpg_mean = r(mean)
    fvgen c.mpg##c.weight, center replace
    assert "`r(allvars)'" == "_mpg_c _weight_c _mpgXweight"
    assert "`: variable label _mpg_c'" == "Mileage (mpg) (centered)"
    regress price `r(allvars)'
    * Centering reparameterizes the main effects; the fit and the product
    * coefficient are unchanged.
    _fvdoc_same e(rss) rss 1e-10
    _fvdoc_same _b[_mpgXweight] b_i
    quietly summarize _mpg_c
    assert abs(r(mean)) < 1e-10
    _fvdoc_same "(mpg[1] - mpg_mean)" "_mpg_c[1]" 1e-10
}
if _rc == 0 {
    display as result "  PASS: 3 Example 3 centered fit equals the native c.mpg##c.weight fit"
    local ++pass_count
}
else {
    display as error "  FAIL: 3 Example 3 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**# 4. Example 4: keep all levels, ASCII interaction symbol
local ++test_count
capture noisily {
    _fvdoc_setup
    fvgen i.foreign##i.rep78, alllevels xsymbol(x) replace
    assert "`r(mainvars)'" == "_foreign_0 _foreign_1 _rep78_1 _rep78_2 _rep78_3 _rep78_4 _rep78_5"
    assert r(k_all) == 10
    assert "`: variable label _foreign_0'" == "Domestic"
    assert "`: variable label _rep78_1'" == "Poor"
    assert "`: variable label _foreignXrep78_1_4'" == "Foreign x Good"
    * Every level is materialized: the level indicators sum to one per
    * nonmissing observation.
    egen double _fvdoc_sum = rowtotal(_rep78_1 _rep78_2 _rep78_3 _rep78_4 _rep78_5)
    assert _fvdoc_sum == 1 if !missing(rep78)
    drop _fvdoc_sum
}
if _rc == 0 {
    display as result "  PASS: 4 Example 4 materializes every level with ASCII labels"
    local ++pass_count
}
else {
    display as error "  FAIL: 4 Example 4 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**# 5. Example 5: a different reference level per factor
local ++test_count
capture noisily {
    _fvdoc_setup
    quietly regress price i.foreign##ib3.rep78
    scalar rss = e(rss)
    scalar b_r1 = _b[1.rep78]
    fvgen i.foreign##i.rep78, ref(rep78 3) replace
    assert "`r(spec)'" == "i.foreign ib3.rep78 i.foreign#ib3.rep78"
    assert strpos(" `r(mainvars)' ", " _rep78_3 ") == 0
    assert strpos(" `r(mainvars)' ", " _rep78_1 ") > 0
    regress price `r(allvars)'
    _fvdoc_same e(rss) rss 1e-10
    _fvdoc_same _b[_rep78_1] b_r1
}
if _rc == 0 {
    display as result "  PASS: 5 Example 5 ref(rep78 3) matches the native ib3.rep78 fit"
    local ++pass_count
}
else {
    display as error "  FAIL: 5 Example 5 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

**# 6. Example 6: per-group slopes (simple effects)
local ++test_count
capture noisily {
    _fvdoc_setup
    quietly regress price i.foreign##c.mpg
    scalar s0 = _b[mpg]
    scalar s1 = _b[mpg] + _b[1.foreign#c.mpg]
    scalar rss = e(rss)
    fvgen i.foreign##c.mpg, simple(foreign) replace
    assert "`r(allvars)'" == "_foreign_1 _foreignXmpg_0 _foreignXmpg_1"
    assert "`: variable label _foreignXmpg_0'" == "Mileage (mpg) (Domestic)"
    assert "`: variable label _foreignXmpg_1'" == "Mileage (mpg) (Foreign)"
    regress price `r(allvars)'
    _fvdoc_same _b[_foreignXmpg_0] s0
    _fvdoc_same _b[_foreignXmpg_1] s1
    _fvdoc_same e(rss) rss 1e-10
}
if _rc == 0 {
    display as result "  PASS: 6 Example 6 slopes equal the native per-group slopes"
    local ++pass_count
}
else {
    display as error "  FAIL: 6 Example 6 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

**# 7. Example 7: reference by value-label string, then tear down
local ++test_count
capture noisily {
    _fvdoc_setup
    fvgen i.foreign##c.mpg, ref(foreign "Domestic") replace
    assert "`r(spec)'" == "ib0.foreign mpg ib0.foreign#c.mpg"
    local made "`r(genvars)'"
    assert "`made'" == "_foreign_1 _foreignXmpg_1"
    fvgen, drop
    assert r(k_dropped) == 2
    assert "`r(dropped)'" == "`made'"
    foreach v of local made {
        capture confirm variable `v'
        assert _rc != 0
    }
    confirm variable mpg foreign
}
if _rc == 0 {
    display as result "  PASS: 7 Example 7 label-string ref() and drop remove exactly the generated variables"
    local ++pass_count
}
else {
    display as error "  FAIL: 7 Example 7 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}

**# 8. Example 8: reference level shown in main-effect labels
local ++test_count
capture noisily {
    _fvdoc_setup
    quietly regress price i.foreign##i.rep78
    scalar rss = e(rss)
    fvgen i.foreign##i.rep78, vsref("(vs. @)") replace
    assert "`: variable label _foreign_1'" == "Foreign (vs. Domestic)"
    assert "`: variable label _rep78_2'" == "Fair (vs. Poor)"
    assert ustrpos("`: variable label _foreignXrep78_1_3'", "Foreign × Avg") == 1
    regress price `r(allvars)'
    _fvdoc_same e(rss) rss 1e-10
}
if _rc == 0 {
    display as result "  PASS: 8 Example 8 vsref() labels and unchanged fit"
    local ++pass_count
}
else {
    display as error "  FAIL: 8 Example 8 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}

**# 9. Example 9: margins after a flattened regression
local ++test_count
capture noisily {
    _fvdoc_setup
    quietly regress price i.foreign##c.mpg
    quietly margins, dydx(mpg) at(foreign=(0 1))
    matrix native = r(b)
    fvgen i.foreign##c.mpg, replace
    regress price `r(allvars)'
    scalar b_flat = _b[_foreignXmpg_1]
    fvgen, margins store(m_price)
    assert "`r(margins)'" == "stored"
    assert "`r(stored)'" == "m_price"
    * store() leaves the flattened fit active for export.
    _fvdoc_same _b[_foreignXmpg_1] b_flat
    estimates restore m_price
    margins, dydx(mpg) at(foreign=(0 1))
    matrix flat = r(b)
    assert colsof(flat) == 2 & colsof(native) == 2
    _fvdoc_same flat[1,1] native[1,1]
    _fvdoc_same flat[1,2] native[1,2]
    * The documented slopes: -329.26 (Domestic) and -250.37 (Foreign).
    assert abs(flat[1,1] - (-329.2551)) < 1e-3
    assert abs(flat[1,2] - (-250.3668)) < 1e-3
    estimates drop m_price
}
if _rc == 0 {
    display as result "  PASS: 9 Example 9 margins on the stored clone equal native margins"
    local ++pass_count
}
else {
    display as error "  FAIL: 9 Example 9 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}

**# 10. README examples (quick start, ref+vsref, center+xsymbol, simple, margins)
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price i.foreign##c.mpg
    scalar rss = e(rss)
    fvgen i.foreign##c.mpg
    regress price `r(allvars)'
    _fvdoc_same e(rss) rss 1e-10
    fvgen, drop
    assert r(k_dropped) == 2

    sysuse auto, clear
    quietly regress price i.foreign##ib3.rep78
    scalar rss = e(rss)
    fvgen i.foreign##i.rep78, ref(rep78 3) vsref("(vs. @)")
    assert ustrpos("`: variable label _foreign_1'", "(vs. Domestic)") > 0
    * README data carry no rep78 value label: labels fall back to var=level.
    assert "`: variable label _rep78_1'" == "rep78=1 (vs. rep78=3)"
    regress price `r(allvars)'
    _fvdoc_same e(rss) rss 1e-10

    sysuse auto, clear
    quietly regress price c.mpg##c.weight
    scalar rss = e(rss)
    fvgen c.mpg##c.weight, center xsymbol(x)
    assert "`: variable label _mpgXweight'" == "Mileage (mpg) x Weight (lbs.)"
    regress price `r(allvars)'
    _fvdoc_same e(rss) rss 1e-10

    sysuse auto, clear
    quietly regress price i.foreign##c.mpg
    scalar s1 = _b[mpg] + _b[1.foreign#c.mpg]
    fvgen i.foreign##c.mpg, simple(foreign)
    regress price `r(allvars)'
    _fvdoc_same _b[_foreignXmpg_1] s1

    sysuse auto, clear
    fvgen i.foreign##c.mpg
    regress price `r(allvars)'
    fvgen, margins store(m_price)
    estimates restore m_price
    margins, dydx(mpg) at(foreign=(0 1))
    matrix flat = r(b)
    assert abs(flat[1,2] - (-250.3668)) < 1e-3
    estimates drop m_price
}
if _rc == 0 {
    display as result "  PASS: 10 README examples run and reproduce the native fits"
    local ++pass_count
}
else {
    display as error "  FAIL: 10 README examples (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10"
}

**# Summary
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED:`failed_tests'"
    display "RESULT: test_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count'"
