*! drest_tmle Version 1.0.0  2026/03/15
*! Targeted Minimum Loss-Based Estimation (TMLE)
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: eclass (returns results in e())

/*
Basic syntax:
  drest_tmle [varlist] [if] [in], outcome(varname) treatment(varname)
      [omodel(varlist) ofamily(string) tmodel(varlist) tfamily(string)
       estimand(string) trimps(numlist) iterate(integer) tolerance(real)
       crossfit folds(integer) seed(integer) level(cilevel) nolog]

Description:
  TMLE is a doubly robust, substitution estimator that targets the
  parameter of interest through a bias-reduction step (fluctuation).
  It inherits the double robustness of AIPW and additionally
  respects the bounds of the statistical model (e.g., predictions
  stay in [0,1] for binary outcomes).

Algorithm:
  1. Fit treatment model → propensity scores
  2. Fit outcome model → initial predictions μ̂₀
  3. Compute clever covariate H = A/ê - (1-A)/(1-ê)
  4. Fluctuate: fit logistic/linear submodel with H and offset(logit(μ̂₀))
  5. Update predictions with targeting step
  6. ATE = mean(μ̂*(1,X) - μ̂*(0,X))
  7. IF-based inference

See help drest_tmle for complete documentation
*/

program define drest_tmle, eclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax [varlist(numeric default=none)] [if] [in] , ///
        OUTcome(varname numeric) TREATment(varname numeric) ///
        [OMODel(varlist numeric) OFamily(string) ///
         TMODel(varlist numeric) TFamily(string) ///
         ESTIMand(string) TRIMps(numlist min=1 max=2) ///
         ITERate(integer 100) TOLerance(real 1e-5) ///
         CROSSfit FOLDs(integer 5) SEED(integer -1) ///
         Level(cilevel) noLOG]

    * =========================================================================
    * MARK SAMPLE
    * =========================================================================
    marksample touse, novarlist
    markout `touse' `outcome' `treatment'
    if "`varlist'" != "" markout `touse' `varlist'
    if "`omodel'" != "" markout `touse' `omodel'
    if "`tmodel'" != "" markout `touse' `tmodel'

    quietly count if `touse'
    if r(N) == 0 {
        set varabbrev `_vaset'
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    * =========================================================================
    * VALIDATE INPUTS
    * =========================================================================
    capture assert inlist(`treatment', 0, 1) if `touse'
    if _rc {
        set varabbrev `_vaset'
        display as error "treatment() must be a binary (0/1) variable"
        exit 198
    }

    quietly count if `touse' & `treatment' == 1
    local n_treated = r(N)
    quietly count if `touse' & `treatment' == 0
    local n_control = r(N)
    if `n_treated' == 0 | `n_control' == 0 {
        set varabbrev `_vaset'
        display as error "both treatment groups (0 and 1) must be present"
        exit 198
    }

    if "`varlist'" == "" & "`omodel'" == "" {
        set varabbrev `_vaset'
        display as error "specify covariates as varlist or via omodel()"
        exit 198
    }

    if "`omodel'" == "" local omodel "`varlist'"
    if "`tmodel'" == "" local tmodel "`varlist'"

    if "`estimand'" == "" local estimand "ATE"
    local estimand = upper("`estimand'")
    if "`estimand'" != "ATE" {
        set varabbrev `_vaset'
        display as error "drest_tmle currently supports ATE only"
        exit 198
    }

    if "`level'" == "" local level = c(level)

    * Parse trimming bounds
    if "`trimps'" == "" {
        local trim_lo = 0.01
        local trim_hi = 0.99
    }
    else {
        local nwords : word count `trimps'
        if `nwords' == 1 {
            if `trimps' == 0 {
                local trim_lo = 0
                local trim_hi = 1
            }
            else {
                local trim_lo = `trimps'
                local trim_hi = 1 - `trimps'
            }
        }
        else {
            local trim_lo : word 1 of `trimps'
            local trim_hi : word 2 of `trimps'
        }
    }
    if `trim_lo' < 0 | `trim_hi' > 1 | `trim_lo' >= `trim_hi' {
        set varabbrev `_vaset'
        display as error "trimps() bounds must satisfy 0 <= lo < hi <= 1"
        exit 198
    }

    if "`tfamily'" == "" local tfamily "logit"
    if "`ofamily'" == "" {
        capture assert inlist(`outcome', 0, 1) if `touse'
        if _rc == 0 {
            local ofamily "logit"
            local is_binary = 1
        }
        else {
            local ofamily "regress"
            local is_binary = 0
        }
    }
    else {
        local is_binary = inlist("`ofamily'", "logit", "probit")
    }

    local predict_opt ""
    if inlist("`ofamily'", "logit", "probit") local predict_opt "pr"
    else if "`ofamily'" == "poisson" local predict_opt "n"

    * =========================================================================
    * DROP OLD VARIABLES
    * =========================================================================
    foreach v in _drest_ps _drest_mu1 _drest_mu0 _drest_if _drest_esample _drest_fold {
        capture drop `v'
    }

    * =========================================================================
    * STEP 1: FIT NUISANCE MODELS
    * =========================================================================
    if "`crossfit'" != "" {
        * =================================================================
        * CROSS-FITTED TMLE
        * =================================================================
        if "`log'" == "" {
            display as text "Cross-fitted TMLE with `folds' folds..."
        }

        if `seed' >= 0 {
            set seed `seed'
        }

        tempvar rand_order fold_var
        gen double `rand_order' = runiform() if `touse'
        egen int `fold_var' = cut(`rand_order') if `touse', group(`folds')
        quietly replace `fold_var' = `fold_var' + 1 if `touse'

        quietly gen int _drest_fold = `fold_var' if `touse'
        label variable _drest_fold "Cross-validation fold (drest)"

        quietly gen double _drest_ps  = . if `touse'
        quietly gen double _drest_mu1 = . if `touse'
        quietly gen double _drest_mu0 = . if `touse'

        local n_trimmed = 0

        forvalues k = 1/`folds' {
            if "`log'" == "" {
                display as text "  Fold `k'/`folds'..." _continue
            }

            tempvar train_k ps_k mu1_k mu0_k

            quietly gen byte `train_k' = (`touse' & `fold_var' != `k')

            * Treatment model
            capture quietly `tfamily' `treatment' `tmodel' if `train_k'
            local rc = _rc
            if `rc' {
                set varabbrev `_vaset'
                display as error ""
                display as error "treatment model failed in fold `k'"
                exit 498
            }
            quietly predict double `ps_k' if `touse' & `fold_var' == `k', pr

            if `trim_lo' > 0 | `trim_hi' < 1 {
                quietly count if `touse' & `fold_var' == `k' & ///
                    (`ps_k' < `trim_lo' | `ps_k' > `trim_hi')
                local n_trimmed = `n_trimmed' + r(N)
                quietly replace `ps_k' = `trim_lo' if `touse' & `fold_var' == `k' & `ps_k' < `trim_lo'
                quietly replace `ps_k' = `trim_hi' if `touse' & `fold_var' == `k' & `ps_k' > `trim_hi'
            }

            quietly replace _drest_ps = `ps_k' if `touse' & `fold_var' == `k'

            * Outcome models
            capture quietly `ofamily' `outcome' `omodel' if `train_k' & `treatment' == 1
            local rc = _rc
            if `rc' {
                set varabbrev `_vaset'
                display as error ""
                display as error "outcome model failed in treated arm, fold `k'"
                exit 498
            }
            quietly predict double `mu1_k' if `touse' & `fold_var' == `k', `predict_opt'

            capture quietly `ofamily' `outcome' `omodel' if `train_k' & `treatment' == 0
            local rc = _rc
            if `rc' {
                set varabbrev `_vaset'
                display as error ""
                display as error "outcome model failed in control arm, fold `k'"
                exit 498
            }
            quietly predict double `mu0_k' if `touse' & `fold_var' == `k', `predict_opt'

            quietly replace _drest_mu1 = `mu1_k' if `touse' & `fold_var' == `k'
            quietly replace _drest_mu0 = `mu0_k' if `touse' & `fold_var' == `k'

            drop `train_k' `ps_k' `mu1_k' `mu0_k'

            if "`log'" == "" {
                display as text " done"
            }
        }
    }
    else {
        * =================================================================
        * STANDARD (NON-CROSS-FITTED) TMLE
        * =================================================================
        if "`log'" == "" {
            display as text "Fitting treatment model..."
        }

        tempvar ps_raw
        capture noisily _drest_propensity `treatment' "`tmodel'" "`tfamily'" `touse' `ps_raw'
        if _rc {
            set varabbrev `_vaset'
            exit _rc
        }

        if `trim_lo' > 0 | `trim_hi' < 1 {
            _drest_trim_ps `ps_raw' `touse' `trim_lo' `trim_hi'
            local n_trimmed "`_drest_n_trimmed'"
        }
        else {
            local n_trimmed = 0
        }

        quietly gen double _drest_ps = `ps_raw' if `touse'

        if "`log'" == "" {
            display as text "Fitting outcome models..."
        }

        tempvar mu1_raw mu0_raw
        capture noisily _drest_outcome_model `outcome' `treatment' "`omodel'" "`ofamily'" `touse' `mu1_raw' `mu0_raw'
        if _rc {
            set varabbrev `_vaset'
            exit _rc
        }

        quietly gen double _drest_mu1 = `mu1_raw' if `touse'
        quietly gen double _drest_mu0 = `mu0_raw' if `touse'
    }

    label variable _drest_ps "Propensity score (drest)"
    label variable _drest_mu1 "Predicted outcome under treatment (drest)"
    label variable _drest_mu0 "Predicted outcome under control (drest)"

    * =========================================================================
    * STEP 2: TARGETING (FLUCTUATION)
    * =========================================================================
    if "`log'" == "" {
        display as text "Targeting step..."
    }

    _drest_tmle_fluctuate `outcome' `treatment' _drest_ps _drest_mu1 _drest_mu0 ///
        `touse' `is_binary' `iterate' `tolerance'

    local converged "`_drest_converged'"
    local n_iter    "`_drest_n_iter'"
    local epsilon   "`_drest_epsilon'"

    if "`converged'" != "1" {
        display as text "{it:Warning: targeting step did not converge in `n_iter' iterations}"
    }

    * =========================================================================
    * STEP 3: COMPUTE TMLE ESTIMATE (substitution estimator)
    * =========================================================================
    if "`log'" == "" {
        display as text "Computing TMLE estimate..."
    }

    quietly {
        * TMLE ATE = mean(mu1_star) - mean(mu0_star)
        summarize _drest_mu1 if `touse', meanonly
        local po1_mean = r(mean)
        summarize _drest_mu0 if `touse', meanonly
        local po0_mean = r(mean)
        local tau = `po1_mean' - `po0_mean'
    }

    * =========================================================================
    * STEP 4: IF-BASED INFERENCE (same form as AIPW but with targeted predictions)
    * =========================================================================
    tempvar ifvar
    quietly gen double `ifvar' = .
    quietly replace `ifvar' = (_drest_mu1 - _drest_mu0 - `tau') ///
        + `treatment' * (`outcome' - _drest_mu1) / _drest_ps ///
        - (1 - `treatment') * (`outcome' - _drest_mu0) / (1 - _drest_ps) ///
        if `touse'

    * Variance from IF
    quietly {
        tempvar ifc
        gen double `ifc' = `ifvar'^2 if `touse'
        summarize `ifc' if `touse', meanonly
        local var = r(sum) / (`N'^2)
        local se = sqrt(`var')
    }

    * Save IF
    quietly gen double _drest_if = `ifvar' if `touse'
    label variable _drest_if "Influence function (drest)"

    quietly gen byte _drest_esample = `touse'
    label variable _drest_esample "Estimation sample (drest)"

    * =========================================================================
    * STEP 5: CONFIDENCE INTERVAL AND ECLASS RESULTS
    * =========================================================================
    local z = invnormal(1 - (100 - `level') / 200)
    local ci_lo = `tau' - `z' * `se'
    local ci_hi = `tau' + `z' * `se'
    local pvalue = 2 * normal(-abs(`tau' / `se'))

    tempname b V
    matrix `b' = (`tau', `po1_mean', `po0_mean')
    matrix colnames `b' = `estimand' PO_mean_1 PO_mean_0
    matrix `V' = J(3, 3, 0)
    matrix `V'[1,1] = `var'
    matrix `V'[2,2] = `var' / 2
    matrix `V'[3,3] = `var' / 2
    matrix colnames `V' = `estimand' PO_mean_1 PO_mean_0
    matrix rownames `V' = `estimand' PO_mean_1 PO_mean_0

    ereturn post `b' `V', obs(`N') esample(`touse') properties(b V)

    ereturn scalar N = `N'
    ereturn scalar N_treated = `n_treated'
    ereturn scalar N_control = `n_control'
    ereturn scalar tau = `tau'
    ereturn scalar se = `se'
    ereturn scalar z = `tau' / `se'
    ereturn scalar p = `pvalue'
    ereturn scalar ci_lo = `ci_lo'
    ereturn scalar ci_hi = `ci_hi'
    ereturn scalar po1 = `po1_mean'
    ereturn scalar po0 = `po0_mean'
    ereturn scalar level = `level'
    ereturn scalar n_trimmed = `n_trimmed'
    ereturn scalar converged = `converged'
    ereturn scalar n_iter = `n_iter'
    ereturn scalar epsilon = `epsilon'

    local method_label "tmle"
    if "`crossfit'" != "" {
        local method_label "tmle_crossfit"
        ereturn scalar folds = `folds'
    }

    ereturn local cmd "drest_tmle"
    ereturn local method "`method_label'"
    ereturn local outcome "`outcome'"
    ereturn local treatment "`treatment'"
    ereturn local omodel "`omodel'"
    ereturn local ofamily "`ofamily'"
    ereturn local tmodel "`tmodel'"
    ereturn local tfamily "`tfamily'"
    ereturn local estimand "`estimand'"
    ereturn local trimps "`trim_lo' `trim_hi'"
    ereturn local depvar "`outcome'"
    ereturn local title "TMLE doubly robust estimation"

    * =========================================================================
    * STORE DATASET CHARACTERISTICS
    * =========================================================================
    char _dta[_drest_estimated]  "1"
    char _dta[_drest_method]     "`method_label'"
    char _dta[_drest_outcome]    "`outcome'"
    char _dta[_drest_treatment]  "`treatment'"
    char _dta[_drest_omodel]     "`omodel'"
    char _dta[_drest_ofamily]    "`ofamily'"
    char _dta[_drest_tmodel]     "`tmodel'"
    char _dta[_drest_tfamily]    "`tfamily'"
    char _dta[_drest_estimand]   "`estimand'"
    char _dta[_drest_ate]        "`tau'"
    char _dta[_drest_ate_se]     "`se'"
    char _dta[_drest_level]      "`level'"
    char _dta[_drest_N]          "`N'"
    char _dta[_drest_trimps_lo]  "`trim_lo'"
    char _dta[_drest_trimps_hi]  "`trim_hi'"
    char _dta[_drest_n_trimmed]  "`n_trimmed'"
    char _dta[_drest_po1]        "`po1_mean'"
    char _dta[_drest_po0]        "`po0_mean'"

    * =========================================================================
    * DISPLAY
    * =========================================================================
    local cf_label ""
    if "`crossfit'" != "" local cf_label " (cross-fitted, `folds' folds)"

    _drest_display_header "drest_tmle" "TMLE Doubly Robust Estimation`cf_label'"

    display as text "Outcome:       " as result "`outcome'"
    display as text "Treatment:     " as result "`treatment'"
    display as text "Estimand:      " as result "`estimand'"
    display as text ""
    display as text "Outcome model: " as result "`ofamily'" as text " (" as result "`omodel'" as text ")"
    display as text "Treatment model: " as result "`tfamily'" as text " (" as result "`tmodel'" as text ")"
    display as text ""
    display as text "Observations:  " as result %10.0fc `N'
    display as text "  Treated:     " as result %10.0fc `n_treated'
    display as text "  Control:     " as result %10.0fc `n_control'
    if `n_trimmed' > 0 {
        display as text "  PS trimmed:  " as result %10.0fc `n_trimmed'
    }
    display as text "Targeting:     " as result "`n_iter' iteration(s)" ///
        as text ", epsilon = " as result %10.6f `epsilon'
    if "`converged'" != "1" {
        display as text "               {it:did not converge}"
    }

    display as text ""
    display as text "{hline 70}"
    display as text %16s "`estimand'" as text " {c |}" ///
        as text %12s "Estimate" as text %12s "Std. Err." ///
        as text %10s "z" as text %10s "P>|z|" ///
        as text %24s "[`level'% Conf. Interval]"
    display as text "{hline 16}{c +}{hline 53}"

    display as text %16s "`estimand'" as text " {c |}" ///
        as result %12.4f `tau' ///
        as result %12.4f `se' ///
        as result %10.2f (`tau' / `se') ///
        as result %10.3f `pvalue' ///
        as result %12.4f `ci_lo' ///
        as result %12.4f `ci_hi'

    display as text "{hline 16}{c +}{hline 53}"
    display as text %16s "PO mean (1)" as text " {c |}" ///
        as result %12.4f `po1_mean'
    display as text %16s "PO mean (0)" as text " {c |}" ///
        as result %12.4f `po0_mean'
    display as text "{hline 70}"

    set varabbrev `_vaset'
end
