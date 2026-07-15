clear all
set more off
version 16.0
set varabbrev off

* validation_iivw_iptw_oracle.do - Gate 2A: the stabilized ATE IPTW oracle
* Tests: 5
*
* WHAT THIS SUITE IS FOR
* ----------------------
* METHOD_ORACLE_MAP.md #4 (stabilized IPTW) was the last tier-1/tier-3 oracle
* missing from the point-estimator surface, and it is the Gate-2A prerequisite
* for the Phase-3 inference work: no coverage claim can rest on a weight whose
* CONSTRUCTION has never been checked against an independent implementation.
*
* test_iivw_literature_invariants.do T6 already pins the stabilized *structure*
* (w*e constant within arm, the two numerators sum to 1). It deliberately does
* NOT hard-code the numerator or compare to external software -- that is exactly
* the gap this suite closes, with a DIRECT value/weight/coefficient parity.
*
* THE ORACLES, STRONGEST FIRST
* ----------------------------
*   T1  tier-1 hand fixture. A saturated single-binary-predictor logit fits
*       ps == the empirical within-cell treatment proportion, EXACTLY (2 params,
*       2 cells). Every ps and every stabilized weight is then hand-computable
*       with a calculator, sharing no code with iivw. This separates two claims:
*       (a) is ps the cell proportion, and (b) is the weight p/ps and (1-p)/(1-ps)
*       applied to the right arm.
*   T2  tier-3 R parity (base-R glm, crossval_iivw_iptw_oracle.R). Treatment-model
*       coefficients, per-subject propensity scores, per-subject stabilized
*       weights (treated and control separately), the weighted treatment
*       coefficient, and row/sample membership -- each compared directly. Class P
*       (TOLERANCE_FRAMEWORK.md): nuisance 1e-6, outcome 1e-5, membership exact.
*   T3  oracle #5, *What If* section 12.3 p.154: under a saturated outcome model
*       (Y ~ A alone) the stabilized weighted point estimate equals the
*       unstabilized (1/e) weighted point estimate. Exact algebra: the
*       within-arm-constant stabilization factor cancels in the weighted normal
*       equations. reldif < 1e-8.
*   T4  oracle #6, *What If* p.153 + Cole & Hernan: mean of the stabilized weight
*       is one, within the SELF-CALIBRATING band MEANONE_K * SD_subj / sqrt(n),
*       computed one row per subject (TOLERANCE_FRAMEWORK.md Class A). NOT a fixed
*       band -- the mean of an estimated weight is itself an estimate.
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do validation_iivw_iptw_oracle.do        Run all
*   stata-mp -b do validation_iivw_iptw_oracle.do 2      Run only T2

args run_only
do "`c(pwd)'/_iivw_qa_common.do"
iivw_qa_selector "`run_only'"
local run_only = `r(run_only)'

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "validation_iivw_iptw_oracle.do must be run from iivw/qa"
    exit 198
}
iivw_qa_sandbox
local pkg_dir "`r(pkg_dir)'"
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace
capture which iivw_weight
if _rc {
    display as error "iivw_weight not found after net install"
    exit 111
}

* Registered tolerances (TOLERANCE_FRAMEWORK.md section 3).
local TOL_INVARIANT   = 1e-8
local TOL_EXACTFORMULA = 1e-10
local TOL_PARITY_COEF = 1e-6
local TOL_PARITY_OUTCOME = 1e-5
local MEANONE_K       = 4

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =============================================================================
* T1 - tier-1 hand fixture: saturated logit => ps == cell proportion, exactly,
*      and the stabilized weight is p/ps (treated), (1-p)/(1-ps) (control)
*
* Construction (hand-computable):
*   L == 0 cell: 10 subjects, 4 treated  => Pr(A=1|L=0) = 0.40
*   L == 1 cell: 10 subjects, 7 treated  => Pr(A=1|L=1) = 0.70
*   marginal prevalence p = 11/20 = 0.55
*   treated,  L=0: 0.55/0.40      = 1.375
*   control,  L=0: 0.45/0.60      = 0.75
*   treated,  L=1: 0.55/0.70      = 0.7857142857...
*   control,  L=1: 0.45/0.30      = 1.5
* A single binary predictor entered linearly is a SATURATED model (2 parameters
* for 2 covariate patterns), so the MLE fitted probabilities equal the observed
* cell proportions. ps is therefore checked to optimiser tolerance (1e-6); the
* WEIGHT FORMULA is a closed-form function of that ps and is checked exactly.
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    capture noisily {
        clear
        set obs 20
        gen long id = _n
        gen byte L = _n > 10
        * L==0 (id 1-10): treated = ids 1-4  ; L==1 (id 11-20): treated = ids 11-17
        gen byte A = (id <= 4) | (id >= 11 & id <= 17)
        gen double y = 2 + 1.0*A + 0.5*L + 0.1*id
        gen double t0 = 0

        quietly iivw_weight, id(id) time(t0) treat(A) treat_cov(L) wtype(iptw) nolog

        * (a) ps equals the hand cell proportions
        quietly summarize _iivw_ps if L == 0
        display as text "    ps(L=0): min=" %8.6f r(min) " max=" %8.6f r(max) " target=0.40"
        assert reldif(r(min), 0.40) < `TOL_PARITY_COEF'
        assert reldif(r(max), 0.40) < `TOL_PARITY_COEF'
        quietly summarize _iivw_ps if L == 1
        display as text "    ps(L=1): min=" %8.6f r(min) " max=" %8.6f r(max) " target=0.70"
        assert reldif(r(min), 0.70) < `TOL_PARITY_COEF'
        assert reldif(r(max), 0.70) < `TOL_PARITY_COEF'

        * (b) the weight is the exact closed-form function of ps and p=0.55.
        * Checked against the package ps (so this isolates the FORMULA from any
        * optimiser wobble in ps), to floating-point noise.
        local p 0.55
        tempvar wexp
        gen double `wexp' = cond(A == 1, `p'/_iivw_ps, (1-`p')/(1-_iivw_ps))
        quietly gen double _dev = abs(_iivw_tw - `wexp')
        quietly summarize _dev
        display as text "    max|tw - p/ps formula| = " %12.3e r(max)
        assert r(max) < `TOL_EXACTFORMULA'

        * (c) the hand-computed absolute weights, to optimiser tolerance
        quietly summarize _iivw_tw if A == 1 & L == 0
        assert reldif(r(mean), 1.375) < `TOL_PARITY_COEF'
        quietly summarize _iivw_tw if A == 0 & L == 0
        assert reldif(r(mean), 0.75) < `TOL_PARITY_COEF'
        quietly summarize _iivw_tw if A == 1 & L == 1
        assert reldif(r(mean), 0.55/0.70) < `TOL_PARITY_COEF'
        quietly summarize _iivw_tw if A == 0 & L == 1
        assert reldif(r(mean), 1.5) < `TOL_PARITY_COEF'
        drop _dev
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T1 hand fixture -- ps == cell proportion, tw == stabilized formula"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' T1"
        display as error "FAIL: T1 hand fixture (error `=_rc')"
    }
}

* =============================================================================
* T2 - tier-3 R parity: base-R glm reproduces every intermediate value
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    capture noisily {
        * prespecified one-row-per-subject DGP
        clear
        set seed 20260715
        set obs 400
        gen long id = _n
        gen double L1 = rnormal()
        gen double L2 = rnormal()
        gen byte A = runiform() < invlogit(0.3 + 0.8*L1 - 0.5*L2)
        gen double y = 1 + 1.5*A + 0.7*L1 - 0.4*L2 + rnormal()
        gen double t0 = 0

        * export for the R oracle
        preserve
        keep id A L1 L2 y
        sort id
        export delimited using "`qa_dir'/iptw_oracle_data.csv", replace
        restore

        * package weights
        quietly iivw_weight, id(id) time(t0) treat(A) treat_cov(L1 L2) wtype(iptw) nolog
        local n_stata = _N

        * a fresh Stata logit for coefficient-level parity (independent of the
        * package internals, same model the package fits)
        quietly logit A L1 L2
        local b_cons_s = _b[_cons]
        local b_L1_s   = _b[L1]
        local b_L2_s   = _b[L2]
        quietly summarize A if e(sample), meanonly
        local ptreat_s = r(mean)

        * the weighted treatment coefficient via the package's outcome path
        * (independence GEE with pweights == WLS); one row per subject
        quietly glm y A [pw=_iivw_tw]
        local wcoef_A_s = _b[A]

        * run the R oracle. Erase any stale outputs FIRST: shell does not set
        * _rc in Stata, so a silently-failed Rscript would otherwise let the
        * confirm-file guards below pass on a leftover from a prior run.
        capture erase "`qa_dir'/iptw_oracle_R.csv"
        capture erase "`qa_dir'/iptw_oracle_R_coefs.csv"
        shell Rscript "`qa_dir'/crossval_iivw_iptw_oracle.R" "`qa_dir'"
        capture confirm file "`qa_dir'/iptw_oracle_R.csv"
        if _rc {
            display as error "R oracle did not write iptw_oracle_R.csv -- is Rscript on PATH?"
            error 601
        }
        capture confirm file "`qa_dir'/iptw_oracle_R_coefs.csv"
        if _rc {
            display as error "R oracle did not write iptw_oracle_R_coefs.csv"
            error 601
        }

        * --- coefficient/scalar parity ---
        * Read value as a STRING and parse with real(): import delimited stores
        * numeric columns as float, which rounds 0.5325 to 0.53250002861 -- a
        * 5.4e-8 artifact that would false-red the exact p_treat identity. real()
        * of the written 15-digit token recovers the full double.
        preserve
        import delimited using "`qa_dir'/iptw_oracle_R_coefs.csv", clear ///
            varnames(1) stringcols(2)
        quietly levelsof term, local(_terms) clean
        foreach tm of local _terms {
            quietly levelsof value if term == "`tm'", local(_vraw) clean
            local R_`tm' = real("`_vraw'")
        }
        restore

        display as text "    tm_L1  Stata=" %10.7f `b_L1_s'   "  R=" %10.7f `R_tm_L1'
        display as text "    tm_L2  Stata=" %10.7f `b_L2_s'   "  R=" %10.7f `R_tm_L2'
        display as text "    p_treat Stata=" %10.7f `ptreat_s' "  R=" %10.7f `R_p_treat'
        display as text "    wcoefA Stata=" %10.7f `wcoef_A_s' "  R=" %10.7f `R_wcoef_A'
        assert reldif(`b_cons_s', `R_tm_cons') < `TOL_PARITY_COEF'
        assert reldif(`b_L1_s',   `R_tm_L1')   < `TOL_PARITY_COEF'
        assert reldif(`b_L2_s',   `R_tm_L2')   < `TOL_PARITY_COEF'
        * p_treat = mean(A) is exact algebra on both sides, but R's value reaches
        * Stata through a CSV that -import delimited- stores as FLOAT (~1e-7
        * relative precision). A 1e-8 bound is below float resolution, so this is
        * a Class-P cross-implementation comparison exactly like the three
        * treatment coefficients above -- not a Class-A identity. The package
        * value is provably correct (here 213/400 = 0.5325); the residual is the
        * float round-trip alone. Registered Class-P tolerance is TOL_PARITY_COEF.
        assert reldif(`ptreat_s', `R_p_treat') < `TOL_PARITY_COEF'
        assert `R_n' == `n_stata'
        * weighted treatment coef: outcome tolerance
        assert reldif(`wcoef_A_s', `R_wcoef_A') < `TOL_PARITY_OUTCOME'

        * --- per-subject propensity + weight parity ---
        * stash the R per-subject file as a tempfile keyed on id
        preserve
        import delimited using "`qa_dir'/iptw_oracle_R.csv", clear varnames(1)
        keep id ps tw
        sort id
        tempfile _rmerge
        save "`_rmerge'"
        restore

        preserve
        quietly keep id A _iivw_ps _iivw_tw
        rename (_iivw_ps _iivw_tw) (ps_stata tw_stata)
        sort id
        merge 1:1 id using "`_rmerge'", nogen assert(match)
        gen double _psdev = abs(ps_stata - ps)
        gen double _twdev = reldif(tw_stata, tw)
        quietly summarize _psdev
        display as text "    max|ps_stata - ps_R| = " %12.3e r(max)
        assert r(max) < `TOL_PARITY_COEF'
        * treated and control weights compared separately (plan 2A)
        quietly summarize _twdev if A == 1
        display as text "    max reldif(tw) treated = " %12.3e r(max)
        assert r(max) < `TOL_PARITY_COEF'
        quietly summarize _twdev if A == 0
        display as text "    max reldif(tw) control = " %12.3e r(max)
        assert r(max) < `TOL_PARITY_COEF'
        restore
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T2 R parity -- treatment coefs, ps, weights, weighted coef, sample"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' T2"
        display as error "FAIL: T2 R parity (error `=_rc')"
    }
    capture erase "`qa_dir'/iptw_oracle_data.csv"
    capture erase "`qa_dir'/iptw_oracle_R.csv"
    capture erase "`qa_dir'/iptw_oracle_R_coefs.csv"
    capture erase "`qa_dir'/iptw_oracle_Rmerge.dta"
}

* =============================================================================
* T3 - oracle #5: saturated-model equivalence (What If s12.3 p.154)
*
* Under a saturated outcome model Y ~ A, the stabilized-weighted point estimate
* equals the unstabilized (1/e) weighted point estimate. The stabilization
* factor is constant WITHIN each arm (p for the treated, 1-p for the controls),
* and a within-group-constant scale cancels in the weighted normal equations of
* a model saturated in that grouping. This is exact algebra, not Monte Carlo.
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    capture noisily {
        clear
        set seed 314159
        set obs 500
        gen long id = _n
        gen double L1 = rnormal()
        gen double L2 = rnormal()
        gen byte A = runiform() < invlogit(0.2 + 0.6*L1 - 0.4*L2)
        gen double y = 3 + 2.0*A + 0.5*L1 + rnormal()
        gen double t0 = 0

        quietly iivw_weight, id(id) time(t0) treat(A) treat_cov(L1 L2) wtype(iptw) nolog

        * stabilized weighted estimate (the shipped weight)
        quietly glm y A [pw=_iivw_tw]
        local b_stab = _b[A]

        * unstabilized (1/e) weight: strip the numerator
        tempvar wunstab
        gen double `wunstab' = cond(A == 1, 1/_iivw_ps, 1/(1-_iivw_ps))
        quietly glm y A [pw=`wunstab']
        local b_unstab = _b[A]

        display as text "    saturated beta_A: stabilized=" %10.7f `b_stab' ///
            "  unstabilized=" %10.7f `b_unstab'
        assert reldif(`b_stab', `b_unstab') < `TOL_INVARIANT'
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T3 saturated-model equivalence stabilized == unstabilized (What If 12.3)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' T3"
        display as error "FAIL: T3 saturated-model equivalence (error `=_rc')"
    }
}

* =============================================================================
* T4 - oracle #6: mean-one, self-calibrating band (What If p.153; Cole & Hernan)
*
* mean(stabilized weight) == 1, judged against MEANONE_K * SD_subj / sqrt(n),
* NOT a fixed band. _iivw_tw is subject-constant, so n is the number of subjects
* (here one row per subject already). TOLERANCE_FRAMEWORK.md Class A.
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    capture noisily {
        clear
        set seed 27182
        set obs 600
        gen long id = _n
        gen double L1 = rnormal()
        gen double L2 = rnormal()
        gen byte A = runiform() < invlogit(0.1 + 0.7*L1 - 0.3*L2)
        gen double y = 1 + A + rnormal()
        gen double t0 = 0

        quietly iivw_weight, id(id) time(t0) treat(A) treat_cov(L1 L2) wtype(iptw) nolog

        quietly summarize _iivw_tw
        local wmean = r(mean)
        local wsd   = r(sd)
        local nsub  = r(N)
        local band  = `MEANONE_K' * `wsd' / sqrt(`nsub')
        display as text "    mean(tw)=" %10.7f `wmean' "  |dev|=" %10.7f abs(`wmean'-1) ///
            "  band(4*SD/sqrt n)=" %10.7f `band'
        assert abs(`wmean' - 1) < `band'

        * power check: the band must still catch a broken (unstabilized) numerator
        tempvar wbroken
        gen double `wbroken' = cond(A == 1, 1/_iivw_ps, 1/(1-_iivw_ps))
        quietly summarize `wbroken'
        display as text "    unstabilized mean=" %10.7f r(mean) " (must be outside the band)"
        assert abs(r(mean) - 1) > `band'
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T4 mean-one within self-calibrating band; catches unstabilized"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' T4"
        display as error "FAIL: T4 mean-one (error `=_rc')"
    }
}

* =============================================================================
* T5 - the treated/control numerators are the complementary prevalences p, 1-p
*      (the stabilization is the ATE marginal, not per-arm 1)
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    capture noisily {
        clear
        set seed 11235
        set obs 500
        gen long id = _n
        gen double L1 = rnormal()
        gen byte A = runiform() < invlogit(0.2 + 0.9*L1)
        gen double y = A + rnormal()
        gen double t0 = 0

        quietly iivw_weight, id(id) time(t0) treat(A) treat_cov(L1) wtype(iptw) nolog
        quietly summarize A, meanonly
        local p = r(mean)

        tempvar num
        gen double `num' = cond(A == 1, _iivw_tw*_iivw_ps, _iivw_tw*(1-_iivw_ps))
        quietly summarize `num' if A == 1
        assert reldif(r(min), r(max)) < `TOL_INVARIANT'
        display as text "    treated numerator=" %10.7f r(mean) "  p=" %10.7f `p'
        assert reldif(r(mean), `p') < `TOL_PARITY_COEF'
        quietly summarize `num' if A == 0
        assert reldif(r(min), r(max)) < `TOL_INVARIANT'
        display as text "    control numerator=" %10.7f r(mean) "  1-p=" %10.7f (1-`p')
        assert reldif(r(mean), 1-`p') < `TOL_PARITY_COEF'
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T5 stabilization numerators are the complementary prevalences p, 1-p"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' T5"
        display as error "FAIL: T5 stabilization numerators (error `=_rc')"
    }
}

iivw_qa_summary, name(validation_iivw_iptw_oracle) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') runonly(`run_only') failedtests("`failed_tests'")

clear
