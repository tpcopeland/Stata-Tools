*! _iivw_weight_signature Version 2.0.1  2026/07/21
*! Sort-invariant signature binding the stored weighting contract to the data
*! it describes: every consumed input, every owned output, and the specification
*! itself.
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

* Why this exists
* ---------------
* The weight contract used to be a characteristic plus "does the column still
* exist". Nothing stopped a user from dropping rows, editing a covariate, or
* overwriting the weight column between iivw_weight and iivw_fit -- the stored
* specification silently stopped describing the data, and the fit ran anyway
* on weights that no longer belonged to it. rc 0, wrong answer.
*
* What it binds, and why that is not obvious
* -----------------------------------------
* An earlier build bound only the final weight, the id/time key, and the
* GENERATED visit-model covariate list. Everything else the weights were built
* from was unbound, and two probes on 2026-07-14 showed exactly what that costs:
* editing a subject's treat() value, and then editing a treat_cov() value, each
* left _iivw_check_weighted returning 0. The stored FIPTIW weights no longer
* described the data and every downstream consumer accepted them.
*
* So the signature now binds EVERYTHING the contract names:
*
*   inputs   id, time, entry, censor, raw visit covariates, raw lag sources,
*            generated lag columns, stabilization covariates, treatment,
*            treatment-model covariates
*   outputs  _iivw_iw, _iivw_ps, _iivw_tw, and the final weight
*   spec     the weight type, prefix, baseline mode, risk-set contract, tie
*            method, truncation, estimand, and convergence state
*
* Binding the components separately (not just their product) is what makes a
* corrupted _iivw_iw with a compensating _iivw_tw detectable.
*
* This is a fingerprint, NOT a cryptographic hash: distinct datasets can in
* principle collide. It is built to catch accident (an edit, a drop, a merge, a
* re-weight), not to withstand an adversary.
*
* It is deliberately built ONLY from sums, so it is invariant to row order: a
* harmless `sort' or `gsort' between weighting and fitting must not trip it.
* For each bound column v the parts are sum(v), sum(v^2), sum(v*k), sum(v*t)
* and the missing count, where k = group(id). The CROSS terms are what bind
* each value to the row it belongs to -- without them, permuting a column
* against the key would leave sum(v) and sum(v^2) unchanged and pass.

program define _iivw_weight_signature, rclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax [, noSPEC]

    * ---------------------------------------------------------------------
    * Read the contract. The signature is computed from the stored
    * characteristics, never from arguments, so the producer (iivw_weight, at
    * its commit point) and every consumer (_iivw_check_weighted) build it from
    * exactly the same definition. An argument list would let the two drift.
    * ---------------------------------------------------------------------
    local s_id       : char _dta[_iivw_id]
    local s_time     : char _dta[_iivw_time]
    local s_wvar     : char _dta[_iivw_weight_var]
    local s_iw       : char _dta[_iivw_iw_var]
    local s_tw       : char _dta[_iivw_tw_var]
    local s_ps       : char _dta[_iivw_ps_var]
    local s_vcraw    : char _dta[_iivw_visit_cov_raw]
    local s_lagsrc   : char _dta[_iivw_lagvars]
    local s_lagnames : char _dta[_iivw_lag_names]
    local s_stabcov  : char _dta[_iivw_stabcov]
    local s_treat    : char _dta[_iivw_treat]
    local s_tcov     : char _dta[_iivw_treat_covars]
    local s_entry    : char _dta[_iivw_entry]
    local s_censvar  : char _dta[_iivw_censor_var]

    if "`s_id'" == "" | "`s_time'" == "" {
        display as error "_iivw_weight_signature: no weighting contract in the data"
        error 198
    }

    * ---------------------------------------------------------------------
    * The bound columns: every input the weights were computed FROM, and every
    * output the package OWNS. Order is fixed and deduplicated so the same
    * data always yields the same string.
    * ---------------------------------------------------------------------
    local __iivw_bind ///
        `s_time' `s_entry' `s_censvar' `s_vcraw' `s_lagsrc' `s_lagnames' ///
        `s_stabcov' `s_treat' `s_tcov' `s_iw' `s_ps' `s_tw' `s_wvar'
    local __iivw_bind : list uniq __iivw_bind

    * ---------------------------------------------------------------------
    * The keys. group() rather than the raw id: it accepts a string id, and it
    * numbers by sorted id value, so it does not depend on the row order.
    * ---------------------------------------------------------------------
    tempvar k
    quietly egen long `k' = group(`s_id')

    local __iivw_n = _N

    * group() numbers the subjects 1..G, so the maximum IS the subject count.
    * NOT levelsof: that materializes every distinct id into a macro, and Stata
    * macros are capped -- a large registry panel would abort the signature (and
    * therefore every fit) on a limit that has nothing to do with the weights.
    quietly summarize `k', meanonly
    local __iivw_nid = r(max)
    if `__iivw_nid' == . local __iivw_nid = 0

    quietly count if missing(`k')
    local __iivw_nidmiss = r(N)

    * %21x is Stata's exact hexadecimal float format: a signature written with
    * %10.0g would round away the very edits it is meant to detect.
    local __iivw_parts "`__iivw_n'|`__iivw_nid'|`__iivw_nidmiss'"

    foreach __iivw_v of local __iivw_bind {
        capture confirm numeric variable `__iivw_v'
        if _rc {
            * A bound column that is gone, or has become non-numeric, is itself
            * a broken contract. Record it as such rather than skipping it: a
            * skipped column is a column whose edits stop being detected.
            local __iivw_parts "`__iivw_parts'|`__iivw_v':GONE"
            continue
        }

        tempvar v2 vk vt
        quietly generate double `v2' = `__iivw_v' * `__iivw_v'
        quietly generate double `vk' = `__iivw_v' * `k'
        quietly generate double `vt' = `__iivw_v' * `s_time'

        local __iivw_parts "`__iivw_parts'|`__iivw_v':"
        foreach __iivw_c in `__iivw_v' `v2' `vk' `vt' {
            quietly summarize `__iivw_c', meanonly
            local __iivw_sum = cond(r(N) == 0, 0, r(sum))
            local __iivw_parts "`__iivw_parts'`=string(`__iivw_sum', "%21x")',"
        }
        quietly count if missing(`__iivw_v')
        local __iivw_parts "`__iivw_parts'`r(N)'"

        drop `v2' `vk' `vt'
    }

    * ---------------------------------------------------------------------
    * Bind the SPECIFICATION too. Two datasets with identical columns but a
    * different stored weight type, risk-set contract, or truncation describe
    * different estimators; a consumer that reads the contract must be able to
    * tell that the contract itself was edited.
    * ---------------------------------------------------------------------
    if "`spec'" != "nospec" {
        local __iivw_specparts ""
        foreach __iivw_ch in _iivw_weighttype _iivw_prefix _iivw_baseevent ///
            _iivw_censor_mode _iivw_maxfu _iivw_truncate _iivw_efron ///
            _iivw_ps_estimand _iivw_contract_version _iivw_nonconverged ///
            _iivw_allowmissingweights _iivw_visit_covars ///
            _iivw_treat_in_visit ///
            _iivw_truncvisit _iivw_trunctreat _iivw_truncfinal ///
            _iivw_tv_locut _iivw_tv_hicut _iivw_tt_locut _iivw_tt_hicut {
            local __iivw_cv : char _dta[`__iivw_ch']
            local __iivw_specparts "`__iivw_specparts'~`__iivw_cv'"
        }
        local __iivw_parts "`__iivw_parts'|spec`__iivw_specparts'"
    }

    return local signature "`__iivw_parts'"
    return local bound "`__iivw_bind'"

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
