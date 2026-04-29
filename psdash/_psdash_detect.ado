*! _psdash_detect Version 1.0.0  2026/04/29
*! Auto-detect propensity score components from estimation context
*! Author: Timothy P Copeland
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
        [COVariates(varlist numeric) Wvar(varname) SAMPLEvar(varname) ///
         ESTImand(string) PSOUT(name) WOUT(name) GETWvar ///
         REFerence(string) PSVars(varlist numeric)]

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
                * Validate psvars count matches K
                local _n_psvars : word count `psvars'
                if `_n_psvars' != `_K' {
                    display as error "psvars() requires `_K' variables (one per treatment level)"
                    display as error "  treatment levels: `_trt_levels'"
                    display as error "  psvars provided: `_n_psvars'"
                    exit 198
                }
                * Set per-level PS variable locals
                local _ps_idx = 1
                foreach _lv of local _trt_levels {
                    local _ps_v : word `_ps_idx' of `psvars'
                    c_local _psd_ps_`_lv' "`_ps_v'"
                    local _ps_idx = `_ps_idx' + 1
                }
                * First PS variable for backward compat
                gettoken _first_psv _rest_psv : psvars
                c_local _psd_psvar "`_first_psv'"
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

                    if "`estimand'" == "ate" {
                        * ATE: w = 1 / P(A=a|X) for each obs's own group
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
                            replace `wt_storage' = 1 / `_ps_lv' ///
                                if `arg_treatment' == `_lv' & `_ps_lv' > 0 `_sv'
                        }
                    }
                    else if "`estimand'" == "att" {
                        * ATT: w=1 for reference, w=P(A=ref|X)/P(A=a|X) for others
                        * Get reference group PS variable
                        local _ref_ps_idx = 1
                        foreach _lv of local _trt_levels {
                            if "`_lv'" == "`_ref_level'" {
                                local _ps_ref : word `_ref_ps_idx' of `psvars'
                            }
                            local _ref_ps_idx = `_ref_ps_idx' + 1
                        }
                        foreach _lv of local _trt_levels {
                            if "`_lv'" == "`_ref_level'" {
                                replace `wt_storage' = 1 ///
                                    if `arg_treatment' == `_lv' `_sv'
                            }
                            else {
                                local _att_ps_idx = 1
                                foreach _lv2 of local _trt_levels {
                                    if "`_lv2'" == "`_lv'" {
                                        local _ps_lv : word `_att_ps_idx' of `psvars'
                                    }
                                    local _att_ps_idx = `_att_ps_idx' + 1
                                }
                                replace `wt_storage' = `_ps_ref' / `_ps_lv' ///
                                    if `arg_treatment' == `_lv' & `_ps_lv' > 0 `_sv'
                            }
                        }
                    }
                    else if "`estimand'" == "atc" {
                        * ATC is symmetric to ATT but reference is the non-reference group
                        * For simplicity, ATC with multi-group uses same formula as ATE
                        * This is the standard approach; ATT/ATC are less common with K>2
                        foreach _lv of local _trt_levels {
                            local _atc_ps_idx = 1
                            foreach _lv2 of local _trt_levels {
                                if "`_lv2'" == "`_lv'" {
                                    local _ps_lv : word `_atc_ps_idx' of `psvars'
                                }
                                local _atc_ps_idx = `_atc_ps_idx' + 1
                            }
                            replace `wt_storage' = 1 / `_ps_lv' ///
                                if `arg_treatment' == `_lv' & `_ps_lv' > 0 `_sv'
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
    * Strategy 2: Auto-detect from teffects
    * -----------------------------------------------------------------
    if "`e(cmd)'" == "teffects" {
        * Parse treatment and covariates from e(cmdline)
        * teffects cmdline format: teffects <subcmd> (outcome [omodel]) (treatment covars [tmodel]) [, options]
        local cmdline "`e(cmdline)'"

        * Find the treatment model equation (second parenthesized group)
        * First, find the position after the first closing paren
        local rest "`cmdline'"
        local found_first = 0
        local found_second = 0
        local tmodel_contents ""

        * future: prefer e(tvar)/e(treat_varlist) accessors once teffects populates them
        * Count parens to find second group
        local paren_depth = 0
        local group_num = 0
        local in_group = 0
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
                _psdash_strip_fv `"`te_covars'"'
                c_local _psd_covariates "`_psd_stripped_covars'"
            }

            * Guard: only predict PS for teffects subcommands that produce one
            local te_subcmd = e(subcmd)
            if !inlist("`te_subcmd'", "ipw", "ipwra", "aipw", "psmatch") {
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
                if "`samplevar'" != "" {
                    quietly predict double `ps_storage' if `samplevar', ps
                }
                else {
                    quietly predict double `ps_storage', ps
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
                            * Multi-group: generalized weights
                            local _ref_level "`reference'"
                            if "`_ref_level'" == "" {
                                local _ref_level : word 1 of `_trt_levels'
                            }
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
                                foreach _lv of local _trt_levels {
                                    local _ps_lv "_psdash_ps_`_lv'"
                                    replace `wt_storage' = 1 / `_ps_lv' ///
                                        if `te_treatment' == `_lv' & `_ps_lv' > 0 `_sv'
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
                _psdash_strip_fv `"`rhs'"'
                c_local _psd_covariates "`_psd_stripped_covars'"
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
                _psdash_strip_fv `"`rhs'"'
                c_local _psd_covariates "`_psd_stripped_covars'"
            }
        }

        * Discover treatment levels
        local _sv_levelsof ""
        if "`samplevar'" != "" local _sv_levelsof "if `samplevar'"
        local _trt_var "`est_treatment'"
        if "`arg_treatment'" != "" local _trt_var "`arg_treatment'"
        quietly levelsof `_trt_var' `_sv_levelsof', local(_trt_levels)

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
            local _n_psvars : word count `psvars'
            if `_n_psvars' != `_K' {
                display as error "psvars() requires `_K' variables (one per treatment level)"
                display as error "  treatment levels: `_trt_levels'"
                display as error "  psvars provided: `_n_psvars'"
                exit 198
            }
            local _ps_idx = 1
            foreach _lv of local _trt_levels {
                local _ps_v : word `_ps_idx' of `psvars'
                c_local _psd_ps_`_lv' "`_ps_v'"
                local _ps_idx = `_ps_idx' + 1
            }
            gettoken _first_psv _rest_psv : psvars
            c_local _psd_psvar "`_first_psv'"
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

* Helper: strip factor-variable notation from covariate list
* Input:  raw tokens (e.g., "i.rep78 c.weight##c.length age")
* Output: unique underlying variable names via c_local (e.g., "rep78 weight length age")
capture program drop _psdash_strip_fv  // idiomatic drop-then-define for private helper
program define _psdash_strip_fv
    args raw_covars

    local clean ""
    foreach token of local raw_covars {
        * Replace interaction operators with spaces to split
        local expanded : subinstr local token "##" " ", all
        local expanded : subinstr local expanded "#" " ", all

        foreach sub of local expanded {
            * Strip factor/operator prefix (everything up to first dot)
            local dotpos = strpos("`sub'", ".")
            if `dotpos' > 0 {
                local sub = substr("`sub'", `dotpos' + 1, .)
            }
            * Only keep if it is a real variable and not already in list
            capture confirm variable `sub'
            if _rc == 0 {
                local dup : list sub in clean
                if !`dup' {
                    local clean "`clean' `sub'"
                }
            }
        }
    }
    c_local _psd_stripped_covars "`=strtrim("`clean'")'"
end
