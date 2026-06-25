*! _kmplot_risktable Version 1.2.0  2026/06/26
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

    syntax , GRPvar(varname) NGRoups(integer) ///
        [TIMEpoints(numlist sort) ///
	         COLors(string asis) SCHeme(string) XMax(real -1) RISKHeight(real -1) ///
	         XTItle(string asis) XLAbel(string asis) ///
	         EVents MONO]

    if "`scheme'" == "" local scheme "`c(scheme)'"
    if `"`xtitle'"' == "" local xtitle "Analysis time"
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

	    tempname rtmat
	    matrix `rtmat' = J(`ngroups' * `ntp', 5, .)
	    matrix colnames `rtmat' = group time at_risk events censored

	    forvalues g = 1/`ngroups' {
	        local j = 0
	        foreach tp of local timepoints {
	            local ++j
            if `has_t0' {
                quietly count if _t >= `tp' & _t0 <= `tp' & `grpvar' == `g'
            }
            else {
                quietly count if _t >= `tp' & `grpvar' == `g'
	            }
	            local nrisk_`g'_`j' = r(N)
	        }
	    }

    * =====================================================================
    * COMPUTE CUMULATIVE EVENTS (before preserve, if requested)
    * =====================================================================

	    forvalues g = 1/`ngroups' {
	        local j = 0
	        foreach tp of local timepoints {
	            local ++j
	            quietly count if _t <= `tp' & _d == 1 & `grpvar' == `g'
	            local nevt_`g'_`j' = r(N)
	            quietly count if _t <= `tp' & _d == 0 & `grpvar' == `g'
	            local ncens_`g'_`j' = r(N)
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

        tempvar rt_time rt_ypos rt_label rt_grp
        quietly gen double `rt_time' = .
        quietly gen double `rt_ypos' = .
        quietly gen str30 `rt_label' = ""
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
            }
        }

    * =====================================================================
    * BUILD SCATTER COMMAND
    * =====================================================================

    local scatcmd ""
    forvalues g = 1/`ngroups' {
        if "`mono'" != "" {
            local col "black"
        }
        else {
            local colidx = mod(`g' - 1, 8) + 1
            local col : word `colidx' of `colors'
            if "`col'" == "" local col "black"
        }
            local scatcmd `"`scatcmd' (scatter `rt_ypos' `rt_time' if `rt_grp' == `g', msymbol(none) mlabel(`rt_label') mlabposition(0) mlabcolor(`col') mlabsize(vsmall))"'
    }

    * =====================================================================
    * Y-AXIS LABELS
    * =====================================================================

    local ylabels ""

    forvalues g = 1/`ngroups' {
        local yval = `ngroups' - `g' + 1
        local lbl `"`grplbl`g''"'
        local ylabels `"`ylabels' `yval' `"`lbl'"'"'
    }

	    local ymin = 0.5
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

    local tp_first : word 1 of `timepoints'

    * Offset xscale start to separate ylabel from first data point
    local xstart = `tp_first' - (`xmax' - `tp_first') * 0.02

    local xlabel_cmd ""
    if `"`xlabel'"' != "" {
        local xlabel_cmd xlabel(`xlabel')
    }
    else {
        local xlabel_cmd xlabel(`timepoints', labsize(vsmall) noticks)
    }

    twoway `scatcmd', ///
        ylabel(`ylabels', angle(0) labsize(vsmall) noticks nogrid) ///
        `xlabel_cmd' ///
        yscale(range(`ymin' `ymax') noline) ///
        xscale(range(`xstart' `xmax') noline) ///
        xtitle(`"`xtitle'"', size(vsmall)) ///
        ytitle("`ytitle_rt'", size(vsmall)) ///
        title("") subtitle("") ///
        scheme(`scheme') ///
        name(_kmplot_risktable, replace) nodraw ///
        plotregion(margin(l=3 r=0 t=2 b=0)) ///
        graphregion(margin(t=0 b=0)) ///
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
	        return local timepoints "`timepoints'"
	        return matrix risktable = `rtmat'
	end
