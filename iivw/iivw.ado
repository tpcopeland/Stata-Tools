*! iivw Version 1.9.1  2026/07/01
*! Inverse intensity of visit weighting and diagnostics for Stata
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  iivw

Description:
  Displays package overview and available commands for inverse
  intensity of visit weighting (IIW), inverse probability of treatment
  weighting (IPTW), their combination (FIPTIW), and diagnostic
  decomposition of sampling versus measurement artifact.

See help iivw for complete documentation
*/

program define iivw, rclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    local __iivw_smcl_lb = char(123)
    local __iivw_smcl_rb = char(125)
    capture noisily {

    syntax

    * Derive the displayed version from this file's *! header so it can never
    * drift from the package version on a bump.
    local version "unknown"
    capture findfile iivw.ado
    if !_rc {
        tempname __iivw_fh
        capture file open `__iivw_fh' using "`r(fn)'", read text
        if !_rc {
            file read `__iivw_fh' __iivw_header_line
            file close `__iivw_fh'
            if regexm("`__iivw_header_line'", "Version ([0-9.]+)") {
                local version = regexs(1)
            }
        }
    }

    display as text ""
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
    display as result "iivw" as text " - Visit Weighting and Diagnostic Workflow for Stata"
    display as text "Version `version'"
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
    display as text ""
    display as text "`__iivw_smcl_lb'bf:Commands`__iivw_smcl_rb'"
    display as result "  iivw_weight     " as text "- Compute IIW/IPTW/FIPTIW weights"
    display as result "  iivw_balance    " as text "- Check weight leverage and visit-model balance"
    display as result "  iivw_fit        " as text "- Fit weighted or unweighted outcome model"
    display as result "  iivw_exogtest   " as text "- Test whether lagged outcomes predict visit timing"
    display as result "  iivw_diagnose   " as text "- Decompose marginal-slope movement across models"
    display as text ""
    display as text "`__iivw_smcl_lb'bf:Weight types`__iivw_smcl_rb'"
    display as text "  IIW     - Inverse intensity weighting (visit process correction)"
    display as text "  IPTW    - Inverse probability of treatment weighting"
    display as text "  FIPTIW  - Fully inverse probability of treatment and intensity"
    display as text "            weighting (IIW x IPTW)"
    display as text ""
    display as text "`__iivw_smcl_lb'bf:Typical diagnostic workflow`__iivw_smcl_rb'"
    display as text ""
    display as text "  1. `__iivw_smcl_lb'cmd:iivw_fit, unweighted`__iivw_smcl_rb'  Fit baseline unweighted outcome model"
    display as text "  2. `__iivw_smcl_lb'cmd:iivw_weight`__iivw_smcl_rb'           Estimate weights from visit/treatment models"
    display as text "  3. `__iivw_smcl_lb'cmd:iivw_balance`__iivw_smcl_rb'          Check leverage and visit-model balance"
    display as text "  4. `__iivw_smcl_lb'cmd:iivw_fit`__iivw_smcl_rb'              Fit weighted and artifact-adjusted models"
    display as text "  5. `__iivw_smcl_lb'cmd:iivw_exogtest`__iivw_smcl_rb'         Check measurement-process exogeneity"
    display as text "  6. `__iivw_smcl_lb'cmd:iivw_diagnose`__iivw_smcl_rb'         Summarize sampling/artifact movement"
    display as text ""
    display as text "`__iivw_smcl_lb'bf:Example`__iivw_smcl_rb'"
    display as text ""
    display as text "  `__iivw_smcl_lb'cmd:iivw_weight, id(id) time(days) ///`__iivw_smcl_rb'"
    display as text "  `__iivw_smcl_lb'cmd:    visit_cov(edss relapse) ///`__iivw_smcl_rb'"
    display as text "  `__iivw_smcl_lb'cmd:    treat(treated) treat_cov(age sex edss_bl) ///`__iivw_smcl_rb'"
    display as text "  `__iivw_smcl_lb'cmd:    truncate(1 99) nolog`__iivw_smcl_rb'"
    display as text ""
    display as text "  `__iivw_smcl_lb'cmd:iivw_fit edss treated age sex edss_bl, ///`__iivw_smcl_rb'"
    display as text "  `__iivw_smcl_lb'cmd:    model(gee) family(gaussian) timespec(linear)`__iivw_smcl_rb'"
    display as text ""
    display as text "Help:  " as result "`__iivw_smcl_lb'help iivw`__iivw_smcl_rb'" as text "  for documentation"
    display as text "       " as result "`__iivw_smcl_lb'help iivw_weight`__iivw_smcl_rb'" as text "  for weight computation"
    display as text "       " as result "`__iivw_smcl_lb'help iivw_balance`__iivw_smcl_rb'" as text "  for balance diagnostics"
    display as text "       " as result "`__iivw_smcl_lb'help iivw_fit`__iivw_smcl_rb'" as text "  for outcome model"
    display as text "       " as result "`__iivw_smcl_lb'help iivw_exogtest`__iivw_smcl_rb'" as text "  for timing exogeneity diagnostics"
    display as text "       " as result "`__iivw_smcl_lb'help iivw_diagnose`__iivw_smcl_rb'" as text "  for diagnostic decomposition"
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"

    return local version "`version'"
    return local commands "iivw_weight iivw_balance iivw_fit iivw_exogtest iivw_diagnose"
    return scalar n_commands = 5

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
