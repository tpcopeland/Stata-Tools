*! _tte_natural_spline Version 1.0.3  2026/03/10
*! Generate natural spline basis variables
*! Author: Timothy P Copeland

* Creates basis variables for natural cubic splines using the Harrell
* restricted cubic spline formulation.
*
* Arguments: variable, df (degrees of freedom), prefix for basis vars
* Returns via c_local: list of created variable names, knot positions, df

program define _tte_natural_spline
    version 16.0
    set varabbrev off
    set more off

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

    * Number of knots = df + 1 (boundary knots at min/max, internal knots
    * at equally spaced quantiles)
    local n_knots = `df' + 1

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
        * Internal knots at equally spaced quantiles
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

        * Additional basis columns using Harrell restricted cubic spline
        * formulation. For K knots (t_0, ..., t_{K-1}), the nonlinear
        * basis functions are:
        *   h_j(x) = d_j(x) - d_{K-2}(x)   for j = 0, ..., K-3
        * where:
        *   d_j(x) = ((x - t_j)_+^3 - (x - t_{K-1})_+^3) / (t_{K-1} - t_j)
        *
        * Here K = n_knots = df+1, so:
        *   boundary knots: knot0 (t_0) and knot`df' (t_{K-1})
        *   penultimate knot: knot`n_internal' (t_{K-2})
        *   loop j = 0, ..., n_internal-1 (= K-2 nonlinear bases)
        *   Plus the linear basis = df total basis functions.
        *
        * For df=2: 1 internal knot, 1 nonlinear basis via simpler formula
        * For df>=3: n_internal nonlinear bases via Harrell formula

        local t_last = `knot`df''
        local t_pen  = `knot`n_internal''

        if `n_internal' == 1 {
            * df=2: single nonlinear basis from the one internal knot
            * d_1(x) = ((x - knot1)_+^3 - (x - knot2)_+^3) / (knot2 - knot1)
            local jj = 2
            gen double `prefix'`jj' = ///
                (max(0, `x' - `knot1')^3 - ///
                 max(0, `x' - `knot`df'')^3) / ///
                (`knot`df'' - `knot1')
            local basisvars "`basisvars' `prefix'`jj'"
        }
        else {
            * df>=3: Harrell RCS formula
            * h_j(x) = d_j(x) - d_pen(x) for j = 0, ..., n_internal-1
            local n_nonlinear = `n_internal'
            forvalues j = 0/`=`n_nonlinear' - 1' {
                local jj = `j' + 2
                * d_j(x) = ((x-knot_j)_+^3 - (x-t_last)_+^3) / (t_last-knot_j)
                * d_pen(x) = ((x-t_pen)_+^3 - (x-t_last)_+^3) / (t_last-t_pen)
                * h_j(x) = d_j(x) - d_pen(x)
                gen double `prefix'`jj' = ///
                    (max(0, `x' - `knot`j'')^3 - max(0, `x' - `t_last')^3) / ///
                    (`t_last' - `knot`j'') - ///
                    (max(0, `x' - `t_pen')^3 - max(0, `x' - `t_last')^3) / ///
                    (`t_last' - `t_pen')

                local basisvars "`basisvars' `prefix'`jj'"
            }
        }
    }

    * Return knot positions for use in prediction
    local knot_list "`knot0'"
    if `df' > 1 {
        local n_internal = `df' - 1
        forvalues k = 1/`n_internal' {
            local knot_list "`knot_list' `knot`k''"
        }
    }
    local knot_list "`knot_list' `knot`df''"

    c_local _tte_spline_vars "`basisvars'"
    c_local _tte_spline_knots "`knot_list'"
    c_local _tte_spline_df "`df'"
end
