*! _psdash_mgps_graph Version 1.9.0  2026/10/29
*! Component-by-treatment generalized propensity score graph
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Internal helper

program define _psdash_mgps_graph, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    local _panel_graphs ""
    local panel_names ""
    local _compact_frame_created = 0
    tempname compact_frame

    capture noisily {
        syntax , TREATment(varname numeric) SAMPLEvar(varname) ///
            PSVars(varlist numeric) LEVELS(string asis) NAME(name) ///
            GPSFLOOR(real) [HISTogram BINS(integer 30) BWidth(real -1) ///
            SAVing(string asis) SCHeme(string) GRAPHOPTions(string asis) ///
            TItle(string) COMPACT(string) _PANEL]

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
        _psdash_pstyles, scheme(`scheme') graphopts(`graphoptions')
        local _pso "`s(order)'"
        * Series colours follow the active scheme in the order _psdash_pstyles
        * returns: p1, p2, p3, ...; in sequential schemes, where p2 sits next to
        * p1, the order is p1, p6, p2, p3, ... See psdash.sthlp.
        local title_opt ""
        if `"`title'"' != "" local title_opt `"title(`"`title'"')"'
        * The gpsfloor reference line has no legend key of its own, so every
        * graph that draws it says what it is.
        local floor_txt = strtrim(string(`gpsfloor', "%9.0g"))
        if substr("`floor_txt'", 1, 1) == "." local floor_txt "0`floor_txt'"
        local floor_label "Practical positivity floor (`floor_txt')"
        local floor_note "Dashed red line: practical positivity floor (`floor_txt')"
        * A 2x2 dashboard panel (psdash combined, _panel) fixes the text sizes
        * the white_tableau scheme uses, so a scheme with larger defaults
        * (s2color, s1mono) cannot push the legend or y title past the cell;
        * long arm labels wrap the legend onto two rows.
        local leg_size ""
        local box_leg_rows = 1
        local lab_size ""
        local over_lab ""
        local tsz ""
        local note_size ""
        if "`_panel'" != "" {
            local leg_size "size(small) symxsize(5) keygap(vsmall) colgap(small)"
            local lab_size "labsize(small)"
            local over_lab ", label(labsize(small))"
            local tsz ", size(small)"
            local note_size ", size(small)"
        }
        * Box-plot legends wrap onto two rows when the arm labels would not
        * fit one row (a dashboard cell sooner than a full-size graph).
        local leg_chars = 0
        foreach lev of local levels {
            _psdash_label_text, variable(`treatment') level(`lev')
            local leg_chars = `leg_chars' + ustrlen(`"`r(text)'"') + 4
        }
        if `leg_chars' > cond("`_panel'" != "", 40, 48) local box_leg_rows = 2

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
                _psdash_label_text, variable(`treatment') level(`score_level')
                local score_label `"`r(text)'"'
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

            * Canonical level -> pstyle mapping (same as the density and
            * weights graphs): colour component j like level j everywhere.
            local box_opts ""
            forvalues j = 1/`K' {
                local pst : word `=mod(`j' - 1, 15) + 1' of `_pso'
                local box_opts `"`box_opts' box(`j', bstyle(p`pst'bar)) marker(`j', mstyle(p`pst'))"'
            }

            noisily frame `compact_frame': graph box _psd_gps, ///
                over(_psd_component) over(`observed_tmp'`over_lab') asyvars ///
                `box_opts' ///
                legend(order(`legend_order') rows(`box_leg_rows') position(6) `leg_size') ///
                yscale(range(0 1)) ylabel(0(.2)1, angle(horizontal) `lab_size') ///
                ytitle("Generalized propensity score"`tsz') ///
                yline(`gpsfloor', lcolor(red) lpattern(shortdash)) ///
                note(`"`floor_note'"'`note_size') ///
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

            * One box per observed group, coloured with the canonical
            * level -> pstyle mapping; the legend names the groups.
            local box_opts ""
            local legend_order ""
            local group_idx = 0
            foreach observed_level of local levels {
                local ++group_idx
                local pst : word `=mod(`group_idx' - 1, 15) + 1' of `_pso'
                local box_opts `"`box_opts' box(`group_idx', bstyle(p`pst'bar)) marker(`group_idx', mstyle(p`pst'))"'
                _psdash_label_text, variable(`treatment') level(`observed_level')
                local legend_order `"`legend_order' `group_idx' `"`r(text)'"'"'
            }

            * Labels from 0 (the axis starts there, under the floor line) to
            * the top of the data on a round step, at most 5 intervals: the
            * automatic labels span only the data, so clustered minima (many
            * arms) printed several overlapping labels at the top of the axis.
            quietly summarize `min_gps' if `samplevar', meanonly
            local box_hi = max(r(max), `gpsfloor')
            local raw_step = `box_hi' / 4
            local magnitude = 10^floor(log10(`raw_step'))
            local normalized = `raw_step' / `magnitude'
            if `normalized' <= 1 local nice_step = 1
            else if `normalized' <= 2 local nice_step = 2
            else if `normalized' <= 2.5 local nice_step = 2.5
            else if `normalized' <= 5 local nice_step = 5
            else local nice_step = 10
            local box_step = `nice_step' * `magnitude'
            local box_top = ceil(`box_hi' / `box_step' - 1e-9) * `box_step'
            local box_ylab ""
            forvalues k = 0/`=round(`box_top' / `box_step')' {
                local box_ylab "`box_ylab' `=strtrim(string(`k' * `box_step', "%12.8g"))'"
            }
            local box_ylab = strtrim("`box_ylab'")
            noisily graph box `min_gps' if `samplevar', ///
                over(`treatment') asyvars `box_opts' ///
                legend(order(`legend_order') rows(`box_leg_rows') position(6) `leg_size') ///
                yscale(range(0)) ylabel(`box_ylab', angle(horizontal) `lab_size') ///
                ytitle("Minimum GPS component"`tsz') ///
                yline(`gpsfloor', lcolor(red) lpattern(shortdash)) ///
                note(`"`floor_note'"'`note_size') ///
                `title_opt' name(`name', replace) `scheme_opt' `graphoptions'

            if `"`saving'"' != "" {
                _psdash_graph_export, saving(`saving')
            }

            return scalar K = `K'
            return scalar panel_count = 1
            return local design "minimum_gps_by_observed_treatment"
        }

        if "`compact'" == "" {
            * Per-panel legends are off: one shared legend panel is added below
            * the panel row (Stata has no shared legend for graph combine).
            local any_floor = 0
            local score_idx = 0
            foreach score_level of local levels {
                local ++score_idx
                local score_var : word `score_idx' of `psvars'
                _psdash_label_text, variable(`treatment') level(`score_level')
                local score_label `"`r(text)'"'

                quietly summarize `score_var' if `samplevar', meanonly
                local score_min = r(min)
                local score_max = r(max)
                local score_range = `score_max' - `score_min'
                local hist_width = `score_range' / `bins'
                if `hist_width' <= 0 local hist_width = 1 / `bins'
                local floor_line = inrange(`gpsfloor', `score_min', `score_max')
                local floor_opt ""
                if `floor_line' {
                    local any_floor = 1
                    local floor_opt ///
                        "xline(`gpsfloor', lcolor(red) lpattern(shortdash))"
                }

                local plot_cmd ""
                local group_idx = 0
                foreach observed_level of local levels {
                    local ++group_idx
                    * Canonical level -> pstyle mapping (see _psdash_pstyles)
                    local pst : word `=mod(`group_idx' - 1, 15) + 1' of `_pso'

                    if "`histogram'" != "" {
                        local plot_cmd `"`plot_cmd' (histogram `score_var' if `samplevar' & `treatment' == `observed_level', fraction start(`score_min') width(`hist_width') pstyle(p`pst') fcolor(%40))"'
                    }
                    else {
                        local plot_cmd `"`plot_cmd' (kdensity `score_var' if `samplevar' & `treatment' == `observed_level', pstyle(p`pst') lwidth(medthick) `bwidth_opt')"'
                    }
                }

                tempname panel_graph
                local _panel_graphs "`_panel_graphs' `panel_graph'"
                local panel_names "`panel_names' `panel_graph'"
                local ytitle = cond("`histogram'" != "", "Fraction", "Density")
                noisily twoway `plot_cmd', legend(off) ///
                    xtitle("Generalized propensity score") ///
                    ytitle("`ytitle'") ylabel(, angle(horizontal)) ///
                    title(`"Pr(A=`score_label' | X)"') ///
                    `floor_opt' ///
                    name(`panel_graph', replace) `scheme_opt' `graphoptions'

                return local panel_`score_idx'_score "`score_var'"
                return local panel_`score_idx'_groups "`levels'"
                return scalar panel_`score_idx'_min = `score_min'
                return scalar panel_`score_idx'_max = `score_max'
                return scalar panel_`score_idx'_floor_line = `floor_line'
            }

            * Legend-only panel: empty plots carry the keys (same pstyles as
            * the panels), the plot region and axes are hidden.
            local leg_plots ""
            local leg_order ""
            local group_idx = 0
            foreach observed_level of local levels {
                local ++group_idx
                local pst : word `=mod(`group_idx' - 1, 15) + 1' of `_pso'
                _psdash_label_text, variable(`treatment') level(`observed_level')
                if "`histogram'" != "" {
                    local leg_plots `"`leg_plots' (scatteri 0 0, recast(area) pstyle(p`pst') fcolor(%40))"'
                }
                else {
                    local leg_plots `"`leg_plots' (scatteri 0 0, recast(line) pstyle(p`pst') lwidth(medthick))"'
                }
                local leg_order `"`leg_order' `group_idx' `"`r(text)'"'"'
            }
            if `any_floor' {
                local leg_plots `"`leg_plots' (scatteri 0 0, recast(line) lcolor(red) lpattern(shortdash))"'
                local leg_order `"`leg_order' `=`K' + 1' `"`floor_label'"'"'
            }
            * Text size follows the row height, not the canvas height: with
            * more than one row of panels the canvas is taller, so panel, legend
            * and title text are scaled by 1/rows to keep the same size as in a
            * one-row layout.
            if `K' <= 3 local combine_cols = `K'
            else if `K' == 4 local combine_cols = 2
            else local combine_cols = 3
            local combine_rows = ceil(`K' / `combine_cols')
            local combine_iscale = 1 / `combine_rows'
            local outer_title_opt ""
            if `"`title'"' != "" {
                local outer_title_opt ///
                    `"title(`"`title'"', size(*`combine_iscale'))"'
            }
            local leg_rows = cond(`K' <= 3 | (`K' <= 4 & !`any_floor'), 1, 2)
            local leg_height = cond(`leg_rows' == 1, 8, 12)
            tempname legend_panel panel_row
            local _panel_graphs "`_panel_graphs' `legend_panel' `panel_row'"
            noisily twoway `leg_plots', ///
                legend(order(`leg_order') rows(`leg_rows') position(12) ring(0)) ///
                xscale(off range(0 1)) yscale(off range(0 1)) ///
                xlabel(none) ylabel(none) xtitle("") ytitle("") ///
                plotregion(style(none)) graphregion(margin(zero)) ///
                fysize(`leg_height') scale(`combine_iscale') ///
                name(`legend_panel', replace) `scheme_opt'

            local combine_xsize = 3.4 * `combine_cols'
            local combine_ysize = 3.2 * `combine_rows'
            noisily graph combine `panel_names', cols(`combine_cols') ///
                xsize(`combine_xsize') ysize(`combine_ysize') ///
                iscale(`combine_iscale') ///
                name(`panel_row', replace) `scheme_opt'
            local outer_ysize = `combine_ysize' * 1.09 + 0.5
            noisily graph combine `panel_row' `legend_panel', cols(1) ///
                xsize(`combine_xsize') ysize(`outer_ysize') iscale(1) ///
                `outer_title_opt' name(`name', replace) `scheme_opt'

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
