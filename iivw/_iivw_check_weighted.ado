*! _iivw_check_weighted Version 2.0.0  2026/07/14
*! Verify the stored weights still describe the data in memory before fitting
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
    * ---------------------------------------------------------------------
    * FAIL CLOSED. This used to be `if the signature is stored, check it' --
    * which means that if the signature is NOT stored, nothing is checked and
    * the fit proceeds. Blanking one characteristic disarmed the entire guard
    * and returned 0. A guard that a single edit can switch off silently is not
    * a guard; it is a guard-shaped hole.
    *
    * Every contract this package writes carries a signature: iivw_weight stamps
    * it at its commit point, and the bootstrap restores it. So a dataset that
    * claims to be weighted and has no signature is either a pre-2.0.0 contract
    * or a tampered one, and neither can be verified. Refuse both.
    * ---------------------------------------------------------------------
    local stored : char _dta[_iivw_wsig]
    if "`stored'" == "" {
        display as error "the weighting contract has no signature"
        display as error ""
        display as error "  These weights cannot be verified against the data in memory, so there"
        display as error "  is no way to tell whether they still describe it. That happens when the"
        display as error "  data was weighted by a version of iivw older than 2.0.0, or when the"
        display as error "  stored contract has been edited."
        display as error ""
        display as error "  Re-run `__iivw_smcl_lb'bf:iivw_weight`__iivw_smcl_rb' on the current data."
        exit 459
    }

    local sid   : char _dta[_iivw_id]
    local stime : char _dta[_iivw_time]

    * The key columns must still be there before the signature can even be
    * built. Everything else the contract binds -- the treatment, the
    * treatment-model covariates, the raw lag sources, the component weights
    * -- is checked BY the signature, which records a vanished column as
    * `name:GONE' rather than silently omitting it.
    local missingvar ""
    foreach v in `sid' `stime' {
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

    _iivw_weight_signature
    if "`r(signature)'" != "`stored'" {
        display as error "the weighted data has changed since iivw_weight ran"
        display as error ""
        display as error "  Rows, the id/time key, the treatment, a model covariate, a lag"
        display as error "  source, a component weight, the final weight column, or the stored"
        display as error "  specification itself has been modified. The stored weights were"
        display as error "  computed for the earlier data and do not describe this data, so"
        display as error "  using them would silently produce a weighted estimate that"
        display as error "  corresponds to no dataset."
        display as error ""
        display as error "  Re-run `__iivw_smcl_lb'bf:iivw_weight`__iivw_smcl_rb' on the current data."
        display as error "  (Re-sorting the data is safe and does not trigger this.)"
        exit 459
    }

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
