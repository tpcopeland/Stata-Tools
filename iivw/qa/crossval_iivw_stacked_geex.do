* =============================================================================
* crossval_iivw_stacked_geex.do - iivw_fit, vce(stacked) vs R geex
* =============================================================================
* Route covered: iivw_fit weighted GEE, vce(stacked), the two-step
* influence-function sandwich (IIW, stabilized IIW, IPTW and FIPTIW weights).
*
* Oracle: R package geex (Saul & Hudgens 2020, J Stat Softw 92(2), eq. 1-2, 4;
* grounding notes _literature/iivw/saul-hudgens-2020.notes.md). The R script
* crossval_iivw_stacked_geex.R refits the Cox visit model (survival::coxph),
* the propensity logit (glm) and the weighted outcome regression (lm) from the
* RAW panel, writes the stacked estimating equations as per-subject functions,
* and lets geex differentiate them (A) and accumulate the outer products (B).
* No iivw weight, score column or information matrix is read by R.
*
* What is held fixed so that both sides solve the SAME equations:
*   - ties: visit times are continuous, so Breslow = Efron = exact partial
*     likelihood; the R script asserts no two event times coincide and that
*     coxph(ties="efron") and coxph(ties="breslow") agree
*   - risk set: Andersen-Gill (t_{j-1}, t_j], first visit = study entry (weight
*     exactly 1), terminal censoring interval (t_J, maxfu] with row J's
*     covariates; the visit model includes a time-varying covariate
*   - normalizer: iivw divides the IIW component by its mean over modeled
*     events; "closure" below treats that mean as a function of gamma, which is
*     what iivw_weight differentiates
*   - finite-sample factor: geex returns A^-1 B A^-T / m; iivw returns the CR1
*     m/(m-1) multiple, so iivw V * (m-1)/m is compared with geex V
*   - stabilized IIW: iivw holds the numerator coefficients delta fixed
*     (Buzkova & Lumley 2007: first-order negligible), so geex fixes them too
*
* Informational only (printed, never asserted): the "param" stacking, where the
* mean-1 divisor is itself an estimated parameter, and the "delta" stacking,
* where the stabilization numerator is estimated. They show how much each
* convention iivw does NOT propagate would move the standard errors. On the
* exploration run, se(a) under the param stacking was 0.9995-1.0000 times
* the closure value (IIW, stabilized IIW, FIPTIW) and under the delta stacking
* 0.9994 times; the stabilization numerator and the mean-1 divisor have no
* material second-order effect on this fixture.
*
* Tolerance, relative: 1e-8 on V; 1e-7 on weights and coefficients. Stata's
* logit stops at its default 1e-6 likelihood tolerance while R solves to ~1e-12,
* so the propensity-weighted arms agree to ~2e-8 (exploration run) and the
* Cox-only arms to ~1e-14; V, a smooth function of the roots, agreed to 7e-11
* at worst. The estimating equations are also checked at R's own roots (mean
* psi per subject < 1e-8) and the hand-built Cox score is compared with
* coxph's score residuals (< 1e-8). Seed 881 (one 250-subject panel, reused
* across arms).
* Bounded: ~5 minutes. Lane: full.
* =============================================================================

clear all
set more off
version 16.0
set varabbrev off

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "crossval_iivw_stacked_geex.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"

local test_count = 16
local pass_count = 0
local fail_count = 0
local failed_tests ""

* -----------------------------------------------------------------------------
* R preflight and fresh output directory (a stale CSV can never stand in)
* -----------------------------------------------------------------------------
local rscript "`qa_dir'/crossval_iivw_stacked_geex.R"
capture confirm file "`rscript'"
if _rc {
    display as error "missing R generator: `rscript'"
    exit 601
}
tempfile _tstub
local ref_dir "`_tstub'_geex"
capture mkdir "`ref_dir'"
local rpre "`ref_dir'/.preflight_ok"
local rcheck "if (all(sapply(c('survival','geex'), requireNamespace, quietly=TRUE))) quit(status=0) else quit(status=1)"
shell Rscript -e "`rcheck'" > /dev/null 2>&1 && touch "`rpre'"
capture confirm file "`rpre'"
if _rc {
    display as error "R preflight failed: needs Rscript with survival and geex"
    display as error `"  install.packages(c("survival","geex"))"'
    exit 198
}

* -----------------------------------------------------------------------------
* Fixture: irregular visits, a time-varying visit covariate (zl, the previous
* visit's draw), a confounded binary treatment, and an outcome that depends on
* covariates the outcome model omits (k1, zl), so the weights do real work and
* the weight-estimation correction is large enough to be resolved.
* -----------------------------------------------------------------------------
capture program drop mkfix
program define mkfix
    syntax , NSub(integer) Seed(integer)
    clear
    set seed `seed'
    set obs `nsub'
    gen long id = _n
    gen double z1 = rnormal()
    gen double k1 = rnormal()
    gen byte a = runiform() < invlogit(0.8*k1)
    expand 25
    bysort id: gen int j = _n
    gen double zt = rnormal()
    bysort id (j): gen double zl = cond(_n == 1, 0, zt[_n-1])
    gen double gap = -ln(runiform())/exp(-0.3 + 0.4*z1 + 0.4*zl + 0.3*a)
    replace gap = 0.05 + 0.4*runiform() if j == 1
    bysort id (j): gen double t = sum(gap)
    keep if t < 7
    gen double y = 1 + 0.5*a + 0.4*z1 + 1.0*zl + 0.6*k1 + 0.1*t + rnormal()
    keep id t y a z1 zl k1
    sort id t
    bysort id (t): gen int seq = _n
end

local arms iiw iiwstab iptw fiptiw
foreach arm of local arms {
    mkfix, nsub(250) seed(881)
    local wt "iivw"
    local vis "visit_cov(z1 zl)"
    local trt ""
    local stb ""
    local mf  "maxfu(7)"
    if "`arm'" == "iptw" {
        local wt "iptw"
        local vis ""
        local mf  ""
    }
    if "`arm'" == "fiptiw" local wt "fiptiw"
    if inlist("`arm'", "iptw", "fiptiw") local trt "treat(a) treat_cov(k1)"
    if "`arm'" == "iiwstab" local stb "stabcov(z1)"
    quietly iivw_weight, id(id) time(t) `vis' `trt' `stb' wtype(`wt') `mf' ///
        scores nolog
    quietly export delimited id seq t y a z1 zl k1 ///
        using "`ref_dir'/panel_`arm'.csv", replace
    preserve
    keep id seq _iivw_weight
    rename _iivw_weight w_stata
    quietly save "`ref_dir'/w_`arm'.dta", replace
    restore
    quietly iivw_fit y a z1, timespec(linear) vce(stacked)
    matrix Vs_`arm' = e(V)
    matrix b_`arm'  = e(b)
    local m_`arm' = e(iivw_stacked_nclust)
    quietly iivw_fit y a z1, timespec(linear) vce(fixed)
    matrix Vf_`arm' = e(V)
    display as text "arm `arm': m = `m_`arm''  se(a) stacked = " ///
        %8.5f sqrt(Vs_`arm'[1,1]) "  fixed = " %8.5f sqrt(Vf_`arm'[1,1])
}

local rok "`ref_dir'/.generated_ok"
shell Rscript "`rscript'" --indir="`ref_dir'" --outdir="`ref_dir'" --maxfu=7 ///
    && touch "`rok'"
capture confirm file "`rok'"
if _rc {
    display as error "R reference generation did not run to completion"
    exit 198
}
capture confirm file "`ref_dir'/stacked_geex_ref.csv"
if _rc {
    display as error "R ran but wrote no reference"
    exit 601
}
quietly import delimited using "`ref_dir'/stacked_geex_ref.csv", clear ///
    varnames(1) stringcols(1 2) asdouble
tempfile ref
quietly save `ref'
quietly import delimited using "`ref_dir'/stacked_geex_weights.csv", clear ///
    varnames(1) stringcols(1) asdouble
tempfile refw
quietly save `refw'

* helper: pull a scalar/4x4 block from the reference file
capture program drop refmat
program define refmat
    args refpath arm kind mname
    preserve
    quietly use "`refpath'", clear
    matrix `mname' = J(4, 4, .)
    forvalues a = 1/4 {
        forvalues b = 1/4 {
            quietly summarize value if arm == "`arm'" & kind == "`kind'" & ///
                i == `a' & j == `b', meanonly
            matrix `mname'[`a', `b'] = r(mean)
        }
    }
    restore
end
capture program drop refsc
program define refsc, rclass
    args refpath arm kind
    preserve
    quietly use "`refpath'", clear
    quietly summarize value if arm == "`arm'" & kind == "`kind'", meanonly
    return scalar v = r(mean)
    return scalar n = r(N)
    restore
end

* -----------------------------------------------------------------------------
* Per arm: P point parity, E equations solved at the independent roots, V the
* variance parity, W power (iivw's stacked V is far closer to geex than the
* fixed-weight V is)
* -----------------------------------------------------------------------------
foreach arm of local arms {
    * ---- P: weights row by row and the outcome coefficients
    quietly use `refw', clear
    quietly keep if arm == "`arm'"
    quietly count
    local nref = r(N)
    quietly merge 1:1 id seq using "`ref_dir'/w_`arm'.dta"
    quietly count if _merge == 3
    local nmatch = r(N)
    quietly gen double rd = abs(w_stata - w) / max(abs(w), 1e-300) if _merge == 3
    quietly summarize rd, meanonly
    local wrd = r(max)
    * coefficients: R order is a z1 t cons, the order of e(b)
    quietly use `ref', clear
    quietly keep if arm == "`arm'" & kind == "beta"
    sort i
    local brd = 0
    forvalues c = 1/4 {
        local rv = value[`c']
        local sv = b_`arm'[1, `c']
        local d = abs(`sv' - `rv') / max(abs(`rv'), 1e-12)
        if `d' > `brd' local brd = `d'
    }
    display as text "P `arm': rows R=`nref' matched=`nmatch' max weight reldif " ///
        %10.3e `wrd' "  max coef reldif " %10.3e `brd'
    if `nmatch' == `nref' & `nmatch' > 0 & !missing(`wrd', `brd') & ///
            `wrd' < 1e-7 & `brd' < 1e-7 {
        local ++pass_count
        display "PASS P-`arm': R-refit weights and WLS coefficients match iivw"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' P-`arm'"
        display "FAIL P-`arm': point-estimate parity with the R refit"
    }

    * ---- E: the stacked equations are solved at R's roots, and the
    * hand-built Cox score reproduces coxph's own score residuals
    quietly refsc `ref' `arm' resid_closure
    local res1 = r(v)
    quietly refsc `ref' `arm' resid_param
    local res2 = r(v)
    quietly refsc `ref' `arm' coxchk
    local cchk = r(v)
    display as text "E `arm': max|mean psi| closure = " %10.3e `res1' ///
        "  param = " %10.3e `res2' "  Cox score vs coxph = " %10.3e `cchk'
    local e_ok = !missing(`res1') & `res1' < 1e-8
    if `res2' < . & `res2' >= 1e-8 local e_ok = 0
    if "`arm'" != "iptw" {
        if missing(`cchk') | `cchk' >= 1e-8 local e_ok = 0
    }
    if `e_ok' {
        local ++pass_count
        display "PASS E-`arm': geex's estimating equations are solved at the independent roots"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' E-`arm'"
        display "FAIL E-`arm': the R stacked system is not solved at its own roots"
    }

    * ---- V: variance parity, closure stacking
    tempname Vg Vi Vfx
    quietly refmat `ref' `arm' V_closure `Vg'
    matrix `Vi' = Vs_`arm' * (`m_`arm'' - 1) / `m_`arm''
    matrix `Vfx' = Vf_`arm' * (`m_`arm'' - 1) / `m_`arm''
    local dV = mreldif(`Vi', `Vg')
    local dF = mreldif(`Vfx', `Vg')
    display as text "V `arm': mreldif(iivw stacked*(m-1)/m, geex) = " %10.3e `dV' ///
        "   mreldif(iivw FIXED*(m-1)/m, geex) = " %10.3e `dF'
    display as text "     se(a): iivw stacked " %9.6f sqrt(`Vi'[1,1]*`m_`arm''/(`m_`arm''-1)) ///
        "  geex*sqrt(m/(m-1)) " %9.6f sqrt(`Vg'[1,1]*`m_`arm''/(`m_`arm''-1)) ///
        "  fixed " %9.6f sqrt(`Vfx'[1,1]*`m_`arm''/(`m_`arm''-1))
    if !missing(`dV') & `dV' < 1e-8 {
        local ++pass_count
        display "PASS V-`arm': vce(stacked) equals geex's stacked sandwich"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' V-`arm'"
        display "FAIL V-`arm': vce(stacked) differs from geex's stacked sandwich"
    }

    * ---- W: power. A comparison this tolerant would also pass for a
    * variance that ignored weight estimation, unless the two differ.
    if !missing(`dV', `dF') & `dF' > 100 * `dV' {
        local ++pass_count
        display "PASS W-`arm': the fixed-weight V is >100x farther from geex than stacked is"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' W-`arm'"
        display "FAIL W-`arm': geex cannot tell stacked from fixed on this fixture"
    }

    * ---- informational: conventions iivw does not propagate
    foreach st in param delta {
        quietly refsc `ref' `arm' V_`st'
        if r(n) > 0 {
            tempname Vx
            quietly refmat `ref' `arm' V_`st' `Vx'
            local se_x = sqrt(`Vx'[1,1] * `m_`arm'' / (`m_`arm'' - 1))
            local se_g = sqrt(`Vg'[1,1] * `m_`arm'' / (`m_`arm'' - 1))
            display as text "  info `arm' [`st' stacking]: se(a) " %9.6f `se_x' ///
                " vs closure " %9.6f `se_g' "  ratio " %7.4f `se_x'/`se_g'
        }
    }
}

**# SUMMARY

iivw_qa_summary, name(crossval_iivw_stacked_geex) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests("`failed_tests'")
