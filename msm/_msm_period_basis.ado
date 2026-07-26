*! _msm_period_basis Version 1.4.0  2026/07/26
*! Build a time basis for the msm weighting models from a period spec
*! Author: Timothy P Copeland, Karolinska Institutet

* Constructs the regressors that represent the time-dependent intercept
* alpha_0(k) of a weighting logit. Hernan, Brumback & Robins (2000),
* Epidemiology 11:561-570, p.564: the weight estimates were robust to the
* method used to estimate alpha_0(k) "provided that sufficient flexibility was
* allowed"; their own models used natural cubic splines in MONTH with five
* knots.
*
* Arguments:
*   varname       - the period variable
*   spec()        - none | linear | quadratic | cubic | ns(#)
*   prefix()      - stem for the generated basis columns
*   [touse()]     - sample used for spline knot placement
*
* Returns via c_local:
*   _msm_period_basis_vars    - the regressor list (may be empty)
*   _msm_period_basis_created - only the columns this call generated, so the
*                               caller can drop them; the period variable
*                               itself is never in this list

program define _msm_period_basis
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        syntax varname, SPEC(string) PREFIX(name) [TOUSE(varname)]

        local x "`varlist'"
        c_local _msm_period_basis_vars ""
        c_local _msm_period_basis_created ""

        local spec = lower(strtrim("`spec'"))
        if "`spec'" == "" local spec "none"

        if "`spec'" == "none" exit

        * linear needs no basis columns: the period variable is the basis.
        if "`spec'" == "linear" {
            c_local _msm_period_basis_vars "`x'"
            exit
        }

        if !inlist("`spec'", "quadratic", "cubic") & ///
            !regexm("`spec'", "^ns\([0-9]+\)$") {
            display as error ///
                "period spec must be none, linear, quadratic, cubic, or ns(#)"
            exit 198
        }

        * A basis column that collides with an existing variable belongs to the
        * caller's data; refuse rather than overwrite it.
        capture ds `prefix'*
        if _rc == 0 {
            display as error ///
                "reserved period-basis name(s) already in the data: `r(varlist)'"
            display as error "Drop or rename them before weighting."
            exit 110
        }

        if regexm("`spec'", "^ns\(([0-9]+)\)$") {
            local _df = regexs(1)
            local _touse_opt ""
            if "`touse'" != "" local _touse_opt "touse(`touse')"
            _msm_natural_spline `x', df(`_df') prefix(`prefix') `_touse_opt'
            c_local _msm_period_basis_vars "`_msm_spline_vars'"
            c_local _msm_period_basis_created "`_msm_spline_vars'"
            exit
        }

        quietly gen double `prefix'1 = `x'^2
        label variable `prefix'1 "Period squared"
        local created "`prefix'1"
        if "`spec'" == "cubic" {
            quietly gen double `prefix'2 = `x'^3
            label variable `prefix'2 "Period cubed"
            local created "`created' `prefix'2"
        }
        c_local _msm_period_basis_vars "`x' `created'"
        c_local _msm_period_basis_created "`created'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
