* test_regtab_backlog_2026_09_26.do - regtab classification, rows, stats, methods
* Regression suite for the regtab items left open after 2.1.11:
*   R1  intercept, cutpoint and ancillary rows classified from the coefficient's
*       equation, never from its display label (a covariate named or labelled
*       p, alpha, constant, cut1 ... survives nointercept and is exponentiated;
*       lognormal/loglogistic ancillary rows keep their own scale under TR)
*   R2  AIC/BIC/QICu count the estimated parameters, not e(rank) after a
*       few-cluster vce(cluster)
*   R3  mestreg in the time metric: the random intercept is not a
*       "Median Hazard Ratio"
*   R4  bootstrap: and jackknife: prefixes are classified like plain fits
*   R5  mi estimate: collections (mi's own eform options, t-based intervals,
*       stats tokens mi_m and fmi); R5b (MI03, mi estimate: logit with
*       vce(robust)) is a guard, not a regression test: it passed on the
*       unfixed tree
*   R6  mlogit/ologit factor covariates keep a header row per equation
*   R7  stats() tokens events, r2_a, rmse, F
*   R8  methods sentence built from the model, not the estimate header
*   R9  r(table) row names stay unique when display labels collide
* Every expected value comes from the fitted model's own e(b)/e(V)/e() or a
* hand computation, never from the table regtab builds.

clear all
set more off
set varabbrev off
version 17.0

capture log close _regtab_backlog
log using "test_regtab_backlog_2026_09_26.log", replace text name(_regtab_backlog)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

* Trimmed contents of column `col' on the one body row whose trimmed label is
* `label'. Errors when the row is absent or duplicated.
capture program drop _rbl_cell
program define _rbl_cell, rclass
    version 17.0
    args frname label col
    frame `frname' {
        tempvar rn
        quietly generate long `rn' = _n
        quietly count if strtrim(A) == `"`label'"' & _n >= 4
        if r(N) != 1 {
            display as error `"frame `frname': `r(N)' rows labelled "`label'""'
            exit 459
        }
        quietly summarize `rn' if strtrim(A) == `"`label'"' & _n >= 4, meanonly
        local row = r(min)
        local cell = strtrim(`col'[`row'])
    }
    return local cell `"`cell'"'
    return scalar row = `row'
end

* Number of body rows whose trimmed label is `label'.
capture program drop _rbl_nrow
program define _rbl_nrow, rclass
    version 17.0
    args frname label
    frame `frname' {
        quietly count if strtrim(A) == `"`label'"' & _n >= 4
        local n = r(N)
    }
    return scalar n = `n'
end

* The text regtab must print for x at digits(2).
capture program drop _rbl_fmt
program define _rbl_fmt, rclass
    version 17.0
    args x
    return local s = strtrim(string(round(`x', 0.01), "%32.2f"))
end

* The CI cell regtab must print for (lo, hi) at digits(2).
capture program drop _rbl_ci
program define _rbl_ci, rclass
    version 17.0
    args lo hi
    local a = strtrim(string(round(`lo', 0.01), "%32.2f"))
    local b = strtrim(string(round(`hi', 0.01), "%32.2f"))
    return local s "(`a', `b')"
end

* Assert the cell of `label' in column `col' equals the formatted value x.
capture program drop _rbl_is
program define _rbl_is
    version 17.0
    args frname label col x
    _rbl_fmt `x'
    local want "`r(s)'"
    _rbl_cell `frname' `"`label'"' `col'
    if `"`r(cell)'"' != "`want'" {
        display as error `"`label' `col': got "`r(cell)'", want "`want'""'
        exit 9
    }
end

* The first sentence of r(methods) must equal `want' exactly.
capture program drop _rbl_methods
program define _rbl_methods
    version 17.0
    args got want
    if strpos(`"`got'"', `"`want' Analysis performed in Stata"') != 1 {
        display as error `"methods: got  "`got'""'
        display as error `"       want "`want'""'
        exit 9
    }
end

**# R1 structural intercept / ancillary classification

* R1a: a covariate named p survives the automatic nointercept, exponentiated
capture noisily {
    sysuse auto, clear
    generate p = mpg
    collect clear
    quietly collect: logit foreign p weight
    local bp = _b[p]
    capture frame drop _rb1
    quietly regtab, frame(_rb1, replace)
    _rbl_is _rb1 "p" c1 `=exp(`bp')'
    _rbl_nrow _rb1 "Intercept"
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: R1a covariate named p kept and exponentiated"
    local ++pass_count
}
else {
    display as error "  FAIL: R1a covariate named p (rc=`=_rc')"
    local ++fail_count
}

* R1b: covariates named like intercept/ancillary parameters
capture noisily {
    foreach nm in alpha lnalpha ln_p constant intercept cut1 {
        sysuse auto, clear
        generate `nm' = mpg
        collect clear
        quietly collect: logit foreign `nm' weight
        local bnm = _b[`nm']
        capture frame drop _rb1
        quietly regtab, frame(_rb1, replace)
        _rbl_is _rb1 "`nm'" c1 `=exp(`bnm')'
    }
}
if _rc == 0 {
    display as result "  PASS: R1b covariates named alpha/lnalpha/ln_p/constant/intercept/cut1"
    local ++pass_count
}
else {
    display as error "  FAIL: R1b covariates named like ancillary rows (rc=`=_rc')"
    local ++fail_count
}

* R1c: covariates labelled p, alpha, Intercept, Constant, /x
capture noisily {
    foreach lb in "p" "alpha" "Intercept" "Constant" "/x" {
        sysuse auto, clear
        label variable mpg "`lb'"
        collect clear
        quietly collect: logit foreign mpg weight
        local bm = _b[mpg]
        capture frame drop _rb1
        quietly regtab, frame(_rb1, replace)
        _rbl_is _rb1 "`lb'" c1 `=exp(`bm')'
    }
}
if _rc == 0 {
    display as result "  PASS: R1c covariates labelled like ancillary rows"
    local ++pass_count
}
else {
    display as error "  FAIL: R1c covariates labelled like ancillary rows (rc=`=_rc')"
    local ++fail_count
}

* R1d: with keepintercept a covariate named p is exponentiated, not ancillary
capture noisily {
    sysuse auto, clear
    generate p = mpg
    collect clear
    quietly collect: logit foreign p weight
    local bp = _b[p]
    local bc = _b[_cons]
    capture frame drop _rb1
    quietly regtab, frame(_rb1, replace) keepintercept
    _rbl_is _rb1 "p" c1 `=exp(`bp')'
    _rbl_is _rb1 "Intercept" c1 `=exp(`bc')'
}
if _rc == 0 {
    display as result "  PASS: R1d keepintercept exponentiates a covariate named p"
    local ++pass_count
}
else {
    display as error "  FAIL: R1d keepintercept covariate named p (rc=`=_rc')"
    local ++fail_count
}

* R1e: lognormal and loglogistic ancillary rows keep their own scale under TR
capture noisily {
    webuse kva, clear
    quietly stset failtime
    collect clear
    quietly collect: streg load bearings, distribution(lognormal)
    matrix b1 = e(b)
    quietly collect: streg load bearings, distribution(loglogistic)
    matrix b2 = e(b)
    local lns = b1[1, colnumb(b1, "/:lnsigma")]
    local lng = b2[1, colnumb(b2, "/:lngamma")]
    local l1 = b1[1, colnumb(b1, "_t:load")]
    local l2 = b2[1, colnumb(b2, "_t:load")]
    foreach opt in "" "keepintercept" {
        capture frame drop _rb1
        quietly regtab, frame(_rb1, replace) `opt'
        frame _rb1: assert strtrim(c1[3]) == "TR" & strtrim(c4[3]) == "TR"
        _rbl_is _rb1 "lnsigma" c1 `lns'
        _rbl_is _rb1 "sigma" c1 `=exp(`lns')'
        _rbl_is _rb1 "lngamma" c4 `lng'
        _rbl_is _rb1 "gamma" c4 `=exp(`lng')'
        _rbl_is _rb1 "Overload (kVA)" c1 `=exp(`l1')'
        _rbl_is _rb1 "Overload (kVA)" c4 `=exp(`l2')'
    }
}
if _rc == 0 {
    display as result "  PASS: R1e lognormal/loglogistic ancillary rows unexponentiated"
    local ++pass_count
}
else {
    display as error "  FAIL: R1e lognormal/loglogistic ancillary rows (rc=`=_rc')"
    local ++fail_count
}

* R1f: guard - Weibull ln_p/p/1/p, nbreg lnalpha/alpha, ologit cutpoints keep
* today's drop (default) and raw display (keepintercept)
capture noisily {
    webuse kva, clear
    quietly stset failtime
    collect clear
    quietly collect: streg load bearings, distribution(weibull)
    matrix bw = e(b)
    local lnp = bw[1, colnumb(bw, "/:ln_p")]
    capture frame drop _rb1
    quietly regtab, frame(_rb1, replace)
    foreach r in ln_p p 1/p Intercept {
        _rbl_nrow _rb1 "`r'"
        assert r(n) == 0
    }
    capture frame drop _rb1
    quietly regtab, frame(_rb1, replace) keepintercept
    _rbl_is _rb1 "ln_p" c1 `lnp'
    _rbl_is _rb1 "p" c1 `=exp(`lnp')'
    _rbl_is _rb1 "1/p" c1 `=exp(-`lnp')'

    sysuse auto, clear
    collect clear
    quietly collect: nbreg rep78 mpg weight
    matrix bn = e(b)
    local lna = bn[1, colnumb(bn, "/:lnalpha")]
    capture frame drop _rb1
    quietly regtab, frame(_rb1, replace)
    foreach r in lnalpha alpha Intercept {
        _rbl_nrow _rb1 "`r'"
        assert r(n) == 0
    }
    capture frame drop _rb1
    quietly regtab, frame(_rb1, replace) keepintercept
    _rbl_is _rb1 "lnalpha" c1 `lna'

    collect clear
    quietly collect: ologit rep78 mpg weight
    matrix bo = e(b)
    capture frame drop _rb1
    quietly regtab, frame(_rb1, replace)
    forvalues k = 1/4 {
        _rbl_nrow _rb1 "cut`k'"
        assert r(n) == 0
    }
    capture frame drop _rb1
    quietly regtab, frame(_rb1, replace) keepintercept
    forvalues k = 1/4 {
        _rbl_is _rb1 "cut`k'" c1 `=bo[1, colnumb(bo, "/:cut`k'")]'
    }
}
if _rc == 0 {
    display as result "  PASS: R1f Weibull/nbreg/ologit ancillary guards"
    local ++pass_count
}
else {
    display as error "  FAIL: R1f ancillary guards (rc=`=_rc')"
    local ++fail_count
}

* R1g: an ancillary parameter in one model and a covariate of the same name
* in another are classified per model. Without keepintercept the ancillary
* is dropped and the covariate row stays; with it, 2.1.13 shows two rows
* (2.1.12 merged them into one, R-tabtools quirks Addendum 9 item 15).
capture noisily {
    sysuse auto, clear
    generate alpha = mpg
    collect clear
    quietly collect: nbreg rep78 mpg weight
    matrix bn = e(b)
    quietly collect: logit foreign alpha weight
    local ba = _b[alpha]
    local lna = bn[1, colnumb(bn, "/:lnalpha")]
    capture frame drop _rb1
    quietly regtab, frame(_rb1, replace)
    _rbl_cell _rb1 "alpha" c1
    assert "`r(cell)'" == ""
    _rbl_is _rb1 "alpha" c4 `=exp(`ba')'
    capture frame drop _rb1
    quietly regtab, frame(_rb1, replace) keepintercept
    _rbl_nrow _rb1 "alpha"
    assert r(n) == 2
    _rbl_fmt `=exp(`lna')'
    local want_a "`r(s)'"
    _rbl_fmt `=exp(`ba')'
    local want_c "`r(s)'"
    frame _rb1 {
        quietly count if strtrim(A) == "alpha" & strtrim(c1) == "`want_a'" ///
            & strtrim(c4) == "" & _n >= 4
        assert r(N) == 1
        quietly count if strtrim(A) == "alpha" & strtrim(c1) == "" ///
            & strtrim(c4) == "`want_c'" & _n >= 4
        assert r(N) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: R1g ancillary vs covariate row classified per model"
    local ++pass_count
}
else {
    display as error "  FAIL: R1g per-model classification (rc=`=_rc')"
    local ++fail_count
}

* R1h: one model whose covariate shares its name with its own ancillary
* parameter shows both, never drops or refuses either (the full cases are
* F8 in test_followups_2026_09_27.do)
capture noisily {
    sysuse auto, clear
    generate alpha = mpg
    collect clear
    quietly collect: nbreg rep78 alpha weight
    matrix bn = e(b)
    local ba = bn[1, colnumb(bn, "rep78:alpha")]
    local lna = bn[1, colnumb(bn, "/:lnalpha")]
    capture frame drop _rb1
    quietly regtab, frame(_rb1, replace)
    _rbl_is _rb1 "alpha" c1 `=exp(`ba')'
    capture frame drop _rb1
    quietly regtab, frame(_rb1, replace) keepintercept
    _rbl_nrow _rb1 "alpha"
    assert r(n) == 2
    _rbl_is _rb1 "lnalpha" c1 `lna'
    frame _rb1 {
        _rbl_fmt `=exp(`ba')'
        assert strtrim(c1[4]) == "`r(s)'"
        quietly generate long _r = _n
        quietly summarize _r if strtrim(A) == "alpha" & _n >= 4
        local ra = r(max)
        _rbl_fmt `=exp(`lna')'
        assert strtrim(c1[`ra']) == "`r(s)'"
    }
}
if _rc == 0 {
    display as result "  PASS: R1h same-model covariate/ancillary name collision shows both rows"
    local ++pass_count
}
else {
    display as error "  FAIL: R1h same-model name collision (rc=`=_rc')"
    local ++fail_count
}

**# R2 AIC/BIC/QICu parameter count

* Fewer clusters than coefficients: e(rank) is capped at G-1
capture program drop _rbl_r2data
program define _rbl_r2data
    version 17.0
    clear
    set obs 400
    set seed 12345
    generate c = mod(_n, 2)
    generate x1 = rnormal()
    generate x2 = rnormal()
    generate x3 = rnormal()
    generate y = runiform() < invlogit(0.3*x1 - 0.2*x2 + 0.1*x3 + 0.5*c)
    generate yc = x1 + x2 + x3 + rnormal()
    generate t = rexponential(1 / exp(0.3*x1))
    generate d = runiform() < 0.8
end

* R2a: logit, regress, stcox with vce(cluster) on 2 clusters
capture noisily {
    _rbl_r2data
    quietly logit y x1 x2 x3, vce(cluster c)
    assert e(rank) == 1
    quietly estat ic
    matrix S = r(S)
    * Stata's own estat ic uses the capped e(rank): documented divergence
    assert S[1, 4] == 1
    local ll = e(ll)
    local N = e(N)
    collect clear
    quietly collect: logit y x1 x2 x3, vce(cluster c)
    quietly collect: logit y x1 x2 x3
    quietly estat ic
    matrix S2 = r(S)
    quietly regtab, stats(n ll aic bic)
    assert reldif(r(aic_1), -2*`ll' + 2*4) < 1e-10
    assert reldif(r(bic_1), -2*`ll' + 4*ln(`N')) < 1e-10
    assert reldif(r(aic_1), r(aic_2)) < 1e-10
    assert reldif(r(aic_2), S2[1, 5]) < 1e-8
    assert reldif(r(bic_2), S2[1, 6]) < 1e-8

    quietly regress yc x1 x2 x3, vce(cluster c)
    local ll = e(ll)
    collect clear
    quietly collect: regress yc x1 x2 x3, vce(cluster c)
    quietly collect: regress yc x1 x2 x3
    quietly estat ic
    matrix S3 = r(S)
    quietly regtab, stats(aic bic)
    assert reldif(r(aic_1), -2*`ll' + 2*4) < 1e-10
    assert reldif(r(aic_1), r(aic_2)) < 1e-10
    assert reldif(r(aic_2), S3[1, 5]) < 1e-8

    quietly stset t, failure(d)
    quietly stcox x1 x2 x3, vce(cluster c)
    local ll = e(ll)
    collect clear
    quietly collect: stcox x1 x2 x3, vce(cluster c)
    quietly collect: stcox x1 x2 x3
    quietly regtab, stats(aic)
    assert reldif(r(aic_1), -2*`ll' + 2*3) < 1e-10
    assert reldif(r(aic_1), r(aic_2)) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: R2a AIC/BIC count parameters after few-cluster vce(cluster)"
    local ++pass_count
}
else {
    display as error "  FAIL: R2a AIC/BIC after few-cluster vce(cluster) (rc=`=_rc')"
    local ++fail_count
}

* R2b: guard - model-based fits keep AIC/BIC equal to estat ic
capture noisily {
    local nfits 0
    sysuse auto, clear
    foreach spec in "logit foreign mpg weight" "regress price mpg weight" ///
        "poisson rep78 i.foreign mpg" "nbreg rep78 mpg weight" ///
        "ologit rep78 mpg weight" "mlogit rep78 mpg if rep78 >= 3" {
        collect clear
        quietly collect: `spec'
        quietly estat ic
        matrix S = r(S)
        quietly regtab, stats(aic bic)
        assert reldif(r(aic_1), S[1, 5]) < 1e-8
        assert reldif(r(bic_1), S[1, 6]) < 1e-8
        local ++nfits
    }
    webuse kva, clear
    quietly stset failtime
    collect clear
    quietly collect: streg load bearings, distribution(weibull)
    quietly estat ic
    matrix S = r(S)
    quietly regtab, stats(aic bic)
    assert reldif(r(aic_1), S[1, 5]) < 1e-8
    webuse pig, clear
    collect clear
    quietly collect: mixed weight week || id:
    quietly estat ic
    matrix S = r(S)
    quietly regtab, stats(aic bic)
    assert reldif(r(aic_1), S[1, 5]) < 1e-8
    assert reldif(r(bic_1), S[1, 6]) < 1e-8
    assert `nfits' == 6
}
if _rc == 0 {
    display as result "  PASS: R2b model-based AIC/BIC equal estat ic"
    local ++pass_count
}
else {
    display as error "  FAIL: R2b model-based AIC/BIC vs estat ic (rc=`=_rc')"
    local ++fail_count
}

* R2c: QICu follows the same rule (Pan 2001: penalty 2p, p = parameters)
capture noisily {
    _rbl_r2data
    generate id = mod(_n, 3) + 1
    bysort id: generate tt = _n
    quietly xtset id tt
    quietly xtgee y x1 x2 x3, family(binomial) link(logit) corr(independent) vce(robust)
    assert e(rank) < 4
    local dev = e(deviance)
    collect clear
    quietly collect: xtgee y x1 x2 x3, family(binomial) link(logit) corr(independent) vce(robust)
    quietly collect: xtgee y x1 x2 x3, family(binomial) link(logit) corr(independent)
    quietly regtab, stats(qic)
    assert reldif(r(qic_1), `dev' + 2*4) < 1e-10
    assert reldif(r(qic_1), r(qic_2)) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: R2c QICu counts parameters under robust vce"
    local ++pass_count
}
else {
    display as error "  FAIL: R2c QICu parameter count (rc=`=_rc')"
    local ++fail_count
}

**# R3 mestreg time metric random intercept

capture noisily {
    webuse catheter, clear
    collect clear
    quietly collect: mestreg age female || patient:, distribution(weibull) time
    matrix bm = e(b)
    local v = bm[1, colnumb(bm, "/:var(_cons[patient])")]
    local ba = bm[1, colnumb(bm, "_t:age")]
    capture frame drop _rb3
    quietly regtab, frame(_rb3, replace)
    frame _rb3: quietly count if strpos(A, "Median Hazard Ratio") > 0
    assert r(N) == 0
    _rbl_is _rb3 "var(_cons[patient])" c1 `v'
    _rbl_is _rb3 "Patient age" c1 `=exp(`ba')'
    capture frame drop _rb3
    quietly regtab, frame(_rb3, replace) relabel
    _rbl_is _rb3 "Variance: Patient ID (Intercept)" c1 `v'

    * guard: the hazard metric keeps its MHR row
    collect clear
    quietly collect: mestreg age female || patient:, distribution(weibull)
    matrix bh = e(b)
    local vh = bh[1, colnumb(bh, "/:var(_cons[patient])")]
    capture frame drop _rb3
    quietly regtab, frame(_rb3, replace)
    _rbl_is _rb3 "Median Hazard Ratio (Patient ID)" c1 `=exp(sqrt(2*`vh')*invnormal(0.75))'
}
if _rc == 0 {
    display as result "  PASS: R3 mestreg time metric random intercept is a variance"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 mestreg time metric random intercept (rc=`=_rc')"
    local ++fail_count
}

**# R4 bootstrap: and jackknife: prefixes

capture noisily {
    sysuse auto, clear
    quietly logit foreign mpg weight
    local bl = _b[mpg]
    quietly poisson rep78 mpg
    local bp = _b[mpg]
    collect clear
    quietly collect: bootstrap, reps(20) seed(1): logit foreign mpg weight
    capture frame drop _rb4
    quietly regtab, frame(_rb4, replace)
    frame _rb4: assert strtrim(c1[3]) == "OR"
    _rbl_is _rb4 "Mileage (mpg)" c1 `=exp(`bl')'
    _rbl_nrow _rb4 "Intercept"
    assert r(n) == 0

    collect clear
    quietly collect: jackknife: poisson rep78 mpg
    capture frame drop _rb4
    quietly regtab, frame(_rb4, replace)
    frame _rb4: assert strtrim(c1[3]) == "IRR"
    _rbl_is _rb4 "Mileage (mpg)" c1 `=exp(`bp')'
    _rbl_nrow _rb4 "Intercept"
    assert r(n) == 0

    * beside plain fits, and with the eform request on either side of the colon
    collect clear
    quietly collect: bootstrap, reps(20) seed(1): logit foreign mpg weight
    quietly collect: logit foreign mpg weight
    quietly collect: jackknife: poisson rep78 mpg
    quietly collect: bootstrap, reps(20) seed(1): logit foreign mpg weight, or
    quietly collect: bs, reps(20) seed(1) eform: logit foreign mpg weight
    capture frame drop _rb4
    quietly regtab, frame(_rb4, replace)
    frame _rb4: assert strtrim(c1[3]) == "OR" & strtrim(c4[3]) == "OR" ///
        & strtrim(c7[3]) == "IRR" & strtrim(c10[3]) == "OR" & strtrim(c13[3]) == "OR"
    foreach c in c1 c4 c10 c13 {
        _rbl_is _rb4 "Mileage (mpg)" `c' `=exp(`bl')'
    }
    _rbl_is _rb4 "Mileage (mpg)" c7 `=exp(`bp')'
    _rbl_nrow _rb4 "Intercept"
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: R4 bootstrap/jackknife prefixes classified"
    local ++pass_count
}
else {
    display as error "  FAIL: R4 bootstrap/jackknife prefixes (rc=`=_rc')"
    local ++fail_count
}

**# R5 mi estimate collections

capture program drop _rbl_midata
program define _rbl_midata
    version 17.0
    sysuse auto, clear
    set seed 2026
    replace mpg = . if runiform() < 0.2
    quietly mi set wide
    quietly mi register imputed mpg
    quietly mi impute regress mpg = weight length foreign, add(5) rseed(99)
end

* Expected estimate and CI cells from mi's own b_mi, V_mi, df_mi (Rubin's
* rules with a t reference on each coefficient's df, [MI] mi estimate (1)).
capture program drop _rbl_miexp
program define _rbl_miexp
    version 17.0
    args frname label col j eform
    matrix _mb = e(b_mi)
    matrix _mV = e(V_mi)
    matrix _md = e(df_mi)
    local b = _mb[1, `j']
    local se = sqrt(_mV[`j', `j'])
    local t = invttail(_md[1, `j'], 0.025)
    local lo = `b' - `t' * `se'
    local hi = `b' + `t' * `se'
    if `eform' {
        local b = exp(`b')
        local lo = exp(`lo')
        local hi = exp(`hi')
    }
    _rbl_is `frname' `"`label'"' `col' `b'
    _rbl_ci `lo' `hi'
    local want "`r(s)'"
    local ccol = "c" + string(real(substr("`col'", 2, .)) + 1)
    _rbl_cell `frname' `"`label'"' `ccol'
    if `"`r(cell)'"' != "`want'" {
        display as error `"`label' CI: got "`r(cell)'", want "`want'""'
        exit 9
    }
end

* MI01 regress, MI02 logit (df rule), MI02b mi's own or option
capture noisily {
    _rbl_midata
    collect clear
    quietly collect: mi estimate: regress price mpg weight
    capture frame drop _rb5
    quietly regtab, frame(_rb5, replace)
    frame _rb5: assert strtrim(c1[3]) == "Coef."
    _rbl_miexp _rb5 "Mileage (mpg)" c1 1 0

    collect clear
    quietly collect: mi estimate: logit foreign mpg weight
    capture frame drop _rb5
    quietly regtab, frame(_rb5, replace)
    frame _rb5: assert strtrim(c1[3]) == "OR"
    _rbl_miexp _rb5 "Mileage (mpg)" c1 1 1
    _rbl_nrow _rb5 "Intercept"
    assert r(n) == 0

    * the fit's own or is ignored by mi; mi's or reports ORs: neither may be
    * exponentiated twice
    collect clear
    quietly collect: mi estimate: logit foreign mpg weight, or
    quietly collect: mi estimate, or: logit foreign mpg weight
    quietly collect: mi est, eform: logit foreign mpg weight
    capture frame drop _rb5
    quietly regtab, frame(_rb5, replace)
    foreach c in c1 c4 c7 {
        _rbl_miexp _rb5 "Mileage (mpg)" `c' 1 1
    }
}
if _rc == 0 {
    display as result "  PASS: R5a MI01/MI02 mi estimate regress and logit"
    local ++pass_count
}
else {
    display as error "  FAIL: R5a MI01/MI02 mi estimate (rc=`=_rc')"
    local ++fail_count
}

* MI03 robust within-imputation VCE (vce() belongs to the fitted command)
capture noisily {
    _rbl_midata
    collect clear
    quietly collect: mi estimate: logit foreign mpg weight, vce(robust)
    capture frame drop _rb5
    quietly regtab, frame(_rb5, replace)
    frame _rb5: assert strtrim(c1[3]) == "OR"
    _rbl_miexp _rb5 "Mileage (mpg)" c1 1 1
    _rbl_miexp _rb5 "Weight (lbs.)" c1 2 1
}
if _rc == 0 {
    display as result "  PASS: R5b MI03 mi estimate logit, vce(robust)"
    local ++pass_count
}
else {
    display as error "  FAIL: R5b MI03 (rc=`=_rc')"
    local ++fail_count
}

* MI04 stcox: mi reports coefficients unless mi's own hr is given
capture noisily {
    sysuse cancer, clear
    set seed 1
    replace age = . if runiform() < 0.2
    quietly mi set wide
    quietly mi register imputed age
    quietly mi impute regress age = drug studytime died, add(5) rseed(9)
    quietly mi stset studytime, failure(died)
    collect clear
    quietly collect: mi estimate: stcox age drug
    capture frame drop _rb5
    quietly regtab, frame(_rb5, replace)
    frame _rb5: assert strtrim(c1[3]) == "HR"
    _rbl_miexp _rb5 "Patient's age at start of exp." c1 1 1
    collect clear
    quietly collect: mi estimate, hr: stcox age drug
    capture frame drop _rb5
    quietly regtab, frame(_rb5, replace)
    _rbl_miexp _rb5 "Patient's age at start of exp." c1 1 1
}
if _rc == 0 {
    display as result "  PASS: R5c MI04 mi estimate stcox"
    local ++pass_count
}
else {
    display as error "  FAIL: R5c MI04 (rc=`=_rc')"
    local ++fail_count
}

* stats tokens mi_m and fmi; ll/AIC/BIC blank
capture noisily {
    _rbl_midata
    collect clear
    quietly collect: mi estimate: logit foreign mpg weight
    local M = e(M_mi)
    matrix F = e(fmi_mi)
    local fmax = 0
    forvalues j = 1/`=colsof(F)' {
        local fmax = max(`fmax', F[1, `j'])
    }
    capture frame drop _rb5
    quietly regtab, frame(_rb5, replace) stats(n mi_m fmi ll aic bic)
    local r_fmi = r(fmi_1)
    local r_mim = r(mi_m_1)
    _rbl_cell _rb5 "Imputations" c1
    assert "`r(cell)'" == "`M'"
    _rbl_cell _rb5 "Largest FMI" c1
    assert "`r(cell)'" == strtrim(string(`fmax', "%6.4f"))
    assert reldif(`r_fmi', `fmax') < 1e-12
    assert `r_mim' == `M'
    foreach r in "AIC" "BIC" "Log-likelihood" {
        _rbl_nrow _rb5 "`r'"
        assert r(n) == 0
    }
    _rbl_cell _rb5 "Observations" c1
    assert "`r(cell)'" == "74"

    * mi estimate reports no R², root MSE, or F of its own: blank, never a
    * value left over from one imputation's fit
    collect clear
    quietly collect: mi estimate: regress price mpg weight
    capture frame drop _rb5
    quietly regtab, frame(_rb5, replace) stats(n r2 r2_a rmse F mi_m)
    foreach r in "R²" "Adjusted R²" "Root MSE" "F statistic" {
        _rbl_nrow _rb5 "`r'"
        assert r(n) == 0
    }
    _rbl_cell _rb5 "Imputations" c1
    assert "`r(cell)'" == "5"
}
if _rc == 0 {
    display as result "  PASS: R5d stats(mi_m fmi) and blank likelihood rows"
    local ++pass_count
}
else {
    display as error "  FAIL: R5d mi stats tokens (rc=`=_rc')"
    local ++fail_count
}

**# R6 factor headers inside multi-equation blocks

capture noisily {
    sysuse auto, clear
    generate byte hi = price > 6000
    label define hil 0 "Cheap" 1 "Dear"
    label values hi hil
    label variable hi "Price class"
    collect clear
    quietly collect: mlogit rep78 i.hi mpg if rep78 >= 3
    matrix bm = e(b)
    capture frame drop _rb6
    quietly regtab, frame(_rb6, replace)
    foreach eq in 4 5 {
        _rbl_cell _rb6 "`eq': Price class" c1
        local hrow = r(row)
        assert "`r(cell)'" == ""
        _rbl_cell _rb6 "`eq':   Cheap" c1
        assert r(row) == `hrow' + 1
        assert "`r(cell)'" == "Reference"
        _rbl_cell _rb6 "`eq':   Dear" c1
        assert r(row) == `hrow' + 2
        _rbl_is _rb6 "`eq':   Dear" c1 `=exp(bm[1, colnumb(bm, "`eq':1.hi")])'
        _rbl_is _rb6 "`eq': Mileage (mpg)" c1 `=exp(bm[1, colnumb(bm, "`eq':mpg")])'
        _rbl_nrow _rb6 "`eq': 1.hi"
        assert r(n) == 0
    }

    * ologit beside mlogit uses the multi-equation layout too
    collect clear
    quietly collect: ologit rep78 i.hi mpg
    matrix bo = e(b)
    quietly collect: mlogit rep78 i.hi mpg if rep78 >= 3
    matrix bm = e(b)
    capture frame drop _rb6
    quietly regtab, frame(_rb6, replace)
    _rbl_cell _rb6 "Repair record 1978: Price class" c1
    local hrow = r(row)
    _rbl_cell _rb6 "Repair record 1978:   Cheap" c1
    assert r(row) == `hrow' + 1 & "`r(cell)'" == "Reference"
    _rbl_is _rb6 "Repair record 1978:   Dear" c1 `=exp(bo[1, colnumb(bo, "rep78:1.hi")])'
    _rbl_is _rb6 "5:   Dear" c4 `=exp(bm[1, colnumb(bm, "5:1.hi")])'

    * ologit alone keeps the single-equation layout (guard)
    collect clear
    quietly collect: ologit rep78 i.hi mpg
    capture frame drop _rb6
    quietly regtab, frame(_rb6, replace)
    _rbl_cell _rb6 "Price class" c1
    local hrow = r(row)
    _rbl_cell _rb6 "Dear" c1
    assert r(row) == `hrow' + 2
    _rbl_is _rb6 "Dear" c1 `=exp(bo[1, colnumb(bo, "rep78:1.hi")])'
}
if _rc == 0 {
    display as result "  PASS: R6 factor header rows per equation"
    local ++pass_count
}
else {
    display as error "  FAIL: R6 factor header rows per equation (rc=`=_rc')"
    local ++fail_count
}

**# R7 stats tokens events r2_a rmse F

capture noisily {
    sysuse auto, clear
    generate w = 1
    quietly svyset [pweight = w]
    collect clear
    quietly collect: regress price mpg weight
    local r2a = e(r2_a)
    local rmse = e(rmse)
    local F = e(F)
    quietly collect: logit foreign mpg weight
    quietly collect: svy: logit foreign mpg weight
    assert !missing(e(F))
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    quietly collect: stcox age drug
    local nf = e(N_fail)
    capture frame drop _rb7
    quietly regtab, frame(_rb7, replace) ///
        stats(F rmse r2_a r2 aic events n)
    local r_ev4 = r(events_4)
    local r_ev1 = r(events_1)
    local r_r2a1 = r(r2_a_1)
    local r_rmse1 = r(rmse_1)
    local r_F1 = r(F_1)
    local r_F3 = r(F_3)
    _rbl_cell _rb7 "Events" c10
    assert "`r(cell)'" == strtrim(string(`nf', "%12.0fc"))
    local r_ev = r(row)
    foreach c in c1 c4 c7 {
        _rbl_cell _rb7 "Events" `c'
        assert "`r(cell)'" == ""
    }
    _rbl_cell _rb7 "Adjusted R²" c1
    assert "`r(cell)'" == strtrim(string(`r2a', "%5.3f"))
    local r_r2a = r(row)
    _rbl_cell _rb7 "Root MSE" c1
    assert "`r(cell)'" == strtrim(string(`rmse', "%9.3f"))
    local r_rmse = r(row)
    _rbl_cell _rb7 "F statistic" c1
    assert "`r(cell)'" == strtrim(string(`F', "%9.2f"))
    local r_F = r(row)
    foreach lab in "Adjusted R²" "Root MSE" "F statistic" {
        foreach c in c4 c7 c10 {
            _rbl_cell _rb7 "`lab'" `c'
            assert "`r(cell)'" == ""
        }
    }
    * row order: counts, then likelihood criteria, then variance explained
    * a survival model in the collection names the N row "Subjects"
    _rbl_cell _rb7 "Subjects" c1
    local r_n = r(row)
    _rbl_cell _rb7 "AIC" c4
    local r_aic = r(row)
    _rbl_cell _rb7 "R² / Pseudo R²" c1
    local r_r2 = r(row)
    assert `r_n' < `r_ev' & `r_ev' < `r_aic' & `r_aic' < `r_r2' ///
        & `r_r2' < `r_r2a' & `r_r2a' < `r_rmse' & `r_rmse' < `r_F'
    assert `r_ev4' == `nf' & missing(`r_ev1')
    assert reldif(`r_r2a1', `r2a') < 1e-12 & reldif(`r_rmse1', `rmse') < 1e-12
    assert reldif(`r_F1', `F') < 1e-12 & missing(`r_F3')
}
if _rc == 0 {
    display as result "  PASS: R7 stats tokens events r2_a rmse F"
    local ++pass_count
}
else {
    display as error "  FAIL: R7 stats tokens (rc=`=_rc')"
    local ++fail_count
}

**# R8 methods sentence from the model

local _ci "with 95% confidence intervals from"
* Sentences that must not change
capture noisily {
    sysuse auto, clear
    foreach pair in ///
        "logit foreign mpg weight|Odds ratios `_ci' multivariable logistic regression." ///
        "poisson rep78 mpg weight|Incidence rate ratios `_ci' multivariable Poisson regression." ///
        "regress price mpg weight|Coefficients `_ci' multivariable linear regression." ///
        "mlogit rep78 mpg weight if rep78 >= 3|Relative risk ratios `_ci' multivariable multinomial logistic regression." {
        gettoken spec want : pair, parse("|")
        local want = substr(`"`want'"', 2, .)
        collect clear
        quietly collect: `spec'
        quietly regtab
        _rbl_methods `"`r(methods)'"' `"`want'"'
    }
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    foreach pair in ///
        "stcox age drug|Hazard ratios `_ci' multivariable Cox proportional hazards regression." ///
        "streg age drug, distribution(weibull)|Hazard ratios `_ci' multivariable parametric proportional hazards survival regression." ///
        "streg age drug, distribution(lognormal)|Time ratios `_ci' multivariable accelerated failure-time survival regression." {
        gettoken spec want : pair, parse("|")
        local want = substr(`"`want'"', 2, .)
        collect clear
        quietly collect: `spec'
        quietly regtab
        _rbl_methods `"`r(methods)'"' `"`want'"'
    }
}
if _rc == 0 {
    display as result "  PASS: R8a unchanged methods sentences"
    local ++pass_count
}
else {
    display as error "  FAIL: R8a unchanged methods sentences (rc=`=_rc')"
    local ++fail_count
}

* Sentences that must become accurate
capture noisily {
    sysuse auto, clear
    generate byte good = rep78 >= 4 if !missing(rep78)
    generate long obs = _n
    foreach pair in ///
        "probit foreign mpg weight|Coefficients `_ci' multivariable probit regression." ///
        "glm foreign mpg weight, family(binomial) link(probit)|Coefficients `_ci' multivariable probit regression." ///
        "nbreg rep78 mpg weight|Incidence rate ratios `_ci' multivariable negative binomial regression." ///
        "logit foreign mpg|Odds ratios `_ci' univariable logistic regression." ///
        "cloglog foreign mpg weight|Coefficients `_ci' multivariable complementary log-log regression." ///
        "glm foreign mpg weight, family(binomial) link(cloglog)|Coefficients `_ci' multivariable complementary log-log regression." ///
        "glm price mpg weight, family(gamma) link(log)|Coefficients `_ci' multivariable gamma regression with a log link." ///
        "zip rep78 mpg weight, inflate(foreign)|Coefficients `_ci' multivariable zero-inflated Poisson regression." ///
        "ologit rep78 mpg weight|Odds ratios `_ci' multivariable ordered logistic regression." {
        gettoken spec want : pair, parse("|")
        local want = substr(`"`want'"', 2, .)
        collect clear
        quietly collect: `spec'
        quietly regtab
        _rbl_methods `"`r(methods)'"' `"`want'"'
    }
    * coef()/cdisc relabels do not rename the model
    collect clear
    quietly collect: regress price mpg weight
    quietly regtab, coef(OR)
    _rbl_methods `"`r(methods)'"' "Coefficients `_ci' multivariable linear regression."
    collect clear
    quietly collect: logit foreign mpg weight
    quietly regtab, coef(Estimate)
    _rbl_methods `"`r(methods)'"' "Odds ratios `_ci' multivariable logistic regression."
    quietly regtab, cdisc
    local want "Odds ratios `_ci' multivariable logistic regression."
    _rbl_methods `"`r(methods)'"' `"`want'"'
    * one and two predictors
    collect clear
    quietly collect: logit foreign mpg
    quietly collect: logit foreign mpg weight
    quietly regtab
    _rbl_methods `"`r(methods)'"' ///
        "Odds ratios `_ci' univariable and multivariable logistic regression across 2 models."
    * a factor variable is one predictor
    collect clear
    quietly collect: logit foreign i.rep78
    quietly regtab
    _rbl_methods `"`r(methods)'"' "Odds ratios `_ci' univariable logistic regression."
    * GEE: binomial/logit is shown as odds ratios, as glm is (F1 in
    * test_followups_2026_09_27.do)
    quietly xtset rep78 obs
    collect clear
    quietly collect: xtgee foreign mpg weight, family(binomial) link(logit)
    quietly regtab
    _rbl_methods `"`r(methods)'"' ///
        "Odds ratios `_ci' multivariable generalized estimating equation (GEE) logistic regression."
    * mixed effects
    webuse pig, clear
    collect clear
    quietly collect: mixed weight week || id:
    quietly regtab, nore
    _rbl_methods `"`r(methods)'"' "Coefficients `_ci' univariable linear mixed-effects regression."
    webuse bangladesh, clear
    collect clear
    quietly collect: melogit c_use urban age || district:
    quietly regtab, nore
    _rbl_methods `"`r(methods)'"' "Odds ratios `_ci' multivariable mixed-effects logistic regression."
    * Fine-Gray
    webuse hypoxia, clear
    quietly stset dftime, failure(dfcens == 1)
    collect clear
    quietly collect: stcrreg ifp tumsize pelnode, compete(dfcens == 2)
    quietly regtab
    _rbl_methods `"`r(methods)'"' ///
        "Subhazard ratios `_ci' multivariable Fine-Gray competing-risks regression."
}
if _rc == 0 {
    display as result "  PASS: R8b methods sentences built from the model"
    local ++pass_count
}
else {
    display as error "  FAIL: R8b methods sentences (rc=`=_rc')"
    local ++fail_count
}

**# R9 unique r(table) row names

capture noisily {
    sysuse auto, clear
    label variable mpg "Same label"
    label variable weight "Same label"
    label variable length "Age (years)"
    label variable turn "Age [years]"
    label variable headroom "A label long enough to be truncated at 32 characters one"
    label variable trunk "A label long enough to be truncated at 32 characters two"
    collect clear
    quietly collect: regress price mpg weight length turn headroom trunk
    matrix bb = e(b)
    quietly regtab
    matrix T = r(table)
    local rn : rownames T
    local nr : word count `rn'
    local un : list uniq rn
    local nu : word count `un'
    assert `nr' == 7 & `nu' == 7
    local vars mpg weight length turn headroom trunk _cons
    forvalues j = 1/7 {
        local v : word `j' of `vars'
        assert reldif(T[`j', 1], bb[1, colnumb(bb, "`v'")]) < 1e-6
        local nm : word `j' of `rn'
        assert strlen("`nm'") <= 32
    }
    local n1 : word 1 of `rn'
    local n2 : word 2 of `rn'
    assert "`n1'" == "Same_label" & "`n2'" == "Same_label_2"
}
if _rc == 0 {
    display as result "  PASS: R9 r(table) row names unique and mapped to the right coefficient"
    local ++pass_count
}
else {
    display as error "  FAIL: R9 r(table) row names (rc=`=_rc')"
    local ++fail_count
}

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_regtab_backlog_2026_09_26 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _regtab_backlog
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_regtab_backlog_2026_09_26 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _regtab_backlog
