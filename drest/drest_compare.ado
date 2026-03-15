*! drest_compare Version 1.0.0  2026/03/15
*! Side-by-side IPTW vs g-computation vs AIPW comparison
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  drest_compare [varlist] [if] [in], outcome(varname) treatment(varname)
      [methods(string) omodel(varlist) ofamily(string) tmodel(varlist)
       tfamily(string) estimand(string) trimps(numlist) level(cilevel)
       graph saving(filename) scheme(string)]

See help drest_compare for complete documentation
*/

program define drest_compare, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax [varlist(numeric default=none)] [if] [in] , ///
        OUTcome(varname numeric) TREATment(varname numeric) ///
        [METHods(string) ///
         OMODel(varlist numeric) OFamily(string) ///
         TMODel(varlist numeric) TFamily(string) ///
         ESTIMand(string) TRIMps(numlist min=1 max=2) ///
         Level(cilevel) ///
         GRaph SAVing(string) SCHeme(string)]

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

    * Treatment must be binary
    capture assert inlist(`treatment', 0, 1) if `touse'
    if _rc {
        set varabbrev `_vaset'
        display as error "treatment() must be a binary (0/1) variable"
        exit 198
    }

    * Set model covariates
    if "`omodel'" == "" local omodel "`varlist'"
    if "`tmodel'" == "" local tmodel "`varlist'"
    if "`omodel'" == "" {
        set varabbrev `_vaset'
        display as error "specify covariates as varlist or via omodel()"
        exit 198
    }

    * Defaults
    if "`estimand'" == "" local estimand "ATE"
    local estimand = upper("`estimand'")
    if "`estimand'" != "ATE" {
        set varabbrev `_vaset'
        display as error "drest_compare currently supports ATE only"
        display as error "use drest_estimate for ATT/ATC estimation"
        exit 198
    }
    if "`methods'" == "" local methods "iptw gcomp aipw"
    if "`level'" == "" local level = c(level)
    if "`scheme'" == "" local scheme "plotplainblind"

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

    local z = invnormal(1 - (100 - `level') / 200)

    _drest_display_header "drest_compare" "Estimator Comparison"

    display as text "Outcome:   " as result "`outcome'"
    display as text "Treatment: " as result "`treatment'"
    display as text "Estimand:  " as result "`estimand'"
    display as text ""

    * Initialize storage
    local n_methods = 0
    local method_names ""
    tempname comp_mat

    * =========================================================================
    * IPTW ESTIMATE
    * =========================================================================
    * Validate model families
    if !inlist("`ofamily'", "regress", "logit", "probit", "poisson") {
        set varabbrev `_vaset'
        display as error "ofamily() must be regress, logit, probit, or poisson"
        exit 198
    }
    if !inlist("`tfamily'", "logit", "probit") {
        set varabbrev `_vaset'
        display as error "tfamily() must be logit or probit"
        exit 198
    }

    if strpos(" `methods' ", " iptw ") {
        local ++n_methods
        local method_names "`method_names' IPTW"

        quietly {
            * Fit PS model
            capture `tfamily' `treatment' `tmodel' if `touse'
            if _rc {
                set varabbrev `_vaset'
                noisily display as error "treatment model (`tfamily') failed to converge in IPTW"
                exit 498
            }
            tempvar iptw_ps iptw_wt
            predict double `iptw_ps' if `touse', pr

            * Trim PS
            replace `iptw_ps' = `trim_lo' if `touse' & `iptw_ps' < `trim_lo'
            replace `iptw_ps' = `trim_hi' if `touse' & `iptw_ps' > `trim_hi'

            * IPW weights
            gen double `iptw_wt' = cond(`treatment' == 1, 1 / `iptw_ps', 1 / (1 - `iptw_ps')) if `touse'

            * Weighted means
            summarize `outcome' [aw = `iptw_wt'] if `touse' & `treatment' == 1
            local iptw_m1 = r(mean)
            summarize `outcome' [aw = `iptw_wt'] if `touse' & `treatment' == 0
            local iptw_m0 = r(mean)
        }
        local iptw_tau = `iptw_m1' - `iptw_m0'

        * Robust SE via Hajek influence function
        quietly {
            tempvar iptw_if
            gen double `iptw_if' = cond(`treatment' == 1, ///
                `iptw_wt' * (`outcome' - `iptw_m1'), ///
                -1 * `iptw_wt' * (`outcome' - `iptw_m0')) if `touse'

            tempvar iptw_if2
            gen double `iptw_if2' = (`iptw_if')^2 if `touse'
            summarize `iptw_if2' if `touse', meanonly
            local iptw_var = r(sum) / (`N'^2)
        }
        local iptw_se = sqrt(`iptw_var')
        local iptw_lo = `iptw_tau' - `z' * `iptw_se'
        local iptw_hi = `iptw_tau' + `z' * `iptw_se'
    }

    * =========================================================================
    * G-COMPUTATION ESTIMATE
    * =========================================================================
    if strpos(" `methods' ", " gcomp ") {
        local ++n_methods
        local method_names "`method_names' G-comp"

        quietly {
            * Set prediction option
            local pred_opt ""
            if inlist("`ofamily'", "logit", "probit") local pred_opt "pr"
            else if "`ofamily'" == "poisson" local pred_opt "n"

            * Fit outcome model in treated
            capture `ofamily' `outcome' `omodel' if `touse' & `treatment' == 1
            if _rc {
                set varabbrev `_vaset'
                noisily display as error "outcome model (`ofamily') failed in treated arm (G-comp)"
                exit 498
            }
            tempvar gc_mu1
            predict double `gc_mu1' if `touse', `pred_opt'

            * Fit outcome model in control
            capture `ofamily' `outcome' `omodel' if `touse' & `treatment' == 0
            if _rc {
                set varabbrev `_vaset'
                noisily display as error "outcome model (`ofamily') failed in control arm (G-comp)"
                exit 498
            }
            tempvar gc_mu0
            predict double `gc_mu0' if `touse', `pred_opt'
        }

        quietly {
            summarize `gc_mu1' if `touse', meanonly
            local gcomp_m1 = r(mean)
            summarize `gc_mu0' if `touse', meanonly
            local gcomp_m0 = r(mean)
        }
        local gcomp_tau = `gcomp_m1' - `gcomp_m0'

        * G-comp SE via IF
        quietly {
            tempvar gcomp_if gcomp_if2
            gen double `gcomp_if' = (`gc_mu1' - `gc_mu0') - `gcomp_tau' if `touse'
            gen double `gcomp_if2' = `gcomp_if'^2 if `touse'
            summarize `gcomp_if2' if `touse', meanonly
            local gcomp_var = r(sum) / (`N'^2)
        }
        local gcomp_se = sqrt(`gcomp_var')
        local gcomp_lo = `gcomp_tau' - `z' * `gcomp_se'
        local gcomp_hi = `gcomp_tau' + `z' * `gcomp_se'
    }

    * =========================================================================
    * AIPW ESTIMATE
    * =========================================================================
    if strpos(" `methods' ", " aipw ") {
        local ++n_methods
        local method_names "`method_names' AIPW"

        quietly {
            * Fit PS
            capture `tfamily' `treatment' `tmodel' if `touse'
            if _rc {
                set varabbrev `_vaset'
                noisily display as error "treatment model (`tfamily') failed to converge in AIPW"
                exit 498
            }
            tempvar aipw_ps
            predict double `aipw_ps' if `touse', pr
            replace `aipw_ps' = `trim_lo' if `touse' & `aipw_ps' < `trim_lo'
            replace `aipw_ps' = `trim_hi' if `touse' & `aipw_ps' > `trim_hi'

            * Fit outcome models
            tempvar aipw_mu1 aipw_mu0

            local pred_opt2 ""
            if inlist("`ofamily'", "logit", "probit") local pred_opt2 "pr"
            else if "`ofamily'" == "poisson" local pred_opt2 "n"

            capture `ofamily' `outcome' `omodel' if `touse' & `treatment' == 1
            if _rc {
                set varabbrev `_vaset'
                noisily display as error "outcome model (`ofamily') failed in treated arm (AIPW)"
                exit 498
            }
            predict double `aipw_mu1' if `touse', `pred_opt2'

            capture `ofamily' `outcome' `omodel' if `touse' & `treatment' == 0
            if _rc {
                set varabbrev `_vaset'
                noisily display as error "outcome model (`ofamily') failed in control arm (AIPW)"
                exit 498
            }
            predict double `aipw_mu0' if `touse', `pred_opt2'

            * AIPW pseudo-outcome
            tempvar aipw_phi
            gen double `aipw_phi' = (`aipw_mu1' - `aipw_mu0') ///
                + `treatment' * (`outcome' - `aipw_mu1') / `aipw_ps' ///
                - (1 - `treatment') * (`outcome' - `aipw_mu0') / (1 - `aipw_ps') ///
                if `touse'

            summarize `aipw_phi' if `touse', meanonly
            local aipw_tau = r(mean)

            * AIPW IF-based SE
            tempvar aipw_if2
            gen double `aipw_if2' = (`aipw_phi' - `aipw_tau')^2 if `touse'
            summarize `aipw_if2' if `touse', meanonly
            local aipw_var = r(sum) / (`N'^2)
        }
        local aipw_se = sqrt(`aipw_var')
        local aipw_lo = `aipw_tau' - `z' * `aipw_se'
        local aipw_hi = `aipw_tau' + `z' * `aipw_se'
    }

    * =========================================================================
    * DISPLAY COMPARISON TABLE
    * =========================================================================
    display as text "{hline 70}"
    display as text %12s "Method" as text " {c |}" ///
        as text %12s "`estimand'" as text %12s "Std. Err." ///
        as text %24s "[`level'% Conf. Interval]"
    display as text "{hline 12}{c +}{hline 57}"

    if strpos(" `methods' ", " iptw ") {
        display as text %12s "IPTW" as text " {c |}" ///
            as result %12.4f `iptw_tau' ///
            as result %12.4f `iptw_se' ///
            as result %12.4f `iptw_lo' ///
            as result %12.4f `iptw_hi'
    }

    if strpos(" `methods' ", " gcomp ") {
        display as text %12s "G-comp" as text " {c |}" ///
            as result %12.4f `gcomp_tau' ///
            as result %12.4f `gcomp_se' ///
            as result %12.4f `gcomp_lo' ///
            as result %12.4f `gcomp_hi'
    }

    if strpos(" `methods' ", " aipw ") {
        display as text %12s "AIPW" as text " {c |}" ///
            as result %12.4f `aipw_tau' ///
            as result %12.4f `aipw_se' ///
            as result %12.4f `aipw_lo' ///
            as result %12.4f `aipw_hi'
    }

    display as text "{hline 70}"

    * =========================================================================
    * BUILD COMPARISON MATRIX
    * =========================================================================
    local row = 0
    if strpos(" `methods' ", " iptw ")  local ++row
    if strpos(" `methods' ", " gcomp ") local ++row
    if strpos(" `methods' ", " aipw ")  local ++row

    matrix `comp_mat' = J(`row', 4, .)
    local r = 0
    local rnames ""
    if strpos(" `methods' ", " iptw ") {
        local ++r
        matrix `comp_mat'[`r', 1] = `iptw_tau'
        matrix `comp_mat'[`r', 2] = `iptw_se'
        matrix `comp_mat'[`r', 3] = `iptw_lo'
        matrix `comp_mat'[`r', 4] = `iptw_hi'
        local rnames "`rnames' IPTW"
    }
    if strpos(" `methods' ", " gcomp ") {
        local ++r
        matrix `comp_mat'[`r', 1] = `gcomp_tau'
        matrix `comp_mat'[`r', 2] = `gcomp_se'
        matrix `comp_mat'[`r', 3] = `gcomp_lo'
        matrix `comp_mat'[`r', 4] = `gcomp_hi'
        local rnames "`rnames' G-comp"
    }
    if strpos(" `methods' ", " aipw ") {
        local ++r
        matrix `comp_mat'[`r', 1] = `aipw_tau'
        matrix `comp_mat'[`r', 2] = `aipw_se'
        matrix `comp_mat'[`r', 3] = `aipw_lo'
        matrix `comp_mat'[`r', 4] = `aipw_hi'
        local rnames "`rnames' AIPW"
    }
    matrix colnames `comp_mat' = Estimate SE CI_lo CI_hi
    matrix rownames `comp_mat' = `rnames'

    * =========================================================================
    * GRAPH
    * =========================================================================
    if "`graph'" != "" {
        preserve
        quietly {
            clear
            local n_meth : word count `rnames'
            set obs `n_meth'
            gen str12 method = ""
            gen double estimate = .
            gen double ci_lo = .
            gen double ci_hi = .
            gen int order = .

            local ylbl ""
            forvalues i = 1/`n_meth' {
                local mname : word `i' of `rnames'
                replace method = "`mname'" in `i'
                replace estimate = `comp_mat'[`i', 1] in `i'
                replace ci_lo = `comp_mat'[`i', 3] in `i'
                replace ci_hi = `comp_mat'[`i', 4] in `i'
                local ord = `n_meth' - `i' + 1
                replace order = `ord' in `i'
                local ylbl `"`ylbl' `ord' "`mname'""'
            }

            local gopts `"title("Estimator Comparison: `estimand'") scheme(`scheme')"'
            if "`saving'" != "" local gopts `"`gopts' saving(`saving', replace)"'
            local gopts `"`gopts' name(drest_compare, replace)"'
        }
        capture noisily twoway (rcap ci_lo ci_hi order, horizontal lcolor(navy)) ///
               (scatter order estimate, msymbol(D) mcolor(navy) msize(medium)), ///
            ylabel(`ylbl', angle(0)) ///
            xlabel(, grid) ///
            ytitle("") xtitle("`estimand'") ///
            xline(0, lcolor(red) lpattern(dash)) ///
            legend(off) ///
            `gopts'
        local graph_rc = _rc
        restore
        if `graph_rc' {
            set varabbrev `_vaset'
            exit `graph_rc'
        }
    }

    * =========================================================================
    * STORE CHARACTERISTICS AND RETURN RESULTS
    * =========================================================================
    char _dta[_drest_compared] "1"

    return matrix comparison = `comp_mat'
    return scalar N = `N'
    return local methods "`methods'"
    return local estimand "`estimand'"
    return local outcome "`outcome'"
    return local treatment "`treatment'"

    if strpos(" `methods' ", " iptw ") {
        return scalar iptw_tau = `iptw_tau'
        return scalar iptw_se = `iptw_se'
    }
    if strpos(" `methods' ", " gcomp ") {
        return scalar gcomp_tau = `gcomp_tau'
        return scalar gcomp_se = `gcomp_se'
    }
    if strpos(" `methods' ", " aipw ") {
        return scalar aipw_tau = `aipw_tau'
        return scalar aipw_se = `aipw_se'
    }

    set varabbrev `_vaset'
end
