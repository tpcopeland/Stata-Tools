*! msm_protocol Version 1.2.0  2026/06/17
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
  replace                  - Replace Protocol sheet in existing workbook

See help msm_protocol for complete documentation
*/

program define msm_protocol, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    local _restore_needed = 0
    set varabbrev off
    set more off

    capture noisily {

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

        mata: st_local("_csv_population", _msm_protocol_csv_escape(st_local("population")))
        mata: st_local("_csv_treatment", _msm_protocol_csv_escape(st_local("treatment")))
        mata: st_local("_csv_confounders", _msm_protocol_csv_escape(st_local("confounders")))
        mata: st_local("_csv_outcome", _msm_protocol_csv_escape(st_local("outcome")))
        mata: st_local("_csv_causal_contrast", _msm_protocol_csv_escape(st_local("causal_contrast")))
        mata: st_local("_csv_weight_spec", _msm_protocol_csv_escape(st_local("weight_spec")))
        mata: st_local("_csv_analysis", _msm_protocol_csv_escape(st_local("analysis")))

        tempname fh
        local _fh_open = 0
        capture noisily {
            file open `fh' using "`export'", write `replace'
            local _fh_open = 1
            file write `fh' `""Component","Description""' _n
            file write `fh' `""Population",`_csv_population'"' _n
            file write `fh' `""Treatment strategies",`_csv_treatment'"' _n
            file write `fh' `""Confounders",`_csv_confounders'"' _n
            file write `fh' `""Outcome",`_csv_outcome'"' _n
            file write `fh' `""Causal contrast",`_csv_causal_contrast'"' _n
            file write `fh' `""Weight specification",`_csv_weight_spec'"' _n
            file write `fh' `""Statistical analysis",`_csv_analysis'"' _n
            file close `fh'
            local _fh_open = 0
        }
        if _rc {
            if `_fh_open' capture file close `fh'
            exit _rc
        }
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
        if "`replace'" != "" local rep_opt "sheetreplace"

        quietly {
            preserve
            local _restore_needed = 1
            clear
            set obs 7
            gen str40 component = ""
            gen strL description = ""

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
            local _restore_needed = 0
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

        mata: st_local("_tex_population", _msm_protocol_latex_escape(st_local("population")))
        mata: st_local("_tex_treatment", _msm_protocol_latex_escape(st_local("treatment")))
        mata: st_local("_tex_confounders", _msm_protocol_latex_escape(st_local("confounders")))
        mata: st_local("_tex_outcome", _msm_protocol_latex_escape(st_local("outcome")))
        mata: st_local("_tex_causal_contrast", _msm_protocol_latex_escape(st_local("causal_contrast")))
        mata: st_local("_tex_weight_spec", _msm_protocol_latex_escape(st_local("weight_spec")))
        mata: st_local("_tex_analysis", _msm_protocol_latex_escape(st_local("analysis")))

        tempname fh
        local _fh_open = 0
        capture noisily {
            file open `fh' using "`export'", write `replace'
            local _fh_open = 1

            file write `fh' "\begin{table}[htbp]" _n
            file write `fh' "\centering" _n
            file write `fh' "\caption{MSM Study Protocol}" _n
            file write `fh' "\begin{tabular}{lp{10cm}}" _n
            file write `fh' "\toprule" _n
            file write `fh' "Component & Description \\" _n
            file write `fh' "\midrule" _n
            file write `fh' `"1. Population & `_tex_population' \\"' _n
            file write `fh' `"2. Treatment strategies & `_tex_treatment' \\"' _n
            file write `fh' `"3. Confounders & `_tex_confounders' \\"' _n
            file write `fh' `"4. Outcome & `_tex_outcome' \\"' _n
            file write `fh' `"5. Causal contrast & `_tex_causal_contrast' \\"' _n
            file write `fh' `"6. Weight specification & `_tex_weight_spec' \\"' _n
            file write `fh' `"7. Statistical analysis & `_tex_analysis' \\"' _n
            file write `fh' "\bottomrule" _n
            file write `fh' "\end{tabular}" _n
            file write `fh' "\end{table}" _n

            file close `fh'
            local _fh_open = 0
        }
        if _rc {
            if `_fh_open' capture file close `fh'
            exit _rc
        }
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

    } /* end capture noisily */
    local _rc = _rc

    if `_restore_needed' {
        capture restore
    }

    set varabbrev `_varabbrev'
    set more `_more'

    if `_rc' exit `_rc'
end

mata:
string scalar _msm_protocol_csv_escape(string scalar s)
{
    string scalar dq

    dq = char(34)
    return(dq + subinstr(s, dq, dq + dq, .) + dq)
}

string scalar _msm_protocol_latex_escape(string scalar s)
{
    string scalar bs, placeholder

    bs = char(92)
    placeholder = char(1)
    s = subinstr(s, bs, placeholder, .)
    s = subinstr(s, "&", bs + "&", .)
    s = subinstr(s, "%", bs + "%", .)
    s = subinstr(s, "$", bs + "$", .)
    s = subinstr(s, "#", bs + "#", .)
    s = subinstr(s, "_", bs + "_", .)
    s = subinstr(s, "{", bs + "{", .)
    s = subinstr(s, "}", bs + "}", .)
    s = subinstr(s, "~", bs + "textasciitilde{}", .)
    s = subinstr(s, "^", bs + "textasciicircum{}", .)
    s = subinstr(s, placeholder, bs + "textbackslash{}", .)
    return(s)
}
end
