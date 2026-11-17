* test_qba_review_regressions.do -- regressions for the 2026-11 external review (v1.2.1)
* Package: qba (Quantitative Bias Analysis)
* Usage: cd qba/qa && stata-mp -b do test_qba_review_regressions.do
*
* One block per confirmed defect. Each block asserts the value or the exact
* refusal (rc and message) the fixed code produces; every block fails on the
* v1.2.0 code, where the defect returned rc=0 with a wrong or silently
* ignored result, or refused a valid input.

clear all
set linesize 255

* === Bootstrap ===
capture do "_qba_qa_common.do"
if _rc {
    do "qa/_qba_qa_common.do"
}
_qba_qa_bootstrap
local qa_dir `"`r(qa_dir)'"'
local pkg_dir `"`r(pkg_dir)'"'

local test_count = 0
local pass_count = 0
local fail_count = 0

* _rr_expect <rc> "<message fragment>" : <command>
* Runs the command, asserts its exact return code, and asserts the console
* output contains the message fragment (the specific domain message, not a
* generic one).
capture program drop _rr_expect
program define _rr_expect
    gettoken want 0 : 0
    gettoken msg 0 : 0
    gettoken colon 0 : 0, parse(":")
    tempfile lg
    quietly log using `"`lg'"', text name(_rr_msg) replace
    capture noisily `0'
    local got = _rc
    quietly log close _rr_msg
    if `got' != `want' {
        display as error "expected rc `want', got `got'"
        exit 9
    }
    _qba_qa_assert_file_contains using `"`lg'"', pattern(`"`msg'"')
end

* _rr_svg_y <file> <label>: y coordinate of the SVG text element whose
* content is exactly <label>
capture program drop _rr_svg_y
program define _rr_svg_y, rclass
    args file label
    tempname fh
    local y = .
    file open `fh' using `"`file'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `">`label'<"') {
            if regexm(`"`macval(line)'"', `"y="([-0-9.]+)""') local y = regexs(1)
        }
        file read `fh' line
    }
    file close `fh'
    return scalar y = `y'
end

* Mock tmle estimator contract: e(cmd)=tmle with e(tau), e(ci_lo), e(ci_hi)
capture program drop _rr_mock_tmle
program define _rr_mock_tmle, eclass
    args tau lo hi meas
    ereturn clear
    tempname b
    matrix `b' = (1)
    ereturn post `b'
    ereturn local cmd "tmle"
    ereturn scalar tau = `tau'
    ereturn scalar se = .1
    ereturn scalar ci_lo = `lo'
    ereturn scalar ci_hi = `hi'
    ereturn local measure "`meas'"
end

tempfile scratch
local dir "`scratch'_rr"
capture mkdir "`dir'"

**# R1 (finding 1): explicit -999/-1 are values, not "omitted"
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    local b_w = _b[weight]
    * confeffect(-999) is a valid signed effect: Schneeweiss (2006) eq. (1b)
    * gives corrected = b - (p1 - p0) * confeffect = b - .2 * (-999)
    qba_confound, from_model coef(weight) p1(.3) p0(.1) confeffect(-999)
    assert !missing(r(corrected))
    assert !missing(r(corrected)) & !missing(`b_w' - (.3 - .1) * (-999)) & reldif(r(corrected), `b_w' - (.3 - .1) * (-999)) < 1e-12
    assert r(confeffect) == -999
    * explicit out-of-domain values meet their own domain checks
    _rr_expect 198 "rrud() must be > 0" : qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2) rrud(-1)
    _rr_expect 198 "specify rrcd() or rrud(), not both" : qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2) rrud(3)
    _rr_expect 198 "rrud() must be > 0" : qba_confound, estimate(1.5) p1(.4) p0(.2) rrud(-1)
    _rr_expect 198 "ci_bound() must be > 0" : qba_confound, estimate(1.5) evalue ci_bound(-999)
    _rr_expect 198 "estimate() must be > 0" : qba_confound, estimate(-999) p1(.4) p0(.2) rrcd(2)
    _rr_expect 198 "p1() must be in [0, 1]" : qba_confound, estimate(1.5) p1(-1) p0(.2) rrcd(2)
    _rr_expect 198 "secb() must be in (0, 1]" : qba_misclass, a(10) b(20) c(30) d(40) seca(.9) spca(.9) secb(-1)
    _rr_expect 198 "seca() must be in (0, 1]" : qba_multi, a(10) b(20) c(30) d(40) reps(100) seca(-1) spca(-1) p1(.4) p0(.2) rrcd(2) seed(1)
    _rr_expect 198 "sela() must be in (0, 1]" : qba_multi, a(10) b(20) c(30) d(40) reps(100) sela(-1) selb(-1) selc(-1) seld(-1) p1(.4) p0(.2) rrcd(2) seed(1)
}
if _rc == 0 {
    display as result "  PASS: R1 explicit sentinel values are validated, not ignored"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 sentinel collisions (error `=_rc')"
    local ++fail_count
}

**# R2 (finding 1, lead 4): explicit estimate() wins over an active contract
local ++test_count
capture noisily {
    _rr_mock_tmle .5 .3 .8 OR
    _rr_expect 198 "estimate() must be > 0" : qba_confound, estimate(-999) p1(.4) p0(.2) rrcd(2)
    _rr_mock_tmle .5 .3 .8 OR
    qba_confound, estimate(2) p1(.4) p0(.2) rrcd(2)
    assert r(observed) == 2
    assert "`r(source)'" == ""
    ereturn clear
}
if _rc == 0 {
    display as result "  PASS: R2 explicit estimate() is never replaced by e(tau)"
    local ++pass_count
}
else {
    display as error "  FAIL: R2 explicit estimate vs contract (error `=_rc')"
    local ++fail_count
}

**# R3 (finding 1, lead 4): seed() presence and domain
local ++test_count
capture noisily {
    _rr_expect 198 "seed() must be an integer between 0 and 2147483647" : qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2) seed(-1)
    _rr_expect 198 "seed() must be an integer between 0 and 2147483647" : qba_selection, a(10) b(20) c(30) d(40) sela(.9) selb(.8) selc(.7) seld(.6) seed(-1)
    _rr_expect 198 "seed() must be an integer between 0 and 2147483647" : qba_misclass, a(10) b(20) c(30) d(40) seca(.9) spca(.9) reps(100) seed(-2)
    _rr_expect 198 "seed() must be an integer between 0 and 2147483647" : qba_multi, a(10) b(20) c(30) d(40) reps(100) p1(.4) p0(.2) rrcd(2) seed(-2)
    _rr_expect 198 "seed() requires reps()" : qba_selection, a(10) b(20) c(30) d(40) sela(.9) selb(.8) selc(.7) seld(.6) seed(0)
    * seed(0) is in the domain and is actually applied: two runs agree, and
    * a different seed gives different draws
    qba_selection, a(10) b(20) c(30) d(40) sela(.9) selb(.8) selc(.7) seld(.6) ///
        reps(200) dist_sela("uniform .5 1") seed(0)
    local m0 = r(mean)
    qba_selection, a(10) b(20) c(30) d(40) sela(.9) selb(.8) selc(.7) seld(.6) ///
        reps(200) dist_sela("uniform .5 1") seed(0)
    assert !missing(`m0') & r(mean) == `m0'
    qba_selection, a(10) b(20) c(30) d(40) sela(.9) selb(.8) selc(.7) seld(.6) ///
        reps(200) dist_sela("uniform .5 1") seed(1)
    assert !missing(r(mean)) & r(mean) != `m0'
}
if _rc == 0 {
    display as result "  PASS: R3 seed() presence and domain"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 seed handling (error `=_rc')"
    local ++fail_count
}

**# R4 (finding 2): from_model CI equals the model's own r(table) interval
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    matrix T = r(table)
    local ll = T[rownumb(T, "ll"), colnumb(T, "weight")]
    local ul = T[rownumb(T, "ul"), colnumb(T, "weight")]
    assert e(df_r) == 71
    qba_confound, from_model coef(weight) p1(.3) p0(.1) confeffect(500)
    assert !missing(r(ci_lower)) & !missing(r(ci_upper))
    assert !missing(r(ci_lower)) & !missing(`ll') & reldif(r(ci_lower), `ll') < 1e-13
    assert !missing(r(ci_upper)) & !missing(`ul') & reldif(r(ci_upper), `ul') < 1e-13
    * a model without e(df_r) keeps the normal critical value: logistic's
    * own r(table) reports exp(b -/+ z*se)
    quietly logistic foreign mpg
    matrix T = r(table)
    local ll = T[rownumb(T, "ll"), colnumb(T, "mpg")]
    local ul = T[rownumb(T, "ul"), colnumb(T, "mpg")]
    qba_confound, from_model coef(mpg) p1(.3) p0(.1) rrcd(2)
    assert !missing(r(ci_lower)) & !missing(r(ci_upper))
    assert !missing(r(ci_lower)) & !missing(`ll') & reldif(r(ci_lower), `ll') < 1e-12
    assert !missing(r(ci_upper)) & !missing(`ul') & reldif(r(ci_upper), `ul') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: R4 from_model CI matches r(table) (t after regress)"
    local ++pass_count
}
else {
    display as error "  FAIL: R4 from_model CI (error `=_rc')"
    local ++fail_count
}

**# R4b (finding 2, round 2): small coefficients whose %21x carrier ends in d/e
* A %21x literal such as 1.398e2d61bc024X-00d followed by "-" was re-lexed as
* decimal exponent notation (rc 111). Each model's own r(table) is the oracle:
* exp(ll), exp(ul) on log-scale models, ll, ul after regress.
capture program drop _rr_ci_vs_table
program define _rr_ci_vs_table
    args coef scale
    tempname T
    matrix `T' = r(table)
    local ll = `T'[rownumb(`T', "ll"), colnumb(`T', "`coef'")]
    local ul = `T'[rownumb(`T', "ul"), colnumb(`T', "`coef'")]
    if "`scale'" == "log" {
        local ll = exp(`ll')
        local ul = exp(`ul')
    }
    if "`scale'" == "log" {
        qba_confound, from_model coef(`coef') p1(.3) p0(.1) rrcd(2) evalue
    }
    else {
        qba_confound, from_model coef(`coef') p1(.3) p0(.1) confeffect(1)
    }
    assert !missing(r(ci_lower)) & !missing(`ll') & reldif(r(ci_lower), `ll') < 1e-12
    assert !missing(r(ci_upper)) & !missing(`ul') & reldif(r(ci_upper), `ul') < 1e-12
end
local ++test_count
capture noisily {
    sysuse auto, clear
    gen double pk = price / 1e4
    quietly regress pk weight
    _rr_ci_vs_table weight linear
    quietly glm price weight, family(poisson) link(log) vce(robust)
    _rr_ci_vs_table weight log
    quietly nbreg price weight
    _rr_ci_vs_table weight log
    quietly logit foreign weight
    _rr_ci_vs_table weight log
    quietly clogit foreign weight, group(rep78)
    _rr_ci_vs_table weight log
}
if _rc == 0 {
    display as result "  PASS: R4b small coefficients: regress (t), glm/nbreg/logit/clogit (z)"
    local ++pass_count
}
else {
    display as error "  FAIL: R4b small coefficients (error `=_rc')"
    local ++fail_count
}

**# R4c (finding 2, round 2): seeded sweep of 200 coefficients over 1e-6..10
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 20261117
    local n_ok = 0
    forvalues k = 1/200 {
        * log-uniform scale; regress for odd k (t), logit for even k (z)
        local s = 10^(-6 + 7 * runiform())
        quietly {
            capture drop yk xk
            if mod(`k', 2) {
                gen double yk = price * `s' / 2
                regress yk weight
            }
            else {
                gen double xk = weight / (`s' * 1000)
                logit foreign xk
            }
        }
        if mod(`k', 2) quietly _rr_ci_vs_table weight linear
        else quietly _rr_ci_vs_table xk log
        local ++n_ok
    }
    assert `n_ok' == 200
}
if _rc == 0 {
    display as result "  PASS: R4c 200 seeded coefficients: rc=0 and CI equals r(table)"
    local ++pass_count
}
else {
    display as error "  FAIL: R4c coefficient sweep (error `=_rc')"
    local ++fail_count
}

**# R18 (round 2): cell counts 8192-32767 (carrier exponent X+00d/X+00e)
local ++test_count
capture noisily {
    * Greenland (1996) eq. (10) and eq. (5)-(6) evaluated here in closed form
    local a 10000
    local b 2000
    local c 5000
    local d 30000
    qba_selection, a(`a') b(`b') c(`c') d(`d') sela(.9) selb(.8) selc(.7) seld(.6)
    local sel_or = ((`a'/.9) * (`d'/.6)) / ((`b'/.8) * (`c'/.7))
    assert !missing(r(corrected)) & !missing(`sel_or') & reldif(r(corrected), `sel_or') < 1e-12
    qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(.9) spca(.95)
    local ac = (`a' - .05 * (`a' + `b')) / .85
    local cc = (`c' - .05 * (`c' + `d')) / .85
    local mc_or = (`ac' * (`c' + `d' - `cc')) / ((`a' + `b' - `ac') * `cc')
    assert !missing(r(corrected)) & !missing(`mc_or') & reldif(r(corrected), `mc_or') < 1e-12
    qba_multi, a(`a') b(`b') c(`c') d(`d') sela(.9) selb(.8) selc(.7) seld(.6) ///
        reps(100) seed(1)
    assert !missing(r(corrected)) & r(n_valid) == 100 & !missing(`sel_or') & reldif(r(corrected), `sel_or') < 1e-12
    qba_confound, estimate(.0002) p1(.4) p0(.2) rrcd(2) evalue
    assert !missing(r(corrected)) & reldif(r(corrected), .0002 / (1.4 / 1.2)) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: R18 cells and estimates in the d/e-exponent band"
    local ++pass_count
}
else {
    display as error "  FAIL: R18 d/e-exponent band (error `=_rc')"
    local ++fail_count
}

**# R5 (finding 8): linear from_model measure() contract
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    local b_w = _b[weight]
    _rr_expect 198 "reports a linear coefficient; specify measure(coefficient) or omit measure()" : qba_confound, from_model coef(weight) p1(.3) p0(.1) confeffect(500) measure(OR)
    qba_confound, from_model coef(weight) p1(.3) p0(.1) confeffect(500) measure(coefficient)
    assert "`r(measure)'" == "coefficient"
    assert !missing(r(corrected)) & !missing(`b_w' - .2 * 500) & reldif(r(corrected), `b_w' - .2 * 500) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: R5 linear measure() refuses ratio labels, accepts coefficient"
    local ++pass_count
}
else {
    display as error "  FAIL: R5 linear measure() (error `=_rc')"
    local ++fail_count
}

**# R6 (finding 9): ratio contract CI must be positive before E-value inversion
local ++test_count
capture noisily {
    * The invalid interval is unavailable, not fatal: the point E-value runs
    * (RR = 1/0.5 = 2, E = 2 + sqrt(2 * 1), Table 1) and no CI E-value or
    * contract CI is posted.
    _rr_mock_tmle .5 -.5 -.1 OR
    _rr_expect 0 "contract CI is not used" : qba_confound, evalue
    _rr_mock_tmle .5 -.5 -.1 OR
    qba_confound, evalue
    assert !missing(r(evalue)) & !missing(2 + sqrt(2)) & reldif(r(evalue), 2 + sqrt(2)) < 1e-12
    assert missing(r(evalue_ci)) & missing(r(ci_lower)) & missing(r(ci_upper))
    _rr_mock_tmle .5 . -.1 OR
    qba_confound, evalue
    assert missing(r(evalue_ci)) & !missing(r(evalue))
    * a plain correction under such a contract still runs: 1.5 / (1.4 / 1.2)
    _rr_mock_tmle 1.5 -.5 2.5 OR
    qba_confound, p1(.4) p0(.2) rrcd(2)
    assert !missing(r(corrected)) & reldif(r(corrected), 1.5 / (1.4 / 1.2)) < 1e-12
    assert missing(r(ci_lower))
    * A coherent contract still works. E-value of the limit nearest the null
    * (VanderWeele & Ding 2017, Table 1): RR = 1/0.8 = 1.25, so
    * E = 1.25 + sqrt(1.25 * 0.25) computed here in closed form.
    _rr_mock_tmle .5 .3 .8 OR
    qba_confound, evalue
    assert !missing(r(evalue_ci))
    assert !missing(r(evalue_ci)) & !missing(1.25 + sqrt(1.25 * .25)) & reldif(r(evalue_ci), 1.25 + sqrt(1.25 * .25)) < 1e-12
    ereturn clear
}
if _rc == 0 {
    display as result "  PASS: R6 nonpositive ratio contract CI treated as unavailable"
    local ++pass_count
}
else {
    display as error "  FAIL: R6 contract CI domain (error `=_rc')"
    local ++fail_count
}

**# R7 (finding 3): totalerror saving() masks reclass_* with the replicate filter
local ++test_count
capture noisily {
    local te "`dir'/te_mask.dta"
    * this seed yields a replicate whose reallocated a cell is 0 (reclass_or
    * = 0) while corrected_or and total_or are masked; v1.2.0 kept the 0
    qba_misclass, a(215) b(1449) c(668) d(4296) seca(.78) spca(.99) reps(200) ///
        dist_se("uniform 0.2 0.9") dist_sp("uniform 0.5 0.99") totalerror ///
        seed(12345) saving("`te'", replace)
    local nv = r(n_valid)
    preserve
    use "`te'", clear
    * the fixture must contain invalid replicates, or the test is vacuous
    quietly count if missing(corrected_or)
    assert !missing(r(N)) & r(N) > 0 & r(N) < _N
    * reclass_or is defined exactly on the replicates the summaries use
    quietly count if missing(corrected_or) & !missing(reclass_or)
    assert r(N) == 0
    quietly count if missing(reclass_or) != missing(total_or)
    assert r(N) == 0
    quietly count if !missing(reclass_or)
    assert r(N) == `nv'
    restore
}
if _rc == 0 {
    display as result "  PASS: R7 reclass_or masked on invalid replicates"
    local ++pass_count
}
else {
    display as error "  FAIL: R7 reclass mask (error `=_rc')"
    local ++fail_count
}

**# R8 (finding 4): r(dist_se)/r(dist_sp) report user-scale text
local ++test_count
capture noisily {
    qba_misclass, a(100) b(200) c(50) d(300) seca(.85) spca(.95) reps(100) seed(1)
    assert `"`r(dist_se)'"' == "constant .85"
    assert `"`r(dist_sp)'"' == "constant .95"
    assert !strpos(`"`r(dist_se)'"', "X") & !strpos(`"`r(dist_sp)'"', "X")
    qba_misclass, a(100) b(200) c(50) d(300) seca(.85) spca(.95) reps(100) ///
        dist_se("uniform .8 .9") seed(1)
    assert `"`r(dist_se)'"' == "uniform .8 .9"
    assert `"`r(dist_sp)'"' == "constant .95"
}
if _rc == 0 {
    display as result "  PASS: R8 dist labels are not %21x hex"
    local ++pass_count
}
else {
    display as error "  FAIL: R8 dist labels (error `=_rc')"
    local ++fail_count
}

**# R9 (finding 5): compound-quoted saving() specifications
local ++test_count
capture noisily {
    capture mkdir "`dir'/sub dir"
    local f1 "`dir'/sub dir/cq1.dta"
    capture erase "`f1'"
    qba_selection, a(10) b(20) c(30) d(40) sela(.9) selb(.8) selc(.7) seld(.6) ///
        reps(100) seed(1) saving(`"`f1'"', replace)
    preserve
    use "`f1'", clear
    assert _N == 100
    confirm variable corrected_or
    restore
    local f2 "`dir'/sub dir/cq2, comma.dta"
    capture erase "`f2'"
    qba_selection, a(10) b(20) c(30) d(40) sela(.9) selb(.8) selc(.7) seld(.6) ///
        reps(100) seed(1) saving(`""`f2'""', replace)
    preserve
    use "`f2'", clear
    assert _N == 100
    restore
    _qba_parse_saving, saving(`"`f2'"', replace)
    assert `"`r(filename)'"' == `"`f2'"'
    assert "`r(replace)'" == "replace"
    * one wrapper around filename AND option is reparsed
    _qba_parse_saving, saving(`""`f2'", replace"')
    assert `"`r(filename)'"' == `"`f2'"'
    assert "`r(replace)'" == "replace"
    * a quote left inside the name is refused, not written to a mangled path
    _rr_expect 198 "filename contains a double-quote character" : _qba_parse_saving, saving(`"`f2'", replace"')
}
if _rc == 0 {
    display as result "  PASS: R9 compound-quoted saving() parsed"
    local ++pass_count
}
else {
    display as error "  FAIL: R9 saving parser (error `=_rc')"
    local ++fail_count
}

**# R10 (finding 6): selection zero cells agree across simple and probabilistic
local ++test_count
capture noisily {
    qba_selection, a(0) b(20) c(30) d(40) sela(.9) selb(.8) selc(.7) seld(.6)
    assert r(corrected) == 0
    qba_selection, a(0) b(20) c(30) d(40) sela(.9) selb(.8) selc(.7) seld(.6) ///
        reps(100) seed(1)
    assert r(n_valid) == 100
    assert r(corrected) == 0 & r(ci_lower) == 0 & r(ci_upper) == 0
    qba_selection, a(10) b(20) c(30) d(0) sela(.9) selb(.8) selc(.7) seld(.6) ///
        reps(100) seed(1) measure(RR)
    assert !missing(r(corrected)) & r(n_valid) == 100
    * qba_multi without misclassification follows the same policy
    qba_multi, a(0) b(20) c(30) d(40) sela(.9) selb(.8) selc(.7) seld(.6) ///
        reps(100) seed(1)
    assert r(n_valid) == 100 & r(corrected) == 0
    qba_multi, a(0) b(20) c(30) d(40) p1(.4) p0(.2) rrcd(2) reps(100) seed(1)
    assert r(n_valid) == 100 & r(corrected) == 0
    * ...while misclassification keeps its zero-cell screen (as qba_misclass)
    _rr_expect 198 "all Monte Carlo replicates produced invalid results" : qba_multi, a(0) b(20) c(30) d(40) seca(.9) spca(.9) reps(100) seed(1)
    * an undefined observed OR is undefined on every replicate
    _rr_expect 198 "observed OR is undefined" : qba_selection, a(10) b(0) c(30) d(40) sela(.9) selb(.8) selc(.7) seld(.6) reps(100) seed(1)
    _rr_expect 198 "observed RR is undefined" : qba_selection, a(10) b(0) c(30) d(40) sela(.9) selb(.8) selc(.7) seld(.6) reps(100) seed(1) measure(RR)
    * a defined observed measure with only out-of-support draws keeps the
    * generic refusal on both measures (the undefined-measure note must not
    * reference a measure that was never computed)
    _rr_expect 198 "all Monte Carlo replicates produced invalid results" : qba_selection, a(20) b(40) c(60) d(120) sela(.8) selb(.6) selc(.7) seld(.9) reps(100) dist_sela("constant 0")
    _rr_expect 198 "all Monte Carlo replicates produced invalid results" : qba_selection, a(20) b(40) c(60) d(120) sela(.8) selb(.6) selc(.7) seld(.9) reps(100) dist_sela("constant 0") measure(RR)
}
if _rc == 0 {
    display as result "  PASS: R10 selection zero-cell policy is route-consistent"
    local ++pass_count
}
else {
    display as error "  FAIL: R10 selection zero cells (error `=_rc')"
    local ++fail_count
}

**# R11 (finding 7): qba_plot refuses options of another plot type
local ++test_count
capture noisily {
    local mc "`dir'/mc.dta"
    quietly qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95) ///
        reps(200) dist_se("uniform .8 .9") seed(1) saving("`mc'", replace)
    _rr_expect 198 "not allowed with distribution plots" : qba_plot, distribution using("`mc'") observed(2.0) a(10) b(20) c(30) d(40)
    _rr_expect 198 "steps()" : qba_plot, distribution using("`mc'") observed(2.0) steps(5)
    _rr_expect 198 "base_se()" : qba_plot, distribution using("`mc'") observed(2.0) base_se(.8)
    _rr_expect 198 "not allowed with tornado plots" : qba_plot, tornado a(136) b(297) c(1432) d(6738) param1(se) range1(.7 1) using("nonexistent.dta") observed(2.0)
    _rr_expect 198 "base_sela()" : qba_plot, tipping a(136) b(297) c(1432) d(6738) param1(se) range1(.7 1) param2(sp) range2(.9 1) base_sela(.5)
    * the routes themselves still run
    qba_plot, distribution using("`mc'") observed(2.0)
    assert "`r(plot_type)'" == "distribution"
    qba_plot, tornado a(136) b(297) c(1432) d(6738) param1(sela) range1(.5 1) base_selb(.9) steps(5)
    assert "`r(plot_type)'" == "tornado" & r(n_missing) == 0
}
if _rc == 0 {
    display as result "  PASS: R11 off-route plot options refused"
    local ++pass_count
}
else {
    display as error "  FAIL: R11 off-route options (error `=_rc')"
    local ++fail_count
}

**# R12 (finding 1): qba_plot explicit observed(-999), null(), base_rrud(), cells
local ++test_count
capture noisily {
    * observed(-999) is a valid value on the coefficient scale
    preserve
    sysuse auto, clear
    quietly regress price mpg weight
    local mcl "`dir'/mc_lin.dta"
    quietly qba_confound, from_model coef(weight) p1(.3) p0(.1) confeffect(500) ///
        reps(100) seed(1) saving("`mcl'", replace)
    restore
    qba_plot, distribution using("`mcl'") observed(-999)
    assert "`r(plot_type)'" == "distribution" & "`r(measure)'" == "coefficient"
    * ...but not on the OR scale, where it now meets its domain check
    local mc "`dir'/mc.dta"
    _rr_expect 198 "must be > 0 for an OR distribution plot" : qba_plot, distribution using("`mc'") observed(-999)
    _rr_expect 198 "null() must be > 0 for OR/RR plots" : qba_plot, tornado a(136) b(297) c(1432) d(6738) param1(p1) range1(0 .5) null(-999)
    _rr_expect 198 "base_rrud() must be > 0" : qba_plot, tornado a(136) b(297) c(1432) d(6738) param1(p1) range1(0 .5) base_rrud(-1)
    _rr_expect 198 "cell counts must be non-negative" : qba_plot, tornado a(-1) b(297) c(1432) d(6738) param1(p1) range1(0 .5)
    _rr_expect 198 "plot requires a() b() c() d()" : qba_plot, tornado b(297) c(1432) d(6738) param1(p1) range1(0 .5)
    * an explicit null() is drawn where given
    local svg "`dir'/null.svg"
    capture erase "`svg'"
    qba_plot, tornado a(136) b(297) c(1432) d(6738) param1(p1) range1(0 .5) ///
        null(2) steps(5) saving("`svg'") replace
    _qba_qa_assert_file_contains using "`svg'", pattern(">Null (2.00)<")
}
if _rc == 0 {
    display as result "  PASS: R12 qba_plot explicit sentinel values"
    local ++pass_count
}
else {
    display as error "  FAIL: R12 qba_plot sentinels (error `=_rc')"
    local ++fail_count
}

**# R13 (finding 10): tipping refuses an undefined observed measure
local ++test_count
capture noisily {
    _rr_expect 198 "observed OR is undefined for these cells" : qba_plot, tipping a(10) b(0) c(20) d(30) param1(se) range1(.7 1) param2(sp) range2(.8 1) steps(5)
    _rr_expect 198 "observed RR is undefined for these cells" : qba_plot, tipping a(10) b(0) c(20) d(30) measure(RR) param1(se) range1(.7 1) param2(sp) range2(.8 1) steps(5)
    qba_plot, tipping a(10) b(5) c(20) d(30) param1(se) range1(.7 1) param2(sp) range2(.8 1) steps(5)
    assert "`r(plot_type)'" == "tipping" & !missing(r(n_missing))
}
if _rc == 0 {
    display as result "  PASS: R13 tipping requires a defined observed measure"
    local ++pass_count
}
else {
    display as error "  FAIL: R13 tipping undefined observed (error `=_rc')"
    local ++fail_count
}

**# R14 (finding 15): quote in using() filename reaches the 198 message
local ++test_count
capture noisily {
    preserve
    sysuse auto, clear
    keep price mpg
    local plain "`dir'/plain.dta"
    quietly save "`plain'", replace
    restore
    local q = char(34)
    local badname `"`dir'/bad`q'quote.dta"'
    copy "`plain'" `"`badname'"', replace
    _rr_expect 198 "no supported corrected result variable found" : qba_plot, distribution using(`"`badname'"') observed(1.5)
    * the refusal is about content, and the fixture really lacks the variable
    preserve
    use `"`badname'"', clear
    assert _N == 74
    capture confirm variable corrected_or
    assert _rc == 111
    restore
    capture erase `"`badname'"'
}
if _rc == 0 {
    display as result "  PASS: R14 quoted using() path in error messages"
    local ++pass_count
}
else {
    display as error "  FAIL: R14 using() message quoting (error `=_rc')"
    local ++fail_count
}

**# R15 (finding 16): mctype() without misclassification is refused
local ++test_count
capture noisily {
    _rr_expect 198 "mctype() requires seca() and spca()" : qba_multi, a(10) b(20) c(30) d(40) reps(100) p1(.4) p0(.2) rrcd(2) mctype(outcome) seed(1)
    qba_multi, a(136) b(297) c(1432) d(6738) reps(100) seca(.85) spca(.99) mctype(outcome) seed(1)
    assert r(n_biases) == 1 & !missing(r(corrected))
}
if _rc == 0 {
    display as result "  PASS: R15 qba_multi mctype() needs misclassification"
    local ++pass_count
}
else {
    display as error "  FAIL: R15 mctype (error `=_rc')"
    local ++fail_count
}

**# R16 (leads 1-2): tornado reference labels and rrcd/rrud sweep
local ++test_count
capture noisily {
    * observed OR = 1 = null: the two labels must not share coordinates
    local svg "`dir'/l1.svg"
    capture erase "`svg'"
    qba_plot, tornado a(10) b(10) c(10) d(10) param1(p1) range1(0 .5) ///
        steps(5) saving("`svg'") replace
    _rr_svg_y "`svg'" "Null (1.00)"
    local y_null = r(y)
    _rr_svg_y "`svg'" "Observed OR (1.00)"
    local y_obs = r(y)
    assert !missing(`y_null') & !missing(`y_obs')
    assert abs(`y_null' - `y_obs') > 50
    * rrcd and rrud are one parameter: sweeping both is refused
    _rr_expect 198 "duplicate parameter" : qba_plot, tornado a(136) b(297) c(1432) d(6738) param1(rrcd) range1(1 3) param2(rrud) range2(1 3)
}
if _rc == 0 {
    display as result "  PASS: R16 tornado labels separated; rrcd+rrud refused"
    local ++pass_count
}
else {
    display as error "  FAIL: R16 tornado labels / rrud (error `=_rc')"
    local ++fail_count
}

**# R17 (lead 3): a missing draw is flagged even with no finite upper bound
local ++test_count
capture noisily {
    preserve
    clear
    set obs 5
    gen double u = cond(_n == 1, 0, .5)
    * logit-normal at u = 0 is invlogit(invnormal(0)) = missing
    _qba_draw_checked, dist("logit-normal 0 1") gen(x) n(5) invalid(bad) ///
        u(u) lower(0) loweropen
    assert r(n_invalid) == 1
    assert missing(x[1]) & bad[1] == 1
    assert bad[2] == 0
    restore
}
if _rc == 0 {
    display as result "  PASS: R17 missing draws counted as invalid"
    local ++pass_count
}
else {
    display as error "  FAIL: R17 missing draw flag (error `=_rc')"
    local ++fail_count
}

capture shell rm -rf "`dir'"
display as result "review regression results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture ado uninstall qba
    display "RESULT: test_qba_review_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

capture ado uninstall qba
display "RESULT: test_qba_review_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
