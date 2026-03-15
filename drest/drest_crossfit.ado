*! drest_crossfit Version 1.0.0  2026/03/15
*! K-fold cross-fitted AIPW estimation (DML-style)
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: eclass (returns results in e())

/*
Basic syntax:
  drest_crossfit [varlist] [if] [in], outcome(varname) treatment(varname)
      [omodel(varlist) ofamily(string) tmodel(varlist) tfamily(string)
       estimand(string) folds(integer) seed(integer) trimps(numlist)
       level(cilevel) nolog]

Description:
  Cross-fitted AIPW avoids Donsker conditions by training nuisance
  models on held-out folds. Essential when models are flexible or
  high-dimensional.

Algorithm:
  1. Randomly assign observations to K folds
  2. For each fold k: train nuisance models on all-but-k, predict on k
  3. Pool cross-fitted predictions across all folds
  4. Compute AIPW using cross-fitted predictions
  5. IF-based variance (accounts for cross-fitting)

See help drest_crossfit for complete documentation
*/

program define drest_crossfit, eclass
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
         ESTIMand(string) FOLDs(integer 5) SEED(integer -1) ///
         TRIMps(numlist min=1 max=2) ///
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
    if !inlist("`estimand'", "ATE", "ATT", "ATC") {
        set varabbrev `_vaset'
        display as error "estimand() must be ATE, ATT, or ATC"
        exit 198
    }

    if `folds' < 2 | `folds' > `N' {
        set varabbrev `_vaset'
        display as error "folds() must be between 2 and N"
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
        }
        else {
            local ofamily "regress"
        }
    }

    * Set prediction option
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
    * STEP 1: CREATE FOLD ASSIGNMENTS
    * =========================================================================
    if "`log'" == "" {
        display as text "Cross-fitting with `folds' folds..."
    }

    if `seed' >= 0 {
        set seed `seed'
    }

    * Generate random fold assignment
    tempvar rand_order fold_var
    gen double `rand_order' = runiform() if `touse'
    egen int `fold_var' = cut(`rand_order') if `touse', group(`folds')
    quietly replace `fold_var' = `fold_var' + 1 if `touse'

    * Save fold assignment
    quietly gen int _drest_fold = `fold_var' if `touse'
    label variable _drest_fold "Cross-validation fold (drest)"

    * =========================================================================
    * STEP 2: CROSS-FITTED PREDICTIONS
    * =========================================================================
    * Initialize prediction variables
    quietly gen double _drest_ps  = . if `touse'
    quietly gen double _drest_mu1 = . if `touse'
    quietly gen double _drest_mu0 = . if `touse'

    local n_trimmed = 0

    forvalues k = 1/`folds' {
        if "`log'" == "" {
            display as text "  Fold `k'/`folds'..." _continue
        }

        * Train on all-but-k, predict on k
        tempvar train_k ps_k mu1_k mu0_k

        quietly gen byte `train_k' = (`touse' & `fold_var' != `k')

        * --- Treatment model ---
        capture quietly `tfamily' `treatment' `tmodel' if `train_k'
        local rc = _rc
        if `rc' {
            set varabbrev `_vaset'
            display as error ""
            display as error "treatment model failed in fold `k'"
            exit 498
        }
        quietly predict double `ps_k' if `touse' & `fold_var' == `k', pr

        * Trim PS
        if `trim_lo' > 0 | `trim_hi' < 1 {
            quietly count if `touse' & `fold_var' == `k' & ///
                (`ps_k' < `trim_lo' | `ps_k' > `trim_hi')
            local n_trimmed = `n_trimmed' + r(N)
            quietly replace `ps_k' = `trim_lo' if `touse' & `fold_var' == `k' & `ps_k' < `trim_lo'
            quietly replace `ps_k' = `trim_hi' if `touse' & `fold_var' == `k' & `ps_k' > `trim_hi'
        }

        * Store in pooled PS variable
        quietly replace _drest_ps = `ps_k' if `touse' & `fold_var' == `k'

        * --- Outcome model (treated arm) ---
        capture quietly `ofamily' `outcome' `omodel' if `train_k' & `treatment' == 1
        local rc = _rc
        if `rc' {
            set varabbrev `_vaset'
            display as error ""
            display as error "outcome model failed in treated arm, fold `k'"
            exit 498
        }
        quietly predict double `mu1_k' if `touse' & `fold_var' == `k', `predict_opt'

        * --- Outcome model (control arm) ---
        capture quietly `ofamily' `outcome' `omodel' if `train_k' & `treatment' == 0
        local rc = _rc
        if `rc' {
            set varabbrev `_vaset'
            display as error ""
            display as error "outcome model failed in control arm, fold `k'"
            exit 498
        }
        quietly predict double `mu0_k' if `touse' & `fold_var' == `k', `predict_opt'

        * Store in pooled prediction variables
        quietly replace _drest_mu1 = `mu1_k' if `touse' & `fold_var' == `k'
        quietly replace _drest_mu0 = `mu0_k' if `touse' & `fold_var' == `k'

        drop `train_k' `ps_k' `mu1_k' `mu0_k'

        if "`log'" == "" {
            display as text " done"
        }
    }

    label variable _drest_ps "Cross-fitted propensity score (drest)"
    label variable _drest_mu1 "Cross-fitted outcome under treatment (drest)"
    label variable _drest_mu0 "Cross-fitted outcome under control (drest)"

    * =========================================================================
    * STEP 3: COMPUTE AIPW WITH CROSS-FITTED PREDICTIONS
    * =========================================================================
    if "`log'" == "" {
        display as text "Computing cross-fitted AIPW..."
    }

    tempvar ifvar
    quietly gen double `ifvar' = .
    _drest_aipw_core `outcome' `treatment' _drest_ps _drest_mu1 _drest_mu0 `touse' "`estimand'" `ifvar'

    local tau      "`_drest_tau'"
    local po1_mean "`_drest_po1_mean'"
    local po0_mean "`_drest_po0_mean'"

    * =========================================================================
    * STEP 4: IF-BASED VARIANCE
    * =========================================================================
    _drest_influence `ifvar' `touse' `tau' "`estimand'" `treatment'

    local se  "`_drest_se'"
    local var "`_drest_var'"

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
    ereturn scalar folds = `folds'

    ereturn local cmd "drest_crossfit"
    ereturn local method "aipw_crossfit"
    ereturn local outcome "`outcome'"
    ereturn local treatment "`treatment'"
    ereturn local omodel "`omodel'"
    ereturn local ofamily "`ofamily'"
    ereturn local tmodel "`tmodel'"
    ereturn local tfamily "`tfamily'"
    ereturn local estimand "`estimand'"
    ereturn local trimps "`trim_lo' `trim_hi'"
    ereturn local depvar "`outcome'"
    ereturn local title "Cross-fitted AIPW doubly robust estimation"

    * =========================================================================
    * STORE DATASET CHARACTERISTICS
    * =========================================================================
    char _dta[_drest_estimated]  "1"
    char _dta[_drest_crossfit]   "1"
    char _dta[_drest_method]     "aipw_crossfit"
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
    char _dta[_drest_folds]      "`folds'"

    * =========================================================================
    * DISPLAY
    * =========================================================================
    _drest_display_header "drest_crossfit" "Cross-fitted AIPW Estimation"

    display as text "Outcome:       " as result "`outcome'"
    display as text "Treatment:     " as result "`treatment'"
    display as text "Estimand:      " as result "`estimand'"
    display as text "Folds:         " as result "`folds'"
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
