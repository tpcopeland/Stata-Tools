*! nma_report Version 1.0.5  2026/03/01
*! Publication-quality report export for network meta-analysis
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  nma_report using filename [, format(excel|csv) eform replace
      sections(setup fit rank inconsistency)]

Description:
  Exports a structured report with selected analysis sections to
  Excel or CSV format.

See help nma_report for complete documentation
*/

program define nma_report, rclass
    version 16.0
    set varabbrev off
    set more off

    syntax using/ [, FORmat(string) EFORM REPLACE ///
        SECTions(string) Level(cilevel) DIGits(integer 4)]

    * =======================================================================
    * CHECK PREREQUISITES
    * =======================================================================

    _nma_check_setup
    _nma_check_fitted
    _nma_get_settings

    local ref         "`_nma_ref'"
    local treatments  "`_nma_treatments'"
    local n_treatments = `_nma_n_treatments'
    local k = `n_treatments'
    local measure     "`_nma_measure'"
    local n_studies   = `_nma_n_studies'
    local ref_code    : char _dta[_nma_ref_code]

    if "`format'" == "" local format "excel"
    if !inlist("`format'", "excel", "csv") {
        display as error "format() must be excel or csv"
        exit 198
    }
    if "`level'" == "" local level 95
    if "`sections'" == "" local sections "setup fit rank"

    local use_eform = 0
    if "`eform'" != "" & inlist("`measure'", "or", "rr", "irr", "hr") {
        local use_eform = 1
    }

    _nma_display_header, command("nma_report") ///
        description("Exporting publication report")

    * =======================================================================
    * BUILD REPORT DATASET
    * =======================================================================

    preserve

    local z_crit = invnormal(1 - (1 - `level'/100) / 2)

    * Map treatment codes to parameter columns and save labels before clear
    local param_trts ""
    local col = 0
    forvalues t = 1/`k' {
        if `t' != `ref_code' {
            local ++col
            local param_trts "`param_trts' `t'"
            local pcol_`t' = `col'
            local trtlbl_`t' : word `t' of `treatments'
        }
    }

    tempname b V
    matrix `b' = e(b)
    matrix `V' = e(V)

    * --- Treatment effects table ---
    local has_fit : list posof "fit" in sections
    if `has_fit' {
        local p = colsof(`b')

        quietly {
            clear
            set obs `p'
            gen str80 treatment = ""
            gen str20 vs_ref = "`ref'"
            gen double effect = .
            gen double se = .
            gen double ci_lower = .
            gen double ci_upper = .
            gen double pvalue = .
            gen str20 evidence = ""
        }

        local col = 0
        foreach t of local param_trts {
            local ++col
            local lbl "`trtlbl_`t''"
            local coef = `b'[1, `col']
            local se_val = sqrt(`V'[`col', `col'])
            local ci_lo = `coef' - `z_crit' * `se_val'
            local ci_hi = `coef' + `z_crit' * `se_val'
            local z = `coef' / `se_val'
            local pval = 2 * (1 - normal(abs(`z')))

            local ev_code = _nma_evidence[`t', `ref_code']
            if `ev_code' == 1 local ev_lbl "Direct"
            else if `ev_code' == 2 local ev_lbl "Indirect"
            else if `ev_code' == 3 local ev_lbl "Mixed"
            else local ev_lbl ""

            if `use_eform' {
                local coef = exp(`coef')
                local ci_lo = exp(`ci_lo')
                local ci_hi = exp(`ci_hi')
            }

            quietly replace treatment = "`lbl'" in `col'
            quietly replace effect = `coef' in `col'
            quietly replace se = `se_val' in `col'
            quietly replace ci_lower = `ci_lo' in `col'
            quietly replace ci_upper = `ci_hi' in `col'
            quietly replace pvalue = `pval' in `col'
            quietly replace evidence = "`ev_lbl'" in `col'
        }

        * Convert to formatted strings for clean export (format handles rounding)
        quietly {
            foreach v in effect se ci_lower ci_upper {
                tostring `v', replace force format(%9.`digits'f)
                replace `v' = strtrim(`v')
            }
            tostring pvalue, replace force format(%7.`digits'f)
            replace pvalue = strtrim(pvalue)
        }

        if "`format'" == "excel" {
            export excel using "`using'", firstrow(variables) sheet("Treatment Effects") `replace'
        }
        else {
            export delimited using "`using'", `replace'
        }

        display as text "  Treatment effects table exported"
    }

    * --- Network summary ---
    local has_setup : list posof "setup" in sections
    if `has_setup' & "`format'" == "excel" {
        quietly {
            clear
            set obs 7
            gen str40 parameter = ""
            gen str80 value = ""

            replace parameter = "Studies" in 1
            replace value = "`n_studies'" in 1
            replace parameter = "Treatments" in 2
            replace value = "`n_treatments'" in 2
            replace parameter = "Reference" in 3
            replace value = "`ref'" in 3
            replace parameter = "Measure" in 4
            replace value = "`measure'" in 4
            replace parameter = "Method" in 5
            replace value = "`=e(method)'" in 5

            local tau2 = e(tau2)
            local I2_val = e(I2)
            replace parameter = "tau2" in 6
            replace value = string(`tau2', "%9.4f") in 6
            replace parameter = "I2" in 7
            replace value = string(`I2_val', "%5.1f") + "%" in 7
        }

        export excel using "`using'", firstrow(variables) sheet("Network Summary") sheetmodify
        display as text "  Network summary exported"
    }

    * --- Rankings (SUCRA) ---
    local has_rank : list posof "rank" in sections
    if `has_rank' {
        * Check if SUCRA matrices exist (nma_rank must have been run)
        capture confirm matrix _nma_sucra
        if _rc == 0 {
            quietly {
                clear
                set obs `k'
                gen str80 treatment = ""
                gen double sucra = .
                gen double mean_rank = .
            }

            forvalues i = 1/`k' {
                local lbl : word `i' of `treatments'
                quietly replace treatment = "`lbl'" in `i'
                quietly replace sucra = _nma_sucra[`i', 1] in `i'
                quietly replace mean_rank = _nma_meanrank[`i', 1] in `i'
            }

            * Format for clean export (format handles rounding)
            quietly {
                foreach v in sucra mean_rank {
                    tostring `v', replace force format(%9.`digits'f)
                    replace `v' = strtrim(`v')
                }
            }

            if "`format'" == "excel" {
                export excel using "`using'", firstrow(variables) sheet("Rankings") sheetmodify
            }
            else {
                * CSV: append not possible, export as separate file
                local rank_file = subinstr("`using'", ".csv", "_rankings.csv", 1)
                export delimited using "`rank_file'", replace
            }

            display as text "  Rankings (SUCRA) exported"
        }
        else {
            display as text "  Rankings skipped (run {bf:nma_rank} first)"
        }
    }

    * =======================================================================
    * XLSX FORMATTING (non-fatal, each sheet independent)
    * =======================================================================

    if "`format'" == "excel" {
        if `has_fit' {
            capture noisily {
                local n_rows = `p' + 1
                mata: b = xl()
                mata: b.load_book("`using'")
                mata: b.set_sheet("Treatment Effects")
                mata: b.set_column_width(1, 1, 22)
                mata: b.set_column_width(2, 2, 12)
                mata: b.set_column_width(3, 6, 14)
                mata: b.set_column_width(7, 7, 12)
                mata: b.set_column_width(8, 8, 12)
                mata: b.close_book()

                putexcel set "`using'", sheet("Treatment Effects") modify
                putexcel (A1:H1), bold hcenter
                putexcel (A1:H1), border(top, thin)
                putexcel (A1:H1), border(bottom, thin)
                putexcel (A`n_rows':H`n_rows'), border(bottom, thin)
                putexcel (A1:H`n_rows'), font(Arial, 10)
                putexcel clear
            }
        }

        if `has_setup' {
            capture noisily {
                mata: b = xl()
                mata: b.load_book("`using'")
                mata: b.set_sheet("Network Summary")
                mata: b.set_column_width(1, 1, 20)
                mata: b.set_column_width(2, 2, 25)
                mata: b.close_book()

                putexcel set "`using'", sheet("Network Summary") modify
                putexcel (A1:B1), bold hcenter
                putexcel (A1:B1), border(top, thin)
                putexcel (A1:B1), border(bottom, thin)
                putexcel (A8:B8), border(bottom, thin)
                putexcel (A1:B8), font(Arial, 10)
                putexcel clear
            }
        }

        if `has_rank' {
            local has_sucra = 0
            capture confirm matrix _nma_sucra
            if _rc == 0 local has_sucra = 1
            if `has_sucra' {
                capture noisily {
                    local rank_rows = `k' + 1
                    mata: b = xl()
                    mata: b.load_book("`using'")
                    mata: b.set_sheet("Rankings")
                    mata: b.set_column_width(1, 1, 22)
                    mata: b.set_column_width(2, 3, 14)
                    mata: b.close_book()

                    putexcel set "`using'", sheet("Rankings") modify
                    putexcel (A1:C1), bold hcenter
                    putexcel (A1:C1), border(top, thin)
                    putexcel (A1:C1), border(bottom, thin)
                    putexcel (A`rank_rows':C`rank_rows'), border(bottom, thin)
                    putexcel (A1:C`rank_rows'), font(Arial, 10)
                    putexcel clear
                }
            }
        }
    }

    restore

    display as text ""
    display as text "Report exported to: " as result "`using'"

    return local filename "`using'"
    return local format "`format'"
end
