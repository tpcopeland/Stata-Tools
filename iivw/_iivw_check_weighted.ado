*! _iivw_check_weighted Version 2.0.0  2026/07/13
*! Verify weight variable exists before fitting
*! Author: Timothy P Copeland, Karolinska Institutet

program define _iivw_check_weighted, rclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    local __iivw_smcl_lb = char(123)
    local __iivw_smcl_rb = char(125)
    capture noisily {

    local weighted : char _dta[_iivw_weighted]
    if "`weighted'" != "1" {
        display as error "data has not been weighted"
        display as error ""
        display as error "Run `__iivw_smcl_lb'bf:iivw_weight`__iivw_smcl_rb' to compute inverse intensity weights."
        display as error "Example:"
        display as error "  `__iivw_smcl_lb'cmd:iivw_weight, id(patid) time(visit_months) ///`__iivw_smcl_rb'"
        display as error "  `__iivw_smcl_lb'cmd:  visit_cov(edss_bl age) lagvars(edss) ///`__iivw_smcl_rb'"
        display as error "  `__iivw_smcl_lb'cmd:  censor(fu_end) nolog`__iivw_smcl_rb'"
        exit 198
    }

    local wvar : char _dta[_iivw_weight_var]
    if "`wvar'" == "" local wvar "_iivw_weight"

    capture confirm variable `wvar'
    if _rc != 0 {
        display as error "weight variable `wvar' not found"
        display as error ""
        display as error "Run `__iivw_smcl_lb'bf:iivw_weight`__iivw_smcl_rb' to compute inverse intensity weights."
        exit 111
    }

    * The weights must still describe THIS data. Existence of the column proves
    * nothing: rows can be dropped, a covariate edited, or the weight column
    * overwritten between iivw_weight and here, and the old contract would have
    * fitted the stale weights without a word. Re-derive the fingerprint and
    * compare. A harmless re-sort does not change it (the signature is built
    * from sums); a real edit does.
    local stored : char _dta[_iivw_wsig]
    if "`stored'" != "" {
        local sid   : char _dta[_iivw_id]
        local stime : char _dta[_iivw_time]
        local scov  : char _dta[_iivw_visit_covars]

        * A missing key/covariate column is itself a broken contract.
        local missingvar ""
        foreach v in `sid' `stime' `scov' {
            capture confirm variable `v'
            if _rc local missingvar "`missingvar' `v'"
        }
        if "`missingvar'" != "" {
            display as error "the weighted data has changed since iivw_weight ran"
            display as error ""
            display as error "  these variables are gone:`missingvar'"
            display as error "  The stored weights were built from them, so they no longer"
            display as error "  describe this data. Re-run `__iivw_smcl_lb'bf:iivw_weight`__iivw_smcl_rb'."
            exit 459
        }

        _iivw_weight_signature, id(`sid') time(`stime') wvar(`wvar') ///
            covars(`scov')
        if "`r(signature)'" != "`stored'" {
            display as error "the weighted data has changed since iivw_weight ran"
            display as error ""
            display as error "  Rows, the id/time key, the visit covariates, or the weight column"
            display as error "  itself have been modified. The stored weights were computed for"
            display as error "  the earlier data and do not describe this data, so fitting with"
            display as error "  them would silently produce a weighted estimate that corresponds"
            display as error "  to no dataset."
            display as error ""
            display as error "  Re-run `__iivw_smcl_lb'bf:iivw_weight`__iivw_smcl_rb' on the current data."
            display as error "  (Re-sorting the data is safe and does not trigger this.)"
            exit 459
        }
    }

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
