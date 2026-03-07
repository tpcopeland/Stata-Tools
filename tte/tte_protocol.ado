*! tte_protocol Version 1.0.2  2026/03/01
*! Target trial protocol table (Hernan 7-component) for target trial emulation
*! Author: Timothy P Copeland
*! Author: Tania F Reza
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Department of Global Public Health, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tte_protocol, auto [eligibility(string) treatment(string) ...]
  tte_protocol, eligibility(string) treatment(string) assignment(string)
      followup_start(string) outcome(string) causal_contrast(string)
      analysis(string) [export(filename) format(string)]

Description:
  Generates a formatted target trial protocol specification table
  following Hernan & Robins (2016) 7-component framework.

  With auto, reads dataset metadata from tte_prepare/tte_fit to
  generate default text for each component. User-supplied text
  overrides auto-generated defaults.

See help tte_protocol for complete documentation
*/

program define tte_protocol, rclass
    version 16.0
    set varabbrev off
    set more off

    syntax [, AUTO ELIGibility(string) TREATment(string) ///
        ASSignment(string) FOLLowup_start(string) ///
        OUTcome(string) CAUSal_contrast(string) ///
        ANALysis(string) ///
        EXPort(string) FORmat(string) TItle(string) REPLACE]

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
    * AUTO-FILL FROM METADATA
    * =========================================================================

    if "`auto'" != "" {
        * Require at least tte_prepare metadata
        local _prepared : char _dta[_tte_prepared]
        if "`_prepared'" != "1" {
            display as error "auto requires data prepared with tte_prepare"
            exit 198
        }

        * Read metadata
        local _id        : char _dta[_tte_id]
        local _treatment : char _dta[_tte_treatment]
        local _outcome   : char _dta[_tte_outcome]
        local _eligible  : char _dta[_tte_eligible]
        local _estimand  : char _dta[_tte_estimand]

        * Read fit metadata if available
        local _fitted    : char _dta[_tte_fitted]
        local _model     : char _dta[_tte_model]
        local _fu_spec   : char _dta[_tte_followup_spec]
        local _cluster   : char _dta[_tte_cluster]

        * Auto-fill components not supplied by user
        if `"`eligibility'"' == "" {
            local eligibility "Eligible at each period (`_eligible' == 1); `_id' as unit of analysis"
        }
        if `"`treatment'"' == "" {
            local treatment "Initiate treatment (`_treatment' == 1) vs. do not initiate"
        }
        if `"`assignment'"' == "" {
            local assignment "At each eligible period, based on observed `_treatment' values"
        }
        if `"`followup_start'"' == "" {
            local followup_start "Start of the period when eligibility criteria are met"
        }
        if `"`outcome'"' == "" {
            local outcome "Binary outcome event (`_outcome' == 1)"
        }
        if `"`causal_contrast'"' == "" {
            if "`_estimand'" == "ITT" {
                local causal_contrast "Intention-to-treat (ITT)"
            }
            else if "`_estimand'" == "PP" {
                local causal_contrast "Per-protocol (PP)"
            }
            else if "`_estimand'" == "AT" {
                local causal_contrast "As-treated (AT)"
            }
            else {
                local causal_contrast "`_estimand'"
            }
        }
        if `"`analysis'"' == "" {
            if "`_fitted'" == "1" {
                local _model_desc "Pooled logistic regression"
                if "`_model'" == "cox" {
                    local _model_desc "Cox proportional hazards"
                }
                local _se_desc "robust SE"
                if "`_cluster'" != "" {
                    local _se_desc "robust SE, clustered by `_cluster'"
                }
                local _fu_desc ""
                if "`_fu_spec'" != "" {
                    local _fu_desc ", follow-up modeled as `_fu_spec'"
                }
                local analysis "`_model_desc' with `_se_desc'`_fu_desc'"
            }
            else {
                local analysis "To be specified after model fitting"
            }
        }
    }
    else {
        * Without auto, all 7 components are required
        if `"`eligibility'"' == "" | `"`treatment'"' == "" | ///
           `"`assignment'"' == "" | `"`followup_start'"' == "" | ///
           `"`outcome'"' == "" | `"`causal_contrast'"' == "" | ///
           `"`analysis'"' == "" {
            display as error "all 7 protocol components required, or specify auto"
            exit 198
        }
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
                putexcel A1 = "`title'"
                putexcel A3 = "Component" B3 = "Description"
                putexcel A4 = "1. Eligibility criteria" B4 = "`eligibility'"
                putexcel A5 = "2. Treatment strategies" B5 = "`treatment'"
                putexcel A6 = "3. Treatment assignment" B6 = "`assignment'"
                putexcel A7 = "4. Start of follow-up" B7 = "`followup_start'"
                putexcel A8 = "5. Outcome" B8 = "`outcome'"
                putexcel A9 = "6. Causal contrast" B9 = "`causal_contrast'"
                putexcel A10 = "7. Statistical analysis" B10 = "`analysis'"
            }

            * Apply formatting (non-fatal)
            capture {
                mata: b = xl()
                mata: b.load_book("`export'")
                mata: b.set_sheet("Protocol")
                mata: b.set_column_width(1, 1, 28)
                mata: b.set_column_width(2, 2, 60)
                mata: b.set_row_height(1, 1, 20)
                mata: b.set_row_height(4, 10, 30)
                mata: b.close_book()
            }
            if _rc {
                local saved_rc = _rc
                capture mata: b.close_book()
                capture mata: mata drop b
                noisily display as error ///
                    "Excel formatting (Mata) failed with error `saved_rc'"
            }
            capture mata: mata drop b

            capture {
                putexcel set "`export'", sheet("Protocol") modify
                putexcel (A1:B1), merge bold
                putexcel (A3:B3), bold hcenter
                putexcel (A3:B3), border(top, thin)
                putexcel (A3:B3), border(bottom, thin)
                putexcel (A10:B10), border(bottom, thin)
                putexcel (A4:B10), txtwrap
                putexcel (A1:B10), font(Arial, 10)
                putexcel clear
            }
            if _rc {
                local saved_rc = _rc
                capture putexcel clear
                noisily display as error ///
                    "Excel cell formatting failed with error `saved_rc'"
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
