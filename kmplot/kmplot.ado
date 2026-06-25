*! kmplot Version 1.0.3  2026/06/25
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
        local _orig_varabbrev = c(varabbrev)
        set varabbrev off
        local _kmplot_preserved = 0
        local _kmplot_side_rc = 0
        capture noisily {

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
        noisily display as error "data not stset"
        noisily display as error ""
        noisily display as error "You must {bf:stset} your data before using kmplot."
        noisily display as error "Example:"
        noisily display as error "  {cmd:stset time, failure(event)}"
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
            quietly replace `touse' = 0 if `by' == ""
        }
    }
    quietly count if `touse'
    if r(N) == 0 {
        noisily display as error "no observations"
        exit 2000
    }
    local N = r(N)

    * Validate cistyle
    if "`cistyle'" != "" & !inlist("`cistyle'", "band", "line") {
        noisily display as error "cistyle() must be {bf:band} or {bf:line}"
        exit 198
    }

    * Validate citransform
    if "`citransform'" != "" & !inlist("`citransform'", "loglog", "log", "plain") {
        noisily display as error "citransform() must be {bf:loglog}, {bf:log}, or {bf:plain}"
        exit 198
    }

    * =========================================================================
    * SET DEFAULTS
    * =========================================================================

    if "`scheme'" == "" local scheme "`c(scheme)'"
    if "`cistyle'" == "" local cistyle "band"
    if "`citransform'" == "" local citransform "loglog"
    if "`lwidth'" == "" local lwidth "medthick"
    if "`pvaluepos'" == "" local pvaluepos "bottomright"
    if "`pvaluepos'" != "" & ///
        !inlist("`pvaluepos'", "topleft", "topright", "bottomleft", "bottomright") {
        noisily display as error "pvaluepos() must be {bf:topleft}, {bf:topright}, {bf:bottomleft}, or {bf:bottomright}"
        exit 198
    }
        if `censorthin' < 1 local censorthin = 1
        if `ciopacity' < 0 | `ciopacity' > 100 {
            noisily display as error "ciopacity() must be between 0 and 100"
            exit 198
        }

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
    * Strip outer quotes from string-asis options (asis preserves user quotes)
    foreach _ttl in xtitle ytitle title subtitle note {
        local _len = strlen(`"``_ttl''"')
        if `_len' >= 2 & ///
            substr(`"``_ttl''"', 1, 1) == char(34) & ///
            substr(`"``_ttl''"', `_len', 1) == char(34) {
            local `_ttl' = substr(`"``_ttl''"', 2, `_len' - 2)
        }
    }
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
            capture noisily quietly sts test `by' if `touse', logrank
            if _rc {
                display as text "(p-value computation failed; skipped)"
                local pvalue ""
            }
            else {
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
    }
    else if "`pvalue'" != "" & "`by'" == "" {
        display as text "(p-value requires by() variable; skipped)"
        local pvalue ""
    }

    * =========================================================================
    * PREPARE DATA
    * =========================================================================

        preserve
        local _kmplot_preserved = 1

        quietly keep if `touse'

        tempvar grpid km_s km_se km_lb km_ub km_tmp km_cens

        * Create numeric group ID
        if "`by'" != "" {
            tempvar _grpid_tmp
            quietly egen int `_grpid_tmp' = group(`by'), label
            quietly gen int `grpid' = `_grpid_tmp'
            quietly tab `grpid'
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
            quietly gen byte `grpid' = 1
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
            quietly sts generate `km_s' = s, by(`grpid')
            quietly sts generate `km_se' = se(s), by(`grpid')
        }
        else {
            quietly sts generate `km_s' = s
            quietly sts generate `km_se' = se(s)
        }

        * Handle all-censored groups (no events -> S = 1)
        forvalues g = 1/`ngroups' {
            quietly count if `grpid' == `g' & !missing(`km_s')
            if r(N) == 0 {
                quietly replace `km_s' = 1 if `grpid' == `g'
                quietly replace `km_se' = 0 if `grpid' == `g'
            }
        }

    * =========================================================================
    * CONFIDENCE INTERVALS
    * =========================================================================

        if "`ci'" != "" {
            quietly {
                gen double `km_lb' = .
                gen double `km_ub' = .

                if "`citransform'" == "loglog" {
                    * Log-log transformation (Stata default)
                    replace `km_lb' = exp(-exp(log(-log(`km_s')) + ///
                        invnormal(0.975) * `km_se' / ///
                        (`km_s' * abs(log(`km_s'))))) ///
                        if `km_s' > 0 & `km_s' < 1 & `km_se' > 0
                    replace `km_ub' = exp(-exp(log(-log(`km_s')) - ///
                        invnormal(0.975) * `km_se' / ///
                        (`km_s' * abs(log(`km_s'))))) ///
                        if `km_s' > 0 & `km_s' < 1 & `km_se' > 0
                }
                else if "`citransform'" == "log" {
                    replace `km_lb' = `km_s' * ///
                        exp(-invnormal(0.975) * `km_se' / `km_s') ///
                        if `km_s' > 0 & `km_se' > 0
                    replace `km_ub' = `km_s' * ///
                        exp(invnormal(0.975) * `km_se' / `km_s') ///
                        if `km_s' > 0 & `km_se' > 0
                }
                else {
                    * Plain (untransformed)
                    replace `km_lb' = `km_s' - invnormal(0.975) * `km_se'
                    replace `km_ub' = `km_s' + invnormal(0.975) * `km_se'
                }

                * Clamp to [0, 1]
                replace `km_lb' = 0 if `km_lb' < 0 & !missing(`km_lb')
                replace `km_ub' = 1 if `km_ub' > 1 & !missing(`km_ub')
            }
        }

    * =========================================================================
    * FAILURE MODE (invert S -> 1-S)
    * =========================================================================

        if "`failure'" != "" {
            quietly replace `km_s' = 1 - `km_s' if !missing(`km_s')
            if "`ci'" != "" {
                quietly {
                    gen double `km_tmp' = 1 - `km_lb'
                    replace `km_lb' = 1 - `km_ub'
                    replace `km_ub' = `km_tmp'
                    drop `km_tmp'
                }
            }
        }

    * =========================================================================
    * CENSOR MARKS
    * =========================================================================

        if "`censor'" != "" {
            quietly gen byte `km_cens' = (_d == 0 & !missing(`km_s'))
            if `censorthin' > 1 {
                tempvar _ccnt
                bysort `grpid' (_t) : gen int `_ccnt' = ///
                    sum(`km_cens') if `km_cens' == 1
                quietly replace `km_cens' = 0 ///
                    if `km_cens' == 1 & mod(`_ccnt', `censorthin') != 0
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

        * If the user supplies explicit x-axis positions with risktable(),
        * use them as the default risk-table timepoints so counts and labels align.
        if "`timepoints'" == "" & `"`xlabel'"' != "" {
            local _rt_posspec `"`xlabel'"'
            local _comma = strpos(`"`_rt_posspec'"', ",")
            if `_comma' > 0 {
                local _rt_posspec = strtrim(substr(`"`_rt_posspec'"', 1, `_comma' - 1))
            }
            capture numlist `"`_rt_posspec'"', sort
            if _rc == 0 {
                local timepoints `r(numlist)'
            }
        }

        local tp_opt ""
        if "`timepoints'" != "" {
            local tp_opt "timepoints(`timepoints')"
        }
        local rt_xtitle_opt ""
        if `"`xtitle'"' != "" {
            local rt_xtitle_opt xtitle("`xtitle'")
        }
        local rt_xlabel_opt ""
        if `"`xlabel'"' != "" {
            local rt_xlabel_opt xlabel(`xlabel')
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

            _kmplot_risktable, grpvar(`grpid') ngroups(`ngroups') ///
                colors(`colors') scheme(`scheme') xmax(`tmax') `tp_opt' ///
                `rt_xtitle_opt' `rt_xlabel_opt' `rt_flags'
        }

    * =========================================================================
    * ADD TIME-ZERO ANCHORS
    * =========================================================================

    local N_cur = _N
    quietly set obs `=`N_cur' + `ngroups''

        forvalues g = 1/`ngroups' {
            local row = `N_cur' + `g'
            quietly replace `grpid' = `g' in `row'
            quietly replace _t = 0 in `row'
            if "`failure'" != "" {
                quietly replace `km_s' = 0 in `row'
            }
            else {
                quietly replace `km_s' = 1 in `row'
            }
            if "`ci'" != "" {
                if "`failure'" != "" {
                    quietly replace `km_lb' = 0 in `row'
                    quietly replace `km_ub' = 0 in `row'
                }
                else {
                    quietly replace `km_lb' = 1 in `row'
                    quietly replace `km_ub' = 1 in `row'
                }
            }
            if "`censor'" != "" {
                quietly replace `km_cens' = 0 in `row'
            }
        }

        sort `grpid' _t

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
                    quietly summarize _t if `grpid' == `g' & ///
                        `km_s' >= 0.5 & !missing(`km_s') & _t > 0
                }
                else {
                    * Survival: first time where S(t) <= 0.5
                    quietly summarize _t if `grpid' == `g' & ///
                        `km_s' <= 0.5 & !missing(`km_s') & _t > 0
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
                if "`col'" == "" local col "black"
                local tw_layers `"`tw_layers' (rarea `km_ub' `km_lb' _t if `grpid' == `g' & !missing(`km_lb'), fcolor(`col'%`ciopacity') lwidth(none) sort)"'
            }
            local legend_offset = `ngroups'
        }

    * --- KM step lines ---
    forvalues g = 1/`ngroups' {
        local colidx = mod(`g' - 1, 8) + 1
        local col : word `colidx' of `colors'
        if "`col'" == "" local col "black"
        local npatterns : word count `lpattern'
        if `npatterns' > 0 {
            local patidx = mod(`g' - 1, `npatterns') + 1
            local pat : word `patidx' of `lpattern'
        }
        else {
            local pat "solid"
        }
            local tw_layers `"`tw_layers' (line `km_s' _t if `grpid' == `g' & !missing(`km_s'), lcolor(`col') lwidth(`lwidth') lpattern(`pat') sort connect(J))"'
        }

    * --- CI lines (alternative to bands) ---
    if "`ci'" != "" & "`cistyle'" == "line" {
        forvalues g = 1/`ngroups' {
                local colidx = mod(`g' - 1, 8) + 1
                local col : word `colidx' of `colors'
                if "`col'" == "" local col "black"
                local tw_layers `"`tw_layers' (line `km_lb' _t if `grpid' == `g' & !missing(`km_lb'), lcolor(`col') lwidth(thin) lpattern(dash) sort connect(J))"'
                local tw_layers `"`tw_layers' (line `km_ub' _t if `grpid' == `g' & !missing(`km_ub'), lcolor(`col') lwidth(thin) lpattern(dash) sort connect(J))"'
            }
        }

    * --- Censor marks ---
    if "`censor'" != "" {
        forvalues g = 1/`ngroups' {
                local colidx = mod(`g' - 1, 8) + 1
                local col : word `colidx' of `colors'
                if "`col'" == "" local col "black"
                local tw_layers `"`tw_layers' (scatter `km_s' _t if `grpid' == `g' & `km_cens' == 1, msymbol(pipe) mcolor(`col') msize(medsmall))"'
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
                if "`col'" == "" local col "black"
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
            * topright (fallthrough)
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
            local _kmplot_drop_main_rc = _rc
            capture graph drop _kmplot_risktable
            local _kmplot_drop_risktable_rc = _rc
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
        local _ef_len = strlen(`"`export_file'"')
            if `_ef_len' >= 2 & ///
                substr(`"`export_file'"', 1, 1) == char(34) & ///
                substr(`"`export_file'"', `_ef_len', 1) == char(34) {
                local export_file = substr(`"`export_file'"', 2, `_ef_len' - 2)
            }
            foreach _bad_ascii in 34 36 38 39 59 60 62 96 124 {
                if strpos(`"`export_file'"', char(`_bad_ascii')) {
                    noisily display as error "export() path contains unsupported shell metacharacters or quote characters"
                    exit 198
                }
            }
            capture noisily graph export `"`export_file'"', `export_opts'
            local _kmplot_side_rc = _rc
            if `_kmplot_side_rc' == 0 {
                capture confirm file `"`export_file'"'
            }
            if `_kmplot_side_rc' == 0 & _rc == 0 {
                display as text "Graph saved to: " as result `"`export_file'"'
            }
        }

    * =========================================================================
    * DISPLAY SUMMARY
    * =========================================================================

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

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

        restore
        local _kmplot_preserved = 0

        } // end capture noisily
        local rc = _rc
        if `_kmplot_preserved' {
            capture restore
        }
        set varabbrev `_orig_varabbrev'
        if `rc' exit `rc'

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
        if `_kmplot_side_rc' exit `_kmplot_side_rc'
end
