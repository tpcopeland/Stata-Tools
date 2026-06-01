* crossval_python_qba.do -- cross-validates qba formulas against Python
* Package: qba (Quantitative Bias Analysis)
* Usage: cd qba/qa && stata-mp -b do crossval_python_qba.do

clear all

* === Bootstrap ===
local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
capture confirm file "`pkg_dir'/qba.pkg"
if _rc {
    local pkg_dir "`qa_dir'"
    capture confirm file "`pkg_dir'/qba.pkg"
    if _rc {
        display as error "could not locate qba package root from `c(pwd)'"
        exit 601
    }
    local qa_dir "`pkg_dir'/qa"
}

capture ado uninstall qba
net install qba, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _assert_close
program define _assert_close
    args actual expected tolerance
    if "`tolerance'" == "" local tolerance = 0.0001
    local diff = abs(`actual' - `expected')
    if `diff' > `tolerance' {
        display as error "Expected: `expected', Got: `actual' (diff: `diff')"
        exit 9
    }
end

capture program drop _expect_from_xval
program define _expect_from_xval, rclass
    syntax , Name(string) USing(string)
    preserve
    use "`using'", clear
    keep if name == "`name'"
    assert _N == 1
    return scalar value = value[1]
    restore
end

* Python is an optional external oracle. If it is absent, skip this file
* without failing the Stata-only QA suite.
capture noisily shell python3 --version
if _rc {
    display as text "SKIP: python3 not available; Python cross-validation not run"
    capture ado uninstall qba
    exit 77
}

tempfile pyscript pycsv xval
tempname fh
file open `fh' using "`pyscript'", write replace text
file write `fh' "import csv, sys" _n
file write `fh' "" _n
file write `fh' "rows = []" _n
file write `fh' "def put(name, value):" _n
file write `fh' "    rows.append((name, float(value)))" _n
file write `fh' "def or_value(a, b, c, d):" _n
file write `fh' "    return (a * d) / (b * c)" _n
file write `fh' "def rr_value(a, b, c, d):" _n
file write `fh' "    return (a / (a + c)) / (b / (b + d))" _n
file write `fh' "def misclass(a, b, c, d, se_a, sp_a, se_b=None, sp_b=None, kind='exposure'):" _n
file write `fh' "    if se_b is None:" _n
file write `fh' "        se_b = se_a" _n
file write `fh' "    if sp_b is None:" _n
file write `fh' "        sp_b = sp_a" _n
file write `fh' "    if kind == 'exposure':" _n
file write `fh' "        m1 = a + b" _n
file write `fh' "        m0 = c + d" _n
file write `fh' "        ac = (a - (1 - sp_a) * m1) / (se_a + sp_a - 1)" _n
file write `fh' "        bc = m1 - ac" _n
file write `fh' "        cc = (c - (1 - sp_b) * m0) / (se_b + sp_b - 1)" _n
file write `fh' "        dc = m0 - cc" _n
file write `fh' "    else:" _n
file write `fh' "        n1 = a + c" _n
file write `fh' "        n0 = b + d" _n
file write `fh' "        ac = (a - (1 - sp_a) * n1) / (se_a + sp_a - 1)" _n
file write `fh' "        cc = n1 - ac" _n
file write `fh' "        bc = (b - (1 - sp_b) * n0) / (se_b + sp_b - 1)" _n
file write `fh' "        dc = n0 - bc" _n
file write `fh' "    return ac, bc, cc, dc" _n
file write `fh' "def selection(a, b, c, d, sa, sb, sc, sd):" _n
file write `fh' "    return a / sa, b / sb, c / sc, d / sd" _n
file write `fh' "def bf(p1, p0, rr):" _n
file write `fh' "    return (p1 * (rr - 1) + 1) / (p0 * (rr - 1) + 1)" _n
file write `fh' "" _n
file write `fh' "a, b, c, d = 90, 70, 210, 630" _n
file write `fh' "ac, bc, cc, dc = misclass(a, b, c, d, .88, .97, .76, .93, 'outcome')" _n
file write `fh' "put('mis_do_a', ac)" _n
file write `fh' "put('mis_do_b', bc)" _n
file write `fh' "put('mis_do_c', cc)" _n
file write `fh' "put('mis_do_d', dc)" _n
file write `fh' "put('mis_do_or', or_value(ac, bc, cc, dc))" _n
file write `fh' "put('mis_do_rr', rr_value(ac, bc, cc, dc))" _n
file write `fh' "" _n
file write `fh' "a, b, c, d = 7, 11, 13, 17" _n
file write `fh' "ac, bc, cc, dc = selection(a, b, c, d, 1, .25, .5, .8)" _n
file write `fh' "put('sel_a', ac)" _n
file write `fh' "put('sel_b', bc)" _n
file write `fh' "put('sel_c', cc)" _n
file write `fh' "put('sel_d', dc)" _n
file write `fh' "put('sel_or', or_value(ac, bc, cc, dc))" _n
file write `fh' "put('sel_rr', rr_value(ac, bc, cc, dc))" _n
file write `fh' "put('sel_sbf', (1 * .8) / (.25 * .5))" _n
file write `fh' "" _n
file write `fh' "put('conf_hi_bf', bf(1, 0, 4))" _n
file write `fh' "put('conf_hi_corr', 2 / bf(1, 0, 4))" _n
file write `fh' "put('conf_lo_bf', bf(0, 1, 4))" _n
file write `fh' "put('conf_lo_corr', 2 / bf(0, 1, 4))" _n
file write `fh' "" _n
file write `fh' "a, b, c, d = 90, 70, 210, 630" _n
file write `fh' "wa, wb, wc, wd = misclass(a, b, c, d, .88, .97, kind='exposure')" _n
file write `fh' "wa, wb, wc, wd = selection(wa, wb, wc, wd, .9, .7, .6, .8)" _n
file write `fh' "multi_bf = bf(.45, .15, 2.5)" _n
file write `fh' "put('multi_default_or', or_value(wa, wb, wc, wd) / multi_bf)" _n
file write `fh' "put('multi_default_rr', rr_value(wa, wb, wc, wd) / multi_bf)" _n
file write `fh' "wa, wb, wc, wd = selection(a, b, c, d, .9, .7, .6, .8)" _n
file write `fh' "wa, wb, wc, wd = misclass(wa, wb, wc, wd, .88, .97, kind='exposure')" _n
file write `fh' "put('multi_reverse_or', or_value(wa, wb, wc, wd) / multi_bf)" _n
file write `fh' "" _n
file write `fh' "a, b, c, d = 90, 70, 210, 630" _n
file write `fh' "wa, wb, wc, wd = misclass(a, b, c, d, .88, .97, .76, .93, 'outcome')" _n
file write `fh' "put('multi_diff_outcome_or', or_value(wa, wb, wc, wd))" _n
file write `fh' "put('multi_diff_outcome_rr', rr_value(wa, wb, wc, wd))" _n
file write `fh' "" _n
file write `fh' "with open(sys.argv[1], 'w', newline='') as f:" _n
file write `fh' "    writer = csv.writer(f)" _n
file write `fh' "    writer.writerow(['name', 'value'])" _n
file write `fh' "    writer.writerows(rows)" _n
file close `fh'

capture noisily shell python3 "`pyscript'" "`pycsv'"
if _rc {
    display as error "Python cross-validation oracle failed (error `=_rc')"
    exit 1
}

preserve
import delimited using "`pycsv'", varnames(1) clear stringcols(_all)
assert _N == 22
gen double value_d = real(value)
drop value
rename value_d value
save "`xval'", replace
restore

* ============================================================
* X1: qba_misclass versus Python matrix correction
* ============================================================

local ++test_count
capture noisily {
    qba_misclass, a(90) b(70) c(210) d(630) ///
        seca(.88) spca(.97) secb(.76) spcb(.93) type(outcome)
    local got_a = r(corrected_a)
    local got_b = r(corrected_b)
    local got_c = r(corrected_c)
    local got_d = r(corrected_d)
    local got_corr = r(corrected)
    foreach s in a b c d {
        _expect_from_xval, name("mis_do_`s'") using("`xval'")
        local exp_`s' = r(value)
    }
    _expect_from_xval, name("mis_do_or") using("`xval'")
    local exp_or = r(value)
    _assert_close `got_a' `exp_a' 0.000001
    _assert_close `got_b' `exp_b' 0.000001
    _assert_close `got_c' `exp_c' 0.000001
    _assert_close `got_d' `exp_d' 0.000001
    _assert_close `got_corr' `exp_or' 0.000001
}
if _rc == 0 {
    display as result "  PASS: X1.1 Misclassification matches Python oracle"
    local ++pass_count
}
else {
    display as error "  FAIL: X1.1 Misclassification Python oracle (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    qba_misclass, a(90) b(70) c(210) d(630) ///
        seca(.88) spca(.97) secb(.76) spcb(.93) ///
        type(outcome) measure(RR)
    local got_corr = r(corrected)
    _expect_from_xval, name("mis_do_rr") using("`xval'")
    local exp_rr = r(value)
    _assert_close `got_corr' `exp_rr' 0.000001
}
if _rc == 0 {
    display as result "  PASS: X1.2 Misclassification RR matches Python oracle"
    local ++pass_count
}
else {
    display as error "  FAIL: X1.2 Misclassification RR Python oracle (error `=_rc')"
    local ++fail_count
}

* ============================================================
* X2: qba_selection versus Python cell reweighting
* ============================================================

local ++test_count
capture noisily {
    qba_selection, a(7) b(11) c(13) d(17) ///
        sela(1) selb(.25) selc(.5) seld(.8)
    local got_a = r(corrected_a)
    local got_b = r(corrected_b)
    local got_c = r(corrected_c)
    local got_d = r(corrected_d)
    local got_corr = r(corrected)
    local got_bf = r(bias_factor)
    foreach s in a b c d {
        _expect_from_xval, name("sel_`s'") using("`xval'")
        local exp_`s' = r(value)
    }
    _expect_from_xval, name("sel_or") using("`xval'")
    local exp_or = r(value)
    _expect_from_xval, name("sel_sbf") using("`xval'")
    local exp_sbf = r(value)
    _assert_close `got_a' `exp_a' 0.000001
    _assert_close `got_b' `exp_b' 0.000001
    _assert_close `got_c' `exp_c' 0.000001
    _assert_close `got_d' `exp_d' 0.000001
    _assert_close `got_corr' `exp_or' 0.000001
    _assert_close `got_bf' `exp_sbf' 0.000001
}
if _rc == 0 {
    display as result "  PASS: X2.1 Selection OR matches Python oracle"
    local ++pass_count
}
else {
    display as error "  FAIL: X2.1 Selection OR Python oracle (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    qba_selection, a(7) b(11) c(13) d(17) ///
        sela(1) selb(.25) selc(.5) seld(.8) measure(RR)
    local got_corr = r(corrected)
    _expect_from_xval, name("sel_rr") using("`xval'")
    local exp_rr = r(value)
    _assert_close `got_corr' `exp_rr' 0.000001
}
if _rc == 0 {
    display as result "  PASS: X2.2 Selection RR matches Python oracle"
    local ++pass_count
}
else {
    display as error "  FAIL: X2.2 Selection RR Python oracle (error `=_rc')"
    local ++fail_count
}

* ============================================================
* X3: qba_confound versus Python bias-factor calculation
* ============================================================

local ++test_count
capture noisily {
    qba_confound, estimate(2) p1(1) p0(0) rrcd(4)
    local got_hi_bf = r(bias_factor)
    local got_hi_corr = r(corrected)
    _expect_from_xval, name("conf_hi_bf") using("`xval'")
    local exp_bf = r(value)
    _expect_from_xval, name("conf_hi_corr") using("`xval'")
    local exp_corr = r(value)
    _assert_close `got_hi_bf' `exp_bf' 0.000001
    _assert_close `got_hi_corr' `exp_corr' 0.000001

    qba_confound, estimate(2) p1(0) p0(1) rrcd(4)
    local got_lo_bf = r(bias_factor)
    local got_lo_corr = r(corrected)
    _expect_from_xval, name("conf_lo_bf") using("`xval'")
    local exp_bf = r(value)
    _expect_from_xval, name("conf_lo_corr") using("`xval'")
    local exp_corr = r(value)
    _assert_close `got_lo_bf' `exp_bf' 0.000001
    _assert_close `got_lo_corr' `exp_corr' 0.000001
}
if _rc == 0 {
    display as result "  PASS: X3.1 Confounding matches Python oracle"
    local ++pass_count
}
else {
    display as error "  FAIL: X3.1 Confounding Python oracle (error `=_rc')"
    local ++fail_count
}

* ============================================================
* X4: qba_multi versus Python chained correction
* ============================================================

local ++test_count
capture noisily {
    qba_multi, a(90) b(70) c(210) d(630) reps(200) ///
        seca(.88) spca(.97) ///
        sela(.9) selb(.7) selc(.6) seld(.8) ///
        p1(.45) p0(.15) rrcd(2.5) ///
        dist_se("constant .88") dist_sp("constant .97") ///
        dist_sela("constant .9") dist_selb("constant .7") ///
        dist_selc("constant .6") dist_seld("constant .8") ///
        dist_p1("constant .45") dist_p0("constant .15") ///
        dist_rr("constant 2.5") seed(777)
    local got_corr = r(corrected)
    local got_mean = r(mean)
    _expect_from_xval, name("multi_default_or") using("`xval'")
    local exp_or = r(value)
    _assert_close `got_corr' `exp_or' 0.000001
    _assert_close `got_mean' `exp_or' 0.000001

    qba_multi, a(90) b(70) c(210) d(630) reps(200) measure(RR) ///
        seca(.88) spca(.97) ///
        sela(.9) selb(.7) selc(.6) seld(.8) ///
        p1(.45) p0(.15) rrcd(2.5) ///
        dist_se("constant .88") dist_sp("constant .97") ///
        dist_sela("constant .9") dist_selb("constant .7") ///
        dist_selc("constant .6") dist_seld("constant .8") ///
        dist_p1("constant .45") dist_p0("constant .15") ///
        dist_rr("constant 2.5") seed(777)
    local got_rr = r(corrected)
    _expect_from_xval, name("multi_default_rr") using("`xval'")
    local exp_rr = r(value)
    _assert_close `got_rr' `exp_rr' 0.000001

    qba_multi, a(90) b(70) c(210) d(630) reps(200) ///
        seca(.88) spca(.97) ///
        sela(.9) selb(.7) selc(.6) seld(.8) ///
        p1(.45) p0(.15) rrcd(2.5) ///
        dist_se("constant .88") dist_sp("constant .97") ///
        dist_sela("constant .9") dist_selb("constant .7") ///
        dist_selc("constant .6") dist_seld("constant .8") ///
        dist_p1("constant .45") dist_p0("constant .15") ///
        dist_rr("constant 2.5") order(selection misclass) seed(777)
    local got_rev = r(corrected)
    _expect_from_xval, name("multi_reverse_or") using("`xval'")
    local exp_rev = r(value)
    _assert_close `got_rev' `exp_rev' 0.000001

    qba_multi, a(90) b(70) c(210) d(630) reps(200) ///
        seca(.88) spca(.97) secb(.76) spcb(.93) mctype(outcome) ///
        dist_se("constant .88") dist_sp("constant .97") ///
        dist_se1("constant .76") dist_sp1("constant .93") seed(777)
    local got_do_or = r(corrected)
    _expect_from_xval, name("multi_diff_outcome_or") using("`xval'")
    local exp_do_or = r(value)
    _assert_close `got_do_or' `exp_do_or' 0.000001

    qba_multi, a(90) b(70) c(210) d(630) reps(200) measure(RR) ///
        seca(.88) spca(.97) secb(.76) spcb(.93) mctype(outcome) ///
        dist_se("constant .88") dist_sp("constant .97") ///
        dist_se1("constant .76") dist_sp1("constant .93") seed(777)
    local got_do_rr = r(corrected)
    _expect_from_xval, name("multi_diff_outcome_rr") using("`xval'")
    local exp_do_rr = r(value)
    _assert_close `got_do_rr' `exp_do_rr' 0.000001
}
if _rc == 0 {
    display as result "  PASS: X4.1 Multi-bias chains match Python oracle"
    local ++pass_count
}
else {
    display as error "  FAIL: X4.1 Multi-bias Python oracle (error `=_rc')"
    local ++fail_count
}

* ============================================================
* SUMMARY
* ============================================================

display as text ""
display as result "Python cross-validation: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture ado uninstall qba
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
    capture ado uninstall qba
}
