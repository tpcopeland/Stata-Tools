*! iivw_diagnose Version 1.1.0  2026/05/24
*! Compare stored estimates for IIVW diagnostic decomposition
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define iivw_diagnose, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    tempname _held_est _estimates
    local _held_ests = 0

    capture noisily {

        syntax anything(name=coefficient id="coefficient") , [*]

        local unweighted ""
        local weighted ""
        local adjusted ""
        local exogeneity ""
        local estimand ""
        local true ""
        local level 95
        local leftover ""
        local optlist `"`options'"'
        while `"`optlist'"' != "" {
            gettoken opt optlist : optlist, bind
            local opt_l = lower(`"`opt'"')
            if regexm(`"`opt_l'"', "^([a-z]+)\(.+\)$") {
                local optname = regexs(1)
                local p1 = strpos(`"`opt'"', "(")
                local p2 = strrpos(`"`opt'"', ")")
                local optval = substr(`"`opt'"', `p1' + 1, `p2' - `p1' - 1)

                if strlen("`optname'") >= 3 & ///
                    substr("unweighted", 1, strlen("`optname'")) == "`optname'" {
                    if "`unweighted'" != "" {
                        display as error "unweighted() specified more than once"
                        error 198
                    }
                    local unweighted `"`optval'"'
                    continue
                }
                if strlen("`optname'") >= 2 & ///
                    substr("weighted", 1, strlen("`optname'")) == "`optname'" {
                    if "`weighted'" != "" {
                        display as error "weighted() specified more than once"
                        error 198
                    }
                    local weighted `"`optval'"'
                    continue
                }
                if strlen("`optname'") >= 2 & ///
                    substr("adjusted", 1, strlen("`optname'")) == "`optname'" {
                    if "`adjusted'" != "" {
                        display as error "adjusted() specified more than once"
                        error 198
                    }
                    local adjusted `"`optval'"'
                    continue
                }
                if strlen("`optname'") >= 2 & ///
                    substr("exogeneity", 1, strlen("`optname'")) == "`optname'" {
                    if "`exogeneity'" != "" {
                        display as error "exogeneity() specified more than once"
                        error 198
                    }
                    local exogeneity `"`optval'"'
                    continue
                }
                if strlen("`optname'") >= 3 & ///
                    substr("estimand", 1, strlen("`optname'")) == "`optname'" {
                    if "`estimand'" != "" {
                        display as error "estimand() specified more than once"
                        error 198
                    }
                    local estimand `"`optval'"'
                    continue
                }
                if strlen("`optname'") >= 2 & ///
                    substr("true", 1, strlen("`optname'")) == "`optname'" {
                    if "`true'" != "" {
                        display as error "true() specified more than once"
                        error 198
                    }
                    local true `"`optval'"'
                    continue
                }
                if strlen("`optname'") >= 1 & ///
                    substr("level", 1, strlen("`optname'")) == "`optname'" {
                    if "`level_seen'" != "" {
                        display as error "level() specified more than once"
                        error 198
                    }
                    local level `"`optval'"'
                    local level_seen 1
                    continue
                }
            }
            local leftover `"`leftover' `opt'"'
        }
        if "`unweighted'" == "" {
            display as error "option unweighted() required"
            error 198
        }
        if "`weighted'" == "" {
            display as error "option weighted() required"
            error 198
        }
        if "`adjusted'" == "" {
            display as error "option adjusted() required"
            error 198
        }
        foreach role in unweighted weighted adjusted {
            capture confirm name ``role''
            if _rc {
                display as error "`role'() must name stored estimation results"
                error 198
            }
        }
        if trim(`"`leftover'"') != "" {
            display as error "option(s) not allowed: `leftover'"
            error 198
        }
        capture confirm number `level'
        if _rc {
            display as error "level() must be numeric"
            error 198
        }
        if `level' <= 10 | `level' >= 99.99 {
            display as error "level() must be between 10 and 99.99"
            error 198
        }
        if "`true'" != "" {
            capture confirm number `true'
            if _rc {
                display as error "true() must be numeric"
                error 198
            }
        }

        local coefficient : list clean coefficient
        local n_coef : word count `coefficient'
        if `n_coef' != 1 {
            display as error "specify exactly one coefficient"
            error 198
        }

        local exogeneity = lower("`exogeneity'")
        if "`exogeneity'" == "" local exogeneity "unknown"
        if !inlist("`exogeneity'", "exogenous", "endogenous", "unknown") {
            display as error "exogeneity() must be exogenous, endogenous, or unknown"
            error 198
        }

        local estimand = lower("`estimand'")
        if "`estimand'" == "" local estimand "marginal"
        if !inlist("`estimand'", "marginal", "contrast") {
            display as error "estimand() must be marginal or contrast"
            error 198
        }

        capture _estimates hold `_held_est', nullok
        if _rc {
            local hold_rc = _rc
            display as error "could not preserve active estimation results"
            error `hold_rc'
        }
        local _held_ests = 1

        foreach role in unweighted weighted adjusted {
            local estname "``role''"
            capture quietly estimates restore `estname'
            if _rc {
                display as error "stored estimates '`estname'' not found"
                error 111
            }

            tempname _btmp _setmp
            capture scalar `_btmp' = _b[`coefficient']
            if _rc {
                display as error ///
                    "coefficient `coefficient' not found in stored estimates '`estname''"
                error 111
            }
            local b_`role' = scalar(`_btmp')

            capture scalar `_setmp' = _se[`coefficient']
            if _rc {
                display as error ///
                    "standard error for coefficient `coefficient' not found in stored estimates '`estname''"
                error 111
            }
            local se_`role' = scalar(`_setmp')

            local cmd_`role' "`e(iivw_cmd)'"
            local wtype_`role' "`e(iivw_weighttype)'"
        }

        local z = invnormal(1 - (100 - `level') / 200)
        local ll_unweighted = `b_unweighted' - `z' * `se_unweighted'
        local ul_unweighted = `b_unweighted' + `z' * `se_unweighted'
        local ll_weighted   = `b_weighted'   - `z' * `se_weighted'
        local ul_weighted   = `b_weighted'   + `z' * `se_weighted'
        local ll_adjusted   = `b_adjusted'   - `z' * `se_adjusted'
        local ul_adjusted   = `b_adjusted'   + `z' * `se_adjusted'

        matrix `_estimates' = ///
            (`b_unweighted', `se_unweighted', `ll_unweighted', `ul_unweighted' \ ///
             `b_weighted',   `se_weighted',   `ll_weighted',   `ul_weighted' \ ///
             `b_adjusted',   `se_adjusted',   `ll_adjusted',   `ul_adjusted')
        matrix rownames `_estimates' = unweighted weighted adjusted
        matrix colnames `_estimates' = b se ll ul

        local sampling_gap = `b_unweighted' - `b_weighted'
        local artifact_gap = `b_weighted' - `b_adjusted'
        local total_gap    = `b_unweighted' - `b_adjusted'
        local bounds_lower = min(`b_weighted', `b_adjusted')
        local bounds_upper = max(`b_weighted', `b_adjusted')

        local shares_available = 0
        local share_note ""
        local sampling_share = .
        local artifact_share = .
        if "`estimand'" == "marginal" {
            if abs(`total_gap') >= 1e-8 {
                local sampling_share = `sampling_gap' / `total_gap'
                local artifact_share = `artifact_gap' / `total_gap'
                local shares_available = 1
                if `sampling_share' < 0 | `sampling_share' > 1 | ///
                    `artifact_share' < 0 | `artifact_share' > 1 {
                    local share_note "sign-inconsistent"
                }
            }
            else {
                local share_note "total-gap-too-small"
            }
        }
        else {
            local share_note "contrast"
        }

        local conclusion "descriptive"
        if "`estimand'" == "contrast" {
            local conclusion "movement_only"
        }
        else if "`exogeneity'" == "endogenous" {
            local conclusion "bounds"
        }
        else if "`share_note'" == "total-gap-too-small" {
            local conclusion "unstable"
        }
        else if "`share_note'" == "sign-inconsistent" {
            local conclusion "sign_inconsistent"
        }
        else if "`exogeneity'" == "exogenous" {
            local conclusion "point_decomposition"
        }

        display as text ""
        if "`estimand'" == "contrast" {
            display as result "IIVW movement summary for contrast: " ///
                as text "`coefficient'"
            display as text ""
            display as text "This is not a sampling/artifact decomposition."
            display as text "Use the marginal/reference time slope for artifact-share decomposition."
        }
        else {
            display as result "IIVW diagnostic decomposition for marginal/reference slope: " ///
                as text "`coefficient'"
        }
        display as text ""
        display as text %28s "Model" _col(34) %10s "Estimate" ///
            _col(47) %9s "SE" _col(59) "`level'% CI"
        display as text "{hline 78}"
        display as text %28s "Unweighted" ///
            as result _col(34) %10.4f `b_unweighted' ///
            _col(47) %9.4f `se_unweighted' ///
            _col(59) %9.4f `ll_unweighted' ///
            as text "," as result %9.4f `ul_unweighted'
        display as text %28s "Weighted" ///
            as result _col(34) %10.4f `b_weighted' ///
            _col(47) %9.4f `se_weighted' ///
            _col(59) %9.4f `ll_weighted' ///
            as text "," as result %9.4f `ul_weighted'
        display as text %28s "Weighted + artifact adj." ///
            as result _col(34) %10.4f `b_adjusted' ///
            _col(47) %9.4f `se_adjusted' ///
            _col(59) %9.4f `ll_adjusted' ///
            as text "," as result %9.4f `ul_adjusted'
        display as text "{hline 78}"

        display as text ""
        display as text "{bf:Diagnostic movement}"
        display as text "Sampling gap:       " as result %10.4f `sampling_gap'
        display as text "Artifact gap:       " as result %10.4f `artifact_gap'
        display as text "Total gap:          " as result %10.4f `total_gap'

        if "`estimand'" == "contrast" {
            display as text ""
            display as text "Treatment contrasts may be structurally insensitive to weighting even"
            display as text "when the marginal/reference slope is sampling-biased."
        }
        else if `shares_available' & "`exogeneity'" != "endogenous" {
            display as text "Sampling share:     " as result %9.1f (100 * `sampling_share') as text "%"
            display as text "Artifact share:     " as result %9.1f (100 * `artifact_share') as text "%"
            if "`share_note'" == "sign-inconsistent" {
                display as text ""
                display as text "note: shares fall outside [0, 1]; decomposition is sign-inconsistent."
            }
        }
        else if "`exogeneity'" == "endogenous" {
            display as text ""
            display as text "Sampling/artifact shares are not displayed because the measurement"
            display as text "adjustment is marked as potentially endogenous."
        }
        else {
            display as text ""
            display as text "note: total gap is too small for a stable share."
        }

        if "`exogeneity'" == "endogenous" & "`estimand'" == "marginal" {
            display as text ""
            display as text "Because the measurement process appears outcome-dependent, the adjusted"
            display as text "model may over-correct. Treat the weighted and adjusted estimates as a"
            display as text "diagnostic range, not a point decomposition."
            display as text "Plausible diagnostic range: " ///
                as result %9.4f `bounds_lower' as text " to " ///
                as result %9.4f `bounds_upper'
        }
        else if "`exogeneity'" == "unknown" & "`estimand'" == "marginal" {
            display as text ""
            display as text "Shares are descriptive because exogeneity of the measurement adjustment"
            display as text "has not been established."
        }
        else if "`exogeneity'" == "exogenous" & "`estimand'" == "marginal" {
            display as text ""
            display as text "Under additive separability and exogenous measurement adjustment, shares"
            display as text "summarize movement from sampling correction versus residual artifact."
        }

        if "`true'" != "" {
            local true_value = `true'
            local bias_unweighted = `b_unweighted' - `true_value'
            local bias_weighted   = `b_weighted'   - `true_value'
            local bias_adjusted   = `b_adjusted'   - `true_value'
            display as text ""
            display as text "{bf:Bias versus true value}"
            display as text "True value:         " as result %10.4f `true_value'
            display as text "Unweighted bias:    " as result %10.4f `bias_unweighted'
            display as text "Weighted bias:      " as result %10.4f `bias_weighted'
            display as text "Adjusted bias:      " as result %10.4f `bias_adjusted'
        }
    }
    local rc = _rc
    if `_held_ests' {
        capture _estimates unhold `_held_est'
        if `rc' == 0 & _rc local rc = _rc
    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'

    return matrix estimates = `_estimates'
    return local conclusion "`conclusion'"
    return local estimand "`estimand'"
    return local exogeneity "`exogeneity'"
    return local adjusted "`adjusted'"
    return local weighted "`weighted'"
    return local unweighted "`unweighted'"
    return local coefficient "`coefficient'"
    return scalar bounds_upper = `bounds_upper'
    return scalar bounds_lower = `bounds_lower'
    return scalar artifact_share = `artifact_share'
    return scalar sampling_share = `sampling_share'
    return scalar total_gap = `total_gap'
    return scalar artifact_gap = `artifact_gap'
    return scalar sampling_gap = `sampling_gap'
    return scalar se_adjusted = `se_adjusted'
    return scalar b_adjusted = `b_adjusted'
    return scalar se_weighted = `se_weighted'
    return scalar b_weighted = `b_weighted'
    return scalar se_unweighted = `se_unweighted'
    return scalar b_unweighted = `b_unweighted'
    if "`true'" != "" {
        return scalar bias_adjusted = `bias_adjusted'
        return scalar bias_weighted = `bias_weighted'
        return scalar bias_unweighted = `bias_unweighted'
        return scalar true = `true_value'
    }
end
