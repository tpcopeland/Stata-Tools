*! _drest_influence Version 1.0.0  2026/03/15
*! Compute influence function variance and standard error
*! Author: Timothy P Copeland

* Usage: _drest_influence ifvar touse tau estimand [treatment]
* Computes: Var(tau) = (1/n^2) * sum(IF_i^2) for ATE
* Returns via c_local: _drest_se, _drest_var

program define _drest_influence
    version 16.0
    set varabbrev off
    set more off

    args ifvar touse tau estimand treatment

    if "`estimand'" == "" local estimand "ATE"
    local estimand = upper("`estimand'")

    quietly {
        if "`estimand'" == "ATE" {
            * IF_i = phi_i - tau
            * Var(tau) = (1/n^2) * sum(IF_i^2)
            tempvar ifc
            gen double `ifc' = (`ifvar' - `tau')^2 if `touse'
            summarize `ifc' if `touse', meanonly
            local N = r(N)
            local variance = r(sum) / (`N'^2)
        }
        else if "`estimand'" == "ATT" {
            * Var(ATT) = (1/n1^2) * sum(IF_i^2)
            count if `touse' & `treatment' == 1
            local n1 = r(N)
            tempvar ifc
            gen double `ifc' = (`ifvar' - `tau' * `treatment')^2 if `touse'
            summarize `ifc' if `touse', meanonly
            local variance = r(sum) / (`n1'^2)
        }
        else if "`estimand'" == "ATC" {
            count if `touse' & `treatment' == 0
            local n0 = r(N)
            tempvar ifc
            gen double `ifc' = (`ifvar' - `tau' * (1 - `treatment'))^2 if `touse'
            summarize `ifc' if `touse', meanonly
            local variance = r(sum) / (`n0'^2)
        }

        local se = sqrt(`variance')
    }

    c_local _drest_se  "`se'"
    c_local _drest_var "`variance'"
end
