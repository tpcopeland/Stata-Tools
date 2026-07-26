* test_qba_fml2023.do -- 1.1.0 alignment with Fox/MacLehose/Lash 2023 and
* VanderWeele/Ding 2017 Table 2
* Package: qba
*
* Run against 1.0.1 this suite scores 3/16: I1 Z1 Z2 T1 C1 C2 S1 E1 E2 E3 R1
* D2 V1 all fail there, which is the evidence that they discriminate.
*
* The three that pass on 1.0.1 do so vacuously and are honest about it:
*   T2, S2  assert that a bad option value is REJECTED, and 1.0.1 rejects the
*           option outright because it does not have it. They discriminate on
*           1.1.0 (guard present vs guard missing); the options existing at all
*           is proved by T1/D2/S1.
*   D1      locks pre-existing saved-dataset behaviour that 1.1.0 documents for
*           the first time. It is a documentation lock, not a bug fix.

clear all
version 16.0

capture do "_qba_qa_common.do"
if _rc {
    do "qa/_qba_qa_common.do"
}

_qba_qa_bootstrap, isolated
local orig_plus `"`r(orig_plus)'"'
local orig_personal `"`r(orig_personal)'"'
local plusdir `"`r(plusdir)'"'
local personaldir `"`r(personaldir)'"'
local pkg_dir `"`r(pkg_dir)'"'

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* _qba_qa_assert_close takes (actual expected tolerance) and silently drops a
* label argument, so failures name no test. Wrap it to keep the label.
capture program drop _qba_fml_close
program define _qba_fml_close
    args actual expected tolerance label
    if missing(`actual') {
        display as error "`label': actual is missing"
        exit 9
    }
    if abs(`actual' - `expected') > `tolerance' {
        display as error "`label': expected " %21.12g `expected' ///
            ", got " %21.12g `actual' ///
            " (diff " %21.12g abs(`actual' - `expected') ///
            ", tol " %21.12g `tolerance' ")"
        exit 9
    }
end

**# I1: MC output is labelled a simulation interval, not a CI

local ++test_count
capture noisily {
    tempfile lg
    log using "`lg'", replace text name(qbafml)
    qba_misclass, a(80) b(120) c(200) d(600) seca(.85) spca(.95) reps(200) seed(1)
    local mis_interval "`r(interval)'"
    qba_selection, a(80) b(120) c(200) d(600) sela(.8) selb(.9) selc(.7) ///
        seld(.95) reps(200) seed(2)
    local sel_interval "`r(interval)'"
    qba_confound, estimate(2) p1(.4) p0(.2) rrcd(2) reps(200) seed(3)
    local conf_interval "`r(interval)'"
    qba_multi, a(80) b(120) c(200) d(600) reps(200) seed(4) seca(.85) spca(.95)
    local multi_interval "`r(interval)'"
    * log close resets r(), so every r() read above happens first.
    log close qbafml

    * Every probabilistic arm must name the interval, in output and in r().
    _assert_file_contains "`lg'" "simulation interval"
    _assert_file_contains "`lg'" "systematic error only"
    _assert_text_file_not_contains "`lg'" "% CI:"
    foreach m in mis sel conf multi {
        if "``m'_interval'" != "systematic-error simulation interval" {
            display as error "r(interval) for `m' is ``m'_interval'"
            exit 9
        }
    }
}
if _rc {
    local ++fail_count
    local failed_tests "`failed_tests' I1"
    display as error "  FAIL: I1 simulation-interval labelling (error `=_rc')"
}
else {
    local ++pass_count
    display as result "  PASS: I1 simulation-interval labelling"
}

**# Z1: simple mode treats a corrected cell of exactly 0 as incompatible
* Fails on 1.0.1: with a_corr exactly 0 the old "< 0" screen let the table
* through and reported a corrected OR of 0.0000 with ratio 0.0000, as if it
* were a valid result. Verified against 1.0.1: r(corrected) came back as 0.

local ++test_count
capture noisily {
    tempfile lg0
    log using "`lg0'", replace text name(qbaz1)
    * 1 - Sp = 0.5 and Se + Sp - 1 = 0.25 are both exact in binary, so
    * a_corr = (100 - 0.5*200)/0.25 is exactly 0. (With a non-dyadic Sp the
    * same construction lands on ~5e-15 instead, which no screen can catch.)
    qba_misclass, a(100) b(100) c(300) d(200) seca(.75) spca(.5)
    local got_a = r(corrected_a)
    local got_corrected = r(corrected)
    log close qbaz1

    if `got_a' != 0 {
        display as error "fixture no longer produces a_corr == 0: `got_a'"
        exit 9
    }
    if !missing(`got_corrected') {
        display as error "corrected OR should be missing on a zero cell; got `got_corrected'"
        exit 9
    }
    _assert_file_contains "`lg0'" "are not positive"
}
if _rc {
    local ++fail_count
    local failed_tests "`failed_tests' Z1"
    display as error "  FAIL: Z1 simple-mode zero-cell handling (error `=_rc')"
}
else {
    local ++pass_count
    display as result "  PASS: Z1 simple-mode zero-cell handling"
}

**# Z2: probabilistic mode discards a zero-cell replicate even when the
* measure stays finite and positive.
* Fails on 1.0.1: an exactly-zero c_corr with measure(RR) leaves the measure
* finite and positive, so neither the "< 0" cell screen nor the "_result <= 0"
* screen caught it. Verified against 1.0.1: it reported "Median: 6.0000,
* 95% CI: 6.0000 - 6.0000" over 200/200 "valid" replicates.

local ++test_count
capture noisily {
    * c_corr = (250 - 0.5*500)/0.25 = 0 exactly, while a_corr = 200 and
    * d_corr = 500, so the corrected RR is 6.0 -- finite and positive. 1.0.1
    * reported that as 200/200 valid replicates.
    capture qba_misclass, a(200) b(100) c(250) d(250) seca(.75) spca(.5) ///
        measure(RR) reps(200) seed(5) ///
        dist_se("constant .75") dist_sp("constant .5")
    local zrc = _rc
    if `zrc' != 198 {
        display as error "expected rc=198 (all replicates invalid); got `zrc'"
        exit 9
    }
}
if _rc {
    local ++fail_count
    local failed_tests "`failed_tests' Z2"
    display as error "  FAIL: Z2 probabilistic zero-cell discard (error `=_rc')"
}
else {
    local ++pass_count
    display as result "  PASS: Z2 probabilistic zero-cell discard"
}

**# T1: totalerror reports three arms and the total interval is the widest

local ++test_count
capture noisily {
    qba_misclass, a(215) b(1449) c(668) d(4296) seca(.78) spca(.99) ///
        measure(RR) reps(20000) seed(11) ///
        dist_se("beta 50.6 14.3") dist_sp("beta 70 1") totalerror

    foreach s in te_median te_mean te_sd te_lower te_upper n_valid_te ///
        re_median re_lower re_upper {
        if missing(r(`s')) {
            display as error "r(`s') is missing"
            exit 9
        }
    }
    local w_syst = r(ci_upper) / r(ci_lower)
    local w_rand = r(re_upper) / r(re_lower)
    local w_tot  = r(te_upper) / r(te_lower)
    * Total error compounds systematic and random error, so its interval must
    * be wider than either component interval.
    if !(`w_tot' > `w_syst' & `w_tot' > `w_rand') {
        display as error "total width `w_tot' not wider than syst `w_syst' / rand `w_rand'"
        exit 9
    }
    * The random-error arm is centred on the OBSERVED measure, the systematic
    * and total arms on the bias-adjusted one. Assert the ordering rather than
    * a loose absolute tolerance: with tol 0.02 these fixtures would still pass
    * if the random-error arm were silently wired to the systematic numbers.
    * Referenced literally as well as through the loop above: the coverage
    * checker greps for r(name) and cannot see r(`s').
    if r(te_mean) <= 0 | r(te_sd) <= 0 {
        display as error "r(te_mean)/r(te_sd) are not positive"
        exit 9
    }
    local obs = r(observed)
    local re_md = r(re_median)
    local sy_md = r(corrected)
    local te_md = r(te_median)
    if abs(`re_md' - `obs') >= abs(`sy_md' - `obs') {
        display as error "random-error median `re_md' is not nearer the observed " ///
            "`obs' than the systematic median `sy_md' is"
        exit 9
    }
    if abs(`te_md' - `sy_md') >= abs(`te_md' - `obs') {
        display as error "total-error median `te_md' is not nearer the systematic " ///
            "`sy_md' than the observed `obs'"
        exit 9
    }
}
if _rc {
    local ++fail_count
    local failed_tests "`failed_tests' T1"
    display as error "  FAIL: T1 totalerror three arms (error `=_rc')"
}
else {
    local ++pass_count
    display as result "  PASS: T1 totalerror three arms"
}

**# T2: totalerror negative paths

local ++test_count
capture noisily {
    * requires reps()
    capture qba_misclass, a(10) b(20) c(30) d(40) seca(.9) spca(.98) totalerror
    if _rc != 198 {
        display as error "totalerror without reps() should exit 198; got `=_rc'"
        exit 9
    }
    * requires whole counts: the binomial reallocation moves counts
    capture qba_misclass, a(10.5) b(20) c(30) d(40) seca(.9) spca(.98) ///
        reps(200) totalerror
    if _rc != 198 {
        display as error "totalerror on a fractional cell should exit 198; got `=_rc'"
        exit 9
    }
    * requires every cell > 0: Beta(0, .) and rbinomial(0, .) are undefined
    capture qba_misclass, a(0) b(20) c(30) d(40) seca(.9) spca(.98) ///
        reps(200) totalerror
    if _rc != 198 {
        display as error "totalerror on an empty cell should exit 198; got `=_rc'"
        exit 9
    }
    * a fractional cell created BY the sampling fractions is caught too
    capture qba_misclass, a(10) b(20) c(30) d(40) type(outcome) ///
        seca(.9) spca(.98) fctrl(.7) reps(200) totalerror
    if _rc != 198 {
        display as error "totalerror on a fractional inflated cell should exit 198; got `=_rc'"
        exit 9
    }
}
if _rc {
    local ++fail_count
    local failed_tests "`failed_tests' T2"
    display as error "  FAIL: T2 totalerror guards (error `=_rc')"
}
else {
    local ++pass_count
    display as result "  PASS: T2 totalerror guards"
}

**# C1: corr() induces the requested dependence and leaves marginals intact

local ++test_count
capture noisily {
    tempfile dcorr dindep

    qba_misclass, a(215) b(1449) c(668) d(4296) seca(.78) spca(.99) ///
        secb(.75) spcb(.98) measure(RR) reps(20000) seed(21) ///
        dist_se("beta 50.6 14.3") dist_sp("beta 70 1") ///
        dist_se1("beta 50.6 14.3") dist_sp1("beta 70 1") ///
        corr(0.8) saving("`dcorr'", replace)
    if r(corr) != 0.8 {
        display as error "r(corr) is " r(corr)
        exit 9
    }

    qba_misclass, a(215) b(1449) c(668) d(4296) seca(.78) spca(.99) ///
        secb(.75) spcb(.98) measure(RR) reps(20000) seed(21) ///
        dist_se("beta 50.6 14.3") dist_sp("beta 70 1") ///
        dist_se1("beta 50.6 14.3") dist_sp1("beta 70 1") ///
        saving("`dindep'", replace)

    use "`dcorr'", clear
    quietly correlate se se1
    local rho_se = r(rho)
    quietly correlate sp sp1
    local rho_sp = r(rho)
    quietly correlate se sp
    local rho_cross = r(rho)
    quietly summarize se
    local mean_corr = r(mean)
    local sd_corr = r(sd)

    * Se has a near-symmetric Beta marginal, so a Gaussian copula transfers
    * the target correlation almost exactly.
    _qba_fml_close `rho_se' 0.80 0.02 "corr(se, se1)"
    * Sp is Beta(70, 1), heavily skewed: the realized Pearson correlation is
    * attenuated but must still be strongly positive.
    if `rho_sp' < 0.6 | `rho_sp' > 0.8 {
        display as error "corr(sp, sp1) = `rho_sp', expected in [0.6, 0.8]"
        exit 9
    }
    * Se and Sp get independent copula pairs and must stay uncorrelated.
    if abs(`rho_cross') > 0.05 {
        display as error "corr(se, sp) = `rho_cross', expected ~0"
        exit 9
    }

    use "`dindep'", clear
    quietly correlate se se1
    if abs(r(rho)) > 0.05 {
        display as error "corr(0) left corr(se, se1) = " r(rho)
        exit 9
    }
    quietly summarize se
    * Copula dependence must not move the marginal: Beta(50.6, 14.3) has
    * mean 50.6/64.9 = 0.779661 and sd = sqrt(ab/((a+b)^2(a+b+1))) = 0.050944.
    _qba_fml_close `mean_corr' 0.779661 0.005 "se marginal mean under corr()"
    _qba_fml_close `sd_corr' 0.050944 0.005 "se marginal sd under corr()"
    _qba_fml_close `mean_corr' `=r(mean)' 0.005 "se mean corr vs independent"
}
if _rc {
    local ++fail_count
    local failed_tests "`failed_tests' C1"
    display as error "  FAIL: C1 correlated Se/Sp draws (error `=_rc')"
}
else {
    local ++pass_count
    display as result "  PASS: C1 correlated Se/Sp draws"
}

**# C2: corr() guards, on qba_misclass and qba_multi alike

local ++test_count
capture noisily {
    * nondifferential has one Se and one Sp: nothing to correlate
    capture qba_misclass, a(80) b(120) c(200) d(600) seca(.85) spca(.95) ///
        reps(200) corr(0.5)
    if _rc != 198 {
        display as error "corr() without differential mode should exit 198; got `=_rc'"
        exit 9
    }
    capture qba_misclass, a(80) b(120) c(200) d(600) seca(.85) spca(.95) ///
        secb(.8) spcb(.9) reps(200) corr(1.5)
    if _rc != 198 {
        display as error "corr(1.5) should exit 198; got `=_rc'"
        exit 9
    }
    capture qba_misclass, a(80) b(120) c(200) d(600) seca(.85) spca(.95) ///
        secb(.8) spcb(.9) corr(0.5)
    if _rc != 198 {
        display as error "corr() without reps() should exit 198; got `=_rc'"
        exit 9
    }
    capture qba_multi, a(80) b(120) c(200) d(600) reps(200) ///
        seca(.85) spca(.95) corr(0.5)
    if _rc != 198 {
        display as error "qba_multi corr() without differential should exit 198; got `=_rc'"
        exit 9
    }
    capture qba_multi, a(80) b(120) c(200) d(600) reps(200) ///
        seca(.85) spca(.95) secb(.8) spcb(.9) corr(-2)
    if _rc != 198 {
        display as error "qba_multi corr(-2) should exit 198; got `=_rc'"
        exit 9
    }
    * and it works where it is allowed
    qba_multi, a(215) b(1449) c(668) d(4296) reps(2000) seed(22) ///
        seca(.78) spca(.99) secb(.75) spcb(.98) ///
        dist_se("beta 50.6 14.3") dist_sp("beta 70 1") ///
        dist_se1("beta 50.6 14.3") dist_sp1("beta 70 1") corr(0.8)
    if r(corr) != 0.8 {
        display as error "qba_multi r(corr) is " r(corr)
        exit 9
    }
}
if _rc {
    local ++fail_count
    local failed_tests "`failed_tests' C2"
    display as error "  FAIL: C2 corr() guards (error `=_rc')"
}
else {
    local ++pass_count
    display as result "  PASS: C2 corr() guards"
}

**# S1: fcase()/fctrl() inflate the sampled table to the source population

local ++test_count
capture noisily {
    * Observed OR is invariant to the inflation (both rows scale), the RR is
    * not -- that is the whole point of restoring the source population.
    qba_misclass, a(387) b(1642) c(685) d(3365) type(outcome) measure(OR) ///
        seca(.92) spca(.98) fcase(1) fctrl(.1)
    local or_cc = r(observed)
    _qba_fml_close `=r(adj_c)' 6850 1e-6 "r(adj_c)"
    _qba_fml_close `=r(adj_d)' 33650 1e-6 "r(adj_d)"
    _qba_fml_close `=r(adj_a)' 387 1e-6 "r(adj_a)"
    _qba_fml_close `=r(a)' 387 1e-6 "r(a) stays the supplied cell"
    _qba_fml_close `=r(c)' 685 1e-6 "r(c) stays the supplied cell"
    if r(fctrl) != 0.1 | r(fcase) != 1 {
        display as error "r(fcase)=" r(fcase) " r(fctrl)=" r(fctrl)
        exit 9
    }

    qba_misclass, a(387) b(1642) c(685) d(3365) type(outcome) measure(OR) ///
        seca(.92) spca(.98)
    _qba_fml_close `or_cc' `=r(observed)' 1e-9 "observed OR invariant to sampling fractions"

    * The corrected measure must differ: the correction runs on a different
    * table.
    qba_misclass, a(387) b(1642) c(685) d(3365) type(outcome) measure(OR) ///
        seca(.92) spca(.98) fctrl(.1)
    local corr_cc = r(corrected)
    qba_misclass, a(387) b(1642) c(685) d(3365) type(outcome) measure(OR) ///
        seca(.92) spca(.98)
    if abs(`corr_cc' - r(corrected)) < 0.01 {
        display as error "fctrl() did not change the corrected OR: `corr_cc' vs " r(corrected)
        exit 9
    }
}
if _rc {
    local ++fail_count
    local failed_tests "`failed_tests' S1"
    display as error "  FAIL: S1 case-control sampling fractions (error `=_rc')"
}
else {
    local ++pass_count
    display as result "  PASS: S1 case-control sampling fractions"
}

**# S2: fcase()/fctrl() guards

local ++test_count
capture noisily {
    * exposure misclassification is corrected within complete outcome rows
    capture qba_misclass, a(387) b(1642) c(685) d(3365) seca(.92) spca(.98) ///
        fctrl(.1)
    if _rc != 198 {
        display as error "fctrl() with type(exposure) should exit 198; got `=_rc'"
        exit 9
    }
    foreach bad in 0 -0.5 1.5 {
        capture qba_misclass, a(387) b(1642) c(685) d(3365) type(outcome) ///
            seca(.92) spca(.98) fcase(`bad')
        if _rc != 198 {
            display as error "fcase(`bad') should exit 198; got `=_rc'"
            exit 9
        }
    }
}
if _rc {
    local ++fail_count
    local failed_tests "`failed_tests' S2"
    display as error "  FAIL: S2 sampling-fraction guards (error `=_rc')"
}
else {
    local ++pass_count
    display as result "  PASS: S2 sampling-fraction guards"
}

**# E1: VanderWeele-Ding Table 2 conversions, hand-computed

local ++test_count
capture noisily {
    * Rare outcome (default) is unchanged from 1.0.1: Table 1 applied directly.
    qba_confound, estimate(1.5) measure(OR) evalue ci_bound(1.1)
    _qba_fml_close `=r(evalue)' 2.3660254 1e-6 "rare-outcome OR E-value"
    _qba_fml_close `=r(evalue_ci)' 1.4316625 1e-6 "rare-outcome OR E-value (CI)"
    _qba_fml_close `=r(evalue_rr)' 1.5 1e-9 "rare-outcome r(evalue_rr)"
    if "`r(evalue_conv)'" != "none" {
        display as error "r(evalue_conv) is `r(evalue_conv)'"
        exit 9
    }

    * Common outcome, OR: RR ~ sqrt(OR) = 1.2247449, E = RR + sqrt(RR(RR-1))
    qba_confound, estimate(1.5) measure(OR) evalue ci_bound(1.1) commonoutcome
    _qba_fml_close `=r(evalue_rr)' 1.2247449 1e-6 "sqrt(OR)"
    _qba_fml_close `=r(evalue)' 1.7493925 1e-6 "common-outcome OR E-value"
    * The CI limit gets the same conversion: sqrt(1.1) = 1.0488088
    _qba_fml_close `=r(evalue_ci)' 1.2750635 1e-6 "common-outcome OR E-value (CI)"
    if "`r(evalue_conv)'" != "sqrtor" {
        display as error "r(evalue_conv) is `r(evalue_conv)'"
        exit 9
    }

    * Common outcome, HR: RR ~ (1-0.5^sqrt(HR))/(1-0.5^sqrt(1/HR))
    qba_confound, estimate(1.5) measure(HR) evalue ci_bound(1.1) commonoutcome
    _qba_fml_close `=r(evalue_rr)' 1.3238135 1e-6 "common-outcome HR conversion"
    _qba_fml_close `=r(evalue)' 1.9785414 1e-6 "common-outcome HR E-value"
    if "`r(evalue_conv)'" != "hrcommon" {
        display as error "r(evalue_conv) is `r(evalue_conv)'"
        exit 9
    }

    * The HR transform satisfies f(1/x) = 1/f(x), so a protective HR of the
    * reciprocal magnitude yields the same E-value.
    qba_confound, estimate(`=1/1.5') measure(HR) evalue commonoutcome
    _qba_fml_close `=r(evalue)' 1.9785414 1e-5 "protective HR E-value symmetry"

    * A rate ratio enters directly at any prevalence; commonoutcome is a no-op.
    qba_confound, estimate(1.5) measure(IRR) evalue commonoutcome
    _qba_fml_close `=r(evalue_rr)' 1.5 1e-9 "IRR needs no conversion"
    if "`r(evalue_conv)'" != "none" {
        display as error "IRR r(evalue_conv) is `r(evalue_conv)'"
        exit 9
    }
}
if _rc {
    local ++fail_count
    local failed_tests "`failed_tests' E1"
    display as error "  FAIL: E1 Table 2 E-value conversions (error `=_rc')"
}
else {
    local ++pass_count
    display as result "  PASS: E1 Table 2 E-value conversions"
}

**# E2: the E-value scale is always stated, and no unsourced robustness grade
* Fails on 1.0.1: it printed "A relatively weak confounder could explain the
* effect." / "A moderately strong confounder would be needed." / "A strong
* confounder would be needed." -- thresholds with no basis in the source.

local ++test_count
capture noisily {
    tempfile lge
    log using "`lge'", replace text name(qbae2)
    qba_confound, estimate(1.5) measure(OR) evalue ci_bound(1.1)
    qba_confound, estimate(1.5) measure(OR) evalue ci_bound(1.1) commonoutcome
    qba_confound, estimate(1.5) measure(HR) evalue commonoutcome
    qba_confound, estimate(1.5) measure(RR) evalue commonoutcome
    log close qbae2

    _assert_text_file_not_contains "`lge'" "relatively weak confounder"
    _assert_text_file_not_contains "`lge'" "moderately strong confounder"
    _assert_text_file_not_contains "`lge'" "A strong confounder would be needed"
    _assert_file_contains "`lge'" "Table 3"
    * the rare-outcome caveat and both conversions are named in output
    _assert_file_contains "`lge'" "rare outcome (<15% by end of follow-up)"
    _assert_file_contains "`lge'" "RR = sqrt(OR)"
    _assert_file_contains "`lge'" "RR = (1-0.5^sqrt(HR))/(1-0.5^sqrt(1/HR))"
    * commonoutcome on an RR reports that it did nothing
    _assert_file_contains "`lge'" "commonoutcome has no effect"
}
if _rc {
    local ++fail_count
    local failed_tests "`failed_tests' E2"
    display as error "  FAIL: E2 E-value scale disclosure (error `=_rc')"
}
else {
    local ++pass_count
    display as result "  PASS: E2 E-value scale disclosure"
}

**# E3: measure() and commonoutcome guards

local ++test_count
capture noisily {
    capture qba_confound, estimate(1.5) measure(SHR) evalue
    if _rc != 198 {
        display as error "measure(SHR) should exit 198; got `=_rc'"
        exit 9
    }
    capture qba_confound, estimate(1.5) measure(OR) p1(.4) p0(.2) rrcd(2) commonoutcome
    if _rc != 198 {
        display as error "commonoutcome without evalue should exit 198; got `=_rc'"
        exit 9
    }
    * HR and IRR are corrected by the same bias factor as RR
    qba_confound, estimate(1.5) measure(HR) p1(.4) p0(.2) rrcd(2)
    local hr_corrected = r(corrected)
    if "`r(measure)'" != "HR" {
        display as error "r(measure) is `r(measure)'"
        exit 9
    }
    qba_confound, estimate(1.5) measure(RR) p1(.4) p0(.2) rrcd(2)
    _qba_fml_close `hr_corrected' `=r(corrected)' 1e-12 "HR corrected == RR corrected"
}
if _rc {
    local ++fail_count
    local failed_tests "`failed_tests' E3"
    display as error "  FAIL: E3 measure()/commonoutcome guards (error `=_rc')"
}
else {
    local ++pass_count
    display as result "  PASS: E3 measure()/commonoutcome guards"
}

**# R1: the reps() floor no longer claims 100 gives stable results

local ++test_count
capture noisily {
    tempfile lgr
    log using "`lgr'", replace text name(qbar1)
    capture noisily qba_misclass, a(80) b(120) c(200) d(600) seca(.85) spca(.95) reps(50)
    capture noisily qba_selection, a(80) b(120) c(200) d(600) sela(.8) selb(.9) ///
        selc(.7) seld(.95) reps(50)
    capture noisily qba_confound, estimate(2) p1(.4) p0(.2) rrcd(2) reps(50)
    capture noisily qba_multi, a(80) b(120) c(200) d(600) reps(50) seca(.85) spca(.95)
    log close qbar1

    _assert_text_file_not_contains "`lgr'" "at least 100 for stable results"
    _assert_file_contains "`lgr'" "must be at least 100"
    _assert_file_contains "`lgr'" "not a stability guarantee"
}
if _rc {
    local ++fail_count
    local failed_tests "`failed_tests' R1"
    display as error "  FAIL: R1 reps() floor messaging (error `=_rc')"
}
else {
    local ++pass_count
    display as result "  PASS: R1 reps() floor messaging"
}

**# D1: a saved MC dataset keeps invalid replications as missing rows

local ++test_count
capture noisily {
    tempfile dsave
    * A wide Sp distribution straddling the Se+Sp>1 boundary guarantees both
    * valid and invalid replications.
    qba_misclass, a(80) b(120) c(200) d(600) seca(.55) spca(.95) ///
        reps(2000) seed(31) dist_se("constant .55") ///
        dist_sp("uniform .30 .95") saving("`dsave'", replace)
    local n_valid = r(n_valid)
    local reps = r(reps)
    if `n_valid' >= `reps' | `n_valid' == 0 {
        display as error "fixture needs a partial invalid rate; got `n_valid'/`reps'"
        exit 9
    }
    use "`dsave'", clear
    if _N != `reps' {
        display as error "saved dataset has _N = " _N " for reps = `reps'"
        exit 9
    }
    quietly count if !missing(corrected_or)
    if r(N) != `n_valid' {
        display as error "nonmissing rows " r(N) " != r(n_valid) `n_valid'"
        exit 9
    }
}
if _rc {
    local ++fail_count
    local failed_tests "`failed_tests' D1"
    display as error "  FAIL: D1 saved-dataset invalid rows (error `=_rc')"
}
else {
    local ++pass_count
    display as result "  PASS: D1 saved-dataset invalid rows"
}

**# D2: totalerror saved schema

local ++test_count
capture noisily {
    tempfile dte
    qba_misclass, a(215) b(1449) c(668) d(4296) seca(.78) spca(.99) ///
        measure(RR) reps(500) seed(32) ///
        dist_se("beta 50.6 14.3") dist_sp("beta 70 1") totalerror ///
        saving("`dte'", replace)
    use "`dte'", clear
    foreach v in se sp a_corr b_corr c_corr d_corr corrected_rr ///
        a_realloc b_realloc c_realloc d_realloc ///
        reclass_rr total_rr random_rr {
        confirm variable `v'
    }
    assert _N == 500
    * The reallocated cells are counts drawn from the observed margins.
    quietly count if !missing(a_realloc) & a_realloc != round(a_realloc)
    if r(N) > 0 {
        display as error "a_realloc has " r(N) " non-integer values"
        exit 9
    }
    quietly count if !missing(a_realloc) & abs(a_realloc + b_realloc - 1664) > 1e-6
    if r(N) > 0 {
        display as error "reallocated case row does not sum to a + b = 1664"
        exit 9
    }
}
if _rc {
    local ++fail_count
    local failed_tests "`failed_tests' D2"
    display as error "  FAIL: D2 totalerror saved schema (error `=_rc')"
}
else {
    local ++pass_count
    display as result "  PASS: D2 totalerror saved schema"
}

**# V1: the displayed/returned package version is read from the .ado header

local ++test_count
capture noisily {
    tempname fh
    file open `fh' using "`pkg_dir'/qba.ado", read text
    file read `fh' hdrline
    file close `fh'
    if !regexm(`"`hdrline'"', "Version ([0-9]+\.[0-9]+\.[0-9]+)") {
        display as error "could not parse the version from the qba.ado header"
        exit 9
    }
    local hdr_ver = regexs(1)

    quietly qba
    if "`r(version)'" != "`hdr_ver'" {
        display as error "r(version) `r(version)' != qba.ado header `hdr_ver'"
        exit 9
    }
    * No .ado may carry a hardcoded version literal that can drift.
    foreach f in qba qba_misclass qba_selection qba_confound qba_multi qba_plot {
        _assert_text_file_not_contains "`pkg_dir'/`f'.ado" `"return local version "1."'
    }
}
if _rc {
    local ++fail_count
    local failed_tests "`failed_tests' V1"
    display as error "  FAIL: V1 version read from header (error `=_rc')"
}
else {
    local ++pass_count
    display as result "  PASS: V1 version read from header"
}

**# Summary

display as text ""
display as result "FML2023 alignment: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_qba_fml2023 tests=`test_count' pass=`pass_count' fail=`fail_count'"

local rc = 0
if `fail_count' > 0 {
    display as error "FAILED TESTS: `failed_tests'"
    local rc = 1
}

_qba_qa_restore_isolation, origplus("`orig_plus'") ///
    origpersonal("`orig_personal'") plusdir("`plusdir'") ///
    personaldir("`personaldir'") uninstall

if `rc' exit `rc'
display as result "ALL TESTS PASSED"
