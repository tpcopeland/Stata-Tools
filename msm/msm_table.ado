*! msm_table Version 1.2.0  2026/06/17
*! Publication-quality Excel tables for MSM pipeline results
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet

/*
Syntax:
  msm_table , xlsx(string) [table_options formatting_options]

Required:
  xlsx(string)         Excel output file (.xlsx extension)

Table selection (default: all available):
  coefficients         Model coefficients (requires msm_fit)
  predictions          Counterfactual outcomes (requires msm_predict)
  balance              Covariate balance (requires msm_diagnose)
  weights              Weight distribution (requires msm_diagnose)
  sensitivity          E-value analysis (requires msm_sensitivity)
  all                  All available tables on separate sheets

Formatting:
  eform                Exponentiated coefficients (OR/HR)
  decimals(#)          Decimal places (default: 3)
  sep(string)          CI delimiter (default: ", ")
  title(string)        Table title for cell A1
  replace              Replace selected sheet(s) in existing workbook
  font(string)         Font name (default: Arial)
  fontsize(#)          Font size in points (default: 10)
  borderstyle(string)  Border style: thin, medium, or academic (default: thin)
  nformat(string)      Excel number format for numeric cells
  zebra                Alternating row shading (light gray)
  boldp(#)             Bold p-values below threshold (Coefficients only)
  highlight(#)         Highlight rows where p < threshold (Coefficients only)
  footnote(string)     Merged footnote below each table
  open                 Auto-open Excel file after export

See help msm_table for complete documentation
*/

* =========================================================================
* MAIN DISPATCHER
* =========================================================================

program define msm_table, nclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    set varabbrev off
    set more off

    capture noisily {

    syntax , XLSX(string) [COEFficients PREDictions BALance WEIGHTs ///
        SENSitivity ALL EForm DECimals(integer 3) SEP(string) ///
        TITle(string) REPLACE Font(string) FONTSize(integer 10) ///
        BORDERstyle(string) NFORmat(string) ZEBRA BOLDp(real 0) ///
        HIGHlight(real 0) FOOTnote(string) OPEN]

    * Defaults
    if "`sep'" == "" local sep ", "
    if "`font'" == "" local font "Arial"
    if "`borderstyle'" == "" local borderstyle "thin"

    if `decimals' < 0 | `decimals' > 10 {
        display as error "decimals() must be between 0 and 10"
        exit 198
    }

    if !inlist("`borderstyle'", "thin", "medium", "academic") {
        display as error "borderstyle() must be thin, medium, or academic"
        exit 198
    }

    * Academic borderstyle uses medium for horizontal borders
    local _hborder = "`borderstyle'"
    if "`borderstyle'" == "academic" local _hborder "medium"

    if `fontsize' < 6 | `fontsize' > 72 {
        display as error "fontsize() must be between 6 and 72"
        exit 198
    }

    if `boldp' < 0 | `boldp' > 1 {
        display as error "boldp() must be between 0 and 1"
        exit 198
    }

    if `highlight' < 0 | `highlight' > 1 {
        display as error "highlight() must be between 0 and 1"
        exit 198
    }

    * Validate xlsx extension
    if !regexm("`xlsx'", "\.xlsx$") {
        display as error "xlsx() must specify a .xlsx file"
        exit 198
    }

    * Handle file existence. With replace, subtable writers use sheetreplace,
    * preserving unrelated sheets.
    if "`replace'" == "" {
        capture confirm new file "`xlsx'"
        if _rc {
            display as error "file {bf:`xlsx'} already exists; use {bf:replace} option"
            exit 602
        }
    }

    * Determine which tables to produce
    local any_explicit = ("`coefficients'" != "") | ("`predictions'" != "") | ///
        ("`balance'" != "") | ("`weights'" != "") | ("`sensitivity'" != "")

    local auto = ("`all'" != "") | !`any_explicit'

    local do_coef = `auto' | ("`coefficients'" != "")
    local do_pred = `auto' | ("`predictions'" != "")
    local do_bal  = `auto' | ("`balance'" != "")
    local do_wt   = `auto' | ("`weights'" != "")
    local do_sens = `auto' | ("`sensitivity'" != "")

    * Check availability and count sheets
    local n_sheets = 0

    if `do_coef' {
        local has : char _dta[_msm_fitted]
        if "`has'" != "1" {
            if `auto' local do_coef = 0
            else {
                display as error "coefficients table requires msm_fit"
                exit 198
            }
        }
        else {
            capture matrix list _msm_fit_b
            if _rc {
                if `auto' local do_coef = 0
                else {
                    display as error "saved model coefficients not found; re-run msm_fit"
                    exit 301
                }
            }
            else local ++n_sheets
        }
    }

    if `do_pred' {
        local has : char _dta[_msm_pred_saved]
        if "`has'" != "1" {
            if `auto' local do_pred = 0
            else {
                display as error "predictions table requires msm_predict"
                exit 198
            }
        }
        else {
            capture matrix list _msm_pred_matrix
            if _rc {
                if `auto' local do_pred = 0
                else {
                    display as error "predictions matrix not found; re-run msm_predict"
                    exit 111
                }
            }
            else local ++n_sheets
        }
    }

    if `do_bal' {
        local has : char _dta[_msm_bal_saved]
        if "`has'" != "1" {
            if `auto' local do_bal = 0
            else {
                display as error "balance table requires msm_diagnose"
                exit 198
            }
        }
        else {
            capture matrix list _msm_bal_matrix
            if _rc {
                if `auto' local do_bal = 0
                else {
                    display as error "balance matrix not found; re-run msm_diagnose"
                    exit 111
                }
            }
            else local ++n_sheets
        }
    }

    if `do_wt' {
        local has : char _dta[_msm_diag_saved]
        if "`has'" != "1" {
            if `auto' local do_wt = 0
            else {
                display as error "weights table requires msm_diagnose"
                exit 198
            }
        }
        else local ++n_sheets
    }

    if `do_sens' {
        local has : char _dta[_msm_sens_saved]
        if "`has'" != "1" {
            if `auto' local do_sens = 0
            else {
                display as error "sensitivity table requires msm_sensitivity"
                exit 198
            }
        }
        else local ++n_sheets
    }

    if `n_sheets' == 0 {
        display as error "no MSM results available for table export"
        exit 198
    }

    * Export tables
    if `do_coef' {
        _msm_tbl_coef, xlsx("`xlsx'") decimals(`decimals') ///
            sep("`sep'") title("`title'") `eform' ///
            font("`font'") fontsize(`fontsize') ///
            borderstyle("`borderstyle'") nformat("`nformat'") ///
            `zebra' boldp(`boldp') highlight(`highlight') ///
            footnote(`"`footnote'"')
    }
    if `do_pred' {
        _msm_tbl_pred, xlsx("`xlsx'") decimals(`decimals') ///
            sep("`sep'") title("`title'") ///
            font("`font'") fontsize(`fontsize') ///
            borderstyle("`borderstyle'") nformat("`nformat'") ///
            `zebra' footnote(`"`footnote'"')
    }
    if `do_bal' {
        _msm_tbl_bal, xlsx("`xlsx'") decimals(`decimals') ///
            title("`title'") ///
            font("`font'") fontsize(`fontsize') ///
            borderstyle("`borderstyle'") nformat("`nformat'") ///
            `zebra' footnote(`"`footnote'"')
    }
    if `do_wt' {
        _msm_tbl_wt, xlsx("`xlsx'") decimals(`decimals') ///
            title("`title'") ///
            font("`font'") fontsize(`fontsize') ///
            borderstyle("`borderstyle'") nformat("`nformat'") ///
            `zebra' footnote(`"`footnote'"')
    }
    if `do_sens' {
        _msm_tbl_sens, xlsx("`xlsx'") decimals(`decimals') ///
            title("`title'") ///
            font("`font'") fontsize(`fontsize') ///
            borderstyle("`borderstyle'") nformat("`nformat'") ///
            `zebra' footnote(`"`footnote'"')
    }

    display as text ""
    display as result "`n_sheets'" as text " table(s) exported to " ///
        as result "`xlsx'"

    if "`open'" != "" {
        _msm_post_export_open, file(`"`xlsx'"')
    }

    * Clear stray r() results from internal helper cleanup; msm_table is nclass.
    quietly version

    } /* end capture noisily */
    local _rc = _rc

    set varabbrev `_varabbrev'
    set more `_more'

    if `_rc' exit `_rc'
end
