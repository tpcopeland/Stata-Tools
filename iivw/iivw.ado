*! iivw Version 1.2.0  2026/03/07
*! Inverse intensity of visit weighting for Stata
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  iivw

Description:
  Displays package overview and available commands for inverse
  intensity of visit weighting (IIW), inverse probability of treatment
  weighting (IPTW), and their combination (FIPTIW).

See help iivw for complete documentation
*/

program define iivw, rclass
    version 16.0
    set varabbrev off
    set more off

    syntax

    local version "1.2.0"

    display as text ""
    display as text "{hline 70}"
    display as result "iivw" as text " - Inverse Intensity of Visit Weighting for Stata"
    display as text "Version `version'"
    display as text "{hline 70}"
    display as text ""
    display as text "{bf:Commands}"
    display as result "  iivw_weight     " as text "- Compute IIW/IPTW/FIPTIW weights"
    display as result "  iivw_fit        " as text "- Fit weighted outcome model (GEE/mixed)"
    display as text ""
    display as text "{bf:Weight types}"
    display as text "  IIW     - Inverse intensity weighting (visit process correction)"
    display as text "  IPTW    - Inverse probability of treatment weighting"
    display as text "  FIPTIW  - Fully inverse probability of treatment and intensity"
    display as text "            weighting (IIW x IPTW)"
    display as text ""
    display as text "{bf:Typical workflow}"
    display as text ""
    display as text "  1. {cmd:iivw_weight}    Estimate weights from visit/treatment models"
    display as text "  2. Inspect weights   {cmd:summarize _iivw_weight, detail}"
    display as text "  3. {cmd:iivw_fit}       Fit weighted outcome model"
    display as text ""
    display as text "{bf:Example}"
    display as text ""
    display as text "  {cmd:iivw_weight, id(id) time(days) ///}"
    display as text "  {cmd:    visit_cov(edss relapse) ///}"
    display as text "  {cmd:    treat(treated) treat_cov(age sex edss_bl) ///}"
    display as text "  {cmd:    truncate(1 99) nolog}"
    display as text ""
    display as text "  {cmd:iivw_fit edss treated age sex edss_bl, ///}"
    display as text "  {cmd:    model(gee) family(gaussian) timespec(linear)}"
    display as text ""
    display as text "Help:  " as result "{help iivw}" as text "  for documentation"
    display as text "       " as result "{help iivw_weight}" as text "  for weight computation"
    display as text "       " as result "{help iivw_fit}" as text "  for outcome model"
    display as text "{hline 70}"

    return local version "`version'"
    return local commands "iivw_weight iivw_fit"
    return scalar n_commands = 2
end
