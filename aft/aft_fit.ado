*! aft_fit Version 1.0.0  2026/03/14
*! AFT model fitting wrapper
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: eclass (returns results in e())

/*
Basic syntax:
  aft_fit [varlist] [if] [in] [, options]

Description:
  Wraps streg with the correct AFT parameterization. Reads the
  recommended distribution from aft_select (or accepts manual
  override via distribution()). Displays time ratios by default.

See help aft_fit for complete documentation
*/

program define aft_fit, eclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax [varlist(numeric fv default=none)] [if] [in] , ///
        [DISTribution(string) noTRatio ///
         STRata(varname) FRAILty(string) SHAred(varname) ///
         vce(passthru) ANCovariate(varlist fv) ///
         Level(cilevel) noLOG noHEADer]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================
    _aft_check_stset

    marksample touse
    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    * =========================================================================
    * RESOLVE DISTRIBUTION
    * =========================================================================

    if "`distribution'" != "" {
        * User override
        local dist = lower("`distribution'")
        if !inlist("`dist'", "exponential", "weibull", "lognormal", "loglogistic", "ggamma") {
            display as error "unknown distribution: `dist'"
            display as error "valid: exponential weibull lognormal loglogistic ggamma"
            exit 198
        }
    }
    else {
        * Try to read from aft_select characteristics
        local dist : char _dta[_aft_best_dist]
        if "`dist'" == "" {
            display as error "no distribution specified"
            display as error ""
            display as error "Either run {bf:aft_select} first, or specify"
            display as error "  {cmd:aft_fit `varlist', distribution(weibull)}"
            exit 198
        }
    }

    * Resolve varlist from characteristics if not provided
    if "`varlist'" == "" {
        local varlist : char _dta[_aft_varlist]
    }

    * =========================================================================
    * RESOLVE PASSTHROUGH OPTIONS FROM CHARACTERISTICS
    * =========================================================================

    * If options not explicitly provided, check characteristics
    if "`strata'" == "" {
        local strata : char _dta[_aft_strata]
    }
    if "`frailty'" == "" {
        local frailty : char _dta[_aft_frailty]
    }
    if "`shared'" == "" {
        local shared : char _dta[_aft_shared]
    }
    if "`vce'" == "" {
        local vce : char _dta[_aft_vce]
    }
    if "`ancovariate'" == "" {
        local _ancov : char _dta[_aft_ancov]
        if "`_ancov'" != "" local ancovariate "`_ancov'"
    }

    * =========================================================================
    * BUILD STREG OPTIONS
    * =========================================================================

    local dist_opts "distribution(`dist')"

    * Exponential and Weibull need time option for AFT metric
    if inlist("`dist'", "exponential", "weibull") {
        local dist_opts "`dist_opts' time"
    }

    local streg_opts ""
    if "`strata'" != "" local streg_opts "`streg_opts' strata(`strata')"
    if "`frailty'" != "" local streg_opts "`streg_opts' frailty(`frailty')"
    if "`shared'" != "" local streg_opts "`streg_opts' shared(`shared')"
    if "`vce'" != "" local streg_opts "`streg_opts' `vce'"
    if "`ancovariate'" != "" local streg_opts "`streg_opts' ancillary(`ancovariate')"
    if "`level'" != "" local streg_opts "`streg_opts' level(`level')"
    if "`log'" == "nolog" local streg_opts "`streg_opts' nolog"
    if "`tratio'" == "notratio" local streg_opts "`streg_opts' notr"

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    if "`header'" != "noheader" {
        _aft_display_header "aft_fit" "AFT Model Fitting"

        display as text "Distribution:     " as result "`dist'"
        if "`varlist'" != "" {
            display as text "Covariates:       " as result "`varlist'"
        }
        display as text "Metric:           " as result ///
            cond("`tratio'" == "notratio", "coefficients", "time ratios")
        display as text ""
    }

    * =========================================================================
    * FIT MODEL
    * =========================================================================

    * Time ratio display: streg shows TR by default for lognormal/loglogistic/ggamma
    * For exponential/weibull with time option, it also shows TR
    * nohr suppresses the exponentiated display

    streg `varlist' `if' `in', `dist_opts' `streg_opts'

    * =========================================================================
    * STORE METADATA
    * =========================================================================

    char _dta[_aft_fitted] "1"
    char _dta[_aft_fit_dist] "`dist'"
    if "`varlist'" != "" {
        char _dta[_aft_varlist] "`varlist'"
    }

    * =========================================================================
    * DISPLAY FOOTER
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as text "Next step: {cmd:aft_diagnose, all} for model diagnostics"
    display as text "           {cmd:aft_compare `varlist'} for Cox vs AFT comparison"
    display as text "{hline 70}"

    * eclass results are stored by streg automatically
    ereturn local aft_cmd "aft_fit"
    ereturn local aft_dist "`dist'"

    set varabbrev `_vaset'
end
