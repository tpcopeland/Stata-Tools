*! drest_estimate Version 1.0.0  2026/03/15
*! AIPW doubly robust estimation (ATE/ATT/ATC)
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: eclass (returns results in e())

/*
Basic syntax:
  drest_estimate [varlist] [if] [in], outcome(varname) treatment(varname) [options]

  When varlist is specified, it is used for both outcome and treatment models.
  Use omodel() and tmodel() for separate covariate specifications.

Required options:
  outcome(varname)   - Outcome variable
  treatment(varname) - Binary treatment indicator (0/1)

Optional options:
  omodel(varlist)    - Covariates for outcome model (overrides varlist)
  ofamily(string)    - Outcome model family: regress logit probit poisson
  tmodel(varlist)    - Covariates for treatment model (overrides varlist)
  tfamily(string)    - Treatment model family: logit probit
  estimand(string)   - ATE (default), ATT, or ATC
  trimps(numlist)    - PS trimming bounds (default: 0.01 0.99)
  level(cilevel)     - Confidence level (default: 95)
  nolog              - Suppress iteration log

See help drest_estimate for complete documentation
*/

program define drest_estimate, eclass
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
    * Treatment must be binary 0/1
    capture assert inlist(`treatment', 0, 1) if `touse'
    if _rc {
        set varabbrev `_vaset'
        display as error "treatment() must be a binary (0/1) variable"
        exit 198
    }

    * Both treatment groups must be present
    quietly count if `touse' & `treatment' == 1
    local n_treated = r(N)
    quietly count if `touse' & `treatment' == 0
    local n_control = r(N)
    if `n_treated' == 0 | `n_control' == 0 {
        set varabbrev `_vaset'
        display as error "both treatment groups (0 and 1) must be present"
        exit 198
    }

    * Covariate specification: varlist or omodel/tmodel
    if "`varlist'" == "" & "`omodel'" == "" {
        set varabbrev `_vaset'
        display as error "specify covariates as varlist or via omodel()"
        exit 198
    }

    * Set model covariates
    if "`omodel'" == "" local omodel "`varlist'"
    if "`tmodel'" == "" local tmodel "`varlist'"

    * Defaults
    if "`estimand'" == "" local estimand "ATE"
    local estimand = upper("`estimand'")
    if !inlist("`estimand'", "ATE", "ATT", "ATC") {
        set varabbrev `_vaset'
        display as error "estimand() must be ATE, ATT, or ATC"
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

    * =========================================================================
    * DROP OLD ESTIMATION VARIABLES
    * =========================================================================
    foreach v in _drest_ps _drest_mu1 _drest_mu0 _drest_if _drest_esample {
        capture drop `v'
    }

    * =========================================================================
    * STEP 1: FIT TREATMENT MODEL (PROPENSITY SCORE)
    * =========================================================================
    if "`log'" == "" {
        display as text "Fitting treatment model..."
    }

    tempvar ps_raw
    capture noisily _drest_propensity `treatment' "`tmodel'" "`tfamily'" `touse' `ps_raw'
    if _rc {
        set varabbrev `_vaset'
        exit _rc
    }

    * Retrieve actual family used
    if "`tfamily'" == "" local tfamily "logit"

    * =========================================================================
    * STEP 2: TRIM PROPENSITY SCORES
    * =========================================================================
    if `trim_lo' > 0 | `trim_hi' < 1 {
        _drest_trim_ps `ps_raw' `touse' `trim_lo' `trim_hi'
        local n_trimmed "`_drest_n_trimmed'"
    }
    else {
        local n_trimmed = 0
    }

    * Save PS as permanent variable
    quietly gen double _drest_ps = `ps_raw' if `touse'
    label variable _drest_ps "Propensity score (drest)"

    * =========================================================================
    * STEP 3: FIT OUTCOME MODELS
    * =========================================================================
    if "`log'" == "" {
        display as text "Fitting outcome models..."
    }

    tempvar mu1_raw mu0_raw
    capture noisily _drest_outcome_model `outcome' `treatment' "`omodel'" "`ofamily'" `touse' `mu1_raw' `mu0_raw'
    if _rc {
        set varabbrev `_vaset'
        exit _rc
    }

    * Retrieve actual family used
    if "`ofamily'" == "" {
        capture assert inlist(`outcome', 0, 1) if `touse'
        if _rc == 0 {
            local ofamily "logit"
        }
        else {
            local ofamily "regress"
        }
    }

    * Save as permanent variables
    quietly gen double _drest_mu1 = `mu1_raw' if `touse'
    quietly gen double _drest_mu0 = `mu0_raw' if `touse'
    label variable _drest_mu1 "Predicted outcome under treatment (drest)"
    label variable _drest_mu0 "Predicted outcome under control (drest)"

    * =========================================================================
    * STEP 4: COMPUTE AIPW ESTIMATE
    * =========================================================================
    if "`log'" == "" {
        display as text "Computing AIPW estimate..."
    }

    tempvar ifvar
    quietly gen double `ifvar' = .
    _drest_aipw_core `outcome' `treatment' `ps_raw' `mu1_raw' `mu0_raw' `touse' "`estimand'" `ifvar'

    local tau      "`_drest_tau'"
    local po1_mean "`_drest_po1_mean'"
    local po0_mean "`_drest_po0_mean'"

    * =========================================================================
    * STEP 5: INFLUENCE-FUNCTION INFERENCE
    * =========================================================================
    _drest_influence `ifvar' `touse' `tau' "`estimand'" `treatment'

    local se  "`_drest_se'"
    local var "`_drest_var'"

    * Save IF as permanent variable
    quietly gen double _drest_if = `ifvar' if `touse'
    label variable _drest_if "Influence function (drest)"

    * Estimation sample indicator
    quietly gen byte _drest_esample = `touse'
    label variable _drest_esample "Estimation sample (drest)"

    * =========================================================================
    * STEP 6: CONFIDENCE INTERVAL
    * =========================================================================
    local z = invnormal(1 - (100 - `level') / 200)
    local ci_lo = `tau' - `z' * `se'
    local ci_hi = `tau' + `z' * `se'
    local pvalue = 2 * normal(-abs(`tau' / `se'))

    * =========================================================================
    * STEP 7: POST ECLASS RESULTS
    * =========================================================================
    * Build coefficient vector: tau, PO1, PO0
    tempname b V
    matrix `b' = (`tau', `po1_mean', `po0_mean')
    matrix colnames `b' = `estimand' PO_mean_1 PO_mean_0

    * Variance matrix (diagonal: main effect has IF variance, PO means approximate)
    matrix `V' = J(3, 3, 0)
    matrix `V'[1,1] = `var'
    * PO variance from IF components (approximation)
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

    ereturn local cmd "drest_estimate"
    ereturn local method "aipw"
    ereturn local outcome "`outcome'"
    ereturn local treatment "`treatment'"
    ereturn local omodel "`omodel'"
    ereturn local ofamily "`ofamily'"
    ereturn local tmodel "`tmodel'"
    ereturn local tfamily "`tfamily'"
    ereturn local estimand "`estimand'"
    ereturn local trimps "`trim_lo' `trim_hi'"
    ereturn local depvar "`outcome'"
    ereturn local title "AIPW doubly robust estimation"

    * =========================================================================
    * STEP 8: STORE DATASET CHARACTERISTICS
    * =========================================================================
    char _dta[_drest_estimated]  "1"
    char _dta[_drest_method]     "aipw"
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
    * DISPLAY RESULTS
    * =========================================================================
    _drest_display_header "drest_estimate" "AIPW Doubly Robust Estimation"

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
        display as text "  PS trimmed:  " as result %10.0fc `n_trimmed' ///
            as text " (bounds: " as result %5.3f `trim_lo' as text ", " ///
            as result %5.3f `trim_hi' as text ")"
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
