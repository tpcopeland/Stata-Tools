*! _psdash_expand_fv Version 1.5.0  2026/07/22
*! Expand factor-variable / interaction covariate terms into design-column labels
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Internal helper

* Enumerates the design columns implied by a factor-variable covariate
* specification (e.g. i.cat, c.x##c.z) using Stata's own factor-variable
* machinery. Returns, for every NON-base, NON-omitted design term:
*   r(labels)  - readable term names (2.cat, c.x#c.z, ...) in fvexpand order
*   r(keepidx) - 1-based positions of those terms within the full fvexpand list,
*                so the caller can pick the matching fvrevar() design column
*                (fvrevar aligns 1:1 with fvexpand, base levels included)
*   r(basevars)- the underlying base variable names (for membership checks)
*   r(nall)    - total fvexpand term count (base included)
*   r(k)       - number of assessable (kept) design columns
* The helper does NOT materialize columns: fvrevar tempvars would be dropped at
* this program's exit. The caller runs fvrevar in its own scope and selects by
* keepidx. Perfectly collinear covariates are NOT silently dropped here (no
* estimation is run); they surface as duplicate design columns downstream.

program define _psdash_expand_fv, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        gettoken spec 0 : 0, parse(",")
        local spec = strtrim(`"`spec'"')
        syntax [, TOUSE(varname numeric) ]

        if `"`spec'"' == "" {
            display as error "_psdash_expand_fv: empty covariate specification"
            exit 198
        }

        local ifq ""
        if "`touse'" != "" local ifq "if `touse'"

        * Full design-term list (base levels included) for the specification.
        capture fvexpand `spec' `ifq'
        if _rc {
            display as error ///
                "psdash: covariates(`spec') is not a valid factor-variable specification"
            exit 459
        }
        local allterms `r(varlist)'
        local nall : word count `allterms'

        * Underlying base variables (used for distribution()/membership checks).
        capture fvrevar `spec' `ifq', list
        if _rc {
            display as error ///
                "psdash: covariates(`spec') references variables that are unavailable"
            exit 459
        }
        local basevars `r(varlist)'

        * Keep every non-base, non-omitted design term and record its position.
        local labels ""
        local keepidx ""
        local j = 0
        foreach t of local allterms {
            local ++j
            if regexm("`t'", "[0-9]+b\.") continue   // base level
            if regexm("`t'", "[0-9]+o\.") continue   // omitted / collinear
            local labels `"`labels' `t'"'
            local keepidx "`keepidx' `j'"
        }
        local labels = strtrim(`"`labels'"')
        local keepidx = strtrim("`keepidx'")
        local k : word count `keepidx'
        if `k' == 0 {
            display as error ///
                "psdash: covariates(`spec') expands to no assessable design columns"
            exit 459
        }

        return local labels `"`labels'"'
        return local keepidx "`keepidx'"
        return local basevars "`basevars'"
        return scalar nall = `nall'
        return scalar k = `k'
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
