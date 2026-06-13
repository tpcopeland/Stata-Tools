*! _msm_natural_spline Version 1.1.0  2026/06/14
*! Generate natural spline basis variables
*! Author: Timothy P Copeland

* Creates basis variables for natural cubic splines using the Harrell
* restricted cubic spline formulation.
*
* Arguments: variable, df (degrees of freedom), prefix for basis vars
* Returns via c_local: list of created variable names, knot positions, df

program define _msm_natural_spline
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        syntax varname, df(integer) prefix(string) [touse(varname)]

        if `df' < 1 {
            display as error "df() must be at least 1"
            exit 198
        }

        local x "`varlist'"

        * If no touse specified, use all observations
        if "`touse'" == "" {
            tempvar touse
            gen byte `touse' = 1
        }

        * Get range of x
        quietly summarize `x' if `touse'
        local xmin = r(min)
        local xmax = r(max)
        local xrange = `xmax' - `xmin'

        if `xrange' == 0 {
            display as error "variable `x' has no variation"
            exit 198
        }

        * Place knots at quantiles
        local basisvars ""

        if `df' == 1 {
            * Linear: just the variable itself
            gen double `prefix'1 = `x'
            local basisvars "`prefix'1"
            local knot0 = `xmin'
            local knot1 = `xmax'
        }
        else {
            * Calculate knot positions using quantiles
            local n_internal = `df' - 1
            forvalues k = 1/`n_internal' {
                local pct = 100 * `k' / (`n_internal' + 1)
                quietly _pctile `x' if `touse', percentiles(`pct')
                local knot`k' = r(r1)
            }

            * Boundary knots at min and max
            local knot0 = `xmin'
            local knot`df' = `xmax'

            * Generate basis: first column is x itself
            gen double `prefix'1 = `x'
            local basisvars "`prefix'1"

            * Harrell restricted cubic spline formulation
            local t_last = `knot`df''
            local t_pen  = `knot`n_internal''

            if `n_internal' == 1 {
                local jj = 2
                gen double `prefix'`jj' = ///
                    (max(0, `x' - `knot1')^3 - ///
                     max(0, `x' - `knot`df'')^3) / ///
                    (`knot`df'' - `knot1')
                local basisvars "`basisvars' `prefix'`jj'"
            }
            else {
                * Harrell RCS: df-1 nonlinear bases using knots 0..n_internal-1
                * (boundary min through second-to-last internal knot)
                forvalues j = 0/`=`n_internal'-1' {
                    local jj = `j' + 2
                    gen double `prefix'`jj' = ///
                        (max(0, `x' - `knot`j'')^3 - max(0, `x' - `t_last')^3) / ///
                        (`t_last' - `knot`j'') - ///
                        (max(0, `x' - `t_pen')^3 - max(0, `x' - `t_last')^3) / ///
                        (`t_last' - `t_pen')

                    local basisvars "`basisvars' `prefix'`jj'"
                }
            }
        }

        * Return knot positions
        local knot_list "`knot0'"
        if `df' > 1 {
            local n_internal = `df' - 1
            forvalues k = 1/`n_internal' {
                local knot_list "`knot_list' `knot`k''"
            }
        }
        local knot_list "`knot_list' `knot`df''"

        c_local _msm_spline_vars "`basisvars'"
        c_local _msm_spline_knots "`knot_list'"
        c_local _msm_spline_df "`df'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
