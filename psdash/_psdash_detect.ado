*! _psdash_detect Version 1.5.0  2026/07/22
*! Auto-detect propensity score components from estimation context
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass
*! Internal helper — not user-facing

/*
DESCRIPTION:
    Resolves treatment variable, PS variable, covariates, and weight variable
    from explicit arguments or the last estimation context (teffects, logit/probit).

    Uses c_local to pass results back to the calling program:
      _psd_treatment   - treatment variable name
      _psd_psvar       - propensity score variable name (first PS col for multi-group)
      _psd_covariates  - covariate list
      _psd_wvar        - weight variable name (may be empty)
      _psd_source      - detection source ("manual", "teffects", "estimation")
      _psd_multigroup  - "1" if K > 2 or K=2 with non-0/1 values, "0" for binary 0/1
      _psd_K           - number of treatment groups
      _psd_levels      - space-separated list of treatment levels
      _psd_reference   - reference group level (smallest by default)
      _psd_longitudinal - "1" for longitudinal LTMLE contract state
      _psd_id          - longitudinal ID variable (LTMLE only)
      _psd_period      - longitudinal period variable (LTMLE only)
      _psd_regime      - longitudinal regime metadata (LTMLE only)
      _psd_contract_version - upstream contract version when available

USAGE:
    _psdash_detect [treatment] [psvar] , [covariates(varlist) wvar(varname) ///
        samplevar(varname) reference(string) psvars(varlist)]
*/

program define _psdash_detect
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {

    * Parse using anything to avoid varlist greedy parsing issues
    syntax [anything] , ///
        [COVariates(varlist numeric fv) Wvar(varname) SAMPLEvar(varname) ///
         ESTImand(string) PSOUT(name) WOUT(name) GETWvar ///
         REFerence(string) PSVars(varlist numeric) ALLOWLongitudinal]

    * Track whether estimand was explicitly provided; validate if so.
    * We don't default here — teffects auto-detection sets it from e(stat);
    * explicit values are respected regardless of e(stat). Default to ate only
    * after all detection paths have had a chance to set it.
    local _estimand_explicit = ("`estimand'" != "")
    if `_estimand_explicit' {
        local estimand = strlower("`estimand'")
        if !inlist("`estimand'", "ate", "att", "atc") {
            display as error "estimand() must be ate, att, or atc"
            exit 198
        }
    }

    * Validate and extract positional args from anything
    local arg_treatment ""
    local arg_psvar ""
    local nargs = 0

    if "`anything'" != "" {
        tokenize `anything'
        if "`1'" != "" {
            confirm variable `1'
            confirm numeric variable `1'
            local arg_treatment "`1'"
            local nargs = 1
        }
        if "`2'" != "" {
            confirm variable `2'
            confirm numeric variable `2'
            local arg_psvar "`2'"
            local nargs = 2
        }
        if "`3'" != "" {
            display as error "too many variables specified; maximum is 2"
            exit 103
        }
    }

    * -----------------------------------------------------------------
    * Strategy 1: Explicit arguments provided
    * -----------------------------------------------------------------
    if "`arg_treatment'" != "" & ("`arg_psvar'" != "" | "`psvars'" != "") {
        c_local _psd_treatment "`arg_treatment'"
        c_local _psd_source "manual"

        * Covariates: use explicit or leave empty for caller to handle
        if "`covariates'" != "" {
            c_local _psd_covariates "`covariates'"
        }

        * Weights: use explicit if given
        if "`wvar'" != "" {
            c_local _psd_wvar "`wvar'"
            c_local _psd_wvar_auto "0"
        }
        if "`estimand'" == "" local estimand "ate"
        c_local _psd_estimand "`estimand'"

        * --- Multi-group detection for manual mode ---
        * Discover treatment levels
        local _sv_levelsof ""
        if "`samplevar'" != "" local _sv_levelsof "if `samplevar'"
        quietly levelsof `arg_treatment' `_sv_levelsof', local(_trt_levels)
        local _K : word count `_trt_levels'

        if `_K' < 2 {
            if `_K' == 0 {
                c_local _psd_treatment "`arg_treatment'"
                c_local _psd_multigroup "0"
                c_local _psd_K "0"
                c_local _psd_levels ""
                c_local _psd_reference ""
                if "`arg_psvar'" != "" c_local _psd_psvar "`arg_psvar'"
                c_local _psd_psvar_auto "0"
                c_local _psd_source "manual"
                if "`estimand'" == "" local estimand "ate"
                c_local _psd_estimand "`estimand'"
                exit
            }
            display as error "treatment must have at least 2 levels"
            exit 198
        }

        * Determine if this is a classic binary 0/1 case
        local _is_binary01 = 0
        if `_K' == 2 {
            local _lev1 : word 1 of `_trt_levels'
            local _lev2 : word 2 of `_trt_levels'
            if ("`_lev1'" == "0" & "`_lev2'" == "1") {
                local _is_binary01 = 1
            }
        }

        if !`_is_binary01' {
            _psdash_validate_levels, levels(`_trt_levels')
        }

        * Set multi-group c_locals
        c_local _psd_K "`_K'"
        c_local _psd_levels "`_trt_levels'"

        if `_is_binary01' {
            c_local _psd_multigroup "0"
            c_local _psd_reference "0"
            * Classic binary: use single psvar
            if "`arg_psvar'" != "" {
                c_local _psd_psvar "`arg_psvar'"
            }
            else if "`psvars'" != "" {
                * User provided psvars() even for binary; use first
                gettoken _first_psv _rest_psv : psvars
                c_local _psd_psvar "`_first_psv'"
            }
            c_local _psd_psvar_auto "0"
        }
        else {
            * Multi-group path (K>2, or K=2 with non-0/1 values)
            c_local _psd_multigroup "1"

            * RB-06: atc targets a single control population and is not uniquely
            * defined once there are three or more arms. Reject it here rather than
            * silently substitute generalized ATE weights while returning
            * r(estimand)=atc. (K=2 with arbitrary levels keeps a well-defined atc,
            * handled by the binary weight formulas below.)
            if "`estimand'" == "atc" & `_K' > 2 {
                display as error "estimand(atc) is not uniquely defined for a multi-valued treatment (K=`_K')"
                display as error "  atc targets a single control population; with K>2 arms there is no"
                display as error "  unique control arm. Fit a binary contrast, or use estimand(att)"
                display as error "  with reference() to target a named arm."
                exit 198
            }

            * Reference group: explicit or smallest level
            if "`reference'" != "" {
                * Validate reference exists in levels
                local _ref_found = 0
                foreach _lv of local _trt_levels {
                    if "`reference'" == "`_lv'" local _ref_found = 1
                }
                if !`_ref_found' {
                    display as error "reference(`reference') is not a treatment level"
                    display as error "  treatment levels: `_trt_levels'"
                    exit 198
                }
                c_local _psd_reference "`reference'"
            }
            else {
                * Default: smallest level (first from levelsof, which sorts ascending)
                local _ref_default : word 1 of `_trt_levels'
                c_local _psd_reference "`_ref_default'"
            }

            * For multi-group, require psvars() with K variables
            if "`psvars'" == "" {
                * Allow single psvar with K=2 non-0/1
                if `_K' == 2 & "`arg_psvar'" != "" {
                    * For K=2 non-0/1, single PS is P(treatment=level2|X)
                    local _sv_cond "1"
                    if "`samplevar'" != "" local _sv_cond "`samplevar'"
                    quietly count if `_sv_cond' & !missing(`arg_psvar') ///
                        & (`arg_psvar' < 0 | `arg_psvar' > 1)
                    if r(N) > 0 {
                        display as error "propensity scores must be in [0,1]"
                        exit 198
                    }
                    c_local _psd_psvar "`arg_psvar'"
                    c_local _psd_psvar_auto "0"
                }
                else if `_K' > 2 {
                    display as error "multi-group treatment requires psvars() with `_K' PS variables"
                    display as error "  one per treatment level: `_trt_levels'"
                    exit 198
                }
            }
            else {
                local _sample_opt ""
                if "`samplevar'" != "" local _sample_opt "samplevar(`samplevar')"
                _psdash_validate_psvars `psvars', levels(`_trt_levels') ///
                    k(`_K') `_sample_opt'
                foreach _lv of local _trt_levels {
                    c_local _psd_ps_`_lv' "`r(ps_`_lv')'"
                }
                c_local _psd_psvar "`r(first_psvar)'"
                c_local _psd_psvar_auto "0"
            }

            * Auto-generate weights for multi-group if getwvar requested
            if "`getwvar'" != "" & "`wvar'" == "" {
                local _ref_level "`reference'"
                if "`_ref_level'" == "" {
                    local _ref_level : word 1 of `_trt_levels'
                }

                local wt_storage "_psdash_wt"
                local wt_fixed = 1
                if "`wout'" != "" {
                    local wt_storage "`wout'"
                    local wt_fixed = 0
                }
                capture confirm variable `wt_storage'
                if _rc == 0 {
                    if `wt_fixed' {
                        local _wt_auto : char `wt_storage'[_psdash_auto]
                        if "`_wt_auto'" != "1" {
                            display as error "variable `wt_storage' already exists"
                            display as error "  drop or rename it before using psdash"
                            exit 110
                        }
                    }
                    drop `wt_storage'
                }

                quietly {
                    local _sv ""
                    if "`samplevar'" != "" local _sv "& `samplevar'"
                    gen double `wt_storage' = .

                    local _single_k2_ps = (`_K' == 2 & "`psvars'" == "" & "`arg_psvar'" != "")
                    if `_single_k2_ps' {
                        local _lev1 : word 1 of `_trt_levels'
                        local _lev2 : word 2 of `_trt_levels'
                        local _ownps_`_lev1' "(1 - `arg_psvar')"
                        local _ownps_`_lev2' "`arg_psvar'"
                    }
                    else {
                        foreach _lv of local _trt_levels {
                            local _ps_lv "`_psd_ps_`_lv''"
                            if "`_ps_lv'" == "" {
                                * Fallback from c_local — read from psvars positional
                                local _lv_idx = 1
                                foreach _lv2 of local _trt_levels {
                                    if "`_lv2'" == "`_lv'" {
                                        local _ps_lv : word `_lv_idx' of `psvars'
                                    }
                                    local _lv_idx = `_lv_idx' + 1
                                }
                            }
                            local _ownps_`_lv' "`_ps_lv'"
                        }
                    }

                    if `_K' == 2 {
                        * RB-06: binary treatment with ARBITRARY levels. Map the two
                        * levels to a documented reference (control) / other (treated)
                        * arm keyed to own-PS, so ate/att/atc are correct and
                        * recoding-invariant. reference = `_ref_level' (default:
                        * smallest level); the other level is the treated arm. These
                        * reduce to the classic 0/1 formulas used elsewhere in the
                        * package (see the binary panel path and the tmle branch).
                        local _oth_level ""
                        foreach _lv of local _trt_levels {
                            if "`_lv'" != "`_ref_level'" local _oth_level "`_lv'"
                        }
                        local _ps_ref "`_ownps_`_ref_level''"    // own-PS of control
                        local _ps_oth "`_ownps_`_oth_level''"    // own-PS of treated
                        if "`estimand'" == "ate" {
                            replace `wt_storage' = 1 / (`_ps_ref') ///
                                if `arg_treatment' == `_ref_level' & (`_ps_ref') > 0 `_sv'
                            replace `wt_storage' = 1 / (`_ps_oth') ///
                                if `arg_treatment' == `_oth_level' & (`_ps_oth') > 0 `_sv'
                        }
                        else if "`estimand'" == "att" {
                            * ATT: target = the treated (non-reference) arm.
                            replace `wt_storage' = 1 ///
                                if `arg_treatment' == `_oth_level' `_sv'
                            replace `wt_storage' = (`_ps_oth') / (`_ps_ref') ///
                                if `arg_treatment' == `_ref_level' & (`_ps_ref') > 0 `_sv'
                        }
                        else if "`estimand'" == "atc" {
                            * ATC: target = the control (reference) arm.
                            replace `wt_storage' = 1 ///
                                if `arg_treatment' == `_ref_level' `_sv'
                            replace `wt_storage' = (`_ps_ref') / (`_ps_oth') ///
                                if `arg_treatment' == `_oth_level' & (`_ps_oth') > 0 `_sv'
                        }
                    }
                    else {
                        * Multi-group (K>2). atc is rejected at detection (above).
                        if "`estimand'" == "ate" {
                            * ATE: w = 1 / P(A=a|X) for each obs's own group
                            foreach _lv of local _trt_levels {
                                local _ps_expr "`_ownps_`_lv''"
                                replace `wt_storage' = 1 / (`_ps_expr') ///
                                    if `arg_treatment' == `_lv' & (`_ps_expr') > 0 `_sv'
                            }
                        }
                        else if "`estimand'" == "att" {
                            * ATT: w=1 for reference arm, w=P(A=ref|X)/P(A=a|X) for others
                            local _ps_ref "`_ownps_`_ref_level''"
                            foreach _lv of local _trt_levels {
                                if "`_lv'" == "`_ref_level'" {
                                    replace `wt_storage' = 1 ///
                                        if `arg_treatment' == `_lv' `_sv'
                                }
                                else {
                                    local _ps_expr "`_ownps_`_lv''"
                                    replace `wt_storage' = (`_ps_ref') / (`_ps_expr') ///
                                        if `arg_treatment' == `_lv' & (`_ps_expr') > 0 `_sv'
                                }
                            }
                        }
                        else if "`estimand'" == "atc" {
                            * Unreachable: guarded at detection. Defensive only.
                            noisily display as error "estimand(atc) is not defined for K>2 arms"
                            exit 198
                        }
                    }
                }
                if `wt_fixed' {
                    char `wt_storage'[_psdash_auto] 1
                }
                c_local _psd_wvar "`wt_storage'"
                c_local _psd_wvar_auto "1"
            }
        }
        exit
    }

    * -----------------------------------------------------------------
    * Strategy 1b: Auto-detect from iivw dataset contract
    * -----------------------------------------------------------------
    if `nargs' == 0 & "`psvars'" == "" {
        local iivw_weighted : char _dta[_iivw_weighted]
        if "`iivw_weighted'" == "1" {
            * RB-07: verify the iivw weighting contract with iivw's own guard
            * before trusting any of its characteristics (fail closed on stale,
            * unsigned, or unverifiable state).
            _psdash_verify_producer iivw : _iivw_check_weighted
            local iivw_wtype : char _dta[_iivw_weighttype]
            local iivw_wtype = strlower("`iivw_wtype'")

            if !inlist("`iivw_wtype'", "iptw", "fiptiw") {
                display as error "last iivw_weight run has no treatment propensity-score component"
                display as error "  use iivw_balance for visit-intensity diagnostics"
                display as error "  or rerun iivw_weight with treat() and treat_cov() for IPTW/FIPTIW diagnostics"
                exit 198
            }

            local iivw_treat : char _dta[_iivw_treat]
            local iivw_psvar : char _dta[_iivw_ps_var]
            local iivw_twvar : char _dta[_iivw_tw_var]
            local iivw_iwvar : char _dta[_iivw_iw_var]
            local iivw_wvar_final : char _dta[_iivw_weight_var]
            local iivw_covars : char _dta[_iivw_treat_covars]
            local iivw_estimand : char _dta[_iivw_ps_estimand]
            local iivw_contract : char _dta[_iivw_contract_version]

            if "`iivw_treat'" == "" {
                display as error "iivw contract does not identify a treatment variable"
                exit 198
            }
            confirm variable `iivw_treat'
            confirm numeric variable `iivw_treat'

            if "`iivw_psvar'" == "" {
                display as error "iivw contract does not identify a treatment propensity score variable"
                exit 198
            }
            confirm variable `iivw_psvar'
            confirm numeric variable `iivw_psvar'

            if "`iivw_covars'" == "" {
                display as error "iivw contract does not identify treatment-model covariates"
                exit 198
            }
            foreach _iivw_cov of local iivw_covars {
                confirm variable `_iivw_cov'
                confirm numeric variable `_iivw_cov'
            }

            if "`iivw_twvar'" == "" {
                display as error "iivw contract does not identify the treatment weight variable"
                exit 198
            }
            confirm variable `iivw_twvar'
            confirm numeric variable `iivw_twvar'

            if "`iivw_wvar_final'" != "" {
                confirm variable `iivw_wvar_final'
                confirm numeric variable `iivw_wvar_final'
            }
            if "`iivw_iwvar'" != "" {
                confirm variable `iivw_iwvar'
                confirm numeric variable `iivw_iwvar'
            }

            local _sv_levelsof ""
            if "`samplevar'" != "" local _sv_levelsof "if `samplevar'"
            quietly levelsof `iivw_treat' `_sv_levelsof', local(_trt_levels)
            local _K : word count `_trt_levels'
            if `_K' < 2 {
                display as error "treatment must have at least 2 levels"
                exit 198
            }
            if `_K' != 2 {
                display as error "iivw propensity diagnostics require binary 0/1 treatment"
                exit 198
            }
            local _lev1 : word 1 of `_trt_levels'
            local _lev2 : word 2 of `_trt_levels'
            if !("`_lev1'" == "0" & "`_lev2'" == "1") {
                display as error "iivw propensity diagnostics require binary 0/1 treatment"
                exit 198
            }

            local iivw_wvar "`wvar'"
            local iivw_wvar_auto "0"
            if "`iivw_wvar'" == "" local iivw_wvar "`iivw_twvar'"

            if "`iivw_estimand'" == "" local iivw_estimand "ate"
            local iivw_estimand = strlower("`iivw_estimand'")

            c_local _psd_treatment "`iivw_treat'"
            c_local _psd_psvar "`iivw_psvar'"
            c_local _psd_psvar_auto "0"
            c_local _psd_covariates "`iivw_covars'"
            c_local _psd_wvar "`iivw_wvar'"
            c_local _psd_wvar_auto "`iivw_wvar_auto'"
            c_local _psd_source "iivw"
            c_local _psd_estimand "`iivw_estimand'"
            c_local _psd_contract_version "`iivw_contract'"
            c_local _psd_multigroup "0"
            c_local _psd_K "2"
            c_local _psd_levels "0 1"
            c_local _psd_reference "0"
            c_local _psd_iivw_component "treatment"
            c_local _psd_iivw_treatment_wvar "`iivw_twvar'"
            c_local _psd_iivw_final_wvar "`iivw_wvar_final'"
            c_local _psd_iivw_visit_wvar "`iivw_iwvar'"
            exit
        }
    }

    * -----------------------------------------------------------------
    * Strategy 1b-msm: Auto-detect from longitudinal msm contract state
    * -----------------------------------------------------------------
    * Checked before the e(cmd) strategies because msm_weight fits logit
    * internally, leaving a stale e(cmd)=="logit" that would otherwise mis-route.
    if `nargs' == 0 & "`psvars'" == "" {
        local msm_weighted : char _dta[_msm_weighted]
        if "`msm_weighted'" == "1" {
            * RB-07: verify the msm weighting contract with msm's own guard.
            _psdash_verify_producer msm : _msm_check_weighted
            if "`allowlongitudinal'" == "" {
                display as error "last msm_weight run is longitudinal"
                display as error "  pooled psdash subcommands are not run automatically after msm_weight"
                display as error "  use {cmd:psdash combined} for longitudinal diagnostics"
                display as error "  or specify treatment and propensity score variables explicitly"
                exit 198
            }

            local msm_treat   : char _dta[_msm_treatment]
            local msm_psvar   : char _dta[_msm_ps_var]
            local msm_period  : char _dta[_msm_period]
            local msm_id      : char _dta[_msm_id]
            local msm_twvar   : char _dta[_msm_tw_var]
            local msm_wfinal  : char _dta[_msm_weight_var]
            local msm_covars  : char _dta[_msm_ps_covars]
            if "`msm_covars'" == "" local msm_covars : char _dta[_msm_covariates]
            local msm_estimand : char _dta[_msm_estimand]
            local msm_contract : char _dta[_msm_contract_version]

            if "`msm_treat'" == "" {
                display as error "msm contract does not identify a treatment variable"
                exit 198
            }
            confirm variable `msm_treat'
            confirm numeric variable `msm_treat'

            if "`msm_psvar'" == "" {
                display as error "msm contract does not identify a treatment propensity score variable"
                display as error "  rerun {cmd:msm_weight} to generate _msm_ps"
                exit 198
            }
            confirm variable `msm_psvar'
            confirm numeric variable `msm_psvar'

            if "`msm_period'" == "" {
                display as error "msm contract does not identify a period variable"
                exit 198
            }
            confirm variable `msm_period'
            confirm numeric variable `msm_period'
            if "`msm_id'" != "" confirm variable `msm_id'

            * Weight: explicit wvar, else treatment weight, else final IP weight
            local msm_wvar "`wvar'"
            if "`msm_wvar'" == "" local msm_wvar "`msm_twvar'"
            if "`msm_wvar'" == "" local msm_wvar "`msm_wfinal'"
            if "`msm_wvar'" == "" {
                display as error "msm contract does not identify a weight variable"
                exit 198
            }
            confirm variable `msm_wvar'
            confirm numeric variable `msm_wvar'

            if "`msm_estimand'" == "" local msm_estimand "ate"
            local msm_estimand = strlower("`msm_estimand'")

            if "`covariates'" != "" {
                c_local _psd_covariates "`covariates'"
            }
            else if "`msm_covars'" != "" {
                _psdash_strip_fv `"`msm_covars'"'
                c_local _psd_covariates "`_psd_stripped_covars'"
            }

            c_local _psd_treatment "`msm_treat'"
            c_local _psd_psvar "`msm_psvar'"
            c_local _psd_psvar_auto "0"
            c_local _psd_wvar "`msm_wvar'"
            c_local _psd_wvar_auto "0"
            c_local _psd_source "msm"
            c_local _psd_contract_version "`msm_contract'"
            c_local _psd_longitudinal "1"
            c_local _psd_id "`msm_id'"
            c_local _psd_period "`msm_period'"
            c_local _psd_multigroup "0"
            c_local _psd_K "2"
            c_local _psd_levels "0 1"
            c_local _psd_reference "0"
            c_local _psd_estimand "`msm_estimand'"
            exit
        }
    }

    * -----------------------------------------------------------------
    * Strategy 1b-tte: Auto-detect from longitudinal tte contract state
    * -----------------------------------------------------------------
    * Checked before the e(cmd) strategies for the same reason as msm:
    * tte_weight fits logit internally and leaves a stale e(cmd).
    if `nargs' == 0 & "`psvars'" == "" {
        local tte_weighted : char _dta[_tte_weighted]
        if "`tte_weighted'" == "1" {
            * RB-07: verify the tte weighting contract with tte's own guard
            * (re-derives the weight data signature; rejects a modified dataset).
            _psdash_verify_producer tte : _tte_get_weight_state, required
            if "`allowlongitudinal'" == "" {
                display as error "last tte_weight run is longitudinal"
                display as error "  pooled psdash subcommands are not run automatically after tte_weight"
                display as error "  use {cmd:psdash combined} for longitudinal diagnostics"
                display as error "  or specify treatment and propensity score variables explicitly"
                exit 198
            }

            local tte_treat    : char _dta[_tte_treatment]
            local tte_psvar    : char _dta[_tte_pscore_var]
            local tte_period   : char _dta[_tte_period]
            local tte_id       : char _dta[_tte_id]
            local tte_wfinal   : char _dta[_tte_weight_var]
            local tte_covars   : char _dta[_tte_covariates]
            local tte_estimand : char _dta[_tte_estimand]
            local tte_contract : char _dta[_tte_contract_version]

            if "`tte_treat'" == "" {
                display as error "tte contract does not identify a treatment variable"
                exit 198
            }
            confirm variable `tte_treat'
            confirm numeric variable `tte_treat'

            if "`tte_psvar'" == "" {
                display as error "tte contract does not identify a treatment propensity score variable"
                display as error "  rerun {cmd:tte_weight} with {cmd:save_ps} to keep the switch/treatment score,"
                display as error "  or specify treatment and propensity score variables explicitly"
                exit 198
            }
            confirm variable `tte_psvar'
            confirm numeric variable `tte_psvar'

            if "`tte_period'" == "" {
                display as error "tte contract does not identify a period variable"
                exit 198
            }
            confirm variable `tte_period'
            confirm numeric variable `tte_period'
            if "`tte_id'" != "" confirm variable `tte_id'

            local tte_wvar "`wvar'"
            if "`tte_wvar'" == "" local tte_wvar "`tte_wfinal'"
            if "`tte_wvar'" == "" {
                display as error "tte contract does not identify a weight variable"
                exit 198
            }
            confirm variable `tte_wvar'
            confirm numeric variable `tte_wvar'

            if "`tte_estimand'" == "" local tte_estimand "ate"
            local tte_estimand = strlower("`tte_estimand'")

            if "`covariates'" != "" {
                c_local _psd_covariates "`covariates'"
            }
            else if "`tte_covars'" != "" {
                _psdash_strip_fv `"`tte_covars'"'
                c_local _psd_covariates "`_psd_stripped_covars'"
            }

            c_local _psd_treatment "`tte_treat'"
            c_local _psd_psvar "`tte_psvar'"
            c_local _psd_psvar_auto "0"
            c_local _psd_wvar "`tte_wvar'"
            c_local _psd_wvar_auto "0"
            c_local _psd_source "tte"
            c_local _psd_contract_version "`tte_contract'"
            c_local _psd_longitudinal "1"
            c_local _psd_id "`tte_id'"
            c_local _psd_period "`tte_period'"
            c_local _psd_multigroup "0"
            c_local _psd_K "2"
            c_local _psd_levels "0 1"
            c_local _psd_reference "0"
            c_local _psd_estimand "`tte_estimand'"
            exit
        }
    }

    * -----------------------------------------------------------------
    * Strategy 1c: Auto-detect from cross-sectional tmle contract state
    * -----------------------------------------------------------------
    if "`e(cmd)'" == "tmle" {
        * RB-07: verify the tmle estimation contract with tmle's own guard.
        _psdash_verify_producer tmle : _tmle_get_context
        local tmle_treatment "`e(treatment)'"
        if "`tmle_treatment'" == "" {
            local tmle_treatment : char _dta[_tmle_treatment]
        }
        if "`tmle_treatment'" == "" {
            display as error "tmle contract does not identify a treatment variable"
            exit 198
        }
        confirm variable `tmle_treatment'
        confirm numeric variable `tmle_treatment'

        local tmle_psvar "`e(ps_var)'"
        if "`tmle_psvar'" == "" {
            local tmle_psvar : char _dta[_tmle_ps_var]
        }
        if "`tmle_psvar'" == "" {
            capture confirm variable _tmle_ps
            if _rc == 0 local tmle_psvar "_tmle_ps"
        }
        if "`tmle_psvar'" == "" {
            display as error "tmle contract does not identify a propensity score variable"
            display as error "  expected e(ps_var), _dta[_tmle_ps_var], or _tmle_ps"
            exit 198
        }
        confirm variable `tmle_psvar'
        confirm numeric variable `tmle_psvar'

        if "`samplevar'" != "" {
            capture confirm variable _tmle_esample
            if _rc == 0 {
                quietly replace `samplevar' = 0 ///
                    if `samplevar' & (_tmle_esample != 1 | missing(_tmle_esample))
            }
        }

        if "`covariates'" != "" {
            c_local _psd_covariates "`covariates'"
        }
        else {
            local tmle_covariates "`e(covariates)'"
            if "`tmle_covariates'" == "" {
                local tmle_covariates : char _dta[_tmle_covariates]
            }
            if "`tmle_covariates'" == "" {
                local tmle_covariates "`e(tmodel)'"
            }
            if "`tmle_covariates'" == "" {
                local tmle_covariates : char _dta[_tmle_tmodel]
            }
            if "`tmle_covariates'" != "" {
                _psdash_strip_fv `"`tmle_covariates'"'
                c_local _psd_covariates "`_psd_stripped_covars'"
            }
        }

        local tmle_estimand "`estimand'"
        if "`tmle_estimand'" == "" {
            local tmle_estimand "`e(estimand)'"
            if "`tmle_estimand'" == "" {
                local tmle_estimand : char _dta[_tmle_estimand]
            }
        }
        local tmle_estimand = strlower("`tmle_estimand'")
        if "`tmle_estimand'" == "" local tmle_estimand "ate"

        local tmle_method "`e(method)'"
        if "`tmle_method'" == "" {
            local tmle_method : char _dta[_tmle_method]
        }
        local tmle_contract "`e(contract_version)'"
        if "`tmle_contract'" == "" {
            local tmle_contract : char _dta[_tmle_contract_version]
        }

        local _sv_levelsof ""
        if "`samplevar'" != "" local _sv_levelsof "if `samplevar'"
        quietly levelsof `tmle_treatment' `_sv_levelsof', local(_trt_levels)
        local _K : word count `_trt_levels'
        if `_K' < 2 {
            display as error "treatment must have at least 2 levels"
            exit 198
        }
        local _is_binary01 = 0
        if `_K' == 2 {
            local _lev1 : word 1 of `_trt_levels'
            local _lev2 : word 2 of `_trt_levels'
            if ("`_lev1'" == "0" & "`_lev2'" == "1") {
                local _is_binary01 = 1
            }
        }
        if !`_is_binary01' {
            display as error "tmle propensity diagnostics require binary 0/1 treatment"
            exit 198
        }

        c_local _psd_treatment "`tmle_treatment'"
        c_local _psd_psvar "`tmle_psvar'"
        c_local _psd_psvar_auto "0"
        c_local _psd_source "tmle"
        c_local _psd_method "`tmle_method'"
        c_local _psd_contract_version "`tmle_contract'"
        c_local _psd_longitudinal "0"
        c_local _psd_multigroup "0"
        c_local _psd_K "2"
        c_local _psd_levels "0 1"
        c_local _psd_reference "0"
        c_local _psd_estimand "`tmle_estimand'"

        local tmle_wvar "`wvar'"
        local tmle_wvar_auto "0"
        if "`tmle_wvar'" == "" {
            local tmle_wvar "`e(weight_var)'"
            if "`tmle_wvar'" == "" {
                local tmle_wvar : char _dta[_tmle_weight_var]
            }
        }
        if "`tmle_wvar'" != "" {
            confirm variable `tmle_wvar'
            confirm numeric variable `tmle_wvar'
            c_local _psd_wvar "`tmle_wvar'"
            c_local _psd_wvar_auto "0"
        }
        else if "`getwvar'" != "" {
            local wt_storage "_psdash_wt"
            local wt_fixed = 1
            if "`wout'" != "" {
                local wt_storage "`wout'"
                local wt_fixed = 0
            }
            capture confirm variable `wt_storage'
            if _rc == 0 {
                if `wt_fixed' {
                    local _wt_auto : char `wt_storage'[_psdash_auto]
                    if "`_wt_auto'" != "1" {
                        display as error "variable `wt_storage' already exists"
                        display as error "  drop or rename it before using psdash"
                        exit 110
                    }
                }
                drop `wt_storage'
            }

            quietly {
                local _sv ""
                if "`samplevar'" != "" local _sv "& `samplevar'"
                gen double `wt_storage' = .
                if "`tmle_estimand'" == "ate" {
                    replace `wt_storage' = 1 / `tmle_psvar' ///
                        if `tmle_treatment' == 1 & `tmle_psvar' > 0 `_sv'
                    replace `wt_storage' = 1 / (1 - `tmle_psvar') ///
                        if `tmle_treatment' == 0 & `tmle_psvar' < 1 `_sv'
                }
                else if "`tmle_estimand'" == "att" {
                    replace `wt_storage' = 1 ///
                        if `tmle_treatment' == 1 `_sv'
                    replace `wt_storage' = `tmle_psvar' / (1 - `tmle_psvar') ///
                        if `tmle_treatment' == 0 & `tmle_psvar' < 1 `_sv'
                }
                else if "`tmle_estimand'" == "atc" {
                    replace `wt_storage' = (1 - `tmle_psvar') / `tmle_psvar' ///
                        if `tmle_treatment' == 1 & `tmle_psvar' > 0 `_sv'
                    replace `wt_storage' = 1 ///
                        if `tmle_treatment' == 0 `_sv'
                }
            }
            if `wt_fixed' {
                char `wt_storage'[_psdash_auto] 1
            }
            c_local _psd_wvar "`wt_storage'"
            c_local _psd_wvar_auto "1"
        }

        exit
    }

    * -----------------------------------------------------------------
    * Strategy 1d: Auto-detect from longitudinal ltmle contract state
    * -----------------------------------------------------------------
    if "`e(cmd)'" == "ltmle" {
        * RB-07: verify the ltmle estimation contract with ltmle's own guard.
        _psdash_verify_producer ltmle : _ltmle_get_context
        if "`allowlongitudinal'" == "" {
            display as error "last estimation command is longitudinal ltmle"
            display as error "  pooled psdash subcommands are not run automatically after ltmle"
            display as error "  use {cmd:psdash combined} for longitudinal diagnostics"
            display as error "  or specify treatment and propensity score variables explicitly"
            exit 198
        }

        local ltmle_treatment "`e(treatment)'"
        if "`ltmle_treatment'" == "" {
            local ltmle_treatment : char _dta[_ltmle_treatment]
        }
        if "`ltmle_treatment'" == "" {
            display as error "ltmle contract does not identify a treatment variable"
            exit 198
        }
        confirm variable `ltmle_treatment'
        confirm numeric variable `ltmle_treatment'

        local ltmle_period "`e(period)'"
        if "`ltmle_period'" == "" {
            local ltmle_period : char _dta[_ltmle_period]
        }
        if "`ltmle_period'" == "" {
            display as error "ltmle contract does not identify a period variable"
            exit 198
        }
        confirm variable `ltmle_period'
        confirm numeric variable `ltmle_period'

        local ltmle_id "`e(id)'"
        if "`ltmle_id'" == "" {
            local ltmle_id : char _dta[_ltmle_id]
        }
        if "`ltmle_id'" != "" {
            confirm variable `ltmle_id'
        }

        local ltmle_psvar "`e(ps_var)'"
        if "`ltmle_psvar'" == "" {
            local ltmle_psvar : char _dta[_ltmle_ps_var]
        }
        if "`ltmle_psvar'" != "" {
            confirm variable `ltmle_psvar'
            confirm numeric variable `ltmle_psvar'
        }

        local ltmle_wvar "`wvar'"
        if "`ltmle_wvar'" == "" {
            local ltmle_wvar "`e(weight_var)'"
            if "`ltmle_wvar'" == "" {
                local ltmle_wvar : char _dta[_ltmle_weight_var]
            }
        }
        if "`ltmle_wvar'" != "" {
            confirm variable `ltmle_wvar'
            confirm numeric variable `ltmle_wvar'
        }

        if "`samplevar'" != "" {
            capture confirm variable _ltmle_esample
            if _rc == 0 {
                quietly replace `samplevar' = 0 ///
                    if `samplevar' & (_ltmle_esample != 1 | missing(_ltmle_esample))
            }
        }

        if "`covariates'" != "" {
            c_local _psd_covariates "`covariates'"
        }
        else {
            local ltmle_covariates "`e(covariates)'"
            local ltmle_baseline "`e(baseline)'"
            if "`ltmle_covariates'" == "" {
                local ltmle_covariates : char _dta[_ltmle_tmodel]
            }
            local ltmle_covariates "`ltmle_covariates' `ltmle_baseline'"
            local ltmle_covariates : list uniq ltmle_covariates
            if "`ltmle_covariates'" != "" {
                _psdash_strip_fv `"`ltmle_covariates'"'
                c_local _psd_covariates "`_psd_stripped_covars'"
            }
        }

        local ltmle_estimand "`estimand'"
        if "`ltmle_estimand'" == "" {
            local ltmle_estimand "`e(estimand)'"
            if "`ltmle_estimand'" == "" {
                local ltmle_estimand : char _dta[_ltmle_estimand]
            }
        }
        local ltmle_estimand = strlower("`ltmle_estimand'")
        if "`ltmle_estimand'" == "" local ltmle_estimand "ate"

        local ltmle_regime "`e(regime)'"
        if "`ltmle_regime'" == "" {
            local ltmle_regime : char _dta[_ltmle_regime]
        }
        local ltmle_contract "`e(contract_version)'"
        if "`ltmle_contract'" == "" {
            local ltmle_contract : char _dta[_ltmle_contract_version]
        }
        local ltmle_method "`e(method)'"
        if "`ltmle_method'" == "" {
            local ltmle_method : char _dta[_ltmle_method]
        }

        c_local _psd_treatment "`ltmle_treatment'"
        c_local _psd_psvar "`ltmle_psvar'"
        c_local _psd_psvar_auto "0"
        c_local _psd_wvar "`ltmle_wvar'"
        c_local _psd_wvar_auto "0"
        c_local _psd_source "ltmle"
        c_local _psd_method "`ltmle_method'"
        c_local _psd_contract_version "`ltmle_contract'"
        c_local _psd_longitudinal "1"
        c_local _psd_id "`ltmle_id'"
        c_local _psd_period "`ltmle_period'"
        c_local _psd_regime "`ltmle_regime'"
        c_local _psd_multigroup "0"
        c_local _psd_K "2"
        c_local _psd_levels "0 1"
        c_local _psd_reference "0"
        c_local _psd_estimand "`ltmle_estimand'"
        exit
    }

    * -----------------------------------------------------------------
    * Strategy 2: Auto-detect from teffects
    * -----------------------------------------------------------------
    if "`e(cmd)'" == "teffects" {
        * RB-05: restrict every automatic diagnostic to the estimation sample.
        * teffects may fit on a strict subset of the data (if/in restriction or
        * observations dropped for missing covariates); diagnosing the full dataset
        * silently contaminates overlap/balance/weights/support with observations the
        * fitted estimator never used. Intersect the caller's touse with e(sample)
        * here, before treatment-level discovery, PS prediction, or weight generation,
        * so every panel that re-detects lands on one common estimation sample.
        if "`samplevar'" != "" {
            quietly count if `samplevar'
            local _psd_n_before = r(N)
            quietly replace `samplevar' = 0 if `samplevar' & !e(sample)
            quietly count if `samplevar'
            local _psd_n_after = r(N)
            c_local _psd_n_estimation "`_psd_n_after'"
            c_local _psd_n_excluded = `_psd_n_before' - `_psd_n_after'
        }

        * Parse treatment and covariates from e(cmdline)
        * teffects cmdline format: teffects <subcmd> (outcome [omodel]) (treatment covars [tmodel]) [, options]
        local cmdline "`e(cmdline)'"

        * Find the treatment model equation (second parenthesized group)
        * future: prefer e(tvar)/e(treat_varlist) accessors once teffects populates them
        * Count parens to find second group
        local paren_depth = 0
        local group_num = 0
        local tmodel_start = 0
        local tmodel_end = 0

        local len = strlen("`cmdline'")
        forvalues pos = 1/`len' {
            local ch = substr("`cmdline'", `pos', 1)
            if "`ch'" == "(" {
                local paren_depth = `paren_depth' + 1
                if `paren_depth' == 1 {
                    local group_num = `group_num' + 1
                    if `group_num' == 2 {
                        local tmodel_start = `pos' + 1
                    }
                }
            }
            if "`ch'" == ")" {
                if `paren_depth' == 1 & `group_num' == 2 {
                    local tmodel_end = `pos' - 1
                }
                local paren_depth = `paren_depth' - 1
            }
        }

        if `tmodel_start' > 0 & `tmodel_end' > `tmodel_start' {
            local tmodel_len = `tmodel_end' - `tmodel_start' + 1
            local tmodel_contents = substr("`cmdline'", `tmodel_start', `tmodel_len')

            * First token is treatment variable
            gettoken te_treatment te_covars : tmodel_contents
            c_local _psd_treatment "`te_treatment'"

            * Remaining tokens are covariates (strip trailing model spec like ", logit")
            * Remove everything after a comma (model specification)
            local comma_pos = strpos("`te_covars'", ",")
            if `comma_pos' > 0 {
                local te_covars = substr("`te_covars'", 1, `comma_pos' - 1)
            }
            local te_covars = strtrim("`te_covars'")

            if "`covariates'" != "" {
                c_local _psd_covariates "`covariates'"
            }
            else if "`te_covars'" != "" {
                * RB-03: raw factor-variable treatment-model terms; balance expands.
                c_local _psd_covariates "`te_covars'"
            }

            * Guard: only predict PS for teffects subcommands that produce one
            local te_subcmd = e(subcmd)
            * RB-04: teffects psmatch is a matching estimator, not an IPW estimator.
            * It exposes no `predict, ps` (predict,ps -> r(322); with an if qualifier
            * -> r(101)), so the old code accepted psmatch and then died with a cryptic
            * downstream error. Worse, repairing predict alone would generate ordinary
            * IPTW weights and diagnose a DIFFERENT design than the matched sample the
            * user fitted. psdash has no matched-design diagnostics, so fail closed with
            * an explicit unsupported-estimator error rather than diagnose the wrong thing.
            if "`te_subcmd'" == "psmatch" {
                display as error "teffects psmatch is not supported by psdash auto-detection"
                display as error "  psmatch produces a matched design (nearest-neighbour on the"
                display as error "  propensity score), not inverse-probability weights, and teffects"
                display as error "  exposes no propensity-score prediction for it. Matched-design"
                display as error "  diagnostics are not implemented. To diagnose the propensity model,"
                display as error "  fit it explicitly (e.g. teffects ipw, logit, or probit) and pass"
                display as error "  the PS variable directly:"
                display as error "    psdash overlap `te_treatment' ps_var"
                exit 198
            }
            if !inlist("`te_subcmd'", "ipw", "ipwra", "aipw") {
                display as error "teffects `te_subcmd' does not produce a propensity score"
                display as error "  provide psvar explicitly, e.g.: psdash overlap `te_treatment' ps_var"
                exit 198
            }

            * --- Multi-group detection for teffects ---
            local _sv_levelsof ""
            if "`samplevar'" != "" local _sv_levelsof "if `samplevar'"
            quietly levelsof `te_treatment' `_sv_levelsof', local(_trt_levels)
            local _K : word count `_trt_levels'

            if `_K' < 2 {
                if `_K' == 0 {
                    c_local _psd_multigroup "0"
                    c_local _psd_treatment "`te_treatment'"
                    c_local _psd_K "0"
                    c_local _psd_levels ""
                    c_local _psd_reference ""
                    c_local _psd_psvar ""
                    c_local _psd_psvar_auto "0"
                    if "`estimand'" == "" local estimand "ate"
                    c_local _psd_estimand "`estimand'"
                    c_local _psd_source "teffects"
                    exit
                }
                display as error "treatment must have at least 2 levels"
                exit 198
            }

            * Determine if this is a classic binary 0/1 case
            local _is_binary01 = 0
            if `_K' == 2 {
                local _lev1 : word 1 of `_trt_levels'
                local _lev2 : word 2 of `_trt_levels'
                if ("`_lev1'" == "0" & "`_lev2'" == "1") {
                    local _is_binary01 = 1
                }
            }

            if !`_is_binary01' {
                _psdash_validate_levels, levels(`_trt_levels')
            }

            c_local _psd_K "`_K'"
            c_local _psd_levels "`_trt_levels'"

            * Reference group
            if "`reference'" != "" {
                local _ref_found = 0
                foreach _lv of local _trt_levels {
                    if "`reference'" == "`_lv'" local _ref_found = 1
                }
                if !`_ref_found' {
                    display as error "reference(`reference') is not a treatment level"
                    display as error "  treatment levels: `_trt_levels'"
                    exit 198
                }
                c_local _psd_reference "`reference'"
            }
            else {
                local _ref_default : word 1 of `_trt_levels'
                c_local _psd_reference "`_ref_default'"
            }

            if `_is_binary01' {
                c_local _psd_multigroup "0"

                * Generate PS from teffects postestimation (binary path)
                local ps_storage "_psdash_ps"
                local ps_fixed = 1
                if "`psout'" != "" {
                    local ps_storage "`psout'"
                    local ps_fixed = 0
                }
                capture confirm variable `ps_storage'
                if _rc == 0 {
                    if `ps_fixed' {
                        local _psd_auto : char `ps_storage'[_psdash_auto]
                        if "`_psd_auto'" != "1" {
                            display as error "variable `ps_storage' already exists"
                            display as error "  drop or rename it before using psdash"
                            exit 110
                        }
                    }
                    drop `ps_storage'
                }
                * teffects' default predict, ps is for the base treatment
                * level; psdash binary formulas require P(A=1|X).
                if "`samplevar'" != "" {
                    quietly predict double `ps_storage' if `samplevar', ps tlevel(1)
                }
                else {
                    quietly predict double `ps_storage', ps tlevel(1)
                }
                if `ps_fixed' {
                    char `ps_storage'[_psdash_auto] 1
                }
                c_local _psd_psvar "`ps_storage'"
                c_local _psd_psvar_auto "1"
            }
            else {
                c_local _psd_multigroup "1"

                * Multi-valued teffects: generate per-level PS columns
                * Use predict with tlevel() in a loop
                local _ps_first ""
                foreach _lv of local _trt_levels {
                    local _ps_name "_psdash_ps_`_lv'"
                    capture confirm variable `_ps_name'
                    if _rc == 0 {
                        local _ps_auto_chk : char `_ps_name'[_psdash_auto]
                        if "`_ps_auto_chk'" != "1" {
                            display as error "variable `_ps_name' already exists"
                            display as error "  drop or rename it before using psdash"
                            exit 110
                        }
                        drop `_ps_name'
                    }
                    if "`samplevar'" != "" {
                        quietly predict double `_ps_name' if `samplevar', ps tlevel(`_lv')
                    }
                    else {
                        quietly predict double `_ps_name', ps tlevel(`_lv')
                    }
                    char `_ps_name'[_psdash_auto] 1
                    c_local _psd_ps_`_lv' "`_ps_name'"
                    if "`_ps_first'" == "" local _ps_first "`_ps_name'"
                }
                c_local _psd_psvar "`_ps_first'"
                c_local _psd_psvar_auto "1"
            }

            * Auto-detect estimand from teffects only when not explicitly set by caller
            if !`_estimand_explicit' & "`e(stat)'" != "" {
                local te_stat = strlower("`e(stat)'")
                if "`te_stat'" == "atet" local estimand "att"
                else if "`te_stat'" == "atc" local estimand "atc"
            }
            * Default to ate if still unset after auto-detection
            if "`estimand'" == "" local estimand "ate"

            * RB-06: atc is not uniquely defined for a multi-valued treatment (K>2).
            * Reject rather than return generalized ATE weights under an atc label.
            if "`estimand'" == "atc" & `_K' > 2 {
                display as error "estimand(atc) is not uniquely defined for a multi-valued treatment (K=`_K')"
                display as error "  atc targets a single control population; with K>2 arms there is no"
                display as error "  unique control arm. Fit a binary contrast, or use estimand(att)"
                display as error "  with reference() to target a named arm."
                exit 198
            }

            * Try to get weights from teffects ipw
            if "`getwvar'" != "" & inlist("`te_subcmd'", "ipw", "ipwra", "aipw") {
                if "`wvar'" != "" {
                    c_local _psd_wvar "`wvar'"
                    c_local _psd_wvar_auto "0"
                }
                else {
                    * Auto-generate weights from PS (guard PS=0 and PS=1)
                    local wt_storage "_psdash_wt"
                    local wt_fixed = 1
                    if "`wout'" != "" {
                        local wt_storage "`wout'"
                        local wt_fixed = 0
                    }
                    capture confirm variable `wt_storage'
                    if _rc == 0 {
                        if `wt_fixed' {
                            local _wt_auto : char `wt_storage'[_psdash_auto]
                            if "`_wt_auto'" != "1" {
                                display as error "variable `wt_storage' already exists"
                                display as error "  drop or rename it before using psdash"
                                exit 110
                            }
                        }
                        drop `wt_storage'
                    }
                    quietly {
                        local _sv ""
                        if "`samplevar'" != "" local _sv "& `samplevar'"
                        gen double `wt_storage' = .

                        if `_is_binary01' {
                            * Binary 0/1: use legacy formulas
                            if "`estimand'" == "ate" {
                                replace `wt_storage' = 1 / `ps_storage' ///
                                    if `te_treatment' == 1 & `ps_storage' > 0 `_sv'
                                replace `wt_storage' = 1 / (1 - `ps_storage') ///
                                    if `te_treatment' == 0 & `ps_storage' < 1 `_sv'
                            }
                            else if "`estimand'" == "att" {
                                replace `wt_storage' = 1 ///
                                    if `te_treatment' == 1 `_sv'
                                replace `wt_storage' = `ps_storage' / (1 - `ps_storage') ///
                                    if `te_treatment' == 0 & `ps_storage' < 1 `_sv'
                            }
                            else if "`estimand'" == "atc" {
                                replace `wt_storage' = (1 - `ps_storage') / `ps_storage' ///
                                    if `te_treatment' == 1 & `ps_storage' > 0 `_sv'
                                replace `wt_storage' = 1 ///
                                    if `te_treatment' == 0 `_sv'
                            }
                        }
                        else {
                            * Multi-group predicted PS in _psdash_ps_<lev>.
                            local _ref_level "`reference'"
                            if "`_ref_level'" == "" {
                                local _ref_level : word 1 of `_trt_levels'
                            }
                            if `_K' == 2 {
                                * RB-06: binary treatment with ARBITRARY levels. Same
                                * reference(control)/other(treated) mapping as the manual
                                * branch, keyed to own-PS, so ate/att/atc are correct and
                                * recoding-invariant instead of routed through the
                                * generalized (atc==ate) fallback.
                                local _oth_level ""
                                foreach _lv of local _trt_levels {
                                    if "`_lv'" != "`_ref_level'" local _oth_level "`_lv'"
                                }
                                local _ps_ref "_psdash_ps_`_ref_level'"
                                local _ps_oth "_psdash_ps_`_oth_level'"
                                if "`estimand'" == "ate" {
                                    replace `wt_storage' = 1 / `_ps_ref' ///
                                        if `te_treatment' == `_ref_level' & `_ps_ref' > 0 `_sv'
                                    replace `wt_storage' = 1 / `_ps_oth' ///
                                        if `te_treatment' == `_oth_level' & `_ps_oth' > 0 `_sv'
                                }
                                else if "`estimand'" == "att" {
                                    replace `wt_storage' = 1 ///
                                        if `te_treatment' == `_oth_level' `_sv'
                                    replace `wt_storage' = `_ps_oth' / `_ps_ref' ///
                                        if `te_treatment' == `_ref_level' & `_ps_ref' > 0 `_sv'
                                }
                                else if "`estimand'" == "atc" {
                                    replace `wt_storage' = 1 ///
                                        if `te_treatment' == `_ref_level' `_sv'
                                    replace `wt_storage' = `_ps_ref' / `_ps_oth' ///
                                        if `te_treatment' == `_oth_level' & `_ps_oth' > 0 `_sv'
                                }
                            }
                            else {
                                * Multi-group (K>2): generalized weights. atc is rejected
                                * at detection (above), so only ate/att reach here.
                                if "`estimand'" == "ate" {
                                    foreach _lv of local _trt_levels {
                                        local _ps_lv "_psdash_ps_`_lv'"
                                        replace `wt_storage' = 1 / `_ps_lv' ///
                                            if `te_treatment' == `_lv' & `_ps_lv' > 0 `_sv'
                                    }
                                }
                                else if "`estimand'" == "att" {
                                    local _ps_ref "_psdash_ps_`_ref_level'"
                                    foreach _lv of local _trt_levels {
                                        if "`_lv'" == "`_ref_level'" {
                                            replace `wt_storage' = 1 ///
                                                if `te_treatment' == `_lv' `_sv'
                                        }
                                        else {
                                            local _ps_lv "_psdash_ps_`_lv'"
                                            replace `wt_storage' = `_ps_ref' / `_ps_lv' ///
                                                if `te_treatment' == `_lv' & `_ps_lv' > 0 `_sv'
                                        }
                                    }
                                }
                                else if "`estimand'" == "atc" {
                                    * Unreachable: guarded at detection. Defensive only.
                                    noisily display as error "estimand(atc) is not defined for K>2 arms"
                                    exit 198
                                }
                            }
                        }
                    }
                    if `wt_fixed' {
                        char `wt_storage'[_psdash_auto] 1
                    }
                    c_local _psd_wvar "`wt_storage'"
                    c_local _psd_wvar_auto "1"
                }
            }
            else if "`wvar'" != "" {
                c_local _psd_wvar "`wvar'"
                c_local _psd_wvar_auto "0"
            }

            c_local _psd_estimand "`estimand'"
            c_local _psd_source "teffects"
            exit
        }
        else {
            display as error "unable to parse teffects command line"
            exit 198
        }
    }

    * -----------------------------------------------------------------
    * Strategy 3: Auto-detect from logit/probit/mlogit
    * -----------------------------------------------------------------
    if inlist("`e(cmd)'", "logit", "probit", "logistic") {
        local est_treatment "`e(depvar)'"

        * Treatment from estimation
        if "`arg_treatment'" != "" {
            c_local _psd_treatment "`arg_treatment'"
        }
        else {
            c_local _psd_treatment "`est_treatment'"
        }

        * PS variable: must be explicitly provided (user ran predict already)
        if "`arg_psvar'" != "" {
            c_local _psd_psvar "`arg_psvar'"
            c_local _psd_psvar_auto "0"
        }
        else if `nargs' == 1 {
            * Single arg could be psvar if treatment is auto-detected
            if "`arg_treatment'" == "`est_treatment'" {
                display as error "after logit/probit, specify the propensity score variable"
                display as error "  treatment is already auto-detected as `est_treatment'"
                display as error "  e.g., {cmd:psdash overlap ps_varname}"
                exit 198
            }
            c_local _psd_treatment "`est_treatment'"
            c_local _psd_psvar "`arg_treatment'"
            c_local _psd_psvar_auto "0"
        }
        else {
            display as error "after logit/probit, specify the propensity score variable"
            display as error "  e.g., {cmd:psdash overlap `est_treatment' ps_varname}"
            exit 198
        }

        * Covariates from estimation command
        if "`covariates'" != "" {
            c_local _psd_covariates "`covariates'"
        }
        else {
            * Parse RHS from e(cmdline): "logit depvar x1 x2 x3 [, opts]"
            local cmdline "`e(cmdline)'"
            * Remove command name and depvar
            gettoken cmd cmdline : cmdline
            gettoken depvar rhs : cmdline
            * Remove everything after comma (options)
            local comma_pos = strpos("`rhs'", ",")
            if `comma_pos' > 0 {
                local rhs = substr("`rhs'", 1, `comma_pos' - 1)
            }
            * Remove if/in conditions
            local if_pos = strpos("`rhs'", " if ")
            if `if_pos' > 0 {
                local rhs = substr("`rhs'", 1, `if_pos' - 1)
            }
            local in_pos = strpos("`rhs'", " in ")
            if `in_pos' > 0 {
                local rhs = substr("`rhs'", 1, `in_pos' - 1)
            }
            local rhs = strtrim("`rhs'")
            if "`rhs'" != "" {
                * RB-03: pass the raw factor-variable RHS through; psdash_balance
                * expands i./c./## into design columns. Stripping here collapsed
                * factors to integer codes and discarded interactions.
                c_local _psd_covariates "`rhs'"
            }
        }

        * Weights
        if "`wvar'" != "" {
            c_local _psd_wvar "`wvar'"
            c_local _psd_wvar_auto "0"
        }

        * Binary 0/1 from logit/probit — always binary
        c_local _psd_multigroup "0"
        c_local _psd_K "2"
        c_local _psd_levels "0 1"
        c_local _psd_reference "0"

        if "`estimand'" == "" local estimand "ate"
        c_local _psd_estimand "`estimand'"
        c_local _psd_source "estimation"
        exit
    }

    * -----------------------------------------------------------------
    * Strategy 3b: Auto-detect from mlogit (multi-group)
    * -----------------------------------------------------------------
    if "`e(cmd)'" == "mlogit" {
        local est_treatment "`e(depvar)'"
        local _K = e(k_out)

        if "`arg_treatment'" != "" {
            c_local _psd_treatment "`arg_treatment'"
        }
        else {
            c_local _psd_treatment "`est_treatment'"
        }

        * For mlogit, user must provide psvars() with K PS variables
        if "`psvars'" == "" & "`arg_psvar'" == "" {
            display as error "after mlogit, specify psvars() with `_K' PS variables (one per level)"
            display as error "  e.g., {cmd:predict ps1 ps2 ps3, pr}"
            display as error "  {cmd:psdash overlap `est_treatment' , psvars(ps1 ps2 ps3)}"
            exit 198
        }

        * Covariates
        if "`covariates'" != "" {
            c_local _psd_covariates "`covariates'"
        }
        else {
            local cmdline "`e(cmdline)'"
            gettoken cmd cmdline : cmdline
            gettoken depvar rhs : cmdline
            local comma_pos = strpos("`rhs'", ",")
            if `comma_pos' > 0 {
                local rhs = substr("`rhs'", 1, `comma_pos' - 1)
            }
            local if_pos = strpos("`rhs'", " if ")
            if `if_pos' > 0 {
                local rhs = substr("`rhs'", 1, `if_pos' - 1)
            }
            local in_pos = strpos("`rhs'", " in ")
            if `in_pos' > 0 {
                local rhs = substr("`rhs'", 1, `in_pos' - 1)
            }
            local rhs = strtrim("`rhs'")
            if "`rhs'" != "" {
                * RB-03: raw factor-variable RHS; balance expands the design.
                c_local _psd_covariates "`rhs'"
            }
        }

        * Discover treatment levels
        local _sv_levelsof ""
        if "`samplevar'" != "" local _sv_levelsof "if `samplevar'"
        local _trt_var "`est_treatment'"
        if "`arg_treatment'" != "" local _trt_var "`arg_treatment'"
        quietly levelsof `_trt_var' `_sv_levelsof', local(_trt_levels)

        _psdash_validate_levels, levels(`_trt_levels')

        c_local _psd_multigroup "1"
        c_local _psd_K "`_K'"
        c_local _psd_levels "`_trt_levels'"

        * Reference group
        if "`reference'" != "" {
            local _ref_found = 0
            foreach _lv of local _trt_levels {
                if "`reference'" == "`_lv'" local _ref_found = 1
            }
            if !`_ref_found' {
                display as error "reference(`reference') is not a treatment level"
                display as error "  treatment levels: `_trt_levels'"
                exit 198
            }
            c_local _psd_reference "`reference'"
        }
        else {
            local _ref_default : word 1 of `_trt_levels'
            c_local _psd_reference "`_ref_default'"
        }

        * Set PS variables
        if "`psvars'" != "" {
            local _sample_opt ""
            if "`samplevar'" != "" local _sample_opt "samplevar(`samplevar')"
            _psdash_validate_psvars `psvars', levels(`_trt_levels') ///
                k(`_K') `_sample_opt'
            foreach _lv of local _trt_levels {
                c_local _psd_ps_`_lv' "`r(ps_`_lv')'"
            }
            c_local _psd_psvar "`r(first_psvar)'"
            c_local _psd_psvar_auto "0"
        }
        else if "`arg_psvar'" != "" {
            c_local _psd_psvar "`arg_psvar'"
            c_local _psd_psvar_auto "0"
        }

        * Weights
        if "`wvar'" != "" {
            c_local _psd_wvar "`wvar'"
            c_local _psd_wvar_auto "0"
        }

        if "`estimand'" == "" local estimand "ate"
        c_local _psd_estimand "`estimand'"
        c_local _psd_source "estimation"
        exit
    }

    * -----------------------------------------------------------------
    * Strategy 4: Partial explicit (treatment only, no estimation context)
    * -----------------------------------------------------------------
    if "`arg_treatment'" != "" & "`arg_psvar'" == "" {
        display as error "specify both treatment variable and propensity score variable"
        display as error "  e.g., {cmd:psdash overlap `arg_treatment' ps_varname}"
        exit 198
    }

    * -----------------------------------------------------------------
    * Nothing detected
    * -----------------------------------------------------------------
    display as error "unable to detect propensity score source"
    display as error "  specify: {cmd:psdash {it:subcmd} treatment psvar}"
    display as error "  or run after: {cmd:teffects}, {cmd:logit}, or {cmd:probit}"
    exit 198

    } // capture noisily
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
