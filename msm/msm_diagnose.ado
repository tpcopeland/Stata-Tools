*! msm_diagnose Version 1.2.3  2026/07/02
*! Weight diagnostics and covariate balance for MSM
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())
*! Longitudinal balance: Adenyo et al. (2024), doi:10.1002/sim.10188

/*
Basic syntax:
  msm_diagnose [, options]

Description:
  Displays weight distribution summaries (mean, SD, percentiles, ESS)
  and covariate balance (SMD before/after weighting).

Options:
  balance_covariates(varlist)  - Covariates for balance assessment
  by_period                    - Show weight stats by period
  threshold(#)                 - SMD threshold for balance (default: 0.1)
  accumulate(name)             - Append a one-row summary to a named frame
  contrast(string)             - Contrast label for the accumulate row (required)
  outcome(string)              - Outcome label for the accumulate row

See help msm_diagnose for complete documentation
*/

program define msm_diagnose, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    set varabbrev off
    set more off

    capture noisily {

    syntax [, BALance_covariates(varlist numeric) BY_period THReshold(real 0.1) ///
              ACCUMulate(name) CONTrast(string) OUTcome(string) ///
              POSITivity(real 0.01)]

    * Operational positivity floor (audit A25): the estimated probability of the
    * OBSERVED treatment must stay away from 0, or the inverse-probability weight
    * is unstable (Cole & Hernan 2008). Must be a proper probability floor.
    if `positivity' <= 0 | `positivity' >= 0.5 {
        display as error "positivity() must be strictly between 0 and 0.5; got `positivity'"
        exit 198
    }

    * contrast() identifies the accumulate row and is required with accumulate()
    if "`accumulate'" != "" & `"`contrast'"' == "" {
        display as error "contrast() is required with accumulate()"
        exit 198
    }
    * contrast()/outcome() only label an accumulate row; without accumulate()
    * they are silently ignored, so reject the meaningless combination (A35).
    if "`accumulate'" == "" & (`"`contrast'"' != "" | `"`outcome'"' != "") {
        display as error "contrast()/outcome() require accumulate()"
        exit 198
    }

    * The SMD threshold must be finite and nonnegative (audit A26): a negative
    * threshold makes |SMD| > threshold always true (everything "imbalanced"),
    * and a missing threshold compares as +infinity.
    if `threshold' < 0 | `threshold' >= . {
        display as error "threshold() must be finite and nonnegative; got `threshold'"
        exit 198
    }

    * Preserve the accumulate labels before the internal `outcome' local (set
    * from _msm_outcome below) clobbers the user-supplied outcome() option.
    local _acc_contrast `"`contrast'"'
    local _acc_outcome  `"`outcome'"'

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

    * =========================================================================
    * WEIGHT DISTRIBUTION
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as result "msm_diagnose" as text " - Weight Diagnostics"
    display as text "{hline 70}"
    display as text ""

    * Overall weight distribution
    display as text "{bf:Weight Distribution}"
    display as text ""

    * Pooled weight summaries are computed on the risk set only (audit A11):
    * carry-forward weights on post-event/post-censor rows are not analytical
    * observations, and letting them in lets appended post-risk follow-up
    * change these numbers. _msm_decision_risk is the authoritative marker set
    * by msm_weight. On data with no post-risk rows it is every row (no-op).
    quietly summarize _msm_weight if _msm_decision_risk, detail
    local w_mean = r(mean)
    local w_sd   = r(sd)
    local w_min  = r(min)
    local w_max  = r(max)
    local w_p1   = r(p1)
    local w_p5   = r(p5)
    local w_p25  = r(p25)
    local w_p50  = r(p50)
    local w_p75  = r(p75)
    local w_p95  = r(p95)
    local w_p99  = r(p99)

    display as text "  Mean:     " as result %9.4f `w_mean'
    display as text "  SD:       " as result %9.4f `w_sd'
    display as text "  Min:      " as result %9.4f `w_min'
    display as text "  P1:       " as result %9.4f `w_p1'
    display as text "  P5:       " as result %9.4f `w_p5'
    display as text "  P25:      " as result %9.4f `w_p25'
    display as text "  Median:   " as result %9.4f `w_p50'
    display as text "  P75:      " as result %9.4f `w_p75'
    display as text "  P95:      " as result %9.4f `w_p95'
    display as text "  P99:      " as result %9.4f `w_p99'
    display as text "  Max:      " as result %9.4f `w_max'

    * Effective sample size (risk set only, audit A11)
    quietly {
        summarize _msm_weight if _msm_decision_risk
        local sum_w = r(sum)
        local n_total = r(N)
        tempvar _w2
        gen double `_w2' = _msm_weight^2 if _msm_decision_risk
        summarize `_w2'
        local sum_w2 = r(sum)
        drop `_w2'
    }
    local ess = (`sum_w'^2) / `sum_w2'
    local ess_pct = 100 * `ess' / `n_total'

    display as text ""
    display as text "  ESS:      " as result %9.1f `ess' ///
        as text " (" as result %4.1f `ess_pct' "%" as text " of " as result `n_total' as text ")"

    * By treatment group
    display as text ""
    display as text "  {bf:By treatment group:}"

    forvalues t = 0/1 {
        local t_label = cond(`t' == 0, "Untreated", "Treated")
        quietly summarize _msm_weight if _msm_decision_risk & `treatment' == `t', detail
        local tw_mean = r(mean)
        local tw_sd = r(sd)
        local tw_n = r(N)

        quietly {
            summarize _msm_weight if _msm_decision_risk & `treatment' == `t'
            local tw_sum = r(sum)
            tempvar _tw2
            gen double `_tw2' = _msm_weight^2 if _msm_decision_risk & `treatment' == `t'
            summarize `_tw2'
            local tw_sum2 = r(sum)
            drop `_tw2'
        }
        local tw_ess = (`tw_sum'^2) / `tw_sum2'

        display as text "    `t_label' (n=" as result `tw_n' as text "): mean=" ///
            as result %6.4f `tw_mean' as text ", SD=" as result %6.4f `tw_sd' ///
            as text ", ESS=" as result %6.1f `tw_ess'
    }

    * Extreme weights (risk set only, audit A11)
    quietly count if _msm_decision_risk & _msm_weight > `w_p99' & !missing(_msm_weight)
    local n_extreme = r(N)
    if `n_extreme' > 0 {
        display as text ""
        display as text "  Extreme weights (>" as result %6.4f `w_p99' as text "): " ///
            as result `n_extreme' as text " obs"
    }

    * =========================================================================
    * BY-PERIOD WEIGHT STATS (optional)
    * =========================================================================

    if "`by_period'" != "" {
        display as text ""
        display as text "{bf:Weight Distribution by Period}"
        display as text ""
        display as text %6s "Period" "  " %8s "N" "  " ///
            %10s "Mean" "  " %10s "SD" "  " %10s "Min" "  " %10s "Max"
        display as text _dup(60) "-"

        quietly levelsof `period' if _msm_decision_risk, local(periods)
        foreach p of local periods {
            quietly summarize _msm_weight if _msm_decision_risk & `period' == `p'
            display as text %6.0f `p' "  " ///
                as result %8.0f r(N) "  " ///
                %10.4f r(mean) "  " %10.4f r(sd) "  " ///
                %10.4f r(min) "  " %10.4f r(max)
        }
    }

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
        tempvar _hist _tb_use _diag_w2
        quietly summarize `period', meanonly
        local _min_period = r(min)
        bysort `id' (`period'): gen double `_hist' = `treatment'[_n-1]
        replace `_hist' = -1 if `period' == `_min_period'
        gen double `_diag_w2' = _msm_weight^2

        tempname _tbal _trow _support _srow
        local _numer_covars : char _dta[_msm_numer_covars]
        quietly levelsof `period' if _msm_decision_risk, local(_diag_periods)
        foreach _p of local _diag_periods {
            quietly levelsof `_hist' if _msm_decision_risk & ///
                `period' == `_p' & !missing(`_hist'), local(_histories)
            foreach _h of local _histories {
                local _cov_idx = 0
                foreach _x of local balance_covariates {
                    local ++_cov_idx
                    gen byte `_tb_use' = _msm_decision_risk & ///
                        `period' == `_p' & `_hist' == `_h' & ///
                        !missing(`treatment')
                    _msm_smd `_x', treatment(`treatment') touse(`_tb_use')
                    local _raw_smd = `_msm_smd_value'
                    _msm_smd `_x', treatment(`treatment') ///
                        weight(_msm_weight) touse(`_tb_use')
                    local _weighted_smd = `_msm_smd_value'
                    quietly count if `_tb_use' & `treatment' == 1
                    local _nt = r(N)
                    quietly count if `_tb_use' & `treatment' == 0
                    local _nu = r(N)
                    quietly summarize _msm_weight if `_tb_use', meanonly
                    local _sw = r(sum)
                    quietly summarize `_diag_w2' if `_tb_use', meanonly
                    local _sw2 = r(sum)
                    local _row_ess = cond(`_sw2' > 0, `_sw'^2 / `_sw2', .)
                    local _target = 1
                    if `: list _x in _numer_covars' local _target = 0
                    matrix `_trow' = (`_p', `_h', `_cov_idx', `_raw_smd', ///
                        `_weighted_smd', `_nt', `_nu', `_row_ess', `_target')
                    matrix `_tbal' = nullmat(`_tbal') \ `_trow'
                    drop `_tb_use'
                }
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
            quietly summarize _msm_weight if _msm_decision_risk & ///
                `period' == `_p', meanonly
            local _sw = r(sum)
            quietly summarize `_diag_w2' if _msm_decision_risk & ///
                `period' == `_p', meanonly
            local _sw2 = r(sum)
            local _pess = cond(`_sw2' > 0, `_sw'^2 / `_sw2', .)
            matrix `_srow' = (`_p', `_N', `_Nt', `_Nu', `_psmin', `_psmax', ///
                `_common_lo', `_common_hi', `_nout', `_pess')
            matrix `_support' = nullmat(`_support') \ `_srow'
        }
        matrix colnames `_tbal' = period history covariate raw_smd ///
            weighted_smd n_treated n_untreated ess target
        matrix colnames `_support' = period N treated untreated ps_min ps_max ///
            common_lo common_hi n_outside ess
        capture matrix drop _msm_tbal_matrix
        capture matrix drop _msm_support_matrix
        matrix _msm_tbal_matrix = `_tbal'
        matrix _msm_support_matrix = `_support'
        return matrix treatment_balance = `_tbal'
        return matrix support = `_support'

        * Operational positivity (audit A25): flag periods whose smallest estimated
        * probability of the observed treatment (support ps_min, column 5) falls
        * below the positivity() floor -- the cells that generate the extreme
        * weights a marginal by-period support count cannot see (Cole & Hernan
        * 2008). Returned as a count plus the periods, not just displayed.
        * Read the persisted copy (_msm_support_matrix); `return matrix support'
        * above MOVES the `_support' tempname, so it no longer exists here.
        local _n_pos_viol = 0
        local _pos_viol_periods ""
        forvalues _r = 1/`=rowsof(_msm_support_matrix)' {
            local _p_r  = _msm_support_matrix[`_r', 1]
            local _psmn = _msm_support_matrix[`_r', 5]
            if !missing(`_psmn') & `_psmn' < `positivity' {
                local ++_n_pos_viol
                local _pos_viol_periods "`_pos_viol_periods' `_p_r'"
            }
        }
        local _pos_viol_periods = strtrim("`_pos_viol_periods'")
        return scalar positivity_threshold = `positivity'
        return scalar n_positivity_violations = `_n_pos_viol'
        if `_n_pos_viol' > 0 {
            display as error "  WARNING: `_n_pos_viol' period(s) breach the operational positivity floor (min P(observed treatment) < `positivity')"
            display as text "    Affected periods: `_pos_viol_periods'"
            display as text "    Estimated probabilities this close to 0 produce extreme weights; consider truncation (an explicit, named choice) or a richer treatment model."
        }

        display as text ""
        display as text "{bf:Primary treatment balance: period x prior-treatment history}"
        display as text "  Rows: " as result rowsof(_msm_tbal_matrix) ///
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
                gen double `_cuncens' = ///
                    (1 - _msm_cens_num_p) / (1 - _msm_cens_den_p) ///
                    if _msm_decision_risk
                gen double `_cprior' = _msm_cw_weight / `_cuncens' ///
                    if _msm_decision_risk & `_cuncens' > 0
                gen double `_cdiag_w' = `_cprior' * `_cuncens' ///
                    if _msm_decision_risk & `censor' == 0
                replace `_cdiag_w' = `_cprior' * ///
                    (_msm_cens_num_p / _msm_cens_den_p) ///
                    if _msm_decision_risk & `censor' == 1
                foreach _p of local _diag_periods {
                    local _ccov_idx = 0
                    foreach _x of local balance_covariates {
                        local ++_ccov_idx
                        gen byte `_tb_use' = _msm_decision_risk & ///
                            `period' == `_p' & !missing(`censor')
                        _msm_smd `_x', treatment(`censor') touse(`_tb_use')
                        local _craw = `_msm_smd_value'
                        _msm_smd `_x', treatment(`censor') ///
                            weight(`_cdiag_w') touse(`_tb_use')
                        local _cweighted = `_msm_smd_value'
                        quietly count if `_tb_use' & `censor' == 1
                        local _nc = r(N)
                        quietly count if `_tb_use' & `censor' == 0
                        local _nuc = r(N)
                        tempvar _cw2
                        gen double `_cw2' = `_cdiag_w'^2 if `_tb_use'
                        quietly summarize `_cdiag_w' if `_tb_use', meanonly
                        local _csw = r(sum)
                        quietly summarize `_cw2' if `_tb_use', meanonly
                        local _csw2 = r(sum)
                        local _cess = cond(`_csw2' > 0, `_csw'^2 / `_csw2', .)
                        drop `_cw2'
                        matrix `_crow' = (`_p', `_ccov_idx', `_craw', ///
                            `_cweighted', `_nc', `_nuc', `_cess')
                        matrix `_cbal' = nullmat(`_cbal') \ `_crow'
                        drop `_tb_use'
                    }
                }
                matrix colnames `_cbal' = period covariate raw_smd ///
                    weighted_smd n_censored n_uncensored ess
                capture matrix drop _msm_cbal_matrix
                matrix _msm_cbal_matrix = `_cbal'
                return matrix censor_balance = `_cbal'
                display as text "{bf:Separate censoring balance: period-specific risk sets}"
                display as text "  Rows: " as result rowsof(_msm_cbal_matrix)
            }
        }

        display as text ""
        display as text "{bf:Secondary pooled person-period balance (backward compatibility)}"
        display as text ""
        display as text %20s "Covariate" "  " ///
            %12s "Unweighted" "  " %12s "Weighted" "  " %8s "Change"
        display as text _dup(58) "-"

        local n_balanced = 0
        local n_imbalanced = 0
        local n_unavailable = 0
        local n_covs : word count `balance_covariates'

        tempname bal_matrix
        matrix `bal_matrix' = J(`n_covs', 3, .)

        local cov_idx = 0
        foreach var of local balance_covariates {
            local ++cov_idx

            * Unweighted SMD
            _msm_smd `var', treatment(`treatment')
            local smd_uw = `_msm_smd_value'

            * Weighted SMD
            _msm_smd `var', treatment(`treatment') weight(_msm_weight)
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
            local bal_flag ""
            if missing(`smd_w') {
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
        display as text "Balanced:   " as result `n_balanced' as text "/" as result `n_covs'
        if `n_imbalanced' > 0 {
            display as text "Imbalanced: " as error `n_imbalanced' as text " covariates marked with *"
        }
        if `n_unavailable' > 0 {
            display as text "Unavailable: " as error `n_unavailable' as text " covariates (SMD could not be computed), marked (n/a)"
        }
        return scalar n_unavailable = `n_unavailable'

        * Add names and persist for msm_table
        matrix rownames `bal_matrix' = `balance_covariates'
        matrix colnames `bal_matrix' = raw_smd weighted_smd pct_change
        capture matrix drop _msm_bal_matrix
        matrix _msm_bal_matrix = `bal_matrix'
        char _dta[_msm_bal_saved] "1"
        char _dta[_msm_bal_threshold] "`threshold'"

        return matrix balance = `bal_matrix'
    }

    * Cross-contrast balance summaries for accumulate(); populated only when
    * balance was assessed, otherwise left missing.  n_imbalanced reuses the
    * count already shown above so the summary matches the displayed table.
    local _diag_nimb = .
    local _diag_maxabs = .
    if "`balance_covariates'" != "" {
        local _diag_nimb = `n_imbalanced'
        local _diag_maxabs = 0
        local _R = rowsof(_msm_bal_matrix)
        forvalues _i = 1/`_R' {
            local _s = abs(_msm_bal_matrix[`_i', 2])
            if `_s' < . {
                if `_s' > `_diag_maxabs' local _diag_maxabs = `_s'
            }
        }
    }

    display as text ""
    display as text "{hline 70}"

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return scalar mean_weight = `w_mean'
    return scalar sd_weight = `w_sd'
    return scalar min_weight = `w_min'
    return scalar max_weight = `w_max'
    return scalar p1_weight = `w_p1'
    return scalar p99_weight = `w_p99'
    return scalar ess = `ess'
    return scalar ess_pct = `ess_pct'
    return scalar n_extreme = `n_extreme'

    * Persist weight diagnostics for msm_table
    char _dta[_msm_diag_mean] "`w_mean'"
    char _dta[_msm_diag_sd] "`w_sd'"
    char _dta[_msm_diag_min] "`w_min'"
    char _dta[_msm_diag_max] "`w_max'"
    char _dta[_msm_diag_p1] "`w_p1'"
    char _dta[_msm_diag_p50] "`w_p50'"
    char _dta[_msm_diag_p99] "`w_p99'"
    char _dta[_msm_diag_ess] "`ess'"
    char _dta[_msm_diag_ess_pct] "`ess_pct'"
    char _dta[_msm_diag_saved] "1"

    * =========================================================================
    * CROSS-CONTRAST ACCUMULATION (optional)
    * =========================================================================
    * Append one summary row per call to a named frame, creating it with the
    * fixed schema on first use.  Values come from the locals computed above
    * (the return-list scalars are not yet in r() inside this program).
    if "`accumulate'" != "" {
        capture frame `accumulate': describe
        if _rc {
            frame create `accumulate' ///
                str80 contrast str40 outcome ///
                double(n_obs ess ess_pct max_weight p99_weight n_extreme ///
                       n_imbalanced max_abs_smd)
        }
        frame post `accumulate' ///
            (`"`_acc_contrast'"') (`"`_acc_outcome'"') ///
            (`n_total') (`ess') (`ess_pct') (`w_max') (`w_p99') ///
            (`n_extreme') (`_diag_nimb') (`_diag_maxabs')
    }

    } /* end capture noisily */
    local _rc = _rc

    set varabbrev `_varabbrev'
    set more `_more'

    if `_rc' exit `_rc'
end
