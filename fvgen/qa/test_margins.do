clear all
set varabbrev off
version 16.0

* Margins repost tests for fvgen.
do _fvgen_qa_common.do
_fvgen_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _fvgen_margins_family_data
program define _fvgen_margins_family_data
    version 16.0
    clear
    set seed 20260630
    set obs 1200
    generate long id = ceil(_n/4)
    bysort id: generate int t = _n
    generate byte g = ceil(3 * runiform())
    generate double x = rnormal()
    generate double xb = -0.4 + 0.25*(g == 2) - 0.15*(g == 3) ///
        + 0.55*x + 0.22*(g == 2)*x - 0.18*(g == 3)*x
    generate double yc = 1 + xb + rnormal()
    generate byte yb = runiform() < invlogit(xb)
    generate int yp = rpoisson(exp(0.7 + xb/3))
    generate int ynb = rnbinomial(2, 2/(2 + exp(0.7 + xb/3)))
    generate double yt = max(0, yc)
    generate byte yord = 1 + (xb + rnormal() > -0.4) + (xb + rnormal() > 0.7)
    generate byte ym = 1
    replace ym = 2 if xb + rnormal() > -0.2
    replace ym = 3 if xb + rnormal() > 1.0
    generate double w = runiform() + 0.5
    generate byte sub = runiform() > 0.15
    xtset id t
    svyset _n [pweight=w]
end

capture program drop _fvgen_margins_compare
program define _fvgen_margins_compare
    version 16.0
    syntax , Label(string) Native(string asis) Flat(string asis) ///
        Margins(string asis) [Tol(real 1e-8)]

    foreach L in native flat margins {
        local s = strtrim(`"``L''"')
        if substr(`"`s'"', 1, 1) == char(34) & ///
            substr(`"`s'"', strlen(`"`s'"'), 1) == char(34) {
            local s = substr(`"`s'"', 2, strlen(`"`s'"') - 2)
        }
        local `L' `"`s'"'
    }

    _fvgen_margins_family_data
    capture quietly `native'
    if _rc {
        local rc = _rc
        display as error "`label': native estimator failed (rc=`rc')"
        display as error `"`native'"'
        exit `rc'
    }
    capture quietly `margins'
    if _rc {
        local rc = _rc
        display as error "`label': native margins failed (rc=`rc')"
        display as error `"`margins'"'
        exit `rc'
    }
    tempname native_b native_v flat_b flat_v
    matrix `native_b' = r(b)
    matrix `native_v' = r(V)

    _fvgen_margins_family_data
    fvgen i.g##c.x, replace
    local av `r(allvars)'
    local flatcmd : subinstr local flat "@AV" "`av'", all
    capture quietly `flatcmd'
    if _rc {
        local rc = _rc
        display as error "`label': flattened estimator failed (rc=`rc')"
        display as error `"`flatcmd'"'
        exit `rc'
    }
    capture noisily fvgen, margins
    if _rc {
        local rc = _rc
        display as error "`label': fvgen margins clone failed (rc=`rc')"
        display as error `"`flatcmd'"'
        exit `rc'
    }
    capture quietly `margins'
    if _rc {
        local rc = _rc
        display as error "`label': clone margins failed (rc=`rc')"
        display as error `"`margins'"'
        exit `rc'
    }
    matrix `flat_b' = r(b)
    matrix `flat_v' = r(V)
    assert colsof(`flat_b') == colsof(`native_b')
    forvalues j = 1/`=colsof(`native_b')' {
        assert reldif(`native_b'[1, `j'], `flat_b'[1, `j']) < `tol'
    }
    assert rowsof(`flat_v') == rowsof(`native_v')
    assert colsof(`flat_v') == colsof(`native_v')
    forvalues i = 1/`=rowsof(`native_v')' {
        forvalues j = 1/`=colsof(`native_v')' {
            assert reldif(`native_v'[`i', `j'], `flat_v'[`i', `j']) < `tol'
        }
    }
end

**# 1. Active margins repost matches native factor-variable regress margins and VCE
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price i.foreign##c.mpg
    quietly margins, dydx(mpg) at(foreign=(0 1))
    matrix native = r(b)
    matrix nativeV = r(V)

    sysuse auto, clear
    fvgen i.foreign##c.mpg
    local av `r(allvars)'
    quietly regress price `av'
    fvgen, margins
    assert "`r(margins)'" == "active"
    local cn : colnames e(b)
    assert strpos(`"`cn'"', "0b.foreign") > 0
    assert strpos(`"`cn'"', "1.foreign#c.mpg") > 0

    quietly margins, dydx(mpg) at(foreign=(0 1))
    matrix flat = r(b)
    matrix flatV = r(V)
    assert colsof(flat) == colsof(native)
    forvalues j = 1/`=colsof(native)' {
        assert reldif(native[1, `j'], flat[1, `j']) < 1e-10
    }
    assert rowsof(flatV) == rowsof(nativeV)
    assert colsof(flatV) == colsof(nativeV)
    forvalues i = 1/`=rowsof(nativeV)' {
        forvalues j = 1/`=colsof(nativeV)' {
            assert reldif(nativeV[`i', `j'], flatV[`i', `j']) < 1e-10
        }
    }
}
if _rc == 0 {
    display as result "  PASS: margins repost matches native regress margins and VCE"
    local ++pass_count
}
else {
    display as error "  FAIL: margins repost estimate/VCE equivalence (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**# 2. store() preserves active flattened estimates and stores a margins-ready clone
local ++test_count
capture noisily {
    sysuse auto, clear
    fvgen i.foreign##c.mpg
    local av `r(allvars)'
    quietly regress price `av'
    local flatnames : colnames e(b)
    capture estimates drop fvmargins

    fvgen, margins store(fvmargins)
    assert "`r(margins)'" == "stored"
    assert "`r(stored)'" == "fvmargins"
    local active_names : colnames e(b)
    assert `"`active_names'"' == `"`flatnames'"'

    estimates restore fvmargins
    local stored_names : colnames e(b)
    assert strpos(`"`stored_names'"', "0b.foreign") > 0
    assert strpos(`"`stored_names'"', "1.foreign#c.mpg") > 0
    quietly margins foreign
    estimates drop fvmargins
}
if _rc == 0 {
    display as result "  PASS: store() keeps active estimate flattened"
    local ++pass_count
}
else {
    display as error "  FAIL: store() active-restore contract (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**# 3. store() replace refreshes an existing margins-ready clone
local ++test_count
capture noisily {
    sysuse auto, clear
    fvgen i.foreign##c.mpg
    quietly regress price `r(allvars)'
    capture estimates drop fvmargins
    fvgen, margins store(fvmargins)
    fvgen, margins store(fvmargins) replace
    assert "`r(margins)'" == "stored"
    assert "`r(stored)'" == "fvmargins"
    estimates restore fvmargins
    quietly margins, dydx(mpg) over(foreign)
    estimates drop fvmargins
}
if _rc == 0 {
    display as result "  PASS: store() replace refreshes stored clone"
    local ++pass_count
}
else {
    display as error "  FAIL: store() replace (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**# 4. center-generated models are refused for margins repost
local ++test_count
capture noisily {
    sysuse auto, clear
    fvgen c.mpg##c.weight, center
    quietly regress price `r(allvars)'
    capture fvgen, margins
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: center margins repost refused"
    local ++pass_count
}
else {
    display as error "  FAIL: center refusal (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**# 5. Logit margins clone matches the native factor-variable fit and VCE
local ++test_count
capture noisily {
    clear
    set seed 123456
    set obs 1000
    generate byte g = ceil(3 * runiform())
    generate double x = rnormal()
    generate double xb = -0.5 + 0.3*(g == 2) - 0.2*(g == 3) ///
        + 0.5*x + 0.4*(g == 2)*x - 0.3*(g == 3)*x
    generate byte y = runiform() < invlogit(xb)

    quietly logit y i.g##c.x, vce(robust)
    quietly margins g
    matrix native = r(b)
    matrix nativeV = r(V)

    fvgen i.g##c.x
    local av `r(allvars)'
    quietly logit y `av', vce(robust)
    fvgen, margins
    assert "`e(cmd)'" == "logit"
    assert "`e(vce)'" == "robust"
    quietly margins g
    matrix flat = r(b)
    matrix flatV = r(V)
    assert colsof(flat) == colsof(native)
    forvalues j = 1/`=colsof(native)' {
        assert reldif(native[1, `j'], flat[1, `j']) < 1e-10
    }
    assert rowsof(flatV) == rowsof(nativeV)
    assert colsof(flatV) == colsof(nativeV)
    forvalues i = 1/`=rowsof(nativeV)' {
        forvalues j = 1/`=colsof(nativeV)' {
            assert reldif(nativeV[`i', `j'], flatV[`i', `j']) < 1e-10
        }
    }
}
if _rc == 0 {
    display as result "  PASS: logit margins clone matches native fit and VCE"
    local ++pass_count
}
else {
    display as error "  FAIL: logit margins clone (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

**# 6. Poisson margins clone matches the native factor-variable fit and VCE
local ++test_count
capture noisily {
    clear
    set seed 654321
    set obs 900
    generate byte g = ceil(3 * runiform())
    generate double x = rnormal()
    generate double xb = 0.2 + 0.25*(g == 2) - 0.15*(g == 3) ///
        + 0.15*x + 0.1*(g == 2)*x - 0.08*(g == 3)*x
    generate int y = rpoisson(exp(xb))

    quietly poisson y i.g##c.x, vce(robust)
    quietly margins, dydx(x) at(g=(1 2 3))
    matrix native = r(b)
    matrix nativeV = r(V)

    fvgen i.g##c.x
    local av `r(allvars)'
    quietly poisson y `av', vce(robust)
    fvgen, margins store(fvpois)
    local active_names : colnames e(b)
    assert strpos(`"`active_names'"', "_gXx_2") > 0
    estimates restore fvpois
    assert "`e(cmd)'" == "poisson"
    assert "`e(vce)'" == "robust"
    quietly margins, dydx(x) at(g=(1 2 3))
    matrix flat = r(b)
    matrix flatV = r(V)
    assert colsof(flat) == colsof(native)
    forvalues j = 1/`=colsof(native)' {
        assert reldif(native[1, `j'], flat[1, `j']) < 1e-10
    }
    assert rowsof(flatV) == rowsof(nativeV)
    assert colsof(flatV) == colsof(nativeV)
    forvalues i = 1/`=rowsof(nativeV)' {
        forvalues j = 1/`=colsof(nativeV)' {
            assert reldif(nativeV[`i', `j'], flatV[`i', `j']) < 1e-10
        }
    }
    estimates drop fvpois
}
if _rc == 0 {
    display as result "  PASS: poisson margins clone matches native fit and VCE"
    local ++pass_count
}
else {
    display as error "  FAIL: poisson margins clone (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

**# 7. Survey prefix with comma options is rerun through the native command line
local ++test_count
capture noisily {
    clear
    set seed 24680
    set obs 800
    generate byte g = ceil(3 * runiform())
    generate double x = rnormal()
    generate double w = runiform() + 0.5
    generate byte sub = runiform() > 0.15
    generate double y = 1 + 0.25*(g == 2) - 0.10*(g == 3) ///
        + 0.6*x + 0.20*(g == 2)*x - 0.15*(g == 3)*x + rnormal()
    svyset _n [pweight=w]

    quietly svy, subpop(sub): regress y i.g##c.x
    quietly margins, dydx(x) at(g=(1 2 3))
    matrix native = r(b)
    matrix nativeV = r(V)

    fvgen i.g##c.x
    local av `r(allvars)'
    quietly svy, subpop(sub): regress y `av'
    fvgen, margins
    assert strpos(`"`e(fvgen_flat_cmdline)'"', "svy") > 0
    assert strpos(`"`e(fvgen_flat_cmdline)'"', "subpop") > 0
    assert strpos(`"`e(fvgen_native_cmdline)'"', "i.g") > 0
    assert strpos(`"`e(fvgen_native_cmdline)'"', "i.g#c.x") > 0
    assert strpos(`"`e(fvgen_native_cmdline)'"', "_gXx_2") == 0
    quietly margins, dydx(x) at(g=(1 2 3))
    matrix flat = r(b)
    matrix flatV = r(V)
    assert colsof(flat) == colsof(native)
    forvalues j = 1/`=colsof(native)' {
        assert reldif(native[1, `j'], flat[1, `j']) < 1e-8
    }
    assert rowsof(flatV) == rowsof(nativeV)
    assert colsof(flatV) == colsof(nativeV)
    forvalues i = 1/`=rowsof(nativeV)' {
        forvalues j = 1/`=colsof(nativeV)' {
            assert reldif(nativeV[`i', `j'], flatV[`i', `j']) < 1e-8
        }
    }
}
if _rc == 0 {
    display as result "  PASS: svy prefix margins clone matches native fit and VCE"
    local ++pass_count
}
else {
    display as error "  FAIL: svy prefix margins clone (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}

**# 8. Broad estimator-family matrix matches native factor-variable margins
local ++test_count
capture noisily {
    _fvgen_margins_compare, label("regress") ///
        native("regress yc i.g##c.x") ///
        flat("regress yc @AV") ///
        margins("margins, dydx(x) at(g=(1 2 3))")
    _fvgen_margins_compare, label("glm gaussian") ///
        native("glm yc i.g##c.x, family(gaussian) link(identity)") ///
        flat("glm yc @AV, family(gaussian) link(identity)") ///
        margins("margins, dydx(x) at(g=(1 2 3))")
    _fvgen_margins_compare, label("qreg") ///
        native("qreg yc i.g##c.x") ///
        flat("qreg yc @AV") ///
        margins("margins, dydx(x) at(g=(1 2 3))") tol(1e-7)
    _fvgen_margins_compare, label("rreg") ///
        native("rreg yc i.g##c.x") ///
        flat("rreg yc @AV") ///
        margins("margins, dydx(x) at(g=(1 2 3))") tol(1e-7)
    _fvgen_margins_compare, label("logit") ///
        native("logit yb i.g##c.x, vce(robust)") ///
        flat("logit yb @AV, vce(robust)") ///
        margins("margins, dydx(x) at(g=(1 2 3))")
    _fvgen_margins_compare, label("logistic") ///
        native("logistic yb i.g##c.x, vce(robust)") ///
        flat("logistic yb @AV, vce(robust)") ///
        margins("margins, dydx(x) at(g=(1 2 3))")
    _fvgen_margins_compare, label("probit") ///
        native("probit yb i.g##c.x, vce(robust)") ///
        flat("probit yb @AV, vce(robust)") ///
        margins("margins, dydx(x) at(g=(1 2 3))")
    _fvgen_margins_compare, label("cloglog") ///
        native("cloglog yb i.g##c.x, vce(robust)") ///
        flat("cloglog yb @AV, vce(robust)") ///
        margins("margins, dydx(x) at(g=(1 2 3))")
    _fvgen_margins_compare, label("glm binomial logit") ///
        native("glm yb i.g##c.x, family(binomial) link(logit) vce(robust)") ///
        flat("glm yb @AV, family(binomial) link(logit) vce(robust)") ///
        margins("margins, dydx(x) at(g=(1 2 3))")
    _fvgen_margins_compare, label("poisson") ///
        native("poisson yp i.g##c.x, vce(robust)") ///
        flat("poisson yp @AV, vce(robust)") ///
        margins("margins, dydx(x) at(g=(1 2 3))")
    _fvgen_margins_compare, label("nbreg") ///
        native("nbreg ynb i.g##c.x") ///
        flat("nbreg ynb @AV") ///
        margins("margins, dydx(x) at(g=(1 2 3))") tol(1e-7)
    _fvgen_margins_compare, label("glm poisson") ///
        native("glm yp i.g##c.x, family(poisson) link(log) vce(robust)") ///
        flat("glm yp @AV, family(poisson) link(log) vce(robust)") ///
        margins("margins, dydx(x) at(g=(1 2 3))")
    _fvgen_margins_compare, label("tobit") ///
        native("tobit yt i.g##c.x, ll(0)") ///
        flat("tobit yt @AV, ll(0)") ///
        margins("margins, dydx(x) at(g=(1 2 3))") tol(1e-7)
    _fvgen_margins_compare, label("ologit") ///
        native("ologit yord i.g##c.x") ///
        flat("ologit yord @AV") ///
        margins("margins, dydx(x) at(g=(1 2 3)) predict(outcome(2))") tol(1e-7)
    _fvgen_margins_compare, label("oprobit") ///
        native("oprobit yord i.g##c.x") ///
        flat("oprobit yord @AV") ///
        margins("margins, dydx(x) at(g=(1 2 3)) predict(outcome(2))") tol(1e-7)
    _fvgen_margins_compare, label("mlogit") ///
        native("mlogit ym i.g##c.x, baseoutcome(1)") ///
        flat("mlogit ym @AV, baseoutcome(1)") ///
        margins("margins, dydx(x) at(g=(1 2 3)) predict(outcome(2))") tol(1e-7)
    _fvgen_margins_compare, label("xtreg re") ///
        native("xtreg yc i.g##c.x, re") ///
        flat("xtreg yc @AV, re") ///
        margins("margins, dydx(x) at(g=(1 2 3))") tol(1e-7)
    _fvgen_margins_compare, label("svy regress") ///
        native("svy, subpop(sub): regress yc i.g##c.x") ///
        flat("svy, subpop(sub): regress yc @AV") ///
        margins("margins, dydx(x) at(g=(1 2 3))") tol(1e-7)
}
if _rc == 0 {
    display as result "  PASS: broad estimator-family matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: broad estimator-family matrix (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}

**# 9. drop clears dataset-level margins provenance
local ++test_count
capture noisily {
    sysuse auto, clear
    fvgen i.foreign##c.mpg
    assert `"`: char _dta[fvgen_terms]'"' != ""
    fvgen, drop
    assert `"`: char _dta[fvgen_terms]'"' == ""
    quietly regress price mpg foreign
    capture fvgen, margins
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: drop clears margins provenance"
    local ++pass_count
}
else {
    display as error "  FAIL: drop provenance cleanup (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}

**# 10. failed generation clears stale margins provenance
local ++test_count
capture noisily {
    sysuse auto, clear
    fvgen i.foreign##c.mpg
    assert `"`: char _dta[fvgen_terms]'"' != ""
    capture fvgen i.foreign##c.mpg, vsref("bad template")
    assert _rc == 198
    assert `"`: char _dta[fvgen_terms]'"' == ""
    quietly regress price mpg foreign
    capture fvgen, margins
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: generation error clears stale margins provenance"
    local ++pass_count
}
else {
    display as error "  FAIL: failed-generation provenance cleanup (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10"
}

**# Summary
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED:`failed_tests'"
    display "RESULT: test_margins tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_margins tests=`test_count' pass=`pass_count' fail=`fail_count'"
