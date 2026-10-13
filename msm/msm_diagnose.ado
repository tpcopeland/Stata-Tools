*! msm_diagnose Version 2.0.0  2026/10/13
*! Longitudinal covariate balance and positivity diagnostics for MSM
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())
*! Longitudinal balance: Adenyo et al. (2024), doi:10.1002/sim.10188

/*
Basic syntax:
  msm_diagnose [, options]

Description:
  Diagnostics psdash cannot produce for a longitudinal MSM: covariate balance
  within period x prior-treatment history (with the stabilized-numerator
  target flag), censoring-decision balance, and the operational positivity
  floor on the estimated probability of the OBSERVED treatment decision. A
  pooled person-period SMD table is kept as a secondary summary. Pooled and
  by-period weight distributions moved to psdash in msm 2.0.0
  (psdash weights / psdash combined, wvar(_msm_weight)).

Options:
  balance_covariates(varlist)  - Covariates for balance assessment
  threshold(#)                 - SMD threshold for balance (default: 0.1)
  positivity(#)                - Observed-decision probability floor (default: 0.01)

See help msm_diagnose for complete documentation
*/

program define msm_diagnose, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    local _caller_sorted : sortedby
    tempname _caller_r
    _return hold `_caller_r'
    set varabbrev off
    set more off

    * The longitudinal balance block below uses bysort over each individual's
    * history, which leaves the caller's observations in id/period order. Capture
    * the incoming order now and restore it on every exit path (audit A06). Every
    * other sorting command in the suite already does this; msm_diagnose was the
    * one that silently handed the caller back a re-sorted dataset.
    tempvar _msm_orig_order

    capture noisily {

    quietly gen long `_msm_orig_order' = _n

    * by_period, accumulate(), contrast() and outcome() were removed in msm
    * 2.0.0. They are still parsed so the refusal can name the replacement
    * instead of a bare "option not allowed".
    syntax [, BALance_covariates(varlist numeric) THReshold(real 0.1) ///
              POSITivity(real 0.01) ///
              BY_period ACCUMulate(string) CONTrast(string) OUTcome(string)]
    if "`by_period'" != "" {
        display as error "msm_diagnose, by_period was removed in msm 2.0.0"
        display as error "Use {bf:psdash combined, wvar(_msm_weight)} (psdash) for per-period weight summaries."
        exit 198
    }
    if `"`accumulate'`contrast'`outcome'"' != "" {
        display as error "msm_diagnose accumulate(), contrast() and outcome() were removed in msm 2.0.0"
        display as error "Post the returned scalars and matrices to your own frame with {bf:frame post}."
        exit 198
    }

    * Operational positivity floor (audit A25): the estimated probability of the
    * OBSERVED treatment must stay away from 0, or the inverse-probability weight
    * is unstable (Cole & Hernan 2008). Must be a proper probability floor.
    if `positivity' <= 0 | `positivity' >= 0.5 {
        display as error "positivity() must be strictly between 0 and 0.5; got `positivity'"
        exit 198
    }

    * The SMD threshold must be finite and nonnegative (audit A26): a negative
    * threshold makes |SMD| > threshold always true (everything "imbalanced"),
    * and a missing threshold compares as +infinity.
    if `threshold' < 0 | `threshold' >= . {
        display as error "threshold() must be finite and nonnegative; got `threshold'"
        exit 198
    }

    * Check prerequisites
    _msm_check_prepared
    _msm_check_weighted
    _msm_get_settings

    local id         "`_msm_id'"
    local period     "`_msm_period'"
    local treatment  "`_msm_treatment'"
    local outcome    "`_msm_outcome'"
    local censor     "`_msm_censor'"

    * Default balance covariates to mapped covariates
    if "`balance_covariates'" == "" {
        local balance_covariates "`_msm_covariates' `_msm_bl_covs'"
        local balance_covariates = strtrim("`balance_covariates'")
    }
    * Nothing mapped: fall back to the treatment-denominator covariates
    if "`balance_covariates'" == "" {
        local balance_covariates : char _dta[_msm_ps_covars]
        local balance_covariates = strtrim("`balance_covariates'")
        if "`balance_covariates'" != "" {
            display as text "note: no covariates mapped in msm_prepare; using the treatment-denominator covariates: " as result "`balance_covariates'"
        }
    }
    if "`balance_covariates'" == "" {
        display as error "msm_diagnose needs at least one balance covariate"
        display as error "Map covariates() or baseline_covariates() in {bf:msm_prepare}, or specify {bf:balance_covariates()}."
        exit 198
    }

    display as text ""
    display as text "{hline 70}"
    display as result "msm_diagnose" as text " - Longitudinal Balance and Positivity"
    display as text "{hline 70}"
    display as text "Weight distributions: {bf:psdash weights} / {bf:psdash combined, wvar(_msm_weight)}"

    * =========================================================================
    * COVARIATE BALANCE (SMD)
    * =========================================================================

    if "`balance_covariates'" != "" {
        * ---------------------------------------------------------------------
        * PRIMARY LONGITUDINAL DIAGNOSTICS
        * ---------------------------------------------------------------------
        * Stabilized treatment weights condition on prior treatment after the
        * baseline decision. Balance is therefore assessed within period and
        * prior-treatment stratum; a pooled person-period SMD can cancel
        * opposite imbalances and is retained only as a secondary summary.
        tempvar _hist _tb_use _p_obs
        quietly summarize `period', meanonly
        local _min_period = r(min)
        quietly bysort `id' (`period'): gen double `_hist' = `treatment'[_n-1]
        quietly replace `_hist' = -1 if `period' == `_min_period'

        * Estimated probability of the OBSERVED treatment decision (audit A25).
        * The support columns ps_min/ps_max report the range of P(A=1); that is
        * NOT the quantity that governs weight stability. An untreated row whose
        * P(A=1) is near 1 has an observed-decision probability near 0 and
        * generates an extreme weight, while leaving ps_min untouched. Cole &
        * Hernan (2008) define the positivity failure on the probability of the
        * decision the subject actually made, so the floor is applied to this.
        quietly gen double `_p_obs' = cond(`treatment' == 1, ///
            _msm_treat_den_raw, 1 - _msm_treat_den_raw) ///
            if _msm_decision_risk & !missing(`treatment')

        tempname _tbal _trow _support _srow
        local _numer_covars : char _dta[_msm_numer_covars]
        quietly levelsof `period' if _msm_decision_risk, local(_diag_periods)
        foreach _p of local _diag_periods {
            quietly levelsof `_hist' if _msm_decision_risk & ///
                `period' == `_p' & !missing(`_hist'), local(_histories)
            foreach _h of local _histories {
                quietly gen byte `_tb_use' = _msm_decision_risk & ///
                    `period' == `_p' & `_hist' == `_h' & ///
                    !missing(`treatment')
                quietly count if `_tb_use' & `treatment' == 1
                local _nt = r(N)
                quietly count if `_tb_use' & `treatment' == 0
                local _nu = r(N)
                _msm_ess _msm_weight if `_tb_use'
                local _row_ess = r(ess)
                local _cov_idx = 0
                foreach _x of local balance_covariates {
                    local ++_cov_idx
                    _msm_smd `_x', treatment(`treatment') touse(`_tb_use')
                    local _raw_smd = `_msm_smd_value'
                    _msm_smd `_x', treatment(`treatment') ///
                        weight(_msm_weight) touse(`_tb_use')
                    local _weighted_smd = `_msm_smd_value'
                    local _target = 1
                    if `: list _x in _numer_covars' local _target = 0
                    matrix `_trow' = (`_p', `_h', `_cov_idx', `_raw_smd', ///
                        `_weighted_smd', `_nt', `_nu', `_row_ess', `_target')
                    matrix `_tbal' = nullmat(`_tbal') \ `_trow'
                }
                drop `_tb_use'
            }

            quietly count if _msm_decision_risk & `period' == `_p' & ///
                !missing(`treatment')
            local _N = r(N)
            quietly count if _msm_decision_risk & `period' == `_p' & ///
                `treatment' == 1
            local _Nt = r(N)
            local _Nu = `_N' - `_Nt'
            quietly summarize _msm_treat_den_raw if _msm_decision_risk & ///
                `period' == `_p', meanonly
            local _psmin = r(min)
            local _psmax = r(max)
            quietly summarize _msm_treat_den_raw if _msm_decision_risk & ///
                `period' == `_p' & `treatment' == 1, meanonly
            local _tmin = r(min)
            local _tmax = r(max)
            quietly summarize _msm_treat_den_raw if _msm_decision_risk & ///
                `period' == `_p' & `treatment' == 0, meanonly
            local _umin = r(min)
            local _umax = r(max)
            local _common_lo = max(`_tmin', `_umin')
            local _common_hi = min(`_tmax', `_umax')
            if missing(`_common_lo') | missing(`_common_hi') | ///
                `_common_lo' > `_common_hi' {
                local _nout = `_N'
            }
            else {
                quietly count if _msm_decision_risk & `period' == `_p' & ///
                    (missing(_msm_treat_den_raw) | ///
                     _msm_treat_den_raw < `_common_lo' | ///
                     _msm_treat_den_raw > `_common_hi')
                local _nout = r(N)
            }
            _msm_ess _msm_weight if _msm_decision_risk & `period' == `_p'
            local _pess = r(ess)
            * Smallest estimated probability of the observed treatment decision
            * in this period -- the quantity the positivity floor is defined on.
            *
            * A decision-risk row with no usable raw probability is the most
            * extreme support failure there is, and summarize would simply skip
            * it, letting the period read as unviolated on the strength of its
            * remaining rows. Report obs_min as an exact 0 instead: estimable
            * probabilities are strictly inside (0,1), so 0 is an unambiguous
            * "no usable probability here" sentinel and it trips the floor. This
            * is reachable only under the explicit probpolicy(clip) opt-in;
            * probpolicy(error) refuses in msm_weight before this point.
            quietly count if _msm_decision_risk & `period' == `_p' & ///
                !missing(`treatment') & missing(_msm_treat_den_raw)
            local _n_unusable = r(N)
            quietly summarize `_p_obs' if _msm_decision_risk & ///
                `period' == `_p', meanonly
            local _obsmin = r(min)
            if r(N) == 0 local _obsmin = .
            if `_n_unusable' > 0 local _obsmin = 0
            matrix `_srow' = (`_p', `_N', `_Nt', `_Nu', `_psmin', `_psmax', ///
                `_obsmin', `_common_lo', `_common_hi', `_nout', `_pess')
            matrix `_support' = nullmat(`_support') \ `_srow'
        }
        matrix colnames `_tbal' = period history covariate raw_smd ///
            weighted_smd n_treated n_untreated ess target
        matrix colnames `_support' = period N treated untreated ps_min ps_max ///
            obs_min common_lo common_hi n_outside ess
        * Working copies: `return matrix' MOVES its argument (msm 2.0.0 no
        * longer leaves _msm_*_matrix globals in the caller's namespace).
        tempname _tbal_c _support_c
        matrix `_tbal_c' = `_tbal'
        matrix `_support_c' = `_support'
        return matrix treatment_balance = `_tbal'
        return matrix support = `_support'

        * Operational positivity (audit A25): flag periods whose smallest
        * estimated probability of the OBSERVED treatment (support obs_min,
        * column 7) falls below the positivity() floor -- the cells that generate
        * the extreme weights a marginal by-period support count cannot see (Cole
        * & Hernan 2008). Returned as a count plus the periods, not just
        * displayed.
        *
        * This deliberately does NOT read ps_min (column 5). ps_min is the
        * smallest P(A=1) in the period, which answers a different question: it
        * fires on a well-supported period in which everyone is comfortably
        * untreated, and stays silent on a period in which untreated rows sit at
        * P(A=1) -> 1 and carry observed-decision probabilities near zero. Only
        * the observed-decision probability tracks the weight the estimator
        * actually receives.
        *
        * Read the working copy (`_support_c'); `return matrix support'
        * above MOVES the `_support' tempname, so it no longer exists here.
        quietly summarize `_p_obs' if _msm_decision_risk, meanonly
        local _min_obs_overall = cond(r(N) == 0, ., r(min))
        quietly count if _msm_decision_risk & !missing(`treatment') & ///
            missing(_msm_treat_den_raw)
        if r(N) > 0 local _min_obs_overall = 0

        local _n_pos_viol = 0
        local _pos_viol_periods ""
        local _pos_viol_min = .
        forvalues _r = 1/`=rowsof(`_support_c')' {
            local _p_r  = `_support_c'[`_r', 1]
            local _obmn = `_support_c'[`_r', 7]
            if !missing(`_obmn') & `_obmn' < `positivity' {
                local ++_n_pos_viol
                local _pos_viol_periods "`_pos_viol_periods' `_p_r'"
                if missing(`_pos_viol_min') | `_obmn' < `_pos_viol_min' ///
                    local _pos_viol_min = `_obmn'
            }
        }
        local _pos_viol_periods = strtrim("`_pos_viol_periods'")

        * Structural support (msm 2.0.0; formerly msm_validate check 10): a
        * period in which no decision-risk row is treated, or none untreated,
        * has no observed contrast at all. The observed-decision floor above
        * cannot see it, because every row in such a period may have made a
        * well-supported decision.
        local _n_nosupp = 0
        local _nosupp_periods ""
        forvalues _r = 1/`=rowsof(`_support_c')' {
            if `_support_c'[`_r', 3] == 0 | `_support_c'[`_r', 4] == 0 {
                local ++_n_nosupp
                local _nosupp_periods "`_nosupp_periods' `=`_support_c'[`_r', 1]'"
            }
        }
        local _nosupp_periods = strtrim("`_nosupp_periods'")
        return scalar n_support_violations = `_n_nosupp'
        return local support_violation_periods "`_nosupp_periods'"
        if `_n_nosupp' > 0 {
            display as error "  WARNING: `_n_nosupp' period(s) have no treated or no untreated decision-risk row: `_nosupp_periods'"
            display as text "    The treatment contrast in these periods rests entirely on the model's period terms."
        }
        return scalar positivity_threshold = `positivity'
        return scalar n_positivity_violations = `_n_pos_viol'
        return scalar min_obs_probability = `_min_obs_overall'
        if `_n_pos_viol' > 0 {
            display as error "  WARNING: `_n_pos_viol' period(s) breach the operational positivity floor (min P(observed treatment) < `positivity')"
            display as text "    Affected periods: `_pos_viol_periods'"
            display as text "    Smallest observed-decision probability among them: " ///
                as result %9.6f `_pos_viol_min'
            display as text "    Estimated probabilities this close to 0 produce extreme weights; consider truncation (an explicit, named choice) or a richer treatment model."
        }

        display as text ""
        display as text "{bf:Primary treatment balance: period x prior-treatment history}"
        display as text "  Rows: " as result rowsof(`_tbal_c') ///
            as text "; covariate numbers follow balance_covariates() order."
        display as text "  target=0 identifies stabilized-numerator covariates retained in the target distribution."

        * Separate censoring-risk-set balance. Treat the current censoring
        * decision as the observed binary decision: prior uncensored decisions
        * retain their cumulative IPCW factors, while the current factor uses
        * P(C_t=c_t|numerator) / P(C_t=c_t|denominator). Applying the usual
        * all-uncensored IPCW factor to C_t=1 rows cannot balance the two
        * observed decision groups and can report severe residual imbalance
        * even under a correctly specified censoring model.
        if "`censor'" != "" {
            capture confirm variable _msm_cw_weight
            if _rc == 0 {
                tempname _cbal _crow
                tempvar _cuncens _cprior _cdiag_w
                quietly gen double `_cuncens' = ///
                    (1 - _msm_cens_num_p) / (1 - _msm_cens_den_p) ///
                    if _msm_decision_risk
                quietly gen double `_cprior' = _msm_cw_weight / `_cuncens' ///
                    if _msm_decision_risk & `_cuncens' > 0 & !missing(`_cuncens')
                quietly gen double `_cdiag_w' = `_cprior' * `_cuncens' ///
                    if _msm_decision_risk & `censor' == 0
                quietly replace `_cdiag_w' = `_cprior' * ///
                    (_msm_cens_num_p / _msm_cens_den_p) ///
                    if _msm_decision_risk & `censor' == 1
                foreach _p of local _diag_periods {
                    quietly gen byte `_tb_use' = _msm_decision_risk & ///
                        `period' == `_p' & !missing(`censor')
                    quietly count if `_tb_use' & `censor' == 1
                    local _nc = r(N)
                    quietly count if `_tb_use' & `censor' == 0
                    local _nuc = r(N)
                    _msm_ess `_cdiag_w' if `_tb_use'
                    local _cess = r(ess)
                    local _ccov_idx = 0
                    foreach _x of local balance_covariates {
                        local ++_ccov_idx
                        _msm_smd `_x', treatment(`censor') touse(`_tb_use')
                        local _craw = `_msm_smd_value'
                        _msm_smd `_x', treatment(`censor') ///
                            weight(`_cdiag_w') touse(`_tb_use')
                        local _cweighted = `_msm_smd_value'
                        matrix `_crow' = (`_p', `_ccov_idx', `_craw', ///
                            `_cweighted', `_nc', `_nuc', `_cess')
                        matrix `_cbal' = nullmat(`_cbal') \ `_crow'
                    }
                    drop `_tb_use'
                }
                matrix colnames `_cbal' = period covariate raw_smd ///
                    weighted_smd n_censored n_uncensored ess
                local _n_cbal = rowsof(`_cbal')
                return matrix censor_balance = `_cbal'
                display as text "{bf:Separate censoring balance: period-specific risk sets}"
                display as text "  Rows: " as result `_n_cbal'
            }
        }

        * The pooled summary is computed on the risk set, like every other
        * summary in this command (audit A11). Post-event and post-censor rows
        * carry the last cumulative weight forward and are never seen by the
        * estimator; letting them into the pooled SMD meant appending
        * analytically irrelevant follow-up could change the reported balance.
        tempvar _pool_use
        quietly gen byte `_pool_use' = _msm_decision_risk
        display as text ""
        display as text "{bf:Secondary pooled person-period balance (risk set)}"
        display as text ""
        display as text %20s "Covariate" "  " ///
            %12s "Unweighted" "  " %12s "Weighted" "  " %8s "Change"
        display as text _dup(58) "-"

        local n_balanced = 0
        local n_imbalanced = 0
        local n_unavailable = 0
        local n_numerator = 0
        local n_covs : word count `balance_covariates'

        tempname bal_matrix
        matrix `bal_matrix' = J(`n_covs', 3, .)

        local cov_idx = 0
        foreach var of local balance_covariates {
            local ++cov_idx

            * Unweighted SMD
            _msm_smd `var', treatment(`treatment') touse(`_pool_use')
            local smd_uw = `_msm_smd_value'

            * Weighted SMD
            _msm_smd `var', treatment(`treatment') weight(_msm_weight) ///
                touse(`_pool_use')
            local smd_w = `_msm_smd_value'

            * Percent change is undefined when the unweighted SMD is ~0: leave it
            * missing rather than reporting 0 even if weighting made it worse
            * (audit A26).
            if abs(`smd_uw') > 0.001 {
                local pct_change = 100 * (abs(`smd_w') - abs(`smd_uw')) / abs(`smd_uw')
            }
            else {
                local pct_change = .
            }

            matrix `bal_matrix'[`cov_idx', 1] = `smd_uw'
            matrix `bal_matrix'[`cov_idx', 2] = `smd_w'
            matrix `bal_matrix'[`cov_idx', 3] = `pct_change'

            * A missing weighted SMD is UNAVAILABLE, not imbalanced (audit A26):
            * `abs(.) > threshold' is true in Stata because `.' is +infinity, so
            * the old code silently counted an unavailable SMD as imbalanced.
            * Stabilized-numerator covariates stay in the target distribution;
            * weighting is not meant to balance them (target=0 above), so they
            * are shown but not counted as balanced or imbalanced.
            local bal_flag ""
            if `: list var in _numer_covars' {
                local bal_flag " (numerator)"
                local ++n_numerator
            }
            else if missing(`smd_w') {
                local bal_flag " (n/a)"
                local ++n_unavailable
            }
            else if abs(`smd_w') > `threshold' {
                local bal_flag " *"
                local ++n_imbalanced
            }
            else {
                local ++n_balanced
            }

            local abbrev_var = abbrev("`var'", 20)
            display as text %20s "`abbrev_var'" "  " ///
                as result %12.4f `smd_uw' "  " %12.4f `smd_w' "  " ///
                %7.1f `pct_change' "%" as text "`bal_flag'"
        }

        display as text _dup(58) "-"
        display as text "Threshold: |SMD| < " as result `threshold'
        if "`: list balance_covariates & _numer_covars'" != "" {
            display as text "(numerator): stabilized-numerator covariate; not a balance target"
        }
        local n_targets = `n_covs' - `n_numerator'
        display as text "Balanced:   " as result `n_balanced' as text "/" as result `n_targets' ///
            as text " balance target(s)"
        if `n_imbalanced' > 0 {
            display as text "Imbalanced: " as result `n_imbalanced' as text " covariates marked with *"
        }
        if `n_unavailable' > 0 {
            display as text "Unavailable: " as result `n_unavailable' as text " covariates (SMD could not be computed), marked (n/a)"
        }
        matrix rownames `bal_matrix' = `balance_covariates'
        matrix colnames `bal_matrix' = raw_smd weighted_smd pct_change

        return scalar n_unavailable = `n_unavailable'
        return scalar n_imbalanced = `n_imbalanced'
        return scalar n_numerator = `n_numerator'
        return scalar threshold = `threshold'
        return matrix balance = `bal_matrix'
    }

    * Covariate k in the treatment_balance and censor_balance matrices (column
    * covariate) and row k of r(balance) is word k of r(covariates).
    return local covariates "`balance_covariates'"

    display as text ""
    display as text "{hline 70}"

    } /* end capture noisily */
    local _rc = _rc

    * Restore the caller's observation order on success and on every error path.
    capture _msm_restore_order `_msm_orig_order'
    local _order_rc = _rc
    if `_rc' == 0 & `_order_rc' != 0 local _rc = `_order_rc'

    * Re-stamp the original keys without changing the restored order in ties.
    if `"`_caller_sorted'"' != "" {
        capture sort `_caller_sorted', stable
        local _sorted_rc = _rc
        if `_rc' == 0 & `_sorted_rc' != 0 local _rc = `_sorted_rc'
    }

    set varabbrev `_varabbrev'
    set more `_more'

    if `_rc' {
        _return restore `_caller_r'
        return add
        exit `_rc'
    }
end
