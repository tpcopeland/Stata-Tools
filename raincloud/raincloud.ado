*! raincloud Version 1.1.0  2026/03/14
*! Raincloud plots: half-violin density + jittered scatter + box elements
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  raincloud varname [if] [in] [fweight aweight], [over(varname) options]

Description:
  Combines three views of a distribution — kernel density shape (cloud),
  raw data points (rain), and box-and-whisker summary (box/umbrella) —
  into a single plot. Based on Allen et al. (2019).

See help raincloud for complete documentation
*/

program define raincloud, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax varlist(numeric min=1 max=1) [if] [in] [fweight aweight] , ///
        [Over(varname)                                     ///
         NOCloud NORAin NOBox NOUMBrella                    ///
         BANDWidth(real 0) Kernel(string) n(integer 200)   ///
         Opacity(integer 50) CLOUDWidth(real 0.4)          ///
         CLOUDopts(string asis)                            ///
         Jitter(real 0.4) SEED(integer -1)                 ///
         POINTSize(string) POINTopts(string asis)          ///
         BOXWidth(real 0.08) BOXopts(string asis)          ///
         NOMEDian MEAN OVERLap MIRror                        ///
         HORizontal VERTical                               ///
         gap(real 1.0) COLors(string)                      ///
         TItle(string asis) SUBtitle(string asis)          ///
         NOTE(string asis) NAME(string asis)               ///
         SAVing(string asis) SCHeme(string)                ///
         PLOTRegion(string asis) GRAPHRegion(string asis)  ///
         YTItle(string asis) XTItle(string asis)           ///
         LEGend(string asis) *]

    * =========================================================================
    * MARK SAMPLE
    * =========================================================================
    marksample touse
    if "`over'" != "" {
        capture confirm numeric variable `over'
        if _rc == 0 {
            markout `touse' `over'
        }
        else {
            * String variable: mark missing (empty string) manually
            quietly replace `touse' = 0 if missing(`over')
        }
    }

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        set varabbrev `_varabbrev'
        set more `_more'
        exit 2000
    }
    local N = r(N)

    * =========================================================================
    * VALIDATE INPUTS
    * =========================================================================
    if `opacity' < 0 | `opacity' > 100 {
        display as error "opacity() must be between 0 and 100"
        set varabbrev `_varabbrev'
        set more `_more'
        exit 198
    }
    if `jitter' < 0 | `jitter' > 1 {
        display as error "jitter() must be between 0 and 1"
        set varabbrev `_varabbrev'
        set more `_more'
        exit 198
    }
    if `cloudwidth' <= 0 {
        display as error "cloudwidth() must be positive"
        set varabbrev `_varabbrev'
        set more `_more'
        exit 198
    }
    if `boxwidth' <= 0 {
        display as error "boxwidth() must be positive"
        set varabbrev `_varabbrev'
        set more `_more'
        exit 198
    }
    if `n' < 10 {
        display as error "n() must be at least 10"
        set varabbrev `_varabbrev'
        set more `_more'
        exit 198
    }
    if `gap' <= 0 {
        display as error "gap() must be positive"
        set varabbrev `_varabbrev'
        set more `_more'
        exit 198
    }

    * noumbrella is synonym for nobox
    if "`noumbrella'" != "" local nobox "nobox"

    * Orientation: default horizontal
    if "`vertical'" != "" & "`horizontal'" != "" {
        display as error "cannot specify both horizontal and vertical"
        set varabbrev `_varabbrev'
        set more `_more'
        exit 198
    }
    local orient = cond("`vertical'" != "", "vertical", "horizontal")

    * Must show at least one element
    if "`nocloud'" != "" & "`norain'" != "" & "`nobox'" != "" {
        display as error "cannot suppress all three elements"
        set varabbrev `_varabbrev'
        set more `_more'
        exit 198
    }

    * =========================================================================
    * SET DEFAULTS
    * =========================================================================
    if "`scheme'" == "" local scheme "plotplainblind"
    if "`kernel'" == "" local kernel "epanechnikov"
    if "`pointsize'" == "" local pointsize "vsmall"

    if "`colors'" == "" {
        local colors "navy cranberry forest_green dkorange purple teal maroon olive_teal"
    }
    local ncolors : word count `colors'

    * Weight expression for kdensity
    local wt_exp ""
    if "`weight'" != "" local wt_exp "[`weight'`exp']"

    * =========================================================================
    * DETERMINE GROUPS
    * =========================================================================
    preserve

    * Wrap post-preserve computation in capture noisily so that
    * varabbrev/more are always restored even if an error occurs
    capture noisily {

    quietly keep if `touse'

    tempvar over_num
    local n_groups = 1
    local grp_levels "1"
    local grp_labels `"`"All"'"'

    if "`over'" != "" {
        * Encode string variables to numeric
        capture confirm string variable `over'
        if _rc == 0 {
            encode `over', generate(`over_num')
        }
        else {
            quietly clonevar `over_num' = `over'
        }

        quietly levelsof `over_num', local(grp_levels)
        local n_groups : word count `grp_levels'

        * Collect labels
        local grp_labels ""
        local has_labels 0
        local lbl : value label `over_num'
        if "`lbl'" != "" local has_labels 1

        foreach lev of local grp_levels {
            if `has_labels' {
                local lab : label `lbl' `lev'
            }
            else {
                local lab "`lev'"
            }
            local grp_labels `"`grp_labels' `"`lab'"'"'
        }
    }
    else {
        quietly gen byte `over_num' = 1
    }

    * =========================================================================
    * PER-GROUP COMPUTATION
    * =========================================================================
    if `seed' >= 0 {
        set seed `seed'
    }

    local twoway_cmd ""
    local ylab_vals ""
    local legend_order ""
    local legend_labels ""
    local layer = 0

    * Stats matrix: n_groups x 8 (n, mean, sd, median, q25, q75, iqr, bw)
    tempname stats
    matrix `stats' = J(`n_groups', 8, .)
    local stat_names ""

    * Pre-allocate shared box tempvars and observations
    if "`nobox'" == "" {
        tempvar bx_q25 bx_q75 bx_ctr bx_wlo bx_whi
        tempvar bx_med bx_mean bx_med_lo bx_med_hi

        local box_base = _N
        quietly set obs `= _N + `n_groups''

        quietly gen double `bx_q25'    = .
        quietly gen double `bx_q75'    = .
        quietly gen double `bx_ctr'    = .
        quietly gen double `bx_wlo'    = .
        quietly gen double `bx_whi'    = .
        quietly gen double `bx_med'    = .
        quietly gen double `bx_mean'   = .
        quietly gen double `bx_med_lo' = .
        quietly gen double `bx_med_hi' = .
    }

    local g = 0
    foreach lev of local grp_levels {
        local ++g
        local center = `g' * `gap'
        local grp_lab : word `g' of `grp_labels'
        local ylab_vals "`ylab_vals' `center'"

        * Color: cycle with modular arithmetic
        local cidx = mod(`g' - 1, `ncolors') + 1
        local clr : word `cidx' of `colors'

        * --- Summary statistics ---
        quietly summarize `varlist' if `over_num' == `lev', detail
        local grp_n    = r(N)
        local grp_mean = r(mean)
        local grp_sd   = r(sd)
        local grp_med  = r(p50)
        local grp_q25  = r(p25)
        local grp_q75  = r(p75)
        local grp_iqr  = `grp_q75' - `grp_q25'

        matrix `stats'[`g', 1] = `grp_n'
        matrix `stats'[`g', 2] = `grp_mean'
        matrix `stats'[`g', 3] = `grp_sd'
        matrix `stats'[`g', 4] = `grp_med'
        matrix `stats'[`g', 5] = `grp_q25'
        matrix `stats'[`g', 6] = `grp_q75'
        matrix `stats'[`g', 7] = `grp_iqr'
        local stat_names `"`stat_names' `"`grp_lab'"'"'

        * Whiskers: data values within 1.5*IQR
        local whi_lo = `grp_q25' - 1.5 * `grp_iqr'
        local whi_hi = `grp_q75' + 1.5 * `grp_iqr'

        * Find actual data whisker endpoints (with guard for empty result)
        quietly summarize `varlist' if `over_num' == `lev' ///
            & `varlist' >= `whi_lo', detail
        if r(N) > 0 {
            local whi_lo = r(min)
        }
        else {
            local whi_lo = `grp_q25'
        }
        quietly summarize `varlist' if `over_num' == `lev' ///
            & `varlist' <= `whi_hi', detail
        if r(N) > 0 {
            local whi_hi = r(max)
        }
        else {
            local whi_hi = `grp_q75'
        }

        * --- Handle edge cases ---
        local skip_cloud = 0
        if `grp_n' == 1 | `grp_sd' == 0 {
            local skip_cloud = 1
        }

        * --- Cloud (kernel density) ---
        if "`nocloud'" == "" & `skip_cloud' == 0 {
            tempvar kd_x_`g' kd_y_`g' cloud_hi_`g' cloud_lo_`g'

            local bw_opt ""
            if `bandwidth' > 0 {
                local bw_opt "bwidth(`bandwidth')"
            }

            quietly kdensity `varlist' if `over_num' == `lev' `wt_exp', ///
                generate(`kd_x_`g'' `kd_y_`g'') nograph n(`n') ///
                `bw_opt' kernel(`kernel')

            * Capture bandwidth before summarize overwrites r()
            matrix `stats'[`g', 8] = r(bwidth)

            * Scale density to cloudwidth
            quietly summarize `kd_y_`g'', meanonly
            local kd_max = r(max)
            if `kd_max' > 0 {
                quietly gen double `cloud_hi_`g'' = `center' + ///
                    (`kd_y_`g'' / `kd_max') * `cloudwidth'
                if "`mirror'" != "" {
                    quietly gen double `cloud_lo_`g'' = `center' - ///
                        (`kd_y_`g'' / `kd_max') * `cloudwidth'
                }
                else {
                    quietly gen double `cloud_lo_`g'' = `center'
                }
            }
            else {
                local skip_cloud = 1
            }
        }

        if "`nocloud'" == "" & `skip_cloud' == 0 {
            local ++layer
            if "`orient'" == "horizontal" {
                * rarea y1 y2 x: kd_x on x-axis, cloud_hi/lo on y-axis
                local twoway_cmd "`twoway_cmd' (rarea `cloud_hi_`g'' `cloud_lo_`g'' `kd_x_`g'', fcolor(`clr'%`opacity') lcolor(`clr') lwidth(vthin) `cloudopts')"
            }
            else {
                * rarea y1 y2 x, horizontal: kd_x on y-axis, cloud_hi/lo on x-axis
                local twoway_cmd "`twoway_cmd' (rarea `cloud_hi_`g'' `cloud_lo_`g'' `kd_x_`g'', horizontal fcolor(`clr'%`opacity') lcolor(`clr') lwidth(vthin) `cloudopts')"
            }
            local legend_order "`legend_order' `layer'"
            local legend_labels `"`legend_labels' label(`layer' `"`grp_lab'"')"'
        }

        * --- Compute shared positions for box and rain ---
        if "`mirror'" != "" {
            local box_center = `center'
        }
        else {
            local box_center = `center' - 0.02 - `boxwidth' / 2
        }

        * --- Box elements ---
        if "`nobox'" == "" {
            local box_obs = `box_base' + `g'

            quietly replace `bx_q25'  = `grp_q25'  in `box_obs'
            quietly replace `bx_q75'  = `grp_q75'  in `box_obs'
            quietly replace `bx_ctr'  = `box_center' in `box_obs'
            quietly replace `bx_wlo'  = `whi_lo'   in `box_obs'
            quietly replace `bx_whi'  = `whi_hi'   in `box_obs'
            quietly replace `bx_med'  = `grp_med'  in `box_obs'
            quietly replace `bx_mean' = `grp_mean' in `box_obs'
            * Median line endpoints (span the box width)
            quietly replace `bx_med_lo' = `box_center' - `boxwidth' / 2 in `box_obs'
            quietly replace `bx_med_hi' = `box_center' + `boxwidth' / 2 in `box_obs'

            * Whisker line
            local ++layer
            if "`orient'" == "horizontal" {
                local twoway_cmd "`twoway_cmd' (rspike `bx_wlo' `bx_whi' `bx_ctr' in `box_obs'/`box_obs', horizontal lcolor(gs4) `boxopts')"
            }
            else {
                local twoway_cmd "`twoway_cmd' (rspike `bx_wlo' `bx_whi' `bx_ctr' in `box_obs'/`box_obs', lcolor(gs4) `boxopts')"
            }

            * IQR box: skip for single-obs groups (degenerate zero-width)
            if `grp_n' > 1 {
                local ++layer
                if "`orient'" == "horizontal" {
                    local twoway_cmd "`twoway_cmd' (rbar `bx_q25' `bx_q75' `bx_ctr' in `box_obs'/`box_obs', horizontal barwidth(`boxwidth') fcolor(white) lcolor(gs4))"
                }
                else {
                    local twoway_cmd "`twoway_cmd' (rbar `bx_q25' `bx_q75' `bx_ctr' in `box_obs'/`box_obs', barwidth(`boxwidth') fcolor(white) lcolor(gs4))"
                }
            }

            * Median line (rspike spanning box width)
            if "`nomedian'" == "" {
                local ++layer
                if "`orient'" == "horizontal" {
                    * Vertical line at x=median spanning box height
                    local twoway_cmd "`twoway_cmd' (rspike `bx_med_lo' `bx_med_hi' `bx_med' in `box_obs'/`box_obs', lcolor(gs2) lwidth(medthick))"
                }
                else {
                    * Horizontal line at y=median spanning box width
                    local twoway_cmd "`twoway_cmd' (rspike `bx_med_lo' `bx_med_hi' `bx_med' in `box_obs'/`box_obs', horizontal lcolor(gs2) lwidth(medthick))"
                }
            }

            * Mean marker (optional, small filled circle)
            if "`mean'" != "" {
                local ++layer
                if "`orient'" == "horizontal" {
                    local twoway_cmd "`twoway_cmd' (scatter `bx_ctr' `bx_mean' in `box_obs'/`box_obs', msymbol(O) msize(small) mcolor(gs2))"
                }
                else {
                    local twoway_cmd "`twoway_cmd' (scatter `bx_mean' `bx_ctr' in `box_obs'/`box_obs', msymbol(O) msize(small) mcolor(gs2))"
                }
            }
        }

        * --- Rain (jittered scatter) ---
        if "`norain'" == "" {
            tempvar rain_pos_`g'
            if "`overlap'" != "" | "`mirror'" != "" {
                * Overlap: jitter points around box center
                if "`mirror'" != "" {
                    local _bc = `center'
                }
                else {
                    local _bc = `center' - (`jitter' * `cloudwidth' / 2 + 0.02)
                }
                quietly gen double `rain_pos_`g'' = `_bc' + ///
                    (runiform() - 0.5) * `boxwidth' * `jitter' * 3 ///
                    if `over_num' == `lev'
            }
            else {
                * Default: rain below box with clear separation
                local rain_top = `box_center' - `boxwidth' / 2 - 0.02
                quietly gen double `rain_pos_`g'' = `rain_top' - ///
                    runiform() * `jitter' * `cloudwidth' ///
                    if `over_num' == `lev'
            }

            local ++layer
            if "`orient'" == "horizontal" {
                local twoway_cmd "`twoway_cmd' (scatter `rain_pos_`g'' `varlist' if `over_num' == `lev', msymbol(oh) msize(`pointsize') mcolor(`clr'%60) `pointopts')"
            }
            else {
                local twoway_cmd "`twoway_cmd' (scatter `varlist' `rain_pos_`g'' if `over_num' == `lev', msymbol(oh) msize(`pointsize') mcolor(`clr'%60) `pointopts')"
            }
        }

        * Track legend: fallback to rain, then box median layer
        if ("`nocloud'" != "" | `skip_cloud') {
            if "`norain'" == "" {
                * Use rain layer for legend
                local legend_order "`legend_order' `layer'"
                local legend_labels `"`legend_labels' label(`layer' `"`grp_lab'"')"'
            }
            else if "`nobox'" == "" {
                * Use median marker layer for legend (last box layer)
                local legend_order "`legend_order' `layer'"
                local legend_labels `"`legend_labels' label(`layer' `"`grp_lab'"')"'
            }
        }
    }

    * =========================================================================
    * AXIS LABELS
    * =========================================================================
    local ylab_spec ""
    local g = 0
    foreach lev of local grp_levels {
        local ++g
        local center = `g' * `gap'
        local grp_lab : word `g' of `grp_labels'
        local ylab_spec `"`ylab_spec' `center' `"`grp_lab'"'"'
    }

    * =========================================================================
    * LEGEND
    * =========================================================================
    local legend_spec ""
    if `n_groups' == 1 {
        local legend_spec "legend(off)"
    }
    else if `"`legend'"' != "" {
        local legend_spec `"legend(`legend')"'
    }
    else {
        local legend_spec `"legend(order(`legend_order') `legend_labels' rows(1) position(6) size(small))"'
    }

    * =========================================================================
    * ASSEMBLE GRAPH OPTIONS
    * =========================================================================
    local var_label : variable label `varlist'
    if `"`var_label'"' == "" local var_label "`varlist'"

    local graph_opts "scheme(`scheme')"

    if `"`title'"'       != "" local graph_opts `"`graph_opts' title(`title')"'
    if `"`subtitle'"'    != "" local graph_opts `"`graph_opts' subtitle(`subtitle')"'
    if `"`note'"'        != "" local graph_opts `"`graph_opts' note(`note')"'
    if `"`name'"'        != "" local graph_opts `"`graph_opts' name(`name')"'
    if `"`saving'"'      != "" local graph_opts `"`graph_opts' saving(`saving')"'
    if `"`plotregion'"'  != "" local graph_opts `"`graph_opts' plotregion(`plotregion')"'
    if `"`graphregion'"' != "" local graph_opts `"`graph_opts' graphregion(`graphregion')"'

    * Axis titles
    if "`orient'" == "horizontal" {
        if `"`xtitle'"' == "" local xtitle `"`"`var_label'"'"'
        if `"`ytitle'"' == "" & `n_groups' > 1 {
            local over_label : variable label `over'
            if `"`over_label'"' == "" & "`over'" != "" local over_label "`over'"
            local ytitle `"`"`over_label'"'"'
        }
        else if `"`ytitle'"' == "" {
            local ytitle `"" ""'
        }
        local graph_opts `"`graph_opts' xtitle(`xtitle') ytitle(`ytitle')"'
        local graph_opts `"`graph_opts' ylabel(`ylab_spec', angle(0) noticks nogrid) yscale(noline)"'
    }
    else {
        if `"`ytitle'"' == "" local ytitle `"`"`var_label'"'"'
        if `"`xtitle'"' == "" & `n_groups' > 1 {
            local over_label : variable label `over'
            if `"`over_label'"' == "" & "`over'" != "" local over_label "`over'"
            local xtitle `"`"`over_label'"'"'
        }
        else if `"`xtitle'"' == "" {
            local xtitle `"" ""'
        }
        local graph_opts `"`graph_opts' ytitle(`ytitle') xtitle(`xtitle')"'
        local graph_opts `"`graph_opts' xlabel(`ylab_spec', noticks nogrid) xscale(noline)"'
    }

    * =========================================================================
    * DRAW GRAPH
    * =========================================================================
    twoway `twoway_cmd', `legend_spec' `graph_opts' `options'

    } // end capture noisily

    * Save return code from the captured block
    local rc = _rc
    restore

    * Always restore session state
    set varabbrev `_varabbrev'
    set more `_more'

    * Re-raise any error from the captured block
    if `rc' {
        exit `rc'
    }

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================
    * Label stats matrix
    matrix colnames `stats' = n mean sd median q25 q75 iqr bandwidth
    if `n_groups' > 1 {
        matrix rownames `stats' = `stat_names'
    }

    return scalar N = `N'
    return scalar n_groups = `n_groups'
    return matrix stats = `stats'
    return local varname "`varlist'"
    if "`over'" != "" {
        return local over "`over'"
    }

    display as text "Raincloud plot: " as result "`varlist'"
    if "`over'" != "" {
        display as text "  Groups:       " as result "`n_groups'" ///
            as text " (over: " as result "`over'" as text ")"
    }
    display as text "  Observations: " as result %10.0fc `N'
    display as text "  Elements:     " as result ///
        cond("`nocloud'" == "", "cloud ", "") ///
        cond("`norain'" == "",  "rain ",  "") ///
        cond("`nobox'" == "",   "box",    "")

end
