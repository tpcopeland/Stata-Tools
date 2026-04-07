*! spaghetti Version 1.0.0  2026/04/08
*! Longitudinal trajectory visualization with group mean overlays
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass
*! Requires: Stata 16.0+

program define spaghetti, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    set varabbrev off
    set more off

    capture noisily {

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax varlist(numeric min=1 max=1) [if] [in] , ///
        ID(varname) TIME(varname numeric) ///
        [BY(varname) MEAN(string asis) ///
         SAMPle(integer 0) SEED(integer -1) ///
         HIGHlight(string asis) COLORby(string asis) ///
         REFline(string asis) EXPort(string asis) ///
         COLors(string) INDividual(string asis) ///
         TItle(string asis) SUBtitle(string asis) NOTE(string asis) ///
         NAME(string) SAVing(string asis) SCHeme(string) ///
         PLOTRegion(string asis) GRAPHRegion(string asis) ///
         YTItle(string asis) XTItle(string asis) *]

    local outcome "`varlist'"

    * =========================================================================
    * MARK SAMPLE
    * =========================================================================
    marksample touse
    markout `touse' `id' `time'
    if "`by'" != "" markout `touse' `by'

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    * =========================================================================
    * VALIDATE INPUTS
    * =========================================================================

    * Count by-groups and get labels
    local n_groups = 1
    if "`by'" != "" {
        quietly levelsof `by' if `touse', local(bylevels)
        local n_groups : word count `bylevels'

        if `n_groups' > 8 {
            display as error "by() has `n_groups' levels; maximum is 8"
            exit 198
        }

        * Get labels from value label or raw levels
        capture confirm numeric variable `by'
        local _by_is_numeric = (_rc == 0)
        local bylabel : value label `by'
        forvalues g = 1/`n_groups' {
            local gval : word `g' of `bylevels'
            if "`bylabel'" != "" & `_by_is_numeric' {
                local glabel`g' : label `bylabel' `gval'
            }
            else {
                local glabel`g' "`gval'"
            }
        }
    }

    * Mutual exclusion
    if `"`colorby'"' != "" & "`by'" != "" {
        display as error "colorby() and by() cannot be used together"
        exit 198
    }
    if `"`colorby'"' != "" & `"`highlight'"' != "" {
        display as error "colorby() and highlight() cannot be used together"
        exit 198
    }

    * =========================================================================
    * AUTO-LOAD HELPERS
    * =========================================================================
    capture program list _spaghetti_sample
    if _rc {
        capture findfile _spaghetti_sample.ado
        if _rc == 0 {
            quietly run "`r(fn)'"
        }
        else {
            display as error ///
                "_spaghetti_sample.ado not found; reinstall spaghetti"
            exit 111
        }
    }

    capture program list _spaghetti_mean
    if _rc {
        capture findfile _spaghetti_mean.ado
        if _rc == 0 {
            quietly run "`r(fn)'"
        }
        else {
            display as error ///
                "_spaghetti_mean.ado not found; reinstall spaghetti"
            exit 111
        }
    }

    * =========================================================================
    * PARSE SUB-OPTIONS
    * =========================================================================

    * --- mean() sub-options ---
    local has_mean 0
    local mean_bold 0
    local mean_ci 0
    local mean_smooth ""
    if `"`mean'"' != "" {
        local has_mean 1
        local _mean_lc = " " + lower(`"`mean'"') + " "
        if strpos("`_mean_lc'", " bold ") local mean_bold 1
        if strpos("`_mean_lc'", " ci ") local mean_ci 1
        if regexm(`"`_mean_lc'"', "smooth\(([a-z]+)\)") {
            local mean_smooth = regexs(1)
            if !inlist("`mean_smooth'", "lowess", "linear") {
                display as error ///
                    "mean(smooth()) must be lowess or linear"
                exit 198
            }
        }
    }

    * --- individual() sub-options ---
    local ind_color "gs12"
    local ind_opacity 25
    local ind_lwidth "vthin"
    if `"`individual'"' != "" {
        local _ind_lc = lower(`"`individual'"')
        if regexm("`_ind_lc'", "color\(([a-z0-9_]+)\)") {
            local ind_color = regexs(1)
        }
        if regexm("`_ind_lc'", "opacity\(([0-9]+)\)") {
            local ind_opacity = regexs(1)
        }
        if regexm("`_ind_lc'", "lwidth\(([a-z]+)\)") {
            local ind_lwidth = regexs(1)
        }
    }

    * --- colorby() sub-options ---
    local cb_var ""
    local cb_categorical 0
    if `"`colorby'"' != "" {
        gettoken cb_var cb_rest : colorby, parse(",")
        local cb_var = strtrim("`cb_var'")
        confirm variable `cb_var'
        if strpos(lower("`cb_rest'"), "categorical") local cb_categorical 1
        * Non-categorical colorby requires numeric variable
        capture confirm numeric variable `cb_var'
        if _rc != 0 & !`cb_categorical' {
            display as error ///
                "colorby() variable `cb_var' is string;" ///
                " use colorby(`cb_var', categorical)"
            exit 109
        }
        * Exclude observations with missing colorby values
        if _rc == 0 {
            markout `touse' `cb_var'
        }
        else {
            quietly replace `touse' = 0 if missing(`cb_var')
        }
        quietly count if `touse'
        if r(N) == 0 {
            display as error "no observations after excluding" ///
                " missing values in colorby() variable"
            exit 2000
        }
        local N = r(N)
    }

    * --- refline() sub-options ---
    local has_refline 0
    local ref_val ""
    local ref_label ""
    local ref_style "dash"
    if `"`refline'"' != "" {
        local has_refline 1
        gettoken ref_val ref_rest : refline, parse(",")
        local ref_val = strtrim("`ref_val'")
        confirm number `ref_val'
        if regexm(`"`ref_rest'"', `"label\("([^"]+)"\)"') {
            local ref_label = regexs(1)
        }
        if regexm(lower(`"`ref_rest'"'), "style\(([a-z]+)\)") {
            local ref_style = regexs(1)
        }
    }

    * --- export() sub-options ---
    local has_export 0
    local exp_file ""
    local exp_replace ""
    if `"`export'"' != "" {
        local has_export 1
        gettoken exp_file exp_rest : export, parse(",")
        local exp_file = strtrim(`"`exp_file'"')
        if strpos("`exp_rest'", "replace") local exp_replace "replace"
    }

    * =========================================================================
    * SET DEFAULTS
    * =========================================================================
    if "`scheme'" == "" local scheme "plotplainblind"

    * Color palette
    if "`colors'" != "" {
        local palette "`colors'"
    }
    else {
        local palette ///
            "navy cranberry forest_green dkorange purple teal maroon olive_teal"
    }

    * Validate palette has enough colors for by-groups
    if "`by'" != "" {
        local _palette_size : word count `palette'
        if `n_groups' > `_palette_size' {
            display as error "by() has `n_groups' levels" ///
                " but colors() has only `_palette_size' colors;" ///
                " specify colors() with at least `n_groups' colors"
            exit 198
        }
    }

    * Axis title defaults
    if `"`ytitle'"' == "" {
        local ytitle : variable label `outcome'
        if `"`ytitle'"' == "" local ytitle "`outcome'"
    }
    if `"`xtitle'"' == "" {
        local xtitle : variable label `time'
        if `"`xtitle'"' == "" local xtitle "`time'"
    }

    * =========================================================================
    * PRESERVE AND PREPARE DATA
    * =========================================================================
    preserve
    quietly keep if `touse'

    * Count unique individuals
    tempvar _id_tag
    bysort `id': gen byte `_id_tag' = (_n == 1)
    quietly count if `_id_tag'
    local n_ids = r(N)
    local n_sampled = `n_ids'
    drop `_id_tag'

    * --- Compute means on FULL data (before sampling) ---
    if `has_mean' {
        tempfile meanfile
        local mean_opts "outcome(`outcome') time(`time') savefile(`meanfile')"
        if "`by'" != "" local mean_opts "`mean_opts' by(`by')"
        if `mean_ci' local mean_opts "`mean_opts' ci"
        if "`mean_smooth'" != "" {
            local mean_opts "`mean_opts' smooth(`mean_smooth')"
        }

        _spaghetti_mean, `mean_opts'
    }

    * --- Sampling (after mean computation) ---
    if `sample' > 0 {
        _spaghetti_sample, id(`id') n(`sample') seed(`seed')
    }

    * --- Highlight ---
    local hl_bgopacity = `ind_opacity'
    if `"`highlight'"' != "" {
        local hlcond `"`highlight'"'

        * Extract bgopacity() sub-option if present (case-insensitive)
        local _hl_lc = lower(`"`hlcond'"')
        if regexm("`_hl_lc'", "bgopacity\(([0-9]+)\)") {
            local hl_bgopacity = regexs(1)
            * Remove bgopacity(...) from the condition string
            local hlcond = regexr(`"`hlcond'"', "[bB][gG][oO][pP][aA][cC][iI][tT][yY]\([0-9]+\)", "")
        }

        * Strip leading "if "
        local hlcond = strtrim(`"`hlcond'"')
        if substr(`"`hlcond'"', 1, 3) == "if " {
            local hlcond = substr(`"`hlcond'"', 4, .)
        }
        local hlcond = strtrim(`"`hlcond'"')

        * Evaluate conditions — try full expression first
        quietly gen byte _spag_hl_obs = 0
        capture quietly replace _spag_hl_obs = (`hlcond')
        if _rc {
            * Fall back: space-separated conditions, OR them together
            quietly replace _spag_hl_obs = 0
            local _hl_err 0
            foreach token in `hlcond' {
                capture quietly replace _spag_hl_obs = 1 if (`token')
                if _rc {
                    noisily display as error ///
                        "highlight(): invalid condition {bf:`token'}"
                    local _hl_err 1
                }
            }
            if `_hl_err' exit 198
        }

        * Propagate to all rows per individual
        bysort `id': egen byte _spag_hl = max(_spag_hl_obs)
        quietly replace _spag_hl = (_spag_hl > 0)
        drop _spag_hl_obs
    }

    * --- Colorby ---
    if "`cb_var'" != "" {
        if `cb_categorical' {
            quietly egen int _spag_cb = group(`cb_var')
        }
        else {
            * Use min(5, n_distinct) quantiles to handle few unique values
            quietly levelsof `cb_var', local(_cb_vals)
            local _cb_ndist : word count `_cb_vals'
            local _cb_nq = min(5, `_cb_ndist')
            if `_cb_nq' < 2 {
                * Degenerate: all same value, treat as single group
                quietly gen int _spag_cb = 1
            }
            else {
                quietly xtile _spag_cb = `cb_var', nq(`_cb_nq')
            }
        }

        quietly levelsof _spag_cb, local(cb_levels)
        local n_cb_groups : word count `cb_levels'

        * Check palette has enough colors for all groups
        local palette_size : word count `palette'
        if `n_cb_groups' > `palette_size' {
            display as error "colorby() has `n_cb_groups' levels" ///
                " but palette has only `palette_size' colors;" ///
                " specify colors() with enough colors or reduce levels"
            exit 198
        }

        * Save original values for categorical labels
        if `cb_categorical' {
            quietly levelsof `cb_var', local(cb_orig_vals)
            local cb_vlabel : value label `cb_var'
            forvalues g = 1/`n_cb_groups' {
                local cb_oval : word `g' of `cb_orig_vals'
                if "`cb_vlabel'" != "" {
                    capture local cb_leg_`g' : label `cb_vlabel' `cb_oval'
                    if _rc local cb_leg_`g' "`cb_oval'"
                }
                else {
                    local cb_leg_`g' "`cb_oval'"
                }
            }
        }
    }

    * =========================================================================
    * INSERT LINE BREAKS
    * =========================================================================
    quietly {
        gen long _spag_origrow = _n

        bysort `id' (`time'): gen byte _spag_last = (_n == _N)
        expand 2 if _spag_last

        * Identify duplicates via original row number
        sort _spag_origrow
        by _spag_origrow: gen byte _spag_isbreak = (_n == 2)

        * Break the line by setting outcome to missing
        replace `outcome' = . if _spag_isbreak

        drop _spag_origrow _spag_last
        sort `id' `time' _spag_isbreak
        drop _spag_isbreak
    }

    * =========================================================================
    * APPEND MEAN DATA
    * =========================================================================
    if `has_mean' {
        quietly gen byte _spag_is_mean = 0
        quietly append using `meanfile'
        sort _spag_is_mean `id' `time'
    }

    * Create numeric by-group variable for uniform graph conditions
    if "`by'" != "" {
        quietly egen int _spag_bygrp = group(`by')
    }

    * =========================================================================
    * BUILD GRAPH COMMAND
    * =========================================================================
    local graphcmd "twoway"
    local layer = 0

    * Condition to exclude mean rows
    local mean_and ""
    local mean_if ""
    if `has_mean' {
        local mean_and "& _spag_is_mean == 0"
        local mean_if "if _spag_is_mean == 0"
    }

    * --- Individual trajectory layers ---
    if `"`highlight'"' != "" {
        * Non-highlighted (faded background using individual() settings)
        local ++layer
        local graphcmd `"`graphcmd' (line `outcome' `time' if _spag_hl == 0 `mean_and', lcolor(`ind_color'%`hl_bgopacity') lwidth(`ind_lwidth') lpattern(solid) cmissing(n))"'

        * Highlighted
        if "`by'" != "" {
            forvalues g = 1/`n_groups' {
                local gc : word `g' of `palette'
                local ++layer
                local graphcmd `"`graphcmd' (line `outcome' `time' if _spag_hl == 1 & _spag_bygrp == `g' `mean_and', lcolor(`gc'%80) lwidth(thin) lpattern(solid) cmissing(n))"'
                local hl_layer_`g' = `layer'
            }
        }
        else {
            local ++layer
            local graphcmd `"`graphcmd' (line `outcome' `time' if _spag_hl == 1 `mean_and', lcolor(navy%80) lwidth(thin) lpattern(solid) cmissing(n))"'
        }
    }
    else if "`by'" != "" {
        * One layer per by-group
        forvalues g = 1/`n_groups' {
            local gc : word `g' of `palette'
            local ++layer
            local graphcmd `"`graphcmd' (line `outcome' `time' if _spag_bygrp == `g' `mean_and', lcolor(`gc'%`ind_opacity') lwidth(`ind_lwidth') lpattern(solid) cmissing(n))"'
            local traj_layer_`g' = `layer'
        }
    }
    else if "`cb_var'" != "" {
        * One layer per color group
        forvalues g = 1/`n_cb_groups' {
            local gval : word `g' of `cb_levels'
            local gc : word `g' of `palette'
            local ++layer
            local graphcmd `"`graphcmd' (line `outcome' `time' if _spag_cb == `gval' `mean_and', lcolor(`gc'%`ind_opacity') lwidth(`ind_lwidth') lpattern(solid) cmissing(n))"'
            local cb_layer_`g' = `layer'
        }
    }
    else {
        * Single layer, all trajectories
        local ++layer
        local graphcmd `"`graphcmd' (line `outcome' `time' `mean_if', lcolor(`ind_color'%`ind_opacity') lwidth(`ind_lwidth') lpattern(solid) cmissing(n))"'
    }

    * --- Mean overlay layers ---
    if `has_mean' {
        local mean_lw = cond(`mean_bold', "thick", "medthick")

        if "`by'" != "" {
            * CI bands per group
            if `mean_ci' {
                forvalues g = 1/`n_groups' {
                    local gc : word `g' of `palette'
                    local ++layer
                    local graphcmd `"`graphcmd' (rarea _spag_mean_lo _spag_mean_hi `time' if _spag_is_mean == 1 & _spag_bygrp == `g', color(`gc'%20) lwidth(none) lpattern(solid))"'
                }
            }

            * Mean lines per group
            forvalues g = 1/`n_groups' {
                local gc : word `g' of `palette'
                local ++layer
                local graphcmd `"`graphcmd' (line _spag_mean_y `time' if _spag_is_mean == 1 & _spag_bygrp == `g', lcolor(`gc') lwidth(`mean_lw') lpattern(solid))"'
                local mean_layer_`g' = `layer'
            }
        }
        else {
            * Single group
            if `mean_ci' {
                local ++layer
                local graphcmd `"`graphcmd' (rarea _spag_mean_lo _spag_mean_hi `time' if _spag_is_mean == 1, color(navy%30) lwidth(none) lpattern(solid))"'
            }
            local ++layer
            local graphcmd `"`graphcmd' (line _spag_mean_y `time' if _spag_is_mean == 1, lcolor(navy) lwidth(`mean_lw') lpattern(solid))"'
        }
    }

    * --- Graph options ---
    local graphopts ""

    * Legend
    local leg_order ""
    if `has_mean' & "`by'" != "" {
        forvalues g = 1/`n_groups' {
            local leg_order `"`leg_order' `mean_layer_`g'' "`glabel`g''""'
        }
    }
    else if "`by'" != "" & `"`highlight'"' != "" {
        forvalues g = 1/`n_groups' {
            local leg_order `"`leg_order' `hl_layer_`g'' "`glabel`g''""'
        }
    }
    else if "`by'" != "" {
        forvalues g = 1/`n_groups' {
            local leg_order `"`leg_order' `traj_layer_`g'' "`glabel`g''""'
        }
    }
    else if "`cb_var'" != "" {
        if `cb_categorical' {
            forvalues g = 1/`n_cb_groups' {
                local leg_order `"`leg_order' `cb_layer_`g'' "`cb_leg_`g''""'
            }
        }
        else {
            forvalues g = 1/`n_cb_groups' {
                local leg_order `"`leg_order' `cb_layer_`g'' "Q`g'""'
            }
        }
    }

    if `"`leg_order'"' != "" {
        local graphopts `"`graphopts' legend(order(`leg_order') rows(1) position(6) size(small))"'
    }
    else {
        local graphopts `"`graphopts' legend(off)"'
    }

    * Axis titles
    local graphopts `"`graphopts' ytitle(`"`ytitle'"') xtitle(`"`xtitle'"')"'

    * Reference line
    if `has_refline' {
        local graphopts `"`graphopts' xline(`ref_val', lpattern(`ref_style') lcolor(gs8) lwidth(thin))"'
        if "`ref_label'" != "" {
            quietly summarize `outcome' if !missing(`outcome'), meanonly
            local _ref_ypos = r(max)
            local graphopts `"`graphopts' text(`_ref_ypos' `ref_val' "`ref_label'", placement(ne) size(vsmall) color(gs6))"'
        }
    }

    * User-specified titles
    if `"`title'"' != "" {
        local graphopts `"`graphopts' title(`title')"'
    }
    if `"`subtitle'"' != "" {
        local graphopts `"`graphopts' subtitle(`subtitle')"'
    }
    if `"`note'"' != "" {
        local graphopts `"`graphopts' note(`note')"'
    }

    * Scheme
    local graphopts `"`graphopts' scheme(`scheme')"'

    * Plot/graph region
    if `"`plotregion'"' != "" {
        local graphopts `"`graphopts' plotregion(`plotregion')"'
    }
    if `"`graphregion'"' != "" {
        local graphopts `"`graphopts' graphregion(`graphregion')"'
    }

    * Name and saving
    if "`name'" != "" {
        if strpos("`name'", "replace") {
            local graphopts `"`graphopts' name(`name')"'
        }
        else {
            local graphopts `"`graphopts' name(`name', replace)"'
        }
    }
    if `"`saving'"' != "" {
        local graphopts `"`graphopts' saving(`saving')"'
    }

    * Passthrough options
    if `"`options'"' != "" {
        local graphopts `"`graphopts' `options'"'
    }

    * Assemble final command
    local graphcmd `"`graphcmd', `graphopts'"'

    * =========================================================================
    * EXECUTE GRAPH
    * =========================================================================
    `graphcmd'

    * =========================================================================
    * EXPORT
    * =========================================================================
    if `has_export' {
        quietly graph export `"`exp_file'"', `exp_replace'
    }

    * Save return values before restore
    local ret_N = `N'
    local ret_n_ids = `n_ids'
    local ret_n_sampled = `n_sampled'
    local ret_n_groups = `n_groups'
    local ret_cmd `"`graphcmd'"'

    restore

    * =========================================================================
    * RETURN VALUES
    * =========================================================================
    return scalar N = `ret_N'
    return scalar n_ids = `ret_n_ids'
    return scalar n_sampled = `ret_n_sampled'
    return scalar n_groups = `ret_n_groups'
    return local cmd `"`ret_cmd'"'
    return local outcome "`outcome'"
    return local id "`id'"
    return local time "`time'"
    if "`by'" != "" return local by "`by'"

    } /* end capture noisily */
    local _rc = _rc

    set varabbrev `_varabbrev'
    set more `_more'

    if `_rc' exit `_rc'
end
