*! _psdash_mgps_graph Version 1.6.9  2026/08/30
*! Component-by-treatment generalized propensity score graph
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Internal helper

program define _psdash_mgps_graph, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    local _panel_graphs ""
    local _compact_frame_created = 0
    tempname compact_frame

    capture noisily {
        syntax , TREATment(varname numeric) SAMPLEvar(varname) ///
            PSVars(varlist numeric) LEVELS(string asis) NAME(name) ///
            GPSFLOOR(real) [HISTogram BINS(integer 30) BWidth(real -1) ///
            SAVing(string asis) SCHeme(string) GRAPHOPTions(string asis) ///
            TItle(string) COMPACT(string)]

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
        if "`compact'" != "" & !inlist("`compact'", "overlap", "support") {
            display as error "compact() must be overlap or support"
            exit 198
        }

        local scheme_opt ""
        if "`scheme'" != "" local scheme_opt "scheme(`scheme')"
        local bwidth_opt ""
        if `bwidth' > 0 local bwidth_opt "bwidth(`bwidth')"
        local color_list "navy cranberry forest_green dkorange purple teal maroon olive"
        local title_opt ""
        if `"`title'"' != "" local title_opt `"title(`"`title'"')"'

        if "`compact'" == "overlap" {
            tempvar observed_tmp row_tmp
            frame put `treatment' `psvars' if `samplevar', into(`compact_frame')
            local _compact_frame_created = 1

            frame `compact_frame': rename `treatment' `observed_tmp'
            local score_tmps ""
            local component_label_defs ""
            local legend_order ""
            local score_idx = 0
            foreach score_level of local levels {
                local ++score_idx
                local score_var : word `score_idx' of `psvars'
                tempvar score_tmp
                frame `compact_frame': rename `score_var' `score_tmp'
                local score_tmps "`score_tmps' `score_tmp'"
                local score_label : label (`treatment') `score_level'
                if `"`score_label'"' == "" local score_label "Group `score_level'"
                local component_label_defs `"`component_label_defs' `score_idx' `"Pr(A=`score_label' | X)"'"'
                local legend_order `"`legend_order' `score_idx' `"`score_label'"'"'
            }

            local score_idx = 0
            foreach score_tmp of local score_tmps {
                local ++score_idx
                frame `compact_frame': rename `score_tmp' _psd_gps`score_idx'
            }
            frame `compact_frame': generate long `row_tmp' = _n
            frame `compact_frame': reshape long _psd_gps, ///
                i(`row_tmp') j(_psd_component)
            frame `compact_frame': label define _psd_component ///
                `component_label_defs', replace
            frame `compact_frame': label values _psd_component _psd_component

            noisily frame `compact_frame': graph box _psd_gps, ///
                over(_psd_component, label(labsize(vsmall))) ///
                over(`observed_tmp', label(labsize(small))) asyvars ///
                legend(order(`legend_order') rows(1) position(6) size(tiny)) ///
                yscale(range(0 1)) ///
                ylabel(0(.2)1, format(%3.1f) labsize(vsmall) angle(horizontal)) ///
                ytitle("Generalized propensity score", size(small)) ///
                yline(`gpsfloor', lcolor(red) lpattern(shortdash)) ///
                `title_opt' name(`name', replace) `scheme_opt' `graphoptions'

            if `"`saving'"' != "" {
                _psdash_graph_export, saving(`saving')
            }

            return scalar K = `K'
            return scalar panel_count = 1
            return local design "gps_component_box_by_observed_treatment"
        }

        if "`compact'" == "support" {
            tempvar min_gps
            quietly egen double `min_gps' = rowmin(`psvars') if `samplevar'

            noisily graph box `min_gps' if `samplevar', ///
                over(`treatment', label(labsize(small))) ///
                legend(off) yscale(range(0)) ///
                ylabel(, format(%4.2f) labsize(vsmall) angle(horizontal)) ///
                ytitle("Minimum GPS component", size(small)) ///
                yline(`gpsfloor', lcolor(red) lpattern(shortdash)) ///
                `title_opt' name(`name', replace) `scheme_opt' `graphoptions'

            if `"`saving'"' != "" {
                _psdash_graph_export, saving(`saving')
            }

            return scalar K = `K'
            return scalar panel_count = 1
            return local design "minimum_gps_by_observed_treatment"
        }

        if "`compact'" == "" {
            local score_idx = 0
            foreach score_level of local levels {
                local ++score_idx
                local score_var : word `score_idx' of `psvars'
                local score_label : label (`treatment') `score_level'
                if `"`score_label'"' == "" local score_label "Group `score_level'"

                quietly summarize `score_var' if `samplevar', meanonly
                local score_min = r(min)
                local score_max = r(max)
                local score_range = `score_max' - `score_min'
                local hist_width = `score_range' / `bins'
                if `hist_width' <= 0 local hist_width = 1 / `bins'
                local floor_line = inrange(`gpsfloor', `score_min', `score_max')
                local floor_opt ""
                if `floor_line' {
                    local floor_opt ///
                        "xline(`gpsfloor', lcolor(red) lpattern(shortdash))"
                }

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
                        local plot_cmd `"`plot_cmd' (histogram `score_var' if `samplevar' & `treatment' == `observed_level', fraction start(`score_min') width(`hist_width') fcolor(`color'%40) lcolor(`color'))"'
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
                    xtitle("Generalized propensity score", size(small)) ///
                    ytitle("`ytitle'", size(small)) ///
                    xlabel(, labsize(small) angle(horizontal)) ///
                    ylabel(, labsize(small) angle(horizontal)) ///
                    title(`"Pr(A=`score_label' | X)"', size(medsmall)) ///
                    `floor_opt' ///
                    name(`panel_graph', replace) `scheme_opt' `graphoptions'

                return local panel_`score_idx'_score "`score_var'"
                return local panel_`score_idx'_groups "`levels'"
                return scalar panel_`score_idx'_min = `score_min'
                return scalar panel_`score_idx'_max = `score_max'
                return scalar panel_`score_idx'_floor_line = `floor_line'
            }

            if `K' <= 3 local combine_cols = `K'
            else if `K' == 4 local combine_cols = 2
            else local combine_cols = 3
            local combine_rows = ceil(`K' / `combine_cols')
            local combine_xsize = max(5.5, 4 * `combine_cols')
            local combine_ysize = max(4, 3.5 * `combine_rows')
            local combine_iscale = cond(`K' <= 3, 1, .8)
            noisily graph combine `_panel_graphs', cols(`combine_cols') ///
                xsize(`combine_xsize') ysize(`combine_ysize') ///
                iscale(`combine_iscale') ///
                `title_opt' name(`name', replace) `scheme_opt'

            if `"`saving'"' != "" {
                _psdash_graph_export, saving(`saving')
            }

            return scalar K = `K'
            return scalar panel_count = `K'
            return scalar combine_cols = `combine_cols'
            return local design "gps_component_by_observed_treatment"
        }
    }
    local rc = _rc
    if `_compact_frame_created' capture frame drop `compact_frame'
    foreach panel_graph of local _panel_graphs {
        capture graph drop `panel_graph'
        local _graph_drop_rc = _rc
    }
    set varabbrev `_vao'
    if `rc' exit `rc'
end
