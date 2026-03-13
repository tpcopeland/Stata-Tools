*! msm_protocol Version 1.0.0  2026/03/03
*! MSM study protocol specification
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  msm_protocol, population(string) treatment(string) confounders(string)
      outcome(string) causal_contrast(string) weight_spec(string)
      analysis(string) [options]

Description:
  Documents the MSM study protocol using 7 components adapted from the
  Hernan framework for MSM/IPTW analyses.

Options:
  population(string)       - Target population definition
  treatment(string)        - Treatment strategies compared
  confounders(string)      - Time-varying and baseline confounders
  outcome(string)          - Outcome definition
  causal_contrast(string)  - Causal contrast (e.g., "always vs never treated")
  weight_spec(string)      - Weight specification details
  analysis(string)         - Statistical analysis plan
  export(string)           - File path for export
  format(string)           - display (default) | csv | excel | latex
  replace                  - Replace existing file

See help msm_protocol for complete documentation
*/

program define msm_protocol, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    set varabbrev off
    set more off

    syntax , POPulation(string) TREATment(string) ///
        CONFounders(string) OUTcome(string) ///
        CAUSal_contrast(string) WEIGHT_spec(string) ///
        ANAlysis(string) ///
        [EXPort(string) FORmat(string) REPLACE]

    if "`format'" == "" local format "display"
    if !inlist("`format'", "display", "csv", "excel", "latex") {
        display as error "format() must be display, csv, excel, or latex"
        exit 198
    }

    * =========================================================================
    * DISPLAY FORMAT
    * =========================================================================

    if "`format'" == "display" {
        display as text ""
        display as text "{hline 70}"
        display as result "msm_protocol" as text " - MSM Study Protocol"
        display as text "{hline 70}"
        display as text ""

        display as text "  {result:1. Population}"
        display as text "     `population'"
        display as text ""
        display as text "  {result:2. Treatment strategies}"
        display as text "     `treatment'"
        display as text ""
        display as text "  {result:3. Confounders}"
        display as text "     `confounders'"
        display as text ""
        display as text "  {result:4. Outcome}"
        display as text "     `outcome'"
        display as text ""
        display as text "  {result:5. Causal contrast}"
        display as text "     `causal_contrast'"
        display as text ""
        display as text "  {result:6. Weight specification}"
        display as text "     `weight_spec'"
        display as text ""
        display as text "  {result:7. Statistical analysis}"
        display as text "     `analysis'"
        display as text ""
        display as text "{hline 70}"
    }

    * =========================================================================
    * CSV FORMAT
    * =========================================================================

    else if "`format'" == "csv" {
        if "`export'" == "" {
            display as error "export() required for csv format"
            exit 198
        }

        tempname fh
        file open `fh' using "`export'", write `replace'
        file write `fh' "Component,Description" _n
        file write `fh' `"Population,"`population'""' _n
        file write `fh' `"Treatment strategies,"`treatment'""' _n
        file write `fh' `"Confounders,"`confounders'""' _n
        file write `fh' `"Outcome,"`outcome'""' _n
        file write `fh' `"Causal contrast,"`causal_contrast'""' _n
        file write `fh' `"Weight specification,"`weight_spec'""' _n
        file write `fh' `"Statistical analysis,"`analysis'""' _n
        file close `fh'
        display as text "Protocol exported to: " as result "`export'"
    }

    * =========================================================================
    * EXCEL FORMAT
    * =========================================================================

    else if "`format'" == "excel" {
        if "`export'" == "" {
            display as error "export() required for excel format"
            exit 198
        }

        local rep_opt ""
        if "`replace'" != "" local rep_opt "replace"

        quietly {
            preserve
            clear
            set obs 7
            gen str40 component = ""
            gen str244 description = ""

            replace component = "1. Population" in 1
            replace description = `"`population'"' in 1
            replace component = "2. Treatment strategies" in 2
            replace description = `"`treatment'"' in 2
            replace component = "3. Confounders" in 3
            replace description = `"`confounders'"' in 3
            replace component = "4. Outcome" in 4
            replace description = `"`outcome'"' in 4
            replace component = "5. Causal contrast" in 5
            replace description = `"`causal_contrast'"' in 5
            replace component = "6. Weight specification" in 6
            replace description = `"`weight_spec'"' in 6
            replace component = "7. Statistical analysis" in 7
            replace description = `"`analysis'"' in 7

            export excel using "`export'", sheet("Protocol") ///
                firstrow(variables) `rep_opt'
            restore
        }
        display as text "Protocol exported to: " as result "`export'"
    }

    * =========================================================================
    * LATEX FORMAT
    * =========================================================================

    else if "`format'" == "latex" {
        if "`export'" == "" {
            display as error "export() required for latex format"
            exit 198
        }

        tempname fh
        file open `fh' using "`export'", write `replace'

        file write `fh' "\begin{table}[htbp]" _n
        file write `fh' "\centering" _n
        file write `fh' "\caption{MSM Study Protocol}" _n
        file write `fh' "\begin{tabular}{lp{10cm}}" _n
        file write `fh' "\toprule" _n
        file write `fh' "Component & Description \\" _n
        file write `fh' "\midrule" _n
        file write `fh' `"1. Population & `population' \\"' _n
        file write `fh' `"2. Treatment strategies & `treatment' \\"' _n
        file write `fh' `"3. Confounders & `confounders' \\"' _n
        file write `fh' `"4. Outcome & `outcome' \\"' _n
        file write `fh' `"5. Causal contrast & `causal_contrast' \\"' _n
        file write `fh' `"6. Weight specification & `weight_spec' \\"' _n
        file write `fh' `"7. Statistical analysis & `analysis' \\"' _n
        file write `fh' "\bottomrule" _n
        file write `fh' "\end{tabular}" _n
        file write `fh' "\end{table}" _n

        file close `fh'
        display as text "Protocol exported to: " as result "`export'"
    }

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return local population "`population'"
    return local treatment "`treatment'"
    return local confounders "`confounders'"
    return local outcome "`outcome'"
    return local causal_contrast "`causal_contrast'"
    return local weight_spec "`weight_spec'"
    return local analysis "`analysis'"
    return local format "`format'"

    set varabbrev `_varabbrev'
    set more `_more'
end
