* test_iivw_audit_2026_10_05_bootstrap.do
* Regressions for the 2026-10-05 audit, bootstrap and pooling track (BP-01..05).
*
*   B1  BP-01 pooling refuses edited auxiliary model inputs (offset, exposure,
*       trials, mixed residual by()/t()); unedited data and a constant trial
*       count still pool
*   B2  BP-02 the BCa refusal stays rc198 and no longer blames one shard
*   B3  BP-03 an undefined selected BCa interval refuses (rc498) instead of
*       posting availability 1; finite BCa, omitted terms and citype(none) pass
*   B4  BP-04 compensating row counts across two shard files are refused
*   B5  BP-04 compensating completed/failed stamps are refused; the genuine
*       acknowledged failed-draw pool still works
*   B6  BP-05 a BCa anchor pooled with percentile files carries no BCa surface
*   B7  citype(wald) with a missing model variance completes (note, not 498)
*   B8  margins at counterfactual raw time refused 459; dydx, consistent predict work
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_audit_2026_10_05_bootstrap.do [case#]

clear all
set varabbrev off
version 16.0

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed ""

local qa_dir "`c(pwd)'"
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"

iivw_qa_selector `1'
local run_only = r(run_only)

tempfile _stub
local work "`_stub'_bpwork"
capture mkdir "`work'"
local here "`c(pwd)'"
quietly cd "`work'"

**# B1: auxiliary model inputs are part of the pooling identity
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
capture noisily {
    clear
    set seed 505
    set obs 90
    gen long id = _n
    gen double ui = rnormal()
    expand 4
    bysort id: gen t = _n
    gen double x = rnormal()
    gen double expo = 1 + runiform()
    gen double py = rpoisson(exp(0.3 + 0.2*x)*expo)
    gen double off = rnormal()
    gen double y = 1 + 0.3*x + 0.1*off + rnormal()

    * native offset()
    quietly iivw_fit y x, unweighted id(id) time(t) timespec(none) ///
        geeopts(offset(off)) vce(bootstrap, reps(10) seed(40) fixedweights) ///
        citype(percentile) rngstream(1) saving(b1_off, double replace) nolog
    assert strpos(" `e(iivw_bs_dsig_vars)' ", " off ") > 0
    quietly iivw_bspool using "b1_off.dta", notable
    assert e(iivw_bs_reps_completed) == 10
    quietly iivw_fit y x, unweighted id(id) time(t) timespec(none) ///
        geeopts(offset(off)) vce(bootstrap, reps(10) seed(40) fixedweights) ///
        citype(percentile) rngstream(1) saving(b1_off, double replace) nolog
    replace off = off + 10
    capture iivw_bspool using "b1_off.dta", notable
    assert _rc == 459
    replace off = off - 10

    * exposure()
    quietly iivw_fit py x, unweighted id(id) time(t) timespec(none) ///
        family(poisson) geeopts(exposure(expo)) ///
        vce(bootstrap, reps(10) seed(34) fixedweights) citype(percentile) ///
        rngstream(1) saving(b1_expo, double replace) nolog
    assert strpos(" `e(iivw_bs_dsig_vars)' ", " expo ") > 0
    quietly iivw_bspool using "b1_expo.dta", notable
    quietly iivw_fit py x, unweighted id(id) time(t) timespec(none) ///
        family(poisson) geeopts(exposure(expo)) ///
        vce(bootstrap, reps(10) seed(34) fixedweights) citype(percentile) ///
        rngstream(1) saving(b1_expo, double replace) nolog
    replace expo = 2*expo
    capture iivw_bspool using "b1_expo.dta", notable
    assert _rc == 459
    replace expo = expo/2

    * binomial trials variable
    gen double trials = 10
    gen double by = rbinomial(trials, invlogit(-0.4 + 0.3*x))
    quietly iivw_fit by x, unweighted id(id) time(t) timespec(none) ///
        family(binomial trials) vce(bootstrap, reps(10) seed(35) fixedweights) ///
        citype(percentile) rngstream(2) saving(b1_trials, double replace) nolog
    assert strpos(" `e(iivw_bs_dsig_vars)' ", " trials ") > 0
    quietly iivw_bspool using "b1_trials.dta", notable
    quietly iivw_fit by x, unweighted id(id) time(t) timespec(none) ///
        family(binomial trials) vce(bootstrap, reps(10) seed(35) fixedweights) ///
        citype(percentile) rngstream(2) saving(b1_trials, double replace) nolog
    replace trials = 11
    capture iivw_bspool using "b1_trials.dta", notable
    assert _rc == 459
    replace trials = 10

    * a constant trial count is model specification, not a data column
    quietly iivw_fit by x, unweighted id(id) time(t) timespec(none) ///
        family(binomial 10) vce(bootstrap, reps(10) seed(36) fixedweights) ///
        citype(percentile) rngstream(2) saving(b1_const, double replace) nolog
    quietly iivw_bspool using "b1_const.dta", notable
    assert e(iivw_bs_reps_completed) == 10

    * mixed residuals by() and t()
    gen byte g = mod(id, 2)
    gen double my = 1 + 0.3*x + 0.1*t + ui + rnormal(0, cond(g, 1, 1.5))
    quietly iivw_fit my x, unweighted id(id) time(t) timespec(linear) ///
        model(mixed) mixedopts(residuals(independent, by(g))) ///
        vce(bootstrap, reps(10) seed(36) fixedweights) citype(percentile) ///
        rngstream(3) saving(b1_mby, double replace) nolog
    assert strpos(" `e(iivw_bs_dsig_vars)' ", " g ") > 0
    quietly iivw_bspool using "b1_mby.dta", notable
    quietly iivw_fit my x, unweighted id(id) time(t) timespec(linear) ///
        model(mixed) mixedopts(residuals(independent, by(g))) ///
        vce(bootstrap, reps(10) seed(36) fixedweights) citype(percentile) ///
        rngstream(3) saving(b1_mby, double replace) nolog
    replace g = mod(id, 3) > 0
    capture iivw_bspool using "b1_mby.dta", notable
    assert _rc == 459
    replace g = mod(id, 2)

    * a string by() group fits, pools, and is bound too
    gen str1 gs = cond(g, "a", "b")
    quietly iivw_fit my x, unweighted id(id) time(t) timespec(linear) ///
        model(mixed) mixedopts(residuals(independent, by(gs))) ///
        vce(bootstrap, reps(10) seed(36) fixedweights) citype(percentile) ///
        rngstream(3) saving(b1_ms, double replace) nolog
    quietly iivw_bspool using "b1_ms.dta", notable
    quietly iivw_fit my x, unweighted id(id) time(t) timespec(linear) ///
        model(mixed) mixedopts(residuals(independent, by(gs))) ///
        vce(bootstrap, reps(10) seed(36) fixedweights) citype(percentile) ///
        rngstream(3) saving(b1_ms, double replace) nolog
    replace gs = cond(mod(id, 3) > 0, "a", "b")
    capture iivw_bspool using "b1_ms.dta", notable
    assert _rc == 459
    drop gs

    gen double tc = t
    quietly iivw_fit my x, unweighted id(id) time(t) timespec(linear) ///
        model(mixed) mixedopts(residuals(ar 1, t(tc))) ///
        vce(bootstrap, reps(10) seed(37) fixedweights) citype(percentile) ///
        rngstream(4) saving(b1_mt, double replace) nolog
    assert strpos(" `e(iivw_bs_dsig_vars)' ", " tc ") > 0
    quietly iivw_bspool using "b1_mt.dta", notable
    quietly iivw_fit my x, unweighted id(id) time(t) timespec(linear) ///
        model(mixed) mixedopts(residuals(ar 1, t(tc))) ///
        vce(bootstrap, reps(10) seed(37) fixedweights) citype(percentile) ///
        rngstream(4) saving(b1_mt, double replace) nolog
    replace tc = cond(t == 1, 2, cond(t == 2, 1, t))
    capture iivw_bspool using "b1_mt.dta", notable
    assert _rc == 459
    display as result "B1 PASS: auxiliary model inputs bind the pooling identity"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' B1"
    display as error "B1 FAIL"
}
}

**# B2: BCa refusal rationale
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
capture noisily {
    clear
    set seed 121
    set obs 50
    gen long id = _n
    expand 3
    bysort id: gen t = _n
    gen double x = rnormal()
    gen double y = 1 + 0.3*x + 0.2*t + rnormal()
    quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) ///
        vce(bootstrap, reps(30) seed(43) fixedweights) citype(bca) ///
        rngstream(1) saving(b2_bca, double replace) nolog
    capture iivw_bspool using "b2_bca.dta", notable
    assert _rc == 198
    * the wording lives in the source and the help; neither may call the
    * full-data acceleration a fraction of the evidence
    foreach f in iivw_bspool.ado iivw_bspool.sthlp {
        tempname fh
        file open `fh' using "`pkg_dir'/`f'", read text
        local bad = 0
        file read `fh' line
        while r(eof) == 0 {
            if strpos(`"`macval(line)'"', "fraction of the evidence") | ///
                strpos(`"`macval(line)'"', "which each shard ran") local bad = 1
            file read `fh' line
        }
        file close `fh'
        assert `bad' == 0
    }
    display as result "B2 PASS: BCa still refused rc198; rationale corrected"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' B2"
    display as error "B2 FAIL"
}
}

**# B3: undefined selected BCa intervals refuse
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
capture noisily {
    clear
    set seed 998
    set obs 20
    gen long id = _n
    expand 3
    bysort id: gen t = _n
    gen double x = rnormal()
    gen double y = 1 + x + 0.5*t + rnormal()
    local n498 = 0
    local n0 = 0
    forvalues seed = 1/15 {
        capture quietly iivw_fit y x, unweighted id(id) time(t) ///
            timespec(linear) vce(bootstrap, reps(2) seed(`seed') fixedweights) ///
            citype(bca) nolog
        if _rc == 498 local ++n498
        else if _rc == 0 {
            local ++n0
            * every accepted fit has fully defined endpoints
            tempname cc
            matrix `cc' = e(iivw_ci)
            mata: assert(sum(missing(st_matrix(st_local("cc")))) == 0)
            assert e(iivw_interval_available) == 1
        }
        else exit _rc
    }
    display "  bca reps(2): `n498' refused, `n0' accepted"
    assert `n498' > 0 & `n0' > 0

    * degenerate design: finite b, zero variance, undefined BCa
    clear
    set obs 30
    gen long id = _n
    expand 2
    bysort id: gen t = _n
    gen double y = cond(t == 1, 0, 2)
    capture iivw_fit y, unweighted id(id) time(t) timespec(none) ///
        vce(bootstrap, reps(50) seed(5) fixedweights) citype(bca) nolog
    assert _rc == 498
    * the same design with a defined interval choice still fits
    quietly iivw_fit y, unweighted id(id) time(t) timespec(none) ///
        vce(bootstrap, reps(50) seed(5) fixedweights) citype(percentile) nolog
    assert e(iivw_interval_available) == 1

    * a truly omitted (collinear) coefficient is not an undefined interval
    clear
    set seed 77
    set obs 60
    gen long id = _n
    expand 3
    bysort id: gen t = _n
    gen double x = rnormal()
    gen double xd = x
    gen double y = 1 + 0.5*x + 0.2*t + rnormal()
    quietly iivw_fit y x xd, unweighted id(id) time(t) timespec(linear) ///
        vce(bootstrap, reps(40) seed(9) fixedweights) citype(percentile) nolog
    assert e(iivw_interval_available) == 1
    display as result "B3 PASS: undefined BCa refuses; finite, omitted and none unaffected"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' B3"
    display as error "B3 FAIL"
}
}

**# B4: compensating row counts across files
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
capture noisily {
    clear
    set seed 40
    set obs 60
    gen long id = _n
    expand 3
    bysort id: gen t = _n
    gen double x = rnormal()
    gen double y = 1 + x + 0.5*t + rnormal()
    forvalues stream = 1/2 {
        quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) ///
            vce(bootstrap, reps(30) seed(49) fixedweights) citype(percentile) ///
            rngstream(`stream') saving(b4_a`stream', double replace) nolog
    }
    quietly iivw_bspool using "b4_a1.dta b4_a2.dta", notable
    assert e(iivw_bs_reps_completed) == 60
    * the second fit's e() is the anchor again
    preserve
    use b4_a1, clear
    keep in 1/20
    save b4_short, replace
    use b4_a2, clear
    keep in 1/10
    save b4_dup, replace
    use b4_a2, clear
    append using b4_dup
    save b4_long, replace
    restore
    capture iivw_bspool using "b4_short.dta b4_long.dta", notable
    assert _rc == 459
    * malformed count stamps
    preserve
    use b4_a1, clear
    char _dta[_iivw_shard_reps_requested] "abc"
    save b4_badstamp, replace
    restore
    capture iivw_bspool using "b4_badstamp.dta b4_a2.dta", notable
    assert _rc == 459
    display as result "B4 PASS: compensating row counts are refused per file"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' B4"
    display as error "B4 FAIL"
}
}

**# B5: compensating completed/failed stamps
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
capture noisily {
    clear
    set seed 999
    set obs 8
    gen long id = _n
    expand 4
    bysort id: gen t = _n
    gen byte rare = id == 1
    gen double y = 2 + 3*rare + rnormal()
    forvalues s = 1/2 {
        quietly iivw_fit y rare, unweighted id(id) time(t) timespec(none) ///
            vce(bootstrap, reps(40) seed(64) fixedweights) citype(percentile) ///
            allowfailedreps rngstream(`s') saving(b5_f`s', double replace) nolog
    }
    capture iivw_bspool using "b5_f1.dta b5_f2.dta", notable
    assert _rc == 430
    quietly iivw_bspool using "b5_f1.dta b5_f2.dta", notable allowfailedreps
    assert e(iivw_bs_reps_requested) == 80
    assert e(iivw_bs_reps_completed) + e(iivw_bs_reps_failed) == 80
    assert e(iivw_bs_reps_failed) > 0
    preserve
    use b5_f1, clear
    quietly ds
    local cols "`r(varlist)'"
    egen bad = rowmiss(`cols')
    gen row = _n
    summarize row if bad == 0, meanonly
    local rowa = r(min)
    drop bad row
    foreach v of local cols {
        quietly replace `v' = . in `rowa'
    }
    save b5_bad1, replace
    use b5_f2, clear
    quietly ds
    local cols "`r(varlist)'"
    egen bad = rowmiss(`cols')
    gen row = _n
    summarize row if bad == 0, meanonly
    local rowgood = r(min)
    summarize row if bad > 0, meanonly
    local rowbad = r(min)
    drop bad row
    foreach v of local cols {
        quietly replace `v' = `v'[`rowgood'] in `rowbad'
    }
    save b5_bad2, replace
    restore
    * aggregate totals are unchanged, each file's own stamps are now false
    capture iivw_bspool using "b5_bad1.dta b5_bad2.dta", notable allowfailedreps
    assert _rc == 459
    display as result "B5 PASS: compensating completed/failed stamps are refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' B5"
    display as error "B5 FAIL"
}
}

**# B6: stale BCa surface under a percentile pool
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
capture noisily {
    clear
    set seed 121
    set obs 50
    gen long id = _n
    expand 3
    bysort id: gen t = _n
    gen double x = rnormal()
    gen double y = 1 + 0.3*x + 0.2*t + rnormal()
    quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) ///
        vce(bootstrap, reps(30) seed(43) fixedweights) citype(bca) ///
        rngstream(1) saving(b6_bca, double replace) nolog
    estimates store b6_anchor
    confirm matrix e(ci_bca)
    confirm matrix e(accel)
    confirm matrix e(iivw_ci_bca)
    forvalues s = 1/2 {
        quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) ///
            vce(bootstrap, reps(30) seed(43) fixedweights) citype(percentile) ///
            rngstream(`s') saving(b6_p`s', double replace) nolog
    }
    estimates restore b6_anchor
    quietly iivw_bspool using "b6_p1.dta b6_p2.dta", notable
    assert e(iivw_bs_reps_completed) == 60
    assert "`e(iivw_ci_type)'" == "percentile"
    foreach m in ci_bca accel iivw_ci_bca {
        capture confirm matrix e(`m')
        assert _rc != 0
    }
    capture estat bootstrap, bca
    assert _rc == 198
    capture estat bootstrap, percentile
    assert _rc == 0
    assert e(N_reps) == 60
    display as result "B6 PASS: no BCa surface survives a pooled percentile result"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' B6"
    display as error "B6 FAIL"
}
}

**# B7: Wald interval with a missing model variance is a note, not a refusal
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
capture noisily {
    * the fit_unweighted T8 design: native glm posts a missing SE for an
    * active interaction term
    clear
    set obs 120
    gen int id = ceil(_n / 4)
    bysort id: gen double t = _n - 1
    gen byte trt = mod(id, 2)
    gen double x = mod(id, 5) - 2 + 0.2 * t
    gen byte arm = mod(id, 3) + 1
    gen double y = 2 + 0.5 * x + 0.25 * t + 0.4 * trt + 0.1 * trt * t + sin(id) / 10
    sort id t
    capture noisily iivw_fit y trt arm, unweighted id(id) time(t) ///
        timespec(linear) categorical(arm) interaction(trt arm) citype(wald) nolog
    assert _rc == 0
    assert e(iivw_interval_available) == 1
    display as result "B7 PASS: wald fit with design-dependent interval completes"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' B7"
    display as error "B7 FAIL"
}
}

**# B8: margins at counterfactual raw time is refused; dydx and consistent predict work
local ++test_count
if `run_only' == 0 | `run_only' == 8 {
capture noisily {
    clear
    set seed 3
    set obs 100
    gen long id = _n
    expand 4
    bysort id: gen t = _n
    gen double x = rnormal()
    gen double y = 1 + 0.3*x + 0.1*t + 0.02*t^2 + rnormal()
    quietly iivw_fit y x, unweighted id(id) time(t) timespec(quadratic) nolog
    capture margins, at(t=(1 2))
    assert _rc == 459
    capture margins, at(t=2 _iivw_time_sq=4)
    assert _rc == 459
    capture margins, dydx(x)
    assert _rc == 0
    preserve
    replace t = 2
    replace _iivw_time_sq = 4
    capture predict double xb2
    assert _rc == 0
    restore
    display as result "B8 PASS: counterfactual margins refused, workaround and dydx work"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' B8"
    display as error "B8 FAIL"
}
}

quietly cd "`here'"
iivw_qa_summary, name(test_iivw_audit_2026_10_05_bootstrap) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') runonly(`run_only') ///
    failedtests("`failed'")
