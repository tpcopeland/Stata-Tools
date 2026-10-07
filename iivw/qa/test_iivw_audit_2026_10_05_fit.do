* test_iivw_audit_2026_10_05_fit.do
* Regressions for the 2026-10-05 audit, fit and inference track (FIT-F01..F12).
*
*   A1  F01 grouped-binomial trials missing: N, e(sample), clusters match the design
*   A2  F01 mixed panel id missing under cluster(): N, e(sample), clusters match
*   A3  F01/F07 mixed residuals(by()/t()) missing values leave the sample
*   A4  F02 intercept-only vce(stacked) fits and names a 1x1 _cons covariance
*   A5  F03 vce(stacked) with geeopts(noconstant) fits a slope-only design
*   A6  F04 family()/link() are refused with model(mixed); omitted defaults fit
*   A7  F05 vce(stacked) e(chi2)/e(p)/e(df_m) are computed from the posted e(V)
*   A8  F06 grouped binomial with constant successes but varying trials fits
*   A9  F07 replace never overwrites an auxiliary input (offset/exposure/trials/by/t)
*   A10 F08 literal sentinel values are refused; integer formats still parse
*   A11 F09 an edited raw source refuses predict; if/in, restore and new rows work
*   A12 F09 sibling generated designs (categorical time, ns, interaction, categorical)
*   A13 F10 mixed reffects/residuals/fitted equal native mixed; e(cmd) restored
*   A14 F11 native mixed estat runs; public e(cmd)/e(estat_cmd) restored
*   A15 F12 point-only xb keeps the offset()/exposure() term
*
* Every population oracle is built from the fixture design (which rows carry a
* missing auxiliary), or from a separately fitted native glm/mixed, never from
* the package's own marker.
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_audit_2026_10_05_fit.do [case#]

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

* 100 subjects x 4 visits, the audit's fit fixture.
capture program drop _afit_base
program define _afit_base
    version 16.0
    clear
    set seed 15783
    quietly set obs 400
    gen long id = ceil(_n/4)
    bysort id: gen double t = _n - 1
    gen double x = rnormal()
    gen byte a = mod(id, 2)
    gen double z = sin(id)
    gen double y = 2 + .7*x + .4*a + .1*t + rnormal()
    gen long clinic = id
end

* The same panel with estimated IPTW weights and nuisance scores.
capture program drop _afit_iptw
program define _afit_iptw
    version 16.0
    _afit_base
    quietly iivw_weight, id(id) time(t) wtype(iptw) treat(a) treat_cov(z) ///
        scores nolog
end

**# A1: F01 grouped-binomial trials missing

* Native glm drops rows whose trial count is missing. The pre-fit marker did
* not, so the point-only repost reported 400 rows and 100 clusters for an
* outcome equation fitted on 320 rows and 80 subjects.
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
capture noisily {
    foreach pattern in whole partial {
        foreach route in "citype(none)" "vce(fixed)" {
            _afit_base
            gen int trials = 10
            gen byte ys = rbinomial(trials, invlogit(.2 + .3*x))
            if "`pattern'" == "whole" quietly replace trials = . if id <= 20
            else quietly replace trials = . if t == 0 & id <= 100 & mod(id, 4) == 0
            gen byte design = !missing(trials)
            quietly count if design
            local n_design = r(N)
            tempvar tag
            egen `tag' = tag(id) if design
            quietly count if `tag' == 1
            local c_design = r(N)
            drop `tag'
            quietly iivw_fit ys x, unweighted id(id) timespec(none) ///
                family(binomial trials) `route' nolog
            quietly count if e(sample)
            local n_sample = r(N)
            quietly count if e(sample) != design
            local mism = r(N)
            display as text "  `pattern' `route': N=" e(N) " sample=`n_sample'" ///
                " clusters=" e(iivw_outcome_nclust) " design=`n_design'/`c_design'"
            assert e(N) == `n_design'
            assert `n_sample' == `n_design'
            assert `mism' == 0
            assert e(iivw_outcome_nclust) == `c_design'
        }
    }
    display as result "A1 PASS: grouped-binomial exclusions reach e(N), e(sample) and clusters"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A1"
    display as error "A1 FAIL"
}
}

**# A2: F01 mixed panel id missing under cluster()

local ++test_count
if `run_only' == 0 | `run_only' == 2 {
capture noisily {
    foreach route in "citype(none)" "vce(fixed)" {
        _afit_base
        quietly replace id = . if clinic <= 20
        quietly replace id = . if clinic > 20 & t == 3 & mod(clinic, 5) == 0
        gen byte design = !missing(id)
        quietly count if design
        local n_design = r(N)
        tempvar tag
        egen `tag' = tag(clinic) if design
        quietly count if `tag' == 1
        local c_design = r(N)
        drop `tag'
        quietly iivw_fit y x, model(mixed) unweighted id(id) cluster(clinic) ///
            timespec(none) `route' nolog
        quietly count if e(sample)
        local n_sample = r(N)
        quietly count if e(sample) != design
        local mism = r(N)
        display as text "  `route': N=" e(N) " sample=`n_sample' clusters=" ///
            e(iivw_outcome_nclust) " design=`n_design'/`c_design'"
        assert e(N) == `n_design'
        assert `n_sample' == `n_design'
        assert `mism' == 0
        assert e(iivw_outcome_nclust) == `c_design'
    }
    display as result "A2 PASS: mixed grouping-variable exclusions reach e(sample)"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A2"
    display as error "A2 FAIL"
}
}

**# A3: F01/F07 mixed residuals(by()/t()) sources missing

local ++test_count
if `run_only' == 0 | `run_only' == 3 {
capture noisily {
    foreach spec in by time {
        foreach route in "citype(none)" "vce(fixed)" {
            _afit_base
            gen byte g = mod(id, 2)
            gen double tt = t
            if "`spec'" == "by" {
                quietly replace g = . if id <= 15
                local mo "residuals(independent, by(g))"
                gen byte design = !missing(g)
            }
            else {
                quietly replace tt = . if id <= 15
                local mo "residuals(ar 1, t(tt))"
                gen byte design = !missing(tt)
            }
            quietly count if design
            local n_design = r(N)
            quietly iivw_fit y x, model(mixed) unweighted id(id) timespec(none) ///
                mixedopts(`mo') `route' nolog
            quietly count if e(sample)
            local n_sample = r(N)
            quietly count if e(sample) != design
            local mism = r(N)
            display as text "  `spec' `route': N=" e(N) " sample=`n_sample'" ///
                " clusters=" e(iivw_outcome_nclust) " design=`n_design'"
            assert e(N) == `n_design'
            assert `n_sample' == `n_design'
            assert `mism' == 0
            assert e(iivw_outcome_nclust) == 85
        }
    }
    display as result "A3 PASS: mixed residual by()/t() exclusions reach e(sample)"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A3"
    display as error "A3 FAIL"
}
}

**# A4: F02 intercept-only vce(stacked)

local ++test_count
if `run_only' == 0 | `run_only' == 4 {
capture noisily {
    _afit_iptw
    local w "`: char _dta[_iivw_weight_var]'"
    if "`w'" == "" local w "_iivw_weight"
    confirm numeric variable `w'
    quietly glm y [pw=`w'], vce(cluster id)
    local b_nat = _b[_cons]
    local v_nat = _se[_cons]^2
    capture noisily iivw_fit y, timespec(none) vce(stacked) nolog
    local rc = _rc
    display as text "  intercept-only stacked rc = `rc'"
    assert `rc' == 0
    assert "`e(vce)'" == "stacked"
    local cn : colnames e(V)
    assert "`cn'" == "_cons"
    assert colsof(e(V)) == 1
    assert !missing(_b[_cons], `b_nat')
    assert reldif(_b[_cons], `b_nat') < 1e-10
    assert e(iivw_stacked_selfcheck) < 1e-8
    assert e(V)[1,1] > 0 & !missing(e(V)[1,1])
    display as text "  fixed V " %12.6g `v_nat' "  stacked V " %12.6g e(V)[1,1]
    display as result "A4 PASS: intercept-only stacked fit posts a 1x1 _cons covariance"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A4"
    display as error "A4 FAIL"
}
}

**# A5: F03 vce(stacked) with geeopts(noconstant)

local ++test_count
if `run_only' == 0 | `run_only' == 5 {
capture noisily {
    _afit_iptw
    local w "`: char _dta[_iivw_weight_var]'"
    if "`w'" == "" local w "_iivw_weight"
    quietly glm y x [pw=`w'], vce(cluster id) noconstant
    local b_nat = _b[x]
    capture noisily iivw_fit y x, timespec(none) vce(stacked) ///
        geeopts(noconstant) nolog
    local rc = _rc
    display as text "  noconstant stacked rc = `rc'"
    assert `rc' == 0
    local cn : colnames e(V)
    assert "`cn'" == "x"
    assert !missing(_b[x], `b_nat')
    assert reldif(_b[x], `b_nat') < 1e-10
    assert e(iivw_stacked_selfcheck) < 1e-8
    * The ordinary intercept design is unchanged and still carries _cons.
    quietly iivw_fit y x, timespec(none) vce(stacked) replace nolog
    local cn : colnames e(V)
    assert "`cn'" == "x _cons"
    display as result "A5 PASS: no-constant stacked fit uses the fitted slope-only design"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A5"
    display as error "A5 FAIL"
}
}

**# A6: F04 family()/link() with model(mixed)

local ++test_count
if `run_only' == 0 | `run_only' == 6 {
capture noisily {
    _afit_base
    foreach opt in "family(poisson)" "link(log)" "family(poisson) link(log)" ///
        "family(gaussian)" {
        capture iivw_fit y x, model(mixed) unweighted id(id) timespec(none) ///
            `opt' nolog
        local rc = _rc
        display as text "  model(mixed) `opt' -> rc = `rc'"
        assert `rc' == 198
    }
    quietly mixed y x || id:, vce(cluster id) nolog
    matrix b_nat = e(b)
    quietly iivw_fit y x, model(mixed) unweighted id(id) timespec(none) nolog
    assert mreldif(e(b), b_nat) < 1e-10
    * Acknowledged weighted mixed with the selectors omitted still fits.
    _afit_iptw
    capture iivw_fit y x, model(mixed) timespec(none) experimentalmixed ///
        vce(fixed) nolog
    assert _rc == 0
    display as result "A6 PASS: family()/link() refused under model(mixed)"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A6"
    display as error "A6 FAIL"
}
}

**# A7: F05 stacked model Wald test from the posted covariance

local ++test_count
if `run_only' == 0 | `run_only' == 7 {
capture noisily {
    _afit_iptw
    gen double x2 = x^2 + rnormal()
    foreach spec in "x" "x x2" {
        quietly iivw_fit y `spec', timespec(none) vce(stacked) replace nolog
        local c = e(chi2)
        local p = e(p)
        local d = e(df_m)
        quietly test `spec'
        display as text "  `spec': e(chi2)=" %12.6g `c' "  test=" %12.6g r(chi2)
        assert !missing(`c', r(chi2), `p', r(p))
        assert reldif(`c', r(chi2)) < 1e-10
        assert reldif(`p', r(p)) < 1e-10 | abs(`p' - r(p)) < 1e-300
        assert `d' == r(df)
    }
    * The fixed-weight test is genuinely different, so the check has power.
    quietly iivw_fit y x, timespec(none) vce(fixed) replace nolog
    local c_fixed = e(chi2)
    quietly iivw_fit y x, timespec(none) vce(stacked) replace nolog
    assert reldif(e(chi2), `c_fixed') > 1e-6
    quietly iivw_fit y, timespec(none) vce(stacked) replace nolog
    assert missing(e(chi2)) & missing(e(p)) & e(df_m) == 0
    display as result "A7 PASS: stacked e(chi2)/e(p)/e(df_m) match a test on e(V)"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A7"
    display as error "A7 FAIL"
}
}

**# A8: F06 grouped binomial with constant successes

local ++test_count
if `run_only' == 0 | `run_only' == 8 {
capture noisily {
    _afit_base
    gen int successes = 2
    gen int trials = 4 + mod(_n, 13)
    quietly glm successes x, family(binomial trials) vce(cluster id)
    matrix b_nat = e(b)
    matrix V_nat = e(V)
    capture noisily iivw_fit successes x, unweighted id(id) timespec(none) ///
        family(binomial trials) nolog
    assert _rc == 0
    assert mreldif(e(b), b_nat) < 1e-10
    assert mreldif(e(V), V_nat) < 1e-8
    * Abbreviated binomial family follows the same rule.
    capture iivw_fit successes x, unweighted id(id) timespec(none) ///
        family(b trials) nolog
    assert _rc == 0
    * A constant proportion under variable trials is still refused.
    gen int s2 = trials/2 if mod(trials, 2) == 0
    replace trials = . if missing(s2)
    capture iivw_fit s2 x, unweighted id(id) timespec(none) ///
        family(binomial trials) nolog
    assert _rc == 198
    * A constant Gaussian response and a fixed-trial constant are still refused.
    _afit_base
    gen double yc = 3
    capture iivw_fit yc x, unweighted id(id) timespec(none) nolog
    assert _rc == 198
    gen int s5 = 5
    capture iivw_fit s5 x, unweighted id(id) timespec(none) ///
        family(binomial 10) nolog
    assert _rc == 198
    display as result "A8 PASS: grouped binomial checks variation in successes/trials"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A8"
    display as error "A8 FAIL"
}
}

**# A9: F07 replace never overwrites an auxiliary input

* Each call names an earlier fit's generated column as an auxiliary input and
* then asks replace to regenerate that column. The original command overwrote
* the input before the engine read it (a different scientific model at rc 0).
local ++test_count
if `run_only' == 0 | `run_only' == 9 {
capture noisily {
    local case1 "geeopts(offset(_iivw_time_sq))"
    local case2 "geeopts(exposure(_iivw_time_sq))"
    local case3 "family(binomial _iivw_time_sq)"
    local case4 "model(mixed) mixedopts(residuals(ar 1, t(_iivw_time_sq)))"
    local case5 "model(mixed) mixedopts(residuals(independent, by(_iivw_time_sq)))"
    forvalues k = 1/5 {
        local c "`case`k''"
        _afit_base
        quietly iivw_fit y x, unweighted id(id) time(t) timespec(quadratic) nolog
        gen double snap = _iivw_time_sq
        local tok : char _iivw_time_sq[_iivw_fit_token]
        gen double t_alt = t + 1
        gen byte ys = mod(_n, 2)
        local dv "y"
        if strpos("`c'", "binomial") local dv "ys"
        capture iivw_fit `dv' x, unweighted id(id) time(t_alt) ///
            timespec(quadratic) `c' replace nolog
        local rc = _rc
        quietly count if _iivw_time_sq != snap
        local changed = r(N)
        local tok2 : char _iivw_time_sq[_iivw_fit_token]
        display as text "  `c' -> rc = `rc', changed rows = `changed'"
        assert `rc' == 198
        assert `changed' == 0
        assert "`tok'" == "`tok2'"
    }
    * Negative control: an auxiliary that is not a generated column is fine.
    _afit_base
    gen double off = .1*t
    quietly glm y x t, offset(off) vce(cluster id)
    matrix b_nat = e(b)
    quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) ///
        geeopts(offset(off)) nolog
    assert mreldif(e(b), b_nat) < 1e-10
    display as result "A9 PASS: auxiliary inputs are protected from replace"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A9"
    display as error "A9 FAIL"
}
}

**# A10: F08 numeric sentinels and integer formats

local ++test_count
if `run_only' == 0 | `run_only' == 10 {
capture noisily {
    _afit_base
    foreach opt in "bootstrap(-999999)" "rngstream(-999999)" ///
        "vce(fixed, reps(-999999))" "vce(fixed, reps(0))" "bootstrap(-1)" ///
        "bootstrap(1.5)" "bootstrap(abc)" "vce(bootstrap, reps(-999999))" ///
        "vce(bootstrap, reps(2.5))" ///
        "vce(bootstrap, reps(2) fixedweights) rngstream(1.5)" {
        capture iivw_fit y x, unweighted id(id) timespec(none) `opt' nolog
        local rc = _rc
        display as text "  `opt' -> rc = `rc'"
        assert `rc' == 198
    }
    foreach opt in "" "bootstrap(0)" "vce(fixed)" {
        capture iivw_fit y x, unweighted id(id) timespec(none) `opt' nolog
        assert _rc == 0
    }
    * The integer formats the old integer option accepted still parse.
    quietly iivw_fit y x, unweighted id(id) timespec(none) bootstrap(2e1) nolog
    assert e(N_reps) == 20
    quietly iivw_fit y x, unweighted id(id) timespec(none) ///
        vce(bootstrap, reps(4.0) fixedweights seed(51)) rngstream(1e0) nolog
    assert e(N_reps) == 4
    assert "`e(iivw_rngstream)'" == "1"
    display as result "A10 PASS: sentinel values refused; integer formats preserved"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A10"
    display as error "A10 FAIL"
}
}

**# A11: F09 an edited raw source refuses predict

local ++test_count
if `run_only' == 0 | `run_only' == 11 {
capture noisily {
    _afit_base
    * Non-integer time exercises exact expression equality.
    quietly replace t = .113 + .207*t + .0031*id
    quietly iivw_fit y x, unweighted id(id) time(t) timespec(quadratic) nolog
    gen double oracle = _b[_cons] + _b[x]*x + _b[t]*t + _b[_iivw_time_sq]*t^2
    predict double p0, xb
    assert !missing(p0, oracle)
    assert reldif(p0, oracle) < 1e-12
    gen double t_orig = t
    quietly replace t = t + 10 if id <= 20
    capture predict double p1, xb
    display as text "  edited raw time, full predict -> rc = " _rc
    assert _rc == 459
    capture confirm variable p1
    assert _rc != 0
    * Selection outside the edited rows is still predicted.
    predict double p2 if id > 20, xb
    assert !missing(p2, oracle) if id > 20
    assert reldif(p2, oracle) < 1e-12 if id > 20
    predict double p3 in 81/400, xb
    assert !missing(p3, oracle) in 81/400
    assert reldif(p3, oracle) < 1e-12 in 81/400
    * Restoring the data restores the prediction.
    quietly replace t = t_orig
    predict double p4, xb
    assert p4 == p0
    * A new row whose generated column follows the fitted expression predicts.
    local nn = _N + 1
    quietly set obs `nn'
    quietly replace id = 999 in `nn'
    quietly replace x = .3 in `nn'
    quietly replace t = 5 in `nn'
    quietly replace _iivw_time_sq = 25 in `nn'
    predict double p5 in `nn', xb
    local p5_oracle = _b[_cons] + .3*_b[x] + 5*_b[t] + 25*_b[_iivw_time_sq]
    local p5_got = p5[`nn']
    assert !missing(`p5_got', `p5_oracle')
    assert reldif(`p5_got', `p5_oracle') < 1e-12
    * Dropping the raw source refuses.
    drop t
    capture predict double p6, xb
    assert _rc == 459
    display as result "A11 PASS: the expression guard follows predict's if/in selection"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A11"
    display as error "A11 FAIL"
}
}

**# A12: F09 sibling generated designs

local ++test_count
if `run_only' == 0 | `run_only' == 12 {
capture noisily {
    * Each entry: predictors | options | the raw source that is edited.
    local d1 "x|time(t) timespec(categorical)|t"
    local d2 "x|time(t) timespec(cubic)|t"
    local d3 "x|time(t) timespec(ns(3))|t"
    local d4 "x|time(t) timespec(linear) interaction(x)|x"
    local d5 "x g|timespec(none) categorical(g)|g"
    forvalues k = 1/5 {
        tokenize "`d`k''", parse("|")
        local preds "`1'"
        local spec "`3'"
        local src "`5'"
        _afit_base
        gen byte g = 2 + mod(id, 3)*5
        quietly iivw_fit y `preds', unweighted id(id) `spec' nolog
        predict double p0, xb
        capture predict double pchk, xb
        assert _rc == 0
        if "`src'" == "g" quietly replace g = cond(g == 2, 7, 2) if id <= 20
        else quietly replace `src' = `src' + 1 if id <= 20
        capture predict double p1, xb
        local rc = _rc
        display as text "  `spec', edited `src' -> rc = `rc'"
        assert `rc' == 459
        predict double p2 if id > 20, xb
        assert p2 == p0 if id > 20
    }
    display as result "A12 PASS: every generated-design branch detects an edited source"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A12"
    display as error "A12 FAIL"
}
}

**# A13: F10 native mixed predictions

local ++test_count
if `run_only' == 0 | `run_only' == 13 {
capture noisily {
    foreach route in "vce(fixed)" "vce(bootstrap, reps(5) fixedweights seed(7))" {
        _afit_base
        quietly mixed y x || id:, nolog
        predict double r_nat, reffects
        predict double s_nat, residuals
        predict double f_nat, fitted
        quietly iivw_fit y x, model(mixed) unweighted id(id) timespec(none) ///
            `route' nolog
        assert "`e(ivars)'" == "id"
        foreach s in r s f {
            local o = cond("`s'" == "r", "reffects", cond("`s'" == "s", "residuals", "fitted"))
            capture noisily predict double `s'_fit, `o'
            assert _rc == 0
            assert !missing(`s'_fit, `s'_nat)
            assert reldif(`s'_fit, `s'_nat) < 1e-8
        }
        assert "`e(cmd)'" == "iivw_fit"
        capture predict double bad, notanoption
        assert _rc != 0
        assert "`e(cmd)'" == "iivw_fit"
        display as text "  `route': reffects/residuals/fitted equal native mixed"
    }
    * Acknowledged weighted mixed with fixed weights: native [pw=] BLUPs.
    _afit_iptw
    local w "`: char _dta[_iivw_weight_var]'"
    if "`w'" == "" local w "_iivw_weight"
    quietly mixed y x [pw=`w'] || id:, vce(cluster id) nolog
    predict double r_nat, reffects
    quietly iivw_fit y x, model(mixed) timespec(none) experimentalmixed ///
        vce(fixed) nolog
    predict double r_fit, reffects
    assert !missing(r_fit, r_nat)
    assert reldif(r_fit, r_nat) < 1e-8
    display as result "A13 PASS: mixed BLUP predictions run under the native identity"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A13"
    display as error "A13 FAIL"
}
}

**# A14: F11 native mixed estat

local ++test_count
if `run_only' == 0 | `run_only' == 14 {
capture noisily {
    capture which _iivw_fit_estat
    assert _rc == 0
    _afit_base
    quietly mixed y x || id:, vce(cluster id) nolog
    quietly estat ic
    matrix S_nat = r(S)
    quietly iivw_fit y x, model(mixed) unweighted id(id) timespec(none) nolog
    foreach sub in group sd recovariance ic {
        capture noisily estat `sub'
        local rc = _rc
        display as text "  estat `sub' -> rc = `rc'"
        assert `rc' == 0
        assert "`e(cmd)'" == "iivw_fit"
        assert "`e(estat_cmd)'" == "_iivw_fit_estat"
    }
    quietly estat ic
    assert mreldif(r(S), S_nat) < 1e-10
    capture estat notasubcommand
    assert _rc != 0
    assert "`e(cmd)'" == "iivw_fit"
    assert "`e(estat_cmd)'" == "_iivw_fit_estat"
    assert "`e(iivw_estat)'" == "mixed_estat"
    assert "`c(varabbrev)'" == "off"
    * estat bootstrap on a fixed-weight mixed bootstrap also delegates.
    quietly iivw_fit y x, model(mixed) unweighted id(id) timespec(none) ///
        vce(bootstrap, reps(5) fixedweights seed(9)) nolog
    capture estat bootstrap
    assert _rc == 0
    assert "`e(cmd)'" == "iivw_fit"
    display as result "A14 PASS: native mixed estat runs and public identity is restored"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A14"
    display as error "A14 FAIL"
}
}

**# A15: F12 point-only predictions keep the offset/exposure term

local ++test_count
if `run_only' == 0 | `run_only' == 15 {
capture noisily {
    foreach mode in offset exposure {
        _afit_base
        gen double aux = .3 + t
        local family "gaussian"
        if "`mode'" == "exposure" {
            local family "poisson"
            quietly replace y = mod(_n, 7)
        }
        quietly glm y x, family(`family') `mode'(aux) vce(cluster id)
        predict double expected, xb
        local eoff_nat "`e(offset)'"
        quietly iivw_fit y x, unweighted id(id) timespec(none) ///
            family(`family') geeopts(`mode'(aux)) citype(none) nolog
        assert "`e(properties)'" == "b"
        assert "`e(offset)'" == "`eoff_nat'"
        local mats : e(matrices)
        assert !strpos(" `mats' ", " V ")
        predict double actual, xb
        assert !missing(actual, expected)
        assert reldif(actual, expected) < 1e-12
        predict double nooff, xb nooffset
        gen double rawlinear = _b[_cons] + _b[x]*x
        assert !missing(nooff, rawlinear)
        assert reldif(nooff, rawlinear) < 1e-12
        capture predict double sd, stdp
        assert _rc != 0
        display as text "  `mode': point-only xb equals native xb (e(offset)=`e(offset)')"
    }
    display as result "A15 PASS: point-only xb includes the offset/exposure term"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A15"
    display as error "A15 FAIL"
}
}

capture matrix drop b_nat V_nat S_nat

iivw_qa_summary, name(test_iivw_audit_2026_10_05_fit) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') runonly(`run_only') ///
    failedtests("`failed'")
