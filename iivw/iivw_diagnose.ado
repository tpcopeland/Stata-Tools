*! iivw_diagnose Version 1.9.4  2026/07/09
*! Compare stored estimates for IIVW diagnostic decomposition
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define iivw_diagnose, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    tempname _held_est _estimates _diagnose_export
    local _held_ests = 0
    local _diagnose_export_created = 0
    local _export_rc = 0
    local _export_xlsx ""
    local _export_sheet ""
    local _export_decimals = .
    local _smcl_lb = char(123)
    local _smcl_rb = char(125)

    capture noisily {

        syntax anything(name=coefficient id="coefficient") , ///
            UNWeighted(name) WEighted(name) ADjusted(name) ///
            [EXogeneity(string) ESTimand(string) TRue(string) ///
             Level(real 95) XLSX(string asis) ///
             SHeet(string asis) Title(string asis) Footnote(string asis) ///
             DECimals(string) REPLACE OPEN ///
             BORDERstyle(string) HEADERShade THEme(string) ///
             HEADERColor(string) ZEBRAColor(string) ZEBra]
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
        local _decimals_final = 4
        if "`decimals'" != "" {
            capture confirm integer number `decimals'
            if _rc {
                display as error "decimals() must be an integer"
                error 198
            }
            if `decimals' < 0 | `decimals' > 6 {
                display as error "decimals() must be between 0 and 6"
                error 198
            }
            local _decimals_final = `decimals'
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
        display as text "`_smcl_lb'hline 78`_smcl_rb'"
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
        display as text "`_smcl_lb'hline 78`_smcl_rb'"

        display as text ""
        display as text "`_smcl_lb'bf:Diagnostic movement`_smcl_rb'"
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
            display as text "`_smcl_lb'bf:Bias versus true value`_smcl_rb'"
            display as text "True value:         " as result %10.4f `true_value'
            display as text "Unweighted bias:    " as result %10.4f `bias_unweighted'
            display as text "Weighted bias:      " as result %10.4f `bias_weighted'
            display as text "Adjusted bias:      " as result %10.4f `bias_adjusted'
        }

        local _export_requested = 0
        if `"`xlsx'"' != "" | ///
            `"`sheet'"' != "" | "`open'" != "" {
            local _export_requested = 1
        }
        if `_export_requested' {
            frame create `_diagnose_export' ///
                strL A ///
                strL B ///
                strL c1 ///
                strL c2 ///
                strL c3
            local _diagnose_export_created = 1

            local _sheet `"`sheet'"'
            if `"`_sheet'"' == "" & ///
                `"`xlsx'"' != "" local _sheet "Diagnostics"

            local _clean_xlsx `"`xlsx'"'
            local _clean_title `"`title'"'
            local _clean_footnote `"`footnote'"'
            local _dq = char(34)
            local _num_fmt "%9.`_decimals_final'f"
            local _clean_sheet `"`_sheet'"'
            foreach _text in xlsx sheet title footnote {
                local _text_n = strlen(`"`_clean_`_text''"')
                if `_text_n' >= 4 & ///
                    substr(`"`_clean_`_text''"', 1, 1) == char(96) & ///
                    substr(`"`_clean_`_text''"', 2, 1) == char(34) & ///
                    substr(`"`_clean_`_text''"', `_text_n' - 1, 1) == char(34) & ///
                    substr(`"`_clean_`_text''"', `_text_n', 1) == char(39) {
                    local _clean_`_text' = ///
                        substr(`"`_clean_`_text''"', 3, `_text_n' - 4)
                }
                else if `_text_n' >= 2 & ///
                    substr(`"`_clean_`_text''"', 1, 1) == char(34) & ///
                    substr(`"`_clean_`_text''"', `_text_n', 1) == char(34) {
                    local _clean_`_text' = ///
                        substr(`"`_clean_`_text''"', 2, `_text_n' - 2)
                }
            }
            if `"`_clean_title'"' == "" {
                local _clean_title "IIVW diagnostic decomposition"
            }
            if `"`_clean_footnote'"' == "" {
                local _clean_footnote ///
                    "Estimate rows report b, SE, and confidence limits; diagnostic and bias rows report a single value below the Diagnostic values divider."
            }

            frame post `_diagnose_export' ///
                (`"`_clean_title'"') ("") ("") ("") ("")
            frame post `_diagnose_export' ///
                ("") ("") ("Model estimates") ("") ("")
            frame post `_diagnose_export' ///
                ("") ("Quantity") ("Estimate") ("SE") ("`level'% CI")

            local _b_str ""
            local _se_str ""
            local _ci_str ""
            if `b_unweighted' < . {
                local _b_str : display `_num_fmt' `b_unweighted'
                local _b_str = strtrim("`_b_str'")
            }
            if `se_unweighted' < . {
                local _se_str : display `_num_fmt' `se_unweighted'
                local _se_str = strtrim("`_se_str'")
            }
            if `ll_unweighted' < . & `ul_unweighted' < . {
                local _ll_str : display `_num_fmt' `ll_unweighted'
                local _ll_str = strtrim("`_ll_str'")
                local _ul_str : display `_num_fmt' `ul_unweighted'
                local _ul_str = strtrim("`_ul_str'")
                local _ci_str "`_ll_str' to `_ul_str'"
            }
            frame post `_diagnose_export' ///
                ("") ("Unweighted") (`"`_b_str'"') (`"`_se_str'"') ///
                (`"`_ci_str'"')

            local _b_str ""
            local _se_str ""
            local _ci_str ""
            if `b_weighted' < . {
                local _b_str : display `_num_fmt' `b_weighted'
                local _b_str = strtrim("`_b_str'")
            }
            if `se_weighted' < . {
                local _se_str : display `_num_fmt' `se_weighted'
                local _se_str = strtrim("`_se_str'")
            }
            if `ll_weighted' < . & `ul_weighted' < . {
                local _ll_str : display `_num_fmt' `ll_weighted'
                local _ll_str = strtrim("`_ll_str'")
                local _ul_str : display `_num_fmt' `ul_weighted'
                local _ul_str = strtrim("`_ul_str'")
                local _ci_str "`_ll_str' to `_ul_str'"
            }
            frame post `_diagnose_export' ///
                ("") ("Weighted") (`"`_b_str'"') (`"`_se_str'"') ///
                (`"`_ci_str'"')

            local _b_str ""
            local _se_str ""
            local _ci_str ""
            if `b_adjusted' < . {
                local _b_str : display `_num_fmt' `b_adjusted'
                local _b_str = strtrim("`_b_str'")
            }
            if `se_adjusted' < . {
                local _se_str : display `_num_fmt' `se_adjusted'
                local _se_str = strtrim("`_se_str'")
            }
            if `ll_adjusted' < . & `ul_adjusted' < . {
                local _ll_str : display `_num_fmt' `ll_adjusted'
                local _ll_str = strtrim("`_ll_str'")
                local _ul_str : display `_num_fmt' `ul_adjusted'
                local _ul_str = strtrim("`_ul_str'")
                local _ci_str "`_ll_str' to `_ul_str'"
            }
            frame post `_diagnose_export' ///
                ("") ("Weighted + artifact adjusted") ///
                (`"`_b_str'"') (`"`_se_str'"') (`"`_ci_str'"')

            * Divider row introducing the single-value diagnostic block.  The
            * label sits in c1 (column C) so the styler can merge and bold it.
            * Its Excel row drives valuespanfrom below: 3 metadata rows
            * (title/super-header/column-header) + 3 model rows + 1 = row 7.
            frame post `_diagnose_export' ///
                ("") ("") ("Diagnostic values") ("") ("")
            local _valuespanfrom = 7

            local _value_str ""
            if `sampling_gap' < . {
                local _value_str : display `_num_fmt' `sampling_gap'
                local _value_str = strtrim("`_value_str'")
            }
            frame post `_diagnose_export' ("") ("Sampling gap") ///
                (`"`_value_str'"') ("") ("")

            local _value_str ""
            if `artifact_gap' < . {
                local _value_str : display `_num_fmt' `artifact_gap'
                local _value_str = strtrim("`_value_str'")
            }
            frame post `_diagnose_export' ("") ("Artifact gap") ///
                (`"`_value_str'"') ("") ("")

            local _value_str ""
            if `total_gap' < . {
                local _value_str : display `_num_fmt' `total_gap'
                local _value_str = strtrim("`_value_str'")
            }
            frame post `_diagnose_export' ("") ("Total gap") ///
                (`"`_value_str'"') ("") ("")

            local _value_str ""
            if `sampling_share' < . {
                local _value_str : display `_num_fmt' `sampling_share'
                local _value_str = strtrim("`_value_str'")
            }
            frame post `_diagnose_export' ("") ("Sampling share") ///
                (`"`_value_str'"') ("") ("")

            local _value_str ""
            if `artifact_share' < . {
                local _value_str : display `_num_fmt' `artifact_share'
                local _value_str = strtrim("`_value_str'")
            }
            frame post `_diagnose_export' ("") ("Artifact share") ///
                (`"`_value_str'"') ("") ("")

            local _value_str ""
            if `bounds_lower' < . {
                local _value_str : display `_num_fmt' `bounds_lower'
                local _value_str = strtrim("`_value_str'")
            }
            frame post `_diagnose_export' ("") ("Lower bound") ///
                (`"`_value_str'"') ("") ("")

            local _value_str ""
            if `bounds_upper' < . {
                local _value_str : display `_num_fmt' `bounds_upper'
                local _value_str = strtrim("`_value_str'")
            }
            frame post `_diagnose_export' ("") ("Upper bound") ///
                (`"`_value_str'"') ("") ("")

            if "`true'" != "" {
                local _value_str : display `_num_fmt' `true_value'
                local _value_str = strtrim("`_value_str'")
                frame post `_diagnose_export' ("") ("True value") ///
                    (`"`_value_str'"') ("") ("")

                local _value_str : display `_num_fmt' `bias_unweighted'
                local _value_str = strtrim("`_value_str'")
                frame post `_diagnose_export' ("") ("Unweighted bias") ///
                    (`"`_value_str'"') ("") ("")

                local _value_str : display `_num_fmt' `bias_weighted'
                local _value_str = strtrim("`_value_str'")
                frame post `_diagnose_export' ("") ("Weighted bias") ///
                    (`"`_value_str'"') ("") ("")

                local _value_str : display `_num_fmt' `bias_adjusted'
                local _value_str = strtrim("`_value_str'")
                frame post `_diagnose_export' ("") ("Adjusted bias") ///
                    (`"`_value_str'"') ("") ("")
            }

            frame post `_diagnose_export' ///
                ("") (`"`_clean_footnote'"') ("") ("") ("")

            local _quote_sentinel = uchar(57344)
            local _dispatch_title = subinstr(`"`_clean_title'"', ///
                char(34), `"`_quote_sentinel'"', .)
            local _dispatch_footnote = subinstr(`"`_clean_footnote'"', ///
                char(34), `"`_quote_sentinel'"', .)

            local _export_opts `"tableframe(`_diagnose_export') decimals(`_decimals_final') layout(tabtools) valuespanfrom(`_valuespanfrom')"'
            if `"`_clean_xlsx'"' != "" local _export_opts `"`_export_opts' xlsx("`_clean_xlsx'")"'
            if `"`_clean_sheet'"' != "" local _export_opts `"`_export_opts' sheet("`_clean_sheet'")"'
            if `"`_dispatch_title'"' != "" local _export_opts `"`_export_opts' title("`_dispatch_title'")"'
            if `"`_dispatch_footnote'"' != "" local _export_opts `"`_export_opts' footnote("`_dispatch_footnote'")"'
            if "`replace'" != "" local _export_opts `"`_export_opts' replace"'
            if "`open'" != "" local _export_opts `"`_export_opts' open"'
            if `"`borderstyle'"' != "" local _export_opts `"`_export_opts' borderstyle(`borderstyle')"'
            if "`headershade'" != "" local _export_opts `"`_export_opts' headershade"'
            if `"`theme'"' != "" local _export_opts `"`_export_opts' theme(`theme')"'
            if `"`headercolor'"' != "" local _export_opts `"`_export_opts' headercolor("`headercolor'")"'
            if `"`zebracolor'"' != "" local _export_opts `"`_export_opts' zebracolor("`zebracolor'")"'
            if "`zebra'" != "" local _export_opts `"`_export_opts' zebra"'

            capture noisily _iivw_export_table, `_export_opts'
            local _export_rc = _rc
            if `_export_rc' == 0 {
                local _export_xlsx `"`r(xlsx)'"'
                local _export_sheet `"`r(sheet)'"'
                local _export_decimals = r(decimals)
            }
            else if `_export_rc' == 602 {
                * Soft failure: worksheet already exists and replace was not
                * given.  The diagnostic succeeded, so warn and return its
                * results.  Genuine option errors (rc 198 etc.) propagate below.
                display as error ///
                    "warning: worksheet already exists; specify replace to overwrite it"
                display as error ///
                    "  iivw_diagnose results are still returned in r()"
            }
            capture frame drop `_diagnose_export'
            local _drop_rc = _rc
            local _diagnose_export_created = 0
            if `_export_rc' != 0 & `_export_rc' != 602 {
                exit `_export_rc'
            }
        }
    }
    local rc = _rc
    if `_diagnose_export_created' {
        capture frame drop `_diagnose_export'
        local _drop_rc = _rc
        if `rc' == 0 & `_drop_rc' != 0 local rc = `_drop_rc'
    }
    if `_held_ests' {
        capture _estimates unhold `_held_est'
        if `rc' == 0 & _rc local rc = _rc
    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'

    tempname _decomp _bias
    if "`true'" != "" {
        matrix `_bias' = (`true_value' \ `bias_unweighted' \ ///
            `bias_weighted' \ `bias_adjusted')
        matrix rownames `_bias' = true bias_unweighted bias_weighted bias_adjusted
        matrix colnames `_bias' = value
    }
    matrix `_decomp' = (`sampling_gap' \ `artifact_gap' \ `total_gap' \ ///
        `sampling_share' \ `artifact_share' \ `bounds_lower' \ `bounds_upper')
    matrix rownames `_decomp' = sampling_gap artifact_gap total_gap ///
        sampling_share artifact_share bounds_lower bounds_upper
    matrix colnames `_decomp' = value

    if "`true'" != "" {
        return matrix bias = `_bias'
    }
    return matrix decomp = `_decomp'
    return matrix estimates = `_estimates'
    return local conclusion "`conclusion'"
    return local estimand "`estimand'"
    return local exogeneity "`exogeneity'"
    return local adjusted "`adjusted'"
    return local weighted "`weighted'"
    return local unweighted "`unweighted'"
    return local coefficient "`coefficient'"
    if `"`_export_xlsx'"' != "" {
        return local xlsx `"`_export_xlsx'"'
        return local sheet `"`_export_sheet'"'
    }
    if `_export_decimals' < . {
        return scalar decimals = `_export_decimals'
    }
end
