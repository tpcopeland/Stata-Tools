*! iivw_diagnose Version 2.2.0  2026/07/23
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
            [EXogeneity(string) ESTimand(string) TRue(string) FORCE ///
             Level(cilevel) XLSX(string asis) ///
             SHeet(string asis) Title(string asis) Footnote(string asis) ///
             DECimals(string) REPLACE OPEN ///
             BORDERstyle(string) HEADERShade THEme(string) ///
             HEADERColor(string) ZEBRAColor(string) ZEBra]
        * cilevel (not real 95): it defaults to c(level) and enforces the
        * standard 10-99.99 range, so `set level' reaches the displayed and
        * exported intervals here exactly as it does in the rest of the suite.
        if "`true'" != "" {
            capture confirm number `true'
            if _rc {
                display as error "true() must be numeric"
                error 198
            }
            * confirm number accepts . and .a-.z. A missing true value would
            * propagate straight into every bias as ., and the command would
            * report a bias table of dots with rc 0.
            if missing(`true') {
                display as error "true() may not be missing"
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

        * Export-only options are meaningless without xlsx(): they were parsed,
        * ignored, and rc 0 returned, so a mistyped export request was
        * indistinguishable from a successful one. Reject before any work.
        local _exportonly ""
        if `"`sheet'"'       != "" local _exportonly "`_exportonly' sheet()"
        if "`open'"          != "" local _exportonly "`_exportonly' open"
        if "`replace'"       != "" local _exportonly "`_exportonly' replace"
        if `"`title'"'       != "" local _exportonly "`_exportonly' title()"
        if `"`footnote'"'    != "" local _exportonly "`_exportonly' footnote()"
        if "`decimals'"      != "" local _exportonly "`_exportonly' decimals()"
        if `"`borderstyle'"' != "" local _exportonly "`_exportonly' borderstyle()"
        if "`headershade'"   != "" local _exportonly "`_exportonly' headershade"
        if `"`theme'"'       != "" local _exportonly "`_exportonly' theme()"
        if `"`headercolor'"' != "" local _exportonly "`_exportonly' headercolor()"
        if `"`zebracolor'"'  != "" local _exportonly "`_exportonly' zebracolor()"
        if "`zebra'"         != "" local _exportonly "`_exportonly' zebra"
        if `"`xlsx'"' == "" & `"`_exportonly'"' != "" {
            display as error "option(s)`_exportonly' require xlsx()"
            display as text "  they affect only the exported workbook; with no xlsx() to write,"
            display as text "  they would be silently ignored"
            error 198
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

        * Sample markers for the H3 identity check (SOL-07). e(sample) is
        * readable only while the estimates are restored, and it is a marker
        * variable, not a count -- so it has to be materialized per role inside
        * the loop below and compared afterwards. A hand-posted `ereturn post'
        * with no esample() marks nothing, which is the "cannot verify" state,
        * not the "identical" state.
        tempvar _es_unweighted _es_weighted _es_adjusted

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

            * Metadata for the comparability gate (H3) and the interval
            * distribution (H4). Captured while the estimates are restored --
            * this is the only moment they are readable.
            local depvar_`role'  "`e(depvar)'"
            local cmd_`role'     "`e(cmd)'"
            local cmd2_`role'    "`e(cmd2)'"
            local family_`role'  "`e(family)'"
            local link_`role'    "`e(link)'"
            local clust_`role'   "`e(clustvar)'"
            local N_`role'       = e(N)
            local dfr_`role'     = e(df_r)

            capture quietly generate byte `_es_`role'' = e(sample)
            local _esrc_`role' = _rc
            local _esn_`role' = 0
            if `_esrc_`role'' == 0 {
                quietly count if `_es_`role''
                local _esn_`role' = r(N)
            }
        }

        * =================================================================
        * H3: the three estimates must be the same estimand.
        * =================================================================
        * The command decomposes b_unweighted - b_weighted into a "sampling"
        * gap and b_weighted - b_adjusted into an "artifact" gap. Subtracting
        * coefficients is only meaningful when they are coefficients OF THE SAME
        * THING, on the same scale, from the same outcome. Nothing checked that.
        * An isolated probe stored regressions of price, weight and length --
        * three different outcomes -- passed them in as the three roles, and got
        * rc 0 and a precise-looking decomposition across outcomes that have
        * nothing to do with each other.
        *
        * A difference of coefficients from different models is a number, not an
        * estimate. force() exists for a deliberately descriptive comparison and
        * says so in the output; it does not make the decomposition valid.
        * =================================================================
        local _incomparable ""
        foreach role in weighted adjusted {
            if "`depvar_`role''" != "`depvar_unweighted'" {
                local _incomparable "`_incomparable' outcome(`role': `depvar_`role'' vs unweighted: `depvar_unweighted')"
            }
            if "`cmd_`role''" != "`cmd_unweighted'" {
                local _incomparable "`_incomparable' estimator(`role': `cmd_`role'' vs unweighted: `cmd_unweighted')"
            }
            if "`family_`role''" != "`family_unweighted'" | ///
                "`link_`role''" != "`link_unweighted'" {
                local _incomparable "`_incomparable' family/link(`role')"
            }
            if "`clust_`role''" != "`clust_unweighted'" {
                local _incomparable "`_incomparable' cluster(`role': `clust_`role'' vs unweighted: `clust_unweighted')"
            }
        }

        * -----------------------------------------------------------------
        * H3b: the same PEOPLE, not merely the same count (SOL-07).
        * -----------------------------------------------------------------
        * The gate above never looked at the sample at all, and an earlier
        * version that did compared e(N). Two disjoint 52-observation
        * regressions have the same N and share no observation; the pre-fix
        * build decomposed them and returned decomposable == 1. Equal counts
        * are not equal samples, so compare the markers.
        *
        * sample_identical is three-valued on purpose: 1 identical, 0 provably
        * different, missing when at least one role carries no usable marker
        * (a hand-posted matrix, or estimates stored against data no longer in
        * memory). Unverifiable is not the same as verified, and it must not
        * be reported as either.
        * The marker must still DESCRIBE the fit it came from.
        *
        * `estimates store' leaves an _est_<name> column in the dataset, and that
        * column is subsetted along with everything else. So if the data changed
        * between the store and this call, every marker shrinks -- consistently,
        * which is the trap. Three models fitted on 40, 64 and 64 observations,
        * followed by an ordinary `keep if', produced three markers of 30 rows
        * each, compared equal, and returned sample_identical = 1 with a printed
        * causal decomposition at rc 0. That is the SOL-07 defect arriving
        * through a different door: the marker check was itself unverified.
        *
        * e(N) is the fit's own record of its sample size and does not move with
        * the data. If the materialized marker disagrees with it, the marker is
        * no longer the estimation sample and nothing here can be trusted --
        * including the comparison between roles. Fail to MISSING (unverifiable)
        * rather than 0 (provably different): we do not know that they differ,
        * we know we cannot tell. A weighted fit whose e(N) is a sum of weights
        * rather than a row count lands here too, and unverifiable is the honest
        * answer for it as well.
        local _sample_avail = 1
        local _sample_stale ""
        foreach role in unweighted weighted adjusted {
            if `_esrc_`role'' != 0 | `_esn_`role'' == 0 local _sample_avail = 0
            else if `N_`role'' < . & `_esn_`role'' != `N_`role'' {
                local _sample_avail = 0
                local _sample_stale ///
                    "`_sample_stale' `role'(marker `_esn_`role'' vs e(N) `N_`role'')"
            }
        }
        local _sample_identical = .
        if `_sample_avail' {
            local _sample_identical = 1
            foreach role in weighted adjusted {
                quietly count if `_es_`role'' != `_es_unweighted'
                if r(N) > 0 {
                    local _sample_identical = 0
                    local _incomparable ///
                        "`_incomparable' sample(`role': `_esn_`role'' obs vs unweighted: `_esn_unweighted' obs, `r(N)' row(s) differ)"
                }
            }
        }

        if `"`_incomparable'"' != "" & "`force'" == "" {
            display as error "the three estimates are not comparable, so their differences are not a decomposition"
            display as error ""
            foreach _m of local _incomparable {
                display as error "  mismatch: `_m'"
            }
            display as error ""
            display as error "  iivw_diagnose splits b(unweighted) - b(weighted) into a sampling gap and"
            display as error "  b(weighted) - b(adjusted) into an artifact gap. Those subtractions mean"
            display as error "  nothing unless all three estimate the same coefficient, of the same"
            display as error "  outcome, on the same scale, at the same cluster level."
            display as error ""
            display as error "  Refit the three models so they differ ONLY in weighting/adjustment, or"
            display as error "  add force to obtain a purely descriptive side-by-side comparison"
            display as error "  (which will be labeled non-decomposable)."
            error 198
        }
        local _forced_incomparable = 0
        if `"`_incomparable'"' != "" & "`force'" != "" {
            local _forced_incomparable = 1
            display as text "note: force specified with incomparable estimates. The gaps below are"
            display as text "  differences between models that do not estimate the same quantity, so"
            display as text "  they are NOT a sampling/artifact decomposition. Descriptive only."
        }

        * -----------------------------------------------------------------
        * H3c: the decomposition needs a collapsible scale (SOL-07).
        * -----------------------------------------------------------------
        * b(weighted) - b(adjusted) is read as the movement caused by ADDING the
        * adjustment. On a nonlinear link that subtraction also contains pure
        * noncollapsibility: conditioning on a prognostic covariate changes the
        * coefficient even when the covariate is independent of treatment and
        * the true "artifact" is exactly zero. A randomized-logit probe with no
        * confounding returned artifact share 1.0 -- the entire gap attributed
        * to an artifact that does not exist.
        *
        * Only an identity-link/Gaussian fit is collapsible in the sense the
        * decomposition assumes, so decomposable == 1 is confined to that case.
        * This is a labelling change, not a refusal: the gaps are still computed
        * and shown, but they are marked descriptive.
        local _nonlinear_roles ""
        foreach role in unweighted weighted adjusted {
            local _fam = lower("`family_`role''")
            local _lnk = lower("`link_`role''")
            local _lin = 0
            if "`_fam'" != "" | "`_lnk'" != "" {
                if "`_fam'" == "gaussian" & "`_lnk'" == "identity" local _lin = 1
            }
            else if inlist("`cmd_`role''", "regress", "areg", "cnsreg", "rreg") {
                local _lin = 1
            }
            else if inlist("`cmd_`role''", "mixed", "xtreg", "ivregress", "newey") {
                local _lin = 1
            }
            if !`_lin' {
                local _nonlinear_roles "`_nonlinear_roles' `role'(`cmd_`role'')"
            }
        }
        local _noncollapsible ""
        if "`_nonlinear_roles'" != "" {
            local _noncollapsible ///
                "identity-link collapsibility not established for:`_nonlinear_roles'"
        }

        * =================================================================
        * H4: use each estimate's own interval distribution.
        * =================================================================
        * The help documents plain -regress- inputs, which report t intervals on
        * e(df_r) residual degrees of freedom. Applying one normal critical value
        * to all three roles silently reports the wrong limits: on sysuse auto
        * (df_r = 72) the mpg lower limit came out -342.9227 where regress itself
        * gives -344.7008. Each role now uses its own df.
        * =================================================================
        local z = invnormal(1 - (100 - `level') / 200)
        foreach role in unweighted weighted adjusted {
            if `dfr_`role'' > 0 & `dfr_`role'' < . {
                local crit_`role' = invttail(`dfr_`role'', (100 - `level') / 200)
                local dist_`role' "t(`dfr_`role'')"
            }
            else {
                local crit_`role' = `z'
                local dist_`role' "z"
            }
        }

        local ll_unweighted = `b_unweighted' - `crit_unweighted' * `se_unweighted'
        local ul_unweighted = `b_unweighted' + `crit_unweighted' * `se_unweighted'
        local ll_weighted   = `b_weighted'   - `crit_weighted'   * `se_weighted'
        local ul_weighted   = `b_weighted'   + `crit_weighted'   * `se_weighted'
        local ll_adjusted   = `b_adjusted'   - `crit_adjusted'   * `se_adjusted'
        local ul_adjusted   = `b_adjusted'   + `crit_adjusted'   * `se_adjusted'

        matrix `_estimates' = ///
            (`b_unweighted', `se_unweighted', `ll_unweighted', `ul_unweighted' \ ///
             `b_weighted',   `se_weighted',   `ll_weighted',   `ul_weighted' \ ///
             `b_adjusted',   `se_adjusted',   `ll_adjusted',   `ul_adjusted')
        matrix rownames `_estimates' = unweighted weighted adjusted
        matrix colnames `_estimates' = b se ll ul

        local sampling_gap = `b_unweighted' - `b_weighted'
        local artifact_gap = `b_weighted' - `b_adjusted'
        local total_gap    = `b_unweighted' - `b_adjusted'
        local range_min = min(`b_weighted', `b_adjusted')
        local range_max = max(`b_weighted', `b_adjusted')

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
            * exogeneity(exogenous) is a USER ASSERTION, not a tested condition.
            * It does not license a causal "point decomposition"; it only says the
            * user is willing to read the descriptive shares as a proportional
            * attribution. The label stays descriptive so no output claims more
            * than the data support.
            local conclusion "shares_descriptive"
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
                as result %9.4f `range_min' as text " to " ///
                as result %9.4f `range_max'
        }
        else if "`exogeneity'" == "unknown" & "`estimand'" == "marginal" {
            display as text ""
            display as text "Shares are descriptive because exogeneity of the measurement adjustment"
            display as text "has not been established."
        }

        else if "`exogeneity'" == "exogenous" & "`estimand'" == "marginal" {
            display as text ""
            display as text "note: exogeneity(exogenous) is your assertion, not a tested condition."
            display as text "The shares are a descriptive proportional attribution under that"
            display as text "assumption; they are not a validated causal decomposition, and this"
            display as text "command does not verify that the adjustment is exogenous."
        }

        * These two are independent of exogeneity()/estimand(), so they sit
        * outside the chain above rather than extending it.
        if `_sample_identical' == . {
            display as text ""
            if "`_sample_stale'" != "" {
                display as error "note: the estimation sample marker is STALE:`_sample_stale'"
                display as text  "  The data in memory changed after these estimates were stored, so"
                display as text  "  each e(sample) marker was subsetted along with it and no longer"
                display as text  "  identifies the rows its model was fitted on. The markers may"
                display as text  "  still agree with each other -- that agreement means nothing."
                display as text  "  Restore the estimation data, or refit, before decomposing."
            }
            else {
                display as text "note: the estimation sample could not be verified for at least one"
                display as text "  estimate (no usable e(sample) marker), so this command cannot"
                display as text "  confirm the three fits describe the same rows."
            }
            display as text "  Reported as non-decomposable."
        }
        if "`_noncollapsible'" != "" {
            display as text ""
            display as text "note: `_noncollapsible'."
            display as text "  On a nonlinear link, adding a prognostic covariate moves the"
            display as text "  coefficient even when that covariate is independent of the exposure,"
            display as text "  so the artifact gap contains noncollapsibility as well as any real"
            display as text "  measurement artifact. Reported as non-decomposable."
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

        * xlsx() is the sole trigger: the guard above already rejected any
        * export-only option that arrived without it.
        local _export_requested = 0
        if `"`xlsx'"' != "" local _export_requested = 1
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
            if `range_min' < . {
                local _value_str : display `_num_fmt' `range_min'
                local _value_str = strtrim("`_value_str'")
            }
            frame post `_diagnose_export' ("") ("Range min") ///
                (`"`_value_str'"') ("") ("")

            local _value_str ""
            if `range_max' < . {
                local _value_str : display `_num_fmt' `range_max'
                local _value_str = strtrim("`_value_str'")
            }
            frame post `_diagnose_export' ("") ("Range max") ///
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

            * Do NOT exit here -- see the note at the return gate below. A
            * confirmed probe (nonexistent export parent, rc 16106) left neither
            * r(estimates) nor r(decomp) even though every estimate had been
            * computed. The rc is carried out and re-raised after the returns.
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
        `sampling_share' \ `artifact_share' \ `range_min' \ `range_max')
    matrix rownames `_decomp' = sampling_gap artifact_gap total_gap ///
        sampling_share artifact_share range_min range_max
    matrix colnames `_decomp' = value

    if "`true'" != "" {
        return matrix bias = `_bias'
    }
    return matrix decomp = `_decomp'
    return matrix estimates = `_estimates'
    * Comparability and interval provenance. decomposable = 0 means the gaps are
    * descriptive only -- because the three estimates are not the same estimand
    * (force), because they were not fitted on the same rows, because the sample
    * could not be verified at all, or because the link is not collapsible.
    local _decomposable = 1 - `_forced_incomparable'
    if `_sample_identical' != 1        local _decomposable = 0
    if "`_noncollapsible'" != ""       local _decomposable = 0
    return scalar decomposable = `_decomposable'
    return scalar sample_identical = `_sample_identical'
    return scalar n_sample_unweighted = `_esn_unweighted'
    return scalar n_sample_weighted   = `_esn_weighted'
    return scalar n_sample_adjusted   = `_esn_adjusted'
    return local noncollapsible "`_noncollapsible'"
    return local ci_dist_unweighted "`dist_unweighted'"
    return local ci_dist_weighted "`dist_weighted'"
    return local ci_dist_adjusted "`dist_adjusted'"
    return local depvar "`depvar_unweighted'"

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

    * Re-raise a failed export now that the analytical payload is posted. The
    * caller sees the export's rc, but r() survives it: the decomposition ran
    * and its results are real whether or not the workbook could be written.
    * rc 602 (sheet exists, no replace) is warned about above, not an error.
    if `_export_rc' != 0 & `_export_rc' != 602 {
        exit `_export_rc'
    }
end
