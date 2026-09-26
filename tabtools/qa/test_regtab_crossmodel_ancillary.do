* test_regtab_crossmodel_ancillary.do - a covariate and another model's
* ancillary parameter of the same name keep their own rows
* Regression suite, written against commit f42ee9cd (tabtools 2.1.12) before
* the fix (R-tabtools quirks Addendum 9, item 15). 2.1.12 moved an ancillary
* or cutpoint item to a private row only when the same model also had a
* covariate of that name; across models the one colname row held model 1's
* covariate and model 2's ancillary parameter side by side.
*   X1  poisson with a covariate alpha beside an nbreg: the covariate row and
*       nbreg's derived alpha row are separate, each blank in the other model
*   X2  the same with the models in the reverse order
*   X3  regress with a covariate cut1 beside an ologit: the cutpoint cut1 is
*       its own row, next to cut2
*   X4  without keepintercept the ancillary row is dropped and the covariate
*       row is unchanged; the user's collection is left as it was
*   X5  one Weibull model with covariates ln_p and p: the two private
*       ancillary rows follow the covariates, in the order ln_p, p, 1/p
*       (2.1.12 anchored each to the other, so both floated up)
*   X6  a regress with covariates ln_p and p beside a Weibull: covariate rows
*       first, then the ancillary block
* Expected values come from each fit's own e(b), never from the output under
* test.

clear all
set more off
set varabbrev off
version 17.0

capture log close _xa
log using "test_regtab_crossmodel_ancillary.log", replace text name(_xa)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

* The text a table prints for x at digits(2).
capture program drop _xa_fmt
program define _xa_fmt, rclass
    version 17.0
    args x
    return local s = strtrim(string(round(`x', 0.01), "%32.2f"))
end

* Body row numbers (frame observation numbers) whose trimmed label is
* `label', in order, and how many there are.
capture program drop _xa_rows
program define _xa_rows, rclass
    version 17.0
    args frname label
    local rows ""
    frame `frname' {
        forvalues r = 4/`=_N' {
            if strtrim(A[`r']) == `"`label'"' local rows "`rows' `r'"
        }
    }
    return local rows "`rows'"
    return scalar n = `: word count `rows''
end

* Assert frame row `r' has in column `col' the formatted value x ("" for an
* empty cell).
capture program drop _xa_at
program define _xa_at
    version 17.0
    args frname r col x
    local want ""
    if `"`x'"' != "" {
        _xa_fmt `x'
        local want "`r(s)'"
    }
    frame `frname': local got = strtrim(`col'[`r'])
    if `"`got'"' != "`want'" {
        frame `frname': local lab = strtrim(A[`r'])
        display as error `"row `r' (`lab') `col': got "`got'", want "`want'""'
        exit 9
    }
end

* Label of frame row `r'.
capture program drop _xa_label
program define _xa_label, rclass
    version 17.0
    args frname r
    frame `frname': local lab = strtrim(A[`r'])
    return local label `"`lab'"'
end

**# X1 poisson covariate alpha beside nbreg's ancillary alpha
capture noisily {
    webuse rod93, clear
    generate alpha = age_mos / 100
    collect clear
    quietly collect: poisson deaths alpha
    matrix b1 = e(b)
    quietly collect: nbreg deaths age_mos
    matrix b2 = e(b)
    local irr = exp(b1[1, colnumb(b1, "deaths:alpha")])
    local lna = b2[1, colnumb(b2, "/:lnalpha")]
    capture frame drop _xa
    quietly regtab, keepintercept frame(_xa, replace)
    _xa_rows _xa "alpha"
    assert r(n) == 2
    local rc_ = word("`r(rows)'", 1)
    local ra_ = word("`r(rows)'", 2)
    * the covariate row: model 1's IRR, empty in model 2
    _xa_at _xa `rc_' c1 `irr'
    _xa_at _xa `rc_' c4 ""
    * the ancillary row: empty in model 1, nbreg's alpha, right after lnalpha
    _xa_at _xa `ra_' c1 ""
    _xa_at _xa `ra_' c4 `=exp(`lna')'
    _xa_label _xa `=`ra_' - 1'
    assert "`r(label)'" == "lnalpha"
    _xa_at _xa `=`ra_' - 1' c4 `lna'
    _xa_label _xa `=`ra_' + 1'
    assert "`r(label)'" == "Intercept"
}
if _rc == 0 {
    display as result "  PASS: X1 poisson covariate alpha and nbreg alpha on separate rows"
    local ++pass_count
}
else {
    display as error "  FAIL: X1 poisson + nbreg alpha rows (rc=`=_rc')"
    local ++fail_count
}

**# X2 the same, nbreg first
capture noisily {
    webuse rod93, clear
    generate alpha = age_mos / 100
    collect clear
    quietly collect: nbreg deaths age_mos
    matrix b1 = e(b)
    quietly collect: poisson deaths alpha
    matrix b2 = e(b)
    local lna = b1[1, colnumb(b1, "/:lnalpha")]
    local irr = exp(b2[1, colnumb(b2, "deaths:alpha")])
    capture frame drop _xa
    quietly regtab, keepintercept frame(_xa, replace)
    _xa_rows _xa "alpha"
    assert r(n) == 2
    local r1 = word("`r(rows)'", 1)
    local r2 = word("`r(rows)'", 2)
    * exactly one of the two rows is the covariate and one the ancillary alpha
    foreach r in `r1' `r2' {
        frame _xa: local c1_ = strtrim(c1[`r'])
        if "`c1_'" == "" {
            _xa_at _xa `r' c4 `irr'
            local rcov `r'
        }
        else {
            _xa_at _xa `r' c1 `=exp(`lna')'
            _xa_at _xa `r' c4 ""
            local ranc `r'
        }
    }
    assert "`rcov'" != "" & "`ranc'" != ""
    _xa_label _xa `=`ranc' - 1'
    assert "`r(label)'" == "lnalpha"
}
if _rc == 0 {
    display as result "  PASS: X2 nbreg first: alpha rows still separate"
    local ++pass_count
}
else {
    display as error "  FAIL: X2 nbreg + poisson alpha rows (rc=`=_rc')"
    local ++fail_count
}

**# X3 regress covariate cut1 beside ologit's cutpoint cut1
capture noisily {
    sysuse auto, clear
    generate cut1 = mpg
    collect clear
    quietly collect: regress price cut1 weight
    matrix b1 = e(b)
    quietly collect: ologit rep78 weight
    matrix b2 = e(b)
    local bc = b1[1, colnumb(b1, "cut1")]
    local k1 = b2[1, colnumb(b2, "/:cut1")]
    local k2 = b2[1, colnumb(b2, "/:cut2")]
    capture frame drop _xa
    quietly regtab, keepintercept frame(_xa, replace)
    _xa_rows _xa "cut1"
    assert r(n) == 2
    local rc_ = word("`r(rows)'", 1)
    local rk_ = word("`r(rows)'", 2)
    _xa_at _xa `rc_' c1 `bc'
    _xa_at _xa `rc_' c4 ""
    _xa_at _xa `rk_' c1 ""
    _xa_at _xa `rk_' c4 `k1'
    _xa_label _xa `=`rk_' + 1'
    assert "`r(label)'" == "cut2"
    _xa_at _xa `=`rk_' + 1' c4 `k2'
}
if _rc == 0 {
    display as result "  PASS: X3 regress covariate cut1 and ologit cut1 on separate rows"
    local ++pass_count
}
else {
    display as error "  FAIL: X3 regress + ologit cut1 rows (rc=`=_rc')"
    local ++fail_count
}

**# X4 without keepintercept; the collection is untouched
capture noisily {
    webuse rod93, clear
    generate alpha = age_mos / 100
    collect clear
    quietly collect: poisson deaths alpha
    matrix b1 = e(b)
    quietly collect: nbreg deaths age_mos
    local irr = exp(b1[1, colnumb(b1, "deaths:alpha")])
    quietly collect levelsof colname
    local lev0 `"`s(levels)'"'
    capture frame drop _xa
    quietly regtab, frame(_xa, replace)
    _xa_rows _xa "alpha"
    assert r(n) == 1
    local r = trim("`r(rows)'")
    _xa_at _xa `r' c1 `irr'
    _xa_at _xa `r' c4 ""
    _xa_rows _xa "lnalpha"
    assert r(n) == 0
    frame _xa: assert _N == 3 + 2
    quietly collect levelsof colname
    assert `"`s(levels)'"' == `"`lev0'"'
    quietly collect dims
    assert "`s(collection)'" == "default"
}
if _rc == 0 {
    display as result "  PASS: X4 no keepintercept: covariate row only; collection unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: X4 no keepintercept / collection state (rc=`=_rc')"
    local ++fail_count
}

**# X5 one Weibull model with covariates ln_p and p (two adjacent private rows)
* 2.1.12 anchored each of the two private ancillary rows to the other, so
* neither was placed and both floated up among the covariates.
capture noisily {
    webuse kva, clear
    quietly stset failtime
    generate ln_p = load / 10
    generate p = bearings
    collect clear
    quietly collect: streg ln_p p, distribution(weibull)
    matrix b = e(b)
    local hln = exp(b[1, colnumb(b, "_t:ln_p")])
    local hp = exp(b[1, colnumb(b, "_t:p")])
    local lnp = b[1, colnumb(b, "/:ln_p")]
    capture frame drop _xa
    quietly regtab, keepintercept frame(_xa, replace)
    frame _xa: assert _N == 3 + 6
    local want "ln_p p ln_p p 1/p Intercept"
    local vals "`hln' `hp' `lnp' `=exp(`lnp')' `=exp(-`lnp')'"
    forvalues k = 1/5 {
        _xa_label _xa `=`k' + 3'
        assert "`r(label)'" == "`: word `k' of `want''"
        _xa_at _xa `=`k' + 3' c1 `: word `k' of `vals''
    }
    _xa_label _xa 9
    assert "`r(label)'" == "Intercept"
}
if _rc == 0 {
    display as result "  PASS: X5 Weibull covariates ln_p and p: ancillary rows after the covariates"
    local ++pass_count
}
else {
    display as error "  FAIL: X5 Weibull ln_p/p row order (rc=`=_rc')"
    local ++fail_count
}

**# X6 regress covariates ln_p and p beside a Weibull
capture noisily {
    webuse kva, clear
    quietly stset failtime
    generate ln_p = load / 10
    generate p = bearings
    collect clear
    quietly collect: regress failtime ln_p p
    matrix b1 = e(b)
    quietly collect: streg load bearings, distribution(weibull)
    matrix b2 = e(b)
    local lnp = b2[1, colnumb(b2, "/:ln_p")]
    capture frame drop _xa
    quietly regtab, keepintercept frame(_xa, replace)
    * ln_p, p (regress), Overload, Has new bearings (streg), then the
    * ancillary block ln_p, p, 1/p and the intercept
    frame _xa: assert _N == 3 + 8
    _xa_label _xa 4
    assert "`r(label)'" == "ln_p"
    _xa_at _xa 4 c1 `=b1[1, colnumb(b1, "ln_p")]'
    _xa_at _xa 4 c4 ""
    _xa_label _xa 5
    assert "`r(label)'" == "p"
    _xa_at _xa 5 c1 `=b1[1, colnumb(b1, "p")]'
    _xa_at _xa 5 c4 ""
    local want "ln_p p 1/p Intercept"
    local vals "`lnp' `=exp(`lnp')' `=exp(-`lnp')'"
    forvalues k = 1/4 {
        _xa_label _xa `=`k' + 7'
        assert "`r(label)'" == "`: word `k' of `want''"
    }
    forvalues k = 1/3 {
        _xa_at _xa `=`k' + 7' c1 ""
        _xa_at _xa `=`k' + 7' c4 `: word `k' of `vals''
    }
}
if _rc == 0 {
    display as result "  PASS: X6 regress ln_p/p and Weibull ancillary rows kept apart and in order"
    local ++pass_count
}
else {
    display as error "  FAIL: X6 regress + Weibull ln_p/p rows (rc=`=_rc')"
    local ++fail_count
}

**# Summary
capture frame drop _xa
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_regtab_crossmodel_ancillary tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _xa
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_regtab_crossmodel_ancillary tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _xa
