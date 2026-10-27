* crossval_finegray_published_stcrreg.do
* Published reproduction: finegray against the numbers PRINTED in the Stata
* manual's [ST] stcrreg and [ST] stcrreg postestimation entries (Stata 19
* manuals, st.pdf), on the same StataCorp example datasets.
*
* SOURCES (read 2026-10-27 through _devkit/automation/stata_docs.sh):
*   M1  [ST] stcrreg, Example 1, pp.192-193 (hypoxia; Pintilie 2006 cervical cancer data):
*       `stcrreg ifp tumsize pelnode, compete(failtype == 2)', the SHR table
*       and the `noshr' replay table, log pseudolikelihood, Wald chi2, counts.
*   M2  [ST] stcrreg, Example 3, p.196 (udca; Lindor et al. 1994 UDCA trial):
*       `stcrreg treat lbili stage [iw=wt], compete(etype == 1 2 4 5 6 7 8)
*       vce(cluster id)' with origin(entry).
*   M3  [ST] stcrreg postestimation, Example 1, p.216 (hypoxia): the listed
*       `predict bch, basecsh' and `predict bcif, basecif' values, rows 1-15.
*   M4  the same baseline CIF through finegray_cif's analytic CIF.
* Not reproduced here: [ST] stcrreg Example 4 (hiv_si), whose printed ccr5
* lower limit is stcrreg's default-convergence answer and differs from the
* exact maximizer by 5e-8, and the Example 2 CIFs, which are given in prose
* only ("near 40%").
*
* WHICH VARIANCE THE PRINTED STANDARD ERRORS ARE. stcrreg's robust variance
* is the Fine-Gray (1999) sandwich with the estimated-censoring psi term,
* which is finegray's `nuisance' variance (crossval_finegray.do C10b: equal to
* 1e-9 on untied data).  So the printed SEs, CIs and Wald statistics are
* compared ONLY on `nuisance' fits.  The default fixed-weight sandwich and the
* `norobust' model-based variance share the point estimates and the objective,
* which are compared on those fits too; their SEs are a different estimator
* and are displayed for the record, never gated.
*
* M2 WEIGHTS. stcrreg treats the udca importance weights (1, 1/2, 1/3, 1/4)
* "like frequency weights" ([ST] stcrreg, Example 3).  finegray refuses
* iweights and refuses any weight with `nuisance', so the records are
* expanded by 12*wt, an exact integer.  A common rescaling of every weight
* leaves the censoring Kaplan-Meier and the score roots unchanged, so the
* printed SHRs are gated.  Two printed quantities map through exact algebra:
*   counts: stcrreg prints the weighted counts rounded to integers (No.
*     failed 13 is 12.67 = 152/12), so round(e(N_fail)/12) is gated;
*   log pseudolikelihood: under w -> 12w the Breslow log likelihood becomes
*     12*ll(w) - 12*ln(12)*sum(w*d), so e(ll)/12 + ln(12)*e(N_fail)/12 is
*     gated against the printed -61.669225.
* The printed clustered SEs (and the Wald chi2 built from them) are NOT
* gated.  They are stcrreg's iweight variance, which is not frequency
* equivalent: stcrreg itself, run on the same 12*wt-expanded records with
* vce(cluster id), returns SHR SEs .3053109 / .3366598 / .3151849, not the
* printed .3238038 / .367095 / .3305371 (measured 2026-10-27, Stata 17).
* finegray refuses iweights, so no finegray route targets the printed SEs;
* they are displayed beside finegray's for the record.
*
* TOLERANCES. A printed number d with k decimals is matched when
* |finegray - d| <= 0.5*10^-k (half a unit in the last printed digit) plus
* 1e-12 for binary representation.  That is the tightest test the printed
* precision supports; no tolerance is wider than the print.
*
* NETWORK. The datasets come from webuse.  hypoxia is cached in c(tmpdir)
* under the name the other finegray suites use; hiv_si and udca are fetched
* on every run.

clear all
set more off
set varabbrev off
version 16.0
set type double

capture log close _all
log using "crossval_finegray_published_stcrreg.log", replace text name(_cvpubst)

**# Setup
local pkgroot "`c(pwd)'"
capture confirm file "`pkgroot'/finegray.pkg"
if _rc {
    capture confirm file "`pkgroot'/../finegray.pkg"
    if _rc {
        display as error "could not locate finegray package root"
        exit 601
    }
    local pkgroot "`pkgroot'/.."
}
capture ado uninstall finegray
quietly net install finegray, from("`pkgroot'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0
local failed_tests ""

* One printed number against one finegray quantity.  Prints the gap; counts a
* miss in $FGPUB_BAD so a block reports every number before it fails.
capture program drop _fgpub_near
program define _fgpub_near
    syntax , Label(string) Actual(string) Printed(real) DP(integer)
    tempname a
    scalar `a' = `actual'
    local tol = 0.5 * 10^(-`dp') + 1e-12
    local gap = abs(`a' - `printed')
    local verdict "ok"
    if missing(`a') | !(`gap' <= `tol') {
        local verdict "MISS"
        global FGPUB_BAD = $FGPUB_BAD + 1
    }
    display as text "    `label': finegray " %16.10g `a' "  printed " ///
        %12.0g `printed' "  |gap| " %9.2e `gap' "  tol " %9.2e `tol' "  `verdict'"
end

capture program drop _fgpub_hypoxia
program define _fgpub_hypoxia
    local cache "`c(tmpdir)'/finegray_hypoxia_cache.dta"
    capture confirm file "`cache'"
    if _rc {
        webuse hypoxia, clear
        quietly save "`cache'", replace
    }
    else {
        use "`cache'", clear
    }
end

local z = invnormal(0.975)

**# M1: [ST] stcrreg Example 1, hypoxia, counts / coefficients / nuisance SE / ll / Wald
local ++test_count
global FGPUB_BAD = 0
capture noisily {
    _fgpub_hypoxia
    assert _N == 109
    stset dftime, failure(failtype)
    finegray ifp tumsize pelnode, compete(failtype) cause(1) nuisance nolog
    assert e(converged) == 1
    assert "`e(vce_meat)'" == "nuisance_adjusted"
    assert e(N) == 109
    assert e(N_fail) == 33
    assert e(N_compete) == 17
    assert e(N_cens) == 59

    * noshr table (coefficient scale)
    _fgpub_near, l("ifp b")      a(_b[ifp])      p(.0326664)  dp(7)
    _fgpub_near, l("tumsize b")  a(_b[tumsize])  p(.2603096)  dp(7)
    _fgpub_near, l("pelnode b")  a(_b[pelnode])  p(-.779114)  dp(6)
    _fgpub_near, l("ifp se")     a(_se[ifp])     p(.0173188)  dp(7)
    _fgpub_near, l("tumsize se") a(_se[tumsize]) p(.0979851)  dp(7)
    _fgpub_near, l("pelnode se") a(_se[pelnode]) p(.4298199)  dp(7)
    _fgpub_near, l("ifp lb")     a(_b[ifp]-`z'*_se[ifp])         p(-.0012777) dp(7)
    _fgpub_near, l("ifp ub")     a(_b[ifp]+`z'*_se[ifp])         p(.0666105)  dp(7)
    _fgpub_near, l("tumsize lb") a(_b[tumsize]-`z'*_se[tumsize]) p(.0682623)  dp(7)
    _fgpub_near, l("tumsize ub") a(_b[tumsize]+`z'*_se[tumsize]) p(.4523568)  dp(7)
    _fgpub_near, l("pelnode lb") a(_b[pelnode]-`z'*_se[pelnode]) p(-1.621546) dp(6)
    _fgpub_near, l("pelnode ub") a(_b[pelnode]+`z'*_se[pelnode]) p(.0633175)  dp(7)

    * SHR table (delta-method SE, exponentiated limits, as stcrreg prints)
    _fgpub_near, l("ifp SHR")        a(exp(_b[ifp]))                 p(1.033206)  dp(6)
    _fgpub_near, l("tumsize SHR")    a(exp(_b[tumsize]))             p(1.297332)  dp(6)
    _fgpub_near, l("pelnode SHR")    a(exp(_b[pelnode]))             p(.4588123)  dp(7)
    _fgpub_near, l("ifp SHR se")     a(exp(_b[ifp])*_se[ifp])         p(.0178938)  dp(7)
    _fgpub_near, l("tumsize SHR se") a(exp(_b[tumsize])*_se[tumsize]) p(.1271191)  dp(7)
    _fgpub_near, l("pelnode SHR se") a(exp(_b[pelnode])*_se[pelnode]) p(.1972067)  dp(7)
    _fgpub_near, l("ifp SHR lb")     a(exp(_b[ifp]-`z'*_se[ifp]))         p(.9987231) dp(7)
    _fgpub_near, l("ifp SHR ub")     a(exp(_b[ifp]+`z'*_se[ifp]))         p(1.068879) dp(6)
    _fgpub_near, l("tumsize SHR lb") a(exp(_b[tumsize]-`z'*_se[tumsize])) p(1.070646) dp(6)
    _fgpub_near, l("tumsize SHR ub") a(exp(_b[tumsize]+`z'*_se[tumsize])) p(1.572013) dp(6)
    _fgpub_near, l("pelnode SHR lb") a(exp(_b[pelnode]-`z'*_se[pelnode])) p(.1975931) dp(7)
    _fgpub_near, l("pelnode SHR ub") a(exp(_b[pelnode]+`z'*_se[pelnode])) p(1.065365) dp(6)

    _fgpub_near, l("log pseudolikelihood") a(e(ll))   p(-138.5308) dp(4)
    _fgpub_near, l("Wald chi2(3)")         a(e(chi2)) p(33.21)     dp(2)
    assert e(df_m) == 3

    * Same printed point estimates and objective under the other two variances.
    foreach v in default norobust {
        local vopt = cond("`v'" == "default", "", "norobust")
        quietly finegray ifp tumsize pelnode, compete(failtype) cause(1) `vopt' nolog
        assert e(converged) == 1
        _fgpub_near, l("`v' ifp b")     a(_b[ifp])     p(.0326664) dp(7)
        _fgpub_near, l("`v' tumsize b") a(_b[tumsize]) p(.2603096) dp(7)
        _fgpub_near, l("`v' pelnode b") a(_b[pelnode]) p(-.779114) dp(6)
        _fgpub_near, l("`v' ll")        a(e(ll))       p(-138.5308) dp(4)
        display as text "    `v' SE (not gated; a different variance estimator): " ///
            %9.7f _se[ifp] " " %9.7f _se[tumsize] " " %9.7f _se[pelnode]
    }
    assert $FGPUB_BAD == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: M1 hypoxia [ST] stcrreg Example 1 reproduced at printed precision"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' M1"
    display as error "  FAIL: M1 hypoxia [ST] stcrreg Example 1 (rc=`=_rc', misses=$FGPUB_BAD)"
}

**# M2: [ST] stcrreg Example 3, udca, cluster(id) SHRs, counts and ll, records expanded by 12*wt
local ++test_count
global FGPUB_BAD = 0
capture noisily {
    webuse udca, clear
    assert _N == 188
    gen double fw = 12 * wt
    assert abs(fw - round(fw)) < 1e-6
    quietly replace fw = round(fw)
    * each patient's records carry a total weight of one, i.e. 12 rows
    bysort id: egen double fwsum = total(fw)
    assert fwsum == 12
    expand fw
    assert _N == 12 * 170
    stset eventtime, failure(etype) origin(time entry)
    finegray treat lbili stage, compete(etype) cause(3) cluster(id) nuisance nolog
    assert e(converged) == 1
    assert "`e(vce_meat)'" == "nuisance_adjusted"
    assert e(N_clust) == 170
    assert e(N) == 12 * 170
    * printed No. failed / competing / censored = 13 / 59 / 98 (weighted, rounded)
    assert round(e(N_fail) / 12) == 13
    assert round(e(N_compete) / 12) == 59
    assert round(e(N_cens) / 12) == 98
    assert e(N_fail) + e(N_compete) + e(N_cens) == 12 * 170
    _fgpub_near, l("treat SHR")    a(exp(_b[treat]))                   p(.5785214) dp(7)
    _fgpub_near, l("lbili SHR")    a(exp(_b[lbili]))                   p(1.012415) dp(6)
    _fgpub_near, l("stage SHR")    a(exp(_b[stage]))                   p(.5537101) dp(7)
    _fgpub_near, l("ll mapped to the iweight scale") ///
        a(e(ll)/12 + ln(12)*e(N_fail)/12) p(-61.669225) dp(6)
    display as text "    printed iweight SHR se .3238038 .367095 .3305371 (not gated); finegray nuisance on expanded rows: " ///
        %9.7f exp(_b[treat])*_se[treat] " " %9.7f exp(_b[lbili])*_se[lbili] ///
        " " %9.7f exp(_b[stage])*_se[stage]
    * the default clustered fixed-weight sandwich: same point estimates
    quietly finegray treat lbili stage, compete(etype) cause(3) cluster(id) nolog
    assert e(converged) == 1
    assert e(N_clust) == 170
    _fgpub_near, l("default treat SHR") a(exp(_b[treat])) p(.5785214) dp(7)
    _fgpub_near, l("default lbili SHR") a(exp(_b[lbili])) p(1.012415) dp(6)
    _fgpub_near, l("default stage SHR") a(exp(_b[stage])) p(.5537101) dp(7)
    display as text "    default cluster SHR se (not gated): " ///
        %9.7f exp(_b[treat])*_se[treat] " " %9.7f exp(_b[lbili])*_se[lbili] ///
        " " %9.7f exp(_b[stage])*_se[stage]
    assert $FGPUB_BAD == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: M2 udca [ST] stcrreg Example 3 SHRs, counts and ll reproduced at printed precision"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' M2"
    display as error "  FAIL: M2 udca [ST] stcrreg Example 3 (rc=`=_rc', misses=$FGPUB_BAD)"
}

* Printed rows 1-15 of [ST] stcrreg postestimation Example 1, in dataset order:
* dftime, failtype (row identity), bch, bcif.
local pr_t  6.152 8.008 .003 1.073 .003 7.929 8.454 7.107 8.378 8.178 3.395 .003 1.35 .003 .512
local pr_f  0 0 1 1 1 0 0 1 0 0 0 1 1 1 2
local pr_h  .0658792 .0813224 .0260186 .0379107 .0260186 .0813224 .0813224 .0813224 .0813224 .0813224 .0658792 .0260186 .051079 .0260186 .0260186
local pr_c  .063756 .0781036 .025683 .0372011 .025683 .0781036 .0781036 .0781036 .0781036 .0781036 .063756 .025683 .0497964 .025683 .025683

**# M3: [ST] stcrreg postestimation Example 1, finegray_predict basecshazard and cif at z = 0, rows 1-15
local ++test_count
global FGPUB_BAD = 0
capture noisily {
    _fgpub_hypoxia
    gen long obs = _n
    forvalues i = 1/15 {
        assert dftime[`i'] == float(real(word("`pr_t'", `i')))
        assert failtype[`i'] == real(word("`pr_f'", `i'))
    }
    stset dftime, failure(failtype)
    finegray ifp tumsize pelnode, compete(failtype) cause(1) nolog
    assert e(converged) == 1
    finegray_predict fg_bch, basecshazard
    sort obs
    forvalues i = 1/15 {
        _fgpub_near, l("row `i' basecsh") a(fg_bch[`i']) p(`=word("`pr_h'", `i')') dp(7)
    }
    * the row CIF route evaluated at the baseline profile (every covariate 0)
    quietly replace ifp = 0
    quietly replace tumsize = 0
    quietly replace pelnode = 0
    finegray_predict fg_bcif, cif
    sort obs
    forvalues i = 1/15 {
        _fgpub_near, l("row `i' basecif") a(fg_bcif[`i']) p(`=word("`pr_c'", `i')') dp(7)
    }
    assert $FGPUB_BAD == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: M3 hypoxia baseline subhazard and baseline CIF rows reproduced"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' M3"
    display as error "  FAIL: M3 hypoxia baseline rows (rc=`=_rc', misses=$FGPUB_BAD)"
}

**# M4: finegray_cif analytic CIF at z = 0, postestimation Example 1 rows
local ++test_count
global FGPUB_BAD = 0
capture noisily {
    _fgpub_hypoxia
    stset dftime, failure(failtype)
    finegray ifp tumsize pelnode, compete(failtype) cause(1) nolog
    assert e(converged) == 1
    * Evaluation times are the rows' own float dftime values written at full
    * double precision, so a cause event at that time is on the curve.
    local times ""
    forvalues i = 1/15 {
        local ti = string(float(real(word("`pr_t'", `i'))), "%21.17g")
        local times "`times' `ti'"
    }
    finegray_cif, at(ifp=0 tumsize=0 pelnode=0) attime(`times') nograph
    matrix T = r(table)
    assert rowsof(T) >= 12
    forvalues i = 1/15 {
        local ti = real(word("`pr_t'", `i'))
        local hit = 0
        forvalues r = 1/`=rowsof(T)' {
            if abs(T[`r', 1] - `ti') < 1e-6 {
                local hit = `r'
                continue, break
            }
        }
        assert `hit' > 0
        _fgpub_near, l("t=`=word("`pr_t'", `i')' CIF0") a(T[`hit', 2]) p(`=word("`pr_c'", `i')') dp(7)
    }
    assert $FGPUB_BAD == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: M4 finegray_cif baseline CIF reproduced at printed precision"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' M4"
    display as error "  FAIL: M4 finegray_cif (rc=`=_rc', misses=$FGPUB_BAD)"
}
macro drop FGPUB_BAD

**# Summary
display "REFERENCE: [ST] stcrreg and [ST] stcrreg postestimation, Stata 19 manual (printed output)"
display as text "RESULTS: crossval_finegray_published_stcrreg.do"
display as text "Total:   " as result `test_count'
display as text "Passed:  " as result `pass_count'
display as text "Failed:  " as result `fail_count'
display as text "Skipped: " as result `skip_count'

display "RESULT: crossval_finegray_published_stcrreg tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count'"

if `fail_count' > 0 {
    display as error "FAILED:`failed_tests'"
    log close _cvpubst
    exit 1
}
display as result "ALL PUBLISHED REPRODUCTIONS PASSED"
log close _cvpubst
