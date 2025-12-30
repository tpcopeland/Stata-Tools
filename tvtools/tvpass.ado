*! tvpass Version 1.0.0  2025/12/29
*! Post-authorization safety/efficacy study workflow support
*! Author: Tim Copeland
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tvpass, cohort(filename) exposure(filename) outcomes(filename) ///
      [id(varname) protocol(filename)]

Description:
  Provides workflow support for post-authorization safety studies (PASS)
  and post-authorization efficacy studies (PAES), including structured
  output for regulatory submissions.

See help tvpass for complete documentation
*/

program define tvpass, rclass
    version 16.0
    set varabbrev off

    syntax , COHort(string) EXPosure(string) OUTcomes(string) ///
        [ID(name) PROTocol(string)]

    * =========================================================================
    * VALIDATE INPUT
    * =========================================================================

    * Check files exist
    foreach file in cohort exposure outcomes {
        capture confirm file `"``file''"'
        if _rc != 0 {
            display as error "`file' file not found: ``file''"
            exit 601
        }
    }

    * Set defaults
    if "`id'" == "" local id "id"

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as text "{bf:TVPASS: Post-Authorization Safety/Efficacy Study Workflow}"
    display as text "{hline 70}"
    display as text ""
    display as text "Cohort file:    " as result "`cohort'"
    display as text "Exposure file:  " as result "`exposure'"
    display as text "Outcomes file:  " as result "`outcomes'"
    if "`protocol'" != "" {
        display as text "Protocol:       " as result "`protocol'"
    }
    display as text ""

    * =========================================================================
    * LOAD AND DESCRIBE DATA
    * =========================================================================

    display as text "{bf:Step 1: Data Overview}"
    display as text "{hline 40}"

    * Cohort
    preserve
    use `"`cohort'"', clear
    quietly count
    local n_cohort = r(N)
    quietly distinct `id'
    local n_ids = r(ndistinct)
    display as text "Cohort:   " as result `n_cohort' " obs, " `n_ids' " individuals"
    restore

    * Exposure
    preserve
    use `"`exposure'"', clear
    quietly count
    local n_exp = r(N)
    display as text "Exposure: " as result `n_exp' " records"
    restore

    * Outcomes
    preserve
    use `"`outcomes'"', clear
    quietly count
    local n_out = r(N)
    display as text "Outcomes: " as result `n_out' " records"
    restore

    display as text ""

    * =========================================================================
    * WORKFLOW GUIDANCE
    * =========================================================================

    display as text "{bf:Step 2: Recommended Workflow}"
    display as text "{hline 40}"
    display as text ""
    display as text "1. Load cohort data:"
    display as text "   . use `cohort', clear"
    display as text ""
    display as text "2. Create time-varying exposure:"
    display as text "   . tvexpose using `exposure', id(`id') ..."
    display as text ""
    display as text "3. Add outcomes:"
    display as text "   . tvevent using intervals, id(`id') ..."
    display as text ""
    display as text "4. Run diagnostics:"
    display as text "   . tvdiagnose, id(`id') ..."
    display as text "   . tvbalance covariates, exposure(tv_exposure)"
    display as text ""
    display as text "5. Analyze:"
    display as text "   . stset stop, failure(_event) id(`id') origin(start)"
    display as text "   . stcox tv_exposure, ..."
    display as text ""
    display as text "6. Sensitivity analysis:"
    display as text "   . tvsensitivity, rr(...)"
    display as text ""

    * =========================================================================
    * RETURN VALUES
    * =========================================================================

    return scalar n_cohort = `n_cohort'
    return scalar n_ids = `n_ids'
    return scalar n_exposure = `n_exp'
    return scalar n_outcomes = `n_out'

    return local cohort "`cohort'"
    return local exposure "`exposure'"
    return local outcomes "`outcomes'"
    return local id "`id'"

    display as text "{hline 70}"

end
