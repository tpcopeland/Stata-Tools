* _msm_qa_common.do
*
* Shared QA scaffold for the msm package.
*
* Include with:  do "`qa_dir'/_msm_qa_common.do"
*
* WHY THIS EXISTS
*
* Formula tests (ESS, SMD, E-value, known-answer coefficients) need exact,
* hand-chosen weights that no real msm_weight run would ever produce. Before
* Phase 1 they got them by writing the pipeline characteristics directly:
*
*     gen double _msm_weight = 1
*     char _dta[_msm_prepared] "1"
*     char _dta[_msm_weighted] "1"
*     msm_diagnose
*
* That forged an artifact with no identity: no ownership token, no stage uuid,
* no dependency on a preparation, no input signature. It is exactly the state
* the Phase 1 guards exist to refuse, and it is a large part of why the QA
* suite passed 21/21 on code carrying seven stop-ship defects -- the suites
* never exercised the state machine at all, they went around it.
*
* _msm_qa_register_weights supplies the values by hand but mints the identity
* through the package's OWN helpers, so the artifact is indistinguishable from
* a real one and is verified like one. A test may still choose the numbers; it
* may not skip the contract.

version 16.0

**# _msm_qa_register_weights
*
* Register the current _msm_weight values as a genuine package-owned weighting
* on top of a REAL msm_prepare. Call it again after editing _msm_weight: the
* weighting signature covers the weight values, so an edit legitimately
* invalidates the artifact until it is re-registered.
capture program drop _msm_qa_register_weights
program define _msm_qa_register_weights
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        local _prepared : char _dta[_msm_prep_uuid]
        if "`_prepared'" == "" {
            display as error "_msm_qa_register_weights: run msm_prepare first"
            display as error "  (hand-setting char _dta[_msm_prepared] is not a preparation)"
            exit 198
        }

        capture confirm variable _msm_weight
        if _rc {
            display as error "_msm_qa_register_weights: create _msm_weight first"
            exit 111
        }

        capture confirm variable _msm_tw_weight
        if _rc {
            quietly gen double _msm_tw_weight = _msm_weight
        }

        capture confirm variable _msm_ps
        if _rc {
            quietly gen double _msm_ps = 0.5
        }

        capture confirm variable _msm_treat_den_raw
        if _rc quietly gen double _msm_treat_den_raw = _msm_ps
        capture confirm variable _msm_treat_den_p
        if _rc quietly gen double _msm_treat_den_p = _msm_ps
        capture confirm variable _msm_treat_num_raw
        if _rc quietly gen double _msm_treat_num_raw = 0.5
        capture confirm variable _msm_treat_num_p
        if _rc quietly gen double _msm_treat_num_p = _msm_treat_num_raw
        capture confirm variable _msm_decision_risk
        if _rc quietly gen byte _msm_decision_risk = 1

        local _created "_msm_weight _msm_tw_weight _msm_ps"
        local _created "`_created' _msm_treat_den_raw _msm_treat_den_p"
        local _created "`_created' _msm_treat_num_raw _msm_treat_num_p _msm_decision_risk"
        capture confirm variable _msm_cw_weight
        if _rc == 0 {
            local _created "`_created' _msm_cw_weight"
            foreach _v in _msm_cens_den_raw _msm_cens_den_p ///
                _msm_cens_num_raw _msm_cens_num_p {
                capture confirm variable `_v'
                if _rc quietly gen double `_v' = 0.5
                local _created "`_created' `_v'"
            }
        }

        * Registering a weighting invalidates anything built on the previous one.
        _msm_invalidate, from(weight)

        _msm_uuid
        local _wuuid "`r(uuid)'"

        char _dta[_msm_weighted] "1"
        char _dta[_msm_weight_var] "_msm_weight"
        char _dta[_msm_weight_uuid] "`_wuuid'"
        char _dta[_msm_weight_dep] "`_prepared'"
        _msm_own claim `_created', token(`_wuuid')

        local _id : char _dta[_msm_id]
        local _period : char _dta[_msm_period]
        local _treatment : char _dta[_msm_treatment]
        local _outcome : char _dta[_msm_outcome]
        local _censor : char _dta[_msm_censor]

        local _wsig "`_id' `_period' `_treatment' `_outcome' `_censor' `_created'"
        local _wsig : list retokenize _wsig
        local _wsig : list uniq _wsig
        _msm_signature `_wsig'
        char _dta[_msm_weight_sig] "`r(sig)'"
        char _dta[_msm_weight_sigvars] "`_wsig'"

        * Exact metadata contract for this deliberately hand-built weighting.
        char _dta[_msm_wt_spec] "qa-registered"
        char _dta[_msm_treat_d_cov] ""
        char _dta[_msm_treat_n_cov] ""
        char _dta[_msm_censor_d_cov] ""
        char _dta[_msm_censor_n_cov] ""
        char _dta[_msm_numer_covars] ""
        char _dta[_msm_weight_truncate] ""
        char _dta[_msm_weight_fitfailure] "qa"
        char _dta[_msm_probability_policy] "qa"
        char _dta[_msm_probability_clip] ""
        char _dta[_msm_probability_models] ///
            "1=treatment_denominator 2=treatment_numerator"
        char _dta[_msm_ps_var] "_msm_ps"
        char _dta[_msm_tw_var] "_msm_tw_weight"
        char _dta[_msm_ps_covars] ""
        char _dta[_msm_estimand] "ate"
        char _dta[_msm_contract_version] "1.0"
        _msm_contract weight
        char _dta[_msm_weight_contract] `"`r(contract)'"'

        label variable _msm_weight "MSM cumulative IP weight"
        label variable _msm_tw_weight "MSM treatment weight (cumulative)"
        label variable _msm_ps "MSM treatment propensity score"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

**# _msm_qa_register_fit
*
* Register a hand-built coefficient vector as a genuine package-owned fit.
*
* Injecting known coefficients and checking that predictions match a
* hand-computed value is a legitimate and valuable technique -- it is the only
* way to test the prediction arithmetic against an exact answer rather than
* against another estimator. What it may not do is bypass the artifact
* contract. Everything except the numbers is minted here through the package's
* own helpers, so the injected fit is verified exactly like an estimated one.
*
* Requires a registered weighting (_msm_qa_register_weights or a real
* msm_weight): a fit that depends on no weighting is refused as stale, which
* is the A03 behaviour under test elsewhere.
capture program drop _msm_qa_register_fit
program define _msm_qa_register_fit
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        syntax , B(name) V(name) [ESAMPle(varname)]

        local _wuuid : char _dta[_msm_weight_uuid]
        if "`_wuuid'" == "" {
            display as error "_msm_qa_register_fit: register a weighting first"
            exit 198
        }

        _msm_own dropowned _msm_esample
        _msm_invalidate, from(fit)

        _msm_uuid
        local _fuuid "`r(uuid)'"

        if "`esample'" != "" {
            quietly gen byte _msm_esample = (`esample' != 0 & !missing(`esample'))
        }
        else {
            quietly gen byte _msm_esample = 1
        }
        label variable _msm_esample "In estimation sample"

        char _dta[_msm_fitted] "1"
        char _dta[_msm_fit_uuid] "`_fuuid'"
        char _dta[_msm_fit_dep] "`_wuuid'"
        _msm_own claim _msm_esample, token(`_fuuid')

        local _model : char _dta[_msm_model]
        if "`_model'" == "" char _dta[_msm_model] "logistic"
        local _period_spec : char _dta[_msm_period_spec]
        if "`_period_spec'" == "" char _dta[_msm_period_spec] "none"
        local _fit_level : char _dta[_msm_fit_level]
        if "`_fit_level'" == "" char _dta[_msm_fit_level] "95"
        local _history_spec : char _dta[_msm_history_spec]
        local _history_vars : char _dta[_msm_history_vars]
        local _history_assumption : char _dta[_msm_history_assumption]
        if "`_history_assumption'" == "" {
            char _dta[_msm_history_spec] ""
            char _dta[_msm_history_vars] ""
            char _dta[_msm_history_assumption] "no_carryover"
            local _history_vars ""
        }
        local _treatment : char _dta[_msm_treatment]
        local _exposure : char _dta[_msm_exposure]
        local _effect = cond("`_exposure'" != "", "`_exposure'", "`_treatment'")
        char _dta[_msm_fit_effect_term] "`_effect'"

        capture matrix drop _msm_fit_b
        capture matrix drop _msm_fit_V
        matrix _msm_fit_b = `b'
        matrix _msm_fit_V = `v'

        * Give V the coefficient names b carries. A real e(V) always has them;
        * a hand-built J(k,k,0) does not, and would arrive with Stata's default
        * c1..ck. The guards require b and V to name the same coefficients
        * (audit A01: "including b/V dimensions and names"), so supplying them
        * here is the helper's job -- relaxing the guard to accept an unnamed
        * variance matrix would give back the hole the check exists to close.
        local _bnames : colnames _msm_fit_b
        matrix colnames _msm_fit_V = `_bnames'
        matrix rownames _msm_fit_V = `_bnames'

        _msm_mat_save _msm_fit_b, key(_msm_fit_b) token(`_fuuid')
        _msm_mat_save _msm_fit_V, key(_msm_fit_V) token(`_fuuid')

        local _id : char _dta[_msm_id]
        local _period : char _dta[_msm_period]
        local _outcome : char _dta[_msm_outcome]
        local _outcome_cov : char _dta[_msm_outcome_cov]
        local _tvcov : char _dta[_msm_tvcov]
        local _cluster : char _dta[_msm_cluster]
        local _strata : char _dta[_msm_strata]

        local _fsig "`_id' `_period' `_outcome' `_treatment' `_effect'"
        local _fsig "`_fsig' _msm_weight _msm_esample `_outcome_cov' `_tvcov'"
        local _fsig "`_fsig' `_cluster' `_strata' `_history_vars'"
        local _fsig : list retokenize _fsig
        local _fsig : list uniq _fsig
        _msm_signature `_fsig'
        char _dta[_msm_fit_sig] "`r(sig)'"
        char _dta[_msm_fit_sigvars] "`_fsig'"

        _msm_contract fit
        char _dta[_msm_fit_contract] `"`r(contract)'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
