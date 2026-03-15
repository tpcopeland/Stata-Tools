*! finegray Version 1.1.0  2026/03/15
*! Fine-Gray competing risks regression
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: eclass (returns results in e())

/*
Basic syntax:
  finegray varlist [if] [in], events(varname) cause(#) [options]

Description:
  Fits Fine-Gray subdistribution hazard model for competing risks.
  Default uses native Mata forward-backward scan algorithm (fast mode).
  Wrapper mode (stcrprep + stcox) available via wrapper option or
  automatically when tvc()/strata() are specified.

  Data must be stset with id().

Required options:
  events(varname)   - Event type variable (0=cens, 1=cause1, 2=cause2, ...)
  cause(#)          - Which event value is cause of interest

Optional options:
  censvalue(#)      - Censoring value (default: 0)
  wrapper           - Force stcrprep + stcox wrapper mode
  fast              - Accepted for backwards compatibility (now the default)
  nohr              - Display log-SHR instead of SHR
  level(cilevel)    - Confidence level
  tvc(varlist)      - Time-varying coefficients (auto-triggers wrapper mode)
  strata(varlist)   - Stratified model (auto-triggers wrapper mode)
  byg(varlist)      - Stratify censoring distribution
  cluster(varname)  - Clustered standard errors
  robust            - Robust standard errors
  nolog             - Suppress iteration log
  noshorten         - Don't collapse equal weights in stcrprep
  iterate(#)        - Max iterations (default: 200)
  tolerance(#)      - Convergence tolerance (default: 1e-8)

See help finegray for complete documentation
*/

program define finegray, eclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax varlist(numeric) [if] [in] , ///
        EVents(varname numeric) CAUse(integer) ///
        [CENSvalue(integer 0) FAST WRAPPER noHR Level(cilevel) ///
         TVC(varlist numeric) STRata(varlist) ///
         BYG(varlist) CLuster(varname) ROBust ///
         noLOG noSHORTen ///
         ITERate(integer 200) TOLerance(real 1e-8)]

    * =========================================================================
    * VALIDATE STSET (must come before marksample references _st)
    * =========================================================================
    capture st_is 2 analysis
    if _rc {
        display as error "data not stset"
        display as error ""
        display as error "You must {bf:stset} your data before using finegray."
        display as error "Example:"
        display as error "  {cmd:stset time, failure(event) id(id)}"
        set varabbrev `_vaset'
        exit 119
    }

    * =========================================================================
    * MARK SAMPLE
    * =========================================================================
    marksample touse
    markout `touse' `events'
    if "`byg'" != "" markout `touse' `byg'
    if "`cluster'" != "" markout `touse' `cluster'

    quietly replace `touse' = 0 if _st != 1

    quietly count if `touse'
    if r(N) == 0 {
        set varabbrev `_vaset'
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    if `"`_dta[st_id]'"' == "" {
        display as error "finegray requires stset with id() variable"
        display as error "Example: {cmd:stset time, failure(event) id(id)}"
        set varabbrev `_vaset'
        exit 198
    }

    * Check one observation per subject
    capture bysort `_dta[st_id]' : assert _N == 1 if `touse'
    if _rc {
        display as error "finegray requires one observation per subject"
        display as error "data appear to have multiple records per id"
        set varabbrev `_vaset'
        exit 198
    }

    * =========================================================================
    * VALIDATE INPUTS
    * =========================================================================
    * Check events variable has cause value
    quietly count if `events' == `cause' & `touse'
    local N_fail = r(N)
    if `N_fail' == 0 {
        display as error "no observations with events() == `cause'"
        set varabbrev `_vaset'
        exit 198
    }

    * Count competing events
    quietly count if `events' != `censvalue' & `events' != `cause' & `touse'
    local N_compete = r(N)
    if `N_compete' == 0 {
        display as error "no competing events found"
        display as error "with cause(`cause') and censvalue(`censvalue'), " ///
            "events() contains no other event types"
        set varabbrev `_vaset'
        exit 198
    }

    * Count censored
    quietly count if `events' == `censvalue' & `touse'
    local N_cens = r(N)
    if `N_cens' == 0 {
        display as error "no censored observations found"
        set varabbrev `_vaset'
        exit 198
    }

    * Validate events/stset consistency
    quietly count if _d == 0 & `events' != `censvalue' & `touse'
    if r(N) > 0 {
        display as error "events() and stset failure indicator do not match"
        display as error "_d==0 but events() != `censvalue' for `r(N)' observations"
        set varabbrev `_vaset'
        exit 198
    }

    * Determine estimation mode: fast (Mata) is default
    * wrapper mode triggered by: wrapper option, tvc(), or strata()
    local _use_wrapper = 0
    if "`wrapper'" != "" local _use_wrapper = 1
    if "`tvc'" != "" local _use_wrapper = 1
    if "`strata'" != "" local _use_wrapper = 1

    * Explicit fast + wrapper is contradictory
    if "`fast'" != "" & "`wrapper'" != "" {
        display as error "cannot specify both fast and wrapper options"
        set varabbrev `_vaset'
        exit 198
    }
    * Explicit fast + tvc/strata is an error
    if "`fast'" != "" & "`tvc'" != "" {
        display as error "tvc() not compatible with fast option"
        display as error "omit fast or specify wrapper to use tvc()"
        set varabbrev `_vaset'
        exit 198
    }
    if "`fast'" != "" & "`strata'" != "" {
        display as error "strata() not compatible with fast option"
        display as error "omit fast or specify wrapper to use strata()"
        set varabbrev `_vaset'
        exit 198
    }

    local _method = cond(`_use_wrapper', "wrapper", "fast")

    if "`level'" == "" local level = c(level)
    local N_sub = `N'

    * =========================================================================
    * DISPATCH: FAST (default) vs WRAPPER
    * =========================================================================
    if `_use_wrapper' {
        _finegray_wrapper "`varlist'" "`events'" `cause' `censvalue' ///
            `touse' "`log'" "`shorten'" "`byg'" "`tvc'" "`strata'" ///
            "`cluster'" "`robust'" `level'
    }
    else {
        _finegray_fast "`varlist'" "`events'" `cause' `censvalue' ///
            `touse' `iterate' `tolerance' "`log'" "`byg'" ///
            "`cluster'" "`robust'" `level'
    }
    local _rc_dispatch = _rc
    if `_rc_dispatch' {
        set varabbrev `_vaset'
        exit `_rc_dispatch'
    }

    * =========================================================================
    * RETRIEVE AND POST E() RESULTS
    * =========================================================================
    * Results are in _finegray_* matrices/scalars set by the subprogram

    tempname b V basehaz
    matrix `b' = _finegray_b
    matrix `V' = _finegray_V

    * Column names from varlist
    local cnames ""
    foreach v of local varlist {
        local cnames "`cnames' `v'"
    }
    matrix colnames `b' = `cnames'
    matrix colnames `V' = `cnames'
    matrix rownames `V' = `cnames'

    local _fg_ll       = _finegray_ll[1,1]
    local _fg_ll_0     = _finegray_ll_0[1,1]
    local _fg_chi2     = _finegray_chi2[1,1]
    local _fg_df_m     = _finegray_df_m[1,1]
    local _fg_conv     = _finegray_conv[1,1]
    local _fg_N_expand = _finegray_N_expand[1,1]

    * Compute p-value from chi2 (stcox may not store e(p) with robust SEs)
    if `_fg_chi2' != . & `_fg_df_m' > 0 {
        local _fg_p = chi2tail(`_fg_df_m', `_fg_chi2')
    }
    else {
        local _fg_p = .
    }

    * Post results
    ereturn post `b' `V', obs(`N') esample(`touse') properties(b V)

    ereturn scalar N = `N'
    ereturn scalar N_sub = `N_sub'
    ereturn scalar N_fail = `N_fail'
    ereturn scalar N_compete = `N_compete'
    ereturn scalar N_cens = `N_cens'
    ereturn scalar ll = `_fg_ll'
    ereturn scalar ll_0 = `_fg_ll_0'
    ereturn scalar chi2 = `_fg_chi2'
    ereturn scalar p = `_fg_p'
    ereturn scalar df_m = `_fg_df_m'
    ereturn scalar converged = `_fg_conv'
    ereturn scalar level = `level'
    ereturn scalar cause = `cause'
    ereturn scalar censvalue = `censvalue'

    if "`_method'" == "fast" {
        ereturn scalar N_expand = .
        ereturn scalar iterate = `iterate'
        ereturn scalar tolerance = `tolerance'
    }
    else {
        ereturn scalar N_expand = `_fg_N_expand'
    }

    ereturn local cmd "finegray"
    ereturn local method "`_method'"
    ereturn local predict "finegray_predict"
    ereturn local depvar "`events'"
    ereturn local events "`events'"
    ereturn local covariates "`varlist'"
    if "`tvc'" != "" ereturn local tvc "`tvc'"
    if "`strata'" != "" ereturn local strata "`strata'"
    if "`byg'" != "" ereturn local byg "`byg'"
    if "`cluster'" != "" ereturn local clustvar "`cluster'"
    if "`robust'" != "" | "`cluster'" != "" ereturn local vce "robust"
    ereturn local title "Fine-Gray competing risks regression"

    capture matrix `basehaz' = _finegray_basehaz
    if _rc == 0 {
        ereturn matrix basehaz = `basehaz'
    }

    * Store dataset chars for predict
    char _dta[_finegray_estimated] "1"
    char _dta[_finegray_method]    "`e(method)'"
    char _dta[_finegray_events]    "`events'"
    char _dta[_finegray_cause]     "`cause'"
    char _dta[_finegray_covars]    "`varlist'"

    * Clean up temporary matrices
    foreach m in _finegray_b _finegray_V _finegray_ll _finegray_ll_0 ///
        _finegray_chi2 _finegray_p_model _finegray_df_m _finegray_conv ///
        _finegray_N_expand _finegray_basehaz {
        capture matrix drop `m'
    }

    * =========================================================================
    * DISPLAY RESULTS
    * =========================================================================
    local method_label = cond("`_method'" == "fast", ///
        "Mata forward-backward scan", "stcrprep + stcox")

    display as text ""
    display as text "Fine-Gray competing risks regression"
    display as text ""
    display as text "Method:         " as result "`method_label'"
    display as text "Events var:     " as result "`events'"
    display as text "Cause of interest: " as result "`cause'"
    display as text "Censoring value: " as result "`censvalue'"
    if "`byg'" != "" {
        display as text "Censoring strata: " as result "`byg'"
    }
    display as text ""
    display as text "No. of subjects    = " as result %10.0fc `N_sub'
    display as text "No. of cause events= " as result %10.0fc `N_fail'
    display as text "No. competing events=" as result %10.0fc `N_compete'
    display as text "No. censored       = " as result %10.0fc `N_cens'
    if "`_method'" == "wrapper" & `_fg_N_expand' > 0 {
        display as text "Expanded obs       = " as result %10.0fc `_fg_N_expand'
    }
    display as text ""

    if `_fg_ll' != . {
        display as text "Log pseudo-likelihood = " as result %12.4f `_fg_ll'
    }
    if `_fg_chi2' != . {
        display as text "Wald chi2(" as result "`_fg_df_m'" ///
            as text ")         = " as result %12.2f `_fg_chi2'
        display as text "Prob > chi2        = " as result %12.4f `_fg_p'
    }
    display as text ""

    if "`hr'" == "nohr" {
        ereturn display, level(`level')
    }
    else {
        ereturn display, eform(SHR) level(`level')
    }

    if `_fg_conv' == 0 {
        display as error "Warning: model did not converge"
    }

    set varabbrev `_vaset'
end


* =============================================================================
* WRAPPER MODE: stcrprep + stcox
* =============================================================================
program define _finegray_wrapper
    args varlist events cause censvalue touse log shorten ///
        byg tvc strata cluster robust level

    * Check stcrprep is available
    capture which stcrprep
    if _rc {
        display as error "stcrprep not installed"
        display as error ""
        display as error "Install with: {cmd:ssc install stcrprep}"
        display as error "Or omit {cmd:wrapper} to use the default Mata-native estimator"
        exit 111
    }

    * Build VCE option
    local vce_opt ""
    if "`cluster'" != "" {
        local vce_opt "vce(cluster `cluster')"
    }
    else if "`robust'" != "" {
        local vce_opt "vce(robust)"
    }

    * Build stcrprep options
    local scrp_opts "events(`events') keep(`varlist'"
    if "`tvc'" != "" local scrp_opts "`scrp_opts' `tvc'"
    if "`strata'" != "" local scrp_opts "`scrp_opts' `strata'"
    if "`byg'" != "" local scrp_opts "`scrp_opts' `byg'"
    if "`cluster'" != "" local scrp_opts "`scrp_opts' `cluster'"
    local scrp_opts "`scrp_opts') trans(`cause')"
    if "`byg'" != "" local scrp_opts "`scrp_opts' byg(`byg')"
    if "`shorten'" != "" local scrp_opts "`scrp_opts' noshorten"
    local scrp_opts "`scrp_opts' censvalue(`censvalue')"

    * Build stcox options
    local cox_opts ""
    if "`tvc'" != "" local cox_opts "`cox_opts' tvc(`tvc')"
    if "`strata'" != "" local cox_opts "`cox_opts' strata(`strata')"
    if "`vce_opt'" != "" local cox_opts "`cox_opts' `vce_opt'"
    if "`log'" == "nolog" local cox_opts "`cox_opts' nolog"
    local cox_opts "`cox_opts' nohr"

    if "`log'" != "nolog" {
        display as text "Step 1/3: Expanding data with stcrprep..."
    }

    * Preserve and run the pipeline
    preserve
    local _rc_final = 0

    capture noisily {
        * Restrict to estimation sample
        quietly keep if `touse'

        * Step 1: stcrprep
        quietly stcrprep, `scrp_opts'

        * Step 2: Generate Fine-Gray event indicator
        quietly gen byte _fg_event = (failcode == `cause')

        * Step 3: stset expanded data with FG weights
        quietly stset tstop [pw=weight_c], failure(_fg_event) enter(tstart)

        * Step 4: Keep only cause-of-interest pseudo-population
        quietly keep if failcode == `cause'

        local N_expand = _N

        if "`log'" != "nolog" {
            display as text "Step 2/3: Expanded to " as result _N ///
                as text " pseudo-observations"
            display as text "Step 3/3: Fitting Cox model..."
        }

        * Step 5: stcox (suppress output, finegray displays its own)
        quietly stcox `varlist', `cox_opts'

        * Capture results before restore destroys them
        tempname b_w V_w basehaz_w
        matrix `b_w' = e(b)
        matrix `V_w' = e(V)

        local ll_w = e(ll)
        local ll_0_w = e(ll_0)
        local chi2_w = e(chi2)
        local p_w = e(p)
        local df_m_w = e(df_m)
        local conv_w = e(converged)

        * Extract baseline cumulative subhazard for predict
        * (not available after stcox with tvc())
        if "`tvc'" == "" {
            tempvar bh_time bh_cumhaz
            quietly predict double `bh_cumhaz', basechazard
            quietly gen double `bh_time' = _t

            * Keep unique (time, cumhaz) pairs
            sort `bh_time'
            quietly by `bh_time': keep if _n == _N

            local n_bh = _N
            matrix `basehaz_w' = J(`n_bh', 2, .)
            forvalues i = 1/`n_bh' {
                matrix `basehaz_w'[`i', 1] = `bh_time'[`i']
                matrix `basehaz_w'[`i', 2] = `bh_cumhaz'[`i']
            }
            matrix colnames `basehaz_w' = time cumhazard
        }

        * Store in named matrices for caller
        matrix _finegray_b = `b_w'
        matrix _finegray_V = `V_w'
        if "`tvc'" == "" matrix _finegray_basehaz = `basehaz_w'
        matrix _finegray_ll = (`ll_w')
        matrix _finegray_ll_0 = (`ll_0_w')
        matrix _finegray_chi2 = (`chi2_w')
        matrix _finegray_p_model = (`p_w')
        matrix _finegray_df_m = (`df_m_w')
        matrix _finegray_conv = (`conv_w')
        matrix _finegray_N_expand = (`N_expand')
    }

    local _rc_final = _rc
    restore

    if `_rc_final' {
        exit `_rc_final'
    }
end


* =============================================================================
* FAST MODE: Mata forward-backward scan engine
* =============================================================================
program define _finegray_fast
    args varlist events cause censvalue touse iterate tolerance ///
        log byg cluster robust level

    * Load Mata engine
    capture program list _finegray_mata_loaded
    if _rc {
        capture findfile _finegray_mata.ado
        if _rc == 0 {
            run "`r(fn)'"
        }
        else {
            display as error "_finegray_mata.ado not found; reinstall finegray"
            exit 111
        }
    }

    * Build VCE option
    local vce_type "model"
    if "`cluster'" != "" local vce_type "cluster"
    else if "`robust'" != "" local vce_type "robust"

    * Preserve and run
    preserve
    local _rc_final = 0

    capture noisily {
        quietly keep if `touse'

        * Sort by event time
        sort _t

        if "`log'" != "nolog" {
            display as text "Fitting Fine-Gray model (Mata engine)..."
        }

        * Call Mata engine
        mata: _finegray_engine( ///
            "`varlist'", "`events'", `cause', `censvalue', ///
            "`byg'", "`vce_type'", "`cluster'", ///
            `iterate', `tolerance', ("`log'" != "nolog"))
    }

    local _rc_final = _rc
    restore

    if `_rc_final' {
        exit `_rc_final'
    }
end
