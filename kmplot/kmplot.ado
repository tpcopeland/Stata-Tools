*! kmplot Version 1.1.0  2026/03/15
*! Publication-ready Kaplan-Meier and cumulative incidence plots
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  kmplot [if] [in] , [by(varname) failure ci risktable median censor
                       pvalue export(string) options]

Description:
  One-command publication-quality Kaplan-Meier survival curves with confidence
  bands, risk tables, median lines, censoring marks, and log-rank p-values.

Requires: Data must be stset

See help kmplot for complete documentation
*/

program define kmplot, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    syntax [if] [in] , [BY(varname) FAILure ///
        CI CIStyle(string) CIOpacity(integer 12) CITRansform(string) ///
        MEDian MEDIANAnnotate ///
        RISKtable RISKEVents RISKCOMpact RISKMono TIMEpoints(numlist sort) ///
        CENsor CENSORThin(integer 1) ///
        PVALue PVALUEPOs(string) ///
        COLors(string asis) LWidth(string) LPattern(string asis) ///
        TItle(string asis) SUBtitle(string asis) ///
        XTItle(string asis) YTItle(string asis) ///
        XLAbel(string asis) YLAbel(string asis) ///
        LEGend(string asis) NOTE(string asis) ///
        SCHeme(string) NAME(string asis) ASPectratio(string) ///
        EXPort(string asis) *]

    * =========================================================================
    * VALIDATE PREREQUISITES
    * =========================================================================

    capture st_is 2 analysis
    if _rc {
        display as error "data not stset"
        display as error ""
        display as error "You must {bf:stset} your data before using kmplot."
        display as error "Example:"
        display as error "  {cmd:stset time, failure(event)}"
        set varabbrev `_vaset'
        exit 119
    }

    marksample touse, novarlist
    quietly replace `touse' = 0 if _st != 1
    if "`by'" != "" {
        capture confirm numeric variable `by'
        if _rc == 0 {
            markout `touse' `by'
        }
        else {
            * String variable: exclude empty strings
            quietly replace `touse' = 0 if `by' == ""
        }
    }
    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        set varabbrev `_vaset'
        exit 2000
    }
    local N = r(N)

    * Validate cistyle
    if "`cistyle'" != "" & !inlist("`cistyle'", "band", "line") {
        display as error "cistyle() must be {bf:band} or {bf:line}"
        set varabbrev `_vaset'
        exit 198
    }

    * Validate citransform
    if "`citransform'" != "" & !inlist("`citransform'", "loglog", "log", "plain") {
        display as error "citransform() must be {bf:loglog}, {bf:log}, or {bf:plain}"
        set varabbrev `_vaset'
        exit 198
    }

    * =========================================================================
    * SET DEFAULTS
    * =========================================================================

    if "`scheme'" == "" local scheme "plotplainblind"
    if "`cistyle'" == "" local cistyle "band"
    if "`citransform'" == "" local citransform "loglog"
    if "`lwidth'" == "" local lwidth "medthick"
    if "`pvaluepos'" == "" local pvaluepos "bottomright"
    if `censorthin' < 1 local censorthin = 1

    if `"`colors'"' == "" {
        local colors "navy cranberry forest_green dkorange purple teal maroon olive_teal"
    }
    if `"`ytitle'"' == "" {
        if "`failure'" != "" {
            local ytitle "Cumulative incidence"
        }
        else {
            local ytitle "Survival probability"
        }
    }
    if `"`xtitle'"' == "" local xtitle "Analysis time"
    * Parse name option (handle "name, replace" syntax)
    if `"`name'"' == "" {
        local name "kmplot"
    }
    else {
        local cpos = strpos(`"`name'"', ",")
        if `cpos' > 0 {
            local name = strtrim(substr(`"`name'"', 1, `cpos' - 1))
        }
    }

    * =========================================================================
    * COMPUTE P-VALUE (before preserve)
    * =========================================================================

    local pval = .
    local pval_text ""
    if "`pvalue'" != "" & "`by'" != "" {
        quietly tab `by' if `touse'
        if r(r) < 2 {
            display as text "(p-value skipped: only one group in sample)"
            local pvalue ""
        }
        else {
            quietly sts test `by' if `touse', logrank
            local pval = chi2tail(r(df), r(chi2))
            if `pval' < 0.001 {
                local pval_text "Log-rank p < 0.001"
            }
            else {
                local pval_text : display "Log-rank p = " %5.3f `pval'
                local pval_text = strtrim("`pval_text'")
            }
        }
    }
    else if "`pvalue'" != "" & "`by'" == "" {
        display as text "(p-value requires by() variable; skipped)"
        local pvalue ""
    }

    * =========================================================================
    * PREPARE DATA
    * =========================================================================

    preserve
    local _rc_final = 0

    capture noisily {

    quietly keep if `touse'

    * Create numeric group ID
    if "`by'" != "" {
        tempvar _grpid_tmp
        quietly egen int `_grpid_tmp' = group(`by'), label
        quietly gen int _kmplot_grpid = `_grpid_tmp'
        quietly tab _kmplot_grpid
        local ngroups = r(r)

        * Get group labels
        local bylbl : value label `by'
        quietly levelsof `by', local(bylevels)
        local g = 0
        foreach lev of local bylevels {
            local ++g
            if "`bylbl'" != "" {
                local grplbl`g' : label `bylbl' `lev'
            }
            else {
                capture confirm numeric variable `by'
                if _rc == 0 {
                    local grplbl`g' "`by'=`lev'"
                }
                else {
                    local grplbl`g' "`lev'"
                }
            }
        }
    }
    else {
        quietly gen byte _kmplot_grpid = 1
        local ngroups = 1
        local grplbl1 "KM estimate"
    }

    * Skip p-value for single group
    if `ngroups' == 1 & "`pvalue'" != "" {
        display as text "(p-value skipped: only one group)"
        local pvalue ""
        local pval_text ""
    }

    * Time range
    quietly summarize _t
    local tmax = r(max)

    * =========================================================================
    * GENERATE KM ESTIMATES
    * =========================================================================

    if `ngroups' > 1 {
        quietly sts generate _kmplot_s = s, by(_kmplot_grpid)
        quietly sts generate _kmplot_se = se(s), by(_kmplot_grpid)
    }
    else {
        quietly sts generate _kmplot_s = s
        quietly sts generate _kmplot_se = se(s)
    }

    * Handle all-censored groups (no events -> S = 1)
    forvalues g = 1/`ngroups' {
        quietly count if _kmplot_grpid == `g' & !missing(_kmplot_s)
        if r(N) == 0 {
            quietly replace _kmplot_s = 1 if _kmplot_grpid == `g'
            quietly replace _kmplot_se = 0 if _kmplot_grpid == `g'
        }
    }

    * =========================================================================
    * CONFIDENCE INTERVALS
    * =========================================================================

    if "`ci'" != "" {
        quietly {
            gen double _kmplot_lb = .
            gen double _kmplot_ub = .

            if "`citransform'" == "loglog" {
                * Log-log transformation (Stata default)
                replace _kmplot_lb = exp(-exp(log(-log(_kmplot_s)) + ///
                    invnormal(0.975) * _kmplot_se / ///
                    (_kmplot_s * abs(log(_kmplot_s))))) ///
                    if _kmplot_s > 0 & _kmplot_s < 1 & _kmplot_se > 0
                replace _kmplot_ub = exp(-exp(log(-log(_kmplot_s)) - ///
                    invnormal(0.975) * _kmplot_se / ///
                    (_kmplot_s * abs(log(_kmplot_s))))) ///
                    if _kmplot_s > 0 & _kmplot_s < 1 & _kmplot_se > 0
            }
            else if "`citransform'" == "log" {
                replace _kmplot_lb = _kmplot_s * ///
                    exp(-invnormal(0.975) * _kmplot_se / _kmplot_s) ///
                    if _kmplot_s > 0 & _kmplot_se > 0
                replace _kmplot_ub = _kmplot_s * ///
                    exp(invnormal(0.975) * _kmplot_se / _kmplot_s) ///
                    if _kmplot_s > 0 & _kmplot_se > 0
            }
            else {
                * Plain (untransformed)
                replace _kmplot_lb = _kmplot_s - invnormal(0.975) * _kmplot_se
                replace _kmplot_ub = _kmplot_s + invnormal(0.975) * _kmplot_se
            }

            * Clamp to [0, 1]
            replace _kmplot_lb = 0 if _kmplot_lb < 0 & !missing(_kmplot_lb)
            replace _kmplot_ub = 1 if _kmplot_ub > 1 & !missing(_kmplot_ub)
        }
    }

    * =========================================================================
    * FAILURE MODE (invert S -> 1-S)
    * =========================================================================

    if "`failure'" != "" {
        quietly replace _kmplot_s = 1 - _kmplot_s if !missing(_kmplot_s)
        if "`ci'" != "" {
            quietly {
                gen double _kmplot_tmp = 1 - _kmplot_lb
                replace _kmplot_lb = 1 - _kmplot_ub
                replace _kmplot_ub = _kmplot_tmp
                drop _kmplot_tmp
            }
        }
    }

    * =========================================================================
    * CENSOR MARKS
    * =========================================================================

    if "`censor'" != "" {
        quietly gen byte _kmplot_cens = (_d == 0 & !missing(_kmplot_s))
        if `censorthin' > 1 {
            tempvar _ccnt
            bysort _kmplot_grpid (_t) : gen int `_ccnt' = ///
                sum(_kmplot_cens) if _kmplot_cens == 1
            quietly replace _kmplot_cens = 0 ///
                if _kmplot_cens == 1 & mod(`_ccnt', `censorthin') != 0
        }
    }

    * =========================================================================
    * RISK TABLE (compute before adding anchors)
    * =========================================================================

    if "`risktable'" != "" {
        * Store group labels in dataset characteristics
        forvalues g = 1/`ngroups' {
            char _dta[_kmplot_grplbl`g'] `"`grplbl`g''"'
        }

        local tp_opt ""
        if "`timepoints'" != "" {
            local tp_opt "timepoints(`timepoints')"
        }

        * Load helper if needed
        capture program list _kmplot_risktable
        if _rc {
            capture findfile _kmplot_risktable.ado
            if _rc == 0 {
                run "`r(fn)'"
            }
            else {
                display as error "_kmplot_risktable.ado not found; reinstall kmplot"
                exit 111
            }
        }

        * riskcompact is a synonym for riskevents
        local rt_flags ""
        if "`riskcompact'" != "" | "`riskevents'" != "" {
            local rt_flags "`rt_flags' events"
        }
        if "`riskmono'" != "" local rt_flags "`rt_flags' mono"

        _kmplot_risktable, grpvar(_kmplot_grpid) ngroups(`ngroups') ///
            colors(`colors') scheme(`scheme') xmax(`tmax') `tp_opt' `rt_flags'
    }

    * =========================================================================
    * ADD TIME-ZERO ANCHORS
    * =========================================================================

    local N_cur = _N
    quietly set obs `=`N_cur' + `ngroups''

    forvalues g = 1/`ngroups' {
        local row = `N_cur' + `g'
        quietly replace _kmplot_grpid = `g' in `row'
        quietly replace _t = 0 in `row'
        if "`failure'" != "" {
            quietly replace _kmplot_s = 0 in `row'
        }
        else {
            quietly replace _kmplot_s = 1 in `row'
        }
        if "`ci'" != "" {
            if "`failure'" != "" {
                quietly replace _kmplot_lb = 0 in `row'
                quietly replace _kmplot_ub = 0 in `row'
            }
            else {
                quietly replace _kmplot_lb = 1 in `row'
                quietly replace _kmplot_ub = 1 in `row'
            }
        }
        if "`censor'" != "" {
            quietly replace _kmplot_cens = 0 in `row'
        }
    }

    sort _kmplot_grpid _t

    * =========================================================================
    * COMPUTE MEDIANS
    * =========================================================================

    forvalues g = 1/`ngroups' {
        local median_`g' = .
    }

    if "`median'" != "" {
        forvalues g = 1/`ngroups' {
            if "`failure'" != "" {
                * CIF: first time where F(t) >= 0.5
                quietly summarize _t if _kmplot_grpid == `g' & ///
                    _kmplot_s >= 0.5 & !missing(_kmplot_s) & _t > 0
            }
            else {
                * Survival: first time where S(t) <= 0.5
                quietly summarize _t if _kmplot_grpid == `g' & ///
                    _kmplot_s <= 0.5 & !missing(_kmplot_s) & _t > 0
            }
            if r(N) > 0 {
                local median_`g' = r(min)
            }
        }
    }

    * Median annotation note
    local med_note ""
    if "`median'" != "" & "`medianannotate'" != "" {
        forvalues g = 1/`ngroups' {
            if `median_`g'' < . {
                local mfmt : display %6.1f `median_`g''
                local mfmt = strtrim("`mfmt'")
                if `ngroups' > 1 {
                    local med_note "`med_note'`grplbl`g'': `mfmt'  "
                }
                else {
                    local med_note "Median: `mfmt'"
                }
            }
            else {
                if `ngroups' > 1 {
                    local med_note "`med_note'`grplbl`g'': NR  "
                }
                else {
                    local med_note "Median: NR"
                }
            }
        }
    }

    * =========================================================================
    * BUILD TWOWAY COMMAND
    * =========================================================================

    local tw_layers ""
    local legend_offset = 0

    * --- CI bands (behind everything) ---
    if "`ci'" != "" & "`cistyle'" == "band" {
        forvalues g = 1/`ngroups' {
            local colidx = mod(`g' - 1, 8) + 1
            local col : word `colidx' of `colors'
            local tw_layers `"`tw_layers' (rarea _kmplot_ub _kmplot_lb _t if _kmplot_grpid == `g' & !missing(_kmplot_lb), fcolor(`col'%`ciopacity') lwidth(none) sort)"'
        }
        local legend_offset = `ngroups'
    }

    * --- KM step lines ---
    forvalues g = 1/`ngroups' {
        local colidx = mod(`g' - 1, 8) + 1
        local col : word `colidx' of `colors'
        local npatterns : word count `lpattern'
        if `npatterns' > 0 {
            local patidx = mod(`g' - 1, `npatterns') + 1
            local pat : word `patidx' of `lpattern'
        }
        else {
            local pat "solid"
        }
        local tw_layers `"`tw_layers' (line _kmplot_s _t if _kmplot_grpid == `g' & !missing(_kmplot_s), lcolor(`col') lwidth(`lwidth') lpattern(`pat') sort connect(J))"'
    }

    * --- CI lines (alternative to bands) ---
    if "`ci'" != "" & "`cistyle'" == "line" {
        forvalues g = 1/`ngroups' {
            local colidx = mod(`g' - 1, 8) + 1
            local col : word `colidx' of `colors'
            local tw_layers `"`tw_layers' (line _kmplot_lb _t if _kmplot_grpid == `g' & !missing(_kmplot_lb), lcolor(`col') lwidth(thin) lpattern(dash) sort connect(J))"'
            local tw_layers `"`tw_layers' (line _kmplot_ub _t if _kmplot_grpid == `g' & !missing(_kmplot_ub), lcolor(`col') lwidth(thin) lpattern(dash) sort connect(J))"'
        }
    }

    * --- Censor marks ---
    if "`censor'" != "" {
        forvalues g = 1/`ngroups' {
            local colidx = mod(`g' - 1, 8) + 1
            local col : word `colidx' of `colors'
            local tw_layers `"`tw_layers' (scatter _kmplot_s _t if _kmplot_grpid == `g' & _kmplot_cens == 1, msymbol(pipe) mcolor(`col') msize(medsmall))"'
        }
    }

    * --- Median reference lines ---
    if "`median'" != "" {
        * Single subtle horizontal reference at y=0.5
        local any_med = 0
        local max_med = 0
        forvalues g = 1/`ngroups' {
            if `median_`g'' < . {
                local any_med = 1
                if `median_`g'' > `max_med' local max_med = `median_`g''
            }
        }
        if `any_med' {
            * Thin horizontal line from x=0 to just past the rightmost median
            local tw_layers `"`tw_layers' (pci 0.5 0 0.5 `=`max_med' * 1.05', lcolor(gs12) lpattern(shortdash) lwidth(vthin))"'
        }
        * Short vertical drop at each group's median
        forvalues g = 1/`ngroups' {
            if `median_`g'' < . {
                local colidx = mod(`g' - 1, 8) + 1
                local col : word `colidx' of `colors'
                local tw_layers `"`tw_layers' (pci 0 `median_`g'' 0.5 `median_`g'', lcolor(`col') lpattern(shortdash) lwidth(vthin))"'
            }
        }
    }

    * --- Legend ---
    if `ngroups' == 1 & `"`legend'"' == "" {
        local legend_cmd "legend(off)"
    }
    else if `"`legend'"' != "" {
        local legend_cmd `"legend(`legend')"'
    }
    else {
        local legend_items ""
        forvalues g = 1/`ngroups' {
            local elem = `legend_offset' + `g'
            local legend_items `"`legend_items' `elem' `"`grplbl`g''"'"'
        }
        local legend_cmd `"legend(order(`legend_items') cols(1) position(1) ring(0) size(vsmall) region(lcolor(none) fcolor(none)) symxsize(8) keygap(1))"'
    }

    * --- Global options ---
    local tw_opts ""

    if `"`title'"' != "" {
        local tw_opts `"`tw_opts' title(`title', size(medium))"'
    }
    if `"`subtitle'"' != "" {
        local tw_opts `"`tw_opts' subtitle(`subtitle', size(small))"'
    }
    local tw_opts `"`tw_opts' xtitle(`"`xtitle'"', size(small)) ytitle(`"`ytitle'"', size(small))"'

    if `"`ylabel'"' != "" {
        local tw_opts `"`tw_opts' ylabel(`ylabel')"'
    }
    else {
        local tw_opts `"`tw_opts' ylabel(0(0.25)1, format(%4.2f) angle(0) nogrid)"'
    }

    if `"`xlabel'"' != "" {
        local tw_opts `"`tw_opts' xlabel(`xlabel')"'
    }

    * Note
    if `"`note'"' != "" {
        local tw_opts `"`tw_opts' note(`"`note'"', size(vsmall))"'
    }
    else if "`med_note'" != "" & "`risktable'" == "" {
        * Only show median note when no risktable (avoids clutter between graphs)
        local tw_opts `"`tw_opts' note(`"`med_note'"', size(vsmall) color(gs5))"'
    }

    * P-value text annotation
    if "`pval_text'" != "" {
        if "`pvaluepos'" == "topleft" {
            local p_y = 0.95
            local p_x = `tmax' * 0.05
            local p_place "e"
        }
        else if "`pvaluepos'" == "bottomleft" {
            local p_y = 0.05
            local p_x = `tmax' * 0.05
            local p_place "ne"
        }
        else if "`pvaluepos'" == "bottomright" {
            local p_y = 0.02
            local p_x = `tmax' * 0.98
            local p_place "sw"
        }
        else {
            * topright (default)
            local p_y = 0.95
            local p_x = `tmax' * 0.95
            local p_place "w"
        }
        local tw_opts `"`tw_opts' text(`p_y' `p_x' `"`pval_text'"', placement(`p_place') size(vsmall) color(gs5))"'
    }

    if "`aspectratio'" != "" {
        local tw_opts `"`tw_opts' aspectratio(`aspectratio')"'
    }

    local tw_opts `"`tw_opts' scheme(`scheme') `legend_cmd'"'

    * Passthrough options
    if `"`options'"' != "" {
        local tw_opts `"`tw_opts' `options'"'
    }

    * =========================================================================
    * EXECUTE PLOT
    * =========================================================================

    if "`risktable'" != "" {
        * When combining with risk table: suppress xlabel/xtitle on main plot
        local rt_main_opts "xtitle("") xlabel(, nolabels noticks)"
        twoway `tw_layers', `tw_opts' `rt_main_opts' ///
            nodraw name(_kmplot_main, replace)

        graph combine _kmplot_main _kmplot_risktable, ///
            cols(1) xcommon ///
            imargin(0 0 0 0) ///
            name(`name', replace) ///
            scheme(`scheme') note("")

        capture graph drop _kmplot_main
        capture graph drop _kmplot_risktable
    }
    else {
        twoway `tw_layers', `tw_opts' name(`name', replace)
    }

    * =========================================================================
    * EXPORT
    * =========================================================================

    if `"`export'"' != "" {
        local export_file `"`export'"'
        local export_opts ""
        local cpos = strpos(`"`export'"', ",")
        if `cpos' > 0 {
            local export_file = strtrim(substr(`"`export'"', 1, `cpos' - 1))
            local export_opts = strtrim(substr(`"`export'"', `cpos' + 1, .))
        }
        graph export `"`export_file'"', `export_opts'
        display as text "Graph saved to: " as result `"`export_file'"'
    }

    * =========================================================================
    * DISPLAY SUMMARY
    * =========================================================================

    display as text ""
    display as text "Kaplan-Meier plot"
    display as text "  Observations: " as result `N'
    display as text "  Groups:       " as result `ngroups'
    if "`ci'" != "" {
        display as text "  CI transform: " as result "`citransform'"
    }
    if "`pval_text'" != "" {
        display as text "  `pval_text'"
    }
    if "`median'" != "" {
        forvalues g = 1/`ngroups' {
            if `median_`g'' < . {
                local mfmt : display %6.1f `median_`g''
                local mfmt = strtrim("`mfmt'")
                display as text "  Median (`grplbl`g''): " as result "`mfmt'"
            }
            else {
                display as text "  Median (`grplbl`g''): " as result "NR"
            }
        }
    }

    } // end capture noisily

    local _rc_final = _rc
    restore

    if `_rc_final' {
        set varabbrev `_vaset'
        exit `_rc_final'
    }

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return scalar N = `N'
    return scalar n_groups = `ngroups'
    if "`pvalue'" != "" {
        return scalar p = `pval'
    }
    forvalues g = 1/`ngroups' {
        if `median_`g'' < . {
            return scalar median_`g' = `median_`g''
        }
    }
    return local cmd "kmplot"
    return local scheme "`scheme'"
    if "`by'" != "" {
        return local by "`by'"
    }

    set varabbrev `_vaset'
end
