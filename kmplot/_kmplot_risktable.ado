*! _kmplot_risktable Version 1.2.9  2026/08/21
*! Risk table helper for kmplot
*! Author: Timothy P Copeland, Karolinska Institutet

/*
Internal helper program. Generates a number-at-risk table graph
to be combined with the main KM plot via graph combine.

Options:
  events  - show cumulative events in compact "N (E)" format
  mono    - display all numbers in black (default: match line colors)

Called from kmplot.ado. Not intended for direct use.
*/

program define _kmplot_risktable, rclass
        version 16.0
        local _orig_varabbrev = c(varabbrev)
        set varabbrev off
        local _kmplot_rt_preserved = 0
        capture noisily {

    syntax , GRPvar(varname) NGRoups(integer) GRAPHName(name) ///
        [TIMEpoints(numlist sort) ///
	         COLors(string asis) SCHeme(string) XMax(real -1) RISKHeight(real -1) ///
	         XTItle(string asis) XLAbel(string asis) YLAbel(string asis) ///
	         EVents MONO TOPTimeaxis]

    if "`scheme'" == "" local scheme "`c(scheme)'"
    if `"`xtitle'"' == "" local xtitle "Analysis time"
    local ncolors : word count `colors'
    if `ncolors' == 0 & "`mono'" == "" {
        noisily display as error "colors() must contain at least one color"
        exit 198
    }
    local _xt_len = strlen(`"`xtitle'"')
    while `_xt_len' >= 2 & ///
        substr(`"`xtitle'"', 1, 1) == char(34) & ///
        substr(`"`xtitle'"', `_xt_len', 1) == char(34) {
        local xtitle = substr(`"`xtitle'"', 2, `_xt_len' - 2)
        local _xt_len = strlen(`"`xtitle'"')
    }

    * Read group labels from dataset characteristics (set by kmplot)
    forvalues g = 1/`ngroups' {
        local grplbl`g' : char _dta[_kmplot_grplbl`g']
        if `"`grplbl`g''"' == "" local grplbl`g' "Group `g'"
    }

    * Determine time range
    if `xmax' <= 0 {
        quietly summarize _t
        local xmax = r(max)
    }

    * Auto timepoints if not specified
    if "`timepoints'" == "" {
        if `xmax' <= 0 {
            * All events at time 0 — use single timepoint
            local timepoints "0"
        }
        else {
            local step = `xmax' / 5
            if `step' >= 100 {
                local step = round(`step', 50)
            }
            else if `step' >= 10 {
                local step = round(`step', 5)
            }
            else if `step' >= 1 {
                local step = round(`step', 1)
            }
            else {
                local step = round(`step', 0.5)
            }
            if `step' <= 0 local step = `xmax' / 5
            if `step' <= 0 local step = `xmax'
            numlist "0(`step')`xmax'"
            local timepoints `r(numlist)'
        }
    }

    local ntp : word count `timepoints'

    * =====================================================================
    * COMPUTE AT-RISK COUNTS (before preserve)
    * =====================================================================

    capture confirm variable _t0
    local has_t0 = (_rc == 0)

    local st_id : char _dta[st_id]
    local st_wv : char _dta[st_wv]
    tempvar rt_weight rt_loss rt_tag
    quietly gen double `rt_weight' = 1
    if `"`st_wv'"' != "" {
        quietly replace `rt_weight' = `st_wv'
    }

    if `"`st_id'"' != "" {
        quietly bysort `st_id' (_t0 _t): gen byte `rt_loss' = ///
            (_d == 0 & (_n == _N | _t < _t0[_n + 1] | ///
            `grpvar' != `grpvar'[_n + 1]))
    }
    else {
        quietly gen byte `rt_loss' = (_d == 0)
    }

	    tempname rtmat
	    matrix `rtmat' = J(`ngroups' * `ntp', 5, .)
	    matrix colnames `rtmat' = group time at_risk events censored

	    forvalues g = 1/`ngroups' {
	        local j = 0
	        foreach tp of local timepoints {
	            local ++j
            if `"`st_id'"' != "" {
                if `has_t0' {
                    quietly egen byte `rt_tag' = tag(`st_id') ///
                        if _t >= `tp' & ///
                        (_t0 < `tp' | (_t0 == 0 & `tp' == 0)) & ///
                        `grpvar' == `g'
                }
                else {
                    quietly egen byte `rt_tag' = tag(`st_id') ///
                        if _t >= `tp' & `grpvar' == `g'
                }
                quietly summarize `rt_weight' if `rt_tag' == 1, meanonly
                local nrisk_`g'_`j' = r(sum)
                quietly drop `rt_tag'
            }
            else {
                if `has_t0' {
                    quietly summarize `rt_weight' ///
                        if _t >= `tp' & ///
                        (_t0 < `tp' | (_t0 == 0 & `tp' == 0)) & ///
                        `grpvar' == `g', meanonly
                }
                else {
                    quietly summarize `rt_weight' ///
                        if _t >= `tp' & `grpvar' == `g', meanonly
                }
                local nrisk_`g'_`j' = r(sum)
	            }
	        }
	    }

    * =====================================================================
    * COMPUTE CUMULATIVE EVENTS (before preserve, if requested)
    * =====================================================================

	    forvalues g = 1/`ngroups' {
	        local j = 0
	        foreach tp of local timepoints {
	            local ++j
	            quietly summarize `rt_weight' ///
                    if _t <= `tp' & _d == 1 & `grpvar' == `g', meanonly
	            local nevt_`g'_`j' = r(sum)
	            quietly summarize `rt_weight' ///
                    if _t <= `tp' & `rt_loss' == 1 & `grpvar' == `g', meanonly
	            local ncens_`g'_`j' = r(sum)
	        }
	    }

	    local _rt_row = 0
	    forvalues g = 1/`ngroups' {
	        local j = 0
	        foreach tp of local timepoints {
	            local ++j
	            local ++_rt_row
	            matrix `rtmat'[`_rt_row', 1] = `g'
	            matrix `rtmat'[`_rt_row', 2] = `tp'
	            matrix `rtmat'[`_rt_row', 3] = `nrisk_`g'_`j''
	            matrix `rtmat'[`_rt_row', 4] = `nevt_`g'_`j''
	            matrix `rtmat'[`_rt_row', 5] = `ncens_`g'_`j''
	        }
	    }

    * =====================================================================
    * BUILD SCATTER DATASET
    * =====================================================================

        preserve
        local _kmplot_rt_preserved = 1
        clear

        local nobs = `ngroups' * `ntp'
        quietly set obs `nobs'

        tempvar rt_time rt_ypos rt_label rt_grplabel rt_grp
        quietly gen double `rt_time' = .
        quietly gen double `rt_ypos' = .
        quietly gen str30 `rt_label' = ""
        quietly gen str244 `rt_grplabel' = ""
        quietly gen int `rt_grp' = .

    local row = 0

    forvalues g = 1/`ngroups' {
        local j = 0
        foreach tp of local timepoints {
            local ++j
            local ++row
                quietly replace `rt_time' = `tp' in `row'
                quietly replace `rt_ypos' = `ngroups' - `g' + 1 in `row'
                if "`events'" != "" {
                    * Compact "N (E)" format
                    local nr = `nrisk_`g'_`j''
                    local ne = `nevt_`g'_`j''
                    quietly replace `rt_label' = "`nr' (`ne')" in `row'
                }
                else {
                    quietly replace `rt_label' = "`nrisk_`g'_`j''" in `row'
                }
                quietly replace `rt_grp' = `g' in `row'
                if `j' == 1 {
                    quietly replace `rt_grplabel' = `"`grplbl`g''"' in `row'
                }
            }
        }

    * =====================================================================
    * BUILD SCATTER COMMAND
    * =====================================================================

    local scatcmd ""
    local xaxis_cmd ""
    if "`toptimeaxis'" != "" local xaxis_cmd "xaxis(1 2)"
    forvalues g = 1/`ngroups' {
        if "`mono'" != "" {
            local col "black"
        }
        else {
            local colidx = mod(`g' - 1, `ncolors') + 1
            local col : word `colidx' of `colors'
            if "`col'" == "" local col "black"
        }
            local scatcmd `"`scatcmd' (scatter `rt_ypos' `rt_time' if `rt_grp' == `g', `xaxis_cmd' msymbol(none) mlabel(`rt_label') mlabposition(0) mlabcolor(`col') mlabsize(small))"'
    }
    local scatcmd `"`scatcmd' (scatter `rt_ypos' `rt_time' if `rt_grplabel' != "", `xaxis_cmd' msymbol(none) mlabel(`rt_grplabel') mlabposition(9) mlabgap(4) mlabcolor(black) mlabsize(small))"'

    * =====================================================================
    * Y-AXIS LABELS
    * =====================================================================

    * Keep breathing room below the final risk-table row.
    local ymin = 0.0
    local ymax = `ngroups' + 0.5
    if `riskheight' > 0 {
        local fysize = `riskheight'
    }
    else {
        local fysize = 25
        if `ngroups' > 3 {
            local fysize = 25 + (`ngroups' - 3) * 4
            if `fysize' > 60 local fysize = 60
        }
    }

    if "`events'" != "" {
        local ytitle_rt "No. at risk (events)"
    }
    else {
        local ytitle_rt "No. at risk"
    }

    * =====================================================================
    * DRAW RISK TABLE
    * =====================================================================

    * Match the main plot's time-zero origin so table columns align with it.
    local xstart = 0

    local xlabel_cmd ""
    local plot_margin_left = 10
    local plot_margin_right = 6
    if `"`xlabel'"' != "" {
        * Append nogrid to the user spec: into the existing suboption group if
        * one is present (a comma), otherwise as a new suboption group.
        if strpos(`"`xlabel'"', ",") {
            local xlabel_cmd xlabel(`xlabel' nogrid)
        }
        else {
            local xlabel_cmd xlabel(`xlabel', nogrid)
        }
    }
    else {
        local xlabel_cmd xlabel(`timepoints', labsize(vsmall) noticks nogrid)
    }

    * Reserve the same left-axis width as the main plot without displaying a
    * second set of y labels.  graph combine aligns whole graphs, not their
    * plot regions, so both panels must carry the same axis geometry.
    if `"`ylabel'"' != "" {
        if strpos(`"`ylabel'"', ",") {
            local ylabel_cmd ylabel(`ylabel' labcolor(none) tlcolor(none) nogrid)
        }
        else {
            local ylabel_cmd ylabel(`ylabel', labcolor(none) tlcolor(none) nogrid)
        }
    }
    else {
        local ylabel_cmd "ylabel(0(0.25)1, format(%4.2f) angle(0) labcolor(none) tlcolor(none) nogrid)"
    }

    local xtitle_cmd `"xtitle(`"`xtitle'"', size(vsmall))"'
    local xscale_cmd "xscale(range(`xstart' `xmax') noextend noline)"
    local separator_cmd ""
    local time_title_cmd ""
    if "`toptimeaxis'" != "" {
        if `"`xlabel'"' != "" {
            if strpos(`"`xlabel'"', ",") {
                local top_xlabel_cmd xlabel(`xlabel' nogrid axis(2))
            }
            else {
                local top_xlabel_cmd xlabel(`xlabel', labsize(small) noticks nogrid axis(2))
            }
        }
        else {
            local top_xlabel_cmd xlabel(`timepoints', labsize(small) noticks nogrid axis(2))
        }
        local xlabel_cmd `"xlabel(, nolabels noticks nogrid axis(1)) `top_xlabel_cmd'"'
        local xtitle_cmd `"xtitle("", axis(1)) xtitle("", axis(2))"'
        local xscale_cmd `"xscale(range(`xstart' `xmax') noextend noline axis(1)) xscale(range(`xstart' `xmax') noextend noline axis(2))"'
        local ymax = `ngroups' + 1.50
        local time_title_y = `ngroups' + 1.45
        local time_title_x = (`xstart' + `xmax') / 2
        local time_title_cmd `"text(`time_title_y' `time_title_x' `"`xtitle'"', placement(n) size(small))"'
        local separator_y = `ngroups' + 0.55
        local separator_cmd "yline(`separator_y', lcolor(gs8) lpattern(solid) lwidth(thin))"
    }

    twoway `scatcmd', ///
        `ylabel_cmd' ///
        `xlabel_cmd' ///
        yscale(range(`ymin' `ymax') noline) ///
        `xscale_cmd' ///
        `xtitle_cmd' ///
        ytitle("`ytitle_rt'", size(small)) ///
        `time_title_cmd' ///
        `separator_cmd' ///
        title("") subtitle("") ///
        scheme(`scheme') ///
        name(`graphname', replace) nodraw ///
        plotregion(margin(l=`plot_margin_left' r=`plot_margin_right' t=2 b=0)) ///
        graphregion(margin(l=0 t=0 b=0)) ///
        legend(off) ///
        fysize(`fysize')

        restore
        local _kmplot_rt_preserved = 0

        } // end capture noisily
        local rc = _rc
        if `_kmplot_rt_preserved' {
            capture restore
        }
	        set varabbrev `_orig_varabbrev'
	        if `rc' exit `rc'
	        return scalar riskheight = `fysize'
	        return scalar n_timepoints = `ntp'
	        return scalar plot_margin_left = `plot_margin_left'
	        return scalar plot_margin_right = `plot_margin_right'
	        return local timepoints "`timepoints'"
	        return matrix risktable = `rtmat'
	end
