*! _psdash_mgps_graph Version 1.6.3  2026/08/10
*! Component-by-treatment generalized propensity score graph
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Internal helper

program define _psdash_mgps_graph, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    local _panel_graphs ""

    capture noisily {
        syntax , TREATment(varname numeric) SAMPLEvar(varname) ///
            PSVars(varlist numeric) LEVELS(string asis) NAME(name) ///
            GPSFLOOR(real) [HISTogram BINS(integer 30) BWidth(real -1) ///
            SAVing(string asis) SCHeme(string) GRAPHOPTions(string asis) ///
            TItle(string asis)]

        local K : word count `levels'
        local n_psvars : word count `psvars'
        if `K' != `n_psvars' {
            display as error "internal error: multi-group graph mapping incomplete"
            exit 498
        }
        if `bins' <= 0 {
            display as error "bins() must be positive"
            exit 198
        }
        if `bwidth' != -1 & `bwidth' <= 0 {
            display as error "bwidth() must be positive"
            exit 198
        }

        local scheme_opt ""
        if "`scheme'" != "" local scheme_opt "scheme(`scheme')"
        local bwidth_opt ""
        if `bwidth' > 0 local bwidth_opt "bwidth(`bwidth')"
        local color_list "navy cranberry forest_green dkorange purple teal maroon olive"
        local hist_width = 1 / `bins'

        local score_idx = 0
        foreach score_level of local levels {
            local ++score_idx
            local score_var : word `score_idx' of `psvars'
            local score_label : label (`treatment') `score_level'
            if `"`score_label'"' == "" local score_label "Group `score_level'"

            local plot_cmd ""
            local legend_order ""
            local group_idx = 0
            foreach observed_level of local levels {
                local ++group_idx
                local observed_label : label (`treatment') `observed_level'
                if `"`observed_label'"' == "" {
                    local observed_label "Group `observed_level'"
                }
                local color_idx = mod(`group_idx' - 1, 8) + 1
                local color : word `color_idx' of `color_list'

                if "`histogram'" != "" {
                    local plot_cmd `"`plot_cmd' (histogram `score_var' if `samplevar' & `treatment' == `observed_level', fraction start(0) width(`hist_width') fcolor(`color'%40) lcolor(`color'))"'
                }
                else {
                    local plot_cmd `"`plot_cmd' (kdensity `score_var' if `samplevar' & `treatment' == `observed_level', lcolor(`color') lwidth(medthick) `bwidth_opt')"'
                }
                local legend_order `"`legend_order' `group_idx' `"`observed_label'"'"'
            }

            tempname panel_graph
            local _panel_graphs "`_panel_graphs' `panel_graph'"
            local ytitle = cond("`histogram'" != "", "Fraction", "Density")
            noisily twoway `plot_cmd', ///
                legend(order(`legend_order') rows(1) position(6) size(vsmall)) ///
                xscale(range(0 1)) xtitle("Generalized propensity score") ///
                ytitle("`ytitle'") ///
                title(`"Pr(A=`score_label' | X)"', size(medsmall)) ///
                xline(`gpsfloor', lcolor(red) lpattern(shortdash)) ///
                name(`panel_graph', replace) `scheme_opt' `graphoptions'

            return local panel_`score_idx'_score "`score_var'"
            return local panel_`score_idx'_groups "`levels'"
        }

        local combine_cols = cond(`K' == 1, 1, 2)
        local title_opt ""
        if `"`title'"' != "" local title_opt `"title(`"`title'"')"'
        noisily graph combine `_panel_graphs', cols(`combine_cols') ///
            `title_opt' name(`name', replace) `scheme_opt'

        if `"`saving'"' != "" {
            _psdash_graph_export, saving(`saving')
        }

        return scalar K = `K'
        return local design "gps_component_by_observed_treatment"
    }
    local rc = _rc
    foreach panel_graph of local _panel_graphs {
        capture graph drop `panel_graph'
        local _graph_drop_rc = _rc
    }
    set varabbrev `_vao'
    if `rc' exit `rc'
end
