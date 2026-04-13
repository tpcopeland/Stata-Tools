*! fittab Version 1.0.3  2026/04/13
*! Model comparison table
*! Author: Timothy P Copeland
*! Program class: rclass

/*
DESCRIPTION:
    Compares stored estimation results side-by-side with fit statistics
    (N, AIC, BIC, log-likelihood, C-statistic, R-squared). Exports to
    Excel with professional formatting.

SYNTAX:
    fittab namelist, xlsx(filename)
        [stats(string) labels(string) lrtest(name)
        sheet(string) title(string) subtitle(string)
        footnote(string) theme(string) borderstyle(string)
        zebra csv(filename) frame(name) display open]
*/

program define fittab, rclass
    version 17.0
    local _prev_varabbrev = c(varabbrev)
    set varabbrev off

    * Auto-load shared helper programs
    capture program list _tabtools_validate_path
    if _rc {
        capture findfile _tabtools_common.ado
        if _rc == 0 {
            run "`r(fn)'"
        }
        else {
            display as error "_tabtools_common.ado not found; reinstall tabtools"
            set varabbrev `_prev_varabbrev'
            exit 111
        }
    }

capture noisily {

**# Syntax and Validation
    syntax anything(name=namelist), [xlsx(string) excel(string) sheet(string) ///
        stats(string) LABels(string) LRTest(name) ///
        title(string) SUBtitle(string) ///
        FOOTnote(string) THEme(string) BORDERstyle(string) ///
        zebra csv(string) FRAme(string) DISplay open]

    * Accept excel() as synonym
    if "`xlsx'" == "" & "`excel'" != "" local xlsx "`excel'"
    local _has_xlsx = "`xlsx'" != ""

    * Defaults
    if "`sheet'" == "" local sheet "Model Comparison"
    _tabtools_validate_sheet "`sheet'" "sheet()"
    if `_has_xlsx' _tabtools_validate_path "`xlsx'" "xlsx()"
    if "`csv'" != "" _tabtools_validate_path "`csv'" "csv()"

    * Default statistics
    if "`stats'" == "" local stats "n aic bic ll"

    * Expand stat abbreviations
    local _expanded_stats ""
    foreach _sw of local stats {
        if inlist("`_sw'", "c", "cstat", "c_stat") local _sw "cstat"
        local _expanded_stats "`_expanded_stats' `_sw'"
    }
    local stats = strtrim("`_expanded_stats'")

    * Count models
    local n_models : word count `namelist'
    if `n_models' < 2 {
        noisily display as error "fittab requires at least 2 stored estimates"
        noisily display as error "Hint: run models and store with {bf:estimates store name} before calling fittab"
        exit 198
    }

    * Parse model labels
    if "`labels'" != "" {
        local labels = subinstr("`labels'", " \ ", "\", .)
        tokenize `"`labels'"', parse("\")
        forvalues m = 1/`n_models' {
            local j = (`m'-1)*2 + 1
            if "``j''" != "" local mlabel_`m' = strtrim("``j''")
            else local mlabel_`m' : word `m' of `namelist'
        }
    }
    else {
        forvalues m = 1/`n_models' {
            local mlabel_`m' : word `m' of `namelist'
        }
    }

    * Resolve formatting
    _tabtools_resolve_format, theme(`theme') borderstyle(`borderstyle')

**# Extract Statistics from Stored Estimates
    local best_aic = .
    local best_bic = .
    local best_cstat = 0
    local _held_active = 0

    tempname _fittab_orig
    capture _estimates hold `_fittab_orig', copy
    local _held_ok = (_rc == 0)
    if `_held_ok' local _held_active = 1

    forvalues m = 1/`n_models' {
        local _mname : word `m' of `namelist'
        capture estimates restore `_mname'
        if _rc {
            noisily display as error "estimates '`_mname'' not found"
            noisily display as error "Hint: run {bf:estimates dir} to see available stored estimates"
            exit 111
        }

        * N
        local _n_`m' = e(N)

        * AIC/BIC via estat ic
        capture quietly estat ic
        if !_rc {
            tempname _ic
            matrix `_ic' = r(S)
            local _aic_`m' = `_ic'[1, 5]
            local _bic_`m' = `_ic'[1, 6]
            local _ll_`m' = `_ic'[1, 3]
        }
        else {
            local _aic_`m' = .
            local _bic_`m' = .
            capture local _ll_`m' = e(ll)
            if _rc local _ll_`m' = .
        }

        * C-statistic (try estat concordance, then lroc as fallback)
        local _cstat_`m' = .
        if strpos("`stats'", "cstat") > 0 {
            capture quietly estat concordance
            if !_rc {
                local _cstat_`m' = r(C)
            }
            else {
                capture quietly lroc, nograph
                if !_rc & r(area) < . {
                    local _cstat_`m' = r(area)
                }
            }
        }

        * R-squared
        local _r2_`m' = .
        local _adjr2_`m' = .
        if strpos("`stats'", "r2") > 0 | strpos("`stats'", "adjr2") > 0 {
            capture local _r2_`m' = e(r2)
            if _rc capture local _r2_`m' = e(r2_p)
            capture local _adjr2_`m' = e(r2_a)
        }

        * RMSE
        local _rmse_`m' = .
        if strpos("`stats'", "rmse") > 0 {
            capture local _rmse_`m' = e(rmse)
        }

        * LR test against reference
        local _lrchi2_`m' = .
        local _lrp_`m' = .
        if "`lrtest'" != "" {
            capture quietly lrtest `lrtest' `_mname'
            if !_rc {
                local _lrchi2_`m' = r(chi2)
                local _lrp_`m' = r(p)
            }
            if _rc != 0 {
                noisily display as text "Note: LR test could not be computed for `_mname'"
            }
        }

        * Track best AIC/BIC/C-stat
        if !missing(`_aic_`m'') & `_aic_`m'' < `best_aic' local best_aic = `_aic_`m''
        if !missing(`_bic_`m'') & `_bic_`m'' < `best_bic' local best_bic = `_bic_`m''
        if !missing(`_cstat_`m'') & `_cstat_`m'' > `best_cstat' local best_cstat = `_cstat_`m''
    }

    if `_held_active' {
        _estimates unhold `_fittab_orig'
        local _held_active = 0
    }

    return scalar best_aic = `best_aic'
    return scalar best_bic = `best_bic'

**# Build Output Dataset
    preserve
    clear

    local out_ncols = 1 + `n_models'
    forvalues c = 1/`out_ncols' {
        qui gen str244 c`c' = ""
    }
    qui gen str244 title = ""

    * Row 1: Title
    local row 1
    qui set obs 1
    qui replace title = "`title'" in 1

    * Row 2: Model headers
    local row = `row' + 1
    qui set obs `row'
    qui replace c1 = "Statistic" in `row'
    forvalues m = 1/`n_models' {
        local _col = `m' + 1
        qui replace c`_col' = "`mlabel_`m''" in `row'
    }

    * Track best AIC/BIC/C-stat row/col for bold formatting
    local _aic_row = 0
    local _bic_row = 0
    local _cstat_row = 0
    local _best_aic_col = 0
    local _best_bic_col = 0
    local _best_cstat_col = 0

    * Statistics rows
    foreach stat of local stats {
        local row = `row' + 1
        qui set obs `row'

        if "`stat'" == "n" {
            qui replace c1 = "N" in `row'
            forvalues m = 1/`n_models' {
                local _col = `m' + 1
                qui replace c`_col' = string(`_n_`m'', "%11.0fc") in `row'
            }
        }
        else if "`stat'" == "aic" {
            qui replace c1 = "AIC" in `row'
            local _aic_row = `row'
            local _best_aic_col = 0
            forvalues m = 1/`n_models' {
                local _col = `m' + 1
                if !missing(`_aic_`m'') {
                    qui replace c`_col' = string(`_aic_`m'', "%12.1f") in `row'
                    if `_aic_`m'' == `best_aic' local _best_aic_col = `_col'
                }
            }
        }
        else if "`stat'" == "bic" {
            qui replace c1 = "BIC" in `row'
            local _bic_row = `row'
            local _best_bic_col = 0
            forvalues m = 1/`n_models' {
                local _col = `m' + 1
                if !missing(`_bic_`m'') {
                    qui replace c`_col' = string(`_bic_`m'', "%12.1f") in `row'
                    if `_bic_`m'' == `best_bic' local _best_bic_col = `_col'
                }
            }
        }
        else if "`stat'" == "ll" {
            qui replace c1 = "Log-likelihood" in `row'
            forvalues m = 1/`n_models' {
                local _col = `m' + 1
                if !missing(`_ll_`m'') {
                    qui replace c`_col' = string(`_ll_`m'', "%12.2f") in `row'
                }
            }
        }
        else if "`stat'" == "cstat" {
            qui replace c1 = "C-statistic" in `row'
            local _cstat_row = `row'
            local _best_cstat_col = 0
            forvalues m = 1/`n_models' {
                local _col = `m' + 1
                if !missing(`_cstat_`m'') {
                    qui replace c`_col' = string(`_cstat_`m'', "%6.4f") in `row'
                    if `_cstat_`m'' == `best_cstat' local _best_cstat_col = `_col'
                }
            }
        }
        else if "`stat'" == "r2" {
            qui replace c1 = "R-squared" in `row'
            forvalues m = 1/`n_models' {
                local _col = `m' + 1
                if !missing(`_r2_`m'') {
                    qui replace c`_col' = string(`_r2_`m'', "%6.4f") in `row'
                }
            }
        }
        else if "`stat'" == "adjr2" {
            qui replace c1 = "Adjusted R-squared" in `row'
            forvalues m = 1/`n_models' {
                local _col = `m' + 1
                if !missing(`_adjr2_`m'') {
                    qui replace c`_col' = string(`_adjr2_`m'', "%6.4f") in `row'
                }
            }
        }
        else if "`stat'" == "rmse" {
            qui replace c1 = "RMSE" in `row'
            forvalues m = 1/`n_models' {
                local _col = `m' + 1
                if !missing(`_rmse_`m'') {
                    qui replace c`_col' = string(`_rmse_`m'', "%9.3f") in `row'
                }
            }
        }
    }

    * LR test rows
    if "`lrtest'" != "" {
        local row = `row' + 1
        qui set obs `row'
        qui replace c1 = "LR test vs `lrtest'" in `row'

        local row = `row' + 1
        qui set obs `row'
        qui replace c1 = "  Chi2 (p-value)" in `row'
        forvalues m = 1/`n_models' {
            local _col = `m' + 1
            if !missing(`_lrchi2_`m'') {
                local _lrp_str = cond(`_lrp_`m'' < 0.001, "<0.001", string(`_lrp_`m'', "%5.3f"))
                qui replace c`_col' = string(`_lrchi2_`m'', "%6.2f") + " (" + "`_lrp_str'" + ")" in `row'
            }
        }
    }

    local num_rows = _N
    local num_cols = `out_ncols' + 1

    * Return matrix
    local n_stats : word count `stats'
    tempname _rtable
    matrix `_rtable' = J(`n_stats', `n_models', .)
    local _si 0
    foreach stat of local stats {
        local _si = `_si' + 1
        forvalues m = 1/`n_models' {
            if "`stat'" == "n" matrix `_rtable'[`_si', `m'] = `_n_`m''
            else if "`stat'" == "aic" capture matrix `_rtable'[`_si', `m'] = `_aic_`m''
            else if "`stat'" == "bic" capture matrix `_rtable'[`_si', `m'] = `_bic_`m''
            else if "`stat'" == "ll" capture matrix `_rtable'[`_si', `m'] = `_ll_`m''
            else if "`stat'" == "cstat" capture matrix `_rtable'[`_si', `m'] = `_cstat_`m''
            else if "`stat'" == "r2" capture matrix `_rtable'[`_si', `m'] = `_r2_`m''
            else if "`stat'" == "adjr2" capture matrix `_rtable'[`_si', `m'] = `_adjr2_`m''
            else if "`stat'" == "rmse" capture matrix `_rtable'[`_si', `m'] = `_rmse_`m''
        }
    }
    capture matrix rownames `_rtable' = `stats'

**# Console Display
    if !`_has_xlsx' | "`display'" != "" {
        noisily _tabtools_console_display `out_ncols' `"`title'"'
    }

**# CSV Export
    if "`csv'" != "" {
        export delimited using "`csv'", replace
    }

**# Frame Output
    if `"`frame'"' != "" {
        _tabtools_frame_put `"`frame'"'
        local frame "`_frame_name'"
    }

**# Excel Export
    if `_has_xlsx' {
        order title c*
        capture export excel using "`xlsx'", sheet("`sheet'") sheetreplace
        if _rc {
            local _export_rc = _rc
            noisily display as error "Failed to export to `xlsx'"
            noisily display as error "Hint: ensure the xlsx file is not open in another application"
            restore
            exit `_export_rc'
        }

        capture {
            putexcel set "`xlsx'", sheet("`sheet'") modify
            _tabtools_build_col_letters `num_cols'
            local letters "`result'"
            local lastcol : word `num_cols' of `letters'

            putexcel (A1:`lastcol'1), merge bold txtwrap left vcenter font("`_font'", `=`_fontsize'+2')
            putexcel (B2:`lastcol'2), border(top, `_hborder') bold hcenter font("`_font'", `_fontsize')
            putexcel (B2:`lastcol'2), border(bottom, `_hborder')
            putexcel (A3:`lastcol'`num_rows'), font("`_font'", `_fontsize')
            putexcel (C3:`lastcol'`num_rows'), hcenter
            putexcel (B`num_rows':`lastcol'`num_rows'), border(bottom, `_hborder')

            if "`zebra'" != "" {
                local _zebracolor "237 242 249"
                if "$TABTOOLS_ZEBRACOLOR" != "" local _zebracolor "$TABTOOLS_ZEBRACOLOR"
                forvalues _zr = 4(2)`num_rows' {
                    putexcel (B`_zr':`lastcol'`_zr'), fpattern(solid, "`_zebracolor'")
                }
            }

            * Bold the best AIC/BIC/C-stat cells
            if `_best_aic_col' > 0 {
                _tabtools_col_letter `_best_aic_col'
                local _aic_letter "`result'"
                putexcel `_aic_letter'`_aic_row', bold
            }
            if `_best_bic_col' > 0 {
                _tabtools_col_letter `_best_bic_col'
                local _bic_letter "`result'"
                putexcel `_bic_letter'`_bic_row', bold
            }
            if `_best_cstat_col' > 0 {
                _tabtools_col_letter `_best_cstat_col'
                local _cstat_letter "`result'"
                putexcel `_cstat_letter'`_cstat_row', bold
            }

            if `"`footnote'"' != "" {
                _tabtools_footnote `"`footnote'"' "`lastcol'" `num_rows' "`_font'" `_fontsize'
            }

            putexcel clear
        }
        if _rc {
            capture putexcel clear
            noisily display as error "Excel formatting failed"
        }
        noisily display as text "Exported to " as result `"`xlsx'"' as text ", sheet " as result `"`sheet'"'
    }

    if "`open'" != "" & `_has_xlsx' _tabtools_open_file "`xlsx'"

    restore

**# Return Results
    capture return matrix table = `_rtable'
    return scalar N_models = `n_models'
    if `_has_xlsx' {
        return local xlsx "`xlsx'"
        return local sheet "`sheet'"
    }
    if "`frame'" != "" return local frame "`frame'"

    local _methods "Model comparison was performed using information criteria."
    if strpos("`stats'", "aic") > 0 local _methods "`_methods' AIC (Akaike Information Criterion) and"
    if strpos("`stats'", "bic") > 0 local _methods "`_methods' BIC (Bayesian Information Criterion) are reported; lower values indicate better fit."
    local _methods "`_methods' Analysis performed in Stata `c(stata_version)' (StataCorp, College Station, TX)."
    return local methods "`_methods'"

} // end capture noisily
    local rc = _rc
    if `rc' & `_held_active' {
        capture _estimates unhold `_fittab_orig'
    }
    set varabbrev `_prev_varabbrev'
    if `rc' exit `rc'
end
