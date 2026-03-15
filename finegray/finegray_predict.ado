*! finegray_predict Version 1.0.0  2026/03/15
*! Post-estimation predictions after finegray
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass

/*
Basic syntax:
  finegray_predict newvar [if] [in], [cif xb timevar(varname)]

Description:
  Generate predictions after finegray.

  xb (default) - linear predictor z'beta
  cif          - cumulative incidence function: 1 - exp(-H0(t)*exp(xb))

Required:
  newvar - name for the new variable

Options:
  cif          - predict CIF instead of xb
  xb           - predict linear predictor (default)
  timevar(var) - use specified variable for time (instead of _t)

See help finegray for complete documentation
*/

program define finegray_predict
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    syntax newvarname [if] [in] , [CIF XB TIMEvar(varname numeric)]

    * Check finegray was run
    if "`e(cmd)'" != "finegray" {
        display as error "last estimates not found"
        display as error "you must run {bf:finegray} before using finegray_predict"
        set varabbrev `_vaset'
        exit 301
    }

    * Default to xb
    local n_types = ("`cif'" != "") + ("`xb'" != "")
    if `n_types' > 1 {
        display as error "specify only one of cif or xb"
        set varabbrev `_vaset'
        exit 198
    }
    if `n_types' == 0 local xb "xb"

    marksample touse, novarlist

    quietly count if `touse'
    if r(N) == 0 {
        set varabbrev `_vaset'
        display as error "no observations"
        exit 2000
    }

    if "`xb'" != "" {
        * Linear predictor: matrix score
        if "`typlist'" == "" local typlist "double"
        tempname b
        matrix `b' = e(b)
        matrix score `typlist' `varlist' = `b' if `touse'
        label variable `varlist' "Linear prediction (xb)"
    }
    else if "`cif'" != "" {
        * CIF = 1 - exp(-H0(t) * exp(xb))
        capture confirm matrix e(basehaz)
        if _rc {
            display as error "baseline hazard not available"
            display as error "CIF prediction requires e(basehaz) from finegray"
            set varabbrev `_vaset'
            exit 198
        }

        * Get time variable
        local tvar "_t"
        if "`timevar'" != "" local tvar "`timevar'"

        capture confirm variable `tvar'
        if _rc {
            display as error "time variable `tvar' not found"
            set varabbrev `_vaset'
            exit 111
        }

        * Compute xb first
        tempvar xb_val
        tempname b
        matrix `b' = e(b)
        matrix score double `xb_val' = `b' if `touse'

        * Get basehaz matrix
        tempname bh
        matrix `bh' = e(basehaz)
        local n_bh = rowsof(`bh')

        if "`typlist'" == "" local typlist "double"

        * Compute CIF in Stata
        * H0(t_i) = baseline cumhazard at time t_i (step function)
        * CIF(t_i|z) = 1 - exp(-H0(t_i) * exp(z'beta))
        tempvar H0_val
        quietly gen double `H0_val' = 0 if `touse'

        * Step function lookup: for each obs, find largest basehaz time <= _t
        forvalues j = 1/`n_bh' {
            local bh_t = `bh'[`j', 1]
            local bh_h = `bh'[`j', 2]
            quietly replace `H0_val' = `bh_h' if `tvar' >= `bh_t' & `touse'
        }

        quietly gen `typlist' `varlist' = ///
            1 - exp(-`H0_val' * exp(`xb_val')) if `touse'
        label variable `varlist' "CIF prediction"
    }

    set varabbrev `_vaset'
end
