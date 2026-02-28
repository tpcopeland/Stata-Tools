*! tte_protocol Version 1.0.1  2026/02/27
*! Target trial protocol table (Hernan 7-component) for target trial emulation
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tte_protocol, eligibility(string) treatment(string)
      assignment(string) followup_start(string)
      outcome(string) causal_contrast(string)
      analysis(string) [export(filename) format(string)]

Description:
  Generates a formatted target trial protocol specification table
  following Hernan & Robins (2016) 7-component framework. This is
  unique to our package - the R TrialEmulation package does not
  have this feature.

Options:
  eligibility(string)       - Eligibility criteria (required)
  treatment(string)         - Treatment strategies (required)
  assignment(string)        - Treatment assignment procedure (required)
  followup_start(string)    - Follow-up start / time zero (required)
  outcome(string)           - Outcome of interest (required)
  causal_contrast(string)   - Causal contrast (ITT/PP) (required)
  analysis(string)          - Statistical analysis plan (required)
  export(filename)          - Export to file
  format(string)            - display (default) | csv | excel | latex
  title(string)             - Custom title
  replace                   - Replace existing file

See help tte_protocol for complete documentation
*/

program define tte_protocol, rclass
    version 16.0
    set varabbrev off
    set more off

    syntax , ELIGibility(string) TREATment(string) ///
        ASSignment(string) FOLLowup_start(string) ///
        OUTcome(string) CAUSal_contrast(string) ///
        ANALysis(string) ///
        [EXPort(string) FORmat(string) TItle(string) REPLACE]

    * =========================================================================
    * DEFAULTS
    * =========================================================================

    if "`format'" == "" local format "display"
    if "`title'" == "" local title "Target Trial Protocol Specification"

    if !inlist("`format'", "display", "csv", "excel", "latex") {
        display as error "format() must be display, csv, excel, or latex"
        exit 198
    }

    * =========================================================================
    * DISPLAY TABLE
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as result "`title'"
    display as text "(Hernan & Robins 7-component framework)"
    display as text "{hline 70}"
    display as text ""

    display as text "{bf:1. Eligibility criteria}"
    display as text "   `eligibility'"
    display as text ""

    display as text "{bf:2. Treatment strategies}"
    display as text "   `treatment'"
    display as text ""

    display as text "{bf:3. Treatment assignment}"
    display as text "   `assignment'"
    display as text ""

    display as text "{bf:4. Start of follow-up (time zero)}"
    display as text "   `followup_start'"
    display as text ""

    display as text "{bf:5. Outcome}"
    display as text "   `outcome'"
    display as text ""

    display as text "{bf:6. Causal contrast}"
    display as text "   `causal_contrast'"
    display as text ""

    display as text "{bf:7. Statistical analysis}"
    display as text "   `analysis'"
    display as text ""

    display as text "{hline 70}"

    * =========================================================================
    * EXPORT
    * =========================================================================

    if "`export'" != "" {
        if "`format'" == "csv" {
            tempname fh
            file open `fh' using "`export'", write `replace'
            file write `fh' "Component,Description" _n
            file write `fh' `"Eligibility criteria,"`eligibility'""' _n
            file write `fh' `"Treatment strategies,"`treatment'""' _n
            file write `fh' `"Treatment assignment,"`assignment'""' _n
            file write `fh' `"Start of follow-up,"`followup_start'""' _n
            file write `fh' `"Outcome,"`outcome'""' _n
            file write `fh' `"Causal contrast,"`causal_contrast'""' _n
            file write `fh' `"Statistical analysis,"`analysis'""' _n
            file close `fh'
            display as text "Protocol exported to: " as result "`export'"
        }
        else if "`format'" == "excel" {
            quietly {
                putexcel set "`export'", sheet("Protocol") `replace'
                putexcel A1 = "`title'" A1:B1 = "`title'"
                putexcel A3 = "Component" B3 = "Description"
                putexcel A4 = "1. Eligibility criteria" B4 = "`eligibility'"
                putexcel A5 = "2. Treatment strategies" B5 = "`treatment'"
                putexcel A6 = "3. Treatment assignment" B6 = "`assignment'"
                putexcel A7 = "4. Start of follow-up" B7 = "`followup_start'"
                putexcel A8 = "5. Outcome" B8 = "`outcome'"
                putexcel A9 = "6. Causal contrast" B9 = "`causal_contrast'"
                putexcel A10 = "7. Statistical analysis" B10 = "`analysis'"
            }
            display as text "Protocol exported to: " as result "`export'"
        }
        else if "`format'" == "latex" {
            tempname fh
            file open `fh' using "`export'", write `replace'
            file write `fh' "\begin{table}[htbp]" _n
            file write `fh' "\centering" _n
            file write `fh' "\caption{`title'}" _n
            file write `fh' "\begin{tabular}{lp{10cm}}" _n
            file write `fh' "\hline" _n
            file write `fh' "Component & Description \\" _n
            file write `fh' "\hline" _n
            file write `fh' "1. Eligibility criteria & `eligibility' \\" _n
            file write `fh' "2. Treatment strategies & `treatment' \\" _n
            file write `fh' "3. Treatment assignment & `assignment' \\" _n
            file write `fh' "4. Start of follow-up & `followup_start' \\" _n
            file write `fh' "5. Outcome & `outcome' \\" _n
            file write `fh' "6. Causal contrast & `causal_contrast' \\" _n
            file write `fh' "7. Statistical analysis & `analysis' \\" _n
            file write `fh' "\hline" _n
            file write `fh' "\end{tabular}" _n
            file write `fh' "\end{table}" _n
            file close `fh'
            display as text "Protocol exported to: " as result "`export'"
        }
    }

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return local eligibility "`eligibility'"
    return local treatment "`treatment'"
    return local assignment "`assignment'"
    return local followup_start "`followup_start'"
    return local outcome "`outcome'"
    return local causal_contrast "`causal_contrast'"
    return local analysis "`analysis'"
    return local format "`format'"
end
